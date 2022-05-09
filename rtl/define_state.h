`ifndef DEFINE_STATE

// for top state - we have more states than needed
typedef enum logic [1:0] {
	S_IDLE,
	S_UART_RX,
	S_M2,
	S_M1
} top_state_type;

typedef enum logic [1:0] {
	S_RXC_IDLE,
	S_RXC_SYNC,
	S_RXC_ASSEMBLE_DATA,
	S_RXC_STOP_BIT
	
} RX_Controller_state_type;

typedef enum logic [2:0] {
	S_US_IDLE,
	S_US_STRIP_FILE_HEADER_1,
	S_US_STRIP_FILE_HEADER_2,
	S_US_START_FIRST_BYTE_RECEIVE,
	S_US_WRITE_FIRST_BYTE,
	S_US_START_SECOND_BYTE_RECEIVE,
	S_US_WRITE_SECOND_BYTE
} UART_SRAM_state_type;

typedef enum logic [3:0] {
	S_VS_WAIT_NEW_PIXEL_ROW,
	S_VS_NEW_PIXEL_ROW_DELAY_1,
	S_VS_NEW_PIXEL_ROW_DELAY_2,
	S_VS_NEW_PIXEL_ROW_DELAY_3,
	S_VS_NEW_PIXEL_ROW_DELAY_4,
	S_VS_NEW_PIXEL_ROW_DELAY_5,
	S_VS_FETCH_PIXEL_DATA_0,
	S_VS_FETCH_PIXEL_DATA_1,
	S_VS_FETCH_PIXEL_DATA_2,
	S_VS_FETCH_PIXEL_DATA_3
} VGA_SRAM_state_type;

typedef enum logic [4:0]{
	IDLE,
	LI_0,
	LI_1,
	LI_2,
	LI_3,
	LI_4,
	LI_5,
	LI_6,
	LI_7,
	CC_0,
	CC_1,
	CC_2,
	CC_3,
	CC_4,
	CC_5,
	CC_6,
	CC_7,
	CC_8,
	LO_0,
	LO_1,
	LO_2,
	LO_3,
	LO_4,
	LO_5

}M1_state_type;

typedef enum logic [6:0] {
	M2_IDLE,
	M2_IDLE_0,
	M2_IDLE_1,
	Fs_LI_0,
	Fs_LO_1,
	Fs_LO_2,
	Fs_LO_3,
	Ct_LI_0,
	Ct_LI_1,
	Ct_CC_0,
	Ct_CC_1,
	Ct_CC_2,
	Ct_CC_3,
	Ct_LO_0,
	Ct_LO_1,
	Ct_LO_2,
	Ct_LO_3,
	Ct_LO_4,
	Ct_LO_5,
	Ct_LO_6,
	Ct_LO_7,
	Cs_Fs_CC_0,
	Cs_Fs_CC_1,
	Cs_Fs_CC_2,
	Cs_Fs_CC_3,
	Cs_Fs_CC_4,
	Cs_Fs_CC_5,
	Ct_Ws_CC_0,
	Ct_Ws_CC_1,
	Ct_Ws_CC_2,
	Ct_Ws_CC_3,
	Ct_Ws_CC_4,
	Ct_Ws_CC_5,
	Ct_Ws_CC_6,
	Ct_Ws_CC_7,
	Ct_Ws_CC_8,
	Ct_Ws_CC_9,
	Ct_Ws_CC_10,
	Ct_Ws_CC_11,
	Cs_LO_0,
	Cs_LO_1,
	Cs_LO_2,
	Cs_LO_3,
	Ws_LO_0,
	Ws_LO_1,
	Ws_LO_2,
	Ws_LO_3,
	Ws_LO_4,
	Ws_LO_5,
	Ws_finish
} M2_state_type;




parameter 
   VIEW_AREA_LEFT = 160,
   VIEW_AREA_RIGHT = 480,
   VIEW_AREA_TOP = 120,
   VIEW_AREA_BOTTOM = 360;

`define DEFINE_STATE 1
`endif