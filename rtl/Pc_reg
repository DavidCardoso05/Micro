`timescale 1ns / 1ps

// Program Counter register (spec rev 3, sections 8.3 and 9)
// - synchronous, active-high reset: PC <- 0
// - i_en gates the update (step/enable): when i_en = 0 the PC holds
// - i_next_pc comes from next_pc (PCSrc already applied there)
//
// With a registered-output instruction memory (READ_LATENCY = 1) the memory
// is addressed with i_next_pc, the D input of this register, so that the
// instruction arrives in the same cycle as the new PC (see instruction_memory.v).
module pc_reg (
    input  wire        i_clk,
    input  wire        i_rst,
    input  wire        i_en,
    input  wire [31:0] i_next_pc,
    output wire [31:0] o_pc
);

    reg [31:0] pc_r;

    always @(posedge i_clk) begin
        if (i_rst)
            pc_r <= 32'h0000_0000;
        else if (i_en)
            pc_r <= i_next_pc;
    end

    assign o_pc = pc_r;

endmodule

