`timescale 1ns/1ps
`default_nettype none

module tb_t510_ai_100gbe_ctrl_chdr_mix;
  localparam int ENET_W         = 512;
  localparam int CPU_W          = 512;
  localparam int CHDR_W         = 512;
  localparam int NET_CHDR_W     = 512;
  localparam int ENET_USER_W    = $clog2(ENET_W/8)+1;
  localparam int CPU_USER_W     = $clog2(CPU_W/8)+1;
  localparam int CHDR_USER_W    = $clog2(CHDR_W/8);
  localparam int CPU_FIFO_SIZE  = 10;
  localparam int CHDR_FIFO_SIZE = 12;
  localparam int NODE_INST      = 0;
  localparam int RT_TBL_SIZE    = 6;
  localparam realtime BUS_HALF_PERIOD_NS = 12.5ns;
  localparam realtime ETH_HALF_PERIOD_NS = BUS_HALF_PERIOD_NS;
  localparam logic [47:0] MY_MAC         = 48'h02_00_00_00_00_11;
  localparam logic [31:0] MY_IP          = 32'hC0A8_0A02; // 192.168.10.2
  localparam logic [15:0] MY_CHDR_UDP    = 16'd49153;
  localparam logic [15:0] CTRL_UDP_PORT  = 16'd49208;
  localparam logic [15:0] CTRL_SRC_PORT  = 16'd49208;
  localparam logic [7:0]  CTRL_SID       = 8'h70;
  localparam logic [2:0]  CHDR_PKT_TYPE_DATA = 3'd6;

  typedef byte unsigned byte_t;
  typedef enum logic [1:0] {
    PKT_NONE = 2'd0,
    PKT_CTRL = 2'd1,
    PKT_CHDR = 2'd2
  } pkt_kind_t;

  logic bus_clk = 1'b0;
  logic eth_clk = 1'b0;
  logic reset = 1'b1;

  logic [15:0]           device_id = 16'h5100;
  logic                  eth_pause_req;
  logic                  kv_stb = 1'b0;
  logic                  kv_busy;
  logic [47:0]           kv_mac_addr = '0;
  logic [31:0]           kv_ip_addr = '0;
  logic [15:0]           kv_udp_port = '0;
  logic [15:0]           kv_dst_epid = '0;
  logic                  kv_raw_udp = 1'b0;

  AxiStreamIf #(
    .DATA_WIDTH(ENET_W),
    .USER_WIDTH(ENET_USER_W),
    .MAX_PACKET_BYTES(65536)
  ) eth_tx (
    .clk(eth_clk),
    .rst(reset)
  );

  AxiStreamIf #(
    .DATA_WIDTH(ENET_W),
    .USER_WIDTH(ENET_USER_W),
    .MAX_PACKET_BYTES(65536)
  ) eth_rx (
    .clk(eth_clk),
    .rst(reset)
  );

  AxiStreamIf #(
    .DATA_WIDTH(CHDR_W),
    .USER_WIDTH(CHDR_USER_W),
    .TKEEP(0),
    .TUSER(0)
  ) v2e (
    .clk(bus_clk),
    .rst(reset)
  );

  AxiStreamIf #(
    .DATA_WIDTH(CHDR_W),
    .USER_WIDTH(CHDR_USER_W),
    .TKEEP(0),
    .TUSER(0)
  ) e2v (
    .clk(bus_clk),
    .rst(reset)
  );

  AxiStreamIf #(
    .DATA_WIDTH(CPU_W),
    .USER_WIDTH(CPU_USER_W),
    .TKEEP(0)
  ) c2e (
    .clk(bus_clk),
    .rst(reset)
  );

  AxiStreamIf #(
    .DATA_WIDTH(CPU_W),
    .USER_WIDTH(CPU_USER_W),
    .TKEEP(0)
  ) e2c (
    .clk(bus_clk),
    .rst(reset)
  );

  eth_ipv4_chdr_adapter #(
    .PROTOVER({8'd1, 8'd0}),
    .CPU_FIFO_SIZE(CPU_FIFO_SIZE),
    .CHDR_FIFO_SIZE(CHDR_FIFO_SIZE),
    .RT_TBL_SIZE(RT_TBL_SIZE),
    .NODE_INST(NODE_INST),
    .PREAMBLE_BYTES(0),
    .SYNC(1),
    .ENET_W(ENET_W),
    .CPU_W(CPU_W),
    .CHDR_W(CHDR_W),
    .NET_CHDR_W(NET_CHDR_W),
    .EN_RX_RAW_PYLD(1)
  ) dut (
    .device_id(device_id),
    .my_mac(MY_MAC),
    .my_ip(MY_IP),
    .my_udp_chdr_port(MY_CHDR_UDP),
    .my_pause_set(16'd40),
    .my_pause_clear(16'd20),
    .kv_stb(kv_stb),
    .kv_busy(kv_busy),
    .kv_mac_addr(kv_mac_addr),
    .kv_ip_addr(kv_ip_addr),
    .kv_udp_port(kv_udp_port),
    .kv_dst_epid(kv_dst_epid),
    .kv_raw_udp(kv_raw_udp),
    .chdr_dropped(),
    .cpu_dropped(),
    .eth_pause_req(eth_pause_req),
    .eth_tx(eth_tx),
    .eth_rx(eth_rx),
    .e2v(e2v),
    .v2e(v2e),
    .e2c(e2c),
    .c2e(c2e)
  );

  always #(BUS_HALF_PERIOD_NS) bus_clk = ~bus_clk;
  always #(ETH_HALF_PERIOD_NS) eth_clk = ~eth_clk;

  task automatic put_cpu_byte(
    inout logic [CPU_W-1:0] word,
    input int idx,
    input byte_t value
  );
    word[idx*8 +: 8] = value;
  endtask

  task automatic put_chdr_byte(
    inout logic [CHDR_W-1:0] word,
    input int idx,
    input byte_t value
  );
    word[idx*8 +: 8] = value;
  endtask

  function automatic logic [15:0] be16_word_at(
    input logic [ENET_W-1:0] word,
    input int idx
  );
    be16_word_at = {word[idx*8 +: 8], word[(idx+1)*8 +: 8]};
  endfunction

  function automatic byte_t le64_byte_at(
    input logic [63:0] value,
    input int idx
  );
    le64_byte_at = value[idx*8 +: 8];
  endfunction

  function automatic logic [63:0] tb_chdr_build_header(
    input logic [5:0]  vc,
    input logic        eob,
    input logic        eov,
    input logic [2:0]  pkt_type,
    input logic [4:0]  num_mdata,
    input logic [15:0] seq_num,
    input logic [15:0] length,
    input logic [15:0] dst_epid
  );
    tb_chdr_build_header = {vc, eob, eov, pkt_type, num_mdata, seq_num, length, dst_epid};
  endfunction

  function automatic logic [63:0] tb_chdr_update_length(
    input int chdr_w,
    input logic [63:0] header,
    input logic [15:0] payload_length
  );
    logic [15:0] header_length;
    begin
      header_length = chdr_w / 8;
      tb_chdr_update_length = {header[63:32], payload_length + header_length, header[15:0]};
    end
  endfunction

  function automatic logic [2:0] tb_chdr_get_pkt_type(input logic [63:0] header);
    tb_chdr_get_pkt_type = header[55:53];
  endfunction

  function automatic logic [15:0] tb_chdr_get_dst_epid(input logic [63:0] header);
    tb_chdr_get_dst_epid = header[15:0];
  endfunction

  task automatic send_c2e_ctrl_packet(input logic [15:0] seq);
    logic [CPU_W-1:0] beat_data;

    beat_data = '0;

    // Ethernet header
    put_cpu_byte(beat_data, 12, 8'h08);
    put_cpu_byte(beat_data, 13, 8'h00);
    // IPv4 header
    put_cpu_byte(beat_data, 14, 8'h45);
    put_cpu_byte(beat_data, 16, 8'h00);
    put_cpu_byte(beat_data, 17, 8'h32);
    put_cpu_byte(beat_data, 22, 8'h40);
    put_cpu_byte(beat_data, 23, 8'h11);
    // UDP header
    put_cpu_byte(beat_data, 34, CTRL_SRC_PORT[15:8]);
    put_cpu_byte(beat_data, 35, CTRL_SRC_PORT[7:0]);
    put_cpu_byte(beat_data, 36, CTRL_UDP_PORT[15:8]);
    put_cpu_byte(beat_data, 37, CTRL_UDP_PORT[7:0]);
    put_cpu_byte(beat_data, 38, 8'h00);
    put_cpu_byte(beat_data, 39, 8'h1e);
    // Control response payload begins at byte 42
    put_cpu_byte(beat_data, 42, CTRL_SID);
    put_cpu_byte(beat_data, 46, 8'h02);
    put_cpu_byte(beat_data, 47, 8'h55);
    put_cpu_byte(beat_data, 48, seq[7:0]);
    put_cpu_byte(beat_data, 49, seq[15:8]);
    c2e.tdata  <= beat_data;
    c2e.tuser  <= '0;
    c2e.tlast  <= 1'b1;
    c2e.tvalid <= 1'b1;
    do @(posedge bus_clk); while (!c2e.tready);

    c2e.tvalid <= 1'b0;
    c2e.tlast  <= 1'b0;
    c2e.tdata  <= '0;
    c2e.tuser  <= '0;
    @(posedge bus_clk);
  endtask

  task automatic send_v2e_chdr_packet(
    input logic [15:0] seq,
    input int payload_bytes
  );
    int idx;
    int total_bytes;
    int beat_bytes;
    logic [63:0] header;
    logic [CHDR_W-1:0] beat_data;
    logic [CHDR_USER_W-1:0] beat_user;
    logic beat_last;

    header = tb_chdr_build_header(
      6'd0,
      1'b1,
      1'b1,
      CHDR_PKT_TYPE_DATA,
      5'd0,
      seq,
      16'd0,
      16'd0
    );
    header = tb_chdr_update_length(CHDR_W, header, payload_bytes[15:0]);

    total_bytes = 8 + payload_bytes;
    idx = 0;
    while (idx < total_bytes) begin
      beat_data  = '0;
      beat_user  = '0;
      beat_bytes = ((total_bytes - idx) > (CHDR_W/8)) ? (CHDR_W/8) : (total_bytes - idx);
      beat_last  = (idx + beat_bytes) == total_bytes;

      for (int b = 0; b < beat_bytes; b++) begin
        if ((idx + b) < 8) begin
          put_chdr_byte(beat_data, b, le64_byte_at(header, idx + b));
        end else begin
          put_chdr_byte(beat_data, b, byte_t'((idx + b) & 8'hff));
        end
      end
      if (beat_last && beat_bytes != (CHDR_W/8)) begin
        beat_user = CHDR_USER_W'(beat_bytes);
      end

      v2e.tdata  <= beat_data;
      v2e.tuser  <= beat_user;
      v2e.tlast  <= beat_last;
      v2e.tvalid <= 1'b1;
      do @(posedge bus_clk); while (!v2e.tready);
      idx += beat_bytes;
    end

    v2e.tvalid <= 1'b0;
    v2e.tlast  <= 1'b0;
    v2e.tdata  <= '0;
    v2e.tuser  <= '0;
    @(posedge bus_clk);
  endtask

  task automatic run_mixed_test(
    input string name,
    input int ctrl_count,
    input int chdr_count,
    input int chdr_bytes,
    input bit throttle_ready
  );
    int ctrl_seen = 0;
    int chdr_seen = 0;
    int total_seen = 0;
    bit done = 0;

    $display("[tb] start %s ctrl_count=%0d chdr_count=%0d chdr_bytes=%0d throttle_ready=%0d",
      name, ctrl_count, chdr_count, chdr_bytes, throttle_ready);

    fork
      begin : ready_thread
        eth_tx.tready <= 1'b1;
        while (!done) begin
          @(posedge eth_clk);
          if (reset) begin
            eth_tx.tready <= 1'b0;
          end else if (throttle_ready) begin
            eth_tx.tready <= (($urandom_range(0, 7) != 0) && ($urandom_range(0, 7) != 1));
          end else begin
            eth_tx.tready <= 1'b1;
          end
        end
        eth_tx.tready <= 1'b1;
      end
      begin : cpu_tx_thread
        for (int i = 0; i < ctrl_count; i++) begin
          send_c2e_ctrl_packet(i[15:0]);
          repeat ($urandom_range(1, 4)) @(posedge bus_clk);
        end
      end
      begin : chdr_tx_thread
        for (int i = 0; i < chdr_count; i++) begin
          send_v2e_chdr_packet(i[15:0], chdr_bytes);
          repeat (8) @(posedge bus_clk);
        end
      end
      begin : rx_thread
        pkt_kind_t cur_kind = PKT_NONE;
        logic in_packet = 1'b0;
        forever begin
          int beat_valid_bytes;
          @(posedge eth_clk);
          if (reset) begin
            cur_kind = PKT_NONE;
            in_packet = 1'b0;
          end else if (eth_tx.tvalid && eth_tx.tready) begin
            beat_valid_bytes = (eth_tx.tlast && (eth_tx.tuser[ENET_USER_W-2:0] != 0))
              ? int'(eth_tx.tuser[ENET_USER_W-2:0])
              : (ENET_W/8);
            if (!in_packet) begin
              logic [15:0] dst_port;
              logic [63:0] chdr_hdr;
              in_packet = 1'b1;
              if (beat_valid_bytes >= 38) begin
                dst_port = be16_word_at(eth_tx.tdata, 36);
              end else begin
                dst_port = 16'hffff;
              end
              if (dst_port == CTRL_UDP_PORT) begin
                cur_kind = PKT_CTRL;
              end else begin
                chdr_hdr = eth_tx.tdata[63:0];
                if ((tb_chdr_get_pkt_type(chdr_hdr) == CHDR_PKT_TYPE_DATA)
                    && (tb_chdr_get_dst_epid(chdr_hdr) == 16'd0)) begin
                  cur_kind = PKT_CHDR;
                end else begin
                  $fatal(1, "[tb] %s: unexpected first beat dst_port=%0d hdr=%016h bytes=%0d total_seen=%0d",
                    name, dst_port, chdr_hdr, beat_valid_bytes, total_seen);
                end
              end
            end
            if (eth_tx.tlast) begin
              total_seen++;
              if (cur_kind == PKT_CTRL) begin
                ctrl_seen++;
              end else if (cur_kind == PKT_CHDR) begin
                chdr_seen++;
              end else begin
                $fatal(1, "[tb] %s: packet ended without classification", name);
              end
              cur_kind = PKT_NONE;
              in_packet = 1'b0;
              if ((ctrl_seen == ctrl_count) && (chdr_seen == chdr_count)) begin
                done = 1'b1;
                disable ready_thread;
                disable cpu_tx_thread;
                disable chdr_tx_thread;
                disable rx_thread;
              end
            end
          end
        end
      end
      begin : timeout_thread
        repeat (400000) @(posedge eth_clk);
        $fatal(1,
          "[tb] %s timeout ctrl_seen=%0d/%0d chdr_seen=%0d/%0d total_seen=%0d",
          name, ctrl_seen, ctrl_count, chdr_seen, chdr_count, total_seen);
      end
    join_none
    wait (done);
    disable fork;

    if ((ctrl_seen != ctrl_count) || (chdr_seen != chdr_count)) begin
      $fatal(1,
        "[tb] %s mismatch ctrl_seen=%0d/%0d chdr_seen=%0d/%0d total_seen=%0d",
        name, ctrl_seen, ctrl_count, chdr_seen, chdr_count, total_seen);
    end

    $display("[tb] PASS %s ctrl_seen=%0d chdr_seen=%0d total_seen=%0d",
      name, ctrl_seen, chdr_seen, total_seen);
  endtask

  initial begin
    eth_rx.tdata  = '0;
    eth_rx.tuser  = '0;
    eth_rx.tlast  = 1'b0;
    eth_rx.tvalid = 1'b0;
    c2e.tdata     = '0;
    c2e.tuser     = '0;
    c2e.tlast     = 1'b0;
    c2e.tvalid    = 1'b0;
    v2e.tdata     = '0;
    v2e.tuser     = '0;
    v2e.tlast     = 1'b0;
    v2e.tvalid    = 1'b0;
    e2c.tready    = 1'b1;
    e2v.tready    = 1'b1;
    eth_tx.tready = 1'b0;

    repeat (20) @(posedge bus_clk);
    reset = 1'b0;
    repeat (12) @(posedge bus_clk);

    run_mixed_test("ctrl_only_no_backpressure", 8, 0, 8160, 1'b0);
    run_mixed_test("chdr_only_no_backpressure", 0, 8, 8160, 1'b0);
    run_mixed_test("mixed_no_backpressure", 32, 64, 8160, 1'b0);
    run_mixed_test("mixed_throttled_egress", 64, 160, 8160, 1'b1);

    $display("TB_PASS tb_t510_ai_100gbe_ctrl_chdr_mix");
    #100ns;
    $finish;
  end

endmodule

module ila_0 (
  input wire clk,
  input wire [1023:0] probe0
);
endmodule

`default_nettype wire
