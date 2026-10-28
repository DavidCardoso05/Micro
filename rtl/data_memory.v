`timescale 1ns / 1ps

// Memória de dados (RAM), leitura combinatória, escrita síncrona
// - i_addr é endereço de byte (vem do ALU); o índice usa i_addr[ADDR_BITS+1:2]
// - 2^ADDR_BITS palavras de 32 bits (por defeito 256 palavras = 1 KB)
// - o_rd só mostra o dado quando i_re = 1, caso contrário vale 0
// - a escrita só acontece com i_we = 1 e i_en = 1
module data_memory #(
    parameter ADDR_BITS = 8
)(
    input  wire        i_clk,
    input  wire        i_en,     // enable global do CPU
    input  wire [31:0] i_addr,
    input  wire [31:0] i_wd,     // dado a escrever (sw)
    input  wire        i_re,     // read enable (lw)
    input  wire        i_we,     // write enable (sw)
    output wire [31:0] o_rd      // dado lido
);

    reg [31:0] mem [0:(1<<ADDR_BITS)-1];
    integer i;

    initial begin
        for (i = 0; i < (1<<ADDR_BITS); i = i + 1)
            mem[i] = 32'h00000000;
    end

    wire [ADDR_BITS-1:0] idx = i_addr[ADDR_BITS+1:2];

    always @(posedge i_clk) begin
        if (i_we && i_en)
            mem[idx] <= i_wd;
    end

    assign o_rd = i_re ? mem[idx] : 32'h00000000;

endmodule