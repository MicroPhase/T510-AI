#ifndef APP_GPIO_H_
#define APP_GPIO_H_

struct app_gpio_line {
	unsigned int offset;
	int line_fd;
	char chip_path[64];
};

int app_gpio_open_output(struct app_gpio_line *line, unsigned int number, int initial_value);
int app_gpio_set_value(struct app_gpio_line *line, int value);
int app_gpio_close(struct app_gpio_line *line);

#endif
