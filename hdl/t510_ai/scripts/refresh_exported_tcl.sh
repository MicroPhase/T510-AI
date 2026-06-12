#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
VIVADO_SETTINGS=${VIVADO_SETTINGS:-/opt/Xilinx/Vivado/2022.2/settings64.sh}
PROJECT_XPR="$ROOT_DIR/vivado/project/t510_ai_100g_full_system/t510_ai_100g_full_system.xpr"
EXPORT_TCL="$ROOT_DIR/scripts/vivado/export_current_t510_ai_bd_state.tcl"

if [ ! -f "$PROJECT_XPR" ]; then
	printf 'skip refresh: missing project %s\n' "${PROJECT_XPR#$ROOT_DIR/}"
	exit 0
fi

if [ ! -f "$VIVADO_SETTINGS" ]; then
	printf 'skip refresh: missing Vivado settings %s\n' "$VIVADO_SETTINGS" >&2
	exit 0
fi

printf 'refreshing exported Tcl from current Vivado project...\n'

# shellcheck disable=SC1090
. "$VIVADO_SETTINGS"
vivado -mode batch -source "$EXPORT_TCL"
