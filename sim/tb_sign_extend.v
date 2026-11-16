`timescale 1ns / 1ps

module tb_sign_extend;
    reg [15:0] imm;
    reg ext_op;

    wire [31:0] ext;

    sign_extend u_sign_extend (
        .i_imm(imm),
        .i_ext_op(ext_op),
        .o_ext(ext)
    );

    initial begin
        // ---------- extensão com sinal (addi, lw, lb, sw) ----------
        ext_op = 1; imm = 16'h7FFF; #10;  // ext = 00007FFF (positivo)
        ext_op = 1; imm = 16'h8000; #10;  // ext = FFFF8000 (negativo)

        // ---------- extensão com zeros (xori, lui) ----------
        ext_op = 0; imm = 16'h7FFF; #10;  // ext = 00007FFF
        ext_op = 0; imm = 16'h8000; #10;  // ext = 00008000

        $finish;
    end
endmodule
