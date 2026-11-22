`timescale 1ns / 1ps

module next_pc #(
    parameter IRQ_BASE = 32'h0000_0004  // bese address of the 4 interrupt vectors
) (
    input wire [31:0] i_pc, // current PC
    input wire [15:0] i_imm, // branch offset
    input wire [31:0] i_rs_data, // register rs (jr target)
    input wire [2:0] i_pc_src, //from the control unit
    input wire [1:0] i_irq_id,
    input wire [25:0] i_target, // jump index (j, jal)

    output reg [31:0] o_next_pc, 
    output wire [31:0] o_pc_plus4 
);

    localparam PC_NEXT = 3'b000,
                PC_BRANCH = 3'b001,
                PC_JUMP = 3'b010,
                PC_JR = 3'b011,
                PC_IRQ = 3'b100;
    
    assign o_pc_plus4 = i_pc + 32'd4;

    wire [31:0] branch_offset = { {14{i_imm[15]}}, i_imm, 2'b00 };  // sign-extend; the last 2 bits are always 0, jumps are in 4 bytes
    wire [31:0] branch_target = o_pc_plus4 + branch_offset;

    wire [31:0] jump_target = { o_pc_plus4[31:28], i_target, 2'b00};

    wire [31:0] irq_target = IRQ_BASE + {28'b0, i_irq_id, 2'b0};

    always @(*) begin
        o_next_pc = o_pc_plus4;  // default: next PC is PC + 4
        case(i_pc_src)
            PC_NEXT: o_next_pc = o_pc_plus4;
            PC_BRANCH: o_next_pc = branch_target;
            PC_JUMP: o_next_pc = jump_target;
            PC_JR: o_next_pc = i_rs_data;
            PC_IRQ: o_next_pc = irq_target;
            default: o_next_pc = o_pc_plus4;
        endcase
    end

endmodule