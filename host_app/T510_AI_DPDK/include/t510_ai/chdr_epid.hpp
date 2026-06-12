#ifndef T510_AI_CHDR_EPID_HPP
#define T510_AI_CHDR_EPID_HPP

#include <cstddef>
#include <cstdint>

namespace t510_ai {

constexpr uint16_t DEFAULT_CTRL_PORT = 49208;
constexpr uint16_t DEFAULT_DATA_PORT = 49200;

// These EPIDs match the current FPGA endpoint in chdr_epid_loopback.sv.
constexpr uint16_t SINK_DST_EPID        = 0x4000;
constexpr uint16_t SOURCE_CTRL_DST_EPID = 0x4001;
constexpr uint16_t IQ_CAPTURE_DST_EPID  = 0x4002;
constexpr uint16_t RETURN_DST_EPID      = 0x1234;

constexpr uint8_t CHDR_PKT_TYPE_DATA = 6;
constexpr uint8_t CHDR_PKT_TYPE_MGMT = 0;

constexpr uint16_t CHDR_PROTO_VER      = 0x0100;
constexpr uint8_t CHDR_MGMT_WIDTH_512  = 3;
constexpr uint8_t CHDR_MGMT_OP_ADVERTISE = 1;
constexpr std::size_t CHDR_NET_WORD_BYTES = 64;

constexpr uint32_t TEST_MAGIC        = 0x54353130u; // "T510"
constexpr uint16_t TEST_VERSION      = 1u;
constexpr std::size_t TEST_HEADER_SIZE = 28u;

constexpr uint32_t SOURCE_CTRL_MAGIC   = 0x53524331u; // "SRC1"
constexpr uint16_t SOURCE_CTRL_VERSION = 1u;
constexpr uint16_t SOURCE_CTRL_CMD_STOP  = 0u;
constexpr uint16_t SOURCE_CTRL_CMD_START = 1u;

} // namespace t510_ai

#endif
