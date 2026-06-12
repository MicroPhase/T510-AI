`timescale 1ns / 1ps
`default_nettype none

module tb_t510_fnic_aurora_tx_iq_player_256;

  localparam integer PACKET_BYTES = 256;
  localparam integer PACKET_BEATS = PACKET_BYTES / 32;
  localparam integer PAYLOAD_WORDS_PER_PACKET = (PACKET_BYTES - 16) / 4;
  localparam [23:0] PACKET_BYTES_24 = PACKET_BYTES[23:0];

  reg aurora_clk = 1'b0;
  reg dac_clk = 1'b0;
  reg rst = 1'b1;
  reg enable = 1'b0;
  reg [255:0] aurora_tdata = 256'd0;
  reg         aurora_tvalid = 1'b0;
  wire [31:0] dac_tdata;
  wire        dac_tvalid;
  reg         dac_tready = 1'b1;

  wire [15:0] fifo_wr_occupancy;
  wire [15:0] fifo_rd_occupancy;
  wire [31:0] aurora_tx_frame_count;
  wire [31:0] aurora_tx_beat_count;
  wire [31:0] aurora_tx_bad_magic_count;
  wire [31:0] aurora_tx_bad_length_count;
  wire [31:0] aurora_tx_drop_frame_count;
  wire [31:0] aurora_tx_overflow_count;
  wire [31:0] dac_sample_count;
  wire [31:0] dac_underflow_count;
  wire [23:0] current_packet_bytes;
  wire [1:0]  dbg_aurora_state;
  wire [15:0] dbg_aurora_beats_remaining;
  wire        dbg_fifo_s_tvalid;
  wire        dbg_fifo_s_tready;
  wire        dbg_fifo_m_tvalid;
  wire        dbg_fifo_m_tready;
  wire        dbg_playback_started;
  wire        dbg_beat_valid;
  wire [2:0]  dbg_word_index;
  wire        dbg_prefetched_valid;
  wire        dbg_prefetch_pending;
  wire        dbg_dac_play_enable;
  wire        dbg_dac_out_ready;
  wire        dbg_load_new_beat;
  wire        dbg_word_fire;
  wire        dbg_prefetch_issue;

  integer seq;
  integer beat;
  integer word;
  integer good_run;
  integer max_good_run;
  integer drops_after_streaming;
  reg streaming_started;

  always #4 aurora_clk = ~aurora_clk;
  always #5 dac_clk = ~dac_clk;

  t510_fnic_aurora_tx_iq_player_256 #(
    .MAX_PACKET_BYTES(24'd4096)
  ) u_dut (
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
    .aurora_tx_frame_count(aurora_tx_frame_count),
    .aurora_tx_beat_count(aurora_tx_beat_count),
    .aurora_tx_bad_magic_count(aurora_tx_bad_magic_count),
    .aurora_tx_bad_length_count(aurora_tx_bad_length_count),
    .aurora_tx_drop_frame_count(aurora_tx_drop_frame_count),
    .aurora_tx_overflow_count(aurora_tx_overflow_count),
    .dac_sample_count(dac_sample_count),
    .dac_underflow_count(dac_underflow_count),
    .last_header(),
    .last_timestamp(),
    .last_seq(),
    .last_sid(),
    .last_length(),
    .current_packet_bytes(current_packet_bytes),
    .dbg_aurora_state(dbg_aurora_state),
    .dbg_aurora_beats_remaining(dbg_aurora_beats_remaining),
    .dbg_fifo_s_tvalid(dbg_fifo_s_tvalid),
    .dbg_fifo_s_tready(dbg_fifo_s_tready),
    .dbg_fifo_m_tvalid(dbg_fifo_m_tvalid),
    .dbg_fifo_m_tready(dbg_fifo_m_tready),
    .dbg_playback_started(dbg_playback_started),
    .dbg_beat_valid(dbg_beat_valid),
    .dbg_word_index(dbg_word_index),
    .dbg_prefetched_valid(dbg_prefetched_valid),
    .dbg_prefetch_pending(dbg_prefetch_pending),
    .dbg_dac_play_enable(dbg_dac_play_enable),
    .dbg_dac_out_ready(dbg_dac_out_ready),
    .dbg_load_new_beat(dbg_load_new_beat),
    .dbg_word_fire(dbg_word_fire),
    .dbg_prefetch_issue(dbg_prefetch_issue)
  );

  task set_word;
    inout [255:0] v;
    input integer idx;
    input [31:0] value;
    begin
      v[idx * 32 +: 32] = value;
    end
  endtask

  function [31:0] sample_word;
    input [15:0] packet_seq;
    input integer beat_index;
    input integer word_index;
    begin
      sample_word = {packet_seq,
                     beat_index[7:0],
                     word_index[7:0]};
    end
  endfunction

  task send_packet;
    input [15:0] packet_seq;
    reg [255:0] v;
    begin
      for (beat = 0; beat < PACKET_BEATS; beat = beat + 1) begin
        v = 256'd0;
        if (beat == 0) begin
          v[63:0] = {16'h5604, packet_seq, 8'd0, PACKET_BYTES_24};
          v[127:64] = {48'd0, packet_seq};
          for (word = 4; word < 8; word = word + 1)
            set_word(v, word, sample_word(packet_seq, beat, word));
        end else begin
          for (word = 0; word < 8; word = word + 1)
            set_word(v, word, sample_word(packet_seq, beat, word));
        end
        @(posedge aurora_clk);
        aurora_tdata <= v;
        aurora_tvalid <= 1'b1;
      end
    end
  endtask

  always @(posedge dac_clk) begin
    if (rst || !enable) begin
      good_run <= 0;
      max_good_run <= 0;
      drops_after_streaming <= 0;
      streaming_started <= 1'b0;
    end else begin
      if (dac_sample_count >= PAYLOAD_WORDS_PER_PACKET)
        streaming_started <= 1'b1;

      if (dac_tvalid && dac_tready) begin
        good_run <= good_run + 1;
        if (good_run + 1 > max_good_run)
          max_good_run <= good_run + 1;
      end else begin
        if (streaming_started)
          drops_after_streaming <= drops_after_streaming + 1;
        good_run <= 0;
      end
    end
  end

  initial begin
    repeat (12) @(posedge aurora_clk);
    rst = 1'b0;
    enable = 1'b1;

    for (seq = 0; seq < 12; seq = seq + 1)
      send_packet(seq[15:0]);
    @(posedge aurora_clk);
    aurora_tvalid <= 1'b0;
    aurora_tdata <= 256'd0;

    wait (dac_sample_count >= 32'd512);
    repeat (10) @(posedge dac_clk);

    if (aurora_tx_bad_magic_count != 0 ||
        aurora_tx_bad_length_count != 0 ||
        aurora_tx_drop_frame_count != 0 ||
        aurora_tx_overflow_count != 0) begin
      $display("FAIL: parser counters bad magic=%0d length=%0d drop=%0d overflow=%0d",
               aurora_tx_bad_magic_count, aurora_tx_bad_length_count,
               aurora_tx_drop_frame_count, aurora_tx_overflow_count);
      $finish;
    end
    if (max_good_run < 256) begin
      $display("FAIL: DAC valid run too short: max_good_run=%0d drops=%0d",
               max_good_run, drops_after_streaming);
      $finish;
    end
    if (drops_after_streaming != 0) begin
      $display("FAIL: DAC valid dropped after streaming started: drops=%0d",
               drops_after_streaming);
      $finish;
    end

    $display("PASS: tx_iq_player continuous valid max_run=%0d samples=%0d fifo_wr=%0d fifo_rd=%0d",
             max_good_run, dac_sample_count, fifo_wr_occupancy, fifo_rd_occupancy);
    $finish;
  end

endmodule

`default_nettype wire
