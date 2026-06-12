`timescale 1ns / 1ps
`default_nettype none

module tb_t510_fnic_tx_iq_player_flow_ctrl_256;

  localparam integer PACKET_BYTES = 81920;
  localparam integer PACKET_BEATS = PACKET_BYTES / 32;
  localparam [23:0] PACKET_BYTES_24 = PACKET_BYTES[23:0];
  localparam [15:0] EXPECTED_PAUSE_HIGH = 16'd4592;
  localparam [15:0] EXPECTED_RESUME_LOW = 16'd4096;

  reg aurora_clk = 1'b0;
  reg dac_clk = 1'b0;
  reg rst = 1'b1;
  reg enable = 1'b0;
  reg [255:0] aurora_tdata = 256'd0;
  reg         aurora_tvalid = 1'b0;
  reg         dac_tready = 1'b1;

  wire [31:0] dac_tdata;
  wire        dac_tvalid;
  wire [15:0] fifo_wr_occupancy;
  wire [15:0] fifo_rd_occupancy;
  wire [31:0] tx_frame_count;
  wire [31:0] tx_beat_count;
  wire [31:0] bad_magic_count;
  wire [31:0] bad_length_count;
  wire [31:0] drop_frame_count;
  wire [31:0] overflow_count;
  wire [31:0] dac_sample_count;
  wire [31:0] dac_underflow_count;
  wire [63:0] last_header;
  wire [23:0] current_packet_bytes;
  wire [255:0] flow_tdata;
  wire         flow_tvalid;
  wire         flow_pause;
  wire [31:0] flow_frame_count;

  wire [15:0] flow_magic = flow_tdata[63:48];
  wire [23:0] flow_length = flow_tdata[23:0];
  wire        flow_pause_bit = flow_tdata[176];
  wire [15:0] flow_resume_low = flow_tdata[175:160];
  wire [15:0] flow_pause_high = flow_tdata[159:144];
  wire [15:0] flow_fifo_level = flow_tdata[143:128];

  integer pkt;
  integer beat;
  integer pause_seen;
  integer max_fifo_level;

  always #4 aurora_clk = ~aurora_clk;
  always #5 dac_clk = ~dac_clk;

  t510_fnic_aurora_tx_iq_player_256 u_player (
    .aurora_clk(aurora_clk),
    .aurora_rst(rst),
    .aurora_enable(enable),
    .aurora_rx_tdata(aurora_tdata),
    .aurora_rx_tvalid(aurora_tvalid),
    .dac_clk(dac_clk),
    .dac_rst(rst),
    .dac_enable(enable),
    .m_dac_tdata(dac_tdata),
    .m_dac_tvalid(dac_tvalid),
    .m_dac_tready(dac_tready),
    .fifo_wr_occupancy(fifo_wr_occupancy),
    .fifo_rd_occupancy(fifo_rd_occupancy),
    .aurora_tx_frame_count(tx_frame_count),
    .aurora_tx_beat_count(tx_beat_count),
    .aurora_tx_bad_magic_count(bad_magic_count),
    .aurora_tx_bad_length_count(bad_length_count),
    .aurora_tx_drop_frame_count(drop_frame_count),
    .aurora_tx_overflow_count(overflow_count),
    .dac_sample_count(dac_sample_count),
    .dac_underflow_count(dac_underflow_count),
    .last_header(last_header),
    .last_timestamp(),
    .last_seq(),
    .last_sid(),
    .last_length(),
    .current_packet_bytes(current_packet_bytes),
    .dbg_aurora_state(),
    .dbg_aurora_beats_remaining(),
    .dbg_fifo_s_tvalid(),
    .dbg_fifo_s_tready(),
    .dbg_fifo_m_tvalid(),
    .dbg_fifo_m_tready(),
    .dbg_playback_started(),
    .dbg_beat_valid(),
    .dbg_word_index(),
    .dbg_prefetched_valid(),
    .dbg_prefetch_pending(),
    .dbg_dac_play_enable(),
    .dbg_dac_out_ready(),
    .dbg_load_new_beat(),
    .dbg_word_fire(),
    .dbg_prefetch_issue()
  );

  t510_fnic_aurora_flow_ctrl_tx_256 #(
    .PAUSE_HIGH_WATERMARK(16'd5632),
    .RESUME_LOW_WATERMARK(EXPECTED_RESUME_LOW),
    .PERIOD_CYCLES(32'd1024),
    .FIFO_DEPTH_BEATS(32'd8192),
    .FIFO_GUARD_BEATS(32'd16),
    .PAUSE_MARGIN_BEATS(32'd1024)
  ) u_flow (
    .clk(aurora_clk),
    .rst(rst),
    .enable(enable),
    .fifo_wr_level(fifo_wr_occupancy),
    .packet_bytes(current_packet_bytes),
    .link_up(1'b1),
    .m_axis_tdata(flow_tdata),
    .m_axis_tvalid(flow_tvalid),
    .m_axis_tready(1'b1),
    .flow_pause(flow_pause),
    .flow_frame_count(flow_frame_count)
  );

  always @(posedge aurora_clk) begin
    if (rst || !enable) begin
      max_fifo_level <= 0;
      pause_seen <= 0;
    end else begin
      if (fifo_wr_occupancy > max_fifo_level)
        max_fifo_level <= fifo_wr_occupancy;
      if (flow_tvalid && flow_pause_bit)
        pause_seen <= 1;
    end
  end

  task set_word;
    inout [255:0] v;
    input integer idx;
    input [31:0] value;
    begin
      v[idx * 32 +: 32] = value;
    end
  endtask

  task send_packet;
    input [15:0] seq;
    reg [255:0] beat_word;
    begin
      for (beat = 0; beat < PACKET_BEATS; beat = beat + 1) begin
        beat_word = 256'd0;
        if (beat == 0) begin
          beat_word[63:0] = {16'h5604, seq, 8'd0, PACKET_BYTES_24};
          beat_word[127:64] = {48'd0, seq};
          set_word(beat_word, 4, {seq, 16'h0004});
          set_word(beat_word, 5, {seq, 16'h0005});
          set_word(beat_word, 6, {seq, 16'h0006});
          set_word(beat_word, 7, {seq, 16'h0007});
        end else begin
          set_word(beat_word, 0, {seq, beat[15:0]});
          set_word(beat_word, 1, {seq, beat[15:0] + 16'd1});
          set_word(beat_word, 2, {seq, beat[15:0] + 16'd2});
          set_word(beat_word, 3, {seq, beat[15:0] + 16'd3});
          set_word(beat_word, 4, {seq, beat[15:0] + 16'd4});
          set_word(beat_word, 5, {seq, beat[15:0] + 16'd5});
          set_word(beat_word, 6, {seq, beat[15:0] + 16'd6});
          set_word(beat_word, 7, {seq, beat[15:0] + 16'd7});
        end
        aurora_tdata = beat_word;
        aurora_tvalid = 1'b1;
        @(posedge aurora_clk);
      end
      aurora_tvalid = 1'b0;
      aurora_tdata = 256'd0;
    end
  endtask

  initial begin
    pause_seen = 0;
    max_fifo_level = 0;

    repeat (16) @(posedge aurora_clk);
    rst = 1'b0;
    enable = 1'b1;
    repeat (8) @(posedge aurora_clk);

    for (pkt = 0; pkt < 8; pkt = pkt + 1)
      send_packet(pkt[15:0]);

    repeat (3000) @(posedge aurora_clk);

    if (current_packet_bytes != PACKET_BYTES_24) begin
      $display("FAIL: packet_bytes=%0d expected=%0d",
               current_packet_bytes, PACKET_BYTES);
      $finish;
    end
    if (max_fifo_level < EXPECTED_PAUSE_HIGH) begin
      $display("FAIL: FIFO never reached pause high max_fifo=%0d high=%0d",
               max_fifo_level, EXPECTED_PAUSE_HIGH);
      $finish;
    end
    if (!pause_seen || !flow_pause || flow_frame_count == 32'd0) begin
      $display("FAIL: no TX pause flow generated pause_seen=%0d pause=%0d count=%0d max_fifo=%0d",
               pause_seen, flow_pause, flow_frame_count, max_fifo_level);
      $finish;
    end
    if (flow_magic != 16'h5605 || flow_length != 24'd32 ||
        flow_pause_high != EXPECTED_PAUSE_HIGH ||
        flow_resume_low != EXPECTED_RESUME_LOW) begin
      $display("FAIL: bad flow frame magic=%h len=%0d high=%0d low=%0d fifo=%0d",
               flow_magic, flow_length, flow_pause_high, flow_resume_low,
               flow_fifo_level);
      $finish;
    end

    $display("PASS: player generated TX flow pause frames=%0d max_fifo=%0d high=%0d low=%0d drops=%0d overflow=%0d",
             flow_frame_count, max_fifo_level, flow_pause_high,
             flow_resume_low, drop_frame_count, overflow_count);
    $finish;
  end

endmodule

`default_nettype wire
