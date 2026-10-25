`timescale 1ns / 1ps

module tb_control_unit;

    // ---------- DUT signals ----------
    reg  [31:0] instr;

    wire        reg_write;
    wire [1:0]  reg_dst;
    wire        alu_src;
    wire [3:0]  alu_ctrl;
    wire        ext_op;
    wire        mem_write;
    wire        mem_read;
    wire [1:0]  wb_src;
    wire        ie_we;
    wire        ie_val;
    wire [2:0]  pc_src;
    wire        branch_ne;

    control_unit u_cu (
        .i_opcode    (instr[31:26]),
        .i_funct     (instr[5:0]),
        .i_rs        (instr[25:21]),
        .i_rd        (instr[15:11]),
        .o_reg_write (reg_write),
        .o_reg_dst   (reg_dst),
        .o_alu_src   (alu_src),
        .o_alu_ctrl  (alu_ctrl),
        .o_ext_op    (ext_op),
        .o_mem_write (mem_write),
        .o_mem_read  (mem_read),
        .o_wb_src    (wb_src),
        .o_ie_we     (ie_we),
        .o_ie_val    (ie_val),
        .o_pc_src    (pc_src),
        .o_branch_ne (branch_ne)
    );

    // ---------- encoding helpers ----------
    function [31:0] r_type;
        input [4:0] rs, rt, rd, shamt;
        input [5:0] funct;
        r_type = {6'b000000, rs, rt, rd, shamt, funct};
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
    // Returns 1 when every non-x bit of exp matches act.
    function match;
        input [3:0] act;
        input [3:0] exp;
        integer k;
        begin
            match = 1'b1;
            for (k = 0; k < 4; k = k + 1)
                if (exp[k] !== 1'bx && act[k] !== exp[k])
                    match = 1'b0;
        end
    endfunction

    integer n_pass = 0;
    integer n_fail = 0;

    // Applies one instruction and checks the whole control word.
    task check;
        input [8*24-1:0] name;
        input [31:0]     word;
        input            e_reg_write;
        input [1:0]      e_reg_dst;
        input            e_alu_src;
        input            e_ext_op;
        input            e_mem_read;
        input            e_mem_write;
        input [1:0]      e_wb_src;
        input [2:0]      e_pc_src;
        input [3:0]      e_alu_ctrl;
        input            e_ie_we;
        input            e_ie_val;
        input            e_branch_ne;
        begin
            instr = word;
            #1;
            if (match(reg_write, e_reg_write) && match(reg_dst,   e_reg_dst)   &&
                match(alu_src,   e_alu_src)   && match(ext_op,    e_ext_op)    &&
                match(mem_read,  e_mem_read)  && match(mem_write, e_mem_write) &&
                match(wb_src,    e_wb_src)    && match(pc_src,    e_pc_src)    &&
                match(alu_ctrl,  e_alu_ctrl)  && match(ie_we,     e_ie_we)     &&
                match(ie_val,    e_ie_val)    && match(branch_ne, e_branch_ne)) begin
                n_pass = n_pass + 1;
                $display("PASS  %0s (%h)", name, word);
            end else begin
                n_fail = n_fail + 1;
                $display("FAIL  %0s (%h)", name, word);
                $display("      got:      rw=%b dst=%b asrc=%b ext=%b mr=%b mw=%b wb=%b pc=%b alu=%b iewe=%b ieval=%b bne=%b",
                         reg_write, reg_dst, alu_src, ext_op, mem_read, mem_write,
                         wb_src, pc_src, alu_ctrl, ie_we, ie_val, branch_ne);
                $display("      expected: rw=%b dst=%b asrc=%b ext=%b mr=%b mw=%b wb=%b pc=%b alu=%b iewe=%b ieval=%b bne=%b",
                         e_reg_write, e_reg_dst, e_alu_src, e_ext_op, e_mem_read, e_mem_write,
                         e_wb_src, e_pc_src, e_alu_ctrl, e_ie_we, e_ie_val, e_branch_ne);
            end
        end
    endtask

    // A word outside the ISA must act as nop: no writes, PC+4.
    task check_nop;
        input [8*24-1:0] name;
        input [31:0]     word;
        begin
            check(name, word, 1'b0, 2'bxx, 1'bx, 1'bx, 1'b0, 1'b0, 2'bxx,
                  3'b000, 4'bxxxx, 1'b0, 1'bx, 1'bx);
        end
    endtask

    initial begin
        instr = 32'b0;
        $display("---- control_unit testbench ----");

        //                                                rw  dst    asrc  ext   mr    mw    wb     pc      alu      iewe  ieval bne
        // ---- R-type ALU: $t2 = $t0 op $t1 ----
        check("add",  r_type(8, 9, 10, 0, 6'b100000),    1'b1, 2'b01, 1'b0, 1'bx, 1'b0, 1'b0, 2'b00, 3'b000, 4'b0010, 1'b0, 1'bx, 1'bx);
        check("sub",  r_type(8, 9, 10, 0, 6'b100010),    1'b1, 2'b01, 1'b0, 1'bx, 1'b0, 1'b0, 2'b00, 3'b000, 4'b0110, 1'b0, 1'bx, 1'bx);
        check("and",  r_type(8, 9, 10, 0, 6'b100100),    1'b1, 2'b01, 1'b0, 1'bx, 1'b0, 1'b0, 2'b00, 3'b000, 4'b0000, 1'b0, 1'bx, 1'bx);
        check("or",   r_type(8, 9, 10, 0, 6'b100101),    1'b1, 2'b01, 1'b0, 1'bx, 1'b0, 1'b0, 2'b00, 3'b000, 4'b0001, 1'b0, 1'bx, 1'bx);
        check("xor",  r_type(8, 9, 10, 0, 6'b100110),    1'b1, 2'b01, 1'b0, 1'bx, 1'b0, 1'b0, 2'b00, 3'b000, 4'b0011, 1'b0, 1'bx, 1'bx);
        check("nor",  r_type(8, 9, 10, 0, 6'b100111),    1'b1, 2'b01, 1'b0, 1'bx, 1'b0, 1'b0, 2'b00, 3'b000, 4'b1000, 1'b0, 1'bx, 1'bx);
        check("slt",  r_type(8, 9, 10, 0, 6'b101010),    1'b1, 2'b01, 1'b0, 1'bx, 1'b0, 1'b0, 2'b00, 3'b000, 4'b0111, 1'b0, 1'bx, 1'bx);
        check("sltu", r_type(8, 9, 10, 0, 6'b101011),    1'b1, 2'b01, 1'b0, 1'bx, 1'b0, 1'b0, 2'b00, 3'b000, 4'b1001, 1'b0, 1'bx, 1'bx);

        // ---- shifts: $t0 = $t1 shift 4 ----
        check("sll",  r_type(0, 9, 8, 4, 6'b000000),     1'b1, 2'b01, 1'b0, 1'bx, 1'b0, 1'b0, 2'b00, 3'b000, 4'b0100, 1'b0, 1'bx, 1'bx);
        check("srl",  r_type(0, 9, 8, 4, 6'b000010),     1'b1, 2'b01, 1'b0, 1'bx, 1'b0, 1'b0, 2'b00, 3'b000, 4'b0101, 1'b0, 1'bx, 1'bx);
        // nop = sll $0,$0,0: writes $0, which the register file ignores
        check("nop (sll $0)", 32'h00000000,              1'b1, 2'b01, 1'b0, 1'bx, 1'b0, 1'b0, 2'b00, 3'b000, 4'b0100, 1'b0, 1'bx, 1'bx);

        // ---- I-type ALU ----
        check("addi", i_type(6'b001000, 9, 8, 16'hFFFC), 1'b1, 2'b00, 1'b1, 1'b1, 1'b0, 1'b0, 2'b00, 3'b000, 4'b0010, 1'b0, 1'bx, 1'bx);
        check("andi", i_type(6'b001100, 9, 8, 16'h00FF), 1'b1, 2'b00, 1'b1, 1'b0, 1'b0, 1'b0, 2'b00, 3'b000, 4'b0000, 1'b0, 1'bx, 1'bx);
        check("ori",  i_type(6'b001101, 9, 8, 16'h00FF), 1'b1, 2'b00, 1'b1, 1'b0, 1'b0, 1'b0, 2'b00, 3'b000, 4'b0001, 1'b0, 1'bx, 1'bx);
        check("xori", i_type(6'b001110, 9, 8, 16'h00FF), 1'b1, 2'b00, 1'b1, 1'b0, 1'b0, 1'b0, 2'b00, 3'b000, 4'b0011, 1'b0, 1'bx, 1'bx);
        check("lui",  i_type(6'b001111, 0, 8, 16'h1234), 1'b1, 2'b00, 1'b1, 1'b0, 1'b0, 1'b0, 2'b00, 3'b000, 4'b1010, 1'b0, 1'bx, 1'bx);

        // ---- memory ----
        check("lw",   i_type(6'b100011, 29, 8, 16'h0004),1'b1, 2'b00, 1'b1, 1'b1, 1'b1, 1'b0, 2'b01, 3'b000, 4'b0010, 1'b0, 1'bx, 1'bx);
        check("sw",   i_type(6'b101011, 29, 8, 16'h0004),1'b0, 2'bxx, 1'b1, 1'b1, 1'b0, 1'b1, 2'bxx, 3'b000, 4'b0010, 1'b0, 1'bx, 1'bx);

        // ---- branches (pc_src = branch; datapath decides taken/not taken) ----
        check("beq",  i_type(6'b000100, 8, 9, 16'hFFFE), 1'b0, 2'bxx, 1'b0, 1'b1, 1'b0, 1'b0, 2'bxx, 3'b001, 4'b0110, 1'b0, 1'bx, 1'b0);
        check("bne",  i_type(6'b000101, 8, 9, 16'h0003), 1'b0, 2'bxx, 1'b0, 1'b1, 1'b0, 1'b0, 2'bxx, 3'b001, 4'b0110, 1'b0, 1'bx, 1'b1);

        // ---- jumps ----
        check("j",    j_type(6'b000010, 26'h0000010),    1'b0, 2'bxx, 1'bx, 1'bx, 1'b0, 1'b0, 2'bxx, 3'b010, 4'bxxxx, 1'b0, 1'bx, 1'bx);
        check("jal",  j_type(6'b000011, 26'h0000010),    1'b1, 2'b10, 1'bx, 1'bx, 1'b0, 1'b0, 2'b10, 3'b010, 4'bxxxx, 1'b0, 1'bx, 1'bx);
        check("jr",   r_type(31, 0, 0, 0, 6'b001000),    1'b0, 2'bxx, 1'bx, 1'bx, 1'b0, 1'b0, 2'bxx, 3'b011, 4'bxxxx, 1'b0, 1'bx, 1'bx);

        // ---- COP0 ----
        check("eret", 32'h42000018,                      1'b0, 2'bxx, 1'bx, 1'bx, 1'b0, 1'b0, 2'bxx, 3'b100, 4'bxxxx, 1'b1, 1'b1, 1'bx);
        check("di",   32'h41606000,                      1'b0, 2'bxx, 1'bx, 1'bx, 1'b0, 1'b0, 2'bxx, 3'b000, 4'bxxxx, 1'b1, 1'b0, 1'bx);
        check("ei",   32'h41606020,                      1'b0, 2'bxx, 1'bx, 1'bx, 1'b0, 1'b0, 2'bxx, 3'b000, 4'bxxxx, 1'b1, 1'b1, 1'bx);

        // ---- invalid encodings: must behave as nop ----
        check_nop("bad funct 000001",      r_type(8, 9, 10, 0, 6'b000001));
        check_nop("jalr (not in ISA)",     r_type(31, 0, 31, 0, 6'b001001));
        check_nop("addiu (not in ISA)",    i_type(6'b001001, 9, 8, 16'h0001));
        check_nop("lb (not in ISA)",       i_type(6'b100000, 9, 8, 16'h0000));
        check_nop("opcode 111111",         32'hFC000000);
        check_nop("mfc0 $t0,$12",          32'h40086000);
        check_nop("mtc0 $t0,$12",          32'h40886000);
        check_nop("eret funct, rs[4]=0",   32'h40000018);
        check_nop("tlbr (CO=1, funct 1)",  32'h42000001);
        check_nop("di/ei with rd=10",      32'h41605000);

        $display("---- %0d passed, %0d failed ----", n_pass, n_fail);
        if (n_fail == 0) $display("ALL TESTS PASSED");
        else             $display("SOME TESTS FAILED");
        $finish;
    end

endmodule
