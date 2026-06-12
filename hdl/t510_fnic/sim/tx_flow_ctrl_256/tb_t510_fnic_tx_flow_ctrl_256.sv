`timescale 1ns / 1ps
`default_nettype none

module tb_t510_fnic_tx_flow_ctrl_256;

  reg clk = 1'b0;
  reg rst = 1'b1;
  reg enable = 1'b0;
  reg [15:0] fifo_level = 16'd0;

  wire [255:0] flow_tdata;
  wire         flow_tvalid;
  wire         flow_pause_tx;
  wire [31:0] flow_tx_count;
  wire        remote_pause;
  wire [15:0] remote_fifo_level;
  wire [15:0] remote_pause_high;
  wire [15:0] remote_resume_low;
  wire [31:0] flow_rx_count;
  wire [31:0] bad_flow_count;
  wire        flow_seen;

  always #5 clk = ~clk;

  t510_fnic_aurora_flow_ctrl_tx_256 #(
    .PAUSE_HIGH_WATERMARK(16'd12),
    .RESUME_LOW_WATERMARK(16'd4),
    .PERIOD_CYCLES(32'd8),
    .FIFO_DEPTH_BEATS(32'd64),
    .FIFO_GUARD_BEATS(32'd2),
    .PAUSE_MARGIN_BEATS(32'd2)
  ) u_tx (
    .clk(clk),
    .rst(rst),
    .enable(enable),
    .fifo_wr_level(fifo_level),
    .packet_bytes(24'd64),
    .link_up(1'b1),
    .m_axis_tdata(flow_tdata),
    .m_axis_tvalid(flow_tvalid),
    .m_axis_tready(1'b1),
    .flow_pause(flow_pause_tx),
    .flow_frame_count(flow_tx_count)
  );

  fnic_aurora_flow_ctrl_rx_256 #(
    .TIMEOUT_CYCLES(32'd1000)
  ) u_rx (
    .clk(clk),
    .rst(rst),
    .enable(enable),
    .s_axis_tdata(flow_tdata),
    .s_axis_tvalid(flow_tvalid),
    .remote_pause(remote_pause),
    .remote_fifo_level(remote_fifo_level),
    .remote_pause_high(remote_pause_high),
    .remote_resume_low(remote_resume_low),
    .flow_frame_count(flow_rx_count),
    .bad_flow_count(bad_flow_count),
    .flow_seen(flow_seen)
  );

  initial begin
    repeat (8) @(posedge clk);
    rst = 1'b0;
    enable = 1'b1;

    fifo_level = 16'd3;
    repeat (20) @(posedge clk);
    if (remote_pause) begin
      $display("FAIL: remote_pause asserted below high watermark");
      $finish;
    end

    fifo_level = 16'd12;
    wait (remote_pause);
    repeat (4) @(posedge clk);
    if (!flow_seen || flow_tx_count == 32'd0 || flow_rx_count == 32'd0) begin
      $display("FAIL: flow frame was not exchanged");
      $finish;
    end
    if (remote_fifo_level != 16'd12 ||
        remote_pause_high != 16'd12 ||
        remote_resume_low != 16'd4) begin
      $display("FAIL: decoded flow fields are wrong");
      $finish;
    end

    fifo_level = 16'd4;
    wait (!remote_pause);
    repeat (20) @(posedge clk);
    if (bad_flow_count != 32'd0) begin
      $display("FAIL: bad_flow_count=%0d", bad_flow_count);
      $finish;
    end

    $display("PASS: tx_flow=%0d rx_flow=%0d pause_high=%0d",
             flow_tx_count, flow_rx_count, remote_pause_high);
    $finish;
  end

endmodule

`default_nettype wire
