// synopsys translate_off
`timescale 1 ps / 1 ps
// synopsys translate_on

/* Charset contains FIO DEC chars, applied from a font like the one on a IBM Model B typewriter
   (which is basically what a Soroban console is) */
module pdp1_terminal_charset (
   address,
   clock,
   q);

   input [11:0]  address;
   input   clock;
   output   [15:0]  q;
`ifndef ALTERA_RESERVED_QIS
// synopsys translate_off
`endif
   tri1    clock;
`ifndef ALTERA_RESERVED_QIS
// synopsys translate_on
`endif

   wire [15:0] sub_wire0;
   wire [15:0] q = sub_wire0[15:0];

   altsyncram  altsyncram_component (
            .address_a (address),
            .clock0 (clock),
            .q_a (sub_wire0),
            .aclr0 (1'b0),
            .aclr1 (1'b0),
            .address_b (1'b1),
            .addressstall_a (1'b0),
            .addressstall_b (1'b0),
            .byteena_a (1'b1),
            .byteena_b (1'b1),
            .clock1 (1'b1),
            .clocken0 (1'b1),
            .clocken1 (1'b1),
            .clocken2 (1'b1),
            .clocken3 (1'b1),
            .data_a ({16{1'b1}}),
            .data_b (1'b1),
            .eccstatus (),
            .q_b (),
            .rden_a (1'b1),
            .rden_b (1'b1),
            .wren_a (1'b0),
            .wren_b (1'b0));
   defparam
      altsyncram_component.address_aclr_a = "NONE",
      altsyncram_component.clock_enable_input_a = "BYPASS",
      altsyncram_component.clock_enable_output_a = "BYPASS",
      altsyncram_component.init_file = "fiodec_charset.mif",
      altsyncram_component.intended_device_family = "Cyclone V",
      altsyncram_component.lpm_hint = "ENABLE_RUNTIME_MOD=NO",
      altsyncram_component.lpm_type = "altsyncram",
      altsyncram_component.numwords_a = 4096,
      altsyncram_component.operation_mode = "ROM",
      altsyncram_component.outdata_aclr_a = "NONE",
      altsyncram_component.outdata_reg_a = "CLOCK0",
      altsyncram_component.ram_block_type = "M10K",
      altsyncram_component.widthad_a = 12,
      altsyncram_component.width_a = 16,
      altsyncram_component.width_byteena_a = 1;

endmodule



/* Rowbuffer holds next 8 lines of pixels which should be drawn on the screen, 
   storing pixels extracted from ring buffers */
   
module pdp1_vga_rowbuffer (
   clock,
   data,
   rdaddress,
   wraddress,
   wren,
   q);

   input   clock;
   input [7:0]  data;
   input [12:0]  rdaddress;
   input [12:0]  wraddress;
   input   wren;
   output   [7:0]  q;
`ifndef ALTERA_RESERVED_QIS
// synopsys translate_off
`endif
   tri1    clock;
   tri0    wren;
`ifndef ALTERA_RESERVED_QIS
// synopsys translate_on
`endif

   wire [7:0] sub_wire0;
   wire [7:0] q = sub_wire0[7:0];

   altsyncram  altsyncram_component (
            .address_a (wraddress),
            .address_b (rdaddress),
            .clock0 (clock),
            .data_a (data),
            .wren_a (wren),
            .q_b (sub_wire0),
            .aclr0 (1'b0),
            .aclr1 (1'b0),
            .addressstall_a (1'b0),
            .addressstall_b (1'b0),
            .byteena_a (1'b1),
            .byteena_b (1'b1),
            .clock1 (1'b1),
            .clocken0 (1'b1),
            .clocken1 (1'b1),
            .clocken2 (1'b1),
            .clocken3 (1'b1),
            .data_b ({8{1'b1}}),
            .eccstatus (),
            .q_a (),
            .rden_a (1'b1),
            .rden_b (1'b1),
            .wren_b (1'b0));
   defparam
      altsyncram_component.address_aclr_b = "NONE",
      altsyncram_component.address_reg_b = "CLOCK0",
      altsyncram_component.clock_enable_input_a = "BYPASS",
      altsyncram_component.clock_enable_input_b = "BYPASS",
      altsyncram_component.clock_enable_output_b = "BYPASS",
      altsyncram_component.intended_device_family = "Cyclone V",
      altsyncram_component.lpm_type = "altsyncram",
      altsyncram_component.numwords_a = 8192,
      altsyncram_component.numwords_b = 8192,
      altsyncram_component.operation_mode = "DUAL_PORT",
      altsyncram_component.outdata_aclr_b = "NONE",
      altsyncram_component.outdata_reg_b = "CLOCK0",
      altsyncram_component.power_up_uninitialized = "FALSE",
      altsyncram_component.ram_block_type = "M10K",
      altsyncram_component.read_during_write_mode_mixed_ports = "OLD_DATA",
      altsyncram_component.widthad_a = 13,
      altsyncram_component.widthad_b = 13,
      altsyncram_component.width_a = 8,
      altsyncram_component.width_b = 8,
      altsyncram_component.width_byteena_a = 1;
endmodule


/* 1,6k of memory which holds a single line of pixels. Three of these are instantiated
   and chained together with 3 additional registers per line, so a 3x3 matrix is formed and
   various kernels can be applied (blur) */

module line_shift_register (
   clock,
   shiftin,
   shiftout,
   taps);

   input   clock;
   input [7:0]  shiftin;
   output   [7:0]  shiftout;
   output   [7:0]  taps;

   wire [7:0] sub_wire0;
   wire [7:0] sub_wire1;
   wire [7:0] shiftout = sub_wire0[7:0];
   wire [7:0] taps = sub_wire1[7:0];

   altshift_taps  ALTSHIFT_TAPS_component (
            .clock (clock),
            .shiftin (shiftin),
            .shiftout (sub_wire0),
            .taps (sub_wire1)
            // synopsys translate_off
            ,
            .aclr (),
            .clken (),
            .sclr ()
            // synopsys translate_on
            );
   defparam
      ALTSHIFT_TAPS_component.intended_device_family = "Cyclone V",
      ALTSHIFT_TAPS_component.lpm_hint = "RAM_BLOCK_TYPE=M10K",
      ALTSHIFT_TAPS_component.lpm_type = "altshift_taps",
      ALTSHIFT_TAPS_component.number_of_taps = 1,
      
      /* Not 1688 (the number of clock cycles in 1280 x 1024 @ 60 Hz row) 
         because 3 explicitly defined registers are used in the chain as well, 
         adding up to 1685 + 3 = 1688 */
      ALTSHIFT_TAPS_component.tap_distance = 1685, 
      ALTSHIFT_TAPS_component.width = 8;

endmodule


/* Pixel ring buffer is a linear feedback shift register, 8k of memory with 8 taps. 
   It is used to store pixels visible on the type 30 CRT, as well as their current intensity  */

module pixel_ring_buffer (
   clock,
   shiftin,
   shiftout,
   taps);

   input   clock;
   input [31:0]  shiftin;
   output   [31:0]  shiftout;
   output   [255:0]  taps;

   wire [31:0] sub_wire0;
   wire [255:0] sub_wire1;
   wire [31:0] shiftout = sub_wire0[31:0];
   wire [255:0] taps = sub_wire1[255:0];

   altshift_taps  ALTSHIFT_TAPS_component (
            .clock (clock),
            .shiftin (shiftin),
            .shiftout (sub_wire0),
            .taps (sub_wire1)
            // synopsys translate_off
            ,
            .aclr (),
            .clken (),
            .sclr ()
            // synopsys translate_on
            );
   defparam
      ALTSHIFT_TAPS_component.intended_device_family = "Cyclone V",
      ALTSHIFT_TAPS_component.lpm_hint = "RAM_BLOCK_TYPE=M10K",
      ALTSHIFT_TAPS_component.lpm_type = "altshift_taps",
      ALTSHIFT_TAPS_component.number_of_taps = 8,
      ALTSHIFT_TAPS_component.tap_distance = 1024,
      ALTSHIFT_TAPS_component.width = 32;


endmodule



/* Terminal frame buffer, contains 64 x 32 characters which correspond to letters on teletype emulator screen */

module pdp1_terminal_fb (
   clock,
   data,
   rdaddress,
   wraddress,
   wren,
   q);

   input   clock;
   input [7:0]  data;
   input [10:0]  rdaddress;
   input [10:0]  wraddress;
   input   wren;
   output   [7:0]  q;
`ifndef ALTERA_RESERVED_QIS
// synopsys translate_off
`endif
   tri1    clock;
   tri0    wren;
`ifndef ALTERA_RESERVED_QIS
// synopsys translate_on
`endif

   wire [7:0] sub_wire0;
   wire [7:0] q = sub_wire0[7:0];

   altsyncram  altsyncram_component (
            .address_a (wraddress),
            .address_b (rdaddress),
            .clock0 (clock),
            .data_a (data),
            .wren_a (wren),
            .q_b (sub_wire0),
            .aclr0 (1'b0),
            .aclr1 (1'b0),
            .addressstall_a (1'b0),
            .addressstall_b (1'b0),
            .byteena_a (1'b1),
            .byteena_b (1'b1),
            .clock1 (1'b1),
            .clocken0 (1'b1),
            .clocken1 (1'b1),
            .clocken2 (1'b1),
            .clocken3 (1'b1),
            .data_b ({8{1'b1}}),
            .eccstatus (),
            .q_a (),
            .rden_a (1'b1),
            .rden_b (1'b1),
            .wren_b (1'b0));
   defparam
      altsyncram_component.address_aclr_b = "NONE",
      altsyncram_component.address_reg_b = "CLOCK0",
      altsyncram_component.clock_enable_input_a = "BYPASS",
      altsyncram_component.clock_enable_input_b = "BYPASS",
      altsyncram_component.clock_enable_output_b = "BYPASS",
      altsyncram_component.intended_device_family = "Cyclone V",
      altsyncram_component.lpm_type = "altsyncram",
      altsyncram_component.numwords_a = 2000,
      altsyncram_component.numwords_b = 2000,
      altsyncram_component.operation_mode = "DUAL_PORT",
      altsyncram_component.outdata_aclr_b = "NONE",
      altsyncram_component.outdata_reg_b = "CLOCK0",
      altsyncram_component.power_up_uninitialized = "FALSE",
      altsyncram_component.read_during_write_mode_mixed_ports = "DONT_CARE",
      altsyncram_component.widthad_a = 11,
      altsyncram_component.widthad_b = 11,
      altsyncram_component.width_a = 8,
      altsyncram_component.width_b = 8,
      altsyncram_component.width_byteena_a = 1;


endmodule


/* ROM, contains 1-bit background image for console output screen */

module console_bg_image (
   address,
   clock,
   q);

   input [15:0]  address;
   input   clock;
   output   [31:0]  q;
`ifndef ALTERA_RESERVED_QIS
// synopsys translate_off
`endif
   tri1    clock;
`ifndef ALTERA_RESERVED_QIS
// synopsys translate_on
`endif

   wire [31:0] sub_wire0;
   wire [31:0] q = sub_wire0[31:0];

   altsyncram  altsyncram_component (
            .address_a (address),
            .clock0 (clock),
            .q_a (sub_wire0),
            .aclr0 (1'b0),
            .aclr1 (1'b0),
            .address_b (1'b1),
            .addressstall_a (1'b0),
            .addressstall_b (1'b0),
            .byteena_a (1'b1),
            .byteena_b (1'b1),
            .clock1 (1'b1),
            .clocken0 (1'b1),
            .clocken1 (1'b1),
            .clocken2 (1'b1),
            .clocken3 (1'b1),
            .data_a ({32{1'b1}}),
            .data_b (1'b1),
            .eccstatus (),
            .q_b (),
            .rden_a (1'b1),
            .rden_b (1'b1),
            .wren_a (1'b0),
            .wren_b (1'b0));
   defparam
      altsyncram_component.address_aclr_a = "NONE",
      altsyncram_component.clock_enable_input_a = "BYPASS",
      altsyncram_component.clock_enable_output_a = "BYPASS",
      altsyncram_component.init_file = "console_bg.mif",
      altsyncram_component.intended_device_family = "Cyclone V",
      altsyncram_component.lpm_hint = "ENABLE_RUNTIME_MOD=NO",
      altsyncram_component.lpm_type = "altsyncram",
      altsyncram_component.numwords_a = 45056,
      altsyncram_component.operation_mode = "ROM",
      altsyncram_component.outdata_aclr_a = "NONE",
      altsyncram_component.outdata_reg_a = "CLOCK0",
      altsyncram_component.ram_block_type = "M10K",
      altsyncram_component.widthad_a = 16,
      altsyncram_component.width_a = 32,
      altsyncram_component.width_byteena_a = 1;


endmodule



/* 4k words of main RAM which connects to PDP1 CPU */

module pdp1_main_ram (
   address_a,
   address_b,
   clock_a,
   clock_b,
   data_a,
   data_b,
   wren_a,
   wren_b,
   q_a,
   q_b);

   input [11:0]  address_a;
   input [11:0]  address_b;
   input   clock_a;
   input   clock_b;
   input [17:0]  data_a;
   input [17:0]  data_b;
   input   wren_a;
   input   wren_b;
   output   [17:0]  q_a;
   output   [17:0]  q_b;
`ifndef ALTERA_RESERVED_QIS
// synopsys translate_off
`endif
   tri1    clock_a;
   tri0    wren_a;
   tri0    wren_b;
`ifndef ALTERA_RESERVED_QIS
// synopsys translate_on
`endif

   wire [17:0] sub_wire0;
   wire [17:0] sub_wire1;
   wire [17:0] q_a = sub_wire0[17:0];
   wire [17:0] q_b = sub_wire1[17:0];

   altsyncram  altsyncram_component (
            .address_a (address_a),
            .address_b (address_b),
            .clock0 (clock_a),
            .clock1 (clock_b),
            .data_a (data_a),
            .data_b (data_b),
            .wren_a (wren_a),
            .wren_b (wren_b),
            .q_a (sub_wire0),
            .q_b (sub_wire1),
            .aclr0 (1'b0),
            .aclr1 (1'b0),
            .addressstall_a (1'b0),
            .addressstall_b (1'b0),
            .byteena_a (1'b1),
            .byteena_b (1'b1),
            .clocken0 (1'b1),
            .clocken1 (1'b1),
            .clocken2 (1'b1),
            .clocken3 (1'b1),
            .eccstatus (),
            .rden_a (1'b1),
            .rden_b (1'b1));
   defparam
      altsyncram_component.address_reg_b = "CLOCK1",
      altsyncram_component.clock_enable_input_a = "BYPASS",
      altsyncram_component.clock_enable_input_b = "BYPASS",
      altsyncram_component.clock_enable_output_a = "BYPASS",
      altsyncram_component.clock_enable_output_b = "BYPASS",
      altsyncram_component.indata_reg_b = "CLOCK1",
      altsyncram_component.intended_device_family = "Cyclone V",
      altsyncram_component.lpm_type = "altsyncram",
      altsyncram_component.init_file = "spacewar.mif",
      altsyncram_component.numwords_a = 4096,
      altsyncram_component.numwords_b = 4096,
      altsyncram_component.operation_mode = "BIDIR_DUAL_PORT",
      altsyncram_component.outdata_aclr_a = "NONE",
      altsyncram_component.outdata_aclr_b = "NONE",
      altsyncram_component.outdata_reg_a = "CLOCK0",
      altsyncram_component.outdata_reg_b = "CLOCK1",
      altsyncram_component.power_up_uninitialized = "FALSE",
      altsyncram_component.ram_block_type = "M10K",
      altsyncram_component.read_during_write_mode_port_a = "NEW_DATA_NO_NBE_READ",
      altsyncram_component.read_during_write_mode_port_b = "NEW_DATA_NO_NBE_READ",
      altsyncram_component.widthad_a = 12,
      altsyncram_component.widthad_b = 12,
      altsyncram_component.width_a = 18,
      altsyncram_component.width_b = 18,
      altsyncram_component.width_byteena_a = 1,
      altsyncram_component.width_byteena_b = 1,
      altsyncram_component.wrcontrol_wraddress_reg_b = "CLOCK1";


endmodule

/* Divider used for hardware division instruction (cheating!!) */

module pdp1_cpu_alu_div (
   in_clock,
	denom,
	numer,
	quotient,
	remain);

	input in_clock;
	input	[16:0]  denom;
	input	[33:0]  numer;
	output	[33:0]  quotient;
	output	[16:0]  remain;

	wire [33:0] sub_wire0;
	wire [16:0] sub_wire1;
	wire [33:0] quotient = sub_wire0[33:0];
	wire [16:0] remain = sub_wire1[16:0];

	lpm_divide	LPM_DIVIDE_component (
				.denom (denom),
				.numer (numer),
				.quotient (sub_wire0),
				.remain (sub_wire1),
				.aclr (1'b0),
				.clken (1'b1),
				.clock (in_clock));
	defparam
		LPM_DIVIDE_component.lpm_drepresentation = "UNSIGNED",
		LPM_DIVIDE_component.lpm_hint = "MAXIMIZE_SPEED=6,LPM_REMAINDERPOSITIVE=TRUE,LPM_PIPELINE=34",
		LPM_DIVIDE_component.lpm_nrepresentation = "UNSIGNED",
		LPM_DIVIDE_component.lpm_type = "LPM_DIVIDE",
		LPM_DIVIDE_component.lpm_widthd = 17,
		LPM_DIVIDE_component.lpm_widthn = 34;		
endmodule