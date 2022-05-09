//MILESTONE1 UNIT

`timescale 1ns/100ps

`ifndef DISABLE_DEFAULT_NET
`default_nettype none
`endif

`include "define_state.h"
module milestone1(
		input logic Clock,
		input logic Resetn,
		input logic start,
		input logic [15:0] SRAM_read_data,
		output logic [15:0] SRAM_write_data,
		output logic [17:0] SRAM_address,
		output logic SRAM_we_n,
		output logic done
		
);
// milestone 1 states
M1_state_type M1_state;
// offset parameters
parameter u_offset = 18'd38400,
		v_offset = 18'd57600;

logic [7:0] y;
logic [7:0] u[5:0];
logic [7:0] v[5:0];
logic [7:0] y_buf;
logic [7:0] u_buf;
logic [7:0] v_buf;

logic signed[31:0] u_reg; // used for multiplication
logic signed[31:0] v_reg;

logic [31:0] R;
logic [31:0] G;
logic [31:0] B;
// registers to store values from clipping
logic [7:0] R_out;
logic [7:0] G_out;
logic [7:0] B_out;
logic [7:0] B_buf;

// registers used for multiplication
logic signed[31:0] multi1;
logic signed[31:0] multi2; 
logic signed[31:0] coeff1;
logic signed[31:0] op1; 
logic signed[31:0] coeff2;
logic signed[31:0] op2; 

// counters to count the address
logic [17:0] y_counter;
logic [17:0] data_counter;
logic [17:0] rgb_counter;
logic [17:0] row_counter;

// used to check whether it needs to read from u and v
logic flag;


always @(posedge Clock or negedge Resetn) begin
	if (~Resetn) begin
		
		SRAM_write_data <= 16'd0;
		SRAM_address <= 18'd0;
		SRAM_we_n <= 1'd1;
		done <= 1'd0;
		
		y <= 8'd0;
		u[0] <= 8'd0;
		u[1] <= 8'd0;
		u[2] <= 8'd0;
		u[3] <= 8'd0;
		u[4] <= 8'd0;
		u[5] <= 8'd0;
		
		
		v[0] <= 8'd0;
		v[1] <= 8'd0;
		v[2] <= 8'd0;
		v[3] <= 8'd0;
		v[4] <= 8'd0;
		v[5] <= 8'd0;
		
		y_buf <= 8'd0;
		u_buf <= 8'd0;
		v_buf <= 8'd0;
		R <= 32'd0;
		G <= 32'd0;
		B <= 32'd0;
		B_buf <= 8'd0;
		u_reg <= 32'b0;
		v_reg <= 32'b0;
		
		coeff1 <= 32'd0;
		op1 <= 32'd0;
		coeff2 <= 32'd0;
		op2 <= 32'd0;
		
		y_counter <= 18'd0;
		data_counter <= 18'd0;
		row_counter <= 18'd0;
		rgb_counter <= 18'd146944;		
		flag = 1'b0;

	
		M1_state <= IDLE;
	end
	else begin
		case(M1_state)
////////////////////////////IDLE state////////////////////////////////////////
		IDLE: begin
			//initial parameters
			y_counter <= 18'd0;
			data_counter <= 18'd0;
			row_counter <= 18'd0;
			rgb_counter <= 18'd146944; //RGB0 address
			SRAM_address <= 18'd0;
			SRAM_we_n <= 1'd1;
			done <= 1'd0;
			flag = 1'b0;
			u_reg <= 32'b0;
			v_reg <= 32'b0;
			
			//check start
			if(start) begin
				M1_state <= LI_0;
			end
		end
//////////////////////////Lead In///////////////////////////////////////////////
		LI_0: begin
			//read v0v1
			SRAM_address <= data_counter + v_offset;
			SRAM_we_n <= 1'b1;
			flag = 1'b0;
			
			M1_state <= LI_1;
		end
		LI_1: begin
			//read u0u1
			SRAM_address <= data_counter + u_offset;
			
			M1_state <= LI_2;
		end
		LI_2: begin
			//read y0y1
			SRAM_address <= y_counter;
			data_counter <= data_counter + 18'b1;
			y_counter <= y_counter + 18'd1;
		
			M1_state <= LI_3;
		end
		LI_3: begin
			//read v2v3
			SRAM_address <= data_counter + v_offset;
		
		
			//put v0v1
			v[0] <= SRAM_read_data[15:8]; //v0
			v[1] <= SRAM_read_data[15:8];
			v[2] <= SRAM_read_data[15:8];
			v[3] <= SRAM_read_data[7:0];  //v1
			v_reg <= {24'd0, SRAM_read_data[15:8]};
			
			M1_state <= LI_4;
		end
		LI_4: begin
			//read u2u3
			SRAM_address <= data_counter + u_offset;
			data_counter <= data_counter + 18'd1;
			
			//put u0u1
			u[0] <= SRAM_read_data[15:8]; //u0
			u[1] <= SRAM_read_data[15:8];
			u[2] <= SRAM_read_data[15:8];
			u[3] <= SRAM_read_data[7:0];  //u1
			u_reg <= {24'd0, SRAM_read_data[15:8]};
			
			//ERV and EGV
			coeff1 <= 32'd104595;
			op1 <= v_reg - 32'd128;
			coeff2 <= 32'd53281;
			op2 <= v_reg - 32'd128;
			
			M1_state <= LI_5;
		end
		LI_5: begin
			//put y0y1
			y <= SRAM_read_data[15:8]; //y0
			y_buf <= SRAM_read_data[7:0]; //y1
			
			//EY and EGU
			coeff1 <= 32'd76284;
			op1 <= {24'd0, SRAM_read_data[15:8]}  - 32'd16; //y0-16
			coeff2 <= 32'd25624;
			op2 <= u_reg - 32'd128;
			
			//accumulate
			R <= multi1; //r=104595*v
			G <= 32'd0 - multi2; //g=-53281v
			
			M1_state <= LI_6;
		end
		LI_6: begin
			//accmulate
			R <= R + multi1; //r=104595*v+76284y
			G <= G + multi1 - multi2; //g=-53281v+76284y-25624u
			B <= multi1; //b=76284y
			
			//EBU and v[j-1]
			coeff1 <= 32'd132251;
			op1 <= u_reg - 32'd128;
			coeff2 <= 32'd159;
			op2 <= v[2] + v[3];
			
			//put v4v6
			v[4] <= SRAM_read_data[15:8]; //v2
			v[5] <= SRAM_read_data[7:0]; //v3
			
			M1_state <= LI_7;
		end
		LI_7: begin
			//initialize next write, write R0G0
			SRAM_we_n <= 1'b0;
			SRAM_write_data <= {R_out,G_out}; //R0G0
			SRAM_address <= rgb_counter;
			rgb_counter <= rgb_counter + 18'd1;
			
			//put u2u3
			u[4] <= SRAM_read_data[15:8]; //u2
			u[5] <= SRAM_read_data[7:0]; //u3
			
			//accmulate
			B <= B + multi1;//b=76284y+132251u
			v_reg <= multi2;
			
			//v[j-3] and v[j-5]
			coeff1 <= 32'd52;
			op1 <= v[1] + v[4]; 
			coeff2 <= 32'd21;
			op2 <= v[0] + v[5];
			
			
			
			M1_state <= CC_0;
		end
///////////////////////////Common Case/////////////////////////////////
		CC_0: begin
			// read y2y3
			SRAM_we_n <= 1'b1;
			SRAM_address <= y_counter; //y2y3
			y_counter <= y_counter + 18'd1;
		
			// accumulate
			v_reg <= v_reg - multi1 + multi2 + 32'd128;
		
			// u[j-1] and u[j-3]
			coeff1 <= 32'd159;
			op1 <= u[2] + u[3];
			coeff2 <= 32'd52;
			op2 <= u[1] + u[4];
			
			//store B0
			B_buf <= B_out;
			
			
			M1_state <= CC_1;	
		end
		CC_1: begin
			// read v4v5
			SRAM_address <= data_counter + v_offset;
			
			//accumulate
			u_reg <= multi1 - multi2 + 32'd128;
			v_reg <= v_reg >>> 8; // 1/256
			
			//OY and u[j-5]
			coeff1 <= 32'd76284;
			op1 <= {24'd0, y_buf} - 32'd16;
			coeff2 <= 32'd21;
			op2 <= u[0] + u[5];
			
			
			
			M1_state <= CC_2;	
		end
		CC_2: begin
			// read u4u5
			SRAM_address <= data_counter + u_offset;
			// increment every 16 CCs
			if(!flag && (y_counter - row_counter < 18'd157)) begin
				data_counter <= data_counter + 18'd1;
			end
			
			//accumulate
			R <= multi1; //76204*y1
			G <= multi1; //76204*y1
			B <= multi1; //76204*y1
			u_reg <= (u_reg + multi2) >>> 8; // 1/256
			
			//ORV and OGV
			coeff1 <= 32'd104595;
			op1 <= v_reg - 32'd128;
			coeff2 <= 32'd53281;
			op2 <= v_reg - 32'd128;
			
			M1_state <= CC_3;		
		end
		CC_3: begin
			// put y2y3
			y <= SRAM_read_data[15:8]; //y2
			y_buf <= SRAM_read_data[7:0]; //y3
			
			//accumulate
			R <= R + multi1; //76204*y1+104595*v'1
			G <= G - multi2; //76204*y1-53281*v'1
			
			//ORU and OGU
			coeff1 <= 32'd25624;
			op1 <= u_reg - 32'd128;
			coeff2 <= 32'd132251;
			op2 <= u_reg - 32'd128;
			
			
			M1_state <= CC_4;		
		end
		CC_4: begin
			//write B0R1
			SRAM_address <= rgb_counter;
			rgb_counter <= rgb_counter + 18'd1;
			SRAM_we_n <= 1'b0;
			SRAM_write_data <= {B_buf,R_out};
			
			//accmulate
			G <= G - multi1; //76204*y1-53281*v'1-25624*u'1
			B <= B + multi2; //76204*y1+132251*u'1
		
			//shift v
			v[0] <= v[1];
			v[1] <= v[2];
			v[2] <= v[3];
			v[3] <= v[4];
			v[4] <= v[5];
			v_reg <= v[3]; // v'2 = v1
			
			// increment every 16 CCs and the last v is set to v159
			if(!flag && (y_counter - row_counter < 18'd157)) begin
				v[5] <= SRAM_read_data[15:8];//v4
				v_buf <= SRAM_read_data[7:0];//v5
			end else begin
				v[5] <= v_buf;//v5
			end
			M1_state <= CC_5;
			
			
		end
		CC_5: begin
			//ERV and EGV
			coeff1 <= 32'd104595;
			op1 <= v_reg - 32'd128;
			coeff2 <= 32'd53281;
			op2 <= v_reg - 32'd128;
			
			// write G1B1
			SRAM_address <= rgb_counter;
			rgb_counter <= rgb_counter +18'd1;
			SRAM_write_data <= {G_out,B_out};
			
			//shift u
			u[0] <= u[1];
			u[1] <= u[2];
			u[2] <= u[3];
			u[3] <= u[4];
			u[4] <= u[5];
			u_reg <= u[3]; // u'2 = u1
			
			// increment every 16 CCs and the last v is set to u159
			if(!flag && (y_counter - row_counter < 18'd157)) begin
				u[5] <= SRAM_read_data[15:8];//u8
				u_buf <= SRAM_read_data[7:0]; //u10
			end else begin
				u[5] <= u_buf; //u5
			end
			
			
			
			M1_state <= CC_6;
		end
		CC_6: begin
			SRAM_we_n <= 1'b1;
			//EY and EGU
			coeff1 <= 32'd76284;
			op1 <= {24'd0, y} - 32'd16; //y0-16
			coeff2 <= 32'd25624;
			op2 <= u_reg - 32'd128;
			
			R <= multi1; //r=104595*v
			G <= 32'd0 - multi2; //g=-53281v
			
			M1_state <= CC_7;
		end
		CC_7: begin		
			//accmulate
			R <= R + multi1; //r=104595*v+76284y
			G <= G + multi1 - multi2; //g=-53281v+76284y-25624u
			B <= multi1; //b=76284y
			
			//EBU and v[j-1]
			coeff1 <= 32'd132251;
			op1 <= u_reg - 32'd128;
			coeff2 <= 32'd159;
			op2 <= v[2] + v[3];
			
			
			
			M1_state <= CC_8;
		end
		CC_8: begin
			//accmulate
			B <= B + multi1;//b=76284y+132251u
			v_reg <= multi2;
			
			//v[j-3] and v[j-5]
			coeff1 <= 32'd52;
			op1 <= v[1] + v[4]; 
			coeff2 <= 32'd21;
			op2 <= v[0] + v[5];
			
			// initialize next write
			SRAM_we_n <= 1'b0;
			SRAM_write_data <= {R_out,G_out}; // R318G318
			SRAM_address <= rgb_counter;
			rgb_counter <= rgb_counter + 18'd1;
			
			// switch flag
			flag <= ~flag ;
			if(y_counter - row_counter < 18'd160) begin
				M1_state <= CC_0;
			end
			else begin
				row_counter <= row_counter + 18'd160;
				M1_state <= LO_0;//go into the lead out part
			end
		end
///////////////////////////End of each row ////////////////////////////
///////////////////////////////Lead Out////////////////////////////////
		LO_0: begin
			SRAM_we_n <= 1'b1;
			// accumulate
			v_reg <= v_reg - multi1 + multi2 + 32'd128;
		
			// u[j-1] and u[j-3]
			coeff1 <= 32'd159;
			op1 <= u[2] + u[3];
			coeff2 <= 32'd52;
			op2 <= u[1] + u[4];
			
			//store B318
			B_buf <= B_out; 
			
			
			M1_state <= LO_1;
		end
		LO_1: begin
			//accumulate
			u_reg <= multi1 - multi2 + 32'd128;
			v_reg <= v_reg >>> 8; // 1/256
			
			//OY and u[j-5]
			coeff1 <= 32'd76284;
			op1 <= {24'd0, y_buf} - 32'd16;
			coeff2 <= 32'd21;
			op2 <= u[0] + u[5];
			
			M1_state <= LO_2;
		end
		LO_2: begin
			//accumulate
			R <= multi1; //76204*y1
			G <= multi1; //76204*y1
			B <= multi1; //76204*y1
			u_reg <= (u_reg + multi2) >>> 8; // 1/256
			
			//ORV and OGV
			coeff1 <= 32'd104595;
			op1 <= v_reg - 32'd128;
			coeff2 <= 32'd53281;
			op2 <= v_reg - 32'd128;
			
			
			M1_state <= LO_3;
		end
		LO_3: begin
			//accumulate
			R <= R + multi1; //76204*y1+104595*v'1
			G <= G - multi2; //76204*y1-53281*v'1
			
			//ORU and OGU
			coeff1 <= 32'd25624;
			op1 <= u_reg - 32'd128;
			coeff2 <= 32'd132251;
			op2 <= u_reg - 32'd128;

			M1_state <= LO_4;
		end
		LO_4: begin
			//accmulate
			G <= G - multi1; //76204*y1-53281*v'1-25624*u'1
			B <= B + multi2; //76204*y1+132251*u'1
			
			// write B318R319
			SRAM_address <= rgb_counter;
			rgb_counter <= rgb_counter + 18'd1;
			SRAM_we_n <= 1'b0;
			SRAM_write_data <= {B_buf,R_out};
			
			M1_state <= LO_5;
		end
		LO_5: begin
			// write G319B319
			SRAM_address <= rgb_counter;
			rgb_counter <= rgb_counter + 18'd1;
			SRAM_write_data <= {G_out,B_out};
			
			if(y_counter < 18'd38400) begin
				M1_state <= LI_0;
			end
			else begin
				M1_state <= IDLE;
				done <= 1'b1;
			end
		end
		default: M1_state <= IDLE;
		endcase
	end
end

// assign the multitiplyer
assign multi1 = coeff1 * op1;
assign multi2 = coeff2 * op2;

// do clipping for RGB
assign R_out = R[31] ? 8'b0 :(|R[30:24]? 8'd255:R[23:16]);
assign G_out = G[31] ? 8'b0 :(|G[30:24]? 8'd255:G[23:16]);
assign B_out = B[31] ? 8'b0 :(|B[30:24]? 8'd255:B[23:16]);
endmodule