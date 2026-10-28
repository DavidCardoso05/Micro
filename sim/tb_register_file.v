`timescale 1ns / 1ps

module tb_register_file;
    reg         i_clk = 0;
    reg         i_rst;
    reg         i_we;
    reg  [4:0]  i_ra1, i_ra2, i_wa;
    reg  [31:0] i_wd;
    wire [31:0] o_rd1, o_rd2;

    register_file dut (
        .i_clk(i_clk), .i_rst(i_rst), .i_we(i_we),
        .i_ra1(i_ra1), .i_ra2(i_ra2), .i_wa(i_wa), .i_wd(i_wd),
        .o_rd1(o_rd1), .o_rd2(o_rd2)
    );

    // relógio de 10 ns de período
    always #5 i_clk = ~i_clk;

    integer erros = 0;
    integer k;

    task check(input [31:0] obtido, input [31:0] esperado, input [255:0] nome);
        begin
            if (obtido !== esperado) begin
                $display("ERRO %0s: obtido %h, esperado %h", nome, obtido, esperado);
                erros = erros + 1;
            end else
                $display("OK:   %0s = %h", nome, obtido);
        end
    endtask

    // escreve um valor num registo (a escrita acontece no flanco de subida)
    task escreve(input [4:0] reg_n, input [31:0] valor);
        begin
            @(negedge i_clk);
            i_wa = reg_n; i_wd = valor; i_we = 1;
            @(negedge i_clk);   // passou um flanco de subida
            i_we = 0;
        end
    endtask

    initial begin
        i_rst = 1; i_we = 0; i_ra1 = 0; i_ra2 = 0; i_wa = 0; i_wd = 0;
        #12 i_rst = 0;

        // 1) depois do reset, todos os registos valem 0
        for (k = 0; k < 32; k = k + 1) begin
            i_ra1 = k; #1;
            check(o_rd1, 32'h0, "reset reg");
        end

        // 2) escrever em $t0 (8) e $t1 (9) e ler os dois em simultâneo
        escreve(5'd8, 32'h00000003);
        escreve(5'd9, 32'h00000005);
        i_ra1 = 5'd8; i_ra2 = 5'd9; #1;
        check(o_rd1, 32'h3, "t0");
        check(o_rd2, 32'h5, "t1");

        // 3) escrever em $zero deve ser ignorado
        escreve(5'd0, 32'hDEADBEEF);
        i_ra1 = 5'd0; #1;
        check(o_rd1, 32'h0, "zero apos escrita");

        // 4) i_we = 0 não pode escrever
        @(negedge i_clk);
        i_wa = 5'd10; i_wd = 32'h12345678; i_we = 0;
        @(negedge i_clk);
        i_ra1 = 5'd10; #1;
        check(o_rd1, 32'h0, "sem write enable");

        // 5) o último registo ($ra = 31) também funciona
        escreve(5'd31, 32'hCAFEBABE);
        i_ra1 = 5'd31; #1;
        check(o_rd1, 32'hCAFEBABE, "ra");

        // 6) o reset limpa tudo
        i_rst = 1; #1; i_rst = 0;
        i_ra1 = 5'd8; i_ra2 = 5'd31; #1;
        check(o_rd1, 32'h0, "t0 apos reset");
        check(o_rd2, 32'h0, "ra apos reset");

        if (erros == 0) $display("TUDO OK");
        else            $display("%0d erro(s)", erros);
        $finish;
    end
endmodule