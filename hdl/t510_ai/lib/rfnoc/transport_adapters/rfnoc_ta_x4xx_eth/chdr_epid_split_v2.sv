`timescale 1ns / 1ps
`default_nettype none

module chdr_epid_split_v2 #(
  parameter int          CHDR_W                        = 512,
  parameter logic [15:0] SINK_DST_EPID                = 16'h4000,
  parameter logic [15:0] CTRL_DST_EPID                = 16'h4001,
  parameter logic [15:0] IQ_CAPTURE_DST_EPID          = 16'h4002,
  parameter logic [15:0] RETURN_DST_EPID              = 16'h1234,
  parameter int unsigned DEFAULT_SOURCE_PAYLOAD_BYTES = 1024,
  parameter int unsigned MAX_SOURCE_PAYLOAD_BYTES     = 8192,
  parameter int unsigned MAX_IQ_PACKET_BYTES          = 16384
) (
  input  wire               clk,
  input  wire               rst,

  input  wire [CHDR_W-1:0]  s_axis_tdata,
  input  wire               s_axis_tlast,
  input  wire               s_axis_tvalid,
  output wire               s_axis_tready,

  input  wire [63:0]        iq_s_axis_tdata,
  input  wire [7:0]         iq_s_axis_tkeep,
  input  wire               iq_s_axis_tlast,
  input  wire               iq_s_axis_tvalid,
  output wire               iq_s_axis_tready,
  input  wire               iq_clear,

  output wire [CHDR_W-1:0]  m_axis_tdata,
  output wire               m_axis_tlast,
  output wire               m_axis_tvalid,
  input  wire               m_axis_tready,

  output wire               iq_idle,
  output wire               iq_stop_done
);

  wire [CHDR_W-1:0] ctrl_m_axis_tdata;
  wire              ctrl_m_axis_tlast;
  wire              ctrl_m_axis_tvalid;
  reg               ctrl_m_axis_tready;

  wire [CHDR_W-1:0] iq_m_axis_tdata;
  wire              iq_m_axis_tlast;
  wire              iq_m_axis_tvalid;
  reg               iq_m_axis_tready;

  reg               grant_iq;
  reg               grant_ctrl;

  chdr_epid_loopback #(
    .CHDR_W                       (CHDR_W),
    .SINK_DST_EPID               (SINK_DST_EPID),
    .CTRL_DST_EPID               (CTRL_DST_EPID),
    .IQ_CAPTURE_DST_EPID         (IQ_CAPTURE_DST_EPID),
    .RETURN_DST_EPID             (RETURN_DST_EPID),
    .DEFAULT_SOURCE_PAYLOAD_BYTES(DEFAULT_SOURCE_PAYLOAD_BYTES),
    .MAX_SOURCE_PAYLOAD_BYTES    (MAX_SOURCE_PAYLOAD_BYTES),
    .MAX_IQ_PACKET_BYTES         (MAX_IQ_PACKET_BYTES)
  ) u_ctrl_loopback_only (
    .clk             (clk),
    .rst             (rst),
    .s_axis_tdata    (s_axis_tdata),
    .s_axis_tlast    (s_axis_tlast),
    .s_axis_tvalid   (s_axis_tvalid),
    .s_axis_tready   (s_axis_tready),
    .iq_s_axis_tdata (64'd0),
    .iq_s_axis_tkeep (8'd0),
    .iq_s_axis_tlast (1'b0),
    .iq_s_axis_tvalid(1'b0),
    .iq_s_axis_tready(),
    .iq_clear        (1'b0),
    .m_axis_tdata    (ctrl_m_axis_tdata),
    .m_axis_tlast    (ctrl_m_axis_tlast),
    .m_axis_tvalid   (ctrl_m_axis_tvalid),
    .m_axis_tready   (ctrl_m_axis_tready)
  );

  chdr_iq_bridge_v2 #(
    .CHDR_W              (CHDR_W),
    .IQ_CAPTURE_DST_EPID (IQ_CAPTURE_DST_EPID)
  ) u_iq_bridge_v2 (
    .clk             (clk),
    .rst             (rst),
    .iq_s_axis_tdata (iq_s_axis_tdata),
    .iq_s_axis_tkeep (iq_s_axis_tkeep),
    .iq_s_axis_tlast (iq_s_axis_tlast),
    .iq_s_axis_tvalid(iq_s_axis_tvalid),
    .iq_s_axis_tready(iq_s_axis_tready),
    .stop_req        (iq_clear),
    .stop_done       (iq_stop_done),
    .idle            (iq_idle),
    .m_axis_tdata    (iq_m_axis_tdata),
    .m_axis_tlast    (iq_m_axis_tlast),
    .m_axis_tvalid   (iq_m_axis_tvalid),
    .m_axis_tready   (iq_m_axis_tready)
  );

  always @(posedge clk) begin
    if (rst) begin
      grant_iq   <= 1'b0;
      grant_ctrl <= 1'b0;
    end else begin
      if (!grant_iq && !grant_ctrl) begin
        if (ctrl_m_axis_tvalid) begin
          grant_ctrl <= 1'b1;
        end else if (iq_m_axis_tvalid) begin
          grant_iq <= 1'b1;
        end
      end else if (grant_ctrl && ctrl_m_axis_tvalid && m_axis_tready && ctrl_m_axis_tlast) begin
        grant_ctrl <= 1'b0;
      end else if (grant_iq && iq_m_axis_tvalid && m_axis_tready && iq_m_axis_tlast) begin
        grant_iq <= 1'b0;
      end
    end
  end

  always @(*) begin
    ctrl_m_axis_tready = 1'b0;
    iq_m_axis_tready   = 1'b0;
    if (grant_ctrl) begin
      ctrl_m_axis_tready = m_axis_tready;
    end else if (grant_iq) begin
      iq_m_axis_tready = m_axis_tready;
    end
  end

  assign m_axis_tvalid = grant_ctrl ? ctrl_m_axis_tvalid :
                         grant_iq   ? iq_m_axis_tvalid   : 1'b0;
  assign m_axis_tdata  = grant_ctrl ? ctrl_m_axis_tdata  :
                         grant_iq   ? iq_m_axis_tdata    : '0;
  assign m_axis_tlast  = grant_ctrl ? ctrl_m_axis_tlast  :
                         grant_iq   ? iq_m_axis_tlast    : 1'b0;

endmodule

`default_nettype wire
