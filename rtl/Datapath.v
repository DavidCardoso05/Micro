`timescale 1ns / 1ps

// Datapath (spec rev 3, sections 2.3 and 9). Contains no decoding: everything
// is driven by the control word from control_unit. Status goes back to the CU.
//
// The instruction memory has a 1-cycle read latency and is addressed with
// o_next_pc (the D input of pc_reg), so i_instr is the instruction at o_pc.
module datapath (
    input  wire        i_clk,
    input  wire        i_rst,
    input  wire        i_en,
    input  wire        i_irq,         // Phase 1: tied to 0 in soc.v

    // ---------- instruction memory interface ----------
    input  wire [31:0] i_instr,       // instruction at o_pc
    output wire [31:0] o_pc,
    output wire [31:0] o_next_pc,     // IMEM address

    // ---------- data memory interface (combinational read) ----------
    input  wire [31:0] i_dmem_rd,
    output wire [31:0] o_dmem_addr,
    output wire [31:0] o_dmem_wd,

    // ---------- control word (CU -> datapath) ----------
    input  wire        i_reg_write,
    input  wire [1:0]  i_reg_dst,     // 00: rt, 01: rd, 10: $31
    input  wire        i_alu_src,     // 0: rt, 1: extended immediate
    input  wire [3:0]  i_alu_ctrl,
    input  wire        i_ext_op,      // 0: zero extend, 1: sign extend
    input  wire        i_load_byte,
    input  wire [1:0]  i_wb_src,      // 00: ALU, 01: load_ext, 10: PC+4, 11: EPC
    input  wire [2:0]  i_pc_src,
    input  wire        i_ie_we,
    input  wire        i_ie_val,

    // ---------- status (datapath -> CU) ----------
    output wire        o_zero,
    output wire        o_rs_neg,
    output wire        o_irq_take
);

    // ---------- instruction fields ----------
    wire [4:0]  rs    = i_instr[25:21];
    wire [4:0]  rt    = i_instr[20:16];
    wire [4:0]  rd    = i_instr[15:11];
    wire [4:0]  shamt = i_instr[10:6];
    wire [15:0] imm   = i_instr[15:0];

    // ---------- internal nets ----------
    wire [31:0] pc_plus4;
    wire [31:0] rd1, rd2;
    wire [31:0] imm_ext;
    wire [31:0] alu_b;
    wire [31:0] alu_y;
    wire [31:0] load_data;
    wire [31:0] epc;
    wire [31:0] wb_data;
    wire [4:0]  wr_addr;

    // ---------- fetch ----------
    pc_reg u_pc_reg (
        .i_clk(i_clk), .i_rst(i_rst), .i_en(i_en),
        .i_next_pc(o_next_pc), .o_pc(o_pc)
    );

    next_pc u_next_pc (
        .i_pc(o_pc), .i_imm(imm), .i_index(i_instr[25:0]),
        .i_rs_data(rd1), .i_pc_src(i_pc_src),
        .o_next_pc(o_next_pc), .o_pc_plus4(pc_plus4)
    );

    // ---------- decode ----------
    mux3 #(.W(5)) u_mux_regdst (
        .i_a(rt), .i_b(rd), .i_c(5'd31), .i_sel(i_reg_dst), .o_y(wr_addr)
    );

    register_file u_register_file (
        .i_clk(i_clk), .i_rst(i_rst), .i_en(i_en), .i_we(i_reg_write),
        .i_ra1(rs), .i_ra2(rt), .i_wa(wr_addr), .i_wd(wb_data),
        .o_rd1(rd1), .o_rd2(rd2)
    );

    sign_extend u_sign_extend (
        .i_imm(imm), .i_ext_op(i_ext_op), .o_ext(imm_ext)
    );

    assign o_rs_neg = rd1[31];

    // ---------- execute ----------
    mux2_32bit u_mux_alusrc (
        .i_a(rd2), .i_b(imm_ext), .i_sel(i_alu_src), .o_y(alu_b)
    );

    alu u_alu (
        .i_a(rd1), .i_b(alu_b), .i_shamt(shamt), .i_ctrl(i_alu_ctrl),
        .o_y(alu_y), .o_zero(o_zero)
    );

    // ---------- memory ----------
    assign o_dmem_addr = alu_y;
    assign o_dmem_wd   = rd2;

    load_ext u_load_ext (
        .i_rd(i_dmem_rd), .i_addr(alu_y[1:0]), .i_load_byte(i_load_byte),
        .o_data(load_data)
    );

    // ---------- COP0 ----------
    cop0 u_cop0 (
        .i_clk(i_clk), .i_rst(i_rst), .i_en(i_en),
        .i_pc(o_pc), .i_irq(i_irq),
        .i_ie_we(i_ie_we), .i_ie_val(i_ie_val),
        .o_epc(epc), .o_irq_take(o_irq_take)
    );

    // ---------- write-back ----------
    mux4 #(.W(32)) u_mux_wb (
        .i_a(alu_y), .i_b(load_data), .i_c(pc_plus4), .i_d(epc),
        .i_sel(i_wb_src), .o_y(wb_data)
    );

endmodule
