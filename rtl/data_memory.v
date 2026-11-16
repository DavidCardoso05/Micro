`timescale 1ns / 1ps

// Memória de dados (RAM), leitura e escrita síncronas (o Vivado infere block RAM)
// - i_addr é endereço de byte (vem da ALU); o índice de palavra é i_addr[ADDR_BITS+1:2]
// - 2^ADDR_BITS palavras de 32 bits (por defeito 512 palavras = 2 KB)
// - com i_en = 1, em cada flanco de subida:
//     o_rd passa a ter mem[índice] (o valor ANTES de uma escrita no mesmo flanco)
//     se i_we = 1, mem[índice] recebe i_wd
// - o_rd só muda com i_en = 1: o lw lê no 1.º ciclo e, no 2.º (i_en = 0), o_rd
//   mantém o dado para o write-back
// - sem reset: o conteúdo de uma block RAM não pode ser posto a zero por reset
module data_memory #(
    parameter ADDR_BITS = 9
)(
    input  wire        i_clk,
    input  wire        i_en,     // acesso à memória (lw, lb, sw)
    input  wire        i_we,     // 1 = escrita (sw), 0 = leitura
    input  wire [31:0] i_addr,
    input  wire [31:0] i_wd,     // dado a escrever (sw)
    output wire [31:0] o_rd      // dado lido (um ciclo depois)
);

    reg [31:0] mem [0:(1<<ADDR_BITS)-1];
    reg [31:0] rd_r;
    integer i;

    initial begin
        for (i = 0; i < (1<<ADDR_BITS); i = i + 1)
            mem[i] = 32'h00000000;
        rd_r = 32'h00000000;
    end

    wire [ADDR_BITS-1:0] idx = i_addr[ADDR_BITS+1:2];

    // escrita
    always @(posedge i_clk) begin
        if (i_en && i_we)
            mem[idx] <= i_wd;
    end

    // leitura
    always @(posedge i_clk) begin
        if (i_en)
            rd_r <= mem[idx];
    end

    assign o_rd = rd_r;

endmodule
