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
	inout  [44:0] HPS_BUS,

	//Base video clock. Usually equals to CLK_SYS.
	output        VGA_CLK,

	//Multiple resolutions are supported using different VGA_CE rates.
	//Must be based on CLK_VIDEO
	output        VGA_CE,

	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_DE,    // = ~(VBlank | HBlank)

	//Base video clock. Usually equals to CLK_SYS.
	output        HDMI_CLK,

	//Multiple resolutions are supported using different HDMI_CE rates.
	//Must be based on CLK_VIDEO
	output        HDMI_CE,

	output  [7:0] HDMI_R,
	output  [7:0] HDMI_G,
	output  [7:0] HDMI_B,
	output        HDMI_HS,
	output        HDMI_VS,
	output        HDMI_DE,   // = ~(VBlank | HBlank)
	output  [1:0] HDMI_SL,   // scanlines fx

	//Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
	output  [7:0] HDMI_ARX,
	output  [7:0] HDMI_ARY,

	output        LED_USER,  // 1 - ON, 0 - OFF.

	// b[1]: 0 - LED status is system status OR'd with b[0]
	//       1 - LED status is controled solely by b[0]
	// hint: supply 2'b00 to let the system control the LED.
	output  [1:0] LED_POWER,
	output  [1:0] LED_DISK,

	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,
	output        AUDIO_S    // 1 - signed audio samples, 0 - unsigned
);

assign LED_USER  = ioctl_download;
assign LED_DISK  = 0;
assign LED_POWER = 0;

assign HDMI_ARX = status[1] ? 8'd16 : status[2] ? 8'd4 : 8'd3;
assign HDMI_ARY = status[1] ? 8'd9  : status[2] ? 8'd3 : 8'd4;

`include "build_id.v" 
localparam CONF_STR = {
	"A.DFNDR;;",
	"F,rom;", // allow loading of alternate ROMs
	"-;",
	"O1,Aspect Ratio,Original,Wide;",
	//"O2,Orientation,Vert,Horz;",
	"O35,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;",
	"-;",
	"O6,Cabinet,Upright,Cocktail;",
	"-;",
	"R0,Reset;",
	"J1,Turn,Fire,Bomb,HyperSpace,Start 1P;",
	"V,",`BUILD_DATE
};

////////////////////   CLOCKS   ///////////////////

wire clk_sys, clk_6p, clk_1p79, clk_0p89, clk_48;
wire pll_locked;

pll pll
(
	.refclk(CLK_50M),
	.rst(0),
	.outclk_0(clk_48), // 48
	.outclk_1(clk_sys), // 24
	.outclk_2(clk_6p), // 6
	.locked(pll_locked)
);

apll apll
(
	.refclk(CLK_50M),
	.rst(0),
	.outclk_0(clk_1p79),
	.outclk_1(clk_0p89)
);


///////////////////////////////////////////////////

wire [31:0] status;
wire  [1:0] buttons;

wire        ioctl_download;
wire        ioctl_wr;
wire [24:0] ioctl_addr;
wire  [7:0] ioctl_dout;

wire [10:0] ps2_key;

wire [15:0] joystick_0, joystick_1;
wire [15:0] joy = joystick_0 | joystick_1;

wire        forced_scandoubler;

hps_io #(.STRLEN($size(CONF_STR)>>3)) hps_io
(
	.clk_sys(clk_sys),
	.HPS_BUS(HPS_BUS),

	.conf_str(CONF_STR),

	.buttons(buttons),
	.status(status),
	.forced_scandoubler(forced_scandoubler),

	.ioctl_download(ioctl_download),
	.ioctl_wr(ioctl_wr),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_dout),

	.joystick_0(joystick_0),
	.joystick_1(joystick_1),
	.ps2_key(ps2_key)
);

wire       pressed = ps2_key[9];
wire [8:0] code    = ps2_key[8:0];
always @(posedge clk_sys) begin
	reg old_state;
	old_state <= ps2_key[10];
	
	if(old_state != ps2_key[10]) begin
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
/*assign VGA_CLK  = clk_48;
assign HDMI_CLK = VGA_CLK;
assign HDMI_CE  = VGA_CE;
assign HDMI_R   = VGA_R;
assign HDMI_G   = VGA_G;
assign HDMI_B   = VGA_B;
assign HDMI_DE  = VGA_DE;
assign HDMI_HS  = VGA_HS;
assign HDMI_VS  = VGA_VS;
//assign HDMI_SL  = 0;
*/
wire HSync = ~hs;
wire VSync = ~vs;
wire HBlank, VBlank;

//wire [1:0] scale = status[4:3];
reg ce_pix;
always @(posedge clk_sys) begin
        reg old_clk;

        old_clk <= clk_6p;
        ce_pix <= old_clk & ~clk_6p;
end

arcade_fx #(306,8) arcade_video
(
        .*,

        .clk_video(clk_sys),

        .RGB_in({r,g,b}),

        .fx(status[5:3])
);


wire [7:0] audio;
assign AUDIO_L = {audio, audio};
assign AUDIO_R = AUDIO_L;
assign AUDIO_S = 0;

defender defender
(
	.clk_sys(clk_sys),
	.clock_6(clk_6p),
	.clk_1p79(clk_1p79),
	.clk_0p89(clk_0p89),

	.reset(RESET | status[0] | buttons[1] | ioctl_download),

	.dn_addr(ioctl_addr[15:0]),
	.dn_data(ioctl_dout),
	.dn_wr(ioctl_wr),

	//-- tv15Khz_mode => tv15Khz_mode,
	.video_r(r),
	.video_g(g),
	.video_b(b),
	.video_hblank(HBlank),
	.video_vblank(VBlank),
	.video_hs(hs),
	.video_vs(vs),
	.audio_out(audio),

	.btn_advance(btn_advance),
	.btn_auto_up(btn_auto_up),
	.btn_high_score_reset(btn_score_reset),

	.btn_left_coin(btn_one_player | joy[8] | btn_two_players),
	.btn_one_player(btn_one_player | joy[8]),
	.btn_two_players(btn_two_players),

	.btn_fire(btn_fire | joy[5]),
	.btn_thrust(btn_thrust | joy[0] | joy[1]),
	.btn_smart_bomb(btn_smart_bomb | joy[6]),
	.btn_hyperSpace(btn_hyperSpace | joy[7]),
	.btn_reverse(btn_reverse | joy[4]),
	.btn_down(btn_down | joy[2]),
	.btn_up(btn_up | joy[3]),

	.sw_coktail_table(status[6]) // 1  // 1 for coktail table, 0 for upright cabinet
);

endmodule
