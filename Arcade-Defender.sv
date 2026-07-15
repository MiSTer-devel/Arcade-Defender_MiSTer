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
	`include "sys/emu_ports.vh"
);

///////// Default values for ports not used in this core /////////

assign ADC_BUS  = 'Z;
assign USER_OUT = '1;
assign {UART_RTS, UART_TXD, UART_DTR} = 0;
assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;
assign {SDRAM_DQ, SDRAM_A, SDRAM_BA, SDRAM_CLK, SDRAM_CKE, SDRAM_DQML, SDRAM_DQMH, SDRAM_nWE, SDRAM_nCAS, SDRAM_nRAS, SDRAM_nCS} = 'Z;
assign VGA_F1    = 0;
assign VGA_SCALER =0;
assign AUDIO_MIX = 0;
assign LED_USER  = ioctl_download;
assign LED_DISK  = 0;
assign LED_POWER = 0;
assign BUTTONS = 0;
assign FB_FORCE_BLANK = '0;
assign HDMI_FREEZE = 0;
assign HDMI_BLACKOUT = 0;
assign HDMI_BOB_DEINT = 0;
assign VGA_DISABLE = 0;

wire [1:0] ar = status[17:16];

assign VIDEO_ARX = (!ar) ? ((status[2] | landscape) ? 8'd4 : 8'd3) : (ar - 1'd1);
assign VIDEO_ARY = (!ar) ? ((status[2] | landscape) ? 8'd3 : 8'd4) : 12'd0;

`include "build_id.v" 
localparam CONF_STR = {
	"A.DFNDR;;",
	"-;",
	"H0OGH,Aspect ratio,Original,Full Screen,[ARC1],[ARC2];",
	"H1H0O2,Orientation,Vert,Horz;",
	"H3OI,Flip Screen,Off,On;",
	"O35,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;",
	"-;",
	"h2O67,Control,Mode 1,Mode 2,Cabinet;",
	"h2-;",
	"DIP;",
	"-;",
	"h2OR,Autosave Hiscores,Off,On;",
	"P1,Pause options;",
	"P1OP,Pause when OSD is open,On,Off;",
	"P1OQ,Dim video after 10s,On,Off;",
	"-;",
	"R0,Reset;",
	"J1,Fire 1,Fire 2,Fire 3,Fire 4,Fire 5,Start 1P,Start 2P,Coin,Advance,Auto Up,High Score Reset,Pause;",
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
wire        ioctl_upload;
wire        ioctl_upload_req;
wire        ioctl_wr;
wire [24:0] ioctl_addr;
wire  [7:0] ioctl_dout;
wire  [7:0] ioctl_din;
wire  [7:0] ioctl_index;
wire  [7:0] ioctl_data;
wire        ioctl_wait;

wire [31:0] joy1, joy2;
wire [31:0] joy = joy1 | joy2;

wire [21:0] gamma_bus;

hps_io #(.CONF_STR(CONF_STR)) hps_io
(
	.clk_sys(clk_sys),
	.HPS_BUS(HPS_BUS),

	.buttons(buttons),
 	.status(status),
	.status_menumask({(mod != mod_jin),(mod == mod_defender),landscape,direct_video}),
 	.forced_scandoubler(forced_scandoubler),
 	.gamma_bus(gamma_bus),
 	.direct_video(direct_video),
	.video_rotated(video_rotated),

	.ioctl_download(ioctl_download),
	.ioctl_upload(ioctl_upload),
	.ioctl_upload_req(ioctl_upload_req),
	.ioctl_wr(ioctl_wr),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_dout),
	.ioctl_din(ioctl_din),
	.ioctl_index(ioctl_index),
	.ioctl_wait(ioctl_wait),

	.joystick_0(joy1),
	.joystick_1(joy2)

);

wire rom_download = ioctl_download && (ioctl_index == 8'd0);
wire nvram_selected = ioctl_index == 8'd4;

reg reset;
always @(posedge clk_6) reset <= RESET | status[0] | buttons[1] | rom_download;

///////////////////////////////////////////////////////////////////

wire m_start1  = joy[9];
wire m_start2  = joy[10];
wire m_coin1   = joy[11];
wire m_advance = joy[12];
wire m_autoup  = joy[13];
wire m_highreset=joy[14];
wire m_pause    =joy[15];

wire m_right1  = joy1[0];
wire m_left1   = joy1[1];
wire m_down1   = joy1[2];
wire m_up1     = joy1[3];
wire m_fire1a  = joy1[4];
wire m_fire1b  = joy1[5];
wire m_fire1c  = joy1[6];
wire m_fire1d  = joy1[7];
wire m_fire1e  = joy1[8];

wire m_right2  = joy2[0];
wire m_left2   = joy2[1];
wire m_down2   = joy2[2];
wire m_up2     = joy2[3];
wire m_fire2a  = joy2[4];
wire m_fire2b  = joy2[5];
wire m_fire2c  = joy2[6];
wire m_fire2d  = joy2[7];
wire m_fire2e  = joy2[8];

wire m_right   = m_right1 | m_right2;
wire m_left    = m_left1  | m_left2; 
wire m_down    = m_down1  | m_down2; 
wire m_up      = m_up1    | m_up2;   
wire m_fire_a  = m_fire1a | m_fire2a;
wire m_fire_b  = m_fire1b | m_fire2b;
wire m_fire_c  = m_fire1c | m_fire2c;
wire m_fire_d  = m_fire1d | m_fire2d;
wire m_fire_e  = m_fire1e | m_fire2e;

// PAUSE SYSTEM
wire				pause_cpu;
wire [7:0]		rgb_out;
pause #(3,3,2,6) pause (
	.*,
	.clk_sys(clk_6), // Use CPU clock rather than clk_sys to reduce timing issues
	.user_button(m_pause),
	.pause_request(hs_pause),
	.options(~status[26:25])
);

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
	input0 <= { 3'b000, m_coin1, m_highreset,1'b0,m_advance,m_autoup};
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
wire HSync_i  = HSync;
wire VSync_i  = VSync;
wire HBlank_i = HBlank;
wire VBlank_i = VBlank;
wire def_state;

defender defender
(
	.clock_6(clk_6),
	.reset(reset),
	.pause(pause_cpu),
	.defender_state(def_state),

	.dn_clk(clk_sys),
	.dn_addr(ioctl_download ? ioctl_addr[15:0] : hs_address),
	.dn_data(ioctl_dout),
	.dn_wr(ioctl_wr & rom_download),
	.dn_nvram_wr(ioctl_wr & nvram_selected), 
	.dn_din(hs_data_out),
	.dn_nvram(nvram_selected),

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
	.input2(in2),
	.flip(core_flip)
);

///////////////////////////////////////////////////////////////////

reg ce_pix;
always @(posedge clk_48) begin
	reg [2:0] div;

	div <= div + 1'd1;
	ce_pix <= !div;
end

wire flip = 1'b0;
wire is_vertical_game = (mod == mod_jin) || (mod == mod_mayday);
wire core_flip = is_vertical_game & status[18];
wire video_rotated;

screen_rotate screen_rotate (.*);

arcade_video #(306,8) arcade_video
(
	.*,
	.clk_video(clk_48),
	.RGB_in(rgb_out),
	.HBlank(HBlank_i),
	.VBlank(VBlank_i),
	.HSync(HSync_i),
	.VSync(VSync_i),
	.fx(status[5:3])
);

wire [7:0] audio;
assign AUDIO_L = {audio, audio[7:2]};
assign AUDIO_R = AUDIO_L;
assign AUDIO_S = 0;


// HISCORE SYSTEM
// --------------
wire [7:0] hs_address;
wire [7:0] hs_data_out;
wire hs_pause;

nvram #(
	.DUMPWIDTH(8),
	.DUMPINDEX(4),
	.PAUSEPAD(2)
) hi (
	.*,
	.clk(clk_sys),
	.paused(pause_cpu),
	.autosave(status[27]),
	.nvram_address(hs_address),
	.nvram_data_out(hs_data_out),
	.pause_cpu(hs_pause)
);
endmodule
