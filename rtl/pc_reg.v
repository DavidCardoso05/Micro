`timescale 1ns / 1ps

// Registo do PC
// - reset síncrono, ativo a 1: PC = 0x0000_0000
// - i_we = PCWrite (da Control Unit): só com i_we = 1 o PC recebe i_next_pc
//   (i_we = 0 no 1.º ciclo de lw / lb)
module pc_reg (
    input  wire        i_clk,
    input  wire        i_rst,
    input  wire        i_we,        // PCWrite
    input  wire [31:0] i_next_pc,
    output wire [31:0] o_pc
);

    localparam RESET_PC = 32'h0000_0000;

    reg [31:0] pc_r;

    always @(posedge i_clk) begin
        if (i_rst)
            pc_r <= RESET_PC;
        else if (i_we)
            pc_r <= i_next_pc;
    end

    assign o_pc = pc_r;

endmodule
