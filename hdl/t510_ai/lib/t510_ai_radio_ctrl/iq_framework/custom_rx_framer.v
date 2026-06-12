`default_nettype none
`timescale 1ns / 1ps

module custom_rx_framer(
    input   wire            clk                         ,
    input   wire            rst                         ,
    input   wire    [63:0]  vita_time_cpack             ,
    input   wire    [63:0]  cpack_data                  ,
    input   wire            cpack_valid                 ,

    input   wire    [7:0]   channel_enable              , /*synthesis keep*/ // how many channels were enabled
    input   wire    [1:0]   rx_mode                     , /*synthesis keep*/ // set rx mode
    input   wire            rx_mode_strobe              , /*synthesis keep*/ // rx mode valid
    input   wire            mode_exit                   , /*synthesis keep*/ // change to other mode, for example stream mode to packet mode
    input   wire            stream_start                , /*synthesis keep*/ // continuous stream start signal
    input   wire    [63:0]  rx_sync_timestamp           , /*synthesis keep*/ // when sync mode is enable, sample will be captured when the vitatime match this time value
    input   wire            rx_sync_timestamp_strobe    , /*synthesis keep*/ // rx_sync_timestamp valid signal
    input   wire            capture_one_block           , /*synthesis keep*/ // capture one packet
    input   wire    [31:0]  rx_sample_bytes             , /*synthesis keep*/ // 用户一次需要的采样点的字节长度
    input   wire    [31:0]  max_sample_bytes_per_packet , /*synthesis keep*/ // 一个数据包里面最多有多少个采样点，以字节长度
    input   wire    [15:0]  dma_s2mm_pkt_per_burst      , /*synthesis keep*/ 

    output  wire            rx_tvalid                   ,
    output  wire    [63:0]  rx_tdata                    ,
    output  wire            rx_tlast                    ,
    input   wire            rx_tready /*synthesis keep*/          
    );

    //====================================================
    //parameter define
    //====================================================
    localparam  IDLE                = 14'b00_0000_0000_0001;
    localparam  MODE_CFG            = 14'b00_0000_0000_0010;
    localparam  PREPARE_STREAM      = 14'b00_0000_0000_0100;
    localparam  STREAM_TIME         = 14'b00_0000_0000_1000;
    localparam  STREAM_DUMP         = 14'b00_0000_0001_0000;
    localparam  STREAM              = 14'b00_0000_0010_0000;
    localparam  PREPARE_PACKET      = 14'b00_0000_0100_0000;
    localparam  PACKET_TIME         = 14'b00_0000_1000_0000;
    localparam  PACKET              = 14'b00_0001_0000_0000;
    localparam  PACKET_DUMP         = 14'b00_0010_0000_0000;
    localparam  PREPARE_SYNC_RX     = 14'b00_0100_0000_0000;
    localparam  SYNC_TIME           = 14'b00_1000_0000_0000;
    localparam  SYNC_PACKET         = 14'b01_0000_0000_0000;
    localparam  SYNC_DUMP           = 14'b10_0000_0000_0000;


    localparam  OUT_IDLE = 2'd0;
    localparam  OUT_HEAD = 2'd1;
    localparam  OUT_TIME = 2'd2;
    localparam  OUT_BODY = 2'd3;

    localparam  STREAM_MODE = 2'd1;
    localparam  PACKET_MODE = 2'd2;
    localparam  SYNC_MODE = 2'd3;

    localparam  MAGIC_HEAD_RX = 16'h5503;
    
    //====================================================
    //internal signal and register
    //====================================================

    reg [13:0]          state = IDLE       ; // state rx工作模式控制状态机
    reg [13:0]          state_dly = IDLE   ; // 状态机延时一拍，方便调试的时候确定各个状态的跳转

    reg [31:0]          cnt_packed_bytes;               /*synthesis keep*/    //计数当前已经打包了多少samples
    reg [31:0]          cnt_packed_bytes_per_packet;    /*synthesis keep*/    //计数当前一个数据包内已经打包了多少samples
    wire [4:0]          samples_per_packed_data;        /*synthesis keep*/    //当前每个传输的数据当中包含多少个sample
    wire [4:0]          bytes_per_packed_data;          /*synthesis keep*/    // 每个传输的数据有多少bytes
    reg                 sync_rx_time_stamp_valid    ;   /*synthesis keep*/    // 标志同步接收的时间戳有效
    wire                user_buffer_done    ;           /*synthesis keep*/    // 一整个帧结束, 比如用户需要的4096个采样点全部发送完毕
    wire                one_packet_done     ;           /*synthesis keep*/    // 一个分包的结束， 比如4096个采样点，按照一定长度进行分批次发送，其中的一个包结束

    reg                 wr_time_fifo_en;    /*synthesis keep*/          // 记录时间戳的fifo写使能
    wire [63:0]         wr_time_fifo_data;  /*synthesis keep*/         // 记录的时间戳
    wire                rd_time_fifo_en;    /*synthesis keep*/           // 组帧的时候读取时间戳使能
    wire [63:0]         rd_time_fifo_data;  /*synthesis keep*/         // 从fifo当中读取的时间戳信息
    wire                time_fifo_full;     /*synthesis keep*/
    wire                time_fifo_empty;    /*synthesis keep*/
    wire [6 : 0]        time_data_count;    /*synthesis keep*/

    reg                 wr_head_fifo_en;   /*synthesis keep*/         // 记录包头的fifo写使能
    wire [63:0]         wr_head_fifo_data; /*synthesis keep*/         // 记录包头数据
    wire                rd_head_fifo_en;   /*synthesis keep*/         // 组帧的时候读包头使能
    wire [63:0]         rd_head_fifo_data; /*synthesis keep*/         // 从fifo当中读取的包头信息
    wire                head_fifo_full;    /*synthesis keep*/
    wire                head_fifo_empty;   /*synthesis keep*/
    wire [6 : 0]        head_data_count;   /*synthesis keep*/


    reg                 wr_data_fifo_en;        /*synthesis keep*/  // 要缓存的数据
    reg                 wr_data_tlast;          /*synthesis keep*/  // 一帧数据的最后一个数据
    reg                 wr_data_terror;         /*synthesis keep*/  // 该帧数据是否存在错误
    wire    [65:0]      wr_data_fifo_data;      /*synthesis keep*/  //64bit data, 1bit tlast, 1bit terror
    wire                rd_data_fifo_en;        /*synthesis keep*/  // pop pakcet enable
    wire    [65:0]      rd_data_fifo_data;      /*synthesis keep*/
    wire                data_fifo_full;         /*synthesis keep*/  
    wire                data_fifo_empty;        /*synthesis keep*/ 
    wire                data_fifo_almost_full;  /*synthesis keep*/  // data fifo 快要满，一帧中间可能不连续，需要丢弃这个包
    wire    [9:0]       data_fifo_count;        /*synthesis keep*/  

    reg  [3:0]          out_state           ; // state machine 用于产生输出的数据
    wire                time_fifo_tvalid    ; /*synthesis keep*/   // 上游模块时间戳有效
    wire [63:0]         time_fifo_tdata     ; /*synthesis keep*/   // 上游模块输出的有效的时间戳
    wire                time_fifo_tready    ; /*synthesis keep*/   // 下游模块ready to pop时间戳
    wire                head_fifo_tvalid    ; /*synthesis keep*/   // 上游模块时间戳有效
    wire [63:0]         head_fifo_tdata     ; /*synthesis keep*/   // 上游模块输出的有效的时间戳
    wire                head_fifo_tready    ; /*synthesis keep*/   // 下游模块ready to pop时间戳
    wire                data_fifo_tvalid    ; /*synthesis keep*/   // 上游模块数据有效
    wire [65:0]         data_fifo_tdata     ; /*synthesis keep*/   
    wire                data_fifo_tready    ; /*synthesis keep*/  

    reg     [31:0]      cnt_frame_bytes     ;

    wire                out_tvalid          ; /*synthesis keep*/   // 产生的组帧数据
    wire                out_tready          ; /*synthesis keep*/   // 帧校验模块ready信号
    wire                out_tlast           ; /*synthesis keep*/   
    wire                out_terror          ; /*synthesis keep*/   //当前帧错误标志信号
    wire [63:0]         out_tdata           ; /*synthesis keep*/  
    wire                out_tlast_int       ; /*synthesis keep*/  

    reg [15:0]          rx_seq                      ; // 当前包的序列号
    reg [31:0]          packet_length_in_bytes      ; // 一个数据包的字节长度
    reg [31:0]          sample_left_in_bytes        ; // 还剩多少字节数据没有发送完毕
    reg                 one_packet_last             ; // 一帧数据结束
    reg                 one_packet_error            ; // 一帧数据出现错误

    
    // every 64bit have how many samples? for example, 1r1t, 64bit have 2samples, 2r2t 64bit have 1 sample
    assign samples_per_packed_data = (channel_enable=='d1) ? 2 : ((channel_enable=='d3) ? 'd1 : 0);
    assign bytes_per_packed_data = 8;



    

    always @(posedge clk ) begin
        if (rst==1'b1) begin
            state <= IDLE;
        end else begin
            case (state)
                IDLE : begin
                    state <= MODE_CFG;
                end

                MODE_CFG : begin
                    if ((rx_mode==STREAM_MODE) & rx_mode_strobe) begin
                        // 进入连续流模式
                        state <= PREPARE_STREAM;
                    end else if ((rx_mode==PACKET_MODE) & rx_mode_strobe) begin
                        // 进入包模式
                        state <= PREPARE_PACKET;
                    end else if ((rx_mode==SYNC_MODE) & rx_mode_strobe) begin
                        // 进入同步包模式
                        state <= PREPARE_SYNC_RX;
                    end
                end

                PREPARE_STREAM : begin
                    if (stream_start) begin
                        // 当前连续流的参数：每个包的samples已经配置完成之后，启动连续流模式
                        // 先进入连续流包头获取
                        state <= STREAM_TIME;
                    end
                end

                STREAM_TIME : begin
                    if (mode_exit) begin
                        // 退出当前模式
                        state <= MODE_CFG;
                    end else if (cpack_valid) begin
                        // 当前时间戳已保存，进入获取一帧连续IQ状态
                        state <= STREAM;
                    end
                end


                STREAM : begin
                    // mode changed, exit stream mode 
                    if (mode_exit) begin
                        state <= MODE_CFG;
                    end else if (user_buffer_done) begin
                        // 连续流模式下，已经填充好完整的用户数据，准备开始填充下一个完整的用户数据
                        state <= STREAM_TIME;
                    end else if (one_packet_done) begin
                        // 连续流模式下，已经填充完一个包的数据，准备填充下一个数据包
                        state <= STREAM_TIME;
                    end else if (data_fifo_almost_full & cpack_valid) begin
                        // 连续流模式下，出现了数据溢出的情况
                        state <= STREAM_DUMP;
                    end
                end

                STREAM_DUMP: begin
                    if(out_tlast & out_tvalid & out_tready & out_terror)begin
                        // 当前已经将出现错误的包处理完毕，可以考虑获取信号数据帧
                        state <= STREAM_TIME;
                    end else if (mode_exit) begin
                        state <= MODE_CFG;
                    end
                end


                PREPARE_PACKET : begin
                    if (capture_one_block) begin
                        // 启动获取一帧数据
                        state <= PACKET_TIME;
                    end else if (mode_exit) begin
                        // 退出当前传输模式
                        state <= MODE_CFG;
                    end 
                end

                PACKET_TIME : begin
                    if (cpack_valid) begin
                        // 包模式下已经获取了时间戳，开始填充这一个数据帧的数据
                        state <= PACKET;
                    end
                end

                PACKET : begin
                    if (user_buffer_done) begin
                        // 当前一帧包已经准备完毕，并且没有出现错误
                        state <= PREPARE_PACKET;
                    end else if (one_packet_done) begin
                        // 包模式下，已经填充完一个包的数据，但是用户所需要的数据还没完全发送，准备填充下一个数据包
                        state <= PACKET_TIME;
                    end else if (data_fifo_almost_full & cpack_valid) begin
                        // 包模式下出现了溢出， DUMP这个包
                        state <= PACKET_DUMP;
                    end
                end

                PACKET_DUMP: begin
                    if(out_tlast & out_tvalid & out_tready & out_terror)begin
                        // 包模式溢出处理完毕，准备一个新的包
                        state <= PACKET_TIME;
                    end else if (mode_exit) begin
                        state <= MODE_CFG;
                    end
                end

                PREPARE_SYNC_RX : begin
                    if ((sync_rx_time_stamp_valid==1'b1) & (vita_time_cpack >= rx_sync_timestamp-1)) begin
                        // 同步采集还未完成，并且当前本地时间戳已经满足需求时间戳需求
                        state <= SYNC_TIME;
                    end else if (mode_exit) begin
                        // 退出当前模式
                        state <= MODE_CFG;
                    end
                end

                SYNC_TIME : begin
                    if (cpack_valid) begin
                        // 同步采集时间戳
                        state <= SYNC_PACKET;
                    end
                end

                SYNC_PACKET : begin
                    if (user_buffer_done) begin
                        // 同步采集数据填充完毕
                        state <= PREPARE_SYNC_RX;
                    end else if (one_packet_done) begin
                        // 同步采集模式下，已经填充完一个包的数据，但是用户所需要的数据还没完全发送，准备填充下一个数据包
                        state <= SYNC_TIME;
                    end else if (data_fifo_almost_full & cpack_valid) begin
                        // 同步采集溢出
                        state <= SYNC_DUMP;
                    end
                end

                SYNC_DUMP: begin
                    if(out_tlast & out_tvalid & out_tready & out_terror)begin
                        // 同步采集溢出处理完毕
                        state <= SYNC_TIME;
                    end else if (mode_exit) begin
                        state <= MODE_CFG;
                    end
                end

                default : state <= IDLE;
            endcase
        end
    end

    always @(posedge clk ) begin
        if (rst==1'b1) begin
            cnt_packed_bytes <= 'd0;
        end else if (state == STREAM_TIME || state == STREAM) begin
            if (user_buffer_done) begin
                // 流模式下，填充完用户需要的所有数据帧,计数器清零
                cnt_packed_bytes <= 'd0;
            end else if (data_fifo_almost_full & cpack_valid) begin
                // 流模式下发生溢出，计数器清零
                cnt_packed_bytes <= 'd0;
            end else if (mode_exit) begin
                // 流模式退出，计数器清零
                cnt_packed_bytes <= 'd0;
            end else if (cpack_valid) begin
                cnt_packed_bytes <= cnt_packed_bytes + bytes_per_packed_data;
            end
        end else if (state == PACKET_TIME || state == PACKET) begin
            if (user_buffer_done) begin
                // 包模式下，填充完用户需要的所有数据帧,计数器清零
                cnt_packed_bytes <= 'd0;
            end else if (data_fifo_almost_full & cpack_valid) begin
                // 包模式下发生溢出，计数器清零
                cnt_packed_bytes <= 'd0;
            end else if (cpack_valid) begin
                cnt_packed_bytes <= cnt_packed_bytes + bytes_per_packed_data;
            end
        end else if (state == SYNC_TIME || state == SYNC_PACKET) begin
            if (user_buffer_done) begin
                // 同步采集模式下填充完用户需要的所有数据帧,计数器清零
                cnt_packed_bytes <= 'd0;
            end else if (data_fifo_almost_full & cpack_valid) begin
                // 同步采集模式下发生溢出，丢弃本帧包
                cnt_packed_bytes <= 'd0;
            end else if (cpack_valid) begin
                cnt_packed_bytes <= cnt_packed_bytes + bytes_per_packed_data;
            end
        end
    end

    //
    assign user_buffer_done = (cnt_packed_bytes == (rx_sample_bytes - bytes_per_packed_data)) & cpack_valid;
    assign one_packet_done = (cnt_packed_bytes_per_packet == (max_sample_bytes_per_packet - bytes_per_packed_data)) & cpack_valid;


    always @(posedge clk ) begin
        if (rst==1'b1) begin
            cnt_packed_bytes_per_packet <= 'd0;
        end else if (state == STREAM_TIME || state == STREAM) begin
            if (one_packet_done) begin
                // 流模式下，填充完一个数据包,计数器清零
                cnt_packed_bytes_per_packet <= 'd0;
            end else if (user_buffer_done) begin
                // 流模式下，填充完用户需要的所有数据帧,计数器清零
                cnt_packed_bytes_per_packet <= 'd0;
            end  else if (data_fifo_almost_full & cpack_valid) begin
                // 流模式下发生溢出，计数器清零
                cnt_packed_bytes_per_packet <= 'd0;
            end else if (mode_exit) begin
                // 流模式退出，计数器清零
                cnt_packed_bytes_per_packet <= 'd0;
            end else if (cpack_valid) begin
                cnt_packed_bytes_per_packet <= cnt_packed_bytes_per_packet + bytes_per_packed_data;
            end
        end else if (state == PACKET_TIME || state == PACKET) begin
            if (one_packet_done) begin
                // 包模式下，填充完一个数据帧,计数器清零
                cnt_packed_bytes_per_packet <= 'd0;
            end else if (user_buffer_done) begin
                // 流模式下，填充完用户需要的所有数据帧,计数器清零
                cnt_packed_bytes_per_packet <= 'd0;
            end else if (data_fifo_almost_full & cpack_valid) begin
                // 包模式下发生溢出，计数器清零
                cnt_packed_bytes_per_packet <= 'd0;
            end else if (mode_exit) begin
                // 流模式退出，计数器清零
                cnt_packed_bytes_per_packet <= 'd0;
            end else if (cpack_valid) begin
                cnt_packed_bytes_per_packet <= cnt_packed_bytes_per_packet + bytes_per_packed_data;
            end
        end else if (state == SYNC_TIME || state == SYNC_PACKET) begin
            if (one_packet_done) begin
                // 同步采集模式下，填充完一个数据帧,计数器清零
                cnt_packed_bytes_per_packet <= 'd0;
            end else if (user_buffer_done) begin
                // 流模式下，填充完用户需要的所有数据帧,计数器清零
                cnt_packed_bytes_per_packet <= 'd0;
            end else if (data_fifo_almost_full & cpack_valid) begin
                // 同步采集模式下发生溢出，计数器清零
                cnt_packed_bytes_per_packet <= 'd0;
            end else if (mode_exit) begin
                // 流模式退出，计数器清零
                cnt_packed_bytes_per_packet <= 'd0;
            end else if (cpack_valid) begin
                cnt_packed_bytes_per_packet <= cnt_packed_bytes_per_packet + bytes_per_packed_data;
            end
        end
    end



    // 一帧数据对应的状态，包结束和包错误标志信号。与数据包组合到一起
    always @(*) begin
        if ((state==STREAM)) begin
            if (one_packet_done) begin
                // 连续流模式下，完成一帧包的组帧工作
                one_packet_last = 1'b1;
                one_packet_error = 1'b0;
            end else if (data_fifo_almost_full & cpack_valid) begin
                // 连续流模式下，data fifo发生了溢出
                one_packet_last = 1'b1;
                one_packet_error = 1'b1;
            end else if (mode_exit) begin
                // 在流模式运行的时候，退出连续流模式，需要将这个包标志位错误，并丢弃这个包
                one_packet_last = 1'b1;
                one_packet_error = 1'b1;
            end else begin
                one_packet_last = 1'b0;
                one_packet_error = 1'b0;
            end
        end else if ((state==PACKET)) begin
            if (one_packet_done) begin
                one_packet_last = 1'b1;
                one_packet_error = 1'b0;
            end else if (data_fifo_almost_full & cpack_valid) begin
                one_packet_last = 1'b1;
                one_packet_error = 1'b1;
            end else begin
                one_packet_last = 1'b0;
                one_packet_error = 1'b0;
            end
        end else if ((state==SYNC_PACKET)) begin
            if (one_packet_done) begin
                one_packet_last = 1'b1;
                one_packet_error = 1'b0;
            end else if (data_fifo_almost_full & cpack_valid) begin
                one_packet_last = 1'b1;
                one_packet_error = 1'b1;
            end else begin
                one_packet_last = 1'b0;
                one_packet_error = 1'b0;
            end
        end else begin
            one_packet_last = 1'b0;
            one_packet_error = 1'b0;
        end
    end

    always @(posedge clk ) begin
        if (rst==1'b1) begin
            sample_left_in_bytes <= 'd0;
        end else if((state == PREPARE_STREAM) & stream_start)begin
            sample_left_in_bytes <= rx_sample_bytes;
        end else if((state == PREPARE_PACKET) & capture_one_block)begin
            sample_left_in_bytes <= rx_sample_bytes;
        end else if((state == PREPARE_SYNC_RX) & (sync_rx_time_stamp_valid==1'b1) & (vita_time_cpack >= rx_sync_timestamp-1))begin
            sample_left_in_bytes <= rx_sample_bytes;
        end else if(state == STREAM)begin
            if (user_buffer_done) begin
                sample_left_in_bytes <= rx_sample_bytes;
            end else if(one_packet_last & (~one_packet_error))begin
                sample_left_in_bytes <= (rx_sample_bytes-bytes_per_packed_data) - cnt_packed_bytes;
            end else if (one_packet_error) begin
                sample_left_in_bytes <= rx_sample_bytes;
            end
        end else if((state == PACKET))begin
            if (user_buffer_done) begin
                sample_left_in_bytes <= rx_sample_bytes;
            end else if(one_packet_last & (~one_packet_error))begin
                sample_left_in_bytes <= (rx_sample_bytes-bytes_per_packed_data) - cnt_packed_bytes;
            end else if (one_packet_error) begin
                sample_left_in_bytes <= rx_sample_bytes;
            end
        end else if((state == SYNC_PACKET)) begin
            if (user_buffer_done) begin
                sample_left_in_bytes <= rx_sample_bytes;
            end else if(one_packet_last & (~one_packet_error))begin
                sample_left_in_bytes <= (rx_sample_bytes-bytes_per_packed_data) - cnt_packed_bytes;
            end else if (one_packet_error) begin
                sample_left_in_bytes <= rx_sample_bytes;
            end
        end
    end

    always @(posedge clk ) begin
        if (rst==1'b1) begin
            packet_length_in_bytes <= 'd0;
        end else if (state == STREAM_TIME) begin
            if(sample_left_in_bytes >= max_sample_bytes_per_packet) begin
                packet_length_in_bytes <= max_sample_bytes_per_packet + 16;
            end else begin
                packet_length_in_bytes <= sample_left_in_bytes+16;
            end
        end else if (state == PACKET_TIME) begin
            if(sample_left_in_bytes >= max_sample_bytes_per_packet) begin
                packet_length_in_bytes <= max_sample_bytes_per_packet + 16;
            end else begin
                packet_length_in_bytes <= sample_left_in_bytes+16;
            end
        end else if (state == SYNC_TIME) begin
            if(sample_left_in_bytes >= max_sample_bytes_per_packet) begin
                packet_length_in_bytes <= max_sample_bytes_per_packet + 16;
            end else begin
                packet_length_in_bytes <= sample_left_in_bytes+16;
            end
        end
    end
    


    always @(posedge clk ) begin
        if (rst==1'b1) begin
            sync_rx_time_stamp_valid <= 1'b0;
        end else if (rx_sync_timestamp_strobe == 1'b1) begin
            // 开始同步采集
            sync_rx_time_stamp_valid <= 1'b1;
        end else if(state==SYNC_PACKET & (user_buffer_done))begin
            // 同步采集模式下，一个同步包采集完毕
            sync_rx_time_stamp_valid <=  1'b0;
        end
    end


    

    // 在流模式，包模式，同步采集模式下保存一帧数据的时间戳使能信号
    always @(*) begin
        if ((state==STREAM_TIME) & cpack_valid) begin
            wr_time_fifo_en = 1'b1;
        end else if ((state==PACKET_TIME) & cpack_valid) begin
            wr_time_fifo_en = 1'b1;
        end else if ((state==SYNC_TIME) & cpack_valid) begin
            wr_time_fifo_en = 1'b1;
        end else begin
            wr_time_fifo_en = 1'b0;
        end
    end

    assign wr_time_fifo_data = vita_time_cpack;
    
    // soft_rx_time_fifo u_rx_time_fifo (
    //     .clk(clk),                      // input wire clk
    //     .srst(rst),                     // input wire srst
    //     .din(wr_time_fifo_data),        // input wire [63 : 0] din
    //     .wr_en(wr_time_fifo_en),        // input wire wr_en
    //     .rd_en(rd_time_fifo_en),        // input wire rd_en
    //     .dout(rd_time_fifo_data),       // output wire [63 : 0] dout
    //     .full(time_fifo_full),          // output wire full
    //     .empty(time_fifo_empty),        // output wire empty
    //     .data_count(time_data_count)    // output wire [6 : 0] data_count
    // );

    soft_rx_time_fifo u_rx_time_fifo(
        .rst        ( rst               ),
        .clk        ( clk               ),
        .we         ( wr_time_fifo_en   ),
        .di         ( wr_time_fifo_data ),
        .re         ( rd_time_fifo_en   ),
        .dout       ( rd_time_fifo_data ),
        .valid      (                   ),
        .full_flag  ( time_fifo_full    ),
        .empty_flag ( time_fifo_empty   ),
        .afull      (                   ),
        .aempty     (                   ),
        .wrusedw    (                   ),
        .rdusedw    (                   ),
        .wr_rst_done(                   )
    );


    always @(posedge clk) begin
        if ((state==STREAM_TIME) & cpack_valid) begin
            wr_head_fifo_en <= 1'b1;
        end else if ((state==PACKET_TIME) & cpack_valid) begin
            wr_head_fifo_en <= 1'b1;
        end else if ((state==SYNC_TIME) & cpack_valid) begin
            wr_head_fifo_en <= 1'b1;
        end else begin
            wr_head_fifo_en <= 1'b0;
        end
    end

    
    // assign packet_length_in_bytes = (sample_left_in_bytes > max_sample_bytes_per_packet) ? max_sample_bytes_per_packet + 16 : sample_left_in_bytes+16;

    always @(posedge clk ) begin
        if (rst==1'b1) begin
            rx_seq <= 'd0;
        end else if (state==STREAM) begin
            if (user_buffer_done) begin
                // 连续流模式下，已经填充好完整的用户数据，准备开始填充下一个完整的用户数据
                rx_seq <= rx_seq + 1'b1;
            end else if (one_packet_done) begin
                // 连续流模式下，已经填充完一个包的数据，准备填充下一个数据包
                rx_seq <= rx_seq + 1'b1;
            end
        end else if (state == PACKET)begin
            if (user_buffer_done) begin
                // 连续流模式下，已经填充好完整的用户数据，准备开始填充下一个完整的用户数据
                rx_seq <= rx_seq + 1'b1;
            end else if (one_packet_done) begin
                // 连续流模式下，已经填充完一个包的数据，准备填充下一个数据包
                rx_seq <= rx_seq + 1'b1;
            end
        end else if (state == SYNC_PACKET) begin
            if (user_buffer_done) begin
                // 连续流模式下，已经填充好完整的用户数据，准备开始填充下一个完整的用户数据
                rx_seq <= rx_seq + 1'b1;
            end else if (one_packet_done) begin
                // 连续流模式下，已经填充完一个包的数据，准备填充下一个数据包
                rx_seq <= rx_seq + 1'b1;
            end
        end else if (state == IDLE || state == MODE_CFG) begin
            rx_seq <= 'd0;
        end
    end

    // headr of custom data, 16bit magic_type, 16bit seq, 32 bit data length in bytes
    assign wr_head_fifo_data = {MAGIC_HEAD_RX, rx_seq, 8'hA0,packet_length_in_bytes[23:0]};

    // soft_rx_time_fifo u_rx_head_fifo (
    //     .clk(clk),                      // input wire clk
    //     .srst(rst),                     // input wire srst
    //     .din(wr_head_fifo_data),        // input wire [63 : 0] din
    //     .wr_en(wr_head_fifo_en),        // input wire wr_en
    //     .rd_en(rd_head_fifo_en),        // input wire rd_en
    //     .dout(rd_head_fifo_data),       // output wire [63 : 0] dout
    //     .full(head_fifo_full),          // output wire full
    //     .empty(head_fifo_empty),        // output wire empty
    //     .data_count(head_data_count)    // output wire [6 : 0] data_count
    // );
    soft_rx_time_fifo u_rx_head_fifo(
        .rst        ( rst               ),
        .clk        ( clk               ),
        .we         ( wr_head_fifo_en   ),
        .di         ( wr_head_fifo_data ),
        .re         ( rd_head_fifo_en   ),
        .dout       ( rd_head_fifo_data ),
        .valid      (                   ),
        .full_flag  ( head_fifo_full    ),
        .empty_flag ( head_fifo_empty   ),
        .afull      (                   ),
        .aempty     (                   ),
        .wrusedw    (                   ),
        .rdusedw    (                   ),
        .wr_rst_done(                   )
    );



    // 不同模式下保存数据
    always @(*) begin
        if ((state == STREAM_TIME) || (state == STREAM)) begin
            wr_data_fifo_en = cpack_valid;
        end else if ((state == PACKET_TIME) || (state == PACKET)) begin
            wr_data_fifo_en = cpack_valid;
        end else if ((state == SYNC_TIME) || (state == SYNC_PACKET)) begin
            wr_data_fifo_en = cpack_valid;
        end else  begin
            wr_data_fifo_en = 1'b0;
        end
    end

    // 一帧数据对应的状态，包结束和包错误标志信号。与数据包组合到一起
    always @(*) begin
        if ((state==STREAM)) begin
            if (user_buffer_done) begin
                // 连续流模式下，所有包的组装
                wr_data_tlast = 1'b1;
                wr_data_terror = 1'b0;
            end else if (one_packet_done) begin
                // 连续流模式下，完成一帧包的组帧工作
                wr_data_tlast = 1'b1;
                wr_data_terror = 1'b0;
            end else if (data_fifo_almost_full & cpack_valid) begin
                // 连续流模式下，data fifo发生了溢出
                wr_data_tlast = 1'b1;
                wr_data_terror = 1'b1;
            end else if (mode_exit) begin
                // 在流模式运行的时候，退出连续流模式，需要将这个包标志位错误，并丢弃这个包
                wr_data_tlast = 1'b1;
                wr_data_terror = 1'b1;
            end else begin
                wr_data_tlast = 1'b0;
                wr_data_terror = 1'b0;
            end
        end else if ((state==PACKET)) begin
            if (user_buffer_done) begin
                // 包模式下，完成所有需要的采样点的组装
                wr_data_tlast = 1'b1;
                wr_data_terror = 1'b0;
            end else if (one_packet_done) begin
                // 包模式下，完成一帧包的组帧工作
                wr_data_tlast = 1'b1;
                wr_data_terror = 1'b0;
            end else if (data_fifo_almost_full & cpack_valid) begin
                wr_data_tlast = 1'b1;
                wr_data_terror = 1'b1;
            end else begin
                wr_data_tlast = 1'b0;
                wr_data_terror = 1'b0;
            end
        end else if ((state==SYNC_PACKET)) begin
            if (user_buffer_done) begin
                wr_data_tlast = 1'b1;
                wr_data_terror = 1'b0;
            end else if (one_packet_done) begin
                // 同步采集模式下，完成所有采样点的组装工作
                wr_data_tlast = 1'b1;
                wr_data_terror = 1'b0;
            end else if (data_fifo_almost_full & cpack_valid) begin
                wr_data_tlast = 1'b1;
                wr_data_terror = 1'b1;
            end else begin
                wr_data_tlast = 1'b0;
                wr_data_terror = 1'b0;
            end
        end else begin
            wr_data_tlast = 1'b0;
            wr_data_terror = 1'b0;
        end
    end


    assign wr_data_fifo_data = {wr_data_terror, wr_data_tlast, cpack_data };
    
    // 当fifo基本要满的时候，标志快要满的信号拉高，判定出现错误。只有在fifo还没完全满的时候，才有
    // 空间将出错的信息数据填入数据fifo当中
    assign data_fifo_almost_full = (data_fifo_count >= 1010);
    // soft_rx_data_fifo u_rx_data_fifo (
    //     .clk(clk),                  // input wire clk
    //     .srst(rst),                 // input wire srst
    //     .din(wr_data_fifo_data),    // input wire [63 : 0] din
    //     .wr_en(wr_data_fifo_en),    // input wire wr_en
    //     .rd_en(rd_data_fifo_en),    // input wire rd_en
    //     .dout(rd_data_fifo_data),   // output wire [63 : 0] dout
    //     .full(data_fifo_full),      // output wire full
    //     .empty(data_fifo_empty),     // output wire empty
    //     .data_count(data_fifo_count)    // output wire [9 : 0] data_count
    // );

    soft_rx_data_fifo u_rx_data_fifo(
        .rst        ( rst               ),
        .clk        ( clk               ),
        .we         ( wr_data_fifo_en   ),
        .di         ( wr_data_fifo_data ),
        .re         ( rd_data_fifo_en   ),
        .dout       ( rd_data_fifo_data ),
        .valid      (                   ),
        .full_flag  ( data_fifo_full    ),
        .empty_flag ( data_fifo_empty   ),
        .afull      (                   ),
        .aempty     (                   ),
        .wrusedw    ( data_fifo_count   ),
        .rdusedw    (                   ),
        .wr_rst_done(                   )
    );



    assign rd_time_fifo_en = time_fifo_tready & time_fifo_tvalid;
    assign time_fifo_tvalid = ~time_fifo_empty;
    assign time_fifo_tdata = rd_time_fifo_data;

    assign rd_head_fifo_en = time_fifo_tready & head_fifo_tvalid;
    assign head_fifo_tvalid = ~head_fifo_empty;
    assign head_fifo_tdata = rd_head_fifo_data;

    assign data_fifo_tdata = rd_data_fifo_data;
    always @(posedge clk ) begin
        if (rst==1'b1) begin
            out_state <= OUT_IDLE;
        end else begin
            case (out_state)
                OUT_IDLE : begin
                    if (time_fifo_tvalid) begin
                        //时间fifo当中有数据，开始组一帧数据
                        out_state <= OUT_HEAD;
                    end
                end

                OUT_HEAD : begin
                    if (out_tvalid & out_tready) begin
                        out_state  <= OUT_TIME;
                    end
                end



                OUT_TIME : begin
                    if (out_tvalid & out_tready) begin
                        out_state  <= OUT_BODY;
                    end
                end

                OUT_BODY : begin
                    if (out_tvalid & out_tready & (out_tlast | out_tlast_int)) begin
                        out_state <= OUT_IDLE;
                    end
                end

                default : out_state <= OUT_IDLE;
            endcase
        end
    end

    // 当一帧数据处理完毕之后，从time_fifo pop一个时间戳
    assign time_fifo_tready = out_tvalid & out_tready & (out_tlast | out_tlast_int);
    assign head_fifo_tready = out_tvalid & out_tready & (out_tlast | out_tlast_int);
    assign rd_data_fifo_en = (out_state == OUT_BODY) ? out_tvalid & out_tready : 1'b0;
    assign data_fifo_tvalid = ~data_fifo_empty;
    assign data_fifo_tready = (out_state == OUT_BODY) ? out_tready : 1'b0;

    assign out_tvalid = (out_state == OUT_HEAD) ? head_fifo_tvalid :
                        (out_state == OUT_TIME) ? time_fifo_tvalid :
                        (out_state == OUT_BODY) ? data_fifo_tvalid : 1'b0;
    
    assign out_tdata = (out_state == OUT_HEAD) ? head_fifo_tdata : 
                       (out_state == OUT_TIME) ? time_fifo_tdata : 
                       (out_state == OUT_BODY) ? data_fifo_tdata[63:0] : 'd0;

    assign {out_terror, out_tlast} = (out_state == OUT_BODY) ? data_fifo_tdata[65:64] : 'd0;


    always @(posedge clk ) begin
        if (rst==1'b1) begin
            cnt_frame_bytes <= 'd0;
        end else if (out_tvalid & out_tready & out_tlast) begin
            cnt_frame_bytes <= 'd0;
        end else if (out_tvalid & out_tready & (cnt_frame_bytes == max_sample_bytes_per_packet + 'd8)) begin
            cnt_frame_bytes <= 'd0;
        end else if (out_tvalid & out_tready)begin
            cnt_frame_bytes <=  cnt_frame_bytes + 8;
        end
    end

    assign out_tlast_int = out_tvalid & out_tready & (cnt_frame_bytes == max_sample_bytes_per_packet + 'd8);


    //如果一个packet检测到错误，那么丢弃这个包
    wire rx_tlast_int; /*synthesis keep*/  
    axi_packet_gate #(
        .WIDTH(64), .SIZE(14), .USE_AS_BUFF(1), .MIN_PKT_SIZE(1)
    ) rx_packet_gate (
        .clk(clk), .reset(rst), .clear(1'b0),
        .i_tdata(out_tdata), .i_tlast(out_tlast), .i_terror(out_terror),
        .i_tvalid(out_tvalid), .i_tready(out_tready),
        .o_tdata(rx_tdata), .o_tlast(rx_tlast_int),
        .o_tvalid(rx_tvalid), .o_tready(rx_tready)
    );

    reg [15:0]  cnt_dma_s2mm_packet;
    reg [31:0]  cnt_out_bytes   ;

    always @(posedge clk ) begin
        if (rst==1'b1) begin
            cnt_dma_s2mm_packet <= 'd0;
        end else if (rx_mode==STREAM_MODE) begin
            if (rx_tvalid & rx_tready & rx_tlast_int & (cnt_dma_s2mm_packet==dma_s2mm_pkt_per_burst-1'b1)) begin
                cnt_dma_s2mm_packet <= 'd0;
            end else if (rx_tvalid & rx_tready & rx_tlast_int) begin
                cnt_dma_s2mm_packet <= cnt_dma_s2mm_packet + 1'b1;
            end
        end else begin
            cnt_dma_s2mm_packet <=  'd0;
        end
    end
    // assign rx_tlast = (rx_mode==STREAM_MODE) ? (rx_tvalid & rx_tready & rx_tlast_int & (cnt_dma_s2mm_packet==dma_s2mm_pkt_per_burst-1'b1)) : rx_tlast_int;
    assign rx_tlast = (rx_tready & rx_tvalid & (cnt_out_bytes == max_sample_bytes_per_packet + 'd8)) | rx_tlast_int;

    always @(posedge clk ) begin
        if (rst==1'b1) begin
            cnt_out_bytes <= 'd0;
        end else if (rx_tready & rx_tvalid & rx_tlast_int) begin
            cnt_out_bytes <= 'd0;
        end else if (rx_tready & rx_tvalid & (cnt_out_bytes == max_sample_bytes_per_packet + 'd8)) begin
            cnt_out_bytes <= 'd0;
        end else if (rx_tready & rx_tvalid )begin
            cnt_out_bytes <=  cnt_out_bytes + 8;
        end
    end

    always @(posedge clk ) begin
        state_dly <= state;
    end
    // wire [255:0] probe0;
    // assign probe0 = {
    //     state,
    //     cpack_valid,
    //     mode_exit,
    //     stream_start,
    //     rx_sync_timestamp_strobe,
    //     capture_one_block,
    //     rx_sample_bytes,
    //     max_sample_bytes_per_packet,
    //     rx_mode,
    //     rx_mode_strobe,
    //     state_dly,
    //     out_state,
    //     rx_tdata,
    //     rx_tlast,
    //     rx_tvalid,
    //     rx_tready
    // };
    // ila_0 u_ila_tx (
    //     .clk(clk), // input wire clk


    //     .probe0(probe0) // input wire [255:0] probe0
    // );


endmodule

`default_nettype wire