//
// Copyright 2026
//
// SPDX-License-Identifier: LGPL-3.0-or-later
//
// Module: chdr_epid_loopback
//
// Description:
//
//   Shared CHDR endpoint for the T510-AI 100GbE design.
//
//   Current responsibilities:
//   - Keep the original SINK / SOURCE CTRL loopback path for debug
//   - Accept IQ packets from iq_framework_wrapper on a 64-bit AXI stream
//   - Repackage each IQ packet into a CHDR DATA packet and send it to host
//
`timescale 1ns / 1ps
`default_nettype none

module chdr_epid_loopback #(
  parameter int          CHDR_W                        = 512,
  parameter logic [15:0] SINK_DST_EPID                = 16'h4000,
  parameter logic [15:0] CTRL_DST_EPID                = 16'h4001,
  parameter logic [15:0] IQ_CAPTURE_DST_EPID          = 16'h4002,
  parameter logic [15:0] RETURN_DST_EPID              = 16'h1234,
  parameter int unsigned DEFAULT_SOURCE_PAYLOAD_BYTES = 1024,
  parameter int unsigned MAX_SOURCE_PAYLOAD_BYTES     = 8192,
  parameter int unsigned MAX_IQ_PACKET_BYTES          = 16384
) (
  input  wire               clk,
  input  wire               rst,

  input  wire [CHDR_W-1:0]  s_axis_tdata,
  input  wire               s_axis_tlast,
  input  wire               s_axis_tvalid,
  output logic              s_axis_tready,

  input  wire [63:0]        iq_s_axis_tdata,
  input  wire [7:0]         iq_s_axis_tkeep,
  input  wire               iq_s_axis_tlast,
  input  wire               iq_s_axis_tvalid,
  output logic              iq_s_axis_tready,
  input  wire               iq_clear,

  output logic [CHDR_W-1:0] m_axis_tdata,
  output logic              m_axis_tlast,
  output logic              m_axis_tvalid,
  input  wire               m_axis_tready
);

  localparam int unsigned WORD_BYTES         = CHDR_W / 8;
  localparam int unsigned WORDS_PER_BEAT     = CHDR_W / 64;
  localparam int unsigned TEST_HEADER_BYTES  = 28;
  localparam int unsigned IQ_MAX_PACKET_WORDS = (MAX_IQ_PACKET_BYTES + 7) / 8;
  /* verilator lint_off WIDTH */
  localparam logic [15:0] WORD_BYTES_16      = CHDR_W / 8;
  localparam logic [15:0] WORDS_PER_BEAT_16  = CHDR_W / 64;
  /* verilator lint_on WIDTH */
  localparam logic [31:0] TEST_MAGIC         = 32'h4655_4450;
  localparam logic [15:0] TEST_VERSION       = 16'd1;
  localparam logic [15:0] TEST_HEADER_SIZE   = 16'd28;
  localparam logic [31:0] CTRL_MAGIC         = 32'h5352_4345;
  localparam logic [15:0] CTRL_VERSION       = 16'd1;
  localparam logic [15:0] CTRL_CMD_START     = 16'd1;
  localparam logic [15:0] CTRL_CMD_STOP      = 16'd2;
  localparam logic [2:0]  CHDR_PKT_TYPE_DATA = 3'd6;
  localparam logic [2:0]  CHDR_PKT_TYPE_DATA_TS = 3'd7;

  logic        rx_in_packet;
  logic        rx_is_ctrl_packet;
  logic [15:0] rx_word_index;

  logic        source_enable;
  logic [15:0] source_payload_bytes;
  logic [63:0] source_packet_limit;
  logic [63:0] source_packets_sent;
  logic [63:0] source_seq;

  logic        tx_active;
  logic        tx_is_iq;
  logic [15:0] tx_payload_bytes;
  logic [15:0] tx_packet_bytes;
  logic [15:0] tx_total_beats;
  logic [15:0] tx_beat_index;
  logic [63:0] tx_seq;

  logic [63:0] iq_packet_mem [0:IQ_MAX_PACKET_WORDS-1];
  logic [15:0] iq_packet_words;
  logic [15:0] iq_payload_bytes;
  logic [15:0] iq_write_word_index;
  logic [15:0] iq_write_bytes;
  logic [63:0] iq_seq;
  logic        iq_packet_ready;
  logic        iq_drop_packet;
  logic        iq_clear_pending;
  logic        iq_clear_meta;
  logic        iq_clear_sync;
  logic        iq_clear_sync_d;

  wire         iq_clear_pulse = iq_clear_sync & ~iq_clear_sync_d;

  function automatic [63:0] chdr_build_header(
    input logic [5:0]  vc,
    input logic        eob,
    input logic        eov,
    input logic [2:0]  pkt_type,
    input logic [4:0]  num_mdata,
    input logic [15:0] seq_num,
    input logic [15:0] length,
    input logic [15:0] dst_epid
  );
    chdr_build_header = {vc, eob, eov, pkt_type, num_mdata, seq_num, length, dst_epid};
  endfunction

  function automatic [7:0] beat_byte(
    input logic [CHDR_W-1:0] word,
    input int unsigned       byte_idx
  );
    beat_byte = word[byte_idx*8 +: 8];
  endfunction

  function automatic [15:0] beat_be16(
    input logic [CHDR_W-1:0] word,
    input int unsigned       byte_idx
  );
    beat_be16 = {beat_byte(word, byte_idx), beat_byte(word, byte_idx + 1)};
  endfunction

  function automatic [31:0] beat_be32(
    input logic [CHDR_W-1:0] word,
    input int unsigned       byte_idx
  );
    beat_be32 = {
      beat_byte(word, byte_idx + 0),
      beat_byte(word, byte_idx + 1),
      beat_byte(word, byte_idx + 2),
      beat_byte(word, byte_idx + 3)
    };
  endfunction

  function automatic [63:0] beat_be64(
    input logic [CHDR_W-1:0] word,
    input int unsigned       byte_idx
  );
    beat_be64 = {
      beat_byte(word, byte_idx + 0),
      beat_byte(word, byte_idx + 1),
      beat_byte(word, byte_idx + 2),
      beat_byte(word, byte_idx + 3),
      beat_byte(word, byte_idx + 4),
      beat_byte(word, byte_idx + 5),
      beat_byte(word, byte_idx + 6),
      beat_byte(word, byte_idx + 7)
    };
  endfunction

  function automatic [7:0] be32_byte(
    input logic [31:0] value,
    input int unsigned byte_idx
  );
    be32_byte = value[(3-byte_idx)*8 +: 8];
  endfunction

  function automatic [7:0] be16_byte(
    input logic [15:0] value,
    input int unsigned byte_idx
  );
    be16_byte = value[(1-byte_idx)*8 +: 8];
  endfunction

  function automatic [7:0] be64_byte(
    input logic [63:0] value,
    input int unsigned byte_idx
  );
    be64_byte = value[(7-byte_idx)*8 +: 8];
  endfunction

  function automatic [15:0] sanitize_payload_bytes(
    input logic [31:0] requested_bytes
  );
    if (requested_bytes == 0) begin
      sanitize_payload_bytes = DEFAULT_SOURCE_PAYLOAD_BYTES[15:0];
    end else if (requested_bytes > MAX_SOURCE_PAYLOAD_BYTES) begin
      sanitize_payload_bytes = MAX_SOURCE_PAYLOAD_BYTES[15:0];
    end else begin
      sanitize_payload_bytes = requested_bytes[15:0];
    end
  endfunction

  function automatic [15:0] calc_packet_bytes(
    input logic [15:0] payload_bytes
  );
    calc_packet_bytes = WORD_BYTES_16 + payload_bytes;
  endfunction

  function automatic [15:0] calc_packet_beats(
    input logic [15:0] payload_bytes
  );
    calc_packet_beats = 16'd1 + ((payload_bytes + WORD_BYTES_16 - 16'd1) / WORD_BYTES_16);
  endfunction

  function automatic [7:0] source_payload_byte(
    input int unsigned payload_offset,
    input logic [15:0] payload_bytes,
    input logic [63:0] seq_num
  );
    logic [31:0] payload_len32;
    logic [63:0] timestamp_value;
    logic [7:0]  pattern_offset;

    payload_len32    = {16'd0, payload_bytes};
    timestamp_value  = seq_num;

    if (payload_offset < 4) begin
      source_payload_byte = be32_byte(TEST_MAGIC, payload_offset);
    end else if (payload_offset < 6) begin
      source_payload_byte = be16_byte(TEST_VERSION, payload_offset - 4);
    end else if (payload_offset < 8) begin
      source_payload_byte = be16_byte(TEST_HEADER_SIZE, payload_offset - 6);
    end else if (payload_offset < 12) begin
      source_payload_byte = be32_byte(payload_len32, payload_offset - 8);
    end else if (payload_offset < 20) begin
      source_payload_byte = be64_byte(seq_num, payload_offset - 12);
    end else if (payload_offset < 28) begin
      source_payload_byte = be64_byte(timestamp_value, payload_offset - 20);
    end else begin
      pattern_offset      = payload_offset[7:0] - TEST_HEADER_SIZE[7:0];
      source_payload_byte = seq_num[7:0] + pattern_offset;
    end
  endfunction

  function automatic [CHDR_W-1:0] build_source_payload_beat(
    input logic [15:0] payload_beat_idx,
    input logic [15:0] payload_bytes,
    input logic [63:0] seq_num
  );
    logic [CHDR_W-1:0] beat_word;
    int unsigned       byte_idx;
    int unsigned       payload_offset;
    logic [15:0]       total_payload_bytes;

    beat_word           = '0;
    total_payload_bytes = TEST_HEADER_SIZE + payload_bytes;
    for (byte_idx = 0; byte_idx < WORD_BYTES; byte_idx = byte_idx + 1) begin
      payload_offset = payload_beat_idx * WORD_BYTES + byte_idx;
      if (payload_offset < total_payload_bytes) begin
        beat_word[byte_idx*8 +: 8] = source_payload_byte(payload_offset, payload_bytes, seq_num);
      end
    end
    build_source_payload_beat = beat_word;
  endfunction

  function automatic [3:0] keep_byte_count(
    input logic [7:0] tkeep
  );
    int i;
    keep_byte_count = 4'd0;
    for (i = 0; i < 8; i = i + 1) begin
      keep_byte_count = keep_byte_count + {3'd0, tkeep[i]};
    end
  endfunction

  function automatic [63:0] apply_tkeep_mask(
    input logic [63:0] data,
    input logic [7:0]  tkeep
  );
    int i;
    apply_tkeep_mask = 64'd0;
    for (i = 0; i < 8; i = i + 1) begin
      if (tkeep[i]) begin
        apply_tkeep_mask[i*8 +: 8] = data[i*8 +: 8];
      end
    end
  endfunction

  wire is_data_pkt = (s_axis_tdata[55:53] == CHDR_PKT_TYPE_DATA)
                  || (s_axis_tdata[55:53] == CHDR_PKT_TYPE_DATA_TS);
  wire [15:0] rx_dst_epid = s_axis_tdata[15:0];

  assign s_axis_tready = 1'b1;
  assign iq_s_axis_tready = !rst && !iq_clear_pending && !iq_clear_pulse
                         && !iq_packet_ready && !tx_active
                         && !iq_drop_packet && (iq_write_word_index < IQ_MAX_PACKET_WORDS[15:0]);

  always_ff @(posedge clk) begin
    if (rst) begin
      iq_clear_meta   <= 1'b0;
      iq_clear_sync   <= 1'b0;
      iq_clear_sync_d <= 1'b0;
    end else begin
      iq_clear_meta   <= iq_clear;
      iq_clear_sync   <= iq_clear_meta;
      iq_clear_sync_d <= iq_clear_sync;
    end
  end

  always_comb begin
    int word_idx;
    int src_idx;

    m_axis_tdata  = '0;
    m_axis_tvalid = tx_active;
    m_axis_tlast  = tx_active && (tx_beat_index == (tx_total_beats - 16'd1));

    if (tx_active) begin
      if (tx_beat_index == 0) begin
        m_axis_tdata[63:0] = chdr_build_header(
          6'd0,
          1'b0,
          1'b0,
          CHDR_PKT_TYPE_DATA,
          5'd0,
          tx_seq[15:0],
          tx_packet_bytes,
          tx_is_iq ? IQ_CAPTURE_DST_EPID : RETURN_DST_EPID
        );
      end else if (tx_is_iq) begin
        for (word_idx = 0; word_idx < WORDS_PER_BEAT; word_idx = word_idx + 1) begin
          src_idx = (int'(tx_beat_index) - 1) * WORDS_PER_BEAT + word_idx;
          if (src_idx < iq_packet_words) begin
            m_axis_tdata[word_idx*64 +: 64] = iq_packet_mem[src_idx];
          end
        end
      end else begin
        m_axis_tdata = build_source_payload_beat(tx_beat_index - 16'd1, tx_payload_bytes, tx_seq);
      end
    end
  end

  always_ff @(posedge clk) begin
    logic [31:0] ctrl_magic;
    logic [15:0] ctrl_version;
    logic [15:0] ctrl_cmd;
    logic [31:0] ctrl_payload_bytes;
    logic [63:0] ctrl_packet_limit;
    logic [3:0]  iq_valid_bytes;

    if (rst) begin
      rx_in_packet         <= 1'b0;
      rx_is_ctrl_packet    <= 1'b0;
      rx_word_index        <= '0;
      source_enable        <= 1'b0;
      source_payload_bytes <= DEFAULT_SOURCE_PAYLOAD_BYTES[15:0];
      source_packet_limit  <= 64'd0;
      source_packets_sent  <= 64'd0;
      source_seq           <= 64'd0;
      tx_active            <= 1'b0;
      tx_is_iq             <= 1'b0;
      tx_payload_bytes     <= '0;
      tx_packet_bytes      <= '0;
      tx_total_beats       <= '0;
      tx_beat_index        <= '0;
      tx_seq               <= '0;
      iq_packet_words      <= '0;
      iq_payload_bytes     <= '0;
      iq_write_word_index  <= '0;
      iq_write_bytes       <= '0;
      iq_seq               <= '0;
      iq_packet_ready      <= 1'b0;
      iq_drop_packet       <= 1'b0;
      iq_clear_pending     <= 1'b0;
    end else begin
      if (iq_clear_pulse) begin
        if (tx_active && tx_is_iq) begin
          iq_clear_pending <= 1'b1;
        end else begin
          iq_packet_words     <= '0;
          iq_payload_bytes    <= '0;
          iq_write_word_index <= '0;
          iq_write_bytes      <= '0;
          iq_packet_ready     <= 1'b0;
          iq_drop_packet      <= 1'b0;
          iq_clear_pending    <= 1'b0;
        end
      end else begin
      if (s_axis_tvalid && s_axis_tready) begin
        if (!rx_in_packet) begin
          rx_in_packet      <= !s_axis_tlast;
          rx_is_ctrl_packet <= is_data_pkt && (rx_dst_epid == CTRL_DST_EPID);
          rx_word_index     <= 16'd0;
        end else begin
          if (rx_is_ctrl_packet && (rx_word_index == 16'd0)) begin
            ctrl_magic         = beat_be32(s_axis_tdata, 0);
            ctrl_version       = beat_be16(s_axis_tdata, 4);
            ctrl_cmd           = beat_be16(s_axis_tdata, 6);
            ctrl_payload_bytes = beat_be32(s_axis_tdata, 8);
            ctrl_packet_limit  = beat_be64(s_axis_tdata, 12);

            if ((ctrl_magic == CTRL_MAGIC) && (ctrl_version == CTRL_VERSION)) begin
              if (ctrl_cmd == CTRL_CMD_START) begin
                source_enable        <= 1'b1;
                source_payload_bytes <= sanitize_payload_bytes(ctrl_payload_bytes);
                source_packet_limit  <= ctrl_packet_limit;
                source_packets_sent  <= 64'd0;
                source_seq           <= 64'd0;
              end else if (ctrl_cmd == CTRL_CMD_STOP) begin
                source_enable       <= 1'b0;
                source_packet_limit <= 64'd0;
              end
            end
          end

          if (s_axis_tlast) begin
            rx_in_packet      <= 1'b0;
            rx_is_ctrl_packet <= 1'b0;
            rx_word_index     <= '0;
          end else begin
            rx_in_packet  <= 1'b1;
            rx_word_index <= rx_word_index + 16'd1;
          end
        end
      end

      if (iq_s_axis_tvalid && iq_s_axis_tready) begin
        iq_valid_bytes = keep_byte_count(iq_s_axis_tkeep);
        if (iq_write_word_index < IQ_MAX_PACKET_WORDS[15:0]) begin
          iq_packet_mem[iq_write_word_index[$clog2(IQ_MAX_PACKET_WORDS)-1:0]]
            <= apply_tkeep_mask(iq_s_axis_tdata, iq_s_axis_tkeep);
        end

        if (iq_s_axis_tlast) begin
          if (!iq_drop_packet) begin
            iq_packet_words <= iq_write_word_index + 16'd1;
            iq_payload_bytes <= iq_write_bytes + {{12{1'b0}}, iq_valid_bytes};
            iq_packet_ready <= 1'b1;
          end
          iq_write_word_index <= '0;
          iq_write_bytes <= '0;
          iq_drop_packet <= 1'b0;
        end else if (iq_write_word_index + 16'd1 >= IQ_MAX_PACKET_WORDS[15:0]) begin
          iq_drop_packet <= 1'b1;
          iq_write_word_index <= iq_write_word_index + 16'd1;
          iq_write_bytes <= iq_write_bytes + {{12{1'b0}}, iq_valid_bytes};
        end else begin
          iq_write_word_index <= iq_write_word_index + 16'd1;
          iq_write_bytes <= iq_write_bytes + {{12{1'b0}}, iq_valid_bytes};
        end
      end

      if (!tx_active && iq_packet_ready && !iq_clear_pending) begin
        tx_active        <= 1'b1;
        tx_is_iq         <= 1'b1;
        tx_payload_bytes <= iq_payload_bytes;
        tx_packet_bytes  <= calc_packet_bytes(iq_payload_bytes);
        tx_total_beats   <= calc_packet_beats(iq_payload_bytes);
        tx_beat_index    <= '0;
        tx_seq           <= iq_seq;
      end else if (!tx_active && source_enable) begin
        tx_active        <= 1'b1;
        tx_is_iq         <= 1'b0;
        tx_payload_bytes <= source_payload_bytes;
        tx_packet_bytes  <= calc_packet_bytes(TEST_HEADER_SIZE + source_payload_bytes);
        tx_total_beats   <= calc_packet_beats(TEST_HEADER_SIZE + source_payload_bytes);
        tx_beat_index    <= '0;
        tx_seq           <= source_seq;
      end else if (tx_active && m_axis_tready) begin
        if (tx_beat_index == tx_total_beats - 16'd1) begin
          tx_active     <= 1'b0;
          tx_is_iq      <= 1'b0;
          tx_beat_index <= '0;

          if (tx_is_iq) begin
            iq_packet_ready <= 1'b0;
            iq_seq <= iq_seq + 64'd1;
            if (iq_clear_pending) begin
              iq_packet_words     <= '0;
              iq_payload_bytes    <= '0;
              iq_write_word_index <= '0;
              iq_write_bytes      <= '0;
              iq_drop_packet      <= 1'b0;
              iq_clear_pending    <= 1'b0;
            end
          end else begin
            source_packets_sent <= source_packets_sent + 64'd1;
            source_seq          <= source_seq + 64'd1;

            if ((source_packet_limit != 64'd0)
                && ((source_packets_sent + 64'd1) >= source_packet_limit)) begin
              source_enable <= 1'b0;
            end
          end
        end else begin
          tx_beat_index <= tx_beat_index + 16'd1;
        end
      end
      end
    end
  end


//   ila_0 chdr_epid_loopback (
//   .clk(clk),
//   .probe0({
//     iq_s_axis_tdata,
//     iq_s_axis_tkeep,
//     iq_s_axis_tlast,
//     iq_s_axis_tvalid,
//     iq_s_axis_tready,
//     m_axis_tlast,
//     m_axis_tvalid,
//     m_axis_tready,

//     rx_in_packet,
//     rx_is_ctrl_packet,
//     rx_word_index,
//     source_enable,
//     source_payload_bytes,
//     tx_active,
//     tx_is_iq,
//     tx_payload_bytes,
//     tx_packet_bytes,
//     tx_total_beats,
//     tx_beat_index,
//     iq_write_word_index,
//     iq_write_bytes,
//     iq_packet_ready,
//     iq_drop_packet
//   })
// );


endmodule : chdr_epid_loopback

`default_nettype wire
