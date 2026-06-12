`timescale 1ns / 1ps
`default_nettype none

module tb_t510_fnic_tx_flow_mux_to_fnic_rx_256;

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
  wire [255:0] mux_tdata;
  wire         mux_tvalid;

  wire        remote_pause;
  wire [15:0] remote_fifo_level;
  wire [15:0] remote_pause_high;
  wire [15:0] remote_resume_low;
  wire [31:0] flow_rx_count;
  wire [31:0] bad_flow_count;
  wire        flow_seen;

  integer beat;

  always #5 clk = ~clk;

  t510_fnic_aurora_tx_mux_256 u_mux (
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
    .m_axis_tdata(mux_tdata),
    .m_axis_tvalid(mux_tvalid),
    .m_axis_tready(1'b1)
  );

  fnic_aurora_flow_ctrl_rx_256 #(
    .TIMEOUT_CYCLES(32'd1000)
  ) u_fnic_rx (
    .clk(clk),
    .rst(rst),
    .enable(enable),
    .s_axis_tdata(mux_tdata),
    .s_axis_tvalid(mux_tvalid),
    .remote_pause(remote_pause),
    .remote_fifo_level(remote_fifo_level),
    .remote_pause_high(remote_pause_high),
    .remote_resume_low(remote_resume_low),
    .flow_frame_count(flow_rx_count),
    .bad_flow_count(bad_flow_count),
    .flow_seen(flow_seen)
  );

  task set_iq_header;
    input [15:0] seq;
    begin
      iq_tdata = 256'd0;
      iq_tdata[63:0] = {16'h5603, seq, 8'd0, 24'd8192};
    end
  endtask

  initial begin
    flow_tdata = 256'd0;
    flow_tdata[63:0] = {16'h5605, 16'h002a, 8'd0, 24'd32};
    flow_tdata[143:128] = 16'd5104;
    flow_tdata[159:144] = 16'd5104;
    flow_tdata[175:160] = 16'd2048;
    flow_tdata[176] = 1'b1;
    flow_tdata[177] = 1'b1;

    repeat (8) @(posedge clk);
    rst = 1'b0;
    enable = 1'b1;

    // Start a live RX IQ packet.  Flow is asserted while the packet is active;
    // the mux must forward it as soon as the 0x5603 packet boundary is reached.
    set_iq_header(16'd1);
    iq_tvalid = 1'b1;
    @(posedge clk);
    while (!iq_tready) @(posedge clk);

    flow_tvalid = 1'b1;
    for (beat = 1; beat < 256; beat = beat + 1) begin
      iq_tdata = {224'd0, beat[31:0]};
      @(posedge clk);
      while (!iq_tready) @(posedge clk);
    end
    iq_tvalid = 1'b0;

    wait (flow_tready);
    @(posedge clk);
    flow_tvalid = 1'b0;

    repeat (8) @(posedge clk);
    if (!flow_seen || !remote_pause || flow_rx_count == 32'd0) begin
      $display("FAIL: FNIC parser did not see muxed flow frame seen=%0d pause=%0d count=%0d",
               flow_seen, remote_pause, flow_rx_count);
      $finish;
    end
    if (remote_fifo_level != 16'd5104 ||
        remote_pause_high != 16'd5104 ||
        remote_resume_low != 16'd2048 ||
        bad_flow_count != 32'd0) begin
      $display("FAIL: decoded fields fifo=%0d high=%0d low=%0d bad=%0d",
               remote_fifo_level, remote_pause_high, remote_resume_low,
               bad_flow_count);
      $finish;
    end

    $display("PASS: muxed TX flow reached FNIC parser count=%0d fifo=%0d",
             flow_rx_count, remote_fifo_level);
    $finish;
  end

endmodule

`default_nettype wire
