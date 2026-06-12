`timescale 1ns / 1ps
`default_nettype none

module iq_framework_wrapper(
    input   wire            radio_clk               ,
    input   wire            radio_rst               ,
    input   wire            clear                   ,
    input   wire            pps                     ,
    
    /*synthesis keep*/input   wire    [15:0]  ch0_adc_i               ,
    /*synthesis keep*/input   wire    [15:0]  ch0_adc_q               ,
    input   wire            ch0_adc_valid           ,
    input   wire    [15:0]  ch1_adc_i               ,
    input   wire    [15:0]  ch1_adc_q               ,
    input   wire            ch1_adc_valid           ,

    /*synthesis keep*/output  wire    [15:0]  ch0_dac_i               ,
    /*synthesis keep*/output  wire    [15:0]  ch0_dac_q               ,
    output  wire            ch0_dac_valid           ,
    output  wire    [15:0]  ch1_dac_i               ,
    output  wire    [15:0]  ch1_dac_q               ,
    output  wire            ch1_dac_valid           ,


    input   wire            get_current_vita_time_b         ,
    input   wire            get_lastpps_vita_time_b         ,
    output  reg  	[63:0]	vita_time_b			            ,
    output  reg 	[63:0]	vita_time_last_pps_b            ,
    input   wire 	[63:0]	set_vita_timestamp_b 	        ,
    input   wire    [2:0]   set_time_mode_b                 ,
    input   wire            time_mode_strobe_b              ,
    input   wire	[63:0]	tx_timestamp_b			        ,
    input   wire    [31:0]  rx_sample_bytes_b               ,
    input   wire    [31:0]  max_sample_bytes_per_packet_b   ,            
    input   wire 			capture_one_block_b		        ,
    input   wire    [63:0]  rx_sync_timestamp_b             ,
    input   wire            rx_sync_timestamp_strobe_b      ,
    input   wire    [1:0]   rx_mode_b                       ,
    input   wire            rx_mode_strobe_b                ,
    input   wire            mode_exit_b                     ,
    input   wire            stream_start_b                  ,
    input   wire    [7:0]   channel_enable_b                ,
    input   wire    [15:0]  dma_s2mm_pkt_per_burst_b        ,
    input   wire    [31:0]  tx_samples_per_packet_b         , // how many samples one packet have, for all the modes
    input   wire    [2:0]   tx_source_sel_b                 , // tx source select, dds, noise or iq
    input   wire            ignore_tx_timestamps_b          , // ignore tx timestamp(packet do not have timestamp)
    input   wire    [15:0]  noise_idx_start_b               , // noise start idx
    input   wire    [15:0]  noise_idx_end_b                 , // noise end idx
    input   wire            noise_cfg_update_b              , // noise cfg update
    input   wire    [31:0]  tx_dds_freq_ctrl_word_b         , // tx dds frequency control word
    input   wire    [31:0]  fc_window_b                     ,
    input   wire            sync_in_b                       , // sync for vitatime


    input   wire            user_bus_clk            ,
    input   wire            user_bus_rst            ,

    // RX for DMA port
    output  wire [63:0]     user_bus_rx_tdata       ,
    output  wire [7:0]      user_bus_rx_tkeep       ,
    output  wire            user_bus_rx_tlast       ,
    input   wire            user_bus_rx_tready      ,
    output  wire            user_bus_rx_tvalid      ,

    // TX for DMA port
    input   wire [63:0]     user_bus_tx_tdata       ,
    input   wire [7:0]      user_bus_tx_tkeep       ,
    input   wire            user_bus_tx_tlast       ,
    output  wire            user_bus_tx_tready      ,
    input   wire            user_bus_tx_tvalid      
    );

    // wire [63:0]     rx_tdata_r       ;
    // wire [7:0]      rx_tkeep_r       ;
    // wire            rx_tlast_r       ;
    // wire            rx_tready_r      ;
    // wire            rx_tvalid_r      ;

    wire    [63:0]  vita_time                       ;
    wire    [63:0]  vita_time_last_pps              ;
    wire 	[63:0]	set_vita_timestamp 	            ;
    wire    [2:0]   set_time_mode                   ;
    wire            time_mode_strobe                ;
    wire	[63:0]	tx_timestamp			        ;
    wire    [31:0]  rx_sample_bytes                 ;
    wire    [31:0]  max_sample_bytes_per_packet     ;
    wire 			capture_one_block		        ;
    wire    [63:0]  rx_sync_timestamp               ;
    wire            rx_sync_timestamp_strobe        ;
    wire    [1:0]   rx_mode                         ;
    wire            rx_mode_strobe                  ;
    wire    [7:0]   channel_enable                  ;
    wire            mode_exit                       ;
    wire            stream_start                    ;
    wire    [15:0]  dma_s2mm_pkt_per_burst          ;
    wire    [31:0]  tx_samples_per_packet           ;
    wire    [2:0]   tx_source_sel                   ;
    wire            ignore_tx_timestamps            ;
    wire    [15:0]  noise_idx_start                 ;
    wire    [15:0]  noise_idx_end                   ;
    wire            noise_cfg_update                ;
    wire    [31:0]  tx_dds_freq_ctrl_word           ;
    wire    [31:0]  fc_window                       ;
    wire            sync_in                         ;

    reg     [1:0]   pps_del                         ;

    wire            rx_tvalid                       ;
    wire    [63:0]  rx_tdata                        ;
    wire            rx_tlast                        ;
    wire            rx_tready                       ;

    wire            tx_tvalid                       ;
    wire    [63:0]  tx_tdata                        ;
    wire            tx_tlast                        ;
    wire            tx_tready                       ;
    
    
    //====================================================
    // internal siganls for cross clock domain
    // bus clock and radio clock
    //====================================================
    reg     [63:0]  vita_time_dd0               ;
    reg     [63:0]  vita_time_last_pps_dd0      ;
    reg 	[63:0]	set_vita_timestamp_dd0 	    ;
    reg     [2:0]   set_time_mode_dd0           ;
    reg             time_mode_strobe_dd0        ;
    reg	    [63:0]	tx_timestamp_dd0			;
    reg     [31:0]  rx_sample_bytes_dd0         ;
    reg     [31:0]  max_sample_bytes_per_packet_dd0;
    reg 			capture_one_block_dd0		;
    reg     [63:0]  rx_sync_timestamp_dd0       ;
    reg             rx_sync_timestamp_strobe_dd0;
    reg     [1:0]   rx_mode_dd0                 ;
    reg             rx_mode_strobe_dd0          ;
    reg     [7:0]   channel_enable_dd0          ;
    reg             mode_exit_dd0               ;
    reg             stream_start_dd0            ;
    reg     [15:0]  dma_s2mm_pkt_per_burst_dd0  ;
    reg     [31:0]  tx_samples_per_packet_dd0   ;
    reg     [2:0]   tx_source_sel_dd0           ;
    reg             ignore_tx_timestamps_dd0    ;
    reg     [15:0]  noise_idx_start_dd0         ;
    reg     [15:0]  noise_idx_end_dd0           ;
    reg             noise_cfg_update_dd0        ;
    reg     [31:0]  tx_dds_freq_ctrl_word_dd0   ;
    reg     [31:0]  fc_window_dd0               ;
    reg             sync_in_dd0                 ;

    reg    [63:0]   vita_time_dd1               ;
    reg    [63:0]   vita_time_last_pps_dd1      ;
    reg    [63:0]	set_vita_timestamp_dd1 	    ;
    reg    [2:0]    set_time_mode_dd1           ;
    reg             time_mode_strobe_dd1        ;
    reg	   [63:0]	tx_timestamp_dd1			;
    reg     [31:0]  rx_sample_bytes_dd1         ;
    reg     [31:0]  max_sample_bytes_per_packet_dd1;
    reg 			capture_one_block_dd1		;
    reg    [63:0]   rx_sync_timestamp_dd1       ;
    reg             rx_sync_timestamp_strobe_dd1;
    reg    [1:0]    rx_mode_dd1                 ;
    reg             rx_mode_strobe_dd1          ;
    reg    [7:0]    channel_enable_dd1          ;
    reg             mode_exit_dd1               ;
    reg             stream_start_dd1            ;
    reg     [15:0]  dma_s2mm_pkt_per_burst_dd1  ;
    reg     [31:0]  tx_samples_per_packet_dd1   ;
    reg     [2:0]   tx_source_sel_dd1           ;
    reg             ignore_tx_timestamps_dd1    ;
    reg     [15:0]  noise_idx_start_dd1         ;
    reg     [15:0]  noise_idx_end_dd1           ;
    reg             noise_cfg_update_dd1        ;
    reg     [31:0]  tx_dds_freq_ctrl_word_dd1   ;
    reg     [31:0]  fc_window_dd1               ;
    reg             sync_in_dd1                 ;

    reg [1:0]       get_current_vita_time_b_dd;
    reg [1:0]       get_lastpps_vita_time_b_dd;

    // delay 2 beats, to cross the clock domain
    // user bus clock to radio clock
    always @(posedge radio_clk ) begin
        set_vita_timestamp_dd0 <= set_vita_timestamp_b;
        set_time_mode_dd0 <= set_time_mode_b;
        time_mode_strobe_dd0 <= time_mode_strobe_b;
        tx_timestamp_dd0 <= tx_timestamp_b;
        rx_sample_bytes_dd0 <= rx_sample_bytes_b;
        max_sample_bytes_per_packet_dd0 <= max_sample_bytes_per_packet_b;
        capture_one_block_dd0 <= capture_one_block_b;
        rx_sync_timestamp_dd0 <= rx_sync_timestamp_b;
        rx_sync_timestamp_strobe_dd0 <= rx_sync_timestamp_strobe_b;
        rx_mode_dd0 <= rx_mode_b;
        rx_mode_strobe_dd0 <= rx_mode_strobe_b;
        mode_exit_dd0 <= mode_exit_b;
        stream_start_dd0 <= stream_start_b;
        channel_enable_dd0 <= channel_enable_b;
        dma_s2mm_pkt_per_burst_dd0 <= dma_s2mm_pkt_per_burst_b;
        tx_samples_per_packet_dd0 <= tx_samples_per_packet_b;
        tx_source_sel_dd0 <= tx_source_sel_b;
        ignore_tx_timestamps_dd0 <= ignore_tx_timestamps_b;
        noise_idx_start_dd0 <= noise_idx_start_b;
        noise_idx_end_dd0 <= noise_idx_end_b; 
        noise_cfg_update_dd0 <= noise_cfg_update_b; 
        tx_dds_freq_ctrl_word_dd0 <= tx_dds_freq_ctrl_word_b; 
        fc_window_dd0 <= fc_window_b;
        sync_in_dd0 <= sync_in_b;
 
        set_vita_timestamp_dd1 <= set_vita_timestamp_dd0;
        set_time_mode_dd1 <= set_time_mode_dd0;
        time_mode_strobe_dd1 <= time_mode_strobe_dd0;
        tx_timestamp_dd1 <= tx_timestamp_dd0;
        rx_sample_bytes_dd1 <= rx_sample_bytes_dd0;
        max_sample_bytes_per_packet_dd1 <= max_sample_bytes_per_packet_dd0;
        capture_one_block_dd1 <= capture_one_block_dd0;
        rx_sync_timestamp_dd1 <= rx_sync_timestamp_dd0;
        rx_sync_timestamp_strobe_dd1 <= rx_sync_timestamp_strobe_dd0;
        rx_mode_dd1 <= rx_mode_dd0;
        rx_mode_strobe_dd1 <= rx_mode_strobe_dd0;
        mode_exit_dd1 <= mode_exit_dd0;
        stream_start_dd1 <= stream_start_dd0;
        channel_enable_dd1 <= channel_enable_dd0;
        dma_s2mm_pkt_per_burst_dd1 <= dma_s2mm_pkt_per_burst_dd0;
        tx_samples_per_packet_dd1 <= tx_samples_per_packet_dd0;
        tx_source_sel_dd1 <= tx_source_sel_dd0;
        ignore_tx_timestamps_dd1 <= ignore_tx_timestamps_dd0;
        noise_idx_start_dd1 <= noise_idx_start_dd0;
        noise_idx_end_dd1 <= noise_idx_end_dd0; 
        noise_cfg_update_dd1 <= noise_cfg_update_dd0; 
        tx_dds_freq_ctrl_word_dd1 <= tx_dds_freq_ctrl_word_dd0; 
        fc_window_dd1 <= fc_window_dd0;
        sync_in_dd1 <= sync_in_dd0;

        pps_del <= {pps_del[0], pps};
    end

    assign set_vita_timestamp = set_vita_timestamp_dd1;
    assign set_time_mode = set_time_mode_dd1;
    assign time_mode_strobe = (~time_mode_strobe_dd1 & time_mode_strobe_dd0);
    assign tx_timestamp = tx_timestamp_dd1;
    assign rx_sample_bytes = rx_sample_bytes_dd1;
    assign max_sample_bytes_per_packet = max_sample_bytes_per_packet_dd1;
    assign capture_one_block = (~capture_one_block_dd1 & capture_one_block_dd0);
    assign rx_sync_timestamp = rx_sync_timestamp_dd1;
    assign rx_sync_timestamp_strobe = rx_sync_timestamp_strobe_dd1;
    assign rx_mode = rx_mode_dd1;
    assign rx_mode_strobe = (~rx_mode_strobe_dd1 & rx_mode_strobe_dd0);
    assign mode_exit = (~mode_exit_dd1 & mode_exit_dd0);
    assign stream_start = (~stream_start_dd1 & stream_start_dd0);
    assign channel_enable = channel_enable_dd1;
    assign dma_s2mm_pkt_per_burst = dma_s2mm_pkt_per_burst_dd1;
    assign tx_samples_per_packet = tx_samples_per_packet_dd1;
    assign tx_source_sel = tx_source_sel_dd1;
    assign ignore_tx_timestamps = ignore_tx_timestamps_dd1;
    assign noise_idx_start = noise_idx_start_dd1;
    assign noise_idx_end = noise_idx_end_dd1;
    assign noise_cfg_update = noise_cfg_update_dd1;
    assign tx_dds_freq_ctrl_word = tx_dds_freq_ctrl_word_dd1;
    assign fc_window = fc_window_dd1;
    assign sync_in = sync_in_dd1;


    // radio clock domain to user bus clock domain
    always @(posedge user_bus_clk ) begin
        vita_time_dd0 <= vita_time;
        vita_time_last_pps_dd0 <= vita_time_last_pps;
        vita_time_dd1 <= vita_time_dd0;
        vita_time_last_pps_dd1 <= vita_time_last_pps_dd0;
    end

    // 检测上升沿
    always @(posedge user_bus_clk ) begin
        get_current_vita_time_b_dd <= {get_current_vita_time_b_dd[0], get_current_vita_time_b};
        get_lastpps_vita_time_b_dd <= {get_lastpps_vita_time_b_dd[0], get_lastpps_vita_time_b};
    end
    
    always @(posedge user_bus_clk ) begin
        if (user_bus_rst==1'b1) begin
            vita_time_b <= 'd0;
        end else if (get_current_vita_time_b_dd==2'b01) begin
            vita_time_b <= vita_time_dd1;
        end
    end

    always @(posedge user_bus_clk ) begin
        if (user_bus_rst==1'b1) begin
            vita_time_last_pps_b <= 'd0;
        end else if (get_lastpps_vita_time_b_dd==2'b01) begin
            vita_time_last_pps_b <= vita_time_last_pps_dd1;
        end
    end

    custom_timekeeper#(
        .INCREMENT         ( 64'h1 )
    )u_custom_timekeeper(
        .clk                ( radio_clk            ),
        .reset              ( radio_rst | clear    ),
        .pps                ( pps_del[1]           ),
        .sync_in            ( sync_in              ),
        .strobe             ( 1'b1                 ),
        .time_mode          ( set_time_mode        ),
        .time_mode_strobe   ( time_mode_strobe     ),
        .set_vita_timestamp ( set_vita_timestamp   ),
        .vita_time          ( vita_time            ),
        .vita_time_lastpps  ( vita_time_last_pps   ),
        .sync_out           (                      )
    );

    t510_ai_iq_capture u_t510_ai_iq_capture(
        .radio_clk                   ( radio_clk                   ),
        .radio_rst                   ( radio_rst | clear           ),
        .ch0_adc_i                   ( ch0_adc_i                   ),
        .ch0_adc_q                   ( ch0_adc_q                   ),
        .ch0_adc_valid               ( ch0_adc_valid               ),
        .ch1_adc_i                   ( ch1_adc_i                   ),
        .ch1_adc_q                   ( ch1_adc_q                   ),
        .vita_time                   ( vita_time                   ),
        .channel_enable              ( channel_enable              ),
        .rx_mode                     ( rx_mode                     ),
        .rx_mode_strobe              ( rx_mode_strobe              ),
        .mode_exit                   ( mode_exit                   ),
        .stream_start                ( stream_start                ),
        .rx_sync_timestamp           ( rx_sync_timestamp           ),
        .rx_sync_timestamp_strobe    ( rx_sync_timestamp_strobe    ),
        .capture_one_block           ( capture_one_block           ),
        .rx_sample_bytes             ( rx_sample_bytes             ),
        .max_sample_bytes_per_packet ( max_sample_bytes_per_packet ),
        .rx_tvalid                   ( rx_tvalid                   ),
        .rx_tdata                    ( rx_tdata                    ),
        .rx_tlast                    ( rx_tlast                    ),
        .rx_tready                   ( rx_tready                   )
    );




    //====================================================
    // rx data cross clock domain
    //====================================================
    wire [64:0] rx_fifo_2clk_dout;
    wire        rx_fifo_2clk_tvalid;
    wire        rx_fifo_2clk_tready;
    wire        rx_fifo_2clk_reset;

    // Flush the radio->bus CDC FIFO on mode_exit so stale IQ beats cannot leak
    // into the next arm/restart sequence.
    assign rx_fifo_2clk_reset = user_bus_rst | mode_exit_b;

    axi_fifo_2clk #(
        .WIDTH    (65),
        .SIZE     (10),
        .PIPELINE ("NONE")
    ) rx_fifo_2clk (
        .reset    (rx_fifo_2clk_reset),
        .i_aclk   (radio_clk),
        .i_tdata  ({rx_tlast, rx_tdata}),
        .i_tvalid (rx_tvalid),
        .i_tready (rx_tready),
        .o_aclk   (user_bus_clk),
        .o_tdata  (rx_fifo_2clk_dout),
        .o_tvalid (rx_fifo_2clk_tvalid),
        .o_tready (rx_fifo_2clk_tready)
    );

    assign user_bus_rx_tvalid = rx_fifo_2clk_tvalid;
    assign {user_bus_rx_tlast, user_bus_rx_tdata} = rx_fifo_2clk_dout;
    assign rx_fifo_2clk_tready = user_bus_rx_tready;
    assign user_bus_rx_tkeep = user_bus_rx_tvalid ? 8'hFF : 8'd0;


    //====================================================
    // TX part
    //====================================================

    wire [64:0] tx_fifo_2clk_dout;
    wire        tx_fifo_2clk_tvalid;
    wire        tx_fifo_2clk_tready;

    axi_fifo_2clk #(
        .WIDTH    (65),
        .SIZE     (10),
        .PIPELINE ("NONE")
    ) tx_fifo_2clk (
        .reset    (user_bus_rst),
        .i_aclk   (user_bus_clk),
        .i_tdata  ({user_bus_tx_tlast, user_bus_tx_tdata}),
        .i_tvalid (user_bus_tx_tvalid),
        .i_tready (user_bus_tx_tready),
        .o_aclk   (radio_clk),
        .o_tdata  (tx_fifo_2clk_dout),
        .o_tvalid (tx_fifo_2clk_tvalid),
        .o_tready (tx_fifo_2clk_tready)
    );

    assign tx_tvalid = tx_fifo_2clk_tvalid;
    assign {tx_tlast, tx_tdata} = tx_fifo_2clk_dout;
    assign tx_fifo_2clk_tready = tx_tready;


    assign ch0_dac_i = 16'd0;
    assign ch0_dac_q = 16'd0;
    assign ch0_dac_valid = 1'b0;
    assign ch1_dac_i = 16'd0;
    assign ch1_dac_q = 16'd0;
    assign ch1_dac_valid = 1'b0;
    assign tx_tready = 1'b1;


    
endmodule

`default_nettype wire
