`timescale 1ns / 1ps

// Memória de instruções (ROM), leitura combinatória
// - i_addr é endereço de byte (vem do PC); o índice usa i_addr[ADDR_BITS+1:2]
// - 2^ADDR_BITS palavras de 32 bits (por defeito 256 palavras = 1 KB)
// - posições não preenchidas pelo ficheiro ficam a 0 (nop)
module instruction_memory #(
    parameter ADDR_BITS = 8,
    parameter INIT_FILE = "program.mem"
)(
    input  wire        i_clk,    // não usado (leitura combinatória); mantido
                                 // para ficar igual à interface do soc
    input  wire [31:0] i_addr,
    output wire [31:0] o_instr
);

    reg [31:0] mem [0:(1<<ADDR_BITS)-1];
    integer i;

    initial begin
        for (i = 0; i < (1<<ADDR_BITS); i = i + 1)
            mem[i] = 32'h00000000;
        $readmemh(INIT_FILE, mem);
    end

    assign o_instr = mem[i_addr[ADDR_BITS+1:2]];

endmodule
