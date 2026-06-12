#ifndef T510_AI_FPGA_CTRL_HPP
#define T510_AI_FPGA_CTRL_HPP

#include <cstdint>
#include <memory>

#include "../../src/transport/local_ctrl.hpp"

namespace t510_ai {

class t510_ai_fpga_ctrl
{
public:
    using sptr = std::shared_ptr<t510_ai_fpga_ctrl>;
    static constexpr uint32_t rx_mode_stream = 1;
    static constexpr uint32_t rx_mode_packet = 2;
    static constexpr uint32_t rx_mode_sync   = 3;
    static constexpr uint32_t default_capture_bytes = 4u * 1024u * 1024u;
    static constexpr uint32_t min_packet_bytes     = 8u;
    static constexpr uint32_t max_packet_bytes     = 8192u;
    static constexpr uint32_t default_packet_bytes  = 8160u;

    explicit t510_ai_fpga_ctrl(local_ctrl::sptr ctrl_bus);

    void set_timestamp(uint64_t time_stamp, uint32_t mode);
    uint64_t get_time_ticks();
    uint64_t get_last_pps_time_ticks();

    void set_channel_enable(uint32_t channel_enable);
    void stop_rx_stream();
    void arm_rx_capture_once(uint32_t total_bytes = default_capture_bytes,
        uint32_t packet_bytes = default_packet_bytes);
    void arm_rx_stream(uint32_t chunk_bytes = default_capture_bytes,
        uint32_t packet_bytes = default_packet_bytes);

private:
    static uint32_t sanitize_packet_bytes(uint32_t packet_bytes);

    void set_rx_mode(uint32_t mode);
    void set_rx_sample_count(uint32_t samples);
    void set_rx_max_packet_bytes(uint32_t bytes);
    void start_rx_stream();

    local_ctrl::sptr _ctrl_bus;
};

} // namespace t510_ai

#endif
