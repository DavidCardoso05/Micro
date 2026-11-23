`timescale 1ns / 1ps

// Testbench da instruction_memory. A memoria e uma ROM combinacional (sem clock):
// cada passo muda o endereco e, no fim dos 10 ns, o_instr ja mostra a palavra
// correspondente. O conteudo vem de tb_instruction_memory.mem.

module tb_instruction_memory;
    reg [31:0] addr;        // PC, endereco em bytes
    wire [31:0] instr;

    instruction_memory #(
        .INIT_FILE("tb_instruction_memory.mem")
    ) u_imem (
        .i_addr(addr),
        .o_instr(instr)
    );

    initial begin
        addr = 32'h0000_0000;

        // ---------- palavras preenchidas no inicio ----------
        addr = 32'h0000_0000; #10;  // instr = 0800_0010 (j main)
        addr = 32'h0000_0004; #10;  // instr = 401A_7000 (mfc0 $k0, $14)
        addr = 32'h0000_0008; #10;  // instr = 4160_6020 (ei)
        addr = 32'h0000_000C; #10;  // instr = 0340_0008 (jr $k0)
        addr = 32'h0000_0010; #10;  // instr = 2008_0005 (addi $8, $0, 5)

        // ---------- palavra nao preenchida: nop ----------
        addr = 32'h0000_0014; #10;  // instr = 0000_0000 (sll $0, $0, 0)
        addr = 32'h0000_0400; #10;  // instr = 0000_0000 (meio da memoria, tambem vazio)

        // ---------- ultima palavra (indice 511) ----------
        addr = 32'h0000_07FC; #10;  // instr = DEAD_BEEF

        // ---------- aliasing: addr[31:11] e ignorado ----------
        addr = 32'h0000_0800; #10;  // instr = 0800_0010 (igual a 0x000)
        addr = 32'h0000_0804; #10;  // instr = 401A_7000 (igual a 0x004)
        addr = 32'h0000_0FFC; #10;  // instr = DEAD_BEEF (igual a 0x7FC)
        addr = 32'hFFFF_F800; #10;  // instr = 0800_0010 (bits altos ignorados)

        // ---------- addr[1:0] ignorado (o PC esta sempre alinhado) ----------
        addr = 32'h0000_0006; #10;  // instr = 401A_7000 (igual a 0x004)

        // ---------- mudancas seguidas: a saida acompanha o endereco ----------
        addr = 32'h0000_0010; #10;  // instr = 2008_0005
        addr = 32'h0000_0000; #10;  // instr = 0800_0010

        $finish;
    end
endmodule
