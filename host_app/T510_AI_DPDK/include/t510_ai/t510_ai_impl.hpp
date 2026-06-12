#ifndef T510_AI_IMPL_HPP
#define T510_AI_IMPL_HPP

#include "sdr/core/dpdk_zero_copy.hpp"
#include "t510_ai/chdr_epid.hpp"
#include "t510_ai/t510_ai_fpga_ctrl.hpp"
#include "t510_ai/t510_ai_rfdc_ctrl.hpp"
#include "t510_ai/t510_ai_regs.hpp"
#include <cstddef>
#include <cstdint>
#include <memory>
#include <mutex>
#include <string>

#include "../../src/transport/local_ctrl.hpp"

namespace t510_ai {

class t510_ai_impl
{
public:
    using sptr = std::shared_ptr<t510_ai_impl>;

    explicit t510_ai_impl(const std::string& remote_ip,
        uint16_t ctrl_port    = DEFAULT_CTRL_PORT,
        uint16_t offload_port = DEFAULT_DATA_PORT);

    bool is_ready() const;

    const std::string& remote_ip() const;
    uint16_t ctrl_port() const;
    uint16_t offload_port() const;

    local_ctrl::sptr get_ctrl_bus() const;
    sdr::core::zero_copy_if::sptr get_iq_data_xport() const;
    t510_ai_rfdc_ctrl::sptr get_rfdc_ctrl() const;
    t510_ai_fpga_ctrl::sptr get_fpga_ctrl() const;

    void set_timestamp(uint64_t time_stamp, uint32_t mode);
    uint64_t get_time_ticks();
    uint64_t get_last_pps_time_ticks();

    void set_channel_enable(uint32_t channel_enable);
    uint32_t get_sample_rate();
    void set_sample_rate(double rate);

    void set_rx_center_freq(uint64_t rx_center_hz, std::size_t channel = 0);
    void set_tx_center_freq(uint64_t tx_center_hz, std::size_t channel = 0);
    uint64_t get_rx_center_freq(std::size_t channel = 0);
    uint64_t get_tx_center_freq(std::size_t channel = 0);

    void set_rfdc_rx_if_freq(uint64_t rx_if_hz, std::size_t channel = 0);
    void set_rfdc_tx_if_freq(uint64_t tx_if_hz, std::size_t channel = 0);
    uint64_t get_rfdc_rx_if_freq(std::size_t channel = 0);
    uint64_t get_rfdc_tx_if_freq(std::size_t channel = 0);

    void set_rx_freq(uint64_t rx_lo_hz, std::size_t channel = 0);
    void set_tx_freq(uint64_t tx_lo_hz, std::size_t channel = 0);
    uint64_t get_rx_freq(std::size_t channel = 0);
    uint64_t get_tx_freq(std::size_t channel = 0);

    uint32_t get_rx_gain(std::size_t channel = 0);
    uint32_t get_tx_gain(std::size_t channel = 0);
    void set_rx_gain(uint32_t rx_gain, std::size_t channel = 0);
    void set_tx_gain(uint32_t tx_gain, std::size_t channel = 0);
    void arm_rx_capture_once(uint32_t total_bytes = t510_ai_fpga_ctrl::default_capture_bytes,
        uint32_t packet_bytes = t510_ai_fpga_ctrl::default_packet_bytes);
    void arm_rx_stream(uint32_t chunk_bytes = t510_ai_fpga_ctrl::default_capture_bytes,
        uint32_t packet_bytes = t510_ai_fpga_ctrl::default_packet_bytes);
    void stop_rx_stream();
    bool has_iq_data_xport() const;
    bool reopen_iq_data_xport();
    void close_iq_data_xport();

private:
    std::string _remote_ip;
    sdr::core::zero_copy_if::sptr _ctrl_xport;
    sdr::core::zero_copy_if::sptr _iq_data_xport;
    local_ctrl::sptr _ctrl_bus;
    t510_ai_rfdc_ctrl::sptr _rfdc_ctrl;
    t510_ai_fpga_ctrl::sptr _fpga_ctrl;
    uint16_t _ctrl_port;
    uint16_t _offload_port;
    bool _ready;
    mutable std::mutex _iq_data_xport_mutex;
};

} // namespace t510_ai

#endif
