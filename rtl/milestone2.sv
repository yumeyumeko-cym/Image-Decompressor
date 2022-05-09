//MILESTONE2 UNIT

`timescale 1ns/100ps

`ifndef DISABLE_DEFAULT_NET
`default_nettype none
`endif

`include "define_state.h"
module milestone2(
		input logic Clock,
		input logic Resetn,
		input logic start,
		input logic [15:0] SRAM_read_data,
		output logic [15:0] SRAM_write_data,
		output logic [17:0] SRAM_address,
		output logic SRAM_we_n,
		output logic done
		
);

M2_state_type M2_state;

logic [6:0] address_0, address_1, address_2, address_3;
logic [31:0] write_data_b [1:0];
logic write_enable_b [1:0];
logic [31:0] read_data_a [1:0];
logic [31:0] read_data_b [1:0];
// Instantiate RAM0
// Ct

dual_port_RAM0 dual_port_RAM_inst0 (
	.address_a ( address_0 ),
	.address_b ( address_1 ), 
	.clock ( Clock ),
	.data_a ( 32'h00 ),
	.data_b ( write_data_b[0] ),
	.wren_a ( 1'b0 ),
	.wren_b ( write_enable_b[0] ),
	.q_a ( read_data_a[0] ),
	.q_b ( read_data_b[0] )
	);

// Instantiate RAM1
// Cs
dual_port_RAM1 dual_port_RAM_inst1 (
	.address_a ( address_2 ),
	.address_b ( address_3 ), 
	.clock ( Clock ),
	.data_a ( 32'h00 ),
	.data_b ( write_data_b[1] ),
	.wren_a ( 1'b0 ),
	.wren_b ( write_enable_b[1] ),
	.q_a ( read_data_a[1] ),
	.q_b ( read_data_b[1] )
	);

parameter Y_OFFSET = 18'd76800,
		  U_OFFSET = 18'd38400,
		  V_OFFSET = 18'd57600,
		  
		  y_read_offset = 9'd320,
		  uv_read_offset = 9'd160,
		  
		  uv_write_offset = 9'd80, //post_IDCT, UV row = half of Y row
		  y_write_offset = 9'd160,
		  
		  
		  uv_block_col = 6'd19,  //UV block is 20 * 30
		  uv_block_row = 6'd29,
		  y_block_col = 6'd39,   //Y block is 40 * 30
		  y_block_row = 6'd29,
		  

		  y_read_block_offset = 12'd2560,
		  uv_read_block_offset= 12'd1280;


logic [5:0] block_row_index,block_col_index;
logic [17:0] row_address,col_address;
logic [3:0] row_index,col_index;

logic [5:0] max_col_index; // depends on whether uv block or y block

logic signed[31:0] T,Y_0,Y_1;
logic [7:0] Y_out_0,Y_out_1;

logic [1:0] flag_ct;
logic flag_fs,flag_ws;

logic [15:0] Y_prime_reg;

logic signed [31:0] op2;
logic signed [31:0] op1;
logic signed [31:0] op0;
  
logic signed [31:0] C0, C1, C2;
logic signed [31:0] MULTI0, MULTI1, MULTI2;

logic [8:0] read_offset,write_offset;
logic [17:0] memory_offset,seg_offset,block_row_offset,read_block_offset;
logic [1:0] memory_sel; // used to judge y/uv
logic [5:0] coeff0,coeff1,coeff2;
logic [6:0] address_counter;
logic [9:0] w_offset;

assign row_address = (block_row_index * read_block_offset) + row_index * read_offset; // read_block_offset is chosen by y/uv
assign col_address = (block_col_index << 3) + col_index; // the nth block * 8 + the column index in that block

// clipping
assign Y_out_0 = (Y_0[31]) ? 8'd0 : (|Y_0[30:24]) ? 8'd255 : Y_0[23:16];
assign Y_out_1 = (Y_1[31]) ? 8'd0 : (|Y_1[30:24]) ? 8'd255 : Y_1[23:16];

assign read_block_offset = (memory_sel == 2'd0)? y_read_block_offset : uv_read_block_offset;
assign max_col_index = (memory_sel == 2'd0) ? y_block_col : uv_block_col;
assign memory_offset = (memory_sel == 2'd0) ? Y_OFFSET : (memory_sel == 2'd1) ? (Y_OFFSET + (U_OFFSET << 1)) : (Y_OFFSET + (V_OFFSET<<1));
assign seg_offset = (memory_sel == 2'd0) ? 18'd0 : (memory_sel == 2'd1) ?U_OFFSET : V_OFFSET;
assign write_offset = (memory_sel == 2'd0) ? y_write_offset : uv_write_offset;
assign read_offset = (memory_sel == 2'd0) ? y_read_offset : uv_read_offset;
assign block_row_offset = (memory_sel == 2'd0) ? 18'd1280 : 18'd640;

always_ff @ (posedge Clock or negedge Resetn) begin
	if (Resetn == 1'b0) begin	
		M2_state <= M2_IDLE;	
		write_enable_b[0] <= 1'b1;
		write_enable_b[1] <= 1'b1;
		write_data_b[0] <= 32'd0;
		write_data_b[1] <= 32'd0;
		address_0 <= 7'd0;
		address_1 <= 7'd0;
		address_2 <= 7'd0;
		address_3 <= 7'd0;
		address_counter <= 7'd0;
		
		SRAM_we_n <= 1'b1;
		SRAM_address <= Y_OFFSET;
		
		block_col_index <= 6'd0;
		block_row_index <= 6'd0;
		row_index <= 4'd0;
		col_index <= 4'd0;
	
		memory_sel <= 2'd0;
		
		coeff0 <= 6'd0;
		coeff1 <= 6'd0;
		
		flag_fs <= 1'b0;
		flag_ct <= 2'b0;
		flag_ws <= 1'b0;
		Y_0 <= 32'd0;
		Y_1 <= 32'd0;
		T <= 32'd0;
		Y_prime_reg <= 16'd0;
		
		done <= 1'b0;
	end else begin
		case (M2_state)
		M2_IDLE: begin			
				if (start) begin
				SRAM_address <= memory_offset + row_address + col_address; //76800+0+0
				col_index <= col_index + 4'd1; //1
				M2_state <= M2_IDLE_0;
			end
		end
		M2_IDLE_0: begin
			//76800 out
			SRAM_address <= memory_offset + row_address + col_address; //76800+0+1
			col_index <= col_index + 4'd1; //2
			M2_state <= M2_IDLE_1;
		end
		
		M2_IDLE_1:begin
			//76801 out
			SRAM_address <= memory_offset + row_address + col_address; //76801+0+1
			col_index <= col_index + 4'd1; //3
			
			address_1 <= 7'd0;	
			M2_state <= Fs_LI_0;	
		end
		Fs_LI_0:begin
			if (col_index == 4'd7) begin 
			    if (row_index == 4'd7) begin // go into a new block
			    	M2_state <= Fs_LO_1; 
					row_index <= 4'd0; //initiate row_index to 0
					col_index <= 4'd0; //initiate col_index to 0
					SRAM_address <= memory_offset + row_address + col_address;
					Y_prime_reg <= SRAM_read_data;
					address_1 <= address_1 + 7'd1;
					write_enable_b[0] <= 1'b0;
					flag_fs <= ~flag_fs;
					
				 //to another row
			    end else begin 
					SRAM_address <= memory_offset + row_address + col_address;
					
					Y_prime_reg <= SRAM_read_data;
					write_enable_b[0] <= 1'b0;
					//write Y into DPRAM0
					address_1 <= address_1 + 7'd1;
					flag_fs <= ~flag_fs;
					
					//initiate a new row
					row_index <= row_index + 4'd1;
					col_index <= 4'd0;
				end
			end else begin 
				// move to the next column
				SRAM_address <= memory_offset + row_address + col_address;
				if (flag_fs)begin
					write_data_b[0] <= {Y_prime_reg,SRAM_read_data};
					write_enable_b[0] <= 1'b1;
					flag_fs <= ~flag_fs;
					
				end else begin // stay at the same line and repeat
					Y_prime_reg <= SRAM_read_data;
					write_enable_b[0] <= 1'b0;
					flag_fs <= ~flag_fs;
					if (SRAM_address != 18'd76802)begin
						//write Y into DPRAM0 
						//increment address except the first write
						address_1 <= address_1 + 7'd1;					
					end
				end
				col_index <= col_index + 4'd1;
			end
		end
		
		
		
		////////////////lead out for fetch s////////////////////
		Fs_LO_1: begin
			write_data_b[0] <= {Y_prime_reg,SRAM_read_data};
			write_enable_b[0] <= 1'b1;
			M2_state <= Fs_LO_2; 
		end
		Fs_LO_2: begin
			//write Y into DPRAM0
			Y_prime_reg <= SRAM_read_data;
			address_1 <= address_1 + 7'd1;
			write_enable_b[0] <= 1'b0;
			M2_state <= Fs_LO_3; 
		end
		Fs_LO_3: begin
			//write last y into DPRAM0
			write_data_b[0] <= {Y_prime_reg,SRAM_read_data};
			write_enable_b[0] <= 1'b1;
			M2_state <= Ct_LI_0; 
		end
		
		
		
		/////////////Lead in for computation///////////////////
      Ct_LI_0: begin
			//initiate address_1,address_0 
			address_1 <= 7'd2;
			address_0 <= address_0 + 7'd1; //1

			//stop writing for next state
			write_enable_b[0] <= 1'b0;			

			M2_state <= Ct_LI_1; 
		end
		
		Ct_LI_1: begin
			address_0 <= address_0 + 7'd1; //2
			
			// compute y0y1
			op0 <= $signed(read_data_a[0][31:16]); //y0
			op1 <= $signed(read_data_a[0][15:0]);	//y1
			coeff0 <= 6'd0;
			coeff1 <= 6'd8;
			
			M2_state <= Ct_CC_0; 
		end
		///////////////////common case//////////////////////
		Ct_CC_0: begin
			address_0 <= address_0 + 7'd1; //3
			T <= MULTI0 + MULTI1;		
			op0 <= $signed(read_data_a[0][31:16]); //y2
			op1 <= $signed(read_data_a[0][15:0]);  //y3
			op2 <= $signed(read_data_b[0][31:16]); //y4
			coeff0 <= coeff0 + 6'd16;
			coeff1 <= coeff1 + 6'd16;
			coeff2 <= coeff0 + 6'd16;
			////write result to DPRAM after 1 CC
			if (flag_ct == 2'b1) begin
				write_data_b[1] <= T;
				write_enable_b[1] <= 1'b1;
			end
			M2_state <= Ct_CC_1;
		end
		
		Ct_CC_1: begin
			if(flag_ct == 2'b0) begin
				flag_ct <= flag_ct + 2'b1;
			end else begin
				address_3 <= address_3 + 7'd1;
			end
			write_enable_b[1] <= 1'b0;		
			T <= T + MULTI0 + MULTI1;
			if (col_index == 4'd7)begin
				address_0 <= address_0 + 7'd1;
			end else begin 
				address_0 <= address_0 - 7'd3;
			end
			op0 <= $signed(read_data_a[0][31:16]); //y6
			op1 <= $signed(read_data_a[0][15:0]);  //y7
			op2 <= $signed(read_data_b[0][31:16]); //y5
			coeff0 <= coeff0 + 6'd16;
         coeff1 <= coeff1 + 6'd16;
			coeff2 <= coeff0 + 6'd16;
			
			M2_state <= Ct_CC_2;
		end	
		
		Ct_CC_2: begin
			address_0 <= address_0 + 7'd1;
			
			T <= T + MULTI0 + MULTI1;
			
			op0 <= $signed(read_data_a[0][31:16]); 
			op1 <= $signed(read_data_a[0][15:0]); 
			coeff0 <= coeff0 + 6'd16;
			coeff1 <= coeff1 + 6'd16;
			
			M2_state <= Ct_CC_3;
		end	
		
		
		Ct_CC_3: begin
			address_0 <= address_0 + 7'd1;		
			T <= (T + MULTI0 + MULTI1) >>> 8;		
			op0 <= $signed(read_data_a[0][31:16]);
			op1 <= $signed(read_data_a[0][15:0]);
			if (col_index == 4'd7) begin
				coeff0 <= 6'd0;
				coeff1 <= 6'd8;
			end else begin
				coeff0 <= coeff0 - 6'd47;
				coeff1 <= coeff1 - 6'd47;
			end			
			if(col_index == 4'd7) begin
				row_index <= row_index + 4'd1;
				col_index <= 4'd0;
			end else begin
				col_index <= col_index + 4'd1;
			end
			
			if (address_0 == 7'd29 && row_index == 4'd7) begin
				M2_state <= Ct_LO_0;
			end else begin
				M2_state <= Ct_CC_0;
			end
		end	
		
		
		///////////////////leadout Ct/////////////////
		Ct_LO_0:begin
			address_0 <= address_0 + 7'd1;
			
			
			T <= MULTI0 + MULTI1;
			
			
			op0 <= $signed(read_data_a[0][31:16]);
			op1 <= $signed(read_data_a[0][15:0]);
			
			coeff0 <= coeff0 + 6'd16;
			coeff1 <= coeff1 + 6'd16;
			
			//T(7,6)
			write_data_b[1] <= T;
			write_enable_b[1] <= 1'b1;
			
			M2_state <= Ct_LO_1;
		end
		
		Ct_LO_1: begin
			
			T <= T + MULTI0 + MULTI1;
			write_enable_b[1] <= 1'b0;
			address_3 <= address_3 + 7'd1;
			
			
			op0 <= $signed(read_data_a[0][31:16]);
			op1 <= $signed(read_data_a[0][15:0]);
			op2 <= $signed(read_data_b[0][31:16]);
			coeff0 <= coeff0 + 6'd16;
			coeff1 <= coeff1 + 6'd16;
			coeff2 <= coeff2 + 6'd16;
			
			M2_state <= Ct_LO_2;
		end
		
		Ct_LO_2: begin
			
			T <= T + MULTI0 + MULTI1 ;
			
			
			op0 <= $signed(read_data_a[0][31:16]);
			op1 <= $signed(read_data_a[0][15:0]);
			op2 <= $signed(read_data_b[0][31:16]);
			coeff0 <= coeff0 + 6'd16;
			coeff1 <= coeff1 + 6'd16;
			coeff2 <= coeff2 + 6'd16;
			// Enable DPRAM write
			M2_state <= Ct_LO_3;
		end	
		
		Ct_LO_3:begin
			
			T <= (T + MULTI0 + MULTI1) >>> 8;
			M2_state <= Ct_LO_4;
		end
		
		Ct_LO_4:begin
			write_data_b[1] <= T; //T(7,7)
			write_enable_b[1] <= 1'b1;
			
			M2_state <= Ct_LO_5;
		end
		
		Ct_LO_5: begin
			write_enable_b[1] <= 1'b0;

			row_index <= 4'd0;
			col_index <= 4'd0;
			flag_ct <= 2'b0;
			
			address_0 <= 7'd0; //write S'
			address_2 <= 7'd0; //T(0,0)
			address_3 <= 7'd8; //T(1,0)
			
			block_col_index <= block_col_index + 6'd1;
			
			M2_state <= Ct_LO_6;
		end
		
		Ct_LO_6: begin
			address_2 <= address_2 + 7'd16; 
			address_3 <= address_3 + 7'd16; 
			SRAM_we_n <= 1'b1;
			M2_state <= Ct_LO_7;
		end
		
		Ct_LO_7: begin
			address_2 <= address_2 + 7'd16; 
			address_3 <= address_3 + 7'd16; 
		
			
			op0 <= read_data_a[1]; //T(0,0)
			op1 <= read_data_b[1]; //T(1,0)
			coeff0 <= 6'd0;
			coeff1 <= 6'd8;
			
			address_counter <= 7'd0;
			M2_state <= Cs_Fs_CC_0;
		end
	
		//////////////Cs and Fs common case ///////////////
		Cs_Fs_CC_0: begin		
			
			address_2 <= address_2 + 7'd16;
			address_3 <= address_3 + 7'd16;		
		
			op0 <= read_data_a[1]; //T(2,0)
			op1 <= read_data_b[1]; //T(3,0)
			op2 <= read_data_b[1]; //T(4,0)
			coeff0 <= coeff0 + 6'd16;
			coeff1 <= coeff1 + 6'd16;
			coeff2 <= coeff0 + 6'd16;
		
			if (col_index[0] == 1'b0) begin
				Y_0 <= MULTI0 + MULTI1;
			end else begin
				Y_1 <= MULTI0 + MULTI1;
			end

			if (col_index == 4'd7 && row_index == 4'd7) begin
				SRAM_address <= memory_offset + row_address + col_address;
			end
			//Update y0y1 to S portion of DPRAM
			if((row_index != 4'd0 || col_index != 4'd0) && col_index[0] == 1'b0) begin
				//write to address 3 Y0Y1
				write_data_b[0] <= {16'd0,Y_out_0,Y_out_1};
				write_enable_b[0] <= 1'b1;
				address_1 <= 7'd64 + address_counter;
			end
			M2_state <= Cs_Fs_CC_1;	
		end
		
		Cs_Fs_CC_1: begin
			
			if (col_index == 4'd7) begin
				if (row_index == 4'd7) begin 
					col_index <= 4'd0;
					row_index <= 4'd0;
					M2_state <= Cs_Fs_CC_4;
				end else begin
					address_2 <= 7'd0; 
					address_3 <= 7'd8; 
					M2_state <= Cs_Fs_CC_2;
				end
			end else begin
				address_2 <= address_2 - 7'd47; 
				address_3 <= address_3 - 7'd47; 
				M2_state <= Cs_Fs_CC_2;
			end
			
			if((row_index != 4'd0 || col_index != 4'd0) && col_index[0] == 1'b0) begin
				address_counter <= address_counter + 7'd1;
			end
		  
	
			op0 <= read_data_a[1]; //T(6,0)
			op1 <= read_data_b[1]; //T(7,0)
			op2 <= read_data_a[1]; //T(5,0)
			
			coeff0 <= coeff0 + 6'd16;
			coeff1 <= coeff1 + 6'd16;
			coeff2 <= coeff2 + 6'd16;
		
			if (col_index[0] == 1'b0) begin
				Y_0 <= Y_0 + MULTI0 + MULTI1;
			end else begin
				Y_1 <= Y_1 + MULTI0 + MULTI1;
			end
			
			write_enable_b[0] <= 1'b0;
		end	
		
		Cs_Fs_CC_2: begin
			address_2 <= address_2 + 7'd16; //T(2,1)
			address_3 <= address_3 + 7'd16; //T(3,1)
			
	
			if (col_index[0] == 1'b0) begin
				Y_0 <= Y_0 + MULTI0 + MULTI1;
			end else begin
				Y_1 <= Y_1 + MULTI0 + MULTI1;
			end
			
		
			op0 <= read_data_a[1];
			op1 <= read_data_b[1];	
			coeff0 <= coeff0 + 6'd16;
			coeff1 <= coeff1 + 6'd16;
			
			if(col_index[0] == 1'b1) begin
				//Register Y' at 76808/76810...
				Y_prime_reg <= SRAM_read_data;
			end else begin
				if((row_index != 4'd0)||(col_index != 1'b0)) begin
					write_data_b[0] <= {Y_prime_reg, SRAM_read_data};
					write_enable_b[0] <= 1'b1;
					if (address_counter != 7'd1)begin
						address_1 <= address_counter-6'd1;
					end else address_1 <= 6'd0;
				end
			end
		M2_state <= Cs_Fs_CC_3;
		end
		
		Cs_Fs_CC_3: begin
			address_2 <= address_2 + 7'd16; //T(4,1)
			address_3 <= address_3 + 7'd16; //T(5,1)
			write_enable_b[0] <= 1'b0;
			

			op0 <= read_data_a[1]; //T(0,0)
			op1 <= read_data_b[1]; //T(0,1)
			if (col_index == 4'd7) begin
				coeff0 <= coeff0 - 6'd47;
				coeff1 <= coeff1 - 6'd47;
			end else begin
				coeff0 <= coeff0 - 6'd48;
				coeff1 <= coeff1 - 6'd48;
			end
			
		
			if (col_index[0] == 1'b0) begin
				Y_0 <= Y_0 + MULTI0 + MULTI1;
			end else begin
				Y_1 <= Y_1 + MULTI0 + MULTI1;
			end
				
			if (col_index == 4'd7) begin
				col_index <= 4'd0;
				row_index <= row_index + 4'd1;
			end else begin
				col_index <= col_index + 4'd1;
			end
			
			//76809 76810
			SRAM_address <= memory_offset + row_address + col_address;			
			M2_state <= Cs_Fs_CC_0;
		end
        ////////////////////////lead out////////////////////////////
		
		
		
		Cs_Fs_CC_4: begin
		
			op0 <= read_data_a[1]; //T(7,6)
			op1 <= read_data_b[1]; //T(7,7)	
			coeff0 <= coeff0 + 6'd16;
			coeff1 <= coeff1 + 6'd16;
			
		
			Y_1 <= Y_1 + MULTI0 + MULTI1;
			
			//row 7 and column 7
			Y_prime_reg <= SRAM_read_data; //79054
			M2_state <= Cs_Fs_CC_5;
		end
		
		Cs_Fs_CC_5: begin
	
			Y_1 <= Y_1 + MULTI0 + MULTI1;
			
			//Ws write operation
			write_data_b[0] <= {Y_prime_reg,SRAM_read_data};
			write_enable_b[0] <= 1'b1;
			address_1 <= address_counter;
			
			address_0 <= 7'd0;
			address_2 <= 7'd0;
			address_3 <= 7'd0;
			
			row_index <= 4'd0;
			col_index <= 4'd0;
			
			M2_state <= Ct_Ws_CC_0;
		end

		//////////////////Ct and Ws coomon case////////////////////
        Ct_Ws_CC_0: begin
			//Ct write operation
			write_data_b[0] <= {16'd0,Y_out_0,Y_out_1};
			address_1 <= address_counter + 7'd64;
			//Read S'
			address_0 <= address_0 + 7'd1; //to 1

			M2_state <= Ct_Ws_CC_1; 
		end
		Ct_Ws_CC_1: begin
			write_enable_b[0] <= 1'b0;
			
			address_1 <= 7'd64;
			address_0 <= address_0 + 7'd1;//to 2
			
		
			op0 <= $signed(read_data_a[0][31:16]); //Y0 Y1
			op1 <= $signed(read_data_a[0][15:0]);
			coeff0 <= 6'd0;
			coeff1 <= 6'd8;
					
			M2_state <= Ct_Ws_CC_2; 
		end
		///////////////////COMMON CASE//////////////////////
		Ct_Ws_CC_2: begin
			address_0 <= address_0 + 7'd1;//3
			
	
			T <= MULTI0 + MULTI1;
			
		
			op0 <= $signed(read_data_a[0][31:16]); //Y2 Y3 Y4
			op1 <= $signed(read_data_a[0][15:0]);
			op2 <= $signed(read_data_b[0][31:16]);
			coeff0 <= coeff0 + 6'd16;
			coeff1 <= coeff1 + 6'd16;
			coeff2 <= coeff0 + 6'd16;
			//write result to DPRAM after two cycle
			if (flag_ct == 2'b1) begin
				write_data_b[1] <= T;
				write_enable_b[1] <= 1'b1;
			end
			M2_state <= Ct_Ws_CC_3;
		end
		Ct_Ws_CC_3: begin
			if(flag_ct == 2'b0) begin
				flag_ct <= flag_ct + 2'b1;
			end else begin
				address_3 <= address_3 + 7'd1;
			end

			T <= T + MULTI0 + MULTI1;
			write_enable_b[1] <= 1'b0;

			if (col_index == 4'd7)begin
				col_index <= 4'd0;
				row_index <= row_index + 4'd1;
				address_0 <= address_0 + 7'd1;
			end else begin 
				col_index <= col_index + 4'd1;
				address_0 <= address_0 - 7'd3;
			end

	
			op0 <= $signed(read_data_a[0][31:16]); //Y5 Y6 Y7
			op1 <= $signed(read_data_a[0][15:0]);
			op2 <= $signed(read_data_b[0][31:16]);
			coeff0 <= coeff0 + 6'd16;
			coeff1 <= coeff1 + 6'd16;
			coeff2 <= coeff0 + 6'd16;
			if (!flag_ws)begin
				//read Y0Y1 and write it to SRAM
				if(memory_sel == 2'd0) begin
					if (block_col_index == 6'd0)begin //block_col_index = 7, row_index - 1
						SRAM_address <= (block_row_index- 6'd1) * block_row_offset + (max_col_index << 2) + (col_index >> 1) + write_offset * row_index + seg_offset;
					end else begin //block_col_index - 1
						SRAM_address <= block_row_index * block_row_offset + ((block_col_index- 6'd1) << 2) + (col_index >> 1) + write_offset * row_index + seg_offset;
					end
				end else begin
					if(block_row_index == 4'd0 && block_col_index == 4'd0) begin
						if (memory_sel == 2'd1)
						//Handling the last Y block
						SRAM_address <= 18'd37276 + (col_index >> 1) + (write_offset << 1) * row_index;
						else 
						//Handling the last U block
						SRAM_address <= 18'd57036 + (col_index >> 1) + write_offset * row_index;
					end else begin	
						if (block_col_index == 6'd0) begin //block_col_index = 7, row_index - 1
							SRAM_address <= (block_row_index - 6'd1)*block_row_offset+(max_col_index << 2) + (col_index >> 1) + write_offset * row_index + seg_offset;
						end else begin //block_col_index - 1
							SRAM_address <= block_row_index * block_row_offset + ((block_col_index- 6'd1) << 2) + (col_index >> 1) + write_offset * row_index + seg_offset;
						end
					end
				end
				SRAM_we_n <= 1'b0;
				SRAM_write_data <= read_data_b[0][15:0];//address_3 output
				flag_ws <= ~flag_ws;
			end else begin 
				flag_ws <= ~flag_ws;
				address_1 <= address_1 + 7'd1;
			end
			
			if (address_0 == 7'd31 && row_index == 4'd7 && col_index == 4'd7) begin
				M2_state <= Ct_Ws_CC_6;
			end else begin
				M2_state <= Ct_Ws_CC_4;
			end
		end
		
		Ct_Ws_CC_4: begin
			address_0 <= address_0 + 7'd1;
			SRAM_we_n <= 1'b1;

			T <= T + MULTI0 + MULTI1;
			

			op0 <= $signed(read_data_a[0][31:16]);
			op1 <= $signed(read_data_a[0][15:0]);
			coeff0 <= coeff0 + 6'd16;
			coeff1 <= coeff1 + 6'd16;
			
			M2_state <= Ct_Ws_CC_5;
		end	
		Ct_Ws_CC_5: begin
			address_0 <= address_0 + 7'd1;
			
	
			T <= (T + MULTI0 + MULTI1) >>> 8;
			
	
			op0 <= $signed(read_data_a[0][31:16]);
			op1 <= $signed(read_data_a[0][15:0]);
			if ((col_index == 4'd0) && (coeff1 == 6'd63))begin
				coeff0 <= 6'd0;
				coeff1 <= 6'd8;
			end else begin
				coeff0 <= coeff0 - 6'd47;
				coeff1 <= coeff1 - 6'd47;
			end
			M2_state <= Ct_Ws_CC_2;
		end	
		//////////////////LEAD OUT of Ct & Ws/////////////////
		Ct_Ws_CC_6: begin
	
			T <= T + MULTI0 + MULTI1;
			

			op0 <= $signed(read_data_a[0][31:16]); //Y0 Y1
			op1 <= $signed(read_data_a[0][15:0]);
			coeff0 <= coeff0 + 6'd16;
			coeff1 <= coeff1 + 6'd16;

			M2_state <= Ct_Ws_CC_7;
		end
		Ct_Ws_CC_7: begin
		
			T <= (T + MULTI0 + MULTI1) >>> 8;
			M2_state <= Ct_Ws_CC_8;
		end
		Ct_Ws_CC_8: begin 
			write_data_b[1] <= T; //T(7,7)
			write_enable_b[1] <= 1'b1;
			M2_state <= Ct_Ws_CC_9;
		end	
		Ct_Ws_CC_9:begin
			write_enable_b[1] <= 1'b0;
			
			SRAM_we_n <= 1'b1;
			
			//Initialize for Cs
			address_2 <= 7'd0; //read T(0,0)
			address_3 <= 7'd8; //read T(1,0)
			row_index <= 4'd0;
			col_index <= 4'd0;
			flag_ct <= 2'b0;
			M2_state <= Ct_Ws_CC_10;
		end
		
		Ct_Ws_CC_10: begin
			address_2 <= address_2 + 7'd16; //read T(2,0)
			address_3 <= address_3 + 7'd16; //read T(3,0)
			M2_state <= Ct_Ws_CC_11;
		end
		
		Ct_Ws_CC_11:begin
			address_2 <= address_2 + 7'd16; //read T(4,0)
			address_3 <= address_3 + 7'd16; //read T(5,0)
			col_index <= col_index + 4'd1;		
			

			op0 <= read_data_a[1]; //T(0,0)
			op1 <= read_data_b[1]; //T(0,1)
			coeff0 <= 6'd0;
			coeff1 <= 6'd8;
			
			//Initialize the DPRAM address for Common Case Cs and Fs 
			if((block_col_index == max_col_index) && (block_row_index == 6'd29) && (memory_sel == 2'd2)) begin
				address_0 <= 7'd64;
				address_1 <= 7'd64;
				row_index <= 4'd0;
				col_index <= 4'd0;
				M2_state <= Cs_LO_0;
			end else begin
				//Return to common case 	
				write_enable_b[1] <= 1'b0;
				row_index <= 4'd0;
				col_index <= 4'd0;
				flag_ct <= 2'b0;
				address_0 <= 7'd0;//write S'
				address_1 <= 7'd0; 
				address_counter <= 7'd0;
				
				if(block_col_index == max_col_index) begin
					if (block_row_index == 6'd29)begin
						memory_sel <= memory_sel + 2'd1;
						block_row_index <= 6'd0;
						block_col_index <= 6'd0;
					end else begin
						block_row_index <= block_row_index + 6'd1;
						block_col_index <= 6'd0;
					end
				end else begin
					block_col_index <= block_col_index + 6'd1;
				end
				M2_state <= Cs_Fs_CC_0; //Line 431
			end
		end
		
		Cs_LO_0: begin
			address_2 <= address_2 + 7'd16; //T(0,6)
			address_3 <= address_3 + 7'd16; //T(0,7)
			
	
			op0 <= read_data_a[1]; //T(2,0)
			op1 <= read_data_b[1]; //T(3,0)
			op2 <= read_data_a[1]; //T(4,0)
			coeff0 <= coeff0 + 6'd16;
			coeff1 <= coeff1 + 6'd16;
			coeff2 <= coeff0 + 6'd16;
			
	
			if(col_index[0] == 1'b0) begin
				Y_0 <= MULTI0 + MULTI1;
			end else begin
				Y_1 <= MULTI0 + MULTI1;
			end
			
			if((row_index != 4'd0 || col_index != 4'd0) && col_index[0] == 1'b0) begin
				write_data_b[0] <= {16'd0,Y_out_0,Y_out_1};
				write_enable_b[0] <= 1'b1;
			end
			M2_state <= Cs_LO_1;
		end
		Cs_LO_1: begin
			if (col_index == 4'd7) begin
				if(row_index == 4'd7) begin
					M2_state <= Ws_LO_0;
					col_index <= 4'd0;
					row_index <= 4'd0;
					w_offset <= 9'd0;
					address_0 <= 7'd64;  //read Ws
				end else begin 
					address_2 <= 7'd0; //T(0,0)
					address_3 <= 7'd8; //T(1,0)
					M2_state <= Cs_LO_2;
				end
			end else begin
				if(col_index == 4'd7) begin
					address_2 <= 7'd0; //T(8,0)
					address_3 <= 7'd8; //T(9,0)
				end else begin
					address_2 <= address_2 - 7'd47; //T(0,0)
					address_3 <= address_3 - 7'd47; //T(1,0)
				end
				M2_state <= Cs_LO_2;
			end
			
			if((row_index != 4'd0 || col_index != 4'd0) && col_index[0] == 1'b0) begin
				address_1 <= address_1 + 7'd1;
			end
			write_enable_b[0] <= 1'b0;
			
	
			op0 <= read_data_a[1]; //T(6,0)
			op1 <= read_data_b[1]; //T(7,0)
			op2 <= read_data_a[1]; //T(5,0)
			coeff0 <= coeff0 + 6'd16;
			coeff1 <= coeff1 + 6'd16;
			
			if(col_index[0] == 1'b0) begin
				Y_0 <= Y_0 + MULTI0 + MULTI1;
			end else begin
				Y_1 <= Y_1 + MULTI0 + MULTI1;
			end
		end
		Cs_LO_2: begin
			address_2 <= address_2 + 7'd16; //T(2,0)
			address_3 <= address_3 + 7'd16; //T(3,0)
			
			op0 <= read_data_a[1];
			op1 <= read_data_b[1];
			if (col_index == 4'd7) begin
				coeff0 <= coeff0 - 6'd47;
				coeff1 <= coeff1 - 6'd47;
			end else begin
				coeff0 <= coeff0 - 6'd48;
				coeff1 <= coeff1 - 6'd48;
			end
			
	
			if(col_index[0] == 1'b0) begin
				Y_0 <= Y_0 + MULTI0 + MULTI1;
			end else begin
				Y_1 <= Y_1 + MULTI0 + MULTI1;
			end
			
			M2_state <= Cs_LO_3;
		end
		Cs_LO_3: begin
			address_2 <= address_2 + 7'd16; //T(0,4)
			address_3 <= address_3 + 7'd16; //T(0,5)
			
	
			op0 <= read_data_a[1];
			op1 <= read_data_b[1];
			coeff0 <= coeff0 + 6'd16;
			coeff1 <= coeff1 + 6'd16;
				

			if(col_index[0] == 1'b0) begin
				Y_0 <= Y_0 + MULTI0 + MULTI1;
			end else begin
				Y_1 <= Y_1 + MULTI0 + MULTI1;
			end
			
			if(col_index == 4'd7) begin
				row_index <= row_index + 4'd1;
				col_index <= 4'd0;
			end else begin
				col_index <= col_index + 4'd1;
			end
			M2_state <= Cs_LO_0;
		end
		Ws_LO_0: begin
			
			op0 <= read_data_a[1];
			op1 <= read_data_b[1];
			coeff0 <= coeff0 + 6'd16;
			coeff1 <= coeff1 + 6'd16;
			

			Y_1 <= Y_1 + MULTI0 + MULTI1;
			
			address_0 <= address_0 + 7'd1;
			
			M2_state <= Ws_LO_1;
		end
		Ws_LO_1: begin
			SRAM_address <= 18'd76236 + col_index;
			SRAM_write_data <= read_data_a[0][15:0];
			col_index <= col_index + 4'd1;
			SRAM_we_n <= 1'b0;
			
			//Update read S address to 66
			address_0 <= address_0 + 7'd1;
			
			
			Y_1 <= Y_1 + MULTI0 + MULTI1; // last y
		
			M2_state <= Ws_LO_2;
		end
		Ws_LO_2: begin
			address_0 <= address_0 + 7'd1;
			
			SRAM_address <= 18'd76236 + col_index;
			SRAM_write_data <= read_data_a[0][15:0];
			col_index <= col_index + 4'd1; //3
			
			
			write_data_b[0] <= {16'd0,Y_out_0,Y_out_1}; //y62 y63
			write_enable_b[0] <= 1'b1;
			
			M2_state <= Ws_LO_3;
		end
		Ws_LO_3: begin
			//read y6y7 and write it to SRAM
			if(row_index == 4'd7 && col_index == 4'd3) begin
				M2_state <= Ws_LO_4;
				row_index <= 4'd0;
				col_index <= 4'd0;
				SRAM_address <= 18'd76236 + col_index + w_offset;
				SRAM_write_data <= read_data_a[0][15:0];
			end else begin
				SRAM_address <= 18'd76236 + col_index + w_offset;
				SRAM_write_data <= read_data_a[0][15:0];
				
				//Update address_2 to read next address
				if (col_index != 4'd2 || row_index != 4'd7) 
				address_0 <= address_0 + 4'd1;
			end
			
			if(col_index == 4'd3) begin
				col_index <= 4'd0;
				w_offset <= w_offset + write_offset;
				row_index <= row_index + 4'd1;
			end else begin
				col_index <= col_index + 4'd1;
			end
			write_enable_b[1] <= 1'b0;
		end
		Ws_LO_4: begin
			SRAM_address <= 18'd76236 + col_index + w_offset;
			SRAM_write_data <= read_data_a[0][15:0];
			SRAM_we_n <= 1'b1;
			done <= 1'b1;
			M2_state <= Ws_LO_5;
		end
		Ws_LO_5:begin
			SRAM_we_n <= 1'b1;
			M2_state <= Ws_finish;
		end
		Ws_finish: begin
			M2_state <= M2_IDLE;
		end
		default: M2_state <= M2_IDLE;
	endcase
	end
end

assign MULTI0 = C0 * op0;
assign MULTI1 = C1 * op1;
assign MULTI2 = C2 * op2;

always_comb begin
	case(coeff0)
	0:   C0 = 32'sd1448;   //C00
	1:   C0 = 32'sd1448;   //C01
	2:   C0 = 32'sd1448;   //C02
	3:   C0 = 32'sd1448;   //C03
	4:   C0 = 32'sd1448;   //C04
	5:   C0 = 32'sd1448;   //C05
	6:   C0 = 32'sd1448;   //C06
	7:   C0 = 32'sd1448;   //C07
	8:   C0 = 32'sd2008;   //C10
	9:   C0 = 32'sd1702;   //C11
	10:  C0 = 32'sd1137;   //C12
	11:  C0 = 32'sd399;    //C13
	12:  C0 = -32'sd399;   //C14
	13:  C0 = -32'sd1137;  //C15
	14:  C0 = -32'sd1702;  //C16
	15:  C0 = -32'sd2008;  //C17
	16:  C0 = 32'sd1892;   //C20
	17:  C0 = 32'sd783;    //C21
	18:  C0 = -32'sd783;   //C22
	19:  C0 = -32'sd1892;  //C23
	20:  C0 = -32'sd1892;  //C24
	21:  C0 = -32'sd783;   //C25
	22:  C0 = 32'sd783;    //C26
	23:  C0 = 32'sd1892;   //C27
	24:  C0 = 32'sd1702;   //C30
	25:  C0 = -32'sd399;   //C31
	26:  C0 = -32'sd2008;  //C32
	27:  C0 = -32'sd1137;  //C33
	28:  C0 = 32'sd1137;   //C34
	29:  C0 = 32'sd2008;   //C35
	30:  C0 = 32'sd399;    //C36
	31:  C0 = -32'sd1702;  //C37
	32:  C0 = 32'sd1448;   //C40
	33:  C0 = -32'sd1448;  //C41
	34:  C0 = -32'sd1448;  //C42
	35:  C0 = 32'sd1448;   //C43
	36:  C0 = 32'sd1448;   //C44
	37:  C0 = -32'sd1448;  //C45
	38:  C0 = -32'sd1448;  //C46
	39:  C0 = 32'sd1448;   //C47
	40:  C0 = 32'sd1137;   //C50
	41:  C0 = -32'sd2008;  //C51
	42:  C0 = 32'sd399;    //C52
	43:  C0 = 32'sd1702;   //C53
	44:  C0 = -32'sd1702;  //C54
	45:  C0 = -32'sd399;   //C55
	46:  C0 = 32'sd2008;   //C56
	47:  C0 = -32'sd1137;  //C57
	48:  C0 = 32'sd783;    //C60
	49:  C0 = -32'sd1892;  //C61
	50:  C0 = 32'sd1892;   //C62
	51:  C0 = -32'sd783;   //C63
	52:  C0 = -32'sd783;   //C64
	53:  C0 = 32'sd1892;   //C65
	54:  C0 = -32'sd1892;  //C66
	55:  C0 = 32'sd783;    //C67
	56:  C0 = 32'sd399;    //C70
   57:  C0 = -32'sd1137;  //C71
   58:  C0 = 32'sd1702;   //C72
   59:  C0 = -32'sd2008;  //C73
   60:  C0 = 32'sd2008;   //C74
   61:  C0 = -32'sd1702;  //C75
   62:  C0 = 32'sd1137;   //C76
   63:  C0 = -32'sd399;   //C77
	endcase
end

always_comb begin
	case(coeff1)
	0:   C1 = 32'sd1448;
	1:   C1 = 32'sd1448;
	2:   C1 = 32'sd1448;
	3:   C1 = 32'sd1448;
	4:   C1 = 32'sd1448;
	5:   C1 = 32'sd1448;
	6:   C1 = 32'sd1448;
	7:   C1 = 32'sd1448;
	8:   C1 = 32'sd2008;
	9:   C1 = 32'sd1702;
	10:  C1 = 32'sd1137;
	11:  C1 = 32'sd399;
	12:  C1 = -32'sd399;
	13:  C1 = -32'sd1137;
	14:  C1 = -32'sd1702;
	15:  C1 = -32'sd2008;
	16:  C1 = 32'sd1892;
	17:  C1 = 32'sd783;
	18:  C1 = -32'sd783;
	19:  C1 = -32'sd1892;
	20:  C1 = -32'sd1892;
	21:  C1 = -32'sd783;
	22:  C1 = 32'sd783;
	23:  C1 = 32'sd1892;
	24:  C1 = 32'sd1702;
	25:  C1 = -32'sd399;
	26:  C1 = -32'sd2008;
	27:  C1 = -32'sd1137;
	28:  C1 = 32'sd1137;
	29:  C1 = 32'sd2008;
	30:  C1 = 32'sd399;
	31:  C1 = -32'sd1702;
	32:  C1 = 32'sd1448;
	33:  C1 = -32'sd1448;
	34:  C1 = -32'sd1448;
	35:  C1 = 32'sd1448;
	36:  C1 = 32'sd1448;
	37:  C1 = -32'sd1448;
	38:  C1 = -32'sd1448;
	39:  C1 = 32'sd1448;
	40:  C1 = 32'sd1137;
	41:  C1 = -32'sd2008;
	42:  C1 = 32'sd399;
	43:  C1 = 32'sd1702;
	44:  C1 = -32'sd1702;
	45:  C1 = -32'sd399;
	46:  C1 = 32'sd2008;
	47:  C1 = -32'sd1137;
	48:  C1 = 32'sd783;
	49:  C1 = -32'sd1892;
	50:  C1 = 32'sd1892;
	51:  C1 = -32'sd783;
	52:  C1 = -32'sd783;
	53:  C1 = 32'sd1892;
	54:  C1 = -32'sd1892;
	55:  C1 = 32'sd783;
	56:  C1 = 32'sd399;
   57:  C1 = -32'sd1137;
   58:  C1 = 32'sd1702;
   59:  C1 = -32'sd2008;
   60:  C1 = 32'sd2008;
   61:  C1 = -32'sd1702;
   62:  C1 = 32'sd1137;
   63:  C1 = -32'sd399;
	endcase	
end

always_comb begin
	case(coeff2)
	0:   C2 = 32'sd1448;
	1:   C2 = 32'sd1448;
	2:   C2 = 32'sd1448;
	3:   C2 = 32'sd1448;
	4:   C2 = 32'sd1448;
	5:   C2 = 32'sd1448;
	6:   C2 = 32'sd1448;
	7:   C2 = 32'sd1448;
	8:   C2 = 32'sd2008;
	9:   C2 = 32'sd1702;
	10:  C2 = 32'sd1137;
	11:  C2 = 32'sd399;
	12:  C2 = -32'sd399;
	13:  C2 = -32'sd1137;
	14:  C2 = -32'sd1702;
	15:  C2 = -32'sd2008;
	16:  C2 = 32'sd1892;
	17:  C2 = 32'sd783;
	18:  C2 = -32'sd783;
	19:  C2 = -32'sd1892;
	20:  C2 = -32'sd1892;
	21:  C2 = -32'sd783;
	22:  C2 = 32'sd783;
	23:  C2 = 32'sd1892;
	24:  C2 = 32'sd1702;
	25:  C2 = -32'sd399;
	26:  C2 = -32'sd2008;
	27:  C2 = -32'sd1137;
	28:  C2 = 32'sd1137;
	29:  C2 = 32'sd2008;
	30:  C2 = 32'sd399;
	31:  C2 = -32'sd1702;
	32:  C2 = 32'sd1448;
	33:  C2 = -32'sd1448;
	34:  C2 = -32'sd1448;
	35:  C2 = 32'sd1448;
	36:  C2 = 32'sd1448;
	37:  C2 = -32'sd1448;
	38:  C2 = -32'sd1448;
	39:  C2 = 32'sd1448;
	40:  C2 = 32'sd1137;
	41:  C2 = -32'sd2008;
	42:  C2 = 32'sd399;
	43:  C2 = 32'sd1702;
	44:  C2 = -32'sd1702;
	45:  C2 = -32'sd399;
	46:  C2 = 32'sd2008;
	47:  C2 = -32'sd1137;
	48:  C2 = 32'sd783;
	49:  C2 = -32'sd1892;
	50:  C2 = 32'sd1892;
	51:  C2 = -32'sd783;
	52:  C2 = -32'sd783;
	53:  C2 = 32'sd1892;
	54:  C2 = -32'sd1892;
	55:  C2 = 32'sd783;
	56:  C2 = 32'sd399;
   57:  C2 = -32'sd1137;
   58:  C2 = 32'sd1702;
   59:  C2 = -32'sd2008;
   60:  C2 = 32'sd2008;
   61:  C2 = -32'sd1702;
   62:  C2 = 32'sd1137;
   63:  C2 = -32'sd399;
	endcase	
end

endmodule
