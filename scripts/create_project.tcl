# Rebuilds the Vivado project from the sources in the repo.
# Usage (from the repo root):
#   vivado -mode batch -nojournal -nolog -source scripts/create_project.tcl
#
# Sources are ADDED (referenced in place), never imported/copied,
# so edits made in VS Code are what Vivado synthesizes and simulates.

set root [file normalize [file join [file dirname [info script]] ..]]
set proj_dir [file join $root build vivado]

create_project mips_soc $proj_dir -part xc7z010clg400-1 -force
set_property target_language Verilog [current_project]

# RTL
set rtl [glob -nocomplain [file join $root rtl *.v]]
if {[llength $rtl]} { add_files -norecurse $rtl }

# Testbenches
set tbs [glob -nocomplain [file join $root sim *.v]]
if {[llength $tbs]} { add_files -fileset sim_1 -norecurse $tbs }

# Constraints
set xdc [glob -nocomplain [file join $root constraints *.xdc]]
if {[llength $xdc]} { add_files -fileset constrs_1 -norecurse $xdc }

# IP (Clocking Wizard etc.): only the .xci lives in git
set xcis [glob -nocomplain [file join $root ip * *.xci]]
foreach x $xcis {
    read_ip $x
    generate_target all [get_files $x]
}

# Top modules: soc / tb_soc once they exist, control_unit until then
if {[llength [get_files -quiet soc.v]]} {
    set_property top soc [get_filesets sources_1]
} elseif {[llength [get_files -quiet control_unit.v]]} {
    set_property top control_unit [get_filesets sources_1]
}
if {[llength [get_files -quiet tb_soc.v]]} {
    set_property top tb_soc [get_filesets sim_1]
} elseif {[llength [get_files -quiet control_unit.v]]} {
    set_property top control_unit [get_filesets sim_1]
}

# Let XSim find program.mem / data.mem next to the testbench
set_property -name {xsim.simulate.runtime} -value {all} -objects [get_filesets sim_1]

puts "Project created at $proj_dir/mips_soc.xpr"
