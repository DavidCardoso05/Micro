`timescale 1ns / 1ps

// Instruction memory (ROM), byte-addressed from outside, word-addressed inside.
// 2^ADDR_BITS words of 32 bits (default 256 words = 1 KB). Words not set by
// INIT_FILE are 0 (= sll $0,$0,0 = nop).
//
// READ_LATENCY = 0: combinational read (distributed RAM), o_instr = mem[i_addr].
//                   i_rst and i_en are not used. This is the rev 3 behaviour.
// READ_LATENCY = 1: registered output (Block RAM style, 1-cycle latency).
//                   Connect i_addr to the NEXT PC (input of pc_reg), not to
//                   the PC. Then o_instr is the instruction at the current PC
//                   in the same cycle, and the CPU still executes one
//                   instruction per cycle:
//
//                     cycle n   : pc_reg.D = next_pc = A   -> memory samples A
//                     cycle n+1 : pc_reg.Q = A, o_instr = mem[A]
//
//                   - i_en = 0 freezes the output together with the PC.
//                   - i_rst = 1 reads word 0, so after reset PC = 0 and
//                     o_instr = mem[0].
module instruction_memory #(
    parameter ADDR_BITS    = 8,
    parameter INIT_FILE    = "program.mem",
    parameter READ_LATENCY = 1
)(
    input  wire        i_clk,
    input  wire        i_rst,    // READ_LATENCY = 1 only
    input  wire        i_en,     // READ_LATENCY = 1 only
    input  wire [31:0] i_addr,   // byte address (next PC when READ_LATENCY = 1)
    output wire [31:0] o_instr
);

    reg [31:0] mem [0:(1<<ADDR_BITS)-1];
    integer i;

    initial begin
        for (i = 0; i < (1<<ADDR_BITS); i = i + 1)
            mem[i] = 32'h00000000;
        $readmemh(INIT_FILE, mem);
    end

    wire [ADDR_BITS-1:0] word_idx = i_addr[ADDR_BITS+1:2];

    // ---------- latency 0: combinational read ----------
    wire [31:0] instr_comb = mem[word_idx];

    // ---------- latency 1: registered read ----------
    wire [ADDR_BITS-1:0] rd_idx = i_rst ? {ADDR_BITS{1'b0}} : word_idx;
    reg  [31:0]          instr_r;

    always @(posedge i_clk) begin
        if (i_rst || i_en)
            instr_r <= mem[rd_idx];
    end

    assign o_instr = (READ_LATENCY == 0) ? instr_comb : instr_r;

endmodule
