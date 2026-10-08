# make gui uses the same settings and recreation hooks as a batch build.
if {[llength $argv] != 4} { error "Expected part, jobs, top, and Vivado version" }
lassign $argv part jobs top expected_version
set root [file normalize [file join [file dirname [info script]] ..]]
source [file join $root fpga create_project.tcl]
validate_design_settings $part $jobs $top $expected_version
create_design_project $root [file join $root build vivado gui] $part $jobs $top
