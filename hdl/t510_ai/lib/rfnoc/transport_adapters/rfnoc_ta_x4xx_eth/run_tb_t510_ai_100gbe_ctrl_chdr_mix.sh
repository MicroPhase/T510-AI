#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"/../../../.. && pwd)"
TB_DIR="$ROOT_DIR/lib/rfnoc/transport_adapters/rfnoc_ta_x4xx_eth"
BUILD_DIR="$TB_DIR/.xsim_tb_t510_ai_100gbe_ctrl_chdr_mix"
TOP="tb_t510_ai_100gbe_ctrl_chdr_mix"

XVLOG="${XVLOG:-/opt/Xilinx/Vivado/2022.2/bin/xvlog}"
XELAB="${XELAB:-/opt/Xilinx/Vivado/2022.2/bin/xelab}"
XSIM="${XSIM:-/opt/Xilinx/Vivado/2022.2/bin/xsim}"

"$ROOT_DIR/scripts/rebuild_build_ip_cache.sh" --if-missing

mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"
rm -rf xsim.dir .Xil

INCDIRS=(
  "$ROOT_DIR/lib/axi4lite_sv"
  "$ROOT_DIR/lib/axi4_sv"
  "$ROOT_DIR/lib/axi4s_sv"
  "$ROOT_DIR/lib/rfnoc/core"
  "$ROOT_DIR/lib/rfnoc/xport_sv"
  "$ROOT_DIR/lib/rfnoc/utils"
  "$ROOT_DIR/lib/packet_proc"
  "$ROOT_DIR/lib/fifo"
  "$ROOT_DIR/lib/control"
  "$TB_DIR"
)

XVLOG_ARGS=()
for inc in "${INCDIRS[@]}"; do
  XVLOG_ARGS+=("-i" "$inc")
done

FILES=(
  "$ROOT_DIR/lib/axi4lite_sv/PkgAxiLite.sv"
  "$ROOT_DIR/lib/axi4_sv/PkgAxi.sv"
  "$ROOT_DIR/lib/axi4lite_sv/AxiLiteIf.sv"
  "$ROOT_DIR/lib/axi4_sv/AxiIf.sv"
  "$ROOT_DIR/lib/axi4s_sv/AxiStreamIf.sv"

  "$ROOT_DIR/lib/control/synchronizer_impl.v"
  "$ROOT_DIR/lib/control/synchronizer.v"
  "$ROOT_DIR/lib/control/ram_2port.v"
  "$ROOT_DIR/lib/control/map/cam_priority_encoder.v"
  "$ROOT_DIR/lib/control/map/cam_srl.v"
  "$ROOT_DIR/lib/control/map/cam_bram.v"
  "$ROOT_DIR/lib/control/map/cam.v"
  "$ROOT_DIR/lib/control/map/kv_map.v"

  "$ROOT_DIR/lib/fifo/axi_packet_gate.v"
  "$ROOT_DIR/lib/fifo/axi_fifo_flop.v"
  "$ROOT_DIR/lib/fifo/axi_fifo_flop2.v"
  "$ROOT_DIR/lib/fifo/axi_fifo_short.v"
  "$ROOT_DIR/lib/fifo/axi_fifo_bram.v"
  "$ROOT_DIR/lib/fifo/axi_fifo.v"
  "$ROOT_DIR/lib/fifo/axi_fifo_2clk.v"
  "$ROOT_DIR/lib/fifo/axi_mux_select.v"
  "$ROOT_DIR/lib/fifo/axi_mux.v"
  "$ROOT_DIR/lib/fifo/axi_demux.v"

  "$ROOT_DIR/lib/axi/axis_width_conv.v"
  "$ROOT_DIR/lib/axi/axis_upsizer.v"
  "$ROOT_DIR/lib/axi/axis_downsizer.v"

  "$TB_DIR/axi4s_add_bytes_stub.sv"
  "$TB_DIR/axi4s_remove_bytes_start_stub.sv"
  "$TB_DIR/axi4s_remove_bytes_stub.sv"
  "$TB_DIR/axi4s_width_conv_stub.sv"
  "$TB_DIR/axi4s_fifo_stub.sv"
  "$TB_DIR/axi4s_packet_gate_stub.sv"

  "$ROOT_DIR/lib/packet_proc/ip_hdr_checksum.v"

  "$ROOT_DIR/lib/rfnoc/core/chdr_mgmt_pkt_handler.v"

  "$ROOT_DIR/lib/rfnoc/utils/chdr_resize.v"
  "$ROOT_DIR/lib/rfnoc/utils/chdr_convert_up.v"
  "$ROOT_DIR/lib/rfnoc/utils/chdr_convert_down.v"
  "$ROOT_DIR/lib/rfnoc/utils/chdr_trim_payload.v"
  "$ROOT_DIR/lib/rfnoc/utils/chdr_strip_header.sv"

  "$ROOT_DIR/lib/rfnoc/crossbar/axis_switch.v"

  "$ROOT_DIR/lib/rfnoc/xport_sv/eth_ipv4_add_udp.sv"
  "$ROOT_DIR/lib/rfnoc/xport_sv/eth_ipv4_chdr_dispatch.sv"
  "$TB_DIR/chdr_xport_adapter_stub.sv"
  "$ROOT_DIR/lib/rfnoc/xport_sv/eth_ipv4_chdr_adapter.sv"
  "$ROOT_DIR/top/t510_ai/build-ip/xczu47drffve1156-2-i/fifo_short_2clk/simulation/fifo_generator_vlog_beh.v"
  "$ROOT_DIR/top/t510_ai/build-ip/xczu47drffve1156-2-i/fifo_short_2clk/hdl/fifo_generator_v13_2_rfs.v"
  "$ROOT_DIR/top/t510_ai/build-ip/xczu47drffve1156-2-i/fifo_short_2clk/sim/fifo_short_2clk.v"
  "$ROOT_DIR/top/t510_ai/build-ip/xczu47drffve1156-2-i/fifo_4k_2clk/sim/fifo_4k_2clk.v"

  "$TB_DIR/tb_t510_ai_100gbe_ctrl_chdr_mix.sv"
)

"$XVLOG" -sv "${XVLOG_ARGS[@]}" "${FILES[@]}"
"$XELAB" "$TOP" -s "$TOP" -timescale 1ns/1ps -mt off -L unisims_ver -L unimacro_ver
"$XSIM" "$TOP" -runall
