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
module tx_fc_monitor(
    input   wire            clk,
    input   wire            rst,
    input   wire            triger_fc       ,
    input   wire    [15:0]  current_tx_seq  ,
    input   wire    [63:0]  vita_time       ,

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
    //====================================================
    //internal signals and registers
    //====================================================
    reg     [3:0]   state;
    reg     [15:0]  tx_seq_cache;
    reg     [63:0]  timestamp_cache;
    reg     [15:0]  cnt_tx_fc;

    always @(posedge clk ) begin
        if (rst==1'b1) begin
            tx_seq_cache <= 'd0;
            timestamp_cache <= 'd0;
        end else if (triger_fc) begin
            tx_seq_cache <= current_tx_seq;
            timestamp_cache <= vita_time;
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
                        (state == TD_TIME) ? timestamp_cache :
                        (state == TD_BODY) ? tx_seq_cache : 'd0;

endmodule
`default_nettype wire