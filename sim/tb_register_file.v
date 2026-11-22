`timescale 1ns / 1ps

// Testbench do register_file (usa o IP rf_dpram: RAM distribuida, escrita sincrona,
// leitura assincrona; sem reset, os registos arrancam a 0 pelo valor por omissao do IP).
//
// Temporizacao: o clock tem periodo 10 ns, com flancos de subida em 5, 15, 25, ...
// As entradas mudam 1 ns depois de cada flanco (6, 16, 26, ...), por isso cada
// passo e um ciclo completo. As leituras sao combinacionais: no FIM do passo, antes
// do flanco seguinte, rd1 e rd2 mostram o valor ANTIGO do registo. O que o flanco
// escreve so aparece no passo seguinte.

module tb_register_file;
    reg clk;
    reg [4:0] ra1, ra2;   // rs e rt: enderecos de leitura
    reg [4:0] wa;         // registo de destino (vem do mux RegDst)
    reg [31:0] wd;        // dado a escrever (vem do mux de write-back)
    reg we;               // RegWrite

    wire [31:0] rd1, rd2;

    register_file u_register_file (
        .i_clk(clk),
        .i_ra1(ra1),
        .i_ra2(ra2),
        .i_wa(wa),
        .i_wd(wd),
        .i_we(we),
        .o_rd1(rd1),
        .o_rd2(rd2)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    // Valores de teste
    localparam V_DEAD = 32'hDEAD_BEEF;
    localparam V_1234 = 32'h1234_5678;
    localparam V_CAFE = 32'hCAFE_0001;
    localparam V_RA   = 32'h0000_0040;   // tipico valor de $ra (PC + 4 do jal)

    initial begin
        ra1 = 5'd0; ra2 = 5'd0; wa = 5'd0; wd = 32'd0; we = 1'b0;
        #6;  // alinha com o primeiro passo (1 ns depois do flanco das 5 ns)

        // ---------- 1. estado inicial: nenhum registo foi escrito ----------
        ra1 = 5'd8; ra2 = 5'd9; we = 0; #10;   // rd1 = rd2 = 0000_0000 (valor por omissao do IP)

        // ---------- 2. escrever $8: a leitura no mesmo ciclo da o valor antigo ----------
        we = 1; wa = 5'd8; wd = V_DEAD; ra1 = 5'd8; ra2 = 5'd0; #10;  // rd1 = 0 (antigo), rd2 = 0 ($0)
        we = 0; wa = 5'd0; wd = 32'd0;  ra1 = 5'd8; ra2 = 5'd8; #10;  // rd1 = rd2 = DEAD_BEEF (as duas portas leem o mesmo registo)

        // ---------- 3. dois registos, uma porta cada ----------
        we = 1; wa = 5'd9; wd = V_1234; ra1 = 5'd8; ra2 = 5'd9; #10;  // rd1 = DEAD_BEEF, rd2 = 0 ($9 ainda antigo)
        we = 0; wa = 5'd0; wd = 32'd0;  ra1 = 5'd9; ra2 = 5'd8; #10;  // rd1 = 1234_5678, rd2 = DEAD_BEEF (portas trocadas)

        // ---------- 4. escrever em $0: continua a ler 0 ----------
        we = 1; wa = 5'd0; wd = 32'hFFFF_FFFF; ra1 = 5'd0; ra2 = 5'd0; #10;  // rd1 = rd2 = 0
        we = 0;                                ra1 = 5'd0; ra2 = 5'd0; #10;  // rd1 = rd2 = 0 (a escrita foi bloqueada, nao so mascarada)

        // ---------- 5. we = 0: o registo nao muda ----------
        we = 0; wa = 5'd8; wd = 32'hFFFF_FFFF; ra1 = 5'd8; ra2 = 5'd0; #10;  // rd1 = DEAD_BEEF
        ra1 = 5'd8;                                                         #10;  // rd1 = DEAD_BEEF (o flanco nao escreveu)

        // ---------- 6. $31 ($ra, destino do jal) ----------
        we = 1; wa = 5'd31; wd = V_RA; ra1 = 5'd31; ra2 = 5'd0; #10;  // rd1 = 0 (antigo)
        we = 0; wa = 5'd0;  wd = 32'd0; ra1 = 5'd31; ra2 = 5'd31; #10; // rd1 = rd2 = 0000_0040

        // ---------- 7. sobrescrever $8: o valor antigo aguenta ate ao flanco ----------
        we = 1; wa = 5'd8; wd = V_CAFE; ra1 = 5'd8; ra2 = 5'd31; #10;  // rd1 = DEAD_BEEF (antigo), rd2 = 0000_0040
        we = 0; wa = 5'd0; wd = 32'd0;  ra1 = 5'd8; ra2 = 5'd9;  #10;  // rd1 = CAFE_0001, rd2 = 1234_5678 ($9 intacto)

        // ---------- 8. extremos do enderecamento: $1 e $30 sem aliasing ----------
        we = 1; wa = 5'd1;  wd = 32'h0000_0001; ra1 = 5'd1;  ra2 = 5'd30; #10;  // rd1 = 0, rd2 = 0
        we = 1; wa = 5'd30; wd = 32'h0000_001E; ra1 = 5'd1;  ra2 = 5'd30; #10;  // rd1 = 0000_0001, rd2 = 0 (antigo)
        we = 0; wa = 5'd0;  wd = 32'd0;         ra1 = 5'd1;  ra2 = 5'd30; #10;  // rd1 = 0000_0001, rd2 = 0000_001E
        ra1 = 5'd31; ra2 = 5'd8;                                          #10;  // rd1 = 0000_0040, rd2 = CAFE_0001 (nada foi corrompido)

        $finish;
    end
endmodule