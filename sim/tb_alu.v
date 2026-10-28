`timescale 1ns / 1ps

// Self-checking testbench for alu (spec rev 3, section 7)
// Part 1: named edge cases, one line each, printed as PASS/FAIL.
// Part 2: corner-value matrix for ADD / SUB / SLT (every pair of values
//         where overflow or sign tricks can go wrong).
// Part 3: random inputs for every ALUCtrl code (including the reserved
//         ones), compared against a reference model.
// Prints "ALL TESTS PASSED" or "SOME TESTS FAILED" at the end.

module tb_alu;

    // ---------- DUT signals ----------
    reg  [31:0] a;
    reg  [31:0] b;
    reg  [4:0]  shamt;
    reg  [3:0]  ctrl;

    wire [31:0] y;
    wire        zero;

    alu u_alu (
        .i_a     (a),
        .i_b     (b),
        .i_shamt (shamt),
        .i_ctrl  (ctrl),
        .o_y     (y),
        .o_zero  (zero)
    );

    // ---------- ALUCtrl codes (spec section 7) ----------
    localparam ALU_AND = 4'b0000, ALU_OR  = 4'b0001, ALU_ADD = 4'b0010,
               ALU_XOR = 4'b0011, ALU_SLL = 4'b0100, ALU_SRL = 4'b0101,
               ALU_SUB = 4'b0110, ALU_SLT = 4'b0111, ALU_NOR = 4'b1000,
               ALU_RSV = 4'b1001, ALU_LUI = 4'b1010;  // 1001 = old SLTU, now reserved

    // ---------- reference model ----------
    // Written differently from the RTL on purpose (plain -, $signed <),
    // so a mistake in the shared-adder logic is not copied here.
    function [31:0] ref_alu;
        input [3:0]  op;
        input [31:0] ra, rb;
        input [4:0]  sh;
        begin
            case (op)
                ALU_AND: ref_alu = ra & rb;
                ALU_OR:  ref_alu = ra | rb;
                ALU_ADD: ref_alu = ra + rb;
                ALU_XOR: ref_alu = ra ^ rb;
                ALU_SLL: ref_alu = rb << sh;
                ALU_SRL: ref_alu = rb >> sh;
                ALU_SUB: ref_alu = ra - rb;
                ALU_SLT: ref_alu = ($signed(ra) < $signed(rb)) ? 32'd1 : 32'd0;
                ALU_NOR: ref_alu = ~(ra | rb);
                ALU_LUI: ref_alu = rb * 32'h0001_0000;  // same as rb << 16, written differently
                default: ref_alu = 32'd0;               // reserved codes
            endcase
        end
    endfunction

    integer n_pass = 0;
    integer n_fail = 0;

    // ---------- Part 1: one operation, checks o_y and o_zero ----------
    task check;
        input [8*44-1:0] name;
        input [3:0]      op;
        input [31:0]     in_a;
        input [31:0]     in_b;
        input [4:0]      in_sh;
        input [31:0]     exp_y;
        begin
            ctrl = op; a = in_a; b = in_b; shamt = in_sh;
            #1;
            if (y === exp_y && zero === (exp_y == 32'b0)) begin
                n_pass = n_pass + 1;
                $display("PASS  %0s", name);
            end else begin
                n_fail = n_fail + 1;
                $display("FAIL  %0s", name);
                $display("      a=%h b=%h shamt=%0d ctrl=%b", in_a, in_b, in_sh, op);
                $display("      got:      y=%h zero=%b", y, zero);
                $display("      expected: y=%h zero=%b", exp_y, (exp_y == 32'b0));
            end
        end
    endtask

    // ---------- Part 2: every pair of corner values for one op ----------
    reg [31:0] corner [0:9];

    task corner_test;
        input [8*8-1:0] name;
        input [3:0]     op;
        integer i, j, errs;
        reg [31:0] exp_y;
        begin
            errs = 0;
            for (i = 0; i < 10; i = i + 1)
                for (j = 0; j < 10; j = j + 1) begin
                    ctrl = op; a = corner[i]; b = corner[j]; shamt = 5'd0;
                    exp_y = ref_alu(op, a, b, shamt);
                    #1;
                    if (y !== exp_y || zero !== (exp_y == 32'b0)) begin
                        errs = errs + 1;
                        if (errs <= 3)
                            $display("      a=%h b=%h got y=%h zero=%b, expected y=%h",
                                     a, b, y, zero, exp_y);
                    end
                end
            if (errs == 0) begin
                n_pass = n_pass + 1;
                $display("PASS  corners %0s (100 pairs)", name);
            end else begin
                n_fail = n_fail + 1;
                $display("FAIL  corners %0s (%0d of 100 pairs wrong)", name, errs);
            end
        end
    endtask

    // ---------- Part 3: random inputs for one op ----------
    task random_test;
        input [8*8-1:0] name;
        input [3:0]     op;
        input integer   count;
        integer i, errs;
        reg [31:0] exp_y;
        begin
            errs = 0;
            for (i = 0; i < count; i = i + 1) begin
                ctrl = op; a = $random; b = $random; shamt = $random;
                exp_y = ref_alu(op, a, b, shamt);
                #1;
                if (y !== exp_y || zero !== (exp_y == 32'b0)) begin
                    errs = errs + 1;
                    if (errs <= 3)
                        $display("      a=%h b=%h shamt=%0d got y=%h zero=%b, expected y=%h",
                                 a, b, shamt, y, zero, exp_y);
                end
            end
            if (errs == 0) begin
                n_pass = n_pass + 1;
                $display("PASS  random %0s (%0d vectors)", name, count);
            end else begin
                n_fail = n_fail + 1;
                $display("FAIL  random %0s (%0d of %0d vectors wrong)", name, errs, count);
            end
        end
    endtask

    reg [31:0] hi;   // used by the lui + xori sequence

    initial begin
        a = 0; b = 0; shamt = 0; ctrl = ALU_ADD;
        $display("---- alu testbench ----");

        // ================= Part 1: edge cases =================
        //     name                                     ctrl     a             b             shamt  expected y
        // ---- logic ----
        check("and",                                    ALU_AND, 32'hF0F0FFFF, 32'h0FF0F00F, 5'd0,  32'h00F0F00F);
        check("or",                                     ALU_OR,  32'hF0F00000, 32'h0FF0000F, 5'd0,  32'hFFF0000F);
        check("xor",                                    ALU_XOR, 32'hFFFF0000, 32'hF0F0F0F0, 5'd0,  32'h0F0FF0F0);
        check("xor equal -> 0, zero=1",                 ALU_XOR, 32'hA5A5A5A5, 32'hA5A5A5A5, 5'd0,  32'h00000000);
        check("xori 0xFFFF zero-extended (low half)",   ALU_XOR, 32'h12345678, 32'h0000FFFF, 5'd0,  32'h1234A987);
        check("nor",                                    ALU_NOR, 32'hF0F00000, 32'h0FF0000F, 5'd0,  32'h000FFFF0);
        check("nor rs,$zero = NOT rs",                  ALU_NOR, 32'h12345678, 32'h00000000, 5'd0,  32'hEDCBA987);
        check("nor 0,0 = all ones",                     ALU_NOR, 32'h00000000, 32'h00000000, 5'd0,  32'hFFFFFFFF);
        check("nor all ones -> 0, zero=1",              ALU_NOR, 32'hFFFFFFFF, 32'h00000000, 5'd0,  32'h00000000);

        // ---- add (add, addi, lw, lb, sw address) ----
        check("add",                                    ALU_ADD, 32'd7,        32'd5,        5'd0,  32'd12);
        check("add negative imm (addi -4)",             ALU_ADD, 32'd10,       32'hFFFFFFFC, 5'd0,  32'd6);
        check("add overflow wraps, no exception",       ALU_ADD, 32'h7FFFFFFF, 32'd1,        5'd0,  32'h80000000);
        check("add carry out discarded",                ALU_ADD, 32'hFFFFFFFF, 32'd1,        5'd0,  32'h00000000);
        check("lb address: last DMEM byte 0x7FF",       ALU_ADD, 32'h00000800, 32'hFFFFFFFF, 5'd0,  32'h000007FF);

        // ---- sub (sub, beq, bne, bgtz) ----
        check("sub",                                    ALU_SUB, 32'd7,        32'd5,        5'd0,  32'd2);
        check("sub negative result",                    ALU_SUB, 32'd5,        32'd7,        5'd0,  32'hFFFFFFFE);
        check("sub equal -> zero=1 (beq taken)",        ALU_SUB, 32'h12345678, 32'h12345678, 5'd0,  32'h00000000);
        check("sub different -> zero=0 (bne taken)",    ALU_SUB, 32'h12345678, 32'h12345679, 5'd0,  32'hFFFFFFFF);
        check("sub overflow wraps",                     ALU_SUB, 32'h80000000, 32'd1,        5'd0,  32'h7FFFFFFF);
        check("bgtz: rs=0 - $zero -> zero=1",           ALU_SUB, 32'h00000000, 32'h00000000, 5'd0,  32'h00000000);
        check("bgtz: rs=1 - $zero -> zero=0",           ALU_SUB, 32'h00000001, 32'h00000000, 5'd0,  32'h00000001);
        check("bgtz: rs=0x80000000 - $zero, zero=0",    ALU_SUB, 32'h80000000, 32'h00000000, 5'd0,  32'h80000000);

        // ---- slt (signed) ----
        check("slt 3 < 5",                              ALU_SLT, 32'd3,        32'd5,        5'd0,  32'd1);
        check("slt 5 < 3",                              ALU_SLT, 32'd5,        32'd3,        5'd0,  32'd0);
        check("slt equal",                              ALU_SLT, 32'd5,        32'd5,        5'd0,  32'd0);
        check("slt -1 < 1",                             ALU_SLT, 32'hFFFFFFFF, 32'd1,        5'd0,  32'd1);
        check("slt 1 < -1",                             ALU_SLT, 32'd1,        32'hFFFFFFFF, 5'd0,  32'd0);
        check("slt 0x80000000 < 1 (A-B overflows)",     ALU_SLT, 32'h80000000, 32'd1,        5'd0,  32'd1);
        check("slt 0x7FFFFFFF < -1 (A-B overflows)",    ALU_SLT, 32'h7FFFFFFF, 32'hFFFFFFFF, 5'd0,  32'd0);
        check("slt rs < $zero (bltz pseudo)",           ALU_SLT, 32'hFFFFFFF0, 32'd0,        5'd0,  32'd1);

        // ---- shifts (B is shifted, A is ignored) ----
        check("sll by 4",                               ALU_SLL, 32'hDEADBEEF, 32'h00000001, 5'd4,  32'h00000010);
        check("sll by 31",                              ALU_SLL, 32'h00000000, 32'h00000003, 5'd31, 32'h80000000);
        check("sll by 0 (nop)",                         ALU_SLL, 32'h00000000, 32'h12345678, 5'd0,  32'h12345678);
        check("sll 31-k moves bit k to bit 31 (k=5)",   ALU_SLL, 32'h00000000, 32'h00000020, 5'd26, 32'h80000000);
        check("srl by 4",                               ALU_SRL, 32'hDEADBEEF, 32'h00000100, 5'd4,  32'h00000010);
        check("srl by 0",                               ALU_SRL, 32'h00000000, 32'h87654321, 5'd0,  32'h87654321);
        check("srl is logical (fills with 0)",          ALU_SRL, 32'h00000000, 32'h80000000, 5'd31, 32'h00000001);
        check("srl uses shamt, not A",                  ALU_SRL, 32'd8,        32'hFFFFFFFF, 5'd1,  32'h7FFFFFFF);

        // ---- lui ----
        check("lui",                                    ALU_LUI, 32'h00000000, 32'h00001234, 5'd0,  32'h12340000);
        check("lui ignores A and upper bits of B",      ALU_LUI, 32'hFFFFFFFF, 32'h0000FFFF, 5'd0,  32'hFFFF0000);
        check("lui 0 -> zero=1",                        ALU_LUI, 32'hFFFFFFFF, 32'h00000000, 5'd0,  32'h00000000);

        // ---- reserved codes give 0 (zero = 1) ----
        check("reserved 1001 (old SLTU) -> 0",          ALU_RSV, 32'd3,        32'd5,        5'd0,  32'h00000000);
        check("reserved 1011 -> 0",                     4'b1011, 32'hFFFFFFFF, 32'hFFFFFFFF, 5'd0,  32'h00000000);
        check("reserved 1111 -> 0",                     4'b1111, 32'h12345678, 32'h87654321, 5'd7,  32'h00000000);

        // ---- 32-bit constants with lui + xori (spec 11.6) ----
        // The second step feeds the first result back as A, like the CPU does.
        ctrl = ALU_LUI; a = 0; b = 32'h00001234; #1; hi = y;
        check("lui+xori 0x12345678",                    ALU_XOR, hi,           32'h00005678, 5'd0,  32'h12345678);
        ctrl = ALU_LUI; a = 0; b = 32'h00008000; #1; hi = y;
        check("lui+xori 0x80008000 (low >= 0x8000)",    ALU_XOR, hi,           32'h00008000, 5'd0,  32'h80008000);
        ctrl = ALU_LUI; a = 0; b = 32'h0000FFFF; #1; hi = y;
        check("lui+xori 0xFFFF0000 (low = 0)",          ALU_XOR, hi,           32'h00000000, 5'd0,  32'hFFFF0000);

        // ================= Part 2: corner matrix =================
        corner[0] = 32'h00000000; corner[1] = 32'h00000001; corner[2] = 32'hFFFFFFFF;
        corner[3] = 32'h7FFFFFFF; corner[4] = 32'h80000000; corner[5] = 32'h80000001;
        corner[6] = 32'h7FFFFFFE; corner[7] = 32'hFFFFFFFE; corner[8] = 32'h00008000;
        corner[9] = 32'h0000FFFF;
        corner_test("add", ALU_ADD);
        corner_test("sub", ALU_SUB);
        corner_test("slt", ALU_SLT);

        // ================= Part 3: random, every code =================
        random_test("and",      ALU_AND, 20000);
        random_test("or",       ALU_OR,  20000);
        random_test("add",      ALU_ADD, 20000);
        random_test("xor",      ALU_XOR, 20000);
        random_test("sll",      ALU_SLL, 20000);
        random_test("srl",      ALU_SRL, 20000);
        random_test("sub",      ALU_SUB, 20000);
        random_test("slt",      ALU_SLT, 20000);
        random_test("nor",      ALU_NOR, 20000);
        random_test("lui",      ALU_LUI, 20000);
        random_test("rsv 1001", ALU_RSV, 1000);
        random_test("rsv 1011", 4'b1011, 1000);
        random_test("rsv 1100", 4'b1100, 1000);
        random_test("rsv 1101", 4'b1101, 1000);
        random_test("rsv 1110", 4'b1110, 1000);
        random_test("rsv 1111", 4'b1111, 1000);

        $display("---- %0d passed, %0d failed ----", n_pass, n_fail);
        if (n_fail == 0) $display("ALL TESTS PASSED");
        else             $display("SOME TESTS FAILED");
        $finish;
    end

endmodule
