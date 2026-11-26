`timescale 1ns / 1ps

// Testbench do topo da placa. Usa blink_sim.mem (DELAY = 3) para os LEDs
// mudarem em poucos ciclos. Basta ver o_led na forma de onda a contar 0,1,2,3...
// Nota: na simulacao o Clocking Wizard real demora alguns us a dar locked;
// ate la o CPU fica em reset (PC = 0).

module tb_mips_top;
    reg clk;
    reg btn_rst;
    wire [3:0] led;

    mips_top #(.PROGRAM("blink_sim.mem")) u_top (
        .i_clk     (clk),
        .i_btn_rst (btn_rst),
        .o_led     (led)
    );

    initial clk = 1'b0;
    always #4 clk = ~clk;      // 125 MHz, como na placa

    initial begin
        btn_rst = 0;
        wait (led == 4'd5);    // o CPU esta a contar
        #1 btn_rst = 1;        // carregar no BTN0
        #100 btn_rst = 0;      // LEDs voltam a 0 e recomeca a contar
        wait (led == 4'd3);
        $finish;
    end

    initial begin #2000000; $display("TIMEOUT"); $finish; end  // 2 ms: rede de seguranca
    always @(led) $display("t=%0t  led = %b", $time, led);
endmodule
