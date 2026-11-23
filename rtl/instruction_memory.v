`timescale 1ns / 1ps

// Memoria de instrucoes (IMEM): ROM de 512 palavras de 32 bits (2 KiB), em LUTs.
// Leitura assincrona: sem clock e sem reset, a instrucao aparece no mesmo ciclo
// em que o PC chega, por isso as instrucoes normais terminam num ciclo.
//
// Mapa (espaco de instrucoes, ver Memory Map):
//   0x0000_0000  reset: j main
//   0x0000_0004  inicio do handler de interrupcao
//   ...          handler e depois main
//
// Enderecamento: i_addr e um endereco em bytes (o PC). O indice da palavra e
// i_addr[10:2]. A IMEM nao e descodificada: i_addr[31:11] e ignorado, por isso
// enderecos acima de 2 KiB repetem (aliasing) o mesmo conteudo. i_addr[1:0] e
// ignorado porque o PC esta sempre alinhado a palavra.
//
// Conteudo: carregado de INIT_FILE (hex, uma palavra por linha, como $readmemh).
// As palavras que o ficheiro nao preenche ficam a 0x0000_0000, que e sll $0,$0,0,
// ou seja, um nop.

module instruction_memory #(
    parameter INIT_FILE = "program.mem"
) (
    input  wire [31:0] i_addr,   // PC, endereco em bytes
    output wire [31:0] o_instr   // instrucao lida
);

    localparam DEPTH = 512;      // palavras

    reg [31:0] mem [0:DEPTH-1];  // so e lida: o synth infere ROM

    integer i;
    initial begin
        for (i = 0; i < DEPTH; i = i + 1)
            mem[i] = 32'h0000_0000;      // por omissao: nop
        $readmemh(INIT_FILE, mem);
    end

    assign o_instr = mem[i_addr[10:2]];

endmodule
