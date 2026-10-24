module control_unit (
    input  wire [5:0] i_opcode,
    input  wire [5:0] i_funct,
    output reg        o_reg_write,
    output reg  [1:0] o_reg_dst,    // 00 = rt, 01 = rd, 10 = $31
    output reg        o_alu_src,    // 0 = registo, 1 = imediato
    output reg        o_ext_op,     // 1 = sign-extend, 0 = zero-extend
    output reg        o_mem_write,
    output reg  [1:0] o_wb_src,     // 00 = ALU, 01 = memoria, 10 = PC+4
    output reg        o_ie,         // 1 = reativa interrupcoes (eret)
    output reg  [2:0] o_pc_src,     // origem do proximo PC (ver PC_*)
    output reg        o_branch_ne,  // 1 = bne (salta se zero = 0), 0 = beq (salta se zero = 1)
    output reg  [3:0] o_alu_ctrl    // operacao da ALU
);
    // ---------- opcodes ----------
    localparam OP_RTYPE = 6'b000000, OP_J    = 6'b000010, OP_JAL  = 6'b000011,
               OP_BEQ   = 6'b000100, OP_BNE  = 6'b000101, OP_ADDI = 6'b001000,
               OP_ANDI  = 6'b001100, OP_ORI  = 6'b001101, OP_XORI = 6'b001110,
               OP_LUI   = 6'b001111, OP_COP0 = 6'b010000, OP_LW   = 6'b100011,
               OP_SW    = 6'b101011;

    // ---------- funct (tipo R) ----------
    localparam F_SLL = 6'b000000, F_SRL = 6'b000010, F_JR   = 6'b001000,
               F_ADD = 6'b100000, F_SUB = 6'b100010, F_AND  = 6'b100100,
               F_OR  = 6'b100101, F_XOR = 6'b100110, F_NOR  = 6'b100111,
               F_SLT = 6'b101010, F_SLTU = 6'b101011;

    // ---------- funct (COP0) ----------
    localparam F_ERET = 6'b011000;

    // ---------- codigos ALUCtrl ----------
    localparam ALU_AND = 4'b0000, ALU_OR  = 4'b0001, ALU_ADD  = 4'b0010,
               ALU_XOR = 4'b0011, ALU_SLL = 4'b0100, ALU_SRL  = 4'b0101,
               ALU_SUB = 4'b0110, ALU_SLT = 4'b0111, ALU_NOR  = 4'b1000,
               ALU_SLTU = 4'b1001, ALU_LUI = 4'b1010;

    // ---------- codigos PCSrc ----------
    // PC_BRANCH: o datapath so usa o alvo se o salto for tomado
    // (beq: zero = 1, bne: zero = 0). 101-111 reservados (vetor de interrupcao).
    localparam PC_PLUS4  = 3'b000,  // PC + 4
               PC_BRANCH = 3'b001,  // (PC+4) + (SignExt(imm) << 2)
               PC_JUMP   = 3'b010,  // {(PC+4)[31:28], index, 00}
               PC_JR     = 3'b011,  // rs
               PC_EPC    = 3'b100;  // EPC

    always @(*) begin
        // valores por defeito: instrucao "nao faz nada"
        o_reg_write = 1'b0; o_reg_dst = 2'b00; o_alu_src = 1'b0; o_ext_op    = 1'b1;
        o_mem_write = 1'b0; o_wb_src  = 2'b00; o_ie      = 1'b0; o_pc_src    = PC_PLUS4;
        o_branch_ne = 1'b0; o_alu_ctrl = ALU_ADD;

        case (i_opcode)
            OP_RTYPE: begin
                if (i_funct == F_JR) begin
                    o_pc_src = PC_JR;
                end else begin
                    o_reg_write = 1'b1; o_reg_dst = 2'b01;
                    case (i_funct)
                        F_ADD  : o_alu_ctrl = ALU_ADD;
                        F_SUB  : o_alu_ctrl = ALU_SUB;
                        F_AND  : o_alu_ctrl = ALU_AND;
                        F_OR   : o_alu_ctrl = ALU_OR;
                        F_XOR  : o_alu_ctrl = ALU_XOR;
                        F_NOR  : o_alu_ctrl = ALU_NOR;
                        F_SLT  : o_alu_ctrl = ALU_SLT;
                        F_SLTU : o_alu_ctrl = ALU_SLTU;
                        F_SLL  : o_alu_ctrl = ALU_SLL;
                        F_SRL  : o_alu_ctrl = ALU_SRL;
                        default: begin o_reg_write = 1'b0; o_reg_dst = 2'b00; end // funct invalido
                    endcase
                end
            end
            OP_ADDI: begin o_reg_write = 1'b1; o_alu_src = 1'b1;                 o_alu_ctrl = ALU_ADD; end
            OP_ANDI: begin o_reg_write = 1'b1; o_alu_src = 1'b1; o_ext_op = 1'b0; o_alu_ctrl = ALU_AND; end
            OP_ORI:  begin o_reg_write = 1'b1; o_alu_src = 1'b1; o_ext_op = 1'b0; o_alu_ctrl = ALU_OR;  end
            OP_XORI: begin o_reg_write = 1'b1; o_alu_src = 1'b1; o_ext_op = 1'b0; o_alu_ctrl = ALU_XOR; end
            OP_LUI:  begin o_reg_write = 1'b1; o_alu_src = 1'b1; o_ext_op = 1'b0; o_alu_ctrl = ALU_LUI; end
            OP_LW:   begin o_reg_write = 1'b1; o_alu_src = 1'b1; o_wb_src = 2'b01; o_alu_ctrl = ALU_ADD; end
            OP_SW:   begin o_mem_write = 1'b1; o_alu_src = 1'b1;                  o_alu_ctrl = ALU_ADD; end
            OP_BEQ:  begin o_pc_src = PC_BRANCH;                     o_alu_ctrl = ALU_SUB; end
            OP_BNE:  begin o_pc_src = PC_BRANCH; o_branch_ne = 1'b1; o_alu_ctrl = ALU_SUB; end
            OP_J:    begin o_pc_src = PC_JUMP; end
            OP_JAL:  begin o_pc_src = PC_JUMP; o_reg_write = 1'b1; o_reg_dst = 2'b10; o_wb_src = 2'b10; end
            OP_COP0: begin
                if (i_funct == F_ERET) begin o_pc_src = PC_EPC; o_ie = 1'b1; end
            end
            default: ; // opcode invalido: comporta-se como nop
        endcase
    end
endmodule
