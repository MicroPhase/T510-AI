`default_nettype none
`timescale 1ns / 1ps

module custom_rx_cpack#(
    parameter   MAX_CHAN = 2,
    parameter   SAMPLE_WIDTH = 32
)(
    input   wire            radio_clk           ,
    input   wire            radio_rst           ,
    input   wire    [7:0]   channel_enable      ,
    input   wire    [15:0]  ch0_adc_i           ,
    input   wire    [15:0]  ch0_adc_q           ,
    input   wire            ch0_adc_valid       ,
    input   wire    [15:0]  ch1_adc_i           ,
    input   wire    [15:0]  ch1_adc_q           ,
    input   wire    [63:0]  vita_time           ,

    output  wire    [MAX_CHAN*SAMPLE_WIDTH-1:0]  cpack_data          ,
    output  wire            cpack_valid         ,
    output  reg     [63:0]  vita_time_cpack     

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



    // wire                      packed_fifo_wr_en;
    // wire [MAX_CHAN*SAMPLE_WIDTH-1 : 0]  packed_fifo_wr_data;

    assign {enable_7,enable_6,enable_5,enable_4,enable_3,enable_2,enable_1,enable_0} = channel_enable;

    assign wr_fifo_en = ch0_adc_valid;


    util_cpack2#(
        .NUM_OF_CHANNELS(MAX_CHAN),
        .SAMPLES_PER_CHANNEL (1),
        .SAMPLE_DATA_WIDTH (SAMPLE_WIDTH)
      ) u_util_cpack2_adc (
        .clk(radio_clk),                                // input wire clk
        .reset(radio_rst),                              // input wire reset
        .enable_0(enable_0),                            // input wire enable_0
        .enable_1(enable_1),                            // input wire enable_1
        .fifo_wr_en(wr_fifo_en),                        // input wire fifo_wr_en
        .fifo_wr_overflow(),                            // output wire fifo_wr_overflow
        .fifo_wr_data_0({ch0_adc_q, ch0_adc_i}),        // input wire [31 : 0] fifo_wr_data_0
        .fifo_wr_data_1({ch1_adc_q, ch1_adc_i}),        // input wire [31 : 0] fifo_wr_data_1
        .packed_fifo_wr_en(cpack_valid),                // output wire packed_fifo_wr_en
        .packed_fifo_wr_overflow(1'b0),                 // input wire packed_fifo_wr_overflow
        .packed_fifo_wr_sync(),                         // output wire packed_fifo_wr_sync
        .packed_fifo_wr_data(cpack_data)                // output wire [63 : 0] packed_fifo_wr_data
    );
    
    // this module if only for 2r2t/1r1t like e310/e200/e100/e316
    always @(* ) begin
         if (channel_enable==8'h1) begin
            vita_time_cpack = vita_time-'d2;
        end else if(channel_enable==8'h3)begin
            vita_time_cpack =  vita_time - 1'b1;
        end else begin
            vita_time_cpack = vita_time-'d2;
        end
    end


    
endmodule

`default_nettype wire