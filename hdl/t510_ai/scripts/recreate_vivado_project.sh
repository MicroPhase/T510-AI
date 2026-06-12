#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
ROOT_DIR="$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)"
VIVADO_SETTINGS="${VIVADO_SETTINGS:-/opt/Xilinx/Vivado/2022.2/settings64.sh}"

if [[ ! -f "$VIVADO_SETTINGS" ]]; then
  printf 'missing Vivado settings: %s\n' "$VIVADO_SETTINGS" >&2
  exit 1
fi

"$SCRIPT_DIR/rebuild_build_ip_cache.sh" --force

# shellcheck disable=SC1090
. "$VIVADO_SETTINGS"
vivado -mode batch -source "$ROOT_DIR/scripts/vivado/create_t510_ai_100g_full_system_project.tcl"
