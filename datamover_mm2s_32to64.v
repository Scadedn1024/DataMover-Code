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
// TEXT NAME:              datamover_mm2s.v
// PATH:                   
// Descriptions:           
//    
// 默认I_m_axis_mm2s_tready恒为1，若I_m_axis_mm2s_tready存在反压情况，数据异步FIFO的读出传递可能存在重复或遗漏问题。  
// 同样的，I_s_axis_mm2s_cmd_len长度也必须是偶数。                   
//----------------------------------------------------------------------------------------
//****************************************************************************************//

module datamover_mm2s(
    input             I_sys_clk                , 
	input             I_sys_rst                , 
	input             I_ps_clk                 , 
	input             I_ps_rst                 , 
    // 
	output reg        O_mm2s_err               , 
	
	input             I_m_axis_mm2s_sts_tready ,      
	output reg        O_m_axis_mm2s_sts_tvalid ,           	     
	output reg  [7:0] O_m_axis_mm2s_sts_tdata  ,   
	output reg        O_m_axis_mm2s_sts_tkeep  ,   
	output reg        O_m_axis_mm2s_sts_tlast  ,  
	
	output reg        O_s_axis_mm2s_cmd_tready ,                 
	input             I_s_axis_mm2s_cmd_tvalid ,            	
	input      [31:0] I_s_axis_mm2s_cmd_addr   ,
    input      [22:0] I_s_axis_mm2s_cmd_len    , 
	
	input             I_m_axi_mm2s_arready     , 
	output            O_m_axi_mm2s_arvalid     ,
	output      [7:0] O_m_axi_mm2s_arlen       , 
	output     [31:0] O_m_axi_mm2s_araddr      , 
	output      [2:0] O_m_axi_mm2s_arsize      , 
	output      [1:0] O_m_axi_mm2s_arburst     , 
	output      [5:0] O_m_axi_mm2s_arid        ,
	output      [2:0] O_m_axi_mm2s_arprot      , 
	output      [3:0] O_m_axi_mm2s_arcache     , 
	output            O_m_axi_mm2s_arlock      , 
	output      [3:0] O_m_axi_mm2s_arqos       , 
	output            O_m_axi_mm2s_aruser      , 	         
	
    output reg        O_m_axi_mm2s_rready      , 	
	input             I_m_axi_mm2s_rvalid      ,     
	input      [63:0] I_m_axi_mm2s_rdata       , 
	input       [1:0] I_m_axi_mm2s_rresp       ,  
	input             I_m_axi_mm2s_rlast       ,  
	input       [5:0] I_m_axi_mm2s_rid         ,         
	     	 	
	input             I_m_axis_mm2s_tready     ,
    output            O_m_axis_mm2s_tvalid     ,    	
	output     [15:0] O_m_axis_mm2s_tdata_I    ,
	output     [15:0] O_m_axis_mm2s_tdata_Q    ,
	output            O_m_axis_mm2s_tkeep      ,   
	output            O_m_axis_mm2s_tlast           
);

reg       [1:0] R_rd_rresp           = 0 ; 
reg             R_gen_sts            = 0 ; 
reg       [3:0] R_gen_sts_dly        = 0 ;
reg       [3:0] R_sts_interval       = 0 ;

// CMD Input Signals
reg             R_wr_en_cmd              ;
reg      [54:0] R_din___cmd              ; // [54:23]:SADDR; [22:0]:BTT;
wire            W_rd_en_cmd              ;
wire     [54:0] W_dout__cmd              ; // [54:23]:SADDR; [22:0]:BTT;
wire            W_data_valid_cmd         ;
wire            W_prog_full_cmd          ;
wire      [4:0] W_rd_data_count_cmd      ;

reg      [31:0] R_src_addr               ; 
reg      [22:0] R_iq_btt                 ; 
reg      [22:0] R_axi_beat_num           ; 
reg      [22:0] R_axi_beat_cnt           ; 
reg      [22:0] R_axi_beat_cnt_d         ; 
reg             R_cmd_receive_done       ; 
reg             R_data_trans_done        ; 
reg             R_data_trans_done_d      ; 
reg             R_m_axi_mm2s_arvalid     ; 
reg      [31:0] R_m_axi_mm2s_araddr      ; 
reg       [7:0] R_m_axi_mm2s_arlen       ; 
reg      [22:0] R_pkt_beat_len           ;
wire            W_data_trans_done_rise   ;

reg             R_wr_en_data             ;
reg      [72:0] R_din__data              ;
wire            W_data_valid_0           ;
reg             R_rd_en_data             ;
wire     [72:0] W_dout__data             ;
wire            W_prog_full_0            ;
wire      [9:0] W_wr_data_count0         ;
wire      [9:0] W_rd_data_count0         ;

reg             R_iq_data_out_valid  = 0 ;
reg             R_iq_data_out_sel    = 0 ;

wire            W_m_axis_mm2s_tvalid     ;
wire     [15:0] W_m_axis_mm2s_tdata_I    ;
wire     [15:0] W_m_axis_mm2s_tdata_Q    ;
wire            W_m_axis_mm2s_tkeep      ;
wire            W_m_axis_mm2s_tlast      ;

reg             R_m_axis_mm2s_tvalid     ;
reg      [15:0] R_m_axis_mm2s_tdata_I    ;
reg      [15:0] R_m_axis_mm2s_tdata_Q    ;
reg             R_m_axis_mm2s_tkeep      ;
reg             R_m_axis_mm2s_tlast      ;


assign O_m_axi_mm2s_arvalid = R_m_axi_mm2s_arvalid;
assign O_m_axi_mm2s_araddr  = R_m_axi_mm2s_araddr ;
assign O_m_axi_mm2s_arlen   = R_m_axi_mm2s_arlen  ;
assign O_m_axi_mm2s_arsize  = 3'b011              ;  // 8字节
assign O_m_axi_mm2s_arburst = 2'b01               ;  // INCR突发
assign O_m_axi_mm2s_arid    = 6'h0                ;
assign O_m_axi_mm2s_arprot  = 3'b000              ;
assign O_m_axi_mm2s_arcache = 4'b0011             ;
assign O_m_axi_mm2s_arlock  = 1'b0                ;
assign O_m_axi_mm2s_arqos   = 4'h0                ;
assign O_m_axi_mm2s_aruser  = 1'b0                ;

assign O_m_axis_mm2s_tvalid  = R_m_axis_mm2s_tvalid ;
assign O_m_axis_mm2s_tdata_I = R_m_axis_mm2s_tdata_I;
assign O_m_axis_mm2s_tdata_Q = R_m_axis_mm2s_tdata_Q;
assign O_m_axis_mm2s_tkeep   = R_m_axis_mm2s_tkeep  ;
assign O_m_axis_mm2s_tlast   = R_m_axis_mm2s_tlast  ;

// ========================================================================================
// State
always @(posedge I_ps_clk)begin 
    if (|R_gen_sts_dly)begin 
	    R_gen_sts_dly <= R_gen_sts_dly - 1'b1; 
	    end 
    else if (O_m_axi_mm2s_rready && I_m_axi_mm2s_rvalid && I_m_axi_mm2s_rlast)begin 
	    R_rd_rresp    <= I_m_axi_mm2s_rresp; 
		R_gen_sts     <= 1'b1; 
		R_gen_sts_dly <= 4'h3; 
	    end 
	else begin 
	    R_gen_sts_dly <= 4'h0; 
		R_gen_sts     <= 1'b0; 
        end 	
    end 
 
always @(posedge I_sys_clk)begin 
    O_mm2s_err <= |R_rd_rresp;     
    if (|R_sts_interval)begin 
	    R_sts_interval <= R_sts_interval - 1'b1; 
	    end 
    else if (O_m_axis_mm2s_sts_tvalid && I_m_axis_mm2s_sts_tready)begin 
        O_m_axis_mm2s_sts_tvalid <= 1'b0; 
        O_m_axis_mm2s_sts_tkeep  <= 1'b0; 	
        O_m_axis_mm2s_sts_tlast  <= 1'b0; 	
        R_sts_interval           <= 4'h5; 		
	    end 
    else if (R_gen_sts)begin  
	    O_m_axis_mm2s_sts_tdata  <= |R_rd_rresp? 8'h10:8'h80;  
		O_m_axis_mm2s_sts_tvalid <= 1'b1; 
		O_m_axis_mm2s_sts_tkeep  <= 1'b1; 
		O_m_axis_mm2s_sts_tlast  <= 1'b1; 
	    end 
    end 

// ========================================================================================
// Command module
// Cross-clock domain conversion to ps_clk for processing
// Considering large data volumes, data fragmentation processing is required
always @(posedge I_sys_clk)begin 
    O_s_axis_mm2s_cmd_tready <= ~W_prog_full_cmd;  
end  

always @(posedge I_sys_clk)begin 
    R_wr_en_cmd <= I_s_axis_mm2s_cmd_tvalid && O_s_axis_mm2s_cmd_tready && (|I_s_axis_mm2s_cmd_len[22:0]) && (~W_prog_full_cmd);
	R_din___cmd <= {I_s_axis_mm2s_cmd_addr,I_s_axis_mm2s_cmd_len}; 		
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
    else if(O_m_axi_mm2s_rready && I_m_axi_mm2s_rvalid && (R_axi_beat_cnt < R_axi_beat_num)) begin 
        R_axi_beat_cnt <= R_axi_beat_cnt + 23'h1; 
    end
    else if(R_cmd_receive_done)
        R_cmd_receive_done <= 1'b0;
end


// Main function for data fragmentation, W_data_trans_done_rise(last 1 clk) is asserted after completing one fragment read, 
// and remains high until AXI AR becomes valid
always @(posedge I_ps_clk) begin
    if(I_ps_rst)
        R_data_trans_done <= 1'b0;
    else if(R_m_axi_mm2s_arvalid && I_m_axi_mm2s_arready)
        R_data_trans_done <= 1'b0;
    //else if((R_axi_beat_cnt[7:0] == R_m_axi_mm2s_arlen) && O_m_axi_mm2s_rready)//(R_axi_beat_cnt != R_axi_beat_cnt_d) && O_m_axi_mm2s_rready)
    else if((R_axi_beat_cnt[7:0] == R_m_axi_mm2s_arlen) && (R_axi_beat_cnt < R_axi_beat_num-1) && O_m_axi_mm2s_rready)
        R_data_trans_done <= 1'b1;
end

always @(posedge I_ps_clk) begin
    R_data_trans_done_d <= R_data_trans_done;
end

always @(posedge I_ps_clk) begin
    R_axi_beat_cnt_d <= R_axi_beat_cnt;
end

assign W_data_trans_done_rise = R_data_trans_done && !R_data_trans_done_d;

// AXI read address channel state machine
// Function: Split long data packets into multiple AXI bursts (maximum 256 beats each)
always @(posedge I_ps_clk) begin
    if(I_ps_rst) begin
        R_m_axi_mm2s_arvalid <= 1'b0;
        R_m_axi_mm2s_araddr  <= 32'h0;
        R_m_axi_mm2s_arlen   <= 8'h0;
        R_pkt_beat_len       <= 23'h0;
    end
    else begin
        // State 1: Address handshake completed, prepare for next burst
        if(R_m_axi_mm2s_arvalid && I_m_axi_mm2s_arready) begin
            R_m_axi_mm2s_arvalid <= 1'b0;
            
            // If there's remaining data, increment address
            if(R_pkt_beat_len > 0) begin
                R_m_axi_mm2s_araddr <= R_m_axi_mm2s_araddr + {R_m_axi_mm2s_arlen, 3'b0} + 32'h8;
            end
        end
        // State 2: Remaining data needs transfer, start new burst
        else if((R_pkt_beat_len > 0) && W_data_trans_done_rise && !R_m_axi_mm2s_arvalid) begin
            R_m_axi_mm2s_arvalid <= 1'b1;
            
            // Split burst: maximum 256 beats
            if(R_pkt_beat_len > 9'h100) begin
                R_m_axi_mm2s_arlen <= 8'hFF;         // 256 beats
                R_pkt_beat_len     <= R_pkt_beat_len - 9'h100;
            end
            else begin
                R_m_axi_mm2s_arlen <= R_pkt_beat_len[7:0] - 8'h1;  // arlen = actual beats - 1
                R_pkt_beat_len     <= 23'h0;
            end
        end
        // State 3: Receive new command, initialize transfer
        else if(R_cmd_receive_done) begin
            R_m_axi_mm2s_arvalid <= 1'b1;
            R_m_axi_mm2s_araddr  <= R_src_addr;  // Start address
            
            // Split burst: maximum 256 beats
            if(R_axi_beat_num > 9'h100) begin
                R_m_axi_mm2s_arlen <= 8'hFF;         // 256 beats
                R_pkt_beat_len     <= R_axi_beat_num - 9'h100;
            end
            else begin
                R_m_axi_mm2s_arlen <= R_axi_beat_num[7:0] - 8'h1;  // arlen = actual beats - 1
                R_pkt_beat_len     <= 23'h0;
            end
        end
    end
end

// ========================================================================================

// AXI read data channel processing
always @(posedge I_ps_clk) begin
    O_m_axi_mm2s_rready <= I_m_axis_mm2s_tready && !W_prog_full_0;
end

// Write AXI read data to FIFO
always @(posedge I_ps_clk) begin
    if(I_ps_rst) begin
        R_din__data  <= 73'h0;
        R_wr_en_data <= 1'b0;
    end
    else if(O_m_axi_mm2s_rready && I_m_axi_mm2s_rvalid) begin
        R_wr_en_data <= 1'b1;
        R_din__data[72]    <= (R_axi_beat_cnt == R_axi_beat_num-1) ? I_m_axi_mm2s_rlast : 1'b0;  // EOP
        R_din__data[71:64] <= 8'hFF;               // KEEP all bits set to 1
        R_din__data[63:0]  <= I_m_axi_mm2s_rdata;  // 64-bit data
    end
    else begin
        R_wr_en_data <= 1'b0;
//        R_din__data  <= 73'h0;
    end
end

// Data FIFO (PS clock domain to SYS clock domain)
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
    .wr_clk        (I_ps_clk               ), 
    .rst           (I_ps_rst               ),
    .rd_clk        (I_sys_clk              ),   
    .wr_en         (R_wr_en_data           ),   
    .din           (R_din__data            ), // [72]:EOP; [71:64]:KEEP; [63:0]:data      
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
    .wr_data_count (W_wr_data_count0       ),
    .rd_data_count (W_rd_data_count0       ),                                          
    .wr_rst_busy   (), 
    .rd_rst_busy   (),                           
    .dbiterr       (),             
    .sbiterr       (),  
    .wr_ack        (),           
    .injectdbiterr (1'b0  ),                                   
    .injectsbiterr (1'b0  ),                                
    .sleep         (1'b0  )                                    
);  

always @(posedge I_sys_clk) begin
    if(I_sys_rst)
        R_rd_en_data <= 1'b0;
    else begin
        if(R_iq_data_out_valid)
            R_rd_en_data <= R_iq_data_out_sel;
        else 
            R_rd_en_data <= 1'b0;
    end
end

always @(posedge I_sys_clk) begin
    if(I_sys_rst) begin
        R_iq_data_out_valid <= 1'b0;
        R_iq_data_out_sel   <= 1'b0;
    end
    else begin
        if(W_data_valid_0 && I_m_axis_mm2s_tready) begin
            R_iq_data_out_sel <= R_iq_data_out_sel + 1'b1;
            R_iq_data_out_valid <= 1'b1;
        end
        else begin
            R_iq_data_out_valid <= 1'b0;
            R_iq_data_out_sel  <= 1'b0;
        end
    end
end


assign W_m_axis_mm2s_tvalid  = R_iq_data_out_valid ? (R_rd_en_data ? |W_dout__data[67:64] : |W_dout__data[71:68]) : 1'b0;
assign W_m_axis_mm2s_tdata_I = R_iq_data_out_valid ? (R_rd_en_data ? W_dout__data[31:16] : W_dout__data[63:48]) : 16'h0;
assign W_m_axis_mm2s_tdata_Q = R_iq_data_out_valid ? (R_rd_en_data ? W_dout__data[15:00] : W_dout__data[47:32]) : 16'h0;
assign W_m_axis_mm2s_tkeep   = R_iq_data_out_valid ? (R_rd_en_data ? |W_dout__data[67:64] : |W_dout__data[71:68]) : 1'b0;
assign W_m_axis_mm2s_tlast   = R_iq_data_out_valid ? (R_rd_en_data ? W_dout__data[72] : 1'b0) : 1'b0;

always @(posedge I_sys_clk) begin
    if(I_sys_rst) begin
        R_m_axis_mm2s_tdata_I <= 16'h0;
        R_m_axis_mm2s_tdata_Q <= 16'h0;
        R_m_axis_mm2s_tlast   <= 1'h0 ;
    end else begin
        R_m_axis_mm2s_tdata_I <= W_m_axis_mm2s_tdata_I;
        R_m_axis_mm2s_tdata_Q <= W_m_axis_mm2s_tdata_Q;
        R_m_axis_mm2s_tlast   <= W_m_axis_mm2s_tlast  ;
    end
end  

always @(posedge I_sys_clk) begin
    if(I_sys_rst) begin
        R_m_axis_mm2s_tvalid <= 1'b0;
        R_m_axis_mm2s_tkeep  <= 1'b0;
    end else begin
        R_m_axis_mm2s_tvalid <= R_m_axis_mm2s_tlast ? 1'b0 : W_m_axis_mm2s_tvalid;
        R_m_axis_mm2s_tkeep  <= R_m_axis_mm2s_tlast ? 1'b0 : W_m_axis_mm2s_tkeep ;
    end
end
                                                                   
                                                                   
endmodule