`timescale 1ns / 1ps
`default_nettype none

// CPU: modulo de integracao. Instancia a unidade de controlo e o datapath e nao
// tem logica propria. Executa uma instrucao por ciclo, exceto lw e lb (dois ciclos).
//
// Arquitetura Harvard: nenhuma das memorias esta dentro do CPU.
//   Lado das instrucoes : o_pc sai, i_instr entra (IMEM, leitura assincrona).
//   Lado dos dados      : o_mem_addr, o_mem_wd, o_mem_en e o_mem_rw saem,
//                         i_mem_rd entra (subsistema da memoria de dados).
//   Interrupcao         : um unico pedido, i_irq, vindo do GPIO.
//
// A palavra de controlo desce da control_unit para o datapath; do datapath voltam
// quatro sinais de estado: zero, rs_neg, irq_take e mem_phase.

module cpu (
    // clock e reset (reset sincrono, ativo a 1)
    input  wire        i_clk,
    input  wire        i_rst,

    // interrupcao
    input  wire        i_irq,        // pedido pendente (GPIO)

    // lado das instrucoes
    output wire [31:0] o_pc,         // endereco da instrucao, em bytes
    input  wire [31:0] i_instr,      // instrucao lida da IMEM

    // lado dos dados
    output wire [31:0] o_mem_addr,   // endereco em bytes (resultado da ALU)
    output wire [31:0] o_mem_wd,     // dado do sw (ReadData2)
    output wire        o_mem_en,     // MemEnable: ha acesso neste ciclo
    output wire        o_mem_rw,     // MemRW: 1 le (lw, lb), 0 escreve (sw)
    input  wire [31:0] i_mem_rd      // palavra lida (ja passou pelo mux de leitura)
);

    // ---------- palavra de controlo (control_unit -> datapath) ----------
    wire        reg_write;
    wire [1:0]  reg_dst;
    wire        alu_src;
    wire [3:0]  alu_ctrl;
    wire        ext_op;
    wire        load_byte;
    wire [1:0]  wb_src;
    wire [2:0]  pc_src;
    wire        pc_write;
    wire        ie_write;
    wire        ie_val;

    // ---------- estado (datapath -> control_unit) ----------
    wire        zero;
    wire        rs_neg;
    wire        irq_take;
    wire        mem_phase;

    control_unit u_control_unit (
        .i_instr      (i_instr),
        .i_zero       (zero),
        .i_rs_neg     (rs_neg),
        .i_irq_take   (irq_take),
        .i_mem_phase  (mem_phase),

        .o_reg_write  (reg_write),
        .o_reg_dst    (reg_dst),
        .o_alu_src    (alu_src),
        .o_alu_ctrl   (alu_ctrl),
        .o_ext_op     (ext_op),
        .o_load_byte  (load_byte),
        .o_wb_src     (wb_src),
        .o_pc_src     (pc_src),
        .o_pc_write   (pc_write),
        .o_ie_write   (ie_write),
        .o_ie_val     (ie_val),

        .o_mem_enable (o_mem_en),
        .o_mem_rw     (o_mem_rw)
    );

    datapath u_datapath (
        .i_clk        (i_clk),
        .i_rst        (i_rst),

        .i_irq        (i_irq),
        .i_irq_id     (2'b00),        // um so vetor (0x0000_0004): o id fica a 0

        .i_instr      (i_instr),
        .i_mem_rd     (i_mem_rd),

        .i_reg_write  (reg_write),
        .i_reg_dst    (reg_dst),
        .i_alu_src    (alu_src),
        .i_alu_ctrl   (alu_ctrl),
        .i_ext_op     (ext_op),
        .i_load_byte  (load_byte),
        .i_wb_src     (wb_src),
        .i_pc_src     (pc_src),
        .i_pc_write   (pc_write),
        .i_ie_write   (ie_write),
        .i_ie_val     (ie_val),

        .o_pc         (o_pc),
        .o_alu_result (o_mem_addr),
        .o_store_data (o_mem_wd),
        .o_zero       (zero),
        .o_rs_neg     (rs_neg),
        .o_irq_take   (irq_take),
        .o_mem_phase  (mem_phase)
    );

endmodule
`default_nettype wire
