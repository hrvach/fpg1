module cpu (
   input              clk,                         /* CPU clock input, 50 MHz */
   input              rst,                         /* Reset signal, if high reset CPU */

   /* Main memory connections */
   output reg  [11:0] MEM_ADDR,                    /* Address bus - memory address register */
   input       [17:0] DI,                          /* Data input */
   output reg  [17:0] MEM_BUFF,                    /* Data output - memory data buffer register */
   output reg         WRITE_ENABLE,                /* Write enable register */

   /* Outputs to console */
   output reg  [17:0] AC,                          /* Accumulator */
   output reg  [17:0] IO,                          /* Input Output register */
   output reg  [11:0] PC,                          /* Program counter */
   output wire [31:0] BUS_out,                     /* Multiplex various flags for console blinkenlights output */

   /* Input controllers */
   input       [17:0] gamepad_in,                  /* Input for spacewar, goes to IO register (4 LSB and 4 MSB bits act as buttons) */

   /* Output to Type 30 CRT */
   output wire  [9:0] pixel_x_out,                 /* Current column of pixel to write */
   output wire  [9:0] pixel_y_out,                 /* In what row the pixel should be written */
   output reg   [2:0] pixel_brightness,            /* Brightness, levels: 4= -3, 5= -2, 6= -1, 7= -0, 0= 0, 1= +1, 2= +2, 3= +3 */
   output reg         pixel_shift_out,             /* Signal to CRT that a pixel is to be written */

   /* Typewriter controls */
   output       [6:0] typewriter_char_out,         /* Character to be output to teletype emulation */
   output reg         typewriter_strobe_out,       /* Indicate that the character is ready to be written */

   input        [5:0] typewriter_char_in,          /* Character sent from the keyboard module (teletype) to the CPU */
   input              typewriter_strobe_in,        /* Indicator that there is a key pressed / new character to be read */
   output reg         typewriter_strobe_ack,       /* Signal the keyboard module (i.e. teletype input) that the character is read by the CPU */

   /* Paper tape connections */
   output reg         send_next_tape_char,         /* Signal the paper tape reader that it's OK to send another character */
   input              is_char_available,           /* Indicates when there is something to be read from the paper tape input word */
   input       [17:0] tape_rcv_word,               /* Word (18-bit) received from paper tape in binary mode (rpb instruction) */

   input       [11:0] start_address,               /* Address to start running the program from, that's where the JMP instruction from RIM points to */

   /* CPU configuration */
   input              hw_mul_enabled,              /* If true, hardware mul/div instructions are used, else mus/dis. Originally a switch in the PDP1 cabinet. */
   input              crt_wait,                    /* If true, when doing iot to crt device, respect wait specificed by bits 5 and 6 (12 and 11). */

   /* Console switches input */
   input       [10:0] console_switches,            /* Commands (start/stop/continue/examine etc) */
   input       [17:0] test_word,                   /* Test word switches (1-18) */
   input       [17:0] test_address,                /* Test address switches (1-12) + extension if implemented */
   input       [5:0]  sense_switches               /* Sense switches (1-6) */
   );


/* Since 50 MHz is much faster than original CPU, we can be quite generous with the clock cycles.
   There is a 250 cycle gap between read_instr_register and read_data_bus which we can simply skip
   if the instruction lasts 5 us instead of 10. */

parameter
   poweron_state              = 8'd0,
   initial_state              = 8'd4,
   read_program_counter       = 8'd31,

   read_instruction_register  = 8'd51,
   read_data_bus              = 8'd65,

   get_effective_address      = 8'd75,
   execute                    = 8'd125,
	check_instruction_duration = 8'd160,
   flush_to_ram               = 8'd214,

   cleanup                    = 8'd254;


/* Instructions, opcodes */

parameter
    i_and   = 5'o1,   i_ior   = 5'o2,    i_xor   = 5'o3,    i_xct   = 5'o4,
    i_cal   = 5'o7,   i_jda   = 5'o7,    i_lac   = 5'o10,   i_lio   = 5'o11,
    i_dac   = 5'o12,  i_dap   = 5'o13,   i_dip   = 5'o14,   i_dio   = 5'o15,
    i_dzm   = 5'o16,  i_add   = 5'o20,   i_sub   = 5'o21,   i_idx   = 5'o22,
    i_isp   = 5'o23,  i_sad   = 5'o24,   i_sas   = 5'o25,   i_mu_   = 5'o26,
    i_di_   = 5'o27,  i_jmp   = 5'o30,   i_jsp   = 5'o31,   i_skp   = 5'o32,
    i_shift = 5'o33,  i_law   = 5'o34,   i_iot   = 5'o35,   i_opr   = 5'o37;

/* Input-output device address list */

parameter
    display_crt               = 6'd7,
    read_gamepad              = 6'd9,
    read_punched_tape_alpha   = 6'd1,
    read_punched_tape_binary  = 6'd2,
    read_reader_buffer        = 6'd24,
    type_out                  = 6'd3,
    type_in                   = 6'd4,
    cks_iosta_check           = 6'd27;


//////////////////  REGISTERS  ////////////////////

reg  [17:0]  IR, PREV_IR;              /* Instruction Register, previous instruction register */
reg   [6:0]  PF = 7'b0;                /* Program Flags, 1-6 are used, flag 0 exists simply to avoid handling it as a special case */
reg   [7:0]  cpu_state;                /* Implement CPU as a State Machine, specify state the CPU is currently in. Implemented as a sequencer */
reg   [0:0]  halt = 1'b0;              /* if 1, then the cpu should not start the next cycle */
reg   [0:0]  cpu_running = 1'b1;       /* run-ff If false, well ... cpu is not running! */

reg  [11:0]  waste_cycles;             /* When non-zero, this will be decremented instead of executing anything by the CPU. Used for exact timing of instructions */

reg   [6:0]  IOSTA = 7'b0000100;       /* Stats of various IO devices, read by cks instruction (72 0033). Bit 2 is initially 1, otherwise it would never write anything out. */
reg   [4:0]  i = 5'b0;                 /* Helper register */

reg   [3:0]  num_shift = 4'b0;         /* Number of shifts in sft instruction */
reg   [5:0]  typewriter_buffer;        /* Stores incoming character from teletype emulation */

reg   [0:0]  old_typewriter_strobe_in, prev_continue_button;                  /* Registers used in positive edge detection */
reg   [0:0]  OV, CARRY, SKIP_FLAG, SKIP_REST_OF_INSTR, DIFFERENT_SIGNS;       /* Various flags, SKIP_REST_OF_INSTR will skip all phases until cpu_state rolls over */

reg [33:0] division_quotient;          /* Store results from the lpm_divide component */
reg [16:0] division_remainder;

//////////////////  FUNCTIONS  ////////////////////

function automatic [17:0] fix_zero;                               /* 1's complement is used, and two representations of zero exist. This converts -0 to +0 (all ones to all zeros). */
    input [17:0] number;
    fix_zero = (number == 18'h3ffff) ? 18'b0 : number;
endfunction

function automatic [17:0] abs;                                    /* MSB bit set means the number is negative. If so, invert all the bits to make it positive (absolute value function). */
    input [17:0] number;
    abs = (number[17]) ? ~number : number;
endfunction

function automatic [16:0] abs_nosign;                             /* Like the abs function, but removes the sign bit. */
    input [17:0] number;
    abs_nosign = (number[17]) ? ~number[16:0]: number[16:0];
endfunction


////////////////////  WIRES  //////////////////////

wire [33:0] multiply_result;

wire [33:0] division_quotient_w;
wire [16:0] division_remainder_w;

wire [33:0] multiply_input;
wire [16:0] denominator;

///////////////////  MODULES  /////////////////////

pdp1_cpu_alu_div divider(
   .in_clock(clk),
   .numer(multiply_input),
   .denom(denominator),
   .quotient(division_quotient_w),
   .remain(division_remainder_w)
   );

////////////////////  TASKS  //////////////////////

task reset_cpu;
begin
   PC           <= start_address;
   AC           <= 18'b0;
   IO           <= 18'b0;
   MEM_BUFF     <= 18'b0;
   MEM_ADDR     <= 12'b0;
   IR           <= 18'b0;
   IOSTA        <= 7'b0000100;
   PF           <= 1'b0;
   OV           <= 1'b0;
   halt         <= 1'b0;
   WRITE_ENABLE <= 1'b0;
   cpu_state    <= poweron_state;
end
endtask

task execute_instruction;
    input [4:0] opcode;
    input [0:0] indirect_addr;
    input [17:0] instruction;
    input [17:0] operand;
begin
   PREV_IR <= IR;

   /* The memory reference format is:

     0  1  2  3  4  5  6  7  8  9 10 11 12 13 14 15 16 17
   +--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+
   |      op      |in|              address              | memory reference
   +--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+

   <0:4> <5>    mnemonic        action                   */

   case (opcode)                                                  /* Instruction   Code #    Op.Time (us)   Explanation                      */

      i_and:   AC <= AC & DI;                                     /* and Y          02          10          Add C(Y) to C(AC)                */
      i_ior:   AC <= AC | DI;                                     /* ior Y          04          10          Inclusive OR C(Y) with C(AC)     */
      i_xor:   AC <= AC ^ DI;                                     /* xor Y          06          10          Exclusive OR C(Y) with C(AC)     */

      i_lac:   AC <= DI;                                          /* lac Y          20          10          Load the AC with C(Y)            */
      i_lio:   IO <= DI;                                          /* lio Y          22          10          Load IO with C(Y)                */

      i_sad:   PC <= PC + (AC != DI);                             /* sad Y          50          10          Skip next instruction if C(AC) != C(Y) */
      i_sas:   PC <= PC + (AC == DI);                             /* sas Y          52          10          Skip next instruction if C(AC) == C(Y) */

      i_xct:   { IR, MEM_BUFF } <= { 2{DI} };                     /* xct Y          10          5 + extra   Perform instruction in Y         */

      i_cal,                                                      /* cal Y          16          10          Equals JDA 100                   */
      i_jda:                                                      /* jda Y          17          10          Equals dac Y and jsp Y + 1       */
      begin
         MEM_BUFF <= AC;
         { MEM_ADDR, PC } <= { 2{ instruction[12] ? operand[11:0] : 12'o100 } };
         AC <= (OV << 17) + PC + 1'b1;
      end

      i_law:                                                      /* law N          70          5           Load the AC with the number N    */
         AC <= IR[12] ? ~{6'b0, IR[11:0]} : IR[11:0];

      /* Memory write instructions */
      /* --------------------------------------------------------------------------------------------------------------------------------------------------- */

      i_dac:   MEM_BUFF <= AC;                                    /* dac Y,         24,         10,         Put C(AC) in Y                   */
      i_dap:   MEM_BUFF <= { DI[17:12], AC[11:0] };               /* dap Y,         26,         10,         Put contents of address part of AC in Y     */
      i_dip:   MEM_BUFF[17:12] <= AC[17:12];                      /* dip Y,         30,         10,         Put contents of instruction part of AC in Y */
      i_dio:   MEM_BUFF <= IO;                                    /* dio Y,         32,         10,         Put C(IO) in Y                   */
      i_dzm:   MEM_BUFF <= 0;                                     /* dzm Y,         34,         10,         Make C(Y) zero                   */

      i_add:                                                      /* add Y,         40,         10,         Add C(Y) to C(AC                 */
      begin
         DIFFERENT_SIGNS = AC[17] ^ DI[17];

         {CARRY, AC} = AC + DI;
         AC = fix_zero(AC + CARRY);

         /* If signs were equal before the addition and now they are not, signal overflow */
         if (DIFFERENT_SIGNS == 0 && (DI[17] != AC[17]))
            OV = 1;
      end

      i_sub:                                                      /* sub Y          42          10          Subtract C(Y) from C(AC)         */
      begin
         DIFFERENT_SIGNS = AC[17] ^ DI[17];

         {CARRY, AC} = AC + (~DI);
         AC = fix_zero(AC + !CARRY);

         /* If signs were opposite before the subtraction and now they are not, signal overflow */
         if (DIFFERENT_SIGNS && (DI[17] == AC[17]))
            OV = 1;
      end

      i_idx,                                                      /* idx Y          44          10          Index (add one) C(Y) leave in Y & AC */
      i_isp:                                                      /* isp Y          46          10          Index and skip if result is positive */
      begin
         { MEM_BUFF, AC } <= {2{fix_zero(DI + 1)}};

         if (opcode == i_isp && (fix_zero(DI + 1'b1) & 18'o400000) == 12'b0)
            PC <= (PREV_IR[17:13] == i_xct) ? PREV_IR[11:0] + 1'b1 : PC + 1'b1;     /* Edge-case, if previous opcode was XCT, PC is the corresponding y + 1 */
      end


      /* Hardware multiply */
      i_mu_:

      if (hw_mul_enabled)                                         /* mul Y          54      max 25          Multiply, hardware multiply enabled                       */
      begin
         DIFFERENT_SIGNS = AC[17] ^ DI[17];

         /* Negative times negative is positive, also fix zero for a 34-bit wide result */
         if (DIFFERENT_SIGNS && (&multiply_result))
            {AC, IO} <= 36'h0;
         else
            {AC, IO} <= {DIFFERENT_SIGNS, DIFFERENT_SIGNS ? ~multiply_result : multiply_result, DIFFERENT_SIGNS};

      end

      else                                                        /* mus Y          54          10          Multiply step, hardware multiply disabled                 */
      begin
         if (IO[0]) begin
            {CARRY, AC} = AC + DI;
            AC = fix_zero(AC + CARRY);
         end

         IO = { AC[0], IO[17:1] };
         AC = AC >> 1;
      end


      i_di_:
      /* div instruction, hardware divide enabled */

      if (hw_mul_enabled)                                         /* div Y          56      max 40          Divide, hardware division enabled                         */
      begin
         DIFFERENT_SIGNS = AC[17] ^ DI[17];

         if (abs_nosign(AC) < abs_nosign(DI))   /* Only if not overflow */
         begin

            IO <= fix_zero( AC[17] ? { 1'b1, ~division_remainder_w[16:0]} : {1'b0, division_remainder_w[16:0]});

            case ({AC[17], DI[17], division_quotient_w[17]})
               3'b000, 3'b110:  AC <= fix_zero({ 1'b0,  division_quotient_w[16:0] });
               3'b001, 3'b111:  AC <= fix_zero({ 1'b0, ~division_quotient_w[16:0] });
               3'b010, 3'b100:  AC <= fix_zero({ 1'b1, ~division_quotient_w[16:0] });
               3'b101, 3'b011:  AC <= fix_zero({ 1'b1,  division_quotient_w[16:0] });
            endcase

            PC <= PC + 1'b1;

         end
         else
            OV <= 1'b1;

      end

      else
      /* dis instruction, hardware divide disabled */
      begin                                                       /* dis Y          56          10          Divide, hardware division disabled                        */
         {AC, IO} = { AC[16:0], IO, AC[17] ^ 1'b1};
         {CARRY, AC} = (IO[0] ? AC + (~DI) : AC + DI + 1'b1);
         AC = fix_zero(AC + (CARRY ^ IO[0]));
      end


      /* ---------------------------------------------------------------------------------------------------------------------------------------------------
         The I/O transfer format is:

    17 16 15 14 13 12 11 10  9  8  7  6  5  4  3  2  1  0
   +--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+
   | 1  1  1  0  1| W| C|   subopcode  |      device     | I/O transfer
   +--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+

      */
      i_iot:
      begin
         case (operand[5:0])              /* device */

         display_crt:
         begin
            pixel_shift_out <= 1'b1;
            pixel_brightness <= DI[8:6];
         end

         read_gamepad:
            IO <= gamepad_in;

         read_reader_buffer,
         read_punched_tape_binary:
         begin
            if (is_char_available)
            begin
               send_next_tape_char <= 1'b1;
               IO <= tape_rcv_word;
            end
            else
               cpu_state <= cpu_state - 4'd10;
         end

         type_out:
         begin
            IOSTA[2] <= 1'b1;                /* Set to 0 at the start of each tyo instruction, back to 1 when typewriter free to receive tyo again */
                                             /* Until artificial slow-down is implemented, typewriter is always available so IOSTA[2] can be pulled high */
            typewriter_strobe_out <= 1'b1;
         end

         type_in:
         begin
            IO <= {11'b0, ~IOSTA[3], typewriter_buffer};
            IOSTA[3] <= 1'b0;                /* Set to 0 by completion of tyi instruction */
                                             /* Set to 1 when typewriter key struck */
            typewriter_strobe_ack <= 1'b1;
         end

         cks_iosta_check:
            IO[17:12] <= { IOSTA[0], IOSTA[1], IOSTA[2], IOSTA[3], IOSTA[4], IOSTA[5] };

         endcase
      end

      /* ---------------------------------------------------------------------------------------------------------------------------------------------------
         skp Y,  opcode 64,  duration 5 us,  Skip instruction

         17 16 15 14 13 12 11 10  9  8  7  6  5  4  3  2  1  0
        +-----------------+--+--+--+--+--+--+--+--+--+--+--+--+
        | 1  1  0  1  0|  |  |  |  |  |  |  |  |  |  |  |  |  |
        +-----------------+--+--+--+--+--+--+--+--+--+--+--+--+
                         |     |  |  |  |  | \______/ \______/
                         |     |  |  |  |  |     |        |
                         |     |  |  |  |  |     |        +---- Program Flags   (szs)
                         |     |  |  |  |  |     +------------- Sense Switches  (szf)
                         |     |  |  |  |  +------------------- AC = 0          (sza)
                         |     |  |  |  +---------------------- AC >= 0         (spa)
                         |     |  |  +------------------------- AC < 0          (sma)
                         |     |  +---------------------------- OV = 0          (szo)
                         |     +------------------------------- IO >= 0         (spi)
                         +------------------------------------- invert skip
      */
      i_skp:
      begin
         SKIP_FLAG = (
               (instruction[6]   && AC == 0)                                    /* Skip on ZERO Accumulator      (sza) */
            || (instruction[7]   && AC[17] == 0)                                /* Skip on Plus Accumulator      (spa) */
            || (instruction[8]   && AC[17] == 1)                                /* Skip on Minus Accumulator     (sma) */
            || (instruction[9]   && OV == 0)                                    /* Skip on ZERO Overflow         (szo) */
            || (instruction[10]  && IO[17] == 0)                                /* Skip on Plus In-Out Register  (spi) */

            || (|instruction[2:0] && ~&instruction[2:0] && PF[instruction[2:0]] == 0)         /* Skip on ZERO Program Flag     (szf) */
            || (instruction[2:0] == 3'b111 && PF == 0)                          /* Skip on ZERO Program Flag all (szf) */

            || (|instruction[5:3] && ~&instruction[5:3] && sense_switches[6 - instruction[5:3]] == 0)  /* Skip on ZERO Switch addr 1-6   (szs) */
            || (instruction[5:3] == 3'b111 && sense_switches == 0)                          /* Skip on ZERO Switch  addr 7   (szs) */
            );

         if (instruction[12] ^ SKIP_FLAG) /* If 6-th bit (DEC notation) is 1 and skip flag 0, or vice-versa */
            PC <= (PREV_IR[17:13] == i_xct) ? PREV_IR[11:0] + 1'b1 : PC + 1'b1;  /* Edge-case, if previous opcode was XCT, PC is the corresponding y + 1 */

         if (operand[9])
            OV <= 0;

      end

      /* ---------------------------------------------------------------------------------------------------------------------------------------------------
         sft Y          66          5           Shift instructions
         The shift format is:

    17 16 15 14 13 12 11 10  9  8  7  6  5  4  3  2  1  0
   +--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+
   | 1  1  0  1  1| subopcode |      encoded count       | shift
   +--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+          */

      i_shift:
      begin
         /* num_shift is the number of high bits in instruction word bits 9-17 (DEC notation) - encoded count */
         num_shift = DI[8] + DI[7] + DI[6] + DI[5] + DI[4] + DI[3] + DI[2] + DI[1] + DI[0];

         for (i=0; i<num_shift; i=i+1'b1)
            begin
               case (operand[17:9] & 9'o777)

               9'o661:  /* Rotate Accumulator Left                      (ral) */
                  AC = {AC[16:0], AC[17]};

               9'o662:  /* Rotate IO Left                               (ril) */
                  IO = {IO[16:0], IO[17]};

               9'o663:  /* Rotate AC and IO Left                        (rcl) */
                  {AC, IO} = { AC[16:0], IO, AC[17] };

               9'o665:  /* Shift Accumulator Left                       (sal) */
                  AC = { AC[17], AC[15:0], AC[17] };

               9'o666:  /* Shift In-Out Register Left                   (sil) */
                  IO = { IO[17], IO[15:0], IO[17] };

               9'o667:  /* Shift AC and IO Left                         (scl) */
                  {AC, IO} = {AC[17], AC[15:0], IO, AC[17]};

               9'o671:  /* Rotate Accumulator Right                     (rar) */
                  AC = {AC[0], AC[17:1]};

               9'o672:  /* Rotate IO Right                              (rir) */
                  IO = {IO[0], IO[17:1]};

               9'o673:  /* Rotate AC and IO Right                       (rcr) */
                  {AC, IO} = { IO[0], AC, IO[17:1] };

               9'o675:  /* Shift Accumulator Right                      (sar) */
                  AC = { AC[17], AC[17:1] };

               9'o676:  /* Shift In-Out Register Right                  (sir) */
                  IO = { IO[17], IO[17:1] };

               9'o677:  /* Shift AC and IO Right                        (scr) */
                  {AC, IO} = {AC[17], AC[17:0], IO[17:1]};

               endcase
            end
      end

      /* The operate format:

    17 16 15 14 13 12 11 10  9  8  7  6  5  4  3  2  1  0
   +--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+
   | 1  1  1  1  1|  |  |  |  |  |  |  |  |  |  |  |  |  | operate
   +--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+
                    |  |  |  |  |  |  |  |  |  | \______/
                    |  |  |  |  |  |  |  |  |  |     |
                    |  |  |  |  |  |  |  |  |  |     +---- PF select
                    |  |  |  |  |  |  |  |  |  +---------- clear/set PF
                    |  |  |  |  |  |  |  |  +------------- LIA (PDP-1D)
                    |  |  |  |  |  |  |  +---------------- LAI (PDP-1D)
                    |  |  |  |  |  |  +------------------- or PC
                    |  |  |  |  |  +---------------------- CLA
                    |  |  |  |  +------------------------- halt
                    |  |  |  +---------------------------- CMA
                    |  |  +------------------------------- or TW
                    |  +---------------------------------- CLI
                    +------------------------------------- CMI (PDP-1D)   */

      i_opr:
      begin
         if (DI[10] && DI[7]) AC <= test_word;                 /* Loads test word switches in Accumulator */
         else if (DI[10] && !DI[7]) AC <= AC | test_word;      /* OR test word switches with existing Accumulator value */
         else if (DI[9] && DI[7]) AC <= 18'h3ffff;             /* If both flags are set, we need to perform cla and cma operations (which make accumulator equal to 0x3ffff) */
         else if (DI[7]) AC <= 0;                              /* Clear Accumulator (cla, Address 200, 5 uSec) */
         else if (DI[9]) AC <= ~AC;                            /* Complement Accumulator (cma, Address 1000, 5 usec) */

         if (DI[4]) IO <= AC;                                  /* Load IO from Accumulator (lia, Address 20, 5 usec) */
         if (DI[5]) AC <= IO;                                  /* Load Accumulator from IO (lai, Address 40, 5 usec) */
                                                               /* Swap Accumulator and IO  (swp, Address 40, 5 usec) - implemented simply by executing both of these ifs */

         if (DI[11]) IO <= 0;                                  /* Clear In-Out Register (cli, Address 4000, 5 usec) */
         if (DI[8]) halt <= 1;                                 /* Stops the computer, (hlt, Address 400) - temporarily disabled  */

         /* PF select, 1-7. 1-6 sets/clears individual flags, 7 does them all.
            PF[0] exists simply to avoid handling it as a special case, it is not used  */

         if (operand[2:0] == 3'd7)                             /* Set and clear program flag (clf / stf) 5 usec */
            PF = operand[3] ? 6'b111111 : 6'b000000 ;          /* Address 07 clears / sets all program flags */
         else
            PF[operand[2:0]] = operand[3];

      end

      i_jmp: PC <= operand[11:0];
      i_jsp:
         begin
            AC <= {OV, 5'b0, PC + 1'b1};
            PC <= operand[11:0];
         end

      default:
         SKIP_REST_OF_INSTR <= 1'b1;

   endcase
end
endtask


/////////////////  ASSIGNMENTS  ///////////////////

assign denominator     = (DI[17] ? (~(DI[16:0])) : DI[16:0]);
assign multiply_input  = AC[17] ? { ~AC[16:0], ~IO[17:1] } : { AC[16:0], IO[17:1] };

assign multiply_result = abs_nosign(AC) * abs_nosign(DI);

assign pixel_x_out = IO[17:8] + 10'd512;
assign pixel_y_out = AC[17:8] + 10'd512;

assign typewriter_char_out = IO[5:0];

assign BUS_out[19:0] = { cpu_running && ~`power_switch, OV, IR[17:13], PF[6:1], sense_switches[5:0] };


/////////////////  MAIN BLOCK  ////////////////////

/* 50 MHz input clock = 20 ns period. Instructions last 5 or 10 uS (250 or 500 clocks), so we have time to spare. */
always @(posedge clk) begin
   old_typewriter_strobe_in <= typewriter_strobe_in;                          /* Store old values for positive edge detection */
   prev_continue_button <= `continue_button;

   pixel_shift_out <= 1'b0;

   if (`stop_button || halt) begin
      cpu_running <= 1'b0;
      halt <= 1'b0;
   end

   if (`continue_button || `start_button) // && SP_4
      cpu_running <= 1'b1;

   /* If we are in single instruction mode, remain in initial_state until continue is pressed, then get stuck again in next initial_state */
   if (cpu_state == initial_state && `single_inst_switch)
      cpu_state <=  (~prev_continue_button && `continue_button) ? cpu_state + 1'b1 : initial_state ;

   else if (cpu_state == initial_state && waste_cycles)                       /* If non-zero, it will keep decrementing until zero rather than execute anything. Used to fine-tune instruction duration */
      waste_cycles <= waste_cycles - 1'b1;

   else if (cpu_state == cleanup + 1'b1)                                      /* If skip rest of instruction flag active, this makes sure it overflows to initial state, not poweron state */
      cpu_state <= initial_state;

   else
      cpu_state <= cpu_state + 1'b1;


   /* Typewriter positive edge transition sets these registers, i.e. on every char received */
   if (~old_typewriter_strobe_in && typewriter_strobe_in) begin
      PF[1] = 1'b1;
      IOSTA[3] <= 1'b1;
      typewriter_buffer <= typewriter_char_in;
   end

   /* ************************************** */

   if (rst)                                     /* If reset signal is high, hold the CPU in reset */
      reset_cpu();

   else if (`start_button)                      /* Pressing start button puts address set by test address switches in program counter */
      PC <= test_address[11:0];

   else if (~cpu_running && ~`power_switch) begin                 /* If CPU is stopped, enable reading and writing memory through console switches */
      WRITE_ENABLE <= `deposit_button;
      if (`deposit_button) begin
         MEM_ADDR <= test_address[11:0];
         MEM_BUFF <= test_word;
      end

      if (`examine_button)
         MEM_ADDR <= test_address[11:0];
   end

   else if (!SKIP_REST_OF_INSTR || cpu_state == initial_state) begin  /* Don't do any of this if SKIP_REST_OF_INSTR is set, except when we reach the next initial state */
      SKIP_REST_OF_INSTR <= 1'b0;                                       /* Set this to false by default, set to true when needed */

      case (cpu_state)
         poweron_state:              PC        <= start_address;

         read_program_counter:       MEM_ADDR  <= PC;
         read_instruction_register:  IR        <= DI;                   /* Make sure the opcode remains in IR even after several cycles of indirect addressing */

         read_data_bus:              MEM_BUFF  <= DI;

         get_effective_address:
            /* Check if we are processing instruction with memory addressing and get effective address in that case */
            case (IR[17:13])
               i_and, i_ior, i_xor, i_xct, i_lac, i_lio, i_dac,
               i_dap, i_dip, i_dio, i_dzm, i_add, i_sub, i_idx,
               i_isp, i_sad, i_sas, i_mu_, i_di_, i_jmp, i_jsp:
                  begin
                     MEM_ADDR <= MEM_BUFF[11:0];

                     /* If indirect addressing, go to 2 clocks before read_data_bus state after we set the
                        MEM_ADDR (address bus) so the memory value has enough time to be clocked onto the data bus.
                        If not, increment current microcode cycle counter and wait for it to reach execute. */

                     cpu_state <= (MEM_BUFF[12] == 1'b1) ? read_data_bus - 2'd2: cpu_state + 1'b1;
                  end
            endcase

         execute:
            begin
               execute_instruction(IR[17:13], IR[12], IR, MEM_BUFF);    /* MEM_BUFF now contains memory[y] */

               case (IR[17:13])
                  i_jmp, i_jsp:  SKIP_REST_OF_INSTR <= 1'b1;
                  i_xct:         cpu_state <= read_data_bus - 3'd8;
               endcase
            end

         check_instruction_duration:
            case (IR[17:13])
               i_shift, i_jmp, i_law, i_xct, i_jsp, i_skp, i_opr:
                  waste_cycles <= 12'd0;                                         /* Waste no cycles, these instructions last only 5 us */
               i_mu_:
                  waste_cycles <= hw_mul_enabled ? 12'd1000 : 12'd250;           /* Waste additional 1000 cycles * 20 ns = +20 us if hw mul enabled, otherwise +5 us */
               i_di_:
                  waste_cycles <= hw_mul_enabled ? 12'd1750 : 12'd250;           /* Waste additional 1750 cycles * 20 ns = +35 us if hw div enabled, otherwise +5 us */
               i_iot:
                  waste_cycles <= (crt_wait && (MEM_BUFF[5:0] == display_crt))   /* Waste additional 2250 cycles * 20 ns = +45 us if writing to CRT, wait is specified and enabled in menu, otherwise +5 us */
                                 ? 12'd2250 : 12'd0;
               default:
                  waste_cycles <= 12'd250;                                       /* Waste additional 250 cycles * 20 ns = +5 us */
            endcase

         flush_to_ram:
            /* These opcodes need to write to memory, set WE high so the value gets written. */
            case (IR[17:13])
               i_dac, i_dap, i_dip, i_dio, i_dzm, i_idx, i_cal, i_jda, i_isp:
                  WRITE_ENABLE <= 1'b1;
            endcase

         cleanup:
            begin
               typewriter_strobe_ack <= 1'b0;
               typewriter_strobe_out <= 1'b0;
               send_next_tape_char <= 1'b0;
               WRITE_ENABLE <= 1'b0;
               PC <= PC + 1'b1;
               cpu_state <= initial_state;
            end
      endcase
   end
end

endmodule
