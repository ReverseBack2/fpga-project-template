# vivado -mode batch -source fpga/build.tcl -tclargs synth <part> 2
proc require_complete {run} {
    set status [get_property STATUS [get_runs $run]]
    if {[get_property PROGRESS [get_runs $run]] ne "100%" ||
        [string match -nocase "*error*" $status]} {
        error "$run failed: $status"
    }
}
proc build_design {} {
    global argv
    if {[llength $argv] != 3} { error "Expected target, FPGA part, and job count" }
    lassign $argv target part jobs
    if {$target ni {synth impl bitstream}} { error "Unknown target: $target" }
    if {$part eq ""} { error "Select an exact FPGA part before synthesis" }
    if {![string is integer -strict $jobs] || $jobs < 1 || $jobs > 6} {
        error "Job count must be between 1 and 6"
    }
    global script_root
    set root $script_root
    if {$target eq "bitstream" && ![file exists [file join $root fpga constraints pins.xdc]]} {
        error "Create fpga/constraints/pins.xdc for your board before generating a bitstream"
    }
    if {[version -short] ne "2026.1"} { error "This project requires Vivado 2026.1" }
    set output [file join $root build vivado]
    file mkdir $output
    source [file join $root fpga create_project.tcl]
    create_design_project $root [file join $output project] $part $jobs
    launch_runs synth_1 -jobs $jobs
    wait_on_run synth_1
    require_complete synth_1
    open_run synth_1
    report_utilization -file [file join $output synthesis_utilization.rpt]
    report_timing_summary -report_unconstrained -file [file join $output synthesis_timing.rpt]
    write_checkpoint -force [file join $output synthesized.dcp]
    if {$target eq "synth"} { return }
    close_design
    launch_runs impl_1 -to_step route_design -jobs $jobs
    wait_on_run impl_1
    require_complete impl_1
    open_run impl_1
    report_utilization -file [file join $output utilization.rpt]
    report_timing_summary -report_unconstrained -file [file join $output timing.rpt]
    report_drc -file [file join $output drc.rpt]
    report_cdc -file [file join $output cdc.rpt]
    write_checkpoint -force [file join $output routed.dcp]
    set paths [get_timing_paths -max_paths 1 -nworst 1]
    if {[llength $paths] == 0} { error "No timed paths found. Inspect clock constraints." }
    if {[get_property SLACK [lindex $paths 0]] < 0} {
        error "Timing failed. Reports and routed checkpoint are available in build/vivado."
    }
    if {$target eq "bitstream"} {
        close_design
        launch_runs impl_1 -to_step write_bitstream -jobs $jobs
        wait_on_run impl_1
        require_complete impl_1
        set bits [glob -nocomplain [file join [get_property DIRECTORY [get_runs impl_1]] *.bit]]
        if {[llength $bits] != 1} { error "Expected one bitstream, found [llength $bits]" }
        file copy -force [lindex $bits 0] [file join $output design.bit]
    }
}
set script_root [file normalize [file join [file dirname [info script]] ..]]
if {[catch {build_design} message options]} {
    puts stderr "ERROR: $message"
    puts stderr [dict get $options -errorinfo]
    exit 1
}
exit 0
