#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
ARTIFACT_DIR="$ROOT_DIR/artifacts/t510_ai_100g_full_system"
PURGE_PROJECT=0
PURGE_BUILD_IP=0
PRUNE_IDE=0

for arg in "$@"; do
	case "$arg" in
	--purge-project)
		PURGE_PROJECT=1
		;;
	--purge-build-ip)
		PURGE_BUILD_IP=1
		;;
	--source-only)
		PURGE_PROJECT=1
		PURGE_BUILD_IP=1
		;;
	--prune-ide)
		PRUNE_IDE=1
		;;
	*)
		printf 'usage: %s [--purge-project] [--purge-build-ip] [--source-only] [--prune-ide]\n' "$0" >&2
		exit 1
		;;
	esac
done

copy_if_exists() {
	src="$1"
	dst="$2"

	if [ -f "$src" ]; then
		mkdir -p "$(dirname "$dst")"
		cp "$src" "$dst"
		printf 'saved: %s\n' "${dst#$ROOT_DIR/}"
	fi
}

remove_path() {
	target="$1"

	if [ -e "$target" ]; then
		rm -rf "$target"
		printf 'removed: %s\n' "${target#$ROOT_DIR/}"
	fi
}

mkdir -p "$ARTIFACT_DIR"

if [ -x "$ROOT_DIR/scripts/refresh_exported_tcl.sh" ]; then
	"$ROOT_DIR/scripts/refresh_exported_tcl.sh"
fi

copy_if_exists \
	"$ROOT_DIR/vivado/project/t510_ai_100g_full_system/t510_ai_100g_full_system.runs/impl_1/t510_ai_100g_full_system_top.bit" \
	"$ARTIFACT_DIR/t510_ai_100g_full_system_top.bit"
copy_if_exists \
	"$ROOT_DIR/vivado/project/t510_ai_100g_full_system/t510_ai_100g_full_system.runs/impl_1/t510_ai_100g_full_system_top.ltx" \
	"$ARTIFACT_DIR/t510_ai_100g_full_system_top.ltx"
copy_if_exists \
	"$ROOT_DIR/vivado/project/t510_ai_100g_full_system/t510_ai_100g_full_system_top.xsa" \
	"$ARTIFACT_DIR/t510_ai_100g_full_system_top.xsa"

if [ "$PRUNE_IDE" -eq 1 ]; then
	remove_path "$ROOT_DIR/.qoder"
	remove_path "$ROOT_DIR/.vscode"
fi

if [ "$PURGE_PROJECT" -eq 1 ]; then
	remove_path "$ROOT_DIR/vivado/project"
fi

if [ "$PURGE_BUILD_IP" -eq 1 ]; then
	remove_path "$ROOT_DIR/top/t510_ai/build-ip/xczu47drffve1156-2-i"
fi

remove_path "$ROOT_DIR/top/t510_ai/build-ip/.vivado-cache-project"
remove_path "$ROOT_DIR/top/t510_ai/build-ip/.tmp"

find "$ROOT_DIR/top/t510_ai/build-ip" -type f \( -name '*.log' -o -name '*.out' -o -name '*.jou' -o -name '*.str' \) -print -delete \
	| sed "s#^$ROOT_DIR/##; s#^#removed: #"

printf '\narchive tree ready:\n'
printf '  source of truth: scripts/vivado/*.tcl, scripts/vivado/*.xdc, lib/, top/t510_ai/ip/, top-level HDL\n'
printf '  artifacts: %s\n' "${ARTIFACT_DIR#$ROOT_DIR/}"
if [ "$PURGE_PROJECT" -eq 1 ]; then
	printf '  vivado project cache: removed\n'
else
	printf '  vivado project cache: kept (use --purge-project to remove)\n'
fi
if [ "$PURGE_BUILD_IP" -eq 1 ]; then
	printf '  build-ip cache: removed\n'
else
	printf '  build-ip cache: kept (use --purge-build-ip to remove)\n'
fi
if [ "$PRUNE_IDE" -eq 1 ]; then
	printf '  IDE metadata: removed\n'
else
	printf '  IDE metadata: kept (use --prune-ide to remove)\n'
fi
printf '  restore command: bash scripts/recreate_vivado_project.sh\n'
