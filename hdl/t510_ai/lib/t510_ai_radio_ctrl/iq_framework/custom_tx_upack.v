`default_nettype none
`timescale 1ns / 1ps

module custom_tx_upack#(
    parameter   MAX_CHAN = 2,
    parameter   SAMPLE_WIDTH = 32
)(
    input   wire            radio_clk           ,
    input   wire            radio_rst           ,
    input   wire    [7:0]   channel_enable      ,
    output  wire    [15:0]  ch0_dac_i           ,
    output  wire    [15:0]  ch0_dac_q           ,
    output  wire            ch0_dac_valid       ,
    output  wire    [15:0]  ch1_dac_i           ,
    output  wire    [15:0]  ch1_dac_q           ,

    input   wire    [MAX_CHAN*SAMPLE_WIDTH-1:0]  upack_tdata          ,
    input   wire            upack_tvalid         ,
    output  wire            upack_tready

    );

    //====================================================
    //parameter define
    //====================================================
    // localparam      MAX_CHAN = 2;
    
    //====================================================
    //internal signal and register
    //====================================================
    wire    wr_fifo_en      ;

    wire    enable_0    ;
    wire    enable_1    ;
    wire    enable_2    ;
    wire    enable_3    ;
    wire    enable_4    ;
    wire    enable_5    ;
    wire    enable_6    ;
    wire    enable_7    ;
    wire    fifo_rd_valid   ;
    wire    fifo_rd_underflow   ;



    // wire                      packed_fifo_wr_en;
    // wire [MAX_CHAN*SAMPLE_WIDTH-1 : 0]  packed_fifo_wr_data;

    assign {enable_7,enable_6,enable_5,enable_4,enable_3,enable_2,enable_1,enable_0} = channel_enable;



    util_upack2#(
        .NUM_OF_CHANNELS     ( MAX_CHAN ),
        .SAMPLES_PER_CHANNEL ( 1 ),
        .SAMPLE_DATA_WIDTH   ( SAMPLE_WIDTH )
    )u_util_upack2(
        .clk                 ( radio_clk           ),
        .reset               ( radio_rst           ),
        .enable_0            ( enable_0            ),
        .enable_1            ( enable_1            ),
        
        .fifo_rd_en          ( 1'b1                     ),
        .fifo_rd_valid       ( ch0_dac_valid            ),
        .fifo_rd_underflow   ( fifo_rd_underflow        ),
        .fifo_rd_data_0      ( {ch0_dac_i, ch0_dac_q}   ),
        .fifo_rd_data_1      ( {ch1_dac_i, ch1_dac_q}   ),
        .s_axis_valid        ( upack_tvalid        ),
        .s_axis_ready        ( upack_tready        ),
        .s_axis_data         ( upack_tdata         )
    );


    // wire [255:0] probe0;
    // assign probe0 = {

    //     channel_enable,
    //     ch0_dac_i,
    //     ch0_dac_q,
    //     ch0_dac_valid,
    //     ch1_dac_i,
    //     ch1_dac_q,
    //     upack_tdata,
    //     upack_tvalid,
    //     upack_tready
    // };
    // ila_0 u_ila_tx_unpack (
    //     .clk(radio_clk), // input wire clk


    //     .probe0(probe0) // input wire [255:0] probe0
    // );
    
endmodule

`default_nettype wire