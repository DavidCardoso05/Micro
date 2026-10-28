`timescale 1ns / 1ps

// Self-checking testbench for next_pc (spec rev 3, section 6.2) and for the
// whole branch / jump path.
//
// Part 1: next_pc alone, named edge cases for every PCSrc code.
// Part 2: next_pc alone, random inputs for every PCSrc code against a
//         reference model.
// Part 3: branch / jump path = control_unit + alu + next_pc wired as in the
//         datapath (register values in, next PC out). Named cases from the
//         test plan (spec 11.6): beq, bne, bgez, bgtz, j, jal, jr.
// Part 4: same path, random instructions and register values.
// Prints "ALL TESTS PASSED" or "SOME TESTS FAILED" at the end.

module tb_next_pc;

    localparam PC_NEXT = 3'b000, PC_BRANCH = 3'b001, PC_JUMP = 3'b010,
               PC_JR   = 3'b011, PC_VECTOR = 3'b100;

    localparam UNIT_VECTOR = 32'h0000_0180;   // overridden in the unit instance
    localparam PATH_VECTOR = 32'h0000_0004;   // default of next_pc

    integer n_pass = 0;
    integer n_fail = 0;

    // ================================================================
    // DUT 1: next_pc alone
    // ================================================================
    reg  [31:0] pc;
    reg  [15:0] imm;
    reg  [25:0] index;
    reg  [31:0] rs_data;
    reg  [2:0]  pc_src;
    wire [31:0] next;
    wire [31:0] pc4;

    next_pc #(.IRQ_VECTOR(UNIT_VECTOR)) u_npc (
        .i_pc       (pc),
        .i_imm      (imm),
        .i_index    (index),
        .i_rs_data  (rs_data),
        .i_pc_src   (pc_src),
        .o_next_pc  (next),
        .o_pc_plus4 (pc4)
    );

    // Reference for next_pc alone (written with plain arithmetic).
    function [31:0] ref_npc;
        input [2:0]  src;
        input [31:0] p;
        input [15:0] im;
        input [25:0] ix;
        input [31:0] rsv;
        reg   [31:0] p4;
        begin
            p4 = p + 4;
            case (src)
                PC_BRANCH: ref_npc = $signed(p4) + $signed(im) * 4;   // all signed: im is sign-extended
                PC_JUMP:   ref_npc = (p4 & 32'hF000_0000) | (ix * 4);
                PC_JR:     ref_npc = rsv;
                PC_VECTOR: ref_npc = UNIT_VECTOR;
                default:   ref_npc = p4;               // 000 and reserved 101-111
            endcase
        end
    endfunction

    task check_unit;
        input [8*44-1:0] name;
        input [2:0]      src;
        input [31:0]     in_pc;
        input [15:0]     in_imm;
        input [25:0]     in_index;
        input [31:0]     in_rs;
        input [31:0]     exp_next;
        begin
            pc_src = src; pc = in_pc; imm = in_imm; index = in_index; rs_data = in_rs;
            #1;
            if (next === exp_next && pc4 === in_pc + 32'd4) begin
                n_pass = n_pass + 1;
                $display("PASS  %0s", name);
            end else begin
                n_fail = n_fail + 1;
                $display("FAIL  %0s", name);
                $display("      pc_src=%b pc=%h imm=%h index=%h rs=%h", src, in_pc, in_imm, in_index, in_rs);
                $display("      got:      next=%h pc4=%h", next, pc4);
                $display("      expected: next=%h pc4=%h", exp_next, in_pc + 32'd4);
            end
        end
    endtask

    task random_unit;
        input [2:0]   src;
        input integer count;
        integer i, errs;
        reg [31:0] exp_next;
        begin
            errs = 0;
            for (i = 0; i < count; i = i + 1) begin
                pc_src = src; pc = $random & 32'hFFFF_FFFC; imm = $random;
                index = $random; rs_data = $random;
                exp_next = ref_npc(src, pc, imm, index, rs_data);
                #1;
                if (next !== exp_next || pc4 !== pc + 32'd4) begin
                    errs = errs + 1;
                    if (errs <= 3)
                        $display("      pc=%h imm=%h index=%h rs=%h got %h, expected %h",
                                 pc, imm, index, rs_data, next, exp_next);
                end
            end
            if (errs == 0) begin
                n_pass = n_pass + 1;
                $display("PASS  random pc_src=%b (%0d vectors)", src, count);
            end else begin
                n_fail = n_fail + 1;
                $display("FAIL  random pc_src=%b (%0d of %0d wrong)", src, errs, count);
            end
        end
    endtask

    // ================================================================
    // DUT 2: branch / jump path (control_unit + alu + next_pc)
    // The register file is modelled here: p_rs / p_rt are the values read
    // from ports A and B, with register 0 always reading 0.
    // ================================================================
    reg  [31:0] p_instr;
    reg  [31:0] p_pc;
    reg  [31:0] p_rs;            // value read from register instr[25:21]
    reg  [31:0] p_rt;            // value read from register instr[20:16]
    reg         p_irq_take;

    wire        p_reg_write, p_alu_src, p_ext_op, p_mem_read, p_mem_write;
    wire        p_load_byte, p_ie_we, p_ie_val;
    wire [1:0]  p_reg_dst, p_wb_src;
    wire [2:0]  p_pc_src;
    wire [3:0]  p_alu_ctrl;
    wire [31:0] p_alu_y;
    wire        p_zero;
    wire [31:0] p_next;
    wire [31:0] p_pc4;

    // extender and ALUSrc mux, as in the datapath
    wire [31:0] p_ext_imm = p_ext_op ? {{16{p_instr[15]}}, p_instr[15:0]}
                                     : {16'b0, p_instr[15:0]};
    wire [31:0] p_alu_b   = p_alu_src ? p_ext_imm : p_rt;

    control_unit u_cu (
        .i_opcode    (p_instr[31:26]),
        .i_rs        (p_instr[25:21]),
        .i_rt        (p_instr[20:16]),
        .i_rd        (p_instr[15:11]),
        .i_funct     (p_instr[5:0]),
        .i_zero      (p_zero),
        .i_rs_neg    (p_rs[31]),
        .i_irq_take  (p_irq_take),
        .o_reg_write (p_reg_write),
        .o_reg_dst   (p_reg_dst),
        .o_alu_src   (p_alu_src),
        .o_alu_ctrl  (p_alu_ctrl),
        .o_ext_op    (p_ext_op),
        .o_mem_read  (p_mem_read),
        .o_mem_write (p_mem_write),
        .o_load_byte (p_load_byte),
        .o_wb_src    (p_wb_src),
        .o_pc_src    (p_pc_src),
        .o_ie_we     (p_ie_we),
        .o_ie_val    (p_ie_val)
    );

    alu u_alu (
        .i_a     (p_rs),
        .i_b     (p_alu_b),
        .i_shamt (p_instr[10:6]),
        .i_ctrl  (p_alu_ctrl),
        .o_y     (p_alu_y),
        .o_zero  (p_zero)
    );

    next_pc u_npc_path (
        .i_pc       (p_pc),
        .i_imm      (p_instr[15:0]),
        .i_index    (p_instr[25:0]),
        .i_rs_data  (p_rs),
        .i_pc_src   (p_pc_src),
        .o_next_pc  (p_next),
        .o_pc_plus4 (p_pc4)
    );

    // Reference: ISA semantics of spec 4 for control-flow instructions.
    // Uses $signed comparisons, independent of the i_zero / i_rs_neg trick.
    function [31:0] ref_path;
        input [31:0] ins;
        input [31:0] p;
        input [31:0] rsv;
        input [31:0] rtv;
        reg   [31:0] p4, bt, jt;
        begin
            p4 = p + 4;
            bt = $signed(p4) + $signed(ins[15:0]) * 4;   // all signed: offset is sign-extended
            jt = {p4[31:28], ins[25:0], 2'b00};
            case (ins[31:26])
                6'h00:   ref_path = (ins[5:0] == 6'h08) ? rsv : p4;                         // jr
                6'h01:   ref_path = (ins[20:16] == 5'd1 && $signed(rsv) >= 0) ? bt : p4;    // bgez
                6'h02,
                6'h03:   ref_path = jt;                                                     // j, jal
                6'h04:   ref_path = (rsv == rtv) ? bt : p4;                                 // beq
                6'h05:   ref_path = (rsv != rtv) ? bt : p4;                                 // bne
                6'h07:   ref_path = (ins[20:16] == 5'd0 && $signed(rsv) > 0) ? bt : p4;     // bgtz
                default: ref_path = p4;                                                     // everything else
            endcase
        end
    endfunction

    // Sets the instruction and register values (register 0 reads 0).
    task apply_path;
        input [31:0] ins;
        input [31:0] in_pc;
        input [31:0] rs_val;
        input [31:0] rt_val;
        begin
            p_instr = ins; p_pc = in_pc;
            p_rs = (ins[25:21] == 5'd0) ? 32'd0 : rs_val;
            p_rt = (ins[20:16] == 5'd0) ? 32'd0 : rt_val;
            #1;
        end
    endtask

    task check_path;
        input [8*44-1:0] name;
        input [31:0]     ins;
        input [31:0]     in_pc;
        input [31:0]     rs_val;
        input [31:0]     rt_val;
        input [31:0]     exp_next;
        begin
            apply_path(ins, in_pc, rs_val, rt_val);
            if (p_next === exp_next) begin
                n_pass = n_pass + 1;
                $display("PASS  %0s", name);
            end else begin
                n_fail = n_fail + 1;
                $display("FAIL  %0s", name);
                $display("      instr=%h pc=%h rs=%h rt(read)=%h pc_src=%b zero=%b",
                         ins, in_pc, p_rs, p_rt, p_pc_src, p_zero);
                $display("      got next=%h, expected %h", p_next, exp_next);
            end
        end
    endtask

    // Random control-flow instruction (or a random other one), random registers.
    task random_path;
        input integer count;
        integer i, errs, kind;
        reg [31:0] ins, rsv, rtv, ppc, exp_next;
        begin
            errs = 0;
            for (i = 0; i < count; i = i + 1) begin
                ins  = $random;
                kind = {$random} % 8;
                case (kind)
                    0: ins[31:26] = 6'h04;                                   // beq
                    1: ins[31:26] = 6'h05;                                   // bne
                    2: begin ins[31:26] = 6'h01; ins[20:16] = 5'd1; end      // bgez
                    3: begin ins[31:26] = 6'h07; ins[20:16] = 5'd0; end      // bgtz
                    4: ins[31:26] = 6'h02 | ({$random} % 2);                 // j / jal
                    5: begin ins[31:26] = 6'h00; ins[5:0] = 6'h08; end       // jr
                    6: ins[31:26] = 6'h01;                                   // REGIMM, any rt
                    default: ;                                               // anything
                endcase
                // small values make rs == rt and rs == 0 happen often
                rsv = ({$random} % 4 == 0) ? ({$random} % 3) - 1 : $random;
                rtv = ({$random} % 4 == 0) ? rsv : $random;
                ppc = $random & 32'hFFFF_FFFC;
                apply_path(ins, ppc, rsv, rtv);
                exp_next = ref_path(ins, ppc, p_rs, p_rt);
                if (p_next !== exp_next) begin
                    errs = errs + 1;
                    if (errs <= 3)
                        $display("      instr=%h pc=%h rs=%h rt=%h got %h, expected %h",
                                 ins, ppc, p_rs, p_rt, p_next, exp_next);
                end
            end
            if (errs == 0) begin
                n_pass = n_pass + 1;
                $display("PASS  random branch/jump path (%0d instructions)", count);
            end else begin
                n_fail = n_fail + 1;
                $display("FAIL  random branch/jump path (%0d of %0d wrong)", errs, count);
            end
        end
    endtask

    // ---------- encoding helpers ----------
    function [31:0] i_type;
        input [5:0]  op;
        input [4:0]  rs, rt;
        input [15:0] imm16;
        i_type = {op, rs, rt, imm16};
    endfunction

    function [31:0] j_type;
        input [5:0]  op;
        input [25:0] ix;
        j_type = {op, ix};
    endfunction

    localparam [31:0] JR_RA = 32'h03E00008;   // jr $ra

    integer s;

    initial begin
        pc = 0; imm = 0; index = 0; rs_data = 0; pc_src = PC_NEXT;
        p_instr = 0; p_pc = 0; p_rs = 0; p_rt = 0; p_irq_take = 0;
        $display("---- next_pc testbench ----");

        // ======================= Part 1: next_pc alone =======================
        //          name                                       pc_src     pc            imm       index         rs            expected next
        check_unit("pc+4",                                    PC_NEXT,   32'h00000000, 16'h0000, 26'h0000000, 32'h0,        32'h00000004);
        check_unit("pc+4 wraps at 0xFFFFFFFC",                PC_NEXT,   32'hFFFFFFFC, 16'h0000, 26'h0000000, 32'h0,        32'h00000000);
        check_unit("pc+4 ignores imm/index/rs",               PC_NEXT,   32'h00000100, 16'hFFFF, 26'h3FFFFFF, 32'hDEADBEEF, 32'h00000104);
        check_unit("branch forward +3",                       PC_BRANCH, 32'h00000100, 16'h0003, 26'h0000000, 32'h0,        32'h00000110);
        check_unit("branch offset 0 = pc+4",                  PC_BRANCH, 32'h00000100, 16'h0000, 26'h0000000, 32'h0,        32'h00000104);
        check_unit("branch -1 = to itself (loop: b loop)",    PC_BRANCH, 32'h00000100, 16'hFFFF, 26'h0000000, 32'h0,        32'h00000100);
        check_unit("branch backward -4",                      PC_BRANCH, 32'h00000100, 16'hFFFC, 26'h0000000, 32'h0,        32'h000000F4);
        check_unit("branch max forward 0x7FFF",               PC_BRANCH, 32'h00000000, 16'h7FFF, 26'h0000000, 32'h0,        32'h00020000);
        check_unit("branch max backward 0x8000",              PC_BRANCH, 32'h00020000, 16'h8000, 26'h0000000, 32'h0,        32'h00000004);
        check_unit("j index 0x10 -> 0x40",                    PC_JUMP,   32'h00000000, 16'h0000, 26'h0000010, 32'h0,        32'h00000040);
        check_unit("j keeps (PC+4)[31:28]",                   PC_JUMP,   32'h30000000, 16'h0000, 26'h3FFFFFF, 32'h0,        32'h3FFFFFFC);
        check_unit("j region from PC+4, not PC",              PC_JUMP,   32'h0FFFFFFC, 16'h0000, 26'h0000010, 32'h0,        32'h10000040);
        check_unit("j index 0x1234 -> 0x48D0",               PC_JUMP,   32'h00000200, 16'h1234, 26'h0001234, 32'h0,        32'h000048D0);
        check_unit("jr",                                      PC_JR,     32'h00000100, 16'h0000, 26'h0000000, 32'h00000340, 32'h00000340);
        check_unit("jr $k0 = 0 (return to address 0)",        PC_JR,     32'h000003FC, 16'h0000, 26'h0000000, 32'h00000000, 32'h00000000);
        check_unit("jr passes rs unchanged (no alignment)",   PC_JR,     32'h00000100, 16'h0000, 26'h0000000, 32'h00000343, 32'h00000343);
        check_unit("vector (parameter override)",             PC_VECTOR, 32'h00000100, 16'h0003, 26'h0000010, 32'h00000340, UNIT_VECTOR);
        check_unit("reserved 101 -> pc+4",                    3'b101,    32'h00000100, 16'h0003, 26'h0000010, 32'h00000340, 32'h00000104);
        check_unit("reserved 110 -> pc+4",                    3'b110,    32'h00000100, 16'h0003, 26'h0000010, 32'h00000340, 32'h00000104);
        check_unit("reserved 111 -> pc+4",                    3'b111,    32'h00000100, 16'h0003, 26'h0000010, 32'h00000340, 32'h00000104);

        // ======================= Part 2: next_pc random =======================
        for (s = 0; s < 8; s = s + 1)
            random_unit(s[2:0], 5000);

        // ======================= Part 3: branch / jump path =======================
        // Registers: $t0 = 8, $t1 = 9, $at = 1. PC = 0x100, so PC+4 = 0x104.
        // Branch offset +4 -> target 0x114; offset -2 -> target 0xFC.
        //          name                                       instruction                        pc            rs            rt            expected next
        // ---- beq / bne ----
        check_path("beq equal -> taken",                      i_type(6'h04, 8, 9, 16'h0004),     32'h00000100, 32'h00000005, 32'h00000005, 32'h00000114);
        check_path("beq different -> not taken",              i_type(6'h04, 8, 9, 16'h0004),     32'h00000100, 32'h00000005, 32'h00000006, 32'h00000104);
        check_path("beq backward taken",                      i_type(6'h04, 8, 9, 16'hFFFE),     32'h00000100, 32'h80000000, 32'h80000000, 32'h000000FC);
        check_path("b label = beq $0,$0 (always)",            i_type(6'h04, 0, 0, 16'h0004),     32'h00000100, 32'h12345678, 32'h87654321, 32'h00000114);
        check_path("bne different -> taken",                  i_type(6'h05, 8, 9, 16'h0004),     32'h00000100, 32'h00000005, 32'h00000006, 32'h00000114);
        check_path("bne equal -> not taken",                  i_type(6'h05, 8, 9, 16'h0004),     32'h00000100, 32'hFFFFFFFF, 32'hFFFFFFFF, 32'h00000104);
        check_path("bne $t0,$0 with $t0=0 -> not taken",      i_type(6'h05, 8, 0, 16'h0004),     32'h00000100, 32'h00000000, 32'h00000000, 32'h00000104);

        // ---- bgez rs (rt field = 00001 reads $at; its value must not matter) ----
        check_path("bgez rs=0 -> taken",                      i_type(6'h01, 8, 1, 16'h0004),     32'h00000100, 32'h00000000, 32'h00000000, 32'h00000114);
        check_path("bgez rs=1 -> taken",                      i_type(6'h01, 8, 1, 16'h0004),     32'h00000100, 32'h00000001, 32'h00000000, 32'h00000114);
        check_path("bgez rs=-1 -> not taken",                 i_type(6'h01, 8, 1, 16'h0004),     32'h00000100, 32'hFFFFFFFF, 32'h00000000, 32'h00000104);
        check_path("bgez rs=0x7FFFFFFF -> taken",             i_type(6'h01, 8, 1, 16'h0004),     32'h00000100, 32'h7FFFFFFF, 32'h00000000, 32'h00000114);
        check_path("bgez rs=0x80000000 -> not taken",         i_type(6'h01, 8, 1, 16'h0004),     32'h00000100, 32'h80000000, 32'h00000000, 32'h00000104);
        check_path("bgez backward taken",                     i_type(6'h01, 8, 1, 16'hFFFE),     32'h00000100, 32'h00000003, 32'h00000000, 32'h000000FC);
        check_path("bgez rs=5, $at=5 (rs-$at=0) -> taken",    i_type(6'h01, 8, 1, 16'h0004),     32'h00000100, 32'h00000005, 32'h00000005, 32'h00000114);
        check_path("bgez rs=5, $at=-7 -> taken",              i_type(6'h01, 8, 1, 16'h0004),     32'h00000100, 32'h00000005, 32'hFFFFFFF9, 32'h00000114);
        check_path("bgez rs=-5, $at=-5 -> not taken",         i_type(6'h01, 8, 1, 16'h0004),     32'h00000100, 32'hFFFFFFFB, 32'hFFFFFFFB, 32'h00000104);
        check_path("bgez $zero -> always taken",              i_type(6'h01, 0, 1, 16'h0004),     32'h00000100, 32'h00000000, 32'h00000000, 32'h00000114);
        // test bit k with sll + bgez: bit 31 of the shifted value clear -> taken
        check_path("bit test: bit clear -> taken",            i_type(6'h01, 8, 1, 16'h0004),     32'h00000100, 32'h7FFFFFFF, 32'h00000000, 32'h00000114);
        check_path("bit test: bit set -> not taken",          i_type(6'h01, 8, 1, 16'h0004),     32'h00000100, 32'h80000001, 32'h00000000, 32'h00000104);

        // ---- bgtz rs (rt = 0, so the B port reads $zero) ----
        check_path("bgtz rs=0 -> not taken",                  i_type(6'h07, 8, 0, 16'h0004),     32'h00000100, 32'h00000000, 32'h00000000, 32'h00000104);
        check_path("bgtz rs=1 -> taken",                      i_type(6'h07, 8, 0, 16'h0004),     32'h00000100, 32'h00000001, 32'h00000000, 32'h00000114);
        check_path("bgtz rs=-1 -> not taken",                 i_type(6'h07, 8, 0, 16'h0004),     32'h00000100, 32'hFFFFFFFF, 32'h00000000, 32'h00000104);
        check_path("bgtz rs=0x7FFFFFFF -> taken",             i_type(6'h07, 8, 0, 16'h0004),     32'h00000100, 32'h7FFFFFFF, 32'h00000000, 32'h00000114);
        check_path("bgtz rs=0x80000000 -> not taken",         i_type(6'h07, 8, 0, 16'h0004),     32'h00000100, 32'h80000000, 32'h00000000, 32'h00000104);
        check_path("bgtz backward taken (countdown loop)",    i_type(6'h07, 8, 0, 16'hFFFE),     32'h00000100, 32'h00000003, 32'h00000000, 32'h000000FC);

        // ---- encodings that look like branches but are not ----
        check_path("bltz (REGIMM rt=0) -> nop",               i_type(6'h01, 8, 0, 16'h0004),     32'h00000100, 32'hFFFFFFFF, 32'h00000000, 32'h00000104);
        check_path("bgtz with rt=1 -> nop",                   i_type(6'h07, 8, 1, 16'h0004),     32'h00000100, 32'h00000001, 32'h00000000, 32'h00000104);

        // ---- j / jal / jr ----
        check_path("j 0x40",                                  j_type(6'h02, 26'h0000010),        32'h00000100, 32'h0,        32'h0,        32'h00000040);
        check_path("j to itself (end: j end)",                j_type(6'h02, 26'h0000040),        32'h00000100, 32'h0,        32'h0,        32'h00000100);
        check_path("jal 0x200",                               j_type(6'h03, 26'h0000080),        32'h00000100, 32'h0,        32'h0,        32'h00000200);
        check_path("jr $ra",                                  JR_RA,                             32'h00000200, 32'h00000104, 32'h0,        32'h00000104);

        // jal link value is PC + 4 (written through WBSrc = 10)
        apply_path(j_type(6'h03, 26'h0000080), 32'h00000100, 0, 0);
        if (p_pc4 === 32'h00000104 && p_wb_src === 2'b10 && p_reg_dst === 2'b10 && p_reg_write === 1'b1) begin
            n_pass = n_pass + 1; $display("PASS  jal links PC+4 into $ra");
        end else begin
            n_fail = n_fail + 1; $display("FAIL  jal links PC+4 into $ra (pc4=%h wb=%b dst=%b rw=%b)",
                                          p_pc4, p_wb_src, p_reg_dst, p_reg_write);
        end

        // ---- non-control instructions continue at PC+4 ----
        check_path("add -> pc+4",                             32'h01095020,                      32'h00000100, 32'h00000005, 32'h00000005, 32'h00000104);
        check_path("lw -> pc+4",                              i_type(6'h23, 29, 8, 16'h0004),    32'h00000100, 32'h00000000, 32'h00000000, 32'h00000104);
        check_path("ei -> pc+4",                              32'h41606020,                      32'h00000100, 32'h00000000, 32'h00000000, 32'h00000104);

        // ---- interrupt taken (Phase 2): vector wins over any branch / jump ----
        p_irq_take = 1'b1;
        check_path("irq at taken beq -> vector",              i_type(6'h04, 8, 9, 16'h0004),     32'h00000100, 32'h00000005, 32'h00000005, PATH_VECTOR);
        check_path("irq at j -> vector",                      j_type(6'h02, 26'h0000010),        32'h00000100, 32'h0,        32'h0,        PATH_VECTOR);
        check_path("irq at jr -> vector",                     JR_RA,                             32'h00000200, 32'h00000104, 32'h0,        PATH_VECTOR);
        check_path("irq at add -> vector",                    32'h01095020,                      32'h00000100, 32'h00000005, 32'h00000005, PATH_VECTOR);
        p_irq_take = 1'b0;

        // ======================= Part 4: random path =======================
        random_path(50000);

        $display("---- %0d passed, %0d failed ----", n_pass, n_fail);
        if (n_fail == 0) $display("ALL TESTS PASSED");
        else             $display("SOME TESTS FAILED");
        $finish;
    end

endmodule
