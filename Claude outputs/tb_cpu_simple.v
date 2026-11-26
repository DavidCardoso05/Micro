`timescale 1ns / 1ps

// Testbench simples do cpu: sem tasks e sem verificacao automatica.
// So gera clock, reset e interrupcao; o resto ve-se na forma de onda.
// O programa vem de tb_cpu.mem (gerado de tb_cpu.asm com tools/assembler.py).
//
// Temporizacao (igual ao tb_datapath): clock de 10 ns, flancos de subida em 5, 15, 25, ...
// Cada passo de #10 comeca 1 ns depois de um flanco e e UMA instrucao.
// Os comentarios dao o que se ve nesse passo (antes do flanco seguinte);
// o que o flanco escreve (registo, memoria, PC, EPC, IE) so aparece no passo seguinte.
//
// Sinais a por na forma de onda: clk, rst, irq, pc, instr, mem_addr, mem_en, mem_rw,
// mem_wd, mem_rd, irq_take, write_data.

module tb_cpu_simple;
    reg clk;
    reg rst;
    reg irq;
    reg [1:0] irq_id;

    wire [31:0] pc;
    wire [31:0] instr;
    wire [31:0] mem_addr;   // resultado da ALU (endereco nos lw/lb/sw)
    wire [31:0] mem_wd;     // dado a escrever (rt)
    wire [31:0] mem_rd;     // dado lido da memoria
    wire mem_en;
    wire mem_rw;            // 1 le, 0 escreve

    cpu u_cpu (
        .i_clk(clk),
        .i_rst(rst),
        .i_instr(instr),
        .i_mem_rd(mem_rd),
        .i_irq(irq),
        .i_irq_id(irq_id),
        .o_pc(pc),
        .o_mem_addr(mem_addr),
        .o_mem_wd(mem_wd),
        .o_mem_en(mem_en),
        .o_mem_rw(mem_rw)
    );

    instruction_memory #(
        .INIT_FILE("tb_cpu.mem")
    ) u_imem (
        .i_addr(pc),
        .o_instr(instr)
    );

    data_memory u_dmem (
        .i_clk(clk),
        .i_en(mem_en),
        .i_rw(mem_rw),
        .i_addr(mem_addr),
        .i_wd(mem_wd),
        .o_rd(mem_rd)
    );

    // dois sinais internos uteis (o cpu nao tem portas para eles)
    wire        irq_take   = u_cpu.irq_take;
    wire [31:0] write_data = u_cpu.u_datapath.write_data;  // dado escrito no registo

    initial clk = 1'b0;
    always #5 clk = ~clk;

    initial begin
        // ---------- reset: o flanco das 5 ns poe PC = 0 ----------
        rst = 1; irq = 0; irq_id = 2'd2;
        #6;
        rst = 0;

        // =====================================================
        // I. Registos, memoria e loads
        // =====================================================
        #10;  // PC = 0x00  j main                    -> PC = 0x40
        #10;  // PC = 0x40  addi $t0, $0, 5           mem_addr = 5; no flanco $t0 = 5
        #10;  // PC = 0x44  add $t1, $t0, $t0         mem_addr = 0xA (ja le o $t0 novo)
        #10;  // PC = 0x48  sw $t1, 0x10($0)          mem_en = 1, mem_rw = 0, mem_addr = 0x10, mem_wd = 0xA
        #10;  // PC = 0x4C  lw $t2, 0x10($0)          mem_rw = 1, mem_rd = 0xA (escrito no flanco anterior)
        #10;  // PC = 0x50  add $t3, $t2, $t0         mem_addr = 0xF (load-use sem stall)
        #10;  // PC = 0x54  lui $t4, 0x8081           mem_addr = 8081_0000
        #10;  // PC = 0x58  xori $t4, $t4, 0x8283     mem_addr = 8081_8283
        #10;  // PC = 0x5C  sw $t4, 0x14($0)          mem_en = 1, mem_rw = 0, mem_wd = 8081_8283
        #10;  // PC = 0x60  lb $t5, 0x15($0)          mem_rd = 8081_8283, write_data = FFFF_FF82 (byte 1, com sinal)

        // =====================================================
        // II. Branch e saltos
        // =====================================================
        #10;  // PC = 0x64  beq $t0, $t0, skip        tomado -> PC = 0x6C (0x68 nunca aparece)
        #10;  // PC = 0x6C  bne $t0, $t0, main        nao tomado -> PC = 0x70
        #10;  // PC = 0x70  add $t6, $t6, $0          mem_addr = 0 (o addi de 0x68 nao correu)
        #10;  // PC = 0x74  jal func                  write_data = 0x78; no flanco $ra = 0x78, PC = 0x94
        #10;  // PC = 0x94  addi $v0, $0, 7           mem_addr = 7
        #10;  // PC = 0x98  jr $ra                    -> PC = 0x78
        #10;  // PC = 0x78  add $s2, $v0, $0          mem_addr = 7

        // =====================================================
        // III. Interrupcao (irq_id = 2 -> vetor 0x0C)
        // =====================================================
        irq = 1;  // pedido de interrupcao, 1 ns depois do flanco
        #10;  // PC = 0x7C  addi $s0, $0, 1           irq_take = 0 (IE = 0)
        #10;  // PC = 0x80  ei                        irq_take = 0 (IE so passa a 1 no flanco)
        #10;  // PC = 0x84  addi $s0, $s0, 1          irq_take = 0 (protegida pelo ei_shadow), mem_addr = 2
        #10;  // PC = 0x88  sw $s0, 0x20($0)          irq_take = 1, mem_en = 0 (sw cancelado); no flanco EPC = 0x88, PC = 0x0C
        irq = 0;  // fonte atendida
        #10;  // PC = 0x0C  j handler                 -> PC = 0x9C
        #10;  // PC = 0x9C  mfc0 $k0, $14             write_data = 0x88 (EPC)
        #10;  // PC = 0xA0  addi $s1, $s1, 1          mem_addr = 1
        #10;  // PC = 0xA4  ei
        #10;  // PC = 0xA8  jr $k0                    irq_take = 0 (shadow); -> PC = 0x88
        #10;  // PC = 0x88  sw $s0, 0x20($0)          agora mem_en = 1, mem_wd = 2
        #10;  // PC = 0x8C  lw $s3, 0x20($0)          mem_rd = 2
        #10;  // PC = 0x90  j fim                     fica aqui para sempre

        $finish;
    end
endmodule
