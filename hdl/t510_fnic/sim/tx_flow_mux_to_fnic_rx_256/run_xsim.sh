#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
VIVADO_VERSION="${VIVADO_VERSION:-2022.2}"
source "/opt/Xilinx/Vivado/${VIVADO_VERSION}/settings64.sh"

WORK_DIR="$(dirname "${BASH_SOURCE[0]}")/xsim_work"
rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

xvlog --sv \
  "$ROOT_DIR/hdl/t510_fnic/top/t510_fnic/rtl/t510_fnic_aurora_tx_mux_256.v" \
  "$ROOT_DIR/hdl/FNIC/fnic_xdma/hdl/fnic_aurora_flow_ctrl_rx_256.v" \
  "$ROOT_DIR/hdl/t510_fnic/sim/tx_flow_mux_to_fnic_rx_256/tb_t510_fnic_tx_flow_mux_to_fnic_rx_256.sv"

xelab tb_t510_fnic_tx_flow_mux_to_fnic_rx_256 \
  -s tb_t510_fnic_tx_flow_mux_to_fnic_rx_256
xsim tb_t510_fnic_tx_flow_mux_to_fnic_rx_256 -R
