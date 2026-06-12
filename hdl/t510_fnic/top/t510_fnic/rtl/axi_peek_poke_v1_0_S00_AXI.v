`timescale 1 ns / 1 ps
`default_nettype none

module axi_peek_poke_v1_0_S00_AXI #(
  parameter integer C_S_AXI_DATA_WIDTH = 32,
  parameter integer C_S_AXI_ADDR_WIDTH = 7
) (
  // PL-side mailbox command input. This interface is synchronous to
  // S_AXI_ACLK; cross from aurora_user_clk before driving these ports.
  input  wire        pl_cmd_valid,
  output wire        pl_cmd_ready,
  input  wire [31:0] pl_cmd_seq,
  input  wire [31:0] pl_cmd_op,
  input  wire [31:0] pl_cmd_arg0,
  input  wire [31:0] pl_cmd_arg1,
  input  wire [31:0] pl_cmd_arg2,
  input  wire [31:0] pl_cmd_arg3,

  // PL-side mailbox response output. This interface is synchronous to
  // S_AXI_ACLK; cross to aurora_user_clk after consuming these ports.
  output wire        pl_resp_valid,
  input  wire        pl_resp_ready,
  output wire [31:0] pl_resp_seq,
  output wire [31:0] pl_resp_status,
  output wire [31:0] pl_resp_data0,
  output wire [31:0] pl_resp_data1,
  output wire [31:0] pl_resp_data2,
  output wire [31:0] pl_resp_data3,

  output wire [31:0] dbg_status,

  input  wire                                  S_AXI_ACLK,
  input  wire                                  S_AXI_ARESETN,
  input  wire [C_S_AXI_ADDR_WIDTH-1 : 0]      S_AXI_AWADDR,
  input  wire [2 : 0]                          S_AXI_AWPROT,
  input  wire                                  S_AXI_AWVALID,
  output wire                                  S_AXI_AWREADY,
  input  wire [C_S_AXI_DATA_WIDTH-1 : 0]      S_AXI_WDATA,
  input  wire [(C_S_AXI_DATA_WIDTH/8)-1 : 0]  S_AXI_WSTRB,
  input  wire                                  S_AXI_WVALID,
  output wire                                  S_AXI_WREADY,
  output wire [1 : 0]                          S_AXI_BRESP,
  output wire                                  S_AXI_BVALID,
  input  wire                                  S_AXI_BREADY,
  input  wire [C_S_AXI_ADDR_WIDTH-1 : 0]      S_AXI_ARADDR,
  input  wire [2 : 0]                          S_AXI_ARPROT,
  input  wire                                  S_AXI_ARVALID,
  output wire                                  S_AXI_ARREADY,
  output wire [C_S_AXI_DATA_WIDTH-1 : 0]      S_AXI_RDATA,
  output wire [1 : 0]                          S_AXI_RRESP,
  output wire                                  S_AXI_RVALID,
  input  wire                                  S_AXI_RREADY
);

  localparam integer ADDR_LSB = (C_S_AXI_DATA_WIDTH/32) + 1;
  localparam integer OPT_MEM_ADDR_BITS = 4;

  localparam [4:0] REG_STATUS              = 5'h00; // 0x00
  localparam [4:0] REG_CONTROL             = 5'h01; // 0x04
  localparam [4:0] REG_CMD_SEQ             = 5'h02; // 0x08
  localparam [4:0] REG_CMD_OP              = 5'h03; // 0x0c
  localparam [4:0] REG_CMD_ARG0            = 5'h04; // 0x10
  localparam [4:0] REG_CMD_ARG1            = 5'h05; // 0x14
  localparam [4:0] REG_CMD_ARG2            = 5'h06; // 0x18
  localparam [4:0] REG_CMD_ARG3            = 5'h07; // 0x1c
  localparam [4:0] REG_RESP_SEQ            = 5'h08; // 0x20
  localparam [4:0] REG_RESP_STATUS         = 5'h09; // 0x24
  localparam [4:0] REG_RESP_DATA0          = 5'h0a; // 0x28
  localparam [4:0] REG_RESP_DATA1          = 5'h0b; // 0x2c
  localparam [4:0] REG_RESP_DATA2          = 5'h0c; // 0x30
  localparam [4:0] REG_RESP_DATA3          = 5'h0d; // 0x34
  localparam [4:0] REG_ACCEPT_COUNT        = 5'h10; // 0x40
  localparam [4:0] REG_OVERFLOW_COUNT      = 5'h11; // 0x44
  localparam [4:0] REG_RESP_COMMIT_COUNT   = 5'h12; // 0x48
  localparam [4:0] REG_RESP_CONSUME_COUNT  = 5'h13; // 0x4c
  localparam [4:0] REG_MAILBOX_ID          = 5'h1f; // 0x7c

  localparam [31:0] MAILBOX_ID = 32'h544d_424f; // "TMBO"

  localparam integer CTRL_CMD_ACK          = 0;
  localparam integer CTRL_RESP_COMMIT      = 1;
  localparam integer CTRL_RESP_ACK_SW      = 2;
  localparam integer CTRL_CLEAR_OVERFLOW   = 3;
  localparam integer CTRL_CLEAR_COUNTERS   = 4;

  reg [C_S_AXI_ADDR_WIDTH-1 : 0] axi_awaddr = {C_S_AXI_ADDR_WIDTH{1'b0}};
  reg                            axi_awready = 1'b0;
  reg                            axi_wready = 1'b0;
  reg [1 : 0]                    axi_bresp = 2'b00;
  reg                            axi_bvalid = 1'b0;
  reg [C_S_AXI_ADDR_WIDTH-1 : 0] axi_araddr = {C_S_AXI_ADDR_WIDTH{1'b0}};
  reg                            axi_arready = 1'b0;
  reg [C_S_AXI_DATA_WIDTH-1 : 0] axi_rdata = {C_S_AXI_DATA_WIDTH{1'b0}};
  reg [1 : 0]                    axi_rresp = 2'b00;
  reg                            axi_rvalid = 1'b0;
  reg                            aw_en = 1'b1;

  reg        cmd_valid = 1'b0;
  reg        resp_valid = 1'b0;
  reg        cmd_overflow = 1'b0;
  reg        ps_busy = 1'b0;

  reg [31:0] cmd_seq = 32'd0;
  reg [31:0] cmd_op = 32'd0;
  reg [31:0] cmd_arg0 = 32'd0;
  reg [31:0] cmd_arg1 = 32'd0;
  reg [31:0] cmd_arg2 = 32'd0;
  reg [31:0] cmd_arg3 = 32'd0;

  reg [31:0] resp_seq = 32'd0;
  reg [31:0] resp_status = 32'd0;
  reg [31:0] resp_data0 = 32'd0;
  reg [31:0] resp_data1 = 32'd0;
  reg [31:0] resp_data2 = 32'd0;
  reg [31:0] resp_data3 = 32'd0;

  reg [31:0] accept_count = 32'd0;
  reg [31:0] overflow_count = 32'd0;
  reg [31:0] resp_commit_count = 32'd0;
  reg [31:0] resp_consume_count = 32'd0;

  wire [4:0] write_index;
  wire [4:0] read_index;
  wire       slv_reg_wren;
  wire       slv_reg_rden;
  wire       write_accept;
  wire       read_accept;
  wire       pl_cmd_fire;
  wire       pl_resp_fire;
  wire [31:0] status_word;
  wire [31:0] wdata32;
  wire [3:0]  wstrb32;

  reg [C_S_AXI_DATA_WIDTH-1:0] reg_data_out;

  assign S_AXI_AWREADY = axi_awready;
  assign S_AXI_WREADY  = axi_wready;
  assign S_AXI_BRESP   = axi_bresp;
  assign S_AXI_BVALID  = axi_bvalid;
  assign S_AXI_ARREADY = axi_arready;
  assign S_AXI_RDATA   = axi_rdata;
  assign S_AXI_RRESP   = axi_rresp;
  assign S_AXI_RVALID  = axi_rvalid;

  assign write_accept = !axi_awready && S_AXI_AWVALID && S_AXI_WVALID && aw_en;
  assign read_accept = !axi_arready && S_AXI_ARVALID && !axi_rvalid;
  assign write_index = write_accept ? S_AXI_AWADDR[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB] :
                                      axi_awaddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB];
  assign read_index  = read_accept ? S_AXI_ARADDR[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB] :
                                    axi_araddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB];
  assign slv_reg_wren = write_accept;
  assign slv_reg_rden = read_accept;

  assign wdata32 = S_AXI_WDATA[31:0];
  assign wstrb32 = S_AXI_WSTRB[3:0];

  assign pl_cmd_ready = !cmd_valid && !ps_busy && !resp_valid;
  assign pl_cmd_fire = pl_cmd_valid && pl_cmd_ready;
  assign pl_resp_valid = resp_valid;
  assign pl_resp_fire = resp_valid && pl_resp_ready;

  assign pl_resp_seq = resp_seq;
  assign pl_resp_status = resp_status;
  assign pl_resp_data0 = resp_data0;
  assign pl_resp_data1 = resp_data1;
  assign pl_resp_data2 = resp_data2;
  assign pl_resp_data3 = resp_data3;

  assign status_word = {
    25'd0,
    resp_valid,
    cmd_valid,
    ps_busy,
    cmd_overflow,
    1'b0,
    resp_valid,
    cmd_valid
  };
  assign dbg_status = status_word;

  always @(posedge S_AXI_ACLK) begin
    if (!S_AXI_ARESETN) begin
      axi_awready <= 1'b0;
      aw_en <= 1'b1;
    end else begin
      if (write_accept) begin
        axi_awready <= 1'b1;
        aw_en <= 1'b0;
      end else if (S_AXI_BREADY && axi_bvalid) begin
        aw_en <= 1'b1;
        axi_awready <= 1'b0;
      end else begin
        axi_awready <= 1'b0;
      end
    end
  end

  always @(posedge S_AXI_ACLK) begin
    if (!S_AXI_ARESETN) begin
      axi_awaddr <= {C_S_AXI_ADDR_WIDTH{1'b0}};
    end else if (write_accept) begin
      axi_awaddr <= S_AXI_AWADDR;
    end
  end

  always @(posedge S_AXI_ACLK) begin
    if (!S_AXI_ARESETN) begin
      axi_wready <= 1'b0;
    end else if (write_accept) begin
      axi_wready <= 1'b1;
    end else begin
      axi_wready <= 1'b0;
    end
  end

  always @(posedge S_AXI_ACLK) begin
    if (!S_AXI_ARESETN) begin
      axi_bvalid <= 1'b0;
      axi_bresp <= 2'b00;
    end else begin
      if (write_accept && !axi_bvalid) begin
        axi_bvalid <= 1'b1;
        axi_bresp <= 2'b00;
      end else if (S_AXI_BREADY && axi_bvalid) begin
        axi_bvalid <= 1'b0;
      end
    end
  end

  always @(posedge S_AXI_ACLK) begin
    if (!S_AXI_ARESETN) begin
      axi_arready <= 1'b0;
      axi_araddr <= {C_S_AXI_ADDR_WIDTH{1'b0}};
    end else begin
      if (read_accept) begin
        axi_arready <= 1'b1;
        axi_araddr <= S_AXI_ARADDR;
      end else begin
        axi_arready <= 1'b0;
      end
    end
  end

  always @(posedge S_AXI_ACLK) begin
    if (!S_AXI_ARESETN) begin
      axi_rvalid <= 1'b0;
      axi_rresp <= 2'b00;
    end else begin
      if (read_accept) begin
        axi_rvalid <= 1'b1;
        axi_rresp <= 2'b00;
      end else if (axi_rvalid && S_AXI_RREADY) begin
        axi_rvalid <= 1'b0;
      end
    end
  end

  always @(*) begin
    reg_data_out = {C_S_AXI_DATA_WIDTH{1'b0}};
    case (read_index)
      REG_STATUS:             reg_data_out[31:0] = status_word;
      REG_CONTROL:            reg_data_out[31:0] = 32'd0;
      REG_CMD_SEQ:            reg_data_out[31:0] = cmd_seq;
      REG_CMD_OP:             reg_data_out[31:0] = cmd_op;
      REG_CMD_ARG0:           reg_data_out[31:0] = cmd_arg0;
      REG_CMD_ARG1:           reg_data_out[31:0] = cmd_arg1;
      REG_CMD_ARG2:           reg_data_out[31:0] = cmd_arg2;
      REG_CMD_ARG3:           reg_data_out[31:0] = cmd_arg3;
      REG_RESP_SEQ:           reg_data_out[31:0] = resp_seq;
      REG_RESP_STATUS:        reg_data_out[31:0] = resp_status;
      REG_RESP_DATA0:         reg_data_out[31:0] = resp_data0;
      REG_RESP_DATA1:         reg_data_out[31:0] = resp_data1;
      REG_RESP_DATA2:         reg_data_out[31:0] = resp_data2;
      REG_RESP_DATA3:         reg_data_out[31:0] = resp_data3;
      REG_ACCEPT_COUNT:       reg_data_out[31:0] = accept_count;
      REG_OVERFLOW_COUNT:     reg_data_out[31:0] = overflow_count;
      REG_RESP_COMMIT_COUNT:  reg_data_out[31:0] = resp_commit_count;
      REG_RESP_CONSUME_COUNT: reg_data_out[31:0] = resp_consume_count;
      REG_MAILBOX_ID:         reg_data_out[31:0] = MAILBOX_ID;
      default:                reg_data_out[31:0] = 32'd0;
    endcase
  end

  always @(posedge S_AXI_ACLK) begin
    if (!S_AXI_ARESETN) begin
      axi_rdata <= {C_S_AXI_DATA_WIDTH{1'b0}};
    end else if (slv_reg_rden) begin
      axi_rdata <= reg_data_out;
    end
  end

  always @(posedge S_AXI_ACLK) begin
    if (!S_AXI_ARESETN) begin
      cmd_valid <= 1'b0;
      resp_valid <= 1'b0;
      cmd_overflow <= 1'b0;
      ps_busy <= 1'b0;
      cmd_seq <= 32'd0;
      cmd_op <= 32'd0;
      cmd_arg0 <= 32'd0;
      cmd_arg1 <= 32'd0;
      cmd_arg2 <= 32'd0;
      cmd_arg3 <= 32'd0;
      resp_seq <= 32'd0;
      resp_status <= 32'd0;
      resp_data0 <= 32'd0;
      resp_data1 <= 32'd0;
      resp_data2 <= 32'd0;
      resp_data3 <= 32'd0;
      accept_count <= 32'd0;
      overflow_count <= 32'd0;
      resp_commit_count <= 32'd0;
      resp_consume_count <= 32'd0;
    end else begin
      if (pl_cmd_valid && !pl_cmd_ready) begin
        cmd_overflow <= 1'b1;
        overflow_count <= overflow_count + 1'b1;
      end

      if (pl_cmd_fire) begin
        cmd_valid <= 1'b1;
        cmd_seq <= pl_cmd_seq;
        cmd_op <= pl_cmd_op;
        cmd_arg0 <= pl_cmd_arg0;
        cmd_arg1 <= pl_cmd_arg1;
        cmd_arg2 <= pl_cmd_arg2;
        cmd_arg3 <= pl_cmd_arg3;
        accept_count <= accept_count + 1'b1;
      end

      if (pl_resp_fire) begin
        resp_valid <= 1'b0;
        resp_consume_count <= resp_consume_count + 1'b1;
      end

      if (slv_reg_wren) begin
        case (write_index)
          REG_CONTROL: begin
            if (wdata32[CTRL_CMD_ACK]) begin
              cmd_valid <= 1'b0;
              ps_busy <= 1'b1;
            end
            if (wdata32[CTRL_RESP_COMMIT]) begin
              resp_valid <= 1'b1;
              ps_busy <= 1'b0;
              resp_commit_count <= resp_commit_count + 1'b1;
            end
            if (wdata32[CTRL_RESP_ACK_SW]) begin
              resp_valid <= 1'b0;
            end
            if (wdata32[CTRL_CLEAR_OVERFLOW]) begin
              cmd_overflow <= 1'b0;
            end
            if (wdata32[CTRL_CLEAR_COUNTERS]) begin
              accept_count <= 32'd0;
              overflow_count <= 32'd0;
              resp_commit_count <= 32'd0;
              resp_consume_count <= 32'd0;
            end
          end
          REG_RESP_SEQ:    resp_seq    <= apply_wstrb(resp_seq, wdata32, wstrb32);
          REG_RESP_STATUS: resp_status <= apply_wstrb(resp_status, wdata32, wstrb32);
          REG_RESP_DATA0:  resp_data0  <= apply_wstrb(resp_data0, wdata32, wstrb32);
          REG_RESP_DATA1:  resp_data1  <= apply_wstrb(resp_data1, wdata32, wstrb32);
          REG_RESP_DATA2:  resp_data2  <= apply_wstrb(resp_data2, wdata32, wstrb32);
          REG_RESP_DATA3:  resp_data3  <= apply_wstrb(resp_data3, wdata32, wstrb32);
          default: begin
          end
        endcase
      end
    end
  end

  function [31:0] apply_wstrb;
    input [31:0] old_value;
    input [31:0] new_value;
    input [3:0]  strobe;
    integer i;
    begin
      apply_wstrb = old_value;
      for (i = 0; i < 4; i = i + 1) begin
        if (strobe[i])
          apply_wstrb[i*8 +: 8] = new_value[i*8 +: 8];
      end
    end
  endfunction

endmodule

`default_nettype wire
