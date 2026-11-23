`timescale 1ns / 1ps


module instruction_memory #(
    parameter INIT_FILE = "program.mem"
) (
    input  wire [31:0] i_addr,   // PC, endereco em bytes
    output wire [31:0] o_instr   // instrucao lida
);

    localparam DEPTH = 512;      // palavras

    reg [31:0] mem [0:DEPTH-1];  // so e lida: o synth infere ROM

    integer i;
    initial begin
        for (i = 0; i < DEPTH; i = i + 1)
            mem[i] = 32'h0000_0000;      // por omissao: nop
        $readmemh(INIT_FILE, mem);
    end

    assign o_instr = mem[i_addr[10:2]];

endmodule
