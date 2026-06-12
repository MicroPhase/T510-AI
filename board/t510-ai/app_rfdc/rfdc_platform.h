#ifndef APP_RFDC_PLATFORM_H_
#define APP_RFDC_PLATFORM_H_

#include <stdbool.h>
#include <stddef.h>

#include <metal/io.h>
#include <xrfdc.h>

#define APP_RFDC_DEFAULT_DT_ROOT "/sys/firmware/devicetree/base"
#define APP_RFDC_DEFAULT_NODE_RELATIVE "amba_pl@0/usp_rf_data_converter@a0040000"
#define APP_RFDC_DEFAULT_BASE_SAMPLE_HZ 245760000ULL
#define APP_RFDC_DEFAULT_ADC_NCO_FREQ_MHZ 1500.0
#define APP_RFDC_DEFAULT_DAC_NCO_FREQ_MHZ 1500.0
#define APP_RFDC_DEFAULT_DAC_VOP_UA 40500U
#define APP_RFDC_DEFAULT_ADC_DSA_ATTENUATION_DB 0.0

struct app_rfdc_device {
	XRFdc rfdc;
	XRFdc_Config config;
	struct metal_io_region io;
	metal_phys_addr_t physmap[1];
	void *map_base;
	size_t map_size;
	int mem_fd;
	bool metal_ready;
};

int app_rfdc_lookup_config(XRFdc_Config *config, u16 device_id, const char *dt_root);
int app_rfdc_initialize(struct app_rfdc_device *dev, const XRFdc_Config *config);
int app_rfdc_apply_default_profile(struct app_rfdc_device *dev);
int app_rfdc_get_default_sample_rate_hz(struct app_rfdc_device *dev, u64 *sample_rate_hz);
int app_rfdc_set_nco_frequency(
	struct app_rfdc_device *dev, u32 type, u32 tile, u32 block, double freq_mhz);
int app_rfdc_set_if_frequency(
	struct app_rfdc_device *dev, u32 type, u32 tile, u32 block, double if_freq_mhz);
int app_rfdc_read_reg32(struct app_rfdc_device *dev, u32 reg_offset, u32 *value);
int app_rfdc_write_reg32(struct app_rfdc_device *dev, u32 reg_offset, u32 value);
void app_rfdc_close(struct app_rfdc_device *dev);

#endif
