#include "t510_ai/t510_ai_dpdk_device.hpp"
#include "t510_ai/t510_ai_iq_payload.hpp"

#include "sdr/log.hpp"
#include <algorithm>
#include <cstring>
#include <stdexcept>
#include <vector>

namespace t510_ai {
namespace {

using sdr::core::managed_recv_buffer;
using sdr::core::managed_send_buffer;
using sdr::core::zero_copy_if;

static void write_be16(uint8_t* p, uint16_t v)
{
    p[0] = static_cast<uint8_t>(v >> 8);
    p[1] = static_cast<uint8_t>(v & 0xffu);
}

static void write_be32(uint8_t* p, uint32_t v)
{
    p[0] = static_cast<uint8_t>(v >> 24);
    p[1] = static_cast<uint8_t>((v >> 16) & 0xffu);
    p[2] = static_cast<uint8_t>((v >> 8) & 0xffu);
    p[3] = static_cast<uint8_t>(v & 0xffu);
}

static void write_be64(uint8_t* p, uint64_t v)
{
    p[0] = static_cast<uint8_t>(v >> 56);
    p[1] = static_cast<uint8_t>((v >> 48) & 0xffu);
    p[2] = static_cast<uint8_t>((v >> 40) & 0xffu);
    p[3] = static_cast<uint8_t>((v >> 32) & 0xffu);
    p[4] = static_cast<uint8_t>((v >> 24) & 0xffu);
    p[5] = static_cast<uint8_t>((v >> 16) & 0xffu);
    p[6] = static_cast<uint8_t>((v >> 8) & 0xffu);
    p[7] = static_cast<uint8_t>(v & 0xffu);
}

static void write_le64(uint8_t* p, uint64_t v)
{
    p[0] = static_cast<uint8_t>(v & 0xffu);
    p[1] = static_cast<uint8_t>((v >> 8) & 0xffu);
    p[2] = static_cast<uint8_t>((v >> 16) & 0xffu);
    p[3] = static_cast<uint8_t>((v >> 24) & 0xffu);
    p[4] = static_cast<uint8_t>((v >> 32) & 0xffu);
    p[5] = static_cast<uint8_t>((v >> 40) & 0xffu);
    p[6] = static_cast<uint8_t>((v >> 48) & 0xffu);
    p[7] = static_cast<uint8_t>(v >> 56);
}

static uint32_t read_be32(const uint8_t* p)
{
    return (static_cast<uint32_t>(p[0]) << 24) | (static_cast<uint32_t>(p[1]) << 16)
           | (static_cast<uint32_t>(p[2]) << 8) | static_cast<uint32_t>(p[3]);
}

static uint64_t read_be64(const uint8_t* p)
{
    return (static_cast<uint64_t>(p[0]) << 56) | (static_cast<uint64_t>(p[1]) << 48)
           | (static_cast<uint64_t>(p[2]) << 40) | (static_cast<uint64_t>(p[3]) << 32)
           | (static_cast<uint64_t>(p[4]) << 24) | (static_cast<uint64_t>(p[5]) << 16)
           | (static_cast<uint64_t>(p[6]) << 8) | static_cast<uint64_t>(p[7]);
}

static uint64_t read_le64(const uint8_t* p)
{
    return (static_cast<uint64_t>(p[7]) << 56) | (static_cast<uint64_t>(p[6]) << 48)
           | (static_cast<uint64_t>(p[5]) << 40) | (static_cast<uint64_t>(p[4]) << 32)
           | (static_cast<uint64_t>(p[3]) << 24) | (static_cast<uint64_t>(p[2]) << 16)
           | (static_cast<uint64_t>(p[1]) << 8) | static_cast<uint64_t>(p[0]);
}

static uint64_t chdr_build_header(uint8_t vc,
    uint8_t eob,
    uint8_t eov,
    uint8_t pkt_type,
    uint8_t num_mdata,
    uint16_t seq_num,
    uint16_t length,
    uint16_t dst_epid)
{
    return (static_cast<uint64_t>(vc & 0x3fu) << 58)
           | (static_cast<uint64_t>(eob & 0x1u) << 57)
           | (static_cast<uint64_t>(eov & 0x1u) << 56)
           | (static_cast<uint64_t>(pkt_type & 0x7u) << 53)
           | (static_cast<uint64_t>(num_mdata & 0x1fu) << 48)
           | (static_cast<uint64_t>(seq_num) << 32) | (static_cast<uint64_t>(length) << 16)
           | static_cast<uint64_t>(dst_epid);
}

static uint64_t chdr_build_mgmt_header(
    uint16_t proto_ver, uint8_t chdr_w, uint16_t num_hops, uint16_t src_epid)
{
    return (static_cast<uint64_t>(proto_ver) << 48)
           | (static_cast<uint64_t>(chdr_w & 0x7u) << 45)
           | (static_cast<uint64_t>(num_hops & 0x03ffu) << 16)
           | static_cast<uint64_t>(src_epid);
}

static uint64_t chdr_build_mgmt_op(uint64_t op_payload, uint8_t op_code, uint8_t ops_pending)
{
    return ((op_payload & 0xffffffffffffull) << 16) | (static_cast<uint64_t>(op_code) << 8)
           | static_cast<uint64_t>(ops_pending);
}

static uint16_t chdr_get_dst_epid(uint64_t header)
{
    return static_cast<uint16_t>(header & 0xffffu);
}

static uint8_t chdr_get_pkt_type(uint64_t header)
{
    return static_cast<uint8_t>((header >> 53) & 0x7u);
}

static uint16_t chdr_get_length(uint64_t header)
{
    return static_cast<uint16_t>((header >> 16) & 0xffffu);
}

static void fill_pattern(uint8_t* payload, std::size_t payload_len, uint64_t seq)
{
    for (std::size_t i = 0; i < payload_len; i++) {
        payload[i] = static_cast<uint8_t>((seq + i) & 0xffu);
    }
}

static std::size_t build_test_payload(uint8_t* buf, std::size_t payload_len, uint64_t seq)
{
    write_be32(buf + 0, TEST_MAGIC);
    write_be16(buf + 4, TEST_VERSION);
    write_be16(buf + 6, static_cast<uint16_t>(TEST_HEADER_SIZE));
    write_be32(buf + 8, static_cast<uint32_t>(payload_len));
    write_be64(buf + 12, seq);
    write_be64(buf + 20, 0);
    fill_pattern(buf + TEST_HEADER_SIZE, payload_len, seq);
    return TEST_HEADER_SIZE + payload_len;
}

static std::size_t build_chdr_advertise_512(uint8_t* buf, uint16_t src_epid)
{
    const std::size_t packet_len = 3u * CHDR_NET_WORD_BYTES;

    std::memset(buf, 0, packet_len);
    write_le64(buf + 0, chdr_build_header(0, 0, 0, CHDR_PKT_TYPE_MGMT, 0, 0,
                             static_cast<uint16_t>(packet_len), 0));
    write_le64(buf + CHDR_NET_WORD_BYTES,
        chdr_build_mgmt_header(CHDR_PROTO_VER, CHDR_MGMT_WIDTH_512, 1, src_epid));
    write_le64(buf + 2u * CHDR_NET_WORD_BYTES, chdr_build_mgmt_op(0, CHDR_MGMT_OP_ADVERTISE, 0));
    return packet_len;
}

static std::size_t build_chdr_data_packet_512(
    uint8_t* buf, std::size_t payload_len, uint64_t seq, uint16_t dst_epid)
{
    const std::size_t inner_len  = build_test_payload(buf + CHDR_NET_WORD_BYTES, payload_len, seq);
    const std::size_t packet_len = CHDR_NET_WORD_BYTES + inner_len;

    write_le64(buf + 0, chdr_build_header(0, 0, 0, CHDR_PKT_TYPE_DATA, 0,
                             static_cast<uint16_t>(seq),
                             static_cast<uint16_t>(packet_len),
                             dst_epid));
    std::memset(buf + 8, 0, CHDR_NET_WORD_BYTES - 8);
    return packet_len;
}

static std::size_t build_source_ctrl_packet_512(
    uint8_t* buf, uint16_t ctrl_cmd, std::size_t payload_len, uint64_t packet_limit)
{
    const std::size_t packet_len = CHDR_NET_WORD_BYTES + TEST_HEADER_SIZE;

    std::memset(buf, 0, 2u * CHDR_NET_WORD_BYTES);
    write_le64(buf + 0, chdr_build_header(0, 0, 0, CHDR_PKT_TYPE_DATA, 0, 0,
                             static_cast<uint16_t>(packet_len), SOURCE_CTRL_DST_EPID));
    std::memset(buf + 8, 0, CHDR_NET_WORD_BYTES - 8);

    write_be32(buf + CHDR_NET_WORD_BYTES + 0, SOURCE_CTRL_MAGIC);
    write_be16(buf + CHDR_NET_WORD_BYTES + 4, SOURCE_CTRL_VERSION);
    write_be16(buf + CHDR_NET_WORD_BYTES + 6, ctrl_cmd);
    write_be32(buf + CHDR_NET_WORD_BYTES + 8, static_cast<uint32_t>(payload_len));
    write_be64(buf + CHDR_NET_WORD_BYTES + 12, packet_limit);
    write_be64(buf + CHDR_NET_WORD_BYTES + 20, 0);
    return packet_len;
}

} // namespace

t510_ai_dpdk_device::t510_ai_dpdk_device(
    const std::string& remote_ip, uint16_t ctrl_port, uint16_t data_port)
    : _impl(std::make_shared<t510_ai_impl>(remote_ip, ctrl_port, data_port))
{
}

bool t510_ai_dpdk_device::is_ready() const
{
    return _impl && _impl->is_ready();
}

t510_ai_impl::sptr t510_ai_dpdk_device::get_impl() const
{
    return _impl;
}

local_ctrl::sptr t510_ai_dpdk_device::get_ctrl_bus() const
{
    return _impl ? _impl->get_ctrl_bus() : nullptr;
}

zero_copy_if::sptr t510_ai_dpdk_device::get_data_xport() const
{
    return _impl ? _impl->get_iq_data_xport() : nullptr;
}

bool t510_ai_dpdk_device::send_payload(const uint8_t* data, std::size_t len, double timeout)
{
    const zero_copy_if::sptr data_xport = get_data_xport();
    if (!data_xport) {
        return false;
    }
    managed_send_buffer::sptr send_buffer =
        data_xport->get_send_buff(timeout, static_cast<uint32_t>(len));
    if (!send_buffer || send_buffer->size() < len) {
        return false;
    }
    std::memcpy(send_buffer->cast<void*>(), data, len);
    send_buffer->commit(len);
    return true;
}

bool t510_ai_dpdk_device::recv_packet(std::vector<uint8_t>& packet, double timeout)
{
    const zero_copy_if::sptr data_xport = get_data_xport();
    if (!data_xport) {
        return false;
    }
    if (auto dpdk_xport = std::dynamic_pointer_cast<sdr::core::dpdk_zero_copy>(data_xport)) {
        return dpdk_xport->recv_payload_copy(packet, timeout);
    }
    managed_recv_buffer::sptr recv_buffer = data_xport->get_recv_buff(timeout);
    if (!recv_buffer || recv_buffer->size() == 0) {
        return false;
    }
    packet.resize(recv_buffer->size());
    std::memcpy(packet.data(), recv_buffer->cast<const void*>(), recv_buffer->size());
    return true;
}

bool t510_ai_dpdk_device::recv_iq_packet(
    uint64_t* seq_out, std::vector<uint8_t>& iq_payload_out, double timeout)
{
    std::vector<uint8_t> packet;
    uint64_t seq = 0;
    std::string error;

    if (!recv_packet(packet, timeout)) {
        return false;
    }

    if (!extract_iq_capture_payload_from_chdr(
            packet, seq_out ? &seq : nullptr, iq_payload_out, &error)) {
        LOG_WARNING("recv_iq_packet dropped packet: %s (size=%zu)", error.c_str(), packet.size());
        return false;
    }
    if (seq_out) {
        *seq_out = seq;
    }
    return true;
}

bool t510_ai_dpdk_device::advertise_route(uint16_t src_epid, double timeout)
{
    uint8_t packet[3u * CHDR_NET_WORD_BYTES];
    const std::size_t packet_len = build_chdr_advertise_512(packet, src_epid);
    if (!send_payload(packet, packet_len, timeout)) {
        return false;
    }
    _route_advertised = true;
    _advertised_src_epid = src_epid;
    return true;
}

bool t510_ai_dpdk_device::ensure_route_advertised(uint16_t src_epid, double timeout)
{
    if (_route_advertised && _advertised_src_epid == src_epid) {
        return true;
    }
    return advertise_route(src_epid, timeout);
}

void t510_ai_dpdk_device::invalidate_route_cache()
{
    _route_advertised = false;
    _advertised_src_epid = 0;
}

bool t510_ai_dpdk_device::prepare_iq_data_path(uint16_t src_epid, double timeout)
{
    if (!ensure_iq_data_transport()) {
        return false;
    }
    return ensure_route_advertised(src_epid, timeout);
}

void t510_ai_dpdk_device::release_iq_data_path()
{
    close_iq_data_transport();
}

bool t510_ai_dpdk_device::has_iq_data_transport() const
{
    return _impl && _impl->has_iq_data_xport();
}

bool t510_ai_dpdk_device::ensure_iq_data_transport()
{
    if (has_iq_data_transport()) {
        return true;
    }
    return reopen_iq_data_transport();
}

bool t510_ai_dpdk_device::reopen_iq_data_transport()
{
    if (!_impl) {
        return false;
    }
    invalidate_route_cache();
    return _impl->reopen_iq_data_xport();
}

void t510_ai_dpdk_device::close_iq_data_transport()
{
    invalidate_route_cache();
    if (_impl) {
        _impl->close_iq_data_xport();
    }
}

std::size_t t510_ai_dpdk_device::get_dropped_rx_packets() const
{
    const zero_copy_if::sptr data_xport = get_data_xport();
    if (auto dpdk_xport = std::dynamic_pointer_cast<sdr::core::dpdk_zero_copy>(data_xport)) {
        return dpdk_xport->get_dropped_rx_packets();
    }
    return 0u;
}

std::size_t t510_ai_dpdk_device::get_ready_rx_packets() const
{
    const zero_copy_if::sptr data_xport = get_data_xport();
    if (auto dpdk_xport = std::dynamic_pointer_cast<sdr::core::dpdk_zero_copy>(data_xport)) {
        return dpdk_xport->get_ready_rx_packets();
    }
    return 0u;
}

std::size_t t510_ai_dpdk_device::get_rx_slot_capacity() const
{
    const zero_copy_if::sptr data_xport = get_data_xport();
    if (auto dpdk_xport = std::dynamic_pointer_cast<sdr::core::dpdk_zero_copy>(data_xport)) {
        return dpdk_xport->get_rx_slot_capacity();
    }
    return 0u;
}

uint16_t t510_ai_dpdk_device::ctrl_port() const
{
    return _impl ? _impl->ctrl_port() : 0;
}

uint16_t t510_ai_dpdk_device::data_port() const
{
    return _impl ? _impl->offload_port() : 0;
}

uint16_t t510_ai_dpdk_device::offload_port() const
{
    return data_port();
}

} // namespace t510_ai
