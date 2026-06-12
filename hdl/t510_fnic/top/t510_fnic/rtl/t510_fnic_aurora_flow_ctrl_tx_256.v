`timescale 1ns / 1ps
`default_nettype none

module t510_fnic_aurora_flow_ctrl_tx_256 #(
  parameter [15:0] PAUSE_HIGH_WATERMARK = 16'd3072,
  parameter [15:0] RESUME_LOW_WATERMARK = 16'd1024,
  parameter [31:0] PERIOD_CYCLES        = 32'd1024,
  parameter [31:0] FIFO_DEPTH_BEATS     = 32'd8192,
  parameter [31:0] FIFO_GUARD_BEATS     = 32'd16,
  parameter [31:0] PAUSE_MARGIN_BEATS   = 32'd512
) (
  input  wire         clk,
  input  wire         rst,
  input  wire         enable,
  input  wire [15:0]  fifo_wr_level,
  input  wire [23:0]  packet_bytes,
  input  wire         link_up,

  output wire [255:0] m_axis_tdata,
  output wire         m_axis_tvalid,
  input  wire         m_axis_tready,

  output wire         flow_pause,
  output reg  [31:0]  flow_frame_count
);

  localparam [15:0] MAGIC_TYPE_AURORA_FLOW = 16'h5605;
  localparam [23:0] FLOW_FRAME_BYTES = 24'd32;

  reg         pause_r = 1'b0;
  reg         valid_r = 1'b0;
  reg [15:0]  seq_r = 16'd0;
  reg [31:0]  period_count_r = 32'd0;
  reg [63:0]  timestamp_r = 64'd0;
  reg [255:0] tdata_r = 256'd0;

  wire [31:0] packet_bytes_safe =
    (packet_bytes < 24'd16) ? 32'd16 : {8'd0, packet_bytes};
  wire [31:0] packet_beats = (packet_bytes_safe + 32'd31) >> 5;
  wire [31:0] required_headroom =
    packet_beats + FIFO_GUARD_BEATS + PAUSE_MARGIN_BEATS;
  wire [31:0] dynamic_pause_high =
    (FIFO_DEPTH_BEATS > required_headroom) ?
    (FIFO_DEPTH_BEATS - required_headroom) :
    ({16'd0, RESUME_LOW_WATERMARK} + 32'd1);
  wire [31:0] configured_pause_high = {16'd0, PAUSE_HIGH_WATERMARK};
  wire [31:0] selected_pause_high =
    (dynamic_pause_high < configured_pause_high) ?
    dynamic_pause_high : configured_pause_high;
  wire [31:0] min_pause_high = {16'd0, RESUME_LOW_WATERMARK} + 32'd1;
  wire [31:0] effective_pause_high =
    (selected_pause_high > min_pause_high) ? selected_pause_high :
                                             min_pause_high;
  wire [15:0] effective_pause_high_16 =
    (effective_pause_high > 32'hffff) ? 16'hffff :
                                        effective_pause_high[15:0];

  wire pause_next =
    pause_r ? (fifo_wr_level > RESUME_LOW_WATERMARK) :
              (fifo_wr_level >= effective_pause_high_16);
  wire pause_changed = (pause_next != pause_r);
  wire period_due = (period_count_r >= (PERIOD_CYCLES - 1'b1));
  wire send_due = enable && link_up && (pause_changed || period_due);
  wire axis_fire = valid_r && m_axis_tready;
  wire [15:0] next_frame_seq = axis_fire ? (seq_r + 1'b1) : seq_r;

  assign flow_pause = pause_r;
  assign m_axis_tdata = tdata_r;
  assign m_axis_tvalid = valid_r;

  always @(posedge clk) begin
    if (rst || !enable || !link_up) begin
      pause_r <= 1'b0;
      valid_r <= 1'b0;
      seq_r <= 16'd0;
      period_count_r <= 32'd0;
      timestamp_r <= 64'd0;
      tdata_r <= 256'd0;
      flow_frame_count <= 32'd0;
    end else begin
      timestamp_r <= timestamp_r + 1'b1;
      pause_r <= pause_next;

      if (period_due || pause_changed)
        period_count_r <= 32'd0;
      else
        period_count_r <= period_count_r + 1'b1;

      if (axis_fire) begin
        seq_r <= seq_r + 1'b1;
        flow_frame_count <= flow_frame_count + 1'b1;
      end

      // Coalesce pending flow frames while the TX mux is busy with an IQ
      // packet.  A pause edge must update the unsent frame instead of waiting
      // behind an older periodic resume/status frame.
      if (send_due) begin
        tdata_r <= {
          78'd0,
          enable,
          pause_next,
          RESUME_LOW_WATERMARK,
          effective_pause_high_16,
          fifo_wr_level,
          timestamp_r,
          MAGIC_TYPE_AURORA_FLOW,
          next_frame_seq,
          8'd0,
          FLOW_FRAME_BYTES
        };
        valid_r <= 1'b1;
      end else if (axis_fire) begin
        valid_r <= 1'b0;
      end
    end
  end

endmodule

`default_nettype wire
