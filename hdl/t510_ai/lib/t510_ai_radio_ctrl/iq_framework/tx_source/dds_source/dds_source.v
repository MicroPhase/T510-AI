`timescale 1ns / 1ps

module dds_source(
    input   wire            clk,
    input   wire            rst,
    input   wire   [31:0]   tx_dds_freq_ctrl_word,

    output  wire            tx_dds_valid,
    output  wire [15:0]     tx_dds_real,
    output  wire [15:0]     tx_dds_imag
    );

    reg [31:0] phase_accum;
    wire [31:0] phase_q = phase_accum + 32'h4000_0000;

    always @(posedge clk) begin
        if (rst)
            phase_accum <= 32'd0;
        else
            phase_accum <= phase_accum + tx_dds_freq_ctrl_word;
    end

    assign tx_dds_valid = 1'b1;
    assign tx_dds_real  = phase_accum[31:16];
    assign tx_dds_imag  = phase_q[31:16];

endmodule
