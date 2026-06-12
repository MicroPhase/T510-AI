`timescale 1ns / 1ps
`default_nettype none

module tb_t510_ai_iq_capture_to_chdr;

  localparam [1:0] PACKET_MODE = 2'd2;
  localparam [31:0] IQ_MAGIC = 32'h5435_3151;
  localparam [7:0]  IQ_VERSION = 8'd1;
  localparam [2:0]  CHDR_PKT_TYPE_DATA = 3'd6;
  localparam [15:0] IQ_CAPTURE_DST_EPID = 16'h4002;

  reg         clk = 1'b0;
  reg         rst = 1'b1;
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
  wire        iq_tvalid;
  wire [63:0] iq_tdata;
  wire        iq_tlast;
  wire        iq_tready;

  reg  [511:0] s_axis_tdata = 512'd0;
  reg          s_axis_tlast = 1'b0;
  reg          s_axis_tvalid = 1'b0;
  wire         s_axis_tready;

  wire [511:0] m_axis_tdata;
  wire         m_axis_tlast;
  wire         m_axis_tvalid;
  reg          m_axis_tready = 1'b1;

  integer actual_count = 0;
  integer error_count = 0;
  reg [511:0] actual_data [0:31];
  reg         actual_last [0:31];

  always #5 clk = ~clk;

  t510_ai_iq_capture capture_dut (
    .radio_clk                   (clk),
    .radio_rst                   (rst),
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
    .rx_tvalid                   (iq_tvalid),
    .rx_tdata                    (iq_tdata),
    .rx_tlast                    (iq_tlast),
    .rx_tready                   (iq_tready)
  );

  chdr_epid_loopback #(
    .CHDR_W               (512),
    .IQ_CAPTURE_DST_EPID  (IQ_CAPTURE_DST_EPID)
  ) chdr_dut (
    .clk            (clk),
    .rst            (rst),
    .s_axis_tdata   (s_axis_tdata),
    .s_axis_tlast   (s_axis_tlast),
    .s_axis_tvalid  (s_axis_tvalid),
    .s_axis_tready  (s_axis_tready),
    .iq_s_axis_tdata(iq_tdata),
    .iq_s_axis_tkeep(8'hff),
    .iq_s_axis_tlast(iq_tlast),
    .iq_s_axis_tvalid(iq_tvalid),
    .iq_s_axis_tready(iq_tready),
    .iq_clear      (mode_exit),
    .m_axis_tdata   (m_axis_tdata),
    .m_axis_tlast   (m_axis_tlast),
    .m_axis_tvalid  (m_axis_tvalid),
    .m_axis_tready  (m_axis_tready)
  );

  always @(posedge clk) begin
    if (!rst && m_axis_tvalid && m_axis_tready) begin
      actual_data[actual_count] <= m_axis_tdata;
      actual_last[actual_count] <= m_axis_tlast;
      actual_count <= actual_count + 1;
    end
  end

  function automatic [63:0] build_chdr_header(
    input [15:0] seq_num,
    input [15:0] length,
    input [15:0] dst_epid
  );
    begin
      build_chdr_header = {6'd0, 1'b0, 1'b0, CHDR_PKT_TYPE_DATA, 5'd0,
                           seq_num, length, dst_epid};
    end
  endfunction

  task automatic pulse_capture_one_block;
    begin
      @(negedge clk);
      capture_one_block <= 1'b1;
      @(negedge clk);
      capture_one_block <= 1'b0;
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
      @(negedge clk);
      ch0_adc_i <= adc0_i;
      ch0_adc_q <= adc0_q;
      ch1_adc_i <= adc1_i;
      ch1_adc_q <= adc1_q;
      vita_time <= ts;
      ch0_adc_valid <= 1'b1;
      @(negedge clk);
      ch0_adc_valid <= 1'b0;
    end
  endtask

  task automatic pulse_mode_exit;
    begin
      @(negedge clk);
      mode_exit <= 1'b1;
      @(negedge clk);
      mode_exit <= 1'b0;
    end
  endtask

  task automatic wait_cycles(input integer cycle_count);
    integer i;
    begin
      for (i = 0; i < cycle_count; i = i + 1) begin
        @(posedge clk);
      end
    end
  endtask

  task automatic wait_for_count(input integer expected_count);
    integer timeout;
    begin
      timeout = 0;
      while (actual_count < expected_count && timeout < 4000) begin
        @(posedge clk);
        timeout = timeout + 1;
      end
      if (actual_count < expected_count) begin
        $display("ERROR timeout waiting for %0d CHDR beats, only got %0d",
                 expected_count, actual_count);
        error_count = error_count + 1;
      end
    end
  endtask

  task automatic check_beat(
    input integer idx,
    input [511:0] expected_data,
    input         expected_last,
    input [255:0] label
  );
    begin
      if (actual_data[idx] !== expected_data) begin
        $display("ERROR %0s data mismatch at beat %0d", label, idx);
        $display("  exp=%0128h", expected_data);
        $display("  got=%0128h", actual_data[idx]);
        error_count = error_count + 1;
      end
      if (actual_last[idx] !== expected_last) begin
        $display("ERROR %0s last mismatch at beat %0d exp=%0d got=%0d",
                 label, idx, expected_last, actual_last[idx]);
        error_count = error_count + 1;
      end
    end
  endtask

  initial begin
    reg [511:0] exp_pkt0_head;
    reg [511:0] exp_pkt0_payload;
    reg [511:0] exp_pkt1_head;
    reg [511:0] exp_pkt1_payload;
    reg [511:0] exp_pkt2_head;
    reg [511:0] exp_pkt2_payload;

    repeat (5) @(posedge clk);
    rst <= 1'b0;

    channel_enable <= 8'h03;
    rx_sample_bytes <= 32'd32;
    max_sample_bytes_per_packet <= 32'd16;
    repeat (4) @(posedge clk);

    pulse_capture_one_block();

    send_sample(16'h0011, 16'h0022, 16'h0033, 16'h0044, 64'd100);
    send_sample(16'h0055, 16'h0066, 16'h0077, 16'h0088, 64'd101);
    send_sample(16'h0099, 16'h00aa, 16'h00bb, 16'h00cc, 64'd102);
    send_sample(16'h00dd, 16'h00ee, 16'h00ff, 16'h0110, 64'd103);

    wait_for_count(4);

    exp_pkt0_head = 512'd0;
    exp_pkt0_head[63:0] = build_chdr_header(16'd0, 16'd96, IQ_CAPTURE_DST_EPID);
    exp_pkt0_payload = 512'd0;
    exp_pkt0_payload[63:0]    = {IQ_MAGIC, IQ_VERSION, 8'h03, 16'd16};
    exp_pkt0_payload[127:64]  = 64'd99;
    exp_pkt0_payload[191:128] = {16'h0044,16'h0033,16'h0022,16'h0011};
    exp_pkt0_payload[255:192] = {16'h0088,16'h0077,16'h0066,16'h0055};

    exp_pkt1_head = 512'd0;
    exp_pkt1_head[63:0] = build_chdr_header(16'd1, 16'd96, IQ_CAPTURE_DST_EPID);
    exp_pkt1_payload = 512'd0;
    exp_pkt1_payload[63:0]    = {IQ_MAGIC, IQ_VERSION, 8'h03, 16'd16};
    exp_pkt1_payload[127:64]  = 64'd101;
    exp_pkt1_payload[191:128] = {16'h00cc,16'h00bb,16'h00aa,16'h0099};
    exp_pkt1_payload[255:192] = {16'h0110,16'h00ff,16'h00ee,16'h00dd};

    check_beat(0, exp_pkt0_head,    1'b0, "pkt0_head");
    check_beat(1, exp_pkt0_payload, 1'b1, "pkt0_payload");
    check_beat(2, exp_pkt1_head,    1'b0, "pkt1_head");
    check_beat(3, exp_pkt1_payload, 1'b1, "pkt1_payload");

    channel_enable <= 8'h01;
    rx_sample_bytes <= 32'd16;
    max_sample_bytes_per_packet <= 32'd16;
    repeat (4) @(posedge clk);

    pulse_capture_one_block();

    send_sample(16'h3001, 16'h3002, 16'h0000, 16'h0000, 64'd400);
    send_sample(16'h3003, 16'h3004, 16'h0000, 16'h0000, 64'd401);
    send_sample(16'h3005, 16'h3006, 16'h0000, 16'h0000, 64'd402);
    send_sample(16'h3007, 16'h3008, 16'h0000, 16'h0000, 64'd403);

    wait_for_count(6);

    exp_pkt2_head = 512'd0;
    exp_pkt2_head[63:0] = build_chdr_header(16'd2, 16'd96, IQ_CAPTURE_DST_EPID);
    exp_pkt2_payload = 512'd0;
    exp_pkt2_payload[63:0]    = {IQ_MAGIC, IQ_VERSION, 8'h01, 16'd16};
    exp_pkt2_payload[127:64]  = 64'd399;
    exp_pkt2_payload[191:128] = {16'h3004,16'h3003,16'h3002,16'h3001};
    exp_pkt2_payload[255:192] = {16'h3008,16'h3007,16'h3006,16'h3005};

    check_beat(4, exp_pkt2_head,    1'b0, "pkt2_head");
    check_beat(5, exp_pkt2_payload, 1'b1, "pkt2_payload");

    channel_enable <= 8'h03;
    rx_sample_bytes <= 32'd24;
    max_sample_bytes_per_packet <= 32'd16;
    repeat (4) @(posedge clk);
    pulse_capture_one_block();

    m_axis_tready <= 1'b0;
    send_sample(16'h4001, 16'h4002, 16'h4003, 16'h4004, 64'd500);
    send_sample(16'h4005, 16'h4006, 16'h4007, 16'h4008, 64'd501);
    send_sample(16'h4009, 16'h400a, 16'h400b, 16'h400c, 64'd502);
    wait_cycles(8);
    pulse_mode_exit();
    wait_cycles(4);
    m_axis_tready <= 1'b1;
    wait_cycles(8);
    if (actual_count != 8) begin
      $display("ERROR mode_exit should drain the in-flight CHDR packet, got beat count %0d", actual_count);
      error_count = error_count + 1;
    end

    exp_pkt2_head = 512'd0;
    exp_pkt2_head[63:0] = build_chdr_header(16'd3, 16'd96, IQ_CAPTURE_DST_EPID);
    exp_pkt2_payload = 512'd0;
    exp_pkt2_payload[63:0]    = {IQ_MAGIC, IQ_VERSION, 8'h03, 16'd16};
    exp_pkt2_payload[127:64]  = 64'd499;
    exp_pkt2_payload[191:128] = {16'h4004,16'h4003,16'h4002,16'h4001};
    exp_pkt2_payload[255:192] = {16'h4008,16'h4007,16'h4006,16'h4005};

    check_beat(6, exp_pkt2_head,    1'b0, "drain_head");
    check_beat(7, exp_pkt2_payload, 1'b1, "drain_payload");

    channel_enable <= 8'h01;
    rx_sample_bytes <= 32'd16;
    max_sample_bytes_per_packet <= 32'd16;
    repeat (4) @(posedge clk);
    pulse_capture_one_block();

    send_sample(16'h5001, 16'h5002, 16'h0000, 16'h0000, 64'd600);
    send_sample(16'h5003, 16'h5004, 16'h0000, 16'h0000, 64'd601);
    send_sample(16'h5005, 16'h5006, 16'h0000, 16'h0000, 64'd602);
    send_sample(16'h5007, 16'h5008, 16'h0000, 16'h0000, 64'd603);

    wait_for_count(10);

    exp_pkt2_head = 512'd0;
    exp_pkt2_head[63:0] = build_chdr_header(16'd4, 16'd96, IQ_CAPTURE_DST_EPID);
    exp_pkt2_payload = 512'd0;
    exp_pkt2_payload[63:0]    = {IQ_MAGIC, IQ_VERSION, 8'h01, 16'd16};
    exp_pkt2_payload[127:64]  = 64'd599;
    exp_pkt2_payload[191:128] = {16'h5004,16'h5003,16'h5002,16'h5001};
    exp_pkt2_payload[255:192] = {16'h5008,16'h5007,16'h5006,16'h5005};

    check_beat(8, exp_pkt2_head,    1'b0, "recovery_head");
    check_beat(9, exp_pkt2_payload, 1'b1, "recovery_payload");

    if (error_count == 0) begin
      $display("TB_PASS t510_ai_iq_capture_to_chdr");
    end else begin
      $display("TB_FAIL t510_ai_iq_capture_to_chdr error_count=%0d", error_count);
    end

    $finish;
  end

endmodule

`default_nettype wire
