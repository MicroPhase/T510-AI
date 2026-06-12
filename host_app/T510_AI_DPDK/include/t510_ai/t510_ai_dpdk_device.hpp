#ifndef T510_AI_DPDK_DEVICE_HPP
#define T510_AI_DPDK_DEVICE_HPP

#include "t510_ai/t510_ai_impl.hpp"
#include <cstddef>
#include <cstdint>
#include <memory>
#include <vector>

namespace t510_ai {

class t510_ai_dpdk_device
{
public:
    using sptr = std::shared_ptr<t510_ai_dpdk_device>;

    explicit t510_ai_dpdk_device(const std::string& remote_ip,
        uint16_t ctrl_port = DEFAULT_CTRL_PORT,
        uint16_t data_port = DEFAULT_DATA_PORT);

    bool is_ready() const;
    t510_ai_impl::sptr get_impl() const;

    local_ctrl::sptr get_ctrl_bus() const;
    sdr::core::zero_copy_if::sptr get_data_xport() const;

    bool recv_packet(std::vector<uint8_t>& packet, double timeout = 1.0);
    bool recv_iq_packet(
        uint64_t* seq_out, std::vector<uint8_t>& iq_payload_out, double timeout = 1.0);
    bool advertise_route(uint16_t src_epid, double timeout = 1.0);
    bool ensure_route_advertised(uint16_t src_epid, double timeout = 1.0);
    void invalidate_route_cache();
    bool prepare_iq_data_path(uint16_t src_epid = IQ_CAPTURE_DST_EPID, double timeout = 1.0);
    void release_iq_data_path();
    bool has_iq_data_transport() const;
    bool ensure_iq_data_transport();
    bool reopen_iq_data_transport();
    void close_iq_data_transport();
    std::size_t get_dropped_rx_packets() const;
    std::size_t get_ready_rx_packets() const;
    std::size_t get_rx_slot_capacity() const;

    uint16_t ctrl_port() const;
    uint16_t data_port() const;
    uint16_t offload_port() const;

private:
    bool send_payload(const uint8_t* data, std::size_t len, double timeout);

    t510_ai_impl::sptr _impl;
    bool _route_advertised = false;
    uint16_t _advertised_src_epid = 0;
};

} // namespace t510_ai

#endif
