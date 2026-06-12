`default_nettype none
`timescale 1ns / 1ps

module t510_ai_iq_capture_v2(
    input   wire            radio_clk                   ,
    input   wire            radio_rst                   ,
    input   wire    [15:0]  ch0_adc_i                   ,
    input   wire    [15:0]  ch0_adc_q                   ,
    input   wire            ch0_adc_valid               ,
    input   wire    [15:0]  ch1_adc_i                   ,
    input   wire    [15:0]  ch1_adc_q                   ,

    input   wire    [63:0]  vita_time                   ,

    input   wire    [7:0]   channel_enable              ,
    input   wire    [1:0]   rx_mode                     ,
    input   wire            rx_mode_strobe              ,
    input   wire            mode_exit                   ,
    input   wire            stream_start                ,
    input   wire    [63:0]  rx_sync_timestamp           ,
    input   wire            rx_sync_timestamp_strobe    ,
    input   wire            capture_one_block           ,
    input   wire    [31:0]  rx_sample_bytes             ,
    input   wire    [31:0]  max_sample_bytes_per_packet ,

    output  wire            rx_tvalid                   ,
    output  wire    [63:0]  rx_tdata                    ,
    output  wire            rx_tlast                    ,
    input   wire            rx_tready                   ,

    output  wire            capture_idle                ,
    output  wire            capture_busy                ,
    output  reg             stop_done
    );

    localparam [1:0] STREAM_MODE = 2'd1;
    localparam [1:0] PACKET_MODE = 2'd2;
    localparam [1:0] SYNC_MODE   = 2'd3;

    localparam [1:0] TX_IDLE     = 2'd0;
    localparam [1:0] TX_HEAD0    = 2'd1;
    localparam [1:0] TX_HEAD1    = 2'd2;
    localparam [1:0] TX_PAYLOAD  = 2'd3;

    localparam [31:0] IQ_MAGIC   = 32'h5435_3151; // "T51Q"
    localparam [7:0]  IQ_VERSION = 8'd1;

    wire [63:0] cpack_data;
    wire        cpack_valid;
    wire [63:0] vita_time_cpack;

    function automatic [31:0] sanitize_capture_bytes(
        input [31:0] requested_bytes
    );
        reg [31:0] aligned_bytes;
        begin
            aligned_bytes = {requested_bytes[31:3], 3'b000};
            if (aligned_bytes == 32'd0)
                sanitize_capture_bytes = 32'd8;
            else
                sanitize_capture_bytes = aligned_bytes;
        end
    endfunction

    function automatic [15:0] sanitize_packet_bytes(
        input [31:0] requested_bytes
    );
        reg [31:0] aligned_bytes;
        begin
            aligned_bytes = {requested_bytes[31:3], 3'b000};
            if (aligned_bytes == 32'd0)
                sanitize_packet_bytes = 16'd8;
            else if (aligned_bytes > 32'd8192)
                sanitize_packet_bytes = 16'd8192;
            else
                sanitize_packet_bytes = aligned_bytes[15:0];
        end
    endfunction

    function automatic [15:0] calc_packet_target_bytes(
        input [31:0] remaining_bytes,
        input [15:0] packet_bytes
    );
        begin
            if (remaining_bytes == 32'd0)
                calc_packet_target_bytes = 16'd0;
            else if (remaining_bytes > {16'd0, packet_bytes})
                calc_packet_target_bytes = packet_bytes;
            else
                calc_packet_target_bytes = remaining_bytes[15:0];
        end
    endfunction

    wire [31:0] cfg_capture_bytes = sanitize_capture_bytes(rx_sample_bytes);
    wire [15:0] cfg_packet_bytes  = sanitize_packet_bytes(max_sample_bytes_per_packet);

    reg  [1:0]  capture_mode;
    reg         stream_enable;
    reg         capture_one_block_pending;
    reg         sync_wait;
    reg  [63:0] sync_target_time;
    reg         stop_requested;

    reg         chunk_active;
    reg  [31:0] chunk_bytes_left;
    reg         packet_open;
    reg  [15:0] packet_target_bytes;
    reg  [15:0] packet_written_bytes;
    reg  [63:0] packet_first_time;

    reg         start_chunk_now;
    reg         active_chunk;
    reg  [31:0] active_chunk_bytes_left;
    reg         active_packet_open;
    reg  [15:0] active_packet_target;
    reg  [15:0] active_packet_written;
    reg  [63:0] active_packet_first_time;
    reg  [31:0] next_chunk_bytes_left;
    reg  [15:0] next_packet_target;
    reg  [15:0] next_packet_written;
    reg  [63:0] next_packet_first_time;
    reg         close_packet_now;
    reg         accept_sample_now;

    wire [63:0] sample_fifo_o_tdata;
    wire        sample_fifo_o_tvalid;
    wire        sample_fifo_o_tready;
    wire        sample_fifo_i_tready;

    wire [79:0] meta_fifo_o_tdata;
    wire        meta_fifo_o_tvalid;
    wire        meta_fifo_o_tready;
    wire        meta_fifo_i_tready;

    reg  [63:0] sample_fifo_i_tdata;
    reg         sample_fifo_i_tvalid;
    reg  [79:0] meta_fifo_i_tdata;
    reg         meta_fifo_i_tvalid;

    reg  [1:0]  tx_state;
    reg  [63:0] tx_header_time;
    reg  [15:0] tx_payload_bytes;
    reg  [15:0] tx_payload_words_left;

    custom_rx_cpack #(
        .MAX_CHAN     (2),
        .SAMPLE_WIDTH (32)
    ) u_custom_rx_cpack (
        .radio_clk       (radio_clk),
        .radio_rst       (radio_rst),
        .channel_enable  (channel_enable),
        .ch0_adc_i       (ch0_adc_i),
        .ch0_adc_q       (ch0_adc_q),
        .ch0_adc_valid   (ch0_adc_valid),
        .ch1_adc_i       (ch1_adc_i),
        .ch1_adc_q       (ch1_adc_q),
        .vita_time       (vita_time),
        .cpack_data      (cpack_data),
        .cpack_valid     (cpack_valid),
        .vita_time_cpack (vita_time_cpack)
    );

    axi_fifo #(
        .WIDTH (64),
        .SIZE  (11)
    ) sample_fifo_i (
        .clk      (radio_clk),
        .reset    (radio_rst),
        .clear    (1'b0),
        .i_tdata  (sample_fifo_i_tdata),
        .i_tvalid (sample_fifo_i_tvalid),
        .i_tready (sample_fifo_i_tready),
        .o_tdata  (sample_fifo_o_tdata),
        .o_tvalid (sample_fifo_o_tvalid),
        .o_tready (sample_fifo_o_tready),
        .space    (),
        .occupied ()
    );

    axi_fifo #(
        .WIDTH (80),
        .SIZE  (5)
    ) meta_fifo_i (
        .clk      (radio_clk),
        .reset    (radio_rst),
        .clear    (1'b0),
        .i_tdata  (meta_fifo_i_tdata),
        .i_tvalid (meta_fifo_i_tvalid),
        .i_tready (meta_fifo_i_tready),
        .o_tdata  (meta_fifo_o_tdata),
        .o_tvalid (meta_fifo_o_tvalid),
        .o_tready (meta_fifo_o_tready),
        .space    (),
        .occupied ()
    );

    always @(posedge radio_clk) begin
        sample_fifo_i_tvalid <= 1'b0;
        meta_fifo_i_tvalid   <= 1'b0;
        stop_done            <= 1'b0;

        if (radio_rst) begin
            capture_mode               <= PACKET_MODE;
            stream_enable              <= 1'b0;
            capture_one_block_pending  <= 1'b0;
            sync_wait                  <= 1'b0;
            sync_target_time           <= 64'd0;
            stop_requested             <= 1'b0;
            chunk_active               <= 1'b0;
            chunk_bytes_left           <= 32'd0;
            packet_open                <= 1'b0;
            packet_target_bytes        <= 16'd0;
            packet_written_bytes       <= 16'd0;
            packet_first_time          <= 64'd0;
        end else begin
            if (rx_mode_strobe) begin
                capture_mode <= rx_mode;
                if (rx_mode != STREAM_MODE)
                    stream_enable <= 1'b0;
                if (rx_mode != PACKET_MODE)
                    capture_one_block_pending <= 1'b0;
                if (rx_mode != SYNC_MODE)
                    sync_wait <= 1'b0;
            end

            if (rx_sync_timestamp_strobe && !stop_requested) begin
                sync_target_time <= rx_sync_timestamp;
                sync_wait        <= 1'b1;
            end

            if (stream_start && (capture_mode == STREAM_MODE) && !stop_requested)
                stream_enable <= 1'b1;

            if (capture_one_block && (capture_mode == PACKET_MODE) && !stop_requested)
                capture_one_block_pending <= 1'b1;

            if (mode_exit) begin
                stream_enable             <= 1'b0;
                capture_one_block_pending <= 1'b0;
                sync_wait                 <= 1'b0;
                stop_requested            <= 1'b1;
            end

            if (cpack_valid) begin
                start_chunk_now          = 1'b0;
                active_chunk             = chunk_active;
                active_chunk_bytes_left  = chunk_bytes_left;
                active_packet_open       = packet_open;
                active_packet_target     = packet_target_bytes;
                active_packet_written    = packet_written_bytes;
                active_packet_first_time = packet_first_time;
                next_packet_first_time   = packet_first_time;

                if (!active_chunk && !active_packet_open && !stop_requested) begin
                    if ((capture_mode == PACKET_MODE) && capture_one_block_pending) begin
                        start_chunk_now = 1'b1;
                    end else if ((capture_mode == STREAM_MODE) && stream_enable) begin
                        start_chunk_now = 1'b1;
                    end else if ((capture_mode == SYNC_MODE) && sync_wait
                                 && (vita_time_cpack >= sync_target_time)) begin
                        start_chunk_now = 1'b1;
                        sync_wait <= 1'b0;
                    end

                    if (start_chunk_now) begin
                        active_chunk            = 1'b1;
                        active_chunk_bytes_left = cfg_capture_bytes;
                        if (capture_mode == PACKET_MODE)
                            capture_one_block_pending <= 1'b0;
                    end
                end

                if (active_chunk) begin
                    if (!active_packet_open) begin
                        next_packet_target = calc_packet_target_bytes(
                            active_chunk_bytes_left, cfg_packet_bytes
                        );
                        next_packet_written    = 16'd8;
                        next_packet_first_time = vita_time_cpack;
                    end else begin
                        next_packet_target  = active_packet_target;
                        next_packet_written = active_packet_written + 16'd8;
                    end

                    close_packet_now = (next_packet_written >= next_packet_target);
                    accept_sample_now = sample_fifo_i_tready
                                     && (!close_packet_now || meta_fifo_i_tready)
                                     && (next_packet_target != 16'd0);

                    if (accept_sample_now) begin
                        sample_fifo_i_tvalid <= 1'b1;
                        sample_fifo_i_tdata  <= cpack_data;
                        next_chunk_bytes_left = active_chunk_bytes_left - 32'd8;
                        chunk_bytes_left      <= next_chunk_bytes_left;

                        if (close_packet_now) begin
                            meta_fifo_i_tvalid <= 1'b1;
                            meta_fifo_i_tdata  <= {next_packet_first_time, next_packet_target};
                            active_packet_open   = 1'b0;
                            active_packet_target = 16'd0;
                            active_packet_written = 16'd0;
                            active_packet_first_time = 64'd0;
                            if (stop_requested || (next_chunk_bytes_left == 32'd0)) begin
                                active_chunk            = 1'b0;
                                active_chunk_bytes_left = 32'd0;
                            end else begin
                                active_chunk            = 1'b1;
                                active_chunk_bytes_left = next_chunk_bytes_left;
                            end
                        end else begin
                            active_packet_open       = 1'b1;
                            active_packet_target     = next_packet_target;
                            active_packet_written    = next_packet_written;
                            active_packet_first_time = next_packet_first_time;
                            active_chunk_bytes_left  = next_chunk_bytes_left;
                            if (next_chunk_bytes_left == 32'd0) begin
                                active_chunk = 1'b0;
                            end
                        end

                        chunk_active         <= active_chunk;
                        packet_open          <= active_packet_open;
                        packet_target_bytes  <= active_packet_target;
                        packet_written_bytes <= active_packet_written;
                        packet_first_time    <= active_packet_first_time;
                    end
                end
            end

            if (stop_requested
                && !chunk_active
                && !packet_open
                && !sample_fifo_o_tvalid
                && !meta_fifo_o_tvalid
                && (tx_state == TX_IDLE)) begin
                stop_requested <= 1'b0;
                stop_done      <= 1'b1;
            end
        end
    end

    assign meta_fifo_o_tready   = (tx_state == TX_IDLE);
    assign sample_fifo_o_tready = (tx_state == TX_PAYLOAD) && rx_tready && sample_fifo_o_tvalid;

    assign rx_tvalid = (tx_state == TX_HEAD0) ? 1'b1 :
                       (tx_state == TX_HEAD1) ? 1'b1 :
                       (tx_state == TX_PAYLOAD) ? sample_fifo_o_tvalid : 1'b0;

    assign rx_tdata = (tx_state == TX_HEAD0) ?
                      {IQ_MAGIC, IQ_VERSION, channel_enable, tx_payload_bytes} :
                      (tx_state == TX_HEAD1) ? tx_header_time :
                      (tx_state == TX_PAYLOAD) ? sample_fifo_o_tdata : 64'd0;

    assign rx_tlast = (tx_state == TX_PAYLOAD) && sample_fifo_o_tvalid && (tx_payload_words_left == 16'd1);

    always @(posedge radio_clk) begin
        if (radio_rst) begin
            tx_state             <= TX_IDLE;
            tx_header_time       <= 64'd0;
            tx_payload_bytes     <= 16'd0;
            tx_payload_words_left <= 16'd0;
        end else begin
            case (tx_state)
            TX_IDLE: begin
                if (meta_fifo_o_tvalid) begin
                    tx_header_time        <= meta_fifo_o_tdata[79:16];
                    tx_payload_bytes      <= meta_fifo_o_tdata[15:0];
                    tx_payload_words_left <= meta_fifo_o_tdata[15:0] >> 3;
                    tx_state              <= TX_HEAD0;
                end
            end
            TX_HEAD0: begin
                if (rx_tready)
                    tx_state <= TX_HEAD1;
            end
            TX_HEAD1: begin
                if (rx_tready)
                    tx_state <= TX_PAYLOAD;
            end
            TX_PAYLOAD: begin
                if (sample_fifo_o_tvalid && rx_tready) begin
                    if (tx_payload_words_left == 16'd1) begin
                        tx_state             <= TX_IDLE;
                        tx_payload_words_left <= 16'd0;
                    end else begin
                        tx_payload_words_left <= tx_payload_words_left - 16'd1;
                    end
                end
            end
            default: tx_state <= TX_IDLE;
            endcase
        end
    end

    assign capture_busy = stop_requested
                       || stream_enable
                       || capture_one_block_pending
                       || sync_wait
                       || chunk_active
                       || packet_open
                       || sample_fifo_o_tvalid
                       || meta_fifo_o_tvalid
                       || (tx_state != TX_IDLE);

    assign capture_idle = !capture_busy;

endmodule

`default_nettype wire
