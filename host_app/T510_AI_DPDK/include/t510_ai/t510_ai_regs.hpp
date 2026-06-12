#ifndef __LOCAL_E100_REGS_H__
#define __LOCAL_E100_REGS_H__

#include "cstdint"

namespace t510_ai_regs {
    constexpr uint32_t CUSTOM_SET_RX_CH1_GAIN_ADDR            =  0x0000;
    constexpr uint32_t CUSTOM_SET_TX_CH1_GAIN_ADDR            =  0x0002;
    constexpr uint32_t CUSTOM_SET_SAMPLE_CLOCK_RATE_ADDR      =  0x0006;
    constexpr uint32_t CUSTOM_SET_ACTIVE_CHANNEL_ADDR         =  0x0007;
    constexpr uint32_t CUSTOM_SET_RX_CH1_LO_FREQ_LOW_ADDR     =  0x0008;
    constexpr uint32_t CUSTOM_SET_RX_CH1_LO_FREQ_HIGH_ADDR    =  0x0009;
    constexpr uint32_t CUSTOM_SET_TX_CH1_LO_FREQ_LOW_ADDR     =  0x000a;
    constexpr uint32_t CUSTOM_SET_TX_CH1_LO_FREQ_HIGH_ADDR    =  0x000b;
    constexpr uint32_t CUSTOM_SET_TIME_MODE_ADDR              =  0x000d;
    constexpr uint32_t CUSTOM_SET_VITA_TIMESTAMP_LOW_ADDR     =  0x000e;
    constexpr uint32_t CUSTOM_SET_VITA_TIMESTAMP_HIGH_ADDR    =  0x000f;
    constexpr uint32_t CUSTOM_SET_CHANNEL_ENABLE_ADDR         =  0x0012;
    constexpr uint32_t CUSTOM_SET_RX_SAMPLE_NUMS_ADDR         =  0x0013;
    constexpr uint32_t CUSTOM_SET_CAPTURE_START_ADDR          =  0x0014;
    constexpr uint32_t CUSTOM_SET_RX_MODE                     =  0x0015;
    constexpr uint32_t CUSTOM_SET_RX_MODE_EXIT                =  0x0016;
    constexpr uint32_t CUSTOM_SET_RX_STREAM_START             =  0x0017;
    constexpr uint32_t CUSTOM_SET_RX_MAX_PACKET_BYTES         =  0x0018;
    constexpr uint32_t CUSTOM_SET_START_RX                    =  0x001b;
    constexpr uint32_t CUSTOM_SET_STOP_RX                     =  0x001c;
    constexpr uint32_t CUSTOM_SET_SAMPLE_RATE_DY              =  0x002c;
    constexpr uint32_t CUSTOM_SET_RB_ADDR                     =  0x0030;
    constexpr uint32_t CUSTOM_RB_GET_RX_CH1_GAIN_ADDR         =  0x0001;
    constexpr uint32_t CUSTOM_RB_GET_TX_CH1_GAIN_ADDR         =  0x0003;
    constexpr uint32_t CUSTOM_RB_GET_SAMPLE_CLOCK_RATE_ADDR   =  0x0007;
    constexpr uint32_t CUSTOM_RB_GET_ACTIVE_CHANNEL_ADDR      =  0x0008;
    constexpr uint32_t CUSTOM_RB_GET_RX_CH1_LO_FREQ_LOW_ADDR  =  0x0009;
    constexpr uint32_t CUSTOM_RB_GET_RX_CH1_LO_FREQ_HIGH_ADDR =  0x000a;
    constexpr uint32_t CUSTOM_RB_GET_TX_CH1_LO_FREQ_LOW_ADDR  =  0x000b;
    constexpr uint32_t CUSTOM_RB_GET_TX_CH1_LO_FREQ_HIGH_ADDR =  0x000c;
    constexpr uint32_t CUSTOM_RB_GET_VITA_TIME_ADDR           =  0x0010;
    constexpr uint32_t CUSTOM_RB_GET_VITA_TIME_LAST_PPS_ADDR  =  0x0011;
}

#endif
