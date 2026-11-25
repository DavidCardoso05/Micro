`timescale 1ns/1ps

module tb_control_unit;
    // ---------- inputs ----------
    reg  [31:0] instr;
    reg         zero;
    reg         rs_neg;
    reg         irq_take;

    // ---------- outputs ----------
    wire        reg_write;
    wire [1:0]  reg_dst;
    wire        alu_src;
    wire [3:0]  alu_ctrl;
    wire        ext_op;
    wire        load_byte;
    wire [1:0]  wb_src;
    wire [2:0]  pc_src;
    wire        ie_write;
    wire        ie_val;
    wire        mem_enable;
    wire        mem_rw;

    control_unit u_control_unit (
    .i_instr      (instr),
    .i_zero       (zero),
    .i_rs_neg     (rs_neg),
    .i_irq_take   (irq_take),
    .o_reg_write  (reg_write),
    .o_reg_dst    (reg_dst),
    .o_alu_src    (alu_src),
    .o_alu_ctrl   (alu_ctrl),
    .o_ext_op     (ext_op),
    .o_load_byte  (load_byte),
    .o_wb_src     (wb_src),
    .o_pc_src     (pc_src),
    .o_ie_write   (ie_write),
    .o_ie_val     (ie_val),
    .o_mem_enable (mem_enable),
    .o_mem_rw     (mem_rw)
    );

    // ALU control codes
    localparam ALU_AND = 4'b0000;
    localparam ALU_OR  = 4'b0001;
    localparam ALU_ADD = 4'b0010;
    localparam ALU_XOR = 4'b0011;
    localparam ALU_SLL = 4'b0100;
    localparam ALU_SRL = 4'b0101;
    localparam ALU_SUB = 4'b0110;
    localparam ALU_SLT = 4'b0111;
    localparam ALU_NOR = 4'b1000;
    localparam ALU_LUI = 4'b1010;

    // Register Destiny
    localparam DST_RT = 2'b00;
    localparam DST_RD = 2'b01;
    localparam DST_RA = 2'b10;  // $31 (jal)

    // WBSrc: which data to write in register file
    localparam WB_ALU  = 2'b00;
    localparam WB_LOAD = 2'b01;
    localparam WB_PC4  = 2'b10;
    localparam WB_EPC  = 2'b11;

    // PCSrc: next PC
    localparam PC_NEXT   = 3'b000;
    localparam PC_BRANCH = 3'b001;
    localparam PC_JUMP   = 3'b010;
    localparam PC_JR     = 3'b011;
    localparam PC_IRQ    = 3'b100;  

    initial begin
        instr = 32'h0; zero = 0; rs_neg = 0; irq_take = 0;

        // =========================================
        //  MEMORY + ALU              0 ns to 70 ns     
        // ===========================================
        // Todas: pc_src = PC_NEXT, ie_write = 0

        // [0-10 ns] add $10, $8, $9   (R-type: 2 registers)
        instr = 32'h01095020;
        #10;  // reg_write = 1, reg_dst = DST_RD, alu_src = 0, alu_ctrl = ALU_ADD,
              // wb_src = WB_ALU, mem_enable = 0

        // [10-20 ns] addi $8, $0, 5   (isigned immeadiate)
        instr = 32'h20080005;
        #10;  // reg_write = 1, reg_dst = DST_RT, alu_src = 1, ext_op = 1 (signed),
              // alu_ctrl = ALU_ADD, wb_src = WB_ALU, mem_enable = 0

        // [20-30 ns] lui $13, 0x1234   (immedaite with zeros)
        instr = 32'h3C0D1234;
        #10;  // reg_write = 1, reg_dst = DST_RT, alu_src = 1, ext_op = 0 (zeros),
              // alu_ctrl = ALU_LUI, wb_src = WB_ALU, mem_enable = 0

        // [30-40 ns] xori $14, $13, 0x5678   (imediato with zeros)
        instr = 32'h39AE5678;
        #10;  // reg_write = 1, reg_dst = DST_RT, alu_src = 1, ext_op = 0 (zeros),
              // alu_ctrl = ALU_XOR, wb_src = WB_ALU, mem_enable = 0

        // [40-50 ns] lw $18, 4($0)   (read the word; address = rs + imm)
        instr = 32'h8C120004;
        #10;  // reg_write = 1, reg_dst = DST_RT, alu_src = 1, ext_op = 1, alu_ctrl = ALU_ADD,
              // mem_enable = 1, mem_rw = 1 (read), load_byte = 0, wb_src = WB_LOAD

        // [50-60 ns] lb $19, 3($0)   (read byte signed)
        instr = 32'h80130003;
        #10;  // same as lw, but load_byte = 1

        // [60-70 ns] sw $8, 8($0)   (write in memory and not in the register)
        instr = 32'hAC080008;
        #10;  // reg_write = 0, alu_src = 1, ext_op = 1, alu_ctrl = ALU_ADD,
              // mem_enable = 1, mem_rw = 0 (write

        $stop;

        // =========================================================
        // BRANCHES AND JUMPS          70 ns to 200 ns 
        // =========================================================
        // Branches: reg_write = 0, alu_ctrl = ALU_SUB (bgez: doenst use the ALU).
        // The same instt as the pc_src but different according to zero / rs_neg:
        // pc_src = PC_BRANCH (001) if taken, if not PC_NEXT (000)

        // [70-80 ns] beq $8, $9, +3   with zero = 0 ($8 != $9)
        instr = 32'h11090003; zero = 0; rs_neg = 0;
        #10;  // dont take: pc_src = PC_NEXT

        // [80-90 ns] beq $8, $9, +3   with zero = 1 ($8 == $9)
        zero = 1;
        #10;  // take: pc_src = PC_BRANCH

        // [90-100 ns] bne $8, $9, -2   with zero = 0
        instr = 32'h1509FFFE; zero = 0;
        #10;  // take: pc_src = PC_BRANCH

        // [100-110 ns] bne $8, $9, -2   with zero = 1
        zero = 1;
        #10;  // dont take: pc_src = PC_NEXT

        // [110-120 ns] bgez $8, +2   with rs_neg = 0, zero = 0
        instr = 32'h05010002; zero = 0; rs_neg = 0;
        #10;  // take: pc_src = PC_BRANCH

        // [120-130 ns] bgez $8, +2   with rs_neg = 0, zero = 1 (zero e ignorado)
        zero = 1;
        #10;  // take: pc_src = PC_BRANCH

        // [130-140 ns] bgez $8, +2   with rs_neg = 1 (rs < 0)
        zero = 0; rs_neg = 1;
        #10;  // dont take: pc_src = PC_NEXT

        // [140-150 ns] bgtz $8, +1   with rs_neg = 0, zero = 0 (rs > 0)
        instr = 32'h1D000001; zero = 0; rs_neg = 0;
        #10;  // take: pc_src = PC_BRANCH

        // [150-160 ns] bgtz $8, +1   with zero = 1 (rs = 0)
        zero = 1;
        #10;  // dont take: pc_src = PC_NEXT

        // [160-170 ns] bgtz $8, +1   with rs_neg = 1 (rs < 0)
        zero = 0; rs_neg = 1;
        #10;  // dont take: pc_src = PC_NEXT

        // [170-180 ns] j 0x80
        instr = 32'h08000020; zero = 0; rs_neg = 0;
        #10;  // reg_write = 0, pc_src = PC_JUMP

        // [180-190 ns] jal 0xC0   (save PC + 4 em $31)
        instr = 32'h0C000030;
        #10;  // reg_write = 1, reg_dst = DST_RA, wb_src = WB_PC4, pc_src = PC_JUMP

        // [190-200 ns] jr $31
        instr = 32'h03E00008;
        #10;  // reg_write = 0, pc_src = PC_JR

        $stop;

        // ================================================
        // COP0 AND INTERRUPCAO           200 ns to 290 ns 
        // ================================================

        // [200-210 ns] mfc0 $26, $14   ($26 = EPC)
        instr = 32'h401A7000;
        #10;  // reg_write = 1, reg_dst = DST_RT, wb_src = WB_EPC, pc_src = PC_NEXT, ie_write = 0

        // [210-220 ns] di   (IE = 0)
        instr = 32'h41606000;
        #10;  // reg_write = 0, ie_write = 1, ie_val = 0, pc_src = PC_NEXT

        // [220-230 ns] ei   (IE = 1)
        instr = 32'h41606020;
        #10;  // reg_write = 0, ie_write = 1, ie_val = 1, pc_src = PC_NEXT

        // ir_take = 1 cancels the intruction: pc_src = PC_IRQ and there is no write

        // [230-240 ns] sw $8, 8($0)   with irq_take = 0 
        instr = 32'hAC080008; irq_take = 0;
        #10;  // mem_enable = 1, pc_src = PC_NEXT

        // [240-250 ns] sw $8, 8($0)   with irq_take = 1
        irq_take = 1;
        #10;  // mem_enable = 0, pc_src = PC_IRQ

        // [250-260 ns] lw $18, 4($0)   with irq_take = 1
        instr = 32'h8C120004;
        #10;  // reg_write = 0, mem_enable = 0, pc_src = PC_IRQ

        // [260-270 ns] jal 0xC0   with irq_take = 1
        instr = 32'h0C000030;
        #10;  // reg_write = 0 ($31 is not writen, pc_src = PC_IRQ (nao PC_JUMP)

        // [270-280 ns] beq $8, $9, +3   zero = 1 with irq_take = 1
        instr = 32'h11090003; zero = 1;
        #10;  // pc_src = PC_IRQ: interruption wins branch

        // [280-290 ns] ei   with irq_take = 1
        instr = 32'h41606020; zero = 0;
        #10;  // ie_write = 0 (IE is not writen, pc_src = PC_IRQ

        $finish;  // 290 ns
    end

endmodule