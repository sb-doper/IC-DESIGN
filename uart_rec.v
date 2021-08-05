module uart_rec(
					clk	  ,
					rst_n   ,
					data_in ,
					bps_set ,
					rx_done ,
					rx_state,
					rs232_rx
);
	input 		clk	  ;
	input			rst_n	  ;
	input	 		data_in ;
	input [1:0] bps_set ;
	
	output 		rx_done ;
	output 		rx_state ;
	output[7:0] rs232_rx;
//==============================================
//检测接收使能上升沿
	reg 			data_in1;
	reg 			data_in2;
	reg 			data_in3;
	wire 			rec_en_flag;
	assign rec_en_flag = ~data_in2 & data_in3;
	always @(posedge clk or negedge rst_n)
		if(~rst_n)
			{data_in3,data_in2,data_in1} <= 3'b0;
		else 
			{data_in3,data_in2,data_in1} <= {data_in2,data_in1,data_in};
//===============================================
//选择波特率
	localparam [12:0] cnt_9600    =	clk_in/9600-1	,
							cnt_19200   =	clk_in/19200-1	,
							cnt_38400   =	clk_in/38400-1	,
							cnt_921600  =	clk_in/921600-1;
	parameter  clk_in		 =	28'd50_000_000;
	reg 			clk_bps;
	reg [12:0]	cnt_bps;
	reg [12:0]	cnt;//最多为5208；
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
//系统时钟计数器产生
	always@(posedge clk or negedge rst_n)
		begin
			if(!rst_n)
				cnt<=1'b0;
			else if(cnt==cnt_bps)
				cnt<=1'b0;
			else if(rec_flag==1'b0)
				cnt<=1'b0;
			else
				cnt<=cnt+1'b1;
		end
//波特率时钟产生
	always@(posedge clk or negedge rst_n)
		begin
			if(!rst_n)
				clk_bps<=1'b0;
			else if(cnt==1'b1)
				clk_bps<=1'b1;
			else	
				clk_bps<=1'b0;
		end
//波特率时钟计数器
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
//================================================
//状态转移寄存接收使能信号，并且产生状态信号
	localparam idle=1'b0;
	localparam rec_state=1'b1;
	reg		  current_state;
	reg		  next_state;
	reg 		  rec_flag;
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
							if(rec_en_flag==1'b1)
								next_state=rec_state;
							else
								next_state=idle;
						end
					rec_state:
						begin
							if(rx_done)
								next_state=idle;
							else	
								next_state=rec_state;
						end
				endcase
		end
		always@(posedge clk or negedge rst_n)
			begin
				if(~rst_n)
					rec_flag<=1'b0;
				else if(current_state==rec_state)
					rec_flag<=1'b1;
				else
					rec_flag<=rec_flag;
			end
//====输出状态信息=====//
	localparam free_rx=1'b0;
	localparam busy_rx=1'b1;
	reg 		  rx_state;
	always@(posedge clk or negedge rst_n)
		begin
			if(!rst_n)
				rx_state <= free_rx;
			else 
				case(current_state)
					idle:
						rx_state <= free_rx;
					rec_state:
						rx_state <= busy_rx;
				endcase
		end
//===================================================
//在波特率时钟计数器的指令下接收数据以及奇偶校验位
	reg [8:0] rs232_rx_reg;
	always @(posedge clk or negedge rst_n)
		begin
			if(~rst_n)
				begin
					rs232_rx_reg <= 9'b0;
				end
			else if(rec_flag)
				if(cnt == cnt_bps/2)
					begin
						case(clk_bps_cnt)
							4'd1:rs232_rx_reg[0] <= data_in2;
							4'd2:rs232_rx_reg[1] <= data_in2;
							4'd3:rs232_rx_reg[2] <= data_in2;
							4'd4:rs232_rx_reg[3] <= data_in2;
							4'd5:rs232_rx_reg[4] <= data_in2;
							4'd6:rs232_rx_reg[5] <= data_in2;
							4'd7:rs232_rx_reg[6] <= data_in2;
							4'd8:rs232_rx_reg[7] <= data_in2;
							4'd9:rs232_rx_reg[8] <= data_in2;//奇偶检验位尚未用到
							default:;//状态机才把状态设为'bx
						endcase
					end
				else rs232_rx_reg <= rs232_rx_reg;
			else rs232_rx_reg <= 9'b0;
		end
//====================================================
//产生done信号以及输出数据
	reg [7:0] rs232_rx;
	reg		 rx_done;
	always@(posedge clk or negedge rst_n)
		begin
			if(~rst_n)
				begin
					rx_done 	<= 1'b0;
					rs232_rx <= 8'b0;
				end
			else if(clk_bps_cnt == 4'd10)
				begin
					rs232_rx <= rs232_rx_reg[7:0];
					rx_done  <= 1'b1;
				end
			else
				begin
					rx_done 	<= rx_done;
					rs232_rx <= rs232_rx;
				end
		end
endmodule			
				
				
				
				
				
				
				
				
				
				
				
				
				