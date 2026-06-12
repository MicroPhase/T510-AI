#ifndef T510_AI_RFDC_CTRL_HPP
#define T510_AI_RFDC_CTRL_HPP

#include <cstddef>
#include <cstdint>
#include <memory>

#include "../../src/transport/local_ctrl.hpp"

namespace t510_ai {

class t510_ai_rfdc_ctrl
{
public:
    using sptr = std::shared_ptr<t510_ai_rfdc_ctrl>;

    explicit t510_ai_rfdc_ctrl(local_ctrl::sptr ctrl_bus);

    uint32_t get_sample_rate();
    void set_sample_rate(double rate);

    void set_rx_if_freq(uint64_t rx_if_hz, std::size_t channel = 0);
    void set_tx_if_freq(uint64_t tx_if_hz, std::size_t channel = 0);
    uint64_t get_rx_if_freq(std::size_t channel = 0);
    uint64_t get_tx_if_freq(std::size_t channel = 0);

    void set_rx_freq(uint64_t rx_freq_hz, std::size_t channel = 0);
    void set_tx_freq(uint64_t tx_freq_hz, std::size_t channel = 0);
    uint64_t get_rx_freq(std::size_t channel = 0);
    uint64_t get_tx_freq(std::size_t channel = 0);

    uint32_t get_rx_gain(std::size_t channel = 0);
    uint32_t get_tx_gain(std::size_t channel = 0);
    void set_rx_gain(uint32_t rx_gain, std::size_t channel = 0);
    void set_tx_gain(uint32_t tx_gain, std::size_t channel = 0);

private:
    local_ctrl::sptr _ctrl_bus;
};

} // namespace t510_ai

#endif
