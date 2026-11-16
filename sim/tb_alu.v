`timescale  1ns / 1ps

module tb_alu;
    reg [31:0] a, b;
    reg [4:0] shamt;
    reg [3:0] ctrl;

    wire [31:0] y;
    wire zero;

    alu u_alu (
        .i_a(a),
        .i_b(b),
        .i_shamt(shamt),
        .i_ctrl(ctrl),
        .o_y(y),
        .o_zero(zero)
    );

    // Códigos de controlo da ALU
    localparam ALU_AND  = 4'b0000;
    localparam ALU_OR   = 4'b0001;
    localparam ALU_ADD  = 4'b0010;
    localparam ALU_XOR  = 4'b0011;
    localparam ALU_SLL  = 4'b0100;
    localparam ALU_SRL  = 4'b0101;
    localparam ALU_SUB  = 4'b0110;
    localparam ALU_SLT  = 4'b0111;
    localparam ALU_NOR  = 4'b1000;
    localparam ALU_SLTU = 4'b1001;
    localparam ALU_LUI  = 4'b1010;

    initial begin
        a = 32'd0; b = 32'd0; shamt = 5'd0;
        // ADD
        ctrl = ALU_ADD;
        a = 32'd10; b = 32'd5;
        #10;

        a = 32'd0; b = 32'd0;
        #10;

        a= 32'hFFFFFFFF; b = 32'd1;
        #10;

        // AND
        ctrl = ALU_AND;
        a = 32'd7; b = 32'd7;
        #10;

        a = 32'd7; b = 32'd3;
        #10;

        // XOR
        ctrl = ALU_XOR;
        a = 32'd7; b = 32'd3;
        #10;

        a = 32'd7; b = 32'd7;
        #10;

        // SLL - Shift Left Logical
        ctrl = ALU_SLL;
        b= 32'b001; shamt = 5'd2;
        #10;

        b= 32'hFFFFFFFF; shamt = 5'd2;
        #10;

        // SRL - Shift Right Logical
        ctrl = ALU_SRL;
        b= 32'b100; shamt = 5'd2;
        #10;

        b = 32'b001; shamt = 5'd2;
        #10;

        //LUI - Load Upper Immediate
        ctrl = ALU_LUI;
        b= 32'h0000FFFF;
        #10;

        b= 32'hFFFF0000;
        #10;

        $finish;
    end
endmodule

