`timescale 1ns / 1ps


module instruction_memory #(
    parameter INIT_FILE = "program.mem"
) (
    input  wire [31:0] i_addr,   // PC, address in bytes
    output wire [31:0] o_instr   // read instrucion
);

    localparam DEPTH = 512;      // words

    reg [31:0] mem [0:DEPTH-1];  // just read - ROM

    integer i;
    initial begin
        for (i = 0; i < DEPTH; i = i + 1)
            mem[i] = 32'h0000_0000;      // omission: nop
        $readmemh(INIT_FILE, mem);
    end

    assign o_instr = mem[i_addr[10:2]];

endmodule
