#include "t510_ai/t510_ai_iq_payload.hpp"

#include "t510_ai/chdr_epid.hpp"

#include <cstring>

namespace t510_ai {
namespace {

constexpr uint32_t IQ_MAGIC = 0x54353151u; // "T51Q"
constexpr uint8_t IQ_VERSION = 1u;
constexpr std::size_t IQ_HEADER_BYTES = 16u;

static uint64_t read_le64(const uint8_t* p)
{
    return (static_cast<uint64_t>(p[7]) << 56) | (static_cast<uint64_t>(p[6]) << 48)
           | (static_cast<uint64_t>(p[5]) << 40) | (static_cast<uint64_t>(p[4]) << 32)
           | (static_cast<uint64_t>(p[3]) << 24) | (static_cast<uint64_t>(p[2]) << 16)
           | (static_cast<uint64_t>(p[1]) << 8) | static_cast<uint64_t>(p[0]);
}

static uint32_t read_be32(const uint8_t* p)
{
    return (static_cast<uint32_t>(p[0]) << 24) | (static_cast<uint32_t>(p[1]) << 16)
           | (static_cast<uint32_t>(p[2]) << 8) | static_cast<uint32_t>(p[3]);
}

static uint32_t read_le32(const uint8_t* p)
{
    return (static_cast<uint32_t>(p[3]) << 24) | (static_cast<uint32_t>(p[2]) << 16)
           | (static_cast<uint32_t>(p[1]) << 8) | static_cast<uint32_t>(p[0]);
}

static uint16_t read_be16(const uint8_t* p)
{
    return static_cast<uint16_t>((static_cast<uint16_t>(p[0]) << 8) | static_cast<uint16_t>(p[1]));
}

static uint16_t read_le16(const uint8_t* p)
{
    return static_cast<uint16_t>((static_cast<uint16_t>(p[1]) << 8) | static_cast<uint16_t>(p[0]));
}

static uint64_t read_be64(const uint8_t* p)
{
    return (static_cast<uint64_t>(p[0]) << 56) | (static_cast<uint64_t>(p[1]) << 48)
           | (static_cast<uint64_t>(p[2]) << 40) | (static_cast<uint64_t>(p[3]) << 32)
           | (static_cast<uint64_t>(p[4]) << 24) | (static_cast<uint64_t>(p[5]) << 16)
           | (static_cast<uint64_t>(p[6]) << 8) | static_cast<uint64_t>(p[7]);
}

static uint8_t chdr_get_pkt_type(uint64_t header)
{
    return static_cast<uint8_t>((header >> 53) & 0x7u);
}

static uint16_t chdr_get_length(uint64_t header)
{
    return static_cast<uint16_t>((header >> 16) & 0xffffu);
}

static uint16_t chdr_get_dst_epid(uint64_t header)
{
    return static_cast<uint16_t>(header & 0xffffu);
}

static void unpack_dual_channel_word(uint64_t word, uint64_t vita_time, t510_ai_iq_frame* frame)
{
    t510_ai_iq_sample sample;
    sample.vita_time = vita_time;
    sample.ch0_i = static_cast<int16_t>(word & 0xffffu);
    sample.ch0_q = static_cast<int16_t>((word >> 16) & 0xffffu);
    sample.ch1_i = static_cast<int16_t>((word >> 32) & 0xffffu);
    sample.ch1_q = static_cast<int16_t>((word >> 48) & 0xffffu);
    sample.ch1_valid = true;
    frame->samples.push_back(sample);
}

static void unpack_single_channel_word(uint64_t word, uint64_t vita_time, t510_ai_iq_frame* frame)
{
    t510_ai_iq_sample sample0;
    t510_ai_iq_sample sample1;

    sample0.vita_time = vita_time;
    sample0.ch0_i = static_cast<int16_t>(word & 0xffffu);
    sample0.ch0_q = static_cast<int16_t>((word >> 16) & 0xffffu);
    sample0.ch1_valid = false;

    sample1.vita_time = vita_time + 1u;
    sample1.ch0_i = static_cast<int16_t>((word >> 32) & 0xffffu);
    sample1.ch0_q = static_cast<int16_t>((word >> 48) & 0xffffu);
    sample1.ch1_valid = false;

    frame->samples.push_back(sample0);
    frame->samples.push_back(sample1);
}

} // namespace

bool extract_iq_capture_payload_from_chdr(
    const std::vector<uint8_t>& chdr_packet,
    uint64_t* seq_out,
    std::vector<uint8_t>& iq_payload_out,
    std::string* error_out)
{
    const uint8_t* iq_payload_ptr = nullptr;
    std::size_t iq_payload_len = 0;
    if (!extract_iq_capture_payload_from_chdr(chdr_packet.data(),
            chdr_packet.size(),
            seq_out,
            &iq_payload_ptr,
            &iq_payload_len,
            error_out)) {
        return false;
    }
    iq_payload_out.assign(iq_payload_ptr, iq_payload_ptr + static_cast<std::ptrdiff_t>(iq_payload_len));
    return true;
}

bool extract_iq_capture_payload_from_chdr(
    const uint8_t* chdr_packet,
    std::size_t chdr_packet_len,
    uint64_t* seq_out,
    const uint8_t** iq_payload_ptr_out,
    std::size_t* iq_payload_len_out,
    std::string* error_out)
{
    uint64_t chdr_header = 0;
    uint16_t packet_bytes = 0;
    uint16_t payload_bytes = 0;

    if (!chdr_packet || chdr_packet_len < CHDR_NET_WORD_BYTES) {
        if (error_out) {
            *error_out = "packet shorter than CHDR header";
        }
        return false;
    }

    chdr_header = read_le64(chdr_packet);
    if (chdr_get_pkt_type(chdr_header) != CHDR_PKT_TYPE_DATA) {
        if (error_out) {
            *error_out = "packet is not CHDR DATA";
        }
        return false;
    }

    if (chdr_get_dst_epid(chdr_header) != IQ_CAPTURE_DST_EPID) {
        if (error_out) {
            *error_out = "packet dst_epid is not IQ capture";
        }
        return false;
    }

    packet_bytes = chdr_get_length(chdr_header);
    if (packet_bytes < CHDR_NET_WORD_BYTES || chdr_packet_len < packet_bytes) {
        if (error_out) {
            *error_out = "packet length field is invalid";
        }
        return false;
    }

    payload_bytes = static_cast<uint16_t>(packet_bytes - CHDR_NET_WORD_BYTES);
    if (seq_out) {
        *seq_out = static_cast<uint16_t>((chdr_header >> 32) & 0xffffu);
    }

    if (iq_payload_ptr_out) {
        *iq_payload_ptr_out = chdr_packet + CHDR_NET_WORD_BYTES;
    }
    if (iq_payload_len_out) {
        *iq_payload_len_out = payload_bytes;
    }
    return true;
}

bool parse_iq_capture_payload(
    const std::vector<uint8_t>& iq_payload,
    uint64_t seq,
    t510_ai_iq_frame* frame_out,
    std::string* error_out)
{
    return parse_iq_capture_payload(
        iq_payload.data(), iq_payload.size(), seq, frame_out, error_out);
}

bool parse_iq_capture_payload(
    const uint8_t* iq_payload,
    std::size_t iq_payload_len,
    uint64_t seq,
    t510_ai_iq_frame* frame_out,
    std::string* error_out)
{
    t510_ai_iq_frame frame;
    std::size_t offset = 0;
    bool payload_little_endian = false;

    if (!frame_out) {
        if (error_out) {
            *error_out = "frame_out is null";
        }
        return false;
    }

    if (!iq_payload || iq_payload_len < IQ_HEADER_BYTES) {
        if (error_out) {
            *error_out = "iq payload shorter than 16-byte header";
        }
        return false;
    }

    if (read_be32(iq_payload) == IQ_MAGIC) {
        payload_little_endian = false;
    } else if (read_le32(iq_payload + 4) == IQ_MAGIC) {
        payload_little_endian = true;
    } else {
        if (error_out) {
            *error_out = "iq payload magic mismatch";
        }
        return false;
    }

    if (payload_little_endian) {
        if (iq_payload[3] != IQ_VERSION) {
            if (error_out) {
                *error_out = "iq payload version mismatch";
            }
            return false;
        }
        frame.channel_enable = iq_payload[2];
        frame.sample_bytes = read_le16(iq_payload);
        frame.first_vita_time = read_le64(iq_payload + 8);
    } else {
        if (iq_payload[4] != IQ_VERSION) {
            if (error_out) {
                *error_out = "iq payload version mismatch";
            }
            return false;
        }
        frame.channel_enable = iq_payload[5];
        frame.sample_bytes = read_be16(iq_payload + 6);
        frame.first_vita_time = read_be64(iq_payload + 8);
    }

    frame.seq = seq;

    if (iq_payload_len != IQ_HEADER_BYTES + frame.sample_bytes) {
        if (error_out) {
            *error_out = "iq payload byte count does not match header";
        }
        return false;
    }

    if ((frame.sample_bytes % 8u) != 0u) {
        if (error_out) {
            *error_out = "sample_bytes is not 8-byte aligned";
        }
        return false;
    }

    for (offset = IQ_HEADER_BYTES; offset < iq_payload_len; offset += 8u) {
        const uint64_t packed_word = payload_little_endian
                                         ? read_le64(iq_payload + offset)
                                         : read_be64(iq_payload + offset);
        frame.packed_words.push_back(packed_word);
        if ((frame.channel_enable & 0x2u) != 0u) {
            unpack_dual_channel_word(
                packed_word,
                frame.first_vita_time + static_cast<uint64_t>(frame.packed_words.size() - 1u),
                &frame);
        } else {
            unpack_single_channel_word(
                packed_word,
                frame.first_vita_time + static_cast<uint64_t>((frame.packed_words.size() - 1u) * 2u),
                &frame);
        }
    }

    *frame_out = std::move(frame);
    return true;
}

} // namespace t510_ai
