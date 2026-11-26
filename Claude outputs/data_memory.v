`timescale 1ns / 1ps

module data_memory (
    input  wire        i_clk,
    input  wire        i_en,     // MemEnable (cpu o_mem_en)
    input  wire        i_rw,     // MemRW: 1 le, 0 escreve (cpu o_mem_rw)
    input  wire [31:0] i_addr,   // endereco em bytes (ALUResult)
    input  wire [31:0] i_wd,     // dado a escrever (ReadData2 / rt)
    output wire [31:0] o_rd      // palavra lida (vai para i_mem_rd do cpu)
);

    // so escreve com acesso ativo e em modo escrita (sw)
    wire we = i_en & ~i_rw;

    dmem_spram u_dmem_spram (
        .a   (i_addr[10:2]),     // 512 palavras = 2 KiB; addr[1:0] escolhe o byte (load_ext)
        .d   (i_wd),
        .clk (i_clk),
        .we  (we),
        .spo (o_rd)              // leitura combinacional (sem ciclo de espera)
    );

endmodule
