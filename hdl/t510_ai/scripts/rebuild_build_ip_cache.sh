#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
ROOT_DIR="$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)"
VIVADO_SETTINGS="${VIVADO_SETTINGS:-/opt/Xilinx/Vivado/2022.2/settings64.sh}"
BUILD_IP_PART_DIR="xczu47drffve1156-2-i"
FORCE_REFRESH=1

if [[ "${1:-}" == "--if-missing" ]]; then
  FORCE_REFRESH=0
elif [[ "${1:-}" == "--force" || -z "${1:-}" ]]; then
  FORCE_REFRESH=1
else
  printf 'usage: %s [--force|--if-missing]\n' "$0" >&2
  exit 1
fi

if [[ ! -f "$VIVADO_SETTINGS" ]]; then
  printf 'missing Vivado settings: %s\n' "$VIVADO_SETTINGS" >&2
  exit 1
fi

if [[ "$FORCE_REFRESH" -eq 0 ]]; then
  required=(
    "$ROOT_DIR/top/t510_ai/build-ip/$BUILD_IP_PART_DIR/fifo_short_2clk/sim/fifo_short_2clk.v"
    "$ROOT_DIR/top/t510_ai/build-ip/$BUILD_IP_PART_DIR/fifo_4k_2clk/sim/fifo_4k_2clk.v"
    "$ROOT_DIR/top/t510_ai/build-ip/$BUILD_IP_PART_DIR/eth_100g_bd/eth_100g_bd/eth_100g_bd.bd"
    "$ROOT_DIR/top/t510_ai/build-ip/$BUILD_IP_PART_DIR/axi_eth_dma_bd/axi_eth_dma_bd/axi_eth_dma_bd.bd"
    "$ROOT_DIR/top/t510_ai/build-ip/$BUILD_IP_PART_DIR/axi_interconnect_eth_bd/axi_interconnect_eth_bd/axi_interconnect_eth_bd.bd"
    "$ROOT_DIR/top/t510_ai/build-ip/$BUILD_IP_PART_DIR/axi_interconnect_dma_bd/axi_interconnect_dma_bd/axi_interconnect_dma_bd.bd"
  )
  all_present=1
  for path in "${required[@]}"; do
    if [[ ! -e "$path" ]]; then
      all_present=0
      break
    fi
  done
  if [[ "$all_present" -eq 1 ]]; then
    printf 'build-ip cache already present\n'
    exit 0
  fi
fi

# shellcheck disable=SC1090
. "$VIVADO_SETTINGS"
vivado -mode batch \
  -notrace \
  -nolog \
  -nojournal \
  -source "$ROOT_DIR/scripts/vivado/rebuild_t510_ai_build_ip_cache.tcl" \
  -tclargs "$FORCE_REFRESH"
