module axi4s_remove_bytes #(
  parameter REM_START = 0,
  parameter REM_END = 8
) (
  interface.slave i,
  interface.master o
);

  always_comb begin
    o.tdata  = i.tdata;
    o.tuser  = i.tuser;
    o.tkeep  = i.tkeep;
    o.tlast  = i.tlast;
    o.tvalid = i.tvalid;
    i.tready = o.tready;
  end

endmodule
