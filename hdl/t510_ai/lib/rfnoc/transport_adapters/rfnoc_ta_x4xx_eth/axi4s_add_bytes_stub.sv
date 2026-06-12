module axi4s_add_bytes #(
  int ADD_START = 0,
  int ADD_BYTES = 6,
  bit SYNC = 1
) (
  interface.slave i,
  interface.master o
);

  always_comb begin : passthrough_add_bytes
    logic [$bits(o.tdata)-1:0] tdata_tmp;
    logic [$bits(o.tuser)-1:0] tuser_tmp;
    logic [$bits(o.tkeep)-1:0] tkeep_tmp;

    tdata_tmp = '0;
    tuser_tmp = '0;
    tkeep_tmp = '0;
    tdata_tmp[$bits(i.tdata)-1:0] = i.tdata;
    if ($bits(i.tuser) > 0 && $bits(o.tuser) > 0) begin
      tuser_tmp[$bits(i.tuser)-1:0] = i.tuser;
    end
    if ($bits(i.tkeep) > 0 && $bits(o.tkeep) > 0) begin
      tkeep_tmp[$bits(i.tkeep)-1:0] = i.tkeep;
    end

    o.tdata  = tdata_tmp;
    o.tuser  = tuser_tmp;
    o.tkeep  = tkeep_tmp;
    o.tlast  = i.tlast;
    o.tvalid = i.tvalid;
    i.tready = o.tready;
  end

endmodule
