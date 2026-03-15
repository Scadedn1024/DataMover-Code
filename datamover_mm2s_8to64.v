`timescale 1ns / 100ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 
// Design Name: 
// Module Name: datamover_mm2s
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
/* MM2S通道输入接口时序模型（严格的同步时序，否则会出错）
 * PL侧给出读请求指令，本模块会按照单次最多读128Byte的原则，处理读请求指令；当本次读请求数据未传输完时，不允许下条读请求指令输入；
 * 
 * 
 * S2MM通道时序模型（严格的同步时序，否则会出错）
 * PL侧给出写请求指令，本模块会按照单次最多写128Byte的原则，处理写请求指令；当本次写请求数据未全部写入时，不允许下条写请求指令输入；
 *   
 *    
 * CMD[71:0]：
 * [71:68]:RSVD 
 * [67:64]:TAG   
 * [63:32]:SADDR   
 *    [31]:DRR
 *    [30]:EOF
 * [29:24]:DSA
 *    [23]:TYPE 
 *  [22:0]:BTT 
 *   
 *
 * 
 */ 
////////////////////////////////////////////////////////////////////////////////// 

module datamover_mm2s (  
    input             I_sys_clk                ,  
	input             I_sys_rst                , 
	input             I_ps_clk                 , 
	input             I_ps_rst                 , 
    // 读通道 
	output reg        O_mm2s_err               , 
	
	input             I_m_axis_mm2s_sts_tready ,      
	output reg        O_m_axis_mm2s_sts_tvalid ,           	     
	output reg  [7:0] O_m_axis_mm2s_sts_tdata  ,   
	output reg        O_m_axis_mm2s_sts_tkeep  ,   
	output reg        O_m_axis_mm2s_sts_tlast  ,  
	
	output reg        O_s_axis_mm2s_cmd_tready ,                 
	input             I_s_axis_mm2s_cmd_tvalid ,            	
	input      [71:0] I_s_axis_mm2s_cmd_tdata  , 
	
	input             I_m_axi_mm2s_arready     , 
	output            O_m_axi_mm2s_arvalid     ,
    output      [7:0] O_m_axi_mm2s_arlen       , 
    output     [48:0] O_m_axi_mm2s_araddr      ,  
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
	output      [7:0] O_m_axis_mm2s_tdata      ,   
	output            O_m_axis_mm2s_tkeep      ,   
    output            O_m_axis_mm2s_tlast        // 当前指令仅有1个byte时有效，中间的切片不会拉高            	       
													           
    );                      
 
reg   [1:0] R_rd_rresp = 0; 
reg         R_gen_sts = 0; 
reg   [3:0] R_gen_sts_dly = 0;
reg   [3:0] R_sts_interval = 0; 

reg         R_wr_en_0 = 0; 
reg  [71:0] R_din___0 = 0; 
wire        W_rd_en_0; 
wire        W_data_valid_0; 
wire [71:0] W_dout__0; 
wire        W_prog_full_0; 
wire  [4:0] W_rd_data_count0; 

reg         R_m_axi_mm2s_arvalid = 0; 
reg  [31:0] R_m_axi_mm2s_araddr = 0;  
reg   [3:0] R_m_axi_mm2s_arlen = 0; 
wire [20:0] W_arlen; 
wire  [2:0] W_remainder_btt; 
reg   [2:0] R_remainder_btt = 0; 
reg         R_receive_dat = 0;
wire        W_last_cmd_flag;
reg  [20:0] R_nxt_len = 0; 
reg   [4:0] R_pkt_len = 0;  

reg         R_rd_dat_sop = 1; 
reg         R_wr_en_1 = 0; 
reg  [73:0] R_din___1 = 0; 
reg         R_rd_en_1 = 0; 
wire        W_rd_en_1; 
wire        W_data_valid_1; 
wire [73:0] W_dout__1; 
wire        W_prog_full_1; 
wire  [9:0] W_rd_data_count1;  

reg   [2:0] R_byte_cnt = 0; 
reg   [4:0] R_lines0 = 0;  

reg         R_byte_dat_vld = 0; //  
reg         R_m_axis_mm2s_tvalid = 0;
reg   [7:0] R_m_axis_mm2s_tdata = 0;
// reg         R_m_axis_mm2s_tkeep = 0;
reg         R_m_axis_mm2s_tlast = 0;

wire [63:0] W_m_axi_mm2s_rdata; 

assign O_m_axi_mm2s_arvalid = R_m_axi_mm2s_arvalid; 
assign O_m_axi_mm2s_araddr  = R_m_axi_mm2s_araddr;   // 位宽扩展由内部处理 
assign O_m_axi_mm2s_arlen   = R_m_axi_mm2s_arlen;    // 位宽扩展由内部处理 

assign O_m_axi_mm2s_arsize  = 3'h3;   
assign O_m_axi_mm2s_arburst = 2'h1; 
assign O_m_axi_mm2s_arid    = 6'h0; 
assign O_m_axi_mm2s_arprot  = 3'h0; 
assign O_m_axi_mm2s_arcache = 4'h0; 
assign O_m_axi_mm2s_arqos   = 4'h0; 
assign O_m_axi_mm2s_aruser  = 1'b0;  

assign O_m_axis_mm2s_tvalid = R_m_axis_mm2s_tvalid;     	
assign O_m_axis_mm2s_tdata  = R_m_axis_mm2s_tdata;   
assign O_m_axis_mm2s_tkeep  = R_m_axis_mm2s_tvalid; // R_m_axis_mm2s_tkeep   
assign O_m_axis_mm2s_tlast  = R_m_axis_mm2s_tlast;  
 
assign W_m_axi_mm2s_rdata = {I_m_axi_mm2s_rdata[07:00],I_m_axi_mm2s_rdata[15:08],I_m_axi_mm2s_rdata[23:16],I_m_axi_mm2s_rdata[31:24],
                             I_m_axi_mm2s_rdata[39:32],I_m_axi_mm2s_rdata[47:40],I_m_axi_mm2s_rdata[55:48],I_m_axi_mm2s_rdata[63:56]};   
 
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

always @(posedge I_ps_clk)begin 
    O_m_axi_mm2s_rready <= ~W_prog_full_1;  
    end 

always @(posedge I_sys_clk)begin 
    O_s_axis_mm2s_cmd_tready <= ~W_prog_full_0;  
    end  

always @(posedge I_sys_clk)begin 
    R_wr_en_0 <= I_s_axis_mm2s_cmd_tvalid && (|I_s_axis_mm2s_cmd_tdata[22:0]) && (~W_prog_full_0);   
	R_din___0 <= I_s_axis_mm2s_cmd_tdata; 		
    end 

xpm_fifo_async #( 
   .DOUT_RESET_VALUE    ("0"       ), // String 
   .ECC_MODE            ("no_ecc"  ), // String 
   .FIFO_MEMORY_TYPE    ("block"   ), // String
   .READ_MODE           ("fwft"    ), // String 
   .USE_ADV_FEATURES    ("1707"    ), // String 
   .FIFO_WRITE_DEPTH    (16        ), // DECIMAL   
   .PROG_FULL_THRESH    (10        ), // DECIMAL 
   .PROG_EMPTY_THRESH   (5         ), // DECIMAL 
   .WRITE_DATA_WIDTH    (72        ), // DECIMAL  
   .READ_DATA_WIDTH     (72        ), // DECIMAL 
   .FIFO_READ_LATENCY   (0         ), // DECIMAL 
   .FULL_RESET_VALUE    (0         ), // DECIMAL 
   .SIM_ASSERT_CHK      (0         ), // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
   .WAKEUP_TIME         (0         ), // DECIMAL
   .RELATED_CLOCKS      (0         ), // DECIMAL 
   .WR_DATA_COUNT_WIDTH (5         ), // DECIMAL
   .RD_DATA_COUNT_WIDTH (5         ), // DECIMAL
   .CDC_SYNC_STAGES     (2         )  // DECIMAL     
) xpm_fifo_async_inst0 (     
    .wr_clk        (I_sys_clk        ),    
    .rst           (I_sys_rst        ), 
    .rd_clk        (I_ps_clk         ),  
    .wr_en         (R_wr_en_0        ),   
    .din           (R_din___0        ),    
    .rd_en         (W_rd_en_0        ),  
    .data_valid    (W_data_valid_0   ),  
    .dout          (W_dout__0        ), // [71:68]:RSVD; [67:64]:TAG; [63:32]:SADDR; [31]:DRR; [30]:EOF; [29:24]:DSA; [23]:TYPE; [22:0]:BTT;              
    .prog_full     (W_prog_full_0    ), 
    .prog_empty    (),    
    .almost_full   (),            
    .almost_empty  (),
    .full          (),
    .empty         (),   
    .overflow      (),  
    .underflow     (),
    .wr_data_count (),
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

// 解析寄存的读请求指令，以128Byte为单位，对于大于128Byte的请求，需要切分  
// Note: 此处构造的读指令，数据长度对齐8Byte. 
assign W_arlen         = W_dout__0[22:3]+|W_dout__0[2:0]; 
assign W_remainder_btt = W_dout__0[2:0]; 
assign W_last_cmd_flag = (R_nxt_len==21'h0);
assign W_rd_en_0       = I_m_axi_mm2s_arready && R_m_axi_mm2s_arvalid && (R_nxt_len==21'h0);   
always @(posedge I_ps_clk)begin 
    if (I_ps_rst)begin  	  
        R_m_axi_mm2s_arvalid <= 1'b0;
        R_receive_dat        <= 1'b0; 		
	    end 
    else if (R_receive_dat)begin // 等待读数据返回 
	    if (O_m_axi_mm2s_rready && I_m_axi_mm2s_rvalid && I_m_axi_mm2s_rlast) begin 
		    R_receive_dat   <= 1'b0; 
            if (|R_nxt_len)begin // 数据未读完，继续发送读请求指令 
		        R_m_axi_mm2s_arvalid <= 1'b1;  
			    R_m_axi_mm2s_araddr  <= R_m_axi_mm2s_araddr + R_m_axi_mm2s_arlen; 
				R_m_axi_mm2s_arlen   <= R_nxt_len-1'b1; 
				R_pkt_len            <= R_nxt_len; 
				R_nxt_len            <= 21'h0; 
				R_remainder_btt      <= W_remainder_btt; 
				if (R_nxt_len>5'h10)begin 
				    R_m_axi_mm2s_arlen <= 4'hF; 
					R_pkt_len          <= 5'h10; 
					R_nxt_len          <= R_nxt_len-5'h10; 
				    end    			
                end  			    
            end 							
        end 	
	else if (R_m_axi_mm2s_arvalid)begin 
	    R_m_axi_mm2s_arvalid <= ~I_m_axi_mm2s_arready;
		R_receive_dat        <= I_m_axi_mm2s_arready; 
        end 
    else if (W_data_valid_0)begin // 检测到读指令 	
        R_receive_dat        <= 1'b0;  	   
	    R_m_axi_mm2s_arvalid <= 1'b1;
        R_m_axi_mm2s_araddr  <= W_dout__0[63:32];   
        R_m_axi_mm2s_arlen   <= W_arlen-1'b1; 
        R_pkt_len	         <= W_arlen;   	
		R_nxt_len            <= 21'h0; 
		R_remainder_btt      <= W_remainder_btt; 
		if (W_arlen > 8'h10)begin 
		    R_m_axi_mm2s_arlen <= 4'hF; 
            R_pkt_len          <= 5'h10; 
            R_nxt_len          <= W_arlen-5'h10;  			
            end 
        end 			
    end  

always @(posedge I_ps_clk)begin 
    R_wr_en_1 <= 1'b0; 
    if (O_m_axi_mm2s_rready && I_m_axi_mm2s_rvalid)begin 
	    R_rd_dat_sop <= I_m_axi_mm2s_rlast; 
        R_wr_en_1    <= 1'b1; 	
		R_din___1    <= R_rd_dat_sop? {W_last_cmd_flag,1'b1,R_remainder_btt,R_pkt_len,W_m_axi_mm2s_rdata}:
		                              {W_last_cmd_flag,1'b0,R_remainder_btt,5'h0,W_m_axi_mm2s_rdata};   
	    end  		
    end 

xpm_fifo_async #( 
   .DOUT_RESET_VALUE    ("0"        ), // String 
   .ECC_MODE            ("no_ecc"   ), // String 
   .FIFO_MEMORY_TYPE    ("block"    ), // String
   .READ_MODE           ("fwft"     ), // String 
   .USE_ADV_FEATURES    ("1707"     ), // String 
   .FIFO_WRITE_DEPTH    (512        ), // DECIMAL   
   .PROG_FULL_THRESH    (500        ), // DECIMAL 
   .PROG_EMPTY_THRESH   (10         ), // DECIMAL 
   .WRITE_DATA_WIDTH    (74         ), // DECIMAL  
   .READ_DATA_WIDTH     (74         ), // DECIMAL 
   .FIFO_READ_LATENCY   (0          ), // DECIMAL 
   .FULL_RESET_VALUE    (0          ), // DECIMAL 
   .SIM_ASSERT_CHK      (0          ), // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
   .WAKEUP_TIME         (0          ), // DECIMAL
   .RELATED_CLOCKS      (0          ), // DECIMAL 
   .WR_DATA_COUNT_WIDTH (10         ), // DECIMAL
   .RD_DATA_COUNT_WIDTH (10         ), // DECIMAL
   .CDC_SYNC_STAGES     (2          )  // DECIMAL     
) xpm_fifo_async_inst1 (     
    .wr_clk        (I_ps_clk               ),  
    .rst           (I_ps_rst               ), 
    .rd_clk        (I_sys_clk              ),  
    .wr_en         (R_wr_en_1              ),   
    .din           (R_din___1              ),    
    .rd_en         (R_rd_en_1 || W_rd_en_1 ),  
    .data_valid    (W_data_valid_1         ),  
    .dout          (W_dout__1              ), // [73]:last piece;[72]:sop;[71:69]:remainder_btt;[68:64]:len; [63:0]:data; 
    .prog_full     (W_prog_full_1          ), 
    .prog_empty    (),    
    .almost_full   (),            
    .almost_empty  (),
    .full          (),
    .empty         (),   
    .overflow      (),  
    .underflow     (),
    .wr_data_count (),
    .rd_data_count (W_rd_data_count1       ),                                          
    .wr_rst_busy   (), 
    .rd_rst_busy   (),                           
    .dbiterr       (),             
    .sbiterr       (),  
    .wr_ack        (),           
    .injectdbiterr (1'b0  ),                                   
    .injectsbiterr (1'b0  ),                                
    .sleep         (1'b0  )                                    
); 

assign W_rd_en_1 = W_data_valid_1 && I_m_axis_mm2s_tready && R_byte_dat_vld && (&R_byte_cnt);   
always @(posedge I_sys_clk)begin // 并串转换   
    if (I_sys_rst)begin 
        R_lines0   <= 5'h0; 
        R_byte_cnt <= 3'h0; 
	    end 		
    else if(R_lines0==5'h1)begin // 取尾部数据   	   		   
	    if (I_m_axis_mm2s_tready)begin 
	        R_byte_dat_vld       <= (R_byte_cnt!=3'h7);
		    R_byte_cnt           <= R_byte_cnt + 1'b1; 
		    R_lines0             <= R_lines0 - &R_byte_cnt;	
            R_m_axis_mm2s_tvalid <= (R_byte_cnt!=3'h7);         // 非最后1片数据时 		   	    
            if (W_dout__1[73] && (W_dout__1[71:69]==3'h1))begin  // 最后1片数据，且数据不为8Byte的整数倍  	    	
		        R_m_axis_mm2s_tvalid <= 1'b0;   		       
		        R_m_axis_mm2s_tlast  <= 1'b0; 
		        end 	
		    else if (W_dout__1[73] && (W_dout__1[71:69] > 3'h1))begin 
		        R_m_axis_mm2s_tvalid <= (R_byte_cnt < W_dout__1[71:69]-3'b1); 
		        R_m_axis_mm2s_tlast  <= (R_byte_cnt ==W_dout__1[71:69]-3'h2);
		        end     
		    else begin 
		        R_m_axis_mm2s_tlast  <= W_dout__1[73] && (R_byte_cnt==3'h6); 
		        end     	    		     		       		    		    	
		    end 		
        end 	
	else if(|R_lines0)begin // 取中间拍数据  	
        if (I_m_axis_mm2s_tready)begin     
	        R_byte_cnt          <= R_byte_cnt + 1'b1;  
		    R_lines0            <= R_lines0 - &R_byte_cnt;   
		    R_m_axis_mm2s_tlast <= W_dout__1[73] && (R_lines0==5'h2) && (&R_byte_cnt) && (W_dout__1[71:69]==3'h1); 
		    end 
        end   	
	else if(W_data_valid_1 && (W_rd_data_count1 >= W_dout__1[68:64]) && I_m_axis_mm2s_tready)begin // 攒包  	
        if (W_dout__1[72])begin    
            R_byte_dat_vld       <= 1'b1;  
            R_lines0             <= W_dout__1[68:64]; // 根据指令长度取数据  	
            R_byte_cnt           <= 3'h0;              
            R_m_axis_mm2s_tvalid <= 1'b1; 
            // R_m_axis_mm2s_tkeep  <= 1'b1; 
            R_m_axis_mm2s_tlast  <= W_dout__1[73] && (W_dout__1[68:64]==5'h1) && (W_dout__1[71:69]==3'h1); //                 		        		                           
            end 
        else if (R_rd_en_1)begin 
		    R_rd_en_1 <= 1'b0; 
            end 	
	    else begin 
		    R_rd_en_1 <= 1'b1;  
            end 		
        end 	
    end 

always @(*)begin 
    case(R_byte_cnt) 
	    3'h0   : R_m_axis_mm2s_tdata  <= W_dout__1[63:56];
	    3'h1   : R_m_axis_mm2s_tdata  <= W_dout__1[55:48];
		3'h2   : R_m_axis_mm2s_tdata  <= W_dout__1[47:40];
		3'h3   : R_m_axis_mm2s_tdata  <= W_dout__1[39:32];
		3'h4   : R_m_axis_mm2s_tdata  <= W_dout__1[31:24];
		3'h5   : R_m_axis_mm2s_tdata  <= W_dout__1[23:16];
		3'h6   : R_m_axis_mm2s_tdata  <= W_dout__1[15:08];
		3'h7   : R_m_axis_mm2s_tdata  <= W_dout__1[07:00];		
		default: R_m_axis_mm2s_tdata  <= R_m_axis_mm2s_tdata;  
	    endcase 
    end      
   
endmodule
