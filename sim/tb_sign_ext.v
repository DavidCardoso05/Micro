`timescale 1ns / 1ps

module tb_sign_ext;
    reg [15:0] imm;
    reg ext_op;  // 1: extensão com sinal | 0: extensão com zeros

    wire [31:0] ext;

    sign_ext u_sign_ext (
        .i_imm(imm),
        .i_ext_op(ext_op),
        .o_ext(ext)
    );

    // Valores de ExtOp vindos da unidade de controlo
    localparam EXT_ZERO = 1'b0;  // xori, lui
    localparam EXT_SIGN = 1'b1;  // addi, lw, lb, sw, branches

    initial begin
        imm = 16'h0000; ext_op = EXT_SIGN;

        // ---------- EXT_SIGN: imediato positivo (bit 15 = 0) ----------
        ext_op = EXT_SIGN;
        imm = 16'h0000; #10;  // ext = 0000_0000
        imm = 16'h0001; #10;  // ext = 0000_0001
        imm = 16'h7FFF; #10;  // ext = 0000_7FFF (maior positivo, bit 15 ainda 0)

        // ---------- EXT_SIGN: imediato negativo (bit 15 = 1) ----------
        imm = 16'h8000; #10;  // ext = FFFF_8000 (menor negativo, o bit 15 replica-se)
        imm = 16'hFFFF; #10;  // ext = FFFF_FFFF (-1)
        imm = 16'hFFFC; #10;  // ext = FFFF_FFFC (-4, offset típico de um branch para trás)

        // ---------- EXT_ZERO: os 16 bits de cima ficam sempre a 0 ----------
        ext_op = EXT_ZERO;
        imm = 16'h0000; #10;  // ext = 0000_0000
        imm = 16'h0001; #10;  // ext = 0000_0001
        imm = 16'h7FFF; #10;  // ext = 0000_7FFF
        imm = 16'h8000; #10;  // ext = 0000_8000 (com EXT_SIGN dava FFFF_8000)
        imm = 16'hFFFF; #10;  // ext = 0000_FFFF (com EXT_SIGN dava FFFF_FFFF)

        // ---------- mudar ExtOp com o mesmo imediato ----------
        imm = 16'hABCD;
        ext_op = EXT_SIGN; #10;  // ext = FFFF_ABCD
        ext_op = EXT_ZERO; #10;  // ext = 0000_ABCD
        ext_op = EXT_SIGN; #10;  // ext = FFFF_ABCD (só ExtOp mudou, a saída acompanha logo)

        $finish;
    end
endmodule