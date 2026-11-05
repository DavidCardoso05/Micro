`timescale 1ns / 1ps
module load_ext (
    input  wire [31:0] i_rd,
    input  wire [1:0]  i_addr,
    input wire   i_load_byte,
    output reg  [31:0] o_data
);
        reg [7:0] byte_sel;

        always @(*) begin
        byte_sel = 8'b0;
        case (i_addr)
            2'b00:   byte_sel = i_rd[7:0];
            2'b01:   byte_sel = i_rd[15:8];
            2'b10:   byte_sel = i_rd[23:16];
            2'b11:   byte_sel = i_rd[31:24];
            default: byte_sel = 8'b0;
        endcase
    end

    always @(*) begin
        o_data = i_rd;
        if (i_load_byte)
            o_data = {{24{byte_sel[7]}}, byte_sel};
    end

endmodule
