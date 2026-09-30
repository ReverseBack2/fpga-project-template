# Project mode keeps GUI access available while Tcl owns project creation.
proc create_design_project {root output part jobs} {
    create_project design $output -part $part -force
    set_param general.maxThreads $jobs
    set sources [open [file join $root fpga rtl.f] r]
    foreach line [split [read $sources] "\n"] {
        set line [string trim $line]
        if {$line eq "" || [string match "#*" $line]} { continue }
        add_files -norecurse [file join $root $line]
    }
    close $sources
    set_property top counter [current_fileset]
    foreach xdc [glob -nocomplain [file join $root fpga constraints *.xdc]] {
        add_files -fileset constrs_1 -norecurse $xdc
    }
    # Add IP definitions, not another machine's generated IP products.
    foreach xci [glob -nocomplain [file join $root fpga ip *.xci]] {
        add_files -norecurse $xci
    }
    if {[llength [get_ips -quiet]] > 0} {
        generate_target all [get_ips]
    }
    update_compile_order -fileset sources_1
}
