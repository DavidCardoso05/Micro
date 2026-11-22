// Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
// Copyright 2022-2024 Advanced Micro Devices, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2024.2 (lin64) Build 5239630 Fri Nov 08 22:34:34 MST 2024
// Date        : Sat Nov 21 10:23:20 2026
// Host        : ddddddddddddddddddd-IdeaPad-Pro-5-14AKP10 running 64-bit Ubuntu 24.04.5 LTS
// Command     : write_verilog -force -mode funcsim
//               /home/david/MIPS/build/vivado/mips.gen/sources_1/ip/rf_dpram/rf_dpram_sim_netlist.v
// Design      : rf_dpram
// Purpose     : This verilog netlist is a functional simulation representation of the design and should not be modified
//               or synthesized. This netlist cannot be used for SDF annotated simulation.
// Device      : xc7z010clg400-1
// --------------------------------------------------------------------------------
`timescale 1 ps / 1 ps

(* CHECK_LICENSE_TYPE = "rf_dpram,dist_mem_gen_v8_0_15,{}" *) (* downgradeipidentifiedwarnings = "yes" *) (* x_core_info = "dist_mem_gen_v8_0_15,Vivado 2024.2" *) 
(* NotValidForBitStream *)
module rf_dpram
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
  rf_dpram_dist_mem_gen_v8_0_15 U0
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
`pragma protect encoding = (enctype = "BASE64", line_length = 76, bytes = 19328)
`pragma protect data_block
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
nfMzaUk=
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
