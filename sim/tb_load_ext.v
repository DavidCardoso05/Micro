`timescale 1ns / 1ps

module tb_load_ext;
    reg [31:0] rd;
    reg [1:0] addr;
    reg load_byte;

    wire [31:0] data;

    load_ext u_load_ext (
        .i_rd(rd),
        .i_addr(addr),
        .i_load_byte(load_byte),
        .o_data(data)
    );

    initial begin
        rd = 32'h8811_7F22;  // byte 3 = 88, byte 2 = 11, byte 1 = 7F, byte 0 = 22

        // ---------- lw: palavra inteira ----------
        load_byte = 0; addr = 2'b00; #10;  // data = 88117F22

        // ---------- lb: little-endian, extensão com sinal ----------
        load_byte = 1; addr = 2'b00; #10;  // byte 0 = 22 -> data = 00000022
        load_byte = 1; addr = 2'b01; #10;  // byte 1 = 7F -> data = 0000007F (maior positivo)
        load_byte = 1; addr = 2'b10; #10;  // byte 2 = 11 -> data = 00000011
        load_byte = 1; addr = 2'b11; #10;  // byte 3 = 88 -> data = FFFFFF88 (negativo)

        $finish;
    end
endmodule
