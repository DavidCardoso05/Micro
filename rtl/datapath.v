`timescale 1ns/1ps

module datapath (
    // --------- inputs -------------
    // clock and reset
    input wire i_clk,
    input wire i_rst,

    // interrupt
    input wire i_irq, // a request is pending -> CP0
    input wire [1:0] i_irq_id, // interruption vector select

    //instruction and memory
    input wire [31:0] i_instr, //current instruction from IMEM
    input wire [31:0] i_mem_rd, // read data from the data memory subsystem

    //control word
    input wire i_reg_write, //register file write enable
    input wire [1:0] i_reg_dst, // write reg: 00 rt, 01 rd, 10 $31
    input wire i_alu_src, // ALU B: 0 ReadData2, 1 extended imm
    input wire [3:0] i_alu_ctrl, 
    input wire i_ext_op, // 1 sign, 0 zero
    input wire i_load_byte, // 1 lb, 0 lw
    input wire [1:0] i_wb_src, // write-back: 00 ALU, 01 load, 10 PC+4, 11 EPC
    input wire [2:0] i_pc_src, // next pc select
    input wire i_pc_write, //pc enable (0 in 1st cycle of lw/lb)
    input wire i_ie_write, // CP0 ie write enable (di/ei)
    input wire i_ie_val, // value written to ie

    // ------------- outputs -------------
    //intruction adress
    output wire [31:0] o_pc,

    //data memory
    output wire [31:0] o_alu_result,
    output wire [31:0] o_store_data, // ReadData2 (rt), written by sw

    //status
    output wire o_zero,
    output wire o_rs_neg, // ReadData1[31] (bgez, bgtz)
    output wire o_irq_take, // interrupt accepted this cycle
    output wire o_mem_phase // 1 = 2nd cycle of lw/lb

);
    // decode instructions fields
    wire [4:0] rs = i_instr[25:21];
    wire [4:0] rt = i_instr[20:16];
    wire [4:0] rd = i_instr[15:11];
    wire [4:0] shamt = i_instr[10:6];
    wire [15:0] imm = i_instr[15:0];
    wire [25:0] index = i_instr[25:0];


    // RegDst MUX
    reg [4:0] write_reg;
    always @(*) begin
        write_reg = 5'd0; //the $zero cannot be written
        case(i_reg_dst)
            2'b00: write_reg = rt;
            2'b01: write_reg = rd;
            2'b10: write_reg = 5'd31;
            default: write_reg = 5'd0;
        endcase
    end

    // ----------- Register File --------------
    wire[31:0] rd1;
    reg [31:0] write_data;

    register_file u_register_file(
        .i_clk (i_clk),
        .i_ra1 (rs),
        .i_ra2 (rt),
        .i_wa (write_reg),
        .i_wd (write_data), // driven by the write-back mux
        .i_we (i_reg_write),
        .o_rd1(rd1),
        .o_rd2(o_store_data)
    );

    assign o_rs_neg = rd1[31];


    // ------- sign extend ------------
    wire [31:0] o_ext;
    
    sign_ext u_sign_ext(
        .i_imm (imm),
        .i_ext_op (i_ext_op),
        .o_ext (o_ext)
    );


    // ----------- ALU --------------
    // ALUSrc MUX, with only 2 inputs
    wire[31:0] alu_b = i_alu_src ? o_ext : o_store_data;

    alu u_alu(
        .i_a (rd1),
        .i_b (alu_b), // output from ALUSrc MUX
        .i_shamt (shamt),
        .i_ctrl (i_alu_ctrl),
        .o_y (o_alu_result), // used inside the datapath
        .o_zero (o_zero)
    );

    // load extend
    wire[31:0] load_data;

    load_ext u_load_ext(
        .i_rd (i_mem_rd),
        .i_addr (o_alu_result[1:0]),
        .i_sel (i_load_byte),
        .o_data (load_data)
    );

    // --------- Fetch and next PC --------------
    //next pc MUX
    reg[31:0] r_pc;
    wire[31:0] pc_plus4;
    wire [31:0] next_pc;

    next_pc u_next_pc(
        .i_pc(r_pc),
        .i_imm (imm),
        .i_rs_data (rd1),
        .i_pc_src (i_pc_src),
        .i_target (index),
        .i_irq_id (i_irq_id),
        .o_next_pc (next_pc),
        .o_pc_plus4 (pc_plus4)
    );

    //pc
    always @(posedge i_clk) begin
        if (i_rst)
            r_pc <= 32'd0; // reset goes to address 0 (j main)
        else if (i_pc_write)
            r_pc <= next_pc; // normal update
    end

    assign o_pc = r_pc; //Instruction address to IMEM

    // --------------- MemPhase and coprocessor0 ----------------
    //MemPhase
    reg r_mem_phase;

    always @(posedge i_clk) begin
        if (i_rst)
            r_mem_phase <= 1'b0;
        else r_mem_phase <= ~i_pc_write; // MemPhase: D = ~PcWrite -> reads 1 in the 2nd cycle of lw/lb
    end

    assign o_mem_phase = r_mem_phase; //status to the control unit

    //COP0
    wire [31:0] epc;
    
    cop0 u_cop0(
        .i_clk (i_clk),
        .i_rst (i_rst),
        .i_pc (o_pc),
        .i_irq (i_irq),
        .i_mem_phase (o_mem_phase),
        .i_ie_we (i_ie_write),
        .i_ie_val (i_ie_val),
        .o_epc (epc),
        .o_irq_take (o_irq_take)
    );

    //write-back MUX
    always @(*) begin
        write_data = 32'd0;
        case(i_wb_src)
            2'b00: write_data = o_alu_result;
            2'b01: write_data = load_data;
            2'b10: write_data = pc_plus4;
            2'b11: write_data = epc;
            default: write_data = 32'd0;
        endcase
    end

endmodule