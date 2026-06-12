`timescale 1ns / 1ps
`default_nettype none

module tb_t510_ai_iq_capture;

  localparam [1:0] STREAM_MODE = 2'd1;
  localparam [1:0] PACKET_MODE = 2'd2;
  localparam [31:0] IQ_MAGIC = 32'h5435_3151;
  localparam [7:0]  IQ_VERSION = 8'd1;

  reg         radio_clk = 1'b0;
  reg         radio_rst = 1'b1;
  reg  [15:0] ch0_adc_i = 16'd0;
  reg  [15:0] ch0_adc_q = 16'd0;
  reg         ch0_adc_valid = 1'b0;
  reg  [15:0] ch1_adc_i = 16'd0;
  reg  [15:0] ch1_adc_q = 16'd0;
  reg  [63:0] vita_time = 64'd0;
  reg  [7:0]  channel_enable = 8'd0;
  reg  [1:0]  rx_mode = PACKET_MODE;
  reg         rx_mode_strobe = 1'b0;
  reg         mode_exit = 1'b0;
  reg         stream_start = 1'b0;
  reg  [63:0] rx_sync_timestamp = 64'd0;
  reg         rx_sync_timestamp_strobe = 1'b0;
  reg         capture_one_block = 1'b0;
  reg  [31:0] rx_sample_bytes = 32'd0;
  reg  [31:0] max_sample_bytes_per_packet = 32'd0;
  wire        rx_tvalid;
  wire [63:0] rx_tdata;
  wire        rx_tlast;
  reg         rx_tready = 1'b1;

  integer actual_count = 0;
  integer error_count = 0;
  reg [63:0] actual_data [0:63];
  reg        actual_last [0:63];

  always #5 radio_clk = ~radio_clk;

  t510_ai_iq_capture dut (
    .radio_clk                   (radio_clk),
    .radio_rst                   (radio_rst),
    .ch0_adc_i                   (ch0_adc_i),
    .ch0_adc_q                   (ch0_adc_q),
    .ch0_adc_valid               (ch0_adc_valid),
    .ch1_adc_i                   (ch1_adc_i),
    .ch1_adc_q                   (ch1_adc_q),
    .vita_time                   (vita_time),
    .channel_enable              (channel_enable),
    .rx_mode                     (rx_mode),
    .rx_mode_strobe              (rx_mode_strobe),
    .mode_exit                   (mode_exit),
    .stream_start                (stream_start),
    .rx_sync_timestamp           (rx_sync_timestamp),
    .rx_sync_timestamp_strobe    (rx_sync_timestamp_strobe),
    .capture_one_block           (capture_one_block),
    .rx_sample_bytes             (rx_sample_bytes),
    .max_sample_bytes_per_packet (max_sample_bytes_per_packet),
    .rx_tvalid                   (rx_tvalid),
    .rx_tdata                    (rx_tdata),
    .rx_tlast                    (rx_tlast),
    .rx_tready                   (rx_tready)
  );

  always @(posedge radio_clk) begin
    if (!radio_rst && rx_tvalid && rx_tready) begin
      actual_data[actual_count] <= rx_tdata;
      actual_last[actual_count] <= rx_tlast;
      actual_count <= actual_count + 1;
    end
  end

  task automatic pulse_rx_mode(input [1:0] mode_value);
    begin
      @(negedge radio_clk);
      rx_mode <= mode_value;
      rx_mode_strobe <= 1'b1;
      @(negedge radio_clk);
      rx_mode_strobe <= 1'b0;
    end
  endtask

  task automatic pulse_capture_one_block;
    begin
      @(negedge radio_clk);
      capture_one_block <= 1'b1;
      @(negedge radio_clk);
      capture_one_block <= 1'b0;
    end
  endtask

  task automatic pulse_stream_start;
    begin
      @(negedge radio_clk);
      stream_start <= 1'b1;
      @(negedge radio_clk);
      stream_start <= 1'b0;
    end
  endtask

  task automatic pulse_mode_exit;
    begin
      @(negedge radio_clk);
      mode_exit <= 1'b1;
      @(negedge radio_clk);
      mode_exit <= 1'b0;
    end
  endtask

  task automatic send_sample(
    input [15:0] adc0_i,
    input [15:0] adc0_q,
    input [15:0] adc1_i,
    input [15:0] adc1_q,
    input [63:0] ts
  );
    begin
      @(negedge radio_clk);
      ch0_adc_i <= adc0_i;
      ch0_adc_q <= adc0_q;
      ch1_adc_i <= adc1_i;
      ch1_adc_q <= adc1_q;
      vita_time <= ts;
      ch0_adc_valid <= 1'b1;
      @(negedge radio_clk);
      ch0_adc_valid <= 1'b0;
    end
  endtask

  task automatic check_beat(
    input integer idx,
    input [63:0] expected_data,
    input        expected_last,
    input [255:0] label
  );
    begin
      if (actual_data[idx] !== expected_data) begin
        $display("ERROR %0s data mismatch at beat %0d exp=%016h got=%016h",
                 label, idx, expected_data, actual_data[idx]);
        error_count = error_count + 1;
      end
      if (actual_last[idx] !== expected_last) begin
        $display("ERROR %0s last mismatch at beat %0d exp=%0d got=%0d",
                 label, idx, expected_last, actual_last[idx]);
        error_count = error_count + 1;
      end
    end
  endtask

  task automatic wait_for_count(input integer expected_count);
    integer timeout;
    begin
      timeout = 0;
      while (actual_count < expected_count && timeout < 2000) begin
        @(posedge radio_clk);
        timeout = timeout + 1;
      end
      if (actual_count < expected_count) begin
        $display("ERROR timeout waiting for %0d beats, only got %0d", expected_count, actual_count);
        error_count = error_count + 1;
      end
    end
  endtask

  task automatic wait_cycles(input integer cycle_count);
    integer i;
    begin
      for (i = 0; i < cycle_count; i = i + 1) begin
        @(posedge radio_clk);
      end
    end
  endtask

  initial begin
    repeat (5) @(posedge radio_clk);
    radio_rst <= 1'b0;

    channel_enable <= 8'h03;
    rx_sample_bytes <= 32'd32;
    max_sample_bytes_per_packet <= 32'd16;
    pulse_rx_mode(PACKET_MODE);
    pulse_capture_one_block();

    send_sample(16'h0011, 16'h0022, 16'h0033, 16'h0044, 64'd100);
    send_sample(16'h0055, 16'h0066, 16'h0077, 16'h0088, 64'd101);
    send_sample(16'h0099, 16'h00aa, 16'h00bb, 16'h00cc, 64'd102);
    send_sample(16'h00dd, 16'h00ee, 16'h00ff, 16'h0110, 64'd103);

    wait_for_count(8);

    check_beat(0, {IQ_MAGIC, IQ_VERSION, 8'h03, 16'd16}, 1'b0, "pkt0_head0");
    check_beat(1, 64'd99, 1'b0, "pkt0_head1");
    check_beat(2, {16'h0044,16'h0033,16'h0022,16'h0011}, 1'b0, "pkt0_data0");
    check_beat(3, {16'h0088,16'h0077,16'h0066,16'h0055}, 1'b1, "pkt0_data1");
    check_beat(4, {IQ_MAGIC, IQ_VERSION, 8'h03, 16'd16}, 1'b0, "pkt1_head0");
    check_beat(5, 64'd101, 1'b0, "pkt1_head1");
    check_beat(6, {16'h00cc,16'h00bb,16'h00aa,16'h0099}, 1'b0, "pkt1_data0");
    check_beat(7, {16'h0110,16'h00ff,16'h00ee,16'h00dd}, 1'b1, "pkt1_data1");

    rx_sample_bytes <= 32'd24;
    max_sample_bytes_per_packet <= 32'd24;
    pulse_rx_mode(STREAM_MODE);
    pulse_stream_start();

    send_sample(16'h1001, 16'h1002, 16'h1003, 16'h1004, 64'd200);
    send_sample(16'h1005, 16'h1006, 16'h1007, 16'h1008, 64'd201);
    send_sample(16'h1009, 16'h100a, 16'h100b, 16'h100c, 64'd202);
    send_sample(16'h1011, 16'h1012, 16'h1013, 16'h1014, 64'd203);
    send_sample(16'h1015, 16'h1016, 16'h1017, 16'h1018, 64'd204);
    send_sample(16'h1019, 16'h101a, 16'h101b, 16'h101c, 64'd205);

    wait_for_count(18);

    check_beat(8,  {IQ_MAGIC, IQ_VERSION, 8'h03, 16'd24}, 1'b0, "stream0_head0");
    check_beat(9,  64'd199, 1'b0, "stream0_head1");
    check_beat(10, {16'h1004,16'h1003,16'h1002,16'h1001}, 1'b0, "stream0_data0");
    check_beat(11, {16'h1008,16'h1007,16'h1006,16'h1005}, 1'b0, "stream0_data1");
    check_beat(12, {16'h100c,16'h100b,16'h100a,16'h1009}, 1'b1, "stream0_data2");
    check_beat(13, {IQ_MAGIC, IQ_VERSION, 8'h03, 16'd24}, 1'b0, "stream1_head0");
    check_beat(14, 64'd202, 1'b0, "stream1_head1");
    check_beat(15, {16'h1014,16'h1013,16'h1012,16'h1011}, 1'b0, "stream1_data0");
    check_beat(16, {16'h1018,16'h1017,16'h1016,16'h1015}, 1'b0, "stream1_data1");
    check_beat(17, {16'h101c,16'h101b,16'h101a,16'h1019}, 1'b1, "stream1_data2");

    pulse_mode_exit();
    send_sample(16'h2001, 16'h2002, 16'h2003, 16'h2004, 64'd300);
    repeat (10) @(posedge radio_clk);
    if (actual_count != 18) begin
      $display("ERROR mode_exit should stop new stream chunks, got beat count %0d", actual_count);
      error_count = error_count + 1;
    end

    channel_enable <= 8'h01;
    rx_sample_bytes <= 32'd16;
    max_sample_bytes_per_packet <= 32'd16;
    pulse_rx_mode(PACKET_MODE);
    pulse_capture_one_block();

    send_sample(16'h3001, 16'h3002, 16'h0000, 16'h0000, 64'd400);
    send_sample(16'h3003, 16'h3004, 16'h0000, 16'h0000, 64'd401);
    send_sample(16'h3005, 16'h3006, 16'h0000, 16'h0000, 64'd402);
    send_sample(16'h3007, 16'h3008, 16'h0000, 16'h0000, 64'd403);

    wait_for_count(22);

    check_beat(18, {IQ_MAGIC, IQ_VERSION, 8'h01, 16'd16}, 1'b0, "single_head0");
    check_beat(19, 64'd399, 1'b0, "single_head1");
    check_beat(20, {16'h3004,16'h3003,16'h3002,16'h3001}, 1'b0, "single_data0");
    check_beat(21, {16'h3008,16'h3007,16'h3006,16'h3005}, 1'b1, "single_data1");

    channel_enable <= 8'h03;
    rx_sample_bytes <= 32'd24;
    max_sample_bytes_per_packet <= 32'd16;
    pulse_rx_mode(PACKET_MODE);
    pulse_capture_one_block();

    rx_tready <= 1'b0;
    send_sample(16'h4001, 16'h4002, 16'h4003, 16'h4004, 64'd500);
    send_sample(16'h4005, 16'h4006, 16'h4007, 16'h4008, 64'd501);
    send_sample(16'h4009, 16'h400a, 16'h400b, 16'h400c, 64'd502);
    wait_cycles(8);
    pulse_mode_exit();
    wait_cycles(4);
    rx_tready <= 1'b1;
    wait_cycles(8);
    if (actual_count != 22) begin
      $display("ERROR mode_exit during blocked packet should discard stale state, got beat count %0d", actual_count);
      error_count = error_count + 1;
    end

    channel_enable <= 8'h01;
    rx_sample_bytes <= 32'd16;
    max_sample_bytes_per_packet <= 32'd16;
    pulse_rx_mode(PACKET_MODE);
    pulse_capture_one_block();

    send_sample(16'h5001, 16'h5002, 16'h0000, 16'h0000, 64'd600);
    send_sample(16'h5003, 16'h5004, 16'h0000, 16'h0000, 64'd601);
    send_sample(16'h5005, 16'h5006, 16'h0000, 16'h0000, 64'd602);
    send_sample(16'h5007, 16'h5008, 16'h0000, 16'h0000, 64'd603);

    wait_for_count(26);

    check_beat(22, {IQ_MAGIC, IQ_VERSION, 8'h01, 16'd16}, 1'b0, "recovery_head0");
    check_beat(23, 64'd599, 1'b0, "recovery_head1");
    check_beat(24, {16'h5004,16'h5003,16'h5002,16'h5001}, 1'b0, "recovery_data0");
    check_beat(25, {16'h5008,16'h5007,16'h5006,16'h5005}, 1'b1, "recovery_data1");

    if (error_count == 0) begin
      $display("TB_PASS t510_ai_iq_capture");
    end else begin
      $display("TB_FAIL t510_ai_iq_capture error_count=%0d", error_count);
    end

    $finish;
  end

endmodule

`default_nettype wire
