#ifndef APP_RFDC_SDR_CTRL_H_
#define APP_RFDC_SDR_CTRL_H_

#include <stdint.h>

#define APP_RFDC_DEFAULT_CTRL_BASE_ADDR 0xA00C0000U
#define APP_RFDC_CTRL_REGION_SIZE 0x1000U

#define APP_RFDC_CTRL_REG(idx) ((uint32_t)(idx) * 4U)
#define APP_RFDC_CTRL_REG_GET_VITA_TIME_STROBE APP_RFDC_CTRL_REG(0U)
#define APP_RFDC_CTRL_REG_GET_VITA_TIME_LOW APP_RFDC_CTRL_REG(0U)
#define APP_RFDC_CTRL_REG_GET_VITA_TIME_HIGH APP_RFDC_CTRL_REG(1U)
#define APP_RFDC_CTRL_REG_GET_VITA_TIME_LAST_PPS_STROBE APP_RFDC_CTRL_REG(2U)
#define APP_RFDC_CTRL_REG_GET_VITA_TIME_LAST_PPS_LOW APP_RFDC_CTRL_REG(2U)
#define APP_RFDC_CTRL_REG_GET_VITA_TIME_LAST_PPS_HIGH APP_RFDC_CTRL_REG(3U)
#define APP_RFDC_CTRL_REG_SET_VITA_TIME_LOW APP_RFDC_CTRL_REG(4U)
#define APP_RFDC_CTRL_REG_SET_VITA_TIME_HIGH APP_RFDC_CTRL_REG(5U)
#define APP_RFDC_CTRL_REG_SET_TIME_MODE APP_RFDC_CTRL_REG(6U)
#define APP_RFDC_CTRL_REG_SET_TIME_MODE_STROBE APP_RFDC_CTRL_REG(7U)
#define APP_RFDC_CTRL_REG_SET_RX_SAMPLE_NUMS APP_RFDC_CTRL_REG(10U)
#define APP_RFDC_CTRL_REG_SET_CAPTURE_ONE_BLOCK APP_RFDC_CTRL_REG(11U)
#define APP_RFDC_CTRL_REG_SET_RX_MODE APP_RFDC_CTRL_REG(14U)
#define APP_RFDC_CTRL_REG_SET_RX_MODE_STROBE APP_RFDC_CTRL_REG(15U)
#define APP_RFDC_CTRL_REG_SET_RX_MODE_EXIT APP_RFDC_CTRL_REG(16U)
#define APP_RFDC_CTRL_REG_SET_RX_STREAM_START APP_RFDC_CTRL_REG(17U)
#define APP_RFDC_CTRL_REG_SET_CHANNEL_ENABLE APP_RFDC_CTRL_REG(18U)
#define APP_RFDC_CTRL_REG_SET_RX_MAX_PACKET_BYTES APP_RFDC_CTRL_REG(27U)

struct app_sdr_ctrl {
    uint32_t mem_start;
    int fd_mem;
    uint32_t mem_len;
    volatile uint32_t *map_base;
};

int app_sdr_ctrl_init(struct app_sdr_ctrl *ctrl, uint32_t base_addr, uint32_t reg_len);
void app_sdr_ctrl_close(struct app_sdr_ctrl *ctrl);
int app_sdr_ctrl_peek(struct app_sdr_ctrl *ctrl, uint32_t reg, uint32_t *value);
int app_sdr_ctrl_poke(struct app_sdr_ctrl *ctrl, uint32_t reg, uint32_t value);

uint64_t app_sdr_ctrl_get_vita_time(struct app_sdr_ctrl *ctrl);
uint64_t app_sdr_ctrl_get_vita_time_last_pps(struct app_sdr_ctrl *ctrl);

int app_sdr_ctrl_set_vita_timestamp(struct app_sdr_ctrl *ctrl, uint64_t value);
int app_sdr_ctrl_set_time_mode(struct app_sdr_ctrl *ctrl, uint32_t value);
int app_sdr_ctrl_set_rx_sample_nums(struct app_sdr_ctrl *ctrl, uint32_t value);
int app_sdr_ctrl_set_packet_capture_start(struct app_sdr_ctrl *ctrl, uint32_t value);
int app_sdr_ctrl_set_rx_mode(struct app_sdr_ctrl *ctrl, uint32_t value);
int app_sdr_ctrl_set_rx_mode_exit(struct app_sdr_ctrl *ctrl);
int app_sdr_ctrl_set_rx_stream_start(struct app_sdr_ctrl *ctrl);
int app_sdr_ctrl_set_channel_enable(struct app_sdr_ctrl *ctrl, uint32_t value);
int app_sdr_ctrl_set_rx_max_packet_bytes(struct app_sdr_ctrl *ctrl, uint32_t value);

#endif
