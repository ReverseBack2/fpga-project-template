# Project mode keeps GUI access available while Tcl owns project creation.
proc validate_design_settings {part jobs top expected_version} {
    if {![regexp {^[A-Za-z0-9_-]+$} $part]} { error "Select an exact FPGA part" }
    if {![string is integer -strict $jobs] || $jobs < 1} { error "Jobs must be positive" }
    if {![regexp {^[A-Za-z_][A-Za-z0-9_]*$} $top]} { error "Select a synthesis top module" }
    if {[version -short] ne $expected_version} { error "This project requires Vivado $expected_version" }
}

proc create_design_project {root output part jobs top} {
    create_project design $output -part $part -force
    # Vivado's general.maxThreads setting supports at most eight threads.
    set_param general.maxThreads [expr {min($jobs, 8)}]
    set_property target_language Verilog [current_project]
    set_property include_dirs [list [file join $root rtl]] [current_fileset]
    set sources [open [file join $root fpga rtl.f] r]
    foreach line [split [read $sources] "\n"] {
        set line [string trim $line]
        if {$line eq "" || [string match "#*" $line]} { continue }
        add_files -norecurse [file join $root $line]
    }
    close $sources
    set_property top $top [current_fileset]
    foreach xdc [glob -nocomplain [file join $root fpga constraints *.xdc]] {
        add_files -fileset constrs_1 -norecurse $xdc
    }
    # Add IP definitions, not another machine's generated IP products.
    foreach xci [glob -nocomplain [file join $root fpga ip *.xci]] {
        add_files -norecurse $xci
    }
    set script [file join $root fpga ip create.tcl]
    if {[file exists $script]} { source $script }
    # Generate standalone IP before BDs introduce nested sub-IP objects.
    if {[llength [get_ips -quiet]] > 0} {
        generate_target all [get_ips]
    }
    set script [file join $root fpga bd create.tcl]
    if {[file exists $script]} { source $script }
    foreach bd [get_files -quiet *.bd] {
        generate_target all $bd
        add_files -norecurse [make_wrapper -files $bd -top]
    }
    update_compile_order -fileset sources_1
}
