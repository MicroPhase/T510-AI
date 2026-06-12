clc;
clear;
close all;

iq_file = '../iq_once.cs16';
sample_rate_hz = 245.76e6;
num_channels = 1;
plot_samples = 65536;
fft_length = 65536;
waterfall_fft_length = 2048;
waterfall_overlap = 1024;
remove_dc = true;

%=============================
% 1. 读取 IQ 数据 (cs16)
%=============================
fprintf('Loading IQ data from %s ...\n', iq_file);
fid_iq = fopen(iq_file, 'rb', 'ieee-le');
if fid_iq < 0
    error('Cannot open IQ file: %s', iq_file);
end

iq_raw = fread(fid_iq, inf, 'int16=>double');
fclose(fid_iq);

if isempty(iq_raw)
    error('IQ file is empty: %s', iq_file);
end

if num_channels == 1
    if mod(numel(iq_raw), 2) ~= 0
        warning('IQ 样点数不是偶数，最后一个 int16 将被丢弃');
        iq_raw = iq_raw(1:end-1);
    end

    i0 = iq_raw(1:2:end);
    q0 = iq_raw(2:2:end);
    iq0 = (i0 + 1j * q0) / 32768.0;
    fprintf('Loaded %d complex IQ samples for CH0.\n', numel(iq0));

elseif num_channels == 2
    rem_count = mod(numel(iq_raw), 4);
    if rem_count ~= 0
        warning('双通道 IQ 数据不是 4 的整数倍，末尾将丢弃 %d 个 int16', rem_count);
        iq_raw = iq_raw(1:end-rem_count);
    end

    iq_mat = reshape(iq_raw, 4, []).';
    iq0 = (iq_mat(:, 1) + 1j * iq_mat(:, 2)) / 32768.0;
    iq1 = (iq_mat(:, 3) + 1j * iq_mat(:, 4)) / 32768.0;
    fprintf('Loaded %d complex IQ samples for CH0/CH1.\n', numel(iq0));

else
    error('num_channels must be 1 or 2');
end

%=============================
% 2. 时域绘图
%=============================
time_axis_us = (0:numel(iq0)-1).' / sample_rate_hz * 1e6;
plot_n = numel(iq0);

figure('Name', 'CH0 IQ Time Domain', 'Color', 'w');
subplot(2, 1, 1);
plot(time_axis_us(1:plot_n), real(iq0(1:plot_n)), 'b');
grid on;
xlabel('Time (us)');
ylabel('I');
title('CH0 I');

subplot(2, 1, 2);
plot(time_axis_us(1:plot_n), imag(iq0(1:plot_n)), 'r');
grid on;
xlabel('Time (us)');
ylabel('Q');
title('CH0 Q');

if num_channels == 2
    figure('Name', 'CH1 IQ Time Domain', 'Color', 'w');
    subplot(2, 1, 1);
    plot(time_axis_us(1:plot_n), real(iq1(1:plot_n)), 'b');
    grid on;
    xlabel('Time (us)');
    ylabel('I');
    title('CH1 I');

    subplot(2, 1, 2);
    plot(time_axis_us(1:plot_n), imag(iq1(1:plot_n)), 'r');
    grid on;
    xlabel('Time (us)');
    ylabel('Q');
    title('CH1 Q');
end

%=============================
% 3. 频谱绘图
%=============================
fft_n = min(fft_length, numel(iq0));
if fft_n < 8
    error('Not enough IQ samples for FFT');
end

if remove_dc
    fft_iq0 = iq0 - mean(iq0);
else
    fft_iq0 = iq0;
end

if fft_n == 1
    win = 1;
else
    n = (0:fft_n-1).';
    win = 0.5 - 0.5 * cos(2 * pi * n / (fft_n - 1));
end

spec0 = fftshift(fft(fft_iq0(1:fft_n) .* win, fft_n));
spec0_db = 20 * log10(max(abs(spec0) / max(sum(win), 1), 1e-15));
freq_axis_mhz = ((-fft_n/2):(fft_n/2-1)).' * (sample_rate_hz / fft_n) / 1e6;

figure('Name', 'CH0 Spectrum', 'Color', 'w');
plot(freq_axis_mhz, spec0_db, 'k');
grid on;
xlabel('Frequency (MHz)');
ylabel('Magnitude (dBFS)');
title(sprintf('CH0 Spectrum, FFT = %d', fft_n));

if num_channels == 2
    if remove_dc
        fft_iq1 = iq1 - mean(iq1);
    else
        fft_iq1 = iq1;
    end

    spec1 = fftshift(fft(fft_iq1(1:fft_n) .* win, fft_n));
    spec1_db = 20 * log10(max(abs(spec1) / max(sum(win), 1), 1e-15));

    figure('Name', 'CH1 Spectrum', 'Color', 'w');
    plot(freq_axis_mhz, spec1_db, 'k');
    grid on;
    xlabel('Frequency (MHz)');
    ylabel('Magnitude (dBFS)');
    title(sprintf('CH1 Spectrum, FFT = %d', fft_n));
end

%=============================
% 4. 瀑布图
%=============================
waterfall_fft_n = min(waterfall_fft_length, numel(iq0));
if waterfall_fft_n < 32
    error('Not enough IQ samples for waterfall');
end

waterfall_overlap = min(waterfall_overlap, waterfall_fft_n - 1);
waterfall_hop = waterfall_fft_n - waterfall_overlap;
waterfall_win_n = (0:waterfall_fft_n-1).';
if waterfall_fft_n == 1
    waterfall_win = 1;
else
    waterfall_win = 0.5 - 0.5 * cos(2 * pi * waterfall_win_n / (waterfall_fft_n - 1));
end

if remove_dc
    waterfall_iq0 = iq0 - mean(iq0);
else
    waterfall_iq0 = iq0;
end

num_frames0 = 1 + floor((numel(waterfall_iq0) - waterfall_fft_n) / waterfall_hop);
waterfall_spec0 = zeros(waterfall_fft_n, num_frames0);
waterfall_time0_us = zeros(1, num_frames0);

for frame_idx = 1:num_frames0
    start_idx = (frame_idx - 1) * waterfall_hop + 1;
    stop_idx = start_idx + waterfall_fft_n - 1;
    segment = waterfall_iq0(start_idx:stop_idx) .* waterfall_win;
    spec = fftshift(fft(segment, waterfall_fft_n));
    waterfall_spec0(:, frame_idx) = 20 * log10(max(abs(spec) / max(sum(waterfall_win), 1), 1e-15));
    waterfall_time0_us(frame_idx) = ((start_idx - 1) + waterfall_fft_n / 2) / sample_rate_hz * 1e6;
end

waterfall_freq_axis_mhz = ((-waterfall_fft_n/2):(waterfall_fft_n/2-1)).' ...
    * (sample_rate_hz / waterfall_fft_n) / 1e6;

figure('Name', 'CH0 Waterfall', 'Color', 'w');
imagesc(waterfall_time0_us, waterfall_freq_axis_mhz, waterfall_spec0);
axis xy;
grid on;
xlabel('Time (us)');
ylabel('Frequency (MHz)');
title(sprintf('CH0 Waterfall, FFT = %d, overlap = %d', waterfall_fft_n, waterfall_overlap));
colorbar;
colormap(jet);

if num_channels == 2
    if remove_dc
        waterfall_iq1 = iq1 - mean(iq1);
    else
        waterfall_iq1 = iq1;
    end

    num_frames1 = 1 + floor((numel(waterfall_iq1) - waterfall_fft_n) / waterfall_hop);
    waterfall_spec1 = zeros(waterfall_fft_n, num_frames1);
    waterfall_time1_us = zeros(1, num_frames1);

    for frame_idx = 1:num_frames1
        start_idx = (frame_idx - 1) * waterfall_hop + 1;
        stop_idx = start_idx + waterfall_fft_n - 1;
        segment = waterfall_iq1(start_idx:stop_idx) .* waterfall_win;
        spec = fftshift(fft(segment, waterfall_fft_n));
        waterfall_spec1(:, frame_idx) = 20 * log10(max(abs(spec) / max(sum(waterfall_win), 1), 1e-15));
        waterfall_time1_us(frame_idx) = ((start_idx - 1) + waterfall_fft_n / 2) / sample_rate_hz * 1e6;
    end

    figure('Name', 'CH1 Waterfall', 'Color', 'w');
    imagesc(waterfall_time1_us, waterfall_freq_axis_mhz, waterfall_spec1);
    axis xy;
    grid on;
    xlabel('Time (us)');
    ylabel('Frequency (MHz)');
    title(sprintf('CH1 Waterfall, FFT = %d, overlap = %d', waterfall_fft_n, waterfall_overlap));
    colorbar;
    colormap(jet);
end
