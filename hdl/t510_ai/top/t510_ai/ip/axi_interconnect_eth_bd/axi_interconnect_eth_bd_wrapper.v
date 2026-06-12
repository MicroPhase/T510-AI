//Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
//--------------------------------------------------------------------------------
//Tool Version: Vivado v.2022.2 (lin64) Build 3671981 Fri Oct 14 04:59:54 MDT 2022
//Date        : Fri Apr 24 15:11:02 2026
//Host        : wcc-B760 running 64-bit Ubuntu 22.04.5 LTS
//Command     : generate_target axi_interconnect_eth_bd_wrapper.bd
//Design      : axi_interconnect_eth_bd_wrapper
//Purpose     : IP block netlist
//--------------------------------------------------------------------------------
`timescale 1 ps / 1 ps

module axi_interconnect_eth_bd_wrapper
   (clk40,
    clk40_rstn,
    m_axi_dma0_araddr,
    m_axi_dma0_arprot,
    m_axi_dma0_arready,
    m_axi_dma0_arvalid,
    m_axi_dma0_awaddr,
    m_axi_dma0_awprot,
    m_axi_dma0_awready,
    m_axi_dma0_awvalid,
    m_axi_dma0_bready,
    m_axi_dma0_bresp,
    m_axi_dma0_bvalid,
    m_axi_dma0_rdata,
    m_axi_dma0_rready,
    m_axi_dma0_rresp,
    m_axi_dma0_rvalid,
    m_axi_dma0_wdata,
    m_axi_dma0_wready,
    m_axi_dma0_wstrb,
    m_axi_dma0_wvalid,
    m_axi_dma1_araddr,
    m_axi_dma1_arprot,
    m_axi_dma1_arready,
    m_axi_dma1_arvalid,
    m_axi_dma1_awaddr,
    m_axi_dma1_awprot,
    m_axi_dma1_awready,
    m_axi_dma1_awvalid,
    m_axi_dma1_bready,
    m_axi_dma1_bresp,
    m_axi_dma1_bvalid,
    m_axi_dma1_rdata,
    m_axi_dma1_rready,
    m_axi_dma1_rresp,
    m_axi_dma1_rvalid,
    m_axi_dma1_wdata,
    m_axi_dma1_wready,
    m_axi_dma1_wstrb,
    m_axi_dma1_wvalid,
    m_axi_dma2_araddr,
    m_axi_dma2_arprot,
    m_axi_dma2_arready,
    m_axi_dma2_arvalid,
    m_axi_dma2_awaddr,
    m_axi_dma2_awprot,
    m_axi_dma2_awready,
    m_axi_dma2_awvalid,
    m_axi_dma2_bready,
    m_axi_dma2_bresp,
    m_axi_dma2_bvalid,
    m_axi_dma2_rdata,
    m_axi_dma2_rready,
    m_axi_dma2_rresp,
    m_axi_dma2_rvalid,
    m_axi_dma2_wdata,
    m_axi_dma2_wready,
    m_axi_dma2_wstrb,
    m_axi_dma2_wvalid,
    m_axi_dma3_araddr,
    m_axi_dma3_arprot,
    m_axi_dma3_arready,
    m_axi_dma3_arvalid,
    m_axi_dma3_awaddr,
    m_axi_dma3_awprot,
    m_axi_dma3_awready,
    m_axi_dma3_awvalid,
    m_axi_dma3_bready,
    m_axi_dma3_bresp,
    m_axi_dma3_bvalid,
    m_axi_dma3_rdata,
    m_axi_dma3_rready,
    m_axi_dma3_rresp,
    m_axi_dma3_rvalid,
    m_axi_dma3_wdata,
    m_axi_dma3_wready,
    m_axi_dma3_wstrb,
    m_axi_dma3_wvalid,
    m_axi_mac0_araddr,
    m_axi_mac0_arprot,
    m_axi_mac0_arready,
    m_axi_mac0_arvalid,
    m_axi_mac0_awaddr,
    m_axi_mac0_awprot,
    m_axi_mac0_awready,
    m_axi_mac0_awvalid,
    m_axi_mac0_bready,
    m_axi_mac0_bresp,
    m_axi_mac0_bvalid,
    m_axi_mac0_rdata,
    m_axi_mac0_rready,
    m_axi_mac0_rresp,
    m_axi_mac0_rvalid,
    m_axi_mac0_wdata,
    m_axi_mac0_wready,
    m_axi_mac0_wstrb,
    m_axi_mac0_wvalid,
    m_axi_mac1_araddr,
    m_axi_mac1_arprot,
    m_axi_mac1_arready,
    m_axi_mac1_arvalid,
    m_axi_mac1_awaddr,
    m_axi_mac1_awprot,
    m_axi_mac1_awready,
    m_axi_mac1_awvalid,
    m_axi_mac1_bready,
    m_axi_mac1_bresp,
    m_axi_mac1_bvalid,
    m_axi_mac1_rdata,
    m_axi_mac1_rready,
    m_axi_mac1_rresp,
    m_axi_mac1_rvalid,
    m_axi_mac1_wdata,
    m_axi_mac1_wready,
    m_axi_mac1_wstrb,
    m_axi_mac1_wvalid,
    m_axi_mac2_araddr,
    m_axi_mac2_arprot,
    m_axi_mac2_arready,
    m_axi_mac2_arvalid,
    m_axi_mac2_awaddr,
    m_axi_mac2_awprot,
    m_axi_mac2_awready,
    m_axi_mac2_awvalid,
    m_axi_mac2_bready,
    m_axi_mac2_bresp,
    m_axi_mac2_bvalid,
    m_axi_mac2_rdata,
    m_axi_mac2_rready,
    m_axi_mac2_rresp,
    m_axi_mac2_rvalid,
    m_axi_mac2_wdata,
    m_axi_mac2_wready,
    m_axi_mac2_wstrb,
    m_axi_mac2_wvalid,
    m_axi_mac3_araddr,
    m_axi_mac3_arprot,
    m_axi_mac3_arready,
    m_axi_mac3_arvalid,
    m_axi_mac3_awaddr,
    m_axi_mac3_awprot,
    m_axi_mac3_awready,
    m_axi_mac3_awvalid,
    m_axi_mac3_bready,
    m_axi_mac3_bresp,
    m_axi_mac3_bvalid,
    m_axi_mac3_rdata,
    m_axi_mac3_rready,
    m_axi_mac3_rresp,
    m_axi_mac3_rvalid,
    m_axi_mac3_wdata,
    m_axi_mac3_wready,
    m_axi_mac3_wstrb,
    m_axi_mac3_wvalid,
    m_axi_misc0_araddr,
    m_axi_misc0_arprot,
    m_axi_misc0_arready,
    m_axi_misc0_arvalid,
    m_axi_misc0_awaddr,
    m_axi_misc0_awprot,
    m_axi_misc0_awready,
    m_axi_misc0_awvalid,
    m_axi_misc0_bready,
    m_axi_misc0_bresp,
    m_axi_misc0_bvalid,
    m_axi_misc0_rdata,
    m_axi_misc0_rready,
    m_axi_misc0_rresp,
    m_axi_misc0_rvalid,
    m_axi_misc0_wdata,
    m_axi_misc0_wready,
    m_axi_misc0_wstrb,
    m_axi_misc0_wvalid,
    m_axi_misc1_araddr,
    m_axi_misc1_arprot,
    m_axi_misc1_arready,
    m_axi_misc1_arvalid,
    m_axi_misc1_awaddr,
    m_axi_misc1_awprot,
    m_axi_misc1_awready,
    m_axi_misc1_awvalid,
    m_axi_misc1_bready,
    m_axi_misc1_bresp,
    m_axi_misc1_bvalid,
    m_axi_misc1_rdata,
    m_axi_misc1_rready,
    m_axi_misc1_rresp,
    m_axi_misc1_rvalid,
    m_axi_misc1_wdata,
    m_axi_misc1_wready,
    m_axi_misc1_wstrb,
    m_axi_misc1_wvalid,
    m_axi_misc2_araddr,
    m_axi_misc2_arprot,
    m_axi_misc2_arready,
    m_axi_misc2_arvalid,
    m_axi_misc2_awaddr,
    m_axi_misc2_awprot,
    m_axi_misc2_awready,
    m_axi_misc2_awvalid,
    m_axi_misc2_bready,
    m_axi_misc2_bresp,
    m_axi_misc2_bvalid,
    m_axi_misc2_rdata,
    m_axi_misc2_rready,
    m_axi_misc2_rresp,
    m_axi_misc2_rvalid,
    m_axi_misc2_wdata,
    m_axi_misc2_wready,
    m_axi_misc2_wstrb,
    m_axi_misc2_wvalid,
    m_axi_misc3_araddr,
    m_axi_misc3_arprot,
    m_axi_misc3_arready,
    m_axi_misc3_arvalid,
    m_axi_misc3_awaddr,
    m_axi_misc3_awprot,
    m_axi_misc3_awready,
    m_axi_misc3_awvalid,
    m_axi_misc3_bready,
    m_axi_misc3_bresp,
    m_axi_misc3_bvalid,
    m_axi_misc3_rdata,
    m_axi_misc3_rready,
    m_axi_misc3_rresp,
    m_axi_misc3_rvalid,
    m_axi_misc3_wdata,
    m_axi_misc3_wready,
    m_axi_misc3_wstrb,
    m_axi_misc3_wvalid,
    s_axi_eth_araddr,
    s_axi_eth_arprot,
    s_axi_eth_arready,
    s_axi_eth_arvalid,
    s_axi_eth_awaddr,
    s_axi_eth_awprot,
    s_axi_eth_awready,
    s_axi_eth_awvalid,
    s_axi_eth_bready,
    s_axi_eth_bresp,
    s_axi_eth_bvalid,
    s_axi_eth_rdata,
    s_axi_eth_rready,
    s_axi_eth_rresp,
    s_axi_eth_rvalid,
    s_axi_eth_wdata,
    s_axi_eth_wready,
    s_axi_eth_wstrb,
    s_axi_eth_wvalid);
  input clk40;
  input clk40_rstn;
  output [39:0]m_axi_dma0_araddr;
  output [2:0]m_axi_dma0_arprot;
  input [0:0]m_axi_dma0_arready;
  output [0:0]m_axi_dma0_arvalid;
  output [39:0]m_axi_dma0_awaddr;
  output [2:0]m_axi_dma0_awprot;
  input [0:0]m_axi_dma0_awready;
  output [0:0]m_axi_dma0_awvalid;
  output [0:0]m_axi_dma0_bready;
  input [1:0]m_axi_dma0_bresp;
  input [0:0]m_axi_dma0_bvalid;
  input [31:0]m_axi_dma0_rdata;
  output [0:0]m_axi_dma0_rready;
  input [1:0]m_axi_dma0_rresp;
  input [0:0]m_axi_dma0_rvalid;
  output [31:0]m_axi_dma0_wdata;
  input [0:0]m_axi_dma0_wready;
  output [3:0]m_axi_dma0_wstrb;
  output [0:0]m_axi_dma0_wvalid;
  output [39:0]m_axi_dma1_araddr;
  output [2:0]m_axi_dma1_arprot;
  input [0:0]m_axi_dma1_arready;
  output [0:0]m_axi_dma1_arvalid;
  output [39:0]m_axi_dma1_awaddr;
  output [2:0]m_axi_dma1_awprot;
  input [0:0]m_axi_dma1_awready;
  output [0:0]m_axi_dma1_awvalid;
  output [0:0]m_axi_dma1_bready;
  input [1:0]m_axi_dma1_bresp;
  input [0:0]m_axi_dma1_bvalid;
  input [31:0]m_axi_dma1_rdata;
  output [0:0]m_axi_dma1_rready;
  input [1:0]m_axi_dma1_rresp;
  input [0:0]m_axi_dma1_rvalid;
  output [31:0]m_axi_dma1_wdata;
  input [0:0]m_axi_dma1_wready;
  output [3:0]m_axi_dma1_wstrb;
  output [0:0]m_axi_dma1_wvalid;
  output [39:0]m_axi_dma2_araddr;
  output [2:0]m_axi_dma2_arprot;
  input [0:0]m_axi_dma2_arready;
  output [0:0]m_axi_dma2_arvalid;
  output [39:0]m_axi_dma2_awaddr;
  output [2:0]m_axi_dma2_awprot;
  input [0:0]m_axi_dma2_awready;
  output [0:0]m_axi_dma2_awvalid;
  output [0:0]m_axi_dma2_bready;
  input [1:0]m_axi_dma2_bresp;
  input [0:0]m_axi_dma2_bvalid;
  input [31:0]m_axi_dma2_rdata;
  output [0:0]m_axi_dma2_rready;
  input [1:0]m_axi_dma2_rresp;
  input [0:0]m_axi_dma2_rvalid;
  output [31:0]m_axi_dma2_wdata;
  input [0:0]m_axi_dma2_wready;
  output [3:0]m_axi_dma2_wstrb;
  output [0:0]m_axi_dma2_wvalid;
  output [39:0]m_axi_dma3_araddr;
  output [2:0]m_axi_dma3_arprot;
  input [0:0]m_axi_dma3_arready;
  output [0:0]m_axi_dma3_arvalid;
  output [39:0]m_axi_dma3_awaddr;
  output [2:0]m_axi_dma3_awprot;
  input [0:0]m_axi_dma3_awready;
  output [0:0]m_axi_dma3_awvalid;
  output [0:0]m_axi_dma3_bready;
  input [1:0]m_axi_dma3_bresp;
  input [0:0]m_axi_dma3_bvalid;
  input [31:0]m_axi_dma3_rdata;
  output [0:0]m_axi_dma3_rready;
  input [1:0]m_axi_dma3_rresp;
  input [0:0]m_axi_dma3_rvalid;
  output [31:0]m_axi_dma3_wdata;
  input [0:0]m_axi_dma3_wready;
  output [3:0]m_axi_dma3_wstrb;
  output [0:0]m_axi_dma3_wvalid;
  output [39:0]m_axi_mac0_araddr;
  output [2:0]m_axi_mac0_arprot;
  input [0:0]m_axi_mac0_arready;
  output [0:0]m_axi_mac0_arvalid;
  output [39:0]m_axi_mac0_awaddr;
  output [2:0]m_axi_mac0_awprot;
  input [0:0]m_axi_mac0_awready;
  output [0:0]m_axi_mac0_awvalid;
  output [0:0]m_axi_mac0_bready;
  input [1:0]m_axi_mac0_bresp;
  input [0:0]m_axi_mac0_bvalid;
  input [31:0]m_axi_mac0_rdata;
  output [0:0]m_axi_mac0_rready;
  input [1:0]m_axi_mac0_rresp;
  input [0:0]m_axi_mac0_rvalid;
  output [31:0]m_axi_mac0_wdata;
  input [0:0]m_axi_mac0_wready;
  output [3:0]m_axi_mac0_wstrb;
  output [0:0]m_axi_mac0_wvalid;
  output [39:0]m_axi_mac1_araddr;
  output [2:0]m_axi_mac1_arprot;
  input [0:0]m_axi_mac1_arready;
  output [0:0]m_axi_mac1_arvalid;
  output [39:0]m_axi_mac1_awaddr;
  output [2:0]m_axi_mac1_awprot;
  input [0:0]m_axi_mac1_awready;
  output [0:0]m_axi_mac1_awvalid;
  output [0:0]m_axi_mac1_bready;
  input [1:0]m_axi_mac1_bresp;
  input [0:0]m_axi_mac1_bvalid;
  input [31:0]m_axi_mac1_rdata;
  output [0:0]m_axi_mac1_rready;
  input [1:0]m_axi_mac1_rresp;
  input [0:0]m_axi_mac1_rvalid;
  output [31:0]m_axi_mac1_wdata;
  input [0:0]m_axi_mac1_wready;
  output [3:0]m_axi_mac1_wstrb;
  output [0:0]m_axi_mac1_wvalid;
  output [39:0]m_axi_mac2_araddr;
  output [2:0]m_axi_mac2_arprot;
  input [0:0]m_axi_mac2_arready;
  output [0:0]m_axi_mac2_arvalid;
  output [39:0]m_axi_mac2_awaddr;
  output [2:0]m_axi_mac2_awprot;
  input [0:0]m_axi_mac2_awready;
  output [0:0]m_axi_mac2_awvalid;
  output [0:0]m_axi_mac2_bready;
  input [1:0]m_axi_mac2_bresp;
  input [0:0]m_axi_mac2_bvalid;
  input [31:0]m_axi_mac2_rdata;
  output [0:0]m_axi_mac2_rready;
  input [1:0]m_axi_mac2_rresp;
  input [0:0]m_axi_mac2_rvalid;
  output [31:0]m_axi_mac2_wdata;
  input [0:0]m_axi_mac2_wready;
  output [3:0]m_axi_mac2_wstrb;
  output [0:0]m_axi_mac2_wvalid;
  output [39:0]m_axi_mac3_araddr;
  output [2:0]m_axi_mac3_arprot;
  input [0:0]m_axi_mac3_arready;
  output [0:0]m_axi_mac3_arvalid;
  output [39:0]m_axi_mac3_awaddr;
  output [2:0]m_axi_mac3_awprot;
  input [0:0]m_axi_mac3_awready;
  output [0:0]m_axi_mac3_awvalid;
  output [0:0]m_axi_mac3_bready;
  input [1:0]m_axi_mac3_bresp;
  input [0:0]m_axi_mac3_bvalid;
  input [31:0]m_axi_mac3_rdata;
  output [0:0]m_axi_mac3_rready;
  input [1:0]m_axi_mac3_rresp;
  input [0:0]m_axi_mac3_rvalid;
  output [31:0]m_axi_mac3_wdata;
  input [0:0]m_axi_mac3_wready;
  output [3:0]m_axi_mac3_wstrb;
  output [0:0]m_axi_mac3_wvalid;
  output [39:0]m_axi_misc0_araddr;
  output [2:0]m_axi_misc0_arprot;
  input [0:0]m_axi_misc0_arready;
  output [0:0]m_axi_misc0_arvalid;
  output [39:0]m_axi_misc0_awaddr;
  output [2:0]m_axi_misc0_awprot;
  input [0:0]m_axi_misc0_awready;
  output [0:0]m_axi_misc0_awvalid;
  output [0:0]m_axi_misc0_bready;
  input [1:0]m_axi_misc0_bresp;
  input [0:0]m_axi_misc0_bvalid;
  input [31:0]m_axi_misc0_rdata;
  output [0:0]m_axi_misc0_rready;
  input [1:0]m_axi_misc0_rresp;
  input [0:0]m_axi_misc0_rvalid;
  output [31:0]m_axi_misc0_wdata;
  input [0:0]m_axi_misc0_wready;
  output [3:0]m_axi_misc0_wstrb;
  output [0:0]m_axi_misc0_wvalid;
  output [39:0]m_axi_misc1_araddr;
  output [2:0]m_axi_misc1_arprot;
  input [0:0]m_axi_misc1_arready;
  output [0:0]m_axi_misc1_arvalid;
  output [39:0]m_axi_misc1_awaddr;
  output [2:0]m_axi_misc1_awprot;
  input [0:0]m_axi_misc1_awready;
  output [0:0]m_axi_misc1_awvalid;
  output [0:0]m_axi_misc1_bready;
  input [1:0]m_axi_misc1_bresp;
  input [0:0]m_axi_misc1_bvalid;
  input [31:0]m_axi_misc1_rdata;
  output [0:0]m_axi_misc1_rready;
  input [1:0]m_axi_misc1_rresp;
  input [0:0]m_axi_misc1_rvalid;
  output [31:0]m_axi_misc1_wdata;
  input [0:0]m_axi_misc1_wready;
  output [3:0]m_axi_misc1_wstrb;
  output [0:0]m_axi_misc1_wvalid;
  output [39:0]m_axi_misc2_araddr;
  output [2:0]m_axi_misc2_arprot;
  input [0:0]m_axi_misc2_arready;
  output [0:0]m_axi_misc2_arvalid;
  output [39:0]m_axi_misc2_awaddr;
  output [2:0]m_axi_misc2_awprot;
  input [0:0]m_axi_misc2_awready;
  output [0:0]m_axi_misc2_awvalid;
  output [0:0]m_axi_misc2_bready;
  input [1:0]m_axi_misc2_bresp;
  input [0:0]m_axi_misc2_bvalid;
  input [31:0]m_axi_misc2_rdata;
  output [0:0]m_axi_misc2_rready;
  input [1:0]m_axi_misc2_rresp;
  input [0:0]m_axi_misc2_rvalid;
  output [31:0]m_axi_misc2_wdata;
  input [0:0]m_axi_misc2_wready;
  output [3:0]m_axi_misc2_wstrb;
  output [0:0]m_axi_misc2_wvalid;
  output [39:0]m_axi_misc3_araddr;
  output [2:0]m_axi_misc3_arprot;
  input [0:0]m_axi_misc3_arready;
  output [0:0]m_axi_misc3_arvalid;
  output [39:0]m_axi_misc3_awaddr;
  output [2:0]m_axi_misc3_awprot;
  input [0:0]m_axi_misc3_awready;
  output [0:0]m_axi_misc3_awvalid;
  output [0:0]m_axi_misc3_bready;
  input [1:0]m_axi_misc3_bresp;
  input [0:0]m_axi_misc3_bvalid;
  input [31:0]m_axi_misc3_rdata;
  output [0:0]m_axi_misc3_rready;
  input [1:0]m_axi_misc3_rresp;
  input [0:0]m_axi_misc3_rvalid;
  output [31:0]m_axi_misc3_wdata;
  input [0:0]m_axi_misc3_wready;
  output [3:0]m_axi_misc3_wstrb;
  output [0:0]m_axi_misc3_wvalid;
  input [39:0]s_axi_eth_araddr;
  input [2:0]s_axi_eth_arprot;
  output [0:0]s_axi_eth_arready;
  input [0:0]s_axi_eth_arvalid;
  input [39:0]s_axi_eth_awaddr;
  input [2:0]s_axi_eth_awprot;
  output [0:0]s_axi_eth_awready;
  input [0:0]s_axi_eth_awvalid;
  input [0:0]s_axi_eth_bready;
  output [1:0]s_axi_eth_bresp;
  output [0:0]s_axi_eth_bvalid;
  output [31:0]s_axi_eth_rdata;
  input [0:0]s_axi_eth_rready;
  output [1:0]s_axi_eth_rresp;
  output [0:0]s_axi_eth_rvalid;
  input [31:0]s_axi_eth_wdata;
  output [0:0]s_axi_eth_wready;
  input [3:0]s_axi_eth_wstrb;
  input [0:0]s_axi_eth_wvalid;

  wire clk40;
  wire clk40_rstn;
  wire [39:0]m_axi_dma0_araddr;
  wire [2:0]m_axi_dma0_arprot;
  wire [0:0]m_axi_dma0_arready;
  wire [0:0]m_axi_dma0_arvalid;
  wire [39:0]m_axi_dma0_awaddr;
  wire [2:0]m_axi_dma0_awprot;
  wire [0:0]m_axi_dma0_awready;
  wire [0:0]m_axi_dma0_awvalid;
  wire [0:0]m_axi_dma0_bready;
  wire [1:0]m_axi_dma0_bresp;
  wire [0:0]m_axi_dma0_bvalid;
  wire [31:0]m_axi_dma0_rdata;
  wire [0:0]m_axi_dma0_rready;
  wire [1:0]m_axi_dma0_rresp;
  wire [0:0]m_axi_dma0_rvalid;
  wire [31:0]m_axi_dma0_wdata;
  wire [0:0]m_axi_dma0_wready;
  wire [3:0]m_axi_dma0_wstrb;
  wire [0:0]m_axi_dma0_wvalid;
  wire [39:0]m_axi_dma1_araddr;
  wire [2:0]m_axi_dma1_arprot;
  wire [0:0]m_axi_dma1_arready;
  wire [0:0]m_axi_dma1_arvalid;
  wire [39:0]m_axi_dma1_awaddr;
  wire [2:0]m_axi_dma1_awprot;
  wire [0:0]m_axi_dma1_awready;
  wire [0:0]m_axi_dma1_awvalid;
  wire [0:0]m_axi_dma1_bready;
  wire [1:0]m_axi_dma1_bresp;
  wire [0:0]m_axi_dma1_bvalid;
  wire [31:0]m_axi_dma1_rdata;
  wire [0:0]m_axi_dma1_rready;
  wire [1:0]m_axi_dma1_rresp;
  wire [0:0]m_axi_dma1_rvalid;
  wire [31:0]m_axi_dma1_wdata;
  wire [0:0]m_axi_dma1_wready;
  wire [3:0]m_axi_dma1_wstrb;
  wire [0:0]m_axi_dma1_wvalid;
  wire [39:0]m_axi_dma2_araddr;
  wire [2:0]m_axi_dma2_arprot;
  wire [0:0]m_axi_dma2_arready;
  wire [0:0]m_axi_dma2_arvalid;
  wire [39:0]m_axi_dma2_awaddr;
  wire [2:0]m_axi_dma2_awprot;
  wire [0:0]m_axi_dma2_awready;
  wire [0:0]m_axi_dma2_awvalid;
  wire [0:0]m_axi_dma2_bready;
  wire [1:0]m_axi_dma2_bresp;
  wire [0:0]m_axi_dma2_bvalid;
  wire [31:0]m_axi_dma2_rdata;
  wire [0:0]m_axi_dma2_rready;
  wire [1:0]m_axi_dma2_rresp;
  wire [0:0]m_axi_dma2_rvalid;
  wire [31:0]m_axi_dma2_wdata;
  wire [0:0]m_axi_dma2_wready;
  wire [3:0]m_axi_dma2_wstrb;
  wire [0:0]m_axi_dma2_wvalid;
  wire [39:0]m_axi_dma3_araddr;
  wire [2:0]m_axi_dma3_arprot;
  wire [0:0]m_axi_dma3_arready;
  wire [0:0]m_axi_dma3_arvalid;
  wire [39:0]m_axi_dma3_awaddr;
  wire [2:0]m_axi_dma3_awprot;
  wire [0:0]m_axi_dma3_awready;
  wire [0:0]m_axi_dma3_awvalid;
  wire [0:0]m_axi_dma3_bready;
  wire [1:0]m_axi_dma3_bresp;
  wire [0:0]m_axi_dma3_bvalid;
  wire [31:0]m_axi_dma3_rdata;
  wire [0:0]m_axi_dma3_rready;
  wire [1:0]m_axi_dma3_rresp;
  wire [0:0]m_axi_dma3_rvalid;
  wire [31:0]m_axi_dma3_wdata;
  wire [0:0]m_axi_dma3_wready;
  wire [3:0]m_axi_dma3_wstrb;
  wire [0:0]m_axi_dma3_wvalid;
  wire [39:0]m_axi_mac0_araddr;
  wire [2:0]m_axi_mac0_arprot;
  wire [0:0]m_axi_mac0_arready;
  wire [0:0]m_axi_mac0_arvalid;
  wire [39:0]m_axi_mac0_awaddr;
  wire [2:0]m_axi_mac0_awprot;
  wire [0:0]m_axi_mac0_awready;
  wire [0:0]m_axi_mac0_awvalid;
  wire [0:0]m_axi_mac0_bready;
  wire [1:0]m_axi_mac0_bresp;
  wire [0:0]m_axi_mac0_bvalid;
  wire [31:0]m_axi_mac0_rdata;
  wire [0:0]m_axi_mac0_rready;
  wire [1:0]m_axi_mac0_rresp;
  wire [0:0]m_axi_mac0_rvalid;
  wire [31:0]m_axi_mac0_wdata;
  wire [0:0]m_axi_mac0_wready;
  wire [3:0]m_axi_mac0_wstrb;
  wire [0:0]m_axi_mac0_wvalid;
  wire [39:0]m_axi_mac1_araddr;
  wire [2:0]m_axi_mac1_arprot;
  wire [0:0]m_axi_mac1_arready;
  wire [0:0]m_axi_mac1_arvalid;
  wire [39:0]m_axi_mac1_awaddr;
  wire [2:0]m_axi_mac1_awprot;
  wire [0:0]m_axi_mac1_awready;
  wire [0:0]m_axi_mac1_awvalid;
  wire [0:0]m_axi_mac1_bready;
  wire [1:0]m_axi_mac1_bresp;
  wire [0:0]m_axi_mac1_bvalid;
  wire [31:0]m_axi_mac1_rdata;
  wire [0:0]m_axi_mac1_rready;
  wire [1:0]m_axi_mac1_rresp;
  wire [0:0]m_axi_mac1_rvalid;
  wire [31:0]m_axi_mac1_wdata;
  wire [0:0]m_axi_mac1_wready;
  wire [3:0]m_axi_mac1_wstrb;
  wire [0:0]m_axi_mac1_wvalid;
  wire [39:0]m_axi_mac2_araddr;
  wire [2:0]m_axi_mac2_arprot;
  wire [0:0]m_axi_mac2_arready;
  wire [0:0]m_axi_mac2_arvalid;
  wire [39:0]m_axi_mac2_awaddr;
  wire [2:0]m_axi_mac2_awprot;
  wire [0:0]m_axi_mac2_awready;
  wire [0:0]m_axi_mac2_awvalid;
  wire [0:0]m_axi_mac2_bready;
  wire [1:0]m_axi_mac2_bresp;
  wire [0:0]m_axi_mac2_bvalid;
  wire [31:0]m_axi_mac2_rdata;
  wire [0:0]m_axi_mac2_rready;
  wire [1:0]m_axi_mac2_rresp;
  wire [0:0]m_axi_mac2_rvalid;
  wire [31:0]m_axi_mac2_wdata;
  wire [0:0]m_axi_mac2_wready;
  wire [3:0]m_axi_mac2_wstrb;
  wire [0:0]m_axi_mac2_wvalid;
  wire [39:0]m_axi_mac3_araddr;
  wire [2:0]m_axi_mac3_arprot;
  wire [0:0]m_axi_mac3_arready;
  wire [0:0]m_axi_mac3_arvalid;
  wire [39:0]m_axi_mac3_awaddr;
  wire [2:0]m_axi_mac3_awprot;
  wire [0:0]m_axi_mac3_awready;
  wire [0:0]m_axi_mac3_awvalid;
  wire [0:0]m_axi_mac3_bready;
  wire [1:0]m_axi_mac3_bresp;
  wire [0:0]m_axi_mac3_bvalid;
  wire [31:0]m_axi_mac3_rdata;
  wire [0:0]m_axi_mac3_rready;
  wire [1:0]m_axi_mac3_rresp;
  wire [0:0]m_axi_mac3_rvalid;
  wire [31:0]m_axi_mac3_wdata;
  wire [0:0]m_axi_mac3_wready;
  wire [3:0]m_axi_mac3_wstrb;
  wire [0:0]m_axi_mac3_wvalid;
  wire [39:0]m_axi_misc0_araddr;
  wire [2:0]m_axi_misc0_arprot;
  wire [0:0]m_axi_misc0_arready;
  wire [0:0]m_axi_misc0_arvalid;
  wire [39:0]m_axi_misc0_awaddr;
  wire [2:0]m_axi_misc0_awprot;
  wire [0:0]m_axi_misc0_awready;
  wire [0:0]m_axi_misc0_awvalid;
  wire [0:0]m_axi_misc0_bready;
  wire [1:0]m_axi_misc0_bresp;
  wire [0:0]m_axi_misc0_bvalid;
  wire [31:0]m_axi_misc0_rdata;
  wire [0:0]m_axi_misc0_rready;
  wire [1:0]m_axi_misc0_rresp;
  wire [0:0]m_axi_misc0_rvalid;
  wire [31:0]m_axi_misc0_wdata;
  wire [0:0]m_axi_misc0_wready;
  wire [3:0]m_axi_misc0_wstrb;
  wire [0:0]m_axi_misc0_wvalid;
  wire [39:0]m_axi_misc1_araddr;
  wire [2:0]m_axi_misc1_arprot;
  wire [0:0]m_axi_misc1_arready;
  wire [0:0]m_axi_misc1_arvalid;
  wire [39:0]m_axi_misc1_awaddr;
  wire [2:0]m_axi_misc1_awprot;
  wire [0:0]m_axi_misc1_awready;
  wire [0:0]m_axi_misc1_awvalid;
  wire [0:0]m_axi_misc1_bready;
  wire [1:0]m_axi_misc1_bresp;
  wire [0:0]m_axi_misc1_bvalid;
  wire [31:0]m_axi_misc1_rdata;
  wire [0:0]m_axi_misc1_rready;
  wire [1:0]m_axi_misc1_rresp;
  wire [0:0]m_axi_misc1_rvalid;
  wire [31:0]m_axi_misc1_wdata;
  wire [0:0]m_axi_misc1_wready;
  wire [3:0]m_axi_misc1_wstrb;
  wire [0:0]m_axi_misc1_wvalid;
  wire [39:0]m_axi_misc2_araddr;
  wire [2:0]m_axi_misc2_arprot;
  wire [0:0]m_axi_misc2_arready;
  wire [0:0]m_axi_misc2_arvalid;
  wire [39:0]m_axi_misc2_awaddr;
  wire [2:0]m_axi_misc2_awprot;
  wire [0:0]m_axi_misc2_awready;
  wire [0:0]m_axi_misc2_awvalid;
  wire [0:0]m_axi_misc2_bready;
  wire [1:0]m_axi_misc2_bresp;
  wire [0:0]m_axi_misc2_bvalid;
  wire [31:0]m_axi_misc2_rdata;
  wire [0:0]m_axi_misc2_rready;
  wire [1:0]m_axi_misc2_rresp;
  wire [0:0]m_axi_misc2_rvalid;
  wire [31:0]m_axi_misc2_wdata;
  wire [0:0]m_axi_misc2_wready;
  wire [3:0]m_axi_misc2_wstrb;
  wire [0:0]m_axi_misc2_wvalid;
  wire [39:0]m_axi_misc3_araddr;
  wire [2:0]m_axi_misc3_arprot;
  wire [0:0]m_axi_misc3_arready;
  wire [0:0]m_axi_misc3_arvalid;
  wire [39:0]m_axi_misc3_awaddr;
  wire [2:0]m_axi_misc3_awprot;
  wire [0:0]m_axi_misc3_awready;
  wire [0:0]m_axi_misc3_awvalid;
  wire [0:0]m_axi_misc3_bready;
  wire [1:0]m_axi_misc3_bresp;
  wire [0:0]m_axi_misc3_bvalid;
  wire [31:0]m_axi_misc3_rdata;
  wire [0:0]m_axi_misc3_rready;
  wire [1:0]m_axi_misc3_rresp;
  wire [0:0]m_axi_misc3_rvalid;
  wire [31:0]m_axi_misc3_wdata;
  wire [0:0]m_axi_misc3_wready;
  wire [3:0]m_axi_misc3_wstrb;
  wire [0:0]m_axi_misc3_wvalid;
  wire [39:0]s_axi_eth_araddr;
  wire [2:0]s_axi_eth_arprot;
  wire [0:0]s_axi_eth_arready;
  wire [0:0]s_axi_eth_arvalid;
  wire [39:0]s_axi_eth_awaddr;
  wire [2:0]s_axi_eth_awprot;
  wire [0:0]s_axi_eth_awready;
  wire [0:0]s_axi_eth_awvalid;
  wire [0:0]s_axi_eth_bready;
  wire [1:0]s_axi_eth_bresp;
  wire [0:0]s_axi_eth_bvalid;
  wire [31:0]s_axi_eth_rdata;
  wire [0:0]s_axi_eth_rready;
  wire [1:0]s_axi_eth_rresp;
  wire [0:0]s_axi_eth_rvalid;
  wire [31:0]s_axi_eth_wdata;
  wire [0:0]s_axi_eth_wready;
  wire [3:0]s_axi_eth_wstrb;
  wire [0:0]s_axi_eth_wvalid;

  axi_interconnect_eth_bd axi_interconnect_eth_bd_i
       (.clk40(clk40),
        .clk40_rstn(clk40_rstn),
        .m_axi_dma0_araddr(m_axi_dma0_araddr),
        .m_axi_dma0_arprot(m_axi_dma0_arprot),
        .m_axi_dma0_arready(m_axi_dma0_arready),
        .m_axi_dma0_arvalid(m_axi_dma0_arvalid),
        .m_axi_dma0_awaddr(m_axi_dma0_awaddr),
        .m_axi_dma0_awprot(m_axi_dma0_awprot),
        .m_axi_dma0_awready(m_axi_dma0_awready),
        .m_axi_dma0_awvalid(m_axi_dma0_awvalid),
        .m_axi_dma0_bready(m_axi_dma0_bready),
        .m_axi_dma0_bresp(m_axi_dma0_bresp),
        .m_axi_dma0_bvalid(m_axi_dma0_bvalid),
        .m_axi_dma0_rdata(m_axi_dma0_rdata),
        .m_axi_dma0_rready(m_axi_dma0_rready),
        .m_axi_dma0_rresp(m_axi_dma0_rresp),
        .m_axi_dma0_rvalid(m_axi_dma0_rvalid),
        .m_axi_dma0_wdata(m_axi_dma0_wdata),
        .m_axi_dma0_wready(m_axi_dma0_wready),
        .m_axi_dma0_wstrb(m_axi_dma0_wstrb),
        .m_axi_dma0_wvalid(m_axi_dma0_wvalid),
        .m_axi_dma1_araddr(m_axi_dma1_araddr),
        .m_axi_dma1_arprot(m_axi_dma1_arprot),
        .m_axi_dma1_arready(m_axi_dma1_arready),
        .m_axi_dma1_arvalid(m_axi_dma1_arvalid),
        .m_axi_dma1_awaddr(m_axi_dma1_awaddr),
        .m_axi_dma1_awprot(m_axi_dma1_awprot),
        .m_axi_dma1_awready(m_axi_dma1_awready),
        .m_axi_dma1_awvalid(m_axi_dma1_awvalid),
        .m_axi_dma1_bready(m_axi_dma1_bready),
        .m_axi_dma1_bresp(m_axi_dma1_bresp),
        .m_axi_dma1_bvalid(m_axi_dma1_bvalid),
        .m_axi_dma1_rdata(m_axi_dma1_rdata),
        .m_axi_dma1_rready(m_axi_dma1_rready),
        .m_axi_dma1_rresp(m_axi_dma1_rresp),
        .m_axi_dma1_rvalid(m_axi_dma1_rvalid),
        .m_axi_dma1_wdata(m_axi_dma1_wdata),
        .m_axi_dma1_wready(m_axi_dma1_wready),
        .m_axi_dma1_wstrb(m_axi_dma1_wstrb),
        .m_axi_dma1_wvalid(m_axi_dma1_wvalid),
        .m_axi_dma2_araddr(m_axi_dma2_araddr),
        .m_axi_dma2_arprot(m_axi_dma2_arprot),
        .m_axi_dma2_arready(m_axi_dma2_arready),
        .m_axi_dma2_arvalid(m_axi_dma2_arvalid),
        .m_axi_dma2_awaddr(m_axi_dma2_awaddr),
        .m_axi_dma2_awprot(m_axi_dma2_awprot),
        .m_axi_dma2_awready(m_axi_dma2_awready),
        .m_axi_dma2_awvalid(m_axi_dma2_awvalid),
        .m_axi_dma2_bready(m_axi_dma2_bready),
        .m_axi_dma2_bresp(m_axi_dma2_bresp),
        .m_axi_dma2_bvalid(m_axi_dma2_bvalid),
        .m_axi_dma2_rdata(m_axi_dma2_rdata),
        .m_axi_dma2_rready(m_axi_dma2_rready),
        .m_axi_dma2_rresp(m_axi_dma2_rresp),
        .m_axi_dma2_rvalid(m_axi_dma2_rvalid),
        .m_axi_dma2_wdata(m_axi_dma2_wdata),
        .m_axi_dma2_wready(m_axi_dma2_wready),
        .m_axi_dma2_wstrb(m_axi_dma2_wstrb),
        .m_axi_dma2_wvalid(m_axi_dma2_wvalid),
        .m_axi_dma3_araddr(m_axi_dma3_araddr),
        .m_axi_dma3_arprot(m_axi_dma3_arprot),
        .m_axi_dma3_arready(m_axi_dma3_arready),
        .m_axi_dma3_arvalid(m_axi_dma3_arvalid),
        .m_axi_dma3_awaddr(m_axi_dma3_awaddr),
        .m_axi_dma3_awprot(m_axi_dma3_awprot),
        .m_axi_dma3_awready(m_axi_dma3_awready),
        .m_axi_dma3_awvalid(m_axi_dma3_awvalid),
        .m_axi_dma3_bready(m_axi_dma3_bready),
        .m_axi_dma3_bresp(m_axi_dma3_bresp),
        .m_axi_dma3_bvalid(m_axi_dma3_bvalid),
        .m_axi_dma3_rdata(m_axi_dma3_rdata),
        .m_axi_dma3_rready(m_axi_dma3_rready),
        .m_axi_dma3_rresp(m_axi_dma3_rresp),
        .m_axi_dma3_rvalid(m_axi_dma3_rvalid),
        .m_axi_dma3_wdata(m_axi_dma3_wdata),
        .m_axi_dma3_wready(m_axi_dma3_wready),
        .m_axi_dma3_wstrb(m_axi_dma3_wstrb),
        .m_axi_dma3_wvalid(m_axi_dma3_wvalid),
        .m_axi_mac0_araddr(m_axi_mac0_araddr),
        .m_axi_mac0_arprot(m_axi_mac0_arprot),
        .m_axi_mac0_arready(m_axi_mac0_arready),
        .m_axi_mac0_arvalid(m_axi_mac0_arvalid),
        .m_axi_mac0_awaddr(m_axi_mac0_awaddr),
        .m_axi_mac0_awprot(m_axi_mac0_awprot),
        .m_axi_mac0_awready(m_axi_mac0_awready),
        .m_axi_mac0_awvalid(m_axi_mac0_awvalid),
        .m_axi_mac0_bready(m_axi_mac0_bready),
        .m_axi_mac0_bresp(m_axi_mac0_bresp),
        .m_axi_mac0_bvalid(m_axi_mac0_bvalid),
        .m_axi_mac0_rdata(m_axi_mac0_rdata),
        .m_axi_mac0_rready(m_axi_mac0_rready),
        .m_axi_mac0_rresp(m_axi_mac0_rresp),
        .m_axi_mac0_rvalid(m_axi_mac0_rvalid),
        .m_axi_mac0_wdata(m_axi_mac0_wdata),
        .m_axi_mac0_wready(m_axi_mac0_wready),
        .m_axi_mac0_wstrb(m_axi_mac0_wstrb),
        .m_axi_mac0_wvalid(m_axi_mac0_wvalid),
        .m_axi_mac1_araddr(m_axi_mac1_araddr),
        .m_axi_mac1_arprot(m_axi_mac1_arprot),
        .m_axi_mac1_arready(m_axi_mac1_arready),
        .m_axi_mac1_arvalid(m_axi_mac1_arvalid),
        .m_axi_mac1_awaddr(m_axi_mac1_awaddr),
        .m_axi_mac1_awprot(m_axi_mac1_awprot),
        .m_axi_mac1_awready(m_axi_mac1_awready),
        .m_axi_mac1_awvalid(m_axi_mac1_awvalid),
        .m_axi_mac1_bready(m_axi_mac1_bready),
        .m_axi_mac1_bresp(m_axi_mac1_bresp),
        .m_axi_mac1_bvalid(m_axi_mac1_bvalid),
        .m_axi_mac1_rdata(m_axi_mac1_rdata),
        .m_axi_mac1_rready(m_axi_mac1_rready),
        .m_axi_mac1_rresp(m_axi_mac1_rresp),
        .m_axi_mac1_rvalid(m_axi_mac1_rvalid),
        .m_axi_mac1_wdata(m_axi_mac1_wdata),
        .m_axi_mac1_wready(m_axi_mac1_wready),
        .m_axi_mac1_wstrb(m_axi_mac1_wstrb),
        .m_axi_mac1_wvalid(m_axi_mac1_wvalid),
        .m_axi_mac2_araddr(m_axi_mac2_araddr),
        .m_axi_mac2_arprot(m_axi_mac2_arprot),
        .m_axi_mac2_arready(m_axi_mac2_arready),
        .m_axi_mac2_arvalid(m_axi_mac2_arvalid),
        .m_axi_mac2_awaddr(m_axi_mac2_awaddr),
        .m_axi_mac2_awprot(m_axi_mac2_awprot),
        .m_axi_mac2_awready(m_axi_mac2_awready),
        .m_axi_mac2_awvalid(m_axi_mac2_awvalid),
        .m_axi_mac2_bready(m_axi_mac2_bready),
        .m_axi_mac2_bresp(m_axi_mac2_bresp),
        .m_axi_mac2_bvalid(m_axi_mac2_bvalid),
        .m_axi_mac2_rdata(m_axi_mac2_rdata),
        .m_axi_mac2_rready(m_axi_mac2_rready),
        .m_axi_mac2_rresp(m_axi_mac2_rresp),
        .m_axi_mac2_rvalid(m_axi_mac2_rvalid),
        .m_axi_mac2_wdata(m_axi_mac2_wdata),
        .m_axi_mac2_wready(m_axi_mac2_wready),
        .m_axi_mac2_wstrb(m_axi_mac2_wstrb),
        .m_axi_mac2_wvalid(m_axi_mac2_wvalid),
        .m_axi_mac3_araddr(m_axi_mac3_araddr),
        .m_axi_mac3_arprot(m_axi_mac3_arprot),
        .m_axi_mac3_arready(m_axi_mac3_arready),
        .m_axi_mac3_arvalid(m_axi_mac3_arvalid),
        .m_axi_mac3_awaddr(m_axi_mac3_awaddr),
        .m_axi_mac3_awprot(m_axi_mac3_awprot),
        .m_axi_mac3_awready(m_axi_mac3_awready),
        .m_axi_mac3_awvalid(m_axi_mac3_awvalid),
        .m_axi_mac3_bready(m_axi_mac3_bready),
        .m_axi_mac3_bresp(m_axi_mac3_bresp),
        .m_axi_mac3_bvalid(m_axi_mac3_bvalid),
        .m_axi_mac3_rdata(m_axi_mac3_rdata),
        .m_axi_mac3_rready(m_axi_mac3_rready),
        .m_axi_mac3_rresp(m_axi_mac3_rresp),
        .m_axi_mac3_rvalid(m_axi_mac3_rvalid),
        .m_axi_mac3_wdata(m_axi_mac3_wdata),
        .m_axi_mac3_wready(m_axi_mac3_wready),
        .m_axi_mac3_wstrb(m_axi_mac3_wstrb),
        .m_axi_mac3_wvalid(m_axi_mac3_wvalid),
        .m_axi_misc0_araddr(m_axi_misc0_araddr),
        .m_axi_misc0_arprot(m_axi_misc0_arprot),
        .m_axi_misc0_arready(m_axi_misc0_arready),
        .m_axi_misc0_arvalid(m_axi_misc0_arvalid),
        .m_axi_misc0_awaddr(m_axi_misc0_awaddr),
        .m_axi_misc0_awprot(m_axi_misc0_awprot),
        .m_axi_misc0_awready(m_axi_misc0_awready),
        .m_axi_misc0_awvalid(m_axi_misc0_awvalid),
        .m_axi_misc0_bready(m_axi_misc0_bready),
        .m_axi_misc0_bresp(m_axi_misc0_bresp),
        .m_axi_misc0_bvalid(m_axi_misc0_bvalid),
        .m_axi_misc0_rdata(m_axi_misc0_rdata),
        .m_axi_misc0_rready(m_axi_misc0_rready),
        .m_axi_misc0_rresp(m_axi_misc0_rresp),
        .m_axi_misc0_rvalid(m_axi_misc0_rvalid),
        .m_axi_misc0_wdata(m_axi_misc0_wdata),
        .m_axi_misc0_wready(m_axi_misc0_wready),
        .m_axi_misc0_wstrb(m_axi_misc0_wstrb),
        .m_axi_misc0_wvalid(m_axi_misc0_wvalid),
        .m_axi_misc1_araddr(m_axi_misc1_araddr),
        .m_axi_misc1_arprot(m_axi_misc1_arprot),
        .m_axi_misc1_arready(m_axi_misc1_arready),
        .m_axi_misc1_arvalid(m_axi_misc1_arvalid),
        .m_axi_misc1_awaddr(m_axi_misc1_awaddr),
        .m_axi_misc1_awprot(m_axi_misc1_awprot),
        .m_axi_misc1_awready(m_axi_misc1_awready),
        .m_axi_misc1_awvalid(m_axi_misc1_awvalid),
        .m_axi_misc1_bready(m_axi_misc1_bready),
        .m_axi_misc1_bresp(m_axi_misc1_bresp),
        .m_axi_misc1_bvalid(m_axi_misc1_bvalid),
        .m_axi_misc1_rdata(m_axi_misc1_rdata),
        .m_axi_misc1_rready(m_axi_misc1_rready),
        .m_axi_misc1_rresp(m_axi_misc1_rresp),
        .m_axi_misc1_rvalid(m_axi_misc1_rvalid),
        .m_axi_misc1_wdata(m_axi_misc1_wdata),
        .m_axi_misc1_wready(m_axi_misc1_wready),
        .m_axi_misc1_wstrb(m_axi_misc1_wstrb),
        .m_axi_misc1_wvalid(m_axi_misc1_wvalid),
        .m_axi_misc2_araddr(m_axi_misc2_araddr),
        .m_axi_misc2_arprot(m_axi_misc2_arprot),
        .m_axi_misc2_arready(m_axi_misc2_arready),
        .m_axi_misc2_arvalid(m_axi_misc2_arvalid),
        .m_axi_misc2_awaddr(m_axi_misc2_awaddr),
        .m_axi_misc2_awprot(m_axi_misc2_awprot),
        .m_axi_misc2_awready(m_axi_misc2_awready),
        .m_axi_misc2_awvalid(m_axi_misc2_awvalid),
        .m_axi_misc2_bready(m_axi_misc2_bready),
        .m_axi_misc2_bresp(m_axi_misc2_bresp),
        .m_axi_misc2_bvalid(m_axi_misc2_bvalid),
        .m_axi_misc2_rdata(m_axi_misc2_rdata),
        .m_axi_misc2_rready(m_axi_misc2_rready),
        .m_axi_misc2_rresp(m_axi_misc2_rresp),
        .m_axi_misc2_rvalid(m_axi_misc2_rvalid),
        .m_axi_misc2_wdata(m_axi_misc2_wdata),
        .m_axi_misc2_wready(m_axi_misc2_wready),
        .m_axi_misc2_wstrb(m_axi_misc2_wstrb),
        .m_axi_misc2_wvalid(m_axi_misc2_wvalid),
        .m_axi_misc3_araddr(m_axi_misc3_araddr),
        .m_axi_misc3_arprot(m_axi_misc3_arprot),
        .m_axi_misc3_arready(m_axi_misc3_arready),
        .m_axi_misc3_arvalid(m_axi_misc3_arvalid),
        .m_axi_misc3_awaddr(m_axi_misc3_awaddr),
        .m_axi_misc3_awprot(m_axi_misc3_awprot),
        .m_axi_misc3_awready(m_axi_misc3_awready),
        .m_axi_misc3_awvalid(m_axi_misc3_awvalid),
        .m_axi_misc3_bready(m_axi_misc3_bready),
        .m_axi_misc3_bresp(m_axi_misc3_bresp),
        .m_axi_misc3_bvalid(m_axi_misc3_bvalid),
        .m_axi_misc3_rdata(m_axi_misc3_rdata),
        .m_axi_misc3_rready(m_axi_misc3_rready),
        .m_axi_misc3_rresp(m_axi_misc3_rresp),
        .m_axi_misc3_rvalid(m_axi_misc3_rvalid),
        .m_axi_misc3_wdata(m_axi_misc3_wdata),
        .m_axi_misc3_wready(m_axi_misc3_wready),
        .m_axi_misc3_wstrb(m_axi_misc3_wstrb),
        .m_axi_misc3_wvalid(m_axi_misc3_wvalid),
        .s_axi_eth_araddr(s_axi_eth_araddr),
        .s_axi_eth_arprot(s_axi_eth_arprot),
        .s_axi_eth_arready(s_axi_eth_arready),
        .s_axi_eth_arvalid(s_axi_eth_arvalid),
        .s_axi_eth_awaddr(s_axi_eth_awaddr),
        .s_axi_eth_awprot(s_axi_eth_awprot),
        .s_axi_eth_awready(s_axi_eth_awready),
        .s_axi_eth_awvalid(s_axi_eth_awvalid),
        .s_axi_eth_bready(s_axi_eth_bready),
        .s_axi_eth_bresp(s_axi_eth_bresp),
        .s_axi_eth_bvalid(s_axi_eth_bvalid),
        .s_axi_eth_rdata(s_axi_eth_rdata),
        .s_axi_eth_rready(s_axi_eth_rready),
        .s_axi_eth_rresp(s_axi_eth_rresp),
        .s_axi_eth_rvalid(s_axi_eth_rvalid),
        .s_axi_eth_wdata(s_axi_eth_wdata),
        .s_axi_eth_wready(s_axi_eth_wready),
        .s_axi_eth_wstrb(s_axi_eth_wstrb),
        .s_axi_eth_wvalid(s_axi_eth_wvalid));
endmodule
