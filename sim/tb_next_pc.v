`timescale 1ns / 1ps

//Esta a dar errado por isso é preciso verificar. Faltam alguns sinais acho eu, mas verificar

module tb_next_pc;

    reg [31:0] pc;
    reg [15:0] imm;
    reg [25:0] target;
    reg [31:0] rs_data;
    reg [2:0] pc_src;

    wire [31:0] next_pc, pc_plus4;

    next_pc u_next_pc(
        .i_pc (pc),
        .i_imm (imm),
        .i_target (target),
        .i_rs_data (rs_data),
        .i_pc_src (pc_src),

        .o_next_pc (next_pc),
        .o_pc_plus4 (pc_plus4)
    );

    initial begin
        pc = 32'h0000_0000; imm = 16'h0004; target = 26'h0000_0040; rs_data = 32'h0000_0200;

        pc_src = 3'b000; #10;  // PC_NEXT
        pc_src = 3'b001; #10;  // PC_BRANCH
        pc_src = 3'b010; #10;  // PC_JUMP
        pc_src = 3'b011; imm = 16'h0008; #10;  // PC_JR
        pc_src = 3'b100; #10;  // PC_IRQ
        pc_src = 3'b101; #10;  // default case
        pc_src = 3'b110; #10;  // default case
        pc_src = 3'b111; #10;  // default case

        // ---------- j guarda os 4 bits altos de PC + 4 ----------
        pc = 32'h3000_0000; pc_src = 3'b010; #10;  // next_pc = 30000100
        $finish;
    end

endmodule