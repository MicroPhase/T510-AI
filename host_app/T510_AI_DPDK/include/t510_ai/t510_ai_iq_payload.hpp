#ifndef T510_AI_IQ_PAYLOAD_HPP
#define T510_AI_IQ_PAYLOAD_HPP

#include <cstddef>
#include <cstdint>
#include <string>
#include <vector>

namespace t510_ai {

struct t510_ai_iq_sample
{
    uint64_t vita_time = 0;
    int16_t ch0_i = 0;
    int16_t ch0_q = 0;
    int16_t ch1_i = 0;
    int16_t ch1_q = 0;
    bool ch1_valid = false;
};

struct t510_ai_iq_frame
{
    uint64_t seq = 0;
    uint8_t channel_enable = 0;
    uint16_t sample_bytes = 0;
    uint64_t first_vita_time = 0;
    std::vector<uint64_t> packed_words;
    std::vector<t510_ai_iq_sample> samples;
};

bool extract_iq_capture_payload_from_chdr(
    const std::vector<uint8_t>& chdr_packet,
    uint64_t* seq_out,
    std::vector<uint8_t>& iq_payload_out,
    std::string* error_out);

bool extract_iq_capture_payload_from_chdr(
    const uint8_t* chdr_packet,
    std::size_t chdr_packet_len,
    uint64_t* seq_out,
    const uint8_t** iq_payload_ptr_out,
    std::size_t* iq_payload_len_out,
    std::string* error_out);

bool parse_iq_capture_payload(
    const std::vector<uint8_t>& iq_payload,
    uint64_t seq,
    t510_ai_iq_frame* frame_out,
    std::string* error_out);

bool parse_iq_capture_payload(
    const uint8_t* iq_payload,
    std::size_t iq_payload_len,
    uint64_t seq,
    t510_ai_iq_frame* frame_out,
    std::string* error_out);

} // namespace t510_ai

#endif
