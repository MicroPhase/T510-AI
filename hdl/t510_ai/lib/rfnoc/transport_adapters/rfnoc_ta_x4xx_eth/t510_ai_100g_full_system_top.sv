//
// Copyright 2026
//
// SPDX-License-Identifier: LGPL-3.0-or-later
//
// Module: t510_ai_100g_full_system_top
//
// Description:
//
//   Standalone top-level system for T510-AI 100GbE reuse. This module combines:
//
//   - a minimal Zynq UltraScale+ MPSoC block design wrapper
//   - the exported T510-AI 100GbE transport wrapper
//
//   The PS block drives:
//
//   - AXI-Lite register access into the 100GbE logic
//   - AXI HP/HPC memory access for DMA into PS DDR
//   - PL clocks and reset
//   - PL interrupts back into the PS
//
`default_nettype none

module t510_ai_100g_full_system_top #(
  parameter        CHDR_W     = 512,
  parameter        NET_CHDR_W = CHDR_W,
  parameter        BYTE_MTU   = $clog2(8*1024),
  parameter [ 7:0] QSFP_NUM   = 8'd0,
  parameter        NODE_INST  = 0,
  parameter [15:0] PROTOVER   = {8'd1, 8'd0}
) (
  // RFDC clocks and analog IO
  input   wire            adc_clk_clk_n   ,
  input   wire            adc_clk_clk_p   ,
  input   wire            dac_clk_clk_n   ,
  input   wire            dac_clk_clk_p   ,

  input   wire            sysref_in_diff_n,
  input   wire            sysref_in_diff_p,

  input   wire            user_clk_p      ,
  input   wire            user_clk_n      ,
  input   wire            pl_sysref_in_p  ,
  input   wire            pl_sysref_in_n  , 
  output  wire            sysref_req      ,
  inout   wire            i2c_scl_io      ,
  inout   wire            i2c_sda_io      ,
  output  wire            i2c_rst_n       ,

  input   wire            rx_ch0_v_n      ,
  input   wire            rx_ch0_v_p      ,
  input   wire            rx_ch1_v_n      ,
  input   wire            rx_ch1_v_p      ,

  // input   wire            rx_ch2_v_n      ,
  // input   wire            rx_ch2_v_p      ,
  // input   wire            rx_ch3_v_n      ,
  // input   wire            rx_ch3_v_p      ,

  // input   wire            rx_ch4_v_n      ,
  // input   wire            rx_ch4_v_p      ,
  // input   wire            rx_ch5_v_n      ,
  // input   wire            rx_ch5_v_p      ,

  // input   wire            rx_ch6_v_n      ,
  // input   wire            rx_ch6_v_p      ,
  // input   wire            rx_ch7_v_n      ,
  // input   wire            rx_ch7_v_p      ,


  output   wire            tx_ch0_v_n      ,
  output   wire            tx_ch0_v_p      ,
  output   wire            tx_ch1_v_n      ,
  output   wire            tx_ch1_v_p      ,

  // output   wire            tx_ch2_v_n      ,
  // output   wire            tx_ch2_v_p      ,
  // output   wire            tx_ch3_v_n      ,
  // output   wire            tx_ch3_v_p      ,

  // output   wire            tx_ch4_v_n      ,
  // output   wire            tx_ch4_v_p      ,
  // output   wire            tx_ch5_v_n      ,
  // output   wire            tx_ch5_v_p      ,

  // output   wire            tx_ch6_v_n      ,
  // output   wire            tx_ch6_v_p      ,
  // output   wire            tx_ch7_v_n      ,
  // output   wire            tx_ch7_v_p      ,


  // QSFP reference clock and serial IO
  input  wire  refclk_p,
  input  wire  refclk_n,
  input  wire  qsfp0_modprs_n,
  output wire  qsfp0_reset_n,
  output wire  qsfp0_lpmode_n,
  (* DONT_TOUCH = "TRUE", KEEP = "TRUE" *)
  output wire [3:0] tx_p,
  output wire [3:0] tx_n,
  input  wire [3:0] rx_p,
  input  wire [3:0] rx_n,

  // Device info and status
  // input  wire  [ 15:0] device_id,
  // output wire          recovered_clk,

  // output wire [127:0] port_info,
  output wire             qsfp_link_up,
  output wire             qsfp_activity

  // Lane-0 FPGA-side stream

);

  wire        pl_clk40;
  wire        pl_clk100;
  wire        pl_clk200;
  wire        pl_resetn0;
  // wire [7:0]  pl_ps_irq0;

  wire [48:0] axi_araddr;
  wire [ 1:0] axi_arburst;
  wire [ 3:0] axi_arcache;
  wire [ 7:0] axi_arlen;
  wire [ 0:0] axi_arlock;
  wire [ 2:0] axi_arprot;
  wire [ 3:0] axi_arqos;
  wire        axi_arready;
  wire [ 2:0] axi_arsize;
  wire        axi_arvalid;
  wire [48:0] axi_awaddr;
  wire [ 1:0] axi_awburst;
  wire [ 3:0] axi_awcache;
  wire [ 7:0] axi_awlen;
  wire [ 0:0] axi_awlock;
  wire [ 2:0] axi_awprot;
  wire [ 3:0] axi_awqos;
  wire        axi_awready;
  wire [ 2:0] axi_awsize;
  wire        axi_awvalid;
  wire        axi_bready;
  wire [ 1:0] axi_bresp;
  wire        axi_bvalid;
  wire [127:0] axi_rdata;
  wire        axi_rlast;
  wire        axi_rready;
  wire [ 1:0] axi_rresp;
  wire        axi_rvalid;
  wire [127:0] axi_wdata;
  wire        axi_wlast;
  wire        axi_wready;
  wire [15:0] axi_wstrb;
  wire        axi_wvalid;

  wire [  3:0] eth_rx_irq;
  wire [  3:0] eth_tx_irq;
  wire [  3:0] link_up  ;
  wire [  3:0] activity ;

  wire [39:0] eth_axil_awaddr;
  wire        eth_axil_awvalid;
  wire        eth_axil_awready;
  wire [31:0] eth_axil_wdata;
  wire [ 3:0] eth_axil_wstrb;
  wire        eth_axil_wvalid;
  wire        eth_axil_wready;
  wire [ 1:0] eth_axil_bresp;
  wire        eth_axil_bvalid;
  wire        eth_axil_bready;
  wire [39:0] eth_axil_araddr;
  wire        eth_axil_arvalid;
  wire        eth_axil_arready;
  wire [31:0] eth_axil_rdata;
  wire [ 1:0] eth_axil_rresp;
  wire        eth_axil_rvalid;
  wire        eth_axil_rready;

  wire [39:0] ctrl_axil_awaddr;
  wire        ctrl_axil_awvalid;
  wire        ctrl_axil_awready;
  wire [31:0] ctrl_axil_wdata;
  wire [ 3:0] ctrl_axil_wstrb;
  wire        ctrl_axil_wvalid;
  wire        ctrl_axil_wready;
  wire [ 1:0] ctrl_axil_bresp;
  wire        ctrl_axil_bvalid;
  wire        ctrl_axil_bready;
  wire [39:0] ctrl_axil_araddr;
  wire        ctrl_axil_arvalid;
  wire        ctrl_axil_arready;
  wire [31:0] ctrl_axil_rdata;
  wire [ 1:0] ctrl_axil_rresp;
  wire        ctrl_axil_rvalid;
  wire        ctrl_axil_rready;

  wire [CHDR_W-1:0] e2v_tdata;
  wire              e2v_tlast;
  wire              e2v_tvalid;
  wire              e2v_tready;

  wire [CHDR_W-1:0] v2e_tdata ;
  wire              v2e_tlast ;
  wire              v2e_tvalid;
  wire              v2e_tready;

  localparam logic [15:0] TEST_SINK_EPID        = 16'h4000;
  localparam logic [15:0] TEST_SOURCE_CTRL_EPID = 16'h4001;
  localparam logic [15:0] IQ_CAPTURE_DST_EPID   = 16'h4002;
  localparam logic [15:0] TEST_RETURN_EPID      = 16'h1234;

  wire [94:0]gpio_i;
  wire [94:0]gpio_o;
  wire [94:0]gpio_t;

  wire core_arst = ~pl_resetn0;
  wire ctrl_rst;
  wire chdr_rst;
  wire axil_rst  = ctrl_rst;
  wire axi_rst   = ctrl_rst;
  assign qsfp_link_up = link_up[0];
  assign qsfp_activity = activity[0];
  assign i2c_rst_n = ~ctrl_rst;


  wire [15:0] m_adc_i0_tdata;
   wire        m_adc_i0_tready;
  wire        m_adc_i0_tvalid;
  wire [15:0] m_adc_q0_tdata;
   wire        m_adc_q0_tready;
  wire        m_adc_q0_tvalid;
  wire [15:0] m_adc_i1_tdata;
   wire        m_adc_i1_tready;
  wire        m_adc_i1_tvalid;
  wire [15:0] m_adc_q1_tdata;
   wire        m_adc_q1_tready;
  wire        m_adc_q1_tvalid;
   wire [31:0] s_dac_ch0_tdata;
  wire        s_dac_ch0_tready;
   wire        s_dac_ch0_tvalid;
   wire [31:0] s_dac_ch1_tdata;
  wire        s_dac_ch1_tready;
   wire        s_dac_ch1_tvalid;

  wire [63:0] vita_time;
  wire [63:0] vita_time_last_pps;
  wire        get_current_vita_time;
  wire        get_lastpps_vita_time;
  wire [63:0] set_vita_timestamp;
  wire [ 2:0] set_time_mode;
  wire        time_mode_strobe;
  wire [63:0] tx_timestamp;
  wire [31:0] rx_sample_bytes;
  wire [31:0] max_sample_bytes_per_packet;
  wire        capture_one_block;
  wire [63:0] rx_sync_timestamp;
  wire        rx_sync_timestamp_strobe;
  wire [ 1:0] rx_mode;
  wire        rx_mode_strobe;
  wire        mode_exit;
  wire        stream_start;
  wire [ 7:0] channel_enable;
  wire [15:0] dma_s2mm_pkt_per_burst;
  wire        axi_dma_rst_n;
  wire [31:0] tx_samples_per_packet;
  wire [ 2:0] tx_source_sel;
  wire        ignore_tx_timestamps;
  wire [15:0] noise_idx_start;
  wire [15:0] noise_idx_end;
  wire        noise_cfg_update;
  wire [31:0] tx_dds_freq_ctrl_word;
  wire [31:0] fc_window;
  wire        sync_in;
  wire [31:0] test_bytes_len;
  wire        test_rx_start;
  wire        dma1_test_rx_start;
  wire        enable_xfft;
  wire        enable_overlap;
  wire [31:0] fft_len;
  wire        fft_len_update;

  wire [15:0] ch0_dac_i;
  wire [15:0] ch0_dac_q;
  wire        ch0_dac_valid;
  wire [15:0] ch1_dac_i;
  wire [15:0] ch1_dac_q;
  wire        ch1_dac_valid;

  wire [63:0] iq_user_bus_rx_tdata;
  wire [ 7:0] iq_user_bus_rx_tkeep;
  wire        iq_user_bus_rx_tlast;
  wire        iq_user_bus_rx_tready;
  wire        iq_user_bus_rx_tvalid;
  wire [63:0] legacy_iq_user_bus_rx_tdata;
  wire [ 7:0] legacy_iq_user_bus_rx_tkeep;
  wire        legacy_iq_user_bus_rx_tlast;
  wire        legacy_iq_user_bus_rx_tready;
  wire        legacy_iq_user_bus_rx_tvalid;
  wire [63:0] iq_user_bus_tx_tdata;
  wire [ 7:0] iq_user_bus_tx_tkeep;
  wire        iq_user_bus_tx_tlast;
  wire        iq_user_bus_tx_tready;
  wire        iq_user_bus_tx_tvalid;
  wire        iq_path_capture_idle_v2;
  wire        iq_path_stop_done_v2;

   wire            radio_rx_clk        ;
    wire            radio_rx_rst_n      ;
    wire            radio_tx_clk        ;
    wire            radio_tx_rst_n      ;
    wire            radio_rst           ;

   wire            user_clk            ;
    wire            user_clk_ibuf       ;
    wire            pl_sysref           ;
    reg             pl_sysref_r         ;
    reg             pl_sysref_r1        ;
wire            user_sysref_adc     ;
    wire            user_sysref_dac     ;
  // assign pl_ps_irq0 = {eth_tx_irq, eth_rx_irq};

  assign m_adc_i0_tready = 1'b1;
  assign m_adc_q0_tready = 1'b1;
  assign m_adc_i1_tready = 1'b1;
  assign m_adc_q1_tready = 1'b1;
  assign s_dac_ch0_tdata = {ch0_dac_q, ch0_dac_i};
  assign s_dac_ch0_tvalid = ch0_dac_valid;
  assign s_dac_ch1_tdata = {ch1_dac_q, ch1_dac_i};
  assign s_dac_ch1_tvalid = ch1_dac_valid;
  assign iq_user_bus_tx_tdata = 64'd0;
  assign iq_user_bus_tx_tkeep = 8'd0;
  assign iq_user_bus_tx_tlast = 1'b0;
  assign iq_user_bus_tx_tvalid = 1'b0;

  reset_sync reset_sync_clk40_i (
    .clk       (pl_clk40),
    .reset_in  (core_arst),
    .reset_out (ctrl_rst)
  );

  reset_sync reset_sync_clk200_i (
    .clk       (pl_clk200),
    .reset_in  (core_arst),
    .reset_out (chdr_rst)
  );

  IBUFDS user_clk_i (
    .I          (user_clk_p),
    .IB         (user_clk_n),
    .O          (user_clk_ibuf));

    BUFG BUFG_inst (
        .O(user_clk), // 1-bit output: Clock output.
        .I(user_clk_ibuf)  // 1-bit input: Clock input.
     );

    IBUFDS pl_sysref_i (
    .I          (pl_sysref_in_p),
    .IB         (pl_sysref_in_n),
    .O          (pl_sysref));

  reset_sync reset_sync_radio_i (
    .clk       (user_clk),
    .reset_in  (core_arst),
    .reset_out (radio_rst)
  );

  assign gpio_i = {95{1'b1}};
  assign sysref_req = gpio_o[0];

  chdr_epid_loopback #(
    .CHDR_W          (CHDR_W),
    .SINK_DST_EPID   (TEST_SINK_EPID),
    .CTRL_DST_EPID   (TEST_SOURCE_CTRL_EPID),
    .IQ_CAPTURE_DST_EPID (IQ_CAPTURE_DST_EPID),
    .RETURN_DST_EPID (TEST_RETURN_EPID)
  ) chdr_epid_loopback_i (
    .clk           (pl_clk200),
    .rst           (chdr_rst),
    .s_axis_tdata  (e2v_tdata),
    .s_axis_tlast  (e2v_tlast),
    .s_axis_tvalid (e2v_tvalid),
    .s_axis_tready (e2v_tready),
    .iq_s_axis_tdata  (iq_user_bus_rx_tdata),
    .iq_s_axis_tkeep  (iq_user_bus_rx_tkeep),
    .iq_s_axis_tlast  (iq_user_bus_rx_tlast),
    .iq_s_axis_tvalid (iq_user_bus_rx_tvalid),
    .iq_s_axis_tready (iq_user_bus_rx_tready),
    .iq_clear         (mode_exit),
    .m_axis_tdata  (v2e_tdata),
    .m_axis_tlast  (v2e_tlast),
    .m_axis_tvalid (v2e_tvalid),
    .m_axis_tready (v2e_tready)
  );
    
    
    always @(posedge user_clk) begin
        pl_sysref_r <= pl_sysref;
        pl_sysref_r1 <= pl_sysref_r;
    end

    assign user_sysref_adc = pl_sysref_r1;
    assign user_sysref_dac = pl_sysref_r1;

    assign radio_rx_clk = user_clk;
    assign radio_tx_clk = user_clk;
    assign radio_rx_rst_n = ~radio_rst;
    assign radio_tx_rst_n = ~radio_rst;
    // assign bus_clk = user_clk;

  axi_center_control axi_center_control_i (
    .get_current_vita_time      (get_current_vita_time),
    .get_lastpps_vita_time      (get_lastpps_vita_time),
    .vita_time                  (vita_time),
    .vita_time_last_pps         (vita_time_last_pps),
    .set_vita_timestamp         (set_vita_timestamp),
    .set_time_mode              (set_time_mode),
    .time_mode_strobe           (time_mode_strobe),
    .tx_timestamp               (tx_timestamp),
    .rx_sample_bytes            (rx_sample_bytes),
    .max_sample_bytes_per_packet(max_sample_bytes_per_packet),
    .capture_one_block          (capture_one_block),
    .rx_sync_timestamp          (rx_sync_timestamp),
    .rx_sync_timestamp_strobe   (rx_sync_timestamp_strobe),
    .rx_mode                    (rx_mode),
    .rx_mode_strobe             (rx_mode_strobe),
    .mode_exit                  (mode_exit),
    .stream_start               (stream_start),
    .channel_enable             (channel_enable),
    .dma_s2mm_pkt_per_burst     (dma_s2mm_pkt_per_burst),
    .axi_dma_rst_n              (axi_dma_rst_n),
    .tx_samples_per_packet      (tx_samples_per_packet),
    .tx_source_sel              (tx_source_sel),
    .ignore_tx_timestamps       (ignore_tx_timestamps),
    .noise_idx_start            (noise_idx_start),
    .noise_idx_end              (noise_idx_end),
    .noise_cfg_update           (noise_cfg_update),
    .tx_dds_freq_ctrl_word      (tx_dds_freq_ctrl_word),
    .fc_window                  (fc_window),
    .sync_in                    (sync_in),
    .pps_select                 (),
    .test_bytes_len             (test_bytes_len),
    .test_rx_start              (test_rx_start),
    .dma1_test_rx_start         (dma1_test_rx_start),
    .enable_xfft                (enable_xfft),
    .enable_overlap             (enable_overlap),
    .fft_len                    (fft_len),
    .fft_len_update             (fft_len_update),
    .xfft_ready                 (1'b0),
    .s00_axi_aclk               (pl_clk40),
    .s00_axi_aresetn            (~axil_rst),
    .s00_axi_awaddr             (ctrl_axil_awaddr[7:0]),
    .s00_axi_awprot             (3'd0),
    .s00_axi_awvalid            (ctrl_axil_awvalid),
    .s00_axi_awready            (ctrl_axil_awready),
    .s00_axi_wdata              (ctrl_axil_wdata),
    .s00_axi_wstrb              (ctrl_axil_wstrb),
    .s00_axi_wvalid             (ctrl_axil_wvalid),
    .s00_axi_wready             (ctrl_axil_wready),
    .s00_axi_bresp              (ctrl_axil_bresp),
    .s00_axi_bvalid             (ctrl_axil_bvalid),
    .s00_axi_bready             (ctrl_axil_bready),
    .s00_axi_araddr             (ctrl_axil_araddr[7:0]),
    .s00_axi_arprot             (3'd0),
    .s00_axi_arvalid            (ctrl_axil_arvalid),
    .s00_axi_arready            (ctrl_axil_arready),
    .s00_axi_rdata              (ctrl_axil_rdata),
    .s00_axi_rresp              (ctrl_axil_rresp),
    .s00_axi_rvalid             (ctrl_axil_rvalid),
    .s00_axi_rready             (ctrl_axil_rready)
  );


    // ila_0 ila_0_top (
    //   .clk(user_clk),
    //   .probe0({
    //       get_current_vita_time ,
    //       get_lastpps_vita_time ,
    //       vita_time ,
    //       vita_time_last_pps  ,
    //       set_time_mode ,
    //       time_mode_strobe  ,
    //       tx_timestamp  ,
    //       rx_sample_bytes ,
    //       max_sample_bytes_per_packet ,
    //       capture_one_block ,
    //       rx_sync_timestamp ,
    //       rx_sync_timestamp_strobe  ,
    //       rx_mode ,
    //       rx_mode_strobe  ,
    //       mode_exit ,
    //       stream_start  ,
    //       channel_enable  ,
    //       sync_in,
    //       m_adc_i0_tdata,
    //       m_adc_q0_tdata,
    //       m_adc_i0_tvalid,
    //       m_adc_q0_tvalid,
    //       iq_user_bus_rx_tdata,
    //       iq_user_bus_rx_tkeep,
    //       iq_user_bus_rx_tlast,
    //       iq_user_bus_rx_tready,
    //       iq_user_bus_rx_tvalid
    //   })
    // );
  iq_framework_wrapper iq_framework_wrapper_i (
    .radio_clk                     (radio_rx_clk),
    .radio_rst                     (radio_rst),
    .clear                         (1'b0),
    .pps                           (1'b0),
    .ch0_adc_i                     (m_adc_i0_tdata),
    .ch0_adc_q                     (m_adc_q0_tdata),
    .ch0_adc_valid                 (m_adc_i0_tvalid & m_adc_q0_tvalid),
    .ch1_adc_i                     (m_adc_i1_tdata),
    .ch1_adc_q                     (m_adc_q1_tdata),
    .ch1_adc_valid                 (m_adc_i1_tvalid & m_adc_q1_tvalid),
    .ch0_dac_i                     (ch0_dac_i),
    .ch0_dac_q                     (ch0_dac_q),
    .ch0_dac_valid                 (ch0_dac_valid),
    .ch1_dac_i                     (ch1_dac_i),
    .ch1_dac_q                     (ch1_dac_q),
    .ch1_dac_valid                 (ch1_dac_valid),
    .get_current_vita_time_b       (get_current_vita_time),
    .get_lastpps_vita_time_b       (get_lastpps_vita_time),
    .vita_time_b                   (vita_time),
    .vita_time_last_pps_b          (vita_time_last_pps),
    .set_vita_timestamp_b          (set_vita_timestamp),
    .set_time_mode_b               (set_time_mode),
    .time_mode_strobe_b            (time_mode_strobe),
    .tx_timestamp_b                (tx_timestamp),
    .rx_sample_bytes_b             (rx_sample_bytes),
    .max_sample_bytes_per_packet_b (max_sample_bytes_per_packet),
    .capture_one_block_b           (capture_one_block),
    .rx_sync_timestamp_b           (rx_sync_timestamp),
    .rx_sync_timestamp_strobe_b    (rx_sync_timestamp_strobe),
    .rx_mode_b                     (rx_mode),
    .rx_mode_strobe_b              (rx_mode_strobe),
    .mode_exit_b                   (mode_exit),
    .stream_start_b                (stream_start),
    .channel_enable_b              (channel_enable),
    .dma_s2mm_pkt_per_burst_b      (dma_s2mm_pkt_per_burst),
    .tx_samples_per_packet_b       (tx_samples_per_packet),
    .tx_source_sel_b               (tx_source_sel),
    .ignore_tx_timestamps_b        (ignore_tx_timestamps),
    .noise_idx_start_b             (noise_idx_start),
    .noise_idx_end_b               (noise_idx_end),
    .noise_cfg_update_b            (noise_cfg_update),
    .tx_dds_freq_ctrl_word_b       (tx_dds_freq_ctrl_word),
    .fc_window_b                   (fc_window),
    .sync_in_b                     (sync_in),
    .user_bus_clk                  (pl_clk200),
    .user_bus_rst                  (chdr_rst),
    .user_bus_rx_tdata             (iq_user_bus_rx_tdata),
    .user_bus_rx_tkeep             (iq_user_bus_rx_tkeep),
    .user_bus_rx_tlast             (iq_user_bus_rx_tlast),
    .user_bus_rx_tready            (iq_user_bus_rx_tready),
    .user_bus_rx_tvalid            (iq_user_bus_rx_tvalid),
    .user_bus_tx_tdata             (iq_user_bus_tx_tdata),
    .user_bus_tx_tkeep             (iq_user_bus_tx_tkeep),
    .user_bus_tx_tlast             (iq_user_bus_tx_tlast),
    .user_bus_tx_tready            (iq_user_bus_tx_tready),
    .user_bus_tx_tvalid            (iq_user_bus_tx_tvalid)
  );

  t510_ai_100g_ps_bd_wrapper t510_ai_100g_ps_bd_i (
    .gpio_i(gpio_i),
    .gpio_o(gpio_o),
    .gpio_t(gpio_t),
    .i2c_scl_io(i2c_scl_io),
    .i2c_sda_io(i2c_sda_io),
    .adc_clk_clk_n (adc_clk_clk_n),
    .adc_clk_clk_p (adc_clk_clk_p),
    .dac_clk_clk_n (dac_clk_clk_n),
    .dac_clk_clk_p (dac_clk_clk_p),
    .pl_clk40     (pl_clk40),
    .pl_clk100    (pl_clk100),
    .pl_clk200    (pl_clk200),
    .pl_resetn0   (pl_resetn0),
    .eth_rx_irq   (eth_rx_irq[0]),
    .eth_tx_irq   (eth_tx_irq[0]),
    .m_adc_i0_tdata  (m_adc_i0_tdata),
    .m_adc_i0_tready (m_adc_i0_tready),
    .m_adc_i0_tvalid (m_adc_i0_tvalid),
    .m_adc_i1_tdata  (m_adc_i1_tdata),
    .m_adc_i1_tready (m_adc_i1_tready),
    .m_adc_i1_tvalid (m_adc_i1_tvalid),
    .m_adc_q0_tdata  (m_adc_q0_tdata),
    .m_adc_q0_tready (m_adc_q0_tready),
    .m_adc_q0_tvalid (m_adc_q0_tvalid),
    .m_adc_q1_tdata  (m_adc_q1_tdata),
    .m_adc_q1_tready (m_adc_q1_tready),
    .m_adc_q1_tvalid (m_adc_q1_tvalid),
    .radio_rx_clk    (radio_rx_clk),
    .radio_tx_clk    (radio_tx_clk),
    .rx_ch0_v_n      (rx_ch0_v_n),
    .rx_ch0_v_p      (rx_ch0_v_p),
    .rx_ch1_v_n      (rx_ch1_v_n),
    .rx_ch1_v_p      (rx_ch1_v_p),
    .s_dac_ch0_tdata  (s_dac_ch0_tdata),
    .s_dac_ch0_tready (s_dac_ch0_tready),
    .s_dac_ch0_tvalid (s_dac_ch0_tvalid),
    .s_dac_ch1_tdata  (s_dac_ch1_tdata),
    .s_dac_ch1_tready (s_dac_ch1_tready),
    .s_dac_ch1_tvalid (s_dac_ch1_tvalid),
    .sysref_in_diff_n (sysref_in_diff_n),
    .sysref_in_diff_p (sysref_in_diff_p),
    .tx_ch0_v_n       (tx_ch0_v_n),
    .tx_ch0_v_p       (tx_ch0_v_p),
    .tx_ch1_v_n       (tx_ch1_v_n),
    .tx_ch1_v_p       (tx_ch1_v_p),
    .user_sysref_adc  (user_sysref_adc),
    .user_sysref_dac  (user_sysref_dac),

    .axil_araddr  (eth_axil_araddr),
    .axil_arready (eth_axil_arready),
    .axil_arvalid (eth_axil_arvalid),
    .axil_awaddr  (eth_axil_awaddr),
    .axil_awready (eth_axil_awready),
    .axil_awvalid (eth_axil_awvalid),
    .axil_bready  (eth_axil_bready),
    .axil_bresp   (eth_axil_bresp),
    .axil_bvalid  (eth_axil_bvalid),
    .axil_rdata   (eth_axil_rdata),
    .axil_rready  (eth_axil_rready),
    .axil_rresp   (eth_axil_rresp),
    .axil_rvalid  (eth_axil_rvalid),
    .axil_wdata   (eth_axil_wdata),
    .axil_wready  (eth_axil_wready),
    .axil_wstrb   (eth_axil_wstrb),
    .axil_wvalid  (eth_axil_wvalid),
    .axil_ctrl_araddr  (ctrl_axil_araddr),
    .axil_ctrl_arready (ctrl_axil_arready),
    .axil_ctrl_arvalid (ctrl_axil_arvalid),
    .axil_ctrl_awaddr  (ctrl_axil_awaddr),
    .axil_ctrl_awready (ctrl_axil_awready),
    .axil_ctrl_awvalid (ctrl_axil_awvalid),
    .axil_ctrl_bready  (ctrl_axil_bready),
    .axil_ctrl_bresp   (ctrl_axil_bresp),
    .axil_ctrl_bvalid  (ctrl_axil_bvalid),
    .axil_ctrl_rdata   (ctrl_axil_rdata),
    .axil_ctrl_rready  (ctrl_axil_rready),
    .axil_ctrl_rresp   (ctrl_axil_rresp),
    .axil_ctrl_rvalid  (ctrl_axil_rvalid),
    .axil_ctrl_wdata   (ctrl_axil_wdata),
    .axil_ctrl_wready  (ctrl_axil_wready),
    .axil_ctrl_wstrb   (ctrl_axil_wstrb),
    .axil_ctrl_wvalid  (ctrl_axil_wvalid),

    .axi_araddr   (axi_araddr),
    .axi_arburst  (axi_arburst),
    .axi_arcache  (axi_arcache),
    .axi_arlen    (axi_arlen),
    .axi_arlock   (axi_arlock),
    .axi_arprot   (axi_arprot),
    .axi_arqos    (axi_arqos),
    .axi_arready  (axi_arready),
    .axi_arsize   (axi_arsize),
    .axi_arvalid  (axi_arvalid),
    .axi_awaddr   (axi_awaddr),
    .axi_awburst  (axi_awburst),
    .axi_awcache  (axi_awcache),
    .axi_awlen    (axi_awlen),
    .axi_awlock   (axi_awlock),
    .axi_awprot   (axi_awprot),
    .axi_awqos    (axi_awqos),
    .axi_awready  (axi_awready),
    .axi_awsize   (axi_awsize),
    .axi_awvalid  (axi_awvalid),
    .axi_bready   (axi_bready),
    .axi_bresp    (axi_bresp),
    .axi_bvalid   (axi_bvalid),
    .axi_rdata    (axi_rdata),
    .axi_rlast    (axi_rlast),
    .axi_rready   (axi_rready),
    .axi_rresp    (axi_rresp),
    .axi_rvalid   (axi_rvalid),
    .axi_wdata    (axi_wdata),
    .axi_wlast    (axi_wlast),
    .axi_wready   (axi_wready),
    .axi_wstrb    (axi_wstrb),
    .axi_wvalid   (axi_wvalid)
  );

  t510_ai_100g_ps_top #(
    .CHDR_W     (CHDR_W),
    .NET_CHDR_W (NET_CHDR_W),
    .BYTE_MTU   (BYTE_MTU),
    .QSFP_NUM   (QSFP_NUM),
    .NODE_INST  (NODE_INST),
    .PROTOVER   (PROTOVER)
  ) t510_ai_100g_ps_top_i (
    .core_arst      (core_arst),
    .rfnoc_ctrl_clk (pl_clk40),
    .rfnoc_ctrl_rst (ctrl_rst),
    .rfnoc_chdr_clk (pl_clk200),
    .rfnoc_chdr_rst (chdr_rst),
    .dclk           (pl_clk100),
    .refclk_p       (refclk_p),
    .refclk_n       (refclk_n),
    .qsfp0_modprs_n (qsfp0_modprs_n),
    .qsfp0_reset_n  (qsfp0_reset_n),
    .qsfp0_lpmode_n (qsfp0_lpmode_n),
    .tx_p           (tx_p),
    .tx_n           (tx_n),
    .rx_p           (rx_p),
    .rx_n           (rx_n),
    .device_id      (16'd0),
    .recovered_clk  (),
    .eth_rx_irq     (eth_rx_irq),
    .eth_tx_irq     (eth_tx_irq),
    .port_info      (),
    .link_up        (link_up),
    .activity       (activity),
    .axil_rst       (axil_rst),
    .axil_clk       (pl_clk40),
    .axil_awaddr    (eth_axil_awaddr),
    .axil_awvalid   (eth_axil_awvalid),
    .axil_awready   (eth_axil_awready),
    .axil_wdata     (eth_axil_wdata),
    .axil_wstrb     (eth_axil_wstrb),
    .axil_wvalid    (eth_axil_wvalid),
    .axil_wready    (eth_axil_wready),
    .axil_bresp     (eth_axil_bresp),
    .axil_bvalid    (eth_axil_bvalid),
    .axil_bready    (eth_axil_bready),
    .axil_araddr    (eth_axil_araddr),
    .axil_arvalid   (eth_axil_arvalid),
    .axil_arready   (eth_axil_arready),
    .axil_rdata     (eth_axil_rdata),
    .axil_rresp     (eth_axil_rresp),
    .axil_rvalid    (eth_axil_rvalid),
    .axil_rready    (eth_axil_rready),
    .axi_rst        (axi_rst),
    .axi_clk        (pl_clk40),
    .axi_araddr     (axi_araddr),
    .axi_arburst    (axi_arburst),
    .axi_arcache    (axi_arcache),
    .axi_arlen      (axi_arlen),
    .axi_arlock     (axi_arlock),
    .axi_arprot     (axi_arprot),
    .axi_arqos      (axi_arqos),
    .axi_arready    (axi_arready),
    .axi_arsize     (axi_arsize),
    .axi_arvalid    (axi_arvalid),
    .axi_awaddr     (axi_awaddr),
    .axi_awburst    (axi_awburst),
    .axi_awcache    (axi_awcache),
    .axi_awlen      (axi_awlen),
    .axi_awlock     (axi_awlock),
    .axi_awprot     (axi_awprot),
    .axi_awqos      (axi_awqos),
    .axi_awready    (axi_awready),
    .axi_awsize     (axi_awsize),
    .axi_awvalid    (axi_awvalid),
    .axi_bready     (axi_bready),
    .axi_bresp      (axi_bresp),
    .axi_bvalid     (axi_bvalid),
    .axi_rdata      (axi_rdata),
    .axi_rlast      (axi_rlast),
    .axi_rready     (axi_rready),
    .axi_rresp      (axi_rresp),
    .axi_rvalid     (axi_rvalid),
    .axi_wdata      (axi_wdata),
    .axi_wlast      (axi_wlast),
    .axi_wready     (axi_wready),
    .axi_wstrb      (axi_wstrb),
    .axi_wvalid     (axi_wvalid),
    .e2v_tdata      (e2v_tdata),
    .e2v_tlast      (e2v_tlast),
    .e2v_tvalid     (e2v_tvalid),
    .e2v_tready     (e2v_tready),
    .v2e_tdata      (v2e_tdata),
    .v2e_tlast      (v2e_tlast),
    .v2e_tvalid     (v2e_tvalid),
    .v2e_tready     (v2e_tready)
  );

endmodule : t510_ai_100g_full_system_top

`default_nettype wire
