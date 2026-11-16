`timescale 1ns / 1ps

module tb_instruction_memory;
    reg [31:0] addr;

    wire [31:0] instr;

    instruction_memory u_instruction_memory (
        .i_addr(addr),
        .o_instr(instr)
    );

    initial begin
        // Programa escrito diretamente na memória (sem ficheiro .mem).
        // #1 para escrever depois do initial da própria memória.
        #1;
        u_instruction_memory.mem[0]   = 32'h20080003;  // addi $t0,$zero,3
        u_instruction_memory.mem[1]   = 32'h20090005;  // addi $t1,$zero,5
        u_instruction_memory.mem[2]   = 32'h01095020;  // add  $t2,$t0,$t1
        u_instruction_memory.mem[511] = 32'hFFFF_FFFF;  // última palavra

        // ---------- leitura assíncrona: instr muda logo com addr ----------
        addr = 32'h000; #10;  // instr = 20080003
        addr = 32'h004; #10;  // instr = 20090005
        addr = 32'h008; #10;  // instr = 01095020
        addr = 32'h00C; #10;  // instr = 0 (posição vazia)

        // ---------- endereço não alinhado: só addr[10:2] conta ----------
        addr = 32'h006; #10;  // instr = 20090005

        // ---------- última palavra e endereço acima de 2 KB ----------
        addr = 32'h7FC; #10;  // instr = FFFFFFFF
        addr = 32'h804; #10;  // instr = 20090005 (dá a volta: bits acima de 10 ignorados)

        $finish;
    end
endmodule
