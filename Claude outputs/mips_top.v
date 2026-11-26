`timescale 1ns / 1ps

// Topo para a placa Zybo Z7-10: cpu + IMEM + DMEM + registo dos LEDs.
//
// Mapa de memoria (so o bit 31 do endereco decide):
//   0x0000_0000 - 0x0000_07FF  DMEM (2 KiB)
//   0x8000_0000 - 0xFFFF_FFFF  perifericos: um sw escreve mem_wd[3:0] nos LEDs
//                              (o programa usa 0xFFFF_FFF0 = -16($zero))

module mips_top #(
    parameter PROGRAM = "blink.mem"
) (
    input  wire       i_clk,      // 125 MHz, pino K17
    input  wire       i_btn_rst,  // BTN0: reset (ativo a 1)
    output wire [3:0] o_led       // LD3..LD0
);

    // ---------- clock do CPU: 125 MHz -> 25 MHz (IP Clocking Wizard) ----------
    wire clk;
    wire locked;

    clk_cpu u_clk_cpu (
        .clk_in1  (i_clk),
        .clk_out1 (clk),
        .locked   (locked)
    );

    // ---------- reset: botao sincronizado + espera pelo MMCM ----------
    // comeca a 1 (valor inicial do FPGA): o CPU arranca sempre em reset
    reg [1:0] rst_sync_r = 2'b11;
    always @(posedge clk)
        rst_sync_r <= {rst_sync_r[0], i_btn_rst | ~locked};
    wire rst = rst_sync_r[1];

    // ---------- CPU ----------
    wire [31:0] pc, instr;
    wire [31:0] mem_addr, mem_wd, mem_rd;
    wire        mem_en, mem_rw;

    cpu u_cpu (
        .i_clk      (clk),
        .i_rst      (rst),
        .i_instr    (instr),
        .i_mem_rd   (mem_rd),
        .i_irq      (1'b0),       // sem interrupcoes nesta demo
        .i_irq_id   (2'd0),
        .o_pc       (pc),
        .o_mem_addr (mem_addr),
        .o_mem_wd   (mem_wd),
        .o_mem_en   (mem_en),
        .o_mem_rw   (mem_rw)
    );

    instruction_memory #(.INIT_FILE(PROGRAM)) u_imem (
        .i_addr  (pc),
        .o_instr (instr)
    );

    // ---------- descodificacao de enderecos ----------
    wire is_io = mem_addr[31];

    wire [31:0] dmem_rd;
    data_memory u_dmem (
        .i_clk  (clk),
        .i_en   (mem_en & ~is_io),   // um sw para os LEDs nao escreve na DMEM
        .i_rw   (mem_rw),
        .i_addr (mem_addr),
        .i_wd   (mem_wd),
        .o_rd   (dmem_rd)
    );

    // ---------- registo dos LEDs ----------
    reg [3:0] led_r = 4'b0000;
    always @(posedge clk)
        if (rst)
            led_r <= 4'b0000;
        else if (mem_en & ~mem_rw & is_io)
            led_r <= mem_wd[3:0];

    assign o_led  = led_r;
    assign mem_rd = is_io ? {28'b0, led_r} : dmem_rd;   // lw dos LEDs le o estado atual

endmodule
