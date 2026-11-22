// Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
// Copyright 2022-2024 Advanced Micro Devices, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2024.2 (lin64) Build 5239630 Fri Nov 08 22:34:34 MST 2024
// Date        : Sat Nov 21 10:23:19 2026
// Host        : ddddddddddddddddddd-IdeaPad-Pro-5-14AKP10 running 64-bit Ubuntu 24.04.5 LTS
// Command     : write_verilog -force -mode funcsim -rename_top decalper_eb_ot_sdeen_pot_pi_dehcac_xnilix -prefix
//               decalper_eb_ot_sdeen_pot_pi_dehcac_xnilix_ rf_dpram_sim_netlist.v
// Design      : rf_dpram
// Purpose     : This verilog netlist is a functional simulation representation of the design and should not be modified
//               or synthesized. This netlist cannot be used for SDF annotated simulation.
// Device      : xc7z010clg400-1
// --------------------------------------------------------------------------------
`timescale 1 ps / 1 ps

(* CHECK_LICENSE_TYPE = "rf_dpram,dist_mem_gen_v8_0_15,{}" *) (* downgradeipidentifiedwarnings = "yes" *) (* x_core_info = "dist_mem_gen_v8_0_15,Vivado 2024.2" *) 
(* NotValidForBitStream *)
module decalper_eb_ot_sdeen_pot_pi_dehcac_xnilix
   (a,
    d,
    dpra,
    clk,
    we,
    dpo);
  input [4:0]a;
  input [31:0]d;
  input [4:0]dpra;
  input clk;
  input we;
  output [31:0]dpo;

  wire [4:0]a;
  wire clk;
  wire [31:0]d;
  wire [31:0]dpo;
  wire [4:0]dpra;
  wire we;
  wire [31:0]NLW_U0_qdpo_UNCONNECTED;
  wire [31:0]NLW_U0_qspo_UNCONNECTED;
  wire [31:0]NLW_U0_spo_UNCONNECTED;

  (* C_FAMILY = "zynq" *) 
  (* C_HAS_CLK = "1" *) 
  (* C_HAS_D = "1" *) 
  (* C_HAS_DPO = "1" *) 
  (* C_HAS_DPRA = "1" *) 
  (* C_HAS_QDPO = "0" *) 
  (* C_HAS_QDPO_CE = "0" *) 
  (* C_HAS_QDPO_CLK = "0" *) 
  (* C_HAS_QDPO_RST = "0" *) 
  (* C_HAS_QDPO_SRST = "0" *) 
  (* C_HAS_QSPO = "0" *) 
  (* C_HAS_QSPO_RST = "0" *) 
  (* C_HAS_QSPO_SRST = "0" *) 
  (* C_HAS_SPO = "0" *) 
  (* C_HAS_WE = "1" *) 
  (* C_MEM_TYPE = "4" *) 
  (* C_REG_DPRA_INPUT = "0" *) 
  (* c_addr_width = "5" *) 
  (* c_default_data = "0" *) 
  (* c_depth = "32" *) 
  (* c_elaboration_dir = "./" *) 
  (* c_has_i_ce = "0" *) 
  (* c_has_qspo_ce = "0" *) 
  (* c_mem_init_file = "no_coe_file_loaded" *) 
  (* c_parser_type = "1" *) 
  (* c_pipeline_stages = "0" *) 
  (* c_qce_joined = "0" *) 
  (* c_qualify_we = "0" *) 
  (* c_read_mif = "0" *) 
  (* c_reg_a_d_inputs = "0" *) 
  (* c_sync_enable = "1" *) 
  (* c_width = "32" *) 
  (* is_du_within_envelope = "true" *) 
  decalper_eb_ot_sdeen_pot_pi_dehcac_xnilix_dist_mem_gen_v8_0_15 U0
       (.a(a),
        .clk(clk),
        .d(d),
        .dpo(dpo),
        .dpra(dpra),
        .i_ce(1'b1),
        .qdpo(NLW_U0_qdpo_UNCONNECTED[31:0]),
        .qdpo_ce(1'b1),
        .qdpo_clk(1'b0),
        .qdpo_rst(1'b0),
        .qdpo_srst(1'b0),
        .qspo(NLW_U0_qspo_UNCONNECTED[31:0]),
        .qspo_ce(1'b1),
        .qspo_rst(1'b0),
        .qspo_srst(1'b0),
        .spo(NLW_U0_spo_UNCONNECTED[31:0]),
        .we(we));
endmodule
`pragma protect begin_protected
`pragma protect version = 1
`pragma protect encrypt_agent = "XILINX"
`pragma protect encrypt_agent_info = "Xilinx Encryption Tool 2024.2"
`pragma protect key_keyowner="Synopsys", key_keyname="SNPS-VCS-RSA-2", key_method="rsa"
`pragma protect encoding = (enctype="BASE64", line_length=76, bytes=128)
`pragma protect key_block
QNtvE2CtVtCLMRpkLokNuGcllLrkXv1+lIa0yP+/1RuZi9oRL2LImNinlDdnYjplAMhYGl9XEctd
Vgvu47P/zXualZ0bLjhzg/aX77+nnnsogQe5QvbfAjNzC3kVXEI0ayxzBG4YOTRrN1s80vc8cnmF
luLtHMoVFTLV/Qa2ImY=

`pragma protect key_keyowner="Aldec", key_keyname="ALDEC15_001", key_method="rsa"
`pragma protect encoding = (enctype="BASE64", line_length=76, bytes=256)
`pragma protect key_block
EsS/DTw31dJ3RxUR5I9m01nWTF9kOWw8OcKsdprEfjEtZHh8rL+clyuQ4Lub9TZ7hvhtvdAM/yG2
lHSWYAypt558DVmIWXAhMktEhUX1YZsVivVh2JCr5Zwpv2M2Zgpbj/u5CVPA/hOLi6zvyslFmuPT
3xQPUx1QbvKJFKaAEIM90X8jh7Ib4ReOb/HDKfMoZpehJ5DROEpNQIMJc3A4xj1YwMvpm1sbGrQ9
BccqTOlUp26MHJqGfaW8k2zVxZWE6EBhTUryObnY6BMG0+oaqvkvNPmIC6DTQ67YDUMEXnF+a9tK
dg2+K6uDt3ntGg0h1nCEXfZlWGaD012YfXAM6A==

`pragma protect key_keyowner="Mentor Graphics Corporation", key_keyname="MGC-VELOCE-RSA", key_method="rsa"
`pragma protect encoding = (enctype="BASE64", line_length=76, bytes=128)
`pragma protect key_block
kvhusES6uczMSZDYIHCLM9JA6G0Ue0G1DJVuqxCaLmNC4FL9fKAJMgGDE9v7dXmHVzr0haCW3l6u
fhPWIv8RS4pQCBUcJ5SbLScY+RrgDxYCV6FAJc1MTcJeCsJL8Set1C2a1I9UMp9tKlbjsU4y7Fzw
zPrhH61jVSiSUHNOKA0=

`pragma protect key_keyowner="Mentor Graphics Corporation", key_keyname="MGC-VERIF-SIM-RSA-2", key_method="rsa"
`pragma protect encoding = (enctype="BASE64", line_length=76, bytes=256)
`pragma protect key_block
inENfe4FJDUWkXD2uskdmhcUKJs5FlDsfQejbIY+Kj3b3+VupqpRsdsVCOZR1iuI1YeUk/pEmpFO
UVwlLds+Gv462s6vzEryKKTUt5LwBWICjIOS1oipeNyRytMUgOzfB1ebbqE/qtSguwFkpuh+PM0R
G4XIc/yb+4ekv06FdCTwRsr1PPQhBN3dvlbmthDh+DlNg+451903inyVrElARA1sfsDyxLE5NXc6
aAGx9EnIlCMIyA3b+EHfUR2fpIJRv2WI8pXHp3BMkDFpFleQncgMRZawXlA8LyRTlEkQY9bWZloL
7c/PR9IocOI7Hgze6It+qoa1TMD4JYI1l4aiag==

`pragma protect key_keyowner="Real Intent", key_keyname="RI-RSA-KEY-1", key_method="rsa"
`pragma protect encoding = (enctype="BASE64", line_length=76, bytes=256)
`pragma protect key_block
fAUq8XfjyOSmYpeEsqFovnm9wo6MN+HSQMUxVb+8Tk7JxMZRzjIUavsTcxzCBGwV0cn9mhAROckY
ZL/S5ZCe9dNczc2GPLM/tKq0J00RTrg1/CnF83vDPBsTqPnubB8Ezocd9Y4mc7fpAqIK37xNhKWw
ZtaqQR5unbDfx1VXgu38tZOtw5xBdYDxXwTpiYO1CpppjaKYlkNgjn14fXojbu1WgOi5te1YIyMq
6VdV+a4vHs8ld5/Bzj1aYQpksd9HSmjhlvRbudp+Wzyeg/JQ/n/rVuL17spv9fRhRYzsYUmVpwVP
XHq7AEGPUxUsCR/hAlOZl74Y6CHWvMLJ1K3BJg==

`pragma protect key_keyowner="Xilinx", key_keyname="xilinxt_2023_11", key_method="rsa"
`pragma protect encoding = (enctype="BASE64", line_length=76, bytes=256)
`pragma protect key_block
viS1PaTaQyAmM0YlLlhPnaKoLyjFUdvV9D3cAsx0LAJDMTKtprr3n6TaJCVxoagTVaFkhc+XNiEY
3MerOEmTEA8PDu+i838+6oE2kSm2AaB5Ay8C2jAKzSTy+G+c1GMbYEnjHq5MNg4E2Jm1PtfCE0SP
QGvgfwSsSN87MBSHyAJsvK4mamZrAuhZWmEqZhT1QZb9hlijud9Tb/RRYib+D2mMfCdXddMWNqaP
NdLMgVMC4ANzo+0rYHrh4UTOeR7KaJJKQy/Mi4p71lRnZoN40Ii89TuZ3bJ7/8T+K5nbcuKUwuyJ
XJ0J8KclRbK50ihLP0KpXo2pm5KlA5/teSmkuQ==

`pragma protect key_keyowner="Metrics Technologies Inc.", key_keyname="DSim", key_method="rsa"
`pragma protect encoding = (enctype="BASE64", line_length=76, bytes=256)
`pragma protect key_block
E8Onz0icX0rH7d0giRecpH5/0LgSB945u0ZnuCpRBtsZWEDByWN4u/K25fQewqo49MlWTepnY6ih
PjoebsOpWNJfQPSgg1L0bPoxnmCScTQ3hQ5ihl7i5h3/1No6o6xyodzFdjfqaRjKZ1DO+MIkhv3p
Wud7PyjZ4Ms0FokgGRpYVWxKLCxoXBRSPbQIkSpW+K3g2YqKIKHjJgVcppXw0sCHzYPC/bkyQmjZ
8k8SsdLV0mSwakgdCD3RujY1sYU6IkirOvpJKHMqG/1D2ArNZwAHXLiJkN/DXZOTzXYo4fKSsO8t
aDIi9/VhLVFit4O+eoScusBihpNtrS8HEIm58w==

`pragma protect key_keyowner="Atrenta", key_keyname="ATR-SG-RSA-1", key_method="rsa"
`pragma protect encoding = (enctype="BASE64", line_length=76, bytes=384)
`pragma protect key_block
ucQchZNK5CXwhtcYBqqQo6DsBOn9eqPg9ol14ONJC8GgTGsYkXtBkLlTv9aOasMyBGKN6enj6sP+
s7C6NxtZw3YAebGfUqSi+R6H+puN46oekTmqVotJkXK/WUX7xc0M0TOcPeYC4XQrd9sz+skEsLch
WsFM9dm84HZ+mMle+By4OEV4LNHaptuAVTu3rrWiJBWidv754MkRpqk8volWGFKpMNLErMvOqMxG
F9s6Y8D2qI/Pj2ETd4xhrNxZ0rhgvZTwTnC+XVhYW76Sok0WNEyVVoIGWQpv3gKNjFII+klapSH7
MN6zCshLHtEpCoorA2TnPgEvygMo5sSLKaxQ5iReBX8bWyzYNdjmt/5qugSuwuMrQzq5lBIWyWRh
zgdZI0LLSMDwhJEpZn9+bRPoTPsjLDeIj0Z6rzMR4MT+giSf9DYoa+zPlnEeffzfWtay5W6s6cDb
xpf3cEtSFsYrgff3SGvHmmFRMQ8z641lLCvKuBP04YULFfd+A48W1oW3

`pragma protect key_keyowner="Cadence Design Systems.", key_keyname="CDS_RSA_KEY_VER_1", key_method="rsa"
`pragma protect encoding = (enctype="BASE64", line_length=76, bytes=256)
`pragma protect key_block
CAJIQgg4LFZ+P0oHwSwu+iEMgGfaKcnQZQrsU3X2LtjDX7mkLYSyP1DUS22lEdlVm1PDDG0M+DN6
j3z4HYyqTBYo06Nu2v5gQs2KNzvE2EmfRlSmtFj784qfv/hbCjRwM1BgSi9pEpRb1fsUXbi2TgrD
QdHcVyRTJGmyva1IFxM6fw0kV59++vjpI8Sv/3nYnkTu4fTFTyXJbpbxlavxYFh7EiLpwnsd3254
xio+kbN3pFIrRdBfD0hk41SQW4Wv69/PSD7vVZ1FlVdcf4z/a7YBNFxpE22bZrKmmfaZOy2H7HSC
PwSIe+298Q8AGwn8ua/D0TLVLS62+/vv8+vpaQ==

`pragma protect data_method = "AES128-CBC"
`pragma protect encoding = (enctype = "BASE64", line_length = 76, bytes = 19360)
`pragma protect data_block
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
`pragma protect end_protected
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
