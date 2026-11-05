`timescale 1ns / 1ps

// COP0 subset (spec rev 3, sections 5.1 and 9): EPC, IE and the ei shadow bit.
// - epc_r       reset 0; written by interrupt entry (Phase 2): EPC <- PC; read by mfc0 $14
// - ie_r        reset 0; di -> 0, ei -> 1, interrupt entry -> 0
// - ei_shadow_r reset 0; set by ei, cleared by the next instruction, so that the
//               return sequence  mfc0 $k0,$14 ; ei ; jr $k0  cannot be interrupted
//               between ei and jr.
// All state updates are gated by i_en. In Phase 1 i_irq is tied to 0.
module cop0 (
    input  wire        i_clk,
    input  wire        i_rst,        // synchronous, active high
    input  wire        i_en,         // step/enable
    input  wire [31:0] i_pc,         // PC of the instruction being interrupted
    input  wire        i_irq,        // interrupt request from soc.v (0 in Phase 1)
    input  wire        i_ie_we,      // di / ei from the control unit
    input  wire        i_ie_val,     // 0: di, 1: ei
    output wire [31:0] o_epc,        // to the write-back mux (WBSrc = 11)
    output wire        o_irq_take    // to the control unit
);

    reg [31:0] epc_r;
    reg        ie_r;
    reg        ei_shadow_r;

    assign o_irq_take = i_irq & ie_r & ~ei_shadow_r;
    assign o_epc      = epc_r;

    always @(posedge i_clk) begin
        if (i_rst) begin
            epc_r       <= 32'b0;
            ie_r        <= 1'b0;
            ei_shadow_r <= 1'b0;
        end else if (i_en) begin
            if (o_irq_take) begin                 // Phase 2: interrupt entry
                epc_r       <= i_pc;
                ie_r        <= 1'b0;
                ei_shadow_r <= 1'b0;
            end else begin
                if (i_ie_we)                      // di / ei
                    ie_r <= i_ie_val;
                ei_shadow_r <= i_ie_we & i_ie_val;
            end
        end
    end

endmodule
