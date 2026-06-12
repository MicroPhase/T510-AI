function result = analyze_t510_ai_iq(file_path, sample_rate_hz, num_channels, varargin)
%ANALYZE_T510_AI_IQ Analyze raw cs16 IQ files captured by t510_ai_demo.
%
%   result = analyze_t510_ai_iq(file_path, sample_rate_hz, num_channels)
%
% Input format:
%   num_channels = 1:
%       [ch0_i, ch0_q] as little-endian int16
%   num_channels = 2:
%       [ch0_i, ch0_q, ch1_i, ch1_q] as little-endian int16
%
% Name-value options:
%   'plot'         : true/false, default true
%   'plot_samples' : time-domain points to plot, default 4096
%   'fft_length'   : FFT length, default 65536
%   'remove_dc'    : true/false, default true
%   'full_scale'   : normalization full scale, default 32768
%   'window'       : 'hann' or 'rectwin', default 'hann'
%
% Example:
%   result = analyze_t510_ai_iq('iq_once.bin', 245.76e6, 1);
%   result = analyze_t510_ai_iq('iq_once.bin', 245.76e6, 2, 'fft_length', 131072);

args = local_parse_inputs(varargin{:});

validateattributes(file_path, {'char', 'string'}, {'nonempty'});
validateattributes(sample_rate_hz, {'numeric'}, {'scalar', 'real', 'positive'});
validateattributes(num_channels, {'numeric'}, {'scalar', 'integer', '>=', 1, '<=', 2});

file_path = char(file_path);
fid = fopen(file_path, 'rb');
if fid < 0
    error('analyze_t510_ai_iq:open_failed', 'failed to open file: %s', file_path);
end
cleanup_obj = onCleanup(@() fclose(fid));

raw = fread(fid, inf, 'int16=>double', 0, 'ieee-le');
if isempty(raw)
    error('analyze_t510_ai_iq:empty_file', 'empty IQ file: %s', file_path);
end

if num_channels == 1
    if mod(numel(raw), 2) ~= 0
        error('analyze_t510_ai_iq:bad_size', ...
            'single-channel file must contain an even number of int16 values');
    end
    raw = reshape(raw, 2, []).';
    iq0 = complex(raw(:, 1), raw(:, 2));
    iq1 = [];
else
    if mod(numel(raw), 4) ~= 0
        error('analyze_t510_ai_iq:bad_size', ...
            'dual-channel file must contain a multiple of 4 int16 values');
    end
    raw = reshape(raw, 4, []).';
    iq0 = complex(raw(:, 1), raw(:, 2));
    iq1 = complex(raw(:, 3), raw(:, 4));
end

iq0 = iq0 / args.full_scale;
if ~isempty(iq1)
    iq1 = iq1 / args.full_scale;
end

result = struct();
result.file_path = file_path;
result.sample_rate_hz = sample_rate_hz;
result.num_channels = num_channels;
result.channel_0 = local_analyze_channel(iq0, sample_rate_hz, args, 'CH0');
if ~isempty(iq1)
    result.channel_1 = local_analyze_channel(iq1, sample_rate_hz, args, 'CH1');
end

fprintf('file: %s\n', file_path);
fprintf('sample_rate_hz: %.0f\n', sample_rate_hz);
fprintf('num_channels: %d\n', num_channels);
local_print_stats(result.channel_0, 'CH0');
if isfield(result, 'channel_1')
    local_print_stats(result.channel_1, 'CH1');
end

if args.plot
    local_plot_channel(result.channel_0, args);
    if isfield(result, 'channel_1')
        local_plot_channel(result.channel_1, args);
    end
end

clear cleanup_obj;

end

function args = local_parse_inputs(varargin)

parser = inputParser();
parser.FunctionName = 'analyze_t510_ai_iq';
addParameter(parser, 'plot', true, @(x) islogical(x) || isnumeric(x));
addParameter(parser, 'plot_samples', 4096, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(parser, 'fft_length', 65536, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(parser, 'remove_dc', true, @(x) islogical(x) || isnumeric(x));
addParameter(parser, 'full_scale', 32768, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(parser, 'window', 'hann', @(x) ischar(x) || isstring(x));
parse(parser, varargin{:});

args = parser.Results;
args.plot = logical(args.plot);
args.plot_samples = floor(double(args.plot_samples));
args.fft_length = floor(double(args.fft_length));
args.remove_dc = logical(args.remove_dc);
args.full_scale = double(args.full_scale);
args.window = char(args.window);

end

function channel = local_analyze_channel(iq, sample_rate_hz, args, label)

channel = struct();
channel.label = label;
channel.num_samples = numel(iq);
channel.time = (0:channel.num_samples - 1).' / sample_rate_hz;
channel.iq = iq;

if args.remove_dc
    iq_fft = iq - mean(iq);
else
    iq_fft = iq;
end

channel.mean_i = mean(real(iq));
channel.mean_q = mean(imag(iq));
channel.rms = sqrt(mean(abs(iq).^2));
channel.peak = max(abs(iq));
channel.peak_dbfs = 20 * log10(max(channel.peak, 1e-15));
channel.rms_dbfs = 20 * log10(max(channel.rms, 1e-15));

fft_len = min(args.fft_length, channel.num_samples);
if fft_len < 8
    error('analyze_t510_ai_iq:too_short', 'not enough samples for FFT');
end

segment = iq_fft(1:fft_len);
switch lower(args.window)
case 'hann'
    if fft_len == 1
        win = 1;
    else
        n = (0:fft_len - 1).';
        win = 0.5 - 0.5 * cos(2 * pi * n / (fft_len - 1));
    end
case 'rectwin'
    win = ones(fft_len, 1);
otherwise
    error('analyze_t510_ai_iq:bad_window', 'unsupported window: %s', args.window);
end

segment = segment .* win;
spec = fftshift(fft(segment, fft_len));
spec_mag = abs(spec) / max(sum(win), 1);

channel.fft_length = fft_len;
channel.freq_axis_hz = ((-fft_len / 2):(fft_len / 2 - 1)).' * (sample_rate_hz / fft_len);
channel.spectrum_dbfs = 20 * log10(max(spec_mag, 1e-15));

[channel.peak_bin_dbfs, peak_idx] = max(channel.spectrum_dbfs);
channel.peak_freq_hz = channel.freq_axis_hz(peak_idx);

end

function local_print_stats(channel, label)

fprintf('%s samples: %d\n', label, channel.num_samples);
fprintf('%s mean: I=%+.6e Q=%+.6e\n', label, channel.mean_i, channel.mean_q);
fprintf('%s rms: %.2f dBFS\n', label, channel.rms_dbfs);
fprintf('%s peak: %.2f dBFS\n', label, channel.peak_dbfs);
fprintf('%s spectrum peak: %.2f dBFS at %.3f MHz\n', ...
    label, channel.peak_bin_dbfs, channel.peak_freq_hz / 1e6);

end

function local_plot_channel(channel, args)

plot_n = min(args.plot_samples, channel.num_samples);

figure('Name', [channel.label ' Time Domain'], 'Color', 'w');
subplot(2, 1, 1);
plot(channel.time(1:plot_n) * 1e6, real(channel.iq(1:plot_n)), 'b');
grid on;
xlabel('Time (us)');
ylabel('I');
title([channel.label ' I']);

subplot(2, 1, 2);
plot(channel.time(1:plot_n) * 1e6, imag(channel.iq(1:plot_n)), 'r');
grid on;
xlabel('Time (us)');
ylabel('Q');
title([channel.label ' Q']);

figure('Name', [channel.label ' Constellation'], 'Color', 'w');
scatter(real(channel.iq(1:plot_n)), imag(channel.iq(1:plot_n)), 8, '.');
grid on;
axis equal;
xlabel('I');
ylabel('Q');
title([channel.label ' Constellation']);

figure('Name', [channel.label ' Spectrum'], 'Color', 'w');
plot(channel.freq_axis_hz / 1e6, channel.spectrum_dbfs, 'k');
grid on;
xlabel('Frequency (MHz)');
ylabel('Magnitude (dBFS)');
title(sprintf('%s Spectrum, FFT=%d', channel.label, channel.fft_length));

end
