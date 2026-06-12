`timescale 1ns / 1ps
`default_nettype none

module t510_fnic_aurora_tx_sink_checker_256 #(
  parameter [15:0] AURORA_MAGIC_TX_DATA = 16'h5604,
  parameter [15:0] AURORA_MAGIC_FLOW    = 16'h5605,
  parameter [23:0] MAX_PACKET_BYTES     = 24'hfffff0
) (
  input  wire         clk,
  input  wire         rst,
  input  wire         enable,
  input  wire [255:0] s_axis_tdata,
  input  wire         s_axis_tvalid,

  output reg  [31:0]  frame_count,
  output reg  [31:0]  beat_count,
  output reg  [31:0]  bad_magic_count,
  output reg  [31:0]  bad_length_count,
  output reg  [31:0]  seq_jump_count,
  output reg  [31:0]  payload_error_count,
  output reg  [63:0]  last_header,
  output reg  [63:0]  last_timestamp,
  output reg  [15:0]  last_seq,
  output reg  [7:0]   last_sid,
  output reg  [23:0]  last_length,
  output reg          frame_active
);

  localparam integer BYTES_PER_BEAT = 32;
  localparam integer PREFIX_BYTES = 16;

  reg [31:0] beats_remaining = 32'd0;
  reg [15:0] expected_seq = 16'd0;
  reg        have_expected_seq = 1'b0;
  reg [31:0] expected_payload_word = 32'd0;

  wire [63:0] header = s_axis_tdata[63:0];
  wire [15:0] magic_type = header[63:48];
  wire [15:0] seq = header[47:32];
  wire [7:0]  sid = header[31:24];
  wire [23:0] length = header[23:0];
  wire [31:0] length_ext = {8'd0, length};
  wire [31:0] max_packet_bytes_ext = {8'd0, MAX_PACKET_BYTES};
  wire [31:0] packet_beats = (length_ext + BYTES_PER_BEAT - 1) >> 5;
  wire        length_ok = (length_ext >= PREFIX_BYTES) &&
                          (length_ext <= max_packet_bytes_ext) &&
                          (packet_beats != 32'd0);
  wire        magic_ok = (magic_type == AURORA_MAGIC_TX_DATA);
  wire        flow_frame = (magic_type == AURORA_MAGIC_FLOW);
  wire        seq_ok = !have_expected_seq || (seq == expected_seq);
  wire        input_fire = enable && s_axis_tvalid;
  wire        first_beat_payload_ok =
    (s_axis_tdata[159:128] == 32'd0) &&
    (s_axis_tdata[191:160] == 32'd1) &&
    (s_axis_tdata[223:192] == 32'd2) &&
    (s_axis_tdata[255:224] == 32'd3);
  wire        data_beat_payload_ok =
    (s_axis_tdata[31:0]    == expected_payload_word + 32'd0) &&
    (s_axis_tdata[63:32]   == expected_payload_word + 32'd1) &&
    (s_axis_tdata[95:64]   == expected_payload_word + 32'd2) &&
    (s_axis_tdata[127:96]  == expected_payload_word + 32'd3) &&
    (s_axis_tdata[159:128] == expected_payload_word + 32'd4) &&
    (s_axis_tdata[191:160] == expected_payload_word + 32'd5) &&
    (s_axis_tdata[223:192] == expected_payload_word + 32'd6) &&
    (s_axis_tdata[255:224] == expected_payload_word + 32'd7);

  always @(posedge clk) begin
    if (rst || !enable) begin
      frame_count <= 32'd0;
      beat_count <= 32'd0;
      bad_magic_count <= 32'd0;
      bad_length_count <= 32'd0;
      seq_jump_count <= 32'd0;
      payload_error_count <= 32'd0;
      last_header <= 64'd0;
      last_timestamp <= 64'd0;
      last_seq <= 16'd0;
      last_sid <= 8'd0;
      last_length <= 24'd0;
      frame_active <= 1'b0;
      beats_remaining <= 32'd0;
      expected_seq <= 16'd0;
      have_expected_seq <= 1'b0;
      expected_payload_word <= 32'd0;
    end else if (input_fire) begin
      beat_count <= beat_count + 1'b1;

      if (!frame_active && flow_frame) begin
        // Flow-control frames share the Aurora RX stream; TX sink ignores them.
      end else if (!frame_active) begin
        last_header <= header;
        last_timestamp <= s_axis_tdata[127:64];
        last_seq <= seq;
        last_sid <= sid;
        last_length <= length;

        if (!magic_ok)
          bad_magic_count <= bad_magic_count + 1'b1;
        if (!length_ok)
          bad_length_count <= bad_length_count + 1'b1;
        if (magic_ok && length_ok && !seq_ok)
          seq_jump_count <= seq_jump_count + 1'b1;
        if (magic_ok && length_ok && !first_beat_payload_ok)
          payload_error_count <= payload_error_count + 1'b1;

        if (magic_ok && length_ok) begin
          frame_count <= frame_count + 1'b1;
          expected_seq <= seq + 1'b1;
          have_expected_seq <= 1'b1;
          expected_payload_word <= 32'd4;
          if (packet_beats > 32'd1) begin
            frame_active <= 1'b1;
            beats_remaining <= packet_beats - 1'b1;
          end else begin
            frame_active <= 1'b0;
            beats_remaining <= 32'd0;
          end
        end else begin
          frame_active <= 1'b0;
          beats_remaining <= 32'd0;
          expected_payload_word <= 32'd0;
        end
      end else begin
        if (!data_beat_payload_ok)
          payload_error_count <= payload_error_count + 1'b1;

        expected_payload_word <= expected_payload_word + 32'd8;
        if (beats_remaining <= 32'd1) begin
          frame_active <= 1'b0;
          beats_remaining <= 32'd0;
          expected_payload_word <= 32'd0;
        end else begin
          beats_remaining <= beats_remaining - 1'b1;
        end
      end
    end
  end

endmodule

`default_nettype wire
