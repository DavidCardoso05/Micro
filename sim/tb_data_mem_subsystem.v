`timescale 1ns/1ps

module tb_data_mem_subsystem;
    reg clk;
    reg [31:0] addr;
    reg [31:0] wd;
    reg en;
    reg rw;

    wire [31:0] rd;

    data_mem_subsystem u_data_mem_subsystem (
        .i_clk (clk),
        .i_addr (addr),
        .i_wd (i_wd),
        .i_en (en),
        .i_rw (rw),
        .o_rd (rd)
    );

    