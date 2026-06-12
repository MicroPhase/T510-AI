`timescale 1ns / 1ps
`default_nettype none

module t510_fnic_axis_async_fifo_256 #(
  parameter ADDR_WIDTH = 9,
  parameter DATA_WIDTH = 256
) (
  input  wire                  s_clk,
  input  wire                  s_rst,
  input  wire [DATA_WIDTH-1:0] s_axis_tdata,
  input  wire                  s_axis_tvalid,
  output wire                  s_axis_tready,

  input  wire                  m_clk,
  input  wire                  m_rst,
  output wire [DATA_WIDTH-1:0] m_axis_tdata,
  output wire                  m_axis_tvalid,
  input  wire                  m_axis_tready,

  output wire [15:0]           wr_occupancy,
  output wire [15:0]           rd_occupancy
);

  localparam integer FIFO_DEPTH = (1 << ADDR_WIDTH);
  localparam integer PTR_WIDTH = ADDR_WIDTH + 1;

  reg [DATA_WIDTH-1:0] mem [0:FIFO_DEPTH-1];
  reg [PTR_WIDTH-1:0] wr_bin = {PTR_WIDTH{1'b0}};
  reg [PTR_WIDTH-1:0] wr_gray = {PTR_WIDTH{1'b0}};
  reg [PTR_WIDTH-1:0] rd_bin = {PTR_WIDTH{1'b0}};
  reg [PTR_WIDTH-1:0] rd_gray = {PTR_WIDTH{1'b0}};
  reg [PTR_WIDTH-1:0] rd_gray_s1 = {PTR_WIDTH{1'b0}};
  reg [PTR_WIDTH-1:0] rd_gray_s2 = {PTR_WIDTH{1'b0}};
  reg [PTR_WIDTH-1:0] wr_gray_s1 = {PTR_WIDTH{1'b0}};
  reg [PTR_WIDTH-1:0] wr_gray_s2 = {PTR_WIDTH{1'b0}};
  reg [DATA_WIDTH-1:0] m_tdata_r = {DATA_WIDTH{1'b0}};
  reg                  m_tvalid_r = 1'b0;

  wire [PTR_WIDTH-1:0] wr_bin_next;
  wire [PTR_WIDTH-1:0] wr_gray_next;
  wire [PTR_WIDTH-1:0] rd_bin_next;
  wire [PTR_WIDTH-1:0] rd_gray_next;
  wire [PTR_WIDTH-1:0] rd_bin_sync;
  wire [PTR_WIDTH-1:0] wr_bin_sync;
  wire [PTR_WIDTH-1:0] wr_count;
  wire [PTR_WIDTH-1:0] rd_count;
  wire                 fifo_full;
  wire                 fifo_empty;
  wire                 wr_fire;
  wire                 rd_load;

  assign wr_bin_next = wr_bin + {{(PTR_WIDTH-1){1'b0}}, wr_fire};
  assign wr_gray_next = (wr_bin_next >> 1) ^ wr_bin_next;
  assign rd_bin_next = rd_bin + {{(PTR_WIDTH-1){1'b0}}, rd_load};
  assign rd_gray_next = (rd_bin_next >> 1) ^ rd_bin_next;
  assign fifo_full = (wr_gray == {~rd_gray_s2[PTR_WIDTH-1:PTR_WIDTH-2],
                                  rd_gray_s2[PTR_WIDTH-3:0]});
  assign fifo_empty = (wr_gray_s2 == rd_gray);
  assign wr_fire = s_axis_tvalid && s_axis_tready;
  assign rd_load = (!m_tvalid_r || m_axis_tready) && !fifo_empty;
  assign s_axis_tready = !fifo_full;
  assign m_axis_tdata = m_tdata_r;
  assign m_axis_tvalid = m_tvalid_r;
  assign rd_bin_sync = gray_to_bin(rd_gray_s2);
  assign wr_bin_sync = gray_to_bin(wr_gray_s2);
  assign wr_count = wr_bin - rd_bin_sync;
  assign rd_count = wr_bin_sync - rd_bin;
  assign wr_occupancy = {{(16-PTR_WIDTH){1'b0}}, wr_count};
  assign rd_occupancy = {{(16-PTR_WIDTH){1'b0}}, rd_count};

  always @(posedge s_clk) begin
    if (s_rst) begin
      wr_bin <= {PTR_WIDTH{1'b0}};
      wr_gray <= {PTR_WIDTH{1'b0}};
      rd_gray_s1 <= {PTR_WIDTH{1'b0}};
      rd_gray_s2 <= {PTR_WIDTH{1'b0}};
    end else begin
      rd_gray_s1 <= rd_gray;
      rd_gray_s2 <= rd_gray_s1;
      if (wr_fire) begin
        mem[wr_bin[ADDR_WIDTH-1:0]] <= s_axis_tdata;
        wr_bin <= wr_bin_next;
        wr_gray <= wr_gray_next;
      end
    end
  end

  always @(posedge m_clk) begin
    if (m_rst) begin
      rd_bin <= {PTR_WIDTH{1'b0}};
      rd_gray <= {PTR_WIDTH{1'b0}};
      wr_gray_s1 <= {PTR_WIDTH{1'b0}};
      wr_gray_s2 <= {PTR_WIDTH{1'b0}};
      m_tdata_r <= {DATA_WIDTH{1'b0}};
      m_tvalid_r <= 1'b0;
    end else begin
      wr_gray_s1 <= wr_gray;
      wr_gray_s2 <= wr_gray_s1;

      if (rd_load) begin
        m_tdata_r <= mem[rd_bin[ADDR_WIDTH-1:0]];
        rd_bin <= rd_bin_next;
        rd_gray <= rd_gray_next;
        m_tvalid_r <= 1'b1;
      end else if (m_tvalid_r && m_axis_tready) begin
        m_tvalid_r <= 1'b0;
      end
    end
  end

  function [PTR_WIDTH-1:0] gray_to_bin;
    input [PTR_WIDTH-1:0] gray;
    integer i;
    begin
      gray_to_bin[PTR_WIDTH-1] = gray[PTR_WIDTH-1];
      for (i = PTR_WIDTH - 2; i >= 0; i = i - 1)
        gray_to_bin[i] = gray_to_bin[i + 1] ^ gray[i];
    end
  endfunction

endmodule

`default_nettype wire
