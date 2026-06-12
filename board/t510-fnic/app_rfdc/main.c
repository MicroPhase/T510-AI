#include <errno.h>
#include <getopt.h>
#include <signal.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include "app_mailbox.h"
#include "app_gpio.h"
#include "lmk04828.h"
#include "remote_regs.h"
#include "rfdc_platform.h"
#include "xrfdc.h"

#define RFDC_DEVICE_ID 0U
#define DEFAULT_TILE 0U
#define DEFAULT_BLOCK 0U
#define DEFAULT_REMOTE_SAMPLE_RATE_HZ 61440000U
#define APP_RFDC_DEFAULT_LMK_SYNC_GPIO 78U
#define APP_RFDC_DEFAULT_LMK_RESET_GPIO 29U
#define REMOTE_RX_TILE 0U
#define REMOTE_RX_BLOCK 0U
#define REMOTE_TX_TILE 0U
#define REMOTE_TX_BLOCK 0U
#define APP_FNIC_PROTOCOL_VERSION 0x00010000U
#define APP_FNIC_BUILD_ID 0x20260604U
#define APP_FNIC_STATUS_OK 0x0000U
#define APP_FNIC_STATUS_BAD_CMD 0x0003U
#define APP_FNIC_STATUS_DENIED 0x0006U
#define APP_FNIC_CMD_NOP 0x0000U
#define APP_FNIC_CMD_GET_VERSION 0x0001U
#define APP_FNIC_CMD_WRITE_REG 0x0002U
#define APP_FNIC_CMD_READ_REG 0x0003U
#define APP_FNIC_CMD_PING 0x00010001U
#define APP_FNIC_CMD_SET_RX_FREQ 0x00010100U
#define APP_FNIC_CMD_GET_RX_FREQ 0x00010101U
#define APP_FNIC_CMD_SET_TX_FREQ 0x00010102U
#define APP_FNIC_CMD_GET_TX_FREQ 0x00010103U
#define APP_FNIC_REG_SET_RX_LO_HZ 0x0031U
#define APP_FNIC_REG_SET_TX_LO_HZ 0x0032U

struct app_args {
	bool set_freq;
	bool skip_lmk_init;
	bool mailbox_server_mode;
	bool no_dump;
	u32 type;
	u32 tile;
	u32 block;
	u32 lmk_chip_id;
	u32 lmk_reset_gpio;
	u32 lmk_sync_gpio;
	u32 mailbox_base;
	double freq_mhz;
	const char *dt_root;
	const char *lmk_spi_path;
};

struct remote_state {
	u32 channel_enable;
	u32 sample_rate_hz;
	u32 rx_gain;
	u32 tx_gain;
	u64 rx_lo_hz;
	u64 tx_lo_hz;
	u32 pending_rx_lo_low;
	u32 pending_tx_lo_low;
	bool pending_rx_lo_valid;
	bool pending_tx_lo_valid;
};

static volatile sig_atomic_t g_stop = 0;

static void usage(const char *prog)
{
	fprintf(stderr,
		"Usage:\n"
		"  %s\n"
		"  %s --type <adc|dac> --tile <id> --block <id> --freq <MHz>\n"
		"  %s --mailbox-server [--mailbox-base <addr>]\n"
		"  %s [--dt-root <path>] [--lmk-spi <path>] [--lmk-chip-id <id>]\n"
		"     [--lmk-reset-gpio <n>] [--lmk-sync-gpio <n>] [--skip-lmk-init]\n",
		prog, prog, prog, prog);
}

static void signal_handler(int signum)
{
	(void)signum;
	g_stop = 1;
}

static const char *tile_type_name(u32 type)
{
	return (type == XRFDC_ADC_TILE) ? "ADC" : "DAC";
}

static void print_rate(const char *label, double rate)
{
	if (rate < 20.0) {
		printf("  %-13s= %.6f GSPS (%.6f MHz)\n", label, rate, rate * 1000.0);
		return;
	}

	printf("  %-13s= %.6f MHz (%.6f GSPS)\n", label, rate, rate / 1000.0);
}

static int parse_type(const char *arg, u32 *type)
{
	if (strcmp(arg, "adc") == 0) {
		*type = XRFDC_ADC_TILE;
		return 0;
	}

	if (strcmp(arg, "dac") == 0) {
		*type = XRFDC_DAC_TILE;
		return 0;
	}

	return -EINVAL;
}

static int parse_u32_arg(const char *arg, u32 *value)
{
	char *end = NULL;
	unsigned long parsed;

	errno = 0;
	parsed = strtoul(arg, &end, 0);
	if (errno != 0 || end == arg || *end != '\0' || parsed > 0xffffffffUL)
		return -EINVAL;

	*value = (u32)parsed;
	return 0;
}

static int parse_double_arg(const char *arg, double *value)
{
	char *end = NULL;

	errno = 0;
	*value = strtod(arg, &end);
	if (errno != 0 || end == arg || *end != '\0')
		return -EINVAL;

	return 0;
}

static void normalize_single_dash_long_options(int argc, char **argv)
{
	static const char *known_options[] = {
		"type",
		"tile",
		"block",
		"freq",
		"dt-root",
		"lmk-spi",
		"lmk-chip-id",
		"lmk-reset-gpio",
		"lmk-sync-gpio",
		"mailbox-server",
		"mailbox-base",
		"skip-lmk-init",
		"no-dump",
		"help",
	};
	int i;
	size_t option_count = sizeof(known_options) / sizeof(known_options[0]);

	for (i = 1; i < argc; ++i) {
		size_t j;

		if (argv[i] == NULL || argv[i][0] != '-' || argv[i][1] == '-' || argv[i][1] == '\0')
			continue;

		for (j = 0; j < option_count; ++j) {
			if (strcmp(argv[i] + 1, known_options[j]) == 0) {
				size_t len = strlen(known_options[j]) + 3U;
				char *fixed = malloc(len);

				if (fixed == NULL)
					break;

				snprintf(fixed, len, "--%s", known_options[j]);
				argv[i] = fixed;
				break;
			}
		}
	}
}

static int parse_args(int argc, char **argv, struct app_args *args)
{
	static const struct option options[] = {
		{ "type",          required_argument, NULL, 't' },
		{ "tile",          required_argument, NULL, 'T' },
		{ "block",         required_argument, NULL, 'b' },
		{ "freq",          required_argument, NULL, 'f' },
		{ "dt-root",       required_argument, NULL, 'r' },
		{ "lmk-spi",       required_argument, NULL, 's' },
		{ "lmk-chip-id",   required_argument, NULL, 'c' },
		{ "lmk-reset-gpio", required_argument, NULL, 'R' },
		{ "lmk-sync-gpio", required_argument, NULL, 'Y' },
		{ "mailbox-server", no_argument,      NULL, 'M' },
		{ "mailbox-base",  required_argument, NULL, 'm' },
		{ "skip-lmk-init", no_argument,       NULL, 'S' },
		{ "no-dump",       no_argument,       NULL, 'D' },
		{ "help",          no_argument,       NULL, 'h' },
		{ NULL,            0,                 NULL,  0  },
	};
	int opt;
	bool have_type = false;

	memset(args, 0, sizeof(*args));
	args->tile = DEFAULT_TILE;
	args->block = DEFAULT_BLOCK;
	args->lmk_chip_id = 6U;
	args->lmk_reset_gpio = APP_RFDC_DEFAULT_LMK_RESET_GPIO;
	args->lmk_sync_gpio = APP_RFDC_DEFAULT_LMK_SYNC_GPIO;
	args->dt_root = APP_RFDC_DEFAULT_DT_ROOT;
	args->lmk_spi_path = LMK04828_SPI_NAME;
	args->mailbox_base = APP_MAILBOX_DEFAULT_BASE_ADDR;

	normalize_single_dash_long_options(argc, argv);

	while ((opt = getopt_long(argc, argv, "t:T:b:f:r:s:c:R:Y:m:MSDh", options, NULL)) != -1) {
		switch (opt) {
		case 't':
			if (parse_type(optarg, &args->type) != 0)
				return -EINVAL;
			have_type = true;
			break;
		case 'T':
			if (parse_u32_arg(optarg, &args->tile) != 0)
				return -EINVAL;
			break;
		case 'b':
			if (parse_u32_arg(optarg, &args->block) != 0)
				return -EINVAL;
			break;
		case 'f':
			if (parse_double_arg(optarg, &args->freq_mhz) != 0)
				return -EINVAL;
			args->set_freq = true;
			break;
		case 'r':
			args->dt_root = optarg;
			break;
		case 's':
			args->lmk_spi_path = optarg;
			break;
		case 'c':
			if (parse_u32_arg(optarg, &args->lmk_chip_id) != 0 || args->lmk_chip_id > 0xffU)
				return -EINVAL;
			break;
		case 'R':
			if (parse_u32_arg(optarg, &args->lmk_reset_gpio) != 0)
				return -EINVAL;
			break;
		case 'Y':
			if (parse_u32_arg(optarg, &args->lmk_sync_gpio) != 0)
				return -EINVAL;
			break;
		case 'm':
			if (parse_u32_arg(optarg, &args->mailbox_base) != 0)
				return -EINVAL;
			break;
		case 'M':
			args->mailbox_server_mode = true;
			break;
		case 'S':
			args->skip_lmk_init = true;
			break;
		case 'D':
			args->no_dump = true;
			break;
		case 'h':
			usage(argv[0]);
			exit(0);
		default:
			return -EINVAL;
		}
	}

	if (args->set_freq && !have_type)
		return -EINVAL;

	if (args->tile > XRFDC_TILE_ID_MAX || args->block > XRFDC_BLOCK_ID_MAX)
		return -EINVAL;

	return 0;
}

static int init_lmk04828(const struct app_args *args)
{
	struct app_gpio_line reset_gpio = {0};
	struct app_gpio_line sync_gpio = {0};
	struct lmk04828_dev lmk = {0};
	int ret;

	printf("Initializing LMK04828 via %s (chip id 0x%02x, reset_gpio=%u, sync_gpio=%u)\n",
	       args->lmk_spi_path,
	       args->lmk_chip_id,
	       args->lmk_reset_gpio,
	       args->lmk_sync_gpio);

	ret = app_gpio_open_output(&reset_gpio, args->lmk_reset_gpio, 1);
	if (ret != 0) {
		fprintf(stderr, "failed to open LMK_RESET gpio %u\n", args->lmk_reset_gpio);
		return -1;
	}

	ret = app_gpio_open_output(&sync_gpio, args->lmk_sync_gpio, 0);
	if (ret != 0) {
		fprintf(stderr, "failed to open LMK_SYNC gpio %u\n", args->lmk_sync_gpio);
		app_gpio_close(&reset_gpio);
		return -1;
	}

	printf("LMK GPIO mapped: reset=%s offset=%u, sync=%s offset=%u\n",
	       reset_gpio.chip_path,
	       reset_gpio.offset,
	       sync_gpio.chip_path,
	       sync_gpio.offset);

	sleep(1);
	ret = app_gpio_set_value(&reset_gpio, 0);
	if (ret != 0) {
		fprintf(stderr, "failed to drive LMK_RESET low on gpio %u\n", args->lmk_reset_gpio);
		app_gpio_close(&sync_gpio);
		app_gpio_close(&reset_gpio);
		return -1;
	}
	sleep(1);
	(void)app_gpio_set_value(&sync_gpio, 0);

	ret = lmk04828_setup(&lmk, args->lmk_spi_path, (uint8_t)args->lmk_chip_id);
	if (ret != 0) {
		fprintf(stderr, "lmk04828_setup failed for %s\n", args->lmk_spi_path);
		app_gpio_close(&sync_gpio);
		app_gpio_close(&reset_gpio);
		return -1;
	}

	lmk04828_remove(&lmk);
	app_gpio_close(&sync_gpio);
	app_gpio_close(&reset_gpio);
	return 0;
}

static void dump_block(XRFdc *rfdc, u32 type, u32 tile, u32 block)
{
	XRFdc_BlockStatus block_status = {0};
	XRFdc_Mixer_Settings mixer = {0};
	XRFdc_PLL_Settings pll = {0};
	u32 nyquist = 0;
	u32 status;

	status = XRFdc_GetBlockStatus(rfdc, type, tile, block, &block_status);
	if (status != XRFDC_SUCCESS) {
		printf("%s tile %u block %u: GetBlockStatus failed\n",
		       tile_type_name(type), tile, block);
		return;
	}

	status = XRFdc_GetMixerSettings(rfdc, type, tile, block, &mixer);
	if (status != XRFDC_SUCCESS) {
		printf("%s tile %u block %u: GetMixerSettings failed\n",
		       tile_type_name(type), tile, block);
		return;
	}

	status = XRFdc_GetNyquistZone(rfdc, type, tile, block, &nyquist);
	if (status != XRFDC_SUCCESS) {
		printf("%s tile %u block %u: GetNyquistZone failed\n",
		       tile_type_name(type), tile, block);
		return;
	}

	status = XRFdc_GetPLLConfig(rfdc, type, tile, &pll);
	if (status != XRFDC_SUCCESS) {
		printf("%s tile %u: GetPLLConfig failed\n", tile_type_name(type), tile);
		return;
	}

	printf("%s tile %u block %u\n", tile_type_name(type), tile, block);
	print_rate("sampling_freq", block_status.SamplingFreq);
	printf("  nyquist_zone  = %u\n", nyquist);
	printf("  mixer_freq    = %.6f MHz\n", mixer.Freq);
	printf("  mixer_mode    = %u\n", mixer.MixerMode);
	printf("  mixer_type    = %u\n", mixer.MixerType);
	printf("  event_source  = %u\n", mixer.EventSource);
	printf("  fifo_enabled  = %u\n", block_status.IsFIFOFlagsEnabled);
	printf("  fifo_asserted = %u\n", block_status.IsFIFOFlagsAsserted);
	printf("  pll_enabled   = %u\n", pll.Enabled);
	print_rate("pll_refclk", pll.RefClkFreq);
	print_rate("pll_samplerate", pll.SampleRate);
}

static void dump_rfdc(XRFdc *rfdc)
{
	u32 tile;
	u32 block;

	printf("RFDC device id %u state dump\n", RFDC_DEVICE_ID);

	for (tile = 0; tile <= XRFDC_TILE_ID_MAX; ++tile) {
		if (XRFdc_CheckTileEnabled(rfdc, XRFDC_ADC_TILE, tile) == XRFDC_SUCCESS) {
			for (block = 0; block <= XRFDC_BLOCK_ID_MAX; ++block) {
				if (XRFdc_IsADCBlockEnabled(rfdc, tile, block))
					dump_block(rfdc, XRFDC_ADC_TILE, tile, block);
			}
		}

		if (XRFdc_CheckTileEnabled(rfdc, XRFDC_DAC_TILE, tile) == XRFDC_SUCCESS) {
			for (block = 0; block <= XRFDC_BLOCK_ID_MAX; ++block) {
				if (XRFdc_IsDACBlockEnabled(rfdc, tile, block))
					dump_block(rfdc, XRFDC_DAC_TILE, tile, block);
			}
		}
	}
}

static int block_is_enabled(XRFdc *rfdc, u32 type, u32 tile, u32 block)
{
	if (XRFdc_CheckTileEnabled(rfdc, type, tile) != XRFDC_SUCCESS)
		return 0;

	if (type == XRFDC_ADC_TILE)
		return XRFdc_IsADCBlockEnabled(rfdc, tile, block);

	return XRFdc_IsDACBlockEnabled(rfdc, tile, block);
}

static int set_if_frequency(struct app_rfdc_device *dev, u32 type, u32 tile, u32 block, double freq_mhz)
{
	if (!block_is_enabled(&dev->rfdc, type, tile, block)) {
		fprintf(stderr, "%s tile %u block %u is not enabled\n",
			tile_type_name(type), tile, block);
		return -1;
	}

	if (app_rfdc_set_if_frequency(dev, type, tile, block, freq_mhz) != 0) {
		fprintf(stderr, "failed to update %s tile %u block %u IF frequency to %.6f MHz\n",
			tile_type_name(type), tile, block, freq_mhz);
		return -1;
	}

	printf("Updated %s tile %u block %u IF frequency to %.6f MHz\n",
	       tile_type_name(type), tile, block, freq_mhz);
	return 0;
}

static u64 mhz_to_hz(double freq_mhz)
{
	if (freq_mhz <= 0.0)
		return 0;

	return (u64)(freq_mhz * 1000000.0 + 0.5);
}

static double hz_to_mhz(u64 freq_hz)
{
	return (double)freq_hz / 1000000.0;
}

static u64 get_block_mixer_hz(XRFdc *rfdc, u32 type, u32 tile, u32 block)
{
	XRFdc_Mixer_Settings mixer = {0};

	if (!block_is_enabled(rfdc, type, tile, block))
		return 0;

	if (XRFdc_GetMixerSettings(rfdc, type, tile, block, &mixer) != XRFDC_SUCCESS)
		return 0;

	if (mixer.Freq == 0.0)
		return 0;

	if (mixer.Freq < 0.0)
		return mhz_to_hz(-mixer.Freq);

	return mhz_to_hz(mixer.Freq);
}

static void init_remote_state(struct remote_state *state, struct app_rfdc_device *dev)
{
	u64 sample_rate_hz = 0;

	memset(state, 0, sizeof(*state));
	state->sample_rate_hz = DEFAULT_REMOTE_SAMPLE_RATE_HZ;
	if (app_rfdc_get_default_sample_rate_hz(dev, &sample_rate_hz) == 0
	    && sample_rate_hz <= UINT32_MAX)
		state->sample_rate_hz = (u32)sample_rate_hz;
	state->channel_enable = 1U;
	state->rx_lo_hz = get_block_mixer_hz(&dev->rfdc, XRFDC_ADC_TILE, REMOTE_RX_TILE, REMOTE_RX_BLOCK);
	state->tx_lo_hz = get_block_mixer_hz(&dev->rfdc, XRFDC_DAC_TILE, REMOTE_TX_TILE, REMOTE_TX_BLOCK);
}

static u64 handle_readback(struct app_rfdc_device *dev, const struct remote_state *state, u32 selector)
{
	(void)dev;

	switch (selector) {
	case APP_RFDC_RB_GET_RX_CH1_GAIN_ADDR:
		return state->rx_gain;
	case APP_RFDC_RB_GET_TX_CH1_GAIN_ADDR:
		return state->tx_gain;
	case APP_RFDC_RB_GET_SAMPLE_CLOCK_RATE_ADDR:
		return state->sample_rate_hz;
	case APP_RFDC_RB_GET_ACTIVE_CHANNEL_ADDR:
		return state->channel_enable;
	case APP_RFDC_RB_GET_RX_CH1_LO_FREQ_LOW_ADDR:
		return (u32)(state->rx_lo_hz & 0xffffffffU);
	case APP_RFDC_RB_GET_RX_CH1_LO_FREQ_HIGH_ADDR:
		return (u32)(state->rx_lo_hz >> 32);
	case APP_RFDC_RB_GET_TX_CH1_LO_FREQ_LOW_ADDR:
		return (u32)(state->tx_lo_hz & 0xffffffffU);
	case APP_RFDC_RB_GET_TX_CH1_LO_FREQ_HIGH_ADDR:
		return (u32)(state->tx_lo_hz >> 32);
	case APP_RFDC_RB_GET_VITA_TIME_ADDR:
	case APP_RFDC_RB_GET_VITA_TIME_LAST_PPS_ADDR:
		return UINT64_MAX;
	default:
		return UINT64_MAX;
	}
}

static u64 handle_set_command(struct app_rfdc_device *dev, struct remote_state *state, u32 addr, u32 data)
{
	u64 freq_hz = 0;

	switch (addr) {
	case APP_RFDC_SET_CMD_PORT:
	case APP_RFDC_SET_DATA_PORT:
		return 0;
	case APP_RFDC_SET_CHANNEL_ENABLE_ADDR:
	case APP_RFDC_SET_ACTIVE_CHANNEL_ADDR:
		state->channel_enable = data;
		printf("[ctrl] channel_enable <= 0x%08x\n", data);
		return 0;
	case APP_RFDC_SET_SAMPLE_CLOCK_RATE_ADDR:
	case APP_RFDC_SET_SAMPLE_RATE_DY_ADDR:
		state->sample_rate_hz = data;
		printf("[ctrl] sample_rate_hz <= %u\n", data);
		return state->sample_rate_hz;
	case APP_RFDC_SET_RX_CH1_GAIN_ADDR:
		state->rx_gain = data;
		return 0;
	case APP_RFDC_SET_TX_CH1_GAIN_ADDR:
		state->tx_gain = data;
		return 0;
	case APP_RFDC_SET_TIME_MODE_ADDR:
	case APP_RFDC_SET_VITA_TIMESTAMP_LOW_ADDR:
	case APP_RFDC_SET_VITA_TIMESTAMP_HIGH_ADDR:
	case APP_RFDC_SET_RX_SAMPLE_NUMS_ADDR:
	case APP_RFDC_SET_CAPTURE_START_ADDR:
	case APP_RFDC_SET_RX_MODE_ADDR:
	case APP_RFDC_SET_RX_MODE_EXIT_ADDR:
	case APP_RFDC_SET_STOP_RX_ADDR:
	case APP_RFDC_SET_RX_STREAM_START_ADDR:
	case APP_RFDC_SET_START_RX_ADDR:
	case APP_RFDC_SET_RX_MAX_PACKET_BYTES_ADDR:
		return UINT64_MAX;
	case APP_RFDC_SET_RX_CH1_LO_FREQ_LOW_ADDR:
		state->pending_rx_lo_low = data;
		state->pending_rx_lo_valid = true;
		return 0;
	case APP_RFDC_SET_RX_CH1_LO_FREQ_HIGH_ADDR:
		if (!state->pending_rx_lo_valid)
			return UINT64_MAX;
		freq_hz = ((u64)data << 32) | state->pending_rx_lo_low;
		if (set_if_frequency(dev,
				     XRFDC_ADC_TILE,
				     REMOTE_RX_TILE,
				     REMOTE_RX_BLOCK,
				     hz_to_mhz(freq_hz))
		    != 0)
			return UINT64_MAX;
		state->rx_lo_hz = freq_hz;
		state->pending_rx_lo_valid = false;
		return 0;
	case APP_RFDC_SET_TX_CH1_LO_FREQ_LOW_ADDR:
		state->pending_tx_lo_low = data;
		state->pending_tx_lo_valid = true;
		return 0;
	case APP_RFDC_SET_TX_CH1_LO_FREQ_HIGH_ADDR:
		if (!state->pending_tx_lo_valid)
			return UINT64_MAX;
		freq_hz = ((u64)data << 32) | state->pending_tx_lo_low;
		if (set_if_frequency(dev,
				     XRFDC_DAC_TILE,
				     REMOTE_TX_TILE,
				     REMOTE_TX_BLOCK,
				     hz_to_mhz(freq_hz))
		    != 0)
			return UINT64_MAX;
		state->tx_lo_hz = freq_hz;
		state->pending_tx_lo_valid = false;
		return 0;
	default:
		return UINT64_MAX;
	}
}

static u64 handle_set_command64(struct app_rfdc_device *dev, struct remote_state *state, u32 addr, u64 value)
{
	switch (addr) {
	case APP_FNIC_REG_SET_RX_LO_HZ:
		if (set_if_frequency(dev,
				     XRFDC_ADC_TILE,
				     REMOTE_RX_TILE,
				     REMOTE_RX_BLOCK,
				     hz_to_mhz(value))
		    != 0)
			return UINT64_MAX;
		state->rx_lo_hz = value;
		state->pending_rx_lo_valid = false;
		return 0;
	case APP_FNIC_REG_SET_TX_LO_HZ:
		if (set_if_frequency(dev,
				     XRFDC_DAC_TILE,
				     REMOTE_TX_TILE,
				     REMOTE_TX_BLOCK,
				     hz_to_mhz(value))
		    != 0)
			return UINT64_MAX;
		state->tx_lo_hz = value;
		state->pending_tx_lo_valid = false;
		return 0;
	default:
		return handle_set_command(dev, state, addr, (u32)(value & 0xffffffffU));
	}
}

static u64 handle_readback64(struct app_rfdc_device *dev, const struct remote_state *state, u32 selector)
{
	switch (selector) {
	case APP_RFDC_RB_GET_RX_CH1_LO_FREQ_LOW_ADDR:
	case APP_RFDC_RB_GET_RX_CH1_LO_FREQ_HIGH_ADDR:
	case APP_FNIC_REG_SET_RX_LO_HZ:
		return state->rx_lo_hz;
	case APP_RFDC_RB_GET_TX_CH1_LO_FREQ_LOW_ADDR:
	case APP_RFDC_RB_GET_TX_CH1_LO_FREQ_HIGH_ADDR:
	case APP_FNIC_REG_SET_TX_LO_HZ:
		return state->tx_lo_hz;
	default:
		return handle_readback(dev, state, selector);
	}
}

static void mailbox_set_value64(struct app_mailbox_resp *resp, u64 value)
{
	resp->data0 = (u32)(value & 0xffffffffU);
	resp->data1 = (u32)(value >> 32);
	resp->data2 = 0;
}

static void handle_mailbox_cmd(
	struct app_rfdc_device *dev,
	struct remote_state *state,
	const struct app_mailbox_cmd *cmd,
	struct app_mailbox_resp *resp)
{
	u64 value = ((u64)cmd->arg2 << 32) | cmd->arg1;
	u64 result = 0;

	memset(resp, 0, sizeof(*resp));
	resp->seq = cmd->seq;
	resp->status = APP_FNIC_STATUS_OK;
	resp->data3 = (cmd->arg3 >> 16) != 0U ? (cmd->arg3 >> 16) : (cmd->op & 0xffffU);

	switch (cmd->op) {
	case APP_FNIC_CMD_NOP:
		break;
	case APP_FNIC_CMD_PING:
		resp->data0 = cmd->arg0;
		resp->data1 = 0x504f4e47U;
		break;
	case APP_FNIC_CMD_GET_VERSION:
		resp->data0 = APP_FNIC_PROTOCOL_VERSION;
		resp->data1 = APP_FNIC_BUILD_ID;
		break;
	case APP_FNIC_CMD_WRITE_REG:
		result = handle_set_command64(dev, state, cmd->arg0, value);
		if (result == UINT64_MAX) {
			resp->status = APP_FNIC_STATUS_DENIED;
		} else {
			mailbox_set_value64(resp, result);
		}
		break;
	case APP_FNIC_CMD_READ_REG:
		result = handle_readback64(dev, state, cmd->arg0);
		if (result == UINT64_MAX) {
			resp->status = APP_FNIC_STATUS_DENIED;
		} else {
			mailbox_set_value64(resp, result);
		}
		break;
	case APP_FNIC_CMD_SET_RX_FREQ:
		result = handle_set_command64(dev, state, APP_FNIC_REG_SET_RX_LO_HZ, value);
		if (result == UINT64_MAX)
			resp->status = APP_FNIC_STATUS_DENIED;
		else
			mailbox_set_value64(resp, state->rx_lo_hz);
		break;
	case APP_FNIC_CMD_GET_RX_FREQ:
		mailbox_set_value64(resp, state->rx_lo_hz);
		break;
	case APP_FNIC_CMD_SET_TX_FREQ:
		result = handle_set_command64(dev, state, APP_FNIC_REG_SET_TX_LO_HZ, value);
		if (result == UINT64_MAX)
			resp->status = APP_FNIC_STATUS_DENIED;
		else
			mailbox_set_value64(resp, state->tx_lo_hz);
		break;
	case APP_FNIC_CMD_GET_TX_FREQ:
		mailbox_set_value64(resp, state->tx_lo_hz);
		break;
	default:
		resp->status = APP_FNIC_STATUS_BAD_CMD;
		break;
	}
}

static int run_mailbox_server(struct app_rfdc_device *dev, const struct app_args *args)
{
	struct app_mailbox mailbox = {0};
	struct remote_state state;
	uint32_t mailbox_id = 0;
	int ret = 0;

	init_remote_state(&state, dev);

	if (app_mailbox_init(&mailbox, args->mailbox_base, APP_MAILBOX_REGION_SIZE) != 0)
		return -1;

	if (app_mailbox_peek(&mailbox, APP_MAILBOX_REG_MAILBOX_ID, &mailbox_id) != 0
	    || mailbox_id != APP_MAILBOX_ID) {
		fprintf(stderr,
			"mailbox id mismatch at 0x%08x: read 0x%08x expected 0x%08x\n",
			args->mailbox_base,
			mailbox_id,
			APP_MAILBOX_ID);
		app_mailbox_close(&mailbox);
		return -1;
	}

	(void)app_mailbox_poke(&mailbox,
			       APP_MAILBOX_REG_CONTROL,
			       APP_MAILBOX_CTRL_CLEAR_OVERFLOW | APP_MAILBOX_CTRL_RESP_ACK_SW);

	printf("RFDC mailbox server polling base=0x%08x id=0x%08x\n",
	       args->mailbox_base,
	       mailbox_id);
	printf("Initial RX LO=%llu Hz TX LO=%llu Hz sample_rate=%u Hz\n",
	       (unsigned long long)state.rx_lo_hz,
	       (unsigned long long)state.tx_lo_hz,
	       state.sample_rate_hz);

	while (!g_stop) {
		struct app_mailbox_cmd cmd = {0};
		struct app_mailbox_resp resp = {0};
		uint32_t status = 0;

		if (app_mailbox_peek(&mailbox, APP_MAILBOX_REG_STATUS, &status) != 0) {
			fprintf(stderr, "failed to read mailbox status\n");
			ret = -1;
			break;
		}

		if ((status & APP_MAILBOX_STATUS_CMD_OVERFLOW) != 0U) {
			fprintf(stderr, "mailbox command overflow latched, clearing\n");
			(void)app_mailbox_poke(&mailbox,
					       APP_MAILBOX_REG_CONTROL,
					       APP_MAILBOX_CTRL_CLEAR_OVERFLOW);
		}

		if ((status & APP_MAILBOX_STATUS_CMD_VALID) == 0U) {
			usleep(1000);
			continue;
		}

		if (app_mailbox_read_cmd(&mailbox, &cmd) != 0) {
			fprintf(stderr, "failed to read mailbox command\n");
			ret = -1;
			break;
		}

		if (app_mailbox_poke(&mailbox, APP_MAILBOX_REG_CONTROL, APP_MAILBOX_CTRL_CMD_ACK) != 0) {
			fprintf(stderr, "failed to ack mailbox command\n");
			ret = -1;
			break;
		}

		printf("[mbox-rx] seq=%u op=0x%08x arg0=0x%08x arg1=0x%08x arg2=0x%08x arg3=0x%08x\n",
		       cmd.seq,
		       cmd.op,
		       cmd.arg0,
		       cmd.arg1,
		       cmd.arg2,
		       cmd.arg3);

		handle_mailbox_cmd(dev, &state, &cmd, &resp);

		if (app_mailbox_write_resp(&mailbox, &resp) != 0) {
			fprintf(stderr, "failed to write mailbox response\n");
			ret = -1;
			break;
		}

		printf("[mbox-tx] seq=%u status=0x%08x data0=0x%08x data1=0x%08x\n",
		       resp.seq,
		       resp.status,
		       resp.data0,
		       resp.data1);
	}

	app_mailbox_close(&mailbox);
	return ret == 0 ? 0 : -1;
}

int main(int argc, char **argv)
{
	struct app_args args;
	struct app_rfdc_device dev;
	XRFdc_Config config;
	int rc = 0;

	if (parse_args(argc, argv, &args) != 0) {
		usage(argv[0]);
		return 1;
	}

	if (!args.skip_lmk_init) {
		if (init_lmk04828(&args) != 0)
			return 1;
	} else {
		printf("Skipping LMK04828 initialization\n");
	}

	if (app_rfdc_lookup_config(&config, RFDC_DEVICE_ID, args.dt_root) != 0)
		return 1;

	if (app_rfdc_initialize(&dev, &config) != 0)
		return 1;

	if (app_rfdc_apply_default_profile(&dev) != 0) {
		app_rfdc_close(&dev);
		return 1;
	}

	if (!args.no_dump)
		dump_rfdc(&dev.rfdc);

	if (args.set_freq) {
		if (set_if_frequency(&dev, args.type, args.tile, args.block, args.freq_mhz) != 0) {
			app_rfdc_close(&dev);
			return 1;
		}
		dump_block(&dev.rfdc, args.type, args.tile, args.block);
	}

	if (args.mailbox_server_mode) {
		signal(SIGINT, signal_handler);
		signal(SIGTERM, signal_handler);
		rc = run_mailbox_server(&dev, &args);
	}

	app_rfdc_close(&dev);
	return rc == 0 ? 0 : 1;
}
