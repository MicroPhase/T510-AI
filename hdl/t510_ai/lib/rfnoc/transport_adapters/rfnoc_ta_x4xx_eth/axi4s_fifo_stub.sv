module axi4s_fifo #(
  int SIZE = 1
) (
  input logic clear = 1'b0,
  interface.slave i,
  interface.master o,
  output logic [15:0] space,
  output logic [15:0] occupied
);

  always_comb begin
    o.tdata  = i.tdata;
    o.tuser  = i.tuser;
    o.tkeep  = i.tkeep;
    o.tlast  = i.tlast;
    o.tvalid = i.tvalid;
    i.tready = clear ? 1'b0 : o.tready;
    space    = 16'hffff;
    occupied = 16'd0;
  end

endmodule
