`timescale 1ns / 1ps
`default_nettype none

module t510_fnic_aurora_resp_builder_256 #(
  parameter [15:0] AURORA_MAGIC_RESP = 16'h5602,
  parameter [23:0] RESP_BYTES        = 24'd32
) (
  input  wire         clk,
  input  wire         rst,
  input  wire         enable,

  input  wire [191:0] s_resp_tdata,
  input  wire         s_resp_tvalid,
  output wire         s_resp_tready,

  output wire [255:0] m_axis_tdata,
  output wire         m_axis_tvalid,
  input  wire         m_axis_tready,

  output reg  [31:0]  resp_count
);

  reg [255:0] m_axis_tdata_r = 256'd0;
  reg         m_axis_tvalid_r = 1'b0;

  wire [31:0] resp_seq = s_resp_tdata[31:0];
  wire [31:0] resp_status = s_resp_tdata[63:32];
  wire [31:0] resp_data0 = s_resp_tdata[95:64];
  wire [31:0] resp_data1 = s_resp_tdata[127:96];
  wire [31:0] resp_data2 = s_resp_tdata[159:128];
  wire [31:0] resp_data3 = s_resp_tdata[191:160];
  wire [15:0] seq = resp_seq[15:0];
  wire [7:0]  sid = resp_seq[23:16];
  wire [15:0] cmd_id = resp_data3[15:0];
  wire [15:0] status = resp_status[15:0];
  wire [63:0] header = {AURORA_MAGIC_RESP, seq, sid, RESP_BYTES};
  wire [63:0] payload0 = {resp_data0, status, cmd_id};
  wire [63:0] payload1 = {resp_data2, resp_data1};
  wire        output_available = !m_axis_tvalid_r || m_axis_tready;

  assign s_resp_tready = enable && output_available;
  assign m_axis_tdata = m_axis_tdata_r;
  assign m_axis_tvalid = enable && m_axis_tvalid_r;

  always @(posedge clk) begin
    if (rst || !enable) begin
      m_axis_tdata_r <= 256'd0;
      m_axis_tvalid_r <= 1'b0;
      resp_count <= 32'd0;
    end else begin
      if (m_axis_tvalid_r && m_axis_tready)
        m_axis_tvalid_r <= 1'b0;

      if (s_resp_tvalid && s_resp_tready) begin
        m_axis_tdata_r <= {
          payload1,
          payload0,
          64'd0,
          header
        };
        m_axis_tvalid_r <= 1'b1;
        resp_count <= resp_count + 1'b1;
      end
    end
  end

endmodule

`default_nettype wire
