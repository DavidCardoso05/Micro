## Zybo Z7-10 - topo mips_top (pinos do Zybo-Z7-Master.xdc da Digilent)

## Clock de 125 MHz
set_property -dict {PACKAGE_PIN K17 IOSTANDARD LVCMOS33} [get_ports i_clk]
create_clock -name sys_clk -period 8.000 [get_ports i_clk]

## BTN0 = reset
set_property -dict {PACKAGE_PIN K18 IOSTANDARD LVCMOS33} [get_ports i_btn_rst]

## LEDs LD0..LD3
set_property -dict {PACKAGE_PIN M14 IOSTANDARD LVCMOS33} [get_ports {o_led[0]}]
set_property -dict {PACKAGE_PIN M15 IOSTANDARD LVCMOS33} [get_ports {o_led[1]}]
set_property -dict {PACKAGE_PIN G14 IOSTANDARD LVCMOS33} [get_ports {o_led[2]}]
set_property -dict {PACKAGE_PIN D18 IOSTANDARD LVCMOS33} [get_ports {o_led[3]}]

## O botao e assincrono (sincronizado no mips_top): sem analise de timing na entrada
set_false_path -from [get_ports i_btn_rst]
