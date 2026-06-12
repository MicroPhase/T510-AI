#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"/../../../.. && pwd)"
TB_DIR="$ROOT_DIR/lib/rfnoc/transport_adapters/rfnoc_ta_x4xx_eth"
BUILD_DIR="$TB_DIR/.xsim_tb_iq_path_v2_smoke"
TOP="tb_iq_path_v2_smoke"

XVLOG="${XVLOG:-/opt/Xilinx/Vivado/2022.2/bin/xvlog}"
XELAB="${XELAB:-/opt/Xilinx/Vivado/2022.2/bin/xelab}"
XSIM="${XSIM:-/opt/Xilinx/Vivado/2022.2/bin/xsim}"

"$ROOT_DIR/scripts/rebuild_build_ip_cache.sh" --if-missing

mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"
rm -rf xsim.dir .Xil

INCDIRS=(
  "$ROOT_DIR/lib/control"
  "$ROOT_DIR/lib/fifo"
  "$ROOT_DIR/lib/t510_ai_radio_ctrl/iq_framework"
  "$ROOT_DIR/lib/t510_ai_radio_ctrl/iq_framework/util_cpack2"
  "$ROOT_DIR/lib/t510_ai_radio_ctrl/iq_framework/util_pack_common"
  "$TB_DIR"
)

XVLOG_ARGS=()
for inc in "${INCDIRS[@]}"; do
  XVLOG_ARGS+=("-i" "$inc")
done

VERILOG_FILES=(
  "$ROOT_DIR/lib/control/synchronizer_impl.v"
  "$ROOT_DIR/lib/control/synchronizer.v"
  "$ROOT_DIR/lib/control/ram_2port.v"
  "$ROOT_DIR/lib/fifo/axi_fifo_flop.v"
  "$ROOT_DIR/lib/fifo/axi_fifo_flop2.v"
  "$ROOT_DIR/lib/fifo/axi_fifo_short.v"
  "$ROOT_DIR/lib/fifo/axi_fifo_bram.v"
  "$ROOT_DIR/lib/fifo/axi_fifo.v"
  "$ROOT_DIR/lib/fifo/axi_fifo_2clk.v"
  "$ROOT_DIR/lib/t510_ai_radio_ctrl/iq_framework/util_pack_common/ad_perfect_shuffle.v"
  "$ROOT_DIR/lib/t510_ai_radio_ctrl/iq_framework/util_pack_common/pack_ctrl.v"
  "$ROOT_DIR/lib/t510_ai_radio_ctrl/iq_framework/util_pack_common/pack_interconnect.v"
  "$ROOT_DIR/lib/t510_ai_radio_ctrl/iq_framework/util_pack_common/pack_network.v"
  "$ROOT_DIR/lib/t510_ai_radio_ctrl/iq_framework/util_pack_common/pack_shell.v"
  "$ROOT_DIR/lib/t510_ai_radio_ctrl/iq_framework/util_cpack2/util_cpack2_impl.v"
  "$ROOT_DIR/lib/t510_ai_radio_ctrl/iq_framework/util_cpack2/util_cpack2.v"
  "$ROOT_DIR/lib/t510_ai_radio_ctrl/iq_framework/custom_rx_cpack.v"
  "$ROOT_DIR/lib/t510_ai_radio_ctrl/iq_framework/custom_timekeeper.v"
  "$ROOT_DIR/lib/t510_ai_radio_ctrl/iq_framework/t510_ai_iq_capture_v2.v"
  "$ROOT_DIR/lib/t510_ai_radio_ctrl/iq_framework/iq_framework_rx_wrapper_v2.v"
  "$ROOT_DIR/top/t510_ai/build-ip/xczu47drffve1156-2-i/fifo_short_2clk/simulation/fifo_generator_vlog_beh.v"
  "$ROOT_DIR/top/t510_ai/build-ip/xczu47drffve1156-2-i/fifo_short_2clk/hdl/fifo_generator_v13_2_rfs.v"
  "$ROOT_DIR/top/t510_ai/build-ip/xczu47drffve1156-2-i/fifo_short_2clk/sim/fifo_short_2clk.v"
  "$ROOT_DIR/top/t510_ai/build-ip/xczu47drffve1156-2-i/fifo_4k_2clk/simulation/fifo_generator_vlog_beh.v"
  "$ROOT_DIR/top/t510_ai/build-ip/xczu47drffve1156-2-i/fifo_4k_2clk/hdl/fifo_generator_v13_2_rfs.v"
  "$ROOT_DIR/top/t510_ai/build-ip/xczu47drffve1156-2-i/fifo_4k_2clk/sim/fifo_4k_2clk.v"
)

SV_FILES=(
  "$TB_DIR/chdr_epid_loopback.sv"
  "$TB_DIR/chdr_iq_bridge_v2.sv"
  "$TB_DIR/chdr_epid_split_v2.sv"
  "$TB_DIR/tb_iq_path_v2_smoke.sv"
)

"$XVLOG" "${XVLOG_ARGS[@]}" "${VERILOG_FILES[@]}"
"$XVLOG" -sv "${XVLOG_ARGS[@]}" "${SV_FILES[@]}"
"$XELAB" "$TOP" -s "$TOP" -timescale 1ns/1ps -mt off -L unisims_ver -L unimacro_ver
"$XSIM" "$TOP" -runall
