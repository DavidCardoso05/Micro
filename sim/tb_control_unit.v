`timescale 1ns / 1ps

module tb_control_unit;
    reg [31:0] instr;
    reg zero, rs_neg, irq_take, mem_phase;

    wire reg_write, alu_src, ext_op, mem_enable, mem_rw, load_byte, pc_write, ie_we, ie_val;
    wire [1:0] reg_dst, wb_src;
    wire [3:0] alu_ctrl;
    wire [2:0] pc_src;

    control_unit u_control_unit (
        .i_opcode(instr[31:26]),
        .i_rs(instr[25:21]),
        .i_rt(instr[20:16]),
        .i_rd(instr[15:11]),
        .i_funct(instr[5:0]),

        .i_zero(zero),
        .i_rs_neg(rs_neg),
        .i_irq_take(irq_take),
        .i_mem_phase(mem_phase),

        .o_reg_write(reg_write),
        .o_reg_dst(reg_dst),
        .o_alu_src(alu_src),
        .o_alu_ctrl(alu_ctrl),
        .o_ext_op(ext_op),
        .o_mem_enable(mem_enable),
        .o_mem_rw(mem_rw),
        .o_load_byte(load_byte),
        .o_wb_src(wb_src),
        .o_pc_src(pc_src),
        .o_pc_write(pc_write),
        .o_ie_we(ie_we),
        .o_ie_val(ie_val)
    );

    // Legenda: reg_dst 00 rt, 01 rd, 10 $31 | wb_src 00 ALU, 01 mem, 10 PC+4, 11 EPC
    //          pc_src 000 PC+4, 001 branch, 010 jump, 011 jr, 100 vetor
    initial begin
        zero = 0; rs_neg = 0; irq_take = 0; mem_phase = 0;

        // ---------- R-type: reg_write = 1, reg_dst = 01, alu_src = 0 ----------
        instr = 32'h01095020; #10;  // add  $t2,$t0,$t1 -> alu_ctrl = 0010
        instr = 32'h01095022; #10;  // sub  -> alu_ctrl = 0110
        instr = 32'h01095024; #10;  // and  -> alu_ctrl = 0000
        instr = 32'h01095025; #10;  // or   -> alu_ctrl = 0001
        instr = 32'h01095026; #10;  // xor  -> alu_ctrl = 0011
        instr = 32'h01095027; #10;  // nor  -> alu_ctrl = 1000
        instr = 32'h0109502A; #10;  // slt  -> alu_ctrl = 0111
        instr = 32'h00095080; #10;  // sll  $t2,$t1,2 -> alu_ctrl = 0100
        instr = 32'h00095082; #10;  // srl  $t2,$t1,2 -> alu_ctrl = 0101
        instr = 32'h03E00008; #10;  // jr   $ra -> reg_write = 0, pc_src = 011

        // ---------- I-type ALU: reg_write = 1, reg_dst = 00, alu_src = 1 ----------
        instr = 32'h20080003; #10;  // addi $t0,$zero,3 -> alu_ctrl = 0010, ext_op = 1
        instr = 32'h392800FF; #10;  // xori $t0,$t1,0xFF -> alu_ctrl = 0011, ext_op = 0
        instr = 32'h3C081234; #10;  // lui  $t0,0x1234 -> alu_ctrl = 1010, ext_op = 0

        // ---------- lw: dois ciclos ----------
        instr = 32'h8D0B0000; mem_phase = 0; #10;  // lw 1.º ciclo: mem_enable = 1, mem_rw = 1, pc_write = 0, reg_write = 0
        mem_phase = 1; #10;                        // lw 2.º ciclo: mem_enable = 0, pc_write = 1, reg_write = 1, wb_src = 01
        mem_phase = 0;

        // ---------- lb: dois ciclos, load_byte = 1 ----------
        instr = 32'h810B0001; mem_phase = 0; #10;  // lb 1.º ciclo: pc_write = 0, reg_write = 0
        mem_phase = 1; #10;                        // lb 2.º ciclo: mem_enable = 0, pc_write = 1, reg_write = 1
        mem_phase = 0;

        // ---------- sw: um ciclo ----------
        instr = 32'hAD0A0004; #10;  // sw $t2,4($t0) -> mem_enable = 1, mem_rw = 0, pc_write = 1, reg_write = 0

        // ---------- branches: pc_src = 001 só quando a condição se verifica ----------
        instr = 32'h11090004; zero = 1; #10;                // beq, rs == rt -> pc_src = 001
        zero = 0; #10;                                      // beq, rs != rt -> pc_src = 000
        instr = 32'h15090004; zero = 0; #10;                // bne, rs != rt -> pc_src = 001
        instr = 32'h05010004; rs_neg = 0; #10;              // bgez, rs >= 0 -> pc_src = 001
        rs_neg = 1; #10;                                    // bgez, rs <  0 -> pc_src = 000
        instr = 32'h1D000004; rs_neg = 0; zero = 0; #10;    // bgtz, rs >  0 -> pc_src = 001
        zero = 1; #10;                                      // bgtz, rs == 0 -> pc_src = 000
        zero = 0; rs_neg = 0;

        // ---------- jumps ----------
        instr = 32'h08000010; #10;  // j   -> pc_src = 010, reg_write = 0
        instr = 32'h0C000010; #10;  // jal -> pc_src = 010, reg_write = 1, reg_dst = 10, wb_src = 10

        // ---------- COP0 ----------
        instr = 32'h401A7000; #10;  // mfc0 $k0,$14 -> reg_write = 1, reg_dst = 00, wb_src = 11
        instr = 32'h41606000; #10;  // di -> ie_we = 1, ie_val = 0
        instr = 32'h41606020; #10;  // ei -> ie_we = 1, ie_val = 1

        // ---------- interrupção: tudo cancelado, pc_src = 100, pc_write = 1 ----------
        irq_take = 1;
        instr = 32'h01095020; #10;  // add com irq_take -> reg_write = 0
        instr = 32'h8D0B0000; #10;  // lw  com irq_take -> mem_enable = 0, pc_write = 1
        instr = 32'hAD0A0004; #10;  // sw  com irq_take -> mem_enable = 0
        instr = 32'h41606020; #10;  // ei  com irq_take -> ie_we = 0
        irq_take = 0;

        // ---------- instrução desconhecida: nop ----------
        instr = 32'hFC000000; #10;  // opcode 0x3F -> sem escritas, pc_src = 000

        $finish;
    end
endmodule
