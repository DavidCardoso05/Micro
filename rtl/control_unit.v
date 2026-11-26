`timescale 1ns/1ps

module control_unit(
    input wire [31:0] i_instr,
    input wire i_zero,
    input wire i_rs_neg, //ReadData1[31] (rs < 0); used by bgez, bgtz
    input wire i_irq_take,

    // datapath control
    output wire o_reg_write, // 1 = write register file
    output reg [1:0] o_reg_dst, // write register: 00 rt, 01 rd, 10 $31 (jal), 11 unused
    output reg o_alu_src, // 1 = extended imm, 0 = ReadData2 (rt)
    output reg [3:0] o_alu_ctrl,
    output reg o_ext_op, // 1 sign ext; 0 zero ext
    output reg o_load_byte, // 0 = word (lw); 1 = sign_extended byte (lb)
    output reg [1:0] o_wb_src, // write-back: 00 ALU result, 01 load data, 10 PC+4 (jal), 11 EPC (mfc0)
    output reg [2:0] o_pc_src, // next PC: 000 PC+4, 001 branch, 010 jump, 011 rs (jr), 100 irq vector, 101-111 reserve
    output wire o_ie_write, // 1 = di/ei writes IE; forced 0 on irq_take
    output reg o_ie_val, // new IE value = instr[5] (0 = di, 1 = ei)

    // memory control
    output wire o_mem_enable, // 1 = data memory access (lw, lb, sw); forced 0 on irq_take
    output wire o_mem_rw //1 = read (lw, lb), 0 = write (sw)
);

    //----------- opcodes ------------
    localparam OP_RTYPE = 6'h00,
            OP_REGIMM = 6'h01, // bgez (rt = 00001)
            OP_J = 6'h02,
            OP_JAL = 6'h03,
            OP_BEQ = 6'h04,
            OP_BNE = 6'h05,
            OP_BGTZ = 6'h07, // rt = 00000
            OP_ADDI = 6'h08,
            OP_XORI = 6'h0E,
            OP_LUI = 6'h0F,
            OP_COP0 = 6'h10, // mfc0, di, ei
            OP_LB = 6'h20,
            OP_LW = 6'h23,
            OP_SW = 6'h2B;

    // ---------- R type funct encodings ---------
    localparam F_SLL = 6'h00,
               F_SRL = 6'h02,
               F_JR = 6'h08,
               F_ADD = 6'h20,
               F_SUB = 6'h22,
               F_AND = 6'h24,
               F_OR = 6'h25,
               F_XOR = 6'h26,
               F_NOR = 6'h27,
               F_SLT = 6'h2A;

    // ---------- fixed fields -----------
    localparam RT_BGEZ = 5'b00001, // REGIMM sub-opcode for bgez
               RT_BGTZ = 5'b00000, // bgtz has rt = 0
               RS_MFC0 = 5'b00000, // COP0 rs = MF
               RS_MFMC0 = 5'b01011, // COP0 rs = MFMC0 (di / ei)
               RD_EPC = 5'd14, // CP0 register 14
               RD_SR = 5'b01100, // CP0 register 12 (Status), fixed field of di / ei
               SEL_0 = 3'b000;

    //--------- ALU Source -----------
    localparam ALU_AND = 4'b0000,
               ALU_OR = 4'b0001,
               ALU_ADD = 4'b0010,
               ALU_XOR = 4'b0011,
               ALU_SLL = 4'b0100,
               ALU_SRL = 4'b0101,
               ALU_SUB = 4'b0110,
               ALU_SLT = 4'b0111,
               ALU_NOR = 4'b1000,
               ALU_LUI = 4'b1010;

    // ---------- RegDst and WbSrc ---------
    localparam DST_RT = 2'b00,
            DST_RD = 2'b01,
            DST_RA = 2'b10;

    localparam WB_ALU = 2'b00,
               WB_MEM = 2'b01,
               WB_PC4 = 2'b10,
               WB_EPC = 2'b11;

    // ----------------- PcSrc codes ------------------
    localparam PC_NEXT = 3'b000, // PC + 4
               PC_BRANCH = 3'b001, // (PC + 4) + (SignExt(imm) << 2)
               PC_JUMP = 3'b010, // {(PC + 4)[31:28], index, 00}
               PC_JR = 3'b011, // rs
               PC_VECTOR = 3'b100; // interrupt


    // ---------- branch ----------
    localparam BR_NONE = 3'd0,
               BR_BEQ = 3'd1,
               BR_BNE = 3'd2,
               BR_BGEZ = 3'd3,
               BR_BGTZ = 3'd4;


    // ----- instruction fields -----
    wire [5:0] opcode = i_instr[31:26];
    wire [4:0] rs = i_instr[25:21]; // COP0 decode (MF / MFMC0)
    wire [4:0] rt = i_instr[20:16]; // REGIMM (bgez) and bgtz decode
    wire [4:0] rd = i_instr[15:11]; // COP0 register (14 EPC, 12 SR)
    wire [5:0] funct = i_instr[5:0]; // R-type funct
    wire [2:0] sel = i_instr[2:0]; // COP0 sel
    wire sc = i_instr[5]; // di = 0, ei = 1

    // ----- decoded signals, before the interrupt logic -----
    reg dec_reg_write;
    reg dec_mem_enable;
    reg dec_mem_rw;
    reg dec_ie_write;
    reg [2:0] dec_pc_src; // PC_NEXT, PC_JUMP or PC_JR (branches use dec_branch)
    reg [2:0] dec_branch; // BR_NONE .. BR_BGTZ

    //=============================
    // 1. Instruction decode
    //=============================
    always @(*) begin
        // safe defaults = nop
        dec_reg_write = 1'b0;
        o_reg_dst = DST_RT;
        o_alu_src = 1'b0;
        o_alu_ctrl = ALU_ADD;
        o_ext_op = 1'b1;
        dec_mem_enable = 1'b0;
        dec_mem_rw = 1'b1;
        o_load_byte = 1'b0;
        o_wb_src = WB_ALU;
        dec_pc_src = PC_NEXT;
        dec_branch = BR_NONE;
        dec_ie_write = 1'b0;
        o_ie_val = sc;

        case (opcode)
            OP_RTYPE: begin
                case (funct)
                    F_ADD: begin dec_reg_write = 1'b1; o_reg_dst = DST_RD; o_alu_ctrl = ALU_ADD; end
                    F_SUB: begin dec_reg_write = 1'b1; o_reg_dst = DST_RD; o_alu_ctrl = ALU_SUB; end
                    F_AND: begin dec_reg_write = 1'b1; o_reg_dst = DST_RD; o_alu_ctrl = ALU_AND; end
                    F_OR: begin dec_reg_write = 1'b1; o_reg_dst = DST_RD; o_alu_ctrl = ALU_OR; end
                    F_XOR: begin dec_reg_write = 1'b1; o_reg_dst = DST_RD; o_alu_ctrl = ALU_XOR; end
                    F_NOR: begin dec_reg_write = 1'b1; o_reg_dst = DST_RD; o_alu_ctrl = ALU_NOR; end
                    F_SLT: begin dec_reg_write = 1'b1; o_reg_dst = DST_RD; o_alu_ctrl = ALU_SLT; end
                    F_SLL: begin dec_reg_write = 1'b1; o_reg_dst = DST_RD; o_alu_ctrl = ALU_SLL; end
                    F_SRL: begin dec_reg_write = 1'b1; o_reg_dst = DST_RD; o_alu_ctrl = ALU_SRL; end
                    F_JR: dec_pc_src = PC_JR;
                    default: ; // unknown funct -> nop
                endcase
            end

            // ---------- I-type ALU ----------
            OP_ADDI: begin dec_reg_write = 1'b1; o_alu_src = 1'b1; o_alu_ctrl = ALU_ADD; end
            OP_XORI: begin dec_reg_write = 1'b1; o_alu_src = 1'b1; o_ext_op = 1'b0; o_alu_ctrl = ALU_XOR; end
            OP_LUI: begin dec_reg_write = 1'b1; o_alu_src = 1'b1; o_ext_op = 1'b0; o_alu_ctrl = ALU_LUI; end

            // ---------- loads / store (address = rs + SignExt(imm)) ----------
            OP_LW: begin
                dec_reg_write = 1'b1; o_alu_src = 1'b1; o_alu_ctrl = ALU_ADD;
                dec_mem_enable = 1'b1; dec_mem_rw = 1'b1; o_wb_src = WB_MEM;
            end
            OP_LB: begin
                dec_reg_write = 1'b1; o_alu_src = 1'b1; o_alu_ctrl = ALU_ADD;
                dec_mem_enable = 1'b1; dec_mem_rw = 1'b1; o_wb_src = WB_MEM; o_load_byte = 1'b1;
            end
            OP_SW: begin
                dec_mem_enable = 1'b1; dec_mem_rw = 1'b0; o_alu_src = 1'b1; o_alu_ctrl = ALU_ADD;
            end

            // ---------- branches: ALU computes rs - rt (sets i_zero) ----------
            OP_BEQ: begin o_alu_ctrl = ALU_SUB; dec_branch = BR_BEQ; end
            OP_BNE: begin o_alu_ctrl = ALU_SUB; dec_branch = BR_BNE; end

            OP_REGIMM: begin
                if (rt == RT_BGEZ) // bgez: only rs[31] matters
                    dec_branch = BR_BGEZ; // other rt -> nop
            end

            OP_BGTZ: begin
                if (rt == RT_BGTZ) begin // bgtz: rs - $zero
                    o_alu_ctrl = ALU_SUB; dec_branch = BR_BGTZ;
                end // other rt -> nop
            end

            // ---------- jumps ----------
            OP_J: dec_pc_src = PC_JUMP;

            OP_JAL: begin
                dec_reg_write = 1'b1; o_reg_dst = DST_RA; o_wb_src = WB_PC4;
                dec_pc_src = PC_JUMP;
            end

            // ---------- CP0 ----------
            OP_COP0: begin
                if (rs == RS_MFC0 && rd == RD_EPC && sel == SEL_0) begin
                    // mfc0 rt, $14: rt <- EPC
                    dec_reg_write = 1'b1; o_reg_dst = DST_RT; o_wb_src = WB_EPC;
                end else if (rs == RS_MFMC0 && rd == RD_SR) begin
                    // di / ei: IE <- sc (o_ie_val = sc by default)
                    dec_ie_write = 1'b1;
                end // other COP0 -> nop
            end

            default: ; // unknown opcode -> nop
        endcase
    end

    //=============================
    // 2. Branch condition
    //=============================
    reg branch_taken;
    always @(*) begin
        case (dec_branch)
            BR_BEQ: branch_taken = i_zero;
            BR_BNE: branch_taken = ~i_zero;
            BR_BGEZ: branch_taken = ~i_rs_neg;
            BR_BGTZ: branch_taken = ~i_rs_neg & ~i_zero;
            default: branch_taken = 1'b0;
        endcase
    end

    //=============================
    // 3. Outputs (interrupt wins over everything)
    //=============================
    // irq_take cancels the current instruction: no register, memory or IE write,
    // and the PC goes to the interrupt vector (EPC keeps this instruction's PC).

    //implementation of the Next PC Selection Decision Tree
    always @(*) begin
        o_pc_src = PC_NEXT; // default: PC+4
        if (i_irq_take)
            o_pc_src = PC_VECTOR; 
        else if (branch_taken) 
            o_pc_src = PC_BRANCH;
        else o_pc_src = dec_pc_src;
    end

    assign o_reg_write = dec_reg_write & ~i_irq_take;
    assign o_mem_enable = dec_mem_enable & ~i_irq_take;
    assign o_mem_rw = dec_mem_rw;
    assign o_ie_write = dec_ie_write & ~i_irq_take;

endmodule
