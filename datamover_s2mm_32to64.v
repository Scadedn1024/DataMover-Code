`timescale 1ns / 1ps
//****************************************VSCODE PLUG-IN**********************************//
//----------------------------------------------------------------------------------------
// IDE :                   VSCODE     
// VSCODE plug-in version: Verilog-Hdl-Format-3.8.20250805
// VSCODE plug-in author : Jiang Percy
//----------------------------------------------------------------------------------------
//****************************************Copyright (c)***********************************//
// Copyright(C)            Please Write Company name
// All rights reserved     
// File name:              
// Last modified Date:     
// Last Version:           V1.0
// Descriptions:           
//----------------------------------------------------------------------------------------
// Created by:             Please Write You Name 
// Created date:           
// mail      :             Please Write mail 
// Version:                V1.0
// TEXT NAME:              datamover_s2mm.v
// PATH:                   
// Descriptions:           
//                
// 关于数据和指令，遵循一个指令一组数据，只有当前数据输入完成后，才可以接收下一条指令。  
// 目前设置的I_s_axis_s2mm_cmd_len必须是偶数，且不为0。       
//----------------------------------------------------------------------------------------
//****************************************************************************************//

module datamover_s2mm(
    input             I_sys_clk                , 
	input             I_sys_rst                , 
	input             I_ps_clk                 , 
	input             I_ps_rst                 , 
    	           	       
	// 写通道 													   
    output reg        O_s2mm_err               ,    
	
    input             I_m_axis_s2mm_sts_tready , // status interface      	
    output reg        O_m_axis_s2mm_sts_tvalid ,   
    output reg  [7:0] O_m_axis_s2mm_sts_tdata  , // 8'h80: 指令与数据长度匹配； 8'h10: 指令与数据长度不匹配； 
    output reg        O_m_axis_s2mm_sts_tkeep  ,
    output reg        O_m_axis_s2mm_sts_tlast  ,     
	  		    							     
    output reg        O_s_axis_s2mm_cmd_tready , // I_sys_clk Clock Domain
    input             I_s_axis_s2mm_cmd_tvalid ,     
    input      [31:0] I_s_axis_s2mm_cmd_addr   ,
    input      [22:0] I_s_axis_s2mm_cmd_len    ,
											   
	output reg        O_s_axis_s2mm_tready     , // I_sys_clk Clock Domain     
    input      [15:0] I_s_axis_s2mm_tdata_I    , 
    input      [15:0] I_s_axis_s2mm_tdata_Q    , 
    input             I_s_axis_s2mm_tkeep      , 
    input             I_s_axis_s2mm_tlast      ,
    input             I_s_axis_s2mm_tvalid     ,
        
    input             I_m_axi_s2mm_awready     , // I_ps_clk Clock Domain
    output            O_m_axi_s2mm_awvalid     ,
    output     [31:0] O_m_axi_s2mm_awaddr      , 
    output      [7:0] O_m_axi_s2mm_awlen       , 
    output      [2:0] O_m_axi_s2mm_awsize      , 
    output      [1:0] O_m_axi_s2mm_awburst     ,
    output      [2:0] O_m_axi_s2mm_awprot      ,
    output      [3:0] O_m_axi_s2mm_awcache     ,
    output            O_m_axi_s2mm_awlock      ,  
    output      [3:0] O_m_axi_s2mm_awqos       ,      
    output      [3:0] O_m_axi_s2mm_awuser      ,    
    
    input             I_m_axi_s2mm_wready      , // I_ps_clk Clock Domain
    output            O_m_axi_s2mm_wvalid      , 
    output reg [63:0] O_m_axi_s2mm_wdata       ,
    output reg  [7:0] O_m_axi_s2mm_wstrb       ,
    output            O_m_axi_s2mm_wlast       ,
    
    output            O_m_axi_s2mm_bready      ,
    input             I_m_axi_s2mm_bvalid      ,        
    input       [1:0] I_m_axi_s2mm_bresp             
);

reg           R_write_err              ;
reg    [22:0] R_rxd_byte           = 0 ;
reg    [22:0] R_iq_pairs_num       = 0 ;

reg           R_m_axi_s2mm_awvalid = 0 ; 
reg    [31:0] R_m_axi_s2mm_awaddr  = 0 ; 
reg     [7:0] R_m_axi_s2mm_awlen   = 0 ;
reg           R_m_axi_s2mm_wvalid  = 0 ;   
reg           R_m_axi_s2mm_wlast   = 0 ;  

// CMD Input Signals
reg             R_wr_en_cmd              ;
reg      [54:0] R_din___cmd              ; // [54:23]:SADDR; [22:0]:BTT;
wire            W_rd_en_cmd              ;
wire     [54:0] W_dout__cmd              ; // [54:23]:SADDR; [22:0]:BTT;
wire            W_data_valid_cmd         ;
wire            W_prog_full_cmd          ;
wire      [4:0] W_rd_data_count_cmd      ;

reg      [31:0] R_src_addr               ;
reg      [22:0] R_iq_btt                 ; // 
reg      [22:0] R_axi_beat_num           ; // AXI Beat Number
reg      [22:0] R_axi_beat_cnt           ; // AXI Beat Count
reg      [22:0] R_axi_beat_cnt_d         ;
reg      [22:0] R_pkt_beat_len           ;

reg             R_cmd_receive_done       ;
reg             R_data_trans_done        ;
reg             R_data_trans_done_d      ;
wire            W_data_trans_done_rise   ;

// Data FIFO Signals
reg      [72:0] R_din__data              ;
reg             R_iq_data_vld            ;
reg             R_wr_en_data             ;
reg             R_rd_en_data             ;
wire     [72:0] W_dout__data             ;
wire            W_data_valid_0           ;
wire            W_prog_full_0            ;
wire      [9:0] W_wr_data_count0         ;
wire      [9:0] W_rd_data_count0         ;

assign O_m_axi_s2mm_awvalid = R_m_axi_s2mm_awvalid; 
assign O_m_axi_s2mm_awaddr  = R_m_axi_s2mm_awaddr ;  
assign O_m_axi_s2mm_awlen   = R_m_axi_s2mm_awlen  ;   
assign O_m_axi_s2mm_awsize  = 3'h3; 
assign O_m_axi_s2mm_awburst = 2'h1; 
assign O_m_axi_s2mm_awprot  = 3'h0;   
assign O_m_axi_s2mm_awcache = 4'h0; 
assign O_m_axi_s2mm_awlock  = 1'b0; 
assign O_m_axi_s2mm_awqos   = 4'h0; 

assign O_m_axi_s2mm_awuser  = 4'h0; 

assign O_m_axi_s2mm_wvalid = R_m_axi_s2mm_wvalid; 
assign O_m_axi_s2mm_wlast  = R_m_axi_s2mm_wlast; 
assign O_m_axi_s2mm_bready = 1'b1;

// =======================================================================================
// State
always @(posedge I_sys_clk) begin
    if(I_sys_rst)
        R_iq_pairs_num <= 23'h0;
    else if(I_s_axis_s2mm_cmd_tvalid && O_s_axis_s2mm_cmd_tready) 
        R_iq_pairs_num <= I_s_axis_s2mm_cmd_len;
end

always @(posedge I_sys_clk)begin // 数据包长度检测  
    if (I_sys_rst)begin 
	    R_rxd_byte <= 23'h0; 
	    end 
    else if (O_s_axis_s2mm_tready && I_s_axis_s2mm_tvalid)begin 
	    R_rxd_byte <= R_rxd_byte + 1'b1; 
        if (I_s_axis_s2mm_tlast)begin 
		    R_rxd_byte <= 23'h0; 			
            end 		
        end 	
    end 

always @(posedge I_sys_clk)begin     
    if (O_m_axis_s2mm_sts_tvalid)begin 
	    O_m_axis_s2mm_sts_tvalid <= ~I_m_axis_s2mm_sts_tready;  
	    end 
    else if(O_s_axis_s2mm_tready && I_s_axis_s2mm_tvalid && I_s_axis_s2mm_tlast)begin 
	    O_m_axis_s2mm_sts_tvalid <= 1'b1; 
		O_m_axis_s2mm_sts_tdata  <= (R_rxd_byte == R_iq_pairs_num - 1'b1)? 8'h80:8'h10;  
		O_m_axis_s2mm_sts_tkeep  <= 1'b1; 
		O_m_axis_s2mm_sts_tlast  <= 1'b1; 
        end 	
    else begin 
	    O_m_axis_s2mm_sts_tdata  <= 8'h0; 
		O_m_axis_s2mm_sts_tvalid <= 1'b0;
        O_m_axis_s2mm_sts_tkeep  <= 1'b0; 	
        O_m_axis_s2mm_sts_tlast  <= 1'b0; 		 
        end 	
    end 

// ========================================================================================
// Command module
// Cross-clock domain conversion to ps_clk for processing
// Considering large data volumes, data fragmentation processing is required
always @(posedge I_sys_clk) begin
    if(I_sys_rst)
        O_s_axis_s2mm_cmd_tready <= 1'b1;
    else if(I_s_axis_s2mm_cmd_tvalid)
        O_s_axis_s2mm_cmd_tready <= 1'b0;
    else if(I_s_axis_s2mm_tvalid && I_s_axis_s2mm_tlast)
        O_s_axis_s2mm_cmd_tready <= 1'b1;
end

always @(posedge I_sys_clk)begin 
    R_wr_en_cmd <= I_s_axis_s2mm_cmd_tvalid && O_s_axis_s2mm_cmd_tready && (|I_s_axis_s2mm_cmd_len[22:0]) && (~W_prog_full_cmd);
	R_din___cmd <= {I_s_axis_s2mm_cmd_addr,I_s_axis_s2mm_cmd_len}; 		
    end 

// CMD ASYNC FIFO
// 55bit: [54:23]:SADDR; [22:0]:BTT;
xpm_fifo_async #( 
   .DOUT_RESET_VALUE    ("0"       ), // String 
   .ECC_MODE            ("no_ecc"  ), // String 
   .FIFO_MEMORY_TYPE    ("block"   ), // String
   .READ_MODE           ("fwft"    ), // String 
   .USE_ADV_FEATURES    ("1707"    ), // String 
   .FIFO_WRITE_DEPTH    (16        ), // DECIMAL   
   .PROG_FULL_THRESH    (10        ), // DECIMAL 
   .PROG_EMPTY_THRESH   (5         ), // DECIMAL 
   .WRITE_DATA_WIDTH    (55        ), // DECIMAL  
   .READ_DATA_WIDTH     (55        ), // DECIMAL 
   .FIFO_READ_LATENCY   (0         ), // DECIMAL 
   .FULL_RESET_VALUE    (0         ), // DECIMAL 
   .SIM_ASSERT_CHK      (0         ), // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
   .WAKEUP_TIME         (0         ), // DECIMAL
   .RELATED_CLOCKS      (0         ), // DECIMAL 
   .WR_DATA_COUNT_WIDTH (5         ), // DECIMAL
   .RD_DATA_COUNT_WIDTH (5         ), // DECIMAL
   .CDC_SYNC_STAGES     (2         )  // DECIMAL     
) xpm_fifo_async_cmd (     
    .wr_clk        (I_sys_clk          ),    
    .rst           (I_sys_rst          ), 
    .rd_clk        (I_ps_clk           ),  
    .wr_en         (R_wr_en_cmd        ),  
    .din           (R_din___cmd        ), // [54:23]:SADDR; [22:0]:BTT; 
    .rd_en         (W_rd_en_cmd        ),  
    .data_valid    (W_data_valid_cmd   ),  
    .dout          (W_dout__cmd        ), // [54:23]:SADDR; [22:0]:BTT;              
    .prog_full     (W_prog_full_cmd    ), 
    .prog_empty    (),    
    .almost_full   (),            
    .almost_empty  (),
    .full          (),
    .empty         (),   
    .overflow      (),  
    .underflow     (),
    .wr_data_count (),
    .rd_data_count (W_rd_data_count_cmd ),                                          
    .wr_rst_busy   (), 
    .rd_rst_busy   (),                           
    .dbiterr       (),             
    .sbiterr       (),  
    .wr_ack        (),           
    .injectdbiterr (1'b0  ),                                   
    .injectsbiterr (1'b0  ),                                
    .sleep         (1'b0  )                                     
); 

assign W_rd_en_cmd = W_data_valid_cmd && (R_axi_beat_cnt == 23'h0);
always @(posedge I_ps_clk) begin
    if(I_ps_rst) begin 
        R_src_addr     <= 32'h0;
        R_iq_btt       <= 23'h0;
        R_axi_beat_num <= 23'h0;
        R_axi_beat_cnt <= 23'h0;

        R_cmd_receive_done <= 1'b0;
    end
    else if(W_data_valid_cmd) begin 
        R_src_addr     <= W_dout__cmd[54:23]; 
        R_iq_btt       <= W_dout__cmd[22:0]; 
        R_axi_beat_num <= W_dout__cmd[22:1] + |W_dout__cmd[0:0]; // AXI Beat Number, 8Byte/Beat, 4Byte/IQ Pair
        R_axi_beat_cnt <= 23'h0; 

        R_cmd_receive_done <= 1'b1;
    end
    else if(O_m_axi_s2mm_wvalid && I_m_axi_s2mm_wready && (R_axi_beat_cnt < R_axi_beat_num)) begin 
        R_axi_beat_cnt <= R_axi_beat_cnt + 23'h1; 
    end
    else if(R_cmd_receive_done)
        R_cmd_receive_done <= 1'b0;
end
// Main function for data fragmentation, W_data_trans_done_rise(last 1 clk) is asserted after completing one fragment write, 
// and remains high until AXI AW becomes valid
always @(posedge I_ps_clk) begin
    if(I_ps_rst)
        R_data_trans_done <= 1'b0;
    else if(R_m_axi_s2mm_awvalid && I_m_axi_s2mm_awready)
        R_data_trans_done <= 1'b0;
    else if((R_axi_beat_cnt[7:0] == R_m_axi_s2mm_awlen) && O_m_axi_s2mm_wvalid)// && (R_axi_beat_cnt != R_axi_beat_cnt_d))
        R_data_trans_done <= 1'b1;
end

always @(posedge I_ps_clk) begin
    R_data_trans_done_d <= R_data_trans_done;
end

always @(posedge I_ps_clk) begin
    R_axi_beat_cnt_d <= R_axi_beat_cnt;
end

assign W_data_trans_done_rise = R_data_trans_done && !R_data_trans_done_d;

// AXI write address channel state machine
// Function: Split long data packets into multiple AXI bursts (max 256 beats each)
always @(posedge I_ps_clk) begin
    if(I_ps_rst) begin
        R_m_axi_s2mm_awvalid <= 1'b0;
        R_m_axi_s2mm_awaddr  <= 32'h0;
        R_m_axi_s2mm_awlen   <= 8'h0;
        R_pkt_beat_len       <= 23'h0;
    end
    else begin
        // State 1: Address handshake completed, prepare for next burst
        if(R_m_axi_s2mm_awvalid && I_m_axi_s2mm_awready) begin
            R_m_axi_s2mm_awvalid <= 1'b0;
            
            // If there's remaining data, increment address
            if(R_pkt_beat_len > 0) begin
                R_m_axi_s2mm_awaddr <= R_m_axi_s2mm_awaddr + {R_m_axi_s2mm_awlen, 3'b0} + 32'h8;
            end
        end
        // State 2: Remaining data needs transmission, start new burst
        else if((R_pkt_beat_len > 0) && W_data_trans_done_rise && !R_m_axi_s2mm_awvalid) begin
            R_m_axi_s2mm_awvalid <= 1'b1;
            
            // Split burst: maximum 256 beats
            if(R_pkt_beat_len > 9'h100) begin
                R_m_axi_s2mm_awlen <= 8'hFF;         // 256 beats
                R_pkt_beat_len     <= R_pkt_beat_len - 9'h100;
            end
            else begin
                R_m_axi_s2mm_awlen <= R_pkt_beat_len[7:0] - 8'h1;  // awlen = actual beats - 1
                R_pkt_beat_len     <= 23'h0;
            end
        end
        // State 3: Receive new command, initialize transmission
        else if(R_cmd_receive_done) begin
            R_m_axi_s2mm_awvalid <= 1'b1;
            R_m_axi_s2mm_awaddr  <= R_src_addr;  // Start address
            
            // Split burst: maximum 256 beats
            if(R_axi_beat_num > 9'h100) begin
                R_m_axi_s2mm_awlen <= 8'hFF;         // 256 beats
                R_pkt_beat_len     <= R_axi_beat_num - 9'h100;
            end
            else begin
                R_m_axi_s2mm_awlen <= R_axi_beat_num[7:0] - 8'h1;  // awlen = actual beats - 1
                R_pkt_beat_len     <= 23'h0;
            end
        end
    end
end

// ======================================================================================================
// Data transmission
// Combined and cross clock domain
always @(posedge I_sys_clk)begin 
    O_s_axis_s2mm_tready <= ~W_prog_full_0;  
    O_s2mm_err	         <= R_write_err; 
end 
always @(posedge I_ps_clk)begin  
    if (I_m_axi_s2mm_bvalid) begin 
	    R_write_err <= |I_m_axi_s2mm_bresp;  
	end 
end

always @(posedge I_sys_clk) begin
    R_wr_en_data <= (I_s_axis_s2mm_tlast & I_s_axis_s2mm_tvalid) ? 1'b1 : R_iq_data_vld;
end

always @(posedge I_sys_clk) begin
    if(I_sys_rst) begin
        R_din__data   <= 64'h0;
        R_iq_data_vld <= 1'b0;
    end
    else if(O_s_axis_s2mm_tready && I_s_axis_s2mm_tvalid) begin
        R_iq_data_vld <= R_iq_data_vld + 1'b1;
        R_din__data[72:72] <= I_s_axis_s2mm_tlast; // EOP
        if(R_iq_data_vld) begin
            R_din__data[31:00] <= {I_s_axis_s2mm_tdata_I,I_s_axis_s2mm_tdata_Q};
            R_din__data[67:64] <= 4'hF;
        end
        else begin
            R_din__data[63:32] <= {I_s_axis_s2mm_tdata_I,I_s_axis_s2mm_tdata_Q};
            R_din__data[71:68] <= 4'hF;
        end
    end
    else begin
        R_din__data   <= 73'h0;
        R_iq_data_vld <= 1'b0;
    end
end

xpm_fifo_async #(
   .DOUT_RESET_VALUE    ("0"       ), // String 
   .ECC_MODE            ("no_ecc"  ), // String 
   .FIFO_MEMORY_TYPE    ("block"   ), // String
   .READ_MODE           ("fwft"    ), // String 
   .USE_ADV_FEATURES    ("1707"    ), // String 
   .FIFO_WRITE_DEPTH    (512       ), // DECIMAL   
   .PROG_FULL_THRESH    (500       ), // DECIMAL 
   .PROG_EMPTY_THRESH   (10        ), // DECIMAL 
   .WRITE_DATA_WIDTH    (73        ), // DECIMAL  
   .READ_DATA_WIDTH     (73        ), // DECIMAL 
   .FIFO_READ_LATENCY   (0         ), // DECIMAL 
   .FULL_RESET_VALUE    (0         ), // DECIMAL 
   .SIM_ASSERT_CHK      (0         ), // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
   .WAKEUP_TIME         (0         ), // DECIMAL
   .RELATED_CLOCKS      (0         ), // DECIMAL 
   .WR_DATA_COUNT_WIDTH (10        ), // DECIMAL
   .RD_DATA_COUNT_WIDTH (10        ), // DECIMAL
   .CDC_SYNC_STAGES     (2         )  // DECIMAL     
) xpm_fifo_async_data (     
    .wr_clk        (I_sys_clk              ), 
    .rst           (I_sys_rst              ),
    .rd_clk        (I_ps_clk               ),   
    .wr_en         (R_wr_en_data           ),   
    .din           (R_din__data            ), // [130:127]:Tag; [126:95]:SADDR; [94:74]:len; [73:66]:KEEP; [65]:SOP; [64]:EOP; [63:0]:data      
    .rd_en         (R_rd_en_data           ),  
    .data_valid    (W_data_valid_0         ),  
    .dout          (W_dout__data           ), // [72]:EOP; [71:64]:KEEP; [63:0]:data; 
    .prog_full     (W_prog_full_0          ), 
    .prog_empty    (),    
    .almost_full   (),            
    .almost_empty  (),
    .full          (),
    .empty         (),   
    .overflow      (),  
    .underflow     (),
    .wr_data_count (W_wr_data_count0 ),
    .rd_data_count (W_rd_data_count0 ),                                          
    .wr_rst_busy   (), 
    .rd_rst_busy   (),                           
    .dbiterr       (),             
    .sbiterr       (),  
    .wr_ack        (),           
    .injectdbiterr (1'b0  ),                                   
    .injectsbiterr (1'b0  ),                                
    .sleep         (1'b0  )                                    
);  

always @(posedge I_ps_clk) begin
    if (I_ps_rst) begin
        R_rd_en_data        <= 1'b0;
        R_m_axi_s2mm_wvalid <= 1'b0;
        O_m_axi_s2mm_wdata  <= 64'h0;
        O_m_axi_s2mm_wstrb  <= 8'h0;
        R_m_axi_s2mm_wlast  <= 1'b0;
    end 
    else begin
        // Default: clear all signals
        R_rd_en_data        <= 1'b0;
        R_m_axi_s2mm_wvalid <= 1'b0;
        O_m_axi_s2mm_wdata  <= 64'h0;
        O_m_axi_s2mm_wstrb  <= 8'h0;
        R_m_axi_s2mm_wlast  <= 1'b0;
        
        // Only assert signals when valid data and ready
        if (W_data_valid_0 && I_m_axi_s2mm_wready && !R_data_trans_done) begin
            R_rd_en_data        <= 1'b1;
            if(R_rd_en_data) begin
                R_rd_en_data        <= 1'b0;
                R_m_axi_s2mm_wvalid <= 1'b1;
                O_m_axi_s2mm_wdata  <= W_dout__data[63:0];
                O_m_axi_s2mm_wstrb  <= W_dout__data[71:64];
                R_m_axi_s2mm_wlast  <= W_dout__data[72];
            end
        end
    end
end
                                                                   
                                                                   
endmodule