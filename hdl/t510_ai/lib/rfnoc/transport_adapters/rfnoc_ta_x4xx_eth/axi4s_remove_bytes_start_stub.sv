module axi4s_remove_bytes_start #(
  parameter REM_END = 3
) (
  interface i,
  interface o
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
