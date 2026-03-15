`timescale 1ns / 100ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 
// Design Name: 
// Module Name: datamover_s2mm
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
/* S2MM通道时序模型：(严格的同步时许，否则会出错)  
 * PL侧给出写请求指令，本模块会按照单次最多写128Byte的原则，处理写请求指令，当本次写请求数据未传输完时，不允许下条写请求指令的输入； 
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
 */ 
////////////////////////////////////////////////////////////////////////////////// 

module datamover_s2mm (  
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
	  		    							     
    output reg        O_s_axis_s2mm_cmd_tready ,
    input             I_s_axis_s2mm_cmd_tvalid ,     
    input      [71:0] I_s_axis_s2mm_cmd_tdata  , 
											   
	output reg        O_s_axis_s2mm_tready     , // 该接口输入的数据是断续的    
    input       [7:0] I_s_axis_s2mm_tdata      , 
    input             I_s_axis_s2mm_tkeep      , 
    input             I_s_axis_s2mm_tlast      ,
    input             I_s_axis_s2mm_tvalid     ,
        
    input             I_m_axi_s2mm_awready     , // 与AXI3对接，AXI3 max_burst_len = 16 ***  
    output            O_m_axi_s2mm_awvalid     ,
    output     [31:0] O_m_axi_s2mm_awaddr      , 
    output      [3:0] O_m_axi_s2mm_awlen       , 
    output      [2:0] O_m_axi_s2mm_awsize      , 
    output      [1:0] O_m_axi_s2mm_awburst     ,
    output      [2:0] O_m_axi_s2mm_awprot      ,
    output      [3:0] O_m_axi_s2mm_awcache     ,
    output            O_m_axi_s2mm_awlock      , // new 
    output      [3:0] O_m_axi_s2mm_awqos       , // new     
    output      [3:0] O_m_axi_s2mm_awuser      ,    
    
    input             I_m_axi_s2mm_wready      ,
    output            O_m_axi_s2mm_wvalid      , 
    output reg [63:0] O_m_axi_s2mm_wdata       ,
    output reg  [7:0] O_m_axi_s2mm_wstrb       ,
    output            O_m_axi_s2mm_wlast       ,
    
    output            O_m_axi_s2mm_bready      ,
    input             I_m_axi_s2mm_bvalid      ,        
    input       [1:0] I_m_axi_s2mm_bresp             
    );                      
    
/******************************************************* 以下为 S2MM-Channel *******************************************************/  
reg           R_write_err = 0;
reg    [22:0] R_rxd_byte = 0;

reg           R_rx_ctrl = 1;  
reg    [22:0] R_byte_num = 0; 
reg    [31:0] R_src_addr = 0; 
reg     [3:0] R_tag_val = 0;
reg     [2:0] R_beat_num = 0;  
reg     [2:0] R_remain_byte = 0;
reg     [7:0] R_Bytenable = 0; 

reg           R_sop_flag = 1; 
reg    [20:0] R_8byte_num = 0;
reg    [20:0] R_8byte_len = 0;
reg           R_8byte_vld = 0;
reg    [63:0] R_8byte_dat = 0; 
reg     [7:0] R_8byte_keep = 0;
reg           R_8byte_sop = 0; 
reg           R_8byte_eop = 0;  

reg           R_wr_en_0 = 0; 
reg   [130:0] R_din___0 = 0; 
wire          W_rd_en_0; 
reg           R_rd_en_0 = 0; 
wire          W_data_valid_0; 
wire  [130:0] W_dout__0; 
wire          W_prog_full_0; 
wire    [9:0] W_rd_data_count0; 

reg     [2:0] R_lst_byte = 0;
reg    [20:0] R_row_num = 0; 
reg    [20:0] R_remain_row = 0; 
reg           R_m_axi_s2mm_awvalid = 0; 
reg    [31:0] R_m_axi_s2mm_awaddr = 0; 
reg     [3:0] R_m_axi_s2mm_awlen = 0;
reg           R_m_axi_s2mm_wvalid = 0;   
reg           R_m_axi_s2mm_wlast = 0;  

assign O_m_axi_s2mm_awvalid = R_m_axi_s2mm_awvalid; 
assign O_m_axi_s2mm_awaddr  = R_m_axi_s2mm_awaddr;  
assign O_m_axi_s2mm_awlen   = R_m_axi_s2mm_awlen;   
assign O_m_axi_s2mm_awsize  = 3'h3; 
assign O_m_axi_s2mm_awburst = 2'h1; 
assign O_m_axi_s2mm_awprot  = 3'h0;   
assign O_m_axi_s2mm_awcache = 4'h0; 
assign O_m_axi_s2mm_awlock  = 1'b0; 
assign O_m_axi_s2mm_awqos   = 4'h0; 

assign O_m_axi_s2mm_awuser  = 4'h0; 

assign O_m_axi_s2mm_wvalid = R_m_axi_s2mm_wvalid;   
// assign O_m_axi_s2mm_wdata  = W_dout__0[63:0]; 
// assign O_m_axi_s2mm_wstrb  = W_dout__0[73:66]; 
// 调整字节序 
//assign O_m_axi_s2mm_wdata  = {W_dout__0[7:0],W_dout__0[15:8],W_dout__0[23:16],W_dout__0[31:24],
//                              W_dout__0[39:32],W_dout__0[47:40],W_dout__0[55:48],W_dout__0[63:56]};
//                              
//assign O_m_axi_s2mm_wstrb  = {W_dout__0[66],W_dout__0[67],W_dout__0[68],W_dout__0[69],
//                              W_dout__0[70],W_dout__0[71],W_dout__0[72],W_dout__0[73]};  
// Adjust the sequency of Bytes 
wire [63:0] W_m_axi_s2mm_wdata; 
wire  [7:0] W_m_axi_s2mm_wstrb;
wire        W_m_axi_s2mm_wlast;
assign W_m_axi_s2mm_wdata  = {W_dout__0[63:56],W_dout__0[55:48],W_dout__0[47:40],W_dout__0[39:32],
                              W_dout__0[31:24],W_dout__0[23:16],W_dout__0[15:8],W_dout__0[7:0]};
                              
assign W_m_axi_s2mm_wstrb  = {W_dout__0[73],W_dout__0[72],W_dout__0[71],W_dout__0[70],
                              W_dout__0[69],W_dout__0[68],W_dout__0[67],W_dout__0[66]};  
                                                                                     
assign W_m_axi_s2mm_wlast  = R_m_axi_s2mm_wlast || W_data_valid_0 && W_dout__0[64];  

always @(*)begin 
    case({W_m_axi_s2mm_wlast,R_lst_byte}) // 1000
	    4'h9   : begin O_m_axi_s2mm_wdata <= {56'h0,W_m_axi_s2mm_wdata[63:56]}; O_m_axi_s2mm_wstrb <= {7'h0,W_m_axi_s2mm_wstrb[7]};   end // 1
	    4'ha   : begin O_m_axi_s2mm_wdata <= {48'h0,W_m_axi_s2mm_wdata[63:48]}; O_m_axi_s2mm_wstrb <= {6'h0,W_m_axi_s2mm_wstrb[7:6]}; end // 2
	    4'hb   : begin O_m_axi_s2mm_wdata <= {40'h0,W_m_axi_s2mm_wdata[63:40]}; O_m_axi_s2mm_wstrb <= {5'h0,W_m_axi_s2mm_wstrb[7:5]}; end // 3 
	    4'hc   : begin O_m_axi_s2mm_wdata <= {32'h0,W_m_axi_s2mm_wdata[63:32]}; O_m_axi_s2mm_wstrb <= {4'h0,W_m_axi_s2mm_wstrb[7:4]}; end // 4 
	    4'hd   : begin O_m_axi_s2mm_wdata <= {24'h0,W_m_axi_s2mm_wdata[63:24]}; O_m_axi_s2mm_wstrb <= {3'h0,W_m_axi_s2mm_wstrb[7:3]}; end // 5 
	    4'he   : begin O_m_axi_s2mm_wdata <= {16'h0,W_m_axi_s2mm_wdata[63:16]}; O_m_axi_s2mm_wstrb <= {2'h0,W_m_axi_s2mm_wstrb[7:2]}; end // 6 
	    4'hf   : begin O_m_axi_s2mm_wdata <= { 8'h0,W_m_axi_s2mm_wdata[63:08]}; O_m_axi_s2mm_wstrb <= {1'h0,W_m_axi_s2mm_wstrb[7:1]}; end // 7    
	    default: begin O_m_axi_s2mm_wdata <=  W_m_axi_s2mm_wdata;               O_m_axi_s2mm_wstrb <= W_m_axi_s2mm_wstrb;             end      
    endcase  
    end 
assign O_m_axi_s2mm_wlast  = W_m_axi_s2mm_wlast; 
assign O_m_axi_s2mm_bready = 1'b1; 

always @(posedge I_sys_clk)begin 
    O_s_axis_s2mm_tready <= ~W_prog_full_0;  
    O_s2mm_err	         <= R_write_err; 
    end 
always @(posedge I_ps_clk)begin  
    if (I_m_axi_s2mm_bvalid) begin 
	    R_write_err <= |I_m_axi_s2mm_bresp;  
	    end 
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
		O_m_axis_s2mm_sts_tdata  <= (R_rxd_byte==R_byte_num-1'b1)? 8'h80:8'h10;  
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

// 将输入的断续数据做成流的形式，并判断指令与数据的字节数是否匹配 
// 输入顺序：必须先给指令，然后给数据，若没有指令，只有数据，则该数据丢失;  
reg  [22:0] R_rx_dat_num = 0;  
reg         R_s2mm_cmd_err2 = 0;
always @(posedge I_sys_clk)begin // 位宽转换：将8bit数据流转换为64bit    
    if (I_sys_rst)begin  
	    O_s_axis_s2mm_cmd_tready <= 1'b1; 
        R_rx_ctrl                <= 1'b1; 
        R_beat_num               <= 3'h0; 
        R_rx_ctrl                <= 1'b1;
        R_sop_flag               <= 1'b1; 		
        end 
	else if (~R_rx_ctrl && I_s_axis_s2mm_tvalid && (~W_prog_full_0))begin // 开始数据接收 
	    R_rx_dat_num <= R_rx_dat_num + 1'b1; 
	    if (I_s_axis_s2mm_tlast)begin 
	        R_rx_dat_num    <= 23'h0; 
	        R_s2mm_cmd_err2 <= (R_rx_dat_num != (R_byte_num-1'b1)); 
	        end 		        
	    R_rx_ctrl    <= I_s_axis_s2mm_tlast; 
	    R_8byte_dat  <= {I_s_axis_s2mm_tdata,R_8byte_dat[63:8]}; // 从高byte开始写 
		R_beat_num   <= I_s_axis_s2mm_tlast? 3'h0:R_beat_num + 1'b1; 
		R_8byte_vld  <= &R_beat_num; 
		R_8byte_sop  <= &R_beat_num && R_sop_flag;   
		R_sop_flag   <= &R_beat_num? 1'b0:R_sop_flag; 		
        R_8byte_keep <= I_s_axis_s2mm_tlast? R_Bytenable:8'hFF;   		
		R_8byte_num  <= R_8byte_num - &R_beat_num; 			
        if(R_8byte_num==21'h1)begin // 最后1拍时 
		   R_8byte_num              <= I_s_axis_s2mm_tlast? 21'h0:R_8byte_num;  
		   R_8byte_vld              <= I_s_axis_s2mm_tlast;  
           R_8byte_eop              <= I_s_axis_s2mm_tlast; 	 
           R_8byte_sop              <= I_s_axis_s2mm_tlast && R_sop_flag; 	
           O_s_axis_s2mm_cmd_tready <= 1'b1;   		   
           end 		
        end 	   
    else if(R_rx_ctrl && I_s_axis_s2mm_cmd_tvalid && O_s_axis_s2mm_cmd_tready)begin // 指令解析   
	    R_byte_num               <= I_s_axis_s2mm_cmd_tdata[22:0];  
        R_8byte_num              <= I_s_axis_s2mm_cmd_tdata[22:3] + |I_s_axis_s2mm_cmd_tdata[2:0]; 
        R_8byte_len              <= I_s_axis_s2mm_cmd_tdata[22:3] + |I_s_axis_s2mm_cmd_tdata[2:0];
        R_remain_byte            <= I_s_axis_s2mm_cmd_tdata[2:0]; 		
        R_src_addr               <= I_s_axis_s2mm_cmd_tdata[63:32]; 
        R_tag_val                <= I_s_axis_s2mm_cmd_tdata[67:64];  
        R_rx_ctrl                <= 1'b0;
        R_sop_flag               <= 1'b1;
        O_s_axis_s2mm_cmd_tready <= 1'b0;  		
        end    
    else begin 
        R_8byte_vld     <= 1'b0; 
        R_8byte_sop     <= 1'b0; 
        R_8byte_eop     <= 1'b0; 
        R_s2mm_cmd_err2 <= 1'b0; 
        end      
    end 

always @(posedge I_sys_clk)begin     
    if (~R_rx_ctrl)begin         
	    case(R_remain_byte) 
		    3'h1   : R_Bytenable <= 8'b1000_0000; 
			3'h2   : R_Bytenable <= 8'b1100_0000;
			3'h3   : R_Bytenable <= 8'b1110_0000;
			3'h4   : R_Bytenable <= 8'b1111_0000;
			3'h5   : R_Bytenable <= 8'b1111_1000;
			3'h6   : R_Bytenable <= 8'b1111_1100;
			3'h7   : R_Bytenable <= 8'b1111_1110;
			default: R_Bytenable <= 8'b1111_1111; 
		endcase 
	    end 
    end 

// 指令检测：
reg         R_s2mm_cmd_err0 = 0; 
reg         R_s2mm_cmd_err1 = 0;  
always @(posedge I_sys_clk)begin 
    R_s2mm_cmd_err0 <= 1'b0; 
    R_s2mm_cmd_err1 <= 1'b0; 
    if (R_rx_ctrl && I_s_axis_s2mm_tvalid)begin // 在指令接收阶段，收到数据  
        R_s2mm_cmd_err0 <= 1'b1; 
        end 
    if (~R_rx_ctrl && I_s_axis_s2mm_cmd_tvalid)begin // 在数据接收阶段，收到指令 
        R_s2mm_cmd_err1 <= 1'b1; 
        end     
    end  
always @(posedge I_sys_clk)begin  
    R_wr_en_0 <= 1'b0; 
    if (R_8byte_vld && R_8byte_sop)begin 
        R_wr_en_0 <= 1'b1;
        R_din___0 <= {R_tag_val,R_src_addr,R_8byte_len,R_8byte_keep,1'b1,R_8byte_eop,R_8byte_dat}; // 4+32+21+8+1+1+64=131
        end 
    else if (R_8byte_vld)begin 
        R_wr_en_0 <= 1'b1;
        // R_din___0 <={66'h0,R_8byte_eop,R_8byte_dat}; 
        R_din___0 <={57'h0,R_8byte_keep,1'b0,R_8byte_eop,R_8byte_dat}; // 57+8+1+1+64
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
   .WRITE_DATA_WIDTH    (131       ), // DECIMAL  
   .READ_DATA_WIDTH     (131       ), // DECIMAL 
   .FIFO_READ_LATENCY   (0         ), // DECIMAL 
   .FULL_RESET_VALUE    (0         ), // DECIMAL 
   .SIM_ASSERT_CHK      (0         ), // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
   .WAKEUP_TIME         (0         ), // DECIMAL
   .RELATED_CLOCKS      (0         ), // DECIMAL 
   .WR_DATA_COUNT_WIDTH (10        ), // DECIMAL
   .RD_DATA_COUNT_WIDTH (10        ), // DECIMAL
   .CDC_SYNC_STAGES     (2         )  // DECIMAL     
) xpm_fifo_async_inst0 (     
    .wr_clk        (I_sys_clk              ), 
    .rst           (I_sys_rst              ),
    .rd_clk        (I_ps_clk               ),   
    .wr_en         (R_wr_en_0              ),   
    .din           (R_din___0              ), // [130:127]:Tag; [126:95]:SADDR; [94:74]:len; [73:66]:KEEP; [65]:SOP; [64]:EOP; [63:0]:data      
    .rd_en         (W_rd_en_0 || R_rd_en_0 ),  
    .data_valid    (W_data_valid_0         ),  
    .dout          (W_dout__0              ), 
    .prog_full     (W_prog_full_0          ), 
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
   
assign W_rd_en_0 = I_m_axi_s2mm_wready && R_m_axi_s2mm_wvalid && W_data_valid_0; 
always @(posedge I_ps_clk)begin  
    if (I_ps_rst)begin 
        R_m_axi_s2mm_wvalid  <= 1'b0; 
        R_m_axi_s2mm_wlast   <= 1'b0; 
        R_m_axi_s2mm_awvalid <= 1'b0;  
		R_m_axi_s2mm_awlen   <= 4'h0;
        R_row_num            <= 21'h0; 		
		R_remain_row         <= 21'h0; 
		R_rd_en_0            <= 1'b0; 
        end 
	else if(R_row_num==4'h1)begin // 此时已经发送完成单次突发操作 ==> 此处存在两种情况: 1)突发长度=1时; 2)突发长度>1时   
	    if (R_m_axi_s2mm_awvalid)begin 
            R_m_axi_s2mm_awvalid <= I_m_axi_s2mm_awready? 1'b0:1'b1;
            R_m_axi_s2mm_wvalid  <= I_m_axi_s2mm_awready? 1'b1:1'b0;  		 
            end 
		else begin // 突发长度>1时 
		    R_m_axi_s2mm_wvalid <= I_m_axi_s2mm_wready? 1'b0:1'b1;
		    R_m_axi_s2mm_wlast  <= I_m_axi_s2mm_wready? 1'b0:1'b1; 
			R_row_num           <= I_m_axi_s2mm_wready? (R_row_num-1'b1):R_row_num;
            end 		
        end 	
    else if (|R_row_num)begin   
        if (~R_m_axi_s2mm_awvalid)begin // 写数据  		    
			R_row_num          <= I_m_axi_s2mm_wready?   (R_row_num-1'b1):R_row_num;
			R_m_axi_s2mm_wlast <= I_m_axi_s2mm_wready && (R_row_num==4'h2);     			 
            end     
	    else if (I_m_axi_s2mm_awready)begin 
		    R_m_axi_s2mm_awvalid <= 1'b0; // 写地址完成   
		    R_m_axi_s2mm_wvalid  <= 1'b1; 
		    R_lst_byte           <= R_remain_byte; // 25-05-20：锁存指令解析出的最后1拍有效字节数   			
		    end 
        end 
    else if(|R_remain_row)begin 
        R_m_axi_s2mm_awvalid <= 1'b1; 
        R_m_axi_s2mm_awaddr  <= R_m_axi_s2mm_awaddr + {R_m_axi_s2mm_awlen,3'b000} + 4'h8;    
        R_m_axi_s2mm_awlen   <= (R_remain_row>5'h10)? 4'hF  : R_remain_row-1'b1; 
	    R_row_num            <= (R_remain_row>5'h10)? 5'h10 : R_remain_row; 
        R_remain_row         <= (R_remain_row>5'h10)? (R_remain_row-5'h10) : 21'h0;  	   
        end     	
    else if(W_data_valid_0 && (W_rd_data_count0 >= W_dout__0[94:74]))begin 
        if (W_dout__0[65])begin               
            R_rd_en_0            <= 1'b0; 
            R_m_axi_s2mm_awvalid <= 1'b1; 
            R_m_axi_s2mm_awaddr  <= W_dout__0[126:95]; 
            R_m_axi_s2mm_awlen   <= (W_dout__0[94:74]>5'h10)? 4'hF:W_dout__0[94:74]-1'b1;
            R_row_num            <= (W_dout__0[94:74]>5'h10)? 5'h10:W_dout__0[94:74];  
            R_remain_row         <= (W_dout__0[94:74]>5'h10)? (W_dout__0[94:74]-5'h10):21'h0;  
            end  
        else if(R_rd_en_0)begin 
            R_rd_en_0 <= 1'b0; 
            end 
        else begin 
            R_rd_en_0 <= 1'b1; 
            end    
        end 
    else begin 
        R_rd_en_0 <= 1'b0;
        end       
    end        

endmodule