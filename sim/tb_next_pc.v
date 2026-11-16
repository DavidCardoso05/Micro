`timescale 1ns / 1ps

module tb_next_pc;
    reg [31:0] pc;
    reg [15:0] imm;
    reg [25:0] index;
    reg [31:0] rs_data;
    reg [2:0] pc_src;

    wire [31:0] next_pc, pc_plus4;

    next_pc u_next_pc (
        .i_pc(pc),
        .i_imm(imm),
        .i_index(index),
        .i_rs_data(rs_data),
        .i_pc_src(pc_src),
        .o_next_pc(next_pc),
        .o_pc_plus4(pc_plus4)
    );

    initial begin
        pc = 32'h0000_0100; imm = 16'h0004; index = 26'h000_0040; rs_data = 32'h0000_0200;
        // pc_plus4 = 00000104 em todos os casos com pc = 100

        pc_src = 3'b000; #10;                  // PC + 4 -> next_pc = 00000104
        pc_src = 3'b001; #10;                  // branch para a frente: 104 + (4 << 2) = 00000114
        pc_src = 3'b001; imm = 16'hFFFE; #10;  // branch para trás: 104 - 8 = 000000FC
        pc_src = 3'b010; #10;                  // j: {0, 40, 00} = 00000100
        pc_src = 3'b011; #10;                  // jr: next_pc = rs_data = 00000200
        pc_src = 3'b100; #10;                  // interrupção: next_pc = 00000004
        pc_src = 3'b111; #10;                  // código reservado: next_pc = 00000104

        // ---------- j guarda os 4 bits altos de PC + 4 ----------
        pc = 32'h3000_0000; pc_src = 3'b010; #10;  // next_pc = 30000100

        $finish;
    end
endmodule
