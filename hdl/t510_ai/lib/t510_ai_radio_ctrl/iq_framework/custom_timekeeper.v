`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/08/2025 01:44:54 PM
// Design Name: 
// Module Name: custom_timekeeper
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module custom_timekeeper#(
    parameter INCREMENT = 64'h1)
   (
    input wire clk, 
    input wire reset, 
    input wire pps, 
    input wire sync_in, 
    input wire strobe,/*synthesis keep*/
    input wire  [2:0]   time_mode,/*synthesis keep*/   
    input wire          time_mode_strobe,/*synthesis keep*/
    input wire  [63:0]  set_vita_timestamp,/*synthesis keep*/
    output reg  [63:0]  vita_time, 
    output reg  [63:0]  vita_time_lastpps,
    output reg sync_out);

   //////////////////////////////////////////////////////////////////////////
   // timer settings for this module
   //////////////////////////////////////////////////////////////////////////
   wire [63:0] time_at_next_event;
   reg  set_time_pps;
   reg  set_time_now;
   reg  set_time_sync;
   wire cmd_trigger;
   reg  [2:0]    time_mode_strobe_del;
   reg  [5:0]    time_mode_del;
   always @(posedge clk ) begin
    if (reset==1'b1) begin
        time_mode_strobe_del <= 3'd0;
    end else begin
        time_mode_strobe_del <=  {time_mode_strobe_del[1:0], time_mode_strobe};
    end
   end

   
   assign time_at_next_event = set_vita_timestamp;
  //  assign {set_time_sync, set_time_pps, set_time_now} = time_mode;
   assign cmd_trigger = time_mode_strobe_del[2:1]==2'b01;
   always @(posedge clk ) begin
    if (reset==1'b1) begin
      {set_time_sync, set_time_pps, set_time_now} <= 'd0;
    end else if (time_mode_strobe) begin
      {set_time_sync, set_time_pps, set_time_now} <= time_mode;
    end
   end



   //////////////////////////////////////////////////////////////////////////
   // PPS edge detection logic
   //////////////////////////////////////////////////////////////////////////
   reg pps_del, pps_del2;
   always @(posedge clk)
     {pps_del2,pps_del} <= {pps_del, pps};

   wire pps_edge = !pps_del2 & pps_del;

   //////////////////////////////////////////////////////////////////////////
   // arm the trigger to latch a new time when the ctrl register is written
   //////////////////////////////////////////////////////////////////////////
   reg armed;
   wire time_event;
   assign time_event = armed && ((set_time_now) || (set_time_pps && pps_edge) || (set_time_sync && sync_in));
   always @(posedge clk) begin
     if (reset) armed <= 1'b0;
     else if (cmd_trigger) armed <= 1'b1;
     else if (time_event) armed <= 1'b0;
   end

   //////////////////////////////////////////////////////////////////////////
   // vita time tracker - update every tick or when we get an "event"
   //////////////////////////////////////////////////////////////////////////
   always @(posedge clk) begin
     sync_out <= 1'b0;
     if(reset) begin
       vita_time <= 64'h0;
     end else begin
         if (time_event) begin
           sync_out <= 1'b1;
           vita_time <= time_at_next_event;
         end else if (strobe) begin
	            vita_time <= vita_time + INCREMENT;
         end
     end
   end

   //////////////////////////////////////////////////////////////////////////
   // track the time at last pps so host can detect the pps
   //////////////////////////////////////////////////////////////////////////
   always @(posedge clk)
     if(reset)
       vita_time_lastpps <= 64'h0;
     else if(pps_edge)
       if(time_event)
         vita_time_lastpps <= time_at_next_event;
       else
         vita_time_lastpps <= vita_time + INCREMENT;


    // wire [255:0] probe0;
    // assign probe0 = {
    //   time_event,
    //   time_mode_del,
    //     set_vita_timestamp,
    //     vita_time,
    //     time_mode,
    //     time_mode_strobe,
    //     armed,
    //     set_time_pps,
    //     set_time_now,
    //     set_time_sync,
    //     time_mode_strobe_del,
    //     cmd_trigger
    // };
    // ila_timekeeper u_ila_timekeeper (
    //     .clk(clk), // input wire clk


    //     .probe0(probe0) // input wire [255:0] probe0
    // );

endmodule
