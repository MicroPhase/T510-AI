#include "remote_ctrl.h"

#include <arpa/inet.h>
#include <errno.h>
#include <string.h>
#include <sys/socket.h>
#include <unistd.h>

struct peer_cache_entry {
	uint16_t port;
	bool valid;
	struct sockaddr_in peer;
};

static struct peer_cache_entry g_peer_cache[3];

static void serialize_header(uint32_t *words, const struct app_rfdc_remote_packet *packet)
{
	words[0] = ((uint32_t)packet->sid << 24) | (packet->packet_len & 0x00ffffffU);
	words[1] = ((uint32_t)packet->magic_type << 16) | packet->seq;
	words[2] = (uint32_t)(packet->timestamp & 0xffffffffU);
	words[3] = (uint32_t)(packet->timestamp >> 32);
}

static void deserialize_header(const uint32_t *words, struct app_rfdc_remote_packet *packet)
{
	packet->sid = (uint8_t)(words[0] >> 24);
	packet->packet_len = words[0] & 0x00ffffffU;
	packet->magic_type = (uint16_t)(words[1] >> 16);
	packet->seq = (uint16_t)(words[1] & 0xffffU);
	packet->timestamp = ((uint64_t)words[3] << 32) | (uint64_t)words[2];
	packet->cmd_id = (uint16_t)(words[4] & 0xffffU);
	packet->flags = (uint8_t)((words[4] >> 16) & 0xffU);
	packet->target = (uint8_t)((words[4] >> 24) & 0xffU);
	packet->arg0 = words[5];
	packet->arg1 = words[6];
	packet->arg2 = words[7];
}

static void cache_peer(uint16_t port, const struct sockaddr_in *peer)
{
	size_t i;

	for (i = 0; i < (sizeof(g_peer_cache) / sizeof(g_peer_cache[0])); ++i) {
		if (g_peer_cache[i].valid && g_peer_cache[i].port == port) {
			g_peer_cache[i].peer = *peer;
			return;
		}
	}

	for (i = 0; i < (sizeof(g_peer_cache) / sizeof(g_peer_cache[0])); ++i) {
		if (!g_peer_cache[i].valid) {
			g_peer_cache[i].valid = true;
			g_peer_cache[i].port = port;
			g_peer_cache[i].peer = *peer;
			return;
		}
	}

	g_peer_cache[0].valid = true;
	g_peer_cache[0].port = port;
	g_peer_cache[0].peer = *peer;
}

static int get_cached_peer(uint16_t port, struct sockaddr_in *peer)
{
	size_t i;

	for (i = 0; i < (sizeof(g_peer_cache) / sizeof(g_peer_cache[0])); ++i) {
		if (g_peer_cache[i].valid && g_peer_cache[i].port == port) {
			*peer = g_peer_cache[i].peer;
			return 0;
		}
	}

	return -ENOENT;
}

int app_rfdc_remote_open(struct app_rfdc_remote_endpoint *endpoint, uint16_t port)
{
	struct sockaddr_in serv_addr;
	int true_v = 1;

	if (endpoint == NULL)
		return -EINVAL;

	memset(endpoint, 0, sizeof(*endpoint));
	endpoint->fd = -1;
	endpoint->port = port;

	endpoint->fd = socket(AF_INET, SOCK_DGRAM, 0);
	if (endpoint->fd < 0)
		return -errno;

	if (setsockopt(endpoint->fd, SOL_SOCKET, SO_REUSEADDR, &true_v, sizeof(true_v)) != 0) {
		close(endpoint->fd);
		endpoint->fd = -1;
		return -errno;
	}

	memset(&serv_addr, 0, sizeof(serv_addr));
	serv_addr.sin_family = AF_INET;
	serv_addr.sin_addr.s_addr = htonl(INADDR_ANY);
	serv_addr.sin_port = htons(port);
	if (bind(endpoint->fd, (const struct sockaddr *)&serv_addr, sizeof(serv_addr)) != 0) {
		close(endpoint->fd);
		endpoint->fd = -1;
		return -errno;
	}

	return 0;
}

void app_rfdc_remote_close(struct app_rfdc_remote_endpoint *endpoint)
{
	if (endpoint != NULL && endpoint->fd >= 0) {
		close(endpoint->fd);
		endpoint->fd = -1;
	}
}

int app_rfdc_remote_recv(struct app_rfdc_remote_endpoint *endpoint, struct app_rfdc_remote_packet *packet)
{
	struct sockaddr_in peer;
	socklen_t peer_len = sizeof(peer);
	uint32_t words[APP_RFDC_REMOTE_PACKET_BYTES / sizeof(uint32_t)] = {0};
	ssize_t len;

	if (endpoint == NULL || packet == NULL || endpoint->fd < 0)
		return -EINVAL;

	len = recvfrom(
		endpoint->fd, words, sizeof(words), 0, (struct sockaddr *)&peer, &peer_len);
	if (len < 0)
		return -errno;
	if ((size_t)len != sizeof(words))
		return -EMSGSIZE;

	deserialize_header(words, packet);
	if (packet->packet_len != sizeof(words))
		return -EMSGSIZE;
	if (packet->magic_type != APP_RFDC_PACKET_TYPE_CTRL)
		return -EPROTO;

	cache_peer(endpoint->port, &peer);
	return 0;
}

int app_rfdc_remote_send_response(
	struct app_rfdc_remote_endpoint *endpoint,
	const struct app_rfdc_remote_packet *request,
	uint16_t status,
	uint64_t value)
{
	struct app_rfdc_remote_packet response;
	struct sockaddr_in peer;
	uint32_t words[APP_RFDC_REMOTE_PACKET_BYTES / sizeof(uint32_t)] = {0};
	ssize_t len;

	if (endpoint == NULL || request == NULL || endpoint->fd < 0)
		return -EINVAL;

	if (get_cached_peer(endpoint->port, &peer) != 0)
		return -ENOENT;

	memset(&response, 0, sizeof(response));
	response.magic_type = APP_RFDC_PACKET_TYPE_RESP;
	response.seq = request->seq;
	response.sid = request->sid;
	response.packet_len = sizeof(words);
	response.timestamp = request->timestamp;
	response.cmd_id = request->cmd_id;

	serialize_header(words, &response);
	words[4] = ((uint32_t)status << 16) | response.cmd_id;
	words[5] = (uint32_t)(value & 0xffffffffU);
	words[6] = (uint32_t)(value >> 32);
	words[7] = 0;

	len = sendto(endpoint->fd, words, sizeof(words), 0, (const struct sockaddr *)&peer, sizeof(peer));
	if (len < 0)
		return -errno;
	if ((size_t)len != sizeof(words))
		return -EIO;

	return 0;
}
