#include "t510_ai/t510_ai_rfdc_ctrl.hpp"

#include "t510_ai/t510_ai_regs.hpp"
#include <stdexcept>

namespace t510_ai {
namespace {

using namespace t510_ai_regs;

static uint64_t join_u64(uint32_t low, uint32_t high)
{
    return (static_cast<uint64_t>(high) << 32) | static_cast<uint64_t>(low);
}

} // namespace

t510_ai_rfdc_ctrl::t510_ai_rfdc_ctrl(local_ctrl::sptr ctrl_bus)
    : _ctrl_bus(std::move(ctrl_bus))
{
}

uint32_t t510_ai_rfdc_ctrl::get_sample_rate()
{
    if (!_ctrl_bus) {
        throw std::runtime_error("control bus not ready");
    }
    return _ctrl_bus->peek32(CUSTOM_RB_GET_SAMPLE_CLOCK_RATE_ADDR);
}

void t510_ai_rfdc_ctrl::set_sample_rate(double rate)
{
    if (!_ctrl_bus) {
        throw std::runtime_error("control bus not ready");
    }
    _ctrl_bus->poke32(CUSTOM_SET_SAMPLE_RATE_DY, static_cast<uint32_t>(rate));
}

void t510_ai_rfdc_ctrl::set_rx_if_freq(uint64_t rx_if_hz, std::size_t)
{
    if (!_ctrl_bus) {
        throw std::runtime_error("control bus not ready");
    }
    _ctrl_bus->poke32(
        CUSTOM_SET_RX_CH1_LO_FREQ_LOW_ADDR, static_cast<uint32_t>(rx_if_hz & 0xffffffffu));
    _ctrl_bus->poke32(CUSTOM_SET_RX_CH1_LO_FREQ_HIGH_ADDR,
        static_cast<uint32_t>((rx_if_hz >> 32) & 0xffffffffu));
}

void t510_ai_rfdc_ctrl::set_tx_if_freq(uint64_t tx_if_hz, std::size_t)
{
    if (!_ctrl_bus) {
        throw std::runtime_error("control bus not ready");
    }
    _ctrl_bus->poke32(
        CUSTOM_SET_TX_CH1_LO_FREQ_LOW_ADDR, static_cast<uint32_t>(tx_if_hz & 0xffffffffu));
    _ctrl_bus->poke32(CUSTOM_SET_TX_CH1_LO_FREQ_HIGH_ADDR,
        static_cast<uint32_t>((tx_if_hz >> 32) & 0xffffffffu));
}

uint64_t t510_ai_rfdc_ctrl::get_rx_if_freq(std::size_t)
{
    if (!_ctrl_bus) {
        throw std::runtime_error("control bus not ready");
    }
    return join_u64(_ctrl_bus->peek32(CUSTOM_RB_GET_RX_CH1_LO_FREQ_LOW_ADDR),
        _ctrl_bus->peek32(CUSTOM_RB_GET_RX_CH1_LO_FREQ_HIGH_ADDR));
}

uint64_t t510_ai_rfdc_ctrl::get_tx_if_freq(std::size_t)
{
    if (!_ctrl_bus) {
        throw std::runtime_error("control bus not ready");
    }
    return join_u64(_ctrl_bus->peek32(CUSTOM_RB_GET_TX_CH1_LO_FREQ_LOW_ADDR),
        _ctrl_bus->peek32(CUSTOM_RB_GET_TX_CH1_LO_FREQ_HIGH_ADDR));
}

void t510_ai_rfdc_ctrl::set_rx_freq(uint64_t rx_freq_hz, std::size_t channel)
{
    set_rx_if_freq(rx_freq_hz, channel);
}

void t510_ai_rfdc_ctrl::set_tx_freq(uint64_t tx_freq_hz, std::size_t channel)
{
    set_tx_if_freq(tx_freq_hz, channel);
}

uint64_t t510_ai_rfdc_ctrl::get_rx_freq(std::size_t channel)
{
    return get_rx_if_freq(channel);
}

uint64_t t510_ai_rfdc_ctrl::get_tx_freq(std::size_t channel)
{
    return get_tx_if_freq(channel);
}

uint32_t t510_ai_rfdc_ctrl::get_rx_gain(std::size_t)
{
    if (!_ctrl_bus) {
        throw std::runtime_error("control bus not ready");
    }
    return _ctrl_bus->peek32(CUSTOM_RB_GET_RX_CH1_GAIN_ADDR);
}

uint32_t t510_ai_rfdc_ctrl::get_tx_gain(std::size_t)
{
    if (!_ctrl_bus) {
        throw std::runtime_error("control bus not ready");
    }
    return _ctrl_bus->peek32(CUSTOM_RB_GET_TX_CH1_GAIN_ADDR);
}

void t510_ai_rfdc_ctrl::set_rx_gain(uint32_t rx_gain, std::size_t)
{
    if (!_ctrl_bus) {
        throw std::runtime_error("control bus not ready");
    }
    _ctrl_bus->poke32(CUSTOM_SET_RX_CH1_GAIN_ADDR, rx_gain);
}

void t510_ai_rfdc_ctrl::set_tx_gain(uint32_t tx_gain, std::size_t)
{
    if (!_ctrl_bus) {
        throw std::runtime_error("control bus not ready");
    }
    _ctrl_bus->poke32(CUSTOM_SET_TX_CH1_GAIN_ADDR, tx_gain);
}

} // namespace t510_ai
