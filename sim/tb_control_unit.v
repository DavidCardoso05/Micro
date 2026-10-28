`timescale 1ns / 1ps

// Self-checking testbench for control_unit (spec rev 3, section 6)
// Part 1: every instruction of the ISA. Non-branch instructions are
//         checked for all 4 combinations of (i_zero, i_rs_neg): their
//         control word must not depend on the status signals.
// Part 2: branches. The taken / not-taken decision is checked for all
//         4 combinations of (i_zero, i_rs_neg).
// Part 3: interrupt cancellation (i_irq_take = 1, Phase 2).
// Part 4: named encodings outside the ISA must behave as nop.
// Part 5: sweeps over every opcode, every R-type funct, every REGIMM /
//         bgtz rt and every COP0 rs/rd/sel/sc combination.
// Prints "ALL TESTS PASSED" or "SOME TESTS FAILED" at the end.

module tb_control_unit;

    // ---------- DUT signals ----------
    reg  [31:0] instr;
    reg         zero;
    reg         rs_neg;
    reg         irq_take;

    wire        reg_write;
    wire [1:0]  reg_dst;
    wire        alu_src;
    wire [3:0]  alu_ctrl;
    wire        ext_op;
    wire        mem_read;
    wire        mem_write;
    wire        load_byte;
    wire [1:0]  wb_src;
    wire [2:0]  pc_src;
    wire        ie_we;
    wire        ie_val;

    control_unit u_cu (
        .i_opcode    (instr[31:26]),
        .i_rs        (instr[25:21]),
        .i_rt        (instr[20:16]),
        .i_rd        (instr[15:11]),
        .i_funct     (instr[5:0]),
        .i_zero      (zero),
        .i_rs_neg    (rs_neg),
        .i_irq_take  (irq_take),
        .o_reg_write (reg_write),
        .o_reg_dst   (reg_dst),
        .o_alu_src   (alu_src),
        .o_alu_ctrl  (alu_ctrl),
        .o_ext_op    (ext_op),
        .o_mem_read  (mem_read),
        .o_mem_write (mem_write),
        .o_load_byte (load_byte),
        .o_wb_src    (wb_src),
        .o_pc_src    (pc_src),
        .o_ie_we     (ie_we),
        .o_ie_val    (ie_val)
    );

    // Whole control word in one vector (19 bits), in the order of the check columns.
    wire [18:0] cw = {reg_write, reg_dst, alu_src, ext_op, mem_read, mem_write,
                      load_byte, wb_src, pc_src, alu_ctrl, ie_we, ie_val};

    // "Does nothing": no writes, no memory read, PC + 4.
    wire nop_now = ~reg_write & ~mem_read & ~mem_write & ~ie_we & (pc_src == 3'b000);

    // ---------- codes (spec 6, 6.2, 7) ----------
    localparam ALU_AND = 4'b0000, ALU_OR  = 4'b0001, ALU_ADD = 4'b0010,
               ALU_XOR = 4'b0011, ALU_SLL = 4'b0100, ALU_SRL = 4'b0101,
               ALU_SUB = 4'b0110, ALU_SLT = 4'b0111, ALU_NOR = 4'b1000,
               ALU_LUI = 4'b1010;

    localparam DST_RT = 2'b00, DST_RD = 2'b01, DST_RA = 2'b10;
    localparam WB_ALU = 2'b00, WB_MEM = 2'b01, WB_PC4 = 2'b10, WB_EPC = 2'b11;
    localparam PC_NEXT = 3'b000, PC_BRANCH = 3'b001, PC_JUMP = 3'b010,
               PC_JR   = 3'b011, PC_VECTOR = 3'b100;

    // short names for "don't care" in the tables below
    localparam [0:0] X1 = 1'bx;
    localparam [1:0] X2 = 2'bxx;
    localparam [3:0] X4 = 4'bxxxx;

    // ---------- encoding helpers ----------
    function [31:0] r_type;
        input [4:0] rs, rt, rd, shamt;
        input [5:0] funct;
        r_type = {6'h00, rs, rt, rd, shamt, funct};
    endfunction

    function [31:0] i_type;
        input [5:0]  op;
        input [4:0]  rs, rt;
        input [15:0] imm;
        i_type = {op, rs, rt, imm};
    endfunction

    function [31:0] j_type;
        input [5:0]  op;
        input [25:0] index;
        j_type = {op, index};
    endfunction

    // ---------- compare with don't cares ----------
    // 1 when every bit of exp that is not x matches act.
    function match;
        input [18:0] act;
        input [18:0] exp;
        integer k;
        begin
            match = 1'b1;
            for (k = 0; k < 19; k = k + 1)
                if (exp[k] !== 1'bx && act[k] !== exp[k])
                    match = 1'b0;
        end
    endfunction

    integer n_pass = 0;
    integer n_fail = 0;

    task report;
        input [8*40-1:0] name;
        input [31:0]     word;
        input integer    errs;
        begin
            if (errs == 0) begin
                n_pass = n_pass + 1;
                $display("PASS  %0s (%h)", name, word);
            end else begin
                n_fail = n_fail + 1;
                $display("FAIL  %0s (%h)", name, word);
            end
        end
    endtask

    task show_mismatch;
        input [18:0] exp;
        begin
            $display("      zero=%b rs_neg=%b irq_take=%b", zero, rs_neg, irq_take);
            $display("      got:      rw=%b dst=%b asrc=%b ext=%b mr=%b mw=%b lb=%b wb=%b pc=%b alu=%b iewe=%b ieval=%b",
                     cw[18], cw[17:16], cw[15], cw[14], cw[13], cw[12], cw[11],
                     cw[10:9], cw[8:6], cw[5:2], cw[1], cw[0]);
            $display("      expected: rw=%b dst=%b asrc=%b ext=%b mr=%b mw=%b lb=%b wb=%b pc=%b alu=%b iewe=%b ieval=%b",
                     exp[18], exp[17:16], exp[15], exp[14], exp[13], exp[12], exp[11],
                     exp[10:9], exp[8:6], exp[5:2], exp[1], exp[0]);
        end
    endtask

    // ---------- Part 1: one instruction, all 4 status combinations ----------
    task check;
        input [8*40-1:0] name;
        input [31:0]     word;
        input            e_rw;
        input [1:0]      e_dst;
        input            e_asrc;
        input            e_ext;
        input            e_mr;
        input            e_mw;
        input            e_lb;
        input [1:0]      e_wb;
        input [2:0]      e_pc;
        input [3:0]      e_alu;
        input            e_iewe;
        input            e_ieval;
        reg   [18:0]     exp;
        integer          s, errs;
        begin
            exp = {e_rw, e_dst, e_asrc, e_ext, e_mr, e_mw, e_lb, e_wb, e_pc, e_alu, e_iewe, e_ieval};
            errs = 0;
            instr = word; irq_take = 1'b0;
            for (s = 0; s < 4; s = s + 1) begin
                {zero, rs_neg} = s;
                #1;
                if (!match(cw, exp)) begin
                    errs = errs + 1;
                    if (errs == 1) show_mismatch(exp);
                end
            end
            report(name, word, errs);
        end
    endtask

    // ---------- Part 2: one branch, all 4 status combinations ----------
    // taken[{zero, rs_neg}] = 1 when the branch must be taken.
    task check_branch;
        input [8*40-1:0] name;
        input [31:0]     word;
        input [3:0]      taken;
        reg   [18:0]     exp;
        integer          s, errs;
        begin
            errs = 0;
            instr = word; irq_take = 1'b0;
            for (s = 0; s < 4; s = s + 1) begin
                {zero, rs_neg} = s;
                //     rw    dst  asrc  ext   mr    mw    lb  wb  pc                                 alu      iewe  ieval
                exp = {1'b0, X2,  1'b0, 1'b1, 1'b0, 1'b0, X1, X2, (taken[s] ? PC_BRANCH : PC_NEXT), ALU_SUB, 1'b0, X1};
                #1;
                if (!match(cw, exp)) begin
                    errs = errs + 1;
                    if (errs == 1) show_mismatch(exp);
                end
            end
            report(name, word, errs);
        end
    endtask

    // ---------- Part 3: interrupt taken -> instruction cancelled ----------
    task check_irq;
        input [8*40-1:0] name;
        input [31:0]     word;
        reg   [18:0]     exp;
        integer          s, errs;
        begin
            //     rw    dst asrc ext mr    mw    lb  wb  pc         alu iewe  ieval
            exp = {1'b0, X2, X1,  X1, 1'b0, 1'b0, X1, X2, PC_VECTOR, X4, 1'b0, X1};
            errs = 0;
            instr = word; irq_take = 1'b1;
            for (s = 0; s < 4; s = s + 1) begin
                {zero, rs_neg} = s;
                #1;
                if (!match(cw, exp)) begin
                    errs = errs + 1;
                    if (errs == 1) show_mismatch(exp);
                end
            end
            irq_take = 1'b0;
            report(name, word, errs);
        end
    endtask

    // ---------- Part 4: a word outside the ISA must act as nop ----------
    task check_nop;
        input [8*40-1:0] name;
        input [31:0]     word;
        begin
            //               rw    dst asrc ext mr    mw    lb  wb  pc       alu iewe  ieval
            check(name, word, 1'b0, X2, X1,  X1, 1'b0, 1'b0, X1, X2, PC_NEXT, X4, 1'b0, X1);
        end
    endtask

    // ---------- Part 5: sweeps ----------
    function valid_opcode;
        input [5:0] op;
        case (op)
            6'h00, 6'h01, 6'h02, 6'h03, 6'h04, 6'h05, 6'h07,
            6'h08, 6'h0E, 6'h0F, 6'h10, 6'h20, 6'h23, 6'h2B: valid_opcode = 1'b1;
            default:                                         valid_opcode = 1'b0;
        endcase
    endfunction

    function valid_funct;
        input [5:0] f;
        case (f)
            6'h00, 6'h02, 6'h08, 6'h20, 6'h22,
            6'h24, 6'h25, 6'h26, 6'h27, 6'h2A: valid_funct = 1'b1;
            default:                           valid_funct = 1'b0;
        endcase
    endfunction

    // Every opcode outside the ISA, 32 random bodies each.
    task sweep_opcodes;
        integer op, k, errs, n;
        begin
            errs = 0; n = 0; irq_take = 1'b0;
            for (op = 0; op < 64; op = op + 1)
                if (!valid_opcode(op))
                    for (k = 0; k < 32; k = k + 1) begin
                        instr = {op[5:0], 26'b0} | ($random & 32'h03FF_FFFF);
                        {zero, rs_neg} = $random;
                        #1; n = n + 1;
                        if (!nop_now) begin
                            errs = errs + 1;
                            if (errs <= 3) $display("      not a nop: %h", instr);
                        end
                    end
            if (errs == 0) begin n_pass = n_pass + 1; $display("PASS  sweep: %0d words with unused opcodes are nop", n); end
            else           begin n_fail = n_fail + 1; $display("FAIL  sweep: %0d of %0d unused-opcode words not nop", errs, n); end
        end
    endtask

    // Every R-type funct outside the ISA, 32 random bodies each.
    task sweep_functs;
        integer f, k, errs, n;
        begin
            errs = 0; n = 0; irq_take = 1'b0;
            for (f = 0; f < 64; f = f + 1)
                if (!valid_funct(f))
                    for (k = 0; k < 32; k = k + 1) begin
                        instr = ($random & 32'h03FF_FFC0) | f[5:0];   // opcode 0, random rs/rt/rd/shamt
                        {zero, rs_neg} = $random;
                        #1; n = n + 1;
                        if (!nop_now) begin
                            errs = errs + 1;
                            if (errs <= 3) $display("      not a nop: %h", instr);
                        end
                    end
            if (errs == 0) begin n_pass = n_pass + 1; $display("PASS  sweep: %0d R-type words with unused funct are nop", n); end
            else           begin n_fail = n_fail + 1; $display("FAIL  sweep: %0d of %0d unused-funct words not nop", errs, n); end
        end
    endtask

    // REGIMM (6'h01) and bgtz (6'h07): every rt, random rs/imm and status.
    // Only rt = 00001 (bgez) and rt = 00000 (bgtz) may branch.
    task sweep_branch_rt;
        input [5:0] op;
        input [4:0] good_rt;
        integer rt, k, errs, n;
        reg exp_taken;
        begin
            errs = 0; n = 0; irq_take = 1'b0;
            for (rt = 0; rt < 32; rt = rt + 1)
                for (k = 0; k < 16; k = k + 1) begin
                    instr = {op, 5'b0, rt[4:0], 16'b0} | ($random & 32'h03E0_FFFF);
                    {zero, rs_neg} = k[1:0];
                    #1; n = n + 1;
                    if (rt == good_rt) begin
                        exp_taken = (op == 6'h01) ? ~rs_neg : (~rs_neg & ~zero);
                        if (reg_write || mem_read || mem_write || ie_we ||
                            pc_src != (exp_taken ? PC_BRANCH : PC_NEXT)) begin
                            errs = errs + 1;
                            if (errs <= 3) $display("      wrong branch: %h zero=%b rs_neg=%b pc_src=%b", instr, zero, rs_neg, pc_src);
                        end
                    end else if (!nop_now) begin
                        errs = errs + 1;
                        if (errs <= 3) $display("      not a nop: %h", instr);
                    end
                end
            if (errs == 0) begin n_pass = n_pass + 1; $display("PASS  sweep: opcode %h, all 32 rt values (%0d words)", op, n); end
            else           begin n_fail = n_fail + 1; $display("FAIL  sweep: opcode %h, %0d of %0d words wrong", op, errs, n); end
        end
    endtask

    // COP0: every rs, rd, sel and sc, with random rt and other bits.
    task sweep_cop0;
        integer rs, rd, sel, sc, errs, n;
        reg is_mfc0, is_mfmc0;
        begin
            errs = 0; n = 0; irq_take = 1'b0;
            for (rs = 0; rs < 32; rs = rs + 1)
                for (rd = 0; rd < 32; rd = rd + 1)
                    for (sel = 0; sel < 8; sel = sel + 1)
                        for (sc = 0; sc < 2; sc = sc + 1) begin
                            instr = {6'h10, rs[4:0], 5'b0, rd[4:0], 11'b0}
                                  | ($random & 32'h001F_07D8)          // random rt, [10:6], [4:3]
                                  | (sc << 5) | sel;
                            {zero, rs_neg} = $random;
                            #1; n = n + 1;
                            is_mfc0  = (rs == 0)  && (rd == 14) && (sel == 0);
                            is_mfmc0 = (rs == 11) && (rd == 12);
                            if (is_mfc0) begin
                                if (!(reg_write && reg_dst == DST_RT && wb_src == WB_EPC &&
                                      !mem_read && !mem_write && !ie_we && pc_src == PC_NEXT)) begin
                                    errs = errs + 1;
                                    if (errs <= 3) $display("      wrong mfc0: %h", instr);
                                end
                            end else if (is_mfmc0) begin
                                if (!(ie_we && ie_val == sc[0] && !reg_write &&
                                      !mem_read && !mem_write && pc_src == PC_NEXT)) begin
                                    errs = errs + 1;
                                    if (errs <= 3) $display("      wrong di/ei: %h", instr);
                                end
                            end else if (!nop_now) begin
                                errs = errs + 1;
                                if (errs <= 3) $display("      not a nop: %h", instr);
                            end
                        end
            if (errs == 0) begin n_pass = n_pass + 1; $display("PASS  sweep: %0d COP0 words decode as mfc0 / di / ei / nop", n); end
            else           begin n_fail = n_fail + 1; $display("FAIL  sweep: %0d of %0d COP0 words wrong", errs, n); end
        end
    endtask

    initial begin
        instr = 32'b0; zero = 1'b0; rs_neg = 1'b0; irq_take = 1'b0;
        $display("---- control_unit testbench ----");

        // ======================= Part 1 =======================
        //                                                       rw    dst     asrc  ext   mr    mw    lb    wb      pc       alu      iewe  ieval
        // ---- R-type ALU: $t2 = $t0 op $t1 ----
        check("add",              r_type(8, 9, 10, 0, 6'h20),    1'b1, DST_RD, 1'b0, X1,   1'b0, 1'b0, X1,   WB_ALU, PC_NEXT, ALU_ADD, 1'b0, X1);
        check("sub",              r_type(8, 9, 10, 0, 6'h22),    1'b1, DST_RD, 1'b0, X1,   1'b0, 1'b0, X1,   WB_ALU, PC_NEXT, ALU_SUB, 1'b0, X1);
        check("and",              r_type(8, 9, 10, 0, 6'h24),    1'b1, DST_RD, 1'b0, X1,   1'b0, 1'b0, X1,   WB_ALU, PC_NEXT, ALU_AND, 1'b0, X1);
        check("or",               r_type(8, 9, 10, 0, 6'h25),    1'b1, DST_RD, 1'b0, X1,   1'b0, 1'b0, X1,   WB_ALU, PC_NEXT, ALU_OR,  1'b0, X1);
        check("xor",              r_type(8, 9, 10, 0, 6'h26),    1'b1, DST_RD, 1'b0, X1,   1'b0, 1'b0, X1,   WB_ALU, PC_NEXT, ALU_XOR, 1'b0, X1);
        check("nor",              r_type(8, 9, 10, 0, 6'h27),    1'b1, DST_RD, 1'b0, X1,   1'b0, 1'b0, X1,   WB_ALU, PC_NEXT, ALU_NOR, 1'b0, X1);
        check("not (nor rd,rs,$0)", r_type(9, 0, 8, 0, 6'h27),   1'b1, DST_RD, 1'b0, X1,   1'b0, 1'b0, X1,   WB_ALU, PC_NEXT, ALU_NOR, 1'b0, X1);
        check("slt",              r_type(8, 9, 10, 0, 6'h2A),    1'b1, DST_RD, 1'b0, X1,   1'b0, 1'b0, X1,   WB_ALU, PC_NEXT, ALU_SLT, 1'b0, X1);

        // ---- shifts: $t0 = $t1 shift 4 ----
        check("sll",              r_type(0, 9, 8, 4, 6'h00),     1'b1, DST_RD, 1'b0, X1,   1'b0, 1'b0, X1,   WB_ALU, PC_NEXT, ALU_SLL, 1'b0, X1);
        check("srl",              r_type(0, 9, 8, 4, 6'h02),     1'b1, DST_RD, 1'b0, X1,   1'b0, 1'b0, X1,   WB_ALU, PC_NEXT, ALU_SRL, 1'b0, X1);
        // nop = sll $0,$0,0: writes $0, which the register file ignores
        check("nop (sll $0,$0,0)", 32'h00000000,                 1'b1, DST_RD, 1'b0, X1,   1'b0, 1'b0, X1,   WB_ALU, PC_NEXT, ALU_SLL, 1'b0, X1);

        // ---- I-type ALU ----
        check("addi",             i_type(6'h08, 9, 8, 16'hFFFC), 1'b1, DST_RT, 1'b1, 1'b1, 1'b0, 1'b0, X1,   WB_ALU, PC_NEXT, ALU_ADD, 1'b0, X1);
        check("xori (zero ext)",  i_type(6'h0E, 9, 8, 16'hFFFF), 1'b1, DST_RT, 1'b1, 1'b0, 1'b0, 1'b0, X1,   WB_ALU, PC_NEXT, ALU_XOR, 1'b0, X1);
        check("lui (zero ext)",   i_type(6'h0F, 0, 8, 16'h8000), 1'b1, DST_RT, 1'b1, 1'b0, 1'b0, 1'b0, X1,   WB_ALU, PC_NEXT, ALU_LUI, 1'b0, X1);

        // ---- memory ----
        check("lw",               i_type(6'h23, 29, 8, 16'h0004),1'b1, DST_RT, 1'b1, 1'b1, 1'b1, 1'b0, 1'b0, WB_MEM, PC_NEXT, ALU_ADD, 1'b0, X1);
        check("lb",               i_type(6'h20, 29, 8, 16'hFFFF),1'b1, DST_RT, 1'b1, 1'b1, 1'b1, 1'b0, 1'b1, WB_MEM, PC_NEXT, ALU_ADD, 1'b0, X1);
        check("sw",               i_type(6'h2B, 29, 8, 16'h0004),1'b0, X2,     1'b1, 1'b1, 1'b0, 1'b1, X1,   X2,     PC_NEXT, ALU_ADD, 1'b0, X1);

        // ---- jumps ----
        check("j",                j_type(6'h02, 26'h0000010),    1'b0, X2,     X1,   X1,   1'b0, 1'b0, X1,   X2,     PC_JUMP, X4,      1'b0, X1);
        check("jal",              j_type(6'h03, 26'h0000010),    1'b1, DST_RA, X1,   X1,   1'b0, 1'b0, X1,   WB_PC4, PC_JUMP, X4,      1'b0, X1);
        check("jr $ra",           r_type(31, 0, 0, 0, 6'h08),    1'b0, X2,     X1,   X1,   1'b0, 1'b0, X1,   X2,     PC_JR,   X4,      1'b0, X1);

        // ---- COP0 (encodings from spec 4.2 / 11.6) ----
        check("mfc0 $k0,$14",     32'h401A7000,                  1'b1, DST_RT, X1,   X1,   1'b0, 1'b0, X1,   WB_EPC, PC_NEXT, X4,      1'b0, X1);
        check("mfc0 $t0,$14",     32'h40087000,                  1'b1, DST_RT, X1,   X1,   1'b0, 1'b0, X1,   WB_EPC, PC_NEXT, X4,      1'b0, X1);
        check("di",               32'h41606000,                  1'b0, X2,     X1,   X1,   1'b0, 1'b0, X1,   X2,     PC_NEXT, X4,      1'b1, 1'b0);
        check("ei",               32'h41606020,                  1'b0, X2,     X1,   X1,   1'b0, 1'b0, X1,   X2,     PC_NEXT, X4,      1'b1, 1'b1);

        // ======================= Part 2: branches =======================
        // taken bits: [3] zero=1,rs_neg=1  [2] zero=1,rs_neg=0  [1] zero=0,rs_neg=1  [0] zero=0,rs_neg=0
        check_branch("beq  (taken when zero)",          i_type(6'h04, 8, 9, 16'hFFFE), 4'b1100);
        check_branch("bne  (taken when !zero)",         i_type(6'h05, 8, 9, 16'h0003), 4'b0011);
        check_branch("bgez (taken when !rs_neg)",       i_type(6'h01, 8, 1, 16'h0005), 4'b0101);
        check_branch("bgez backward",                   i_type(6'h01, 8, 1, 16'h8000), 4'b0101);
        check_branch("bgtz (taken when !rs_neg&!zero)", i_type(6'h07, 8, 0, 16'h0005), 4'b0001);
        check_branch("bgtz backward",                   i_type(6'h07, 8, 0, 16'hFFFF), 4'b0001);
        check_branch("b label (beq $0,$0)",             i_type(6'h04, 0, 0, 16'h0002), 4'b1100);

        // ======================= Part 3: interrupt cancellation =======================
        check_irq("irq at add",               r_type(8, 9, 10, 0, 6'h20));
        check_irq("irq at lw",                i_type(6'h23, 29, 8, 16'h0004));
        check_irq("irq at lb",                i_type(6'h20, 29, 8, 16'h0001));
        check_irq("irq at sw",                i_type(6'h2B, 29, 8, 16'h0004));
        check_irq("irq at beq",               i_type(6'h04, 8, 9, 16'hFFFE));
        check_irq("irq at bgez",              i_type(6'h01, 8, 1, 16'h0005));
        check_irq("irq at j",                 j_type(6'h02, 26'h0000010));
        check_irq("irq at jal",               j_type(6'h03, 26'h0000010));
        check_irq("irq at jr",                r_type(31, 0, 0, 0, 6'h08));
        check_irq("irq at mfc0",              32'h401A7000);
        check_irq("irq at di",                32'h41606000);
        check_irq("irq at ei",                32'h41606020);
        check_irq("irq at invalid word",      32'hFC000000);

        // ======================= Part 4: outside the ISA -> nop =======================
        check_nop("eret (removed in rev 3)",     32'h42000018);
        check_nop("ori (other group)",           i_type(6'h0D, 9, 8, 16'h00FF));
        check_nop("andi (other group)",          i_type(6'h0C, 9, 8, 16'h00FF));
        check_nop("addiu (other group)",         i_type(6'h09, 9, 8, 16'h0001));
        check_nop("sb (other group)",            i_type(6'h28, 29, 8, 16'h0000));
        check_nop("lbu (not in ISA)",            i_type(6'h24, 29, 8, 16'h0000));
        check_nop("sltu (removed in rev 3)",     r_type(8, 9, 10, 0, 6'h2B));
        check_nop("jalr (not in ISA)",           r_type(31, 0, 31, 0, 6'h09));
        check_nop("sra (not in ISA)",            r_type(0, 9, 8, 4, 6'h03));
        check_nop("bltz (REGIMM rt=0)",          i_type(6'h01, 8, 0, 16'h0005));
        check_nop("bgezal (REGIMM rt=17)",       i_type(6'h01, 8, 17, 16'h0005));
        check_nop("bgtz with rt=1",              i_type(6'h07, 8, 1, 16'h0005));
        check_nop("blez (opcode 6)",             i_type(6'h06, 8, 0, 16'h0005));
        check_nop("mfc0 $t0,$12 (Status)",       32'h40086000);
        check_nop("mfc0 $t0,$14 sel=1",          32'h40087001);
        check_nop("mtc0 $t0,$14",                32'h40887000);
        check_nop("di/ei with rd=10",            32'h41605000);
        check_nop("opcode 111111",               32'hFC000000);

        // ======================= Part 5: sweeps =======================
        sweep_opcodes;
        sweep_functs;
        sweep_branch_rt(6'h01, 5'b00001);   // REGIMM: only bgez
        sweep_branch_rt(6'h07, 5'b00000);   // bgtz: only rt = 0
        sweep_cop0;

        $display("---- %0d passed, %0d failed ----", n_pass, n_fail);
        if (n_fail == 0) $display("ALL TESTS PASSED");
        else             $display("SOME TESTS FAILED");
        $finish;
    end

endmodule
