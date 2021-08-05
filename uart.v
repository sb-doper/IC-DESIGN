module uart(
	input			clk			,
	input 		rst_n			,
	input 		uart_rx		,
	input [1:0]	bps_set		,
	input			send_en		,
	input [7:0]	data_out		,//要传输的数据
	output 		uart_tx		,
	output  		tx_done		,
	output   	tx_state		,
	output[7:0]	rs232_rx		,//已接收的数据
	output		rx_done		,
	output		rx_state
);

//=======================
//调用uart_rec模块
	uart_rec m2(
		.clk		(clk)		,		
		.rst_n	(rst_n)	,
		.rs232_rx(rs232_rx),
		.bps_set	(bps_set),
		.data_in	(uart_rx),
		.rx_done	(rx_done),
		.rx_state(rx_state)			
);
//=======================
//调用uart_send模块
	uart_send m3(
		.clk		(clk)			,		
		.rst_n	(rst_n)		,
		.data_out(data_out)	,
		.bps_set	(bps_set)	,
		.send_en	(send_en)	,
		.tx_done	(tx_done)	,
		.tx_state(tx_state)	,
		.rs232_tx(uart_tx)	
);
endmodule