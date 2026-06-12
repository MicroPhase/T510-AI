#ifndef APP_RFDC_MAILBOX_H_
#define APP_RFDC_MAILBOX_H_

#include <stdint.h>

#define APP_MAILBOX_DEFAULT_BASE_ADDR 0xA0000000U
#define APP_MAILBOX_REGION_SIZE 0x1000U

#define APP_MAILBOX_REG_STATUS 0x00U
#define APP_MAILBOX_REG_CONTROL 0x04U
#define APP_MAILBOX_REG_CMD_SEQ 0x08U
#define APP_MAILBOX_REG_CMD_OP 0x0cU
#define APP_MAILBOX_REG_CMD_ARG0 0x10U
#define APP_MAILBOX_REG_CMD_ARG1 0x14U
#define APP_MAILBOX_REG_CMD_ARG2 0x18U
#define APP_MAILBOX_REG_CMD_ARG3 0x1cU
#define APP_MAILBOX_REG_RESP_SEQ 0x20U
#define APP_MAILBOX_REG_RESP_STATUS 0x24U
#define APP_MAILBOX_REG_RESP_DATA0 0x28U
#define APP_MAILBOX_REG_RESP_DATA1 0x2cU
#define APP_MAILBOX_REG_RESP_DATA2 0x30U
#define APP_MAILBOX_REG_RESP_DATA3 0x34U
#define APP_MAILBOX_REG_MAILBOX_ID 0x7cU

#define APP_MAILBOX_STATUS_CMD_VALID 0x00000001U
#define APP_MAILBOX_STATUS_RESP_VALID 0x00000002U
#define APP_MAILBOX_STATUS_CMD_OVERFLOW 0x00000008U
#define APP_MAILBOX_STATUS_BUSY 0x00000010U

#define APP_MAILBOX_CTRL_CMD_ACK 0x00000001U
#define APP_MAILBOX_CTRL_RESP_COMMIT 0x00000002U
#define APP_MAILBOX_CTRL_RESP_ACK_SW 0x00000004U
#define APP_MAILBOX_CTRL_CLEAR_OVERFLOW 0x00000008U
#define APP_MAILBOX_CTRL_CLEAR_COUNTERS 0x00000010U

#define APP_MAILBOX_ID 0x544d424fU

struct app_mailbox {
	uint32_t mem_start;
	uint32_t mem_len;
	int fd_mem;
	volatile uint32_t *map_base;
};

struct app_mailbox_cmd {
	uint32_t seq;
	uint32_t op;
	uint32_t arg0;
	uint32_t arg1;
	uint32_t arg2;
	uint32_t arg3;
};

struct app_mailbox_resp {
	uint32_t seq;
	uint32_t status;
	uint32_t data0;
	uint32_t data1;
	uint32_t data2;
	uint32_t data3;
};

int app_mailbox_init(struct app_mailbox *mailbox, uint32_t base_addr, uint32_t reg_len);
void app_mailbox_close(struct app_mailbox *mailbox);
int app_mailbox_peek(struct app_mailbox *mailbox, uint32_t reg, uint32_t *value);
int app_mailbox_poke(struct app_mailbox *mailbox, uint32_t reg, uint32_t value);
int app_mailbox_read_cmd(struct app_mailbox *mailbox, struct app_mailbox_cmd *cmd);
int app_mailbox_write_resp(struct app_mailbox *mailbox, const struct app_mailbox_resp *resp);

#endif
