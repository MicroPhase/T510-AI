`default_nettype none
`timescale 1ns / 1ps

module custom_rx_control(
    input   wire            radio_clk                   ,
    input   wire            radio_rst                   ,
    input   wire    [15:0]  ch0_adc_i                   ,
    input   wire    [15:0]  ch0_adc_q                   ,
    input   wire            ch0_adc_valid               ,
    input   wire    [15:0]  ch1_adc_i                   ,
    input   wire    [15:0]  ch1_adc_q                   ,

    input   wire    [63:0]  vita_time                   ,

    input   wire    [7:0]   channel_enable              , // how many channels were enabled
    input   wire    [1:0]   rx_mode                     , // set rx mode
    input   wire            rx_mode_strobe              , // rx mode valid
    input   wire            mode_exit                   , // change to other mode, for example stream mode to packet mode
    input   wire            stream_start                , // continuous stream start signal
    input   wire    [63:0]  rx_sync_timestamp           , // when sync mode is enable, sample will be captured when the vitatime match this time value
    input   wire            rx_sync_timestamp_strobe    ,
    input   wire            capture_one_block           , // capture one packet
    input   wire    [31:0]  rx_sample_bytes             , // 用户一次需要的采样点的字节长度
    input   wire    [31:0]  max_sample_bytes_per_packet , // 一个数据包里面最多有多少个采样点，以字节长度
    input   wire    [15:0]  dma_s2mm_pkt_per_burst      ,

    output  wire            rx_tvalid                   ,
    output  wire    [63:0]  rx_tdata                    ,
    output  wire    [7:0]   rx_tkeep                    ,
    output  wire            rx_tlast                    ,
    input   wire            rx_tready           
    );

    //====================================================
    //parameter define
    //====================================================

    
    //====================================================
    //internal signal and register
    //====================================================
    wire    [63:0]  vita_time_cpack;
    wire    [63:0]  cpack_data;
    wire            cpack_valid;

    custom_rx_cpack#(
        .MAX_CHAN        ( 2 ),
        .SAMPLE_WIDTH    ( 32 )
    )u_custom_rx_cpack(
        .radio_clk       ( radio_clk       ),
        .radio_rst       ( radio_rst       ),
        .channel_enable  ( channel_enable  ),
        .ch0_adc_i       ( ch0_adc_i       ),
        .ch0_adc_q       ( ch0_adc_q       ),
        .ch0_adc_valid   ( ch0_adc_valid   ),
        .ch1_adc_i       ( ch1_adc_i       ),
        .ch1_adc_q       ( ch1_adc_q       ),
        .vita_time       ( vita_time       ),
        .cpack_data      ( cpack_data      ),
        .cpack_valid     ( cpack_valid     ),
        .vita_time_cpack ( vita_time_cpack  )
    );


    custom_rx_framer u_custom_rx_framer(
        .clk                            ( radio_clk                     ),
        .rst                            ( radio_rst                     ),
        .vita_time_cpack                ( vita_time_cpack               ),
        .cpack_data                     ( cpack_data                    ),
        .cpack_valid                    ( cpack_valid                   ),
        .channel_enable                 ( channel_enable                ),
        .rx_mode                        ( rx_mode                       ),
        .rx_mode_strobe                 ( rx_mode_strobe                ),
        .mode_exit                      ( mode_exit                     ),
        .stream_start                   ( stream_start                  ),
        .rx_sync_timestamp              ( rx_sync_timestamp             ),
        .rx_sync_timestamp_strobe       ( rx_sync_timestamp_strobe      ),
        .capture_one_block              ( capture_one_block             ),
        .rx_sample_bytes                ( rx_sample_bytes               ),
        .max_sample_bytes_per_packet    ( max_sample_bytes_per_packet   ),
        .dma_s2mm_pkt_per_burst         ( dma_s2mm_pkt_per_burst        ),
        .rx_tvalid                      ( rx_tvalid                     ),
        .rx_tdata                       ( rx_tdata                      ),
        .rx_tlast                       ( rx_tlast                      ),
        .rx_tready                      ( rx_tready                     )
    );


    // custom_rx_framer u_custom_rx_framer(
    //     .clk                          ( clk                          ),
    //     .rst                          ( rst                          ),
    //     .vita_time_cpack              ( vita_time_cpack              ),
    //     .cpack_data                   ( cpack_data                   ),
    //     .cpack_valid                  ( cpack_valid                  ),
    //     .channel_enable               ( channel_enable               ),
    //     .rx_mode                      ( rx_mode                      ),
    //     .rx_mode_strobe               ( rx_mode_strobe               ),
    //     .mode_exit                    ( mode_exit                    ),
    //     .stream_start                 ( stream_start                 ),
    //     .rx_sync_timestamp            ( rx_sync_timestamp            ),
    //     .rx_sync_timestamp_strobe     ( rx_sync_timestamp_strobe     ),
    //     .capture_one_block            ( capture_one_block            ),
    //     .rx_sample_bytes              ( rx_sample_bytes              ),
    //     .max_sample_bytes_per_packet  ( max_sample_bytes_per_packet  ),
    //     .dma_s2mm_pkt_per_burst       ( dma_s2mm_pkt_per_burst       ),
    //     .rx_tvalid                    ( rx_tvalid                    ),
    //     .rx_tdata                     ( rx_tdata                     ),
    //     .rx_tlast                     ( rx_tlast                     ),
    //     .rx_tready                    ( rx_tready                    )
    // );




endmodule

`default_nettype wire