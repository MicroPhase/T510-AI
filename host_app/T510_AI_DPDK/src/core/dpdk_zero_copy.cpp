#include <arpa/inet.h>
#include <atomic>
#include <chrono>
#include <condition_variable>
#include <cstdlib>
#include <cstring>
#include <deque>
#include <fstream>
#include <mutex>
#include <stdexcept>
#include <string>
#include <thread>
#include <unordered_map>
#include <vector>

#include <rte_arp.h>
#include <rte_byteorder.h>
#include <rte_eal.h>
#include <rte_ether.h>
#include <rte_ethdev.h>
#include <rte_ip.h>
#include <rte_mbuf.h>
#include <rte_ring.h>
#include <rte_udp.h>

#include "include/sdr/core/dpdk_zero_copy.hpp"
#include "include/sdr/log.hpp"

using namespace sdr;
using namespace sdr::core;

namespace {

constexpr const char* DEFAULT_DPDK_PCI_ADDR      = "0000:01:00.0";
constexpr const char* DEFAULT_DPDK_CORELIST      = "1-2";
constexpr const char* DEFAULT_DPDK_LOCAL_IP      = "192.168.10.10";
constexpr uint16_t DEFAULT_DPDK_MTU              = 9000;
constexpr uint16_t DEFAULT_DPDK_RX_DESC          = 2048;
constexpr uint16_t DEFAULT_DPDK_TX_DESC          = 2048;
constexpr unsigned DEFAULT_DPDK_NUM_MBUFS        = 16384;
constexpr int DEFAULT_DPDK_MEM_CHANNELS          = 4;
constexpr int DEFAULT_DPDK_LOCAL_PORT_OFFSET     = 0;
constexpr size_t DEFAULT_DPDK_MAX_RX_BURST       = 128;
constexpr int DEFAULT_DPDK_PUMP_POLL_US          = 100;
constexpr int DEFAULT_DPDK_ARP_TIMEOUT_MS        = 1000;
constexpr size_t DEFAULT_RX_QUEUE_DEPTH_FACTOR   = 4;
constexpr size_t DEFAULT_RX_QUEUE_MIN_DEPTH      = 1024;

static std::atomic<uint32_t> g_dpdk_rx_ring_id{0};

static uint64_t now_ns()
{
    return std::chrono::duration_cast<std::chrono::nanoseconds>(
               std::chrono::steady_clock::now().time_since_epoch())
        .count();
}

static std::string getenv_or_default(const char* name, const char* fallback)
{
    const char* value = std::getenv(name);
    return (value && *value) ? std::string(value) : std::string(fallback);
}

static uint64_t getenv_u64_or_default(const char* name, uint64_t fallback)
{
    const char* value = std::getenv(name);
    if (!value || !*value) {
        return fallback;
    }
    char* end = nullptr;
    const unsigned long long parsed = std::strtoull(value, &end, 0);
    if (!end || *end != '\0') {
        return fallback;
    }
    return static_cast<uint64_t>(parsed);
}

static int parse_ipv4_string(const std::string& text, uint32_t* out_be)
{
    struct in_addr addr;
    if (inet_pton(AF_INET, text.c_str(), &addr) != 1) {
        return -1;
    }
    *out_be = addr.s_addr;
    return 0;
}

static int parse_mac_string(const std::string& text, struct rte_ether_addr* mac)
{
    unsigned values[6];
    if (std::sscanf(text.c_str(),
            "%02x:%02x:%02x:%02x:%02x:%02x",
            &values[0],
            &values[1],
            &values[2],
            &values[3],
            &values[4],
            &values[5])
        != 6) {
        return -1;
    }
    for (size_t i = 0; i < RTE_ETHER_ADDR_LEN; i++) {
        mac->addr_bytes[i] = static_cast<uint8_t>(values[i]);
    }
    return 0;
}

static bool env_flag_enabled(const char* name, bool default_value)
{
    const char* value = std::getenv(name);
    if (!value || !*value) {
        return default_value;
    }

    if (std::strcmp(value, "1") == 0 || std::strcmp(value, "y") == 0 || std::strcmp(value, "Y") == 0
        || std::strcmp(value, "yes") == 0 || std::strcmp(value, "YES") == 0
        || std::strcmp(value, "true") == 0 || std::strcmp(value, "TRUE") == 0
        || std::strcmp(value, "on") == 0 || std::strcmp(value, "ON") == 0) {
        return true;
    }

    if (std::strcmp(value, "0") == 0 || std::strcmp(value, "n") == 0 || std::strcmp(value, "N") == 0
        || std::strcmp(value, "no") == 0 || std::strcmp(value, "NO") == 0
        || std::strcmp(value, "false") == 0 || std::strcmp(value, "FALSE") == 0
        || std::strcmp(value, "off") == 0 || std::strcmp(value, "OFF") == 0) {
        return false;
    }

    return default_value;
}

static uint32_t read_le32_unaligned(const uint8_t* p)
{
    uint32_t v = 0;
    std::memcpy(&v, p, sizeof(v));
    return v;
}

static unsigned next_pow2_ge(unsigned value)
{
    unsigned v = 1;
    while (v < value) {
        v <<= 1;
    }
    return v;
}

static bool host_has_hugepages()
{
    std::ifstream meminfo("/proc/meminfo");
    std::string key;
    uint64_t value = 0;
    std::string unit;

    if (!meminfo.is_open()) {
        return false;
    }

    while (meminfo >> key >> value >> unit) {
        if (key == "HugePages_Total:") {
            return value > 0;
        }
    }

    return false;
}

static uint32_t calc_mbuf_data_room(const zero_copy_xport_params& params, uint16_t mtu)
{
    const size_t payload = std::max(params.recv_frame_size, params.send_frame_size);
    const uint32_t frame_bytes =
        static_cast<uint32_t>(std::max<size_t>(mtu, payload + 64)) + sizeof(rte_ether_hdr)
        + RTE_ETHER_CRC_LEN + 256u;
    const uint32_t data_room = static_cast<uint32_t>(RTE_PKTMBUF_HEADROOM) + frame_bytes;
    return data_room > RTE_MBUF_DEFAULT_BUF_SIZE ? data_room : RTE_MBUF_DEFAULT_BUF_SIZE;
}

static uint16_t find_port_id_by_name(const std::string& name)
{
    uint16_t port_id;
    char port_name[RTE_ETH_NAME_MAX_LEN];

    RTE_ETH_FOREACH_DEV(port_id)
    {
        if (rte_eth_dev_get_name_by_port(port_id, port_name) == 0
            && name == std::string(port_name)) {
            return port_id;
        }
    }
    return RTE_MAX_ETHPORTS;
}

class dpdk_zero_copy_impl;

struct rx_packet_desc
{
    void* data = nullptr;
    uint16_t len = 0;
};

class rx_dispatch_target
{
public:
    virtual ~rx_dispatch_target() = default;
    virtual void enqueue_payload_copy(const uint8_t* data, size_t len) = 0;
    virtual bool enqueue_payload_mbuf(rte_mbuf* mbuf, uint16_t payload_offset, uint16_t payload_len)
    {
        (void)mbuf;
        (void)payload_offset;
        (void)payload_len;
        return false;
    }
};

class dpdk_shared_context
{
public:
    static dpdk_shared_context& instance()
    {
        static dpdk_shared_context ctx;
        return ctx;
    }

    ~dpdk_shared_context()
    {
        _pump_running = false;
        if (_pump_thread.joinable()) {
            _pump_thread.join();
        }
    }

    void ensure_init(const zero_copy_xport_params& params)
    {
        std::call_once(_init_once, [&]() {
            _pci_addr       = getenv_or_default("IQ_TAXI_DPDK_PCI_ADDR", DEFAULT_DPDK_PCI_ADDR);
            _corelist       = getenv_or_default("IQ_TAXI_DPDK_CORELIST", DEFAULT_DPDK_CORELIST);
            _local_ip_str   = getenv_or_default("IQ_TAXI_DPDK_LOCAL_IP", DEFAULT_DPDK_LOCAL_IP);
            _mtu            = static_cast<uint16_t>(
                getenv_u64_or_default("IQ_TAXI_DPDK_MTU", DEFAULT_DPDK_MTU));
            _num_mbufs      = static_cast<unsigned>(
                getenv_u64_or_default("IQ_TAXI_DPDK_NUM_MBUFS", DEFAULT_DPDK_NUM_MBUFS));
            _rx_desc        = static_cast<uint16_t>(
                getenv_u64_or_default("IQ_TAXI_DPDK_RX_DESC", DEFAULT_DPDK_RX_DESC));
            _tx_desc        = static_cast<uint16_t>(
                getenv_u64_or_default("IQ_TAXI_DPDK_TX_DESC", DEFAULT_DPDK_TX_DESC));
            _mem_channels   = static_cast<int>(
                getenv_u64_or_default("IQ_TAXI_DPDK_MEM_CHANNELS", DEFAULT_DPDK_MEM_CHANNELS));
            _local_port_offset = static_cast<int>(
                getenv_u64_or_default("IQ_TAXI_DPDK_LOCAL_PORT_OFFSET",
                    DEFAULT_DPDK_LOCAL_PORT_OFFSET));
            _remote_mac_str = getenv_or_default("IQ_TAXI_DPDK_REMOTE_MAC", "");

            if (parse_ipv4_string(_local_ip_str, &_local_ip_be) != 0) {
                throw std::runtime_error("IQ_TAXI_DPDK_LOCAL_IP 非法");
            }

            const bool use_no_huge =
                env_flag_enabled("IQ_TAXI_DPDK_NO_HUGE", !host_has_hugepages());
            char mem_channels_str[16];
            std::vector<std::string> eal_args;
            std::vector<char*> eal_argv;

            std::snprintf(mem_channels_str, sizeof(mem_channels_str), "%d", _mem_channels);
            eal_args.emplace_back("iq_taxi_dpdk");
            eal_args.emplace_back("-l");
            eal_args.emplace_back(_corelist);
            eal_args.emplace_back("-n");
            eal_args.emplace_back(mem_channels_str);
            eal_args.emplace_back("-a");
            eal_args.emplace_back(_pci_addr);
            eal_args.emplace_back(use_no_huge ? "--iova-mode=va" : "--iova-mode=pa");
            if (use_no_huge) {
                eal_args.emplace_back("--no-huge");
                eal_args.emplace_back("--in-memory");
            }

            eal_argv.reserve(eal_args.size());
            for (std::string& arg : eal_args) {
                eal_argv.push_back(arg.data());
            }

            if (rte_eal_init(static_cast<int>(eal_argv.size()), eal_argv.data()) < 0) {
                throw std::runtime_error("rte_eal_init 失败");
            }

            _port_id = find_port_id_by_name(_pci_addr);
            if (_port_id == RTE_MAX_ETHPORTS) {
                throw std::runtime_error("未找到 DPDK 端口: " + _pci_addr);
            }

            rte_eth_conf port_conf;
            std::memset(&port_conf, 0, sizeof(port_conf));
#if defined(RTE_ETH_RX_OFFLOAD_JUMBO_FRAME)
            port_conf.rxmode.offloads |= RTE_ETH_RX_OFFLOAD_JUMBO_FRAME;
#elif defined(DEV_RX_OFFLOAD_JUMBO_FRAME)
            port_conf.rxmode.offloads |= DEV_RX_OFFLOAD_JUMBO_FRAME;
#endif
#if RTE_VER_YEAR > 21 || (RTE_VER_YEAR == 21 && RTE_VER_MONTH == 11)
            port_conf.rxmode.mtu = _mtu;
#else
            port_conf.rxmode.max_rx_pkt_len =
                static_cast<uint32_t>(_mtu) + sizeof(rte_ether_hdr) + RTE_ETHER_CRC_LEN;
#endif

            int rc = rte_eth_dev_configure(_port_id, 1, 1, &port_conf);
            if (rc != 0) {
                throw std::runtime_error("rte_eth_dev_configure 失败");
            }

            (void)rte_eth_dev_set_mtu(_port_id, _mtu);

            _mbuf_data_room = calc_mbuf_data_room(params, _mtu);
            _mbuf_pool = rte_pktmbuf_pool_create("iq_taxi_dpdk_pool",
                _num_mbufs,
                256,
                0,
                _mbuf_data_room,
                rte_socket_id());
            if (!_mbuf_pool) {
                throw std::runtime_error("rte_pktmbuf_pool_create 失败");
            }

            rc = rte_eth_rx_queue_setup(
                _port_id, 0, _rx_desc, rte_eth_dev_socket_id(_port_id), nullptr, _mbuf_pool);
            if (rc != 0) {
                throw std::runtime_error("rte_eth_rx_queue_setup 失败");
            }

            rc = rte_eth_tx_queue_setup(
                _port_id, 0, _tx_desc, rte_eth_dev_socket_id(_port_id), nullptr);
            if (rc != 0) {
                throw std::runtime_error("rte_eth_tx_queue_setup 失败");
            }

            rc = rte_eth_dev_start(_port_id);
            if (rc != 0) {
                throw std::runtime_error("rte_eth_dev_start 失败");
            }

            rte_eth_macaddr_get(_port_id, &_local_mac);

            if (!_remote_mac_str.empty()) {
                if (parse_mac_string(_remote_mac_str, &_fallback_remote_mac) != 0) {
                    throw std::runtime_error("IQ_TAXI_DPDK_REMOTE_MAC 非法");
                }
                _fallback_remote_mac_valid = true;
            }

            LOG_INFO("DPDK transport started: pci=%s local_ip=%s mtu=%u mbuf_data_room=%u",
                _pci_addr.c_str(),
                _local_ip_str.c_str(),
                _mtu,
                _mbuf_data_room);
            LOG_INFO("DPDK EAL mode: %s",
                use_no_huge ? "no-huge/in-memory (debug-friendly)" : "hugepage");

            _pump_running = true;
            _pump_thread = std::thread([this]() {
                while (_pump_running.load(std::memory_order_relaxed)) {
                    pump_once(1);
                }
            });
        });
    }

    void register_transport(uint16_t local_port, rx_dispatch_target* target)
    {
        std::lock_guard<std::mutex> lock(_route_mutex);
        _route_table[local_port] = target;
    }

    void unregister_transport(uint16_t local_port)
    {
        std::lock_guard<std::mutex> lock(_route_mutex);
        _route_table.erase(local_port);
    }

    std::string local_ip_str() const
    {
        return _local_ip_str;
    }

    uint16_t compute_local_port(uint16_t remote_port) const
    {
        return static_cast<uint16_t>(remote_port + _local_port_offset);
    }

    bool ensure_remote_mac(uint32_t remote_ip_be, struct rte_ether_addr* mac_out)
    {
        {
            std::lock_guard<std::mutex> lock(_arp_mutex);
            auto it = _arp_cache.find(remote_ip_be);
            if (it != _arp_cache.end()) {
                *mac_out = it->second;
                return true;
            }
        }

        if (_fallback_remote_mac_valid) {
            *mac_out = _fallback_remote_mac;
            return true;
        }

        if (!send_arp_request(remote_ip_be)) {
            return false;
        }

        const uint64_t deadline = now_ns() + DEFAULT_DPDK_ARP_TIMEOUT_MS * 1000000ull;
        while (now_ns() < deadline) {
            pump_once(5);
            std::lock_guard<std::mutex> lock(_arp_mutex);
            auto it = _arp_cache.find(remote_ip_be);
            if (it != _arp_cache.end()) {
                *mac_out = it->second;
                return true;
            }
        }

        return false;
    }

    bool send_udp_payload(uint16_t local_port,
        uint32_t remote_ip_be,
        uint16_t remote_port,
        const uint8_t* payload,
        uint16_t payload_len)
    {
        struct rte_ether_addr remote_mac;
        if (!ensure_remote_mac(remote_ip_be, &remote_mac)) {
            LOG_ERROR("resolve remote MAC failed for remote_ip=0x%08x", rte_be_to_cpu_32(remote_ip_be));
            return false;
        }

        const uint16_t total_len = static_cast<uint16_t>(sizeof(rte_ether_hdr)
            + sizeof(rte_ipv4_hdr) + sizeof(rte_udp_hdr) + payload_len);

        std::lock_guard<std::mutex> lock(_tx_mutex);
        rte_mbuf* mbuf = rte_pktmbuf_alloc(_mbuf_pool);
        if (!mbuf) {
            LOG_ERROR("rte_pktmbuf_alloc failed");
            return false;
        }

        uint8_t* data = reinterpret_cast<uint8_t*>(rte_pktmbuf_append(mbuf, total_len));
        if (!data) {
            rte_pktmbuf_free(mbuf);
            LOG_ERROR("rte_pktmbuf_append failed, total_len=%u", total_len);
            return false;
        }

        auto* eth = reinterpret_cast<rte_ether_hdr*>(data);
        auto* ip  = reinterpret_cast<rte_ipv4_hdr*>(eth + 1);
        auto* udp = reinterpret_cast<rte_udp_hdr*>(ip + 1);

        rte_ether_addr_copy(&remote_mac, &eth->dst_addr);
        rte_ether_addr_copy(&_local_mac, &eth->src_addr);
        eth->ether_type = rte_cpu_to_be_16(RTE_ETHER_TYPE_IPV4);

        std::memset(ip, 0, sizeof(*ip));
        ip->version_ihl    = RTE_IPV4_VHL_DEF;
        ip->type_of_service = 0;
        ip->total_length   = rte_cpu_to_be_16(
            static_cast<uint16_t>(sizeof(rte_ipv4_hdr) + sizeof(rte_udp_hdr) + payload_len));
        ip->packet_id      = 0;
        ip->fragment_offset = 0;
        ip->time_to_live   = 64;
        ip->next_proto_id  = IPPROTO_UDP;
        ip->src_addr       = _local_ip_be;
        ip->dst_addr       = remote_ip_be;
        ip->hdr_checksum   = rte_ipv4_cksum(ip);

        udp->src_port    = rte_cpu_to_be_16(local_port);
        udp->dst_port    = rte_cpu_to_be_16(remote_port);
        udp->dgram_len   = rte_cpu_to_be_16(static_cast<uint16_t>(sizeof(rte_udp_hdr) + payload_len));
        udp->dgram_cksum = 0;

        std::memcpy(reinterpret_cast<uint8_t*>(udp + 1), payload, payload_len);

        rte_mbuf* pkts[1] = {mbuf};
        if (rte_eth_tx_burst(_port_id, 0, pkts, 1) != 1) {
            rte_pktmbuf_free(mbuf);
            LOG_WARNING("rte_eth_tx_burst failed");
            return false;
        }

        return true;
    }

    bool pump_once(int timeout_ms)
    {
        const uint64_t deadline = now_ns() + static_cast<uint64_t>(timeout_ms) * 1000000ull;
        rte_mbuf* rx_pkts[DEFAULT_DPDK_MAX_RX_BURST];

        while (now_ns() < deadline) {
            uint16_t n = 0;
            {
                std::lock_guard<std::mutex> lock(_rx_mutex);
                n = rte_eth_rx_burst(_port_id, 0, rx_pkts, DEFAULT_DPDK_MAX_RX_BURST);
            }
            if (n == 0) {
                std::this_thread::sleep_for(std::chrono::microseconds(DEFAULT_DPDK_PUMP_POLL_US));
                continue;
            }

            for (uint16_t i = 0; i < n; i++) {
                dispatch_rx_packet(rx_pkts[i]);
            }
            return true;
        }

        return false;
    }

private:
    dpdk_shared_context() = default;

    bool send_arp_request(uint32_t remote_ip_be)
    {
        std::lock_guard<std::mutex> lock(_tx_mutex);
        rte_mbuf* mbuf = rte_pktmbuf_alloc(_mbuf_pool);
        if (!mbuf) {
            return false;
        }

        const uint16_t frame_len = sizeof(rte_ether_hdr) + sizeof(rte_arp_hdr);
        uint8_t* data = reinterpret_cast<uint8_t*>(rte_pktmbuf_append(mbuf, frame_len));
        if (!data) {
            rte_pktmbuf_free(mbuf);
            return false;
        }

        auto* eth = reinterpret_cast<rte_ether_hdr*>(data);
        auto* arp = reinterpret_cast<rte_arp_hdr*>(eth + 1);

        static const rte_ether_addr broadcast_mac = {{0xff, 0xff, 0xff, 0xff, 0xff, 0xff}};
        rte_ether_addr_copy(&broadcast_mac, &eth->dst_addr);
        rte_ether_addr_copy(&_local_mac, &eth->src_addr);
        eth->ether_type = rte_cpu_to_be_16(RTE_ETHER_TYPE_ARP);

        std::memset(arp, 0, sizeof(*arp));
        arp->arp_hardware = rte_cpu_to_be_16(RTE_ARP_HRD_ETHER);
        arp->arp_protocol = rte_cpu_to_be_16(RTE_ETHER_TYPE_IPV4);
        arp->arp_hlen     = RTE_ETHER_ADDR_LEN;
        arp->arp_plen     = sizeof(uint32_t);
        arp->arp_opcode   = rte_cpu_to_be_16(RTE_ARP_OP_REQUEST);
        rte_ether_addr_copy(&_local_mac, &arp->arp_data.arp_sha);
        arp->arp_data.arp_sip = _local_ip_be;
        std::memset(&arp->arp_data.arp_tha, 0, sizeof(arp->arp_data.arp_tha));
        arp->arp_data.arp_tip = remote_ip_be;

        rte_mbuf* pkts[1] = {mbuf};
        if (rte_eth_tx_burst(_port_id, 0, pkts, 1) != 1) {
            rte_pktmbuf_free(mbuf);
            return false;
        }
        return true;
    }

    bool send_arp_reply(const rte_ether_addr& dst_mac,
        const rte_ether_addr& dst_hw,
        uint32_t dst_ip_be)
    {
        std::lock_guard<std::mutex> lock(_tx_mutex);
        rte_mbuf* mbuf = rte_pktmbuf_alloc(_mbuf_pool);
        if (!mbuf) {
            return false;
        }

        const uint16_t frame_len = sizeof(rte_ether_hdr) + sizeof(rte_arp_hdr);
        uint8_t* data = reinterpret_cast<uint8_t*>(rte_pktmbuf_append(mbuf, frame_len));
        if (!data) {
            rte_pktmbuf_free(mbuf);
            return false;
        }

        auto* eth = reinterpret_cast<rte_ether_hdr*>(data);
        auto* arp = reinterpret_cast<rte_arp_hdr*>(eth + 1);

        rte_ether_addr_copy(&dst_mac, &eth->dst_addr);
        rte_ether_addr_copy(&_local_mac, &eth->src_addr);
        eth->ether_type = rte_cpu_to_be_16(RTE_ETHER_TYPE_ARP);

        std::memset(arp, 0, sizeof(*arp));
        arp->arp_hardware = rte_cpu_to_be_16(RTE_ARP_HRD_ETHER);
        arp->arp_protocol = rte_cpu_to_be_16(RTE_ETHER_TYPE_IPV4);
        arp->arp_hlen     = RTE_ETHER_ADDR_LEN;
        arp->arp_plen     = sizeof(uint32_t);
        arp->arp_opcode   = rte_cpu_to_be_16(RTE_ARP_OP_REPLY);
        rte_ether_addr_copy(&_local_mac, &arp->arp_data.arp_sha);
        arp->arp_data.arp_sip = _local_ip_be;
        rte_ether_addr_copy(&dst_hw, &arp->arp_data.arp_tha);
        arp->arp_data.arp_tip = dst_ip_be;

        rte_mbuf* pkts[1] = {mbuf};
        if (rte_eth_tx_burst(_port_id, 0, pkts, 1) != 1) {
            rte_pktmbuf_free(mbuf);
            return false;
        }
        return true;
    }

    void dispatch_rx_packet(rte_mbuf* mbuf)
    {
        const uint8_t* data = rte_pktmbuf_mtod(mbuf, const uint8_t*);
        const uint16_t pkt_len = mbuf->pkt_len;

        if (pkt_len < sizeof(rte_ether_hdr)) {
            rte_pktmbuf_free(mbuf);
            return;
        }

        const auto* eth = reinterpret_cast<const rte_ether_hdr*>(data);
        if (eth->ether_type == rte_cpu_to_be_16(RTE_ETHER_TYPE_ARP)) {
            handle_arp_packet(mbuf);
            rte_pktmbuf_free(mbuf);
            return;
        }

        if (eth->ether_type != rte_cpu_to_be_16(RTE_ETHER_TYPE_IPV4)
            || pkt_len < sizeof(rte_ether_hdr) + sizeof(rte_ipv4_hdr) + sizeof(rte_udp_hdr)) {
            rte_pktmbuf_free(mbuf);
            return;
        }

        const auto* ip = reinterpret_cast<const rte_ipv4_hdr*>(eth + 1);
        if (ip->next_proto_id != IPPROTO_UDP || ip->dst_addr != _local_ip_be) {
            rte_pktmbuf_free(mbuf);
            return;
        }

        const auto* udp = reinterpret_cast<const rte_udp_hdr*>(ip + 1);
        const uint16_t src_port = rte_be_to_cpu_16(udp->src_port);
        const uint16_t dst_port = rte_be_to_cpu_16(udp->dst_port);
        const uint8_t* payload  = reinterpret_cast<const uint8_t*>(udp + 1);
        const uint16_t payload_len =
            static_cast<uint16_t>(rte_be_to_cpu_16(udp->dgram_len) - sizeof(rte_udp_hdr));

        if (env_flag_enabled("IQ_TAXI_DPDK_TRACE_CTRL_RX", false) && payload_len >= 24) {
            const uint32_t w0 = read_le32_unaligned(payload + 0);
            const uint32_t w1 = read_le32_unaligned(payload + 4);
            const uint8_t sid = static_cast<uint8_t>(w0 >> 24);
            const uint32_t packet_len = w0 & 0x00ffffffu;
            const uint16_t magic_type = static_cast<uint16_t>(w1 >> 16);
            const uint16_t seq = static_cast<uint16_t>(w1 & 0xffffu);
            if (dst_port == 49208u || src_port == 49208u || magic_type == 0x5501u
                || magic_type == 0x5502u) {
                std::fprintf(stderr,
                    "[dpdk_rx] src_port=%u dst_port=%u len=%u type=0x%04x sid=0x%02x seq=%u pkt_len=%u\n",
                    src_port,
                    dst_port,
                    static_cast<unsigned>(payload_len),
                    magic_type,
                    sid,
                    seq,
                    packet_len);
            }
        }

        rx_dispatch_target* target = nullptr;
        {
            std::lock_guard<std::mutex> lock(_route_mutex);
            auto it = _route_table.find(dst_port);
            if (it != _route_table.end()) {
                target = it->second;
            }
        }

        if (target) {
            const uint16_t payload_offset = static_cast<uint16_t>(payload - data);
            if (target->enqueue_payload_mbuf(mbuf, payload_offset, payload_len)) {
                return;
            }
            target->enqueue_payload_copy(payload, payload_len);
        }

        rte_pktmbuf_free(mbuf);
    }

    void handle_arp_packet(rte_mbuf* mbuf)
    {
        if (mbuf->pkt_len < sizeof(rte_ether_hdr) + sizeof(rte_arp_hdr)) {
            return;
        }

        const auto* eth = rte_pktmbuf_mtod(mbuf, const rte_ether_hdr*);
        const auto* arp = reinterpret_cast<const rte_arp_hdr*>(eth + 1);

        const uint16_t opcode = rte_be_to_cpu_16(arp->arp_opcode);
        if (arp->arp_data.arp_tip != _local_ip_be) {
            return;
        }

        {
            std::lock_guard<std::mutex> lock(_arp_mutex);
            _arp_cache[arp->arp_data.arp_sip] = arp->arp_data.arp_sha;
        }

        if (opcode == RTE_ARP_OP_REQUEST) {
            const bool trace_arp = env_flag_enabled("IQ_TAXI_DPDK_TRACE_ARP", false);
            if (trace_arp) {
                std::fprintf(stderr,
                    "[dpdk_arp] replying to arp request for local_ip=0x%08x from sip=0x%08x\n",
                    rte_be_to_cpu_32(_local_ip_be),
                    rte_be_to_cpu_32(arp->arp_data.arp_sip));
            }
            send_arp_reply(eth->src_addr, arp->arp_data.arp_sha, arp->arp_data.arp_sip);
            return;
        }

        if (opcode == RTE_ARP_OP_REPLY && env_flag_enabled("IQ_TAXI_DPDK_TRACE_ARP", false)) {
            std::fprintf(stderr,
                "[dpdk_arp] learned arp reply sip=0x%08x\n",
                rte_be_to_cpu_32(arp->arp_data.arp_sip));
        }
    }

    std::once_flag _init_once;
    std::string _pci_addr;
    std::string _corelist;
    std::string _local_ip_str;
    std::string _remote_mac_str;
    uint32_t _local_ip_be            = 0;
    uint16_t _port_id                = RTE_MAX_ETHPORTS;
    uint16_t _mtu                    = DEFAULT_DPDK_MTU;
    uint16_t _rx_desc                = DEFAULT_DPDK_RX_DESC;
    uint16_t _tx_desc                = DEFAULT_DPDK_TX_DESC;
    unsigned _num_mbufs              = DEFAULT_DPDK_NUM_MBUFS;
    int _mem_channels                = DEFAULT_DPDK_MEM_CHANNELS;
    int _local_port_offset           = DEFAULT_DPDK_LOCAL_PORT_OFFSET;
    uint32_t _mbuf_data_room         = RTE_MBUF_DEFAULT_BUF_SIZE;
    rte_mempool* _mbuf_pool          = nullptr;
    rte_ether_addr _local_mac        = {};
    rte_ether_addr _fallback_remote_mac = {};
    bool _fallback_remote_mac_valid  = false;

    std::mutex _route_mutex;
    std::unordered_map<uint16_t, rx_dispatch_target*> _route_table;

    std::mutex _arp_mutex;
    std::unordered_map<uint32_t, rte_ether_addr> _arp_cache;

    std::mutex _rx_mutex;
    std::mutex _tx_mutex;
    std::atomic<bool> _pump_running{false};
    std::thread _pump_thread;
};

class dpdk_zero_copy_mrb : public managed_recv_buffer
{
public:
    dpdk_zero_copy_mrb(class dpdk_zero_copy_impl* owner)
        : _owner(owner), _desc(nullptr), _len(0)
    {
    }

    void release(void) override;

    sptr get_new(const double timeout, size_t& index);

    void attach(rx_packet_desc* desc, void* data, size_t len)
    {
        _desc = desc;
        _mem  = data;
        _len  = len;
    }

private:
    class dpdk_zero_copy_impl* _owner;
    rx_packet_desc* _desc;
    void* _mem = nullptr;
    size_t _len;
    simple_claimer _claimer;
};

class dpdk_zero_copy_msb : public managed_send_buffer
{
public:
    dpdk_zero_copy_msb(
        class dpdk_zero_copy_impl* owner, void* mem, const size_t frame_size)
        : _owner(owner), _mem(mem), _frame_size(frame_size)
    {
    }

    void release(void) override;

    sptr get_new(const double timeout, size_t& index)
    {
        if (!_claimer.claim_with_wait(timeout)) {
            return sptr();
        }
        index++;
        return make(this, _mem, _frame_size);
    }

private:
    class dpdk_zero_copy_impl* _owner;
    void* _mem;
    size_t _frame_size;
    simple_claimer _claimer;
};

class dpdk_zero_copy_impl : public dpdk_zero_copy, public rx_dispatch_target
{
public:
    typedef std::shared_ptr<dpdk_zero_copy_impl> sptr;

    dpdk_zero_copy_impl(const std::string& addr,
        const std::string& port,
        const zero_copy_xport_params& xport_params)
        : _ctx(dpdk_shared_context::instance())
        , _remote_ip_str(addr)
        , _remote_port(static_cast<uint16_t>(std::stoi(port)))
        , _local_port(_ctx.compute_local_port(_remote_port))
        , _recv_frame_size(xport_params.recv_frame_size)
        , _num_recv_frames(xport_params.num_recv_frames)
        , _send_frame_size(xport_params.send_frame_size)
        , _num_send_frames(xport_params.num_send_frames)
        , _recv_buffer_pool(buffer_pool::make(
              std::max<size_t>(
                  xport_params.num_recv_frames * DEFAULT_RX_QUEUE_DEPTH_FACTOR, DEFAULT_RX_QUEUE_MIN_DEPTH),
              xport_params.recv_frame_size))
        , _send_buffer_pool(buffer_pool::make(
              xport_params.num_send_frames, xport_params.send_frame_size))
        , _next_recv_buff_index(0)
        , _next_send_buff_index(0)
    {
        if (parse_ipv4_string(_remote_ip_str, &_remote_ip_be) != 0) {
            throw std::runtime_error("remote IPv4 非法: " + _remote_ip_str);
        }

        _ctx.register_transport(_local_port, this);

        _rx_slot_capacity = std::max<size_t>(
            _num_recv_frames * DEFAULT_RX_QUEUE_DEPTH_FACTOR, DEFAULT_RX_QUEUE_MIN_DEPTH);
        _rx_desc_pool.resize(_rx_slot_capacity);

        const uint32_t ring_id = g_dpdk_rx_ring_id.fetch_add(1, std::memory_order_relaxed);
        const unsigned ring_size = next_pow2_ge(static_cast<unsigned>(_rx_slot_capacity + 1));

        char ready_name[64];
        char free_name[64];
        std::snprintf(ready_name, sizeof(ready_name), "t510_rx_ready_%u_%u", _local_port, ring_id);
        std::snprintf(free_name, sizeof(free_name), "t510_rx_free_%u_%u", _local_port, ring_id);

        // The ready ring can be dequeued by both:
        // 1. the normal consumer path (`recv_payload_copy` / `flush_rx`)
        // 2. the producer overflow path, which drops the oldest ready desc
        // So this ring must support multi-consumer dequeue semantics.
        _rx_ready_ring =
            rte_ring_create(ready_name, ring_size, rte_socket_id(), 0);
        _rx_free_ring =
            rte_ring_create(free_name, ring_size, rte_socket_id(), RING_F_SC_DEQ);
        if (!_rx_ready_ring || !_rx_free_ring) {
            throw std::runtime_error("rte_ring_create for rx queue failed");
        }
        for (rx_packet_desc& desc : _rx_desc_pool) {
            desc.data = _recv_buffer_pool->at(&desc - _rx_desc_pool.data());
            rte_ring_enqueue(_rx_free_ring, &desc);
        }

        for (size_t i = 0; i < get_num_recv_frames(); i++) {
            _mrb_pool.push_back(std::make_shared<dpdk_zero_copy_mrb>(this));
        }

        for (size_t i = 0; i < get_num_send_frames(); i++) {
            _msb_pool.push_back(std::make_shared<dpdk_zero_copy_msb>(
                this, _send_buffer_pool->at(i), get_send_frame_size()));
        }
    }

    ~dpdk_zero_copy_impl() override
    {
        _ctx.unregister_transport(_local_port);
        if (_rx_ready_ring) {
            void* entry = nullptr;
            while (rte_ring_dequeue(_rx_ready_ring, &entry) == 0) {
                auto* desc = static_cast<rx_packet_desc*>(entry);
                desc->len = 0;
            }
            rte_ring_free(_rx_ready_ring);
        }
        if (_rx_free_ring) {
            rte_ring_free(_rx_free_ring);
        }
    }

    managed_recv_buffer::sptr get_recv_buff(double timeout = 1.0) override
    {
        if (_next_recv_buff_index == _num_recv_frames) {
            _next_recv_buff_index = 0;
        }
        return _mrb_pool[_next_recv_buff_index]->get_new(timeout, _next_recv_buff_index);
    }

    size_t get_num_recv_frames(void) const override
    {
        return _num_recv_frames;
    }

    size_t get_recv_frame_size(void) const override
    {
        return _recv_frame_size;
    }

    managed_send_buffer::sptr get_send_buff(double timeout = 0.1, uint32_t len = 24) override
    {
        (void)len;
        if (_next_send_buff_index == _num_send_frames) {
            _next_send_buff_index = 0;
        }
        return _msb_pool[_next_send_buff_index]->get_new(timeout, _next_send_buff_index);
    }

    size_t get_num_send_frames(void) const override
    {
        return _num_send_frames;
    }

    size_t get_send_frame_size(void) const override
    {
        return _send_frame_size;
    }

    uint16_t get_local_port(void) const override
    {
        return _local_port;
    }

    std::string get_local_addr(void) const override
    {
        return _ctx.local_ip_str();
    }

    bool recv_payload_copy(std::vector<uint8_t>& payload, double timeout = 1.0) override
    {
        const uint64_t deadline = now_ns() + static_cast<uint64_t>(timeout * 1e9);

        while (true) {
            rx_packet_desc* desc = nullptr;
            if (try_pop_ready_desc(desc)) {
                payload.resize(desc->len);
                std::memcpy(payload.data(), desc->data, desc->len);
                recycle_desc(desc);
                return true;
            }

            if (now_ns() >= deadline) {
                return false;
            }
            std::this_thread::sleep_for(std::chrono::milliseconds(1));
        }
    }

    std::size_t flush_rx(void) override
    {
        std::size_t flushed = 0;
        rx_packet_desc* desc = nullptr;
        while (try_pop_ready_desc(desc)) {
            recycle_desc(desc);
            flushed++;
        }
        return flushed;
    }

    std::size_t get_dropped_rx_packets(void) const override
    {
        return _dropped_rx_packets.load(std::memory_order_relaxed);
    }

    std::size_t get_ready_rx_packets(void) const override
    {
        return _rx_ready_ring ? static_cast<std::size_t>(rte_ring_count(_rx_ready_ring)) : 0u;
    }

    std::size_t get_rx_slot_capacity(void) const override
    {
        return _rx_slot_capacity;
    }

    void enqueue_payload_copy(const uint8_t* data, size_t len) override
    {
        (void)data;
        (void)len;
    }

    bool enqueue_payload_mbuf(rte_mbuf* mbuf, uint16_t payload_offset, uint16_t payload_len) override
    {
        const uint8_t* payload = rte_pktmbuf_mtod(mbuf, const uint8_t*) + payload_offset;
        enqueue_payload_desc(payload, payload_len);
        rte_pktmbuf_free(mbuf);
        return true;
    }

    bool wait_copy_into(void* dst, size_t capacity, double timeout, size_t& out_len)
    {
        const uint64_t deadline = now_ns() + static_cast<uint64_t>(timeout * 1e9);

        while (true) {
            rx_packet_desc* desc = nullptr;
            if (try_pop_ready_desc(desc)) {
                out_len = std::min(capacity, static_cast<size_t>(desc->len));
                std::memcpy(dst, desc->data, out_len);
                recycle_desc(desc);
                return true;
            }

            if (now_ns() >= deadline) {
                return false;
            }
            std::this_thread::sleep_for(std::chrono::milliseconds(1));
        }
    }

    bool send_payload(const void* data, size_t len)
    {
        return _ctx.send_udp_payload(
            _local_port, _remote_ip_be, _remote_port, static_cast<const uint8_t*>(data), len);
    }

    bool wait_pop_ready_desc(rx_packet_desc*& desc, double timeout)
    {
        const uint64_t deadline = now_ns() + static_cast<uint64_t>(timeout * 1e9);
        while (true) {
            if (try_pop_ready_desc(desc)) {
                return true;
            }
            if (now_ns() >= deadline) {
                return false;
            }
            std::this_thread::sleep_for(std::chrono::milliseconds(1));
        }
    }

    bool try_pop_ready_desc(rx_packet_desc*& desc)
    {
        void* entry = nullptr;
        if (!_rx_ready_ring || rte_ring_dequeue(_rx_ready_ring, &entry) != 0) {
            return false;
        }
        desc = static_cast<rx_packet_desc*>(entry);
        return true;
    }

    bool wait_recv_desc_for_mrb(rx_packet_desc*& desc, double timeout)
    {
        return wait_pop_ready_desc(desc, timeout);
    }

    void recycle_desc(rx_packet_desc* desc)
    {
        if (!desc || !_rx_free_ring) {
            return;
        }
        desc->len    = 0;
        rte_ring_enqueue(_rx_free_ring, desc);
    }

    void enqueue_payload_desc(const uint8_t* payload, uint16_t payload_len)
    {
        static const bool log_rx_overflow = env_flag_enabled("IQ_TAXI_DPDK_LOG_RX_OVERFLOW", false);
        bool dropped = false;
        rx_packet_desc* desc = nullptr;

        if (!_rx_free_ring || !_rx_ready_ring) {
            return;
        }

        if (!payload || payload_len == 0u) {
            return;
        }

        if (payload_len > _recv_frame_size) {
            _dropped_rx_packets++;
            LOG_WARNING("DPDK RX payload too large: len=%u capacity=%zu dropped=%zu",
                static_cast<unsigned>(payload_len),
                _recv_frame_size,
                _dropped_rx_packets.load(std::memory_order_relaxed));
            return;
        }

        if (rte_ring_dequeue(_rx_free_ring, reinterpret_cast<void**>(&desc)) != 0) {
            if (rte_ring_dequeue(_rx_ready_ring, reinterpret_cast<void**>(&desc)) == 0) {
                dropped = true;
            } else {
                return;
            }
        }

        std::memcpy(desc->data, payload, payload_len);
        desc->len = payload_len;

        if (rte_ring_enqueue(_rx_ready_ring, desc) != 0) {
            recycle_desc(desc);
            return;
        }

        if (dropped) {
            _dropped_rx_packets++;
            if (log_rx_overflow && (_dropped_rx_packets.load(std::memory_order_relaxed) & 0xffu) == 1u) {
                LOG_WARNING("DPDK RX payload queue overflow: dropped=%zu depth=%zu",
                    _dropped_rx_packets.load(std::memory_order_relaxed),
                    _rx_slot_capacity);
            }
        }

    }

private:
    dpdk_shared_context& _ctx;
    std::string _remote_ip_str;
    uint32_t _remote_ip_be = 0;
    uint16_t _remote_port  = 0;
    uint16_t _local_port   = 0;

    const size_t _recv_frame_size, _num_recv_frames;
    const size_t _send_frame_size, _num_send_frames;
    buffer_pool::sptr _recv_buffer_pool;
    buffer_pool::sptr _send_buffer_pool;
    std::vector<std::shared_ptr<dpdk_zero_copy_msb>> _msb_pool;
    std::vector<std::shared_ptr<dpdk_zero_copy_mrb>> _mrb_pool;
    size_t _next_recv_buff_index, _next_send_buff_index;

    size_t _rx_slot_capacity = 0;
    std::vector<rx_packet_desc> _rx_desc_pool;
    rte_ring* _rx_ready_ring = nullptr;
    rte_ring* _rx_free_ring = nullptr;
    std::atomic<size_t> _dropped_rx_packets{0};
};

managed_recv_buffer::sptr dpdk_zero_copy_mrb::get_new(const double timeout, size_t& index)
{
    if (!_claimer.claim_with_wait(timeout)) {
        return sptr();
    }

    rx_packet_desc* desc = nullptr;
    if (_owner->wait_recv_desc_for_mrb(desc, timeout)) {
        attach(desc, desc->data, desc->len);
        index++;
        return make(this, _mem, _len);
    }

    _claimer.release();
    return sptr();
}

void dpdk_zero_copy_mrb::release(void)
{
    if (_desc) {
        _owner->recycle_desc(_desc);
        _desc = nullptr;
    }
    _buffer = nullptr;
    _length = 0;
    _len    = 0;
    _claimer.release();
}

void dpdk_zero_copy_msb::release(void)
{
    if (!_owner->send_payload(_mem, size())) {
        LOG_WARNING("DPDK send_payload failed");
    }
    _claimer.release();
}

} // namespace

dpdk_zero_copy::sptr dpdk_zero_copy::make(const std::string& addr,
    const std::string& port,
    const zero_copy_xport_params& default_buff_args)
{
    zero_copy_xport_params xport_params = default_buff_args;

    if (xport_params.num_recv_frames == 0) {
        xport_params.num_recv_frames = 16;
    }
    if (xport_params.num_send_frames == 0) {
        xport_params.num_send_frames = 16;
    }
    if (xport_params.recv_frame_size == 0) {
        xport_params.recv_frame_size = 8192;
    }
    if (xport_params.send_frame_size == 0) {
        xport_params.send_frame_size = 8192;
    }

    dpdk_shared_context::instance().ensure_init(xport_params);

    return std::make_shared<dpdk_zero_copy_impl>(addr, port, xport_params);
}
