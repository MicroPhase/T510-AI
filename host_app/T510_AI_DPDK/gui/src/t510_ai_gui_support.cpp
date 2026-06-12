#include "t510_ai_gui_app.hpp"

#include "sdr/core/dpdk_zero_copy.hpp"

#include <limits>

namespace t510_ai_gui {

std::atomic<bool> g_shutdown_requested{false};

extern "C" void t510_gui_signal_handler(int)
{
    g_shutdown_requested.store(true);
}

static uint32_t read_be32_local(const uint8_t* p)
{
    return (static_cast<uint32_t>(p[0]) << 24) | (static_cast<uint32_t>(p[1]) << 16)
           | (static_cast<uint32_t>(p[2]) << 8) | static_cast<uint32_t>(p[3]);
}

static uint32_t read_le32_local(const uint8_t* p)
{
    return (static_cast<uint32_t>(p[3]) << 24) | (static_cast<uint32_t>(p[2]) << 16)
           | (static_cast<uint32_t>(p[1]) << 8) | static_cast<uint32_t>(p[0]);
}

static uint16_t read_be16_local(const uint8_t* p)
{
    return static_cast<uint16_t>((static_cast<uint16_t>(p[0]) << 8) | static_cast<uint16_t>(p[1]));
}

static uint16_t read_le16_local(const uint8_t* p)
{
    return static_cast<uint16_t>((static_cast<uint16_t>(p[1]) << 8) | static_cast<uint16_t>(p[0]));
}

static uint64_t read_be64_local(const uint8_t* p)
{
    return (static_cast<uint64_t>(p[0]) << 56) | (static_cast<uint64_t>(p[1]) << 48)
           | (static_cast<uint64_t>(p[2]) << 40) | (static_cast<uint64_t>(p[3]) << 32)
           | (static_cast<uint64_t>(p[4]) << 24) | (static_cast<uint64_t>(p[5]) << 16)
           | (static_cast<uint64_t>(p[6]) << 8) | static_cast<uint64_t>(p[7]);
}

static uint64_t read_le64_local(const uint8_t* p)
{
    return (static_cast<uint64_t>(p[7]) << 56) | (static_cast<uint64_t>(p[6]) << 48)
           | (static_cast<uint64_t>(p[5]) << 40) | (static_cast<uint64_t>(p[4]) << 32)
           | (static_cast<uint64_t>(p[3]) << 24) | (static_cast<uint64_t>(p[2]) << 16)
           | (static_cast<uint64_t>(p[1]) << 8) | static_cast<uint64_t>(p[0]);
}

bool parse_iq_frame_meta(
    const uint8_t* iq_payload, std::size_t iq_payload_len, uint64_t seq, iq_frame_meta* meta_out,
    std::string* error_out)
{
    constexpr uint32_t iq_magic = 0x54353151u;
    constexpr uint8_t iq_version = 1u;
    constexpr std::size_t iq_header_bytes = 16u;

    if (!meta_out) {
        if (error_out) {
            *error_out = "meta_out is null";
        }
        return false;
    }
    if (!iq_payload || iq_payload_len < iq_header_bytes) {
        if (error_out) {
            *error_out = "iq payload shorter than 16-byte header";
        }
        return false;
    }

    iq_frame_meta meta;
    const bool payload_little_endian =
        (read_be32_local(iq_payload) == iq_magic) ? false : (read_le32_local(iq_payload + 4) == iq_magic);
    if (!payload_little_endian && read_be32_local(iq_payload) != iq_magic) {
        if (error_out) {
            *error_out = "iq payload magic mismatch";
        }
        return false;
    }

    if (payload_little_endian) {
        if (iq_payload[3] != iq_version) {
            if (error_out) {
                *error_out = "iq payload version mismatch";
            }
            return false;
        }
        meta.channel_enable = iq_payload[2];
        meta.sample_bytes = read_le16_local(iq_payload);
        meta.first_vita_time = read_le64_local(iq_payload + 8);
    } else {
        if (iq_payload[4] != iq_version) {
            if (error_out) {
                *error_out = "iq payload version mismatch";
            }
            return false;
        }
        meta.channel_enable = iq_payload[5];
        meta.sample_bytes = read_be16_local(iq_payload + 6);
        meta.first_vita_time = read_be64_local(iq_payload + 8);
    }

    if (iq_payload_len != iq_header_bytes + meta.sample_bytes) {
        if (error_out) {
            *error_out = "iq payload byte count does not match header";
        }
        return false;
    }
    if ((meta.sample_bytes % 8u) != 0u) {
        if (error_out) {
            *error_out = "sample_bytes is not 8-byte aligned";
        }
        return false;
    }

    const uint64_t packed_words = meta.sample_bytes / 8u;
    meta.sample_count = ((meta.channel_enable & 0x2u) != 0u) ? packed_words : (packed_words * 2u);
    meta.seq = seq;
    *meta_out = meta;
    return true;
}

bool parse_iq_frame_meta(
    const std::vector<uint8_t>& iq_payload, uint64_t seq, iq_frame_meta* meta_out, std::string* error_out)
{
    return parse_iq_frame_meta(iq_payload.data(), iq_payload.size(), seq, meta_out, error_out);
}

std::string format_continuity_warning(const continuity_stats& stats)
{
    std::ostringstream oss;
    bool first = true;

    if (stats.seq_gap_events != 0u) {
        oss << "seq gap";
        if (stats.seq_first_actual || stats.seq_first_expected) {
            oss << " expected=" << stats.seq_first_expected << " actual=" << stats.seq_first_actual;
        }
        oss << " events=" << stats.seq_gap_events << " total=" << stats.seq_gap_total;
        first = false;
    }

    if (stats.vita_gap_events != 0u) {
        if (!first) {
            oss << "; ";
        }
        oss << "vita gap";
        if (stats.vita_first_actual || stats.vita_first_expected) {
            oss << " expected=" << stats.vita_first_expected << " actual=" << stats.vita_first_actual;
        }
        oss << " events=" << stats.vita_gap_events << " total=" << stats.vita_gap_total;
        first = false;
    }

    if (!stats.channel_enable_stable) {
        if (!first) {
            oss << "; ";
        }
        oss << "channel_enable changed";
    }

    return first ? std::string{} : oss.str();
}

double duration_ms(
    const std::chrono::steady_clock::time_point& start,
    const std::chrono::steady_clock::time_point& end)
{
    return std::chrono::duration_cast<std::chrono::duration<double, std::milli>>(end - start).count();
}

std::size_t drain_pending_packets(t510_ai::t510_ai_dpdk_device& device, std::size_t max_packets)
{
    std::vector<uint8_t> packet;
    std::size_t drained = 0;
    while (drained < max_packets && device.recv_packet(packet, 0.01)) {
        drained++;
    }
    return drained;
}

std::string format_quiesce_summary(const quiesce_result& result)
{
    std::ostringstream oss;
    oss << "quiesce drained=" << result.drained_total << " (flush=" << result.flush_total
        << ", drain=" << result.drain_total << ", hit_limit=" << result.hit_limit_count << ")";
    return oss.str();
}

drain_result drain_until_idle(
    t510_ai::t510_ai_dpdk_device& device,
    std::chrono::milliseconds idle_time,
    std::size_t hard_limit)
{
    std::vector<uint8_t> packet;
    drain_result result;
    auto last_packet = std::chrono::steady_clock::now();
    while (result.drained < hard_limit) {
        if (device.recv_packet(packet, 0.01)) {
            result.drained++;
            last_packet = std::chrono::steady_clock::now();
            continue;
        }
        if ((std::chrono::steady_clock::now() - last_packet) >= idle_time) {
            break;
        }
    }
    result.hit_limit = (result.drained >= hard_limit);
    return result;
}

quiesce_result quiesce_rx_path(
    t510_ai::t510_ai_dpdk_device* device,
    const t510_ai::t510_ai_impl::sptr& impl,
    std::size_t rounds)
{
    quiesce_result result;
    if (!device || !impl) {
        return result;
    }

    for (std::size_t round = 0; round < rounds; round++) {
        try {
            impl->stop_rx_stream();
        } catch (...) {
        }
        std::this_thread::sleep_for(stream_stop_settle_time);
        if (auto dpdk_xport = std::dynamic_pointer_cast<sdr::core::dpdk_zero_copy>(device->get_data_xport())) {
            const std::size_t flushed = dpdk_xport->flush_rx();
            result.flush_total += flushed;
            result.drained_total += flushed;
        }
        for (std::size_t pass = 0; pass < 8u; pass++) {
            const drain_result res = drain_until_idle(*device);
            result.drain_total += res.drained;
            result.drained_total += res.drained;
            if (!res.hit_limit) {
                break;
            }
            result.hit_limit_count++;
            std::this_thread::sleep_for(std::chrono::milliseconds(10));
        }
        if (auto dpdk_xport = std::dynamic_pointer_cast<sdr::core::dpdk_zero_copy>(device->get_data_xport())) {
            const std::size_t flushed = dpdk_xport->flush_rx();
            result.flush_total += flushed;
            result.drained_total += flushed;
        }
    }
    if (result.drained_total != 0u || result.hit_limit_count != 0u) {
        const std::string summary = format_quiesce_summary(result);
        std::fprintf(stderr, "[t510_ai_gui] %s\n", summary.c_str());
    }
    return result;
}

void append_frame_samples_for_display(
    std::vector<t510_ai::t510_ai_iq_sample>& out, const t510_ai::t510_ai_iq_frame& frame)
{
    if (frame.samples.empty()) {
        return;
    }

    const std::size_t take = std::min(frame.samples.size(), stream_display_samples_per_packet);
    out.reserve(std::min(stream_display_buffer_limit, out.size() + take));

    if (take >= frame.samples.size()) {
        out.insert(out.end(), frame.samples.begin(), frame.samples.end());
    } else {
        for (std::size_t i = 0; i < take; i++) {
            const std::size_t src =
                (i * (frame.samples.size() - 1u)) / std::max<std::size_t>(1u, take - 1u);
            out.push_back(frame.samples[src]);
        }
    }

    if (out.size() > stream_display_buffer_limit) {
        out.erase(out.begin(), out.begin() + static_cast<std::ptrdiff_t>(out.size() - stream_display_buffer_limit));
    }
}

std::vector<std::complex<float>> frame_to_complex_ch0(const t510_ai::t510_ai_iq_frame& frame)
{
    std::vector<std::complex<float>> out;
    out.reserve(frame.samples.size());
    for (const auto& sample : frame.samples) {
        out.emplace_back(static_cast<float>(sample.ch0_i), static_cast<float>(sample.ch0_q));
    }
    return out;
}

std::vector<std::complex<float>> frame_to_complex_ch1(const t510_ai::t510_ai_iq_frame& frame)
{
    std::vector<std::complex<float>> out;
    out.reserve(frame.samples.size());
    for (const auto& sample : frame.samples) {
        if (sample.ch1_valid) {
            out.emplace_back(static_cast<float>(sample.ch1_i), static_cast<float>(sample.ch1_q));
        }
    }
    return out;
}

static void write_le16(std::ofstream& output, int16_t value)
{
    const char bytes[2] = {
        static_cast<char>(value & 0xff),
        static_cast<char>((static_cast<uint16_t>(value) >> 8) & 0xff),
    };
    output.write(bytes, sizeof(bytes));
}

std::size_t write_frame_as_raw_cs16(
    std::ofstream& output, const t510_ai::t510_ai_iq_frame& frame, std::size_t remaining_bytes)
{
    const bool dual_channel = (frame.channel_enable & 0x2u) != 0u;
    const std::size_t bytes_per_sample = dual_channel ? 8u : 4u;
    std::size_t bytes_written = 0;

    for (const auto& sample : frame.samples) {
        if (bytes_written + bytes_per_sample > remaining_bytes) {
            break;
        }
        write_le16(output, sample.ch0_i);
        write_le16(output, sample.ch0_q);
        if (dual_channel) {
            write_le16(output, sample.ch1_i);
            write_le16(output, sample.ch1_q);
        }
        bytes_written += bytes_per_sample;
    }

    return bytes_written;
}

static std::size_t next_power_of_two(std::size_t value)
{
    std::size_t result = 1;
    while (result < value) {
        result <<= 1u;
    }
    return result;
}

static void fft_inplace(std::vector<std::complex<float>>& data)
{
    const std::size_t n = data.size();
    std::size_t j = 0;
    for (std::size_t i = 1; i < n; i++) {
        std::size_t bit = n >> 1u;
        while ((j & bit) != 0u) {
            j ^= bit;
            bit >>= 1u;
        }
        j ^= bit;
        if (i < j) {
            std::swap(data[i], data[j]);
        }
    }

    for (std::size_t len = 2; len <= n; len <<= 1u) {
        const float angle = -2.0f * 3.14159265358979323846f / static_cast<float>(len);
        const std::complex<float> wlen(std::cos(angle), std::sin(angle));
        for (std::size_t i = 0; i < n; i += len) {
            std::complex<float> w(1.0f, 0.0f);
            for (std::size_t k = 0; k < len / 2u; k++) {
                const std::complex<float> u = data[i + k];
                const std::complex<float> v = data[i + k + len / 2u] * w;
                data[i + k] = u + v;
                data[i + k + len / 2u] = u - v;
                w *= wlen;
            }
        }
    }
}

std::vector<float> compute_spectrum_db(const std::vector<std::complex<float>>& iq, std::size_t fft_size)
{
    if (iq.empty()) {
        return {};
    }

    const std::size_t n = next_power_of_two(std::max<std::size_t>(8u, fft_size));
    std::vector<std::complex<float>> fft_buf(n, {0.0f, 0.0f});
    const std::size_t copy_count = std::min(n, iq.size());
    const std::size_t offset = iq.size() - copy_count;
    constexpr float full_scale = 8192.0f;
    float window_sum = 0.0f;

    for (std::size_t i = 0; i < copy_count; i++) {
        float win = 1.0f;
        if (copy_count > 1u) {
            win = 0.5f - 0.5f * std::cos(
                2.0f * 3.14159265358979323846f * static_cast<float>(i) / static_cast<float>(copy_count - 1u));
        }
        window_sum += win;
        fft_buf[i] = (iq[offset + i] / full_scale) * win;
    }

    fft_inplace(fft_buf);

    std::vector<float> out(n, -160.0f);
    for (std::size_t i = 0; i < n; i++) {
        const std::size_t shifted = (i + n / 2u) % n;
        const float mag = std::abs(fft_buf[shifted]) / std::max(window_sum, 1e-12f);
        out[i] = 20.0f * std::log10(mag + 1e-12f);
    }
    return out;
}

void rebuild_waterfall_from_iq(
    waterfall_history& waterfall, const std::vector<std::complex<float>>& iq, std::size_t fft_size)
{
    waterfall.clear();
    if (iq.empty()) {
        return;
    }

    const std::size_t n = next_power_of_two(std::max<std::size_t>(8u, fft_size));
    if (iq.size() < n) {
        waterfall.push(resample_curve(compute_spectrum_db(iq, fft_size), waterfall_bins));
        return;
    }

    const std::size_t max_start = iq.size() - n;
    const std::size_t base_hop = std::max<std::size_t>(n / 4u, 1u);
    const std::size_t natural_frames = (max_start / base_hop) + 1u;

    if (natural_frames <= waterfall_rows) {
        for (std::size_t start = 0; start <= max_start; start += base_hop) {
            std::vector<std::complex<float>> frame(
                iq.begin() + static_cast<std::ptrdiff_t>(start),
                iq.begin() + static_cast<std::ptrdiff_t>(start + n));
            waterfall.push(resample_curve(compute_spectrum_db(frame, fft_size), waterfall_bins));
        }
        return;
    }

    const std::size_t frames_to_emit = waterfall_rows;
    const double step = static_cast<double>(max_start) / static_cast<double>(frames_to_emit - 1u);
    for (std::size_t frame_idx = 0; frame_idx < frames_to_emit; frame_idx++) {
        const std::size_t start = std::min<std::size_t>(
            max_start, static_cast<std::size_t>(std::llround(step * static_cast<double>(frame_idx))));
        std::vector<std::complex<float>> frame(
            iq.begin() + static_cast<std::ptrdiff_t>(start),
            iq.begin() + static_cast<std::ptrdiff_t>(start + n));
        waterfall.push(resample_curve(compute_spectrum_db(frame, fft_size), waterfall_bins));
    }
}

std::vector<float> resample_curve(const std::vector<float>& in, std::size_t bins)
{
    if (in.empty() || bins == 0u) {
        return {};
    }
    std::vector<float> out(bins, in.front());
    for (std::size_t i = 0; i < bins; i++) {
        const float pos = (static_cast<float>(i) * static_cast<float>(in.size() - 1u))
                          / static_cast<float>(std::max<std::size_t>(1u, bins - 1u));
        const std::size_t left = static_cast<std::size_t>(pos);
        const std::size_t right = std::min(left + 1u, in.size() - 1u);
        const float frac = pos - static_cast<float>(left);
        out[i] = in[left] * (1.0f - frac) + in[right] * frac;
    }
    return out;
}

static std::vector<float> reduce_trace_for_plot(const std::vector<float>& in, std::size_t limit)
{
    if (in.size() <= limit) {
        return in;
    }
    return resample_curve(in, limit);
}

std::vector<float> to_plot_i(const std::vector<std::complex<float>>& iq)
{
    std::vector<float> out;
    out.reserve(iq.size());
    for (const auto& v : iq) {
        out.push_back(v.real());
    }
    return out;
}

std::vector<float> to_plot_q(const std::vector<std::complex<float>>& iq)
{
    std::vector<float> out;
    out.reserve(iq.size());
    for (const auto& v : iq) {
        out.push_back(v.imag());
    }
    return out;
}

static float curve_to_y(float value, float min_v, float max_v, float y0, float y1)
{
    const float t = std::clamp((value - min_v) / std::max(1e-6f, max_v - min_v), 0.0f, 1.0f);
    return y1 - t * (y1 - y0);
}

std::string trim_float_string(std::string text)
{
    const auto dot = text.find('.');
    if (dot == std::string::npos) {
        return text;
    }
    while (!text.empty() && text.back() == '0') {
        text.pop_back();
    }
    if (!text.empty() && text.back() == '.') {
        text.pop_back();
    }
    return text;
}

static std::string format_frequency_label(double hz)
{
    const double abs_hz = std::fabs(hz);
    char buffer[64];
    if (abs_hz >= 1.0e9) {
        std::snprintf(buffer, sizeof(buffer), "%.3f GHz", hz / 1.0e9);
        return trim_float_string(buffer);
    }
    if (abs_hz >= 1.0e6) {
        std::snprintf(buffer, sizeof(buffer), "%.3f MHz", hz / 1.0e6);
        return trim_float_string(buffer);
    }
    if (abs_hz >= 1.0e3) {
        std::snprintf(buffer, sizeof(buffer), "%.3f kHz", hz / 1.0e3);
        return trim_float_string(buffer);
    }
    std::snprintf(buffer, sizeof(buffer), "%.0f Hz", hz);
    return buffer;
}

static void draw_frequency_axis(
    ImDrawList* draw_list, const ImVec2& min, const ImVec2& max, float y_axis_bottom, uint64_t center_freq_hz,
    uint64_t sample_rate_hz)
{
    constexpr int tick_count = 6;
    const ImU32 axis_grid = IM_COL32(34, 55, 72, 150);
    const ImU32 axis_text = IM_COL32(154, 174, 191, 220);
    const double half_span_hz = static_cast<double>(sample_rate_hz) * 0.5;
    const double start_hz = static_cast<double>(center_freq_hz) - half_span_hz;
    const double stop_hz = static_cast<double>(center_freq_hz) + half_span_hz;
    const float axis_y = max.y - 18.0f;

    draw_list->AddLine(ImVec2(min.x, axis_y), ImVec2(max.x, axis_y), axis_grid, 1.0f);
    for (int i = 0; i <= tick_count; i++) {
        const float t = static_cast<float>(i) / static_cast<float>(tick_count);
        const float x = min.x + (max.x - min.x) * t;
        const double freq_hz = start_hz + (stop_hz - start_hz) * static_cast<double>(t);
        draw_list->AddLine(ImVec2(x, min.y), ImVec2(x, y_axis_bottom), axis_grid, 1.0f);
        draw_list->AddLine(ImVec2(x, axis_y), ImVec2(x, axis_y + 4.0f), axis_text, 1.0f);
        const std::string label = format_frequency_label(freq_hz);
        const ImVec2 text_size = ImGui::CalcTextSize(label.c_str());
        const float clamped_x = std::clamp(x - text_size.x * 0.5f, min.x + 4.0f, max.x - text_size.x - 4.0f);
        draw_list->AddText(ImVec2(clamped_x, axis_y + 6.0f), axis_text, label.c_str());
    }
}

static void draw_db_range_slider(
    const char* id, ImDrawList* draw_list, const ImVec2& min, const ImVec2& max, float y0, float y1, float& top_dbfs,
    float& bottom_dbfs)
{
    const float lane_w = 14.0f;
    const float handle_h = 8.0f;
    const float lane_x0 = max.x - 18.0f;
    const float lane_x1 = lane_x0 + lane_w;
    const ImVec2 lane_min(lane_x0, y0);
    const ImVec2 lane_max(lane_x1, y1);
    const float top_y = curve_to_y(top_dbfs, spectrum_slider_min_dbfs, spectrum_slider_max_dbfs, y0, y1);
    const float bottom_y = curve_to_y(bottom_dbfs, spectrum_slider_min_dbfs, spectrum_slider_max_dbfs, y0, y1);

    draw_list->AddRectFilled(lane_min, lane_max, IM_COL32(10, 18, 28, 230), 4.0f);
    draw_list->AddRect(lane_min, lane_max, IM_COL32(48, 78, 100, 220), 4.0f);
    draw_list->AddRectFilled(
        ImVec2(lane_x0 + 2.0f, top_y), ImVec2(lane_x1 - 2.0f, bottom_y), IM_COL32(44, 130, 208, 72), 3.0f);

    const ImVec2 top_handle_min(lane_x0 - 2.0f, top_y - handle_h * 0.5f);
    const ImVec2 top_handle_max(lane_x1 + 2.0f, top_y + handle_h * 0.5f);
    const ImVec2 bottom_handle_min(lane_x0 - 2.0f, bottom_y - handle_h * 0.5f);
    const ImVec2 bottom_handle_max(lane_x1 + 2.0f, bottom_y + handle_h * 0.5f);
    draw_list->AddRectFilled(top_handle_min, top_handle_max, IM_COL32(198, 238, 255, 245), 3.0f);
    draw_list->AddRectFilled(bottom_handle_min, bottom_handle_max, IM_COL32(198, 238, 255, 245), 3.0f);
    const ImVec2 mouse = ImGui::GetIO().MousePos;
    const ImVec2 hit_min(lane_x0 - 10.0f, y0);
    const ImVec2 hit_max(lane_x1 + 10.0f, y1);
    const bool hovered = ImGui::IsMouseHoveringRect(hit_min, hit_max, true);
    const ImGuiID slider_id = ImGui::GetID(id);
    static ImGuiID active_slider = 0;
    static int active_handle = 0;

    if (hovered && ImGui::IsMouseClicked(ImGuiMouseButton_Left)) {
        const float dist_top = std::fabs(mouse.y - top_y);
        const float dist_bottom = std::fabs(mouse.y - bottom_y);
        active_slider = slider_id;
        active_handle = (dist_top <= dist_bottom) ? 1 : 2;
    }
    if (active_slider == slider_id && ImGui::IsMouseDown(ImGuiMouseButton_Left)) {
        const float t = std::clamp((y1 - mouse.y) / std::max(1.0f, y1 - y0), 0.0f, 1.0f);
        const float value = spectrum_slider_min_dbfs + t * (spectrum_slider_max_dbfs - spectrum_slider_min_dbfs);
        if (active_handle == 1) {
            top_dbfs = std::clamp(value, bottom_dbfs + 10.0f, spectrum_slider_max_dbfs);
        } else if (active_handle == 2) {
            bottom_dbfs = std::clamp(value, spectrum_slider_min_dbfs, top_dbfs - 10.0f);
        }
    }
    if (!ImGui::IsMouseDown(ImGuiMouseButton_Left) && active_slider == slider_id) {
        active_slider = 0;
        active_handle = 0;
    }

    if (hovered || active_slider == slider_id) {
        draw_list->AddRect(hit_min, hit_max, IM_COL32(110, 170, 215, 110), 4.0f);
    }
}

static std::pair<float, float> auto_trace_bounds(const std::vector<float>& data)
{
    if (data.empty()) {
        return {-1.0f, 1.0f};
    }

    std::vector<float> magnitudes;
    magnitudes.reserve(data.size());
    for (float v : data) {
        magnitudes.push_back(std::fabs(v));
    }
    std::sort(magnitudes.begin(), magnitudes.end());
    const std::size_t idx = std::min(magnitudes.size() - 1u, (magnitudes.size() * 95u) / 100u);
    float bound = magnitudes[idx] * 1.15f;
    if (bound < 1.0f) {
        bound = 1.0f;
    }
    return {-bound, bound};
}

static void draw_grid(ImDrawList* draw_list, const ImVec2& min, const ImVec2& max, int vertical, int horizontal)
{
    const ImU32 grid = IM_COL32(32, 56, 74, 180);
    for (int i = 1; i < vertical; i++) {
        const float x = min.x + (max.x - min.x) * static_cast<float>(i) / static_cast<float>(vertical);
        draw_list->AddLine(ImVec2(x, min.y), ImVec2(x, max.y), grid, 1.0f);
    }
    for (int i = 1; i < horizontal; i++) {
        const float y = min.y + (max.y - min.y) * static_cast<float>(i) / static_cast<float>(horizontal);
        draw_list->AddLine(ImVec2(min.x, y), ImVec2(max.x, y), grid, 1.0f);
    }
}

void draw_time_trace(const char* label, const std::vector<float>& data, float height)
{
    ImGui::TextUnformatted(label);
    const ImVec2 size(ImGui::GetContentRegionAvail().x, height);
    ImGui::InvisibleButton(label, size);
    const ImVec2 min = ImGui::GetItemRectMin();
    const ImVec2 max = ImGui::GetItemRectMax();
    ImDrawList* draw_list = ImGui::GetWindowDrawList();
    draw_list->AddRectFilled(min, max, IM_COL32(12, 20, 29, 255), 8.0f);
    draw_list->AddRect(min, max, IM_COL32(42, 70, 91, 255), 8.0f);
    draw_grid(draw_list, min, max, 8, 4);
    const std::vector<float> plot_data = reduce_trace_for_plot(data, time_trace_plot_limit);
    const auto [min_v, max_v] = auto_trace_bounds(plot_data);
    const float mid_y = curve_to_y(0.0f, min_v, max_v, min.y + 6.0f, max.y - 6.0f);
    draw_list->AddLine(ImVec2(min.x, mid_y), ImVec2(max.x, mid_y), IM_COL32(66, 103, 128, 185), 1.0f);

    if (plot_data.empty()) {
        return;
    }

    const float inner_y0 = min.y + 6.0f;
    const float inner_y1 = max.y - 6.0f;
    const std::size_t columns = std::max<std::size_t>(
        1u, std::min<std::size_t>(plot_data.size(), static_cast<std::size_t>(std::max(1.0f, max.x - min.x))));
    for (std::size_t col = 0; col < columns; col++) {
        const std::size_t start = (col * plot_data.size()) / columns;
        const std::size_t stop = std::max(start + 1u, ((col + 1u) * plot_data.size()) / columns);
        float local_min = plot_data[start];
        float local_max = plot_data[start];
        for (std::size_t i = start + 1u; i < stop; i++) {
            local_min = std::min(local_min, plot_data[i]);
            local_max = std::max(local_max, plot_data[i]);
        }
        const float x = min.x + (max.x - min.x) * (static_cast<float>(col) + 0.5f) / static_cast<float>(columns);
        const float y_min = curve_to_y(local_min, min_v, max_v, inner_y0, inner_y1);
        const float y_max = curve_to_y(local_max, min_v, max_v, inner_y0, inner_y1);
        draw_list->AddLine(ImVec2(x, y_min), ImVec2(x, y_max), IM_COL32(49, 176, 255, 26), 3.5f);
        draw_list->AddLine(ImVec2(x, y_min), ImVec2(x, y_max), IM_COL32(49, 176, 255, 56), 1.8f);
        draw_list->AddLine(ImVec2(x, y_min), ImVec2(x, y_max), IM_COL32(156, 236, 255, 230), 1.0f);
    }
}

void draw_spectrum_canvas(
    const char* title, const std::vector<float>& spectrum, spectrum_trace_state& trace_state, float height,
    bool advance_trace, uint64_t center_freq_hz, uint64_t sample_rate_hz, float& top_dbfs, float& bottom_dbfs)
{
    ImGui::TextUnformatted(title);
    const ImVec2 size(ImGui::GetContentRegionAvail().x, height);
    ImGui::InvisibleButton(title, size);
    const ImVec2 min = ImGui::GetItemRectMin();
    const ImVec2 max = ImGui::GetItemRectMax();
    ImDrawList* draw_list = ImGui::GetWindowDrawList();
    draw_list->AddRectFilledMultiColor(
        min,
        max,
        IM_COL32(5, 10, 19, 255),
        IM_COL32(5, 10, 19, 255),
        IM_COL32(11, 20, 33, 255),
        IM_COL32(11, 20, 33, 255));
    draw_list->AddRect(min, max, IM_COL32(42, 70, 91, 255), 8.0f);
    draw_grid(draw_list, min, max, 10, 6);

    if (spectrum.empty()) {
        draw_list->AddText(ImVec2(min.x + 10.0f, min.y + 10.0f), IM_COL32(155, 175, 190, 255), "No spectrum");
        return;
    }

    if (advance_trace || trace_state.current.empty()) {
        trace_state.update(spectrum);
    }
    const float y0 = min.y + 8.0f;
    const float y1 = max.y - 30.0f;
    const float ceil_db = std::max(top_dbfs, bottom_dbfs + 10.0f);
    const float floor_db = std::min(bottom_dbfs, ceil_db - 10.0f);
    const float plot_x1 = max.x - 24.0f;

    std::vector<ImVec2> current_pts;
    std::vector<ImVec2> glow_pts;
    std::vector<ImVec2> peak_pts;
    current_pts.reserve(trace_state.current.size());
    glow_pts.reserve(trace_state.glow.size());
    peak_pts.reserve(trace_state.peak.size());

    for (std::size_t i = 0; i < trace_state.current.size(); i++) {
        const float x = min.x + (plot_x1 - min.x) * static_cast<float>(i)
                        / static_cast<float>(std::max<std::size_t>(1u, trace_state.current.size() - 1u));
        current_pts.emplace_back(x, curve_to_y(trace_state.current[i], floor_db, ceil_db, y0, y1));
        glow_pts.emplace_back(x, curve_to_y(trace_state.glow[i], floor_db, ceil_db, y0, y1));
        peak_pts.emplace_back(x, curve_to_y(trace_state.peak[i], floor_db, ceil_db, y0, y1));
    }

    const std::size_t history_count = trace_state.history.size();
    for (std::size_t h = 0; h < history_count; h++) {
        const auto& hist = trace_state.history[h];
        if (hist.size() != trace_state.current.size()) {
            continue;
        }
        std::vector<ImVec2> hist_pts;
        hist_pts.reserve(hist.size());
        for (std::size_t i = 0; i < hist.size(); i++) {
            const float x = min.x + (plot_x1 - min.x) * static_cast<float>(i)
                            / static_cast<float>(std::max<std::size_t>(1u, hist.size() - 1u));
            hist_pts.emplace_back(x, curve_to_y(hist[i], floor_db, ceil_db, y0, y1));
        }
        const float t = static_cast<float>(h + 1u) / static_cast<float>(history_count);
        const int alpha = static_cast<int>(4.0f + 40.0f * t * t);
        const float thickness = 0.7f + 0.5f * t;
        draw_list->AddPolyline(
            hist_pts.data(), static_cast<int>(hist_pts.size()), IM_COL32(52, 170, 255, alpha), 0, thickness);
    }

    for (float thick : {4.0f, 2.0f}) {
        const int alpha = (thick > 3.0f) ? 12 : 28;
        draw_list->AddPolyline(
            glow_pts.data(), static_cast<int>(glow_pts.size()), IM_COL32(72, 199, 255, alpha), 0, thick);
    }
    draw_list->AddPolyline(peak_pts.data(), static_cast<int>(peak_pts.size()), IM_COL32(255, 170, 78, 128), 0, 0.95f);
    draw_list->AddPolyline(
        current_pts.data(), static_cast<int>(current_pts.size()), IM_COL32(208, 248, 255, 255), 0, 1.4f);
    draw_list->AddPolyline(
        current_pts.data(), static_cast<int>(current_pts.size()), IM_COL32(76, 205, 255, 220), 0, 0.8f);

    const float step = spectrum_tick_step_db;
    const float first_tick = std::floor(floor_db / step) * step;
    for (float tick = first_tick; tick <= ceil_db + 0.1f; tick += step) {
        if (tick < floor_db - 0.1f) {
            continue;
        }
        const float y = curve_to_y(tick, floor_db, ceil_db, y0, y1);
        draw_list->AddLine(ImVec2(min.x, y), ImVec2(plot_x1, y), IM_COL32(46, 74, 96, 110), 1.0f);
        char label[32];
        std::snprintf(label, sizeof(label), "%.0f dBFS", tick);
        draw_list->AddText(ImVec2(min.x + 10.0f, y - 8.0f), IM_COL32(154, 174, 191, 220), label);
    }

    draw_frequency_axis(draw_list, min, ImVec2(plot_x1, max.y), y1, center_freq_hz, sample_rate_hz);
    draw_db_range_slider(title, draw_list, min, max, y0, y1, top_dbfs, bottom_dbfs);
}

void apply_cyberether_style()
{
    ImGuiStyle& style = ImGui::GetStyle();
    style.WindowRounding = 10.0f;
    style.ChildRounding = 8.0f;
    style.FrameRounding = 6.0f;
    style.PopupRounding = 6.0f;
    style.GrabRounding = 6.0f;
    style.ScrollbarRounding = 6.0f;
    style.TabRounding = 6.0f;
    style.WindowPadding = ImVec2(14.0f, 12.0f);
    style.FramePadding = ImVec2(10.0f, 8.0f);
    style.ItemSpacing = ImVec2(10.0f, 10.0f);
    style.ItemInnerSpacing = ImVec2(8.0f, 6.0f);

    ImVec4* colors = style.Colors;
    colors[ImGuiCol_WindowBg] = ImVec4(0.05f, 0.08f, 0.11f, 1.0f);
    colors[ImGuiCol_ChildBg] = ImVec4(0.07f, 0.11f, 0.15f, 1.0f);
    colors[ImGuiCol_PopupBg] = ImVec4(0.08f, 0.12f, 0.16f, 0.98f);
    colors[ImGuiCol_Border] = ImVec4(0.17f, 0.28f, 0.36f, 1.0f);
    colors[ImGuiCol_FrameBg] = ImVec4(0.10f, 0.16f, 0.22f, 1.0f);
    colors[ImGuiCol_FrameBgHovered] = ImVec4(0.14f, 0.23f, 0.31f, 1.0f);
    colors[ImGuiCol_FrameBgActive] = ImVec4(0.17f, 0.28f, 0.38f, 1.0f);
    colors[ImGuiCol_TitleBg] = ImVec4(0.06f, 0.09f, 0.13f, 1.0f);
    colors[ImGuiCol_TitleBgActive] = ImVec4(0.08f, 0.12f, 0.17f, 1.0f);
    colors[ImGuiCol_Button] = ImVec4(0.12f, 0.26f, 0.38f, 1.0f);
    colors[ImGuiCol_ButtonHovered] = ImVec4(0.17f, 0.36f, 0.51f, 1.0f);
    colors[ImGuiCol_ButtonActive] = ImVec4(0.13f, 0.42f, 0.60f, 1.0f);
    colors[ImGuiCol_Header] = ImVec4(0.10f, 0.20f, 0.28f, 1.0f);
    colors[ImGuiCol_HeaderHovered] = ImVec4(0.14f, 0.28f, 0.38f, 1.0f);
    colors[ImGuiCol_HeaderActive] = ImVec4(0.16f, 0.32f, 0.44f, 1.0f);
    colors[ImGuiCol_Separator] = ImVec4(0.17f, 0.28f, 0.36f, 1.0f);
    colors[ImGuiCol_Text] = ImVec4(0.86f, 0.92f, 0.95f, 1.0f);
    colors[ImGuiCol_TextDisabled] = ImVec4(0.52f, 0.61f, 0.67f, 1.0f);
    colors[ImGuiCol_PlotLines] = ImVec4(0.43f, 0.84f, 0.98f, 1.0f);
    colors[ImGuiCol_PlotHistogram] = ImVec4(0.23f, 0.77f, 0.71f, 1.0f);
}

static ImU32 waterfall_color(float level)
{
    const float x = std::clamp(level, 0.0f, 1.0f);
    static constexpr ImVec4 turbo_stops[] = {
        ImVec4(0.18995f, 0.07176f, 0.23217f, 1.0f),
        ImVec4(0.25107f, 0.25237f, 0.63374f, 1.0f),
        ImVec4(0.27628f, 0.47787f, 0.94918f, 1.0f),
        ImVec4(0.21291f, 0.65886f, 0.55171f, 1.0f),
        ImVec4(0.62601f, 0.85465f, 0.22335f, 1.0f),
        ImVec4(0.97323f, 0.74682f, 0.22536f, 1.0f),
        ImVec4(0.94137f, 0.35566f, 0.07031f, 1.0f)
    };

    const float scaled = x * static_cast<float>(std::size(turbo_stops) - 1u);
    const std::size_t idx =
        std::min<std::size_t>(std::size(turbo_stops) - 2u, static_cast<std::size_t>(scaled));
    const float t = scaled - static_cast<float>(idx);
    ImVec4 color;
    color.x = turbo_stops[idx].x + (turbo_stops[idx + 1u].x - turbo_stops[idx].x) * t;
    color.y = turbo_stops[idx].y + (turbo_stops[idx + 1u].y - turbo_stops[idx].y) * t;
    color.z = turbo_stops[idx].z + (turbo_stops[idx + 1u].z - turbo_stops[idx].z) * t;
    color.w = 1.0f;

    if (x < 0.08f) {
        color.x *= 0.55f;
        color.y *= 0.55f;
        color.z *= 0.65f;
    }
    return ImGui::ColorConvertFloat4ToU32(color);
}

void draw_waterfall_section(
    const char* title, const waterfall_history& waterfall, uint64_t center_freq_hz, uint64_t sample_rate_hz)
{
    ImGui::TextUnformatted(title);
    const ImVec2 size(ImGui::GetContentRegionAvail().x, 240.0f);
    ImGui::InvisibleButton(title, size);
    const ImVec2 min = ImGui::GetItemRectMin();
    const ImVec2 max = ImGui::GetItemRectMax();
    ImDrawList* draw_list = ImGui::GetWindowDrawList();
    draw_list->AddRectFilledMultiColor(
        min,
        max,
        IM_COL32(5, 8, 14, 255),
        IM_COL32(5, 8, 14, 255),
        IM_COL32(12, 18, 28, 255),
        IM_COL32(12, 18, 28, 255));
    draw_list->AddRect(min, max, IM_COL32(42, 70, 91, 255), 8.0f);

    if (waterfall.rows() == 0u || waterfall.bins() == 0u) {
        draw_list->AddText(
            ImVec2(min.x + 12.0f, min.y + 12.0f), IM_COL32(160, 180, 190, 255), "No spectrum history");
        return;
    }

    const float plot_bottom = max.y - 28.0f;
    const float row_h = (plot_bottom - min.y) / static_cast<float>(waterfall_rows);
    const float bin_w = (max.x - min.x) / static_cast<float>(waterfall.bins());
    for (std::size_t row = 0; row < waterfall.rows(); row++) {
        const auto& line = waterfall.row_from_newest(row);
        const float y0 = min.y + static_cast<float>(row) * row_h;
        const float y1 = y0 + row_h + 0.6f;
        for (std::size_t bin = 0; bin < waterfall.bins(); bin++) {
            const float x0 = min.x + static_cast<float>(bin) * bin_w;
            const float x1 = x0 + bin_w + 0.8f;
            draw_list->AddRectFilled(ImVec2(x0, y0), ImVec2(x1, y1), waterfall_color(line[bin]));
        }
    }

    draw_list->AddText(ImVec2(min.x + 10.0f, min.y + 8.0f), IM_COL32(122, 144, 166, 220), "New");
    if (waterfall.rows() > 0u) {
        const float used_bottom = min.y + static_cast<float>(waterfall.rows()) * row_h;
        draw_list->AddText(
            ImVec2(min.x + 10.0f, used_bottom - 18.0f), IM_COL32(122, 144, 166, 220), "Old");
    }
    draw_frequency_axis(draw_list, min, max, plot_bottom, center_freq_hz, sample_rate_hz);
}

} // namespace t510_ai_gui
