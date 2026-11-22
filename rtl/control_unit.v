`timescale 1ns/1ps

module control_unit(
    input wire [31:0] i_instr,
    input wire i_zero,
    input wire i_rs_neg, //used by 
    input wire i_irq_take,
    input wire i_mem_phase,

    // datapath control
    output wire o_reg_write,
    output wire [1:0] o_reg_dst,
    output wire o_alu_src,
    output wire [3:0] o_alu_ctrl,
    output wire o_ext_op,
    output wire o_load_byte,
    output wire [1:0] o_wb_src,
    output wire [2:0] o_pc_src,
    output wire o_pc_write,
    output wire o_ie_write,
    output wire o_ie_val,

    // memory control
    output wire o_mem_enable,
    output wire o_mem_rw
);

    //----------- opcodes ------------
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
    
    // ---------- R type funct encodings ---------
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
    
    // ---------- fixed fields -----------
    localparam RT_BGEZ  = 5'b00001,  // REGIMM sub-opcode for bgez
               RT_BGTZ  = 5'b00000,  // bgtz has rt = 0
               RS_MFC0  = 5'b00000,  // COP0 rs = MF
               RS_MFMC0 = 5'b01011,  // COP0 rs = MFMC0 (di / ei)
               RD_EPC   = 5'd14,     // CP0 register 14
               RD_SR    = 5'b01100,     // CP0 register 12 (Status), fixed field of di / ei
               SEL_0    = 3'b000;


endmodule