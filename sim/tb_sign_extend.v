`timescale 1ns / 1ps

module tb_sign_extend;
    reg  [15:0] i_imm;
    reg         i_ext_op;
    wire [31:0] o_ext;

    sign_extend dut (.i_imm(i_imm), .i_ext_op(i_ext_op), .o_ext(o_ext));

    task check(input [31:0] esperado);
        begin
            #1;
            if (o_ext !== esperado)
                $display("ERRO: imm=%h ext_op=%b -> %h (esperado %h)",
                          i_imm, i_ext_op, o_ext, esperado);
            else
                $display("OK:   imm=%h ext_op=%b -> %h",
                          i_imm, i_ext_op, o_ext);
        end
    endtask

    initial begin
        i_imm = 16'h7FFF; i_ext_op = 1; check(32'h00007FFF);
        i_imm = 16'h8000; i_ext_op = 1; check(32'hFFFF8000);
        i_imm = 16'h7FFF; i_ext_op = 0; check(32'h00007FFF);
        i_imm = 16'h8000; i_ext_op = 0; check(32'h00008000);
        i_imm = 16'hFFFF; i_ext_op = 1; check(32'hFFFFFFFF);
        i_imm = 16'hFFFF; i_ext_op = 0; check(32'h0000FFFF);
        $finish;
    end
endmodule