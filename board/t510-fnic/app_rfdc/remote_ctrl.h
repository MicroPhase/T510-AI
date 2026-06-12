#ifndef APP_RFDC_REMOTE_CTRL_H_
#define APP_RFDC_REMOTE_CTRL_H_

#include <stdbool.h>
#include <stdint.h>

#define APP_RFDC_DEFAULT_CTRL_PORT 49208U

#define APP_RFDC_PACKET_TYPE_CTRL 0x5501U
#define APP_RFDC_PACKET_TYPE_RESP 0x5502U

struct app_rfdc_remote_packet {
	uint16_t magic_type;
	uint16_t seq;
	uint8_t sid;
	uint32_t packet_len;
	uint64_t timestamp;
	uint32_t data;
	uint32_t addr;
};

struct app_rfdc_remote_endpoint {
	int fd;
	uint16_t port;
};

int app_rfdc_remote_open(struct app_rfdc_remote_endpoint *endpoint, uint16_t port);
void app_rfdc_remote_close(struct app_rfdc_remote_endpoint *endpoint);
int app_rfdc_remote_recv(struct app_rfdc_remote_endpoint *endpoint, struct app_rfdc_remote_packet *packet);
int app_rfdc_remote_send_response(
	struct app_rfdc_remote_endpoint *endpoint, const struct app_rfdc_remote_packet *request, uint64_t value);

#endif
