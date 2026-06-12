`timescale 1ns / 1ps
`default_nettype none

module iq_framework_rx_wrapper_v2(
    input   wire            radio_clk,
    input   wire            radio_rst,
    input   wire            clear,
    input   wire            pps,

    input   wire    [15:0]  ch0_adc_i,
    input   wire    [15:0]  ch0_adc_q,
    input   wire            ch0_adc_valid,
    input   wire    [15:0]  ch1_adc_i,
    input   wire    [15:0]  ch1_adc_q,
    input   wire            ch1_adc_valid,

    input   wire    [63:0]  set_vita_timestamp_b,
    input   wire    [2:0]   set_time_mode_b,
    input   wire            time_mode_strobe_b,
    input   wire    [31:0]  rx_sample_bytes_b,
    input   wire    [31:0]  max_sample_bytes_per_packet_b,
    input   wire            capture_one_block_b,
    input   wire    [63:0]  rx_sync_timestamp_b,
    input   wire            rx_sync_timestamp_strobe_b,
    input   wire    [1:0]   rx_mode_b,
    input   wire            rx_mode_strobe_b,
    input   wire            mode_exit_b,
    input   wire            stream_start_b,
    input   wire    [7:0]   channel_enable_b,
    input   wire            sync_in_b,

    input   wire            user_bus_clk,
    input   wire            user_bus_rst,
    output  wire [63:0]     user_bus_rx_tdata,
    output  wire [7:0]      user_bus_rx_tkeep,
    output  wire            user_bus_rx_tlast,
    input   wire            user_bus_rx_tready,
    output  wire            user_bus_rx_tvalid,

    output  wire            capture_idle_b,
    output  wire            stop_done_b
);

    wire    [63:0]  vita_time;
    wire    [63:0]  vita_time_last_pps;
    reg     [1:0]   pps_del;

    reg     [63:0]  set_vita_timestamp_dd0;
    reg     [2:0]   set_time_mode_dd0;
    reg             time_mode_strobe_dd0;
    reg     [31:0]  rx_sample_bytes_dd0;
    reg     [31:0]  max_sample_bytes_per_packet_dd0;
    reg             capture_one_block_dd0;
    reg     [63:0]  rx_sync_timestamp_dd0;
    reg             rx_sync_timestamp_strobe_dd0;
    reg     [1:0]   rx_mode_dd0;
    reg             rx_mode_strobe_dd0;
    reg             mode_exit_dd0;
    reg             stream_start_dd0;
    reg     [7:0]   channel_enable_dd0;
    reg             sync_in_dd0;

    reg     [63:0]  set_vita_timestamp_dd1;
    reg     [2:0]   set_time_mode_dd1;
    reg             time_mode_strobe_dd1;
    reg     [31:0]  rx_sample_bytes_dd1;
    reg     [31:0]  max_sample_bytes_per_packet_dd1;
    reg             capture_one_block_dd1;
    reg     [63:0]  rx_sync_timestamp_dd1;
    reg             rx_sync_timestamp_strobe_dd1;
    reg     [1:0]   rx_mode_dd1;
    reg             rx_mode_strobe_dd1;
    reg             mode_exit_dd1;
    reg             stream_start_dd1;
    reg     [7:0]   channel_enable_dd1;
    reg             sync_in_dd1;

    wire    [63:0]  set_vita_timestamp;
    wire    [2:0]   set_time_mode;
    wire            time_mode_strobe;
    wire    [31:0]  rx_sample_bytes;
    wire    [31:0]  max_sample_bytes_per_packet;
    wire            capture_one_block;
    wire    [63:0]  rx_sync_timestamp;
    wire            rx_sync_timestamp_strobe;
    wire    [1:0]   rx_mode;
    wire            rx_mode_strobe;
    wire            mode_exit;
    wire            stream_start;
    wire    [7:0]   channel_enable;
    wire            sync_in;

    wire            rx_tvalid;
    wire    [63:0]  rx_tdata;
    wire            rx_tlast;
    wire            rx_tready;
    wire            capture_idle_radio;
    wire            stop_done_radio;

    reg             capture_idle_meta;
    reg             capture_idle_sync;
    reg             stop_done_meta;
    reg             stop_done_sync;

    wire [64:0] rx_fifo_2clk_dout;
    wire        rx_fifo_2clk_tvalid;
    wire        rx_fifo_2clk_tready;

    always @(posedge radio_clk) begin
        set_vita_timestamp_dd0 <= set_vita_timestamp_b;
        set_time_mode_dd0 <= set_time_mode_b;
        time_mode_strobe_dd0 <= time_mode_strobe_b;
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
        sync_in_dd0 <= sync_in_b;

        set_vita_timestamp_dd1 <= set_vita_timestamp_dd0;
        set_time_mode_dd1 <= set_time_mode_dd0;
        time_mode_strobe_dd1 <= time_mode_strobe_dd0;
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
        sync_in_dd1 <= sync_in_dd0;

        pps_del <= {pps_del[0], pps};
    end

    assign set_vita_timestamp         = set_vita_timestamp_dd1;
    assign set_time_mode              = set_time_mode_dd1;
    assign time_mode_strobe           = (~time_mode_strobe_dd1 & time_mode_strobe_dd0);
    assign rx_sample_bytes            = rx_sample_bytes_dd1;
    assign max_sample_bytes_per_packet = max_sample_bytes_per_packet_dd1;
    assign capture_one_block          = (~capture_one_block_dd1 & capture_one_block_dd0);
    assign rx_sync_timestamp          = rx_sync_timestamp_dd1;
    assign rx_sync_timestamp_strobe   = rx_sync_timestamp_strobe_dd1;
    assign rx_mode                    = rx_mode_dd1;
    assign rx_mode_strobe             = (~rx_mode_strobe_dd1 & rx_mode_strobe_dd0);
    assign mode_exit                  = (~mode_exit_dd1 & mode_exit_dd0);
    assign stream_start               = (~stream_start_dd1 & stream_start_dd0);
    assign channel_enable             = channel_enable_dd1;
    assign sync_in                    = sync_in_dd1;

    custom_timekeeper #(
        .INCREMENT (64'h1)
    ) u_custom_timekeeper_v2 (
        .clk                (radio_clk),
        .reset              (radio_rst | clear),
        .pps                (pps_del[1]),
        .sync_in            (sync_in),
        .strobe             (1'b1),
        .time_mode          (set_time_mode),
        .time_mode_strobe   (time_mode_strobe),
        .set_vita_timestamp (set_vita_timestamp),
        .vita_time          (vita_time),
        .vita_time_lastpps  (vita_time_last_pps),
        .sync_out           ()
    );

    t510_ai_iq_capture_v2 u_t510_ai_iq_capture_v2 (
        .radio_clk                   (radio_clk),
        .radio_rst                   (radio_rst | clear),
        .ch0_adc_i                   (ch0_adc_i),
        .ch0_adc_q                   (ch0_adc_q),
        .ch0_adc_valid               (ch0_adc_valid),
        .ch1_adc_i                   (ch1_adc_i),
        .ch1_adc_q                   (ch1_adc_q),
        .vita_time                   (vita_time),
        .channel_enable              (channel_enable),
        .rx_mode                     (rx_mode),
        .rx_mode_strobe              (rx_mode_strobe),
        .mode_exit                   (mode_exit),
        .stream_start                (stream_start),
        .rx_sync_timestamp           (rx_sync_timestamp),
        .rx_sync_timestamp_strobe    (rx_sync_timestamp_strobe),
        .capture_one_block           (capture_one_block),
        .rx_sample_bytes             (rx_sample_bytes),
        .max_sample_bytes_per_packet (max_sample_bytes_per_packet),
        .rx_tvalid                   (rx_tvalid),
        .rx_tdata                    (rx_tdata),
        .rx_tlast                    (rx_tlast),
        .rx_tready                   (rx_tready),
        .capture_idle                (capture_idle_radio),
        .capture_busy                (),
        .stop_done                   (stop_done_radio)
    );

    axi_fifo_2clk #(
        .WIDTH    (65),
        .SIZE     (10),
        .PIPELINE ("NONE")
    ) rx_fifo_2clk_v2 (
        .reset    (user_bus_rst),
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

    always @(posedge user_bus_clk) begin
        capture_idle_meta <= capture_idle_radio;
        capture_idle_sync <= capture_idle_meta;
        stop_done_meta    <= stop_done_radio;
        stop_done_sync    <= stop_done_meta;
    end

    assign capture_idle_b = capture_idle_sync;
    assign stop_done_b    = stop_done_sync;

endmodule

`default_nettype wire
