`timescale 1ns/1ps

module sign_ext(
    input wire [15:0] i_imm,
    input wire i_ext_op, // 1 -> sign extend ; 0-> zero extend 
    output wire [31:0] o_ext
);

    assign o_ext = i_ext_op ? {{16{i_imm[15]}}, i_imm} : {16'b0, i_imm};

endmodule