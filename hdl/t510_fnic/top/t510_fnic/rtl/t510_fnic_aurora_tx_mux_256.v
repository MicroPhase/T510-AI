`timescale 1ns / 1ps
`default_nettype none

module t510_fnic_aurora_tx_mux_256 (
  input  wire         clk,
  input  wire         rst,
  input  wire         enable,

  input  wire [255:0] resp_tdata,
  input  wire         resp_tvalid,
  output wire         resp_tready,

  input  wire [255:0] flow_tdata,
  input  wire         flow_tvalid,
  output wire         flow_tready,

  input  wire [255:0] iq_tdata,
  input  wire         iq_tvalid,
  output wire         iq_tready,

  output wire [255:0] m_axis_tdata,
  output wire         m_axis_tvalid,
  input  wire         m_axis_tready
);

  localparam integer BYTES_PER_BEAT = 32;
  localparam [15:0] AURORA_MAGIC_RX_DATA = 16'h5603;

  reg        iq_active_r = 1'b0;
  reg [31:0] iq_beats_remaining_r = 32'd0;

  wire [63:0] iq_header = iq_tdata[63:0];
  wire [15:0] iq_magic = iq_header[63:48];
  wire [23:0] iq_length = iq_header[23:0];
  wire [31:0] iq_length_ext = {8'd0, iq_length};
  wire [31:0] iq_packet_beats =
    (iq_length_ext + BYTES_PER_BEAT - 1) >> 5;
  wire iq_header_ok = (iq_magic == AURORA_MAGIC_RX_DATA) &&
                      (iq_packet_beats != 32'd0);

  wire select_resp = !iq_active_r && resp_tvalid;
  wire select_flow = !iq_active_r && !resp_tvalid && flow_tvalid;
  wire select_iq = iq_active_r ? iq_tvalid :
                                 (!resp_tvalid && !flow_tvalid && iq_tvalid);
  wire out_valid = enable && (select_resp || select_flow || select_iq);
  wire out_fire = out_valid && m_axis_tready;

  // T510 Aurora TX priority:
  //   1. mailbox responses, so host control transactions complete quickly
  //   2. flow-control frames, so FNIC can pause H2C1 TX IQ promptly
  //   3. live RFDC RX IQ stream
  // Once a 0x5603 IQ packet starts, hold the grant until its declared packet
  // length has been sent.  This keeps response/flow frames from being inserted
  // into the middle of a packet on the shared Aurora TX stream.
  assign m_axis_tdata = select_resp ? resp_tdata :
                        (select_flow ? flow_tdata : iq_tdata);
  assign m_axis_tvalid = out_valid;
  assign resp_tready = enable && select_resp && m_axis_tready;
  assign flow_tready = enable && select_flow && m_axis_tready;
  assign iq_tready = enable && select_iq && m_axis_tready;

  always @(posedge clk) begin
    if (rst || !enable) begin
      iq_active_r <= 1'b0;
      iq_beats_remaining_r <= 32'd0;
    end else if (out_fire && select_iq) begin
      if (!iq_active_r) begin
        if (iq_header_ok && iq_packet_beats > 32'd1) begin
          iq_active_r <= 1'b1;
          iq_beats_remaining_r <= iq_packet_beats - 1'b1;
        end else begin
          iq_active_r <= 1'b0;
          iq_beats_remaining_r <= 32'd0;
        end
      end else if (iq_beats_remaining_r <= 32'd1) begin
        iq_active_r <= 1'b0;
        iq_beats_remaining_r <= 32'd0;
      end else begin
        iq_beats_remaining_r <= iq_beats_remaining_r - 1'b1;
      end
    end
  end

endmodule

`default_nettype wire
