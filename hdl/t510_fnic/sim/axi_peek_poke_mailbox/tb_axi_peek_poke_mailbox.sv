`timescale 1ns / 1ps
`default_nettype none

module tb_axi_peek_poke_mailbox;

  localparam [31:0] REG_STATUS             = 32'h00;
  localparam [31:0] REG_CONTROL            = 32'h04;
  localparam [31:0] REG_CMD_SEQ            = 32'h08;
  localparam [31:0] REG_CMD_OP             = 32'h0c;
  localparam [31:0] REG_CMD_ARG0           = 32'h10;
  localparam [31:0] REG_CMD_ARG1           = 32'h14;
  localparam [31:0] REG_CMD_ARG2           = 32'h18;
  localparam [31:0] REG_CMD_ARG3           = 32'h1c;
  localparam [31:0] REG_RESP_SEQ           = 32'h20;
  localparam [31:0] REG_RESP_STATUS        = 32'h24;
  localparam [31:0] REG_RESP_DATA0         = 32'h28;
  localparam [31:0] REG_RESP_DATA1         = 32'h2c;
  localparam [31:0] REG_RESP_DATA2         = 32'h30;
  localparam [31:0] REG_RESP_DATA3         = 32'h34;
  localparam [31:0] REG_ACCEPT_COUNT       = 32'h40;
  localparam [31:0] REG_OVERFLOW_COUNT     = 32'h44;
  localparam [31:0] REG_RESP_COMMIT_COUNT  = 32'h48;
  localparam [31:0] REG_RESP_CONSUME_COUNT = 32'h4c;
  localparam [31:0] REG_MAILBOX_ID         = 32'h7c;

  localparam [31:0] CTRL_CMD_ACK           = 32'h0000_0001;
  localparam [31:0] CTRL_RESP_COMMIT       = 32'h0000_0002;
  localparam [31:0] CTRL_RESP_ACK_SW       = 32'h0000_0004;
  localparam [31:0] CTRL_CLEAR_OVERFLOW    = 32'h0000_0008;
  localparam [31:0] CTRL_CLEAR_COUNTERS    = 32'h0000_0010;

  localparam [31:0] STATUS_CMD_VALID       = 32'h0000_0001;
  localparam [31:0] STATUS_RESP_VALID      = 32'h0000_0002;
  localparam [31:0] STATUS_OVERFLOW        = 32'h0000_0008;
  localparam [31:0] STATUS_BUSY            = 32'h0000_0010;

  reg         clk = 1'b0;
  reg         rstn = 1'b0;

  reg  [6:0]  s_axi_awaddr = 7'd0;
  reg  [2:0]  s_axi_awprot = 3'd0;
  reg         s_axi_awvalid = 1'b0;
  wire        s_axi_awready;
  reg  [31:0] s_axi_wdata = 32'd0;
  reg  [3:0]  s_axi_wstrb = 4'h0;
  reg         s_axi_wvalid = 1'b0;
  wire        s_axi_wready;
  wire [1:0]  s_axi_bresp;
  wire        s_axi_bvalid;
  reg         s_axi_bready = 1'b0;
  reg  [6:0]  s_axi_araddr = 7'd0;
  reg  [2:0]  s_axi_arprot = 3'd0;
  reg         s_axi_arvalid = 1'b0;
  wire        s_axi_arready;
  wire [31:0] s_axi_rdata;
  wire [1:0]  s_axi_rresp;
  wire        s_axi_rvalid;
  reg         s_axi_rready = 1'b0;

  reg         pl_cmd_valid = 1'b0;
  wire        pl_cmd_ready;
  reg  [31:0] pl_cmd_seq = 32'd0;
  reg  [31:0] pl_cmd_op = 32'd0;
  reg  [31:0] pl_cmd_arg0 = 32'd0;
  reg  [31:0] pl_cmd_arg1 = 32'd0;
  reg  [31:0] pl_cmd_arg2 = 32'd0;
  reg  [31:0] pl_cmd_arg3 = 32'd0;

  wire        pl_resp_valid;
  reg         pl_resp_ready = 1'b0;
  wire [31:0] pl_resp_seq;
  wire [31:0] pl_resp_status;
  wire [31:0] pl_resp_data0;
  wire [31:0] pl_resp_data1;
  wire [31:0] pl_resp_data2;
  wire [31:0] pl_resp_data3;
  wire [31:0] dbg_status;

  integer timeout;
  reg [31:0] rdata;

  axi_peek_poke_v1_0_S00_AXI dut (
    .pl_cmd_valid(pl_cmd_valid),
    .pl_cmd_ready(pl_cmd_ready),
    .pl_cmd_seq(pl_cmd_seq),
    .pl_cmd_op(pl_cmd_op),
    .pl_cmd_arg0(pl_cmd_arg0),
    .pl_cmd_arg1(pl_cmd_arg1),
    .pl_cmd_arg2(pl_cmd_arg2),
    .pl_cmd_arg3(pl_cmd_arg3),
    .pl_resp_valid(pl_resp_valid),
    .pl_resp_ready(pl_resp_ready),
    .pl_resp_seq(pl_resp_seq),
    .pl_resp_status(pl_resp_status),
    .pl_resp_data0(pl_resp_data0),
    .pl_resp_data1(pl_resp_data1),
    .pl_resp_data2(pl_resp_data2),
    .pl_resp_data3(pl_resp_data3),
    .dbg_status(dbg_status),
    .S_AXI_ACLK(clk),
    .S_AXI_ARESETN(rstn),
    .S_AXI_AWADDR(s_axi_awaddr),
    .S_AXI_AWPROT(s_axi_awprot),
    .S_AXI_AWVALID(s_axi_awvalid),
    .S_AXI_AWREADY(s_axi_awready),
    .S_AXI_WDATA(s_axi_wdata),
    .S_AXI_WSTRB(s_axi_wstrb),
    .S_AXI_WVALID(s_axi_wvalid),
    .S_AXI_WREADY(s_axi_wready),
    .S_AXI_BRESP(s_axi_bresp),
    .S_AXI_BVALID(s_axi_bvalid),
    .S_AXI_BREADY(s_axi_bready),
    .S_AXI_ARADDR(s_axi_araddr),
    .S_AXI_ARPROT(s_axi_arprot),
    .S_AXI_ARVALID(s_axi_arvalid),
    .S_AXI_ARREADY(s_axi_arready),
    .S_AXI_RDATA(s_axi_rdata),
    .S_AXI_RRESP(s_axi_rresp),
    .S_AXI_RVALID(s_axi_rvalid),
    .S_AXI_RREADY(s_axi_rready)
  );

  always #5 clk = ~clk;

  initial begin
    repeat (8) @(posedge clk);
    @(negedge clk);
    rstn = 1'b1;
    repeat (2) @(posedge clk);

    axi_read(REG_MAILBOX_ID, rdata);
    expect_eq(rdata, 32'h544d_424f, "mailbox id");

    axi_read(REG_STATUS, rdata);
    expect_eq(rdata & (STATUS_CMD_VALID | STATUS_RESP_VALID | STATUS_OVERFLOW | STATUS_BUSY),
              32'd0, "initial status");

    send_pl_cmd(32'h10, 32'h0000_0001, 32'hcafe_0000, 32'hcafe_0001,
                32'hcafe_0002, 32'hcafe_0003);

    axi_read(REG_STATUS, rdata);
    expect_eq(rdata & STATUS_CMD_VALID, STATUS_CMD_VALID, "cmd valid after PL command");
    expect_eq(pl_cmd_ready, 1'b0, "pl cmd ready low while PS has pending command");

    axi_read(REG_CMD_SEQ, rdata);
    expect_eq(rdata, 32'h10, "cmd seq");
    axi_read(REG_CMD_OP, rdata);
    expect_eq(rdata, 32'h0000_0001, "cmd op");
    axi_read(REG_CMD_ARG0, rdata);
    expect_eq(rdata, 32'hcafe_0000, "cmd arg0");
    axi_read(REG_CMD_ARG3, rdata);
    expect_eq(rdata, 32'hcafe_0003, "cmd arg3");
    axi_read(REG_ACCEPT_COUNT, rdata);
    expect_eq(rdata, 32'd1, "accept count");

    axi_write(REG_CONTROL, CTRL_CMD_ACK, 4'hf);
    axi_read(REG_STATUS, rdata);
    expect_eq(rdata & STATUS_CMD_VALID, 32'd0, "cmd valid cleared after PS ack");
    expect_eq(rdata & STATUS_BUSY, STATUS_BUSY, "busy set after PS ack");

    hold_overflow_cmd(32'h11);
    axi_read(REG_STATUS, rdata);
    expect_eq(rdata & STATUS_OVERFLOW, STATUS_OVERFLOW, "overflow latched while PS busy");
    axi_read(REG_OVERFLOW_COUNT, rdata);
    if (rdata == 32'd0)
      fail("overflow counter did not increment");

    axi_write(REG_RESP_SEQ, 32'h10, 4'hf);
    axi_write(REG_RESP_STATUS, 32'h0, 4'hf);
    axi_write(REG_RESP_DATA0, 32'h504f_4e47, 4'hf);
    axi_write(REG_RESP_DATA1, 32'h1234_5678, 4'hf);
    axi_write(REG_RESP_DATA2, 32'h9abc_def0, 4'hf);
    axi_write(REG_RESP_DATA3, 32'hfeed_beef, 4'hf);
    axi_write(REG_CONTROL, CTRL_RESP_COMMIT, 4'hf);

    axi_read(REG_STATUS, rdata);
    expect_eq(rdata & STATUS_BUSY, 32'd0, "busy cleared after response commit");
    expect_eq(rdata & STATUS_RESP_VALID, STATUS_RESP_VALID, "resp valid after commit");
    expect_eq(pl_cmd_ready, 1'b0, "pl cmd ready low while response is pending");
    expect_eq(pl_resp_valid, 1'b1, "PL sees response valid");
    expect_eq(pl_resp_seq, 32'h10, "PL resp seq");
    expect_eq(pl_resp_data0, 32'h504f_4e47, "PL resp data0");

    consume_pl_resp();
    axi_read(REG_STATUS, rdata);
    expect_eq(rdata & STATUS_RESP_VALID, 32'd0, "resp valid cleared after PL consume");
    axi_read(REG_RESP_CONSUME_COUNT, rdata);
    expect_eq(rdata, 32'd1, "response consume count");

    axi_write(REG_CONTROL, CTRL_CLEAR_OVERFLOW, 4'hf);
    axi_read(REG_STATUS, rdata);
    expect_eq(rdata & STATUS_OVERFLOW, 32'd0, "overflow cleared by PS");

    axi_write(REG_CONTROL, CTRL_CLEAR_COUNTERS, 4'hf);
    axi_read(REG_ACCEPT_COUNT, rdata);
    expect_eq(rdata, 32'd0, "accept counter clear");
    axi_read(REG_RESP_COMMIT_COUNT, rdata);
    expect_eq(rdata, 32'd0, "resp commit counter clear");

    send_pl_cmd(32'h20, 32'h0000_0002, 32'h1111_0000, 32'h1111_0001,
                32'h1111_0002, 32'h1111_0003);
    axi_read(REG_CMD_SEQ, rdata);
    expect_eq(rdata, 32'h20, "second command accepted after response path finished");

    $display("TEST PASSED");
    $finish;
  end

  task axi_write;
    input [31:0] addr;
    input [31:0] data;
    input [3:0] strobe;
    begin
      @(negedge clk);
      s_axi_awaddr = addr[6:0];
      s_axi_wdata = data;
      s_axi_wstrb = strobe;
      s_axi_awvalid = 1'b1;
      s_axi_wvalid = 1'b1;
      s_axi_bready = 1'b0;

      @(posedge clk);
      @(negedge clk);
      if (!(s_axi_awready && s_axi_wready))
        fail("AXI write address/data handshake timeout");
      s_axi_awvalid = 1'b0;
      s_axi_wvalid = 1'b0;
      s_axi_bready = 1'b1;

      timeout = 0;
      while (!s_axi_bvalid) begin
        @(posedge clk);
        timeout = timeout + 1;
        if (timeout > 50)
          fail("AXI write response timeout");
      end
      if (s_axi_bresp !== 2'b00)
        fail("AXI write response was not OKAY");

      @(negedge clk);
      s_axi_bready = 1'b0;
      s_axi_awaddr = 7'd0;
      s_axi_wdata = 32'd0;
      s_axi_wstrb = 4'h0;
    end
  endtask

  task axi_read;
    input [31:0] addr;
    output [31:0] data;
    begin
      @(negedge clk);
      s_axi_araddr = addr[6:0];
      s_axi_arvalid = 1'b1;
      s_axi_rready = 1'b0;

      @(posedge clk);
      @(negedge clk);
      if (!s_axi_arready)
        fail("AXI read address timeout");
      s_axi_arvalid = 1'b0;
      s_axi_rready = 1'b1;

      timeout = 0;
      while (!s_axi_rvalid) begin
        @(posedge clk);
        timeout = timeout + 1;
        if (timeout > 50)
          fail("AXI read data timeout");
      end
      if (s_axi_rresp !== 2'b00)
        fail("AXI read response was not OKAY");
      data = s_axi_rdata;

      @(negedge clk);
      s_axi_rready = 1'b0;
      s_axi_araddr = 7'd0;
    end
  endtask

  task send_pl_cmd;
    input [31:0] seq;
    input [31:0] op;
    input [31:0] arg0;
    input [31:0] arg1;
    input [31:0] arg2;
    input [31:0] arg3;
    begin
      timeout = 0;
      while (!pl_cmd_ready) begin
        @(posedge clk);
        timeout = timeout + 1;
        if (timeout > 100)
          fail("PL command ready timeout");
      end

      @(negedge clk);
      pl_cmd_seq = seq;
      pl_cmd_op = op;
      pl_cmd_arg0 = arg0;
      pl_cmd_arg1 = arg1;
      pl_cmd_arg2 = arg2;
      pl_cmd_arg3 = arg3;
      pl_cmd_valid = 1'b1;
      @(posedge clk);
      if (!pl_cmd_ready)
        fail("PL command was not ready at valid handshake");
      @(negedge clk);
      pl_cmd_valid = 1'b0;
      pl_cmd_seq = 32'd0;
      pl_cmd_op = 32'd0;
      pl_cmd_arg0 = 32'd0;
      pl_cmd_arg1 = 32'd0;
      pl_cmd_arg2 = 32'd0;
      pl_cmd_arg3 = 32'd0;
    end
  endtask

  task hold_overflow_cmd;
    input [31:0] seq;
    begin
      @(negedge clk);
      pl_cmd_seq = seq;
      pl_cmd_op = 32'hffff_0001;
      pl_cmd_valid = 1'b1;
      repeat (2) @(posedge clk);
      @(negedge clk);
      pl_cmd_valid = 1'b0;
      pl_cmd_seq = 32'd0;
      pl_cmd_op = 32'd0;
    end
  endtask

  task consume_pl_resp;
    begin
      timeout = 0;
      while (!pl_resp_valid) begin
        @(posedge clk);
        timeout = timeout + 1;
        if (timeout > 100)
          fail("PL response valid timeout");
      end
      @(negedge clk);
      pl_resp_ready = 1'b1;
      @(posedge clk);
      @(negedge clk);
      pl_resp_ready = 1'b0;
    end
  endtask

  task expect_eq;
    input [31:0] actual;
    input [31:0] expected;
    input [8*80-1:0] message;
    begin
      if (actual !== expected) begin
        $display("FAIL: %0s actual=0x%08x expected=0x%08x", message, actual, expected);
        $finish;
      end
    end
  endtask

  task fail;
    input [8*120-1:0] message;
    begin
      $display("FAIL: %0s", message);
      $finish;
    end
  endtask

endmodule

`default_nettype wire
