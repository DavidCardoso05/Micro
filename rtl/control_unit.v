module control_unit (
    input wire [5:0] i_opcode,
    input wire [5:0] i_funct,
    input  wire [4:0] i_rs,         // instr[25:21] (COP0 decode)
    input  wire [4:0] i_rd,         // instr[15:11] (COP0 decode)

    output reg o_reg_write,
    output reg [1:0]o_reg_dst, // 00: rt, 01: rd, 10: $31
    output reg o_alu_src, // 0: reg; 1: imm
    output reg [3:0] o_alu_ctrl,
    output reg o_ext_op, // 0: zero extend; 1: sign extend
    output reg o_mem_write, //1 to sw
    output reg o_mem_read, //1 to lw
    output reg [1:0] o_wb_src, // 00: alu, 01: mem, 10: pc+4
    output reg o_ie, //1 to eret
    output reg [2:0] o_pc_src, // 000: pc+4, 001: branch, 010: jump, 011: jr, 100: epc
    output reg o_branch_ne //1 to beq
);

//--------opcode--------
localparam OP_R_TYPE = 6'b000000,
            OP_ADDI = 6'b001000,
            OP_LW = 6'b100011,
            OP_SW = 6'b101011,
            OP_BEQ = 6'b000100,
            OP_BNE = 6'b000101,
            OP_ANDI = 6'b001100,
            OP_ORI = 6'b001101,
            OP_XORI = 6'b001110,
            OP_LUI = 6'b001111,
            OP_J = 6'b000010,
            OP_JAL = 6'b000011,
            OP_COP0 = 6'b010000;

//--------funct--------
localparam F_ADD = 6'b100000,
            F_SUB = 6'b100010,
            F_AND = 6'b100100,
            F_OR = 6'b100101,
            F_XOR = 6'b100110,
            F_NOR = 6'b100111,
            F_SLT = 6'b101010,
            F_SLTU = 6'b101011,
            F_SLL = 6'b000000,
            F_SRL = 6'b000010,
            F_JR = 6'b001000;

//--------COP0 funct--------
localparam F_ERET = 6'b011000,
            RS_MFC0 = 5'b01011,
            RD_STATUS = 5'b01100;

//--------ALU Control--------
localparam ALU_AND = 4'b0000,
            ALU_OR = 4'b0001,
            ALU_ADD = 4'b0010,
            ALU_XOR = 4'b0011,
            ALU_SLL = 4'b0100,
            ALU_SRL = 4'b0101,
            ALU_SUB = 4'b0110,
            ALU_SLT = 4'b0111,
            ALU_NOR = 4'b1000,
            ALU_SLTU = 4'b1001,
            ALU_LUI = 4'b1010;

//--------PC Source--------
localparam PC_NEXT = 3'b000,
            PC_BRANCH = 3'b001,
            PC_JUMP = 3'b010,
            PC_JR = 3'b011,
            PC_EPC = 3'b100;

 always @(*) begin
        // safe defaults = nop
        o_reg_write = 1'b0;  o_reg_dst  = 2'b00;    o_alu_src   = 1'b0;
        o_ext_op    = 1'b1;  o_mem_read = 1'b0;     o_mem_write = 1'b0;
        o_wb_src    = 2'b00; o_pc_src   = PC_PLUS4; o_branch_ne = 1'b0;
        o_alu_ctrl  = ALU_ADD; o_ie_we  = 1'b0;     o_ie_val    = 1'b0;

        case (i_opcode)
            OP_RTYPE: begin
                case (i_funct)
                    F_ADD:  begin o_reg_write = 1'b1; o_reg_dst = 2'b01; o_alu_ctrl = ALU_ADD;  end
                    F_SUB:  begin o_reg_write = 1'b1; o_reg_dst = 2'b01; o_alu_ctrl = ALU_SUB;  end
                    F_AND:  begin o_reg_write = 1'b1; o_reg_dst = 2'b01; o_alu_ctrl = ALU_AND;  end
                    F_OR:   begin o_reg_write = 1'b1; o_reg_dst = 2'b01; o_alu_ctrl = ALU_OR;   end
                    F_XOR:  begin o_reg_write = 1'b1; o_reg_dst = 2'b01; o_alu_ctrl = ALU_XOR;  end
                    F_NOR:  begin o_reg_write = 1'b1; o_reg_dst = 2'b01; o_alu_ctrl = ALU_NOR;  end
                    F_SLT:  begin o_reg_write = 1'b1; o_reg_dst = 2'b01; o_alu_ctrl = ALU_SLT;  end
                    F_SLTU: begin o_reg_write = 1'b1; o_reg_dst = 2'b01; o_alu_ctrl = ALU_SLTU; end
                    F_SLL:  begin o_reg_write = 1'b1; o_reg_dst = 2'b01; o_alu_ctrl = ALU_SLL;  end
                    F_SRL:  begin o_reg_write = 1'b1; o_reg_dst = 2'b01; o_alu_ctrl = ALU_SRL;  end
                    F_JR:   o_pc_src = PC_JR;
                    default: ;  // invalid funct -> nop
                endcase
            end
            OP_ADDI: begin o_reg_write = 1'b1; o_alu_src = 1'b1;                  o_alu_ctrl = ALU_ADD; end
            OP_ANDI: begin o_reg_write = 1'b1; o_alu_src = 1'b1; o_ext_op = 1'b0; o_alu_ctrl = ALU_AND; end
            OP_ORI:  begin o_reg_write = 1'b1; o_alu_src = 1'b1; o_ext_op = 1'b0; o_alu_ctrl = ALU_OR;  end
            OP_XORI: begin o_reg_write = 1'b1; o_alu_src = 1'b1; o_ext_op = 1'b0; o_alu_ctrl = ALU_XOR; end
            OP_LUI:  begin o_reg_write = 1'b1; o_alu_src = 1'b1; o_ext_op = 1'b0; o_alu_ctrl = ALU_LUI; end
            OP_LW:   begin o_reg_write = 1'b1; o_alu_src = 1'b1; o_mem_read = 1'b1;
                           o_wb_src = 2'b01; o_alu_ctrl = ALU_ADD; end
            OP_SW:   begin o_mem_write = 1'b1; o_alu_src = 1'b1; o_alu_ctrl = ALU_ADD; end
            OP_BEQ:  begin o_pc_src = PC_BRANCH; o_alu_ctrl = ALU_SUB; end
            OP_BNE:  begin o_pc_src = PC_BRANCH; o_alu_ctrl = ALU_SUB; o_branch_ne = 1'b1; end
            OP_J:    o_pc_src = PC_JUMP;
            OP_JAL:  begin o_reg_write = 1'b1; o_reg_dst = 2'b10; o_wb_src = 2'b10;
                           o_pc_src = PC_JUMP; end
            OP_COP0: begin
                if (i_rs[4] && i_funct == F_ERET) begin           // eret
                    o_pc_src = PC_EPC; o_ie_we = 1'b1; o_ie_val = 1'b1;
                end else if (i_rs == RS_MFMC0 && i_rd == RD_STATUS) begin  // di / ei
                    o_ie_we = 1'b1; o_ie_val = i_funct[5];         // instr[5]: 0 = di, 1 = ei
                end
            end
            default: ;  // unknown opcode -> nop
        endcase
    end

endmodule





