`timescale 1ns / 1ps

// Mux 2 para 1, 32 bits: i_sel = 0 -> i_a, i_sel = 1 -> i_b
module mux2_32bit (
    input  wire [31:0] i_a,
    input  wire [31:0] i_b,
    input  wire        i_sel,
    output wire [31:0] o_y
);
    assign o_y = i_sel ? i_b : i_a;
endmodule

// Mux 2 para 1, 5 bits
module mux2_5bit (
    input  wire [4:0] i_a,
    input  wire [4:0] i_b,
    input  wire       i_sel,
    output wire [4:0] o_y
);
    assign o_y = i_sel ? i_b : i_a;
endmodule

// Mux 3 para 1, largura parametrizável (por defeito 32 bits)
// i_sel = 00 -> i_a, 01 -> i_b, 10 -> i_c
// (11 não deve ocorrer; por segurança escolhe i_a)
module mux3 #(
    parameter W = 32
)(
    input  wire [W-1:0] i_a,
    input  wire [W-1:0] i_b,
    input  wire [W-1:0] i_c,
    input  wire [1:0]   i_sel,
    output reg  [W-1:0] o_y
);
    always @(*) begin
        case (i_sel)
            2'b00:   o_y = i_a;
            2'b01:   o_y = i_b;
            2'b10:   o_y = i_c;
            default: o_y = i_a;
        endcase
    end
endmodule

module mux4 #(
    parameter W=32
)(
    input wire [W-1:0] i_a;
    input wire [W-1:0] i_b;
    input wire [W-1:0] i_c;
    input wire [W-1:0] i_d;
    input wire [1:0]   i_sel;
    output reg  [W-1:0] o_y;
);
always @(*) begin
    case (i_sel)
        2'b00:   o_y = i_a;
        2'b01:   o_y = i_b;
        2'b10:   o_y = i_c;
        2'b11:   o_y = i_d;
        default: o_y = i_a;
    endcase
end
endmodule   

