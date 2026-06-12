#include "rfdc_platform.h"

#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <math.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>

#include <metal/log.h>
#include <metal/sys.h>

#define APP_RFDC_COMPAT_PREFIX "xlnx,usp-rf-data-converter-"

static int app_rfdc_block_is_enabled(struct app_rfdc_device *dev, u32 type, u32 tile, u32 block)
{
	if (XRFdc_CheckTileEnabled(&dev->rfdc, type, tile) != XRFDC_SUCCESS)
		return 0;

	if (type == XRFDC_ADC_TILE)
		return XRFdc_IsADCBlockEnabled(&dev->rfdc, tile, block);

	return XRFdc_IsDACBlockEnabled(&dev->rfdc, tile, block);
}

static u32 app_rfdc_interp_decim_from_ratio(u32 ratio)
{
	switch (ratio) {
	case 1:
		return XRFDC_INTERP_DECIM_1X;
	case 2:
		return XRFDC_INTERP_DECIM_2X;
	case 3:
		return XRFDC_INTERP_DECIM_3X;
	case 4:
		return XRFDC_INTERP_DECIM_4X;
	case 5:
		return XRFDC_INTERP_DECIM_5X;
	case 6:
		return XRFDC_INTERP_DECIM_6X;
	case 8:
		return XRFDC_INTERP_DECIM_8X;
	case 10:
		return XRFDC_INTERP_DECIM_10X;
	case 12:
		return XRFDC_INTERP_DECIM_12X;
	case 16:
		return XRFDC_INTERP_DECIM_16X;
	case 20:
		return XRFDC_INTERP_DECIM_20X;
	case 24:
		return XRFDC_INTERP_DECIM_24X;
	case 40:
		return XRFDC_INTERP_DECIM_40X;
	default:
		return 0U;
	}
}

static int app_rfdc_get_first_enabled_tile_sample_rate_hz(
	struct app_rfdc_device *dev, u32 type, u64 *sample_rate_hz)
{
	u32 tile;

	if (sample_rate_hz == NULL)
		return -EINVAL;

	for (tile = 0; tile <= XRFDC_TILE_ID_MAX; ++tile) {
		XRFdc_PLL_Settings pll = {0};

		if (XRFdc_CheckTileEnabled(&dev->rfdc, type, tile) != XRFDC_SUCCESS)
			continue;

		if (XRFdc_GetPLLConfig(&dev->rfdc, type, tile, &pll) != XRFDC_SUCCESS)
			continue;

		if (pll.SampleRate > 0.0) {
			*sample_rate_hz = (u64)(pll.SampleRate * 1000000000.0 + 0.5);
			return 0;
		}
	}

	return -ENOENT;
}

int app_rfdc_set_nco_frequency(struct app_rfdc_device *dev, u32 type, u32 tile, u32 block, double freq_mhz)
{
	XRFdc_Mixer_Settings mixer = {0};
	u32 status;

	if (dev == NULL)
		return -EINVAL;

	if (!app_rfdc_block_is_enabled(dev, type, tile, block))
		return -ENODEV;

	status = XRFdc_GetMixerSettings(&dev->rfdc, type, tile, block, &mixer);
	if (status != XRFDC_SUCCESS)
		return -EIO;

	if (mixer.MixerType == XRFDC_MIXER_TYPE_DISABLED || mixer.MixerMode == XRFDC_MIXER_MODE_OFF)
		return -ENOTSUP;

	mixer.Freq = freq_mhz;
	mixer.EventSource = XRFDC_EVNT_SRC_TILE;

	status = XRFdc_SetMixerSettings(&dev->rfdc, type, tile, block, &mixer);
	if (status != XRFDC_SUCCESS)
		return -EIO;

	status = XRFdc_ResetNCOPhase(&dev->rfdc, type, tile, block);
	if (status != XRFDC_SUCCESS)
		return -EIO;

	status = XRFdc_UpdateEvent(&dev->rfdc, type, tile, block, XRFDC_EVENT_MIXER);
	if (status != XRFDC_SUCCESS)
		return -EIO;

	return 0;
}

static int app_rfdc_get_block_sample_rate_hz(
	struct app_rfdc_device *dev, u32 type, u32 tile, u32 block, double *sample_rate_hz)
{
	XRFdc_BlockStatus block_status = {0};
	u32 status;

	if (dev == NULL || sample_rate_hz == NULL)
		return -EINVAL;

	if (!app_rfdc_block_is_enabled(dev, type, tile, block))
		return -ENODEV;

	status = XRFdc_GetBlockStatus(&dev->rfdc, type, tile, block, &block_status);
	if (status != XRFDC_SUCCESS)
		return -EIO;

	*sample_rate_hz = block_status.SamplingFreq * 1000000000.0;
	return 0;
}

int app_rfdc_set_if_frequency(
	struct app_rfdc_device *dev, u32 type, u32 tile, u32 block, double if_freq_mhz)
{
	XRFdc_Mixer_Settings mixer = {0};
	double sample_rate_hz = 0.0;
	double nyquist_cutoff_hz = 0.0;
	double if_freq_hz = if_freq_mhz * 1000000.0;
	double requested_if_mhz = fabs(if_freq_mhz);
	double effective_nco_mhz = 0.0;
	u32 nyquist_zone;
	u32 mixer_mode;
	u32 status;
	int enable_inverse_sinc;

	if (dev == NULL)
		return -EINVAL;

	if (!app_rfdc_block_is_enabled(dev, type, tile, block))
		return -ENODEV;

	if (app_rfdc_get_block_sample_rate_hz(dev, type, tile, block, &sample_rate_hz) != 0)
		return -EIO;

	nyquist_cutoff_hz = sample_rate_hz / 2.0;

	if (if_freq_hz <= nyquist_cutoff_hz) {
		nyquist_zone = XRFDC_ODD_NYQUIST_ZONE;
		mixer_mode = (type == XRFDC_DAC_TILE) ? XRFDC_MIXER_MODE_C2R : XRFDC_MIXER_MODE_R2C;
		enable_inverse_sinc = 1;
	} else {
		nyquist_zone = XRFDC_EVEN_NYQUIST_ZONE;
		mixer_mode = (type == XRFDC_DAC_TILE) ? XRFDC_MIXER_MODE_C2R : XRFDC_MIXER_MODE_R2C;
		enable_inverse_sinc = 0;
	}

	/*
	 * PG269 "NCO Frequency Conversion":
	 * - Down conversion (ADC): even Nyquist bands use positive NCO, odd bands use negative NCO.
	 * - Up conversion (DAC): even Nyquist bands use negative NCO, odd bands use positive NCO.
	 *
	 * This keeps the original spectrum orientation without requiring an extra IQ swap stage.
	 */
	if (type == XRFDC_ADC_TILE) {
		effective_nco_mhz = (nyquist_zone == XRFDC_EVEN_NYQUIST_ZONE)
			? requested_if_mhz
			: -requested_if_mhz;
	} else {
		effective_nco_mhz = (nyquist_zone == XRFDC_EVEN_NYQUIST_ZONE)
			? -requested_if_mhz
			: requested_if_mhz;
	}

	status = XRFdc_SetNyquistZone(&dev->rfdc, type, tile, block, nyquist_zone);
	if (status != XRFDC_SUCCESS)
		return -EIO;

	status = XRFdc_GetMixerSettings(&dev->rfdc, type, tile, block, &mixer);
	if (status != XRFDC_SUCCESS)
		return -EIO;

	mixer.MixerMode = mixer_mode;
	mixer.MixerType = XRFDC_MIXER_TYPE_FINE;
	mixer.Freq = effective_nco_mhz;
	mixer.EventSource = XRFDC_EVNT_SRC_TILE;

	status = XRFdc_SetMixerSettings(&dev->rfdc, type, tile, block, &mixer);
	if (status != XRFDC_SUCCESS)
		return -EIO;

	if (type == XRFDC_DAC_TILE) {
		status = XRFdc_SetInvSincFIR(&dev->rfdc, tile, block, enable_inverse_sinc);
		if (status != XRFDC_SUCCESS)
			return -EIO;
	}

	status = XRFdc_ResetNCOPhase(&dev->rfdc, type, tile, block);
	if (status != XRFDC_SUCCESS)
		return -EIO;

	status = XRFdc_UpdateEvent(&dev->rfdc, type, tile, block, XRFDC_EVENT_MIXER);
	if (status != XRFDC_SUCCESS)
		return -EIO;

	return 0;
}

static int app_rfdc_apply_default_gain_profile(struct app_rfdc_device *dev)
{
	XRFdc_DSA_Settings dsa = {0};
	u32 tile;
	u32 block;

	dsa.DisableRTS = 1U;
	dsa.Attenuation = APP_RFDC_DEFAULT_ADC_DSA_ATTENUATION_DB;

	for (tile = 0; tile <= XRFDC_TILE_ID_MAX; ++tile) {
		for (block = 0; block <= XRFDC_BLOCK_ID_MAX; ++block) {
			if (app_rfdc_block_is_enabled(dev, XRFDC_DAC_TILE, tile, block)) {
				if (XRFdc_SetDACVOP(&dev->rfdc, tile, block, APP_RFDC_DEFAULT_DAC_VOP_UA) != XRFDC_SUCCESS) {
					fprintf(stderr, "XRFdc_SetDACVOP failed on DAC tile %u block %u\n", tile, block);
					return -1;
				}
			}

			if (app_rfdc_block_is_enabled(dev, XRFDC_ADC_TILE, tile, block)) {
				if (XRFdc_SetDSA(&dev->rfdc, tile, block, &dsa) != XRFDC_SUCCESS) {
					fprintf(stderr, "XRFdc_SetDSA failed on ADC tile %u block %u\n", tile, block);
					return -1;
				}
				if (XRFdc_SetDither(&dev->rfdc, tile, block, XRFDC_DITH_ENABLE) != XRFDC_SUCCESS) {
					fprintf(stderr, "XRFdc_SetDither failed on ADC tile %u block %u\n", tile, block);
					return -1;
				}
			}
		}
	}

	return 0;
}

static int app_rfdc_apply_default_nco_profile(
	struct app_rfdc_device *dev, u64 adc_sample_rate_hz, u64 dac_sample_rate_hz)
{
	u32 tile;
	u32 block;
	double adc_freq_mhz = APP_RFDC_DEFAULT_ADC_NCO_FREQ_MHZ;
	double dac_freq_mhz = APP_RFDC_DEFAULT_DAC_NCO_FREQ_MHZ;
	u32 adc_nyquist = 1U;
	u32 dac_nyquist = 1U;

	if (dac_sample_rate_hz != 0U
	    && (APP_RFDC_DEFAULT_DAC_NCO_FREQ_MHZ * 1000000.0) >= ((double)dac_sample_rate_hz / 2.0)) {
		dac_nyquist = 2U;
		dac_freq_mhz = -dac_freq_mhz;
	}

	if (adc_sample_rate_hz != 0U
	    && (APP_RFDC_DEFAULT_ADC_NCO_FREQ_MHZ * 1000000.0) < ((double)adc_sample_rate_hz / 2.0)) {
		adc_nyquist = 1U;
		adc_freq_mhz = -adc_freq_mhz;
	} else {
		adc_nyquist = 2U;
	}

	for (tile = 0; tile <= XRFDC_TILE_ID_MAX; ++tile) {
		for (block = 0; block <= XRFDC_BLOCK_ID_MAX; ++block) {
			if (app_rfdc_block_is_enabled(dev, XRFDC_DAC_TILE, tile, block)) {
				if (XRFdc_SetNyquistZone(&dev->rfdc, XRFDC_DAC_TILE, tile, block, dac_nyquist) != XRFDC_SUCCESS) {
					fprintf(stderr, "XRFdc_SetNyquistZone failed on DAC tile %u block %u\n", tile, block);
					return -1;
				}
				if (app_rfdc_set_nco_frequency(dev, XRFDC_DAC_TILE, tile, block, dac_freq_mhz) != 0) {
					fprintf(stderr, "failed to set DAC mixer on tile %u block %u\n", tile, block);
					return -1;
				}
			}

			if (app_rfdc_block_is_enabled(dev, XRFDC_ADC_TILE, tile, block)) {
				if (XRFdc_SetNyquistZone(&dev->rfdc, XRFDC_ADC_TILE, tile, block, adc_nyquist) != XRFDC_SUCCESS) {
					fprintf(stderr, "XRFdc_SetNyquistZone failed on ADC tile %u block %u\n", tile, block);
					return -1;
				}
				if (app_rfdc_set_nco_frequency(dev, XRFDC_ADC_TILE, tile, block, adc_freq_mhz) != 0) {
					fprintf(stderr, "failed to set ADC mixer on tile %u block %u\n", tile, block);
					return -1;
				}
			}
		}
	}

	return 0;
}

static int app_rfdc_apply_default_baseband_profile(struct app_rfdc_device *dev, u64 adc_sample_rate_hz)
{
	u32 tile;
	u32 block;
	u32 ratio;
	u32 factor;

	if (adc_sample_rate_hz == 0U)
		return 0;

	ratio = (u32)((adc_sample_rate_hz + (APP_RFDC_DEFAULT_BASE_SAMPLE_HZ / 2ULL))
		      / APP_RFDC_DEFAULT_BASE_SAMPLE_HZ);
	factor = app_rfdc_interp_decim_from_ratio(ratio);
	if (factor == 0U) {
		fprintf(stderr,
			"unsupported interpolation/decimation ratio %u for sample_rate=%llu base_rate=%llu\n",
			ratio,
			(unsigned long long)adc_sample_rate_hz,
			(unsigned long long)APP_RFDC_DEFAULT_BASE_SAMPLE_HZ);
		return -1;
	}

	for (tile = 0; tile <= XRFDC_TILE_ID_MAX; ++tile) {
		for (block = 0; block <= XRFDC_BLOCK_ID_MAX; ++block) {
			if (app_rfdc_block_is_enabled(dev, XRFDC_DAC_TILE, tile, block)) {
				if (XRFdc_SetInterpolationFactor(&dev->rfdc, tile, block, factor) != XRFDC_SUCCESS) {
					fprintf(stderr, "XRFdc_SetInterpolationFactor failed on DAC tile %u block %u\n", tile, block);
					return -1;
				}
			}
			if (app_rfdc_block_is_enabled(dev, XRFDC_ADC_TILE, tile, block)) {
				if (XRFdc_SetDecimationFactor(&dev->rfdc, tile, block, factor) != XRFDC_SUCCESS) {
					fprintf(stderr, "XRFdc_SetDecimationFactor failed on ADC tile %u block %u\n", tile, block);
					return -1;
				}
			}
		}
	}

	return 0;
}

static int app_rfdc_apply_default_qmc_profile(struct app_rfdc_device *dev)
{
	u32 tile;
	u32 block;

	for (tile = 0; tile <= XRFDC_TILE_ID_MAX; ++tile) {
		for (block = 0; block <= XRFDC_BLOCK_ID_MAX; ++block) {
			XRFdc_QMC_Settings qmc = {0};

			if (!app_rfdc_block_is_enabled(dev, XRFDC_ADC_TILE, tile, block))
				continue;

			if (XRFdc_GetQMCSettings(&dev->rfdc, XRFDC_ADC_TILE, tile, block, &qmc) != XRFDC_SUCCESS) {
				fprintf(stderr, "XRFdc_GetQMCSettings failed on ADC tile %u block %u\n", tile, block);
				return -1;
			}

			qmc.EnableGain = XRFDC_ENABLED;
			qmc.GainCorrectionFactor = 1.99;
			qmc.EventSource = XRFDC_EVNT_SRC_TILE;

			if (XRFdc_SetQMCSettings(&dev->rfdc, XRFDC_ADC_TILE, tile, block, &qmc) != XRFDC_SUCCESS) {
				fprintf(stderr, "XRFdc_SetQMCSettings failed on ADC tile %u block %u\n", tile, block);
				return -1;
			}
			if (XRFdc_UpdateEvent(&dev->rfdc, XRFDC_ADC_TILE, tile, block, XRFDC_EVENT_QMC) != XRFDC_SUCCESS) {
				fprintf(stderr, "XRFdc_UpdateEvent(QMC) failed on ADC tile %u block %u\n", tile, block);
				return -1;
			}
		}
	}

	return 0;
}

static int read_file_exact(const char *path, void *buf, size_t size)
{
	int fd;
	ssize_t len;
	size_t total = 0;

	fd = open(path, O_RDONLY);
	if (fd < 0)
		return -errno;

	while (total < size) {
		len = read(fd, (char *)buf + total, size - total);
		if (len < 0) {
			close(fd);
			return -errno;
		}
		if (len == 0)
			break;
		total += (size_t)len;
	}
	close(fd);

	return total == size ? 0 : -EINVAL;
}

static int read_file_prefix(const char *path, const char *prefix)
{
	char buf[128] = {0};
	int fd;
	ssize_t len;

	fd = open(path, O_RDONLY);
	if (fd < 0)
		return -errno;

	len = read(fd, buf, sizeof(buf) - 1);
	close(fd);
	if (len < 0)
		return -errno;
	if ((size_t)len < strlen(prefix))
		return -EINVAL;

	return strncmp(buf, prefix, strlen(prefix)) == 0 ? 0 : -EINVAL;
}

static int join_path(char *dst, size_t dst_size, const char *dir, const char *name)
{
	int len;

	len = snprintf(dst, dst_size, "%s/%s", dir, name);
	if (len < 0 || (size_t)len >= dst_size)
		return -ENAMETOOLONG;

	return 0;
}

static int load_rfdc_config_from_node(const char *node_path, XRFdc_Config *config)
{
	char compatible_path[PATH_MAX];
	char param_path[PATH_MAX];
	int ret;

	ret = join_path(compatible_path, sizeof(compatible_path), node_path, "compatible");
	if (ret != 0)
		return ret;

	ret = read_file_prefix(compatible_path, APP_RFDC_COMPAT_PREFIX);
	if (ret != 0)
		return ret;

	ret = join_path(param_path, sizeof(param_path), node_path, "param-list");
	if (ret != 0)
		return ret;

	memset(config, 0, sizeof(*config));
	return read_file_exact(param_path, config, sizeof(*config));
}

static int map_rfdc_registers(struct app_rfdc_device *dev)
{
	long page_size;
	uintptr_t page_mask;
	void *virt_base;
	off_t page_base;
	off_t page_offset;
	size_t map_size;
	void *map;

	page_size = sysconf(_SC_PAGESIZE);
	if (page_size <= 0)
		return -EINVAL;

	page_mask = (uintptr_t)page_size - 1U;
	page_base = (off_t)(dev->config.BaseAddr & ~((metal_phys_addr_t)page_mask));
	page_offset = (off_t)(dev->config.BaseAddr - page_base);
	map_size = (size_t)page_offset + XRFDC_REGION_SIZE;
	map_size = (map_size + (size_t)page_size - 1U) & ~((size_t)page_size - 1U);

	map = mmap(NULL, map_size, PROT_READ | PROT_WRITE, MAP_SHARED, dev->mem_fd, page_base);
	if (map == MAP_FAILED)
		return -errno;

	virt_base = (void *)((uintptr_t)map + (uintptr_t)page_offset);
	dev->map_base = map;
	dev->map_size = map_size;
	dev->physmap[0] = dev->config.BaseAddr;
	metal_io_init(&dev->io, virt_base, dev->physmap, XRFDC_REGION_SIZE, (unsigned int)-1, 0,
		      NULL);
	dev->rfdc.io = &dev->io;

	return 0;
}

int app_rfdc_lookup_config(XRFdc_Config *config, u16 device_id, const char *dt_root)
{
	char node_path[PATH_MAX];
	int ret;

	ret = join_path(node_path, sizeof(node_path), dt_root, APP_RFDC_DEFAULT_NODE_RELATIVE);
	if (ret != 0) {
		fprintf(stderr, "RFDC node path is too long\n");
		return -1;
	}

	ret = load_rfdc_config_from_node(node_path, config);
	if (ret != 0) {
		fprintf(stderr, "failed to load RFDC config from %s\n", node_path);
		return -1;
	}

	if (config->DeviceId != device_id) {
		fprintf(stderr, "RFDC node %s has device id %u, expected %u\n", node_path,
			config->DeviceId, device_id);
		return -1;
	}

	printf("RFDC config loaded from %s\n", node_path);
	return 0;
}

int app_rfdc_initialize(struct app_rfdc_device *dev, const XRFdc_Config *config)
{
	struct metal_init_params init_params = METAL_INIT_DEFAULTS;
	u32 status;
	int ret;

	memset(dev, 0, sizeof(*dev));
	dev->mem_fd = -1;
	dev->config = *config;

	metal_set_log_level(METAL_LOG_WARNING);
	if (metal_init(&init_params) != 0) {
		fprintf(stderr, "metal_init failed\n");
		return -1;
	}
	dev->metal_ready = true;

	dev->mem_fd = open("/dev/mem", O_RDWR | O_SYNC);
	if (dev->mem_fd < 0) {
		fprintf(stderr, "failed to open /dev/mem: %s\n", strerror(errno));
		return -1;
	}

	ret = map_rfdc_registers(dev);
	if (ret != 0) {
		fprintf(stderr, "failed to map RFDC registers at 0x%llx: %s\n",
			(unsigned long long)dev->config.BaseAddr, strerror(-ret));
		return -1;
	}

	status = XRFdc_CfgInitialize(&dev->rfdc, &dev->config);
	if (status != XRFDC_SUCCESS) {
		fprintf(stderr, "XRFdc_CfgInitialize failed\n");
		return -1;
	}

	dev->rfdc.UpdateMixerScale = 0;

	printf("RFDC base address: 0x%llx\n", (unsigned long long)dev->config.BaseAddr);
	return 0;
}

int app_rfdc_get_default_sample_rate_hz(struct app_rfdc_device *dev, u64 *sample_rate_hz)
{
	if (dev == NULL)
		return -EINVAL;

	return app_rfdc_get_first_enabled_tile_sample_rate_hz(dev, XRFDC_ADC_TILE, sample_rate_hz);
}

int app_rfdc_apply_default_profile(struct app_rfdc_device *dev)
{
	u32 tile;
	u64 adc_sample_rate_hz = 0;
	u64 dac_sample_rate_hz = 0;

	if (dev == NULL)
		return -EINVAL;

	for (tile = 0; tile <= XRFDC_TILE_ID_MAX; ++tile) {
		if (XRFdc_CheckTileEnabled(&dev->rfdc, XRFDC_DAC_TILE, tile) == XRFDC_SUCCESS) {
			if (XRFdc_Reset(&dev->rfdc, XRFDC_DAC_TILE, (int)tile) != XRFDC_SUCCESS) {
				fprintf(stderr, "XRFdc_Reset failed on DAC tile %u\n", tile);
				return -1;
			}
		}
		if (XRFdc_CheckTileEnabled(&dev->rfdc, XRFDC_ADC_TILE, tile) == XRFDC_SUCCESS) {
			if (XRFdc_Reset(&dev->rfdc, XRFDC_ADC_TILE, (int)tile) != XRFDC_SUCCESS) {
				fprintf(stderr, "XRFdc_Reset failed on ADC tile %u\n", tile);
				return -1;
			}
		}
	}

	(void)app_rfdc_get_first_enabled_tile_sample_rate_hz(dev, XRFDC_ADC_TILE, &adc_sample_rate_hz);
	(void)app_rfdc_get_first_enabled_tile_sample_rate_hz(dev, XRFDC_DAC_TILE, &dac_sample_rate_hz);

	printf("RFDC bring-up: adc_sample_rate=%llu Hz, dac_sample_rate=%llu Hz\n",
	       (unsigned long long)adc_sample_rate_hz,
	       (unsigned long long)dac_sample_rate_hz);

	if (app_rfdc_apply_default_gain_profile(dev) != 0)
		return -1;
	if (app_rfdc_apply_default_nco_profile(dev, adc_sample_rate_hz, dac_sample_rate_hz) != 0)
		return -1;
	if (app_rfdc_apply_default_baseband_profile(dev, adc_sample_rate_hz) != 0)
		return -1;
	if (app_rfdc_apply_default_qmc_profile(dev) != 0)
		return -1;

	return 0;
}

int app_rfdc_read_reg32(struct app_rfdc_device *dev, u32 reg_offset, u32 *value)
{
	XRFdc *instance = NULL;

	if (dev == NULL || value == NULL)
		return -EINVAL;

	if ((reg_offset & 0x3U) != 0U || reg_offset >= XRFDC_REGION_SIZE)
		return -EINVAL;

	instance = &dev->rfdc;
	*value = XRFdc_ReadReg(instance, XRFDC_IP_BASE, reg_offset);
	return 0;
}

int app_rfdc_write_reg32(struct app_rfdc_device *dev, u32 reg_offset, u32 value)
{
	XRFdc *instance = NULL;

	if (dev == NULL)
		return -EINVAL;

	if ((reg_offset & 0x3U) != 0U || reg_offset >= XRFDC_REGION_SIZE)
		return -EINVAL;

	instance = &dev->rfdc;
	XRFdc_WriteReg(instance, XRFDC_IP_BASE, reg_offset, value);
	return 0;
}

void app_rfdc_close(struct app_rfdc_device *dev)
{
	if (dev->rfdc.io != NULL) {
		metal_io_finish(dev->rfdc.io);
		dev->rfdc.io = NULL;
	}

	if (dev->map_base != NULL && dev->map_size != 0U)
		munmap(dev->map_base, dev->map_size);

	if (dev->mem_fd >= 0)
		close(dev->mem_fd);

	if (dev->metal_ready)
		metal_finish();
}
