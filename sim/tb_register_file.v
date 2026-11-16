`timescale 1ns / 1ps

module tb_register_file;
    reg clk;
    reg rst;
    reg we; //Write Enable
    reg [4:0] wa; //Write Adress
    reg[31:0] wd; //Write Data
    reg [4:0] ra1, ra2;

    wire [31:0] rd1, rd2;

    register_file u_register_file(
        .i_clk(clk),
        .i_rst(rst),
        .i_we(we),

        .i_wa(wa),
        .i_wd(wd),

        .i_ra1(ra1),
        .o_rd1(rd1),
        .i_ra2(ra2),
        .o_rd2(rd2)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
             // ---------- Escrever $8 e ler ----------
        we = 1; wa = 5'd8;  wd = 32'hDEAD_BEEF; ra1 = 5'd8;  ra2 = 5'd0;  #10;  // rd1 muda para DEADBEEF no flanco
        we = 0; wa = 5'd0;  wd = 32'h0;         ra1 = 5'd8;  ra2 = 5'd8;  #10;  // rd1 = rd2 = DEADBEEF

        // ---------- Escrever $9 e ler as duas portas em simultâneo ----------
        we = 1; wa = 5'd9;  wd = 32'h1234_5678; ra1 = 5'd8;  ra2 = 5'd9;  #10;  // rd2 muda para 12345678 no flanco
        we = 0; wa = 5'd0;  wd = 32'h0;         ra1 = 5'd9;  ra2 = 5'd8;  #10;  // rd1 = 12345678, rd2 = DEADBEEF

        // ---------- Escrever em $0 (tem de ser ignorado) ----------
        we = 1; wa = 5'd0;  wd = 32'hFFFF_FFFF; ra1 = 5'd0;  ra2 = 5'd0;  #10;  // rd1 = rd2 = 0

        // ---------- en = 0: não pode escrever ----------
        we = 1; wa = 5'd8;  wd = 32'h0000_0000; ra1 = 5'd8;  ra2 = 5'd0;  #10;  // rd1 continua DEADBEEF

        // ---------- we = 0: não pode escrever ----------
        we = 0; wa = 5'd8;  wd = 32'h0000_0000; ra1 = 5'd8;  ra2 = 5'd0;  #10;  // rd1 continua DEADBEEF

        // ---------- Escrever $31 ($ra) ----------
        we = 1; wa = 5'd31; wd = 32'h0000_0040; ra1 = 5'd31; ra2 = 5'd0;  #10;  // rd1 = 00000040

        // ---------- Reescrever $8 (ler e escrever o mesmo registo) ----------
        we = 1; wa = 5'd8;  wd = 32'hCAFE_0001; ra1 = 5'd8;  ra2 = 5'd0;  #10;  // antes do flanco: DEADBEEF; depois: CAFE0001

        $finish;
    end
endmodule
