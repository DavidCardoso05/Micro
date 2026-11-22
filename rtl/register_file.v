`timescale 1ns / 1ps

module register_file(
    input wire i_clk,
    input wire [4:0] i_ra1, //rs - read address 1
    input wire [4:0] i_ra2, //rt - read address 2
    input wire [4:0] i_wa,  //write address register
    input wire [31:0] i_wd, //write data
    input wire i_we,        //RegWrite
    output wire [31:0] o_rd1, //read data 1
    output wire [31:0] o_rd2  //read data 2
);

    wire we_nzero;

    //never writes register 0
    assign we_nzero = i_we & (i_wa != 5'b0);

    rf_dpram u_rf_dpram_rs(
        .a (i_wa),
        .d (i_wd),
        .dpra (i_ra1),
        .clk (i_clk),
        .we (we_nzero),

        .dpo (o_rd1)
    );

    rf_dpram u_rf_dpram_rt(
        .a (i_wa),
        .d (i_wd),
        .dpra (i_ra2),
        .clk (i_clk),
        .we (we_nzero),

        .dpo (o_rd2)
    );

endmodule
