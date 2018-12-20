// synopsys translate_off
`timescale 1 ps / 1 ps
// synopsys translate_on

/* This module is a probably overcomplicated (but for educational purposes) vector display implementation 
   attempt with a 1280 x 1024 @ 60 Hz output. It uses several M10K altsyncram instances to provide memory
   storage. To simulate phosphor decay, a classic straightforward approach would require at least 
   1024 x 1024 (DEC Type 30 CRT resolution) pixels x 8 bit per pixel = 8 Mbits of memory. Cyclone V on the
   DE 10 nano (5CSEBA6U23I7) has 5,5 Mbits, and this would require SDRAM. However, SDRAM requires refresh,
   and it's impractical to use as framebuffer (i.e. don't know how at this pixel clock). For more info, see 
   github page. */

module pdp1_vga_crt (
  input clk,                                                   /* Clock input, 1280 x 1024 @ 60 Hz is 108 MHz pixel clock */

  input [10:0] horizontal_counter,                             /* Current video drawing position */
  input [10:0] vertical_counter,                               
                        
  output reg [7:0] red_out,                                    /* Outputs RGB values for corresponding pixels */
  output reg [7:0] green_out,
  output reg [7:0] blue_out,               
  
  input  [9:0] pixel_x_i,                                      /* Gets input from PDP as a peripheral IOT device */
  input  [9:0] pixel_y_i,                                      /* Don't forget the input is clocked at 50 MHz */
  input  [2:0] pixel_brightness,                               /* Pixel brightness / intensity */
  
  input  variable_brightness,                                  /* Should we respect specified brightness levels? */
        
  input  pixel_available                                       /* High when there is a pixel to be written */
);
             
//////////////////  PARAMETERS  ///////////////////
                     
parameter
   DATA_WIDTH                    = 'd32,
   offset                        = 2'd3,
   brightness                    = 8'd242;    

//////////////////  FUNCTIONS  ////////////////////          
          
function automatic [11:0] dim_pixel;
   input [11:0] luma;
	dim_pixel = (luma > 12'd3864 && luma < 12'd3936) ? 12'd2576 : luma - 1'b1;              /* Sudden drop in brightness is to simulate the secondary (green-ish) phosphor afterglow */	
endfunction                   


////////////////////  TASKS  //////////////////////

task output_pixel;                                                                        /* It outputs a pixel and adjusts is color depending on the luminosity */
   input [7:0] intensity;                                                                 /* A bright pixel is blue-white and a darker one is green */
   begin
 
   red_out <= inside_visible_area ? {5'b0, intensity[7:5]} : 8'b0;
   
      if (intensity >= 8'h80) begin      
         green_out <= inside_visible_area ? intensity      : 8'b0;
         blue_out <= inside_visible_area ? intensity       : 8'b0;
         red_out <= inside_visible_area ? intensity[7:6]   : 8'b0;               
      end
      else begin
         green_out <= inside_visible_area ? intensity      : 8'b0;
         blue_out <= inside_visible_area ? intensity[7]    : 8'b0;
      end                           

   end
endtask


////////////////////  WIRES  //////////////////////

wire [7:0] rowbuff_rdata;                                      /* Output from row buffer */
wire [7:0] p31_w, p21_w, p13_w, p23_w, p33_w;                  /* Output from line shift registers */
wire [255:0] taps1, taps2, taps3, taps4;                       /* Ring buffer taps (8 per ring buffer, 32-bit each) */

wire [31:0] shiftout_1_w, shiftout_2_w,                        /* Ring buffer outputs */
            shiftout_3_w, shiftout_4_w;   

wire [9:0] current_y, current_x;                               /* Current visible screen area position */

//////////////////  REGISTERS  ////////////////////

reg  [12:0] rowbuff_rdaddress, rowbuff_wraddress;              /* Row buffer addressing, this is for storing next 8 lines to be drawn */
reg  [7:0] rowbuff_wdata;
reg  [0:0] rowbuff_wren;

/* Create 3x3 pixel matrix from registers to multiply with the blur kernel */         
reg [7:0] p11, p12, p13, // <- p13_w <- line1
          p21, p22, p23, // <- p23_w <- line2 
          p31, p32, p33; // <- p33_w <- line3 <- row buffer


reg [31:0] shiftout_1, shiftout_2, shiftout_3, shiftout_4;     /* Store (and manipulate) values being output from LFSR shift registers */  

reg [9:0] pixel_x, pixel_y;    
reg [9:0] pixel_1_x, pixel_1_y, pixel_2_x, pixel_2_y, 
          pixel_3_x, pixel_3_y, pixel_4_x, pixel_4_y;

reg [11:0] luma, luma_1, luma_2, luma_3, luma_4;

integer i;                                                     /* Used in for loop as index */
         
reg [31:0] pass_counter = 32'd1;                               /* Counts vertical refresh cycles */
reg [9:0]  erase_counter;
                    
reg [31:0] search_counter;                                     /* Counts how many clock cycles passed since we didn't see the pixel to be added on any of the ring buffer taps */

reg [9:0] next_pixel_x, next_pixel_y;                          /* Store the values from the fifo buffer at read pointer to these temporary registers */

reg [9:0] buffer_pixel_x[63:0];                                /* FIFO buffer storing the pixels to be written to ring buffer (when empty slot found) */
reg [9:0] buffer_pixel_y[63:0];
  
reg [5:0] buffer_read_ptr, buffer_write_ptr;                   /* Pointers to FIFO buffer position for read and write operations, 
                                                                  when not equal there is something waiting to be written */
reg [15:0] pixel_out;

reg prev_wren_i, prev_prev_wren_i, wren;                       /* Store write enable signals to detect a rising edge */
      
reg inside_visible_area;                                       /* Indicate if we are currently within area which is visible */


/////////////////  ASSIGNMENTS  ///////////////////

assign p21_w = p21;
assign p31_w = p31;

assign current_y = (vertical_counter >= `v_visible_offset && vertical_counter < `v_visible_offset_end) ? vertical_counter - `v_visible_offset : 11'b0;
assign current_x = (horizontal_counter >= `h_visible_offset + `h_center_offset && horizontal_counter < `h_visible_offset_end + `h_center_offset) ? horizontal_counter - (`h_visible_offset + `h_center_offset): 11'b0;
       
         
///////////////////  MODULES  /////////////////////   
         
/* Row buffer keeps the next 8 lines to be drawn and we populate it with pixels as ring buffer advances */        
pdp1_vga_rowbuffer rowbuffer(
   .data(rowbuff_wdata),
   .rdaddress(rowbuff_rdaddress),
   .clock(clk),
   .wraddress(rowbuff_wraddress),
   .wren(rowbuff_wren),
   .q(rowbuff_rdata));
                   
                     
/* To enable blurring, create 3 1-line shift registers */                                               
line_shift_register line1(.clock(clk), .shiftout(p13_w), .shiftin(p21_w));    
line_shift_register line2(.clock(clk), .shiftout(p23_w), .shiftin(p31_w));    
line_shift_register line3(.clock(clk), .shiftout(p33_w), .shiftin(current_x > 0 ? rowbuff_rdata : 0));                        


/* Create 4 pixel ring buffers with 8 taps each and connect them in a loop (a.k.a. hadron collider style) */
/* e.g. ring_buffer_1 .. shiftout_1_w -> {pixel_1_y, pixel_1_x, luma_1} -> shiftout_2 .. ring_buffer_2    */

pixel_ring_buffer ring_buffer_1(.clock(clk),  .shiftin(shiftout_1),  .shiftout(shiftout_1_w),  .taps(taps1) );
pixel_ring_buffer ring_buffer_2(.clock(clk),  .shiftin(shiftout_2),  .shiftout(shiftout_2_w),  .taps(taps2) );
pixel_ring_buffer ring_buffer_3(.clock(clk),  .shiftin(shiftout_3),  .shiftout(shiftout_3_w),  .taps(taps3) );
pixel_ring_buffer ring_buffer_4(.clock(clk),  .shiftin(shiftout_4),  .shiftout(shiftout_4_w),  .taps(taps4) );

       
////////////////  ALWAYS BLOCKS  //////////////////
                   
always @(posedge clk) begin                               
     next_pixel_x <= buffer_pixel_x[buffer_read_ptr];
     next_pixel_y <= buffer_pixel_y[buffer_read_ptr];
    
     search_counter <= search_counter + 1'b1;
                                   
     { pixel_1_y, pixel_1_x, luma_1 } <= shiftout_1_w;         /* shiftout_?_w is where ring buffers (lfsr) connect to each other */
     { pixel_2_y, pixel_2_x, luma_2 } <= shiftout_2_w;         /* Store these values to corresponding registers */
     { pixel_3_y, pixel_3_x, luma_3 } <= shiftout_3_w;
     { pixel_4_y, pixel_4_x, luma_4 } <= shiftout_4_w;
     
     if(wren) begin                                

          if (variable_brightness && pixel_brightness > 3'b0 && pixel_brightness < 3'b100)
          begin
            { buffer_pixel_y[buffer_write_ptr], buffer_pixel_x[buffer_write_ptr] } <= { ~pixel_x_i, pixel_y_i };                         /* Inverted, MSB <--> LSB */                                
            
            { buffer_pixel_y[buffer_write_ptr + 3'd1], buffer_pixel_x[buffer_write_ptr + 3'd1] } <= { ~pixel_x_i + 1'b1, pixel_y_i };    /* For more brightness, a current naive approach is to add 4 more */                                
            { buffer_pixel_y[buffer_write_ptr + 3'd2], buffer_pixel_x[buffer_write_ptr + 3'd2] } <= { ~pixel_x_i, pixel_y_i + 1'b1};     /* pixels next so the current one appears brighter. */                                
            { buffer_pixel_y[buffer_write_ptr + 3'd3], buffer_pixel_x[buffer_write_ptr + 3'd3] } <= { ~pixel_x_i - 1'b1, pixel_y_i };    /* Pixels won't actually be added, but updated instead if they */                                
            { buffer_pixel_y[buffer_write_ptr + 3'd4], buffer_pixel_x[buffer_write_ptr + 3'd4] } <= { ~pixel_x_i, pixel_y_i - 1'b1};     /* already exist. However, checking takes time. */                                

            buffer_write_ptr <= buffer_write_ptr + 3'd5;                                                                                                                          
          end
          
          else 
          
          begin
            { buffer_pixel_y[buffer_write_ptr], buffer_pixel_x[buffer_write_ptr] } <= { ~pixel_x_i, pixel_y_i };                         /* Regular brightness, invert MSB <--> LSB */                                
            buffer_write_ptr <= buffer_write_ptr + 1'b1;                                                 
          end
          
          if (buffer_write_ptr == buffer_read_ptr)
               search_counter <= 0;                                            
     end                           
     
     begin                                       
     /* Dimming old pixels at the points where ring buffers connect. They are stored into registers and connected: 1->2, 2->3, 3->4, 4->1 */                               
     shiftout_1 <= luma_4[11:4] ? { pixel_4_y, pixel_4_x, pass_counter[2:0] == 3'b0 ? dim_pixel(luma_4) : luma_4 } : 0;
     shiftout_2 <= luma_1[11:4] ? { pixel_1_y, pixel_1_x, pass_counter[2:0] == 3'b0 ? dim_pixel(luma_1) : luma_1 } : 0;
     shiftout_3 <= luma_2[11:4] ? { pixel_2_y, pixel_2_x, pass_counter[2:0] == 3'b0 ? dim_pixel(luma_2) : luma_2 }: 0;
     shiftout_4 <= luma_3[11:4] ? { pixel_3_y, pixel_3_x, pass_counter[2:0] == 3'b0 ? dim_pixel(luma_3) : luma_3 }: 0;                                
     
     /* Add new pixel */
     
     /* If we didn't find a pixel on one of the taps withing 1024 clock cycles (inter-tap distance), assume there is 
        nothing to update and once we find a dark pixel we can re-use, add the current one to that position */
     
     if (buffer_write_ptr != buffer_read_ptr && search_counter > 1024 && (!luma_1[11:4] || !luma_2[11:4] || !luma_3[11:4] || !luma_4[11:4]))
     begin
         if (luma_4[11:4] == 0)  
               shiftout_1 <= { { next_pixel_y, next_pixel_x, 12'd4095 } };
         else if (luma_1[11:4] == 0)  
               shiftout_2 <= { { next_pixel_y, next_pixel_x, 12'd4095 } };
         else if (luma_2[11:4] == 0)  
               shiftout_3 <= { { next_pixel_y, next_pixel_x, 12'd4095 } };
         else if (luma_3[11:4] == 0)  
               shiftout_4 <= { { next_pixel_y, next_pixel_x, 12'd4095 } };
      
         buffer_read_ptr <= buffer_read_ptr + 1'b1;

         next_pixel_x <= buffer_pixel_x[buffer_read_ptr + 1'b1];
         next_pixel_y <= buffer_pixel_y[buffer_read_ptr + 1'b1];

         search_counter <= 0;                                                                   
      end
     
     /* Update existing pixel, treat this as an existing pixel refresh only if it's visible on the screen 
        (search counter is < 1024 and we in fact found the pixel on one of the LFSR outputs) */
   
   else if (buffer_write_ptr != buffer_read_ptr && 
      (  (pixel_1_x == next_pixel_x && pixel_1_y == next_pixel_y)
      || (pixel_2_x == next_pixel_x && pixel_2_y == next_pixel_y)
      || (pixel_3_x == next_pixel_x && pixel_3_y == next_pixel_y)
      || (pixel_4_x == next_pixel_x && pixel_4_y == next_pixel_y)
      ))
   begin
      if (pixel_1_x == next_pixel_x && pixel_1_y == next_pixel_y)
         shiftout_2 <= { next_pixel_y, next_pixel_x, 12'd4095};      
         
      else if (pixel_2_x == next_pixel_x && pixel_2_y == next_pixel_y)
         shiftout_3 <= { next_pixel_y, next_pixel_x, 12'd4095};      
         
      else if (pixel_3_x == next_pixel_x && pixel_3_y == next_pixel_y)
         shiftout_4 <= { next_pixel_y, next_pixel_x, 12'd4095};      

      else if (pixel_4_x == next_pixel_x && pixel_4_y == next_pixel_y)
         shiftout_1 <= { next_pixel_y, next_pixel_x, 12'd4095};      
         
      /* Increment the read_ptr pointer as we have just inserted one pixel from the write fifo buffer */
      buffer_read_ptr <= buffer_read_ptr + 1'b1;               
      
      next_pixel_x <= buffer_pixel_x[buffer_read_ptr + 1'b1];
      next_pixel_y <= buffer_pixel_y[buffer_read_ptr + 1'b1];

      search_counter <= 0;
     
   end
     
     /* We have seen our pixel exists in ring buffer on one of the taps. Reset search counter so we don't add another one but wait for it to appear 
     on the LSFR outputs (in shiftout_? registers). As we buffer 8 lines ahead and have 8 taps per ring buffer, we will "catch" the pixel in time to be output */
     else 
         for (i=8; i>0; i=i-1'b1)               
            if ((taps1[i * DATA_WIDTH-1 -: 10] == next_pixel_y && taps1[i * DATA_WIDTH-11 -: 10] == next_pixel_x && taps1[i * DATA_WIDTH-21 -: 8])
              ||(taps2[i * DATA_WIDTH-1 -: 10] == next_pixel_y && taps2[i * DATA_WIDTH-11 -: 10] == next_pixel_x && taps2[i * DATA_WIDTH-21 -: 8])
              ||(taps3[i * DATA_WIDTH-1 -: 10] == next_pixel_y && taps3[i * DATA_WIDTH-11 -: 10] == next_pixel_x && taps3[i * DATA_WIDTH-21 -: 8])
              ||(taps4[i * DATA_WIDTH-1 -: 10] == next_pixel_y && taps4[i * DATA_WIDTH-11 -: 10] == next_pixel_x && taps4[i * DATA_WIDTH-21 -: 8])
               )
               
               search_counter <= 0;                                                                                                
     end
end            

always @(posedge clk) begin                                
   /* Read from one line buffer to the screen and prepare the next line */                                   
                                             
   rowbuff_rdaddress <= {current_y[2:0], current_x};
   rowbuff_wren <= 1'b1;
               
   /* Shift the 3x3 register values (connected to the lfsr line buffers). We use these to apply a blur kernel since without it the graphics are too sharp for a CRT output */          
   p11 <= p12; p12 <= p13; p13 <= p13_w;
   p21 <= p22; p22 <= p23; p23 <= p23_w;
   p31 <= p32; p32 <= p33; p33 <= p33_w;                       

   /* Simple averaging blur kernel, but instead with 9, we divide by 8. Since this applies only to phosphor trail anyways, it will never overflow the max value for pixel_out register width */
   if ( p22 < brightness) 
	begin   		
		pixel_out <= ( {8'b0, p11[7:1]} + p12 + p13 + p21 + p22 + p23 + p31 + p32 + p33[7:1] ) >> 3;		/* Remove chance of overflow by taking two pixels with 0.5 coefficient */			
		p21 <= pixel_out;		
	end
   else                       
      pixel_out <= p22;
   
   output_pixel(pixel_out);

   if (erase_counter < current_x)                              /* This is so the last column gets erased */
      begin                         
         rowbuff_wraddress <= {current_y[2:0], erase_counter}; 
         rowbuff_wdata <= 0;
         erase_counter <= erase_counter + 1'b1;                               
      end         
   
   else
   /* Multi row scanline buffer, look 7 lines ahead and fill corresponding pixels with matches found in the ring buffer */
   for (i=8; i>0; i=i-1'b1)               
      if (current_y < taps1[i * DATA_WIDTH-1 -: 10] && taps1[i * DATA_WIDTH-1 -: 10] - current_y <= 3'd7 && taps1[i * DATA_WIDTH - 21 -: 8] > 0) 
         begin  rowbuff_wraddress <= {taps1[i * DATA_WIDTH - 8 -: 3], taps1[i * DATA_WIDTH - 11 -: 10]}; rowbuff_wdata <= taps1[i * DATA_WIDTH - 21 -: 8]; end                        
      else
      if (current_y < taps2[i * DATA_WIDTH-1 -: 10] && taps2[i * DATA_WIDTH-1 -: 10] - current_y <= 3'd7 && taps2[i * DATA_WIDTH - 21 -: 8] > 0) 
         begin  rowbuff_wraddress <= {taps2[i * DATA_WIDTH - 8 -: 3], taps2[i * DATA_WIDTH - 11 -: 10]}; rowbuff_wdata <= taps2[i * DATA_WIDTH - 21 -: 8]; end                        
      else
      if (current_y < taps3[i * DATA_WIDTH-1 -: 10] && taps3[i * DATA_WIDTH-1 -: 10] - current_y <= 3'd7 && taps3[i * DATA_WIDTH - 21 -: 8] > 0) 
         begin  rowbuff_wraddress <= {taps3[i * DATA_WIDTH - 8 -: 3], taps3[i * DATA_WIDTH - 11 -: 10]}; rowbuff_wdata <= taps3[i * DATA_WIDTH - 21 -: 8]; end                                           
      else
      if (current_y < taps4[i * DATA_WIDTH-1 -: 10] && taps4[i * DATA_WIDTH-1 -: 10] - current_y <= 3'd7 && taps4[i * DATA_WIDTH - 21 -: 8] > 0) 
         begin  rowbuff_wraddress <= {taps4[i * DATA_WIDTH - 8 -: 3], taps4[i * DATA_WIDTH - 11 -: 10]}; rowbuff_wdata <= taps4[i * DATA_WIDTH - 21 -: 8]; end                                           
      else            
   
   /* Erase counter is the x index used to erase the last column of the 1280 x 8 buffer used to store the next lines to be drawn. */
   if (horizontal_counter == `h_line_timing)
      erase_counter <= 0;

end
         

always @(posedge clk) begin         
   inside_visible_area <= (horizontal_counter >= `h_visible_offset + `h_center_offset && horizontal_counter < `h_visible_offset_end + `h_center_offset);
      
   if (horizontal_counter == `h_line_timing)    
      pass_counter <= pass_counter + 1'b1;                     /* Counts the number of vertical refresh passes, used to slow down pixel dimming (do one for every n passes) */

   prev_prev_wren_i <= prev_wren_i;                            /* Positive edge detect on a write enable signal, with additional clock to allow the signal to stabilize */
   prev_wren_i <= pixel_available;
   wren <= prev_prev_wren_i & ~prev_wren_i;
      
end     

  
endmodule
