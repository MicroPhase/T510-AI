#ifndef APP_RFDC_REMOTE_CTRL_H_
#define APP_RFDC_REMOTE_CTRL_H_

#include <stdbool.h>
#include <stdint.h>

#define APP_RFDC_DEFAULT_CTRL_PORT 49208U

#define APP_RFDC_PACKET_TYPE_CTRL 0x5501U
#define APP_RFDC_PACKET_TYPE_RESP 0x5502U

#define APP_RFDC_REMOTE_PACKET_BYTES 32U
#define APP_RFDC_REMOTE_CMD_NOP       0x0000U
#define APP_RFDC_REMOTE_CMD_GET_VERSION 0x0001U
#define APP_RFDC_REMOTE_CMD_WRITE_REG 0x0002U
#define APP_RFDC_REMOTE_CMD_READ_REG  0x0003U

#define APP_RFDC_REMOTE_STATUS_OK         0x0000U
#define APP_RFDC_REMOTE_STATUS_BAD_MAGIC  0x0001U
#define APP_RFDC_REMOTE_STATUS_BAD_LENGTH 0x0002U
#define APP_RFDC_REMOTE_STATUS_BAD_CMD    0x0003U
#define APP_RFDC_REMOTE_STATUS_BAD_SID    0x0004U
#define APP_RFDC_REMOTE_STATUS_DENIED     0x0006U

struct app_rfdc_remote_packet {
	uint16_t magic_type;
	uint16_t seq;
	uint8_t sid;
	uint32_t packet_len;
	uint64_t timestamp;
	uint16_t cmd_id;
	uint8_t flags;
	uint8_t target;
	uint32_t arg0;
	uint32_t arg1;
	uint32_t arg2;
};

struct app_rfdc_remote_endpoint {
	int fd;
	uint16_t port;
};

int app_rfdc_remote_open(struct app_rfdc_remote_endpoint *endpoint, uint16_t port);
void app_rfdc_remote_close(struct app_rfdc_remote_endpoint *endpoint);
int app_rfdc_remote_recv(struct app_rfdc_remote_endpoint *endpoint, struct app_rfdc_remote_packet *packet);
int app_rfdc_remote_send_response(
	struct app_rfdc_remote_endpoint *endpoint,
	const struct app_rfdc_remote_packet *request,
	uint16_t status,
	uint64_t value);

#endif
