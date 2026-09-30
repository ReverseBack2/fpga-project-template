# vivado -mode gui -source fpga/gui.tcl -tclargs <part> 2
if {[llength $argv] != 2} { error "Expected FPGA part and job count" }
lassign $argv part jobs
if {$part eq "" || ![string is integer -strict $jobs] || $jobs < 1 || $jobs > 6} {
    error "Provide an exact FPGA part and 1 to 6 jobs"
}
if {[version -short] ne "2026.1"} { error "This project requires Vivado 2026.1" }
set root [file normalize [file join [file dirname [info script]] ..]]
source [file join $root fpga create_project.tcl]
create_design_project $root [file join $root build vivado gui] $part $jobs
