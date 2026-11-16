`timescale 1ns / 1ps

module tb_muxes;
    reg [31:0] a, b, c, d;
    reg sel2;
    reg [1:0] sel;

    wire [31:0] y2, y3, y4;

    mux2_32bit u_mux2 (.i_a(a), .i_b(b), .i_sel(sel2), .o_y(y2));
    mux3       u_mux3 (.i_a(a), .i_b(b), .i_c(c), .i_sel(sel), .o_y(y3));
    mux4       u_mux4 (.i_a(a), .i_b(b), .i_c(c), .i_d(d), .i_sel(sel), .o_y(y4));

    initial begin
        a = 32'hAAAA_AAAA; b = 32'hBBBB_BBBB; c = 32'hCCCC_CCCC; d = 32'hDDDD_DDDD;

        // ---------- mux2 ----------
        sel2 = 0; sel = 2'b00; #10;  // y2 = AAAAAAAA
        sel2 = 1;              #10;  // y2 = BBBBBBBB

        // ---------- mux3 e mux4 ----------
        sel = 2'b00; #10;  // y3 = AAAAAAAA, y4 = AAAAAAAA
        sel = 2'b01; #10;  // y3 = BBBBBBBB, y4 = BBBBBBBB
        sel = 2'b10; #10;  // y3 = CCCCCCCC, y4 = CCCCCCCC
        sel = 2'b11; #10;  // y3 = AAAAAAAA (código não usado), y4 = DDDDDDDD

        $finish;
    end
endmodule
