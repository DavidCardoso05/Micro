`timescale 1ns / 1ps

module data_memory #(
    parameter INIT_FILE = ""
) (
    input  wire        i_clk,
    input  wire        i_en,     // EN: ha acesso neste ciclo
    input  wire        i_we,     // WE: 1 escreve (sw), 0 le (lw, lb)
    input  wire [31:0] i_addr,   // endereco em bytes
    input  wire [31:0] i_wd,     // dado do sw (ReadData2)
    output reg  [31:0] o_rd      // palavra lida, valida no ciclo seguinte ao acesso
);

    localparam DEPTH = 512;      // palavras

    (* ram_style = "block" *) reg [31:0] mem [0:DEPTH-1];

    integer i;
    initial begin
        for (i = 0; i < DEPTH; i = i + 1)
            mem[i] = 32'h0000_0000;
        if (INIT_FILE != "")
            $readmemh(INIT_FILE, mem);
        o_rd = 32'h0000_0000;
    end

    always @(posedge i_clk) begin
        if (i_en) begin
            if (i_we)
                mem[i_addr[10:2]] <= i_wd;
            o_rd <= mem[i_addr[10:2]];   // le o valor antigo (read-first)
        end
    end

endmodule
