`timescale 1ns / 1ps

// Control Unit (spec rev 3, section 6)
// Purely combinational. Three stages, each in its own block:
//
//   1. Instruction decode: the control word as a function of the
//      instruction fields only (no status signals).
//   2. Branch condition (spec 6.1): uses the status signals i_zero and
//      i_rs_neg to decide if a branch is taken.
//   3. Next-PC select and interrupt cancellation (spec 10.2): when
//      i_irq_take = 1 the instruction at PC is cancelled (no register,
//      memory or IE write, no memory read) and PCSrc selects the vector.
//
// Unknown encodings (opcode, funct, REGIMM rt, bgtz rt, COP0 fields)
// behave as nop: no writes, PCSrc = PC + 4.

module control_unit (
    // ---------- instruction fields ----------
    input  wire [5:0] i_opcode,     // instr[31:26]
    input  wire [4:0] i_rs,         // instr[25:21]  COP0 decode
    input  wire [4:0] i_rt,         // instr[20:16]  REGIMM (bgez) and bgtz decode
    input  wire [4:0] i_rd,         // instr[15:11]  COP0 decode
    input  wire [5:0] i_funct,      // instr[5:0]    R-type funct; COP0 sel = [2:0], sc = [5]

    // ---------- status signals (datapath -> CU) ----------
    input  wire       i_zero,       // ALU result == 0
    input  wire       i_rs_neg,     // rs[31], straight from register-file port A
    input  wire       i_irq_take,   // Phase 2: i_irq & ie_r & ~ei_shadow_r (0 in Phase 1)

    // ---------- control word (CU -> datapath) ----------
    output wire       o_reg_write,
    output reg  [1:0] o_reg_dst,    // 00: rt, 01: rd, 10: $31
    output reg        o_alu_src,    // 0: rt, 1: extended immediate
    output reg  [3:0] o_alu_ctrl,
    output reg        o_ext_op,     // 0: zero extend, 1: sign extend
    output wire       o_mem_read,
    output wire       o_mem_write,
    output reg        o_load_byte,  // 0: lw (whole word), 1: lb (sign-extended byte)
    output reg  [1:0] o_wb_src,     // 00: ALU, 01: load-ext, 10: PC + 4, 11: EPC
    output reg  [2:0] o_pc_src,     // see PC_* below
    output wire       o_ie_we,      // di / ei write IE
    output reg        o_ie_val      // value written to IE (= instr[5])
);

    // ---------- opcodes (spec 4.3) ----------
    localparam OP_RTYPE  = 6'h00,
               OP_REGIMM = 6'h01,   // bgez (rt = 00001)
               OP_J      = 6'h02,
               OP_JAL    = 6'h03,
               OP_BEQ    = 6'h04,
               OP_BNE    = 6'h05,
               OP_BGTZ   = 6'h07,   // rt = 00000
               OP_ADDI   = 6'h08,
               OP_XORI   = 6'h0E,
               OP_LUI    = 6'h0F,
               OP_COP0   = 6'h10,   // mfc0, di, ei
               OP_LB     = 6'h20,
               OP_LW     = 6'h23,
               OP_SW     = 6'h2B;

    // ---------- R-type funct ----------
    localparam F_SLL = 6'h00,
               F_SRL = 6'h02,
               F_JR  = 6'h08,
               F_ADD = 6'h20,
               F_SUB = 6'h22,
               F_AND = 6'h24,
               F_OR  = 6'h25,
               F_XOR = 6'h26,
               F_NOR = 6'h27,
               F_SLT = 6'h2A;

    // ---------- fixed fields ----------
    localparam RT_BGEZ  = 5'b00001,  // REGIMM sub-opcode for bgez
               RT_BGTZ  = 5'b00000,  // bgtz has rt = 0
               RS_MFC0  = 5'b00000,  // COP0 rs = MF
               RS_MFMC0 = 5'b01011,  // COP0 rs = MFMC0 (di / ei)
               RD_EPC   = 5'd14,     // CP0 register 14
               RD_SR    = 5'd12,     // CP0 register 12 (Status), fixed field of di / ei
               SEL_0    = 3'b000;

    // ---------- ALUCtrl (spec 7) ----------
    localparam ALU_AND = 4'b0000,
               ALU_OR  = 4'b0001,
               ALU_ADD = 4'b0010,
               ALU_XOR = 4'b0011,
               ALU_SLL = 4'b0100,
               ALU_SRL = 4'b0101,
               ALU_SUB = 4'b0110,
               ALU_SLT = 4'b0111,
               ALU_NOR = 4'b1000,
               ALU_LUI = 4'b1010;

    // ---------- RegDst / WBSrc / PCSrc codes ----------
    localparam DST_RT = 2'b00,
               DST_RD = 2'b01,
               DST_RA = 2'b10;

    localparam WB_ALU = 2'b00,
               WB_MEM = 2'b01,
               WB_PC4 = 2'b10,
               WB_EPC = 2'b11;

    localparam PC_NEXT   = 3'b000,   // PC + 4
               PC_BRANCH = 3'b001,   // (PC + 4) + (SignExt(imm) << 2)
               PC_JUMP   = 3'b010,   // {(PC + 4)[31:28], index, 00}
               PC_JR     = 3'b011,   // rs
               PC_VECTOR = 3'b100;   // interrupt vector (Phase 2)

    // ---------- branch kinds (internal) ----------
    localparam BR_NONE = 3'd0,
               BR_BEQ  = 3'd1,
               BR_BNE  = 3'd2,
               BR_BGEZ = 3'd3,
               BR_BGTZ = 3'd4;

    // decoded write/read enables, before interrupt cancellation
    reg       dec_reg_write;
    reg       dec_mem_read;
    reg       dec_mem_write;
    reg       dec_ie_we;
    reg [2:0] dec_pc_src;            // PC source when no branch is taken
    reg [2:0] dec_branch;            // which branch condition to test
    reg       branch_taken;

    // ================================================================
    // 1. Instruction decode (instruction fields only)
    // ================================================================
    always @(*) begin
        // safe defaults = nop
        dec_reg_write = 1'b0;
        o_reg_dst     = DST_RT;
        o_alu_src     = 1'b0;
        o_alu_ctrl    = ALU_ADD;
        o_ext_op      = 1'b1;
        dec_mem_read  = 1'b0;
        dec_mem_write = 1'b0;
        o_load_byte   = 1'b0;
        o_wb_src      = WB_ALU;
        dec_pc_src    = PC_NEXT;
        dec_branch    = BR_NONE;
        dec_ie_we     = 1'b0;
        o_ie_val      = 1'b0;

        case (i_opcode)
            OP_RTYPE: begin
                case (i_funct)
                    F_ADD: begin dec_reg_write = 1'b1; o_reg_dst = DST_RD; o_alu_ctrl = ALU_ADD; end
                    F_SUB: begin dec_reg_write = 1'b1; o_reg_dst = DST_RD; o_alu_ctrl = ALU_SUB; end
                    F_AND: begin dec_reg_write = 1'b1; o_reg_dst = DST_RD; o_alu_ctrl = ALU_AND; end
                    F_OR:  begin dec_reg_write = 1'b1; o_reg_dst = DST_RD; o_alu_ctrl = ALU_OR;  end
                    F_XOR: begin dec_reg_write = 1'b1; o_reg_dst = DST_RD; o_alu_ctrl = ALU_XOR; end
                    F_NOR: begin dec_reg_write = 1'b1; o_reg_dst = DST_RD; o_alu_ctrl = ALU_NOR; end
                    F_SLT: begin dec_reg_write = 1'b1; o_reg_dst = DST_RD; o_alu_ctrl = ALU_SLT; end
                    F_SLL: begin dec_reg_write = 1'b1; o_reg_dst = DST_RD; o_alu_ctrl = ALU_SLL; end
                    F_SRL: begin dec_reg_write = 1'b1; o_reg_dst = DST_RD; o_alu_ctrl = ALU_SRL; end
                    F_JR:  dec_pc_src = PC_JR;
                    default: ;                                    // unknown funct -> nop
                endcase
            end

            // ---------- I-type ALU ----------
            OP_ADDI: begin dec_reg_write = 1'b1; o_alu_src = 1'b1;                  o_alu_ctrl = ALU_ADD; end
            OP_XORI: begin dec_reg_write = 1'b1; o_alu_src = 1'b1; o_ext_op = 1'b0; o_alu_ctrl = ALU_XOR; end
            OP_LUI:  begin dec_reg_write = 1'b1; o_alu_src = 1'b1; o_ext_op = 1'b0; o_alu_ctrl = ALU_LUI; end

            // ---------- loads / store (address = rs + SignExt(imm)) ----------
            OP_LW: begin
                dec_reg_write = 1'b1; o_alu_src = 1'b1; o_alu_ctrl = ALU_ADD;
                dec_mem_read  = 1'b1; o_wb_src  = WB_MEM;
            end
            OP_LB: begin
                dec_reg_write = 1'b1; o_alu_src = 1'b1; o_alu_ctrl = ALU_ADD;
                dec_mem_read  = 1'b1; o_wb_src  = WB_MEM; o_load_byte = 1'b1;
            end
            OP_SW: begin
                dec_mem_write = 1'b1; o_alu_src = 1'b1; o_alu_ctrl = ALU_ADD;
            end

            // ---------- branches: ALU computes rs - rt (sets i_zero) ----------
            OP_BEQ: begin o_alu_ctrl = ALU_SUB; dec_branch = BR_BEQ; end
            OP_BNE: begin o_alu_ctrl = ALU_SUB; dec_branch = BR_BNE; end
            OP_REGIMM: begin
                if (i_rt == RT_BGEZ) begin                        // bgez: only rs[31] matters
                    o_alu_ctrl = ALU_SUB; dec_branch = BR_BGEZ;
                end                                               // other rt -> nop
            end
            OP_BGTZ: begin
                if (i_rt == RT_BGTZ) begin                        // bgtz: rs - $zero
                    o_alu_ctrl = ALU_SUB; dec_branch = BR_BGTZ;
                end                                               // other rt -> nop
            end

            // ---------- jumps ----------
            OP_J:   dec_pc_src = PC_JUMP;
            OP_JAL: begin
                dec_reg_write = 1'b1; o_reg_dst = DST_RA; o_wb_src = WB_PC4;
                dec_pc_src    = PC_JUMP;
            end

            // ---------- COP0 ----------
            OP_COP0: begin
                if (i_rs == RS_MFC0 && i_rd == RD_EPC && i_funct[2:0] == SEL_0) begin
                    dec_reg_write = 1'b1; o_reg_dst = DST_RT; o_wb_src = WB_EPC;   // mfc0 rt, $14
                end else if (i_rs == RS_MFMC0 && i_rd == RD_SR) begin
                    dec_ie_we = 1'b1; o_ie_val = i_funct[5];                     // di (0) / ei (1)
                end                                                              // other -> nop
            end

            default: ;                                            // unknown opcode -> nop
        endcase
    end

    // ================================================================
    // 2. Branch condition (spec 6.1)
    // ================================================================
    always @(*) begin
        branch_taken = 1'b0;
        case (dec_branch)
            BR_BEQ:  branch_taken =  i_zero;                      // rs == rt
            BR_BNE:  branch_taken = ~i_zero;                      // rs != rt
            BR_BGEZ: branch_taken = ~i_rs_neg;                    // rs >= 0
            BR_BGTZ: branch_taken = ~i_rs_neg & ~i_zero;          // rs >  0
            default: branch_taken = 1'b0;
        endcase
    end

    // ================================================================
    // 3. Next-PC select and interrupt cancellation
    // ================================================================
    always @(*) begin
        o_pc_src = dec_pc_src;
        if (i_irq_take)
            o_pc_src = PC_VECTOR;
        else if (branch_taken)
            o_pc_src = PC_BRANCH;
    end

    // A cancelled instruction leaves no trace. MemRead is also cancelled,
    // because an MMIO read can have side effects (e.g. popping a UART FIFO).
    assign o_reg_write = dec_reg_write & ~i_irq_take;
    assign o_mem_read  = dec_mem_read  & ~i_irq_take;
    assign o_mem_write = dec_mem_write & ~i_irq_take;
    assign o_ie_we     = dec_ie_we     & ~i_irq_take;

endmodule
