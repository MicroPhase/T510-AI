//
// Copyright 2026
//
// SPDX-License-Identifier: LGPL-3.0-or-later
//
// Module: t510_ai_100g_ps_top
//
// Description:
//
//   Minimal top-level wrapper for reusing the T510-AI 100G QSFP datapath in a
//   standalone project. This wrapper:
//
//   - fixes the QSFP protocol to a single 100GbE port on lane 0
//   - exposes the AXI-Lite register bus as discrete top-level signals
//   - exposes the AXI HP master bus as discrete top-level signals for PS DDR
//   - exposes the FPGA-side stream only for lane 0
//
//   The lane-0 stream is the internal transport stream produced by the
//   x4xx_qsfp_wrapper path. It is not a raw Ethernet MAC stream.
//
`default_nettype none

`include "./x4xx_mgt_types.vh"


module t510_ai_100g_ps_top #(
  parameter        CHDR_W   = 512,
  parameter        NET_CHDR_W = CHDR_W,
  parameter        BYTE_MTU = $clog2(8*1024),
  parameter [ 7:0] QSFP_NUM = 8'd0,
  parameter        NODE_INST = 0,
  parameter [15:0] PROTOVER = {8'd1, 8'd0}
) (
  // Global resets and clocks
  input  wire  core_arst,
  input  wire  rfnoc_ctrl_clk,
  input  wire  rfnoc_ctrl_rst,
  input  wire  rfnoc_chdr_clk,
  input  wire  rfnoc_chdr_rst,
  input  wire  dclk,

  // QSFP reference clock and serial IO
  input  wire  refclk_p,
  input  wire  refclk_n,
  input  wire  qsfp0_modprs_n,
  output logic qsfp0_reset_n,
  output logic qsfp0_lpmode_n,
  output logic [3:0] tx_p,
  output logic [3:0] tx_n,
  input  wire  [3:0] rx_p,
  input  wire  [3:0] rx_n,

  // Status
  input  wire  [ 15:0] device_id,
  output logic         recovered_clk,
  output logic [  3:0] eth_rx_irq,
  output logic [  3:0] eth_tx_irq,
  output logic [127:0] port_info,
  output logic [  3:0] link_up,
  output logic [  3:0] activity,

  // AXI-Lite register bus
  input  wire         axil_rst,
  input  wire         axil_clk,
  input  wire  [39:0] axil_awaddr,
  input  wire         axil_awvalid,
  output logic        axil_awready,
  input  wire  [31:0] axil_wdata,
  input  wire  [ 3:0] axil_wstrb,
  input  wire         axil_wvalid,
  output logic        axil_wready,
  output logic [ 1:0] axil_bresp,
  output logic        axil_bvalid,
  input  wire         axil_bready,
  input  wire  [39:0] axil_araddr,
  input  wire         axil_arvalid,
  output logic        axil_arready,
  output logic [31:0] axil_rdata,
  output logic [ 1:0] axil_rresp,
  output logic        axil_rvalid,
  input  wire         axil_rready,

  // AXI HP master bus toward PS
  input  wire          axi_rst,
  input  wire          axi_clk,
  output logic [ 48:0] axi_araddr,
  output logic [  1:0] axi_arburst,
  output logic [  3:0] axi_arcache,
  output logic [  7:0] axi_arlen,
  output logic [  0:0] axi_arlock,
  output logic [  2:0] axi_arprot,
  output logic [  3:0] axi_arqos,
  input  wire          axi_arready,
  output logic [  2:0] axi_arsize,
  output logic         axi_arvalid,
  output logic [ 48:0] axi_awaddr,
  output logic [  1:0] axi_awburst,
  output logic [  3:0] axi_awcache,
  output logic [  7:0] axi_awlen,
  output logic [  0:0] axi_awlock,
  output logic [  2:0] axi_awprot,
  output logic [  3:0] axi_awqos,
  input  wire          axi_awready,
  output logic [  2:0] axi_awsize,
  output logic         axi_awvalid,
  output logic         axi_bready,
  input  wire  [  1:0] axi_bresp,
  input  wire          axi_bvalid,
  input  wire  [127:0] axi_rdata,
  input  wire          axi_rlast,
  output logic         axi_rready,
  input  wire  [  1:0] axi_rresp,
  input  wire          axi_rvalid,
  output logic [127:0] axi_wdata,
  output logic         axi_wlast,
  input  wire          axi_wready,
  output logic [ 15:0] axi_wstrb,
  output logic         axi_wvalid,

  // Lane-0 FPGA-side stream
  output logic [CHDR_W-1:0] e2v_tdata,
  output logic              e2v_tlast,
  output logic              e2v_tvalid,
  input  wire               e2v_tready,

  input  wire  [CHDR_W-1:0] v2e_tdata,
  input  wire               v2e_tlast,
  input  wire               v2e_tvalid,
  output logic              v2e_tready
);

  localparam integer QSFP_PROTOCOL [3:0] = '{
    0: `MGT_100GbE,
    default: `MGT_Disabled
  };

  logic [4*CHDR_W-1:0] s_rfnoc_chdr_tdata;
  logic [         3:0] s_rfnoc_chdr_tlast;
  logic [         3:0] s_rfnoc_chdr_tvalid;
  logic [         3:0] s_rfnoc_chdr_tready;

  logic [4*CHDR_W-1:0] m_rfnoc_chdr_tdata;
  logic [         3:0] m_rfnoc_chdr_tlast;
  logic [         3:0] m_rfnoc_chdr_tvalid;
  logic [         3:0] m_rfnoc_chdr_tready;

  always_comb begin
    // Match the original X4xx top-level defaults for QSFP module control.
    qsfp0_reset_n  = 1'b1;
    qsfp0_lpmode_n = 1'b0;

    // Export only lane 0 to the standalone project.
    e2v_tdata  = s_rfnoc_chdr_tdata[CHDR_W-1:0];
    e2v_tlast  = s_rfnoc_chdr_tlast[0];
    e2v_tvalid = s_rfnoc_chdr_tvalid[0];

    s_rfnoc_chdr_tready = 4'b0000;
    s_rfnoc_chdr_tready[0] = e2v_tready;

    m_rfnoc_chdr_tdata  = '0;
    m_rfnoc_chdr_tlast  = '0;
    m_rfnoc_chdr_tvalid = '0;
    m_rfnoc_chdr_tdata[CHDR_W-1:0] = v2e_tdata;
    m_rfnoc_chdr_tlast[0]          = v2e_tlast;
    m_rfnoc_chdr_tvalid[0]         = v2e_tvalid;
    v2e_tready                     = m_rfnoc_chdr_tready[0];

    // Presence input is intentionally not consumed in this wrapper.
    if (qsfp0_modprs_n) begin
      qsfp0_reset_n  = 1'b1;
      qsfp0_lpmode_n = 1'b0;
    end
  end

  rfnoc_ta_x4xx_eth #(
    .PROTOCOL  (QSFP_PROTOCOL),
    .CHDR_W    (CHDR_W),
    .NET_CHDR_W(NET_CHDR_W),
    .BYTE_MTU  (BYTE_MTU),
    .QSFP_NUM  (QSFP_NUM),
    .NODE_INST (NODE_INST),
    .PROTOVER  (PROTOVER)
  ) rfnoc_ta_x4xx_eth_i (
    .core_arst          (core_arst),
    .rfnoc_ctrl_clk     (rfnoc_ctrl_clk),
    .rfnoc_ctrl_rst     (rfnoc_ctrl_rst),
    .rfnoc_chdr_clk     (rfnoc_chdr_clk),
    .rfnoc_chdr_rst     (rfnoc_chdr_rst),
    .refclk_p           (refclk_p),
    .refclk_n           (refclk_n),
    .dclk               (dclk),
    .tx_p               (tx_p),
    .tx_n               (tx_n),
    .rx_p               (rx_p),
    .rx_n               (rx_n),
    .recovered_clk      (recovered_clk),
    .device_id          (device_id),
    .rx_irq             (eth_rx_irq),
    .tx_irq             (eth_tx_irq),
    .port_info          (port_info),
    .link_up            (link_up),
    .activity           (activity),
    .axil_rst           (axil_rst),
    .axil_clk           (axil_clk),
    .axil_awaddr        (axil_awaddr),
    .axil_awvalid       (axil_awvalid),
    .axil_awready       (axil_awready),
    .axil_wdata         (axil_wdata),
    .axil_wstrb         (axil_wstrb),
    .axil_wvalid        (axil_wvalid),
    .axil_wready        (axil_wready),
    .axil_bresp         (axil_bresp),
    .axil_bvalid        (axil_bvalid),
    .axil_bready        (axil_bready),
    .axil_araddr        (axil_araddr),
    .axil_arvalid       (axil_arvalid),
    .axil_arready       (axil_arready),
    .axil_rdata         (axil_rdata),
    .axil_rresp         (axil_rresp),
    .axil_rvalid        (axil_rvalid),
    .axil_rready        (axil_rready),
    .axi_rst            (axi_rst),
    .axi_clk            (axi_clk),
    .axi_araddr         (axi_araddr),
    .axi_arburst        (axi_arburst),
    .axi_arcache        (axi_arcache),
    .axi_arlen          (axi_arlen),
    .axi_arlock         (axi_arlock),
    .axi_arprot         (axi_arprot),
    .axi_arqos          (axi_arqos),
    .axi_arready        (axi_arready),
    .axi_arsize         (axi_arsize),
    .axi_arvalid        (axi_arvalid),
    .axi_awaddr         (axi_awaddr),
    .axi_awburst        (axi_awburst),
    .axi_awcache        (axi_awcache),
    .axi_awlen          (axi_awlen),
    .axi_awlock         (axi_awlock),
    .axi_awprot         (axi_awprot),
    .axi_awqos          (axi_awqos),
    .axi_awready        (axi_awready),
    .axi_awsize         (axi_awsize),
    .axi_awvalid        (axi_awvalid),
    .axi_bready         (axi_bready),
    .axi_bresp          (axi_bresp),
    .axi_bvalid         (axi_bvalid),
    .axi_rdata          (axi_rdata),
    .axi_rlast          (axi_rlast),
    .axi_rready         (axi_rready),
    .axi_rresp          (axi_rresp),
    .axi_rvalid         (axi_rvalid),
    .axi_wdata          (axi_wdata),
    .axi_wlast          (axi_wlast),
    .axi_wready         (axi_wready),
    .axi_wstrb          (axi_wstrb),
    .axi_wvalid         (axi_wvalid),
    .s_rfnoc_chdr_tdata (s_rfnoc_chdr_tdata),
    .s_rfnoc_chdr_tlast (s_rfnoc_chdr_tlast),
    .s_rfnoc_chdr_tvalid(s_rfnoc_chdr_tvalid),
    .s_rfnoc_chdr_tready(s_rfnoc_chdr_tready),
    .m_rfnoc_chdr_tdata (m_rfnoc_chdr_tdata),
    .m_rfnoc_chdr_tlast (m_rfnoc_chdr_tlast),
    .m_rfnoc_chdr_tvalid(m_rfnoc_chdr_tvalid),
    .m_rfnoc_chdr_tready(m_rfnoc_chdr_tready)
  );

endmodule : t510_ai_100g_ps_top

`default_nettype wire
