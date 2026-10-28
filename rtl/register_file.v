`timescale 1ns / 1ps

// Banco de registos: 32 x 32 bits
// - 2 leituras assíncronas (i_ra1, i_ra2)
// - 1 escrita síncrona (flanco de subida de i_clk) com i_we = 1
// - $zero (registo 0) vale sempre 0 e nunca é escrito
module register_file (
    input  wire        i_clk,
    input  wire        i_rst,
    input  wire        i_we,     // write enable
    input  wire [4:0]  i_ra1,    // endereço de leitura 1 (rs)
    input  wire [4:0]  i_ra2,    // endereço de leitura 2 (rt)
    input  wire [4:0]  i_wa,     // endereço de escrita
    input  wire [31:0] i_wd,     // dado a escrever
    output wire [31:0] o_rd1,    // dado lido 1
    output wire [31:0] o_rd2     // dado lido 2
);

    reg [31:0] rf [0:31];
    integer index;

    always @(posedge i_clk or posedge i_rst) begin
        if (i_rst) begin
            for (index = 0; index < 32; index = index + 1)
                rf[index] <= 32'b0;
        end else if (i_we && (i_wa != 5'b00000)) begin
            rf[i_wa] <= i_wd;
        end
    end

    assign o_rd1 = rf[i_ra1];
    assign o_rd2 = rf[i_ra2];

endmodule