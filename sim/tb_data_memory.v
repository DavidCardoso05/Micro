`timescale 1ns / 1ps

// Testbench da data_memory (block RAM: escrita e leitura sincronas).
//
// Temporizacao: o clock tem periodo 10 ns, com flancos de subida em 5, 15, 25, ...
// As entradas mudam 1 ns depois de cada flanco (6, 16, 26, ...), por isso cada
// passo e um ciclo completo. Le-se o resultado no FIM do passo (antes do flanco
// seguinte). O acesso pedido num passo e capturado nesse flanco, e o_rd so mostra
// o resultado no passo SEGUINTE (leitura sincrona). E por isso que o lw leva dois
// ciclos: ciclo 1 pede o endereco, ciclo 2 (mesmo endereco) ja tem o dado.
//
// Conteudo inicial vindo de tb_data_memory.mem: [0x00] = 6C6C6548, [0x04] = 0000006F.

module tb_data_memory;
    reg clk;
    reg en;            // EN: ha acesso neste ciclo
    reg we;            // WE: 1 sw, 0 lw / lb
    reg [31:0] addr;   // endereco em bytes (alu_result)
    reg [31:0] wd;     // dado do sw (ReadData2)

    wire [31:0] rd;

    data_memory #(
        .INIT_FILE("tb_data_memory.mem")
    ) u_dmem (
        .i_clk(clk),
        .i_en(en),
        .i_we(we),
        .i_addr(addr),
        .i_wd(wd),
        .o_rd(rd)
    );

    initial clk = 1'b0;
    always #5 clk = ~clk;

    initial begin
        en = 0; we = 0; addr = 32'h0; wd = 32'h0;
        #6;  // alinha com o primeiro passo (1 ns depois do flanco das 5 ns)

        // =====================================================
        // I. Conteudo inicial, palavra a palavra (lw: 2 ciclos)
        // =====================================================

        // lw 0x00   ciclo 1
        en = 1; we = 0; addr = 32'h0000_0000; wd = 32'h0;
        #10;  // rd = 0000_0000 (ainda nada lido); no flanco guarda a palavra 0x00
        // lw 0x00   ciclo 2
        #10;  // rd = 6C6C_6548 ("Hell", pre-carregado)

        // lw 0x04   ciclo 1
        addr = 32'h0000_0004;
        #10;  // rd = 6C6C_6548 (leitura anterior); no flanco guarda a palavra 0x04
        // lw 0x04   ciclo 2
        #10;  // rd = 0000_006F ("o", pre-carregado)

        // lw 0x08   palavra que o ficheiro nao preenche
        addr = 32'h0000_0008;
        #10;  // rd = 0000_006F (leitura anterior); no flanco guarda a palavra 0x08
        #10;  // rd = 0000_0000 (o resto da memoria arranca a 0)

        // i_addr[1:0] e ignorado: 0x06 e a mesma palavra que 0x04
        addr = 32'h0000_0006;
        #10;  // rd = 0000_0000 (leitura anterior); no flanco guarda a palavra 0x04
        #10;  // rd = 0000_006F (igual a ler 0x04)

        // =====================================================
        // II. sw: escrita num ciclo, depois lw para confirmar
        // =====================================================

        // sw 0x00   escreve por cima do conteudo pre-carregado
        en = 1; we = 1; addr = 32'h0000_0000; wd = 32'hDEAD_BEEF;
        #10;  // rd = 0000_006F (nao muda: e o fim da leitura anterior); no flanco mem[0x00] = DEADBEEF

        // lw 0x00   ciclo 1
        we = 0; wd = 32'h0;
        #10;  // rd = 6C6C_6548 (o sw deixa o valor ANTIGO na saida, read-first; o datapath nao o usa)
        // lw 0x00   ciclo 2
        #10;  // rd = DEAD_BEEF (a escrita substituiu o 6C6C6548)

        // lw 0x04   a palavra vizinha nao foi tocada
        addr = 32'h0000_0004;
        #10;  // rd = DEAD_BEEF (leitura anterior)
        #10;  // rd = 0000_006F

        // =====================================================
        // III. Varias palavras, incluindo a ultima (indice 511)
        // =====================================================

        // sw 0x08
        we = 1; addr = 32'h0000_0008; wd = 32'hCAFE_0001;
        #10;  // rd = 0000_006F; no flanco mem[0x08] = CAFE0001

        // sw 0x7FC   ultima palavra
        addr = 32'h0000_07FC; wd = 32'h1234_5678;
        #10;  // rd = 0000_0000 (valor antigo de 0x08, deixado pelo sw anterior); no flanco mem[0x7FC] = 12345678

        // lw 0x08   ciclos 1 e 2
        we = 0; addr = 32'h0000_0008; wd = 32'h0;
        #10;  // rd = 0000_0000 (valor antigo de 0x7FC, deixado pelo sw anterior)
        #10;  // rd = CAFE_0001

        // lw 0x7FC  ciclos 1 e 2
        addr = 32'h0000_07FC;
        #10;  // rd = CAFE_0001 (leitura anterior)
        #10;  // rd = 1234_5678 (ultima palavra)

        // lw 0x00   ciclos 1 e 2: nada foi corrompido
        addr = 32'h0000_0000;
        #10;  // rd = 1234_5678 (leitura anterior)
        #10;  // rd = DEAD_BEEF

        // =====================================================
        // IV. EN = 0: sem acesso
        // =====================================================

        // sw com EN = 0 nao escreve
        en = 0; we = 1; addr = 32'h0000_0008; wd = 32'hFFFF_FFFF;
        #10;  // rd = DEAD_BEEF (EN = 0: a saida nao muda)

        // lw 0x08   continua CAFE0001
        en = 1; we = 0; wd = 32'h0;
        #10;  // rd = DEAD_BEEF (leitura anterior); no flanco guarda a palavra 0x08
        #10;  // rd = CAFE_0001 (a escrita bloqueada nao aconteceu)

        // EN = 0 mantem a saida, mesmo com outro endereco
        en = 0; addr = 32'h0000_0000;
        #10;  // rd = CAFE_0001; no flanco nao ha leitura
        #10;  // rd = CAFE_0001 (continua; nao passou para DEADBEEF)

        // EN = 1 volta a atualizar a saida
        en = 1;
        #10;  // rd = CAFE_0001; no flanco guarda a palavra 0x00
        en = 0;
        #10;  // rd = DEAD_BEEF

        $finish;
    end
endmodule
