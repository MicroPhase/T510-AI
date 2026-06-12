//
// Copyright 2026
//
// SPDX-License-Identifier: LGPL-3.0-or-later
//
// Module: chdr_iq_bridge_v2
//
// Description:
//
//   Lightweight IQ-only replacement candidate for the IQ path inside
//   chdr_epid_loopback. This module accepts the existing 64-bit IQ packet
//   format emitted by t510_ai_iq_capture and repackages it into CHDR DATA
//   packets without using per-packet RAM storage.
//
//   Tradeoff:
//   - Simpler stop/drain behavior and much less baggage
//   - Throughput is intentionally conservative; this is a stability-first
//     candidate, not a drop-in performance-tuned datapath
//
`timescale 1ns / 1ps
`default_nettype none

module chdr_iq_bridge_v2 #(
  parameter int          CHDR_W               = 512,
  parameter logic [15:0] IQ_CAPTURE_DST_EPID  = 16'h4002
) (
  input  wire               clk,
  input  wire               rst,

  input  wire [63:0]        iq_s_axis_tdata,
  input  wire [7:0]         iq_s_axis_tkeep,
  input  wire               iq_s_axis_tlast,
  input  wire               iq_s_axis_tvalid,
  output logic              iq_s_axis_tready,

  input  wire               stop_req,
  output reg                stop_done,
  output wire               idle,

  output logic [CHDR_W-1:0] m_axis_tdata,
  output logic              m_axis_tlast,
  output logic              m_axis_tvalid,
  input  wire               m_axis_tready
);

  localparam int unsigned WORD_BYTES         = CHDR_W / 8;
  localparam int unsigned WORDS_PER_BEAT     = CHDR_W / 64;
  /* verilator lint_off WIDTH */
  localparam logic [15:0] WORD_BYTES_16      = CHDR_W / 8;
  /* verilator lint_on WIDTH */
  localparam logic [31:0] IQ_MAGIC           = 32'h5435_3151;
  localparam logic [7:0]  IQ_VERSION         = 8'd1;
  localparam logic [2:0]  CHDR_PKT_TYPE_DATA = 3'd6;
  localparam logic [$clog2(WORDS_PER_BEAT+1)-1:0] WORDS_PER_BEAT_CNT =
    WORDS_PER_BEAT[$clog2(WORDS_PER_BEAT+1)-1:0];

  localparam logic [2:0] ST_IDLE        = 3'd0;
  localparam logic [2:0] ST_HEAD1       = 3'd1;
  localparam logic [2:0] ST_SEND_HEADER = 3'd2;
  localparam logic [2:0] ST_FILL        = 3'd3;
  localparam logic [2:0] ST_SEND_PAYLD  = 3'd4;
  localparam logic [2:0] ST_DROP        = 3'd5;

  logic [2:0]  state;

  logic [63:0] iq_header0;
  logic [15:0] sample_payload_bytes;
  logic [15:0] sample_words_left;
  logic [15:0] seq_num;

  logic [CHDR_W-1:0] payload_buf;
  logic [$clog2(WORDS_PER_BEAT+1)-1:0] payload_buf_words;
  logic        payload_buf_last;

  function automatic [63:0] chdr_build_header(
    input logic [5:0]  vc,
    input logic        eob,
    input logic        eov,
    input logic [2:0]  pkt_type,
    input logic [4:0]  num_mdata,
    input logic [15:0] seq_local,
    input logic [15:0] length,
    input logic [15:0] dst_epid
  );
    chdr_build_header = {vc, eob, eov, pkt_type, num_mdata, seq_local, length, dst_epid};
  endfunction

  assign idle = (state == ST_IDLE) && !m_axis_tvalid;

  always @(*) begin
    iq_s_axis_tready = 1'b0;
    case (state)
      ST_IDLE: begin
        iq_s_axis_tready = !rst && !stop_req && !m_axis_tvalid;
      end
      ST_HEAD1: begin
        iq_s_axis_tready = !rst && !m_axis_tvalid;
      end
      ST_FILL: begin
        iq_s_axis_tready = !rst && !m_axis_tvalid && (payload_buf_words < WORDS_PER_BEAT_CNT);
      end
      ST_DROP: begin
        iq_s_axis_tready = !rst && !m_axis_tvalid;
      end
      default: begin
        iq_s_axis_tready = 1'b0;
      end
    endcase
  end

  always @(posedge clk) begin
    stop_done <= 1'b0;

    if (rst) begin
      state               <= ST_IDLE;
      iq_header0          <= 64'd0;
      sample_payload_bytes <= 16'd0;
      sample_words_left   <= 16'd0;
      seq_num             <= 16'd0;
      payload_buf         <= '0;
      payload_buf_words   <= '0;
      payload_buf_last    <= 1'b0;
      m_axis_tdata        <= '0;
      m_axis_tlast        <= 1'b0;
      m_axis_tvalid       <= 1'b0;
    end else begin
      if (stop_req && idle) begin
        stop_done <= 1'b1;
      end

      if (m_axis_tvalid && m_axis_tready) begin
        m_axis_tvalid <= 1'b0;
        m_axis_tlast  <= 1'b0;

        case (state)
          ST_SEND_HEADER: begin
            if (payload_buf_last) begin
              m_axis_tdata    <= payload_buf;
              m_axis_tlast    <= 1'b1;
              m_axis_tvalid   <= 1'b1;
              payload_buf     <= '0;
              payload_buf_words <= '0;
              state           <= ST_SEND_PAYLD;
            end else begin
              state <= ST_FILL;
            end
          end

          ST_SEND_PAYLD: begin
            if (payload_buf_last) begin
              seq_num          <= seq_num + 16'd1;
              payload_buf_last <= 1'b0;
              payload_buf      <= '0;
              state            <= ST_IDLE;
            end else begin
              state <= ST_FILL;
            end
          end

          default: begin
          end
        endcase
      end

      if (iq_s_axis_tvalid && iq_s_axis_tready) begin
        case (state)
          ST_IDLE: begin
            iq_header0          <= iq_s_axis_tdata;
            sample_payload_bytes <= iq_s_axis_tdata[15:0];
            sample_words_left   <= iq_s_axis_tdata[15:0] >> 3;
            payload_buf         <= '0;
            payload_buf_words   <= '0;
            payload_buf_last    <= 1'b0;
            state               <= ((iq_s_axis_tdata[63:32] == IQ_MAGIC)
                                 && (iq_s_axis_tdata[31:24] == IQ_VERSION)) ? ST_HEAD1 : ST_DROP;
          end

          ST_HEAD1: begin
            payload_buf              <= '0;
            payload_buf[63:0]        <= iq_header0;
            payload_buf[127:64]      <= iq_s_axis_tdata;
            payload_buf_words        <= 2;
            payload_buf_last         <= (sample_words_left == 16'd0);
            m_axis_tdata             <= '0;
            m_axis_tdata[63:0] <= chdr_build_header(
              6'd0,
              1'b0,
              1'b0,
              CHDR_PKT_TYPE_DATA,
              5'd0,
              seq_num,
              WORD_BYTES_16 + 16'd16 + sample_payload_bytes,
              IQ_CAPTURE_DST_EPID
            );
            m_axis_tlast  <= 1'b0;
            m_axis_tvalid <= 1'b1;
            state         <= ST_SEND_HEADER;
          end

          ST_FILL: begin
            payload_buf[payload_buf_words*64 +: 64] <= iq_s_axis_tdata;

            if (iq_s_axis_tlast || (payload_buf_words == (WORDS_PER_BEAT_CNT - 1'b1))) begin
              m_axis_tdata                              <= payload_buf;
              m_axis_tdata[payload_buf_words*64 +: 64] <= iq_s_axis_tdata;
              m_axis_tlast                              <= iq_s_axis_tlast;
              m_axis_tvalid                             <= 1'b1;
              payload_buf_words                         <= '0;
              payload_buf_last                          <= iq_s_axis_tlast;
              if (sample_words_left != 16'd0)
                sample_words_left <= sample_words_left - 16'd1;
              state <= ST_SEND_PAYLD;
            end else begin
              payload_buf_words <= payload_buf_words + 1'b1;
              if (sample_words_left != 16'd0)
                sample_words_left <= sample_words_left - 16'd1;
            end
          end

          ST_DROP: begin
            if (iq_s_axis_tlast) begin
              state <= ST_IDLE;
            end
          end

          default: begin
          end
        endcase
      end
    end
  end

  wire _unused = &{1'b0, iq_s_axis_tkeep};

endmodule

`default_nettype wire
