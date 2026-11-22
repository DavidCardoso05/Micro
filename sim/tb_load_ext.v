`timescale 1ns / 1ps

module tb_load_ext;
    reg [31:0] rd;    // palavra lida da memoria de dados
    reg [1:0] addr;   // alu_result[1:0]: byte escolhido por lb
    reg sel;          // 0: lw | 1: lb

    wire [31:0] data;

    load_ext u_load_ext (
        .i_rd(rd),
        .i_addr(addr),
        .i_sel(sel),
        .o_data(data)
    );

    // Valores de LoadByte vindos da unidade de controlo
    localparam LOAD_LW = 1'b0;
    localparam LOAD_LB = 1'b1;

    // Palavras de teste (little-endian: addr 0 = byte [7:0], addr 3 = byte [31:24])
    localparam WORD_A = 32'h01807F81;  // bytes: [7:0]=81 (neg) [15:8]=7F (pos) [23:16]=80 (neg) [31:24]=01 (pos)
    localparam WORD_B = 32'h00FF00FF;  // bytes: [7:0]=FF [15:8]=00 [23:16]=FF [31:24]=00

    initial begin
        rd = 32'd0; addr = 2'd0; sel = LOAD_LW;

        // ---------- LB: escolhe o byte com addr e estende o sinal ----------
        sel = LOAD_LB;
        rd = WORD_A;
        addr = 2'd0; #10;  // byte 81 -> data = FFFF_FF81 (bit 7 = 1, sinal replicado)
        addr = 2'd1; #10;  // byte 7F -> data = 0000_007F (bit 7 = 0, zeros)
        addr = 2'd2; #10;  // byte 80 -> data = FFFF_FF80 (menor byte negativo)
        addr = 2'd3; #10;  // byte 01 -> data = 0000_0001

        // ---------- LW: devolve a palavra inteira, addr nao conta ----------
        sel = LOAD_LW;
        addr = 2'd0; #10;  // data = 0180_7F81
        addr = 2'd1; #10;  // data = 0180_7F81 (igual)
        addr = 2'd2; #10;  // data = 0180_7F81 (igual)
        addr = 2'd3; #10;  // data = 0180_7F81 (igual)

        // ---------- LB com bytes 00 e FF (extremos) ----------
        sel = LOAD_LB;
        rd = WORD_B;
        addr = 2'd0; #10;  // byte FF -> data = FFFF_FFFF (-1)
        addr = 2'd1; #10;  // byte 00 -> data = 0000_0000
        addr = 2'd2; #10;  // byte FF -> data = FFFF_FFFF
        addr = 2'd3; #10;  // byte 00 -> data = 0000_0000

        // ---------- mudar so LoadByte com a mesma palavra e o mesmo addr ----------
        rd = WORD_A; addr = 2'd2;
        sel = LOAD_LB; #10;  // data = FFFF_FF80
        sel = LOAD_LW; #10;  // data = 0180_7F81
        sel = LOAD_LB; #10;  // data = FFFF_FF80 (so LoadByte mudou, a saida acompanha logo)

        $finish;
    end
endmodule
