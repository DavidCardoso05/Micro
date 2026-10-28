`timescale 1ns / 1ps

// Next-PC logic (spec rev 3, section 6.2)
// Purely combinational. Computes every PC candidate and selects one with
// PCSrc from the control unit. The branch condition is decided in the
// control unit (spec 6.1), so here PCSrc = 001 always means "taken".
//
//   PCSrc  Next PC                              Used by
//   000    PC + 4                               sequential execution
//   001    (PC + 4) + (SignExt(imm) << 2)       beq, bne, bgez, bgtz (taken)
//   010    {(PC + 4)[31:28], index, 00}         j, jal
//   011    rs                                   jr
//   100    IRQ_VECTOR                           interrupt entry (Phase 2)
//   101-111 reserved -> PC + 4
//
// o_pc_plus4 is also the link value written by jal (WBSrc = 10).

module next_pc #(
    parameter IRQ_VECTOR = 32'h0000_0004    // placeholder, fixed in Phase 2
) (
    input  wire [31:0] i_pc,         // current PC
    input  wire [15:0] i_imm,        // instr[15:0]  branch offset (in words)
    input  wire [25:0] i_index,      // instr[25:0]  jump index
    input  wire [31:0] i_rs_data,    // register rs  (jr target)
    input  wire [2:0]  i_pc_src,     // PCSrc from the control unit
    output reg  [31:0] o_next_pc,
    output wire [31:0] o_pc_plus4
);

    localparam PC_NEXT   = 3'b000,
               PC_BRANCH = 3'b001,
               PC_JUMP   = 3'b010,
               PC_JR     = 3'b011,
               PC_VECTOR = 3'b100;

    // Sign extension and << 2 are only wiring: no logic is spent on them.
    wire [31:0] branch_offset = {{14{i_imm[15]}}, i_imm, 2'b00};
    wire [31:0] branch_target = o_pc_plus4 + branch_offset;
    wire [31:0] jump_target   = {o_pc_plus4[31:28], i_index, 2'b00};

    assign o_pc_plus4 = i_pc + 32'd4;

    always @(*) begin
        o_next_pc = o_pc_plus4;                       // default: sequential
        case (i_pc_src)
            PC_NEXT:   o_next_pc = o_pc_plus4;
            PC_BRANCH: o_next_pc = branch_target;
            PC_JUMP:   o_next_pc = jump_target;
            PC_JR:     o_next_pc = i_rs_data;
            PC_VECTOR: o_next_pc = IRQ_VECTOR;
            default:   o_next_pc = o_pc_plus4;        // 101-111 reserved
        endcase
    end

endmodule
