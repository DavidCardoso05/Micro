`timescale 1ns / 1ps

module tb_data_memory;
    reg clk;
    reg en;  // acesso à memória
    reg we;  // 1 = escrita
    reg [31:0] addr;
    reg [31:0] wd;

    wire [31:0] rd;

    data_memory u_data_memory (
        .i_clk(clk),
        .i_en(en),
        .i_we(we),
        .i_addr(addr),
        .i_wd(wd),
        .o_rd(rd)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    // As entradas mudam no flanco de descida (t = 10, 20, ...);
    // a memória atua no flanco de subida seguinte (t = 15, 25, ...).
    // Numa escrita, rd recebe o valor que estava lá antes (read-first).
    initial begin
        // ---------- sem acesso: rd fica a 0 ----------
        en = 0; we = 0; addr = 32'h0;   wd = 32'h0;         #10;  // rd = 0

        // ---------- escrever 0x10 e 0x14 ----------
        en = 1; we = 1; addr = 32'h10;  wd = 32'hDEAD_BEEF; #10;  // mem[0x10] = DEADBEEF
        en = 1; we = 1; addr = 32'h14;  wd = 32'h1234_5678; #10;  // mem[0x14] = 12345678

        // ---------- ler: o dado aparece um flanco depois ----------
        en = 1; we = 0; addr = 32'h10;  wd = 32'h0;         #10;  // rd = DEADBEEF depois do flanco
        en = 1; we = 0; addr = 32'h14;                      #10;  // rd = 12345678 depois do flanco

        // ---------- en = 0: não lê nem escreve ----------
        en = 0; we = 1; addr = 32'h10;  wd = 32'hFFFF_FFFF; #10;  // rd continua 12345678
        en = 1; we = 0; addr = 32'h10;                      #10;  // rd = DEADBEEF (não foi escrito)

        // ---------- endereço não alinhado: mesma palavra ----------
        en = 1; we = 0; addr = 32'h17;                      #10;  // rd = 12345678 (palavra 0x14)

        // ---------- última palavra (índice 511 = 0x7FC) ----------
        en = 1; we = 1; addr = 32'h7FC; wd = 32'hCAFE_0001; #10;  // escreve; rd = 0 (lê o valor antigo)
        en = 1; we = 0; addr = 32'h7FC;                     #10;  // rd = CAFE0001

        $finish;
    end
endmodule
