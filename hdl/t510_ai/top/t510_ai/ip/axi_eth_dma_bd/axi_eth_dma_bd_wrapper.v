//Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
//--------------------------------------------------------------------------------
//Tool Version: Vivado v.2022.2 (lin64) Build 3671981 Fri Oct 14 04:59:54 MDT 2022
//Date        : Fri Apr 24 15:10:59 2026
//Host        : wcc-B760 running 64-bit Ubuntu 22.04.5 LTS
//Command     : generate_target axi_eth_dma_bd_wrapper.bd
//Design      : axi_eth_dma_bd_wrapper
//Purpose     : IP block netlist
//--------------------------------------------------------------------------------
`timescale 1 ps / 1 ps

module axi_eth_dma_bd_wrapper
   (axi_eth_dma_araddr,
    axi_eth_dma_arready,
    axi_eth_dma_arvalid,
    axi_eth_dma_awaddr,
    axi_eth_dma_awready,
    axi_eth_dma_awvalid,
    axi_eth_dma_bready,
    axi_eth_dma_bresp,
    axi_eth_dma_bvalid,
    axi_eth_dma_rdata,
    axi_eth_dma_rready,
    axi_eth_dma_rresp,
    axi_eth_dma_rvalid,
    axi_eth_dma_wdata,
    axi_eth_dma_wready,
    axi_eth_dma_wvalid,
    axi_hp_araddr,
    axi_hp_arburst,
    axi_hp_arcache,
    axi_hp_arlen,
    axi_hp_arlock,
    axi_hp_arprot,
    axi_hp_arqos,
    axi_hp_arready,
    axi_hp_arsize,
    axi_hp_arvalid,
    axi_hp_awaddr,
    axi_hp_awburst,
    axi_hp_awcache,
    axi_hp_awlen,
    axi_hp_awlock,
    axi_hp_awprot,
    axi_hp_awqos,
    axi_hp_awready,
    axi_hp_awsize,
    axi_hp_awvalid,
    axi_hp_bready,
    axi_hp_bresp,
    axi_hp_bvalid,
    axi_hp_rdata,
    axi_hp_rlast,
    axi_hp_rready,
    axi_hp_rresp,
    axi_hp_rvalid,
    axi_hp_wdata,
    axi_hp_wlast,
    axi_hp_wready,
    axi_hp_wstrb,
    axi_hp_wvalid,
    c2e_tdata,
    c2e_tkeep,
    c2e_tlast,
    c2e_tready,
    c2e_tvalid,
    clk40,
    clk40_rstn,
    e2c_tdata,
    e2c_tkeep,
    e2c_tlast,
    e2c_tready,
    e2c_tvalid,
    eth_rx_irq,
    eth_tx_irq);
  input [9:0]axi_eth_dma_araddr;
  output axi_eth_dma_arready;
  input axi_eth_dma_arvalid;
  input [9:0]axi_eth_dma_awaddr;
  output axi_eth_dma_awready;
  input axi_eth_dma_awvalid;
  input axi_eth_dma_bready;
  output [1:0]axi_eth_dma_bresp;
  output axi_eth_dma_bvalid;
  output [31:0]axi_eth_dma_rdata;
  input axi_eth_dma_rready;
  output [1:0]axi_eth_dma_rresp;
  output axi_eth_dma_rvalid;
  input [31:0]axi_eth_dma_wdata;
  output axi_eth_dma_wready;
  input axi_eth_dma_wvalid;
  output [48:0]axi_hp_araddr;
  output [1:0]axi_hp_arburst;
  output [3:0]axi_hp_arcache;
  output [7:0]axi_hp_arlen;
  output [0:0]axi_hp_arlock;
  output [2:0]axi_hp_arprot;
  output [3:0]axi_hp_arqos;
  input axi_hp_arready;
  output [2:0]axi_hp_arsize;
  output axi_hp_arvalid;
  output [48:0]axi_hp_awaddr;
  output [1:0]axi_hp_awburst;
  output [3:0]axi_hp_awcache;
  output [7:0]axi_hp_awlen;
  output [0:0]axi_hp_awlock;
  output [2:0]axi_hp_awprot;
  output [3:0]axi_hp_awqos;
  input axi_hp_awready;
  output [2:0]axi_hp_awsize;
  output axi_hp_awvalid;
  output axi_hp_bready;
  input [1:0]axi_hp_bresp;
  input axi_hp_bvalid;
  input [127:0]axi_hp_rdata;
  input axi_hp_rlast;
  output axi_hp_rready;
  input [1:0]axi_hp_rresp;
  input axi_hp_rvalid;
  output [127:0]axi_hp_wdata;
  output axi_hp_wlast;
  input axi_hp_wready;
  output [15:0]axi_hp_wstrb;
  output axi_hp_wvalid;
  output [63:0]c2e_tdata;
  output [7:0]c2e_tkeep;
  output c2e_tlast;
  input c2e_tready;
  output c2e_tvalid;
  input clk40;
  input clk40_rstn;
  input [63:0]e2c_tdata;
  input [7:0]e2c_tkeep;
  input e2c_tlast;
  output e2c_tready;
  input e2c_tvalid;
  output eth_rx_irq;
  output eth_tx_irq;

  wire [9:0]axi_eth_dma_araddr;
  wire axi_eth_dma_arready;
  wire axi_eth_dma_arvalid;
  wire [9:0]axi_eth_dma_awaddr;
  wire axi_eth_dma_awready;
  wire axi_eth_dma_awvalid;
  wire axi_eth_dma_bready;
  wire [1:0]axi_eth_dma_bresp;
  wire axi_eth_dma_bvalid;
  wire [31:0]axi_eth_dma_rdata;
  wire axi_eth_dma_rready;
  wire [1:0]axi_eth_dma_rresp;
  wire axi_eth_dma_rvalid;
  wire [31:0]axi_eth_dma_wdata;
  wire axi_eth_dma_wready;
  wire axi_eth_dma_wvalid;
  wire [48:0]axi_hp_araddr;
  wire [1:0]axi_hp_arburst;
  wire [3:0]axi_hp_arcache;
  wire [7:0]axi_hp_arlen;
  wire [0:0]axi_hp_arlock;
  wire [2:0]axi_hp_arprot;
  wire [3:0]axi_hp_arqos;
  wire axi_hp_arready;
  wire [2:0]axi_hp_arsize;
  wire axi_hp_arvalid;
  wire [48:0]axi_hp_awaddr;
  wire [1:0]axi_hp_awburst;
  wire [3:0]axi_hp_awcache;
  wire [7:0]axi_hp_awlen;
  wire [0:0]axi_hp_awlock;
  wire [2:0]axi_hp_awprot;
  wire [3:0]axi_hp_awqos;
  wire axi_hp_awready;
  wire [2:0]axi_hp_awsize;
  wire axi_hp_awvalid;
  wire axi_hp_bready;
  wire [1:0]axi_hp_bresp;
  wire axi_hp_bvalid;
  wire [127:0]axi_hp_rdata;
  wire axi_hp_rlast;
  wire axi_hp_rready;
  wire [1:0]axi_hp_rresp;
  wire axi_hp_rvalid;
  wire [127:0]axi_hp_wdata;
  wire axi_hp_wlast;
  wire axi_hp_wready;
  wire [15:0]axi_hp_wstrb;
  wire axi_hp_wvalid;
  wire [63:0]c2e_tdata;
  wire [7:0]c2e_tkeep;
  wire c2e_tlast;
  wire c2e_tready;
  wire c2e_tvalid;
  wire clk40;
  wire clk40_rstn;
  wire [63:0]e2c_tdata;
  wire [7:0]e2c_tkeep;
  wire e2c_tlast;
  wire e2c_tready;
  wire e2c_tvalid;
  wire eth_rx_irq;
  wire eth_tx_irq;

  axi_eth_dma_bd axi_eth_dma_bd_i
       (.axi_eth_dma_araddr(axi_eth_dma_araddr),
        .axi_eth_dma_arready(axi_eth_dma_arready),
        .axi_eth_dma_arvalid(axi_eth_dma_arvalid),
        .axi_eth_dma_awaddr(axi_eth_dma_awaddr),
        .axi_eth_dma_awready(axi_eth_dma_awready),
        .axi_eth_dma_awvalid(axi_eth_dma_awvalid),
        .axi_eth_dma_bready(axi_eth_dma_bready),
        .axi_eth_dma_bresp(axi_eth_dma_bresp),
        .axi_eth_dma_bvalid(axi_eth_dma_bvalid),
        .axi_eth_dma_rdata(axi_eth_dma_rdata),
        .axi_eth_dma_rready(axi_eth_dma_rready),
        .axi_eth_dma_rresp(axi_eth_dma_rresp),
        .axi_eth_dma_rvalid(axi_eth_dma_rvalid),
        .axi_eth_dma_wdata(axi_eth_dma_wdata),
        .axi_eth_dma_wready(axi_eth_dma_wready),
        .axi_eth_dma_wvalid(axi_eth_dma_wvalid),
        .axi_hp_araddr(axi_hp_araddr),
        .axi_hp_arburst(axi_hp_arburst),
        .axi_hp_arcache(axi_hp_arcache),
        .axi_hp_arlen(axi_hp_arlen),
        .axi_hp_arlock(axi_hp_arlock),
        .axi_hp_arprot(axi_hp_arprot),
        .axi_hp_arqos(axi_hp_arqos),
        .axi_hp_arready(axi_hp_arready),
        .axi_hp_arsize(axi_hp_arsize),
        .axi_hp_arvalid(axi_hp_arvalid),
        .axi_hp_awaddr(axi_hp_awaddr),
        .axi_hp_awburst(axi_hp_awburst),
        .axi_hp_awcache(axi_hp_awcache),
        .axi_hp_awlen(axi_hp_awlen),
        .axi_hp_awlock(axi_hp_awlock),
        .axi_hp_awprot(axi_hp_awprot),
        .axi_hp_awqos(axi_hp_awqos),
        .axi_hp_awready(axi_hp_awready),
        .axi_hp_awsize(axi_hp_awsize),
        .axi_hp_awvalid(axi_hp_awvalid),
        .axi_hp_bready(axi_hp_bready),
        .axi_hp_bresp(axi_hp_bresp),
        .axi_hp_bvalid(axi_hp_bvalid),
        .axi_hp_rdata(axi_hp_rdata),
        .axi_hp_rlast(axi_hp_rlast),
        .axi_hp_rready(axi_hp_rready),
        .axi_hp_rresp(axi_hp_rresp),
        .axi_hp_rvalid(axi_hp_rvalid),
        .axi_hp_wdata(axi_hp_wdata),
        .axi_hp_wlast(axi_hp_wlast),
        .axi_hp_wready(axi_hp_wready),
        .axi_hp_wstrb(axi_hp_wstrb),
        .axi_hp_wvalid(axi_hp_wvalid),
        .c2e_tdata(c2e_tdata),
        .c2e_tkeep(c2e_tkeep),
        .c2e_tlast(c2e_tlast),
        .c2e_tready(c2e_tready),
        .c2e_tvalid(c2e_tvalid),
        .clk40(clk40),
        .clk40_rstn(clk40_rstn),
        .e2c_tdata(e2c_tdata),
        .e2c_tkeep(e2c_tkeep),
        .e2c_tlast(e2c_tlast),
        .e2c_tready(e2c_tready),
        .e2c_tvalid(e2c_tvalid),
        .eth_rx_irq(eth_rx_irq),
        .eth_tx_irq(eth_tx_irq));
endmodule
