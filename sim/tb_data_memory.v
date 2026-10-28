`timescale 1ns / 1ps

module tb_data_memory;
    reg         i_clk = 0;
    reg         i_en;
    reg  [31:0] i_addr, i_wd;
    reg         i_re, i_we;
    wire [31:0] o_rd;

    data_memory dut (
        .i_clk(i_clk), .i_en(i_en), .i_addr(i_addr), .i_wd(i_wd),
        .i_re(i_re), .i_we(i_we), .o_rd(o_rd)
    );

    always #5 i_clk = ~i_clk;

    integer erros = 0;

    task check(input [31:0] obtido, input [31:0] esperado, input [255:0] nome);
        begin
            if (obtido !== esperado) begin
                $display("ERRO %0s: obtido %h, esperado %h", nome, obtido, esperado);
                erros = erros + 1;
            end else
                $display("OK:   %0s = %h", nome, obtido);
        end
    endtask

    // escrita: sinais mudam no flanco de descida, o flanco de subida escreve
    task escreve(input [31:0] endereco, input [31:0] valor);
        begin
            @(negedge i_clk);
            i_addr = endereco; i_wd = valor; i_we = 1; i_re = 0;
            @(negedge i_clk);
            i_we = 0;
        end
    endtask

    // leitura: combinatória, basta pôr o endereço e i_re = 1
    task le(input [31:0] endereco);
        begin
            i_addr = endereco; i_re = 1; i_we = 0;
            #1;
        end
    endtask

    initial begin
        i_en = 1; i_addr = 0; i_wd = 0; i_re = 0; i_we = 0;
        #12;

        // 1) memória começa a zero
        le(32'h00); check(o_rd, 32'h0, "inicio addr 0");
        le(32'h3FC); check(o_rd, 32'h0, "inicio ultima palavra");

        // 2) escrever e ler a mesma posição (sw seguido de lw)
        escreve(32'h10, 32'h00000008);
        le(32'h10); check(o_rd, 32'h8, "sw/lw addr 0x10");

        // 3) posições diferentes são independentes
        escreve(32'h14, 32'hCAFEBABE);
        le(32'h10); check(o_rd, 32'h8, "addr 0x10 intacto");
        le(32'h14); check(o_rd, 32'hCAFEBABE, "addr 0x14");

        // 4) com i_re = 0 a saída vale 0, mesmo havendo dado guardado
        i_addr = 32'h10; i_re = 0; #1;
        check(o_rd, 32'h0, "i_re=0 -> saida 0");

        // 5) i_we = 0 não escreve
        @(negedge i_clk);
        i_addr = 32'h20; i_wd = 32'h11111111; i_we = 0;
        @(negedge i_clk);
        le(32'h20); check(o_rd, 32'h0, "sem write enable");

        // 6) i_en = 0 (CPU parado) não escreve
        i_en = 0;
        escreve(32'h24, 32'h22222222);
        i_en = 1;
        le(32'h24); check(o_rd, 32'h0, "sem enable global");

        // 7) endereço não alinhado cai na mesma palavra (0x13 -> palavra de 0x10)
        le(32'h13); check(o_rd, 32'h8, "addr nao alinhado");

        // 8) última palavra (0x3FC) também funciona
        escreve(32'h3FC, 32'hFFFFFFFF);
        le(32'h3FC); check(o_rd, 32'hFFFFFFFF, "ultima palavra");

        if (erros == 0) $display("TUDO OK");
        else            $display("%0d erro(s)", erros);
        $finish;
    end
endmodule