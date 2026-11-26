`timescale 1ns / 1ps

// Testbench da data_memory (IP Distributed Memory, single port, 512 x 32).
// Escrita sincrona (flanco de subida), leitura COMBINACIONAL (sem ciclo de espera).
// Clock de 10 ns, flancos em 5, 15, 25, ... As entradas mudam 1 ns depois do flanco;
// o valor indicado em cada comentario e o de rd ANTES do flanco seguinte.

module tb_data_memory;
    reg clk;
    reg en;              // MemEnable
    reg rw;              // 1 le, 0 escreve
    reg [31:0] addr;     // endereco em bytes
    reg [31:0] wd;
    wire [31:0] rd;

    data_memory u_dmem (
        .i_clk(clk), .i_en(en), .i_rw(rw),
        .i_addr(addr), .i_wd(wd), .o_rd(rd)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        en = 0; rw = 1; addr = 32'h0; wd = 32'h0;
        #6;  // 1 ns depois do flanco das 5 ns

        // ---------- 1. estado inicial: tudo a 0 ----------
        en = 1; rw = 1; addr = 32'h0000_0000; #10;  // rd = 0000_0000
        addr = 32'h0000_07FC;                 #10;  // rd = 0000_0000 (ultima palavra)

        // ---------- 2. escrita: o valor novo aparece LOGO a seguir ao flanco ----------
        en = 1; rw = 0; addr = 32'h0000_0010; wd = 32'hDEAD_BEEF; #4;  // t=30: rd = 0000_0000 (antes do flanco)
                                                                  #6;  // t=36: rd = DEAD_BEEF (flanco das 35 escreveu)
        en = 1; rw = 1; wd = 32'h0;                               #10; // rd = DEAD_BEEF (lw no ciclo seguinte)

        // ---------- 3. en = 0: nao escreve, mesmo com rw = 0 ----------
        en = 0; rw = 0; wd = 32'hFFFF_FFFF; #10;  // rd = DEAD_BEEF
        en = 1; rw = 1;                     #10;  // rd = DEAD_BEEF (o flanco nao escreveu)

        // ---------- 4. rw = 1 (lw/lb): nao escreve ----------
        en = 1; rw = 1; wd = 32'h1234_5678; #10;  // rd = DEAD_BEEF
                                            #10;  // rd = DEAD_BEEF

        // ---------- 5. addr[1:0] ignorado: 0x11..0x13 sao a mesma palavra ----------
        addr = 32'h0000_0011; #10;  // rd = DEAD_BEEF
        addr = 32'h0000_0013; #10;  // rd = DEAD_BEEF (o byte e escolhido no load_ext)

        // ---------- 6. escritas seguidas em palavras vizinhas ----------
        en = 1; rw = 0; addr = 32'h0000_0014; wd = 32'h8081_8283; #10; // rd = 0000_0000 (0x14 ainda antigo)
        en = 1; rw = 0; addr = 32'h0000_0018; wd = 32'hCAFE_0001; #10; // rd = 0000_0000 (0x18 ainda antigo)
        en = 1; rw = 1; addr = 32'h0000_0014;                     #10; // rd = 8081_8283
        addr = 32'h0000_0018;                                     #10; // rd = CAFE_0001
        addr = 32'h0000_0010;                                     #10; // rd = DEAD_BEEF (vizinha intacta)

        // ---------- 7. ultima palavra e aliasing (addr[31:11] ignorado) ----------
        en = 1; rw = 0; addr = 32'h0000_07FC; wd = 32'h0000_07FC; #10; // rd = 0000_0000 (antigo)
        en = 1; rw = 1;                                           #10; // rd = 0000_07FC
        addr = 32'h0000_0810;                                     #10; // rd = DEAD_BEEF (0x810 = palavra 4 = 0x010)

        // ---------- 8. sobrescrever: o valor antigo aguenta ate ao flanco ----------
        en = 1; rw = 0; addr = 32'h0000_0010; wd = 32'h0000_0001; #10; // rd = DEAD_BEEF (antigo)
        en = 1; rw = 1;                                           #10; // rd = 0000_0001

        $finish;
    end
endmodule
