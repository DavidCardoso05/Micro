## Zybo Z7-10 constraints
## 125 MHz system clock (the Clocking Wizard derives the 50 MHz CPU clock)
set_property -dict { PACKAGE_PIN K17 IOSTANDARD LVCMOS33 } [get_ports { i_clk }]
create_clock -add -name sys_clk_pin -period 8.00 -waveform {0 4} [get_ports { i_clk }]

## Buttons, switches and LEDs: copy the lines you need from Digilent's
## Zybo-Z7-Master.xdc and rename the ports to i_btn[*], i_sw[*], o_led[*].
