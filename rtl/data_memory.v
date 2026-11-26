`timescale 1ns/1ps

module data_memory (
    input wire i_clk, 
    input wire i_en, //write enable
    input wire i_rw, // read -> 1; write -> 0
    input wire[31:0] i_addr, // address in bytes from the alu_result
    input wire[31:0] i_wd,
    output wire [31:0] o_rd
);

    assign we = i_en & ~i_rw;

    dist_mem_gen_0 u_dist_mem_gen_0 (
        .a (i_addr[10:2]), // 512 words
        .d (i_wd),
        .clk (i_clk),
        .we (we),
        .spo (o_rd)
    );

endmodule