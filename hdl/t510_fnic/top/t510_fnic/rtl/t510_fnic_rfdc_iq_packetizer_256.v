`timescale 1ns / 1ps
`default_nettype none

module t510_fnic_rfdc_iq_packetizer_256 #(
  parameter [23:0] PACKET_BYTES = 24'd8192,
  parameter [7:0]  SID          = 8'd0,
  parameter        PACK_Q_HIGH  = 1
) (
  input  wire         s_clk,
  input  wire         s_rst,
  input  wire [15:0]  s_i_tdata,
  input  wire         s_i_tvalid,
  output wire         s_i_tready,
  input  wire [15:0]  s_q_tdata,
  input  wire         s_q_tvalid,
  output wire         s_q_tready,

  input  wire         m_clk,
  input  wire         m_rst,
  input  wire         enable,
  input  wire         pause,
  output wire [255:0] m_axis_tdata,
  output wire         m_axis_tvalid,
  input  wire         m_axis_tready,

  output reg  [15:0]  packet_seq,
  output reg  [31:0]  packet_count,
  output reg  [31:0]  beat_count,
  output reg  [63:0]  sample_count,
  output wire [15:0]  fifo_wr_occupancy,
  output wire [15:0]  fifo_rd_occupancy
);

  localparam [15:0] MAGIC_TYPE_RX_DATA = 16'h5603;
  localparam integer BYTES_PER_BEAT = 32;
  localparam integer PREFIX_BYTES = 16;
  localparam integer REQUESTED_PACKET_BYTES_INT = {8'd0, PACKET_BYTES};
  localparam integer SAFE_PACKET_BYTES_INT =
    (REQUESTED_PACKET_BYTES_INT < 32) ? 32 :
    ((REQUESTED_PACKET_BYTES_INT / BYTES_PER_BEAT) * BYTES_PER_BEAT);
  localparam [23:0] SAFE_PACKET_BYTES = SAFE_PACKET_BYTES_INT[23:0];
  localparam integer FIRST_BEAT_SAMPLES = 4;
  localparam integer DATA_BEAT_SAMPLES = 8;
  localparam integer PACKET_BEATS = SAFE_PACKET_BYTES_INT / BYTES_PER_BEAT;

  // RFDC gives I and Q as independent 16-bit AXIS-like streams.  The small
  // hold registers pair one I sample with one Q sample before packing them
  // into a 32-bit IQ word.
  reg [15:0] i_hold = 16'd0;
  reg [15:0] q_hold = 16'd0;
  reg        i_hold_valid = 1'b0;
  reg        q_hold_valid = 1'b0;

  reg [255:0] beat_word = 256'd0;
  reg [31:0]  beat_index = 32'd0;
  reg [2:0]   sample_slot = 3'd0;
  reg [255:0] fifo_s_tdata = 256'd0;
  reg         fifo_s_tvalid = 1'b0;

  wire        fifo_s_tready;
  wire [255:0] fifo_m_tdata;
  wire         fifo_m_tvalid;
  wire         fifo_m_tready;
  wire         output_ready;
  wire         sample_ready;
  wire         sample_available;
  wire         sample_fire;
  wire [31:0] sample_word;
  wire [63:0] next_header;
  wire [63:0] next_sample_count;
  wire        i_accept;
  wire        q_accept;
  wire        first_beat;
  wire        last_sample_in_beat;
  wire        last_beat_in_packet;
  wire [2:0]  samples_this_beat;
  wire [7:0]  sample_bit_base;

  assign sample_word = PACK_Q_HIGH ? {q_hold, i_hold} : {i_hold, q_hold};
  assign sample_available = i_hold_valid && q_hold_valid;
  assign output_ready = !fifo_s_tvalid || fifo_s_tready;
  assign sample_ready = output_ready;
  assign sample_fire = sample_available && sample_ready;
  assign s_i_tready = !i_hold_valid || sample_fire;
  assign s_q_tready = !q_hold_valid || sample_fire;
  assign i_accept = s_i_tvalid && s_i_tready;
  assign q_accept = s_q_tvalid && s_q_tready;
  assign first_beat = (beat_index == 32'd0);
  assign samples_this_beat = first_beat ? FIRST_BEAT_SAMPLES[2:0] : DATA_BEAT_SAMPLES[2:0];
  assign last_sample_in_beat = (sample_slot == samples_this_beat - 1'b1);
  assign last_beat_in_packet = (beat_index == PACKET_BEATS - 1);
  assign sample_bit_base = first_beat ? (8'd128 + {sample_slot, 5'b00000}) :
                                       {sample_slot, 5'b00000};
  assign next_header = {MAGIC_TYPE_RX_DATA, packet_seq + 1'b1, SID, SAFE_PACKET_BYTES};
  assign next_sample_count = sample_count + 1'b1;

  // Flow-control from FNIC gates only the Aurora side of the FIFO.  The RFDC
  // side can keep filling until FIFO backpressure reaches s_i/s_q_tready.
  assign fifo_m_tready = enable && !pause && m_axis_tready;
  assign m_axis_tdata = fifo_m_tdata;
  assign m_axis_tvalid = enable && !pause && fifo_m_tvalid;

  always @(posedge s_clk) begin
    if (s_rst) begin
      i_hold <= 16'd0;
      q_hold <= 16'd0;
      i_hold_valid <= 1'b0;
      q_hold_valid <= 1'b0;
    end else begin
      if (i_accept) begin
        i_hold <= s_i_tdata;
      end
      if (q_accept) begin
        q_hold <= s_q_tdata;
      end
      if (sample_fire) begin
        i_hold_valid <= i_accept;
        q_hold_valid <= q_accept;
      end else begin
        if (i_accept)
          i_hold_valid <= 1'b1;
        if (q_accept)
          q_hold_valid <= 1'b1;
      end
    end
  end

  // First beat layout:
  //   [63:0]   = {magic=0x5603, seq, sid, packet_bytes}
  //   [127:64] = first sample counter
  //   [255:128]= 4 IQ samples
  // Later beats carry 8 IQ samples with no header.
  always @(posedge s_clk) begin
    if (s_rst) begin
      beat_word <= {128'd0, 64'd0, {MAGIC_TYPE_RX_DATA, 16'd0, SID, SAFE_PACKET_BYTES}};
      beat_index <= 32'd0;
      sample_slot <= 3'd0;
      fifo_s_tdata <= 256'd0;
      fifo_s_tvalid <= 1'b0;
      packet_seq <= 16'd0;
      packet_count <= 32'd0;
      beat_count <= 32'd0;
      sample_count <= 64'd0;
    end else begin
      if (fifo_s_tvalid && fifo_s_tready)
        fifo_s_tvalid <= 1'b0;

      if (sample_fire) begin
        sample_count <= sample_count + 1'b1;
        beat_word[sample_bit_base +: 32] <= sample_word;

        if (last_sample_in_beat) begin
          fifo_s_tdata <= set_sample_word(beat_word, sample_bit_base, sample_word);
          fifo_s_tvalid <= 1'b1;
          beat_count <= beat_count + 1'b1;
          sample_slot <= 3'd0;

          if (last_beat_in_packet) begin
            packet_seq <= packet_seq + 1'b1;
            packet_count <= packet_count + 1'b1;
            beat_index <= 32'd0;
            beat_word <= {128'd0, next_sample_count, next_header};
          end else begin
            beat_index <= beat_index + 1'b1;
            beat_word <= 256'd0;
          end
        end else begin
          sample_slot <= sample_slot + 1'b1;
        end
      end
    end
  end

  function [255:0] set_sample_word;
    input [255:0] word_in;
    input [7:0]   bit_base;
    input [31:0]  value;
    reg [255:0] tmp;
    begin
      tmp = word_in;
      tmp[bit_base +: 32] = value;
      set_sample_word = tmp;
    end
  endfunction

  // CDC from RFDC clock to Aurora user clock.  This is the only clock-domain
  // crossing in the RFDC RX IQ path.
  t510_fnic_axis_async_fifo_256 #(
    .ADDR_WIDTH(9),
    .DATA_WIDTH(256)
  ) packet_fifo_i (
    .s_clk         (s_clk),
    .s_rst         (s_rst),
    .s_axis_tdata  (fifo_s_tdata),
    .s_axis_tvalid (fifo_s_tvalid),
    .s_axis_tready (fifo_s_tready),
    .m_clk         (m_clk),
    .m_rst         (m_rst),
    .m_axis_tdata  (fifo_m_tdata),
    .m_axis_tvalid (fifo_m_tvalid),
    .m_axis_tready (fifo_m_tready),
    .wr_occupancy  (fifo_wr_occupancy),
    .rd_occupancy  (fifo_rd_occupancy)
  );

endmodule

`default_nettype wire
