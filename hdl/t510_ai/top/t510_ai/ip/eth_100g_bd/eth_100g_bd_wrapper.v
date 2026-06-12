//Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
//--------------------------------------------------------------------------------
//Tool Version: Vivado v.2022.2 (lin64) Build 3671981 Fri Oct 14 04:59:54 MDT 2022
//Date        : Fri Apr 24 15:10:53 2026
//Host        : wcc-B760 running 64-bit Ubuntu 22.04.5 LTS
//Command     : generate_target eth_100g_bd_wrapper.bd
//Design      : eth_100g_bd_wrapper
//Purpose     : IP block netlist
//--------------------------------------------------------------------------------
`timescale 1 ps / 1 ps

module eth_100g_bd_wrapper
   (core_drp_daddr,
    core_drp_den,
    core_drp_di,
    core_drp_do,
    core_drp_drdy,
    core_drp_dwe,
    core_rx_reset,
    core_tx_reset,
    ctl_tx_pause_req,
    ctl_tx_resend_pause,
    drp_clk,
    eth100g_rx_lbus_seg0_data,
    eth100g_rx_lbus_seg0_ena,
    eth100g_rx_lbus_seg0_eop,
    eth100g_rx_lbus_seg0_err,
    eth100g_rx_lbus_seg0_mty,
    eth100g_rx_lbus_seg0_sop,
    eth100g_rx_lbus_seg1_data,
    eth100g_rx_lbus_seg1_ena,
    eth100g_rx_lbus_seg1_eop,
    eth100g_rx_lbus_seg1_err,
    eth100g_rx_lbus_seg1_mty,
    eth100g_rx_lbus_seg1_sop,
    eth100g_rx_lbus_seg2_data,
    eth100g_rx_lbus_seg2_ena,
    eth100g_rx_lbus_seg2_eop,
    eth100g_rx_lbus_seg2_err,
    eth100g_rx_lbus_seg2_mty,
    eth100g_rx_lbus_seg2_sop,
    eth100g_rx_lbus_seg3_data,
    eth100g_rx_lbus_seg3_ena,
    eth100g_rx_lbus_seg3_eop,
    eth100g_rx_lbus_seg3_err,
    eth100g_rx_lbus_seg3_mty,
    eth100g_rx_lbus_seg3_sop,
    eth100g_tx_lbus_seg0_data,
    eth100g_tx_lbus_seg0_ena,
    eth100g_tx_lbus_seg0_eop,
    eth100g_tx_lbus_seg0_err,
    eth100g_tx_lbus_seg0_mty,
    eth100g_tx_lbus_seg0_sop,
    eth100g_tx_lbus_seg1_data,
    eth100g_tx_lbus_seg1_ena,
    eth100g_tx_lbus_seg1_eop,
    eth100g_tx_lbus_seg1_err,
    eth100g_tx_lbus_seg1_mty,
    eth100g_tx_lbus_seg1_sop,
    eth100g_tx_lbus_seg2_data,
    eth100g_tx_lbus_seg2_ena,
    eth100g_tx_lbus_seg2_eop,
    eth100g_tx_lbus_seg2_err,
    eth100g_tx_lbus_seg2_mty,
    eth100g_tx_lbus_seg2_sop,
    eth100g_tx_lbus_seg3_data,
    eth100g_tx_lbus_seg3_ena,
    eth100g_tx_lbus_seg3_eop,
    eth100g_tx_lbus_seg3_err,
    eth100g_tx_lbus_seg3_mty,
    eth100g_tx_lbus_seg3_sop,
    eth100g_tx_tx_rdyout,
    gt_powergoodout,
    gt_txusrclk2,
    gtwiz_reset_rx_datapath,
    gtwiz_reset_tx_datapath,
    init_clk,
    pm_tick,
    refclk_clk_n,
    refclk_clk_p,
    rx_clk,
    rx_n,
    rx_p,
    s_axi_aclk,
    s_axi_araddr,
    s_axi_arready,
    s_axi_arvalid,
    s_axi_awaddr,
    s_axi_awready,
    s_axi_awvalid,
    s_axi_bready,
    s_axi_bresp,
    s_axi_bvalid,
    s_axi_rdata,
    s_axi_rready,
    s_axi_rresp,
    s_axi_rvalid,
    s_axi_sreset,
    s_axi_wdata,
    s_axi_wready,
    s_axi_wstrb,
    s_axi_wvalid,
    stat_rx_aligned,
    stat_rx_aligned_err,
    stat_rx_bip_err_0_0,
    stat_rx_bip_err_10_0,
    stat_rx_bip_err_11_0,
    stat_rx_bip_err_12_0,
    stat_rx_bip_err_13_0,
    stat_rx_bip_err_14_0,
    stat_rx_bip_err_15_0,
    stat_rx_bip_err_16_0,
    stat_rx_bip_err_17_0,
    stat_rx_bip_err_18_0,
    stat_rx_bip_err_19_0,
    stat_rx_bip_err_1_0,
    stat_rx_bip_err_2_0,
    stat_rx_bip_err_3_0,
    stat_rx_bip_err_4_0,
    stat_rx_bip_err_5_0,
    stat_rx_bip_err_6_0,
    stat_rx_bip_err_7_0,
    stat_rx_bip_err_8_0,
    stat_rx_bip_err_9_0,
    stat_rx_block_lock,
    stat_rx_hi_ber,
    stat_rx_misaligned,
    stat_rx_pause_req,
    stat_rx_pcsl_number_0_0,
    stat_rx_pcsl_number_10_0,
    stat_rx_pcsl_number_11_0,
    stat_rx_pcsl_number_12_0,
    stat_rx_pcsl_number_13_0,
    stat_rx_pcsl_number_14_0,
    stat_rx_pcsl_number_15_0,
    stat_rx_pcsl_number_16_0,
    stat_rx_pcsl_number_17_0,
    stat_rx_pcsl_number_18_0,
    stat_rx_pcsl_number_19_0,
    stat_rx_pcsl_number_1_0,
    stat_rx_pcsl_number_2_0,
    stat_rx_pcsl_number_3_0,
    stat_rx_pcsl_number_4_0,
    stat_rx_pcsl_number_5_0,
    stat_rx_pcsl_number_6_0,
    stat_rx_pcsl_number_7_0,
    stat_rx_pcsl_number_8_0,
    stat_rx_pcsl_number_9_0,
    stat_rx_synced,
    stat_rx_synced_err,
    sys_reset,
    tx_n,
    tx_ovfout,
    tx_p,
    tx_unfout,
    usr_rx_reset,
    usr_tx_reset);
  input [9:0]core_drp_daddr;
  input core_drp_den;
  input [15:0]core_drp_di;
  output [15:0]core_drp_do;
  output core_drp_drdy;
  input core_drp_dwe;
  input core_rx_reset;
  input core_tx_reset;
  input [8:0]ctl_tx_pause_req;
  input ctl_tx_resend_pause;
  input drp_clk;
  output [127:0]eth100g_rx_lbus_seg0_data;
  output eth100g_rx_lbus_seg0_ena;
  output eth100g_rx_lbus_seg0_eop;
  output eth100g_rx_lbus_seg0_err;
  output [3:0]eth100g_rx_lbus_seg0_mty;
  output eth100g_rx_lbus_seg0_sop;
  output [127:0]eth100g_rx_lbus_seg1_data;
  output eth100g_rx_lbus_seg1_ena;
  output eth100g_rx_lbus_seg1_eop;
  output eth100g_rx_lbus_seg1_err;
  output [3:0]eth100g_rx_lbus_seg1_mty;
  output eth100g_rx_lbus_seg1_sop;
  output [127:0]eth100g_rx_lbus_seg2_data;
  output eth100g_rx_lbus_seg2_ena;
  output eth100g_rx_lbus_seg2_eop;
  output eth100g_rx_lbus_seg2_err;
  output [3:0]eth100g_rx_lbus_seg2_mty;
  output eth100g_rx_lbus_seg2_sop;
  output [127:0]eth100g_rx_lbus_seg3_data;
  output eth100g_rx_lbus_seg3_ena;
  output eth100g_rx_lbus_seg3_eop;
  output eth100g_rx_lbus_seg3_err;
  output [3:0]eth100g_rx_lbus_seg3_mty;
  output eth100g_rx_lbus_seg3_sop;
  input [127:0]eth100g_tx_lbus_seg0_data;
  input eth100g_tx_lbus_seg0_ena;
  input eth100g_tx_lbus_seg0_eop;
  input eth100g_tx_lbus_seg0_err;
  input [3:0]eth100g_tx_lbus_seg0_mty;
  input eth100g_tx_lbus_seg0_sop;
  input [127:0]eth100g_tx_lbus_seg1_data;
  input eth100g_tx_lbus_seg1_ena;
  input eth100g_tx_lbus_seg1_eop;
  input eth100g_tx_lbus_seg1_err;
  input [3:0]eth100g_tx_lbus_seg1_mty;
  input eth100g_tx_lbus_seg1_sop;
  input [127:0]eth100g_tx_lbus_seg2_data;
  input eth100g_tx_lbus_seg2_ena;
  input eth100g_tx_lbus_seg2_eop;
  input eth100g_tx_lbus_seg2_err;
  input [3:0]eth100g_tx_lbus_seg2_mty;
  input eth100g_tx_lbus_seg2_sop;
  input [127:0]eth100g_tx_lbus_seg3_data;
  input eth100g_tx_lbus_seg3_ena;
  input eth100g_tx_lbus_seg3_eop;
  input eth100g_tx_lbus_seg3_err;
  input [3:0]eth100g_tx_lbus_seg3_mty;
  input eth100g_tx_lbus_seg3_sop;
  output eth100g_tx_tx_rdyout;
  output [3:0]gt_powergoodout;
  output gt_txusrclk2;
  input gtwiz_reset_rx_datapath;
  input gtwiz_reset_tx_datapath;
  input init_clk;
  input pm_tick;
  input refclk_clk_n;
  input refclk_clk_p;
  input rx_clk;
  input [3:0]rx_n;
  input [3:0]rx_p;
  input s_axi_aclk;
  input [31:0]s_axi_araddr;
  output s_axi_arready;
  input s_axi_arvalid;
  input [31:0]s_axi_awaddr;
  output s_axi_awready;
  input s_axi_awvalid;
  input s_axi_bready;
  output [1:0]s_axi_bresp;
  output s_axi_bvalid;
  output [31:0]s_axi_rdata;
  input s_axi_rready;
  output [1:0]s_axi_rresp;
  output s_axi_rvalid;
  input s_axi_sreset;
  input [31:0]s_axi_wdata;
  output s_axi_wready;
  input [3:0]s_axi_wstrb;
  input s_axi_wvalid;
  output stat_rx_aligned;
  output stat_rx_aligned_err;
  output stat_rx_bip_err_0_0;
  output stat_rx_bip_err_10_0;
  output stat_rx_bip_err_11_0;
  output stat_rx_bip_err_12_0;
  output stat_rx_bip_err_13_0;
  output stat_rx_bip_err_14_0;
  output stat_rx_bip_err_15_0;
  output stat_rx_bip_err_16_0;
  output stat_rx_bip_err_17_0;
  output stat_rx_bip_err_18_0;
  output stat_rx_bip_err_19_0;
  output stat_rx_bip_err_1_0;
  output stat_rx_bip_err_2_0;
  output stat_rx_bip_err_3_0;
  output stat_rx_bip_err_4_0;
  output stat_rx_bip_err_5_0;
  output stat_rx_bip_err_6_0;
  output stat_rx_bip_err_7_0;
  output stat_rx_bip_err_8_0;
  output stat_rx_bip_err_9_0;
  output [19:0]stat_rx_block_lock;
  output stat_rx_hi_ber;
  output stat_rx_misaligned;
  output [8:0]stat_rx_pause_req;
  output [4:0]stat_rx_pcsl_number_0_0;
  output [4:0]stat_rx_pcsl_number_10_0;
  output [4:0]stat_rx_pcsl_number_11_0;
  output [4:0]stat_rx_pcsl_number_12_0;
  output [4:0]stat_rx_pcsl_number_13_0;
  output [4:0]stat_rx_pcsl_number_14_0;
  output [4:0]stat_rx_pcsl_number_15_0;
  output [4:0]stat_rx_pcsl_number_16_0;
  output [4:0]stat_rx_pcsl_number_17_0;
  output [4:0]stat_rx_pcsl_number_18_0;
  output [4:0]stat_rx_pcsl_number_19_0;
  output [4:0]stat_rx_pcsl_number_1_0;
  output [4:0]stat_rx_pcsl_number_2_0;
  output [4:0]stat_rx_pcsl_number_3_0;
  output [4:0]stat_rx_pcsl_number_4_0;
  output [4:0]stat_rx_pcsl_number_5_0;
  output [4:0]stat_rx_pcsl_number_6_0;
  output [4:0]stat_rx_pcsl_number_7_0;
  output [4:0]stat_rx_pcsl_number_8_0;
  output [4:0]stat_rx_pcsl_number_9_0;
  output [19:0]stat_rx_synced;
  output [19:0]stat_rx_synced_err;
  input sys_reset;
  output [3:0]tx_n;
  output tx_ovfout;
  output [3:0]tx_p;
  output tx_unfout;
  output usr_rx_reset;
  output usr_tx_reset;

  wire [9:0]core_drp_daddr;
  wire core_drp_den;
  wire [15:0]core_drp_di;
  wire [15:0]core_drp_do;
  wire core_drp_drdy;
  wire core_drp_dwe;
  wire core_rx_reset;
  wire core_tx_reset;
  wire [8:0]ctl_tx_pause_req;
  wire ctl_tx_resend_pause;
  wire drp_clk;
  wire [127:0]eth100g_rx_lbus_seg0_data;
  wire eth100g_rx_lbus_seg0_ena;
  wire eth100g_rx_lbus_seg0_eop;
  wire eth100g_rx_lbus_seg0_err;
  wire [3:0]eth100g_rx_lbus_seg0_mty;
  wire eth100g_rx_lbus_seg0_sop;
  wire [127:0]eth100g_rx_lbus_seg1_data;
  wire eth100g_rx_lbus_seg1_ena;
  wire eth100g_rx_lbus_seg1_eop;
  wire eth100g_rx_lbus_seg1_err;
  wire [3:0]eth100g_rx_lbus_seg1_mty;
  wire eth100g_rx_lbus_seg1_sop;
  wire [127:0]eth100g_rx_lbus_seg2_data;
  wire eth100g_rx_lbus_seg2_ena;
  wire eth100g_rx_lbus_seg2_eop;
  wire eth100g_rx_lbus_seg2_err;
  wire [3:0]eth100g_rx_lbus_seg2_mty;
  wire eth100g_rx_lbus_seg2_sop;
  wire [127:0]eth100g_rx_lbus_seg3_data;
  wire eth100g_rx_lbus_seg3_ena;
  wire eth100g_rx_lbus_seg3_eop;
  wire eth100g_rx_lbus_seg3_err;
  wire [3:0]eth100g_rx_lbus_seg3_mty;
  wire eth100g_rx_lbus_seg3_sop;
  wire [127:0]eth100g_tx_lbus_seg0_data;
  wire eth100g_tx_lbus_seg0_ena;
  wire eth100g_tx_lbus_seg0_eop;
  wire eth100g_tx_lbus_seg0_err;
  wire [3:0]eth100g_tx_lbus_seg0_mty;
  wire eth100g_tx_lbus_seg0_sop;
  wire [127:0]eth100g_tx_lbus_seg1_data;
  wire eth100g_tx_lbus_seg1_ena;
  wire eth100g_tx_lbus_seg1_eop;
  wire eth100g_tx_lbus_seg1_err;
  wire [3:0]eth100g_tx_lbus_seg1_mty;
  wire eth100g_tx_lbus_seg1_sop;
  wire [127:0]eth100g_tx_lbus_seg2_data;
  wire eth100g_tx_lbus_seg2_ena;
  wire eth100g_tx_lbus_seg2_eop;
  wire eth100g_tx_lbus_seg2_err;
  wire [3:0]eth100g_tx_lbus_seg2_mty;
  wire eth100g_tx_lbus_seg2_sop;
  wire [127:0]eth100g_tx_lbus_seg3_data;
  wire eth100g_tx_lbus_seg3_ena;
  wire eth100g_tx_lbus_seg3_eop;
  wire eth100g_tx_lbus_seg3_err;
  wire [3:0]eth100g_tx_lbus_seg3_mty;
  wire eth100g_tx_lbus_seg3_sop;
  wire eth100g_tx_tx_rdyout;
  wire [3:0]gt_powergoodout;
  wire gt_txusrclk2;
  wire gtwiz_reset_rx_datapath;
  wire gtwiz_reset_tx_datapath;
  wire init_clk;
  wire pm_tick;
  wire refclk_clk_n;
  wire refclk_clk_p;
  wire rx_clk;
  wire [3:0]rx_n;
  wire [3:0]rx_p;
  wire s_axi_aclk;
  wire [31:0]s_axi_araddr;
  wire s_axi_arready;
  wire s_axi_arvalid;
  wire [31:0]s_axi_awaddr;
  wire s_axi_awready;
  wire s_axi_awvalid;
  wire s_axi_bready;
  wire [1:0]s_axi_bresp;
  wire s_axi_bvalid;
  wire [31:0]s_axi_rdata;
  wire s_axi_rready;
  wire [1:0]s_axi_rresp;
  wire s_axi_rvalid;
  wire s_axi_sreset;
  wire [31:0]s_axi_wdata;
  wire s_axi_wready;
  wire [3:0]s_axi_wstrb;
  wire s_axi_wvalid;
  wire stat_rx_aligned;
  wire stat_rx_aligned_err;
  wire stat_rx_bip_err_0_0;
  wire stat_rx_bip_err_10_0;
  wire stat_rx_bip_err_11_0;
  wire stat_rx_bip_err_12_0;
  wire stat_rx_bip_err_13_0;
  wire stat_rx_bip_err_14_0;
  wire stat_rx_bip_err_15_0;
  wire stat_rx_bip_err_16_0;
  wire stat_rx_bip_err_17_0;
  wire stat_rx_bip_err_18_0;
  wire stat_rx_bip_err_19_0;
  wire stat_rx_bip_err_1_0;
  wire stat_rx_bip_err_2_0;
  wire stat_rx_bip_err_3_0;
  wire stat_rx_bip_err_4_0;
  wire stat_rx_bip_err_5_0;
  wire stat_rx_bip_err_6_0;
  wire stat_rx_bip_err_7_0;
  wire stat_rx_bip_err_8_0;
  wire stat_rx_bip_err_9_0;
  wire [19:0]stat_rx_block_lock;
  wire stat_rx_hi_ber;
  wire stat_rx_misaligned;
  wire [8:0]stat_rx_pause_req;
  wire [4:0]stat_rx_pcsl_number_0_0;
  wire [4:0]stat_rx_pcsl_number_10_0;
  wire [4:0]stat_rx_pcsl_number_11_0;
  wire [4:0]stat_rx_pcsl_number_12_0;
  wire [4:0]stat_rx_pcsl_number_13_0;
  wire [4:0]stat_rx_pcsl_number_14_0;
  wire [4:0]stat_rx_pcsl_number_15_0;
  wire [4:0]stat_rx_pcsl_number_16_0;
  wire [4:0]stat_rx_pcsl_number_17_0;
  wire [4:0]stat_rx_pcsl_number_18_0;
  wire [4:0]stat_rx_pcsl_number_19_0;
  wire [4:0]stat_rx_pcsl_number_1_0;
  wire [4:0]stat_rx_pcsl_number_2_0;
  wire [4:0]stat_rx_pcsl_number_3_0;
  wire [4:0]stat_rx_pcsl_number_4_0;
  wire [4:0]stat_rx_pcsl_number_5_0;
  wire [4:0]stat_rx_pcsl_number_6_0;
  wire [4:0]stat_rx_pcsl_number_7_0;
  wire [4:0]stat_rx_pcsl_number_8_0;
  wire [4:0]stat_rx_pcsl_number_9_0;
  wire [19:0]stat_rx_synced;
  wire [19:0]stat_rx_synced_err;
  wire sys_reset;
  wire [3:0]tx_n;
  wire tx_ovfout;
  wire [3:0]tx_p;
  wire tx_unfout;
  wire usr_rx_reset;
  wire usr_tx_reset;

  eth_100g_bd eth_100g_bd_i
       (.core_drp_daddr(core_drp_daddr),
        .core_drp_den(core_drp_den),
        .core_drp_di(core_drp_di),
        .core_drp_do(core_drp_do),
        .core_drp_drdy(core_drp_drdy),
        .core_drp_dwe(core_drp_dwe),
        .core_rx_reset(core_rx_reset),
        .core_tx_reset(core_tx_reset),
        .ctl_tx_pause_req(ctl_tx_pause_req),
        .ctl_tx_resend_pause(ctl_tx_resend_pause),
        .drp_clk(drp_clk),
        .eth100g_rx_lbus_seg0_data(eth100g_rx_lbus_seg0_data),
        .eth100g_rx_lbus_seg0_ena(eth100g_rx_lbus_seg0_ena),
        .eth100g_rx_lbus_seg0_eop(eth100g_rx_lbus_seg0_eop),
        .eth100g_rx_lbus_seg0_err(eth100g_rx_lbus_seg0_err),
        .eth100g_rx_lbus_seg0_mty(eth100g_rx_lbus_seg0_mty),
        .eth100g_rx_lbus_seg0_sop(eth100g_rx_lbus_seg0_sop),
        .eth100g_rx_lbus_seg1_data(eth100g_rx_lbus_seg1_data),
        .eth100g_rx_lbus_seg1_ena(eth100g_rx_lbus_seg1_ena),
        .eth100g_rx_lbus_seg1_eop(eth100g_rx_lbus_seg1_eop),
        .eth100g_rx_lbus_seg1_err(eth100g_rx_lbus_seg1_err),
        .eth100g_rx_lbus_seg1_mty(eth100g_rx_lbus_seg1_mty),
        .eth100g_rx_lbus_seg1_sop(eth100g_rx_lbus_seg1_sop),
        .eth100g_rx_lbus_seg2_data(eth100g_rx_lbus_seg2_data),
        .eth100g_rx_lbus_seg2_ena(eth100g_rx_lbus_seg2_ena),
        .eth100g_rx_lbus_seg2_eop(eth100g_rx_lbus_seg2_eop),
        .eth100g_rx_lbus_seg2_err(eth100g_rx_lbus_seg2_err),
        .eth100g_rx_lbus_seg2_mty(eth100g_rx_lbus_seg2_mty),
        .eth100g_rx_lbus_seg2_sop(eth100g_rx_lbus_seg2_sop),
        .eth100g_rx_lbus_seg3_data(eth100g_rx_lbus_seg3_data),
        .eth100g_rx_lbus_seg3_ena(eth100g_rx_lbus_seg3_ena),
        .eth100g_rx_lbus_seg3_eop(eth100g_rx_lbus_seg3_eop),
        .eth100g_rx_lbus_seg3_err(eth100g_rx_lbus_seg3_err),
        .eth100g_rx_lbus_seg3_mty(eth100g_rx_lbus_seg3_mty),
        .eth100g_rx_lbus_seg3_sop(eth100g_rx_lbus_seg3_sop),
        .eth100g_tx_lbus_seg0_data(eth100g_tx_lbus_seg0_data),
        .eth100g_tx_lbus_seg0_ena(eth100g_tx_lbus_seg0_ena),
        .eth100g_tx_lbus_seg0_eop(eth100g_tx_lbus_seg0_eop),
        .eth100g_tx_lbus_seg0_err(eth100g_tx_lbus_seg0_err),
        .eth100g_tx_lbus_seg0_mty(eth100g_tx_lbus_seg0_mty),
        .eth100g_tx_lbus_seg0_sop(eth100g_tx_lbus_seg0_sop),
        .eth100g_tx_lbus_seg1_data(eth100g_tx_lbus_seg1_data),
        .eth100g_tx_lbus_seg1_ena(eth100g_tx_lbus_seg1_ena),
        .eth100g_tx_lbus_seg1_eop(eth100g_tx_lbus_seg1_eop),
        .eth100g_tx_lbus_seg1_err(eth100g_tx_lbus_seg1_err),
        .eth100g_tx_lbus_seg1_mty(eth100g_tx_lbus_seg1_mty),
        .eth100g_tx_lbus_seg1_sop(eth100g_tx_lbus_seg1_sop),
        .eth100g_tx_lbus_seg2_data(eth100g_tx_lbus_seg2_data),
        .eth100g_tx_lbus_seg2_ena(eth100g_tx_lbus_seg2_ena),
        .eth100g_tx_lbus_seg2_eop(eth100g_tx_lbus_seg2_eop),
        .eth100g_tx_lbus_seg2_err(eth100g_tx_lbus_seg2_err),
        .eth100g_tx_lbus_seg2_mty(eth100g_tx_lbus_seg2_mty),
        .eth100g_tx_lbus_seg2_sop(eth100g_tx_lbus_seg2_sop),
        .eth100g_tx_lbus_seg3_data(eth100g_tx_lbus_seg3_data),
        .eth100g_tx_lbus_seg3_ena(eth100g_tx_lbus_seg3_ena),
        .eth100g_tx_lbus_seg3_eop(eth100g_tx_lbus_seg3_eop),
        .eth100g_tx_lbus_seg3_err(eth100g_tx_lbus_seg3_err),
        .eth100g_tx_lbus_seg3_mty(eth100g_tx_lbus_seg3_mty),
        .eth100g_tx_lbus_seg3_sop(eth100g_tx_lbus_seg3_sop),
        .eth100g_tx_tx_rdyout(eth100g_tx_tx_rdyout),
        .gt_powergoodout(gt_powergoodout),
        .gt_txusrclk2(gt_txusrclk2),
        .gtwiz_reset_rx_datapath(gtwiz_reset_rx_datapath),
        .gtwiz_reset_tx_datapath(gtwiz_reset_tx_datapath),
        .init_clk(init_clk),
        .pm_tick(pm_tick),
        .refclk_clk_n(refclk_clk_n),
        .refclk_clk_p(refclk_clk_p),
        .rx_clk(rx_clk),
        .rx_n(rx_n),
        .rx_p(rx_p),
        .s_axi_aclk(s_axi_aclk),
        .s_axi_araddr(s_axi_araddr),
        .s_axi_arready(s_axi_arready),
        .s_axi_arvalid(s_axi_arvalid),
        .s_axi_awaddr(s_axi_awaddr),
        .s_axi_awready(s_axi_awready),
        .s_axi_awvalid(s_axi_awvalid),
        .s_axi_bready(s_axi_bready),
        .s_axi_bresp(s_axi_bresp),
        .s_axi_bvalid(s_axi_bvalid),
        .s_axi_rdata(s_axi_rdata),
        .s_axi_rready(s_axi_rready),
        .s_axi_rresp(s_axi_rresp),
        .s_axi_rvalid(s_axi_rvalid),
        .s_axi_sreset(s_axi_sreset),
        .s_axi_wdata(s_axi_wdata),
        .s_axi_wready(s_axi_wready),
        .s_axi_wstrb(s_axi_wstrb),
        .s_axi_wvalid(s_axi_wvalid),
        .stat_rx_aligned(stat_rx_aligned),
        .stat_rx_aligned_err(stat_rx_aligned_err),
        .stat_rx_bip_err_0_0(stat_rx_bip_err_0_0),
        .stat_rx_bip_err_10_0(stat_rx_bip_err_10_0),
        .stat_rx_bip_err_11_0(stat_rx_bip_err_11_0),
        .stat_rx_bip_err_12_0(stat_rx_bip_err_12_0),
        .stat_rx_bip_err_13_0(stat_rx_bip_err_13_0),
        .stat_rx_bip_err_14_0(stat_rx_bip_err_14_0),
        .stat_rx_bip_err_15_0(stat_rx_bip_err_15_0),
        .stat_rx_bip_err_16_0(stat_rx_bip_err_16_0),
        .stat_rx_bip_err_17_0(stat_rx_bip_err_17_0),
        .stat_rx_bip_err_18_0(stat_rx_bip_err_18_0),
        .stat_rx_bip_err_19_0(stat_rx_bip_err_19_0),
        .stat_rx_bip_err_1_0(stat_rx_bip_err_1_0),
        .stat_rx_bip_err_2_0(stat_rx_bip_err_2_0),
        .stat_rx_bip_err_3_0(stat_rx_bip_err_3_0),
        .stat_rx_bip_err_4_0(stat_rx_bip_err_4_0),
        .stat_rx_bip_err_5_0(stat_rx_bip_err_5_0),
        .stat_rx_bip_err_6_0(stat_rx_bip_err_6_0),
        .stat_rx_bip_err_7_0(stat_rx_bip_err_7_0),
        .stat_rx_bip_err_8_0(stat_rx_bip_err_8_0),
        .stat_rx_bip_err_9_0(stat_rx_bip_err_9_0),
        .stat_rx_block_lock(stat_rx_block_lock),
        .stat_rx_hi_ber(stat_rx_hi_ber),
        .stat_rx_misaligned(stat_rx_misaligned),
        .stat_rx_pause_req(stat_rx_pause_req),
        .stat_rx_pcsl_number_0_0(stat_rx_pcsl_number_0_0),
        .stat_rx_pcsl_number_10_0(stat_rx_pcsl_number_10_0),
        .stat_rx_pcsl_number_11_0(stat_rx_pcsl_number_11_0),
        .stat_rx_pcsl_number_12_0(stat_rx_pcsl_number_12_0),
        .stat_rx_pcsl_number_13_0(stat_rx_pcsl_number_13_0),
        .stat_rx_pcsl_number_14_0(stat_rx_pcsl_number_14_0),
        .stat_rx_pcsl_number_15_0(stat_rx_pcsl_number_15_0),
        .stat_rx_pcsl_number_16_0(stat_rx_pcsl_number_16_0),
        .stat_rx_pcsl_number_17_0(stat_rx_pcsl_number_17_0),
        .stat_rx_pcsl_number_18_0(stat_rx_pcsl_number_18_0),
        .stat_rx_pcsl_number_19_0(stat_rx_pcsl_number_19_0),
        .stat_rx_pcsl_number_1_0(stat_rx_pcsl_number_1_0),
        .stat_rx_pcsl_number_2_0(stat_rx_pcsl_number_2_0),
        .stat_rx_pcsl_number_3_0(stat_rx_pcsl_number_3_0),
        .stat_rx_pcsl_number_4_0(stat_rx_pcsl_number_4_0),
        .stat_rx_pcsl_number_5_0(stat_rx_pcsl_number_5_0),
        .stat_rx_pcsl_number_6_0(stat_rx_pcsl_number_6_0),
        .stat_rx_pcsl_number_7_0(stat_rx_pcsl_number_7_0),
        .stat_rx_pcsl_number_8_0(stat_rx_pcsl_number_8_0),
        .stat_rx_pcsl_number_9_0(stat_rx_pcsl_number_9_0),
        .stat_rx_synced(stat_rx_synced),
        .stat_rx_synced_err(stat_rx_synced_err),
        .sys_reset(sys_reset),
        .tx_n(tx_n),
        .tx_ovfout(tx_ovfout),
        .tx_p(tx_p),
        .tx_unfout(tx_unfout),
        .usr_rx_reset(usr_rx_reset),
        .usr_tx_reset(usr_tx_reset));
endmodule
