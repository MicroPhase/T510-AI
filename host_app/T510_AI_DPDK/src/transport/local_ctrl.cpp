//
// Created by jcc on 25-4-8.
//
#include <chrono>
#include <cstdio>
#include <cstring>
#include "local_ctrl.hpp"


local_ctrl::local_ctrl(zero_copy_if::sptr& xport, uint32_t sid)
        :_xport(xport)
        ,_sid(sid)
        ,_tx_seq(0)
        ,_rx_seq(0)
        ,_rx_buf_len(8)
        ,_tx_buf_len(8)
        ,_send_buf(new uint32_t[8])
        ,_recv_buf(new uint32_t[8]){
    set_tick_rate(1.0);
    time_spec_t time = time_spec_t(0.0);
    set_time(time);

}


local_ctrl::local_ctrl(zero_copy_if::sptr& xport, uint32_t sid, uint32_t buf_len)
        :_xport(xport)
        ,_sid(sid)
        ,_rx_seq(0)
        ,_tx_seq(0)
        ,_rx_buf_len(buf_len)
        ,_tx_buf_len(buf_len)
        ,_send_buf(new uint32_t[buf_len])
        ,_recv_buf(new uint32_t[buf_len]){
    set_tick_rate(1.0);
    time_spec_t time = time_spec_t(0.0);
    set_time(time);
    set_rx_buf_size(_rx_buf_len);
    tx_buf_resize(_tx_buf_len);
}

local_ctrl::~local_ctrl() {
    if (_send_buf) {
        delete [] _send_buf;
        _send_buf=nullptr;
    }

    if(_recv_buf){
        delete [] _recv_buf;
        _recv_buf=nullptr;
    }
}

void local_ctrl::poke32(uint32_t addr, uint32_t data) {
    std::lock_guard<std::mutex> lock(_transaction_mutex);
    send_pkt(SDR_CTRL_CMD_WRITE_REG, 0x02, 0x00, addr, data, 0);
    wait_for_ack(false);
}

uint32_t local_ctrl::peek32(uint32_t addr) {
    std::lock_guard<std::mutex> lock(_transaction_mutex);
    send_pkt(SDR_CTRL_CMD_READ_REG, 0x01, 0x00, addr, 0, 0);
    return wait_for_ack(true);
}

uint64_t local_ctrl::peek64(uint32_t addr) {
    std::lock_guard<std::mutex> lock(_transaction_mutex);
    send_pkt(SDR_CTRL_CMD_READ_REG, 0x01, 0x00, addr, 0, 0);
    return wait_for_ack(true);
}

void local_ctrl::serialize_hdr(uint32_t * buf, sdr_header_t &  hdr){
    buf[0] = (((uint32_t)hdr.sid) << 24) | (hdr.packet_len);
    buf[1] = (((uint32_t)hdr.magic_type) << 16) | (hdr.seq);
    buf[2] = hdr.timestamp & 0xFFFFFFFF;
    buf[3] = (hdr.timestamp >> 32) & 0xFFFFFFFF;
}

void local_ctrl::deserialize_hdr(uint32_t * buf, sdr_header_t &  hdr){
    
    hdr.sid = (buf[0] >> 24);
    hdr.packet_len = buf[0] & 0xFFFFFF;
    hdr.magic_type = buf[1] >> 16;
    hdr.seq = buf[1] & 0xFFFF;
    hdr.timestamp = (((uint64_t)buf[3]) << 32) | buf[2];
}


void local_ctrl::send_pkt(uint16_t cmd_id, uint8_t flags, uint8_t target, uint32_t arg0, uint32_t arg1, uint32_t arg2) {
    sdr_header_t packet_info;
    packet_info.magic_type = PACKET_TYPE_CTRL;
    packet_info.seq = _tx_seq;
    packet_info.sid = _sid;
    packet_info.packet_len = SDR_CTRL_PACKET_BYTES;
    packet_info.timestamp = 0x00;

    serialize_hdr(_send_buf, packet_info);

    _send_buf[4] = (static_cast<uint32_t>(target) << 24)
                 | (static_cast<uint32_t>(flags) << 16)
                 | static_cast<uint32_t>(cmd_id);
    _send_buf[5] = arg0;
    _send_buf[6] = arg1;
    _send_buf[7] = arg2;

    managed_send_buffer::sptr send_buffer = _xport->get_send_buff();
    if(send_buffer){
        // std::cout << "Buffer address: " << send_buffer->cast<void*>() << std::endl;
        std::memcpy(send_buffer->cast<void*>(),_send_buf,packet_info.packet_len);
        send_buffer->commit(packet_info.packet_len);
    }
    _tx_seq++;
}

uint64_t local_ctrl::wait_for_ack(bool read_back) {
    sdr_header_t packet_info;
    const uint16_t expected_seq = static_cast<uint16_t>(_tx_seq - 1u);
    const auto deadline = std::chrono::steady_clock::now() + std::chrono::seconds(1);
    std::size_t ignored_packets = 0;
    bool saw_any_packet = false;
    uint16_t last_magic = 0;
    uint16_t last_seq = 0;
    uint8_t last_sid = 0;

    while (std::chrono::steady_clock::now() < deadline) {
        const auto now = std::chrono::steady_clock::now();
        const double timeout = std::chrono::duration_cast<std::chrono::duration<double>>(deadline - now).count();
        managed_recv_buffer::sptr recv_buffer = _xport->get_recv_buff(timeout);
        if (!recv_buffer || recv_buffer->size() == 0) {
            continue;
        }

        const std::size_t copy_bytes =
            std::min<std::size_t>(recv_buffer->size(), static_cast<std::size_t>(_rx_buf_len) * sizeof(uint32_t));
        std::memset(_recv_buf, 0, static_cast<std::size_t>(_rx_buf_len) * sizeof(uint32_t));
        std::memcpy(_recv_buf, recv_buffer->cast<void*>(), copy_bytes);
        deserialize_hdr(_recv_buf, packet_info);
        saw_any_packet = true;
        last_magic = packet_info.magic_type;
        last_seq = packet_info.seq;
        last_sid = packet_info.sid;

        if (packet_info.magic_type != PACKET_TYPE_RESP) {
            ignored_packets++;
            continue;
        }
        if (packet_info.sid != _sid) {
            ignored_packets++;
            continue;
        }
        if (packet_info.seq != expected_seq) {
            ignored_packets++;
            continue;
        }
        if (packet_info.packet_len != SDR_CTRL_PACKET_BYTES || recv_buffer->size() < SDR_CTRL_PACKET_BYTES) {
            ignored_packets++;
            continue;
        }
        const uint16_t resp_cmd = static_cast<uint16_t>(_recv_buf[4] & 0xffffu);
        const uint16_t resp_status = static_cast<uint16_t>((_recv_buf[4] >> 16) & 0xffffu);
        (void)resp_cmd;
        if (resp_status != SDR_CTRL_STATUS_OK) {
            std::fprintf(stderr,
                "[local_ctrl] command failed: seq=%u sid=0x%02x status=0x%04x cmd=0x%04x\n",
                packet_info.seq,
                packet_info.sid,
                resp_status,
                resp_cmd);
            return 0;
        }

        _timestamp = packet_info.timestamp;
        _rx_seq = packet_info.seq;
        if (read_back) {
            uint64_t lo = _recv_buf[5];
            uint64_t hi = _recv_buf[6];
            return ((hi << 32) | lo);
        }
        return 0;
    }
    {
        const char* timeout_kind = read_back ? "read timeout" : "ack timeout";
        if (saw_any_packet) {
            std::fprintf(stderr,
                "[local_ctrl] %s: expected seq=%u sid=0x%02x type=0x%04x, ignored=%zu, last_seen={type=0x%04x sid=0x%02x seq=%u}\n",
                timeout_kind,
                expected_seq,
                _sid,
                PACKET_TYPE_RESP,
                ignored_packets,
                last_magic,
                last_sid,
                last_seq);
        } else {
            std::fprintf(stderr,
                "[local_ctrl] %s: expected seq=%u sid=0x%02x type=0x%04x, no packet received\n",
                timeout_kind,
                expected_seq,
                _sid,
                PACKET_TYPE_RESP);
        }
    }
    return 0;
}

void local_ctrl::set_time(time_spec_t &time) {
    _time = time;
    auto time_zero = time_spec_t(0.0);time_spec_t(0.0);
    _has_tsf = !(_time == time_zero);
}

time_spec_t local_ctrl::get_time() {
    return _time;
}

void local_ctrl::set_tick_rate(const double rate) {
    _tick_rate = rate;
}

void local_ctrl::clear_seq() {
    std::lock_guard<std::mutex> lock(_transaction_mutex);
    _tx_seq = 0;
    _rx_seq = 0;
}

void local_ctrl::set_rx_buf_size(uint32_t len) {
    if(_rx_buf_len != len){
        _rx_buf_len = len;
        rx_buf_resize(len);
    }
}

void local_ctrl::set_tx_buf_size(uint32_t len) {
    if(_tx_buf_len != len){
        _tx_buf_len = len;
        tx_buf_resize(len);
    }
}

void local_ctrl::rx_buf_resize(uint32_t len) {
    delete [] _recv_buf;
    _recv_buf = new uint32_t[len];
}

void local_ctrl::tx_buf_resize(uint32_t len) {
    if (_send_buf) {
        delete [] _send_buf;
        _send_buf=nullptr;
    }
    _send_buf = new uint32_t[len];
}
