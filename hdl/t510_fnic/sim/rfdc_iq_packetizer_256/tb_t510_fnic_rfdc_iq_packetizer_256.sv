`timescale 1ns / 1ps
`default_nettype none

module tb_t510_fnic_rfdc_iq_packetizer_256;

  localparam [23:0] PACKET_BYTES = 24'd64;
  localparam [7:0]  SID          = 8'h5a;
  localparam integer TOTAL_SAMPLES = 24;
  localparam integer EXPECTED_BEATS = 4;

  reg          s_clk = 1'b0;
  reg          s_rst = 1'b1;
  reg  [15:0]  s_i_tdata = 16'd0;
  reg          s_i_tvalid = 1'b0;
  wire         s_i_tready;
  reg  [15:0]  s_q_tdata = 16'd0;
  reg          s_q_tvalid = 1'b0;
  wire         s_q_tready;

  reg          m_clk = 1'b0;
  reg          m_rst = 1'b1;
  reg          enable = 1'b0;
  reg          pause = 1'b0;
  wire [255:0] m_axis_tdata;
  wire         m_axis_tvalid;
  reg          m_axis_tready = 1'b1;

  wire [15:0]  packet_seq;
  wire [31:0]  packet_count;
  wire [31:0]  beat_count;
  wire [63:0]  sample_count;
  wire [15:0]  fifo_wr_occupancy;
  wire [15:0]  fifo_rd_occupancy;

  reg [255:0] expected [0:EXPECTED_BEATS-1];
  integer accepted_samples = 0;
  integer received_beats = 0;
  integer slot = 0;
  integer timeout_cycles = 0;
  reg     drive_enable = 1'b0;

  t510_fnic_rfdc_iq_packetizer_256 #(
    .PACKET_BYTES (PACKET_BYTES),
    .SID          (SID),
    .PACK_Q_HIGH  (1)
  ) dut (
    .s_clk             (s_clk),
    .s_rst             (s_rst),
    .s_i_tdata         (s_i_tdata),
    .s_i_tvalid        (s_i_tvalid),
    .s_i_tready        (s_i_tready),
    .s_q_tdata         (s_q_tdata),
    .s_q_tvalid        (s_q_tvalid),
    .s_q_tready        (s_q_tready),
    .m_clk             (m_clk),
    .m_rst             (m_rst),
    .enable            (enable),
    .pause             (pause),
    .m_axis_tdata      (m_axis_tdata),
    .m_axis_tvalid     (m_axis_tvalid),
    .m_axis_tready     (m_axis_tready),
    .packet_seq        (packet_seq),
    .packet_count      (packet_count),
    .beat_count        (beat_count),
    .sample_count      (sample_count),
    .fifo_wr_occupancy (fifo_wr_occupancy),
    .fifo_rd_occupancy (fifo_rd_occupancy)
  );

  always #5 s_clk = ~s_clk;
  always #4 m_clk = ~m_clk;

  initial begin
    build_expected_words();

    repeat (8) @(posedge s_clk);
    @(negedge s_clk);
    s_rst = 1'b0;

    repeat (8) @(posedge m_clk);
    @(negedge m_clk);
    m_rst = 1'b0;
    enable = 1'b1;
    drive_enable = 1'b1;
    s_i_tvalid = 1'b1;
    s_q_tvalid = 1'b1;
    s_i_tdata = i_sample(0);
    s_q_tdata = q_sample(0);

    wait (received_beats == 1);
    @(negedge m_clk);
    pause = 1'b1;
    repeat (6) begin
      @(posedge m_clk);
      if (m_axis_tvalid !== 1'b0)
        fail("m_axis_tvalid was not masked while pause was asserted");
    end
    @(negedge m_clk);
    pause = 1'b0;

    while (received_beats < EXPECTED_BEATS && timeout_cycles < 2000) begin
      @(posedge m_clk);
      timeout_cycles = timeout_cycles + 1;
    end

    if (received_beats != EXPECTED_BEATS)
      fail("timed out waiting for expected output beats");

    wait (accepted_samples == TOTAL_SAMPLES);
    repeat (10) @(posedge s_clk);

    if (packet_seq !== 16'd2)
      fail("packet_seq did not advance to 2");
    if (packet_count !== 32'd2)
      fail("packet_count did not advance to 2");
    if (beat_count !== 32'd4)
      fail("beat_count did not advance to 4");
    if (sample_count !== 64'd24)
      fail("sample_count did not advance to 24");

    $display("PASS: t510_fnic_rfdc_iq_packetizer_256 self-check completed");
    $finish;
  end

  always @(posedge s_clk) begin
    if (s_rst) begin
      accepted_samples <= 0;
      s_i_tvalid <= 1'b0;
      s_q_tvalid <= 1'b0;
      s_i_tdata <= i_sample(0);
      s_q_tdata <= q_sample(0);
    end else if (drive_enable && s_i_tvalid && s_q_tvalid &&
                 s_i_tready && s_q_tready) begin
      accepted_samples <= accepted_samples + 1;
      if (accepted_samples + 1 < TOTAL_SAMPLES) begin
        s_i_tdata <= i_sample(accepted_samples + 1);
        s_q_tdata <= q_sample(accepted_samples + 1);
      end else begin
        s_i_tvalid <= 1'b0;
        s_q_tvalid <= 1'b0;
      end
    end
  end

  always @(posedge m_clk) begin
    if (m_rst) begin
      received_beats <= 0;
    end else if (m_axis_tvalid && m_axis_tready) begin
      if (pause)
        fail("output handshake occurred while pause was asserted");
      if (received_beats >= EXPECTED_BEATS)
        fail("received more output beats than expected");
      if (m_axis_tdata !== expected[received_beats]) begin
        $display("Expected beat %0d: %064h", received_beats, expected[received_beats]);
        $display("Actual   beat %0d: %064h", received_beats, m_axis_tdata);
        fail("output beat payload mismatch");
      end
      received_beats <= received_beats + 1;
    end
  end

  task build_expected_words;
    begin
      expected[0] = 256'd0;
      expected[0][63:0] = {16'h5603, 16'd0, SID, PACKET_BYTES};
      expected[0][127:64] = 64'd0;
      for (slot = 0; slot < 4; slot = slot + 1)
        expected[0][128 + (slot * 32) +: 32] = iq_sample(slot);

      expected[1] = 256'd0;
      for (slot = 0; slot < 8; slot = slot + 1)
        expected[1][(slot * 32) +: 32] = iq_sample(4 + slot);

      expected[2] = 256'd0;
      expected[2][63:0] = {16'h5603, 16'd1, SID, PACKET_BYTES};
      expected[2][127:64] = 64'd12;
      for (slot = 0; slot < 4; slot = slot + 1)
        expected[2][128 + (slot * 32) +: 32] = iq_sample(12 + slot);

      expected[3] = 256'd0;
      for (slot = 0; slot < 8; slot = slot + 1)
        expected[3][(slot * 32) +: 32] = iq_sample(16 + slot);
    end
  endtask

  function [15:0] i_sample;
    input integer index;
    begin
      i_sample = 16'h1000 + index[15:0];
    end
  endfunction

  function [15:0] q_sample;
    input integer index;
    begin
      q_sample = 16'h2000 + index[15:0];
    end
  endfunction

  function [31:0] iq_sample;
    input integer index;
    begin
      iq_sample = {q_sample(index), i_sample(index)};
    end
  endfunction

  task fail;
    input [8*96-1:0] message;
    begin
      $display("FAIL: %0s", message);
      $fatal(1);
    end
  endtask

endmodule

`default_nettype wire
