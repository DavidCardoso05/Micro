`timescale 1ns / 1ps

// Testbench do datapath SEM control_unit: a palavra de controlo e dada a mao,
// instrucao a instrucao, como a unidade de controlo a daria (ver tabela de controlo).
//
// Temporizacao: o clock tem periodo 10 ns, com flancos de subida em 5, 15, 25, ...
// As entradas mudam 1 ns depois de cada flanco (6, 16, 26, ...), por isso cada
// passo e um ciclo completo. Le-se o resultado do ciclo no FIM do passo (antes do
// flanco seguinte): PC, alu_result, zero, rs_neg e irq_take sao os dessa
// instrucao. O que o flanco escreve (registo, PC, EPC, IE) aparece no passo seguinte.

module tb_datapath;
    reg clk;
    reg rst;
    reg irq;
    reg [1:0] irq_id;
    reg [31:0] instr;
    reg [31:0] mem_rd;

    // palavra de controlo
    reg reg_write;
    reg [1:0] reg_dst;
    reg alu_src;
    reg [3:0] alu_ctrl;
    reg ext_op;
    reg load_byte;
    reg [1:0] wb_src;
    reg [2:0] pc_src;
    reg ie_write;
    reg ie_val;

    wire [31:0] pc;
    wire [31:0] alu_result;
    wire [31:0] store_data;
    wire zero;
    wire rs_neg;
    wire irq_take;

    datapath u_datapath (
        .i_clk(clk),
        .i_rst(rst),
        .i_irq(irq),
        .i_irq_id(irq_id),
        .i_instr(instr),
        .i_mem_rd(mem_rd),
        .i_reg_write(reg_write),
        .i_reg_dst(reg_dst),
        .i_alu_src(alu_src),
        .i_alu_ctrl(alu_ctrl),
        .i_ext_op(ext_op),
        .i_load_byte(load_byte),
        .i_wb_src(wb_src),
        .i_pc_src(pc_src),
        .i_ie_write(ie_write),
        .i_ie_val(ie_val),
        .o_pc(pc),
        .o_alu_result(alu_result),
        .o_store_data(store_data),
        .o_zero(zero),
        .o_rs_neg(rs_neg),
        .o_irq_take(irq_take)
    );

    // Codigos de controlo da ALU
    localparam ALU_AND = 4'b0000;
    localparam ALU_OR  = 4'b0001;
    localparam ALU_ADD = 4'b0010;
    localparam ALU_XOR = 4'b0011;
    localparam ALU_SLL = 4'b0100;
    localparam ALU_SRL = 4'b0101;
    localparam ALU_SUB = 4'b0110;
    localparam ALU_SLT = 4'b0111;
    localparam ALU_NOR = 4'b1000;
    localparam ALU_LUI = 4'b1010;

    // RegDst: registo de destino
    localparam DST_RT = 2'b00;
    localparam DST_RD = 2'b01;
    localparam DST_RA = 2'b10;  // $31 (jal)

    // ALUSrc: segundo operando da ALU
    localparam SRC_REG = 1'b0;  // ReadData2
    localparam SRC_IMM = 1'b1;  // imediato estendido

    // ExtOp
    localparam EXT_ZERO = 1'b0;
    localparam EXT_SIGN = 1'b1;

    // WBSrc: dado escrito no registo
    localparam WB_ALU  = 2'b00;
    localparam WB_LOAD = 2'b01;
    localparam WB_PC4  = 2'b10;
    localparam WB_EPC  = 2'b11;

    // PCSrc: proximo PC
    localparam PC_NEXT   = 3'b000;
    localparam PC_BRANCH = 3'b001;
    localparam PC_JUMP   = 3'b010;
    localparam PC_JR     = 3'b011;
    localparam PC_IRQ    = 3'b100;

    // Palavra de controlo "neutra": nao escreve nada e segue para PC + 4.
    // Cada instrucao parte daqui e so altera os sinais que precisa.
    task ctrl_nop;
        begin
            reg_write = 1'b0; reg_dst = DST_RT; alu_src = SRC_REG; alu_ctrl = ALU_ADD;
            ext_op = EXT_SIGN; load_byte = 1'b0; wb_src = WB_ALU; pc_src = PC_NEXT;
            ie_write = 1'b0; ie_val = 1'b0;
        end
    endtask

    initial clk = 1'b0;
    always #5 clk = ~clk;

    initial begin
        // ---------- reset: PC = 0 ----------
        rst = 1; irq = 0; irq_id = 2'd0; instr = 32'h0; mem_rd = 32'h0; ctrl_nop;
        #6;  // o flanco de 5 ns faz o reset: PC = 0x00

        // =====================================================
        // I. Aritmetica e logica: o resultado e escrito no flanco
        // =====================================================
        rst = 0;

        // addi $8, $0, 5
        instr = 32'h20080005; ctrl_nop;
        reg_write = 1; reg_dst = DST_RT; alu_src = SRC_IMM; alu_ctrl = ALU_ADD; ext_op = EXT_SIGN;
        #10;  // PC = 0x00, alu_result = 5; no flanco $8 = 5, PC -> 0x04

        // addi $9, $0, 3
        instr = 32'h20090003; ctrl_nop;
        reg_write = 1; reg_dst = DST_RT; alu_src = SRC_IMM; alu_ctrl = ALU_ADD; ext_op = EXT_SIGN;
        #10;  // PC = 0x04, alu_result = 3; no flanco $9 = 3, PC -> 0x08

        // add $10, $8, $9   (RegDst = rd)
        instr = 32'h01095020; ctrl_nop;
        reg_write = 1; reg_dst = DST_RD; alu_src = SRC_REG; alu_ctrl = ALU_ADD;
        #10;  // PC = 0x08, alu_result = 8; no flanco $10 = 8, PC -> 0x0C

        // sub $11, $8, $9
        instr = 32'h01095822; ctrl_nop;
        reg_write = 1; reg_dst = DST_RD; alu_src = SRC_REG; alu_ctrl = ALU_SUB;
        #10;  // PC = 0x0C, alu_result = 2; no flanco $11 = 2, PC -> 0x10

        // sll $12, $8, 2   (shamt vem da instrucao; o operando e rt = $8)
        instr = 32'h00086080; ctrl_nop;
        reg_write = 1; reg_dst = DST_RD; alu_src = SRC_REG; alu_ctrl = ALU_SLL;
        #10;  // PC = 0x10, alu_result = 0x14; no flanco $12 = 0x14, PC -> 0x14

        // lui $13, 0x1234   (ExtOp = zeros)
        instr = 32'h3C0D1234; ctrl_nop;
        reg_write = 1; reg_dst = DST_RT; alu_src = SRC_IMM; alu_ctrl = ALU_LUI; ext_op = EXT_ZERO;
        #10;  // PC = 0x14, alu_result = 0x12340000; no flanco $13 = 0x12340000, PC -> 0x18

        // xori $14, $13, 0x5678   (lui + xori constroem uma constante de 32 bits)
        instr = 32'h39AE5678; ctrl_nop;
        reg_write = 1; reg_dst = DST_RT; alu_src = SRC_IMM; alu_ctrl = ALU_XOR; ext_op = EXT_ZERO;
        #10;  // PC = 0x18, alu_result = 0x12345678; no flanco $14 = 0x12345678, PC -> 0x1C

        // slt $15, $9, $8   (3 < 5)
        instr = 32'h0128782A; ctrl_nop;
        reg_write = 1; reg_dst = DST_RD; alu_src = SRC_REG; alu_ctrl = ALU_SLT;
        #10;  // PC = 0x1C, alu_result = 1; no flanco $15 = 1, PC -> 0x20

        // addi $0, $0, 7   (escrita em $0 tem de ser ignorada)
        instr = 32'h20000007; ctrl_nop;
        reg_write = 1; reg_dst = DST_RT; alu_src = SRC_IMM; alu_ctrl = ALU_ADD; ext_op = EXT_SIGN;
        #10;  // PC = 0x20, alu_result = 7; no flanco $0 continua 0, PC -> 0x24

        // add $16, $0, $0   (se $0 tivesse sido escrito, dava 14)
        instr = 32'h00008020; ctrl_nop;
        reg_write = 1; reg_dst = DST_RD; alu_src = SRC_REG; alu_ctrl = ALU_ADD;
        #10;  // PC = 0x24, alu_result = 0; no flanco $16 = 0, PC -> 0x28

        // addi $17, $0, -1   (imediato 0xFFFF estendido com sinal)
        instr = 32'h2011FFFF; ctrl_nop;
        reg_write = 1; reg_dst = DST_RT; alu_src = SRC_IMM; alu_ctrl = ALU_ADD; ext_op = EXT_SIGN;
        #10;  // PC = 0x28, alu_result = FFFFFFFF; no flanco $17 = FFFFFFFF, PC -> 0x2C

        // =====================================================
        // II. Branches: o datapath da zero e rs_neg; a unidade de
        //     controlo escolhe PC_BRANCH (tomado) ou PC_NEXT
        // =====================================================

        // beq $8, $9, +3   ($8 != $9: nao toma)
        instr = 32'h11090003; ctrl_nop;
        alu_src = SRC_REG; alu_ctrl = ALU_SUB; pc_src = PC_NEXT;
        #10;  // PC = 0x2C, zero = 0; PC -> 0x30

        // beq $8, $8, +3   ($8 == $8: toma; alvo = 0x30 + 4 + 3*4)
        instr = 32'h11080003; ctrl_nop;
        alu_src = SRC_REG; alu_ctrl = ALU_SUB; pc_src = PC_BRANCH;
        #10;  // PC = 0x30, zero = 1; PC -> 0x40

        // bne $8, $9, -2   (zero = 0: toma; offset negativo, alvo = 0x40 + 4 - 2*4)
        instr = 32'h1509FFFE; ctrl_nop;
        alu_src = SRC_REG; alu_ctrl = ALU_SUB; pc_src = PC_BRANCH;
        #10;  // PC = 0x40, zero = 0; PC -> 0x3C

        // bne $8, $8, +1   (zero = 1: nao toma)
        instr = 32'h15080001; ctrl_nop;
        alu_src = SRC_REG; alu_ctrl = ALU_SUB; pc_src = PC_NEXT;
        #10;  // PC = 0x3C, zero = 1; PC -> 0x40

        // bgez $8, +2   ($8 = 5: rs_neg = 0, toma; alvo = 0x40 + 4 + 2*4)
        instr = 32'h05010002; ctrl_nop;
        alu_src = SRC_REG; alu_ctrl = ALU_SUB; pc_src = PC_BRANCH;
        #10;  // PC = 0x40, rs_neg = 0; PC -> 0x4C

        // bgez $17, +2   ($17 = -1: rs_neg = 1, nao toma)
        instr = 32'h06210002; ctrl_nop;
        alu_src = SRC_REG; alu_ctrl = ALU_SUB; pc_src = PC_NEXT;
        #10;  // PC = 0x4C, rs_neg = 1; PC -> 0x50

        // bgtz $8, +1   ($8 = 5 > 0: zero = 0 e rs_neg = 0, toma; alvo = 0x50 + 4 + 4)
        instr = 32'h1D000001; ctrl_nop;
        alu_src = SRC_REG; alu_ctrl = ALU_SUB; pc_src = PC_BRANCH;
        #10;  // PC = 0x50, zero = 0, rs_neg = 0; PC -> 0x58

        // bgtz $0, +1   ($0 = 0: zero = 1, nao toma)
        instr = 32'h1C000001; ctrl_nop;
        alu_src = SRC_REG; alu_ctrl = ALU_SUB; pc_src = PC_NEXT;
        #10;  // PC = 0x58, zero = 1; PC -> 0x5C

        // bgtz $17, +1   ($17 = -1: zero = 0 mas rs_neg = 1, nao toma)
        instr = 32'h1E200001; ctrl_nop;
        alu_src = SRC_REG; alu_ctrl = ALU_SUB; pc_src = PC_NEXT;
        #10;  // PC = 0x5C, zero = 0, rs_neg = 1; PC -> 0x60

        // =====================================================
        // III. Saltos: j, jal (escreve $31 = PC + 4) e jr
        // =====================================================

        // j 0x80   (alvo = {PC+4[31:28], index, 00})
        instr = 32'h08000020; ctrl_nop;
        pc_src = PC_JUMP;
        #10;  // PC = 0x60; PC -> 0x80

        // jal 0xC0   (RegDst = $31, WBSrc = PC+4)
        instr = 32'h0C000030; ctrl_nop;
        reg_write = 1; reg_dst = DST_RA; wb_src = WB_PC4; pc_src = PC_JUMP;
        #10;  // PC = 0x80; no flanco $31 = 0x84, PC -> 0xC0

        // jr $31
        instr = 32'h03E00008; ctrl_nop;
        pc_src = PC_JR;
        #10;  // PC = 0xC0; PC -> 0x84 (volta a seguir ao jal)

        // =====================================================
        // IV. Memoria de dados: sw, lw e lb (1 ciclo)
        // =====================================================

        // sw $8, 8($0)   (a memoria e externa: so se ve o endereco e o dado)
        instr = 32'hAC080008; ctrl_nop;
        alu_src = SRC_IMM; alu_ctrl = ALU_ADD; ext_op = EXT_SIGN;
        #10;  // PC = 0x84, alu_result = 8 (endereco), store_data = 5 ($8); PC -> 0x88

        // lw $18, 4($0)   o dado chega no mesmo ciclo e e escrito no flanco
        instr = 32'h8C120004; ctrl_nop;
        alu_src = SRC_IMM; alu_ctrl = ALU_ADD; ext_op = EXT_SIGN;
        reg_write = 1; wb_src = WB_LOAD; mem_rd = 32'hDEADBEEF;
        #10;  // PC = 0x88, alu_result = 4; no flanco $18 = DEADBEEF, PC -> 0x8C

        // lb $19, 3($0)   addr[1:0] = 3 escolhe o byte [31:24] = DE, com sinal
        instr = 32'h80130003; ctrl_nop;
        alu_src = SRC_IMM; alu_ctrl = ALU_ADD; ext_op = EXT_SIGN;
        reg_write = 1; wb_src = WB_LOAD; load_byte = 1; mem_rd = 32'hDEADBEEF;
        #10;  // PC = 0x8C, alu_result = 3; no flanco $19 = FFFFFFDE, PC -> 0x90

        // add $20, $18, $0   (le $18 para confirmar o lw)
        instr = 32'h0240A020; ctrl_nop;
        reg_write = 1; reg_dst = DST_RD; alu_src = SRC_REG; alu_ctrl = ALU_ADD; mem_rd = 32'h0;
        #10;  // PC = 0x90, alu_result = DEADBEEF; no flanco $20 = DEADBEEF, PC -> 0x94

        // add $21, $19, $0   (le $19 para confirmar o lb)
        instr = 32'h0260A820; ctrl_nop;
        reg_write = 1; reg_dst = DST_RD; alu_src = SRC_REG; alu_ctrl = ALU_ADD;
        #10;  // PC = 0x94, alu_result = FFFFFFDE; no flanco $21 = FFFFFFDE, PC -> 0x98

        // =====================================================
        // V. Interrupcoes: ei, ei_shadow, entrada e retorno
        // =====================================================

        // ei   (IE = 1; a instrucao seguinte fica protegida pelo ei_shadow)
        instr = 32'h41606020; ctrl_nop;
        ie_write = 1; ie_val = 1;
        #10;  // PC = 0x98, irq_take = 0; no flanco IE = 1, shadow = 1, PC -> 0x9C

        // lw $22, 0($0)   com irq = 1: protegido pelo shadow
        instr = 32'h8C160000; ctrl_nop;
        alu_src = SRC_IMM; alu_ctrl = ALU_ADD; ext_op = EXT_SIGN;
        reg_write = 1; wb_src = WB_LOAD; mem_rd = 32'h0000CAFE;
        irq = 1;
        #10;  // PC = 0x9C, irq_take = 0 (shadow = 1); no flanco $22 = 0000CAFE, PC -> 0xA0, shadow -> 0

        // addi $23, $0, 9   irq = 1 aceite: o controlo cancela a instrucao e vai para o vetor 2
        instr = 32'h20170009; ctrl_nop;
        alu_src = SRC_IMM; alu_ctrl = ALU_ADD; ext_op = EXT_SIGN;
        pc_src = PC_IRQ; irq_id = 2'd2;  // reg_write = 0: nenhuma escrita
        #10;  // PC = 0xA0, irq_take = 1; no flanco EPC = 0xA0, IE = 0, PC -> 0x0C, $23 nao e escrito

        // mfc0 $26, $14   (primeira instrucao do handler; irq continua a 1 mas IE = 0)
        instr = 32'h401A7000; ctrl_nop;
        reg_write = 1; reg_dst = DST_RT; wb_src = WB_EPC;
        #10;  // PC = 0x0C, irq_take = 0 (IE = 0); no flanco $26 = 0xA0 (EPC), PC -> 0x10

        // ei   (IE = 1 e shadow = 1)
        instr = 32'h41606020; ctrl_nop;
        ie_write = 1; ie_val = 1;
        #10;  // PC = 0x10, irq_take = 0 (IE ainda 0); no flanco IE = 1, shadow = 1, PC -> 0x14

        // jr $26   (retorno: com irq = 1 e IE = 1, so o shadow impede nova interrupcao)
        instr = 32'h03400008; ctrl_nop;
        pc_src = PC_JR;
        #10;  // PC = 0x14, irq_take = 0 (shadow = 1); no flanco PC -> 0xA0 (EPC), shadow -> 0

        // addi $23, $0, 9   corre outra vez, agora com irq = 0
        irq = 0;
        instr = 32'h20170009; ctrl_nop;
        reg_write = 1; reg_dst = DST_RT; alu_src = SRC_IMM; alu_ctrl = ALU_ADD; ext_op = EXT_SIGN;
        #10;  // PC = 0xA0, irq_take = 0, alu_result = 9; no flanco $23 = 9, PC -> 0xA4

        $finish;
    end
endmodule