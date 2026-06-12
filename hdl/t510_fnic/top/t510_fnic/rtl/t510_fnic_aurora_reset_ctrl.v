`timescale 1ns / 1ps
`default_nettype none

module t510_fnic_aurora_reset_ctrl #(
  parameter integer STARTUP_RESET_CYCLES = 1000000
) (
  input  wire clk,
  input  wire rst,
  input  wire soft_reset_req,
  output reg  pma_init = 1'b1,
  output reg  reset_pb = 1'b1,
  output reg  reset_done = 1'b0
);

  localparam integer COUNTER_WIDTH = 32;

  reg [COUNTER_WIDTH-1:0] reset_count = {COUNTER_WIDTH{1'b0}};

  always @(posedge clk) begin
    if (rst || soft_reset_req) begin
      reset_count <= {COUNTER_WIDTH{1'b0}};
      pma_init    <= 1'b1;
      reset_pb    <= 1'b1;
      reset_done  <= 1'b0;
    end else if (!reset_done) begin
      if ((STARTUP_RESET_CYCLES <= 0) ||
          (reset_count >= STARTUP_RESET_CYCLES - 1)) begin
        pma_init   <= 1'b0;
        reset_pb   <= 1'b0;
        reset_done <= 1'b1;
      end else begin
        reset_count <= reset_count + 1'b1;
        pma_init    <= 1'b1;
        reset_pb    <= 1'b1;
      end
    end
  end

endmodule

`default_nettype wire
