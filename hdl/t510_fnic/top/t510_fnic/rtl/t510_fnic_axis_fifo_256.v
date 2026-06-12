`timescale 1ns / 1ps
`default_nettype none

module t510_fnic_axis_fifo_256 #(
  parameter ADDR_WIDTH = 9,
  parameter DATA_WIDTH = 256
) (
  input  wire                  clk,
  input  wire                  rst,

  input  wire [DATA_WIDTH-1:0] s_axis_tdata,
  input  wire                  s_axis_tvalid,
  output wire                  s_axis_tready,

  output wire [DATA_WIDTH-1:0] m_axis_tdata,
  output wire                  m_axis_tvalid,
  input  wire                  m_axis_tready,

  output wire [15:0]           occupancy,
  output wire [15:0]           space
);

  localparam integer FIFO_DEPTH = (1 << ADDR_WIDTH);
  localparam integer COUNT_WIDTH = ADDR_WIDTH + 1;

  reg [DATA_WIDTH-1:0] mem [0:FIFO_DEPTH-1];
  reg [ADDR_WIDTH-1:0] wr_ptr = {ADDR_WIDTH{1'b0}};
  reg [ADDR_WIDTH-1:0] rd_ptr = {ADDR_WIDTH{1'b0}};
  reg [COUNT_WIDTH-1:0] count = {COUNT_WIDTH{1'b0}};

  wire write_fire = s_axis_tvalid && s_axis_tready;
  wire read_fire = m_axis_tvalid && m_axis_tready;

  assign s_axis_tready = (count < FIFO_DEPTH[COUNT_WIDTH-1:0]);
  assign m_axis_tvalid = (count != {COUNT_WIDTH{1'b0}});
  assign m_axis_tdata = mem[rd_ptr];
  assign occupancy = {{(16-COUNT_WIDTH){1'b0}}, count};
  assign space = FIFO_DEPTH[15:0] - {{(16-COUNT_WIDTH){1'b0}}, count};

  always @(posedge clk) begin
    if (rst) begin
      wr_ptr <= {ADDR_WIDTH{1'b0}};
      rd_ptr <= {ADDR_WIDTH{1'b0}};
      count <= {COUNT_WIDTH{1'b0}};
    end else begin
      if (write_fire) begin
        mem[wr_ptr] <= s_axis_tdata;
        wr_ptr <= wr_ptr + 1'b1;
      end

      if (read_fire)
        rd_ptr <= rd_ptr + 1'b1;

      case ({write_fire, read_fire})
      2'b10: count <= count + 1'b1;
      2'b01: count <= count - 1'b1;
      default: count <= count;
      endcase
    end
  end

endmodule

`default_nettype wire
