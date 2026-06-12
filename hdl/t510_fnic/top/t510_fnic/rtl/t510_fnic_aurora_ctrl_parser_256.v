`timescale 1ns / 1ps
`default_nettype none

module t510_fnic_aurora_ctrl_parser_256 #(
  parameter [15:0] AURORA_MAGIC_CTRL = 16'h5601,
  parameter [23:0] CTRL_BYTES        = 24'd32
) (
  input  wire         clk,
  input  wire         rst,
  input  wire         enable,

  input  wire [255:0] s_axis_tdata,
  input  wire         s_axis_tvalid,

  output wire [191:0] m_cmd_tdata,
  output wire         m_cmd_tvalid,
  input  wire         m_cmd_tready,

  output reg  [31:0]  ctrl_count,
  output reg  [31:0]  bad_length_count,
  output reg  [31:0]  drop_count
);

  reg [191:0] m_cmd_tdata_r = 192'd0;
  reg         m_cmd_valid_r = 1'b0;

  wire [63:0] header = s_axis_tdata[63:0];
  wire [15:0] magic_type = header[63:48];
  wire [15:0] seq = header[47:32];
  wire [7:0]  sid = header[31:24];
  wire [23:0] length = header[23:0];
  wire [15:0] cmd_id = s_axis_tdata[143:128];
  wire [7:0]  flags = s_axis_tdata[151:144];
  wire [7:0]  target = s_axis_tdata[159:152];
  wire [31:0] arg0 = s_axis_tdata[191:160];
  wire [31:0] arg1 = s_axis_tdata[223:192];
  wire [31:0] arg2 = s_axis_tdata[255:224];
  wire        ctrl_frame = enable && s_axis_tvalid && (magic_type == AURORA_MAGIC_CTRL);
  wire        ctrl_length_ok = (length == CTRL_BYTES);
  wire        output_available = !m_cmd_valid_r || m_cmd_tready;
  wire [31:0] mailbox_seq = {8'd0, sid, seq};
  wire [31:0] mailbox_op =
    (cmd_id == 16'h0100) ? 32'h0001_0100 :
    (cmd_id == 16'h0101) ? 32'h0001_0101 :
    (cmd_id == 16'h0102) ? 32'h0001_0102 :
    (cmd_id == 16'h0103) ? 32'h0001_0103 :
    (cmd_id == 16'h7f01) ? 32'h0001_0001 :
                           {16'd0, cmd_id};
  wire [31:0] mailbox_arg3 = {cmd_id, target, flags};

  assign m_cmd_tdata = m_cmd_tdata_r;
  assign m_cmd_tvalid = m_cmd_valid_r;

  always @(posedge clk) begin
    if (rst || !enable) begin
      m_cmd_tdata_r <= 192'd0;
      m_cmd_valid_r <= 1'b0;
      ctrl_count <= 32'd0;
      bad_length_count <= 32'd0;
      drop_count <= 32'd0;
    end else begin
      if (m_cmd_valid_r && m_cmd_tready)
        m_cmd_valid_r <= 1'b0;

      if (ctrl_frame) begin
        if (!ctrl_length_ok) begin
          bad_length_count <= bad_length_count + 1'b1;
        end else if (output_available) begin
          m_cmd_tdata_r <= {
            mailbox_arg3,
            arg2,
            arg1,
            arg0,
            mailbox_op,
            mailbox_seq
          };
          m_cmd_valid_r <= 1'b1;
          ctrl_count <= ctrl_count + 1'b1;
        end else begin
          drop_count <= drop_count + 1'b1;
        end
      end
    end
  end

endmodule

`default_nettype wire
