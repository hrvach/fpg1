// synopsys translate_off
`timescale 1 ps / 1 ps
// synopsys translate_on

module pdp1_vga_console (
  input clk,                                                   /* Clock input, 108 MHz */

  input [5:0] selected_ptr_x,                                  /* Current switch-selecting cursor position */
  input [4:0] selected_ptr_y,       
  input console_switch_strobe,                                 /* A switch was flipped indication */
  
  input [10:0] horizontal_counter,                             /* Current video drawing position */
  input [10:0] vertical_counter,
  
  input [10:0] console_switches,                               /* Current state of console switches */
  
  input [17:0] AC_in,                                          /* Current register/bus state to display on console */
  input [17:0] IO_in,
  input [17:0] DI_in,
  input [11:0] PC_in,
  input [11:0] AB_in,
  input [31:0] BUS_in,
  input RIM_in,
  
  output reg [5:0] sense_switches,                             /* Output toggle switches state */
  output reg [17:0] test_word,
  output reg [17:0] test_address,                
  
  output reg [7:0] red_out,                                    /* Output RGB values to generate console image */
  output reg [7:0] green_out,
  output reg [7:0] blue_out                      
);

//////////////////  PARAMETERS  ///////////////////
                     
parameter
   horizontal                    = 1'b0,
   vertical                      = 1'b1,
   bulb                          = 1'b0,
   switch                        = 1'b1;

//////////////////  FUNCTIONS  ////////////////////
   
function [0:0] is_circle_12;                                   /* Lookup tables to decide if a (x, y) coordinate is within a circle (r = 12). */
   input [4:0] coord_x;                                        /* Contains only data for the first quadrant, and transforms other quadrants accordingly */
   input [4:0] coord_y;
begin
   /* Translate everything into the first quadrant */
   if (coord_x < 5'd16) coord_x = ~coord_x;
   if (coord_y > 5'd16) coord_y = ~coord_y;

   case (coord_y)
      5'd16: is_circle_12 = coord_x < 5'd27;
      5'd15: is_circle_12 = coord_x < 5'd27;
      5'd14: is_circle_12 = coord_x < 5'd27;
      5'd13: is_circle_12 = coord_x < 5'd27;
      5'd12: is_circle_12 = coord_x < 5'd27;
      5'd11: is_circle_12 = coord_x < 5'd27;
      5'd10: is_circle_12 = coord_x < 5'd26;
      5'd9: is_circle_12 = coord_x < 5'd26;
      5'd8: is_circle_12 = coord_x < 5'd25;
      5'd7: is_circle_12 = coord_x < 5'd24;
      5'd6: is_circle_12 = coord_x < 5'd23;
      5'd5: is_circle_12 = coord_x < 5'd22;
      5'd4: is_circle_12 = coord_x < 5'd20;        
      default: is_circle_12 = 1'b0;
   endcase           
end

endfunction

function [0:0] is_circle_8;												/* For circle with radius = 8 pixels */
   input [4:0] coord_x;
   input [4:0] coord_y;
   input [0:0] position; /* 1 = up, 0 = down */
begin
   /* Translate everything into the first quadrant */
   if (coord_x < 5'd16) coord_x = ~coord_x;
   if (~position) coord_y = ~coord_y;

   if (coord_y > 5'd7 && coord_y < 5'd16)  coord_y = 5'd15 - coord_y;            

   case (coord_y)
      5'd7:  is_circle_8 = coord_x < 5'd23;
      5'd6:  is_circle_8 = coord_x < 5'd23;
      5'd5:  is_circle_8 = coord_x < 5'd23;
      5'd4:  is_circle_8 = coord_x < 5'd23;
      5'd3:  is_circle_8 = coord_x < 5'd22;
      5'd2:  is_circle_8 = coord_x < 5'd22;
      5'd1:  is_circle_8 = coord_x < 5'd21;
      5'd0:  is_circle_8 = coord_x < 5'd19;
      default: is_circle_8 = 1'b0;
   endcase           
end

endfunction


////////////////////  TASKS  //////////////////////

task draw_element;
 /* Somewhat ugly way to draw the bulbs and switches on the console */
 input [17:0] register;
 input [5:0] width;
 input [5:0] bulb_x;
 input [4:0] bulb_y;
 input [0:0] direction;          
 input elem_type;
 
 begin         
 
 if ((~direction && (current_y[10:5]  == bulb_y && (current_x[10:5] >= bulb_x && current_x[10:5] < bulb_x + width))) 
   || (direction && (current_x[10:5]  == bulb_x && (current_y[10:5] >= bulb_y && current_y[10:5] < bulb_y + width)))
 )
    if (elem_type == bulb)
    begin
      if (is_circle_12(current_x[4:0], current_y[4:0]))
         begin                                              
            /* In case the power switch is not on, prevent any of the bulbs being drawn as lit. It is inverted logic (0 active) */
            pixel_r <= ~`power_switch & register[width - 1'b1 + bulb_x - current_x[9:5] + bulb_y - current_y[9:5]] ? 8'h88 : 8'haa;
            pixel_g <= ~`power_switch & register[width - 1'b1 + bulb_x - current_x[9:5] + bulb_y - current_y[9:5]] ? 8'hff : 8'haa;
            pixel_b <= ~`power_switch & register[width - 1'b1 + bulb_x - current_x[9:5] + bulb_y - current_y[9:5]] ? 8'h88 : 8'haa;                                                                                                                            
         end
    end
         
   else if (elem_type == switch && direction == horizontal)
   begin
            
      if (current_x[4:0] > 5'd13 && current_x[4:0] < 5'd18 )                                                       /* Switch lever */
         { pixel_r, pixel_g, pixel_b } <= { 8'h44, 8'h44, 8'h44 };
         
      if (is_circle_8(current_x[4:0], current_y[4:0], register[width - 1'b1 - current_x[9:5] + bulb_x]))           /* Switch knob, comes after lever so it's a layer 'above' */
         { pixel_r, pixel_g, pixel_b } <= selected_switch ? { 8'hff, 8'hff, 8'hff } : { 8'haa, 8'haa, 8'haa };
      
   end                     
   
   else if (elem_type == switch && direction == vertical)                                                          /* If direction is vertical, x and y coordinates are reversed */
   begin
            
      if (current_y[4:0] > 5'd13 && current_y[4:0] < 5'd18 )                                                                        
         { pixel_r, pixel_g, pixel_b } <= { 8'h44, 8'h44, 8'h44 };
         
      if (is_circle_8(current_y[4:0], current_x[4:0], register[width - 1'b1 - current_y[9:5] + bulb_y]))                            
         { pixel_r, pixel_g, pixel_b } <= selected_switch ? { 8'hff, 8'hff, 8'hff } : { 8'haa, 8'haa, 8'haa };
      
   end                     
   
end
endtask


///////////////////  MODULES  /////////////////////

console_bg_image bg_image(
   .clock(clk),
   .address(bg_address),
   .q(bg_data)
);

////////////////////  WIRES  //////////////////////

wire [31:0] bg_data;       


//////////////////  REGISTERS  ////////////////////

reg [15:0] bg_address;                                         /* Address register for the console background image data */
reg [7:0] pixel_r, pixel_g, pixel_b;                           /* RGB intensity values */

reg [10:0] current_y, current_x;                               /* Current pixel location relative to the visible part of image */  
                                                                          
reg inside_visible_area = 1'b0;                                /* Indicator if current horizontal/vertical counters are inside visible area */

reg [17:0] AC_copy, IO_copy, DI_copy;                          /* Latch current register states here once per vertical refresh interval */
reg [11:0] PC_copy, AB_copy;
reg [31:0] BUS_copy;

reg old_console_switch_strobe;                                 /* Detect positive edge in switch toggle signal */
reg old_old_console_switch_strobe;                             /* Same value, two clock cycles ago (different clock domains, to give signal time to rise) */
reg selected_switch = 1'b0;                                    /* Indicate the current switch as selected */
      

////////////////  ALWAYS BLOCKS  //////////////////

always @(posedge clk) begin                                
                                                         
   /* 1280 pixels in line / 32 pixels per address = 40 */               
   bg_address <= (current_y * 16'd40) + current_x[10:5];                      
   
   /* 55 88 ff is the background RGB (blue-ish)
      order of bits should be inverted because the leftmost bit is displayed first, 
      offset of 3 is the number of clocks required for data to appear on ROM's q output 
      blank first 8 lines (because rom readout outside visible area maps at address 0)
   */                      

   /* If the current bit is a 1, display a blue color, otherwise make it white. That way we only need to store 1-bit per pixel */
   { pixel_r, pixel_g, pixel_b } <= bg_data[current_x[4:0] - 3'd3] || current_x < 4'd4 ? 24'hffffff : {8'h55, 8'h88, 8'hff};
               
   /* Implement cursor which can be used to select and flip a switch on the console */
   selected_switch <= (selected_ptr_x == current_x[10:5] && selected_ptr_y == current_y[10:5]);                

   //////////////////  DRAW SWITCHES ////////////////////
   
   draw_element(test_word, 6'd18, 5'd3, 5'd21, 1'b0, switch);              /* test word */
   draw_element(test_address, 6'd16, 5'd5, 5'd19, 1'b0, switch);           /* test address */
   draw_element(sense_switches, 6'd6, 5'd31, 5'd14, 1'b0, switch);         /* Sense Switches */          
   
   /* These are just placeholders for now */
   draw_element(1'b0, 6'd1, 5'd3, 5'd19, 1'b0, switch);                    /* extend switch */        
   draw_element({~`power_switch, console_switches[9:8]}, 6'd3, 6'd33, 5'd8, 1'b1, switch);   /* Power, Single Step, Single inst. */          
   
   /* TODO: Optimize these single switch drawing tasks and the rest of this ugly module */

   draw_element(~`start_button,    1'd1, 6'd4,  5'd25, 1'b0, switch);      /* Start */          
   draw_element(~`stop_button,     1'd1, 6'd7,  5'd25, 1'b0, switch);      /* Stop */           
   draw_element(~`continue_button, 1'd1, 6'd10, 5'd25, 1'b0, switch);      /* Continue */          
   draw_element(~`examine_button,  1'd1, 6'd13, 5'd25, 1'b0, switch);      /* Examine */           
   draw_element(~`deposit_button,  1'd1, 6'd16, 5'd25, 1'b0, switch);      /* Deposit */           
   draw_element(~`readin_button,   1'd1, 6'd19, 5'd25, 1'b0, switch);      /* Read-In */           
   
   draw_element(~`reader_button,   1'd1, 6'd30, 5'd25, 1'b0, switch);      /* Reader */            
   draw_element(~`tapefeed_button, 1'd1, 6'd34, 5'd25, 1'b0, switch);      /* Tape Feed */                                             
   
   old_console_switch_strobe <= console_switch_strobe;
	old_old_console_switch_strobe	<= old_console_switch_strobe;
   
   if (~old_old_console_switch_strobe && old_console_switch_strobe)        /* Switch was pressed, positive edge detection */
      case (selected_ptr_y)                        
         /* No two groups of switches are in the same row, so it's possible to tell them apart that way */
         5'd21: test_word[6'd20 - selected_ptr_x] <= ~test_word[6'd20 - selected_ptr_x];           /* width - selected_ptr_x + switch x_offset - 1 */
         5'd19: test_address[6'd20 - selected_ptr_x] <= ~test_address[6'd20 - selected_ptr_x];
         5'd14: sense_switches[6'd36 - selected_ptr_x] <= ~sense_switches[6'd36 - selected_ptr_x];                            
      endcase

   ///////////////////  DRAW BULBS  /////////////////////
      
   draw_element({4'b0, PC_copy}, 6'd16, 5'd4, 5'd7, 1'b0, bulb);           /* Program Counter, no extended mode implemented yet */
   draw_element({4'b0, AB_copy}, 6'd16, 5'd4, 5'd10, 1'b0, bulb);          /* Memory Address, no extended mode implemented yet */
   
   draw_element(DI_copy, 6'd18, 5'd3, 5'd12, 1'b0, bulb);                  /* Memory buffer */
   draw_element(AC_copy, 6'd18, 5'd3, 5'd14, 1'b0, bulb);                  /* Accumulator */
   draw_element(IO_copy, 6'd18, 5'd3, 5'd16, 1'b0, bulb);                  /* IO register */
   
   draw_element(BUS_copy[5:0], 6'd6, 5'd31, 5'd12, 1'b0, bulb);            /* Sense switches */
   draw_element(BUS_copy[11:6], 6'd6, 5'd31, 5'd17, 1'b0, bulb);           /* Program flags */
   draw_element(BUS_copy[16:12], 6'd5, 5'd31, 5'd20, 1'b0, bulb);          /* Current instruction opcode */
   
   draw_element({BUS_copy[18], 5'b0, BUS_copy[17], RIM_in, 5'b0}, 
                                    6'd13, 5'd24, 5'd8, 1'b1, bulb);       /* Instruction */
                                    
   draw_element({~`power_switch, console_switches[9:8]}, 
                                     6'd3, 5'd31, 5'd8, 1'b1, bulb);       /* Power, Single Step, Single Inst. */
               
end
         

always @(posedge clk) begin         
   inside_visible_area <= (horizontal_counter >= `h_visible_offset);
      
   current_y <= (vertical_counter >= `v_visible_offset && vertical_counter < `v_visible_offset_end) ? vertical_counter - `v_visible_offset   : 11'b0;
   current_x <= (horizontal_counter >= `h_visible_offset && horizontal_counter < `h_line_timing)    ? horizontal_counter - `h_visible_offset : 11'b0; 
   
   if (vertical_counter == `v_line_timing) begin            
       /* Changes occur much more frequently than monitor vertical refresh rate. To avoid distortion, we sample registers once per vertical refresh interval. */
       
       AC_copy <= AC_in;
       IO_copy <= IO_in;
       PC_copy <= PC_in;      
       AB_copy <= AB_in;
       DI_copy <= DI_in;
       BUS_copy <= BUS_in;
   end                

   red_out   <= inside_visible_area ? pixel_r : 8'b0;
   green_out <= inside_visible_area ? pixel_g : 8'b0;         
   blue_out  <= inside_visible_area ? pixel_b : 8'b0;
   
end     


endmodule
