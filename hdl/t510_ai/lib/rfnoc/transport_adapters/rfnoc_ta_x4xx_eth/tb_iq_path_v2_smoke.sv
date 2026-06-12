`timescale 1ns / 1ps
`default_nettype none

module tb_iq_path_v2_smoke;

  localparam [1:0] PACKET_MODE = 2'd2;
  localparam [31:0] IQ_MAGIC   = 32'h5435_3151;
  localparam [7:0]  IQ_VERSION = 8'd1;

  reg         radio_clk = 1'b0;
  reg         user_bus_clk = 1'b0;
  reg         radio_rst = 1'b1;
  reg         user_bus_rst = 1'b1;
  reg         clear = 1'b0;
  reg         pps = 1'b0;
  reg  [15:0] ch0_adc_i = 16'd0;
  reg  [15:0] ch0_adc_q = 16'd1;
  reg         ch0_adc_valid = 1'b0;
  reg  [15:0] ch1_adc_i = 16'd0;
  reg  [15:0] ch1_adc_q = 16'd0;
  reg  [63:0] set_vita_timestamp_b = 64'd0;
  reg  [2:0]  set_time_mode_b = 3'd0;
  reg         time_mode_strobe_b = 1'b0;
  reg  [31:0] rx_sample_bytes_b = 32'd1024;
  reg  [31:0] max_sample_bytes_per_packet_b = 32'd256;
  reg         capture_one_block_b = 1'b0;
  reg  [63:0] rx_sync_timestamp_b = 64'd0;
  reg         rx_sync_timestamp_strobe_b = 1'b0;
  reg  [1:0]  rx_mode_b = PACKET_MODE;
  reg         rx_mode_strobe_b = 1'b0;
  reg         mode_exit_b = 1'b0;
  reg         stream_start_b = 1'b0;
  reg  [7:0]  channel_enable_b = 8'h01;
  reg         sync_in_b = 1'b0;

  wire [63:0] iq_tdata;
  wire [7:0]  iq_tkeep;
  wire        iq_tlast;
  wire        iq_tvalid;
  wire        iq_tready;
  wire        capture_idle_b;
  wire        stop_done_b;

  reg  [511:0] s_axis_tdata = '0;
  reg          s_axis_tlast = 1'b0;
  reg          s_axis_tvalid = 1'b0;
  wire         s_axis_tready;

  wire [511:0] m_axis_tdata;
  wire         m_axis_tlast;
  wire         m_axis_tvalid;
  reg          m_axis_tready = 1'b1;
  wire         iq_idle;
  wire         iq_stop_done;

  integer iq_packets = 0;
  integer chdr_packets = 0;
  integer error_count = 0;
  reg     capture_stop_seen = 1'b0;
  reg     bridge_stop_seen = 1'b0;
  integer chdr_beat_index = 0;
  reg     chdr_magic_checked = 1'b0;

  always #2 radio_clk = ~radio_clk;
  always #5 user_bus_clk = ~user_bus_clk;

  iq_framework_rx_wrapper_v2 dut_rx (
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
    .set_vita_timestamp_b        (set_vita_timestamp_b),
    .set_time_mode_b             (set_time_mode_b),
    .time_mode_strobe_b          (time_mode_strobe_b),
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
    .sync_in_b                   (sync_in_b),
    .user_bus_clk                (user_bus_clk),
    .user_bus_rst                (user_bus_rst),
    .user_bus_rx_tdata           (iq_tdata),
    .user_bus_rx_tkeep           (iq_tkeep),
    .user_bus_rx_tlast           (iq_tlast),
    .user_bus_rx_tready          (iq_tready),
    .user_bus_rx_tvalid          (iq_tvalid),
    .capture_idle_b              (capture_idle_b),
    .stop_done_b                 (stop_done_b)
  );

  chdr_epid_split_v2 #(
    .CHDR_W              (512),
    .IQ_CAPTURE_DST_EPID (16'h4002)
  ) dut_split (
    .clk             (user_bus_clk),
    .rst             (user_bus_rst),
    .s_axis_tdata    (s_axis_tdata),
    .s_axis_tlast    (s_axis_tlast),
    .s_axis_tvalid   (s_axis_tvalid),
    .s_axis_tready   (s_axis_tready),
    .iq_s_axis_tdata (iq_tdata),
    .iq_s_axis_tkeep (iq_tkeep),
    .iq_s_axis_tlast (iq_tlast),
    .iq_s_axis_tvalid(iq_tvalid),
    .iq_s_axis_tready(iq_tready),
    .iq_clear        (mode_exit_b),
    .m_axis_tdata    (m_axis_tdata),
    .m_axis_tlast    (m_axis_tlast),
    .m_axis_tvalid   (m_axis_tvalid),
    .m_axis_tready   (m_axis_tready),
    .iq_idle         (iq_idle),
    .iq_stop_done    (iq_stop_done)
  );

  always @(posedge user_bus_clk) begin
    if (!user_bus_rst && iq_tvalid && iq_tready && iq_tlast)
      iq_packets <= iq_packets + 1;
    if (!user_bus_rst && m_axis_tvalid && m_axis_tready) begin
      if (chdr_beat_index == 1) begin
        chdr_magic_checked <= 1'b1;
        if (m_axis_tdata[63:32] != IQ_MAGIC) begin
          $display("TB_FAIL: CHDR IQ payload magic mismatch: got %08x expected %08x",
                   m_axis_tdata[63:32], IQ_MAGIC);
          error_count = error_count + 1;
        end
        if (m_axis_tdata[31:24] != IQ_VERSION) begin
          $display("TB_FAIL: CHDR IQ payload version mismatch: got %0d expected %0d",
                   m_axis_tdata[31:24], IQ_VERSION);
          error_count = error_count + 1;
        end
      end

      if (m_axis_tlast) begin
        chdr_packets <= chdr_packets + 1;
        chdr_beat_index <= 0;
      end else begin
        chdr_beat_index <= chdr_beat_index + 1;
      end
    end
    if (!user_bus_rst && stop_done_b)
      capture_stop_seen <= 1'b1;
    if (!user_bus_rst && iq_stop_done)
      bridge_stop_seen <= 1'b1;
  end

  task automatic wait_radio_cycles(input integer cycles);
    integer i;
    begin
      for (i = 0; i < cycles; i = i + 1)
        @(posedge radio_clk);
    end
  endtask

  task automatic wait_user_cycles(input integer cycles);
    integer i;
    begin
      for (i = 0; i < cycles; i = i + 1)
        @(posedge user_bus_clk);
    end
  endtask

  task automatic pulse_capture_one_block;
    begin
      @(negedge user_bus_clk);
      capture_one_block_b <= 1'b1;
      repeat (8) @(negedge user_bus_clk);
      capture_one_block_b <= 1'b0;
    end
  endtask

  initial begin
    wait_radio_cycles(8);
    radio_rst = 1'b0;
    wait_user_cycles(4);
    user_bus_rst = 1'b0;

    ch0_adc_valid = 1'b1;
    fork
      begin : adc_drive
        integer n;
        for (n = 0; n < 5000; n = n + 1) begin
          @(posedge radio_clk);
          ch0_adc_i <= ch0_adc_i + 16'd1;
          ch0_adc_q <= ch0_adc_q + 16'd1;
        end
      end
      begin : control_flow
        pulse_capture_one_block();
        wait_user_cycles(300);
        @(negedge user_bus_clk);
        mode_exit_b <= 1'b1;
        repeat (20) @(negedge user_bus_clk);
        mode_exit_b <= 1'b0;
      end
    join

    wait_user_cycles(300);

    if (iq_packets == 0) begin
      $display("TB_FAIL: no IQ packets observed");
      error_count = error_count + 1;
    end
    if (chdr_packets == 0) begin
      $display("TB_FAIL: no CHDR packets observed");
      error_count = error_count + 1;
    end
    if (!capture_idle_b || !iq_idle) begin
      $display("TB_FAIL: path not idle after stop (capture_idle=%0d iq_idle=%0d)", capture_idle_b, iq_idle);
      error_count = error_count + 1;
    end
    if (!capture_stop_seen || !bridge_stop_seen) begin
      $display("TB_FAIL: stop_done not observed (capture=%0d bridge=%0d)", capture_stop_seen, bridge_stop_seen);
      error_count = error_count + 1;
    end
    if (chdr_packets > iq_packets) begin
      $display("TB_FAIL: CHDR packets exceeded IQ packets (%0d > %0d)", chdr_packets, iq_packets);
      error_count = error_count + 1;
    end
    if (!chdr_magic_checked) begin
      $display("TB_FAIL: CHDR payload header was never checked");
      error_count = error_count + 1;
    end

    if (error_count == 0) begin
      $display("TB_PASS iq_packets=%0d chdr_packets=%0d", iq_packets, chdr_packets);
    end else begin
      $display("TB_FAIL error_count=%0d", error_count);
      $fatal(1);
    end
    $finish;
  end

endmodule

`default_nettype wire
