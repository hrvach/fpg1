module keyboard (
   input              clk,
   input       [10:0] ps2_key,
   input              key_was_processed,

   output reg         kbd_read_strobe,
   output reg         console_switch_strobe,
   output reg  [10:0] console_switches,
   output reg  [6:0]  kbd_char_out,

   /* selected_ptr_* points to cursor coordinates (used for flipping main console switches) */
   output reg  [5:0]  selected_ptr_x,
   output reg  [4:0]  selected_ptr_y,

   output reg  [1:0]  current_output_device,
   output reg  [7:0]  joystick_emu
);


reg  pressed, current_key_state, old_state;

reg current_case;
wire next_case;
reg  [1:0] current_shift_pressed;
wire [1:0] shift_pressed;

assign shift_pressed[0] = ps2_key[7:0] == 8'h12 ? pressed : current_shift_pressed[0];
assign shift_pressed[1] = ps2_key[7:0] == 8'h59 ? pressed : current_shift_pressed[1];
assign next_case = |shift_pressed;

reg [6:0] keyboard_buffer[7:0];
reg [2:0] kbdbuf_read_ptr  = 3'b0;
reg [2:0] kbdbuf_write_ptr = 3'b0;

reg [0:0] old_key_was_processed;
reg [1:0] active_switches;

`define key_assign(code)  keyboard_buffer[kbdbuf_write_ptr] <= { current_case, code }
`include "definitions.v"

always @(posedge clk) begin
   pressed <= ps2_key[9];
   current_key_state <= ps2_key[10];

   kbd_char_out <= keyboard_buffer[kbdbuf_read_ptr];

   old_state <= current_key_state;
   old_key_was_processed <= key_was_processed;

   if (old_state != current_key_state) begin

      if (pressed && (current_output_device == `output_teletype)) // Write to write ptr buffer only if outputting to tty
         kbdbuf_write_ptr <= kbdbuf_write_ptr + 1'b1;

      if (~pressed)                                               // Changed, was if(~pressed), TEST!
         kbd_read_strobe <= 1'b0;

      /* Keys for typewriter emulation and console */

      case (ps2_key[7:0])
         8'h0D: keyboard_buffer[kbdbuf_write_ptr]      <= 6'o36;      // TAB (ps2 = 0x0d, fiodec = o36)
         8'h29: keyboard_buffer[kbdbuf_write_ptr]      <= 6'o00;      // Space
         8'h5A: begin
                  keyboard_buffer[kbdbuf_write_ptr]    <= 6'o77;      // Carriage Return
                  console_switch_strobe                <= pressed;
                end

         8'h05: `power_switch                          <= pressed ^ `power_switch;         // F1 -> Power switch toggle
         8'h06: begin
                  active_switches                      <= active_switches + pressed;       // F2 -> Toggle active switch row
                  case (active_switches + pressed)
                     2'b00: {selected_ptr_x, selected_ptr_y}       <= { 6'd3,  5'd21 };  // Test word cursor set
                     2'b01: {selected_ptr_x, selected_ptr_y}       <= { 6'd5,  5'd19 };  // Test address cursor set
                     2'b10: {selected_ptr_x, selected_ptr_y}       <= { 6'd31, 5'd14 };  // Sense switches cursor set
                     2'b11: {selected_ptr_x, selected_ptr_y}       <= { 11'b0 };         // Clear selection
                  endcase
                end

         8'h04: `single_inst_switch                    <= pressed ^ `single_inst_switch;   // F3 -> Single Instruction switch toggle

         8'h0C: current_output_device                  <= current_output_device + pressed + &current_output_device; // F4 -> Cycle output, skip fourth case because we have only three

         8'h03: `start_button                          <= pressed;                // F5  -> Start
         8'h0B: `stop_button                           <= pressed;                // F6  -> Stop
         8'h83: `continue_button                       <= pressed;                // F7  -> Continue

         8'h0A: `examine_button                        <= pressed;                // F8  -> Examine
         8'h01: `deposit_button                        <= pressed;                // F9  -> Deposit
         8'h09: `readin_button                         <= pressed;                // F10 -> Read in mode pressed
         8'h78: `tapefeed_button                       <= pressed;                // F11 -> Tape Feed

         8'h70: `power_switch                          <= pressed ^ `power_switch;         // Insert -> Power
         8'h69: `single_step_switch                    <= pressed ^ `single_step_switch;   // Num Lock-> Single Step
         8'h71: `single_inst_switch                    <= pressed ^ `single_inst_switch;   // Delete -> Single Instruction

         /* PS2 code    FIO-DEC code    Key */

         8'h66: `key_assign(6'o75);   // Backspace
         8'h41,
         8'h55: `key_assign(6'o33);   // , =  (comma, equal)
         8'h4A: `key_assign(6'o21);   // / ?  (slash, question mark)
         8'h54: `key_assign(6'o57);   // ( [  (left brackets)
         8'h5B: `key_assign(6'o55);   // ) ]  (right brackets)
         8'h49: `key_assign(6'o73);   // . x  (period, multiply)
         8'h4E: `key_assign(6'o54);   // - +  (minus, plus)
         8'h7C: `key_assign(6'o40);   // . _  (middle dot, underline)

         8'h5D: `key_assign(6'o56);   // non-spacing overstrike and vertical
         8'h58: `key_assign(6'o36);   // caps lock -> captab

         8'h45: `key_assign(6'o020);  /* 0 */          8'h1C: `key_assign(6'o061);  /* a */
         8'h16: `key_assign(6'o001);  /* 1 */          8'h32: `key_assign(6'o062);  /* b */
         8'h1E: `key_assign(6'o002);  /* 2 */          8'h21: `key_assign(6'o063);  /* c */
         8'h26: `key_assign(6'o003);  /* 3 */          8'h23: `key_assign(6'o064);  /* d */
         8'h25: `key_assign(6'o004);  /* 4 */          8'h24: `key_assign(6'o065);  /* e */
         8'h2E: `key_assign(6'o005);  /* 5 */          8'h2B: `key_assign(6'o066);  /* f */
         8'h36: `key_assign(6'o006);  /* 6 */          8'h34: `key_assign(6'o067);  /* g */
         8'h3D: `key_assign(6'o007);  /* 7 */          8'h33: `key_assign(6'o070);  /* h */
         8'h3E: `key_assign(6'o010);  /* 8 */          8'h43: `key_assign(6'o071);  /* i */
         8'h46: `key_assign(6'o011);  /* 9 */          8'h3B: `key_assign(6'o041);  /* j */


         8'h42: `key_assign(6'o042);  /* k */          8'h1B: `key_assign(6'o022);  /* s */
         8'h4B: `key_assign(6'o043);  /* l */          8'h2C: `key_assign(6'o023);  /* t */
         8'h3A: `key_assign(6'o044);  /* m */          8'h3C: `key_assign(6'o024);  /* u */
         8'h31: `key_assign(6'o045);  /* n */          8'h2A: `key_assign(6'o025);  /* v */
         8'h44: `key_assign(6'o046);  /* o */          8'h1D: `key_assign(6'o026);  /* w */
         8'h4D: `key_assign(6'o047);  /* p */          8'h22: `key_assign(6'o027);  /* x */
         8'h15: `key_assign(6'o050);  /* q */          8'h35: `key_assign(6'o030);  /* y */
         8'h2D: `key_assign(6'o051);  /* r */          8'h1A: `key_assign(6'o031);  /* z */


         /* Controls for navigating cursor through console switches */

         8'h74: selected_ptr_x                         <= selected_ptr_x + pressed;
         8'h6B: selected_ptr_x                         <= selected_ptr_x - pressed;

         8'h12,   /* Left shift / right shift */
         8'h59:
         begin
            if (current_case != next_case) begin
               keyboard_buffer[kbdbuf_write_ptr] <= next_case ? 6'o74 : 6'o72;
               kbdbuf_write_ptr <= kbdbuf_write_ptr + 1'b1;
            end else kbdbuf_write_ptr <= kbdbuf_write_ptr;

            current_case <= next_case;
            current_shift_pressed <= shift_pressed;
         end

         /* If key not recognized, don't increment write pointer */
         default:
            kbdbuf_write_ptr <= kbdbuf_write_ptr;

      endcase
   end

   if (kbdbuf_write_ptr != kbdbuf_read_ptr)
      kbd_read_strobe <= 1'b1;

   if (~old_key_was_processed && key_was_processed)
   begin
      kbdbuf_read_ptr <= kbdbuf_read_ptr + 1'b1;
      kbd_read_strobe <= 1'b0;
   end

end

/* Enable using the keyboard as controller for spacewar */
always @(posedge clk) begin
   if(old_state != current_key_state) begin
      casex(ps2_key[8:0])
         8'h1D: joystick_emu[0] <= pressed; // w, fire
         8'h1C: joystick_emu[1] <= pressed; // a, left
         8'h1B: joystick_emu[2] <= pressed; // s, thrust
         8'h23: joystick_emu[3] <= pressed; // d, right

         8'h43: joystick_emu[4] <= pressed; // i, fire
         8'h3B: joystick_emu[5] <= pressed; // j, left
         8'h42: joystick_emu[6] <= pressed; // k, thrust
         8'h4B: joystick_emu[7] <= pressed; // l, right
      endcase
   end
end

endmodule
