`timescale 1ns / 1ps

// CPU core: control_unit + datapath. The memories are outside the CPU.
//
//  IMEM (asynchronous read): addr = o_pc  ->  i_instr (instruction at o_pc)
//  DMEM (synchronous read and write):
//      o_dmem_enable  access (lw, lb, sw)
//      o_dmem_rw      1: read, 0: write  -> the memory's write enable is
//                     o_dmem_enable & ~o_dmem_rw (to be done outside the CPU)
//      o_dmem_addr / o_dmem_wd / i_dmem_rd
//      lw / lb take two cycles: o_dmem_enable = 1 only in the first one;
//      i_dmem_rd must hold the value read and is used in the second one.
module cpu (
    input  wire        i_clk,
    input  wire        i_rst,         // synchronous, active high
    input  wire        i_irq,

    output wire [31:0] o_pc,
    input  wire [31:0] i_instr,

    output wire        o_dmem_enable,
    output wire        o_dmem_rw,
    output wire [31:0] o_dmem_addr,
    output wire [31:0] o_dmem_wd,
    input  wire [31:0] i_dmem_rd
);

    // control word
    wire       reg_write, alu_src, ext_op, load_byte, pc_write, ie_we, ie_val;
    wire [1:0] reg_dst, wb_src;
    wire [3:0] alu_ctrl;
    wire [2:0] pc_src;
    // status
    wire       zero, rs_neg, irq_take, mem_phase;

    control_unit u_control_unit (
        .i_opcode(i_instr[31:26]), .i_rs(i_instr[25:21]), .i_rt(i_instr[20:16]),
        .i_rd(i_instr[15:11]),     .i_funct(i_instr[5:0]),
        .i_zero(zero), .i_rs_neg(rs_neg), .i_irq_take(irq_take), .i_mem_phase(mem_phase),
        .o_reg_write(reg_write), .o_reg_dst(reg_dst), .o_alu_src(alu_src),
        .o_alu_ctrl(alu_ctrl),   .o_ext_op(ext_op),
        .o_mem_enable(o_dmem_enable), .o_mem_rw(o_dmem_rw),
        .o_load_byte(load_byte), .o_wb_src(wb_src), .o_pc_src(pc_src),
        .o_pc_write(pc_write),
        .o_ie_we(ie_we),         .o_ie_val(ie_val)
    );

    datapath u_datapath (
        .i_clk(i_clk), .i_rst(i_rst), .i_irq(i_irq),
        .i_instr(i_instr), .o_pc(o_pc),
        .i_dmem_rd(i_dmem_rd), .o_dmem_addr(o_dmem_addr), .o_dmem_wd(o_dmem_wd),
        .i_reg_write(reg_write), .i_reg_dst(reg_dst), .i_alu_src(alu_src),
        .i_alu_ctrl(alu_ctrl),   .i_ext_op(ext_op),   .i_load_byte(load_byte),
        .i_wb_src(wb_src),       .i_pc_src(pc_src),   .i_pc_write(pc_write),
        .i_ie_we(ie_we),         .i_ie_val(ie_val),
        .o_zero(zero), .o_rs_neg(rs_neg), .o_irq_take(irq_take), .o_mem_phase(mem_phase)
    );

endmodule
