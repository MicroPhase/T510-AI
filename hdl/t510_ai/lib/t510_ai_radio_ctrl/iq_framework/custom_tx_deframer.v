`default_nettype none
`timescale 1ns / 1ps

module custom_tx_deframer(
    input   wire            clk                         ,
    input   wire            rst                         ,
    input   wire    [63:0]  vita_time                   ,/*synthesis keep*/
    output  wire    [63:0]  upack_tdata                 ,/*synthesis keep*/
    output  wire            upack_tvalid                ,/*synthesis keep*/
    input   wire            upack_tready                ,/*synthesis keep*/

    input   wire    [7:0]   channel_enable              , // how many channels were enabled
    input   wire    [31:0]  tx_samples_per_packet       , // how many samples one packet have, for all the modes
    input   wire            ignore_tx_timestamps        , // don't care tx timestamps, send all the data from upper stream
                                                          // tx do not have timestamps, only iq needs to be sent
    input   wire    [31:0]  fc_window                   , // flow control window        

    output  wire    [63:0]  fc_tdata                    ,
    output  wire            fc_tvalid                   ,
    output  wire            fc_tlast                    ,
    input   wire            fc_tready                   ,

    /*synthesis keep*/ input   wire            tx_tvalid                   ,
    /*synthesis keep*/ input   wire    [63:0]  tx_tdata                    ,
    /*synthesis keep*/ input   wire    [63:0]  tx_tuser                    ,
    /*synthesis keep*/ input   wire            tx_tlast                    ,
    /*synthesis keep*/ output  reg             tx_tready                    
    );

    //====================================================
    //parameter define
    //====================================================
    localparam  IDLE        = 5'b00001;
    localparam  TX_TD_HEAD     = 5'b00010;
    localparam  TX_TD_TIME     = 5'b00100;
    localparam  TX_TD_BODY     = 5'b01000;
    localparam  TX_TD_DUMP     = 5'b10000;
   
    
    //====================================================
    //internal signal and register
    //====================================================
    reg     [4:0]   state;/*synthesis keep*/
    wire    [7:0]   samples_per_packed_data;
    wire now;   /*synthesis keep*/
    wire early; /*synthesis keep*/
    wire late;  /*synthesis keep*/
    wire too_early; /*synthesis keep*/
    wire            time_compare_enable;/*synthesis keep*/
    wire            triger_fc       ;
    reg     [15:0]  current_tx_seq  ;
    reg     [31:0]  cnt_tx_pkt      ;
    wire    [31:0]  fc_window_now   ;
    // every 64bit have how many samples? for example, 1r1t, 64bit have 2samples, 2r2t 64bit have 1 sample
    assign samples_per_packed_data = (channel_enable=='d1) ? 2 : ((channel_enable=='d3) ? 'd1 : 0);
    

    tx_fc_monitor u_tx_fc_monitor(
        .clk             ( clk             ),
        .rst             ( rst             ),
        .triger_fc       ( triger_fc       ),
        .current_tx_seq  ( current_tx_seq  ),
        .vita_time       ( vita_time       ),
        .fc_tvalid       ( fc_tvalid       ),
        .fc_tdata        ( fc_tdata        ),
        .fc_tlast        ( fc_tlast        ),
        .fc_tready       ( fc_tready       )
    );



    // 时间比较，比较当前的本地时间戳和
    time_compare u_time_compare(
        .clk          ( clk          ),
        .reset        ( rst          ),
        .time_now     ( vita_time    ),
        .enable       ( time_compare_enable ),
        .trigger_time ( tx_tuser     ),
        .now          ( now          ),
        .early        ( early        ),
        .late         ( late         ),
        .too_early    ( too_early    )
    );
    assign time_compare_enable = (state == TX_TD_TIME & tx_tvalid) & (~ignore_tx_timestamps);


    always @(posedge clk ) begin
        if (rst==1'b1) begin
            state <= TX_TD_TIME;
        end else begin
            case (state)
                // IDLE : begin
                //     if(tx_tvalid) begin
                //         state <= TX_TD_HEAD;
                //     end                    
                // end

                // TX_TD_HEAD : begin
                //     if (tx_tvalid & tx_tready) begin
                //         state <= TX_TD_TIME;
                //     end
                // end

                TX_TD_TIME : begin
                    if (tx_tvalid & tx_tready) begin
                         if (ignore_tx_timestamps) begin
                            // TX的时间戳全为0，也就是说当前数据不包含时间戳
                            state <= TX_TD_BODY;
                        end else if(now) begin
                            // 本地时间戳==这一帧需要发送的数据的时间戳
                            state <= TX_TD_BODY;
                        end else if (late) begin
                            // 本地时间戳已经超时，丢弃这一帧数据
                            state <= TX_TD_DUMP;
                        end
                    end
                   
                end

                TX_TD_BODY : begin
                    if(tx_tvalid & tx_tready & tx_tlast) begin
                        // 直到本帧数据结束
                        state <= TX_TD_TIME;
                    end
                end

                TX_TD_DUMP : begin
                    if(tx_tvalid & tx_tready & tx_tlast) begin
                        // 直到本帧数据结束
                        state <= TX_TD_TIME;
                    end
                end

                default: state <= TX_TD_TIME;
            endcase
        end
    end

    wire    tx_buf_tvalid;
    wire    tx_buf_tready;

    always @(*) begin
        if((state == TX_TD_HEAD)) begin
            tx_tready = 1'b1;
        end else if((state == TX_TD_TIME) & (now | late)) begin
            tx_tready = 1'b1;
        end else if((state == TX_TD_TIME) & ignore_tx_timestamps) begin
            tx_tready = 1'b1;
        end else if (state == TX_TD_BODY) begin
            tx_tready = tx_buf_tready;
        end else if (state == TX_TD_DUMP) begin
            tx_tready = 1'b1;
        end else begin
            tx_tready = 1'b0;
        end
    end

    assign tx_buf_tvalid = (state == TX_TD_BODY) & tx_tvalid;
    // assign upack_tdata = tx_tdata;


    assign fc_window_now = (fc_window ==32'd0) ? 'd32 : fc_window;
    always @(posedge clk ) begin
        if (rst==1'b1) begin
            cnt_tx_pkt <= 'd0;
        end else if ((tx_tvalid & tx_tready & tx_tlast) & (cnt_tx_pkt == fc_window_now -1'b1)) begin
            cnt_tx_pkt <= 'd0;
        end else if (tx_tvalid & tx_tready & tx_tlast) begin
            cnt_tx_pkt <= cnt_tx_pkt + 1'b1;
        end
    end

    assign triger_fc = (tx_tvalid & tx_tready & tx_tlast) & (cnt_tx_pkt == fc_window_now -1'b1);

    always @(posedge clk ) begin
        if (rst==1'b1) begin
            current_tx_seq <= 'd0;
        end else if (state == TX_TD_HEAD) begin
            current_tx_seq <= tx_tdata[47:32];
        end
    end



    axi_fifo #(
        .WIDTH(64),.SIZE(4)
    )tx_iq_deframer (
        .clk(clk), .reset(rst), .clear(1'b0),
        .i_tdata(tx_tdata),
        .i_tvalid(tx_buf_tvalid ), .i_tready(tx_buf_tready),
        .o_tdata(upack_tdata),
        .o_tvalid(upack_tvalid), .o_tready(upack_tready),
        .space(), .occupied()
    );


    // wire [255:0] probe0;
    // assign probe0 = {
    //     state,
    //     tx_tvalid,
    //     tx_tdata,
    //     tx_tlast,
    //     tx_tready,
    //     now,
    //     early,
    //     late,
    //     ignore_tx_timestamps,
    //     time_compare_enable,
    //     triger_fc,
    //     current_tx_seq,
    //     cnt_tx_pkt,
    //     fc_window_now,
    //     fc_tdata[15:0],
    //     fc_tvalid,
    //     fc_tlast,
    //     fc_tready,
    //     upack_tdata,
    //     upack_tvalid,
    //     upack_tready

    // };
    // ila_0 u_ila_tx (
    //     .clk(clk), // input wire clk


    //     .probe0(probe0) // input wire [255:0] probe0
    // );


endmodule

`default_nettype wire