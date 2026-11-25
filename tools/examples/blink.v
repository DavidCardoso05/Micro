module blink (
    input  wire i_clk,   // 125 MHz, pino K17
    output wire o_led    // LD0
);
    reg [26:0] cnt_r = 27'd0;

    always @(posedge i_clk)
        cnt_r <= cnt_r + 27'd1;

    assign o_led = cnt_r[26];   // 2^27 / 125 MHz ≈ 1,07 s por ciclo
endmodule