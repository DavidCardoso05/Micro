`timescale 1ns / 1ps

// Memoria de dados (DMEM): 512 palavras de 32 bits (2 KiB), em block RAM.
// Escrita e leitura sincronas, ambas no flanco de subida do clock:
//   sw      : 1 ciclo. Endereco, dado e WE sao capturados no flanco.
//   lw / lb : 2 ciclos. No flanco do 1.o ciclo a RAM guarda a palavra lida;
//             no 2.o ciclo o_rd ja a mostra (e o que o MemPhase espera).
//
// Este modulo e so o armazenamento. O decoder de enderecos, os registos MMIO
// (GPIO) e o mux de leitura ficam no subsistema da memoria de dados, que gera
// i_en e i_we a partir de MemEnable, MemRW e do endereco.
//
// Enderecamento: i_addr e um endereco em bytes. O indice da palavra e
// i_addr[10:2]; i_addr[1:0] e ignorado (so ha acessos a palavra: sw, lw e, no lb,
// o byte e escolhido fora, no load_ext). i_addr[31:11] tambem e ignorado: garantir
// que so chegam enderecos de 0 a 0x7FF e trabalho do decoder.
//
// i_en = 0: nao ha acesso, a escrita e bloqueada e o_rd mantem o ultimo valor.
// Escrita em modo read-first: no flanco de um sw, o_rd recebe o valor ANTIGO da
// palavra (o datapath nao usa o_rd depois de um sw).
//
// Conteudo inicial: tudo a 0. Se INIT_FILE nao for "", a memoria e pre-carregada
// com $readmemh (strings, constantes). Como so existe sw (nao sb), e a unica forma
// de ter bytes soltos em memoria logo no arranque.

module data_memory #(
    parameter INIT_FILE = ""
) (
    input  wire        i_clk,
    input  wire        i_en,     // EN: ha acesso neste ciclo
    input  wire        i_we,     // WE: 1 escreve (sw), 0 le (lw, lb)
    input  wire [31:0] i_addr,   // endereco em bytes
    input  wire [31:0] i_wd,     // dado do sw (ReadData2)
    output reg  [31:0] o_rd      // palavra lida, valida no ciclo seguinte ao acesso
);

    localparam DEPTH = 512;      // palavras

    (* ram_style = "block" *) reg [31:0] mem [0:DEPTH-1];

    integer i;
    initial begin
        for (i = 0; i < DEPTH; i = i + 1)
            mem[i] = 32'h0000_0000;
        if (INIT_FILE != "")
            $readmemh(INIT_FILE, mem);
        o_rd = 32'h0000_0000;
    end

    always @(posedge i_clk) begin
        if (i_en) begin
            if (i_we)
                mem[i_addr[10:2]] <= i_wd;
            o_rd <= mem[i_addr[10:2]];   // le o valor antigo (read-first)
        end
    end

endmodule
