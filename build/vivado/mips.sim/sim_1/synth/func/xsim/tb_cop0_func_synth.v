// Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
// Copyright 2022-2024 Advanced Micro Devices, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2024.2 (lin64) Build 5239630 Fri Nov 08 22:34:34 MST 2024
// Date        : Tue Nov 17 14:42:42 2026
// Host        : ddddddddddddddddddd-IdeaPad-Pro-5-14AKP10 running 64-bit Ubuntu 24.04.5 LTS
// Command     : write_verilog -mode funcsim -nolib -force -file
//               /home/david/MIPS/build/vivado/mips.sim/sim_1/synth/func/xsim/tb_cop0_func_synth.v
// Design      : cop0
// Purpose     : This verilog netlist is a functional simulation representation of the design and should not be modified
//               or synthesized. This netlist cannot be used for SDF annotated simulation.
// Device      : xc7z010clg400-1
// --------------------------------------------------------------------------------
`timescale 1 ps / 1 ps

(* NotValidForBitStream *)
module cop0
   (i_clk,
    i_rst,
    i_pc,
    i_irq,
    i_mem_phase,
    i_ie_we,
    i_ie_val,
    o_epc,
    o_irq_take);
  input i_clk;
  input i_rst;
  input [31:0]i_pc;
  input i_irq;
  input i_mem_phase;
  input i_ie_we;
  input i_ie_val;
  output [31:0]o_epc;
  output o_irq_take;

  wire ei_shadow_r;
  wire ei_shadow_r_i_1_n_0;
  wire ei_shadow_r_reg_n_0;
  wire i_clk;
  wire i_clk_IBUF;
  wire i_clk_IBUF_BUFG;
  wire i_ie_val;
  wire i_ie_val_IBUF;
  wire i_ie_we;
  wire i_ie_we_IBUF;
  wire i_irq;
  wire i_irq_IBUF;
  wire i_mem_phase;
  wire i_mem_phase_IBUF;
  wire [31:0]i_pc;
  wire [31:0]i_pc_IBUF;
  wire i_rst;
  wire i_rst_IBUF;
  wire ie_r;
  wire [31:0]o_epc;
  wire [31:0]o_epc_OBUF;
  wire o_irq_take;
  wire o_irq_take_OBUF;

  LUT4 #(
    .INIT(16'h0008)) 
    ei_shadow_r_i_1
       (.I0(i_ie_val_IBUF),
        .I1(i_ie_we_IBUF),
        .I2(i_rst_IBUF),
        .I3(o_irq_take_OBUF),
        .O(ei_shadow_r_i_1_n_0));
  FDRE #(
    .INIT(1'b0)) 
    ei_shadow_r_reg
       (.C(i_clk_IBUF_BUFG),
        .CE(1'b1),
        .D(ei_shadow_r_i_1_n_0),
        .Q(ei_shadow_r_reg_n_0),
        .R(1'b0));
  FDRE #(
    .INIT(1'b0)) 
    \epc_r_reg[0] 
       (.C(i_clk_IBUF_BUFG),
        .CE(o_irq_take_OBUF),
        .D(i_pc_IBUF[0]),
        .Q(o_epc_OBUF[0]),
        .R(i_rst_IBUF));
  FDRE #(
    .INIT(1'b0)) 
    \epc_r_reg[10] 
       (.C(i_clk_IBUF_BUFG),
        .CE(o_irq_take_OBUF),
        .D(i_pc_IBUF[10]),
        .Q(o_epc_OBUF[10]),
        .R(i_rst_IBUF));
  FDRE #(
    .INIT(1'b0)) 
    \epc_r_reg[11] 
       (.C(i_clk_IBUF_BUFG),
        .CE(o_irq_take_OBUF),
        .D(i_pc_IBUF[11]),
        .Q(o_epc_OBUF[11]),
        .R(i_rst_IBUF));
  FDRE #(
    .INIT(1'b0)) 
    \epc_r_reg[12] 
       (.C(i_clk_IBUF_BUFG),
        .CE(o_irq_take_OBUF),
        .D(i_pc_IBUF[12]),
        .Q(o_epc_OBUF[12]),
        .R(i_rst_IBUF));
  FDRE #(
    .INIT(1'b0)) 
    \epc_r_reg[13] 
       (.C(i_clk_IBUF_BUFG),
        .CE(o_irq_take_OBUF),
        .D(i_pc_IBUF[13]),
        .Q(o_epc_OBUF[13]),
        .R(i_rst_IBUF));
  FDRE #(
    .INIT(1'b0)) 
    \epc_r_reg[14] 
       (.C(i_clk_IBUF_BUFG),
        .CE(o_irq_take_OBUF),
        .D(i_pc_IBUF[14]),
        .Q(o_epc_OBUF[14]),
        .R(i_rst_IBUF));
  FDRE #(
    .INIT(1'b0)) 
    \epc_r_reg[15] 
       (.C(i_clk_IBUF_BUFG),
        .CE(o_irq_take_OBUF),
        .D(i_pc_IBUF[15]),
        .Q(o_epc_OBUF[15]),
        .R(i_rst_IBUF));
  FDRE #(
    .INIT(1'b0)) 
    \epc_r_reg[16] 
       (.C(i_clk_IBUF_BUFG),
        .CE(o_irq_take_OBUF),
        .D(i_pc_IBUF[16]),
        .Q(o_epc_OBUF[16]),
        .R(i_rst_IBUF));
  FDRE #(
    .INIT(1'b0)) 
    \epc_r_reg[17] 
       (.C(i_clk_IBUF_BUFG),
        .CE(o_irq_take_OBUF),
        .D(i_pc_IBUF[17]),
        .Q(o_epc_OBUF[17]),
        .R(i_rst_IBUF));
  FDRE #(
    .INIT(1'b0)) 
    \epc_r_reg[18] 
       (.C(i_clk_IBUF_BUFG),
        .CE(o_irq_take_OBUF),
        .D(i_pc_IBUF[18]),
        .Q(o_epc_OBUF[18]),
        .R(i_rst_IBUF));
  FDRE #(
    .INIT(1'b0)) 
    \epc_r_reg[19] 
       (.C(i_clk_IBUF_BUFG),
        .CE(o_irq_take_OBUF),
        .D(i_pc_IBUF[19]),
        .Q(o_epc_OBUF[19]),
        .R(i_rst_IBUF));
  FDRE #(
    .INIT(1'b0)) 
    \epc_r_reg[1] 
       (.C(i_clk_IBUF_BUFG),
        .CE(o_irq_take_OBUF),
        .D(i_pc_IBUF[1]),
        .Q(o_epc_OBUF[1]),
        .R(i_rst_IBUF));
  FDRE #(
    .INIT(1'b0)) 
    \epc_r_reg[20] 
       (.C(i_clk_IBUF_BUFG),
        .CE(o_irq_take_OBUF),
        .D(i_pc_IBUF[20]),
        .Q(o_epc_OBUF[20]),
        .R(i_rst_IBUF));
  FDRE #(
    .INIT(1'b0)) 
    \epc_r_reg[21] 
       (.C(i_clk_IBUF_BUFG),
        .CE(o_irq_take_OBUF),
        .D(i_pc_IBUF[21]),
        .Q(o_epc_OBUF[21]),
        .R(i_rst_IBUF));
  FDRE #(
    .INIT(1'b0)) 
    \epc_r_reg[22] 
       (.C(i_clk_IBUF_BUFG),
        .CE(o_irq_take_OBUF),
        .D(i_pc_IBUF[22]),
        .Q(o_epc_OBUF[22]),
        .R(i_rst_IBUF));
  FDRE #(
    .INIT(1'b0)) 
    \epc_r_reg[23] 
       (.C(i_clk_IBUF_BUFG),
        .CE(o_irq_take_OBUF),
        .D(i_pc_IBUF[23]),
        .Q(o_epc_OBUF[23]),
        .R(i_rst_IBUF));
  FDRE #(
    .INIT(1'b0)) 
    \epc_r_reg[24] 
       (.C(i_clk_IBUF_BUFG),
        .CE(o_irq_take_OBUF),
        .D(i_pc_IBUF[24]),
        .Q(o_epc_OBUF[24]),
        .R(i_rst_IBUF));
  FDRE #(
    .INIT(1'b0)) 
    \epc_r_reg[25] 
       (.C(i_clk_IBUF_BUFG),
        .CE(o_irq_take_OBUF),
        .D(i_pc_IBUF[25]),
        .Q(o_epc_OBUF[25]),
        .R(i_rst_IBUF));
  FDRE #(
    .INIT(1'b0)) 
    \epc_r_reg[26] 
       (.C(i_clk_IBUF_BUFG),
        .CE(o_irq_take_OBUF),
        .D(i_pc_IBUF[26]),
        .Q(o_epc_OBUF[26]),
        .R(i_rst_IBUF));
  FDRE #(
    .INIT(1'b0)) 
    \epc_r_reg[27] 
       (.C(i_clk_IBUF_BUFG),
        .CE(o_irq_take_OBUF),
        .D(i_pc_IBUF[27]),
        .Q(o_epc_OBUF[27]),
        .R(i_rst_IBUF));
  FDRE #(
    .INIT(1'b0)) 
    \epc_r_reg[28] 
       (.C(i_clk_IBUF_BUFG),
        .CE(o_irq_take_OBUF),
        .D(i_pc_IBUF[28]),
        .Q(o_epc_OBUF[28]),
        .R(i_rst_IBUF));
  FDRE #(
    .INIT(1'b0)) 
    \epc_r_reg[29] 
       (.C(i_clk_IBUF_BUFG),
        .CE(o_irq_take_OBUF),
        .D(i_pc_IBUF[29]),
        .Q(o_epc_OBUF[29]),
        .R(i_rst_IBUF));
  FDRE #(
    .INIT(1'b0)) 
    \epc_r_reg[2] 
       (.C(i_clk_IBUF_BUFG),
        .CE(o_irq_take_OBUF),
        .D(i_pc_IBUF[2]),
        .Q(o_epc_OBUF[2]),
        .R(i_rst_IBUF));
  FDRE #(
    .INIT(1'b0)) 
    \epc_r_reg[30] 
       (.C(i_clk_IBUF_BUFG),
        .CE(o_irq_take_OBUF),
        .D(i_pc_IBUF[30]),
        .Q(o_epc_OBUF[30]),
        .R(i_rst_IBUF));
  FDRE #(
    .INIT(1'b0)) 
    \epc_r_reg[31] 
       (.C(i_clk_IBUF_BUFG),
        .CE(o_irq_take_OBUF),
        .D(i_pc_IBUF[31]),
        .Q(o_epc_OBUF[31]),
        .R(i_rst_IBUF));
  FDRE #(
    .INIT(1'b0)) 
    \epc_r_reg[3] 
       (.C(i_clk_IBUF_BUFG),
        .CE(o_irq_take_OBUF),
        .D(i_pc_IBUF[3]),
        .Q(o_epc_OBUF[3]),
        .R(i_rst_IBUF));
  FDRE #(
    .INIT(1'b0)) 
    \epc_r_reg[4] 
       (.C(i_clk_IBUF_BUFG),
        .CE(o_irq_take_OBUF),
        .D(i_pc_IBUF[4]),
        .Q(o_epc_OBUF[4]),
        .R(i_rst_IBUF));
  FDRE #(
    .INIT(1'b0)) 
    \epc_r_reg[5] 
       (.C(i_clk_IBUF_BUFG),
        .CE(o_irq_take_OBUF),
        .D(i_pc_IBUF[5]),
        .Q(o_epc_OBUF[5]),
        .R(i_rst_IBUF));
  FDRE #(
    .INIT(1'b0)) 
    \epc_r_reg[6] 
       (.C(i_clk_IBUF_BUFG),
        .CE(o_irq_take_OBUF),
        .D(i_pc_IBUF[6]),
        .Q(o_epc_OBUF[6]),
        .R(i_rst_IBUF));
  FDRE #(
    .INIT(1'b0)) 
    \epc_r_reg[7] 
       (.C(i_clk_IBUF_BUFG),
        .CE(o_irq_take_OBUF),
        .D(i_pc_IBUF[7]),
        .Q(o_epc_OBUF[7]),
        .R(i_rst_IBUF));
  FDRE #(
    .INIT(1'b0)) 
    \epc_r_reg[8] 
       (.C(i_clk_IBUF_BUFG),
        .CE(o_irq_take_OBUF),
        .D(i_pc_IBUF[8]),
        .Q(o_epc_OBUF[8]),
        .R(i_rst_IBUF));
  FDRE #(
    .INIT(1'b0)) 
    \epc_r_reg[9] 
       (.C(i_clk_IBUF_BUFG),
        .CE(o_irq_take_OBUF),
        .D(i_pc_IBUF[9]),
        .Q(o_epc_OBUF[9]),
        .R(i_rst_IBUF));
  BUFG i_clk_IBUF_BUFG_inst
       (.I(i_clk_IBUF),
        .O(i_clk_IBUF_BUFG));
  IBUF i_clk_IBUF_inst
       (.I(i_clk),
        .O(i_clk_IBUF));
  IBUF i_ie_val_IBUF_inst
       (.I(i_ie_val),
        .O(i_ie_val_IBUF));
  IBUF i_ie_we_IBUF_inst
       (.I(i_ie_we),
        .O(i_ie_we_IBUF));
  IBUF i_irq_IBUF_inst
       (.I(i_irq),
        .O(i_irq_IBUF));
  IBUF i_mem_phase_IBUF_inst
       (.I(i_mem_phase),
        .O(i_mem_phase_IBUF));
  IBUF \i_pc_IBUF[0]_inst 
       (.I(i_pc[0]),
        .O(i_pc_IBUF[0]));
  IBUF \i_pc_IBUF[10]_inst 
       (.I(i_pc[10]),
        .O(i_pc_IBUF[10]));
  IBUF \i_pc_IBUF[11]_inst 
       (.I(i_pc[11]),
        .O(i_pc_IBUF[11]));
  IBUF \i_pc_IBUF[12]_inst 
       (.I(i_pc[12]),
        .O(i_pc_IBUF[12]));
  IBUF \i_pc_IBUF[13]_inst 
       (.I(i_pc[13]),
        .O(i_pc_IBUF[13]));
  IBUF \i_pc_IBUF[14]_inst 
       (.I(i_pc[14]),
        .O(i_pc_IBUF[14]));
  IBUF \i_pc_IBUF[15]_inst 
       (.I(i_pc[15]),
        .O(i_pc_IBUF[15]));
  IBUF \i_pc_IBUF[16]_inst 
       (.I(i_pc[16]),
        .O(i_pc_IBUF[16]));
  IBUF \i_pc_IBUF[17]_inst 
       (.I(i_pc[17]),
        .O(i_pc_IBUF[17]));
  IBUF \i_pc_IBUF[18]_inst 
       (.I(i_pc[18]),
        .O(i_pc_IBUF[18]));
  IBUF \i_pc_IBUF[19]_inst 
       (.I(i_pc[19]),
        .O(i_pc_IBUF[19]));
  IBUF \i_pc_IBUF[1]_inst 
       (.I(i_pc[1]),
        .O(i_pc_IBUF[1]));
  IBUF \i_pc_IBUF[20]_inst 
       (.I(i_pc[20]),
        .O(i_pc_IBUF[20]));
  IBUF \i_pc_IBUF[21]_inst 
       (.I(i_pc[21]),
        .O(i_pc_IBUF[21]));
  IBUF \i_pc_IBUF[22]_inst 
       (.I(i_pc[22]),
        .O(i_pc_IBUF[22]));
  IBUF \i_pc_IBUF[23]_inst 
       (.I(i_pc[23]),
        .O(i_pc_IBUF[23]));
  IBUF \i_pc_IBUF[24]_inst 
       (.I(i_pc[24]),
        .O(i_pc_IBUF[24]));
  IBUF \i_pc_IBUF[25]_inst 
       (.I(i_pc[25]),
        .O(i_pc_IBUF[25]));
  IBUF \i_pc_IBUF[26]_inst 
       (.I(i_pc[26]),
        .O(i_pc_IBUF[26]));
  IBUF \i_pc_IBUF[27]_inst 
       (.I(i_pc[27]),
        .O(i_pc_IBUF[27]));
  IBUF \i_pc_IBUF[28]_inst 
       (.I(i_pc[28]),
        .O(i_pc_IBUF[28]));
  IBUF \i_pc_IBUF[29]_inst 
       (.I(i_pc[29]),
        .O(i_pc_IBUF[29]));
  IBUF \i_pc_IBUF[2]_inst 
       (.I(i_pc[2]),
        .O(i_pc_IBUF[2]));
  IBUF \i_pc_IBUF[30]_inst 
       (.I(i_pc[30]),
        .O(i_pc_IBUF[30]));
  IBUF \i_pc_IBUF[31]_inst 
       (.I(i_pc[31]),
        .O(i_pc_IBUF[31]));
  IBUF \i_pc_IBUF[3]_inst 
       (.I(i_pc[3]),
        .O(i_pc_IBUF[3]));
  IBUF \i_pc_IBUF[4]_inst 
       (.I(i_pc[4]),
        .O(i_pc_IBUF[4]));
  IBUF \i_pc_IBUF[5]_inst 
       (.I(i_pc[5]),
        .O(i_pc_IBUF[5]));
  IBUF \i_pc_IBUF[6]_inst 
       (.I(i_pc[6]),
        .O(i_pc_IBUF[6]));
  IBUF \i_pc_IBUF[7]_inst 
       (.I(i_pc[7]),
        .O(i_pc_IBUF[7]));
  IBUF \i_pc_IBUF[8]_inst 
       (.I(i_pc[8]),
        .O(i_pc_IBUF[8]));
  IBUF \i_pc_IBUF[9]_inst 
       (.I(i_pc[9]),
        .O(i_pc_IBUF[9]));
  IBUF i_rst_IBUF_inst
       (.I(i_rst),
        .O(i_rst_IBUF));
  LUT5 #(
    .INIT(32'hFFFF0400)) 
    ie_r_i_1
       (.I0(ei_shadow_r_reg_n_0),
        .I1(ie_r),
        .I2(i_mem_phase_IBUF),
        .I3(i_irq_IBUF),
        .I4(i_rst_IBUF),
        .O(ei_shadow_r));
  FDRE #(
    .INIT(1'b0)) 
    ie_r_reg
       (.C(i_clk_IBUF_BUFG),
        .CE(i_ie_we_IBUF),
        .D(i_ie_val_IBUF),
        .Q(ie_r),
        .R(ei_shadow_r));
  OBUF \o_epc_OBUF[0]_inst 
       (.I(o_epc_OBUF[0]),
        .O(o_epc[0]));
  OBUF \o_epc_OBUF[10]_inst 
       (.I(o_epc_OBUF[10]),
        .O(o_epc[10]));
  OBUF \o_epc_OBUF[11]_inst 
       (.I(o_epc_OBUF[11]),
        .O(o_epc[11]));
  OBUF \o_epc_OBUF[12]_inst 
       (.I(o_epc_OBUF[12]),
        .O(o_epc[12]));
  OBUF \o_epc_OBUF[13]_inst 
       (.I(o_epc_OBUF[13]),
        .O(o_epc[13]));
  OBUF \o_epc_OBUF[14]_inst 
       (.I(o_epc_OBUF[14]),
        .O(o_epc[14]));
  OBUF \o_epc_OBUF[15]_inst 
       (.I(o_epc_OBUF[15]),
        .O(o_epc[15]));
  OBUF \o_epc_OBUF[16]_inst 
       (.I(o_epc_OBUF[16]),
        .O(o_epc[16]));
  OBUF \o_epc_OBUF[17]_inst 
       (.I(o_epc_OBUF[17]),
        .O(o_epc[17]));
  OBUF \o_epc_OBUF[18]_inst 
       (.I(o_epc_OBUF[18]),
        .O(o_epc[18]));
  OBUF \o_epc_OBUF[19]_inst 
       (.I(o_epc_OBUF[19]),
        .O(o_epc[19]));
  OBUF \o_epc_OBUF[1]_inst 
       (.I(o_epc_OBUF[1]),
        .O(o_epc[1]));
  OBUF \o_epc_OBUF[20]_inst 
       (.I(o_epc_OBUF[20]),
        .O(o_epc[20]));
  OBUF \o_epc_OBUF[21]_inst 
       (.I(o_epc_OBUF[21]),
        .O(o_epc[21]));
  OBUF \o_epc_OBUF[22]_inst 
       (.I(o_epc_OBUF[22]),
        .O(o_epc[22]));
  OBUF \o_epc_OBUF[23]_inst 
       (.I(o_epc_OBUF[23]),
        .O(o_epc[23]));
  OBUF \o_epc_OBUF[24]_inst 
       (.I(o_epc_OBUF[24]),
        .O(o_epc[24]));
  OBUF \o_epc_OBUF[25]_inst 
       (.I(o_epc_OBUF[25]),
        .O(o_epc[25]));
  OBUF \o_epc_OBUF[26]_inst 
       (.I(o_epc_OBUF[26]),
        .O(o_epc[26]));
  OBUF \o_epc_OBUF[27]_inst 
       (.I(o_epc_OBUF[27]),
        .O(o_epc[27]));
  OBUF \o_epc_OBUF[28]_inst 
       (.I(o_epc_OBUF[28]),
        .O(o_epc[28]));
  OBUF \o_epc_OBUF[29]_inst 
       (.I(o_epc_OBUF[29]),
        .O(o_epc[29]));
  OBUF \o_epc_OBUF[2]_inst 
       (.I(o_epc_OBUF[2]),
        .O(o_epc[2]));
  OBUF \o_epc_OBUF[30]_inst 
       (.I(o_epc_OBUF[30]),
        .O(o_epc[30]));
  OBUF \o_epc_OBUF[31]_inst 
       (.I(o_epc_OBUF[31]),
        .O(o_epc[31]));
  OBUF \o_epc_OBUF[3]_inst 
       (.I(o_epc_OBUF[3]),
        .O(o_epc[3]));
  OBUF \o_epc_OBUF[4]_inst 
       (.I(o_epc_OBUF[4]),
        .O(o_epc[4]));
  OBUF \o_epc_OBUF[5]_inst 
       (.I(o_epc_OBUF[5]),
        .O(o_epc[5]));
  OBUF \o_epc_OBUF[6]_inst 
       (.I(o_epc_OBUF[6]),
        .O(o_epc[6]));
  OBUF \o_epc_OBUF[7]_inst 
       (.I(o_epc_OBUF[7]),
        .O(o_epc[7]));
  OBUF \o_epc_OBUF[8]_inst 
       (.I(o_epc_OBUF[8]),
        .O(o_epc[8]));
  OBUF \o_epc_OBUF[9]_inst 
       (.I(o_epc_OBUF[9]),
        .O(o_epc[9]));
  OBUF o_irq_take_OBUF_inst
       (.I(o_irq_take_OBUF),
        .O(o_irq_take));
  LUT4 #(
    .INIT(16'h0020)) 
    o_irq_take_OBUF_inst_i_1
       (.I0(i_irq_IBUF),
        .I1(i_mem_phase_IBUF),
        .I2(ie_r),
        .I3(ei_shadow_r_reg_n_0),
        .O(o_irq_take_OBUF));
endmodule
`ifndef GLBL
`define GLBL
`timescale  1 ps / 1 ps

module glbl ();

    parameter ROC_WIDTH = 100000;
    parameter TOC_WIDTH = 0;
    parameter GRES_WIDTH = 10000;
    parameter GRES_START = 10000;

//--------   STARTUP Globals --------------
    wire GSR;
    wire GTS;
    wire GWE;
    wire PRLD;
    wire GRESTORE;
    tri1 p_up_tmp;
    tri (weak1, strong0) PLL_LOCKG = p_up_tmp;

    wire PROGB_GLBL;
    wire CCLKO_GLBL;
    wire FCSBO_GLBL;
    wire [3:0] DO_GLBL;
    wire [3:0] DI_GLBL;
   
    reg GSR_int;
    reg GTS_int;
    reg PRLD_int;
    reg GRESTORE_int;

//--------   JTAG Globals --------------
    wire JTAG_TDO_GLBL;
    wire JTAG_TCK_GLBL;
    wire JTAG_TDI_GLBL;
    wire JTAG_TMS_GLBL;
    wire JTAG_TRST_GLBL;

    reg JTAG_CAPTURE_GLBL;
    reg JTAG_RESET_GLBL;
    reg JTAG_SHIFT_GLBL;
    reg JTAG_UPDATE_GLBL;
    reg JTAG_RUNTEST_GLBL;

    reg JTAG_SEL1_GLBL = 0;
    reg JTAG_SEL2_GLBL = 0 ;
    reg JTAG_SEL3_GLBL = 0;
    reg JTAG_SEL4_GLBL = 0;

    reg JTAG_USER_TDO1_GLBL = 1'bz;
    reg JTAG_USER_TDO2_GLBL = 1'bz;
    reg JTAG_USER_TDO3_GLBL = 1'bz;
    reg JTAG_USER_TDO4_GLBL = 1'bz;

    assign (strong1, weak0) GSR = GSR_int;
    assign (strong1, weak0) GTS = GTS_int;
    assign (weak1, weak0) PRLD = PRLD_int;
    assign (strong1, weak0) GRESTORE = GRESTORE_int;

    initial begin
	GSR_int = 1'b1;
	PRLD_int = 1'b1;
	#(ROC_WIDTH)
	GSR_int = 1'b0;
	PRLD_int = 1'b0;
    end

    initial begin
	GTS_int = 1'b1;
	#(TOC_WIDTH)
	GTS_int = 1'b0;
    end

    initial begin 
	GRESTORE_int = 1'b0;
	#(GRES_START);
	GRESTORE_int = 1'b1;
	#(GRES_WIDTH);
	GRESTORE_int = 1'b0;
    end

endmodule
`endif
