#include "t510_ai/t510_ai_fpga_ctrl.hpp"

#include "t510_ai/t510_ai_regs.hpp"
#include <stdexcept>

namespace t510_ai {
namespace {

using namespace t510_ai_regs;

} // namespace

t510_ai_fpga_ctrl::t510_ai_fpga_ctrl(local_ctrl::sptr ctrl_bus)
    : _ctrl_bus(std::move(ctrl_bus))
{
}

uint32_t t510_ai_fpga_ctrl::sanitize_packet_bytes(uint32_t packet_bytes)
{
    const uint32_t aligned_bytes = packet_bytes & ~0x7u;

    if (aligned_bytes < min_packet_bytes) {
        return min_packet_bytes;
    }
    if (aligned_bytes > max_packet_bytes) {
        return max_packet_bytes;
    }

    return aligned_bytes;
}

void t510_ai_fpga_ctrl::set_timestamp(uint64_t time_stamp, uint32_t mode)
{
    if (!_ctrl_bus) {
        throw std::runtime_error("control bus not ready");
    }
    _ctrl_bus->poke32(CUSTOM_SET_VITA_TIMESTAMP_LOW_ADDR, static_cast<uint32_t>(time_stamp & 0xffffffffu));
    _ctrl_bus->poke32(CUSTOM_SET_VITA_TIMESTAMP_HIGH_ADDR, static_cast<uint32_t>((time_stamp >> 32) & 0xffffffffu));
    _ctrl_bus->poke32(CUSTOM_SET_TIME_MODE_ADDR, mode);
}

uint64_t t510_ai_fpga_ctrl::get_time_ticks()
{
    if (!_ctrl_bus) {
        throw std::runtime_error("control bus not ready");
    }
    return _ctrl_bus->peek64(CUSTOM_RB_GET_VITA_TIME_ADDR);
}

uint64_t t510_ai_fpga_ctrl::get_last_pps_time_ticks()
{
    if (!_ctrl_bus) {
        throw std::runtime_error("control bus not ready");
    }
    return _ctrl_bus->peek64(CUSTOM_RB_GET_VITA_TIME_LAST_PPS_ADDR);
}

void t510_ai_fpga_ctrl::set_channel_enable(uint32_t channel_enable)
{
    if (!_ctrl_bus) {
        throw std::runtime_error("control bus not ready");
    }
    _ctrl_bus->poke32(CUSTOM_SET_CHANNEL_ENABLE_ADDR, channel_enable);
}

void t510_ai_fpga_ctrl::set_rx_mode(uint32_t mode)
{
    if (!_ctrl_bus) {
        throw std::runtime_error("control bus not ready");
    }
    _ctrl_bus->poke32(CUSTOM_SET_RX_MODE, mode);
}

void t510_ai_fpga_ctrl::set_rx_sample_count(uint32_t samples)
{
    if (!_ctrl_bus) {
        throw std::runtime_error("control bus not ready");
    }
    _ctrl_bus->poke32(CUSTOM_SET_RX_SAMPLE_NUMS_ADDR, samples);
}

void t510_ai_fpga_ctrl::set_rx_max_packet_bytes(uint32_t bytes)
{
    if (!_ctrl_bus) {
        throw std::runtime_error("control bus not ready");
    }
    _ctrl_bus->poke32(CUSTOM_SET_RX_MAX_PACKET_BYTES, sanitize_packet_bytes(bytes));
}

void t510_ai_fpga_ctrl::start_rx_stream()
{
    if (!_ctrl_bus) {
        throw std::runtime_error("control bus not ready");
    }
    _ctrl_bus->poke32(CUSTOM_SET_RX_STREAM_START, 1);
}

void t510_ai_fpga_ctrl::stop_rx_stream()
{
    if (!_ctrl_bus) {
        throw std::runtime_error("control bus not ready");
    }
    _ctrl_bus->poke32(CUSTOM_SET_RX_MODE_EXIT, 1);
}

void t510_ai_fpga_ctrl::arm_rx_capture_once(uint32_t total_bytes, uint32_t packet_bytes)
{
    set_rx_mode(rx_mode_packet);
    set_rx_sample_count(total_bytes);
    set_rx_max_packet_bytes(sanitize_packet_bytes(packet_bytes));
    _ctrl_bus->poke32(CUSTOM_SET_CAPTURE_START_ADDR, 1);
}

void t510_ai_fpga_ctrl::arm_rx_stream(uint32_t chunk_bytes, uint32_t packet_bytes)
{
    set_rx_mode(rx_mode_stream);
    set_rx_sample_count(chunk_bytes);
    set_rx_max_packet_bytes(sanitize_packet_bytes(packet_bytes));
    start_rx_stream();
}

} // namespace t510_ai
