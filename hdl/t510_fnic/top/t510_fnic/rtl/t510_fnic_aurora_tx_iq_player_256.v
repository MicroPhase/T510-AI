`timescale 1ns / 1ps
`default_nettype none

module t510_fnic_aurora_tx_iq_player_256 #(
  parameter [15:0] AURORA_MAGIC_TX_DATA = 16'h5604,
  parameter [23:0] MAX_PACKET_BYTES     = 24'hfffff0,
  parameter [15:0] START_LEVEL_BEATS    = 16'd16,
  parameter        SKIP_HEADER_WORDS    = 1
) (
  input  wire         aurora_clk,
  input  wire         aurora_rst,
  input  wire         aurora_enable,
  input  wire [255:0] aurora_rx_tdata,
  input  wire         aurora_rx_tvalid,

  input  wire         dac_clk,
  input  wire         dac_rst,
  input  wire         dac_enable,
  output wire [31:0]  m_dac_tdata,
  output wire         m_dac_tvalid,
  input  wire         m_dac_tready,

  output wire [15:0]  fifo_wr_occupancy,
  output wire [15:0]  fifo_rd_occupancy,
  output reg  [31:0]  aurora_tx_frame_count,
  output reg  [31:0]  aurora_tx_beat_count,
  output reg  [31:0]  aurora_tx_bad_magic_count,
  output reg  [31:0]  aurora_tx_bad_length_count,
  output reg  [31:0]  aurora_tx_drop_frame_count,
  output reg  [31:0]  aurora_tx_overflow_count,
  output reg  [31:0]  dac_sample_count,
  output reg  [31:0]  dac_underflow_count,
  output reg  [63:0]  last_header,
  output reg  [63:0]  last_timestamp,
  output reg  [15:0]  last_seq,
  output reg  [7:0]   last_sid,
  output reg  [23:0]  last_length,
  output wire [23:0]  current_packet_bytes,

  output wire [1:0]   dbg_aurora_state,
  output wire [15:0]  dbg_aurora_beats_remaining,
  output wire         dbg_fifo_s_tvalid,
  output wire         dbg_fifo_s_tready,
  output wire         dbg_fifo_m_tvalid,
  output wire         dbg_fifo_m_tready,
  output wire         dbg_playback_started,
  output wire         dbg_beat_valid,
  output wire [2:0]   dbg_word_index,
  output wire         dbg_prefetched_valid,
  output wire         dbg_prefetch_pending,
  output wire         dbg_dac_play_enable,
  output wire         dbg_dac_out_ready,
  output wire         dbg_load_new_beat,
  output wire         dbg_word_fire,
  output wire         dbg_prefetch_issue
);

  localparam integer BYTES_PER_BEAT = 32;
  localparam integer PREFIX_BYTES = 16;
  localparam integer WORDS_PER_BEAT = 8;
  localparam integer FIRST_PAYLOAD_WORD = SKIP_HEADER_WORDS ? 4 : 0;
  localparam [2:0] LAST_WORD_INDEX = WORDS_PER_BEAT[2:0] - 1'b1;
  localparam [1:0] AURORA_SEARCH = 2'd0;
  localparam [1:0] AURORA_STREAM = 2'd1;
  localparam [1:0] AURORA_DROP = 2'd2;

  reg [1:0]  aurora_state = AURORA_SEARCH;
  reg [31:0] aurora_beats_remaining = 32'd0;

  wire [63:0] header = aurora_rx_tdata[63:0];
  wire [15:0] magic_type = header[63:48];
  wire [15:0] seq = header[47:32];
  wire [7:0]  sid = header[31:24];
  wire [23:0] length = header[23:0];
  wire [31:0] length_ext = {8'd0, length};
  wire [31:0] max_packet_bytes_ext = {8'd0, MAX_PACKET_BYTES};
  wire [31:0] packet_beats = (length_ext + BYTES_PER_BEAT - 1) >> 5;
  wire        magic_ok = (magic_type == AURORA_MAGIC_TX_DATA);
  wire        length_ok = (length_ext >= PREFIX_BYTES) &&
                          (length_ext <= max_packet_bytes_ext) &&
                          (packet_beats != 32'd0);
  wire        header_ok = magic_ok && length_ok;
  wire        aurora_input_fire = aurora_enable && aurora_rx_tvalid;
  wire        fifo_s_tready;
  wire        fifo_s_tvalid =
    aurora_input_fire &&
    (((aurora_state == AURORA_SEARCH) && header_ok) ||
     (aurora_state == AURORA_STREAM));

  wire [256:0] fifo_s_tdata;
  wire [256:0] fifo_m_tdata;
  wire [255:0] fifo_m_beat;
  wire         fifo_m_first_beat;
  wire         fifo_m_tvalid;
  wire         fifo_m_tready;

  reg [255:0] beat_word = 256'd0;
  reg         beat_valid = 1'b0;
  reg [2:0]   word_index = 3'd0;
  reg [255:0] prefetched_beat = 256'd0;
  reg         prefetched_first_beat = 1'b0;
  reg         prefetched_valid = 1'b0;
  reg         prefetch_pending = 1'b0;
  reg         playback_started = 1'b0;
  reg [31:0]  dac_tdata_r = 32'd0;
  reg         dac_tvalid_r = 1'b0;

  wire        playback_can_start =
    playback_started || (fifo_rd_occupancy >= START_LEVEL_BEATS);
  wire        dac_play_enable = dac_enable && playback_can_start;
  wire        dac_out_ready = !dac_tvalid_r || m_dac_tready;
  wire        load_new_beat = !beat_valid && fifo_m_tvalid && dac_out_ready;
  wire        word_fire = dac_play_enable && beat_valid && dac_out_ready;
  wire [31:0] selected_word = beat_word[{word_index, 5'b00000} +: 32];
  wire        last_word_in_beat = (word_index == LAST_WORD_INDEX);
  wire        prefetch_word = (word_index == (LAST_WORD_INDEX - 1'b1));
  wire        prefetch_issue = dac_play_enable && beat_valid && dac_out_ready &&
                               prefetch_word && !prefetched_valid &&
                               !prefetch_pending && fifo_m_tvalid;

  assign fifo_s_tdata = {(aurora_state == AURORA_SEARCH), aurora_rx_tdata};
  assign fifo_m_beat = fifo_m_tdata[255:0];
  assign fifo_m_first_beat = fifo_m_tdata[256];
  assign fifo_m_tready = dac_play_enable && (load_new_beat || prefetch_issue);
  assign m_dac_tdata = dac_tdata_r;
  assign m_dac_tvalid = dac_play_enable && dac_tvalid_r;
  assign current_packet_bytes = last_length;
  assign dbg_aurora_state = aurora_state;
  assign dbg_aurora_beats_remaining =
    (aurora_beats_remaining > 32'h0000ffff) ? 16'hffff :
                                              aurora_beats_remaining[15:0];
  assign dbg_fifo_s_tvalid = fifo_s_tvalid;
  assign dbg_fifo_s_tready = fifo_s_tready;
  assign dbg_fifo_m_tvalid = fifo_m_tvalid;
  assign dbg_fifo_m_tready = fifo_m_tready;
  assign dbg_playback_started = playback_started;
  assign dbg_beat_valid = beat_valid;
  assign dbg_word_index = word_index;
  assign dbg_prefetched_valid = prefetched_valid;
  assign dbg_prefetch_pending = prefetch_pending;
  assign dbg_dac_play_enable = dac_play_enable;
  assign dbg_dac_out_ready = dac_out_ready;
  assign dbg_load_new_beat = load_new_beat;
  assign dbg_word_fire = word_fire;
  assign dbg_prefetch_issue = prefetch_issue;

  always @(posedge aurora_clk) begin
    if (aurora_rst || !aurora_enable) begin
      aurora_state <= AURORA_SEARCH;
      aurora_beats_remaining <= 32'd0;
      aurora_tx_frame_count <= 32'd0;
      aurora_tx_beat_count <= 32'd0;
      aurora_tx_bad_magic_count <= 32'd0;
      aurora_tx_bad_length_count <= 32'd0;
      aurora_tx_drop_frame_count <= 32'd0;
      aurora_tx_overflow_count <= 32'd0;
      last_header <= 64'd0;
      last_timestamp <= 64'd0;
      last_seq <= 16'd0;
      last_sid <= 8'd0;
      last_length <= 24'd0;
    end else if (aurora_input_fire) begin
      case (aurora_state)
      AURORA_SEARCH: begin
        last_header <= header;
        last_timestamp <= aurora_rx_tdata[127:64];
        last_seq <= seq;
        last_sid <= sid;
        last_length <= length;
        if (!magic_ok)
          aurora_tx_bad_magic_count <= aurora_tx_bad_magic_count + 1'b1;
        if (magic_ok && !length_ok)
          aurora_tx_bad_length_count <= aurora_tx_bad_length_count + 1'b1;

        if (header_ok && fifo_s_tready) begin
          aurora_tx_frame_count <= aurora_tx_frame_count + 1'b1;
          aurora_tx_beat_count <= aurora_tx_beat_count + 1'b1;
          if (packet_beats > 32'd1) begin
            aurora_state <= AURORA_STREAM;
            aurora_beats_remaining <= packet_beats - 1'b1;
          end else begin
            aurora_state <= AURORA_SEARCH;
            aurora_beats_remaining <= 32'd0;
          end
        end else begin
          if (header_ok && !fifo_s_tready)
            aurora_tx_overflow_count <= aurora_tx_overflow_count + 1'b1;
          aurora_tx_drop_frame_count <= aurora_tx_drop_frame_count + 1'b1;
          if (length_ok && packet_beats > 32'd1) begin
            aurora_state <= AURORA_DROP;
            aurora_beats_remaining <= packet_beats - 1'b1;
          end else begin
            aurora_state <= AURORA_SEARCH;
            aurora_beats_remaining <= 32'd0;
          end
        end
      end

      AURORA_STREAM: begin
        if (fifo_s_tready) begin
          aurora_tx_beat_count <= aurora_tx_beat_count + 1'b1;
          if (aurora_beats_remaining <= 32'd1) begin
            aurora_state <= AURORA_SEARCH;
            aurora_beats_remaining <= 32'd0;
          end else begin
            aurora_beats_remaining <= aurora_beats_remaining - 1'b1;
          end
        end else begin
          aurora_tx_overflow_count <= aurora_tx_overflow_count + 1'b1;
          aurora_tx_drop_frame_count <= aurora_tx_drop_frame_count + 1'b1;
          if (aurora_beats_remaining <= 32'd1) begin
            aurora_state <= AURORA_SEARCH;
            aurora_beats_remaining <= 32'd0;
          end else begin
            aurora_state <= AURORA_DROP;
            aurora_beats_remaining <= aurora_beats_remaining - 1'b1;
          end
        end
      end

      AURORA_DROP: begin
        if (aurora_beats_remaining <= 32'd1) begin
          aurora_state <= AURORA_SEARCH;
          aurora_beats_remaining <= 32'd0;
        end else begin
          aurora_beats_remaining <= aurora_beats_remaining - 1'b1;
        end
      end

      default: begin
        aurora_state <= AURORA_SEARCH;
        aurora_beats_remaining <= 32'd0;
      end
      endcase
    end
  end

  always @(posedge dac_clk) begin
    if (dac_rst || !dac_enable) begin
      beat_word <= 256'd0;
      beat_valid <= 1'b0;
      word_index <= FIRST_PAYLOAD_WORD[2:0];
      prefetched_beat <= 256'd0;
      prefetched_first_beat <= 1'b0;
      prefetched_valid <= 1'b0;
      prefetch_pending <= 1'b0;
      playback_started <= 1'b0;
      dac_tdata_r <= 32'd0;
      dac_tvalid_r <= 1'b0;
      dac_sample_count <= 32'd0;
      dac_underflow_count <= 32'd0;
    end else begin
      if (!playback_started && fifo_rd_occupancy >= START_LEVEL_BEATS)
        playback_started <= 1'b1;

      if (dac_tvalid_r && m_dac_tready)
        dac_tvalid_r <= 1'b0;

      if (prefetch_pending) begin
        prefetched_beat <= fifo_m_beat;
        prefetched_first_beat <= fifo_m_first_beat;
        prefetched_valid <= 1'b1;
        prefetch_pending <= 1'b0;
      end
      if (prefetch_issue)
        prefetch_pending <= 1'b1;

      if (load_new_beat) begin
        beat_word <= fifo_m_beat;
        beat_valid <= 1'b1;
        word_index <= fifo_m_first_beat ? FIRST_PAYLOAD_WORD[2:0] : 3'd0;
      end else if (playback_started && !beat_valid && dac_out_ready) begin
        dac_underflow_count <= dac_underflow_count + 1'b1;
        playback_started <= 1'b0;
      end

      if (word_fire) begin
        dac_tdata_r <= selected_word;
        dac_tvalid_r <= 1'b1;
        dac_sample_count <= dac_sample_count + 1'b1;
        if (last_word_in_beat) begin
          if (prefetch_pending) begin
            beat_word <= fifo_m_beat;
            beat_valid <= 1'b1;
            word_index <= fifo_m_first_beat ? FIRST_PAYLOAD_WORD[2:0] : 3'd0;
            prefetched_valid <= 1'b0;
            prefetch_pending <= 1'b0;
          end else if (prefetched_valid) begin
            beat_word <= prefetched_beat;
            beat_valid <= 1'b1;
            word_index <= prefetched_first_beat ? FIRST_PAYLOAD_WORD[2:0] : 3'd0;
            prefetched_valid <= 1'b0;
          end else begin
            beat_valid <= 1'b0;
            word_index <= FIRST_PAYLOAD_WORD[2:0];
          end
        end else begin
          word_index <= word_index + 1'b1;
        end
      end
    end
  end

  t510_fnic_axis_async_fifo_256 #(
    .ADDR_WIDTH(13),
    .DATA_WIDTH(257)
  ) tx_iq_fifo_i (
    .s_clk         (aurora_clk),
    .s_rst         (aurora_rst),
    .s_axis_tdata  (fifo_s_tdata),
    .s_axis_tvalid (fifo_s_tvalid),
    .s_axis_tready (fifo_s_tready),
    .m_clk         (dac_clk),
    .m_rst         (dac_rst),
    .m_axis_tdata  (fifo_m_tdata),
    .m_axis_tvalid (fifo_m_tvalid),
    .m_axis_tready (fifo_m_tready),
    .wr_occupancy  (fifo_wr_occupancy),
    .rd_occupancy  (fifo_rd_occupancy)
  );

endmodule

`default_nettype wire
