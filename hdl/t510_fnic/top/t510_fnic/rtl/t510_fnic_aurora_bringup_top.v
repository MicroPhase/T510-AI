`timescale 1ns / 1ps
`default_nettype none

module t510_fnic_aurora_bringup_top (
  input  wire       user_clk,

  input  wire       adc_clk_clk_n,
  input  wire       adc_clk_clk_p,
  input  wire       dac_clk_clk_n,
  input  wire       dac_clk_clk_p,
  input  wire       sysref_in_diff_n,
  input  wire       sysref_in_diff_p,
  input  wire       rfdc_user_clk_n,
  input  wire       rfdc_user_clk_p,
  input  wire       pl_sysref_in_n,
  input  wire       pl_sysref_in_p,
  output wire       sysref_req,
  input  wire       rx_ch0_v_n,
  input  wire       rx_ch0_v_p,
  input  wire       rx_ch1_v_n,
  input  wire       rx_ch1_v_p,
  output wire       tx_ch0_v_n,
  output wire       tx_ch0_v_p,
  output wire       tx_ch1_v_n,
  output wire       tx_ch1_v_p,

  input  wire       refclk_p,
  input  wire       refclk_n,
  input  wire [0:3] rx_p,
  input  wire [0:3] rx_n,
  output wire [0:3] tx_p,
  output wire [0:3] tx_n,

  input  wire       qsfp0_modprs_n,
  output wire       qsfp0_reset_n,
  output wire       qsfp0_lpmode_n,

  output wire       qsfp_link_up,
  output wire       qsfp_activity
);

  wire        aurora_pma_init;
  wire        aurora_reset_pb;
  wire        aurora_reset_done;
  wire        aurora_channel_up;
  wire        aurora_gt_pll_lock;
  wire        aurora_hard_err;
  wire [0:3]  aurora_lane_up;
  wire        aurora_pll_not_locked;
  wire        aurora_soft_err;
  wire        aurora_sys_reset;
  wire        aurora_user_clk;
  wire        ps_pl_clk100;
  wire        ps_pl_clk40;
  wire        ps_pl_clk200;
  wire        ps_pl_resetn0;
  wire [94:0] ps_gpio_o;
  wire [94:0] ps_gpio_t;
  wire        pl_sysref;
  wire        rfdc_user_clk_ibuf;
  wire        rfdc_user_clk;
  reg         pl_sysref_r = 1'b0;
  reg         pl_sysref_r1 = 1'b0;
  wire [15:0] rfdc_m_adc_i0_tdata;
  wire        rfdc_m_adc_i0_tvalid;
  wire [15:0] rfdc_m_adc_q0_tdata;
  wire        rfdc_m_adc_q0_tvalid;
  wire [15:0] rfdc_m_adc_i1_tdata;
  wire        rfdc_m_adc_i1_tvalid;
  wire [15:0] rfdc_m_adc_q1_tdata;
  wire        rfdc_m_adc_q1_tvalid;
  wire        rfdc_s_dac_ch0_tready;
  wire        rfdc_s_dac_ch1_tready;

  wire [255:0] aurora_rx_tdata;
  wire         aurora_rx_tvalid;
  wire [255:0] aurora_tx_tdata;
  wire         aurora_tx_tready;
  wire         aurora_tx_tvalid;
  wire [39:0]  axi_peek_poke_awaddr;
  wire [2:0]   axi_peek_poke_awprot;
  wire         axi_peek_poke_awready;
  wire         axi_peek_poke_awvalid;
  wire [31:0]  axi_peek_poke_wdata;
  wire [3:0]   axi_peek_poke_wstrb;
  wire         axi_peek_poke_wready;
  wire         axi_peek_poke_wvalid;
  wire [1:0]   axi_peek_poke_bresp;
  wire         axi_peek_poke_bvalid;
  wire         axi_peek_poke_bready;
  wire [39:0]  axi_peek_poke_araddr;
  wire [2:0]   axi_peek_poke_arprot;
  wire         axi_peek_poke_arready;
  wire         axi_peek_poke_arvalid;
  wire [31:0]  axi_peek_poke_rdata;
  wire [1:0]   axi_peek_poke_rresp;
  wire         axi_peek_poke_rvalid;
  wire         axi_peek_poke_rready;

  wire [255:0] rx_iq_tdata;
  wire         rx_iq_tvalid;
  wire         rx_iq_tready;
  wire [255:0] aurora_resp_tdata;
  wire         aurora_resp_tvalid;
  wire         aurora_resp_tready;
  wire         rfdc_m_adc_i0_tready;
  wire         rfdc_m_adc_q0_tready;
  wire [15:0]  rx_iq_packet_seq;
  wire [31:0]  rx_iq_packet_count;
  wire [31:0]  rx_iq_beat_count;
  wire [63:0]  rx_iq_sample_count;
  wire [15:0]  rx_iq_fifo_wr_occupancy;
  wire [15:0]  rx_iq_fifo_rd_occupancy;
  wire         rx_flow_pause;
  wire [15:0]  rx_flow_fifo_level;
  wire [15:0]  rx_flow_pause_high;
  wire [15:0]  rx_flow_resume_low;
  wire [31:0]  rx_flow_frame_count;
  wire [31:0]  rx_flow_bad_count;
  wire         rx_flow_seen;
  wire [31:0]  tx_sink_frame_count;
  wire [31:0]  tx_sink_beat_count;
  wire [31:0]  tx_sink_bad_magic_count;
  wire [31:0]  tx_sink_bad_length_count;
  wire [31:0]  tx_sink_seq_jump_count;
  wire [31:0]  tx_sink_payload_error_count;
  wire [63:0]  tx_sink_last_header;
  wire [63:0]  tx_sink_last_timestamp;
  wire [15:0]  tx_sink_last_seq;
  wire [7:0]   tx_sink_last_sid;
  wire [23:0]  tx_sink_last_length;
  wire         tx_sink_frame_active;
  wire [31:0]  tx_dac_tdata;
  wire         tx_dac_tvalid;
  wire [15:0]  tx_dac_fifo_wr_occupancy;
  wire [15:0]  tx_dac_fifo_rd_occupancy;
  wire [31:0]  tx_dac_frame_count;
  wire [31:0]  tx_dac_beat_count;
  wire [31:0]  tx_dac_bad_magic_count;
  wire [31:0]  tx_dac_bad_length_count;
  wire [31:0]  tx_dac_drop_frame_count;
  wire [31:0]  tx_dac_overflow_count;
  wire [31:0]  tx_dac_sample_count;
  wire [31:0]  tx_dac_underflow_count;
  wire [23:0]  tx_dac_packet_bytes;
  wire [63:0]  tx_dac_last_header;
  wire [63:0]  tx_dac_last_timestamp;
  wire [15:0]  tx_dac_last_seq;
  wire [7:0]   tx_dac_last_sid;
  wire [23:0]  tx_dac_last_length;
  wire [1:0]   tx_dac_dbg_aurora_state;
  wire [15:0]  tx_dac_dbg_aurora_beats_remaining;
  wire         tx_dac_dbg_fifo_s_tvalid;
  wire         tx_dac_dbg_fifo_s_tready;
  wire         tx_dac_dbg_fifo_m_tvalid;
  wire         tx_dac_dbg_fifo_m_tready;
  wire         tx_dac_dbg_playback_started;
  wire         tx_dac_dbg_beat_valid;
  wire [2:0]   tx_dac_dbg_word_index;
  wire         tx_dac_dbg_prefetched_valid;
  wire         tx_dac_dbg_prefetch_pending;
  wire         tx_dac_dbg_dac_play_enable;
  wire         tx_dac_dbg_dac_out_ready;
  wire         tx_dac_dbg_load_new_beat;
  wire         tx_dac_dbg_word_fire;
  wire         tx_dac_dbg_prefetch_issue;
  wire [255:0] tx_flow_tdata;
  wire         tx_flow_tvalid;
  wire         tx_flow_tready;
  wire         tx_flow_pause;
  wire [31:0]  tx_flow_frame_count;
  reg  [31:0]  rx_valid_counter = 32'd0;
  wire         init_clk;
  wire [31:0]  mailbox_dbg_status;
  wire         mbox_pl_cmd_valid;
  wire         mbox_pl_cmd_ready;
  wire [31:0]  mbox_pl_cmd_seq;
  wire [31:0]  mbox_pl_cmd_op;
  wire [31:0]  mbox_pl_cmd_arg0;
  wire [31:0]  mbox_pl_cmd_arg1;
  wire [31:0]  mbox_pl_cmd_arg2;
  wire [31:0]  mbox_pl_cmd_arg3;
  wire         mbox_pl_resp_valid;
  wire         mbox_pl_resp_ready;
  wire [31:0]  mbox_pl_resp_seq;
  wire [31:0]  mbox_pl_resp_status;
  wire [31:0]  mbox_pl_resp_data0;
  wire [31:0]  mbox_pl_resp_data1;
  wire [31:0]  mbox_pl_resp_data2;
  wire [31:0]  mbox_pl_resp_data3;
  wire [191:0] aurora_cmd_tdata;
  wire         aurora_cmd_tvalid;
  wire         aurora_cmd_tready;
  wire [191:0] mbox_cmd_tdata;
  wire         mbox_cmd_tvalid;
  wire         mbox_cmd_tready;
  wire [191:0] mbox_resp_tdata;
  wire         mbox_resp_tvalid;
  wire         mbox_resp_tready;
  wire [191:0] aurora_resp_payload_tdata;
  wire         aurora_resp_payload_tvalid;
  wire         aurora_resp_payload_tready;
  wire [15:0]  cmd_fifo_wr_occupancy;
  wire [15:0]  cmd_fifo_rd_occupancy;
  wire [15:0]  resp_fifo_wr_occupancy;
  wire [15:0]  resp_fifo_rd_occupancy;
  wire [31:0]  aurora_ctrl_count;
  wire [31:0]  aurora_ctrl_bad_length_count;
  wire [31:0]  aurora_ctrl_drop_count;
  wire [31:0]  aurora_resp_count;

  // The mailbox payload is 6 x 32-bit words.  Aurora carries it in a
  // 256-bit framed word, while the PS mailbox logic consumes the lower
  // 192 bits as seq/op/arg0..arg3.
  assign init_clk = user_clk;
  assign mbox_pl_cmd_seq = mbox_cmd_tdata[31:0];
  assign mbox_pl_cmd_op = mbox_cmd_tdata[63:32];
  assign mbox_pl_cmd_arg0 = mbox_cmd_tdata[95:64];
  assign mbox_pl_cmd_arg1 = mbox_cmd_tdata[127:96];
  assign mbox_pl_cmd_arg2 = mbox_cmd_tdata[159:128];
  assign mbox_pl_cmd_arg3 = mbox_cmd_tdata[191:160];
  assign mbox_cmd_tready = mbox_pl_cmd_ready;
  assign mbox_pl_cmd_valid = mbox_cmd_tvalid;
  assign mbox_resp_tdata = {
    mbox_pl_resp_data3,
    mbox_pl_resp_data2,
    mbox_pl_resp_data1,
    mbox_pl_resp_data0,
    mbox_pl_resp_status,
    mbox_pl_resp_seq
  };
  assign mbox_resp_tvalid = mbox_pl_resp_valid;
  assign mbox_pl_resp_ready = mbox_resp_tready;

  IBUFDS pl_sysref_i (
    .I (pl_sysref_in_p),
    .IB(pl_sysref_in_n),
    .O (pl_sysref)
  );

  IBUFDS rfdc_user_clk_i (
    .I (rfdc_user_clk_p),
    .IB(rfdc_user_clk_n),
    .O (rfdc_user_clk_ibuf)
  );

  BUFG rfdc_user_clk_bufg_i (
    .I(rfdc_user_clk_ibuf),
    .O(rfdc_user_clk)
  );

  assign qsfp0_reset_n  = aurora_reset_done;
  assign qsfp0_lpmode_n = 1'b0;

  assign qsfp_link_up  = aurora_channel_up;
  assign qsfp_activity = rx_valid_counter[23];
  assign sysref_req = ps_gpio_o[0];

  always @(posedge aurora_user_clk) begin
    if (aurora_sys_reset || !aurora_channel_up) begin
      rx_valid_counter <= 32'd0;
    end else if (aurora_rx_tvalid) begin
      rx_valid_counter <= rx_valid_counter + 1'b1;
    end
  end

  always @(posedge rfdc_user_clk) begin
    pl_sysref_r <= pl_sysref;
    pl_sysref_r1 <= pl_sysref_r;
  end

  t510_fnic_aurora_reset_ctrl #(
    .STARTUP_RESET_CYCLES(1000000)
  ) aurora_reset_ctrl_i (
    .clk            (init_clk),
    .rst            (1'b0),
    .soft_reset_req (1'b0),
    .pma_init       (aurora_pma_init),
    .reset_pb       (aurora_reset_pb),
    .reset_done     (aurora_reset_done)
  );

  // T510/FNIC naming note:
  //   rx_iq_* is ADC receive IQ from the T510 radio point of view.
  //   The same stream is transmitted on the Aurora link, so it becomes
  //   aurora_tx_* only after the local TX mux.
  t510_fnic_rfdc_iq_packetizer_256 #(
    .PACKET_BYTES(24'd8192),
    .SID(8'd0),
    .PACK_Q_HIGH(1)
  ) rfdc_iq_packetizer_i (
    .s_clk            (rfdc_user_clk),
    .s_rst            (!ps_pl_resetn0),
    .s_i_tdata        (rfdc_m_adc_i0_tdata),
    .s_i_tvalid       (rfdc_m_adc_i0_tvalid),
    .s_i_tready       (rfdc_m_adc_i0_tready),
    .s_q_tdata        (rfdc_m_adc_q0_tdata),
    .s_q_tvalid       (rfdc_m_adc_q0_tvalid),
    .s_q_tready       (rfdc_m_adc_q0_tready),
    .m_clk            (aurora_user_clk),
    .m_rst            (aurora_sys_reset),
    .enable           (aurora_channel_up),
    .pause            (rx_flow_pause),
    .m_axis_tdata     (rx_iq_tdata),
    .m_axis_tvalid    (rx_iq_tvalid),
    .m_axis_tready    (rx_iq_tready),
    .packet_seq       (rx_iq_packet_seq),
    .packet_count     (rx_iq_packet_count),
    .beat_count       (rx_iq_beat_count),
    .sample_count     (rx_iq_sample_count),
    .fifo_wr_occupancy(rx_iq_fifo_wr_occupancy),
    .fifo_rd_occupancy(rx_iq_fifo_rd_occupancy)
  );

  // 0x5601 control frames from FNIC are unpacked here, then moved into
  // the PS clock domain for the AXI peek/poke mailbox.
  t510_fnic_aurora_ctrl_parser_256 aurora_ctrl_parser_i (
    .clk             (aurora_user_clk),
    .rst             (aurora_sys_reset || !aurora_channel_up),
    .enable          (aurora_channel_up),
    .s_axis_tdata    (aurora_rx_tdata),
    .s_axis_tvalid   (aurora_rx_tvalid),
    .m_cmd_tdata     (aurora_cmd_tdata),
    .m_cmd_tvalid    (aurora_cmd_tvalid),
    .m_cmd_tready    (aurora_cmd_tready),
    .ctrl_count      (aurora_ctrl_count),
    .bad_length_count(aurora_ctrl_bad_length_count),
    .drop_count      (aurora_ctrl_drop_count)
  );

  // Aurora user clock -> PS PL clock crossing for control commands.
  t510_fnic_axis_async_fifo_256 #(
    .ADDR_WIDTH(3),
    .DATA_WIDTH(192)
  ) aurora_cmd_cdc_fifo_i (
    .s_clk        (aurora_user_clk),
    .s_rst        (aurora_sys_reset || !aurora_channel_up),
    .s_axis_tdata (aurora_cmd_tdata),
    .s_axis_tvalid(aurora_cmd_tvalid),
    .s_axis_tready(aurora_cmd_tready),
    .m_clk        (ps_pl_clk40),
    .m_rst        (!ps_pl_resetn0),
    .m_axis_tdata (mbox_cmd_tdata),
    .m_axis_tvalid(mbox_cmd_tvalid),
    .m_axis_tready(mbox_cmd_tready),
    .wr_occupancy (cmd_fifo_wr_occupancy),
    .rd_occupancy (cmd_fifo_rd_occupancy)
  );

  // PS PL clock -> Aurora user clock crossing for mailbox responses.
  t510_fnic_axis_async_fifo_256 #(
    .ADDR_WIDTH(3),
    .DATA_WIDTH(192)
  ) aurora_resp_cdc_fifo_i (
    .s_clk        (ps_pl_clk40),
    .s_rst        (!ps_pl_resetn0),
    .s_axis_tdata (mbox_resp_tdata),
    .s_axis_tvalid(mbox_resp_tvalid),
    .s_axis_tready(mbox_resp_tready),
    .m_clk        (aurora_user_clk),
    .m_rst        (aurora_sys_reset || !aurora_channel_up),
    .m_axis_tdata (aurora_resp_payload_tdata),
    .m_axis_tvalid(aurora_resp_payload_tvalid),
    .m_axis_tready(aurora_resp_payload_tready),
    .wr_occupancy (resp_fifo_wr_occupancy),
    .rd_occupancy (resp_fifo_rd_occupancy)
  );

  // Rebuild the mailbox response as a 0x5602 Aurora response frame.
  t510_fnic_aurora_resp_builder_256 aurora_resp_builder_i (
    .clk          (aurora_user_clk),
    .rst          (aurora_sys_reset || !aurora_channel_up),
    .enable       (aurora_channel_up),
    .s_resp_tdata (aurora_resp_payload_tdata),
    .s_resp_tvalid(aurora_resp_payload_tvalid),
    .s_resp_tready(aurora_resp_payload_tready),
    .m_axis_tdata (aurora_resp_tdata),
    .m_axis_tvalid(aurora_resp_tvalid),
    .m_axis_tready(aurora_resp_tready),
    .resp_count   (aurora_resp_count)
  );

  // T510 -> FNIC TX flow-control.  This protects the local DAC playback FIFO
  // from FNIC H2C1 bursts; FNIC pauses TX IQ when this 0x5605 stream asserts.
  t510_fnic_aurora_flow_ctrl_tx_256 #(
    .PAUSE_HIGH_WATERMARK(16'd5632),
    .RESUME_LOW_WATERMARK(16'd4096),
    .PERIOD_CYCLES       (32'd1024),
    .FIFO_DEPTH_BEATS    (32'd8192),
    .FIFO_GUARD_BEATS    (32'd16),
    .PAUSE_MARGIN_BEATS  (32'd1024)
  ) tx_dac_flow_ctrl_tx_i (
    .clk             (aurora_user_clk),
    .rst             (aurora_sys_reset || !aurora_channel_up),
    .enable          (aurora_channel_up),
    .fifo_wr_level   (tx_dac_fifo_wr_occupancy),
    .packet_bytes    (tx_dac_packet_bytes),
    .link_up         (aurora_channel_up),
    .m_axis_tdata    (tx_flow_tdata),
    .m_axis_tvalid   (tx_flow_tvalid),
    .m_axis_tready   (tx_flow_tready),
    .flow_pause      (tx_flow_pause),
    .flow_frame_count(tx_flow_frame_count)
  );

  // Aurora TX priority on T510:
  //   1. mailbox responses, so host control transactions complete quickly
  //   2. TX-DAC flow-control frames, so FNIC can pause H2C1 TX IQ promptly
  //   3. RFDC RX IQ stream, back-pressured by FNIC flow-control frames
  t510_fnic_aurora_tx_mux_256 aurora_tx_mux_i (
    .clk            (aurora_user_clk),
    .rst            (aurora_sys_reset),
    .enable         (aurora_channel_up),
    .resp_tdata     (aurora_resp_tdata),
    .resp_tvalid    (aurora_resp_tvalid),
    .resp_tready    (aurora_resp_tready),
    .flow_tdata     (tx_flow_tdata),
    .flow_tvalid    (tx_flow_tvalid),
    .flow_tready    (tx_flow_tready),
    .iq_tdata       (rx_iq_tdata),
    .iq_tvalid      (rx_iq_tvalid),
    .iq_tready      (rx_iq_tready),
    .m_axis_tdata   (aurora_tx_tdata),
    .m_axis_tvalid  (aurora_tx_tvalid),
    .m_axis_tready  (aurora_tx_tready)
  );

  // AXI-lite mailbox visible to the T510 PS.  PL receives parsed Aurora
  // commands, PS services them through software, then PL sends responses
  // back to FNIC over Aurora.
  axi_peek_poke_v1_0_S00_AXI #(
    .C_S_AXI_DATA_WIDTH(32),
    .C_S_AXI_ADDR_WIDTH(7)
  ) ps_mailbox_i (
    .pl_cmd_valid (mbox_pl_cmd_valid),
    .pl_cmd_ready (mbox_pl_cmd_ready),
    .pl_cmd_seq   (mbox_pl_cmd_seq),
    .pl_cmd_op    (mbox_pl_cmd_op),
    .pl_cmd_arg0  (mbox_pl_cmd_arg0),
    .pl_cmd_arg1  (mbox_pl_cmd_arg1),
    .pl_cmd_arg2  (mbox_pl_cmd_arg2),
    .pl_cmd_arg3  (mbox_pl_cmd_arg3),
    .pl_resp_valid(mbox_pl_resp_valid),
    .pl_resp_ready(mbox_pl_resp_ready),
    .pl_resp_seq  (mbox_pl_resp_seq),
    .pl_resp_status(mbox_pl_resp_status),
    .pl_resp_data0(mbox_pl_resp_data0),
    .pl_resp_data1(mbox_pl_resp_data1),
    .pl_resp_data2(mbox_pl_resp_data2),
    .pl_resp_data3(mbox_pl_resp_data3),
    .dbg_status   (mailbox_dbg_status),
    .S_AXI_ACLK   (ps_pl_clk40),
    .S_AXI_ARESETN(ps_pl_resetn0),
    .S_AXI_AWADDR (axi_peek_poke_awaddr[6:0]),
    .S_AXI_AWPROT (axi_peek_poke_awprot),
    .S_AXI_AWVALID(axi_peek_poke_awvalid),
    .S_AXI_AWREADY(axi_peek_poke_awready),
    .S_AXI_WDATA  (axi_peek_poke_wdata),
    .S_AXI_WSTRB  (axi_peek_poke_wstrb),
    .S_AXI_WVALID (axi_peek_poke_wvalid),
    .S_AXI_WREADY (axi_peek_poke_wready),
    .S_AXI_BRESP  (axi_peek_poke_bresp),
    .S_AXI_BVALID (axi_peek_poke_bvalid),
    .S_AXI_BREADY (axi_peek_poke_bready),
    .S_AXI_ARADDR (axi_peek_poke_araddr[6:0]),
    .S_AXI_ARPROT (axi_peek_poke_arprot),
    .S_AXI_ARVALID(axi_peek_poke_arvalid),
    .S_AXI_ARREADY(axi_peek_poke_arready),
    .S_AXI_RDATA  (axi_peek_poke_rdata),
    .S_AXI_RRESP  (axi_peek_poke_rresp),
    .S_AXI_RVALID (axi_peek_poke_rvalid),
    .S_AXI_RREADY (axi_peek_poke_rready)
  );

  // 0x5605 flow-control frames come from FNIC and directly throttle the
  // RFDC IQ packetizer before the Aurora TX FIFO can overrun.
  t510_fnic_aurora_flow_ctrl_rx_256 #(
    .TIMEOUT_CYCLES(32'd1000000)
  ) aurora_flow_ctrl_rx_i (
    .clk              (aurora_user_clk),
    .rst              (aurora_sys_reset || !aurora_channel_up),
    .enable           (aurora_channel_up),
    .s_axis_tdata     (aurora_rx_tdata),
    .s_axis_tvalid    (aurora_rx_tvalid),
    .remote_pause     (rx_flow_pause),
    .remote_fifo_level(rx_flow_fifo_level),
    .remote_pause_high(rx_flow_pause_high),
    .remote_resume_low(rx_flow_resume_low),
    .flow_frame_count (rx_flow_frame_count),
    .bad_flow_count   (rx_flow_bad_count),
    .flow_seen        (rx_flow_seen)
  );

  // Host-to-T510 TX data (0x5604) is still checked here for bring-up
  // counters, while the player below drives single-channel DAC IQ.
  t510_fnic_aurora_tx_sink_checker_256 aurora_tx_sink_checker_i (
    .clk                 (aurora_user_clk),
    .rst                 (aurora_sys_reset || !aurora_channel_up),
    .enable              (aurora_channel_up),
    .s_axis_tdata        (aurora_rx_tdata),
    .s_axis_tvalid       (aurora_rx_tvalid),
    .frame_count         (tx_sink_frame_count),
    .beat_count          (tx_sink_beat_count),
    .bad_magic_count     (tx_sink_bad_magic_count),
    .bad_length_count    (tx_sink_bad_length_count),
    .seq_jump_count      (tx_sink_seq_jump_count),
    .payload_error_count (tx_sink_payload_error_count),
    .last_header         (tx_sink_last_header),
    .last_timestamp      (tx_sink_last_timestamp),
    .last_seq            (tx_sink_last_seq),
    .last_sid            (tx_sink_last_sid),
    .last_length         (tx_sink_last_length),
    .frame_active        (tx_sink_frame_active)
  );

  // Single-channel TX IQ path.  The host sends 0x5504 packets to FNIC H2C1;
  // FNIC forwards them as Aurora 0x5604 packets.  T510 strips the Aurora
  // header, crosses into the RFDC clock domain, and streams payload words to
  // DAC channel 0 as packed 32-bit IQ samples.
  t510_fnic_aurora_tx_iq_player_256 aurora_tx_iq_player_i (
    .aurora_clk                (aurora_user_clk),
    .aurora_rst                (aurora_sys_reset || !aurora_channel_up),
    .aurora_enable             (aurora_channel_up),
    .aurora_rx_tdata           (aurora_rx_tdata),
    .aurora_rx_tvalid          (aurora_rx_tvalid),
    .dac_clk                   (rfdc_user_clk),
    .dac_rst                   (!ps_pl_resetn0),
    .dac_enable                (aurora_channel_up),
    .m_dac_tdata               (tx_dac_tdata),
    .m_dac_tvalid              (tx_dac_tvalid),
    .m_dac_tready              (rfdc_s_dac_ch0_tready),
    .fifo_wr_occupancy         (tx_dac_fifo_wr_occupancy),
    .fifo_rd_occupancy         (tx_dac_fifo_rd_occupancy),
    .aurora_tx_frame_count     (tx_dac_frame_count),
    .aurora_tx_beat_count      (tx_dac_beat_count),
    .aurora_tx_bad_magic_count (tx_dac_bad_magic_count),
    .aurora_tx_bad_length_count(tx_dac_bad_length_count),
    .aurora_tx_drop_frame_count(tx_dac_drop_frame_count),
    .aurora_tx_overflow_count  (tx_dac_overflow_count),
    .dac_sample_count          (tx_dac_sample_count),
    .dac_underflow_count       (tx_dac_underflow_count),
    .last_header               (tx_dac_last_header),
    .last_timestamp            (tx_dac_last_timestamp),
    .last_seq                  (tx_dac_last_seq),
    .last_sid                  (tx_dac_last_sid),
    .last_length               (tx_dac_last_length),
    .current_packet_bytes      (tx_dac_packet_bytes),
    .dbg_aurora_state          (tx_dac_dbg_aurora_state),
    .dbg_aurora_beats_remaining(tx_dac_dbg_aurora_beats_remaining),
    .dbg_fifo_s_tvalid         (tx_dac_dbg_fifo_s_tvalid),
    .dbg_fifo_s_tready         (tx_dac_dbg_fifo_s_tready),
    .dbg_fifo_m_tvalid         (tx_dac_dbg_fifo_m_tvalid),
    .dbg_fifo_m_tready         (tx_dac_dbg_fifo_m_tready),
    .dbg_playback_started      (tx_dac_dbg_playback_started),
    .dbg_beat_valid            (tx_dac_dbg_beat_valid),
    .dbg_word_index            (tx_dac_dbg_word_index),
    .dbg_prefetched_valid      (tx_dac_dbg_prefetched_valid),
    .dbg_prefetch_pending      (tx_dac_dbg_prefetch_pending),
    .dbg_dac_play_enable       (tx_dac_dbg_dac_play_enable),
    .dbg_dac_out_ready         (tx_dac_dbg_dac_out_ready),
    .dbg_load_new_beat         (tx_dac_dbg_load_new_beat),
    .dbg_word_fire             (tx_dac_dbg_word_fire),
    .dbg_prefetch_issue        (tx_dac_dbg_prefetch_issue)
  );

  t510_fnic_aurora_bd_wrapper aurora_bd_i (
    .axi_peek_poke_araddr         (axi_peek_poke_araddr),
    .axi_peek_poke_arprot         (axi_peek_poke_arprot),
    .axi_peek_poke_arready        (axi_peek_poke_arready),
    .axi_peek_poke_arvalid        (axi_peek_poke_arvalid),
    .axi_peek_poke_awaddr         (axi_peek_poke_awaddr),
    .axi_peek_poke_awprot         (axi_peek_poke_awprot),
    .axi_peek_poke_awready        (axi_peek_poke_awready),
    .axi_peek_poke_awvalid        (axi_peek_poke_awvalid),
    .axi_peek_poke_bready         (axi_peek_poke_bready),
    .axi_peek_poke_bresp          (axi_peek_poke_bresp),
    .axi_peek_poke_bvalid         (axi_peek_poke_bvalid),
    .axi_peek_poke_rdata          (axi_peek_poke_rdata),
    .axi_peek_poke_rready         (axi_peek_poke_rready),
    .axi_peek_poke_rresp          (axi_peek_poke_rresp),
    .axi_peek_poke_rvalid         (axi_peek_poke_rvalid),
    .axi_peek_poke_wdata          (axi_peek_poke_wdata),
    .axi_peek_poke_wready         (axi_peek_poke_wready),
    .axi_peek_poke_wstrb          (axi_peek_poke_wstrb),
    .axi_peek_poke_wvalid         (axi_peek_poke_wvalid),
    .core_status_channel_up        (aurora_channel_up),
    .core_status_gt_pll_lock       (aurora_gt_pll_lock),
    .core_status_hard_err          (aurora_hard_err),
    .core_status_lane_up           (aurora_lane_up),
    .core_status_pll_not_locked_out(aurora_pll_not_locked),
    .core_status_soft_err          (aurora_soft_err),
    .adc_clk_clk_n                 (adc_clk_clk_n),
    .adc_clk_clk_p                 (adc_clk_clk_p),
    .dac_clk_clk_n                 (dac_clk_clk_n),
    .dac_clk_clk_p                 (dac_clk_clk_p),
    .gpio_i                        (95'd0),
    .gpio_o                        (ps_gpio_o),
    .gpio_t                        (ps_gpio_t),
    .gty_rx_rxn                    (rx_n),
    .gty_rx_rxp                    (rx_p),
    .gty_tx_txn                    (tx_n),
    .gty_tx_txp                    (tx_p),
    .init_clk                      (init_clk),
    .pma_init                      (aurora_pma_init),
    .pl_clk100                     (ps_pl_clk100),
    .pl_clk200                     (ps_pl_clk200),
    .pl_clk40                      (ps_pl_clk40),
    .pl_resetn0                    (ps_pl_resetn0),
    .m_adc_i0_tdata                (rfdc_m_adc_i0_tdata),
    .m_adc_i0_tready               (rfdc_m_adc_i0_tready),
    .m_adc_i0_tvalid               (rfdc_m_adc_i0_tvalid),
    .m_adc_i1_tdata                (rfdc_m_adc_i1_tdata),
    .m_adc_i1_tready               (1'b1),
    .m_adc_i1_tvalid               (rfdc_m_adc_i1_tvalid),
    .m_adc_q0_tdata                (rfdc_m_adc_q0_tdata),
    .m_adc_q0_tready               (rfdc_m_adc_q0_tready),
    .m_adc_q0_tvalid               (rfdc_m_adc_q0_tvalid),
    .m_adc_q1_tdata                (rfdc_m_adc_q1_tdata),
    .m_adc_q1_tready               (1'b1),
    .m_adc_q1_tvalid               (rfdc_m_adc_q1_tvalid),
    .radio_rx_clk                  (rfdc_user_clk),
    .radio_tx_clk                  (rfdc_user_clk),
    .ref_gty_clk_clk_n             (refclk_n),
    .ref_gty_clk_clk_p             (refclk_p),
    .reset_pb                      (aurora_reset_pb),
    .rx_ch0_v_n                    (rx_ch0_v_n),
    .rx_ch0_v_p                    (rx_ch0_v_p),
    .rx_ch1_v_n                    (rx_ch1_v_n),
    .rx_ch1_v_p                    (rx_ch1_v_p),
    .rx_tdata                      (aurora_rx_tdata),
    .rx_tvalid                     (aurora_rx_tvalid),
    .s_dac_ch0_tdata               (tx_dac_tdata),
    .s_dac_ch0_tready              (rfdc_s_dac_ch0_tready),
    .s_dac_ch0_tvalid              (tx_dac_tvalid),
    .s_dac_ch1_tdata               (32'd0),
    .s_dac_ch1_tready              (rfdc_s_dac_ch1_tready),
    .s_dac_ch1_tvalid              (1'b0),
    .sysref_in_diff_n              (sysref_in_diff_n),
    .sysref_in_diff_p              (sysref_in_diff_p),
    .sys_rst                       (aurora_sys_reset),
    .tx_ch0_v_n                    (tx_ch0_v_n),
    .tx_ch0_v_p                    (tx_ch0_v_p),
    .tx_ch1_v_n                    (tx_ch1_v_n),
    .tx_ch1_v_p                    (tx_ch1_v_p),
    .tx_tdata                      (aurora_tx_tdata),
    .tx_tready                     (aurora_tx_tready),
    .tx_tvalid                     (aurora_tx_tvalid),
    .user_sysref_adc               (pl_sysref_r1),
    .user_sysref_dac               (pl_sysref_r1),
    .user_clk                      (aurora_user_clk)
  );

  // TX-DAC focused ILA map, sampled on the DAC/RFDC user clock.
  // [511:504] pad
  // [503:496] link/status: modprs, channel_up, reset, aurora rx/tx, DAC ready/valid
  // [495:348] T510->FNIC TX flow frame/status
  // [347:260] last accepted 0x5604 header and packet_bytes
  // [259:100] TX player counters
  // [99:34]   DAC FIFO/output
  // [33:0]    256-bit Aurora beat to 32-bit DAC word playback debug
  ila_0 ila_0_i (
    .clk(aurora_user_clk),
    .probe0({
      8'd0,                         // [511:504]
      qsfp0_modprs_n,                // [503]
      aurora_channel_up,             // [502]
      aurora_sys_reset,              // [501]
      aurora_rx_tvalid,              // [500]
      aurora_tx_tvalid,              // [499]
      aurora_tx_tready,              // [498]
      rfdc_s_dac_ch0_tready,         // [497]
      tx_dac_tvalid,                 // [496]
      tx_flow_pause,                 // [495]
      tx_flow_tvalid,                // [494]
      tx_flow_tready,                // [493]
      tx_flow_frame_count,           // [492:461]
      tx_flow_tdata[176],            // [460] pause bit inside 0x5605
      tx_flow_tdata[175:160],        // [459:444] resume low
      tx_flow_tdata[159:144],        // [443:428] pause high
      tx_flow_tdata[143:128],        // [427:412] reported FIFO level
      tx_flow_tdata[63:0],           // [411:348] 0x5605 header
      tx_dac_last_header,            // [347:284]
      tx_dac_packet_bytes,           // [283:260]
      tx_dac_frame_count,            // [259:228]
      tx_dac_beat_count,             // [227:196]
      tx_dac_bad_magic_count[15:0],  // [195:180]
      tx_dac_bad_length_count[15:0], // [179:164]
      tx_dac_drop_frame_count[15:0], // [163:148]
      tx_dac_overflow_count[15:0],   // [147:132]
      tx_dac_underflow_count[15:0],  // [131:116]
      tx_dac_sample_count[15:0],     // [115:100]
      tx_dac_fifo_wr_occupancy,      // [99:84]
      tx_dac_fifo_rd_occupancy,      // [83:68]
      tx_dac_tdata,                  // [67:36]
      tx_dac_tvalid,                 // [35]
      rfdc_s_dac_ch0_tready,         // [34]
      tx_dac_dbg_aurora_state,       // [33:32]
      tx_dac_dbg_aurora_beats_remaining, // [31:16]
      tx_dac_dbg_fifo_s_tvalid,      // [15]
      tx_dac_dbg_fifo_s_tready,      // [14]
      tx_dac_dbg_fifo_m_tvalid,      // [13]
      tx_dac_dbg_fifo_m_tready,      // [12]
      tx_dac_dbg_playback_started,   // [11]
      tx_dac_dbg_beat_valid,         // [10]
      tx_dac_dbg_word_index,         // [9:7]
      tx_dac_dbg_prefetched_valid,   // [6]
      tx_dac_dbg_prefetch_pending,   // [5]
      tx_dac_dbg_dac_play_enable,    // [4]
      tx_dac_dbg_dac_out_ready,      // [3]
      tx_dac_dbg_load_new_beat,      // [2]
      tx_dac_dbg_word_fire,          // [1]
      tx_dac_dbg_prefetch_issue      // [0]
    })
  );

endmodule

`default_nettype wire
