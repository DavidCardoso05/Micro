read_verilog blink.v
read_xdc     blink.xdc
synth_design -top blink -part xc7z010clg400-1
opt_design
place_design
route_design
report_timing_summary -file timing.rpt
write_bitstream -force blink.bit

open_hw_manager
connect_hw_server
open_hw_target
set dev [lindex [get_hw_devices xc7z010*] 0]
current_hw_device $dev
refresh_hw_device $dev
set_property PROGRAM.FILE blink.bit $dev
program_hw_devices $dev
close_hw_manager