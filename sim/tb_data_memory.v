`timescale 1ns/1ps

module tb_data_memory;
    reg clk;
    reg en; //write enable
    reg rw; // read -> 1; write -> 0
    reg [31:0] addr;
    reg[31:0] wd;
    wire [31:0] rd;

    data_memory u_data_memory(
        .i_clk (clk),
        .i_en(en), .i_rw(rw),
        .i_addr(addr), .i_wd(wd),
        .o_rd (rd)
    );

    initial clk= 0;
    always #5 clk = ~clk;

    initial begin
        //default values 
        en = 0; rw = 1; addr = 32'h0; wd = 32'h0;
        #6;

        //6 - 26ns
        en = 1; rw = 0; addr = 32'h0; wd = 32'h0000_FFFF;
        #10;
        en = 1; rw = 1; addr = 32'h0000_07FC; wd = 32'h0000_BEEF;
        #10;

        // 26 - 46 ns, enable at 0;
        en = 0; rw = 0; addr = 32'h0000_002C; wd = 32'h0000_FFFF;
        #10;
        en = 0; rw = 1; addr = 32'h0000_0300; wd = 32'h0000_BEEF;
        #10;

        //46 - 56 ns, addr not available
        en = 1; rw = 0; addr = 32'h0; wd = 32'hDEAD_BEEF;
        #10;

        //56 - 86 neighbors
        en = 1; rw = 0; addr = 32'h0000_0004; wd = 32'hBEEF_0000;
        #10;
        addr = 32'h0000_0008; wd = 32'h0000_BEEF;
        #10;
        addr = 32'h0000_000C; wd = 32'hDEAD_BEEF;
        #10;

        // 86 - 106 ns, overwrite
        en = 1; rw= 0; addr = 32'h0000_0020; wd = 32'hAAAA_AAAA;
        #10;
        en = 1; rw= 0; addr = 32'h0000_0020; wd = 32'hFFFF_FFFF;
        #10;

        $finish;
    end

    




endmodule