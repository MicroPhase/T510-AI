//Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
//--------------------------------------------------------------------------------
//Tool Version: Vivado v.2022.2 (lin64) Build 3671981 Fri Oct 14 04:59:54 MDT 2022
//Date        : Fri Apr 24 15:11:04 2026
//Host        : wcc-B760 running 64-bit Ubuntu 22.04.5 LTS
//Command     : generate_target axi_interconnect_dma_bd_wrapper.bd
//Design      : axi_interconnect_dma_bd_wrapper
//Purpose     : IP block netlist
//--------------------------------------------------------------------------------
`timescale 1 ps / 1 ps

module axi_interconnect_dma_bd_wrapper
   (clk40,
    clk40_rstn,
    m_axi_hp_araddr,
    m_axi_hp_arburst,
    m_axi_hp_arcache,
    m_axi_hp_arlen,
    m_axi_hp_arlock,
    m_axi_hp_arprot,
    m_axi_hp_arqos,
    m_axi_hp_arready,
    m_axi_hp_arregion,
    m_axi_hp_arsize,
    m_axi_hp_arvalid,
    m_axi_hp_awaddr,
    m_axi_hp_awburst,
    m_axi_hp_awcache,
    m_axi_hp_awlen,
    m_axi_hp_awlock,
    m_axi_hp_awprot,
    m_axi_hp_awqos,
    m_axi_hp_awready,
    m_axi_hp_awregion,
    m_axi_hp_awsize,
    m_axi_hp_awvalid,
    m_axi_hp_bready,
    m_axi_hp_bresp,
    m_axi_hp_bvalid,
    m_axi_hp_rdata,
    m_axi_hp_rlast,
    m_axi_hp_rready,
    m_axi_hp_rresp,
    m_axi_hp_rvalid,
    m_axi_hp_wdata,
    m_axi_hp_wlast,
    m_axi_hp_wready,
    m_axi_hp_wstrb,
    m_axi_hp_wvalid,
    s_axi_hp_dma0_araddr,
    s_axi_hp_dma0_arburst,
    s_axi_hp_dma0_arcache,
    s_axi_hp_dma0_arlen,
    s_axi_hp_dma0_arlock,
    s_axi_hp_dma0_arprot,
    s_axi_hp_dma0_arqos,
    s_axi_hp_dma0_arready,
    s_axi_hp_dma0_arregion,
    s_axi_hp_dma0_arsize,
    s_axi_hp_dma0_arvalid,
    s_axi_hp_dma0_awaddr,
    s_axi_hp_dma0_awburst,
    s_axi_hp_dma0_awcache,
    s_axi_hp_dma0_awlen,
    s_axi_hp_dma0_awlock,
    s_axi_hp_dma0_awprot,
    s_axi_hp_dma0_awqos,
    s_axi_hp_dma0_awready,
    s_axi_hp_dma0_awregion,
    s_axi_hp_dma0_awsize,
    s_axi_hp_dma0_awvalid,
    s_axi_hp_dma0_bready,
    s_axi_hp_dma0_bresp,
    s_axi_hp_dma0_bvalid,
    s_axi_hp_dma0_rdata,
    s_axi_hp_dma0_rlast,
    s_axi_hp_dma0_rready,
    s_axi_hp_dma0_rresp,
    s_axi_hp_dma0_rvalid,
    s_axi_hp_dma0_wdata,
    s_axi_hp_dma0_wlast,
    s_axi_hp_dma0_wready,
    s_axi_hp_dma0_wstrb,
    s_axi_hp_dma0_wvalid,
    s_axi_hp_dma1_araddr,
    s_axi_hp_dma1_arburst,
    s_axi_hp_dma1_arcache,
    s_axi_hp_dma1_arlen,
    s_axi_hp_dma1_arlock,
    s_axi_hp_dma1_arprot,
    s_axi_hp_dma1_arqos,
    s_axi_hp_dma1_arready,
    s_axi_hp_dma1_arregion,
    s_axi_hp_dma1_arsize,
    s_axi_hp_dma1_arvalid,
    s_axi_hp_dma1_awaddr,
    s_axi_hp_dma1_awburst,
    s_axi_hp_dma1_awcache,
    s_axi_hp_dma1_awlen,
    s_axi_hp_dma1_awlock,
    s_axi_hp_dma1_awprot,
    s_axi_hp_dma1_awqos,
    s_axi_hp_dma1_awready,
    s_axi_hp_dma1_awregion,
    s_axi_hp_dma1_awsize,
    s_axi_hp_dma1_awvalid,
    s_axi_hp_dma1_bready,
    s_axi_hp_dma1_bresp,
    s_axi_hp_dma1_bvalid,
    s_axi_hp_dma1_rdata,
    s_axi_hp_dma1_rlast,
    s_axi_hp_dma1_rready,
    s_axi_hp_dma1_rresp,
    s_axi_hp_dma1_rvalid,
    s_axi_hp_dma1_wdata,
    s_axi_hp_dma1_wlast,
    s_axi_hp_dma1_wready,
    s_axi_hp_dma1_wstrb,
    s_axi_hp_dma1_wvalid,
    s_axi_hp_dma2_araddr,
    s_axi_hp_dma2_arburst,
    s_axi_hp_dma2_arcache,
    s_axi_hp_dma2_arlen,
    s_axi_hp_dma2_arlock,
    s_axi_hp_dma2_arprot,
    s_axi_hp_dma2_arqos,
    s_axi_hp_dma2_arready,
    s_axi_hp_dma2_arregion,
    s_axi_hp_dma2_arsize,
    s_axi_hp_dma2_arvalid,
    s_axi_hp_dma2_awaddr,
    s_axi_hp_dma2_awburst,
    s_axi_hp_dma2_awcache,
    s_axi_hp_dma2_awlen,
    s_axi_hp_dma2_awlock,
    s_axi_hp_dma2_awprot,
    s_axi_hp_dma2_awqos,
    s_axi_hp_dma2_awready,
    s_axi_hp_dma2_awregion,
    s_axi_hp_dma2_awsize,
    s_axi_hp_dma2_awvalid,
    s_axi_hp_dma2_bready,
    s_axi_hp_dma2_bresp,
    s_axi_hp_dma2_bvalid,
    s_axi_hp_dma2_rdata,
    s_axi_hp_dma2_rlast,
    s_axi_hp_dma2_rready,
    s_axi_hp_dma2_rresp,
    s_axi_hp_dma2_rvalid,
    s_axi_hp_dma2_wdata,
    s_axi_hp_dma2_wlast,
    s_axi_hp_dma2_wready,
    s_axi_hp_dma2_wstrb,
    s_axi_hp_dma2_wvalid,
    s_axi_hp_dma3_araddr,
    s_axi_hp_dma3_arburst,
    s_axi_hp_dma3_arcache,
    s_axi_hp_dma3_arlen,
    s_axi_hp_dma3_arlock,
    s_axi_hp_dma3_arprot,
    s_axi_hp_dma3_arqos,
    s_axi_hp_dma3_arready,
    s_axi_hp_dma3_arregion,
    s_axi_hp_dma3_arsize,
    s_axi_hp_dma3_arvalid,
    s_axi_hp_dma3_awaddr,
    s_axi_hp_dma3_awburst,
    s_axi_hp_dma3_awcache,
    s_axi_hp_dma3_awlen,
    s_axi_hp_dma3_awlock,
    s_axi_hp_dma3_awprot,
    s_axi_hp_dma3_awqos,
    s_axi_hp_dma3_awready,
    s_axi_hp_dma3_awregion,
    s_axi_hp_dma3_awsize,
    s_axi_hp_dma3_awvalid,
    s_axi_hp_dma3_bready,
    s_axi_hp_dma3_bresp,
    s_axi_hp_dma3_bvalid,
    s_axi_hp_dma3_rdata,
    s_axi_hp_dma3_rlast,
    s_axi_hp_dma3_rready,
    s_axi_hp_dma3_rresp,
    s_axi_hp_dma3_rvalid,
    s_axi_hp_dma3_wdata,
    s_axi_hp_dma3_wlast,
    s_axi_hp_dma3_wready,
    s_axi_hp_dma3_wstrb,
    s_axi_hp_dma3_wvalid);
  input clk40;
  input clk40_rstn;
  output [48:0]m_axi_hp_araddr;
  output [1:0]m_axi_hp_arburst;
  output [3:0]m_axi_hp_arcache;
  output [7:0]m_axi_hp_arlen;
  output [0:0]m_axi_hp_arlock;
  output [2:0]m_axi_hp_arprot;
  output [3:0]m_axi_hp_arqos;
  input m_axi_hp_arready;
  output [3:0]m_axi_hp_arregion;
  output [2:0]m_axi_hp_arsize;
  output m_axi_hp_arvalid;
  output [48:0]m_axi_hp_awaddr;
  output [1:0]m_axi_hp_awburst;
  output [3:0]m_axi_hp_awcache;
  output [7:0]m_axi_hp_awlen;
  output [0:0]m_axi_hp_awlock;
  output [2:0]m_axi_hp_awprot;
  output [3:0]m_axi_hp_awqos;
  input m_axi_hp_awready;
  output [3:0]m_axi_hp_awregion;
  output [2:0]m_axi_hp_awsize;
  output m_axi_hp_awvalid;
  output m_axi_hp_bready;
  input [1:0]m_axi_hp_bresp;
  input m_axi_hp_bvalid;
  input [127:0]m_axi_hp_rdata;
  input m_axi_hp_rlast;
  output m_axi_hp_rready;
  input [1:0]m_axi_hp_rresp;
  input m_axi_hp_rvalid;
  output [127:0]m_axi_hp_wdata;
  output m_axi_hp_wlast;
  input m_axi_hp_wready;
  output [15:0]m_axi_hp_wstrb;
  output m_axi_hp_wvalid;
  input [48:0]s_axi_hp_dma0_araddr;
  input [1:0]s_axi_hp_dma0_arburst;
  input [3:0]s_axi_hp_dma0_arcache;
  input [7:0]s_axi_hp_dma0_arlen;
  input [0:0]s_axi_hp_dma0_arlock;
  input [2:0]s_axi_hp_dma0_arprot;
  input [3:0]s_axi_hp_dma0_arqos;
  output s_axi_hp_dma0_arready;
  input [3:0]s_axi_hp_dma0_arregion;
  input [2:0]s_axi_hp_dma0_arsize;
  input s_axi_hp_dma0_arvalid;
  input [48:0]s_axi_hp_dma0_awaddr;
  input [1:0]s_axi_hp_dma0_awburst;
  input [3:0]s_axi_hp_dma0_awcache;
  input [7:0]s_axi_hp_dma0_awlen;
  input [0:0]s_axi_hp_dma0_awlock;
  input [2:0]s_axi_hp_dma0_awprot;
  input [3:0]s_axi_hp_dma0_awqos;
  output s_axi_hp_dma0_awready;
  input [3:0]s_axi_hp_dma0_awregion;
  input [2:0]s_axi_hp_dma0_awsize;
  input s_axi_hp_dma0_awvalid;
  input s_axi_hp_dma0_bready;
  output [1:0]s_axi_hp_dma0_bresp;
  output s_axi_hp_dma0_bvalid;
  output [127:0]s_axi_hp_dma0_rdata;
  output s_axi_hp_dma0_rlast;
  input s_axi_hp_dma0_rready;
  output [1:0]s_axi_hp_dma0_rresp;
  output s_axi_hp_dma0_rvalid;
  input [127:0]s_axi_hp_dma0_wdata;
  input s_axi_hp_dma0_wlast;
  output s_axi_hp_dma0_wready;
  input [15:0]s_axi_hp_dma0_wstrb;
  input s_axi_hp_dma0_wvalid;
  input [48:0]s_axi_hp_dma1_araddr;
  input [1:0]s_axi_hp_dma1_arburst;
  input [3:0]s_axi_hp_dma1_arcache;
  input [7:0]s_axi_hp_dma1_arlen;
  input [0:0]s_axi_hp_dma1_arlock;
  input [2:0]s_axi_hp_dma1_arprot;
  input [3:0]s_axi_hp_dma1_arqos;
  output s_axi_hp_dma1_arready;
  input [3:0]s_axi_hp_dma1_arregion;
  input [2:0]s_axi_hp_dma1_arsize;
  input s_axi_hp_dma1_arvalid;
  input [48:0]s_axi_hp_dma1_awaddr;
  input [1:0]s_axi_hp_dma1_awburst;
  input [3:0]s_axi_hp_dma1_awcache;
  input [7:0]s_axi_hp_dma1_awlen;
  input [0:0]s_axi_hp_dma1_awlock;
  input [2:0]s_axi_hp_dma1_awprot;
  input [3:0]s_axi_hp_dma1_awqos;
  output s_axi_hp_dma1_awready;
  input [3:0]s_axi_hp_dma1_awregion;
  input [2:0]s_axi_hp_dma1_awsize;
  input s_axi_hp_dma1_awvalid;
  input s_axi_hp_dma1_bready;
  output [1:0]s_axi_hp_dma1_bresp;
  output s_axi_hp_dma1_bvalid;
  output [127:0]s_axi_hp_dma1_rdata;
  output s_axi_hp_dma1_rlast;
  input s_axi_hp_dma1_rready;
  output [1:0]s_axi_hp_dma1_rresp;
  output s_axi_hp_dma1_rvalid;
  input [127:0]s_axi_hp_dma1_wdata;
  input s_axi_hp_dma1_wlast;
  output s_axi_hp_dma1_wready;
  input [15:0]s_axi_hp_dma1_wstrb;
  input s_axi_hp_dma1_wvalid;
  input [48:0]s_axi_hp_dma2_araddr;
  input [1:0]s_axi_hp_dma2_arburst;
  input [3:0]s_axi_hp_dma2_arcache;
  input [7:0]s_axi_hp_dma2_arlen;
  input [0:0]s_axi_hp_dma2_arlock;
  input [2:0]s_axi_hp_dma2_arprot;
  input [3:0]s_axi_hp_dma2_arqos;
  output s_axi_hp_dma2_arready;
  input [3:0]s_axi_hp_dma2_arregion;
  input [2:0]s_axi_hp_dma2_arsize;
  input s_axi_hp_dma2_arvalid;
  input [48:0]s_axi_hp_dma2_awaddr;
  input [1:0]s_axi_hp_dma2_awburst;
  input [3:0]s_axi_hp_dma2_awcache;
  input [7:0]s_axi_hp_dma2_awlen;
  input [0:0]s_axi_hp_dma2_awlock;
  input [2:0]s_axi_hp_dma2_awprot;
  input [3:0]s_axi_hp_dma2_awqos;
  output s_axi_hp_dma2_awready;
  input [3:0]s_axi_hp_dma2_awregion;
  input [2:0]s_axi_hp_dma2_awsize;
  input s_axi_hp_dma2_awvalid;
  input s_axi_hp_dma2_bready;
  output [1:0]s_axi_hp_dma2_bresp;
  output s_axi_hp_dma2_bvalid;
  output [127:0]s_axi_hp_dma2_rdata;
  output s_axi_hp_dma2_rlast;
  input s_axi_hp_dma2_rready;
  output [1:0]s_axi_hp_dma2_rresp;
  output s_axi_hp_dma2_rvalid;
  input [127:0]s_axi_hp_dma2_wdata;
  input s_axi_hp_dma2_wlast;
  output s_axi_hp_dma2_wready;
  input [15:0]s_axi_hp_dma2_wstrb;
  input s_axi_hp_dma2_wvalid;
  input [48:0]s_axi_hp_dma3_araddr;
  input [1:0]s_axi_hp_dma3_arburst;
  input [3:0]s_axi_hp_dma3_arcache;
  input [7:0]s_axi_hp_dma3_arlen;
  input [0:0]s_axi_hp_dma3_arlock;
  input [2:0]s_axi_hp_dma3_arprot;
  input [3:0]s_axi_hp_dma3_arqos;
  output s_axi_hp_dma3_arready;
  input [3:0]s_axi_hp_dma3_arregion;
  input [2:0]s_axi_hp_dma3_arsize;
  input s_axi_hp_dma3_arvalid;
  input [48:0]s_axi_hp_dma3_awaddr;
  input [1:0]s_axi_hp_dma3_awburst;
  input [3:0]s_axi_hp_dma3_awcache;
  input [7:0]s_axi_hp_dma3_awlen;
  input [0:0]s_axi_hp_dma3_awlock;
  input [2:0]s_axi_hp_dma3_awprot;
  input [3:0]s_axi_hp_dma3_awqos;
  output s_axi_hp_dma3_awready;
  input [3:0]s_axi_hp_dma3_awregion;
  input [2:0]s_axi_hp_dma3_awsize;
  input s_axi_hp_dma3_awvalid;
  input s_axi_hp_dma3_bready;
  output [1:0]s_axi_hp_dma3_bresp;
  output s_axi_hp_dma3_bvalid;
  output [127:0]s_axi_hp_dma3_rdata;
  output s_axi_hp_dma3_rlast;
  input s_axi_hp_dma3_rready;
  output [1:0]s_axi_hp_dma3_rresp;
  output s_axi_hp_dma3_rvalid;
  input [127:0]s_axi_hp_dma3_wdata;
  input s_axi_hp_dma3_wlast;
  output s_axi_hp_dma3_wready;
  input [15:0]s_axi_hp_dma3_wstrb;
  input s_axi_hp_dma3_wvalid;

  wire clk40;
  wire clk40_rstn;
  wire [48:0]m_axi_hp_araddr;
  wire [1:0]m_axi_hp_arburst;
  wire [3:0]m_axi_hp_arcache;
  wire [7:0]m_axi_hp_arlen;
  wire [0:0]m_axi_hp_arlock;
  wire [2:0]m_axi_hp_arprot;
  wire [3:0]m_axi_hp_arqos;
  wire m_axi_hp_arready;
  wire [3:0]m_axi_hp_arregion;
  wire [2:0]m_axi_hp_arsize;
  wire m_axi_hp_arvalid;
  wire [48:0]m_axi_hp_awaddr;
  wire [1:0]m_axi_hp_awburst;
  wire [3:0]m_axi_hp_awcache;
  wire [7:0]m_axi_hp_awlen;
  wire [0:0]m_axi_hp_awlock;
  wire [2:0]m_axi_hp_awprot;
  wire [3:0]m_axi_hp_awqos;
  wire m_axi_hp_awready;
  wire [3:0]m_axi_hp_awregion;
  wire [2:0]m_axi_hp_awsize;
  wire m_axi_hp_awvalid;
  wire m_axi_hp_bready;
  wire [1:0]m_axi_hp_bresp;
  wire m_axi_hp_bvalid;
  wire [127:0]m_axi_hp_rdata;
  wire m_axi_hp_rlast;
  wire m_axi_hp_rready;
  wire [1:0]m_axi_hp_rresp;
  wire m_axi_hp_rvalid;
  wire [127:0]m_axi_hp_wdata;
  wire m_axi_hp_wlast;
  wire m_axi_hp_wready;
  wire [15:0]m_axi_hp_wstrb;
  wire m_axi_hp_wvalid;
  wire [48:0]s_axi_hp_dma0_araddr;
  wire [1:0]s_axi_hp_dma0_arburst;
  wire [3:0]s_axi_hp_dma0_arcache;
  wire [7:0]s_axi_hp_dma0_arlen;
  wire [0:0]s_axi_hp_dma0_arlock;
  wire [2:0]s_axi_hp_dma0_arprot;
  wire [3:0]s_axi_hp_dma0_arqos;
  wire s_axi_hp_dma0_arready;
  wire [3:0]s_axi_hp_dma0_arregion;
  wire [2:0]s_axi_hp_dma0_arsize;
  wire s_axi_hp_dma0_arvalid;
  wire [48:0]s_axi_hp_dma0_awaddr;
  wire [1:0]s_axi_hp_dma0_awburst;
  wire [3:0]s_axi_hp_dma0_awcache;
  wire [7:0]s_axi_hp_dma0_awlen;
  wire [0:0]s_axi_hp_dma0_awlock;
  wire [2:0]s_axi_hp_dma0_awprot;
  wire [3:0]s_axi_hp_dma0_awqos;
  wire s_axi_hp_dma0_awready;
  wire [3:0]s_axi_hp_dma0_awregion;
  wire [2:0]s_axi_hp_dma0_awsize;
  wire s_axi_hp_dma0_awvalid;
  wire s_axi_hp_dma0_bready;
  wire [1:0]s_axi_hp_dma0_bresp;
  wire s_axi_hp_dma0_bvalid;
  wire [127:0]s_axi_hp_dma0_rdata;
  wire s_axi_hp_dma0_rlast;
  wire s_axi_hp_dma0_rready;
  wire [1:0]s_axi_hp_dma0_rresp;
  wire s_axi_hp_dma0_rvalid;
  wire [127:0]s_axi_hp_dma0_wdata;
  wire s_axi_hp_dma0_wlast;
  wire s_axi_hp_dma0_wready;
  wire [15:0]s_axi_hp_dma0_wstrb;
  wire s_axi_hp_dma0_wvalid;
  wire [48:0]s_axi_hp_dma1_araddr;
  wire [1:0]s_axi_hp_dma1_arburst;
  wire [3:0]s_axi_hp_dma1_arcache;
  wire [7:0]s_axi_hp_dma1_arlen;
  wire [0:0]s_axi_hp_dma1_arlock;
  wire [2:0]s_axi_hp_dma1_arprot;
  wire [3:0]s_axi_hp_dma1_arqos;
  wire s_axi_hp_dma1_arready;
  wire [3:0]s_axi_hp_dma1_arregion;
  wire [2:0]s_axi_hp_dma1_arsize;
  wire s_axi_hp_dma1_arvalid;
  wire [48:0]s_axi_hp_dma1_awaddr;
  wire [1:0]s_axi_hp_dma1_awburst;
  wire [3:0]s_axi_hp_dma1_awcache;
  wire [7:0]s_axi_hp_dma1_awlen;
  wire [0:0]s_axi_hp_dma1_awlock;
  wire [2:0]s_axi_hp_dma1_awprot;
  wire [3:0]s_axi_hp_dma1_awqos;
  wire s_axi_hp_dma1_awready;
  wire [3:0]s_axi_hp_dma1_awregion;
  wire [2:0]s_axi_hp_dma1_awsize;
  wire s_axi_hp_dma1_awvalid;
  wire s_axi_hp_dma1_bready;
  wire [1:0]s_axi_hp_dma1_bresp;
  wire s_axi_hp_dma1_bvalid;
  wire [127:0]s_axi_hp_dma1_rdata;
  wire s_axi_hp_dma1_rlast;
  wire s_axi_hp_dma1_rready;
  wire [1:0]s_axi_hp_dma1_rresp;
  wire s_axi_hp_dma1_rvalid;
  wire [127:0]s_axi_hp_dma1_wdata;
  wire s_axi_hp_dma1_wlast;
  wire s_axi_hp_dma1_wready;
  wire [15:0]s_axi_hp_dma1_wstrb;
  wire s_axi_hp_dma1_wvalid;
  wire [48:0]s_axi_hp_dma2_araddr;
  wire [1:0]s_axi_hp_dma2_arburst;
  wire [3:0]s_axi_hp_dma2_arcache;
  wire [7:0]s_axi_hp_dma2_arlen;
  wire [0:0]s_axi_hp_dma2_arlock;
  wire [2:0]s_axi_hp_dma2_arprot;
  wire [3:0]s_axi_hp_dma2_arqos;
  wire s_axi_hp_dma2_arready;
  wire [3:0]s_axi_hp_dma2_arregion;
  wire [2:0]s_axi_hp_dma2_arsize;
  wire s_axi_hp_dma2_arvalid;
  wire [48:0]s_axi_hp_dma2_awaddr;
  wire [1:0]s_axi_hp_dma2_awburst;
  wire [3:0]s_axi_hp_dma2_awcache;
  wire [7:0]s_axi_hp_dma2_awlen;
  wire [0:0]s_axi_hp_dma2_awlock;
  wire [2:0]s_axi_hp_dma2_awprot;
  wire [3:0]s_axi_hp_dma2_awqos;
  wire s_axi_hp_dma2_awready;
  wire [3:0]s_axi_hp_dma2_awregion;
  wire [2:0]s_axi_hp_dma2_awsize;
  wire s_axi_hp_dma2_awvalid;
  wire s_axi_hp_dma2_bready;
  wire [1:0]s_axi_hp_dma2_bresp;
  wire s_axi_hp_dma2_bvalid;
  wire [127:0]s_axi_hp_dma2_rdata;
  wire s_axi_hp_dma2_rlast;
  wire s_axi_hp_dma2_rready;
  wire [1:0]s_axi_hp_dma2_rresp;
  wire s_axi_hp_dma2_rvalid;
  wire [127:0]s_axi_hp_dma2_wdata;
  wire s_axi_hp_dma2_wlast;
  wire s_axi_hp_dma2_wready;
  wire [15:0]s_axi_hp_dma2_wstrb;
  wire s_axi_hp_dma2_wvalid;
  wire [48:0]s_axi_hp_dma3_araddr;
  wire [1:0]s_axi_hp_dma3_arburst;
  wire [3:0]s_axi_hp_dma3_arcache;
  wire [7:0]s_axi_hp_dma3_arlen;
  wire [0:0]s_axi_hp_dma3_arlock;
  wire [2:0]s_axi_hp_dma3_arprot;
  wire [3:0]s_axi_hp_dma3_arqos;
  wire s_axi_hp_dma3_arready;
  wire [3:0]s_axi_hp_dma3_arregion;
  wire [2:0]s_axi_hp_dma3_arsize;
  wire s_axi_hp_dma3_arvalid;
  wire [48:0]s_axi_hp_dma3_awaddr;
  wire [1:0]s_axi_hp_dma3_awburst;
  wire [3:0]s_axi_hp_dma3_awcache;
  wire [7:0]s_axi_hp_dma3_awlen;
  wire [0:0]s_axi_hp_dma3_awlock;
  wire [2:0]s_axi_hp_dma3_awprot;
  wire [3:0]s_axi_hp_dma3_awqos;
  wire s_axi_hp_dma3_awready;
  wire [3:0]s_axi_hp_dma3_awregion;
  wire [2:0]s_axi_hp_dma3_awsize;
  wire s_axi_hp_dma3_awvalid;
  wire s_axi_hp_dma3_bready;
  wire [1:0]s_axi_hp_dma3_bresp;
  wire s_axi_hp_dma3_bvalid;
  wire [127:0]s_axi_hp_dma3_rdata;
  wire s_axi_hp_dma3_rlast;
  wire s_axi_hp_dma3_rready;
  wire [1:0]s_axi_hp_dma3_rresp;
  wire s_axi_hp_dma3_rvalid;
  wire [127:0]s_axi_hp_dma3_wdata;
  wire s_axi_hp_dma3_wlast;
  wire s_axi_hp_dma3_wready;
  wire [15:0]s_axi_hp_dma3_wstrb;
  wire s_axi_hp_dma3_wvalid;

  axi_interconnect_dma_bd axi_interconnect_dma_bd_i
       (.clk40(clk40),
        .clk40_rstn(clk40_rstn),
        .m_axi_hp_araddr(m_axi_hp_araddr),
        .m_axi_hp_arburst(m_axi_hp_arburst),
        .m_axi_hp_arcache(m_axi_hp_arcache),
        .m_axi_hp_arlen(m_axi_hp_arlen),
        .m_axi_hp_arlock(m_axi_hp_arlock),
        .m_axi_hp_arprot(m_axi_hp_arprot),
        .m_axi_hp_arqos(m_axi_hp_arqos),
        .m_axi_hp_arready(m_axi_hp_arready),
        .m_axi_hp_arregion(m_axi_hp_arregion),
        .m_axi_hp_arsize(m_axi_hp_arsize),
        .m_axi_hp_arvalid(m_axi_hp_arvalid),
        .m_axi_hp_awaddr(m_axi_hp_awaddr),
        .m_axi_hp_awburst(m_axi_hp_awburst),
        .m_axi_hp_awcache(m_axi_hp_awcache),
        .m_axi_hp_awlen(m_axi_hp_awlen),
        .m_axi_hp_awlock(m_axi_hp_awlock),
        .m_axi_hp_awprot(m_axi_hp_awprot),
        .m_axi_hp_awqos(m_axi_hp_awqos),
        .m_axi_hp_awready(m_axi_hp_awready),
        .m_axi_hp_awregion(m_axi_hp_awregion),
        .m_axi_hp_awsize(m_axi_hp_awsize),
        .m_axi_hp_awvalid(m_axi_hp_awvalid),
        .m_axi_hp_bready(m_axi_hp_bready),
        .m_axi_hp_bresp(m_axi_hp_bresp),
        .m_axi_hp_bvalid(m_axi_hp_bvalid),
        .m_axi_hp_rdata(m_axi_hp_rdata),
        .m_axi_hp_rlast(m_axi_hp_rlast),
        .m_axi_hp_rready(m_axi_hp_rready),
        .m_axi_hp_rresp(m_axi_hp_rresp),
        .m_axi_hp_rvalid(m_axi_hp_rvalid),
        .m_axi_hp_wdata(m_axi_hp_wdata),
        .m_axi_hp_wlast(m_axi_hp_wlast),
        .m_axi_hp_wready(m_axi_hp_wready),
        .m_axi_hp_wstrb(m_axi_hp_wstrb),
        .m_axi_hp_wvalid(m_axi_hp_wvalid),
        .s_axi_hp_dma0_araddr(s_axi_hp_dma0_araddr),
        .s_axi_hp_dma0_arburst(s_axi_hp_dma0_arburst),
        .s_axi_hp_dma0_arcache(s_axi_hp_dma0_arcache),
        .s_axi_hp_dma0_arlen(s_axi_hp_dma0_arlen),
        .s_axi_hp_dma0_arlock(s_axi_hp_dma0_arlock),
        .s_axi_hp_dma0_arprot(s_axi_hp_dma0_arprot),
        .s_axi_hp_dma0_arqos(s_axi_hp_dma0_arqos),
        .s_axi_hp_dma0_arready(s_axi_hp_dma0_arready),
        .s_axi_hp_dma0_arregion(s_axi_hp_dma0_arregion),
        .s_axi_hp_dma0_arsize(s_axi_hp_dma0_arsize),
        .s_axi_hp_dma0_arvalid(s_axi_hp_dma0_arvalid),
        .s_axi_hp_dma0_awaddr(s_axi_hp_dma0_awaddr),
        .s_axi_hp_dma0_awburst(s_axi_hp_dma0_awburst),
        .s_axi_hp_dma0_awcache(s_axi_hp_dma0_awcache),
        .s_axi_hp_dma0_awlen(s_axi_hp_dma0_awlen),
        .s_axi_hp_dma0_awlock(s_axi_hp_dma0_awlock),
        .s_axi_hp_dma0_awprot(s_axi_hp_dma0_awprot),
        .s_axi_hp_dma0_awqos(s_axi_hp_dma0_awqos),
        .s_axi_hp_dma0_awready(s_axi_hp_dma0_awready),
        .s_axi_hp_dma0_awregion(s_axi_hp_dma0_awregion),
        .s_axi_hp_dma0_awsize(s_axi_hp_dma0_awsize),
        .s_axi_hp_dma0_awvalid(s_axi_hp_dma0_awvalid),
        .s_axi_hp_dma0_bready(s_axi_hp_dma0_bready),
        .s_axi_hp_dma0_bresp(s_axi_hp_dma0_bresp),
        .s_axi_hp_dma0_bvalid(s_axi_hp_dma0_bvalid),
        .s_axi_hp_dma0_rdata(s_axi_hp_dma0_rdata),
        .s_axi_hp_dma0_rlast(s_axi_hp_dma0_rlast),
        .s_axi_hp_dma0_rready(s_axi_hp_dma0_rready),
        .s_axi_hp_dma0_rresp(s_axi_hp_dma0_rresp),
        .s_axi_hp_dma0_rvalid(s_axi_hp_dma0_rvalid),
        .s_axi_hp_dma0_wdata(s_axi_hp_dma0_wdata),
        .s_axi_hp_dma0_wlast(s_axi_hp_dma0_wlast),
        .s_axi_hp_dma0_wready(s_axi_hp_dma0_wready),
        .s_axi_hp_dma0_wstrb(s_axi_hp_dma0_wstrb),
        .s_axi_hp_dma0_wvalid(s_axi_hp_dma0_wvalid),
        .s_axi_hp_dma1_araddr(s_axi_hp_dma1_araddr),
        .s_axi_hp_dma1_arburst(s_axi_hp_dma1_arburst),
        .s_axi_hp_dma1_arcache(s_axi_hp_dma1_arcache),
        .s_axi_hp_dma1_arlen(s_axi_hp_dma1_arlen),
        .s_axi_hp_dma1_arlock(s_axi_hp_dma1_arlock),
        .s_axi_hp_dma1_arprot(s_axi_hp_dma1_arprot),
        .s_axi_hp_dma1_arqos(s_axi_hp_dma1_arqos),
        .s_axi_hp_dma1_arready(s_axi_hp_dma1_arready),
        .s_axi_hp_dma1_arregion(s_axi_hp_dma1_arregion),
        .s_axi_hp_dma1_arsize(s_axi_hp_dma1_arsize),
        .s_axi_hp_dma1_arvalid(s_axi_hp_dma1_arvalid),
        .s_axi_hp_dma1_awaddr(s_axi_hp_dma1_awaddr),
        .s_axi_hp_dma1_awburst(s_axi_hp_dma1_awburst),
        .s_axi_hp_dma1_awcache(s_axi_hp_dma1_awcache),
        .s_axi_hp_dma1_awlen(s_axi_hp_dma1_awlen),
        .s_axi_hp_dma1_awlock(s_axi_hp_dma1_awlock),
        .s_axi_hp_dma1_awprot(s_axi_hp_dma1_awprot),
        .s_axi_hp_dma1_awqos(s_axi_hp_dma1_awqos),
        .s_axi_hp_dma1_awready(s_axi_hp_dma1_awready),
        .s_axi_hp_dma1_awregion(s_axi_hp_dma1_awregion),
        .s_axi_hp_dma1_awsize(s_axi_hp_dma1_awsize),
        .s_axi_hp_dma1_awvalid(s_axi_hp_dma1_awvalid),
        .s_axi_hp_dma1_bready(s_axi_hp_dma1_bready),
        .s_axi_hp_dma1_bresp(s_axi_hp_dma1_bresp),
        .s_axi_hp_dma1_bvalid(s_axi_hp_dma1_bvalid),
        .s_axi_hp_dma1_rdata(s_axi_hp_dma1_rdata),
        .s_axi_hp_dma1_rlast(s_axi_hp_dma1_rlast),
        .s_axi_hp_dma1_rready(s_axi_hp_dma1_rready),
        .s_axi_hp_dma1_rresp(s_axi_hp_dma1_rresp),
        .s_axi_hp_dma1_rvalid(s_axi_hp_dma1_rvalid),
        .s_axi_hp_dma1_wdata(s_axi_hp_dma1_wdata),
        .s_axi_hp_dma1_wlast(s_axi_hp_dma1_wlast),
        .s_axi_hp_dma1_wready(s_axi_hp_dma1_wready),
        .s_axi_hp_dma1_wstrb(s_axi_hp_dma1_wstrb),
        .s_axi_hp_dma1_wvalid(s_axi_hp_dma1_wvalid),
        .s_axi_hp_dma2_araddr(s_axi_hp_dma2_araddr),
        .s_axi_hp_dma2_arburst(s_axi_hp_dma2_arburst),
        .s_axi_hp_dma2_arcache(s_axi_hp_dma2_arcache),
        .s_axi_hp_dma2_arlen(s_axi_hp_dma2_arlen),
        .s_axi_hp_dma2_arlock(s_axi_hp_dma2_arlock),
        .s_axi_hp_dma2_arprot(s_axi_hp_dma2_arprot),
        .s_axi_hp_dma2_arqos(s_axi_hp_dma2_arqos),
        .s_axi_hp_dma2_arready(s_axi_hp_dma2_arready),
        .s_axi_hp_dma2_arregion(s_axi_hp_dma2_arregion),
        .s_axi_hp_dma2_arsize(s_axi_hp_dma2_arsize),
        .s_axi_hp_dma2_arvalid(s_axi_hp_dma2_arvalid),
        .s_axi_hp_dma2_awaddr(s_axi_hp_dma2_awaddr),
        .s_axi_hp_dma2_awburst(s_axi_hp_dma2_awburst),
        .s_axi_hp_dma2_awcache(s_axi_hp_dma2_awcache),
        .s_axi_hp_dma2_awlen(s_axi_hp_dma2_awlen),
        .s_axi_hp_dma2_awlock(s_axi_hp_dma2_awlock),
        .s_axi_hp_dma2_awprot(s_axi_hp_dma2_awprot),
        .s_axi_hp_dma2_awqos(s_axi_hp_dma2_awqos),
        .s_axi_hp_dma2_awready(s_axi_hp_dma2_awready),
        .s_axi_hp_dma2_awregion(s_axi_hp_dma2_awregion),
        .s_axi_hp_dma2_awsize(s_axi_hp_dma2_awsize),
        .s_axi_hp_dma2_awvalid(s_axi_hp_dma2_awvalid),
        .s_axi_hp_dma2_bready(s_axi_hp_dma2_bready),
        .s_axi_hp_dma2_bresp(s_axi_hp_dma2_bresp),
        .s_axi_hp_dma2_bvalid(s_axi_hp_dma2_bvalid),
        .s_axi_hp_dma2_rdata(s_axi_hp_dma2_rdata),
        .s_axi_hp_dma2_rlast(s_axi_hp_dma2_rlast),
        .s_axi_hp_dma2_rready(s_axi_hp_dma2_rready),
        .s_axi_hp_dma2_rresp(s_axi_hp_dma2_rresp),
        .s_axi_hp_dma2_rvalid(s_axi_hp_dma2_rvalid),
        .s_axi_hp_dma2_wdata(s_axi_hp_dma2_wdata),
        .s_axi_hp_dma2_wlast(s_axi_hp_dma2_wlast),
        .s_axi_hp_dma2_wready(s_axi_hp_dma2_wready),
        .s_axi_hp_dma2_wstrb(s_axi_hp_dma2_wstrb),
        .s_axi_hp_dma2_wvalid(s_axi_hp_dma2_wvalid),
        .s_axi_hp_dma3_araddr(s_axi_hp_dma3_araddr),
        .s_axi_hp_dma3_arburst(s_axi_hp_dma3_arburst),
        .s_axi_hp_dma3_arcache(s_axi_hp_dma3_arcache),
        .s_axi_hp_dma3_arlen(s_axi_hp_dma3_arlen),
        .s_axi_hp_dma3_arlock(s_axi_hp_dma3_arlock),
        .s_axi_hp_dma3_arprot(s_axi_hp_dma3_arprot),
        .s_axi_hp_dma3_arqos(s_axi_hp_dma3_arqos),
        .s_axi_hp_dma3_arready(s_axi_hp_dma3_arready),
        .s_axi_hp_dma3_arregion(s_axi_hp_dma3_arregion),
        .s_axi_hp_dma3_arsize(s_axi_hp_dma3_arsize),
        .s_axi_hp_dma3_arvalid(s_axi_hp_dma3_arvalid),
        .s_axi_hp_dma3_awaddr(s_axi_hp_dma3_awaddr),
        .s_axi_hp_dma3_awburst(s_axi_hp_dma3_awburst),
        .s_axi_hp_dma3_awcache(s_axi_hp_dma3_awcache),
        .s_axi_hp_dma3_awlen(s_axi_hp_dma3_awlen),
        .s_axi_hp_dma3_awlock(s_axi_hp_dma3_awlock),
        .s_axi_hp_dma3_awprot(s_axi_hp_dma3_awprot),
        .s_axi_hp_dma3_awqos(s_axi_hp_dma3_awqos),
        .s_axi_hp_dma3_awready(s_axi_hp_dma3_awready),
        .s_axi_hp_dma3_awregion(s_axi_hp_dma3_awregion),
        .s_axi_hp_dma3_awsize(s_axi_hp_dma3_awsize),
        .s_axi_hp_dma3_awvalid(s_axi_hp_dma3_awvalid),
        .s_axi_hp_dma3_bready(s_axi_hp_dma3_bready),
        .s_axi_hp_dma3_bresp(s_axi_hp_dma3_bresp),
        .s_axi_hp_dma3_bvalid(s_axi_hp_dma3_bvalid),
        .s_axi_hp_dma3_rdata(s_axi_hp_dma3_rdata),
        .s_axi_hp_dma3_rlast(s_axi_hp_dma3_rlast),
        .s_axi_hp_dma3_rready(s_axi_hp_dma3_rready),
        .s_axi_hp_dma3_rresp(s_axi_hp_dma3_rresp),
        .s_axi_hp_dma3_rvalid(s_axi_hp_dma3_rvalid),
        .s_axi_hp_dma3_wdata(s_axi_hp_dma3_wdata),
        .s_axi_hp_dma3_wlast(s_axi_hp_dma3_wlast),
        .s_axi_hp_dma3_wready(s_axi_hp_dma3_wready),
        .s_axi_hp_dma3_wstrb(s_axi_hp_dma3_wstrb),
        .s_axi_hp_dma3_wvalid(s_axi_hp_dma3_wvalid));
endmodule
