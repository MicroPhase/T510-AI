#include "app_gpio.h"

#include <ctype.h>
#include <errno.h>
#include <fcntl.h>
#include <linux/gpio.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <unistd.h>

#define APP_GPIO_MAX_CHIPS 32
#define APP_GPIO_DEFAULT_CHIP_HINT "zynqmp_gpio"

static int app_gpio_open_chip_for_offset(unsigned int offset, char *chip_path, size_t chip_path_size)
{
	const char *override_path = getenv("APP_RFDC_GPIOCHIP");
	int fallback_fd = -1;
	char fallback_path[64] = {0};
	int idx;

	if (override_path != NULL && override_path[0] != '\0') {
		int fd = open(override_path, O_RDONLY);
		if (fd < 0)
			return -errno;
		snprintf(chip_path, chip_path_size, "%s", override_path);
		return fd;
	}

	for (idx = 0; idx < APP_GPIO_MAX_CHIPS; ++idx) {
		char path[64];
		struct gpiochip_info info = {0};
		int fd;

		snprintf(path, sizeof(path), "/dev/gpiochip%d", idx);
		fd = open(path, O_RDONLY);
		if (fd < 0)
			continue;

		if (ioctl(fd, GPIO_GET_CHIPINFO_IOCTL, &info) < 0) {
			close(fd);
			continue;
		}

		if (info.lines <= offset) {
			close(fd);
			continue;
		}

		if (strstr(info.label, APP_GPIO_DEFAULT_CHIP_HINT) != NULL
		    || strstr(info.name, APP_GPIO_DEFAULT_CHIP_HINT) != NULL) {
			snprintf(chip_path, chip_path_size, "%s", path);
			return fd;
		}

		if (fallback_fd < 0) {
			fallback_fd = fd;
			snprintf(fallback_path, sizeof(fallback_path), "%s", path);
			continue;
		}

		close(fd);
	}

	if (fallback_fd >= 0) {
		snprintf(chip_path, chip_path_size, "%s", fallback_path);
		return fallback_fd;
	}

	return -ENOENT;
}

int app_gpio_open_output(struct app_gpio_line *line, unsigned int number, int initial_value)
{
	struct gpiohandle_request req = {0};
	int chip_fd;

	if (line == NULL)
		return -EINVAL;

	memset(line, 0, sizeof(*line));
	line->offset = number;
	line->line_fd = -1;

	chip_fd = app_gpio_open_chip_for_offset(number, line->chip_path, sizeof(line->chip_path));
	if (chip_fd < 0)
		return chip_fd;

	req.lines = 1;
	req.lineoffsets[0] = number;
	req.flags = GPIOHANDLE_REQUEST_OUTPUT;
	req.default_values[0] = initial_value ? 1 : 0;
	snprintf(req.consumer_label, sizeof(req.consumer_label), "app_rfdc");

	if (ioctl(chip_fd, GPIO_GET_LINEHANDLE_IOCTL, &req) < 0) {
		int ret = -errno;
		close(chip_fd);
		return ret;
	}

	close(chip_fd);
	line->line_fd = req.fd;
	return 0;
}

int app_gpio_set_value(struct app_gpio_line *line, int value)
{
	struct gpiohandle_data data = {0};

	if (line == NULL || line->line_fd < 0)
		return -EINVAL;

	data.values[0] = value ? 1 : 0;
	if (ioctl(line->line_fd, GPIOHANDLE_SET_LINE_VALUES_IOCTL, &data) < 0)
		return -errno;

	return 0;
}

int app_gpio_close(struct app_gpio_line *line)
{
	if (line == NULL)
		return -EINVAL;

	if (line->line_fd >= 0)
		close(line->line_fd);

	memset(line, 0, sizeof(*line));
	line->line_fd = -1;
	return 0;
}
