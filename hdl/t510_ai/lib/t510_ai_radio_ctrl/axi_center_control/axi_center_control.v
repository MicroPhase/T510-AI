
`timescale 1 ns / 1 ps

	module axi_center_control #
	(
		// Users to add parameters here

		// User parameters ends
		// Do not modify the parameters beyond this line


		// Parameters of Axi Slave Bus Interface S00_AXI
		parameter integer C_S00_AXI_DATA_WIDTH	= 32,
		parameter integer C_S00_AXI_ADDR_WIDTH	= 8
	)
	(
		// Users to add ports here
		output   wire            get_current_vita_time     	,
		output   wire            get_lastpps_vita_time     	,
		input  	 wire  	[63:0]	 vita_time			       	,
		input  	 wire 	[63:0]	 vita_time_last_pps        	,
		output   wire 	[63:0]	 set_vita_timestamp 	   	,
		output   wire    [2:0]   set_time_mode             	,
		output   wire            time_mode_strobe          	,
		output   wire	[63:0]	 tx_timestamp			   	,
		output   wire 	[31:0]	 rx_sample_bytes 		   	,
		output 	 wire 	[31:0] 	 max_sample_bytes_per_packet,
		output   wire 			 capture_one_block		   	,
		output   wire    [63:0]  rx_sync_timestamp         	,
		output   wire            rx_sync_timestamp_strobe  	,
		output   wire    [1:0]   rx_mode                   	,
		output   wire            rx_mode_strobe            	,
		output   wire            mode_exit                 	,
		output   wire            stream_start              	,
		output   wire    [7:0]   channel_enable            	,
		output 	 wire 	[15:0]	 dma_s2mm_pkt_per_burst    	,
		output 	 wire 			 axi_dma_rst_n 				,
		output 	 wire    [31:0]  tx_samples_per_packet      ,
		output 	 wire    [2:0]   tx_source_sel              ,
		output 	 wire            ignore_tx_timestamps       ,
		output 	 wire    [15:0]  noise_idx_start            ,
		output 	 wire    [15:0]  noise_idx_end              ,
		output 	 wire            noise_cfg_update           ,
		output 	 wire    [31:0]  tx_dds_freq_ctrl_word      ,
		output 	 wire 	 [31:0]	 fc_window 					,
		output	 wire 			 sync_in 					,
		output 	 wire	 [1:0]	 pps_select 				,

		output 	wire 	[31:0]	test_bytes_len 			,
		output 	wire 			test_rx_start 			,
		output 	wire 			dma1_test_rx_start 		,

		output 	wire 		    enable_xfft             , 
		output 	wire            enable_overlap          , 
		output 	wire    [31:0]  fft_len                 ,
		output 	wire            fft_len_update          , 
		input 	wire 			xfft_ready 				,


		// User ports ends
		// Do not modify the ports beyond this line


		// Ports of Axi Slave Bus Interface S00_AXI
		input wire  s00_axi_aclk,
		input wire  s00_axi_aresetn,
		input wire [C_S00_AXI_ADDR_WIDTH-1 : 0] s00_axi_awaddr,
		input wire [2 : 0] s00_axi_awprot,
		input wire  s00_axi_awvalid,
		output wire  s00_axi_awready,
		input wire [C_S00_AXI_DATA_WIDTH-1 : 0] s00_axi_wdata,
		input wire [(C_S00_AXI_DATA_WIDTH/8)-1 : 0] s00_axi_wstrb,
		input wire  s00_axi_wvalid,
		output wire  s00_axi_wready,
		output wire [1 : 0] s00_axi_bresp,
		output wire  s00_axi_bvalid,
		input wire  s00_axi_bready,
		input wire [C_S00_AXI_ADDR_WIDTH-1 : 0] s00_axi_araddr,
		input wire [2 : 0] s00_axi_arprot,
		input wire  s00_axi_arvalid,
		output wire  s00_axi_arready,
		output wire [C_S00_AXI_DATA_WIDTH-1 : 0] s00_axi_rdata,
		output wire [1 : 0] s00_axi_rresp,
		output wire  s00_axi_rvalid,
		input wire  s00_axi_rready
	);
// Instantiation of Axi Bus Interface S00_AXI
	axi_center_control_v1_0_S00_AXI # ( 
		.C_S_AXI_DATA_WIDTH(C_S00_AXI_DATA_WIDTH),
		.C_S_AXI_ADDR_WIDTH(C_S00_AXI_ADDR_WIDTH)
	) axi_center_control_v1_0_S00_AXI_inst (
		.get_current_vita_time(get_current_vita_time),
		.get_lastpps_vita_time(get_lastpps_vita_time),
		.vita_time(vita_time),
		.vita_time_last_pps(vita_time_last_pps),
		.set_vita_timestamp(set_vita_timestamp),
		.set_time_mode(set_time_mode),
		.time_mode_strobe(time_mode_strobe),
		.tx_timestamp(tx_timestamp),
		.rx_sample_bytes(rx_sample_bytes),
		.max_sample_bytes_per_packet(max_sample_bytes_per_packet),
		.capture_one_block(capture_one_block),
		.rx_sync_timestamp(rx_sync_timestamp),
		.rx_sync_timestamp_strobe(rx_sync_timestamp_strobe),
		.rx_mode(rx_mode),
		.rx_mode_strobe(rx_mode_strobe),
		.mode_exit(mode_exit),
		.stream_start(stream_start),
		.channel_enable(channel_enable),
		.dma_s2mm_pkt_per_burst(dma_s2mm_pkt_per_burst),
		.axi_dma_rst_n (axi_dma_rst_n),
		.tx_samples_per_packet(tx_samples_per_packet),
		.tx_source_sel(tx_source_sel),
		.ignore_tx_timestamps(ignore_tx_timestamps),
		.noise_idx_start(noise_idx_start),
		.noise_idx_end(noise_idx_end),
		.noise_cfg_update(noise_cfg_update),
		.tx_dds_freq_ctrl_word(tx_dds_freq_ctrl_word),
		.fc_window(fc_window),
		.sync_in(sync_in),
		.pps_select(pps_select),
		
		.test_bytes_len(test_bytes_len),
		.test_rx_start(test_rx_start),
		.dma1_test_rx_start(dma1_test_rx_start),

		.enable_xfft(enable_xfft),
		.enable_overlap(enable_overlap),
		.fft_len(fft_len),
		.fft_len_update(fft_len_update),
		
		.xfft_ready(xfft_ready),
		.S_AXI_ACLK(s00_axi_aclk),
		.S_AXI_ARESETN(s00_axi_aresetn),
		.S_AXI_AWADDR(s00_axi_awaddr),
		.S_AXI_AWPROT(s00_axi_awprot),
		.S_AXI_AWVALID(s00_axi_awvalid),
		.S_AXI_AWREADY(s00_axi_awready),
		.S_AXI_WDATA(s00_axi_wdata),
		.S_AXI_WSTRB(s00_axi_wstrb),
		.S_AXI_WVALID(s00_axi_wvalid),
		.S_AXI_WREADY(s00_axi_wready),
		.S_AXI_BRESP(s00_axi_bresp),
		.S_AXI_BVALID(s00_axi_bvalid),
		.S_AXI_BREADY(s00_axi_bready),
		.S_AXI_ARADDR(s00_axi_araddr),
		.S_AXI_ARPROT(s00_axi_arprot),
		.S_AXI_ARVALID(s00_axi_arvalid),
		.S_AXI_ARREADY(s00_axi_arready),
		.S_AXI_RDATA(s00_axi_rdata),
		.S_AXI_RRESP(s00_axi_rresp),
		.S_AXI_RVALID(s00_axi_rvalid),
		.S_AXI_RREADY(s00_axi_rready)
	);

	// Add user logic here

	// User logic ends

	endmodule
