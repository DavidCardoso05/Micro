`timescale 1ns / 1ps

// Extensão do dado lido da memória (combinacional)
// - i_load_byte = 0 (lw): passa a palavra inteira
// - i_load_byte = 1 (lb): escolhe o byte por i_addr (little-endian) e estende o sinal
//     i_addr = 00 -> i_rd[7:0]     01 -> i_rd[15:8]
//     i_addr = 10 -> i_rd[23:16]   11 -> i_rd[31:24]
module load_ext (
    input  wire [31:0] i_rd,         // palavra lida da memória de dados
    input  wire [1:0]  i_addr,       // addr[1:0]
    input  wire        i_load_byte,
    output wire [31:0] o_data
);

    reg [7:0] byte_sel;

    always @(*) begin
        byte_sel = i_rd[7:0];
        case (i_addr)
            2'b00:   byte_sel = i_rd[7:0];
            2'b01:   byte_sel = i_rd[15:8];
            2'b10:   byte_sel = i_rd[23:16];
            2'b11:   byte_sel = i_rd[31:24];
            default: byte_sel = i_rd[7:0];
        endcase
    end

    assign o_data = i_load_byte ? {{24{byte_sel[7]}}, byte_sel} : i_rd;

endmodule
