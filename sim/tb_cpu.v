`timescale 1ns / 1ps

// CPU + memória de instruções + memória de dados.
// O programa é escrito diretamente na memória de instruções (sem ficheiro .mem).
// Ver na forma de onda: pc, pc_write, mem_phase e os registos
// u_cpu.u_datapath.u_register_file._rf[8..12].
module tb_cpu;
    reg clk;
    reg rst;
    reg irq;

    wire [31:0] pc, instr;
    wire dmem_enable, dmem_rw;
    wire [31:0] dmem_addr, dmem_wd, dmem_rd;

    // sinais internos, só para os ver na forma de onda
    wire pc_write  = u_cpu.pc_write;
    wire mem_phase = u_cpu.mem_phase;

    cpu u_cpu (
        .i_clk(clk),
        .i_rst(rst),
        .i_irq(irq),
        .o_pc(pc),
        .i_instr(instr),
        .o_dmem_enable(dmem_enable),
        .o_dmem_rw(dmem_rw),
        .o_dmem_addr(dmem_addr),
        .o_dmem_wd(dmem_wd),
        .i_dmem_rd(dmem_rd)
    );

    instruction_memory u_instruction_memory (
        .i_addr(pc),
        .o_instr(instr)
    );

    data_memory u_data_memory (
        .i_clk(clk),
        .i_en(dmem_enable),
        .i_we(dmem_enable & ~dmem_rw),  // MemRW = 0 -> escrita
        .i_addr(dmem_addr),
        .i_wd(dmem_wd),
        .o_rd(dmem_rd)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        // #1 para escrever depois do initial da própria memória
        #1;
        u_instruction_memory.mem[0] = 32'h20080008;  // 00: addi $t0,$zero,8     $t0 = 8
        u_instruction_memory.mem[1] = 32'h20090085;  // 04: addi $t1,$zero,0x85  $t1 = 85
        u_instruction_memory.mem[2] = 32'hAD090000;  // 08: sw   $t1,0($t0)      mem[8] = 85 (1 ciclo)
        u_instruction_memory.mem[3] = 32'h8D0A0000;  // 0C: lw   $t2,0($t0)      $t2 = 00000085 (2 ciclos)
        u_instruction_memory.mem[4] = 32'h810B0000;  // 10: lb   $t3,0($t0)      $t3 = FFFFFF85 (2 ciclos)
        u_instruction_memory.mem[5] = 32'h014B6020;  // 14: add  $t4,$t2,$t3     $t4 = 0000000A
        u_instruction_memory.mem[6] = 32'h08000006;  // 18: j    0x18            fica aqui
    end

    initial begin
        // ---------- reset (apanha o flanco de t = 5) ----------
        rst = 1; irq = 0; #10;  // pc = 0

        // ---------- correr o programa ----------
        // Sem interrupções (irq = 0): o vetor 0x04 não é usado aqui.
        // pc: 00, 04, 08, 0C, 0C, 10, 10, 14, 18, 18, ...
        // Em 0C e 10 o PC fica dois ciclos: no 1.º pc_write = 0 e dmem_enable = 1;
        // no 2.º mem_phase = 1 e dmem_enable = 0 (a memória só é lida uma vez).
        rst = 0; #100;

        $finish;
    end
endmodule
