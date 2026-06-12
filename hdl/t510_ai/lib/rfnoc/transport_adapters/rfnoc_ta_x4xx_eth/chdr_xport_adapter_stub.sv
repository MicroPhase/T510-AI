`timescale 1ns/1ps
`default_nettype none

module chdr_xport_adapter #(
  parameter int          PREAMBLE_BYTES   = 6,
  parameter int          MAX_PACKET_BYTES = 2**16,
  parameter logic [15:0] PROTOVER         = {8'd1, 8'd0},
  parameter int          TBL_SIZE         = 6,
  parameter logic [7:0]  NODE_SUBTYPE     = 8'd0,
  parameter int          NODE_INST        = 0,
  parameter bit          ALLOW_DISC       = 1,
  parameter int          NET_CHDR_W       = 64,
  parameter bit          EN_RX_RAW_PYLD   = 1,
  localparam int         USER_META_W      = 97
) (
  input  wire  [15:0] device_id,
  input  wire  [47:0] my_mac,
  input  wire  [31:0] my_ip,
  input  wire  [15:0] my_udp_chdr_port,
  input  wire         kv_stb,
  output logic        kv_busy,
  input  wire  [15:0] kv_dst_epid,
  input  wire  [USER_META_W-1:0] kv_data,
  AxiStreamIf.slave   eth_rx,
  AxiStreamIf.master  eth_tx,
  AxiStreamIf.slave   v2e,
  AxiStreamIf.master  e2v
);

  always_comb begin
    kv_busy    = 1'b0;

    eth_tx.tdata  = v2e.tdata;
    eth_tx.tlast  = v2e.tlast;
    eth_tx.tvalid = v2e.tvalid;
    eth_tx.tuser  = '0;
    if ($bits(v2e.tuser) > 0 && $bits(eth_tx.tuser) > 0) begin
      eth_tx.tuser[$bits(v2e.tuser)-1:0] = v2e.tuser;
    end
    if (eth_tx.TKEEP) begin
      eth_tx.tkeep = v2e.tkeep;
    end
    v2e.tready = eth_tx.tready;

    e2v.tdata  = '0;
    e2v.tlast  = 1'b0;
    e2v.tvalid = 1'b0;
    e2v.tuser  = '0;
    if (e2v.TKEEP) begin
      e2v.tkeep = '0;
    end
    eth_rx.tready = 1'b1;
  end

endmodule

`default_nettype wire
