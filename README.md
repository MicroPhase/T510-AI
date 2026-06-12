# T510-AI Image Builder

This repository contains the board support files, hardware artifacts, Buildroot
configuration, and helper scripts used to build bootable SD-card images for the
T510-AI and T510-FNIC boards.

Only this top-level README is maintained for now. More detailed documentation
for the individual hardware, board, and host application areas will be added
later.

## Supported Boards

- `t510-ai`
- `t510-fnic`

You can list the boards known to the build system with:

```bash
make list-boards
```

## Prerequisites

The build expects the Xilinx 2022.2 tools to be installed and available on the
host machine. The Makefile uses Vivado/Vitis utilities such as `bootgen` and the
cross-compilers from the generated Buildroot host tree.

Set the Xilinx environment before building:

```bash
export VIVADO_SETTINGS=/opt/Xilinx/Vivado/2022.2/settings64.sh
```

If your installation path is different, point `VIVADO_SETTINGS` at the matching
`settings64.sh` file.

## Fetch External Sources

The Linux, U-Boot, Buildroot, ARM Trusted Firmware, embeddedsw, and
device-tree-xlnx source trees are shared build inputs. Fetch them before the
first build:

```bash
make BOARD=t510-ai fetch
```

When switching boards after one board has already patched the shared source
trees, reset and fetch for the target board:

```bash
make BOARD=t510-fnic reset-sources
make BOARD=t510-fnic fetch
```

## Build the T510-AI SD Image

Build the SD-card boot files for T510-AI with:

```bash
make BOARD=t510-ai sd
```

The output is written to:

```text
build/t510-ai/sd/
```

Typical files in that directory include `BOOT.BIN`, `Image`, `uEnv.txt`,
the device tree blob, and the compressed root filesystem image.

## Build the T510-FNIC SD Image

Build the SD-card boot files for T510-FNIC with:

```bash
make BOARD=t510-fnic sd
```

The output is written to:

```text
build/t510-fnic/sd/
```

Typical files in that directory include `BOOT.BIN`, `Image`, `uEnv.txt`,
the device tree blob, and the compressed root filesystem image.

## Useful Build Commands

Show the resolved configuration for a board:

```bash
make BOARD=t510-ai show-config
make BOARD=t510-fnic show-config
```

Build the default full image set for a board:

```bash
make BOARD=t510-ai
make BOARD=t510-fnic
```

Remove generated outputs:

```bash
make BOARD=t510-ai clean
make BOARD=t510-fnic clean
```

Remove generated outputs and fetched external source trees:

```bash
make distclean
```

## Notes

- Use `BOARD=t510-ai` or `BOARD=t510-fnic` on every command that depends on the
  target board.
- The SD image target assembles boot files under `build/<board>/sd/`; it does
  not write directly to an SD card.
- Generated directories such as `build/`, `.Xil/`, Vivado project output, and
  Buildroot output should not be committed.
