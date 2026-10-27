`timescale 1ns / 1ps

module tb_muxes;
    // --- mux2_32bit ---
    reg  [31:0] a32, b32;
    reg         sel2;
    wire [31:0] y2_32;
    mux2_32bit dut_m2_32 (.i_a(a32), .i_b(b32), .i_sel(sel2), .o_y(y2_32));

    // --- mux2_5bit ---
    reg  [4:0] a5, b5;
    wire [4:0] y2_5;
    mux2_5bit dut_m2_5 (.i_a(a5), .i_b(b5), .i_sel(sel2), .o_y(y2_5));

    // --- mux3 de 32 bits ---
    reg  [31:0] c32;
    reg  [1:0]  sel3;
    wire [31:0] y3_32;
    mux3 dut_m3_32 (.i_a(a32), .i_b(b32), .i_c(c32), .i_sel(sel3), .o_y(y3_32));

    // --- mux3 de 5 bits (RegDst) ---
    reg  [4:0] c5;
    wire [4:0] y3_5;
    mux3 #(.W(5)) dut_m3_5 (.i_a(a5), .i_b(b5), .i_c(c5), .i_sel(sel3), .o_y(y3_5));

    integer erros = 0;

    task check32(input [31:0] obtido, input [31:0] esperado, input [127:0] nome);
        begin
            if (obtido !== esperado) begin
                $display("ERRO %0s: obtido %h, esperado %h", nome, obtido, esperado);
                erros = erros + 1;
            end else
                $display("OK:   %0s = %h", nome, obtido);
        end
    endtask

    initial begin
        a32 = 32'hAAAAAAAA; b32 = 32'hBBBBBBBB; c32 = 32'hCCCCCCCC;
        a5  = 5'd8;         b5  = 5'd9;         c5  = 5'd31;

        // mux2
        sel2 = 0; #1; check32(y2_32, a32, "mux2_32 sel=0"); check32(y2_5, a5, "mux2_5 sel=0");
        sel2 = 1; #1; check32(y2_32, b32, "mux2_32 sel=1"); check32(y2_5, b5, "mux2_5 sel=1");

        // mux3 de 32 bits
        sel3 = 2'b00; #1; check32(y3_32, a32, "mux3_32 sel=00");
        sel3 = 2'b01; #1; check32(y3_32, b32, "mux3_32 sel=01");
        sel3 = 2'b10; #1; check32(y3_32, c32, "mux3_32 sel=10");
        sel3 = 2'b11; #1; check32(y3_32, a32, "mux3_32 sel=11");

        // mux3 de 5 bits (RegDst: rt, rd, $31)
        sel3 = 2'b00; #1; check32(y3_5, a5, "mux3_5 sel=00");
        sel3 = 2'b01; #1; check32(y3_5, b5, "mux3_5 sel=01");
        sel3 = 2'b10; #1; check32(y3_5, c5, "mux3_5 sel=10");

        if (erros == 0) $display("TUDO OK");
        else            $display("%0d erro(s)", erros);
        $finish;
    end
endmodule