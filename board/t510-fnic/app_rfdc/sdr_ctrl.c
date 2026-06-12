#include "sdr_ctrl.h"

#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <unistd.h>

static uint32_t resolve_base_addr(uint32_t default_base_addr)
{
    const char *env = getenv("APP_RFDC_CTRL_BASE_ADDR");
    char *end = NULL;
    unsigned long value;

    if (env == NULL || *env == '\0')
        return default_base_addr;

    errno = 0;
    value = strtoul(env, &end, 0);
    if (errno != 0 || end == env || *end != '\0' || value > 0xffffffffUL) {
        fprintf(stderr, "invalid APP_RFDC_CTRL_BASE_ADDR='%s', fallback to 0x%08x\n",
                env, default_base_addr);
        return default_base_addr;
    }

    return (uint32_t)value;
}

int app_sdr_ctrl_init(struct app_sdr_ctrl *ctrl, uint32_t base_addr, uint32_t reg_len)
{
    int fd_mem;
    void *map_base;

    if (ctrl == NULL)
        return -EINVAL;

    memset(ctrl, 0, sizeof(*ctrl));
    ctrl->fd_mem = -1;
    ctrl->mem_start = resolve_base_addr(base_addr);

    fd_mem = open("/dev/mem", O_RDWR | O_SYNC);
    if (fd_mem < 0) {
        perror("open /dev/mem failed");
        return -1;
    }

    map_base = mmap(NULL, reg_len, PROT_READ | PROT_WRITE, MAP_SHARED, fd_mem, ctrl->mem_start);
    if (map_base == MAP_FAILED) {
        perror("mmap failed");
        close(fd_mem);
        return -1;
    }

    ctrl->fd_mem = fd_mem;
    ctrl->mem_len = reg_len;
    ctrl->map_base = (volatile uint32_t *)map_base;
    return 0;
}

void app_sdr_ctrl_close(struct app_sdr_ctrl *ctrl)
{
    if (ctrl == NULL)
        return;

    if (ctrl->map_base != NULL && ctrl->mem_len != 0U)
        munmap((void *)ctrl->map_base, ctrl->mem_len);

    if (ctrl->fd_mem >= 0)
        close(ctrl->fd_mem);

    memset(ctrl, 0, sizeof(*ctrl));
    ctrl->fd_mem = -1;
}

int app_sdr_ctrl_peek(struct app_sdr_ctrl *ctrl, uint32_t reg, uint32_t *value)
{
    if (ctrl == NULL || value == NULL || ctrl->map_base == NULL)
        return -EINVAL;

    if ((reg & 0x3U) != 0U || reg >= ctrl->mem_len)
        return -EINVAL;

    *value = *(ctrl->map_base + reg / 4U);
    return 0;
}

int app_sdr_ctrl_poke(struct app_sdr_ctrl *ctrl, uint32_t reg, uint32_t value)
{
    if (ctrl == NULL || ctrl->map_base == NULL)
        return -EINVAL;

    if ((reg & 0x3U) != 0U || reg >= ctrl->mem_len)
        return -EINVAL;

    *(ctrl->map_base + reg / 4U) = value;
    return 0;
}

uint64_t app_sdr_ctrl_get_vita_time(struct app_sdr_ctrl *ctrl)
{
    uint32_t low = 0;
    uint32_t high = 0;

    if (app_sdr_ctrl_poke(ctrl, APP_RFDC_CTRL_REG_GET_VITA_TIME_STROBE, 1U) != 0)
        return UINT64_MAX;
    if (app_sdr_ctrl_peek(ctrl, APP_RFDC_CTRL_REG_GET_VITA_TIME_LOW, &low) != 0)
        return UINT64_MAX;
    if (app_sdr_ctrl_peek(ctrl, APP_RFDC_CTRL_REG_GET_VITA_TIME_HIGH, &high) != 0)
        return UINT64_MAX;

    return ((uint64_t)high << 32) | low;
}

uint64_t app_sdr_ctrl_get_vita_time_last_pps(struct app_sdr_ctrl *ctrl)
{
    uint32_t low = 0;
    uint32_t high = 0;

    if (app_sdr_ctrl_poke(ctrl, APP_RFDC_CTRL_REG_GET_VITA_TIME_LAST_PPS_STROBE, 1U) != 0)
        return UINT64_MAX;
    if (app_sdr_ctrl_peek(ctrl, APP_RFDC_CTRL_REG_GET_VITA_TIME_LAST_PPS_LOW, &low) != 0)
        return UINT64_MAX;
    if (app_sdr_ctrl_peek(ctrl, APP_RFDC_CTRL_REG_GET_VITA_TIME_LAST_PPS_HIGH, &high) != 0)
        return UINT64_MAX;

    return ((uint64_t)high << 32) | low;
}

int app_sdr_ctrl_set_vita_timestamp(struct app_sdr_ctrl *ctrl, uint64_t value)
{
    if (app_sdr_ctrl_poke(ctrl, APP_RFDC_CTRL_REG_SET_VITA_TIME_LOW, (uint32_t)value) != 0)
        return -1;
    return app_sdr_ctrl_poke(ctrl, APP_RFDC_CTRL_REG_SET_VITA_TIME_HIGH, (uint32_t)(value >> 32));
}

int app_sdr_ctrl_set_time_mode(struct app_sdr_ctrl *ctrl, uint32_t value)
{
    if (app_sdr_ctrl_poke(ctrl, APP_RFDC_CTRL_REG_SET_TIME_MODE, value & 0x7U) != 0)
        return -1;
    return app_sdr_ctrl_poke(ctrl, APP_RFDC_CTRL_REG_SET_TIME_MODE_STROBE, 1U);
}

int app_sdr_ctrl_set_rx_sample_nums(struct app_sdr_ctrl *ctrl, uint32_t value)
{
    return app_sdr_ctrl_poke(ctrl, APP_RFDC_CTRL_REG_SET_RX_SAMPLE_NUMS, value);
}

int app_sdr_ctrl_set_packet_capture_start(struct app_sdr_ctrl *ctrl, uint32_t value)
{
    return app_sdr_ctrl_poke(ctrl, APP_RFDC_CTRL_REG_SET_CAPTURE_ONE_BLOCK, value);
}

int app_sdr_ctrl_set_rx_mode(struct app_sdr_ctrl *ctrl, uint32_t value)
{
    if (app_sdr_ctrl_poke(ctrl, APP_RFDC_CTRL_REG_SET_RX_MODE, value & 0x3U) != 0)
        return -1;
    return app_sdr_ctrl_poke(ctrl, APP_RFDC_CTRL_REG_SET_RX_MODE_STROBE, 1U);
}

int app_sdr_ctrl_set_rx_mode_exit(struct app_sdr_ctrl *ctrl)
{
    return app_sdr_ctrl_poke(ctrl, APP_RFDC_CTRL_REG_SET_RX_MODE_EXIT, 1U);
}

int app_sdr_ctrl_set_rx_stream_start(struct app_sdr_ctrl *ctrl)
{
    return app_sdr_ctrl_poke(ctrl, APP_RFDC_CTRL_REG_SET_RX_STREAM_START, 1U);
}

int app_sdr_ctrl_set_channel_enable(struct app_sdr_ctrl *ctrl, uint32_t value)
{
    return app_sdr_ctrl_poke(ctrl, APP_RFDC_CTRL_REG_SET_CHANNEL_ENABLE, value);
}

int app_sdr_ctrl_set_rx_max_packet_bytes(struct app_sdr_ctrl *ctrl, uint32_t value)
{
    return app_sdr_ctrl_poke(ctrl, APP_RFDC_CTRL_REG_SET_RX_MAX_PACKET_BYTES, value);
}
