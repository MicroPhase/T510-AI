`timescale 1ns / 1ps
`default_nettype none

module t510_fnic_aurora_flow_ctrl_rx_256 #(
  parameter [31:0] TIMEOUT_CYCLES = 32'd1000000
) (
  input  wire         clk,
  input  wire         rst,
  input  wire         enable,
  input  wire [255:0] s_axis_tdata,
  input  wire         s_axis_tvalid,

  output wire         remote_pause,
  output reg  [15:0]  remote_fifo_level,
  output reg  [15:0]  remote_pause_high,
  output reg  [15:0]  remote_resume_low,
  output reg  [31:0]  flow_frame_count,
  output reg  [31:0]  bad_flow_count,
  output reg          flow_seen
);

  localparam [15:0] MAGIC_TYPE_AURORA_FLOW = 16'h5605;
  localparam [23:0] FLOW_FRAME_BYTES = 24'd32;

  reg        remote_pause_r = 1'b0;
  reg [31:0] timeout_count_r = 32'd0;

  wire [63:0] header = s_axis_tdata[63:0];
  wire [15:0] magic_type = header[63:48];
  wire [23:0] length = header[23:0];
  wire        flow_valid = s_axis_tvalid &&
                           (magic_type == MAGIC_TYPE_AURORA_FLOW) &&
                           (length == FLOW_FRAME_BYTES);
  wire        flow_bad = s_axis_tvalid &&
                         (magic_type == MAGIC_TYPE_AURORA_FLOW) &&
                         (length != FLOW_FRAME_BYTES);

  assign remote_pause = remote_pause_r;

  always @(posedge clk) begin
    if (rst || !enable) begin
      remote_pause_r <= 1'b0;
      remote_fifo_level <= 16'd0;
      remote_pause_high <= 16'd0;
      remote_resume_low <= 16'd0;
      flow_frame_count <= 32'd0;
      bad_flow_count <= 32'd0;
      flow_seen <= 1'b0;
      timeout_count_r <= 32'd0;
    end else begin
      if (flow_valid) begin
        remote_pause_r <= s_axis_tdata[176];
        remote_fifo_level <= s_axis_tdata[143:128];
        remote_pause_high <= s_axis_tdata[159:144];
        remote_resume_low <= s_axis_tdata[175:160];
        flow_frame_count <= flow_frame_count + 1'b1;
        flow_seen <= 1'b1;
        timeout_count_r <= 32'd0;
      end else begin
        if (timeout_count_r >= TIMEOUT_CYCLES - 1'b1) begin
          remote_pause_r <= 1'b0;
        end else begin
          timeout_count_r <= timeout_count_r + 1'b1;
        end
      end

      if (flow_bad) begin
        bad_flow_count <= bad_flow_count + 1'b1;
      end
    end
  end

endmodule

`default_nettype wire
