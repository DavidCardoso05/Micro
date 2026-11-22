`timescale 1ns / 1ps

module tb_cop0;
    reg clk;
    reg rst;
    reg [31:0] pc;
    reg irq;
    reg mem_phase;
    reg ie_we, ie_val;  // di: ie_we = 1, ie_val = 0 | ei: ie_we = 1, ie_val = 1

    wire [31:0] epc;
    wire irq_take;

    cop0 u_cop0 (
        .i_clk(clk),
        .i_rst(rst),
        .i_pc(pc),
        .i_irq(irq),
        .i_mem_phase(mem_phase),
        .i_ie_we(ie_we),
        .i_ie_val(ie_val),
        .o_epc(epc),
        .o_irq_take(irq_take)
    );

    initial clk = 5;
    always #5 clk = ~clk;

    initial begin
        // ---------- reset: EPC = 0, IE = 0 ----------
        rst = 1; pc = 32'h0; irq = 0; mem_phase = 0; ie_we = 0; ie_val = 0; #11;

        // ---------- IE = 0: o pedido é ignorado ----------
        rst = 0; pc = 32'h20; irq = 1; #10;  // irq_take = 0

        // ---------- ei: IE = 1, mas ei_shadow bloqueia a instrução seguinte ----------
        pc = 32'h24; irq = 0; ie_we = 1; ie_val = 1; #10;  // ie_r = 1, ei_shadow_r = 1 no flanco
        pc = 32'h28; irq = 1; ie_we = 0;             #10;  // irq_take = 0 até ao flanco (shadow); no flanco
                                                           // o shadow volta a 0 e irq_take sobe (já é o ciclo seguinte)

        // ---------- MemPhase = 1 (2.º ciclo de lw) bloqueia ----------
        pc = 32'h2C; irq = 1; mem_phase = 1; #10;  // irq_take = 0

        // ---------- interrupção aceite ----------
        pc = 32'h2C; irq = 1; mem_phase = 0; #10;  // irq_take = 1; no flanco EPC = 0000002C, IE = 0
        pc = 32'h04; irq = 1;                #10;  // irq_take = 0 (IE = 0 dentro do handler)

        // ---------- di: IE = 0 ----------
        pc = 32'h08; irq = 0; ie_we = 1; ie_val = 1; #10;  // ei: IE = 1
        pc = 32'h0C; irq = 0; ie_we = 1; ie_val = 0; #10;  // di: IE = 0
        pc = 32'h10; irq = 1; ie_we = 0;             #10;  // irq_take = 0; EPC continua 0000002C

        $finish;
    end
endmodule
