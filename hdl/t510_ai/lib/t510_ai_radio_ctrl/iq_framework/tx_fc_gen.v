// -----------------------------------------------------------------------------
// -----------------------------------------------------------------------------
// Author 	 : WCC 1530604142@qq.com
// File   	 : tx_fc_monitor
// Create 	 : 2025-06-18
// Revise 	 : 2025-
// Editor 	 : Vscode, tab size (4)
// Version	 : v1.0  
// Functions : 
// License	  : License: LGPL-3.0-or-later
// -----------------------------------------------------------------------------
// -----------------------------------------------------------------------------
`default_nettype none
`timescale 1ns / 1ps
module tx_fc_gen(
    input   wire            clk,
    input   wire            rst,
    input   wire            above_fifo_threshold,
    input   wire            below_fifo_threshold,

    output  wire    [63:0]  fc_tdata       ,
    output  wire            fc_tvalid      ,
    output  wire            fc_tlast        ,
    input   wire            fc_tready       
    );

    //====================================================
    //parameter define
    //====================================================
    localparam  IDLE    = 4'b0001;
    localparam  TD_HEAD = 4'b0010;
    localparam  TD_TIME = 4'b0100;
    localparam  TD_BODY = 4'b1000;

    localparam  MAGIC_HEAD_FC = 16'h5505;
    localparam  MAGIC_STOP  = 16'h5555;
    localparam  MAGIC_START = 16'hAAAA;
    //====================================================
    //internal signals and registers
    //====================================================
    reg     [3:0]   state;
    reg     [15:0]  tx_seq_cache;
    wire            triger_fc;
    reg     [15:0]  cnt_tx_fc;

    reg [1:0] above_fifo_threshold_dd;
    reg [1:0] below_fifo_threshold_dd;

    always @(posedge clk ) begin
        above_fifo_threshold_dd <= {above_fifo_threshold_dd[0], above_fifo_threshold};
        below_fifo_threshold_dd <= {below_fifo_threshold_dd[0], below_fifo_threshold};
    end

    assign triger_fc = (above_fifo_threshold_dd==2'b01) | (below_fifo_threshold_dd==2'b01);

    always @(posedge clk ) begin
        if (rst==1'b1) begin
            tx_seq_cache <= 'd0;
        end else if (above_fifo_threshold_dd==2'b01) begin
            tx_seq_cache <= MAGIC_STOP;
        end else if (below_fifo_threshold_dd==2'b01) begin
            tx_seq_cache <= MAGIC_START;
        end
    end

    always @(posedge clk ) begin
        if (rst==1'b1) begin
            state  <= IDLE;
        end else begin
            case (state)
                IDLE : begin
                    if (triger_fc) begin
                        state <= TD_HEAD;
                    end
                end

                TD_HEAD : begin
                    if (fc_tvalid & fc_tready) begin
                        state <= TD_TIME;
                    end
                end

                TD_TIME : begin
                    if (fc_tvalid & fc_tready) begin
                        state <= TD_BODY;
                    end
                end 

                TD_BODY : begin
                    if (fc_tvalid & fc_tready & fc_tlast) begin
                        state <= IDLE;
                    end
                end

                default : state <= IDLE;
            endcase
        end
    end

    always @(posedge clk ) begin
        if (rst==1'b1) begin
            cnt_tx_fc <= 'd0;
        end else if (fc_tvalid & fc_tready & fc_tlast) begin
            cnt_tx_fc <= cnt_tx_fc + 1'b1;
        end
    end

    assign fc_tlast =   (state == TD_BODY);
    assign fc_tvalid=   (state == TD_HEAD) | (state == TD_TIME) | (state == TD_BODY);
    assign fc_tdata =   (state == TD_HEAD) ? {MAGIC_HEAD_FC, cnt_tx_fc, 8'h50, 24'd24} :
                        (state == TD_TIME) ? 'd0 :
                        (state == TD_BODY) ? tx_seq_cache : 'd0;

endmodule
`default_nettype wire