//
// Created by jcc on 25-4-8.
//

#ifndef SOAPY_LOCAL_CTRL_HPP
#define SOAPY_LOCAL_CTRL_HPP

#include "sdr/core/zero_copy.hpp"
#include "sdr/core/time_spec.hpp"
#include <memory>
#include <mutex>


#define SR_CORE_READBACK 0x0030
#define SDR_CTRL_PACKET_BYTES 32u
#define SDR_CTRL_CMD_NOP 0x0000u
#define SDR_CTRL_CMD_GET_VERSION 0x0001u
#define SDR_CTRL_CMD_WRITE_REG 0x0002u
#define SDR_CTRL_CMD_READ_REG 0x0003u
#define SDR_CTRL_STATUS_OK 0x0000u

using namespace sdr::core;

enum packet_type_t {
    // VRT language:
    PACKET_TYPE_CTRL    = 0x5501,
    PACKET_TYPE_RESP    = 0x5502,
    PACKET_TYPE_RX_IQ   = 0x5503,
    PACKET_TYPE_TX_IQ   = 0x5504,
    PACKET_TYPE_TX_FC   = 0x5505,
};


typedef struct  
{
    uint16_t magic_type;
    uint16_t seq;
    uint8_t  sid;
    uint32_t packet_len;
    uint64_t timestamp;
    
} sdr_header_t;

typedef struct
{
    sdr_header_t hdr;
    uint16_t cmd_id;
    uint8_t flags;
    uint8_t target;
    uint32_t arg0;
    uint32_t arg1;
    uint32_t arg2;
} sdr_ctrl_packet_t;

typedef struct
{
    sdr_header_t hdr;
    uint16_t cmd_id;
    uint16_t status;
    uint32_t value0;
    uint32_t value1;
    uint32_t value2;
} sdr_resp_packet_t;




class local_ctrl{
public:
    typedef std::shared_ptr<local_ctrl> sptr;

    local_ctrl(zero_copy_if::sptr& xport,uint32_t sid);
    local_ctrl(zero_copy_if::sptr& xport,uint32_t sid, uint32_t buf_len);
    ~local_ctrl();

    void poke32(uint32_t addr,uint32_t data);
    uint32_t peek32(uint32_t addr);
    uint64_t peek64(uint32_t addr);

    void serialize_hdr(uint32_t * buf, sdr_header_t &  hdr);
    void deserialize_hdr(uint32_t * buf, sdr_header_t &  hdr);
    void send_pkt(uint16_t cmd_id, uint8_t flags, uint8_t target, uint32_t arg0, uint32_t arg1, uint32_t arg2);
    uint64_t wait_for_ack(bool read_back);


    void set_time(time_spec_t &time);
    time_spec_t get_time();
    void set_tick_rate(double rate);

    void clear_seq();

    void set_rx_buf_size(uint32_t len);
    void set_tx_buf_size(uint32_t len);

    void rx_buf_resize(uint32_t len);
    void tx_buf_resize(uint32_t len);

    zero_copy_if::sptr get_xport()
    {
        return _xport;
    }

private:
    std::mutex _transaction_mutex;
    bool _has_sid;
    uint32_t _sid;
    bool _has_tsf;
    uint64_t _timestamp;
    time_spec_t _time;
    double _tick_rate;
    uint16_t _tx_seq;
    uint16_t _rx_seq;
    uint32_t * _send_buf;
    uint32_t * _recv_buf;
    uint32_t _rx_buf_len;
    uint32_t _tx_buf_len;

    zero_copy_if::sptr& _xport;
};



#endif //SOAPY_LOCAL_CTRL_HPP
