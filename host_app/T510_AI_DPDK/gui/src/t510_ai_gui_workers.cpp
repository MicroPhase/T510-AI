#include "t510_ai_gui_app.hpp"

#include <cstring>
#include <limits>

namespace t510_ai_gui {

namespace {

constexpr uint32_t stream_loop_capture_bytes = t510_ai::t510_ai_fpga_ctrl::default_capture_bytes;
constexpr double stoppable_capture_poll_timeout_sec = 0.2;

void refresh_stream_capture_views(gui_state* state, const capture_result& capture, uint32_t fft_size)
{
    if (!state) {
        return;
    }

    std::vector<float> ch0_spectrum_view;
    std::vector<float> ch1_spectrum_view;
    waterfall_history waterfall;

    if (!capture.ch0_iq.empty()) {
        ch0_spectrum_view = resample_curve(compute_spectrum_db(capture.ch0_iq, fft_size), spectrum_bins);
    }
    if (!capture.ch0_iq.empty()) {
        rebuild_waterfall_from_iq(waterfall, capture.ch0_iq, fft_size);
    }
    if (!capture.ch1_iq.empty()) {
        ch1_spectrum_view = resample_curve(compute_spectrum_db(capture.ch1_iq, fft_size), spectrum_bins);
    }

    {
        std::lock_guard<std::mutex> lock(state->mutex);
        state->live_ch0_spectrum = std::move(ch0_spectrum_view);
        state->live_ch1_spectrum = std::move(ch1_spectrum_view);
        state->live_waterfall = std::move(waterfall);
        state->spectral_source_single_capture = false;
        state->live_visual_generation++;
    }
}

} // namespace

rx_debug_stats sample_rx_debug_stats(const t510_ai::t510_ai_dpdk_device& device)
{
    rx_debug_stats stats;
    stats.dropped_packets = device.get_dropped_rx_packets();
    stats.ready_packets = device.get_ready_rx_packets();
    stats.slot_capacity = device.get_rx_slot_capacity();
    return stats;
}

void refresh_mode_debug(gui_state::mode_debug* debug, const t510_ai::t510_ai_dpdk_device& device)
{
    if (!debug) {
        return;
    }

    const rx_debug_stats rx_stats = sample_rx_debug_stats(device);
    debug->dpdk_drop_total = rx_stats.dropped_packets;
    debug->dpdk_drop_delta =
        (rx_stats.dropped_packets >= debug->dpdk_drop_base) ? (rx_stats.dropped_packets - debug->dpdk_drop_base) : 0u;
    debug->dpdk_ready_packets = rx_stats.ready_packets;
    debug->dpdk_slot_capacity = rx_stats.slot_capacity;
}

capture_result run_single_capture(
    t510_ai::t510_ai_dpdk_device& device,
    t510_ai::t510_ai_impl::sptr impl,
    const std::string& output_path,
    uint32_t total_bytes,
    uint32_t packet_bytes,
    gui_state* state,
    const std::atomic<bool>* stop_requested)
{
    capture_result result;
    const bool write_output = !output_path.empty();
    std::ofstream output;
    sample_ring local_ring(ring_capacity);
    std::size_t bytes_written = 0;
    bool got_first_packet = false;
    bool local_has_ch1 = false;
    gui_state::mode_debug local_debug;
    const auto total_start = std::chrono::steady_clock::now();
    auto recv_loop_start = total_start;

    if (write_output) {
        output.open(output_path, std::ios::binary | std::ios::trunc);
    }
    if (write_output && !output.is_open()) {
        throw std::runtime_error("failed to open output file: " + output_path);
    }

    auto stop_capture_path = [&]() {
        try {
            impl->stop_rx_stream();
        } catch (...) {
        }
    };

    local_debug.mode_name = "capture-once";
    local_debug.dpdk_drop_base = device.get_dropped_rx_packets();
    refresh_mode_debug(&local_debug, device);

    try {
        stop_capture_path();
        std::this_thread::sleep_for(std::chrono::milliseconds(10));

        {
            const auto step_start = std::chrono::steady_clock::now();
            drain_pending_packets(device);
            const auto step_end = std::chrono::steady_clock::now();
            (void)duration_ms(step_start, step_end);
        }

        {
            const auto step_start = std::chrono::steady_clock::now();
            if (!device.prepare_iq_data_path(t510_ai::IQ_CAPTURE_DST_EPID, 1.0)) {
                throw std::runtime_error("failed to prepare IQ capture route");
            }
            const auto step_end = std::chrono::steady_clock::now();
            (void)duration_ms(step_start, step_end);
        }
        {
            const auto step_start = std::chrono::steady_clock::now();
            std::this_thread::sleep_for(std::chrono::milliseconds(10));
            const auto step_end = std::chrono::steady_clock::now();
            (void)duration_ms(step_start, step_end);
        }
        {
            const auto step_start = std::chrono::steady_clock::now();
            impl->arm_rx_capture_once(total_bytes, packet_bytes);
            const auto step_end = std::chrono::steady_clock::now();
            (void)duration_ms(step_start, step_end);
        }
        recv_loop_start = std::chrono::steady_clock::now();

        {
            std::lock_guard<std::mutex> lock(state->mutex);
            state->ring.clear();
            state->stats.reset();
            state->debug = local_debug;
            state->status = "Capturing once...";
            state->has_ch1 = false;
            state->spectral_source_single_capture = false;
        }

        while (bytes_written < total_bytes) {
            if (stop_requested && stop_requested->load()) {
                throw std::runtime_error("capture interrupted");
            }

            std::vector<uint8_t> iq_payload;
            t510_ai::t510_ai_iq_frame frame;
            std::string parse_error;
            uint64_t seq = 0;

            const double recv_timeout = stop_requested ? stoppable_capture_poll_timeout_sec : 3.0;
            if (!device.recv_iq_packet(&seq, iq_payload, recv_timeout)) {
                if (stop_requested) {
                    if (stop_requested->load()) {
                        throw std::runtime_error("capture interrupted");
                    }
                    continue;
                }
                std::ostringstream oss;
                oss << "timeout waiting for IQ data or invalid packet"
                    << " (bytes_written=" << bytes_written << "/" << total_bytes
                    << ", packets_received=" << result.stats.packet_count
                    << ", first_packet=" << (got_first_packet ? "yes" : "no") << ")";
                throw std::runtime_error(oss.str());
            }
            if (iq_payload.empty()) {
                continue;
            }
            if (!got_first_packet) {
                const auto first_packet_time = std::chrono::steady_clock::now();
                (void)duration_ms(recv_loop_start, first_packet_time);
                got_first_packet = true;
            }

            if (!t510_ai::parse_iq_capture_payload(iq_payload, seq, &frame, &parse_error)) {
                throw std::runtime_error("failed to parse IQ payload: " + parse_error);
            }

            result.stats.update(frame);
            if (write_output) {
                bytes_written += write_frame_as_raw_cs16(output, frame, total_bytes - bytes_written);
            } else {
                bytes_written += std::min<std::size_t>(frame.sample_bytes, total_bytes - bytes_written);
            }

            const std::vector<std::complex<float>> frame_ch0 = frame_to_complex_ch0(frame);
            result.ch0_iq.insert(result.ch0_iq.end(), frame_ch0.begin(), frame_ch0.end());
            if ((frame.channel_enable & 0x2u) != 0u) {
                const std::vector<std::complex<float>> frame_ch1 = frame_to_complex_ch1(frame);
                result.ch1_iq.insert(result.ch1_iq.end(), frame_ch1.begin(), frame_ch1.end());
            }

            for (const auto& sample : frame.samples) {
                local_ring.push(sample);
                if (sample.ch1_valid) {
                    local_has_ch1 = true;
                }
            }
        }

        const auto total_end = std::chrono::steady_clock::now();
        (void)duration_ms(recv_loop_start, total_end);
        (void)duration_ms(total_start, total_end);
        stop_capture_path();
        refresh_mode_debug(&local_debug, device);

        result.success = (result.stats.seq_gap_events == 0u) && (result.stats.vita_gap_events == 0u)
                         && result.stats.channel_enable_stable;
        result.message = result.success
                             ? "Single capture completed and continuity check passed"
                             : "Single capture completed but continuity warnings were detected";
        result.bytes_written = bytes_written;
        result.packets_received = result.stats.packet_count;

        {
            std::lock_guard<std::mutex> lock(state->mutex);
            state->ring = std::move(local_ring);
            state->stats = result.stats;
            state->debug = local_debug;
            state->has_ch1 = local_has_ch1;
            state->status = result.message;
            state->spectral_source_single_capture = true;
        }

        return result;
    } catch (...) {
        stop_capture_path();
        std::this_thread::sleep_for(stream_stop_settle_time);
        drain_pending_packets(device, stream_stop_drain_limit);
        refresh_mode_debug(&local_debug, device);
        {
            std::lock_guard<std::mutex> lock(state->mutex);
            state->debug = local_debug;
        }
        throw;
    }
}

void stream_worker::start(
    t510_ai::t510_ai_dpdk_device* device, t510_ai::t510_ai_impl::sptr impl, gui_state* state, uint32_t chunk_bytes,
    uint32_t packet_bytes, uint32_t fft_size)
{
    (void)chunk_bytes;

    stop(device, impl, state);
    quiesce_rx_path(device, impl);

    _stop_requested = false;
    gui_state::mode_debug start_debug;
    start_debug.mode_name = "stream";
    start_debug.dpdk_drop_base = device ? device->get_dropped_rx_packets() : 0u;
    if (device) {
        refresh_mode_debug(&start_debug, *device);
    }
    {
        std::lock_guard<std::mutex> lock(state->mutex);
        state->ring.clear();
        state->stats.reset();
        state->debug = start_debug;
        state->streaming = true;
        state->status = "Streaming (4MB capture-once loop)...";
        state->last_error.clear();
        state->has_ch1 = false;
        state->spectral_source_single_capture = false;
        state->live_ch0_spectrum.clear();
        state->live_ch1_spectrum.clear();
        state->live_waterfall.clear();
    }

    _thread = std::thread([this, device, impl, state, packet_bytes, fft_size]() {
        std::size_t capture_index = 0u;

        while (!_stop_requested.load()) {
            try {
                capture_result result = run_single_capture(
                    *device, impl, std::string{}, stream_loop_capture_bytes, packet_bytes, state, &_stop_requested);
                if (_stop_requested.load()) {
                    break;
                }

                refresh_stream_capture_views(state, result, fft_size);

                gui_state::mode_debug local_debug;
                {
                    std::lock_guard<std::mutex> lock(state->mutex);
                    local_debug = state->debug;
                }
                if (device) {
                    refresh_mode_debug(&local_debug, *device);
                }

                {
                    std::lock_guard<std::mutex> lock(state->mutex);
                    state->debug = local_debug;
                    state->streaming = true;
                    if (local_debug.dpdk_drop_delta != 0u) {
                        state->status = "Streaming (4MB capture-once loop, degraded by DPDK drops)...";
                        state->last_error = "stream warning: DPDK RX overflow/drop detected";
                    } else if (!result.success) {
                        state->status = "Streaming (4MB capture-once loop, continuity warnings)...";
                        state->last_error = "stream warning: " + format_continuity_warning(result.stats);
                    } else {
                        std::ostringstream oss;
                        oss << "Streaming (4MB capture-once loop, chunk " << (capture_index + 1u) << " complete)";
                        state->status = oss.str();
                        state->last_error.clear();
                    }
                }
                capture_index++;
            } catch (const std::exception& ex) {
                if (_stop_requested.load()) {
                    break;
                }
                std::lock_guard<std::mutex> lock(state->mutex);
                state->status = "Stream failed";
                state->last_error = ex.what();
                break;
            }
        }
    });
}

void stream_worker::stop(
    t510_ai::t510_ai_dpdk_device* device, t510_ai::t510_ai_impl::sptr impl, gui_state* state)
{
    quiesce_result quiesce;

    if (_thread.joinable()) {
        _stop_requested = true;
        if (impl) {
            impl->stop_rx_stream();
        }
        _thread.join();
    }
    if (device && impl) {
        quiesce = quiesce_rx_path(device, impl);
    }

    if (state) {
        std::lock_guard<std::mutex> lock(state->mutex);
        state->streaming = false;
        if (device) {
            refresh_mode_debug(&state->debug, *device);
        }
        state->debug.last_quiesce_summary = format_quiesce_summary(quiesce);
        if (state->status.rfind("Streaming (4MB capture-once loop", 0) == 0) {
            std::ostringstream oss;
            oss << "Streaming stopped (drained " << quiesce.drained_total
                << " pending packets, dpdk_drop_delta=" << state->debug.dpdk_drop_delta << ")";
            state->status = oss.str();
        }
    }
    _stop_requested = false;
}

void record_worker::start(
    t510_ai::t510_ai_dpdk_device* device, t510_ai::t510_ai_impl::sptr impl, gui_state* state,
    const std::string& output_path, uint32_t chunk_bytes, uint32_t packet_bytes)
{
    stop(device, impl, state);

    {
        std::ofstream probe(output_path, std::ios::binary | std::ios::trunc);
        if (!probe.is_open()) {
            throw std::runtime_error("failed to open record output: " + output_path);
        }
    }

    quiesce_rx_path(device, impl);

    if (!device->prepare_iq_data_path(t510_ai::IQ_CAPTURE_DST_EPID, 1.0)) {
        throw std::runtime_error("failed to prepare IQ capture route");
    }
    std::this_thread::sleep_for(std::chrono::milliseconds(10));
    impl->arm_rx_stream(chunk_bytes, packet_bytes);

    _stop_requested = false;
    _abort_pending = false;
    gui_state::mode_debug start_debug;
    start_debug.mode_name = "record";
    start_debug.dpdk_drop_base = device ? device->get_dropped_rx_packets() : 0u;
    if (device) {
        refresh_mode_debug(&start_debug, *device);
    }
    {
        std::lock_guard<std::mutex> lock(state->mutex);
        state->stats.reset();
        state->debug = start_debug;
        state->recording = true;
        state->status = "Recording (lossless, GUI preview disabled)...";
        state->last_error.clear();
    }

    _thread = std::thread([this, device, state, output_path]() {
        struct record_slot
        {
            std::vector<uint8_t> packet;
            std::size_t len = 0;
        };

        continuity_stats local_stats;
        gui_state::mode_debug local_debug;
        std::ofstream output(output_path, std::ios::binary | std::ios::trunc);
        if (!output.is_open()) {
            std::lock_guard<std::mutex> lock(state->mutex);
            state->recording = false;
            state->status = "Record start failed";
            state->last_error = "failed to open record output: " + output_path;
            return;
        }

        local_debug.mode_name = "record";
        local_debug.dpdk_drop_base = device ? device->get_dropped_rx_packets() : 0u;
        if (device) {
            refresh_mode_debug(&local_debug, *device);
        }

        const auto data_xport = device->get_data_xport();
        const std::size_t packet_capacity =
            std::max<std::size_t>(data_xport ? data_xport->get_recv_frame_size() : 0u, 8192u);

        std::vector<record_slot> slots(record_queue_depth);
        std::deque<std::size_t> free_slots;
        std::deque<std::size_t> ready_slots;
        free_slots.resize(record_queue_depth);
        for (std::size_t i = 0; i < record_queue_depth; i++) {
            slots[i].packet.resize(packet_capacity);
            free_slots[i] = i;
        }

        std::mutex queue_mutex;
        std::condition_variable queue_cv;
        std::atomic<bool> writer_stop{false};
        std::atomic<bool> writer_failed{false};
        std::atomic<std::size_t> bytes_written_atomic{0};
        std::atomic<std::size_t> packets_received_atomic{0};
        std::atomic<std::size_t> queue_drop_packets{0};
        std::size_t queue_peak_depth = 0;
        std::string writer_error;

        std::thread writer([&]() {
            while (true) {
                std::size_t slot_index = 0;
                {
                    std::unique_lock<std::mutex> lock(queue_mutex);
                    queue_cv.wait_for(lock, std::chrono::milliseconds(20), [&]() {
                        return writer_stop.load() || !ready_slots.empty();
                    });
                    if (ready_slots.empty()) {
                        if (writer_stop.load()) {
                            break;
                        }
                        continue;
                    }
                    slot_index = ready_slots.front();
                    ready_slots.pop_front();
                }

                t510_ai::t510_ai_iq_frame frame;
                std::string parse_error;
                uint64_t seq = 0;
                const uint8_t* iq_payload = nullptr;
                std::size_t iq_payload_len = 0;
                const auto& slot = slots[slot_index];
                if (!t510_ai::extract_iq_capture_payload_from_chdr(
                        slot.packet.data(), slot.len, &seq, &iq_payload, &iq_payload_len, &parse_error)) {
                    writer_failed = true;
                    writer_error = "record chdr parse failed: " + parse_error;
                } else if (!t510_ai::parse_iq_capture_payload(
                               iq_payload, iq_payload_len, seq, &frame, &parse_error)) {
                    writer_failed = true;
                    writer_error = "record parse failed: " + parse_error;
                } else {
                    local_stats.update(frame);
                    bytes_written_atomic +=
                        write_frame_as_raw_cs16(output, frame, std::numeric_limits<std::size_t>::max());
                    if (!output.good()) {
                        writer_failed = true;
                        writer_error = "failed while writing record output";
                    }
                }

                {
                    std::lock_guard<std::mutex> lock(queue_mutex);
                    slots[slot_index].len = 0;
                    free_slots.push_back(slot_index);
                }
                queue_cv.notify_one();

                if (writer_failed.load()) {
                    break;
                }
            }
        });

        auto last_publish = std::chrono::steady_clock::now();
        while (!_stop_requested.load() && !writer_failed.load()) {
            const sdr::core::managed_recv_buffer::sptr recv_buffer =
                data_xport ? data_xport->get_recv_buff(0.2) : sdr::core::managed_recv_buffer::sptr();
            if (!recv_buffer || recv_buffer->size() == 0) {
                continue;
            }

            bool enqueued = false;
            {
                std::unique_lock<std::mutex> lock(queue_mutex);
                std::size_t slot_index = std::numeric_limits<std::size_t>::max();
                if (!_stop_requested.load() && !free_slots.empty()) {
                    slot_index = free_slots.front();
                    free_slots.pop_front();
                } else if (!_stop_requested.load() && !ready_slots.empty()) {
                    slot_index = ready_slots.front();
                    ready_slots.pop_front();
                    queue_drop_packets++;
                    if (queue_drop_packets.load() == 1u) {
                        std::fprintf(
                            stderr,
                            "[t510_ai_gui] record queue overflow: switch to overwrite-oldest mode packets=%zu bytes_written=%zu\n",
                            packets_received_atomic.load(),
                            bytes_written_atomic.load());
                    }
                }
                if (!_stop_requested.load() && slot_index != std::numeric_limits<std::size_t>::max()) {
                    lock.unlock();
                    auto& slot = slots[slot_index];
                    slot.len = std::min<std::size_t>(recv_buffer->size(), slot.packet.size());
                    std::memcpy(slot.packet.data(), recv_buffer->cast<const void*>(), slot.len);
                    lock.lock();
                    ready_slots.push_back(slot_index);
                    queue_peak_depth = std::max(queue_peak_depth, ready_slots.size());
                    enqueued = true;
                }
            }
            if (enqueued) {
                packets_received_atomic++;
                queue_cv.notify_one();
            }

            const auto now = std::chrono::steady_clock::now();
            if ((now - last_publish) >= stream_publish_interval) {
                std::size_t ready_depth = 0;
                {
                    std::lock_guard<std::mutex> lock(queue_mutex);
                    ready_depth = ready_slots.size();
                }
                local_debug.app_queue_drop_packets = queue_drop_packets.load();
                local_debug.app_queue_ready_depth = ready_depth;
                local_debug.app_queue_peak_depth = std::max(queue_peak_depth, ready_depth);
                if (device) {
                    refresh_mode_debug(&local_debug, *device);
                }
                std::ostringstream oss;
                oss << "Recording (lossless) "
                    << trim_float_string(
                           std::to_string(static_cast<double>(bytes_written_atomic.load()) / (1024.0 * 1024.0)))
                    << " MB, packets=" << packets_received_atomic.load() << ", queued=" << ready_depth
                    << ", dpdk_drop_delta=" << local_debug.dpdk_drop_delta;
                if (queue_drop_packets.load() != 0u) {
                    oss << ", qdrop=" << queue_drop_packets.load();
                }
                std::lock_guard<std::mutex> lock(state->mutex);
                state->debug = local_debug;
                    state->status = oss.str();
                    last_publish = now;
                }
            }

        if (_abort_pending.load()) {
            std::lock_guard<std::mutex> lock(queue_mutex);
            for (const std::size_t slot_index : ready_slots) {
                slots[slot_index].len = 0;
                free_slots.push_back(slot_index);
            }
            ready_slots.clear();
        }

        writer_stop = true;
        queue_cv.notify_all();
        writer.join();
        output.flush();

        local_debug.app_queue_drop_packets = queue_drop_packets.load();
        local_debug.app_queue_ready_depth = 0u;
        local_debug.app_queue_peak_depth = queue_peak_depth;
        if (device) {
            refresh_mode_debug(&local_debug, *device);
        }

        std::lock_guard<std::mutex> lock(state->mutex);
        state->recording = false;
        state->stats = local_stats;
        state->debug = local_debug;
        if (writer_failed.load()) {
            state->status = "Record write failed";
            state->last_error = writer_error;
        } else if (queue_drop_packets.load() != 0u) {
            std::ostringstream oss;
            oss << "Recording stopped with queue drops/overwrite-oldest (" << queue_drop_packets.load()
                << ", dpdk_drop_delta=" << local_debug.dpdk_drop_delta << ")";
            state->status = oss.str();
            state->last_error = "record queue overflow handled by overwrite-oldest policy";
        } else if ((local_stats.seq_gap_events == 0u) && (local_stats.vita_gap_events == 0u)
                   && local_stats.channel_enable_stable) {
            std::ostringstream oss;
            oss << "Recording stopped, wrote "
                << trim_float_string(
                       std::to_string(static_cast<double>(bytes_written_atomic.load()) / (1024.0 * 1024.0)))
                << " MB, dpdk_drop_delta=" << local_debug.dpdk_drop_delta;
            state->status = oss.str();
            state->last_error.clear();
        } else {
            state->status = "Recording stopped with continuity warnings";
            state->last_error = "record warning: " + format_continuity_warning(local_stats);
        }
    });
}

void record_worker::stop(
    t510_ai::t510_ai_dpdk_device* device, t510_ai::t510_ai_impl::sptr impl, gui_state* state)
{
    if (_thread.joinable()) {
        _stop_requested = true;
        _abort_pending = true;
        if (impl) {
            impl->stop_rx_stream();
        }
        _thread.join();
    }
    quiesce_result quiesce_first;
    quiesce_result quiesce_second;
    if (device && impl) {
        quiesce_first = quiesce_rx_path(device, impl, 4u);
        std::this_thread::sleep_for(std::chrono::milliseconds(120));
        quiesce_second = quiesce_rx_path(device, impl, 2u);
    }
    if (state) {
        std::lock_guard<std::mutex> lock(state->mutex);
        state->recording = false;
        if (device) {
            refresh_mode_debug(&state->debug, *device);
        }
        std::ostringstream oss;
        oss << format_quiesce_summary(quiesce_first) << "; post_wait " << format_quiesce_summary(quiesce_second);
        state->debug.last_quiesce_summary = oss.str();
    }
    _stop_requested = false;
    _abort_pending = false;
}

void drain_worker::start(
    t510_ai::t510_ai_dpdk_device* device, t510_ai::t510_ai_impl::sptr impl, gui_state* state, uint32_t chunk_bytes,
    uint32_t packet_bytes)
{
    stop(device, impl, state);
    quiesce_rx_path(device, impl);

    if (!device->prepare_iq_data_path(t510_ai::IQ_CAPTURE_DST_EPID, 1.0)) {
        throw std::runtime_error("failed to prepare IQ capture route");
    }
    std::this_thread::sleep_for(std::chrono::milliseconds(10));
    impl->arm_rx_stream(chunk_bytes, packet_bytes);

    _stop_requested = false;
    gui_state::mode_debug start_debug;
    start_debug.mode_name = "drain";
    start_debug.dpdk_drop_base = device ? device->get_dropped_rx_packets() : 0u;
    if (device) {
        refresh_mode_debug(&start_debug, *device);
    }
    {
        std::lock_guard<std::mutex> lock(state->mutex);
        state->stats.reset();
        state->debug = start_debug;
        state->draining = true;
        state->status = "Draining packets (no decode, no file write)...";
        state->last_error.clear();
    }

    _thread = std::thread([this, device, state]() {
        std::size_t packets = 0;
        std::size_t bytes = 0;
        continuity_stats local_stats;
        gui_state::mode_debug local_debug;
        auto last_publish = std::chrono::steady_clock::now();
        const auto data_xport = device->get_data_xport();
        std::size_t primed_packets = 0;
        const auto prime_deadline = std::chrono::steady_clock::now() + drain_start_prime_time;

        local_debug.mode_name = "drain";
        local_debug.dpdk_drop_base = device ? device->get_dropped_rx_packets() : 0u;
        if (device) {
            refresh_mode_debug(&local_debug, *device);
        }

        {
            std::lock_guard<std::mutex> lock(state->mutex);
            state->status = "Draining packets (priming startup boundary)...";
        }

        while (!_stop_requested.load() && primed_packets < drain_start_prime_packet_limit
               && std::chrono::steady_clock::now() < prime_deadline) {
            const sdr::core::managed_recv_buffer::sptr recv_buffer =
                data_xport ? data_xport->get_recv_buff(0.02) : sdr::core::managed_recv_buffer::sptr();
            if (!recv_buffer || recv_buffer->size() == 0) {
                continue;
            }
            primed_packets++;
        }

        last_publish = std::chrono::steady_clock::now();
        {
            std::lock_guard<std::mutex> lock(state->mutex);
            state->stats.reset();
            state->status = "Draining packets (no decode, no file write)...";
        }

        while (!_stop_requested.load()) {
            const sdr::core::managed_recv_buffer::sptr recv_buffer =
                data_xport ? data_xport->get_recv_buff(0.2) : sdr::core::managed_recv_buffer::sptr();
            if (!recv_buffer || recv_buffer->size() == 0) {
                continue;
            }
            packets++;
            bytes += recv_buffer->size();

            const uint8_t* iq_payload = nullptr;
            std::size_t iq_payload_len = 0;
            std::string parse_error;
            uint64_t seq = 0;
            if (t510_ai::extract_iq_capture_payload_from_chdr(
                    recv_buffer->cast<const uint8_t*>(),
                    recv_buffer->size(),
                    &seq,
                    &iq_payload,
                    &iq_payload_len,
                    &parse_error)) {
                iq_frame_meta meta;
                if (parse_iq_frame_meta(iq_payload, iq_payload_len, seq, &meta, &parse_error)) {
                    local_stats.update_packet(
                        meta.seq, meta.channel_enable, meta.sample_bytes, meta.first_vita_time, meta.sample_count);
                } else {
                    std::lock_guard<std::mutex> lock(state->mutex);
                    state->last_error = "drain meta parse failed: " + parse_error;
                }
            }

            const auto now = std::chrono::steady_clock::now();
            if ((now - last_publish) >= drain_publish_interval) {
                if (device) {
                    refresh_mode_debug(&local_debug, *device);
                }
                std::ostringstream oss;
                oss << "Draining packets "
                    << trim_float_string(std::to_string(static_cast<double>(bytes) / (1024.0 * 1024.0)))
                    << " MB, packets=" << packets << ", dpdk_drop_delta=" << local_debug.dpdk_drop_delta;
                if (local_stats.seq_gap_events != 0u || local_stats.vita_gap_events != 0u
                    || !local_stats.channel_enable_stable) {
                    oss << ", warn";
                }
                std::lock_guard<std::mutex> lock(state->mutex);
                state->stats = local_stats;
                state->debug = local_debug;
                state->status = oss.str();
                last_publish = now;
            }
        }

        if (device) {
            refresh_mode_debug(&local_debug, *device);
        }
        std::lock_guard<std::mutex> lock(state->mutex);
        state->draining = false;
        state->stats = local_stats;
        state->debug = local_debug;
        if ((local_stats.seq_gap_events == 0u) && (local_stats.vita_gap_events == 0u)
            && local_stats.channel_enable_stable) {
            std::ostringstream oss;
            oss << "Drain stopped, consumed "
                << trim_float_string(std::to_string(static_cast<double>(bytes) / (1024.0 * 1024.0)))
                << " MB, packets=" << packets << ", continuity ok, dpdk_drop_delta=" << local_debug.dpdk_drop_delta;
            state->status = oss.str();
            state->last_error.clear();
        } else {
            std::ostringstream oss;
            oss << "Drain stopped, consumed "
                << trim_float_string(std::to_string(static_cast<double>(bytes) / (1024.0 * 1024.0)))
                << " MB, packets=" << packets
                << ", continuity warnings, dpdk_drop_delta=" << local_debug.dpdk_drop_delta;
            state->status = oss.str();
            state->last_error = "drain warning: " + format_continuity_warning(local_stats);
        }
    });
}

void drain_worker::stop(
    t510_ai::t510_ai_dpdk_device* device, t510_ai::t510_ai_impl::sptr impl, gui_state* state)
{
    if (_thread.joinable()) {
        _stop_requested = true;
        if (impl) {
            impl->stop_rx_stream();
        }
        _thread.join();
    }
    quiesce_result quiesce;
    if (device && impl) {
        quiesce = quiesce_rx_path(device, impl);
    }
    if (state) {
        std::lock_guard<std::mutex> lock(state->mutex);
        state->draining = false;
        if (device) {
            refresh_mode_debug(&state->debug, *device);
        }
        state->debug.last_quiesce_summary = format_quiesce_summary(quiesce);
    }
    _stop_requested = false;
}

} // namespace t510_ai_gui
