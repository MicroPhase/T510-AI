#include "app_mailbox.h"

#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <unistd.h>

static uint32_t resolve_mailbox_base_addr(uint32_t default_base_addr)
{
	const char *env = getenv("APP_RFDC_MAILBOX_BASE_ADDR");
	char *end = NULL;
	unsigned long value;

	if (env == NULL || *env == '\0')
		return default_base_addr;

	errno = 0;
	value = strtoul(env, &end, 0);
	if (errno != 0 || end == env || *end != '\0' || value > 0xffffffffUL) {
		fprintf(stderr, "invalid APP_RFDC_MAILBOX_BASE_ADDR='%s', fallback to 0x%08x\n",
			env, default_base_addr);
		return default_base_addr;
	}

	return (uint32_t)value;
}

int app_mailbox_init(struct app_mailbox *mailbox, uint32_t base_addr, uint32_t reg_len)
{
	void *map_base;
	int fd_mem;

	if (mailbox == NULL)
		return -EINVAL;

	memset(mailbox, 0, sizeof(*mailbox));
	mailbox->fd_mem = -1;
	mailbox->mem_start = resolve_mailbox_base_addr(base_addr);

	fd_mem = open("/dev/mem", O_RDWR | O_SYNC);
	if (fd_mem < 0) {
		perror("open /dev/mem failed");
		return -1;
	}

	map_base = mmap(NULL, reg_len, PROT_READ | PROT_WRITE, MAP_SHARED, fd_mem, mailbox->mem_start);
	if (map_base == MAP_FAILED) {
		perror("mailbox mmap failed");
		close(fd_mem);
		return -1;
	}

	mailbox->fd_mem = fd_mem;
	mailbox->mem_len = reg_len;
	mailbox->map_base = (volatile uint32_t *)map_base;
	return 0;
}

void app_mailbox_close(struct app_mailbox *mailbox)
{
	if (mailbox == NULL)
		return;

	if (mailbox->map_base != NULL && mailbox->mem_len != 0U)
		munmap((void *)mailbox->map_base, mailbox->mem_len);

	if (mailbox->fd_mem >= 0)
		close(mailbox->fd_mem);

	memset(mailbox, 0, sizeof(*mailbox));
	mailbox->fd_mem = -1;
}

int app_mailbox_peek(struct app_mailbox *mailbox, uint32_t reg, uint32_t *value)
{
	if (mailbox == NULL || value == NULL || mailbox->map_base == NULL)
		return -EINVAL;

	if ((reg & 0x3U) != 0U || reg >= mailbox->mem_len)
		return -EINVAL;

	*value = *(mailbox->map_base + reg / 4U);
	return 0;
}

int app_mailbox_poke(struct app_mailbox *mailbox, uint32_t reg, uint32_t value)
{
	if (mailbox == NULL || mailbox->map_base == NULL)
		return -EINVAL;

	if ((reg & 0x3U) != 0U || reg >= mailbox->mem_len)
		return -EINVAL;

	*(mailbox->map_base + reg / 4U) = value;
	return 0;
}

int app_mailbox_read_cmd(struct app_mailbox *mailbox, struct app_mailbox_cmd *cmd)
{
	if (cmd == NULL)
		return -EINVAL;

	if (app_mailbox_peek(mailbox, APP_MAILBOX_REG_CMD_SEQ, &cmd->seq) != 0)
		return -1;
	if (app_mailbox_peek(mailbox, APP_MAILBOX_REG_CMD_OP, &cmd->op) != 0)
		return -1;
	if (app_mailbox_peek(mailbox, APP_MAILBOX_REG_CMD_ARG0, &cmd->arg0) != 0)
		return -1;
	if (app_mailbox_peek(mailbox, APP_MAILBOX_REG_CMD_ARG1, &cmd->arg1) != 0)
		return -1;
	if (app_mailbox_peek(mailbox, APP_MAILBOX_REG_CMD_ARG2, &cmd->arg2) != 0)
		return -1;
	if (app_mailbox_peek(mailbox, APP_MAILBOX_REG_CMD_ARG3, &cmd->arg3) != 0)
		return -1;

	return 0;
}

int app_mailbox_write_resp(struct app_mailbox *mailbox, const struct app_mailbox_resp *resp)
{
	if (resp == NULL)
		return -EINVAL;

	if (app_mailbox_poke(mailbox, APP_MAILBOX_REG_RESP_SEQ, resp->seq) != 0)
		return -1;
	if (app_mailbox_poke(mailbox, APP_MAILBOX_REG_RESP_STATUS, resp->status) != 0)
		return -1;
	if (app_mailbox_poke(mailbox, APP_MAILBOX_REG_RESP_DATA0, resp->data0) != 0)
		return -1;
	if (app_mailbox_poke(mailbox, APP_MAILBOX_REG_RESP_DATA1, resp->data1) != 0)
		return -1;
	if (app_mailbox_poke(mailbox, APP_MAILBOX_REG_RESP_DATA2, resp->data2) != 0)
		return -1;
	if (app_mailbox_poke(mailbox, APP_MAILBOX_REG_RESP_DATA3, resp->data3) != 0)
		return -1;

	return app_mailbox_poke(mailbox, APP_MAILBOX_REG_CONTROL, APP_MAILBOX_CTRL_RESP_COMMIT);
}
