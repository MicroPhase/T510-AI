`default_nettype none
`timescale 1ns / 1ps

module custom_tx_control(
    input   wire            radio_clk               ,
    input   wire            radio_rst               ,
    output  reg     [15:0]  ch0_dac_i               ,
    output  reg     [15:0]  ch0_dac_q               ,
    output  wire            ch0_dac_valid           ,
    output  wire    [15:0]  ch1_dac_i               ,
    output  wire    [15:0]  ch1_dac_q               ,


    input   wire    [63:0]  vita_time               ,

    input   wire    [7:0]   channel_enable          , // how many channels were enabled
    input   wire    [31:0]  tx_samples_per_packet   , // how many samples one packet have, for all the modes
    input   wire    [2:0]   tx_source_sel           , // tx source select, dds, noise or iq
    input   wire            ignore_tx_timestamps    , // ignore tx timestamp(packet do not have timestamp)
    input   wire    [15:0]  noise_idx_start         , // noise start idx
    input   wire    [15:0]  noise_idx_end           , // noise end idx
    input   wire            noise_cfg_update        , // noise cfg update
    input   wire    [31:0]  tx_dds_freq_ctrl_word   , // tx dds frequency control word
    input   wire    [31:0]  fc_window               , // tx flow control window

    output  wire            fc_tvalid               ,
    output  wire    [63:0]  fc_tdata                ,
    output  wire            fc_tlast                ,
    input   wire            fc_tready               , 

    input   wire            tx_tvalid               ,
    input   wire    [63:0]  tx_tdata                ,
    input   wire            tx_tlast                ,
    output  wire            tx_tready               
    );

    //====================================================
    //parameter define
    //====================================================
    localparam  TX_SOURCE_IQ    = 3'd1; // 发送源为主机发送而来的IQ
    localparam  TX_SOURCE_DDS   = 3'd2; // 发送源为FPGA内部DDS
    localparam  TX_SORCE_NOISE  = 3'd3; // 发送源为FPGA内部的噪声源
    
    //====================================================
    //internal signal and register
    //====================================================
    wire    [63:0]  upack_tdata     ;
    wire            upack_tvalid    ;
    wire            upack_tready    ;

    wire            noise_tx_valid  ;
    wire    [15:0]  noise_tx_ifft_i ;
    wire    [15:0]  noise_tx_ifft_q ;

    wire            dds_tx_valid  ;
    wire    [15:0]  dds_tx_i ;
    wire    [15:0]  dds_tx_q ;

    wire            iq_tx_valid  ;
    wire    [15:0]  iq_tx_i ;
    wire    [15:0]  iq_tx_q ;

    wire            tx_unpack_tvalid               ;
    wire    [63:0]  tx_unpack_tdata                ;
    wire    [63:0]  tx_unpack_tuser                ;
    wire            tx_unpack_tlast                ;
    wire            tx_unpack_tready               ;



    custom_tx_frame_unpacke u_custom_tx_frame_unpacke(
        .clk       ( radio_clk       ),
        .rst       ( radio_rst       ),
        .i_tvalid  ( tx_tvalid  ),
        .i_tdata   ( tx_tdata   ),
        .i_tlast   ( tx_tlast   ),
        .i_tready  ( tx_tready  ),
        .o_tvalid  ( tx_unpack_tvalid  ),
        .o_tdata   ( tx_unpack_tdata   ),
        .o_tuser   ( tx_unpack_tuser   ),
        .o_tlast   ( tx_unpack_tlast   ),
        .o_tready  ( tx_unpack_tready  )
    );


    custom_tx_deframer u_custom_tx_deframer(
        .clk                    ( radio_clk              ),
        .rst                    ( radio_rst              ),
        .vita_time              ( vita_time              ),

        .channel_enable         ( channel_enable         ),
        .tx_samples_per_packet  ( tx_samples_per_packet  ),
        .ignore_tx_timestamps   ( 1'b0   ),
        .fc_window              ( fc_window              ),

        .tx_tvalid              ( tx_unpack_tvalid       ),
        .tx_tdata               ( tx_unpack_tdata        ),
        .tx_tuser               ( tx_unpack_tuser        ),
        .tx_tlast               ( tx_unpack_tlast        ),
        .tx_tready              ( tx_unpack_tready       ),

        .fc_tvalid              ( fc_tvalid              ),
        .fc_tdata               ( fc_tdata               ),
        .fc_tlast               ( fc_tlast               ),
        .fc_tready              ( fc_tready              ),

        .upack_tdata            ( upack_tdata            ),
        .upack_tvalid           ( upack_tvalid           ),
        .upack_tready           ( upack_tready           )


    );



    custom_tx_upack#(
        .MAX_CHAN        ( 2 ),
        .SAMPLE_WIDTH    ( 32 )
    )u_custom_tx_upack(
        .radio_clk       ( radio_clk       ),
        .radio_rst       ( radio_rst       ),
        .channel_enable  ( channel_enable  ),
        .ch0_dac_i       ( iq_tx_i         ),
        .ch0_dac_q       ( iq_tx_q         ),
        .ch0_dac_valid   ( iq_tx_valid     ),
        .ch1_dac_i       (                 ),
        .ch1_dac_q       (                 ),
        .upack_tdata     ( upack_tdata     ),
        .upack_tvalid    ( upack_tvalid    ),
        .upack_tready    ( upack_tready    )
    );

    // time_domain_lfsr_noise u_time_domain_lfsr_noise(
    //     .clk               ( radio_clk         ),
    //     .rst               ( radio_rst         ),
    //     .idx_start         ( noise_idx_start   ),
    //     .idx_end           ( noise_idx_end     ),
    //     .noise_cfg_update  ( noise_cfg_update  ),
    //     .tx_valid          ( noise_tx_valid          ),
    //     .tx_ifft_i         ( noise_tx_ifft_i         ),
    //     .tx_ifft_q         ( noise_tx_ifft_q         )
    // );



    dds_source u_dds_source(
        .clk                    ( radio_clk              ),
        .rst                    ( radio_rst              ),
        .tx_dds_freq_ctrl_word  ( tx_dds_freq_ctrl_word  ),
        .tx_dds_valid           ( dds_tx_valid           ),
        .tx_dds_real            ( dds_tx_i               ),
        .tx_dds_imag            ( dds_tx_q               )
    );

    always @(*) begin
        case (tx_source_sel)
            TX_SOURCE_IQ: {ch0_dac_q, ch0_dac_i} = {iq_tx_q, iq_tx_i};
            TX_SORCE_NOISE: {ch0_dac_q, ch0_dac_i} = {noise_tx_ifft_q, noise_tx_ifft_i};
            TX_SOURCE_DDS : {ch0_dac_q, ch0_dac_i} = {dds_tx_q, dds_tx_i};
            default: {ch0_dac_q, ch0_dac_i} = {iq_tx_q, iq_tx_i};
        endcase
    end

    assign ch0_dac_valid = (tx_source_sel == TX_SOURCE_DDS)   ? dds_tx_valid :
                           (tx_source_sel == TX_SORCE_NOISE) ? noise_tx_valid :
                                                                 iq_tx_valid;
    assign ch1_dac_i     = 16'd0;
    assign ch1_dac_q     = 16'd0;


    // wire [255:0] probe0;
    // assign probe0 = {
    //     vita_time,
    //     tx_tvalid,
    //     tx_tdata,
    //     tx_tlast,
    //     tx_tready,
    //     tx_source_sel,
    //     channel_enable,
    //     ignore_tx_timestamps,
    //     noise_idx_start,
    //     noise_idx_end,
    //     noise_cfg_update,
    //     tx_dds_freq_ctrl_word,
    //     ch0_dac_q,
    //     ch0_dac_i

    // };
    // ila_256 u_ila_dma_sg_test (
    //     .clk(radio_clk), // input wire clk


    //     .probe0(probe0) // input wire [255:0] probe0
    // );



endmodule

`default_nettype wire
