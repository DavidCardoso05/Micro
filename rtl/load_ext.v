`timescale 1ns/1ps

module load_ext(
    input wire [31:0] i_rd, // word read from memory data
    input wire [1:0] i_addr, // which byte to extend
    input wire i_sel, // 0 -> lw; 1 -> lb 
    output wire [31:0] o_data
);
    reg [7:0] byte_sel;

    always @(*) begin
        byte_sel = i_rd[7:0];
        case(i_addr)
            2'b00: byte_sel = i_rd[7:0];
            2'b01: byte_sel = i_rd[15:8];
            2'b10: byte_sel = i_rd[23:16];
            2'b11: byte_sel = i_rd[31:24];

            default: byte_sel = i_rd[7:0];
        endcase 
    end

    assign o_data = i_sel ? {{24{byte_sel[7]}}, byte_sel} : i_rd;

endmodule