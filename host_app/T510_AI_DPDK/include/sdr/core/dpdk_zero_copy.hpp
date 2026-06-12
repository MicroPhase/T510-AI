//
// DPDK transport backend for IQ_TAXI
//

#ifndef SOAPY_DPDK_ZERO_COPY_HPP
#define SOAPY_DPDK_ZERO_COPY_HPP

#include <memory>
#include <string>
#include <vector>

#include "zero_copy.hpp"

namespace sdr { namespace core {

class API_EXPORT dpdk_zero_copy : public zero_copy_if
{
public:
    typedef std::shared_ptr<dpdk_zero_copy> sptr;

    static sptr make(const std::string& addr,
        const std::string& port,
        const zero_copy_xport_params& default_buff_args);

    virtual uint16_t get_local_port(void) const = 0;
    virtual std::string get_local_addr(void) const = 0;
    virtual bool recv_payload_copy(std::vector<uint8_t>& payload, double timeout = 1.0) = 0;
    virtual std::size_t flush_rx(void) = 0;
    virtual std::size_t get_dropped_rx_packets(void) const = 0;
    virtual std::size_t get_ready_rx_packets(void) const = 0;
    virtual std::size_t get_rx_slot_capacity(void) const = 0;
};

}} // namespace sdr::core

#endif // SOAPY_DPDK_ZERO_COPY_HPP
