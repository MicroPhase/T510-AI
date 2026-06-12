`timescale 1ns / 1ps
`default_nettype none

module tb_t510_fnic_aurora_tx_mux_256;

  reg clk = 1'b0;
  reg rst = 1'b1;
  reg enable = 1'b0;

  reg [255:0] resp_tdata = 256'd0;
  reg         resp_tvalid = 1'b0;
  wire        resp_tready;
  reg [255:0] flow_tdata = 256'd0;
  reg         flow_tvalid = 1'b0;
  wire        flow_tready;
  reg [255:0] iq_tdata = 256'd0;
  reg         iq_tvalid = 1'b0;
  wire        iq_tready;
  wire [255:0] m_tdata;
  wire         m_tvalid;
  reg          m_tready = 1'b1;

  integer out_count = 0;
  reg [15:0] observed [0:4];

  always #5 clk = ~clk;

  t510_fnic_aurora_tx_mux_256 u_dut (
    .clk(clk),
    .rst(rst),
    .enable(enable),
    .resp_tdata(resp_tdata),
    .resp_tvalid(resp_tvalid),
    .resp_tready(resp_tready),
    .flow_tdata(flow_tdata),
    .flow_tvalid(flow_tvalid),
    .flow_tready(flow_tready),
    .iq_tdata(iq_tdata),
    .iq_tvalid(iq_tvalid),
    .iq_tready(iq_tready),
    .m_axis_tdata(m_tdata),
    .m_axis_tvalid(m_tvalid),
    .m_axis_tready(m_tready)
  );

  always @(posedge clk) begin
    if (rst || !enable) begin
      out_count <= 0;
    end else if (m_tvalid && m_tready) begin
      observed[out_count] <= m_tdata[63:48];
      out_count <= out_count + 1;
    end
  end

  task set_iq;
    input [15:0] tag;
    begin
      iq_tdata = {192'd0, tag, 16'h0000, 8'h00, 24'd96};
      iq_tdata[63:48] = 16'h5603;
    end
  endtask

  initial begin
    resp_tdata = {192'd0, 16'h5602, 16'h0001, 8'h00, 24'd32};
    flow_tdata = {192'd0, 16'h5605, 16'h0001, 8'h00, 24'd32};
    repeat (4) @(posedge clk);
    rst = 1'b0;
    enable = 1'b1;

    set_iq(16'h5603);
    iq_tvalid = 1'b1;
    @(posedge clk);
    while (!iq_tready) @(posedge clk);

    resp_tvalid = 1'b1;
    flow_tvalid = 1'b1;
    set_iq(16'h5603);
    @(posedge clk);
    while (!iq_tready) @(posedge clk);

    set_iq(16'h5603);
    @(posedge clk);
    while (!iq_tready) @(posedge clk);
    iq_tvalid = 1'b0;

    @(posedge clk);
    if (resp_tready)
      resp_tvalid = 1'b0;
    @(posedge clk);
    if (flow_tready)
      flow_tvalid = 1'b0;

    repeat (4) @(posedge clk);
    if (out_count != 5) begin
      $display("FAIL: output count=%0d", out_count);
      $finish;
    end
    if (observed[0] != 16'h5603 || observed[1] != 16'h5603 ||
        observed[2] != 16'h5603 || observed[3] != 16'h5602 ||
        observed[4] != 16'h5605) begin
      $display("FAIL: mux order %h %h %h %h %h",
               observed[0], observed[1], observed[2],
               observed[3], observed[4]);
      $finish;
    end

    $display("PASS: mux kept IQ packet contiguous before resp/flow");
    $finish;
  end

endmodule

`default_nettype wire
