`timescale 1ns / 1ps
`default_nettype none

module t510_fnic_aurora_rx_test_source_256 #(
  parameter [23:0] PACKET_BYTES = 24'd1040,
  parameter [7:0]  SID          = 8'd0,
  parameter [31:0] PACKET_GAP_CYCLES = 32'd0
) (
  input  wire         clk,
  input  wire         rst,
  input  wire         enable,
  input  wire         pause,

  output wire [255:0] m_axis_tdata,
  output wire         m_axis_tvalid,
  input  wire         m_axis_tready,

  output reg  [15:0]  packet_seq,
  output reg  [31:0]  packet_count,
  output reg  [31:0]  beat_count
);

  localparam [15:0] MAGIC_TYPE_RX_DATA = 16'h5603;
  localparam integer BYTES_PER_BEAT = 32;
  localparam integer PREFIX_BYTES = 16;
  localparam HAS_PACKET_GAP = (PACKET_GAP_CYCLES != 32'd0);

  localparam [23:0] SAFE_PACKET_BYTES =
    (PACKET_BYTES < PREFIX_BYTES) ? PREFIX_BYTES : PACKET_BYTES;

  localparam [31:0] PACKET_BEATS =
    (SAFE_PACKET_BYTES + BYTES_PER_BEAT - 1) / BYTES_PER_BEAT;

  reg [31:0] beat_index = 32'd0;
  reg [31:0] payload_word_base = 32'd0;
  reg [63:0] timestamp_counter = 64'd0;
  reg [31:0] gap_count = 32'd0;
  reg        valid_r = 1'b0;
  reg        gap_active = 1'b0;

  wire can_start_frame = !pause;
  wire frame_active = valid_r && (beat_index != 32'd0);
  wire axis_fire = valid_r && !gap_active && m_axis_tready &&
                   (frame_active || can_start_frame);
  wire last_beat = (beat_index == PACKET_BEATS - 1);

  wire [63:0] packet_header = {MAGIC_TYPE_RX_DATA, packet_seq, SID, SAFE_PACKET_BYTES};
  wire [255:0] tdata_native = (beat_index == 32'd0) ?
    {
      payload_word_base + 32'd3,
      payload_word_base + 32'd2,
      payload_word_base + 32'd1,
      payload_word_base + 32'd0,
      timestamp_counter,
      packet_header
    } :
    {
      payload_word_base + 32'd7,
      payload_word_base + 32'd6,
      payload_word_base + 32'd5,
      payload_word_base + 32'd4,
      payload_word_base + 32'd3,
      payload_word_base + 32'd2,
      payload_word_base + 32'd1,
      payload_word_base + 32'd0
    };

  assign m_axis_tdata = tdata_native;
  assign m_axis_tvalid = valid_r && !gap_active &&
                         (frame_active || can_start_frame);

  always @(posedge clk) begin
    if (rst || !enable) begin
      valid_r <= 1'b0;
    end else begin
      valid_r <= 1'b1;
    end
  end

  always @(posedge clk) begin
    if (rst || !enable) begin
      gap_active <= 1'b0;
      gap_count <= 32'd0;
    end else if (axis_fire && last_beat && HAS_PACKET_GAP) begin
      gap_active <= 1'b1;
      gap_count <= 32'd0;
    end else if (gap_active) begin
      if (gap_count >= PACKET_GAP_CYCLES - 1'b1) begin
        gap_active <= 1'b0;
        gap_count <= 32'd0;
      end else begin
        gap_count <= gap_count + 1'b1;
      end
    end
  end

  always @(posedge clk) begin
    if (rst || !enable) begin
      beat_index <= 32'd0;
    end else if (axis_fire) begin
      if (last_beat)
        beat_index <= 32'd0;
      else
        beat_index <= beat_index + 1'b1;
    end
  end

  always @(posedge clk) begin
    if (rst || !enable) begin
      packet_seq <= 16'd0;
      packet_count <= 32'd0;
      beat_count <= 32'd0;
      payload_word_base <= 32'd0;
      timestamp_counter <= 64'd0;
    end else if (axis_fire) begin
      beat_count <= beat_count + 1'b1;
      if (last_beat) begin
        packet_seq <= packet_seq + 1'b1;
        packet_count <= packet_count + 1'b1;
        timestamp_counter <= timestamp_counter + 64'd1;
        payload_word_base <= 32'd0;
      end else if (beat_index == 32'd0) begin
        payload_word_base <= payload_word_base + 32'd4;
      end else begin
        payload_word_base <= payload_word_base + 32'd8;
      end
    end
  end

endmodule

`default_nettype wire
