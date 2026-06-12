`timescale 1ns / 1ps
`default_nettype none

module t510_fnic_aurora_tx_loopback_256 #(
  parameter FIFO_ADDR_WIDTH = 10,
  parameter [15:0] AURORA_MAGIC_TX_DATA = 16'h5604,
  parameter [15:0] AURORA_MAGIC_RX_DATA = 16'h5603,
  parameter [15:0] AURORA_MAGIC_FLOW    = 16'h5605,
  parameter [23:0] MAX_PACKET_BYTES     = 24'hfffff0
) (
  input  wire         clk,
  input  wire         rst,
  input  wire         enable,

  input  wire [255:0] s_axis_tdata,
  input  wire         s_axis_tvalid,

  output wire [255:0] m_axis_tdata,
  output wire         m_axis_tvalid,
  input  wire         m_axis_tready,

  output wire [15:0]  fifo_occupancy,
  output wire [15:0]  fifo_space,
  output reg  [31:0]  rx_frame_count,
  output reg  [31:0]  rx_beat_count,
  output reg  [31:0]  tx_frame_count,
  output reg  [31:0]  tx_beat_count,
  output reg  [31:0]  bad_magic_count,
  output reg  [31:0]  bad_length_count,
  output reg  [31:0]  overflow_count,
  output reg  [31:0]  drop_frame_count,
  output reg  [63:0]  last_header,
  output reg  [15:0]  last_seq,
  output reg  [7:0]   last_sid,
  output reg  [23:0]  last_length
);

  localparam integer BYTES_PER_BEAT = 32;
  localparam integer PREFIX_BYTES = 16;
  localparam [1:0] S_IDLE = 2'd0;
  localparam [1:0] S_PASS = 2'd1;
  localparam [1:0] S_DROP = 2'd2;

  reg [1:0]  rx_state = S_IDLE;
  reg [31:0] rx_beats_remaining = 32'd0;
  reg [31:0] tx_beats_remaining = 32'd0;
  reg        tx_in_frame = 1'b0;

  wire [63:0] header = s_axis_tdata[63:0];
  wire [15:0] magic_type = header[63:48];
  wire [15:0] seq = header[47:32];
  wire [7:0]  sid = header[31:24];
  wire [23:0] length = header[23:0];
  wire [31:0] length_ext = {8'd0, length};
  wire [31:0] packet_beats = (length_ext + BYTES_PER_BEAT - 1) >> 5;
  wire        magic_ok = (magic_type == AURORA_MAGIC_TX_DATA);
  wire        flow_frame = (magic_type == AURORA_MAGIC_FLOW);
  wire        length_ok = (length >= PREFIX_BYTES) &&
                          (length <= MAX_PACKET_BYTES) &&
                          (packet_beats != 32'd0) &&
                          (length[4:0] == 5'd0);
  wire        frame_space_ok =
    fifo_space > (packet_beats[15:0] + 16'd8);

  wire [255:0] converted_first_beat = {s_axis_tdata[255:64],
                                       AURORA_MAGIC_RX_DATA,
                                       header[47:0]};
  wire [255:0] fifo_in_tdata =
    (rx_state == S_IDLE) ? converted_first_beat : s_axis_tdata;
  wire fifo_in_tvalid = enable && s_axis_tvalid &&
                        ((rx_state == S_PASS) ||
                         (rx_state == S_IDLE && magic_ok && length_ok &&
                          frame_space_ok));
  wire fifo_in_tready;
  wire fifo_out_fire = enable && m_axis_tvalid && m_axis_tready;
  wire fifo_in_fire = fifo_in_tvalid && fifo_in_tready;
  wire input_fire = enable && s_axis_tvalid;

  t510_fnic_axis_fifo_256 #(
    .ADDR_WIDTH(FIFO_ADDR_WIDTH),
    .DATA_WIDTH(256)
  ) u_loop_fifo (
    .clk           (clk),
    .rst           (rst),
    .s_axis_tdata  (fifo_in_tdata),
    .s_axis_tvalid (fifo_in_tvalid),
    .s_axis_tready (fifo_in_tready),
    .m_axis_tdata  (m_axis_tdata),
    .m_axis_tvalid (m_axis_tvalid),
    .m_axis_tready (m_axis_tready),
    .occupancy     (fifo_occupancy),
    .space         (fifo_space)
  );

  always @(posedge clk) begin
    if (rst || !enable) begin
      rx_state <= S_IDLE;
      rx_beats_remaining <= 32'd0;
      rx_frame_count <= 32'd0;
      rx_beat_count <= 32'd0;
      bad_magic_count <= 32'd0;
      bad_length_count <= 32'd0;
      overflow_count <= 32'd0;
      drop_frame_count <= 32'd0;
      last_header <= 64'd0;
      last_seq <= 16'd0;
      last_sid <= 8'd0;
      last_length <= 24'd0;
    end else if (input_fire) begin
      if (!flow_frame)
        rx_beat_count <= rx_beat_count + 1'b1;

      case (rx_state)
      S_IDLE: begin
        if (flow_frame) begin
          rx_state <= S_IDLE;
          rx_beats_remaining <= 32'd0;
        end else begin
          last_header <= header;
          last_seq <= seq;
          last_sid <= sid;
          last_length <= length;

          if (!magic_ok)
            bad_magic_count <= bad_magic_count + 1'b1;
          if (!length_ok)
            bad_length_count <= bad_length_count + 1'b1;

          if (magic_ok && length_ok && frame_space_ok && fifo_in_tready) begin
            rx_frame_count <= rx_frame_count + 1'b1;
            if (packet_beats > 32'd1) begin
              rx_state <= S_PASS;
              rx_beats_remaining <= packet_beats - 1'b1;
            end else begin
              rx_state <= S_IDLE;
              rx_beats_remaining <= 32'd0;
            end
          end else begin
            drop_frame_count <= drop_frame_count + 1'b1;
            if (magic_ok && length_ok && (!frame_space_ok || !fifo_in_tready))
              overflow_count <= overflow_count + 1'b1;
            if (length_ok && packet_beats > 32'd1) begin
              rx_state <= S_DROP;
              rx_beats_remaining <= packet_beats - 1'b1;
            end else begin
              rx_state <= S_IDLE;
              rx_beats_remaining <= 32'd0;
            end
          end
        end
      end

      S_PASS: begin
        if (fifo_in_fire) begin
          if (rx_beats_remaining <= 32'd1) begin
            rx_state <= S_IDLE;
            rx_beats_remaining <= 32'd0;
          end else begin
            rx_beats_remaining <= rx_beats_remaining - 1'b1;
          end
        end else begin
          overflow_count <= overflow_count + 1'b1;
          drop_frame_count <= drop_frame_count + 1'b1;
          if (rx_beats_remaining <= 32'd1) begin
            rx_state <= S_IDLE;
            rx_beats_remaining <= 32'd0;
          end else begin
            rx_state <= S_DROP;
            rx_beats_remaining <= rx_beats_remaining - 1'b1;
          end
        end
      end

      S_DROP: begin
        if (rx_beats_remaining <= 32'd1) begin
          rx_state <= S_IDLE;
          rx_beats_remaining <= 32'd0;
        end else begin
          rx_beats_remaining <= rx_beats_remaining - 1'b1;
        end
      end

      default: begin
        rx_state <= S_IDLE;
        rx_beats_remaining <= 32'd0;
      end
      endcase
    end
  end

  always @(posedge clk) begin
    if (rst || !enable) begin
      tx_frame_count <= 32'd0;
      tx_beat_count <= 32'd0;
      tx_beats_remaining <= 32'd0;
      tx_in_frame <= 1'b0;
    end else if (fifo_out_fire) begin
      tx_beat_count <= tx_beat_count + 1'b1;
      if (!tx_in_frame) begin
        tx_frame_count <= tx_frame_count + 1'b1;
        tx_beats_remaining <=
          ({8'd0, m_axis_tdata[23:0]} + BYTES_PER_BEAT - 1) >> 5;
        tx_in_frame <=
          ((({8'd0, m_axis_tdata[23:0]} + BYTES_PER_BEAT - 1) >> 5) >
           32'd1);
      end else if (tx_beats_remaining <= 32'd2) begin
        tx_beats_remaining <= 32'd0;
        tx_in_frame <= 1'b0;
      end else begin
        tx_beats_remaining <= tx_beats_remaining - 1'b1;
      end
    end
  end

endmodule

`default_nettype wire
