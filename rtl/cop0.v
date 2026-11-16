`timescale 1ns / 1ps

// COP0 subset: EPC, IE and the ei shadow bit.
// - epc_r       reset 0; written by interrupt entry: EPC <- PC; read by mfc0 $14
// - ie_r        reset 0; di -> 0, ei -> 1, interrupt entry -> 0
// - ei_shadow_r reset 0; set by ei, cleared by the next instruction, so that the
//               return sequence  mfc0 $k0,$14 ; ei ; jr $k0  cannot be interrupted
//               between ei and jr.
// No interrupt is taken in the second cycle of lw / lb (i_mem_phase = 1),
// so a load is either cancelled whole (in its first cycle) or completed.
module cop0 (
    input  wire        i_clk,
    input  wire        i_rst,        // synchronous, active high
    input  wire [31:0] i_pc,         // PC of the instruction being interrupted
    input  wire        i_irq,        // interrupt request
    input  wire        i_mem_phase,  // 1 in the second cycle of lw / lb
    input  wire        i_ie_we,      // di / ei from the control unit
    input  wire        i_ie_val,     // 0: di, 1: ei
    output wire [31:0] o_epc,        // to the write-back mux (WBSrc = 11)
    output wire        o_irq_take    // to the control unit
);

    reg [31:0] epc_r;
    reg        ie_r;
    reg        ei_shadow_r;

    assign o_irq_take = i_irq & ie_r & ~ei_shadow_r & ~i_mem_phase;
    assign o_epc      = epc_r;

    always @(posedge i_clk) begin
        if (i_rst) begin
            epc_r       <= 32'b0;
            ie_r        <= 1'b0;
            ei_shadow_r <= 1'b0;
        end else if (o_irq_take) begin            // interrupt entry
            epc_r       <= i_pc;
            ie_r        <= 1'b0;
            ei_shadow_r <= 1'b0;
        end else begin
            if (i_ie_we)                          // di / ei
                ie_r <= i_ie_val;
            ei_shadow_r <= i_ie_we & i_ie_val;
        end
    end

endmodule
