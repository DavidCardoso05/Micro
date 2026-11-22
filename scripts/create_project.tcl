# Rebuilds the Vivado project for the MIPS block-level work (ALU, CP0, register file).
# Usage (from the MIPS folder root):
#   vivado -mode batch -nojournal -nolog -source scripts/create_project.tcl
#
# Sources are ADDED (referenced in place), never imported/copied,
# so edits made in the editor are what Vivado synthesizes and simulates.

set root [file normalize [file join [file dirname [info script]] ..]]
set proj_dir [file join $root build vivado]

create_project mips $proj_dir -part xc7z010clg400-1 -force
set_property target_language Verilog [current_project]

# RTL
set rtl [glob -nocomplain [file join $root rtl *.v]]
if {[llength $rtl]} { add_files -norecurse $rtl }

# Testbenches
set tbs [glob -nocomplain [file join $root sim *.v]]
if {[llength $tbs]} { add_files -fileset sim_1 -norecurse $tbs }

# IP (only the .xci configuration is kept in git, under ip/<name>/).
# import_ip copies the .xci into the project, so the generated output stays inside build/
# and ip/ is never touched. Vivado regenerates the IP (rf_dpram, the register file RAM) here.
set xci [glob -nocomplain [file join $root ip * *.xci]]
foreach f $xci { import_ip $f }
if {[llength [get_ips -quiet]]} {
    generate_target all [get_ips]
}

# Constraints (none yet; picked up automatically if added later)
set xdc [glob -nocomplain [file join $root constraints *.xdc]]
if {[llength $xdc]} { add_files -fileset constrs_1 -norecurse $xdc }

# Top modules. Change the simulation top in the GUI (or here) to run
# tb_cop0 or tb_register_file instead of tb_alu.
if {[llength [get_files -quiet alu.v]]} {
    set_property top alu [get_filesets sources_1]
}
if {[llength [get_files -quiet tb_alu.v]]} {
    set_property top tb_alu [get_filesets sim_1]
}

set_property -name {xsim.simulate.runtime} -value {all} -objects [get_filesets sim_1]

puts "Project created at $proj_dir/mips.xpr"