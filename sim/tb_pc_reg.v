`timescale 1ns / 1ps

module tb_pc_reg;
    reg clk;
    reg rst;
    reg we;  // PCWrite
    reg [31:0] next_pc;

    wire [31:0] pc;

    pc_reg u_pc_reg (
        .i_clk(clk),
        .i_rst(rst),
        .i_we(we),
        .i_next_pc(next_pc),
        .o_pc(pc)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        // ---------- reset (apanha o flanco de t = 5) ----------
        rst = 1; we = 1; next_pc = 32'h0000_0040; #10;  // pc = 0

        // ---------- we = 1: o PC avança no flanco ----------
        rst = 0; we = 1; next_pc = 32'h0000_0004; #10;  // pc = 00000004
        rst = 0; we = 1; next_pc = 32'h0000_0008; #10;  // pc = 00000008

        // ---------- we = 0: o PC fica parado (1.º ciclo do lw) ----------
        rst = 0; we = 0; next_pc = 32'h0000_000C; #10;  // pc continua 00000008
        rst = 0; we = 1; next_pc = 32'h0000_000C; #10;  // pc = 0000000C

        // ---------- reset ganha a we ----------
        rst = 1; we = 1; next_pc = 32'h0000_0010; #10;  // pc = 0

        $finish;
    end
endmodule
