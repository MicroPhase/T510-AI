module axi4s_width_conv #(
  parameter PIPELINE = "NONE",
  bit I_USER_TRAILING_BYTES = 0,
  bit O_USER_TRAILING_BYTES = 0,
  bit SYNC_CLKS = 1
) (
  interface.slave i,
  interface.master o
);

  always_comb begin : passthrough_width_conv
    logic [$bits(o.tdata)-1:0] tdata_tmp;
    logic [$bits(o.tuser)-1:0] tuser_tmp;
    logic [$bits(o.tkeep)-1:0] tkeep_tmp;

    tdata_tmp = '0;
    tuser_tmp = '0;
    tkeep_tmp = '0;
    if ($bits(i.tdata) <= $bits(o.tdata)) begin
      tdata_tmp[$bits(i.tdata)-1:0] = i.tdata;
    end else begin
      tdata_tmp = i.tdata[$bits(o.tdata)-1:0];
    end
    if ($bits(i.tuser) > 0 && $bits(o.tuser) > 0) begin
      if ($bits(i.tuser) <= $bits(o.tuser)) begin
        tuser_tmp[$bits(i.tuser)-1:0] = i.tuser;
      end else begin
        tuser_tmp = i.tuser[$bits(o.tuser)-1:0];
      end
    end
    if ($bits(i.tkeep) > 0 && $bits(o.tkeep) > 0) begin
      if ($bits(i.tkeep) <= $bits(o.tkeep)) begin
        tkeep_tmp[$bits(i.tkeep)-1:0] = i.tkeep;
      end else begin
        tkeep_tmp = i.tkeep[$bits(o.tkeep)-1:0];
      end
    end

    o.tdata  = tdata_tmp;
    o.tuser  = tuser_tmp;
    o.tkeep  = tkeep_tmp;
    o.tlast  = i.tlast;
    o.tvalid = i.tvalid;
    i.tready = o.tready;
  end

endmodule
