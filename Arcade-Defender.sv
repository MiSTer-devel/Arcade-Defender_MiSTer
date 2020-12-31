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
	inout  [45:0] HPS_BUS,

	//Base video clock. Usually equals to CLK_SYS.
	output        CLK_VIDEO,

	//Multiple resolutions are supported using different CE_PIXEL rates.
	//Must be based on CLK_VIDEO
	output        CE_PIXEL,

	//Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
	output [11:0] VIDEO_ARX,
	output [11:0] VIDEO_ARY,

	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_DE,    // = ~(VBlank | HBlank)
	output        VGA_F1,
	output [1:0]  VGA_SL,
	output        VGA_SCALER, // Force VGA scaler

	// Use framebuffer from DDRAM (USE_FB=1 in qsf)
	// FB_FORMAT:
	//    [2:0] : 011=8bpp(palette) 100=16bpp 101=24bpp 110=32bpp
	//    [3]   : 0=16bits 565 1=16bits 1555
	//    [4]   : 0=RGB  1=BGR (for 16/24/32 modes)
	//
	// FB_STRIDE either 0 (rounded to 256 bytes) or multiple of 16 bytes.
	output        FB_EN,
	output  [4:0] FB_FORMAT,
	output [11:0] FB_WIDTH,
	output [11:0] FB_HEIGHT,
	output [31:0] FB_BASE,
	output [13:0] FB_STRIDE,
	input         FB_VBL,
	input         FB_LL,
	output        FB_FORCE_BLANK,

	// Palette control for 8bit modes.
	// Ignored for other video modes.
	output        FB_PAL_CLK,
	output  [7:0] FB_PAL_ADDR,
	output [23:0] FB_PAL_DOUT,
	input  [23:0] FB_PAL_DIN,
	output        FB_PAL_WR,

	output        LED_USER,  // 1 - ON, 0 - OFF.

	// b[1]: 0 - LED status is system status OR'd with b[0]
	//       1 - LED status is controled solely by b[0]
	// hint: supply 2'b00 to let the system control the LED.
	output  [1:0] LED_POWER,
	output  [1:0] LED_DISK,

	input         CLK_AUDIO, // 24.576 MHz
	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,
	output        AUDIO_S,    // 1 - signed audio samples, 0 - unsigned

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

	// Open-drain User port.
	// 0 - D+/RX
	// 1 - D-/TX
	// 2..6 - USR2..USR6
	// Set USER_OUT to 1 to read from USER_IN.
	input   [6:0] USER_IN,
	output  [6:0] USER_OUT
);

assign VGA_F1    = 0;
assign VGA_SCALER =0;
assign USER_OUT  = '1;
assign LED_USER  = ioctl_download;
assign LED_DISK  = 0;
assign LED_POWER = 0;
assign {FB_PAL_CLK, FB_FORCE_BLANK, FB_PAL_ADDR, FB_PAL_DOUT, FB_PAL_WR} = '0;

wire [1:0] ar = status[17:16];

assign VIDEO_ARX = (!ar) ?  8'd4  : (ar - 1'd1);
assign VIDEO_ARY = (!ar) ?  8'd3  : 12'd0;


`include "build_id.v" 
localparam CONF_STR = {
	"A.DFNDR;;",
	"-;",
	 "H0OGH,Aspect ratio,Original,Full Screen,[ARC1],[ARC2];",
	"H1H0O2,Orientation,Vert,Horz;",
	"O35,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;",
	"-;",
	"h2O67,Control,Mode 1,Mode 2,Cabinet;",
	"h2-;",
	"DIP;",
	"-;",
	"R0,Reset;",
	"J1,Fire 1,Fire 2,Fire 3,Fire 4,Fire 5,Start 1P,Start 2P,Coin;",
	"V,v",`BUILD_DATE
};

////////////////////   CLOCKS   ///////////////////

wire clk_sys, clk_6, clk_48;

pll pll
(
	.refclk(CLK_50M),
	.rst(0),
	.outclk_0(clk_48),  // 48
	.outclk_1(clk_sys), // 24
	.outclk_2(clk_6)    // 6
);

///////////////////////////////////////////////////

wire [31:0] status;
wire  [1:0] buttons;
wire        forced_scandoubler;
wire        direct_video;

wire        ioctl_download;
wire        ioctl_wr;
wire [24:0] ioctl_addr;
wire  [7:0] ioctl_dout;
wire  [7:0] ioctl_index;
wire  [7:0] ioctl_data;
wire        ioctl_wait;


wire [31:0] joy1, joy2;
wire [31:0] joy = joy1 | joy2;

wire [21:0] gamma_bus;

hps_io #(.STRLEN($size(CONF_STR)>>3)) hps_io
(
	.clk_sys(clk_sys),
	.HPS_BUS(HPS_BUS),

	.conf_str(CONF_STR),

	.buttons(buttons),
 	.status(status),
	.status_menumask({mod == mod_defender,landscape,direct_video}),
 	.forced_scandoubler(forced_scandoubler),
 	.gamma_bus(gamma_bus),
 	.direct_video(direct_video),


	.ioctl_download(ioctl_download),
	.ioctl_wr(ioctl_wr),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_dout),

	.ioctl_index(ioctl_index),
	.ioctl_wait(ioctl_wait),

	.joystick_0(joy1),
	.joystick_1(joy2)

);

wire rom_download = ioctl_download && !ioctl_index;

reg reset;
always @(posedge clk_6) reset <= RESET | status[0] | buttons[1] | rom_download;

///////////////////////////////////////////////////////////////////

wire m_start1  = joy[9];
wire m_start2  = joy[10];
wire m_coin1   = joy[11];

wire m_right1  = joy1[0];
wire m_left1   = joy1[1];
wire m_down1   = joy1[2];
wire m_up1     = joy1[3];
wire m_fire1a  = joy1[4];
wire m_fire1b  = joy1[5];
wire m_fire1c  = joy1[6];
wire m_fire1d  = joy1[7];
wire m_fire1e  = joy1[8];
//wire m_rcw1    =              joy1[8];
//wire m_rccw1   =              joy1[9];
//wire m_spccw1  =              joy1[30];
//wire m_spcw1   =              joy1[31];

wire m_right2  = joy2[0];
wire m_left2   = joy2[1];
wire m_down2   = joy2[2];
wire m_up2     = joy2[3];
wire m_fire2a  = joy2[4];
wire m_fire2b  = joy2[5];
wire m_fire2c  = joy2[6];
wire m_fire2d  = joy2[7];
wire m_fire2e  = joy2[8];
//wire m_rcw2    =              joy2[8];
//wire m_rccw2   =              joy2[9];
//wire m_spccw2  =              joy2[30];
//wire m_spcw2   =              joy2[31];

wire m_right   = m_right1 | m_right2;
wire m_left    = m_left1  | m_left2; 
wire m_down    = m_down1  | m_down2; 
wire m_up      = m_up1    | m_up2;   
wire m_fire_a  = m_fire1a | m_fire2a;
wire m_fire_b  = m_fire1b | m_fire2b;
wire m_fire_c  = m_fire1c | m_fire2c;
wire m_fire_d  = m_fire1d | m_fire2d;
wire m_fire_e  = m_fire1e | m_fire2e;
//wire m_rcw     = m_rcw1   | m_rcw2;
//wire m_rccw    = m_rccw1  | m_rccw2;
//wire m_spccw   = m_spccw1 | m_spccw2;
//wire m_spcw    = m_spcw1  | m_spcw2;

///////////////////////////////////////////////////////////////////

localparam mod_defender = 0;
localparam mod_colony7  = 1;
localparam mod_mayday   = 2;
localparam mod_jin      = 3;

reg [7:0] mod = 0;
always @(posedge clk_sys) if (ioctl_wr & (ioctl_index==1)) mod <= ioctl_dout;

// load the DIPS
reg [7:0] sw[8];
always @(posedge clk_sys) if (ioctl_wr && (ioctl_index==254) && !ioctl_addr[24:3]) sw[ioctl_addr[2:0]] <= ioctl_dout;

///////////////////////////////////////////////////////////////////

reg  [7:0] input0;
reg  [7:0] input1;
reg  [7:0] input2;
reg        mayday;
reg        landscape;
reg        rotate_ccw;
reg        extvbl;

always @(posedge clk_sys) begin
	mayday <= 0;
	input0 <= { 3'b000, m_coin1, 4'b0000 };
	input1 <= 0;
	input2 <= 0;
	landscape <= 1;
	rotate_ccw <= 0;
	extvbl <= 0;

	case(mod)
	mod_defender:
		begin 
			input1 <= { m_down, (status[7:6]==2'b10)? m_fire_e : ( status[7:6]==2'b01 ? (def_state ? m_right : m_left) : (m_left | m_right)), m_start1, m_start2, m_fire_d, m_fire_c, status[7:6]==2'b01 ? (def_state ? m_left : m_right) : m_fire_b, m_fire_a };
			input2 <= { 7'b000000, m_up };
		end
	mod_colony7:
		begin
			landscape  <= 0;
			rotate_ccw <= 1;
			input1 <= { m_fire_b, m_fire_a, m_start1, m_start2, m_up, m_left, m_right, m_down };
			input2 <= { 7'b000000, m_fire_c };
		end
	mod_mayday:
		begin
			mayday <= 1;
			input1 <= { m_down, 1'b0, m_start1, m_start2, m_fire_b, m_fire_c, m_right, m_fire_a };
			input2 <= { 7'b000000, m_up };
		end
	mod_jin:
		begin
			landscape <= 0;
			extvbl <= 1;
			input1 <= { m_fire_b, m_fire_a, m_start1, m_start2, m_right, m_left, m_down, m_up };
		end
	default:;
	endcase
end

wire no_rotate = status[2] | direct_video | landscape;

reg [7:0] in0,in1,in2;
reg extvbl1, mayday1;
always @(posedge clk_6) begin
	in0 <= sw[0] | input0;
	in1 <= sw[1] | input1;
	in2 <= sw[2] | input2;
	
	extvbl1 <= extvbl;
	mayday1 <= mayday;
end

///////////////////////////////////////////////////////////////////

wire [2:0] r,g;
wire [1:0] b;
wire HSync, VSync;
wire HBlank, VBlank;
wire def_state;

defender defender
(
	.clock_6(clk_6),
	.reset(reset),
	.defender_state(def_state),

	.dn_clk(clk_sys),
	.dn_addr(ioctl_addr[15:0]),
	.dn_data(ioctl_dout),
	.dn_wr(ioctl_wr & rom_download),

	.video_r(r),
	.video_g(g),
	.video_b(b),
	.video_hblank(HBlank),
	.video_vblank(VBlank),
	.video_hs(HSync),
	.video_vs(VSync),
	.audio_out(audio),

	.extvbl(extvbl1),
	.mayday(mayday1),

	.input0(in0),
	.input1(in1),
	.input2(in2)
);

///////////////////////////////////////////////////////////////////

reg ce_pix;
always @(posedge clk_48) begin
	reg [2:0] div;

	div <= div + 1'd1;
	ce_pix <= !div;
end

screen_rotate screen_rotate (.*);

arcade_video #(306,8) arcade_video
(
	.*,
	.clk_video(clk_48),
	.RGB_in({r,g,b}),
	.fx(status[5:3])
);

wire [7:0] audio;
assign AUDIO_L = {audio, audio};
assign AUDIO_R = AUDIO_L;
assign AUDIO_S = 0;

endmodule
