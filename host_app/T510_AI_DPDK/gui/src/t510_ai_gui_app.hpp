#pragma once

#include "imgui.h"

#include "t510_ai/t510_ai_dpdk_device.hpp"
#include "t510_ai/t510_ai_iq_payload.hpp"

#include <algorithm>
#include <atomic>
#include <chrono>
#include <cmath>
#include <complex>
#include <condition_variable>
#include <cstdint>
#include <cstdio>
#include <deque>
#include <fstream>
#include <memory>
#include <mutex>
#include <sstream>
#include <string>
#include <thread>
#include <utility>
#include <vector>

namespace t510_ai_gui {

extern std::atomic<bool> g_shutdown_requested;

extern "C" void t510_gui_signal_handler(int);

inline constexpr const char* default_remote_ip = "192.168.10.3";
inline constexpr uint64_t fixed_sample_rate_hz = 245760000ull;
inline constexpr uint32_t default_display_samples = 65536u;
inline constexpr uint32_t default_fft_size = 4096u;
inline constexpr std::size_t time_trace_plot_limit = 65536u;
inline constexpr std::size_t ring_capacity = 131072u;
inline constexpr const char* default_cjk_font = "/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc";
inline constexpr std::size_t stream_display_buffer_limit = ring_capacity;
inline constexpr std::size_t stream_display_samples_per_packet = 64u;
inline constexpr std::size_t stream_fft_packet_batch = 16u;
inline constexpr auto stream_publish_interval = std::chrono::milliseconds(50);
inline constexpr auto drain_publish_interval = std::chrono::milliseconds(200);
inline constexpr auto stream_idle_poll_timeout = std::chrono::milliseconds(20);
inline constexpr auto drain_start_prime_time = std::chrono::milliseconds(500);
inline constexpr std::size_t drain_start_prime_packet_limit = 65536u;
inline constexpr std::size_t stream_drain_batch_limit = 256u;
inline constexpr std::size_t stream_display_packet_cycle = 1024u;
inline constexpr std::size_t stream_display_packet_window = 64u;
inline constexpr auto stream_stop_settle_time = std::chrono::milliseconds(80);
inline constexpr std::size_t stream_stop_drain_limit = 4u * 1024u * 1024u;
inline constexpr auto stream_stop_idle_time = std::chrono::milliseconds(60);
inline constexpr std::size_t record_queue_depth = 16384u;
inline constexpr std::size_t waterfall_rows = 220u;
inline constexpr std::size_t waterfall_bins = 384u;
inline constexpr std::size_t spectrum_bins = 512u;
inline constexpr float spectrum_slider_min_dbfs = -140.0f;
inline constexpr float spectrum_slider_max_dbfs = 0.0f;
inline constexpr float spectrum_tick_step_db = 10.0f;

struct spectrum_trace_state
{
    std::vector<float> current;
    std::vector<float> glow;
    std::vector<float> peak;
    std::vector<std::vector<float>> history;

    void reset()
    {
        current.clear();
        glow.clear();
        peak.clear();
        history.clear();
    }

    void update(const std::vector<float>& input)
    {
        if (input.empty()) {
            return;
        }

        if (current.size() != input.size()) {
            current = input;
            glow = input;
            peak = input;
            history.assign(1u, input);
            return;
        }

        for (std::size_t i = 0; i < input.size(); i++) {
            current[i] = current[i] * 0.10f + input[i] * 0.90f;
            glow[i] = std::max(current[i], glow[i] - 0.38f);
            peak[i] = std::max(current[i], peak[i] - 0.06f);
        }

        if (history.size() >= 14u) {
            history.erase(history.begin());
        }
        history.push_back(current);
    }
};

struct waterfall_history
{
    explicit waterfall_history(std::size_t rows = waterfall_rows, std::size_t bins = waterfall_bins)
        : _rows(rows)
        , _bins(bins)
        , _data(rows, std::vector<float>(bins, 0.0f))
    {
    }

    void clear()
    {
        for (auto& row : _data) {
            std::fill(row.begin(), row.end(), 0.0f);
        }
        _next_row = 0;
        _filled = 0;
        _scale_ready = false;
        _floor_db = -105.0f;
        _ceil_db = -35.0f;
    }

    void push(const std::vector<float>& spectrum_db)
    {
        if (spectrum_db.empty()) {
            return;
        }
        std::vector<float> sorted = spectrum_db;
        std::sort(sorted.begin(), sorted.end());
        const std::size_t low_index = sorted.size() / 12u;
        const std::size_t high_index = (sorted.size() * 19u) / 20u;
        const float local_floor = sorted[std::min(low_index, sorted.size() - 1u)];
        const float local_ceil = sorted[std::min(high_index, sorted.size() - 1u)];
        if (!_scale_ready) {
            _floor_db = local_floor;
            _ceil_db = std::max(local_floor + 20.0f, local_ceil);
            _scale_ready = true;
        } else {
            _floor_db = _floor_db * 0.92f + local_floor * 0.08f;
            _ceil_db = _ceil_db * 0.88f + std::max(local_floor + 20.0f, local_ceil) * 0.12f;
        }
        const float range = std::max(18.0f, _ceil_db - _floor_db);
        auto& row = _data[_next_row];
        for (std::size_t i = 0; i < _bins; i++) {
            const std::size_t src = (i * spectrum_db.size()) / _bins;
            const float db = spectrum_db[std::min(src, spectrum_db.size() - 1u)];
            const float normalized = std::clamp((db - _floor_db) / range, 0.0f, 1.0f);
            row[i] = std::pow(normalized, 0.78f);
        }
        _next_row = (_next_row + 1u) % _rows;
        if (_filled < _rows) {
            _filled++;
        }
    }

    std::size_t rows() const
    {
        return _filled;
    }

    std::size_t bins() const
    {
        return _bins;
    }

    const std::vector<float>& row_from_oldest(std::size_t index) const
    {
        const std::size_t oldest = (_next_row + _rows - _filled) % _rows;
        return _data[(oldest + index) % _rows];
    }

    const std::vector<float>& row_from_newest(std::size_t index) const
    {
        const std::size_t newest = (_next_row + _rows - 1u) % _rows;
        return _data[(newest + _rows - (index % _rows)) % _rows];
    }

private:
    std::size_t _rows = 0;
    std::size_t _bins = 0;
    std::size_t _next_row = 0;
    std::size_t _filled = 0;
    bool _scale_ready = false;
    float _floor_db = -105.0f;
    float _ceil_db = -35.0f;
    std::vector<std::vector<float>> _data;
};

struct sample_ring
{
    explicit sample_ring(std::size_t capacity = ring_capacity)
        : _capacity(capacity)
        , _ch0_i(capacity, 0.0f)
        , _ch0_q(capacity, 0.0f)
        , _ch1_i(capacity, 0.0f)
        , _ch1_q(capacity, 0.0f)
        , _ch1_valid(capacity, false)
    {
    }

    void clear()
    {
        _head = 0;
        _count = 0;
    }

    void push(const t510_ai::t510_ai_iq_sample& sample)
    {
        _ch0_i[_head] = static_cast<float>(sample.ch0_i);
        _ch0_q[_head] = static_cast<float>(sample.ch0_q);
        _ch1_i[_head] = static_cast<float>(sample.ch1_i);
        _ch1_q[_head] = static_cast<float>(sample.ch1_q);
        _ch1_valid[_head] = sample.ch1_valid;

        _head = (_head + 1u) % _capacity;
        if (_count < _capacity) {
            _count++;
        }
    }

    std::size_t size() const
    {
        return _count;
    }

    std::vector<std::complex<float>> snapshot_ch0(std::size_t max_points) const
    {
        return snapshot_channel(_ch0_i, _ch0_q, max_points);
    }

    std::vector<std::complex<float>> snapshot_ch1(std::size_t max_points) const
    {
        if (!has_ch1()) {
            return {};
        }
        return snapshot_channel(_ch1_i, _ch1_q, max_points);
    }

    bool has_ch1() const
    {
        if (_count == 0) {
            return false;
        }
        for (std::size_t i = 0; i < _count; i++) {
            if (_ch1_valid[index_from_oldest(i)]) {
                return true;
            }
        }
        return false;
    }

private:
    std::size_t index_from_oldest(std::size_t offset) const
    {
        const std::size_t oldest = (_head + _capacity - _count) % _capacity;
        return (oldest + offset) % _capacity;
    }

    std::vector<std::complex<float>> snapshot_channel(
        const std::vector<float>& i_buf, const std::vector<float>& q_buf, std::size_t max_points) const
    {
        const std::size_t take = std::min(_count, max_points);
        std::vector<std::complex<float>> out;
        out.reserve(take);
        for (std::size_t i = _count - take; i < _count; i++) {
            const std::size_t idx = index_from_oldest(i);
            out.emplace_back(i_buf[idx], q_buf[idx]);
        }
        return out;
    }

    std::size_t _capacity = 0;
    std::size_t _head = 0;
    std::size_t _count = 0;
    std::vector<float> _ch0_i;
    std::vector<float> _ch0_q;
    std::vector<float> _ch1_i;
    std::vector<float> _ch1_q;
    std::vector<bool> _ch1_valid;
};

struct continuity_stats
{
    uint64_t packet_count = 0;
    uint64_t payload_bytes = 0;
    uint64_t sample_count = 0;
    uint64_t first_seq = 0;
    uint64_t last_seq = 0;
    uint64_t first_vita_time = 0;
    uint64_t last_vita_time = 0;
    uint64_t seq_gap_events = 0;
    uint64_t seq_gap_total = 0;
    uint64_t vita_gap_events = 0;
    uint64_t vita_gap_total = 0;
    uint64_t seq_first_expected = 0;
    uint64_t seq_first_actual = 0;
    uint64_t vita_first_expected = 0;
    uint64_t vita_first_actual = 0;
    bool channel_enable_stable = true;
    uint8_t channel_enable = 0;
    bool have_seq = false;
    bool have_vita = false;
    uint64_t expected_next_seq = 0;
    uint64_t expected_next_vita = 0;

    static uint16_t next_seq16(uint64_t seq)
    {
        return static_cast<uint16_t>((static_cast<uint16_t>(seq) + 1u) & 0xffffu);
    }

    static uint16_t seq_gap16(uint64_t expected, uint64_t actual)
    {
        return static_cast<uint16_t>(
            (static_cast<uint16_t>(actual) - static_cast<uint16_t>(expected)) & 0xffffu);
    }

    void reset()
    {
        *this = continuity_stats{};
    }

    void update(const t510_ai::t510_ai_iq_frame& frame)
    {
        if (!have_seq) {
            first_seq = frame.seq;
            expected_next_seq = next_seq16(frame.seq);
            have_seq = true;
        } else {
            if (frame.seq != expected_next_seq) {
                seq_gap_events++;
                if (seq_gap_events == 1u) {
                    seq_first_expected = expected_next_seq;
                    seq_first_actual = frame.seq;
                }
                seq_gap_total += seq_gap16(expected_next_seq, frame.seq);
            }
            expected_next_seq = next_seq16(frame.seq);
        }
        last_seq = frame.seq;

        if (packet_count == 0u) {
            channel_enable = frame.channel_enable;
            first_vita_time = frame.first_vita_time;
        } else if (frame.channel_enable != channel_enable) {
            channel_enable_stable = false;
        }

        if (!frame.samples.empty()) {
            if (!have_vita) {
                expected_next_vita = frame.samples.back().vita_time + 1u;
                have_vita = true;
            } else {
                if (frame.first_vita_time != expected_next_vita) {
                    vita_gap_events++;
                    if (vita_gap_events == 1u) {
                        vita_first_expected = expected_next_vita;
                        vita_first_actual = frame.first_vita_time;
                    }
                    if (frame.first_vita_time > expected_next_vita) {
                        vita_gap_total += (frame.first_vita_time - expected_next_vita);
                    }
                }
                expected_next_vita = frame.samples.back().vita_time + 1u;
            }
            last_vita_time = frame.samples.back().vita_time;
        }

        packet_count++;
        payload_bytes += frame.sample_bytes;
        sample_count += frame.samples.size();
    }

    void update_packet(
        uint64_t seq,
        uint8_t packet_channel_enable,
        uint16_t packet_sample_bytes,
        uint64_t packet_first_vita_time,
        uint64_t packet_sample_count)
    {
        if (!have_seq) {
            first_seq = seq;
            expected_next_seq = next_seq16(seq);
            have_seq = true;
        } else {
            if (seq != expected_next_seq) {
                seq_gap_events++;
                if (seq_gap_events == 1u) {
                    seq_first_expected = expected_next_seq;
                    seq_first_actual = seq;
                }
                seq_gap_total += seq_gap16(expected_next_seq, seq);
            }
            expected_next_seq = next_seq16(seq);
        }
        last_seq = seq;

        if (packet_count == 0u) {
            channel_enable = packet_channel_enable;
            first_vita_time = packet_first_vita_time;
        } else if (packet_channel_enable != channel_enable) {
            channel_enable_stable = false;
        }

        if (packet_sample_count != 0u) {
            const uint64_t packet_last_vita_time = packet_first_vita_time + packet_sample_count - 1u;
            if (!have_vita) {
                expected_next_vita = packet_last_vita_time + 1u;
                have_vita = true;
            } else {
                if (packet_first_vita_time != expected_next_vita) {
                    vita_gap_events++;
                    if (vita_gap_events == 1u) {
                        vita_first_expected = expected_next_vita;
                        vita_first_actual = packet_first_vita_time;
                    }
                    if (packet_first_vita_time > expected_next_vita) {
                        vita_gap_total += (packet_first_vita_time - expected_next_vita);
                    }
                }
                expected_next_vita = packet_last_vita_time + 1u;
            }
            last_vita_time = packet_last_vita_time;
        }

        packet_count++;
        payload_bytes += packet_sample_bytes;
        sample_count += packet_sample_count;
    }
};

struct iq_frame_meta
{
    uint64_t seq = 0;
    uint8_t channel_enable = 0;
    uint16_t sample_bytes = 0;
    uint64_t first_vita_time = 0;
    uint64_t sample_count = 0;
};

struct capture_result
{
    continuity_stats stats;
    std::string message;
    bool success = false;
    std::size_t bytes_written = 0;
    std::size_t packets_received = 0;
    std::vector<std::complex<float>> ch0_iq;
    std::vector<std::complex<float>> ch1_iq;
};

struct drain_result
{
    std::size_t drained = 0u;
    bool hit_limit = false;
};

struct quiesce_result
{
    std::size_t drained_total = 0u;
    std::size_t flush_total = 0u;
    std::size_t drain_total = 0u;
    std::size_t hit_limit_count = 0u;
};

struct gui_state
{
    struct mode_debug
    {
        std::string mode_name;
        uint64_t dpdk_drop_base = 0;
        uint64_t dpdk_drop_total = 0;
        uint64_t dpdk_drop_delta = 0;
        std::size_t dpdk_ready_packets = 0;
        std::size_t dpdk_slot_capacity = 0;
        uint64_t app_queue_drop_packets = 0;
        std::size_t app_queue_ready_depth = 0;
        std::size_t app_queue_peak_depth = 0;
        std::string last_quiesce_summary;

        void reset()
        {
            *this = mode_debug{};
        }
    };

    std::mutex mutex;
    sample_ring ring;
    std::vector<float> live_ch0_spectrum;
    std::vector<float> live_ch1_spectrum;
    waterfall_history live_waterfall;
    continuity_stats stats;
    mode_debug debug;
    std::string status = "Not connected";
    std::string last_error;
    bool streaming = false;
    bool recording = false;
    bool draining = false;
    bool connected = false;
    bool has_ch1 = false;
    bool spectral_source_single_capture = false;
    uint64_t live_visual_generation = 0;
};

struct rx_debug_stats
{
    std::size_t dropped_packets = 0;
    std::size_t ready_packets = 0;
    std::size_t slot_capacity = 0;
};

class async_action_worker
{
public:
    ~async_action_worker()
    {
        join();
    }

    bool busy() const
    {
        return _busy.load();
    }

    template <typename Fn>
    void start(Fn&& fn)
    {
        if (_busy.load()) {
            return;
        }
        join();
        _busy.store(true);
        _thread = std::thread([this, task = std::forward<Fn>(fn)]() mutable {
            task();
            _busy.store(false);
        });
    }

    void join()
    {
        if (_thread.joinable()) {
            _thread.join();
        }
    }

private:
    std::atomic<bool> _busy{false};
    std::thread _thread;
};

struct app_model
{
    char remote_ip[64] = {};
    char capture_output[256] = {};
    char record_output[256] = {};
    uint32_t channel_enable = 1u;
    uint64_t sample_rate_hz = fixed_sample_rate_hz;
    uint64_t applied_sample_rate_hz = fixed_sample_rate_hz;
    uint64_t rx_center_freq_hz = 1850000000ull;
    uint64_t applied_rx_center_freq_hz = 1850000000ull;
    uint64_t tx_center_freq_hz = 1850000000ull;
    uint64_t applied_tx_center_freq_hz = 1850000000ull;
    uint64_t rx_if_freq_hz = 1850000000ull;
    uint64_t tx_if_freq_hz = 1850000000ull;
    uint32_t rx_gain = 0u;
    uint32_t applied_rx_gain = 0u;
    uint32_t tx_gain = 0u;
    uint32_t applied_tx_gain = 0u;
    uint64_t set_time_ticks = 0ull;
    uint32_t set_time_mode = 0u;
    uint64_t current_time_ticks = 0ull;
    float capture_size_mb = static_cast<float>(t510_ai::t510_ai_fpga_ctrl::default_capture_bytes)
                            / static_cast<float>(1024u * 1024u);
    uint32_t packet_bytes = t510_ai::t510_ai_fpga_ctrl::default_packet_bytes;
    uint32_t stream_chunk_bytes = t510_ai::t510_ai_fpga_ctrl::default_capture_bytes;
    uint32_t display_samples = default_display_samples;
    uint32_t fft_size = default_fft_size;
    float spectrum_top_dbfs = -60.0f;
    float spectrum_bottom_dbfs = -120.0f;

    app_model()
    {
        std::snprintf(remote_ip, sizeof(remote_ip), "%s", default_remote_ip);
        std::snprintf(capture_output, sizeof(capture_output), "%s", "iq_once.cs16");
        std::snprintf(record_output, sizeof(record_output), "%s", "iq_record.cs16");
    }
};

rx_debug_stats sample_rx_debug_stats(const t510_ai::t510_ai_dpdk_device& device);
void refresh_mode_debug(gui_state::mode_debug* debug, const t510_ai::t510_ai_dpdk_device& device);

bool parse_iq_frame_meta(
    const uint8_t* iq_payload,
    std::size_t iq_payload_len,
    uint64_t seq,
    iq_frame_meta* meta_out,
    std::string* error_out);
bool parse_iq_frame_meta(
    const std::vector<uint8_t>& iq_payload,
    uint64_t seq,
    iq_frame_meta* meta_out,
    std::string* error_out);
std::string format_continuity_warning(const continuity_stats& stats);

double duration_ms(
    const std::chrono::steady_clock::time_point& start,
    const std::chrono::steady_clock::time_point& end);
std::size_t drain_pending_packets(t510_ai::t510_ai_dpdk_device& device, std::size_t max_packets = 2048u);
std::string format_quiesce_summary(const quiesce_result& result);
drain_result drain_until_idle(
    t510_ai::t510_ai_dpdk_device& device,
    std::chrono::milliseconds idle_time = stream_stop_idle_time,
    std::size_t hard_limit = stream_stop_drain_limit);
quiesce_result quiesce_rx_path(
    t510_ai::t510_ai_dpdk_device* device,
    const t510_ai::t510_ai_impl::sptr& impl,
    std::size_t rounds = 2u);
void append_frame_samples_for_display(
    std::vector<t510_ai::t510_ai_iq_sample>& out,
    const t510_ai::t510_ai_iq_frame& frame);
std::vector<std::complex<float>> frame_to_complex_ch0(const t510_ai::t510_ai_iq_frame& frame);
std::vector<std::complex<float>> frame_to_complex_ch1(const t510_ai::t510_ai_iq_frame& frame);
std::size_t write_frame_as_raw_cs16(
    std::ofstream& output,
    const t510_ai::t510_ai_iq_frame& frame,
    std::size_t remaining_bytes);
std::vector<float> compute_spectrum_db(
    const std::vector<std::complex<float>>& iq,
    std::size_t fft_size);
void rebuild_waterfall_from_iq(
    waterfall_history& waterfall,
    const std::vector<std::complex<float>>& iq,
    std::size_t fft_size);
std::vector<float> resample_curve(const std::vector<float>& in, std::size_t bins);
std::vector<float> to_plot_i(const std::vector<std::complex<float>>& iq);
std::vector<float> to_plot_q(const std::vector<std::complex<float>>& iq);
std::string trim_float_string(std::string text);

capture_result run_single_capture(
    t510_ai::t510_ai_dpdk_device& device,
    t510_ai::t510_ai_impl::sptr impl,
    const std::string& output_path,
    uint32_t total_bytes,
    uint32_t packet_bytes,
    gui_state* state,
    const std::atomic<bool>* stop_requested = nullptr);

class stream_worker
{
public:
    void start(
        t510_ai::t510_ai_dpdk_device* device,
        t510_ai::t510_ai_impl::sptr impl,
        gui_state* state,
        uint32_t chunk_bytes,
        uint32_t packet_bytes,
        uint32_t fft_size);
    void stop(
        t510_ai::t510_ai_dpdk_device* device,
        t510_ai::t510_ai_impl::sptr impl,
        gui_state* state);
    ~stream_worker() = default;

private:
    std::atomic<bool> _stop_requested{false};
    std::thread _thread;
};

class record_worker
{
public:
    void start(
        t510_ai::t510_ai_dpdk_device* device,
        t510_ai::t510_ai_impl::sptr impl,
        gui_state* state,
        const std::string& output_path,
        uint32_t chunk_bytes,
        uint32_t packet_bytes);
    void stop(
        t510_ai::t510_ai_dpdk_device* device,
        t510_ai::t510_ai_impl::sptr impl,
        gui_state* state);
    ~record_worker() = default;

private:
    std::atomic<bool> _stop_requested{false};
    std::atomic<bool> _abort_pending{false};
    std::thread _thread;
};

class drain_worker
{
public:
    void start(
        t510_ai::t510_ai_dpdk_device* device,
        t510_ai::t510_ai_impl::sptr impl,
        gui_state* state,
        uint32_t chunk_bytes,
        uint32_t packet_bytes);
    void stop(
        t510_ai::t510_ai_dpdk_device* device,
        t510_ai::t510_ai_impl::sptr impl,
        gui_state* state);
    ~drain_worker() = default;

private:
    std::atomic<bool> _stop_requested{false};
    std::thread _thread;
};

void apply_cyberether_style();
void draw_time_trace(const char* label, const std::vector<float>& data, float height);
void draw_spectrum_canvas(
    const char* title,
    const std::vector<float>& spectrum,
    spectrum_trace_state& trace_state,
    float height,
    bool advance_trace,
    uint64_t center_freq_hz,
    uint64_t sample_rate_hz,
    float& top_dbfs,
    float& bottom_dbfs);
void draw_waterfall_section(
    const char* title,
    const waterfall_history& waterfall,
    uint64_t center_freq_hz,
    uint64_t sample_rate_hz);

} // namespace t510_ai_gui
