`timescale 1ns / 1ps

// Extensor de imediato de 16 para 32 bits
// i_ext_op = 1 -> extensão com sinal (addi, lw, sw, beq, bne)
// i_ext_op = 0 -> extensão com zeros (andi, ori, xori, lui)
module sign_extend (
    input  wire [15:0] i_imm,
    input  wire        i_ext_op,
    output wire [31:0] o_ext
);
    assign o_ext = i_ext_op ? {{16{i_imm[15]}}, i_imm} : {16'b0, i_imm};
endmodule
