#define GLFW_INCLUDE_NONE
#include <GL/glew.h>
#include <GLFW/glfw3.h>

#include "backends/imgui_impl_glfw.h"
#include "backends/imgui_impl_opengl3.h"
#include "imgui.h"

#include "t510_ai_gui_app.hpp"

#include <csignal>
#include <functional>

namespace {

struct gui_cleanup_guard
{
    std::function<void()> fn;

    ~gui_cleanup_guard()
    {
        if (fn) {
            fn();
        }
    }
};

} // namespace

int main()
{
    using namespace t510_ai_gui;

    g_shutdown_requested.store(false);
    std::signal(SIGINT, t510_gui_signal_handler);
    std::signal(SIGTERM, t510_gui_signal_handler);

    if (!glfwInit()) {
        std::fprintf(stderr, "glfwInit failed\n");
        return 1;
    }

    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3);
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 3);
    glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);
    GLFWwindow* window = glfwCreateWindow(1600, 980, "T510-AI Cyber Console", nullptr, nullptr);
    if (!window) {
        std::fprintf(stderr, "glfwCreateWindow failed\n");
        glfwTerminate();
        return 1;
    }

    glfwMakeContextCurrent(window);
    glfwSwapInterval(1);

    if (glewInit() != GLEW_OK) {
        std::fprintf(stderr, "glewInit failed\n");
        glfwDestroyWindow(window);
        glfwTerminate();
        return 1;
    }

    IMGUI_CHECKVERSION();
    ImGui::CreateContext();
    if (std::FILE* font_probe = std::fopen(default_cjk_font, "rb")) {
        std::fclose(font_probe);
        ImGuiIO& io = ImGui::GetIO();
        io.Fonts->AddFontFromFileTTF(default_cjk_font, 18.0f, nullptr, io.Fonts->GetGlyphRangesChineseFull());
    }
    apply_cyberether_style();
    ImGui_ImplGlfw_InitForOpenGL(window, true);
    ImGui_ImplOpenGL3_Init("#version 330");

    app_model model;
    gui_state state;
    waterfall_history waterfall;
    spectrum_trace_state ch0_spectrum_trace;
    spectrum_trace_state ch1_spectrum_trace;
    uint64_t last_spectrum_sample_count = 0;
    uint64_t last_live_visual_generation = 0;
    stream_worker streamer;
    record_worker recorder;
    drain_worker drainer;
    async_action_worker action_worker;
    std::shared_ptr<t510_ai::t510_ai_dpdk_device> device;
    t510_ai::t510_ai_impl::sptr impl;
    std::mutex device_mutex;

    const auto refresh_model_from_impl = [&](const t510_ai::t510_ai_impl::sptr& local_impl) {
        model.sample_rate_hz = fixed_sample_rate_hz;
        model.applied_sample_rate_hz = fixed_sample_rate_hz;
        model.rx_center_freq_hz = local_impl->get_rx_center_freq();
        model.applied_rx_center_freq_hz = model.rx_center_freq_hz;
        model.tx_center_freq_hz = local_impl->get_tx_center_freq();
        model.applied_tx_center_freq_hz = model.tx_center_freq_hz;
        model.rx_if_freq_hz = local_impl->get_rfdc_rx_if_freq();
        model.tx_if_freq_hz = local_impl->get_rfdc_tx_if_freq();
        model.rx_gain = local_impl->get_rx_gain();
        model.applied_rx_gain = model.rx_gain;
        model.tx_gain = local_impl->get_tx_gain();
        model.applied_tx_gain = model.tx_gain;
    };

    const auto stop_all_modes = [&]() {
        std::shared_ptr<t510_ai::t510_ai_dpdk_device> local_device;
        t510_ai::t510_ai_impl::sptr local_impl;
        {
            std::lock_guard<std::mutex> lock(device_mutex);
            local_device = device;
            local_impl = impl;
        }
        drainer.stop(local_device.get(), local_impl, &state);
        recorder.stop(local_device.get(), local_impl, &state);
        streamer.stop(local_device.get(), local_impl, &state);
    };

    gui_cleanup_guard cleanup_guard{[&]() {
        action_worker.join();
        stop_all_modes();
        ImGui_ImplOpenGL3_Shutdown();
        ImGui_ImplGlfw_Shutdown();
        ImGui::DestroyContext();
        if (window) {
            glfwDestroyWindow(window);
        }
        glfwTerminate();
    }};

    while (!glfwWindowShouldClose(window)) {
        if (g_shutdown_requested.load()) {
            glfwSetWindowShouldClose(window, GLFW_TRUE);
        }
        glfwPollEvents();
        ImGui_ImplOpenGL3_NewFrame();
        ImGui_ImplGlfw_NewFrame();
        ImGui::NewFrame();

        const ImGuiViewport* viewport = ImGui::GetMainViewport();
        ImGui::SetNextWindowPos(viewport->WorkPos);
        ImGui::SetNextWindowSize(viewport->WorkSize);
        ImGui::PushStyleVar(ImGuiStyleVar_WindowRounding, 0.0f);
        ImGui::PushStyleVar(ImGuiStyleVar_WindowBorderSize, 0.0f);
        ImGui::Begin(
            "CyberT510",
            nullptr,
            ImGuiWindowFlags_NoTitleBar | ImGuiWindowFlags_NoResize | ImGuiWindowFlags_NoMove
                | ImGuiWindowFlags_NoCollapse);
        ImGui::PopStyleVar(2);

        continuity_stats stats_snapshot;
        gui_state::mode_debug debug_snapshot;
        std::vector<std::complex<float>> ch0_snapshot;
        std::vector<std::complex<float>> ch1_snapshot;
        std::vector<std::complex<float>> ch0_fft_snapshot;
        std::vector<std::complex<float>> ch1_fft_snapshot;
        std::vector<std::complex<float>> ch0_waterfall_snapshot;
        std::vector<float> live_ch0_spectrum_snapshot;
        std::vector<float> live_ch1_spectrum_snapshot;
        waterfall_history live_waterfall_snapshot;
        rx_debug_stats live_rx_snapshot;
        std::string status_snapshot;
        std::string error_snapshot;
        bool have_live_rx_snapshot = false;
        bool has_ch1 = false;
        bool streaming_snapshot = false;
        bool recording_snapshot = false;
        bool draining_snapshot = false;
        bool single_capture_spectral_snapshot = false;
        uint64_t live_visual_generation_snapshot = 0;
        bool connected_snapshot = false;
        bool device_ready_snapshot = false;
        bool impl_ready_snapshot = false;
        const bool action_busy_snapshot = action_worker.busy();

        {
            std::lock_guard<std::mutex> lock(device_mutex);
            connected_snapshot = static_cast<bool>(device && impl);
            device_ready_snapshot = static_cast<bool>(device);
            impl_ready_snapshot = static_cast<bool>(impl);
            if (device) {
                live_rx_snapshot = sample_rx_debug_stats(*device);
                have_live_rx_snapshot = true;
            }
        }

        {
            std::lock_guard<std::mutex> lock(state.mutex);
            stats_snapshot = state.stats;
            debug_snapshot = state.debug;
            status_snapshot = state.status;
            error_snapshot = state.last_error;
            streaming_snapshot = state.streaming;
            recording_snapshot = state.recording;
            draining_snapshot = state.draining;
            single_capture_spectral_snapshot = state.spectral_source_single_capture;
            live_visual_generation_snapshot = state.live_visual_generation;
            ch0_snapshot = state.ring.snapshot_ch0(std::min<std::size_t>(model.display_samples, ring_capacity));
            ch0_fft_snapshot =
                state.ring.snapshot_ch0(std::min<std::size_t>(std::max<uint32_t>(model.fft_size, 8u), ring_capacity));
            ch0_waterfall_snapshot = state.ring.snapshot_ch0(std::min<std::size_t>(
                ring_capacity,
                std::max<std::size_t>(
                    model.display_samples,
                    static_cast<std::size_t>(std::max<uint32_t>(model.fft_size, 8u)) * 48u)));
            live_ch0_spectrum_snapshot = state.live_ch0_spectrum;
            live_ch1_spectrum_snapshot = state.live_ch1_spectrum;
            live_waterfall_snapshot = state.live_waterfall;
            has_ch1 = state.has_ch1;
            if (has_ch1) {
                ch1_snapshot = state.ring.snapshot_ch1(std::min<std::size_t>(model.display_samples, ring_capacity));
                ch1_fft_snapshot = state.ring.snapshot_ch1(
                    std::min<std::size_t>(std::max<uint32_t>(model.fft_size, 8u), ring_capacity));
            }
        }

        std::vector<float> ch0_spectrum_view;
        std::vector<float> ch1_spectrum_view;
        bool advance_spectral_visuals = false;
        if (streaming_snapshot) {
            advance_spectral_visuals = (live_visual_generation_snapshot != last_live_visual_generation);
            if (advance_spectral_visuals) {
                last_live_visual_generation = live_visual_generation_snapshot;
            }
        } else {
            advance_spectral_visuals = (stats_snapshot.sample_count != last_spectrum_sample_count);
        }
        if (advance_spectral_visuals || !streaming_snapshot) {
            last_spectrum_sample_count = stats_snapshot.sample_count;
        }
        if (streaming_snapshot && !live_ch0_spectrum_snapshot.empty()) {
            ch0_spectrum_view = live_ch0_spectrum_snapshot;
            waterfall = live_waterfall_snapshot;
        } else if (!ch0_fft_snapshot.empty()) {
            const std::vector<float> ch0_spectrum = compute_spectrum_db(ch0_fft_snapshot, model.fft_size);
            if (advance_spectral_visuals) {
                if (streaming_snapshot) {
                    waterfall.push(resample_curve(ch0_spectrum, waterfall_bins));
                } else if (single_capture_spectral_snapshot) {
                    rebuild_waterfall_from_iq(waterfall, ch0_waterfall_snapshot, model.fft_size);
                }
            }
            ch0_spectrum_view = resample_curve(ch0_spectrum, spectrum_bins);
        } else {
            waterfall.clear();
            ch0_spectrum_trace.reset();
        }
        if (streaming_snapshot && !live_ch1_spectrum_snapshot.empty()) {
            ch1_spectrum_view = live_ch1_spectrum_snapshot;
        } else if (!ch1_fft_snapshot.empty()) {
            ch1_spectrum_view = resample_curve(compute_spectrum_db(ch1_fft_snapshot, model.fft_size), spectrum_bins);
        } else {
            ch1_spectrum_trace.reset();
        }

        ImGui::TextColored(ImVec4(0.40f, 0.86f, 0.98f, 1.0f), "T510-AI Cyber Console");
        ImGui::SameLine();
        ImGui::TextDisabled("Live spectrum / waterfall workspace");
        ImGui::Spacing();

        const float left_width = 392.0f;
        ImGui::PushStyleVar(ImGuiStyleVar_FramePadding, ImVec2(6.0f, 4.0f));
        ImGui::PushStyleVar(ImGuiStyleVar_ItemSpacing, ImVec2(6.0f, 6.0f));
        ImGui::BeginChild("ControlPane", ImVec2(left_width, 0.0f), true);
        ImGui::PushItemWidth(200.0f);
        ImGui::TextColored(ImVec4(0.55f, 0.86f, 0.98f, 1.0f), "Device");
        ImGui::InputText("Remote IP", model.remote_ip, sizeof(model.remote_ip));

        if (!connected_snapshot) {
            if (ImGui::Button("Connect", ImVec2(-1.0f, 0.0f)) && !action_busy_snapshot) {
                const std::string remote_ip = model.remote_ip;
                {
                    std::lock_guard<std::mutex> lock(state.mutex);
                    state.status = "Connecting...";
                    state.last_error.clear();
                }
                action_worker.start([&, remote_ip]() {
                    try {
                        auto local_device = std::make_shared<t510_ai::t510_ai_dpdk_device>(remote_ip);
                        if (!local_device->is_ready()) {
                            throw std::runtime_error("device init failed");
                        }
                        auto local_impl = local_device->get_impl();
                        if (!local_device->prepare_iq_data_path(t510_ai::IQ_CAPTURE_DST_EPID, 1.0)) {
                            throw std::runtime_error("failed to prepare IQ capture route");
                        }
                        refresh_model_from_impl(local_impl);
                        {
                            std::lock_guard<std::mutex> lock(device_mutex);
                            device = std::move(local_device);
                            impl = std::move(local_impl);
                        }
                        std::lock_guard<std::mutex> lock(state.mutex);
                        state.connected = true;
                        state.recording = false;
                        state.draining = false;
                        state.status = "Connected";
                        state.last_error.clear();
                    } catch (const std::exception& ex) {
                        {
                            std::lock_guard<std::mutex> lock(device_mutex);
                            device.reset();
                            impl.reset();
                        }
                        std::lock_guard<std::mutex> lock(state.mutex);
                        state.connected = false;
                        state.status = "Connect failed";
                        state.last_error = ex.what();
                    }
                });
            }
        } else {
            if (ImGui::Button("Disconnect", ImVec2(-1.0f, 0.0f)) && !action_busy_snapshot) {
                stop_all_modes();
                {
                    std::lock_guard<std::mutex> lock(device_mutex);
                    device.reset();
                    impl.reset();
                }
                std::lock_guard<std::mutex> lock(state.mutex);
                state.connected = false;
                state.status = "Disconnected";
            }
            if (ImGui::Button("Refresh From Device", ImVec2(-1.0f, 0.0f)) && !action_busy_snapshot) {
                t510_ai::t510_ai_impl::sptr local_impl;
                {
                    std::lock_guard<std::mutex> lock(device_mutex);
                    local_impl = impl;
                }
                if (local_impl) {
                    {
                        std::lock_guard<std::mutex> lock(state.mutex);
                        state.status = "Refreshing...";
                        state.last_error.clear();
                    }
                    action_worker.start([&, local_impl]() {
                        try {
                            refresh_model_from_impl(local_impl);
                            std::lock_guard<std::mutex> lock(state.mutex);
                            state.status = "Device values refreshed";
                            state.last_error.clear();
                        } catch (const std::exception& ex) {
                            std::lock_guard<std::mutex> lock(state.mutex);
                            state.status = "Refresh failed";
                            state.last_error = ex.what();
                        }
                    });
                }
            }
        }

        ImGui::SeparatorText("Runtime");
        if (ImGui::BeginTable(
                "MetricSidebar",
                2,
                ImGuiTableFlags_SizingStretchProp | ImGuiTableFlags_BordersInnerV | ImGuiTableFlags_NoPadOuterX
                    | ImGuiTableFlags_NoPadInnerX)) {
            const ImVec4 metric_colors[6] = {
                connected_snapshot ? ImVec4(0.23f, 0.86f, 0.61f, 1.0f) : ImVec4(0.98f, 0.35f, 0.35f, 1.0f),
                ImVec4(0.42f, 0.79f, 1.0f, 1.0f),
                ImVec4(0.30f, 0.89f, 0.77f, 1.0f),
                ImVec4(1.0f, 0.79f, 0.33f, 1.0f),
                ImVec4(0.98f, 0.53f, 0.33f, 1.0f),
                ImVec4(0.75f, 0.62f, 1.0f, 1.0f),
            };
            const std::string metric_labels[6] = {
                "Link", "Sample Rate", "RX Center", "Packets", "Samples", "VITA",
            };
            const std::string metric_values[6] = {
                connected_snapshot ? "ONLINE" : "OFFLINE",
                std::to_string(model.applied_sample_rate_hz) + " Hz",
                std::to_string(model.applied_rx_center_freq_hz) + " Hz",
                std::to_string(static_cast<unsigned long long>(stats_snapshot.packet_count)),
                std::to_string(static_cast<unsigned long long>(stats_snapshot.sample_count)),
                std::to_string(static_cast<unsigned long long>(stats_snapshot.last_vita_time)),
            };
            for (int i = 0; i < 6; i++) {
                ImGui::TableNextColumn();
                ImGui::TextColored(metric_colors[i], "%s", metric_labels[i].c_str());
                ImGui::TableNextColumn();
                ImGui::TextUnformatted(metric_values[i].c_str());
            }
            ImGui::EndTable();
        }

        auto start_device_update = [&](const char* pending_status, const char* done_status, auto&& task_fn) {
            if (action_worker.busy()) {
                return;
            }
            t510_ai::t510_ai_impl::sptr local_impl;
            {
                std::lock_guard<std::mutex> lock(device_mutex);
                local_impl = impl;
            }
            if (!local_impl) {
                return;
            }
            {
                std::lock_guard<std::mutex> lock(state.mutex);
                state.status = pending_status;
                state.last_error.clear();
            }
            action_worker.start(
                [&, local_impl, done = std::string(done_status), task = std::forward<decltype(task_fn)>(task_fn)]() mutable {
                    try {
                        task(local_impl);
                        std::lock_guard<std::mutex> lock(state.mutex);
                        state.status = done;
                        state.last_error.clear();
                    } catch (const std::exception& ex) {
                        std::lock_guard<std::mutex> lock(state.mutex);
                        state.status = "Apply failed";
                        state.last_error = ex.what();
                    }
                });
        };

        ImGui::SeparatorText("RFDC / FPGA");
        ImGui::InputScalar("Channel Enable", ImGuiDataType_U32, &model.channel_enable);
        if (ImGui::IsItemDeactivatedAfterEdit()) {
            const auto channel_enable = model.channel_enable;
            start_device_update(
                "Applying channel enable...",
                "Channel enable applied",
                [&, channel_enable](const t510_ai::t510_ai_impl::sptr& local_impl) {
                    local_impl->set_channel_enable(channel_enable);
                });
        }
        model.sample_rate_hz = fixed_sample_rate_hz;
        model.applied_sample_rate_hz = fixed_sample_rate_hz;
        ImGui::BeginDisabled();
        ImGui::InputScalar("Sample Rate (Hz)", ImGuiDataType_U64, &model.sample_rate_hz);
        ImGui::EndDisabled();
        ImGui::TextDisabled("Sample rate is currently fixed at 245.76 MHz. Runtime retune is not implemented.");
        ImGui::InputScalar("RX Center Freq (Hz)", ImGuiDataType_U64, &model.rx_center_freq_hz);
        if (ImGui::IsItemDeactivatedAfterEdit()) {
            const auto rx_center_freq_hz = model.rx_center_freq_hz;
            start_device_update(
                "Applying RX center...",
                "RX center applied",
                [&, rx_center_freq_hz](const t510_ai::t510_ai_impl::sptr& local_impl) {
                    local_impl->set_rx_center_freq(rx_center_freq_hz);
                    model.rx_center_freq_hz = local_impl->get_rx_center_freq();
                    model.applied_rx_center_freq_hz = model.rx_center_freq_hz;
                    model.rx_if_freq_hz = local_impl->get_rfdc_rx_if_freq();
                });
        }
        ImGui::InputScalar("TX Center Freq (Hz)", ImGuiDataType_U64, &model.tx_center_freq_hz);
        if (ImGui::IsItemDeactivatedAfterEdit()) {
            const auto tx_center_freq_hz = model.tx_center_freq_hz;
            start_device_update(
                "Applying TX center...",
                "TX center applied",
                [&, tx_center_freq_hz](const t510_ai::t510_ai_impl::sptr& local_impl) {
                    local_impl->set_tx_center_freq(tx_center_freq_hz);
                    model.tx_center_freq_hz = local_impl->get_tx_center_freq();
                    model.applied_tx_center_freq_hz = model.tx_center_freq_hz;
                    model.tx_if_freq_hz = local_impl->get_rfdc_tx_if_freq();
                });
        }
        ImGui::InputScalar("RX Gain", ImGuiDataType_U32, &model.rx_gain);
        if (ImGui::IsItemDeactivatedAfterEdit()) {
            const auto rx_gain = model.rx_gain;
            start_device_update("Applying RX gain...", "RX gain applied", [&, rx_gain](const t510_ai::t510_ai_impl::sptr& local_impl) {
                local_impl->set_rx_gain(rx_gain);
                model.rx_gain = local_impl->get_rx_gain();
                model.applied_rx_gain = model.rx_gain;
            });
        }
        ImGui::InputScalar("TX Gain", ImGuiDataType_U32, &model.tx_gain);
        if (ImGui::IsItemDeactivatedAfterEdit()) {
            const auto tx_gain = model.tx_gain;
            start_device_update("Applying TX gain...", "TX gain applied", [&, tx_gain](const t510_ai::t510_ai_impl::sptr& local_impl) {
                local_impl->set_tx_gain(tx_gain);
                model.tx_gain = local_impl->get_tx_gain();
                model.applied_tx_gain = model.tx_gain;
            });
        }
        ImGui::InputScalar("Set Time Ticks", ImGuiDataType_U64, &model.set_time_ticks);
        ImGui::InputScalar("Set Time Mode", ImGuiDataType_U32, &model.set_time_mode);
        ImGui::BeginDisabled();
        ImGui::InputScalar("Current Time Ticks", ImGuiDataType_U64, &model.current_time_ticks);
        ImGui::EndDisabled();

        if (ImGui::CollapsingHeader("Advanced RFDC Debug", ImGuiTreeNodeFlags_DefaultOpen)) {
            ImGui::TextUnformatted("Current direct-sampling chain uses center_freq as the user control.");
            ImGui::Text(
                "RFDC RX IF Freq (read-only): %llu Hz",
                static_cast<unsigned long long>(model.rx_if_freq_hz));
            ImGui::Text(
                "RFDC TX IF Freq (read-only): %llu Hz",
                static_cast<unsigned long long>(model.tx_if_freq_hz));
        }

        if (ImGui::Button("Set Time", ImVec2(-1.0f, 0.0f)) && !action_worker.busy()) {
            t510_ai::t510_ai_impl::sptr local_impl;
            {
                std::lock_guard<std::mutex> lock(device_mutex);
                local_impl = impl;
            }
            if (local_impl) {
                const auto set_time_ticks = model.set_time_ticks;
                const auto set_time_mode = model.set_time_mode;
                {
                    std::lock_guard<std::mutex> lock(state.mutex);
                    state.status = "Setting time...";
                    state.last_error.clear();
                }
                action_worker.start([&, local_impl, set_time_ticks, set_time_mode]() {
                    try {
                        local_impl->set_timestamp(set_time_ticks, set_time_mode);
                        std::lock_guard<std::mutex> lock(state.mutex);
                        state.status = "Timestamp set";
                        state.last_error.clear();
                    } catch (const std::exception& ex) {
                        std::lock_guard<std::mutex> lock(state.mutex);
                        state.status = "Set time failed";
                        state.last_error = ex.what();
                    }
                });
            }
        }
        if (ImGui::Button("Read Time", ImVec2(-1.0f, 0.0f)) && !action_worker.busy()) {
            t510_ai::t510_ai_impl::sptr local_impl;
            {
                std::lock_guard<std::mutex> lock(device_mutex);
                local_impl = impl;
            }
            if (local_impl) {
                {
                    std::lock_guard<std::mutex> lock(state.mutex);
                    state.status = "Reading time...";
                    state.last_error.clear();
                }
                action_worker.start([&, local_impl]() {
                    try {
                        model.current_time_ticks = local_impl->get_time_ticks();
                        std::lock_guard<std::mutex> lock(state.mutex);
                        state.status = "Read current time";
                        state.last_error.clear();
                    } catch (const std::exception& ex) {
                        std::lock_guard<std::mutex> lock(state.mutex);
                        state.status = "Read time failed";
                        state.last_error = ex.what();
                    }
                });
            }
        }

        ImGui::SeparatorText("Capture");
        ImGui::InputText("Single Capture Output", model.capture_output, sizeof(model.capture_output));
        ImGui::InputFloat("Capture Size (MB)", &model.capture_size_mb, 1.0f, 4.0f, "%.3f");
        model.capture_size_mb = std::max(0.001f, model.capture_size_mb);
        ImGui::InputText("Record Output", model.record_output, sizeof(model.record_output));
        if (ImGui::InputScalar("FFT Size", ImGuiDataType_U32, &model.fft_size)) {
            ch0_spectrum_trace.reset();
            ch1_spectrum_trace.reset();
            waterfall.clear();
        }

        ImGui::BeginDisabled(action_busy_snapshot || streaming_snapshot || recording_snapshot || draining_snapshot);
        if (ImGui::Button("Capture Once", ImVec2(-1.0f, 0.0f)) && !action_busy_snapshot && !streaming_snapshot
            && !recording_snapshot && !draining_snapshot) {
            std::shared_ptr<t510_ai::t510_ai_dpdk_device> local_device;
            t510_ai::t510_ai_impl::sptr local_impl;
            {
                std::lock_guard<std::mutex> lock(device_mutex);
                local_device = device;
                local_impl = impl;
            }
            if (local_device && local_impl) {
                const std::string output_path = model.capture_output;
                const auto capture_bytes = static_cast<uint32_t>(
                    std::llround(static_cast<double>(model.capture_size_mb) * 1024.0 * 1024.0));
                const auto packet_bytes = model.packet_bytes;
                {
                    std::lock_guard<std::mutex> lock(state.mutex);
                    state.status = "Preparing capture...";
                    state.last_error.clear();
                }
                action_worker.start([&, local_device, local_impl, output_path, capture_bytes, packet_bytes]() {
                    try {
                        if (!local_device->prepare_iq_data_path(t510_ai::IQ_CAPTURE_DST_EPID, 1.0)) {
                            throw std::runtime_error("failed to prepare IQ data path");
                        }
                        const capture_result result = run_single_capture(
                            *local_device, local_impl, output_path, capture_bytes, packet_bytes, &state);
                        std::lock_guard<std::mutex> lock(state.mutex);
                        state.last_error.clear();
                        if (!result.success) {
                            state.last_error = "continuity warning: " + format_continuity_warning(result.stats);
                        }
                    } catch (const std::exception& ex) {
                        std::lock_guard<std::mutex> lock(state.mutex);
                        state.last_error = ex.what();
                        state.status = "Capture failed";
                        std::fprintf(stderr, "[t510_ai_gui] capture_once failed: %s\n", ex.what());
                    }
                });
            }
        }
        ImGui::EndDisabled();

        ImGui::BeginDisabled(
            action_busy_snapshot || streaming_snapshot || recording_snapshot || draining_snapshot || !device_ready_snapshot || !impl_ready_snapshot);
        if (ImGui::Button("Start Stream (4MB Loop)", ImVec2(-1.0f, 0.0f)) && !action_busy_snapshot && device_ready_snapshot && impl_ready_snapshot
            && !streaming_snapshot && !recording_snapshot && !draining_snapshot) {
            std::shared_ptr<t510_ai::t510_ai_dpdk_device> local_device;
            t510_ai::t510_ai_impl::sptr local_impl;
            {
                std::lock_guard<std::mutex> lock(device_mutex);
                local_device = device;
                local_impl = impl;
            }
            try {
                if (!local_device || !local_impl) {
                    throw std::runtime_error("device not ready");
                }
                if (!local_device->prepare_iq_data_path(t510_ai::IQ_CAPTURE_DST_EPID, 1.0)) {
                    throw std::runtime_error("failed to prepare IQ data path");
                }
                streamer.start(
                    local_device.get(), local_impl, &state, model.stream_chunk_bytes, model.packet_bytes, model.fft_size);
            } catch (const std::exception& ex) {
                state.last_error = ex.what();
                state.status = "Stream start failed";
            }
        }
        ImGui::EndDisabled();

        ImGui::BeginDisabled(action_busy_snapshot || !impl_ready_snapshot || !streaming_snapshot);
        if (ImGui::Button("Stop Stream", ImVec2(-1.0f, 0.0f)) && !action_busy_snapshot && impl_ready_snapshot) {
            std::shared_ptr<t510_ai::t510_ai_dpdk_device> local_device;
            t510_ai::t510_ai_impl::sptr local_impl;
            {
                std::lock_guard<std::mutex> lock(device_mutex);
                local_device = device;
                local_impl = impl;
            }
            {
                std::lock_guard<std::mutex> lock(state.mutex);
                state.status = "Stopping stream...";
                state.last_error.clear();
            }
            action_worker.start([&, local_device, local_impl]() {
                streamer.stop(local_device.get(), local_impl, &state);
                if (local_device) {
                    local_device->release_iq_data_path();
                }
            });
        }
        ImGui::EndDisabled();

        ImGui::BeginDisabled(
            action_busy_snapshot || streaming_snapshot || recording_snapshot || draining_snapshot || !device_ready_snapshot || !impl_ready_snapshot);
        if (ImGui::Button("Start Record", ImVec2(-1.0f, 0.0f)) && !action_busy_snapshot && device_ready_snapshot && impl_ready_snapshot
            && !streaming_snapshot && !recording_snapshot && !draining_snapshot) {
            std::shared_ptr<t510_ai::t510_ai_dpdk_device> local_device;
            t510_ai::t510_ai_impl::sptr local_impl;
            {
                std::lock_guard<std::mutex> lock(device_mutex);
                local_device = device;
                local_impl = impl;
            }
            try {
                if (!local_device || !local_impl) {
                    throw std::runtime_error("device not ready");
                }
                if (!local_device->prepare_iq_data_path(t510_ai::IQ_CAPTURE_DST_EPID, 1.0)) {
                    throw std::runtime_error("failed to prepare IQ data path");
                }
                recorder.start(
                    local_device.get(), local_impl, &state, model.record_output, model.stream_chunk_bytes, model.packet_bytes);
            } catch (const std::exception& ex) {
                state.last_error = ex.what();
                state.status = "Record start failed";
            }
        }
        ImGui::EndDisabled();

        ImGui::BeginDisabled(action_busy_snapshot || !impl_ready_snapshot || !recording_snapshot);
        if (ImGui::Button("Stop Record", ImVec2(-1.0f, 0.0f)) && !action_busy_snapshot && impl_ready_snapshot) {
            std::shared_ptr<t510_ai::t510_ai_dpdk_device> local_device;
            t510_ai::t510_ai_impl::sptr local_impl;
            {
                std::lock_guard<std::mutex> lock(device_mutex);
                local_device = device;
                local_impl = impl;
            }
            {
                std::lock_guard<std::mutex> lock(state.mutex);
                state.status = "Stopping record...";
                state.last_error.clear();
            }
            action_worker.start([&, local_device, local_impl]() {
                recorder.stop(local_device.get(), local_impl, &state);
                if (local_device) {
                    local_device->release_iq_data_path();
                }
            });
        }
        ImGui::EndDisabled();

        ImGui::BeginDisabled(
            action_busy_snapshot || streaming_snapshot || recording_snapshot || draining_snapshot || !device_ready_snapshot || !impl_ready_snapshot);
        if (ImGui::Button("Start Drain Test", ImVec2(-1.0f, 0.0f)) && !action_busy_snapshot && device_ready_snapshot && impl_ready_snapshot
            && !streaming_snapshot && !recording_snapshot && !draining_snapshot) {
            std::shared_ptr<t510_ai::t510_ai_dpdk_device> local_device;
            t510_ai::t510_ai_impl::sptr local_impl;
            {
                std::lock_guard<std::mutex> lock(device_mutex);
                local_device = device;
                local_impl = impl;
            }
            try {
                if (!local_device || !local_impl) {
                    throw std::runtime_error("device not ready");
                }
                if (!local_device->prepare_iq_data_path(t510_ai::IQ_CAPTURE_DST_EPID, 1.0)) {
                    throw std::runtime_error("failed to prepare IQ data path");
                }
                drainer.start(local_device.get(), local_impl, &state, model.stream_chunk_bytes, model.packet_bytes);
            } catch (const std::exception& ex) {
                state.last_error = ex.what();
                state.status = "Drain start failed";
            }
        }
        ImGui::EndDisabled();

        ImGui::BeginDisabled(action_busy_snapshot || !impl_ready_snapshot || !draining_snapshot);
        if (ImGui::Button("Stop Drain Test", ImVec2(-1.0f, 0.0f)) && !action_busy_snapshot && impl_ready_snapshot) {
            std::shared_ptr<t510_ai::t510_ai_dpdk_device> local_device;
            t510_ai::t510_ai_impl::sptr local_impl;
            {
                std::lock_guard<std::mutex> lock(device_mutex);
                local_device = device;
                local_impl = impl;
            }
            {
                std::lock_guard<std::mutex> lock(state.mutex);
                state.status = "Stopping drain test...";
                state.last_error.clear();
            }
            action_worker.start([&, local_device, local_impl]() {
                drainer.stop(local_device.get(), local_impl, &state);
                if (local_device) {
                    local_device->release_iq_data_path();
                }
            });
        }
        ImGui::EndDisabled();
        ImGui::PopItemWidth();
        ImGui::EndChild();
        ImGui::PopStyleVar(2);

        ImGui::SameLine();
        ImGui::BeginChild("WorkspacePane", ImVec2(0.0f, 0.0f), false);
        ImGui::TextColored(ImVec4(0.55f, 0.86f, 0.98f, 1.0f), "Workspace");
        ImGui::TextDisabled("Live spectrum / waterfall");
        ImGui::Separator();
        ImGui::BeginChild("SignalPane", ImVec2(0.0f, 0.0f), true);
        if (ch0_snapshot.empty()) {
            ImGui::TextDisabled("No CH0 samples yet");
            static const std::vector<float> empty_spectrum;
            static const std::vector<float> empty_trace;
            ImGui::Text("CH0 samples: 0");
            draw_time_trace("CH0 I", empty_trace, 98.0f);
            draw_time_trace("CH0 Q", empty_trace, 98.0f);
            draw_spectrum_canvas(
                "CH0 Spectrum",
                empty_spectrum,
                ch0_spectrum_trace,
                230.0f,
                false,
                model.applied_rx_center_freq_hz,
                model.applied_sample_rate_hz,
                model.spectrum_top_dbfs,
                model.spectrum_bottom_dbfs);
            draw_waterfall_section(
                "CH0 Waterfall", waterfall, model.applied_rx_center_freq_hz, model.applied_sample_rate_hz);
        } else {
            ImGui::Text("CH0 samples: %zu", ch0_snapshot.size());
            draw_time_trace("CH0 I", to_plot_i(ch0_snapshot), 98.0f);
            draw_time_trace("CH0 Q", to_plot_q(ch0_snapshot), 98.0f);
            draw_spectrum_canvas(
                "CH0 Spectrum",
                ch0_spectrum_view,
                ch0_spectrum_trace,
                230.0f,
                advance_spectral_visuals,
                model.applied_rx_center_freq_hz,
                model.applied_sample_rate_hz,
                model.spectrum_top_dbfs,
                model.spectrum_bottom_dbfs);
            draw_waterfall_section(
                "CH0 Waterfall", waterfall, model.applied_rx_center_freq_hz, model.applied_sample_rate_hz);
        }

        if (has_ch1) {
            ImGui::Separator();
            if (ch1_snapshot.empty()) {
                ImGui::TextDisabled("No CH1 samples yet");
            } else {
                ImGui::Text("CH1 samples: %zu", ch1_snapshot.size());
                draw_time_trace("CH1 I", to_plot_i(ch1_snapshot), 98.0f);
                draw_time_trace("CH1 Q", to_plot_q(ch1_snapshot), 98.0f);
                draw_spectrum_canvas(
                    "CH1 Spectrum",
                    ch1_spectrum_view,
                    ch1_spectrum_trace,
                    230.0f,
                    advance_spectral_visuals,
                    model.applied_rx_center_freq_hz,
                    model.applied_sample_rate_hz,
                    model.spectrum_top_dbfs,
                    model.spectrum_bottom_dbfs);
            }
        }

        ImGui::SeparatorText("Status");
        ImGui::TextWrapped("%s", status_snapshot.c_str());
        if (stats_snapshot.packet_count != 0u) {
            ImGui::Text(
                "SEQ last=%llu  gaps=%llu(+%llu)",
                static_cast<unsigned long long>(stats_snapshot.last_seq),
                static_cast<unsigned long long>(stats_snapshot.seq_gap_events),
                static_cast<unsigned long long>(stats_snapshot.seq_gap_total));
            ImGui::Text(
                "VITA last=%llu  gaps=%llu(+%llu)",
                static_cast<unsigned long long>(stats_snapshot.last_vita_time),
                static_cast<unsigned long long>(stats_snapshot.vita_gap_events),
                static_cast<unsigned long long>(stats_snapshot.vita_gap_total));
        }
        if (have_live_rx_snapshot) {
            ImGui::Text(
                "DPDK RX dropped=%llu  ready=%llu/%llu",
                static_cast<unsigned long long>(live_rx_snapshot.dropped_packets),
                static_cast<unsigned long long>(live_rx_snapshot.ready_packets),
                static_cast<unsigned long long>(live_rx_snapshot.slot_capacity));
        }
        if (!debug_snapshot.mode_name.empty()) {
            ImGui::Text(
                "Mode[%s] dpdk_drop base=%llu  delta=%llu  total=%llu",
                debug_snapshot.mode_name.c_str(),
                static_cast<unsigned long long>(debug_snapshot.dpdk_drop_base),
                static_cast<unsigned long long>(debug_snapshot.dpdk_drop_delta),
                static_cast<unsigned long long>(debug_snapshot.dpdk_drop_total));
            if (debug_snapshot.app_queue_drop_packets != 0u || debug_snapshot.app_queue_ready_depth != 0u
                || debug_snapshot.app_queue_peak_depth != 0u) {
                ImGui::Text(
                    "App queue drop=%llu  ready=%llu  peak=%llu",
                    static_cast<unsigned long long>(debug_snapshot.app_queue_drop_packets),
                    static_cast<unsigned long long>(debug_snapshot.app_queue_ready_depth),
                    static_cast<unsigned long long>(debug_snapshot.app_queue_peak_depth));
            }
            if (!debug_snapshot.last_quiesce_summary.empty()) {
                ImGui::TextWrapped("%s", debug_snapshot.last_quiesce_summary.c_str());
            }
        }
        if (!error_snapshot.empty()) {
            ImGui::TextColored(ImVec4(0.98f, 0.45f, 0.45f, 1.0f), "%s", error_snapshot.c_str());
        }
        ImGui::EndChild();
        ImGui::EndChild();

        ImGui::End();

        ImGui::Render();
        int display_w = 0;
        int display_h = 0;
        glfwGetFramebufferSize(window, &display_w, &display_h);
        glViewport(0, 0, display_w, display_h);
        glClearColor(0.04f, 0.06f, 0.09f, 1.0f);
        glClear(GL_COLOR_BUFFER_BIT);
        ImGui_ImplOpenGL3_RenderDrawData(ImGui::GetDrawData());
        glfwSwapBuffers(window);
    }

    return 0;
}
