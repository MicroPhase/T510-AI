`timescale 1ns / 1ps
`default_nettype none

module tb_t510_ai_iq_wrapper_mode_exit_rearm;

  localparam [1:0] STREAM_MODE = 2'd1;
  localparam [1:0] PACKET_MODE = 2'd2;
  localparam integer CONTROL_STROBE_CYCLES = 8;
  localparam integer STOP_STROBE_CYCLES = 1000;
  localparam integer REARM_CAPTURE_BYTES = 32'd16384;
  localparam integer REARM_PACKET_BYTES  = 32'd1024;
  localparam integer REARM_PACKET_COUNT  = REARM_CAPTURE_BYTES / REARM_PACKET_BYTES;
  localparam integer REARM_SAMPLE_COUNT  = REARM_CAPTURE_BYTES / 8;

  reg         radio_clk = 1'b0;
  reg         user_bus_clk = 1'b0;
  reg         radio_rst = 1'b1;
  reg         user_bus_rst = 1'b1;
  reg         clear = 1'b0;
  reg         pps = 1'b0;
  reg  [15:0] ch0_adc_i = 16'd0;
  reg  [15:0] ch0_adc_q = 16'd0;
  reg         ch0_adc_valid = 1'b0;
  reg  [15:0] ch1_adc_i = 16'd0;
  reg  [15:0] ch1_adc_q = 16'd0;
  reg         get_current_vita_time_b = 1'b0;
  reg         get_lastpps_vita_time_b = 1'b0;
  wire [63:0] vita_time_b;
  wire [63:0] vita_time_last_pps_b;
  reg  [63:0] set_vita_timestamp_b = 64'd0;
  reg  [2:0]  set_time_mode_b = 3'd0;
  reg         time_mode_strobe_b = 1'b0;
  reg  [63:0] tx_timestamp_b = 64'd0;
  reg  [31:0] rx_sample_bytes_b = 32'd0;
  reg  [31:0] max_sample_bytes_per_packet_b = 32'd0;
  reg         capture_one_block_b = 1'b0;
  reg  [63:0] rx_sync_timestamp_b = 64'd0;
  reg         rx_sync_timestamp_strobe_b = 1'b0;
  reg  [1:0]  rx_mode_b = PACKET_MODE;
  reg         rx_mode_strobe_b = 1'b0;
  reg         mode_exit_b = 1'b0;
  reg         stream_start_b = 1'b0;
  reg  [7:0]  channel_enable_b = 8'h01;
  reg  [15:0] dma_s2mm_pkt_per_burst_b = 16'd0;
  reg  [31:0] tx_samples_per_packet_b = 32'd0;
  reg  [2:0]  tx_source_sel_b = 3'd0;
  reg         ignore_tx_timestamps_b = 1'b0;
  reg  [15:0] noise_idx_start_b = 16'd0;
  reg  [15:0] noise_idx_end_b = 16'd0;
  reg         noise_cfg_update_b = 1'b0;
  reg  [31:0] tx_dds_freq_ctrl_word_b = 32'd0;
  reg  [31:0] fc_window_b = 32'd0;
  reg         sync_in_b = 1'b0;

  wire [63:0] user_bus_rx_tdata;
  wire [7:0]  user_bus_rx_tkeep;
  wire        user_bus_rx_tlast;
  wire        user_bus_rx_tready;
  wire        user_bus_rx_tvalid;
  reg  [63:0] user_bus_tx_tdata = 64'd0;
  reg  [7:0]  user_bus_tx_tkeep = 8'd0;
  reg         user_bus_tx_tlast = 1'b0;
  wire        user_bus_tx_tready;
  reg         user_bus_tx_tvalid = 1'b0;

  reg  [511:0] s_axis_tdata = 512'd0;
  reg          s_axis_tlast = 1'b0;
  reg          s_axis_tvalid = 1'b0;
  wire         s_axis_tready;

  wire [511:0] m_axis_tdata;
  wire         m_axis_tlast;
  wire         m_axis_tvalid;
  reg          m_axis_tready = 1'b1;

  integer error_count = 0;
  integer wrapper_packet_count = 0;
  integer chdr_packet_count = 0;
  integer wrapper_packet_count_base = 0;
  integer chdr_packet_count_base = 0;

  always #2 radio_clk = ~radio_clk;
  always #5 user_bus_clk = ~user_bus_clk;

  iq_framework_wrapper dut (
    .radio_clk                   (radio_clk),
    .radio_rst                   (radio_rst),
    .clear                       (clear),
    .pps                         (pps),
    .ch0_adc_i                   (ch0_adc_i),
    .ch0_adc_q                   (ch0_adc_q),
    .ch0_adc_valid               (ch0_adc_valid),
    .ch1_adc_i                   (ch1_adc_i),
    .ch1_adc_q                   (ch1_adc_q),
    .ch1_adc_valid               (1'b0),
    .ch0_dac_i                   (),
    .ch0_dac_q                   (),
    .ch0_dac_valid               (),
    .ch1_dac_i                   (),
    .ch1_dac_q                   (),
    .ch1_dac_valid               (),
    .get_current_vita_time_b     (get_current_vita_time_b),
    .get_lastpps_vita_time_b     (get_lastpps_vita_time_b),
    .vita_time_b                 (vita_time_b),
    .vita_time_last_pps_b        (vita_time_last_pps_b),
    .set_vita_timestamp_b        (set_vita_timestamp_b),
    .set_time_mode_b             (set_time_mode_b),
    .time_mode_strobe_b          (time_mode_strobe_b),
    .tx_timestamp_b              (tx_timestamp_b),
    .rx_sample_bytes_b           (rx_sample_bytes_b),
    .max_sample_bytes_per_packet_b(max_sample_bytes_per_packet_b),
    .capture_one_block_b         (capture_one_block_b),
    .rx_sync_timestamp_b         (rx_sync_timestamp_b),
    .rx_sync_timestamp_strobe_b  (rx_sync_timestamp_strobe_b),
    .rx_mode_b                   (rx_mode_b),
    .rx_mode_strobe_b            (rx_mode_strobe_b),
    .mode_exit_b                 (mode_exit_b),
    .stream_start_b              (stream_start_b),
    .channel_enable_b            (channel_enable_b),
    .dma_s2mm_pkt_per_burst_b    (dma_s2mm_pkt_per_burst_b),
    .tx_samples_per_packet_b     (tx_samples_per_packet_b),
    .tx_source_sel_b             (tx_source_sel_b),
    .ignore_tx_timestamps_b      (ignore_tx_timestamps_b),
    .noise_idx_start_b           (noise_idx_start_b),
    .noise_idx_end_b             (noise_idx_end_b),
    .noise_cfg_update_b          (noise_cfg_update_b),
    .tx_dds_freq_ctrl_word_b     (tx_dds_freq_ctrl_word_b),
    .fc_window_b                 (fc_window_b),
    .sync_in_b                   (sync_in_b),
    .user_bus_clk                (user_bus_clk),
    .user_bus_rst                (user_bus_rst),
    .user_bus_rx_tdata           (user_bus_rx_tdata),
    .user_bus_rx_tkeep           (user_bus_rx_tkeep),
    .user_bus_rx_tlast           (user_bus_rx_tlast),
    .user_bus_rx_tready          (user_bus_rx_tready),
    .user_bus_rx_tvalid          (user_bus_rx_tvalid),
    .user_bus_tx_tdata           (user_bus_tx_tdata),
    .user_bus_tx_tkeep           (user_bus_tx_tkeep),
    .user_bus_tx_tlast           (user_bus_tx_tlast),
    .user_bus_tx_tready          (user_bus_tx_tready),
    .user_bus_tx_tvalid          (user_bus_tx_tvalid)
  );

  chdr_epid_loopback #(
    .CHDR_W              (512),
    .IQ_CAPTURE_DST_EPID (16'h4002)
  ) chdr_dut (
    .clk             (user_bus_clk),
    .rst             (user_bus_rst),
    .s_axis_tdata    (s_axis_tdata),
    .s_axis_tlast    (s_axis_tlast),
    .s_axis_tvalid   (s_axis_tvalid),
    .s_axis_tready   (s_axis_tready),
    .iq_s_axis_tdata (user_bus_rx_tdata),
    .iq_s_axis_tkeep (user_bus_rx_tkeep),
    .iq_s_axis_tlast (user_bus_rx_tlast),
    .iq_s_axis_tvalid(user_bus_rx_tvalid),
    .iq_s_axis_tready(user_bus_rx_tready),
    .iq_clear        (mode_exit_b),
    .m_axis_tdata    (m_axis_tdata),
    .m_axis_tlast    (m_axis_tlast),
    .m_axis_tvalid   (m_axis_tvalid),
    .m_axis_tready   (m_axis_tready)
  );

  always @(posedge user_bus_clk) begin
    if (!user_bus_rst && user_bus_rx_tvalid && user_bus_rx_tready && user_bus_rx_tlast)
      wrapper_packet_count <= wrapper_packet_count + 1;
  end

  always @(posedge user_bus_clk) begin
    if (!user_bus_rst && m_axis_tvalid && m_axis_tready && m_axis_tlast)
      chdr_packet_count <= chdr_packet_count + 1;
  end

  task automatic wait_radio_cycles(input integer cycle_count);
    integer i;
    begin
      for (i = 0; i < cycle_count; i = i + 1)
        @(posedge radio_clk);
    end
  endtask

  task automatic wait_bus_cycles(input integer cycle_count);
    integer i;
    begin
      for (i = 0; i < cycle_count; i = i + 1)
        @(posedge user_bus_clk);
    end
  endtask

  task automatic pulse_capture_one_block;
    begin
      @(negedge user_bus_clk);
      capture_one_block_b <= 1'b1;
      repeat (CONTROL_STROBE_CYCLES) @(negedge user_bus_clk);
      capture_one_block_b <= 1'b0;
    end
  endtask

  task automatic pulse_stream_start;
    begin
      @(negedge user_bus_clk);
      stream_start_b <= 1'b1;
      repeat (CONTROL_STROBE_CYCLES) @(negedge user_bus_clk);
      stream_start_b <= 1'b0;
    end
  endtask

  task automatic pulse_rx_mode_strobe;
    begin
      @(negedge user_bus_clk);
      rx_mode_strobe_b <= 1'b1;
      repeat (CONTROL_STROBE_CYCLES) @(negedge user_bus_clk);
      rx_mode_strobe_b <= 1'b0;
    end
  endtask

  task automatic start_mode_exit_strobe;
    begin
      fork
        begin
          @(negedge user_bus_clk);
          mode_exit_b <= 1'b1;
          repeat (STOP_STROBE_CYCLES) @(negedge user_bus_clk);
          mode_exit_b <= 1'b0;
        end
      join_none
    end
  endtask

  task automatic send_sample(
    input [15:0] adc0_i,
    input [15:0] adc0_q,
    input [63:0] ts
  );
    begin
      @(negedge radio_clk);
      ch0_adc_i <= adc0_i;
      ch0_adc_q <= adc0_q;
      ch0_adc_valid <= 1'b1;
      @(negedge radio_clk);
      ch0_adc_valid <= 1'b0;
    end
  endtask

  task automatic send_samples(
    input integer sample_count,
    input [15:0] seed,
    input [63:0] start_time
  );
    integer i;
    begin
      for (i = 0; i < sample_count; i = i + 1)
        send_sample(seed + i[15:0], seed + i[15:0] + 16'h1000, start_time + i);
    end
  endtask

  task automatic wait_for_packet_count(
    input integer expected_wrapper_packets,
    input integer expected_chdr_packets,
    input integer timeout_cycles
  );
    integer timeout;
    begin
      timeout = 0;
      while ((((wrapper_packet_count - wrapper_packet_count_base) < expected_wrapper_packets) ||
              ((chdr_packet_count - chdr_packet_count_base) < expected_chdr_packets)) &&
             (timeout < timeout_cycles)) begin
        @(posedge user_bus_clk);
        timeout = timeout + 1;
      end
    end
  endtask

  initial begin
    integer wrapper_delta;
    integer chdr_delta;

    repeat (8) @(posedge radio_clk);
    radio_rst <= 1'b0;
    repeat (4) @(posedge user_bus_clk);
    user_bus_rst <= 1'b0;

    wait_bus_cycles(8);

    rx_mode_b <= STREAM_MODE;
    rx_sample_bytes_b <= 32'd256;
    max_sample_bytes_per_packet_b <= 32'd128;
    wait_bus_cycles(4);
    pulse_rx_mode_strobe();
    wait_bus_cycles(4);
    pulse_stream_start();
    wait_bus_cycles(4);
    send_samples(40, 16'h1000, 64'd1000);

    start_mode_exit_strobe();
    wait_bus_cycles(20);

    wrapper_packet_count_base = wrapper_packet_count;
    chdr_packet_count_base = chdr_packet_count;

    rx_mode_b <= PACKET_MODE;
    rx_sample_bytes_b <= REARM_CAPTURE_BYTES;
    max_sample_bytes_per_packet_b <= REARM_PACKET_BYTES;
    wait_bus_cycles(4);
    pulse_rx_mode_strobe();
    wait_bus_cycles(4);
    pulse_capture_one_block();
    wait_bus_cycles(4);

    send_samples(REARM_SAMPLE_COUNT, 16'h2000, 64'd10000);
    wait_bus_cycles(STOP_STROBE_CYCLES + 1200);

    wrapper_delta = wrapper_packet_count - wrapper_packet_count_base;
    chdr_delta = chdr_packet_count - chdr_packet_count_base;

    $display("INFO rearm_during_mode_exit wrapper_packets=%0d chdr_packets=%0d nominal_expected=%0d",
             wrapper_delta, chdr_delta, REARM_PACKET_COUNT);

    if (wrapper_delta == 0) begin
      $display("ERROR wrapper produced no packets after rearm");
      error_count = error_count + 1;
    end

    if (chdr_delta != wrapper_delta) begin
      $display("ERROR chdr packet mismatch during mode_exit overlap wrapper=%0d chdr=%0d",
               wrapper_delta, chdr_delta);
      error_count = error_count + 1;
    end

    if (error_count == 0)
      $display("TB_PASS t510_ai_iq_wrapper_mode_exit_rearm");
    else
      $display("TB_FAIL t510_ai_iq_wrapper_mode_exit_rearm error_count=%0d", error_count);

    $finish;
  end

endmodule

`default_nettype wire
