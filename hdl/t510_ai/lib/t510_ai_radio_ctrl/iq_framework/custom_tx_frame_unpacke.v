`default_nettype none
`timescale 1ns / 1ps

module custom_tx_frame_unpacke(
    input   wire            clk                         ,
    input   wire            rst                         ,
    input   wire            i_tvalid                   ,
    input   wire    [63:0]  i_tdata                    ,
    input   wire            i_tlast                    ,
    output  wire            i_tready                   ,

    output  wire            o_tvalid                   ,
    output  wire    [63:0]  o_tdata                    ,
    output  reg     [63:0]  o_tuser                    ,
    output  wire            o_tlast                    ,
    input   wire            o_tready                         
    );

    //====================================================
    //parameter define
    //====================================================
    localparam  HEAD      = 3'b001;
    localparam  TIME      = 3'b010;
    localparam  BODY      = 3'b100;

    reg     [2:0]   state;


    always @(posedge clk ) begin
        if (rst==1'b1) begin
            state <= HEAD;
        end else begin
            case (state)
                HEAD : begin
                    if (i_tvalid & i_tready) begin
                        state <= TIME;
                    end
                end

                TIME : begin
                    if (i_tvalid & i_tready) begin
                        state <= BODY;
                    end
                end

                BODY : begin
                    if (i_tvalid & i_tready & i_tlast) begin
                        state <= HEAD;
                    end
                end

                default: state <= HEAD;
            endcase
        end
    end

    assign i_tready = (state==HEAD || state == TIME) ? 1'b1 : o_tready;


    always @(posedge clk ) begin
        if (rst==1'b1) begin
            o_tuser <= 'd0;
        end else if ((state == TIME) && i_tvalid & i_tready) begin
            o_tuser <= i_tdata;
        end
    end

    assign o_tdata = i_tdata;
    assign o_tvalid = (state == BODY) & i_tvalid;
    assign o_tlast = i_tlast;



endmodule

`default_nettype wire