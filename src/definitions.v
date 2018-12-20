/* 1280 x 1024 @ 60 Hz constants  */

`define   h_front_porch          11'd48
`define   h_back_porch           11'd248
        
`define   h_sync_pulse           11'd112
            
`define   v_sync_pulse           11'd3
`define   v_front_porch          11'd1
`define   v_back_porch           11'd38
            
`define   h_line_timing          11'd1688
`define   v_line_timing          11'd1066
            
`define   h_visible_offset       11'd408
`define   h_center_offset        11'd128
`define   h_visible_offset_end   11'd1432
            
`define   v_visible_offset       11'd42
`define   v_visible_offset_end   11'd1066


/* Joystick, defined in core configuration string as 
   "J,Left,Right,Thrust,Fire,HyperSpace;", therefore:
*/

`define   joystick_left          5'd4
`define   joystick_right         5'd5
`define   joystick_thrust        5'd6
`define   joystick_fire          5'd7
`define   joystick_hyperspace    5'd8


/* Outputs */

`define   output_crt             2'b00
`define   output_console         2'b01
`define   output_teletype        2'b10

/* Status options */

`define  menu_enable_rim            status[5]
`define  menu_disable_rim           status[6]
`define  menu_reset                 status[7]
`define  menu_aspect_ratio          status[1]
`define  menu_hardware_multiply     status[4]
`define  menu_variable_brightness   status[8]
`define  menu_crt_wait              status[9]


/* Console switches */

`define  start_button               console_switches[0]
`define  stop_button                console_switches[1]
`define  continue_button            console_switches[2]
`define  examine_button             console_switches[3]
`define  deposit_button             console_switches[4]
`define  readin_button              console_switches[5]
`define  reader_button              console_switches[6]
`define  tapefeed_button            console_switches[7]

`define  single_inst_switch         console_switches[8]
`define  single_step_switch         console_switches[9]
`define  power_switch               console_switches[10]


/* Teletype special characters */

`define  lowercase                  6'o72
`define  uppercase                  6'o74
`define  carriage_return            6'o77
