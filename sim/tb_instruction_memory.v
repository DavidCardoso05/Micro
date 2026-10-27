`timescale 1ns / 1ps

module tb_instruction_memory;
    reg         i_clk = 0;
    reg  [31:0] i_addr;
    wire [31:0] o_instr;

    instruction_memory dut (.i_clk(i_clk), .i_addr(i_addr), .o_instr(o_instr));

    integer erros = 0;

    task check(input [31:0] endereco, input [31:0] esperado);
        begin
            i_addr = endereco;
            #1;
            if (o_instr !== esperado) begin
                $display("ERRO addr=%h: obtido %h, esperado %h", endereco, o_instr, esperado);
                erros = erros + 1;
            end else
                $display("OK:   addr=%h -> %h", endereco, o_instr);
        end
    endtask

    initial begin
        // as 6 instruções do programa de teste
        check(32'h00, 32'h20080003);   // addi $t0,$zero,3
        check(32'h04, 32'h20090005);   // addi $t1,$zero,5
        check(32'h08, 32'h01095020);   // add  $t2,$t0,$t1
        check(32'h0C, 32'hAC0A0000);   // sw   $t2,0($t0)
        check(32'h10, 32'h8C0B0000);   // lw   $t3,0($t0)
        check(32'h14, 32'h114BFFFA);   // beq  $t2,$t3,-6

        // posições seguintes: nops do ficheiro e depois zeros por defeito
        check(32'h18, 32'h00000000);
        check(32'h1C, 32'h00000000);
        check(32'h20, 32'h00000000);

        // endereços não alinhados dão a mesma palavra (só o índice conta)
        check(32'h05, 32'h20090005);

        // última palavra da memória (índice 255 -> endereço 0x3FC)
        check(32'h3FC, 32'h00000000);

        if (erros == 0) $display("TUDO OK");
        else            $display("%0d erro(s)", erros);
        $finish;
    end
endmodule