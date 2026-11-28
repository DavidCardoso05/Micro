`timescale 1ns/1ps

module data_mem_subsystem(
    input wire i_clk,
    input wire [31:0] i_addr, //from ALUResult
    input wire [31:0] i_wd, //data to bre written
    input wire i_en, //enables write and read
    input wire i_rw, // read -> 1; write -> 0

    output reg [31:0] o_rd //data read for the load_ext
);
    wire [31:0] ram_rd;

    data_memory u_data_memory (
        .i_clk (i_clk),
        .i_addr (i_addr),
        .i_wd (i_wd),
        .i_en (i_en),
        .i_rw (i_rw),
        .o_rd (ram_rd)
    );

    assign wire dmem_sel = i_addr[31:11] = 11'b0 ?      1'b1 : 1'b0;

    assign wire mmio_sel =  i_addr[31:8] = 24'h000010 ? 1'b1 : 1'b0;

    wire ram_en = dmem_sel & i_en;

    wire mmio_en = mmio_sel & i_en;

    //read MUX, not yet implemented mmio registers
    always @(*) begin
        o_rd = 32'h0;
        if (dmem_sel)
            o_rd = ram_rd 
        else if (mmio_sel)
            o_rd = 32'h0; //ready for the mmio
        else o_rd = 32'h0;
    end

endmodule