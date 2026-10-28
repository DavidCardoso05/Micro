`timescale 1ns / 1ps

// ALU (spec rev 3, section 7)
// Purely combinational. 4-bit control, 10 operations, 6 reserved codes.
// Not used by mfc0 / di / ei / bgez (their ALUCtrl is a don't care).
//
//   ALUCtrl  Operation  Result            Used by
//   0000     AND        A & B             and
//   0001     OR         A | B             or
//   0010     ADD        A + B             add, addi, lw, lb, sw
//   0011     XOR        A ^ B             xor, xori
//   0100     SLL        B << shamt        sll
//   0101     SRL        B >> shamt        srl
//   0110     SUB        A - B             sub, beq, bne, bgtz
//   0111     SLT        A < B (signed)    slt
//   1000     NOR        ~(A | B)          nor
//   1001     -          reserved (was SLTU in rev 2) -> 0
//   1010     LUI        B[15:0] << 16     lui
//   1011-1111 -         reserved -> 0

module alu (
    input  wire [31:0] i_a,      // rs
    input  wire [31:0] i_b,      // rt or extended immediate
    input  wire [4:0]  i_shamt,  // instr[10:6]
    input  wire [3:0]  i_ctrl,   // ALUCtrl from the control unit
    output reg  [31:0] o_y,
    output wire        o_zero    // o_y == 0 (beq, bne, bgtz)
);

    localparam ALU_AND = 4'b0000,
               ALU_OR  = 4'b0001,
               ALU_ADD = 4'b0010,
               ALU_XOR = 4'b0011,
               ALU_SLL = 4'b0100,
               ALU_SRL = 4'b0101,
               ALU_SUB = 4'b0110,
               ALU_SLT = 4'b0111,
               ALU_NOR = 4'b1000,
               ALU_LUI = 4'b1010;

    // ---------- one shared adder for ADD, SUB and SLT (spec 8.3) ----------
    // SUB is computed as A + ~B + 1. SLT needs A - B to decide the sign.
    wire        sub_en = (i_ctrl == ALU_SUB) || (i_ctrl == ALU_SLT);
    wire [31:0] b_in   = sub_en ? ~i_b : i_b;
    wire [31:0] sum    = i_a + b_in + {31'b0, sub_en};

    // Signed A < B without overflow problems:
    // if the signs differ, A is smaller exactly when A is negative;
    // if the signs are equal, A - B cannot overflow, so its sign bit is the answer.
    wire lt_signed = (i_a[31] != i_b[31]) ? i_a[31] : sum[31];

    always @(*) begin
        o_y = 32'b0;                                        // default: reserved codes give 0
        case (i_ctrl)
            ALU_AND: o_y = i_a & i_b;
            ALU_OR:  o_y = i_a | i_b;
            ALU_ADD: o_y = sum;
            ALU_XOR: o_y = i_a ^ i_b;
            ALU_SLL: o_y = i_b << i_shamt;
            ALU_SRL: o_y = i_b >> i_shamt;                  // logical: fills with 0
            ALU_SUB: o_y = sum;
            ALU_SLT: o_y = {31'b0, lt_signed};
            ALU_NOR: o_y = ~(i_a | i_b);
            ALU_LUI: o_y = {i_b[15:0], 16'b0};              // A is not used
            default: o_y = 32'b0;                           // 1001, 1011-1111 reserved
        endcase
    end

    assign o_zero = (o_y == 32'b0);

endmodule
