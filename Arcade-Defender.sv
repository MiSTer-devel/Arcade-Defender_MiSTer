//============================================================================
//  Arcade: Defender
//
//  Port to MiSTer
//  Copyright (C) 2017 Sorgelig
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//============================================================================

module emu
(
	//Master input clock
	input         CLK_50M,

	//Async reset from top-level module.
	//Can be used as initial reset.
	input         RESET,

	//Must be passed to hps_io module
	inout  [43:0] HPS_BUS,

	//Base video clock. Usually equals to CLK_SYS.
	output        CLK_VIDEO,

	//Multiple resolutions are supported using different CE_PIXEL rates.
	//Must be based on CLK_VIDEO
	output        CE_PIXEL,

	//Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
	output  [7:0] VIDEO_ARX,
	output  [7:0] VIDEO_ARY,

	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_DE,    // = ~(VBlank | HBlank)

	output        LED_USER,  // 1 - ON, 0 - OFF.

	// b[1]: 0 - LED status is system status ORed with b[0]
	//       1 - LED status is controled solely by b[0]
	// hint: supply 2'b00 to let the system control the LED.
	output  [1:0] LED_POWER,
	output  [1:0] LED_DISK,

	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,
	output        AUDIO_S, // 1 - signed audio samples, 0 - unsigned
	input         TAPE_IN,

	// SD-SPI
	output        SD_SCK,
	output        SD_MOSI,
	input         SD_MISO,
	output        SD_CS,

	//High latency DDR3 RAM interface
	//Use for non-critical time purposes
	output        DDRAM_CLK,
	input         DDRAM_BUSY,
	output  [7:0] DDRAM_BURSTCNT,
	output [28:0] DDRAM_ADDR,
	input  [63:0] DDRAM_DOUT,
	input         DDRAM_DOUT_READY,
	output        DDRAM_RD,
	output [63:0] DDRAM_DIN,
	output  [7:0] DDRAM_BE,
	output        DDRAM_WE,

	//SDRAM interface with lower latency
	output        SDRAM_CLK,
	output        SDRAM_CKE,
	output [12:0] SDRAM_A,
	output  [1:0] SDRAM_BA,
	inout  [15:0] SDRAM_DQ,
	output        SDRAM_DQML,
	output        SDRAM_DQMH,
	output        SDRAM_nCS,
	output        SDRAM_nCAS,
	output        SDRAM_nRAS,
	output        SDRAM_nWE
);

assign {DDRAM_CLK, DDRAM_BURSTCNT, DDRAM_ADDR, DDRAM_DIN, DDRAM_BE, DDRAM_RD, DDRAM_WE} = 0; 
assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;
assign {SDRAM_DQ, SDRAM_A, SDRAM_BA, SDRAM_CLK, SDRAM_CKE, SDRAM_DQML, SDRAM_DQMH, SDRAM_nWE, SDRAM_nCAS, SDRAM_nRAS, SDRAM_nCS} = 'Z;

assign LED_USER  = 0;
assign LED_DISK  = 0;
assign LED_POWER = 0;

assign VIDEO_ARX = status[1] ? 8'd16 : 8'd4;
assign VIDEO_ARY = status[1] ? 8'd9  : 8'd3; 

`include "build_id.v" 
localparam CONF_STR = {
	"A.DFNDR;;",
	"-;",
	"O1,Aspect ratio,4:3,16:9;",
	"-;",
	"T6,Reset;",
	"J,Turn,Fire,Bomb,HyperSpace,Start 1P,Coin;",
	"V,v1.00.",`BUILD_DATE
};

////////////////////   CLOCKS   ///////////////////

wire clk_sys, clk_1p79, clk_0p89;
wire pll_locked;
		
pll pll
(
	.refclk(CLK_50M),
	.rst(0),
	.outclk_0(clk_sys),
	.outclk_1(clk_1p79),
	.outclk_2(clk_0p89),
	.locked(pll_locked)
);

///////////////////////////////////////////////////

wire [31:0] status;
wire  [1:0] buttons;

wire [64:0] ps2_key;

wire [15:0] joystick_0, joystick_1;
wire [15:0] joy = joystick_0 | joystick_1;

hps_io #(.STRLEN($size(CONF_STR)>>3)) hps_io
(
	.clk_sys(clk_sys),
	.HPS_BUS(HPS_BUS),

	.conf_str(CONF_STR),

	.buttons(buttons),
	.status(status),

	.joystick_0(joystick_0),
	.joystick_1(joystick_1),
	.ps2_key(ps2_key)
);

wire pressed    = (ps2_key[15:8] != 8'hf0);
wire extended   = (~pressed ? (ps2_key[23:16] == 8'he0) : (ps2_key[15:8] == 8'he0));
wire [8:0] code = ps2_key[63:24] ? 9'd0 : {extended, ps2_key[7:0]}; // filter out PRNSCR and PAUSE
always @(posedge clk_sys) begin
	reg old_state;
	old_state <= ps2_key[64];
	
	if(old_state != ps2_key[64]) begin
		casex(code)
			'hX75: btn_up           <= pressed; // up
			'hX72: btn_down         <= pressed; // down
			'hX6B: btn_thrust       <= pressed; // left
			'hX74: btn_thrust       <= pressed; // right
			'h012: btn_reverse      <= pressed; // l shift
			'h059: btn_reverse      <= pressed; // r shift
			'h029: btn_fire         <= pressed; // space
			'h005: btn_one_player   <= pressed; // F1
			'h006: btn_two_players  <= pressed; // F2
			'h004: btn_left_coin    <= pressed; // F3
			'hX14: btn_smart_bomb   <= pressed; // ctrl
			'h01D: btn_hyperSpace   <= pressed; // W
			'h01C: btn_advance      <= pressed; // A
			'h03C: btn_auto_up      <= pressed; // U
			'h033: btn_score_reset  <= pressed; // H
		endcase
	end
end

reg btn_advance = 0;
reg btn_auto_up = 0;
reg btn_score_reset = 0;
reg btn_left_coin = 0;
reg btn_one_player = 0;
reg btn_two_players = 0;
reg btn_fire = 0;
reg btn_thrust = 0;
reg btn_smart_bomb = 0;
reg btn_hyperSpace = 0;
reg btn_reverse = 0;
reg btn_down = 0;
reg btn_up = 0;

wire [2:0] r,g;
wire [1:0] b;
wire vs,hs;

assign CLK_VIDEO = clk_sys;
assign CE_PIXEL = 1;

assign VGA_HS = ~hs;
assign VGA_VS = ~vs;
assign VGA_R = {r,r,r[2:1]};
assign VGA_G = {g,g,g[2:1]};
assign VGA_B = {b,b,b,b};


wire [7:0] audio;
assign AUDIO_L = {audio, audio};
assign AUDIO_R = AUDIO_L;
assign AUDIO_S = 0;

defender defender
(
	.clock_6(clk_sys),
	.clk_1p79(clk_1p79),
	.clk_0p89(clk_0p89),

	.reset(RESET | status[0] | status[6] | buttons[1]),

	//-- tv15Khz_mode => tv15Khz_mode,
	.video_r(r),
	.video_g(g),
	.video_b(b),
	.video_blankn(VGA_DE),
	.video_hs(hs),
	.video_vs(vs),
	.audio_out(audio),

	.btn_advance(btn_advance),
	.btn_auto_up(btn_auto_up),
	.btn_high_score_reset(btn_score_reset),

	.btn_left_coin(btn_left_coin | joy[9]),
	.btn_one_player(btn_one_player | joy[8]),
	.btn_two_players(btn_two_players),

	.btn_fire(btn_fire | joy[5]),
	.btn_thrust(btn_thrust | joy[0] | joy[1]),
	.btn_smart_bomb(btn_smart_bomb | joy[6]),
	.btn_hyperSpace(btn_hyperSpace | joy[7]),
	.btn_reverse(btn_reverse | joy[4]),
	.btn_down(btn_down | joy[2]),
	.btn_up(btn_up | joy[3]),

	.sw_coktail_table(1) // 1 for coktail table, 0 for upright cabinet
);

endmodule
