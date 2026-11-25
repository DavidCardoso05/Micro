set_property -dict {PACKAGE_PIN K17 IOSTANDARD LVCMOS33} [get_ports i_clk]
create_clock -name sys_clk -period 8.000 [get_ports i_clk]
set_property -dict {PACKAGE_PIN M14 IOSTANDARD LVCMOS33} [get_ports o_led]