module axi4s_packet_gate #(
  bit TDATA        = 1,
  bit TUSER        = 1,
  int SIZE         = 10,
  bit USE_AS_BUFF  = 1,
  int MIN_PKT_SIZE = 1
) (
  input logic clear = 1'b0,
  input logic error = 1'b0,
  interface.slave i,
  interface.master o
);

  always_comb begin
    o.tdata  = i.tdata;
    o.tuser  = i.tuser;
    o.tkeep  = i.tkeep;
    o.tlast  = i.tlast;
    o.tvalid = i.tvalid & ~error;
    i.tready = clear ? 1'b0 : o.tready;
  end

endmodule
