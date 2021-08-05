//=====================//
//=======uart-send=======//
//===实现uart传输通信==//
//=====================//
`timescale 1ns/1ns
module uart_send(
						clk		,
						rst_n		,
						bps_set	,
						send_en	,
						data_out	,	
						rs232_tx	,
						tx_done	,
						tx_state
);
	input 			clk		;
	input				rst_n		;
	input		[7:0]	data_out	;
	input 			send_en	;
	input 	[1:0]	bps_set	;
	
	output 			rs232_tx	;//串口单bit传输
	output			tx_done	;
	output 			tx_state	;
//========================================
//比特率时钟产生
	localparam cnt_9600   =	clk_in/9600-1,
				  cnt_19200  =	clk_in/19200-1,
				  cnt_38400	 =	clk_in/38400-1,
				  cnt_921600 =	clk_in/921600-1;
	parameter  clk_in		 =	28'd50_000_000;
	reg 			clk_bps;
	reg [12:0]	cnt_bps;
	reg [12:0]	cnt;//最多为5208；
//波特率选择	
	always@(posedge clk or negedge rst_n)
		begin
			if(!rst_n)
				cnt_bps<=1'b0;
			else
				case(bps_set)
					2'b00:cnt_bps	<= cnt_9600;
					2'b01:cnt_bps	<= cnt_19200;
					2'b10:cnt_bps	<= cnt_38400;
					2'b11:cnt_bps	<= cnt_921600;
				endcase
		end
//======计数器产生=====//
	always@(posedge clk or negedge rst_n)
		begin
			if(!rst_n)
				cnt<=1'b0;
			else if(cnt==cnt_bps)
				cnt<=1'b0;
			else if(send_flag==1'b0)
				cnt<=1'b0;
			else
				cnt<=cnt+1'b1;
		end
//=====产生发送标志==//
	always@(posedge clk or negedge rst_n)
		begin
			if(!rst_n)
				clk_bps<=1'b0;
			else if(cnt==1'b1)
				clk_bps<=1'b1;
			else	
				clk_bps<=1'b0;
		end
//====产生比特率时钟的计数器===//
	reg [3:0] clk_bps_cnt;
	always@(posedge clk or negedge rst_n)
		begin
			if(!rst_n)
				clk_bps_cnt<=1'b0;
			else if(clk_bps==1'b1)
				clk_bps_cnt<=clk_bps_cnt+1'b1;
			else
				clk_bps_cnt<=clk_bps_cnt;
		end
//==================================================
//数据寄存器
	reg [7:0] data_out_reg;
	always@(posedge clk or negedge rst_n)
		begin
			if(!rst_n)
				data_out_reg<=7'b0;
			else if(clk_bps==1'b1 & clk_bps_cnt==1'b1)
				data_out_reg<=data_out;
			else
				data_out_reg<=data_out_reg;
		end
//=================================================
//发送使能的上升沿检测//
	reg send_en1;
	reg send_en2;
	wire send_en_flag;
	always@(posedge clk or negedge rst_n)
		if(~rst_n)
			{send_en2,send_en1}<=2'b0;
		else 
			{send_en2,send_en1}<={send_en1,send_en};	
	assign send_en_flag = ~send_en2 & send_en1;
//=================================================		
//将发送信号利用两状态机寄存起来，分送到各模块以达到低功耗
	localparam idle=1'b0;
	localparam send_state=1'b1;
	reg		  current_state;
	reg		  next_state;
	reg 		  send_flag;
	always@(posedge clk or negedge rst_n)
		begin
			if(~rst_n)
				current_state<=idle;
			else	
				current_state<=next_state;
		end
	always@(*)
		begin
			if(~rst_n)
				next_state=idle;
			else	
				case(current_state)
					idle:
						begin
							if(send_en_flag==1'b1)
								next_state=send_state;
							else
								next_state=idle;
						end
					send_state:
						begin
							if(tx_done)
								next_state=idle;
							else	
								next_state=send_state;
						end
				endcase
		end
		always@(posedge clk or negedge rst_n)
			begin
				if(~rst_n)
					send_flag<=1'b0;
				else if(current_state==send_state)
					send_flag<=1'b1;
				else
					send_flag<=send_flag;
			end
//=================================================
//输出状态信息
	localparam free_tx=1'b0;
	localparam busy_tx=1'b1;
	reg 		  tx_state;
	always@(posedge clk or negedge rst_n)
		begin
			if(!rst_n)
				tx_state <= free_tx;
			else 
				case(current_state)
					idle:
						tx_state <= free_tx;
					send_state:
						tx_state <= busy_tx;
				endcase
		end			
//=================================================
//奇偶校验位
	wire even_check;
	reg even_check_1;
	reg even_check_2;
	always@(posedge clk or negedge rst_n)
		begin
			if(!rst_n)
				begin
					even_check_1 <= 1'b0;
					even_check_2 <= 1'b0;
				end
			else if(clk_bps_cnt==4'd9)
				begin
					even_check_1 <= data_out_reg[7]^data_out_reg[6]^data_out_reg[5]^data_out_reg[4];//cyclone IV是四输入的lut；
					even_check_2 <= data_out_reg[3]^data_out_reg[2]^data_out_reg[1]^data_out_reg[0];
				end
			else
				begin
					even_check_1 <= even_check_1;
					even_check_2 <= even_check_2;
				end
		end
	assign even_check=even_check_1^even_check_2;
//=================================================
//传送数据
	reg rs232_tx;
	always@(posedge clk or negedge rst_n)
		begin
			if(~rst_n)
				rs232_tx<=1'b1;
			else 
				case(clk_bps_cnt)
					1'd0:rs232_tx=1'b1;
					1'd1:rs232_tx=1'b0;
					1'd2:rs232_tx=data_out_reg[0];
					1'd3:rs232_tx=data_out_reg[1];
					1'd4:rs232_tx=data_out_reg[2];
					1'd5:rs232_tx=data_out_reg[3];
					1'd6:rs232_tx=data_out_reg[4];
					1'd7:rs232_tx=data_out_reg[5];
					1'd8:rs232_tx=data_out_reg[6];
					1'd9:rs232_tx=data_out_reg[7];
					1'd10:rs232_tx=even_check;
					1'd11:rs232_tx=1'b1;
					default:rs232_tx=1'b1;
				endcase	
		end
//输出完成传输信号
	reg tx_done;
	always@(posedge clk or negedge rst_n)
		begin
			if(~rst_n)
				tx_done<=1'b0;
			else if(clk_bps_cnt==4'd11)
				tx_done<=1'b1;
			else  
				tx_done<=1'b0;
		end
endmodule
	