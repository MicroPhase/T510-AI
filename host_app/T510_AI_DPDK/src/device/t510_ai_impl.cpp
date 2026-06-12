#include "t510_ai/t510_ai_impl.hpp"

#include "sdr/log.hpp"

namespace t510_ai {
namespace {

using sdr::core::dpdk_zero_copy;
using sdr::core::zero_copy_if;
using sdr::core::zero_copy_xport_params;

static zero_copy_xport_params make_ctrl_params()
{
    zero_copy_xport_params params;
    params.send_frame_size = 1024;
    params.recv_frame_size = 1024;
    params.num_send_frames = 32;
    params.num_recv_frames = 32;
    params.send_buff_size  = 1 << 20;
    params.recv_buff_size  = 1 << 20;
    return params;
}

static zero_copy_xport_params make_iq_data_params()
{
    zero_copy_xport_params params;
    params.send_frame_size = 9000;
    params.recv_frame_size = 9000;
    params.num_send_frames = 256;
    params.num_recv_frames = 2048;
    params.send_buff_size  = 8 << 20;
    params.recv_buff_size  = 32 << 20;
    return params;
}

static zero_copy_if::sptr make_iq_data_xport(const std::string& remote_ip, uint16_t offload_port)
{
    return dpdk_zero_copy::make(remote_ip, std::to_string(offload_port), make_iq_data_params());
}

} // namespace

t510_ai_impl::t510_ai_impl(const std::string& remote_ip, uint16_t ctrl_port, uint16_t offload_port)
    : _remote_ip(remote_ip)
    , _ctrl_port(ctrl_port)
    , _offload_port(offload_port)
    , _ready(false)
{
    try {
        _ctrl_xport    = dpdk_zero_copy::make(remote_ip, std::to_string(ctrl_port), make_ctrl_params());
        _iq_data_xport = make_iq_data_xport(remote_ip, offload_port);
        _ctrl_bus      = std::make_shared<local_ctrl>(_ctrl_xport, 0x70, 8192);
        _rfdc_ctrl     = std::make_shared<t510_ai_rfdc_ctrl>(_ctrl_bus);
        _fpga_ctrl     = std::make_shared<t510_ai_fpga_ctrl>(_ctrl_bus);
        LOG_INFO("t510_ai_impl transport ports: ctrl=%u offload=%u", ctrl_port, offload_port);
        _ready         = true;
    } catch (const std::exception& ex) {
        LOG_ERROR("t510_ai_impl init failed: %s", ex.what());
        _ready = false;
    }
}

bool t510_ai_impl::is_ready() const
{
    return _ready;
}

const std::string& t510_ai_impl::remote_ip() const
{
    return _remote_ip;
}

uint16_t t510_ai_impl::ctrl_port() const
{
    return _ctrl_port;
}

uint16_t t510_ai_impl::offload_port() const
{
    return _offload_port;
}

local_ctrl::sptr t510_ai_impl::get_ctrl_bus() const
{
    return _ctrl_bus;
}

zero_copy_if::sptr t510_ai_impl::get_iq_data_xport() const
{
    std::lock_guard<std::mutex> lock(_iq_data_xport_mutex);
    return _iq_data_xport;
}

t510_ai_rfdc_ctrl::sptr t510_ai_impl::get_rfdc_ctrl() const
{
    return _rfdc_ctrl;
}

t510_ai_fpga_ctrl::sptr t510_ai_impl::get_fpga_ctrl() const
{
    return _fpga_ctrl;
}

void t510_ai_impl::set_timestamp(uint64_t time_stamp, uint32_t mode)
{
    _fpga_ctrl->set_timestamp(time_stamp, mode);
}

uint64_t t510_ai_impl::get_time_ticks()
{
    return _fpga_ctrl->get_time_ticks();
}

uint64_t t510_ai_impl::get_last_pps_time_ticks()
{
    return _fpga_ctrl->get_last_pps_time_ticks();
}

void t510_ai_impl::set_channel_enable(uint32_t channel_enable)
{
    _fpga_ctrl->set_channel_enable(channel_enable);
}

uint32_t t510_ai_impl::get_sample_rate()
{
    return _rfdc_ctrl->get_sample_rate();
}

void t510_ai_impl::set_sample_rate(double rate)
{
    _rfdc_ctrl->set_sample_rate(rate);
}

void t510_ai_impl::set_rx_center_freq(uint64_t rx_center_hz, std::size_t channel)
{
    _rfdc_ctrl->set_rx_if_freq(rx_center_hz, channel);
}

void t510_ai_impl::set_tx_center_freq(uint64_t tx_center_hz, std::size_t channel)
{
    _rfdc_ctrl->set_tx_if_freq(tx_center_hz, channel);
}

uint64_t t510_ai_impl::get_rx_center_freq(std::size_t channel)
{
    return _rfdc_ctrl->get_rx_if_freq(channel);
}

uint64_t t510_ai_impl::get_tx_center_freq(std::size_t channel)
{
    return _rfdc_ctrl->get_tx_if_freq(channel);
}

void t510_ai_impl::set_rfdc_rx_if_freq(uint64_t rx_if_hz, std::size_t channel)
{
    _rfdc_ctrl->set_rx_if_freq(rx_if_hz, channel);
}

void t510_ai_impl::set_rfdc_tx_if_freq(uint64_t tx_if_hz, std::size_t channel)
{
    _rfdc_ctrl->set_tx_if_freq(tx_if_hz, channel);
}

uint64_t t510_ai_impl::get_rfdc_rx_if_freq(std::size_t channel)
{
    return _rfdc_ctrl->get_rx_if_freq(channel);
}

uint64_t t510_ai_impl::get_rfdc_tx_if_freq(std::size_t channel)
{
    return _rfdc_ctrl->get_tx_if_freq(channel);
}

void t510_ai_impl::set_rx_freq(uint64_t rx_lo_hz, std::size_t channel)
{
    set_rx_center_freq(rx_lo_hz, channel);
}

void t510_ai_impl::set_tx_freq(uint64_t tx_lo_hz, std::size_t channel)
{
    set_tx_center_freq(tx_lo_hz, channel);
}

uint64_t t510_ai_impl::get_rx_freq(std::size_t channel)
{
    return get_rx_center_freq(channel);
}

uint64_t t510_ai_impl::get_tx_freq(std::size_t channel)
{
    return get_tx_center_freq(channel);
}

uint32_t t510_ai_impl::get_rx_gain(std::size_t)
{
    return _rfdc_ctrl->get_rx_gain();
}

uint32_t t510_ai_impl::get_tx_gain(std::size_t)
{
    return _rfdc_ctrl->get_tx_gain();
}

void t510_ai_impl::set_rx_gain(uint32_t rx_gain, std::size_t)
{
    _rfdc_ctrl->set_rx_gain(rx_gain);
}

void t510_ai_impl::set_tx_gain(uint32_t tx_gain, std::size_t)
{
    _rfdc_ctrl->set_tx_gain(tx_gain);
}

void t510_ai_impl::arm_rx_capture_once(uint32_t total_bytes, uint32_t packet_bytes)
{
    _fpga_ctrl->arm_rx_capture_once(total_bytes, packet_bytes);
}

void t510_ai_impl::arm_rx_stream(uint32_t chunk_bytes, uint32_t packet_bytes)
{
    _fpga_ctrl->arm_rx_stream(chunk_bytes, packet_bytes);
}

void t510_ai_impl::stop_rx_stream()
{
    _fpga_ctrl->stop_rx_stream();
}

bool t510_ai_impl::has_iq_data_xport() const
{
    std::lock_guard<std::mutex> lock(_iq_data_xport_mutex);
    return static_cast<bool>(_iq_data_xport);
}

bool t510_ai_impl::reopen_iq_data_xport()
{
    try {
        auto new_xport = make_iq_data_xport(_remote_ip, _offload_port);
        std::lock_guard<std::mutex> lock(_iq_data_xport_mutex);
        _iq_data_xport = std::move(new_xport);
        return true;
    } catch (const std::exception& ex) {
        LOG_ERROR("t510_ai_impl reopen_iq_data_xport failed: %s", ex.what());
        std::lock_guard<std::mutex> lock(_iq_data_xport_mutex);
        _iq_data_xport.reset();
        return false;
    }
}

void t510_ai_impl::close_iq_data_xport()
{
    std::lock_guard<std::mutex> lock(_iq_data_xport_mutex);
    _iq_data_xport.reset();
}

} // namespace t510_ai
