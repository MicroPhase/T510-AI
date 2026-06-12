#!/usr/bin/env python3

import argparse
import pathlib
import re
import sys


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Render board config files so all boot stages follow one PS UART selection."
    )
    parser.add_argument(
        "mode",
        choices=(
            "linux-dtsi",
            "uboot-dts",
            "uenv",
            "uboot-fragment",
            "buildroot-defconfig",
            "post-build",
        ),
    )
    parser.add_argument("--source", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--console-uart", type=int, choices=(0, 1), required=True)
    parser.add_argument("--post-build-script")
    return parser.parse_args()


def console_settings(console_uart: int) -> dict[str, str]:
    other_uart = 1 - console_uart
    base = {
        0: "0xff000000",
        1: "0xff010000",
    }[console_uart]
    return {
        "uart": str(console_uart),
        "other_uart": str(other_uart),
        "tty": "ttyPS0",
        "base": base,
        "earlycon": f"cdns,mmio,{base}",
        "default_bootargs": (
            "console=ttyPS0,115200 "
            f"earlycon=cdns,mmio,{base} "
            "root=/dev/ram0 rw clk_ignore_unused"
        ),
    }


def replace_console_bootargs(value: str, settings: dict[str, str]) -> str:
    value = re.sub(
        r"\bconsole=ttyPS[01],115200\b",
        f"console={settings['tty']},115200",
        value,
    )
    if f"console={settings['tty']},115200" not in value:
        value = f"console={settings['tty']},115200 {value}".strip()

    value = re.sub(
        r"\bearlycon=cdns,mmio,0x[0-9a-fA-F]+\b",
        f"earlycon={settings['earlycon']}",
        value,
    )
    if f"earlycon={settings['earlycon']}" not in value:
        value = f"earlycon={settings['earlycon']} {value}".strip()

    return re.sub(r"\s+", " ", value).strip()


def replace_or_append_dts_bootargs(text: str, settings: dict[str, str]) -> tuple[str, bool]:
    pattern = re.compile(r'(bootargs\s*=\s*")([^"]*)(";)', re.MULTILINE)

    def repl(match: re.Match[str]) -> str:
        return (
            match.group(1)
            + replace_console_bootargs(match.group(2), settings)
            + match.group(3)
        )

    updated, count = pattern.subn(repl, text)
    return updated, count > 0


def replace_or_append_uenv_bootargs(text: str, settings: dict[str, str]) -> str:
    pattern = re.compile(r"^(bootargs=)(.*)$", re.MULTILINE)

    def repl(match: re.Match[str]) -> str:
        return match.group(1) + replace_console_bootargs(match.group(2), settings)

    updated, count = pattern.subn(repl, text)
    if count == 0:
        updated = f"bootargs={settings['default_bootargs']}\n{updated.lstrip()}"
    return updated


def render_linux_dtsi(text: str, settings: dict[str, str]) -> str:
    text, has_bootargs = replace_or_append_dts_bootargs(text, settings)
    bootargs_line = ""
    if not has_bootargs:
        bootargs_line = (
            f'\n\t\tbootargs = "{settings["default_bootargs"]}";'
        )

    overlay = f"""
/* Generated console overrides. Keep PS UART selection in sync across boot stages. */
/ {{
\taliases {{
\t\tserial0 = &uart{settings["uart"]};
\t\tserial1 = &uart{settings["other_uart"]};
\t}};

\tchosen {{
\t\tstdout-path = "serial0:115200n8";{bootargs_line}
\t}};
}};

&uart{settings["uart"]} {{
\tstatus = "okay";
}};
"""
    return text.rstrip() + "\n\n" + overlay.lstrip()


def render_uboot_dts(text: str, settings: dict[str, str]) -> str:
    overlay = f"""
/* Generated console overrides. Keep PS UART selection in sync across boot stages. */
/ {{
\taliases {{
\t\tserial0 = &uart{settings["uart"]};
\t\tserial1 = &uart{settings["other_uart"]};
\t}};

\tchosen {{
\t\tstdout-path = "serial0:115200n8";
\t}};
}};

&uart{settings["uart"]} {{
\tstatus = "okay";
\tu-boot,dm-pre-reloc;
}};
"""
    return text.rstrip() + "\n\n" + overlay.lstrip()


def render_uenv(text: str, settings: dict[str, str]) -> str:
    return replace_or_append_uenv_bootargs(text, settings)


def replace_or_append_line(text: str, pattern: str, replacement: str) -> str:
    updated, count = re.subn(pattern, replacement, text, flags=re.MULTILINE)
    if count == 0:
        if updated and not updated.endswith("\n"):
            updated += "\n"
        updated += replacement + "\n"
    return updated


def render_uboot_fragment(text: str, settings: dict[str, str]) -> str:
    return replace_or_append_line(
        text,
        r"^CONFIG_DEBUG_UART_BASE=.*$",
        f"CONFIG_DEBUG_UART_BASE={settings['base']}",
    )


def render_buildroot_defconfig(
    text: str, settings: dict[str, str], post_build_script: str | None
) -> str:
    text = replace_or_append_line(
        text,
        r'^BR2_TARGET_GENERIC_GETTY_PORT="ttyPS[01]"$',
        f'BR2_TARGET_GENERIC_GETTY_PORT="{settings["tty"]}"',
    )
    if post_build_script:
        text = replace_or_append_line(
            text,
            r'^BR2_ROOTFS_POST_BUILD_SCRIPT=".*"$',
            f'BR2_ROOTFS_POST_BUILD_SCRIPT="{post_build_script}"',
        )
    return text


def render_post_build(text: str, settings: dict[str, str]) -> str:
    target_getty = (
        f'{settings["tty"]}::respawn:/sbin/getty -L {settings["tty"]} 115200 vt100'
    )
    for existing in (
        "ttyPS0::respawn:/sbin/getty -L ttyPS0 115200 vt100",
        "ttyPS1::respawn:/sbin/getty -L ttyPS1 115200 vt100",
    ):
        text = text.replace(existing, target_getty)

    for existing in ("^ttyPS0::respawn:", "^ttyPS1::respawn:"):
        text = text.replace(existing, f"^{settings['tty']}::respawn:")

    return text


def main() -> int:
    args = parse_args()
    settings = console_settings(args.console_uart)
    source = pathlib.Path(args.source)
    output = pathlib.Path(args.output)

    text = source.read_text()

    if args.mode == "linux-dtsi":
        rendered = render_linux_dtsi(text, settings)
    elif args.mode == "uboot-dts":
        rendered = render_uboot_dts(text, settings)
    elif args.mode == "uenv":
        rendered = render_uenv(text, settings)
    elif args.mode == "uboot-fragment":
        rendered = render_uboot_fragment(text, settings)
    elif args.mode == "buildroot-defconfig":
        rendered = render_buildroot_defconfig(
            text,
            settings,
            args.post_build_script,
        )
    elif args.mode == "post-build":
        rendered = render_post_build(text, settings)
    else:
        raise AssertionError(f"unsupported mode {args.mode}")

    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(rendered)
    return 0


if __name__ == "__main__":
    sys.exit(main())
