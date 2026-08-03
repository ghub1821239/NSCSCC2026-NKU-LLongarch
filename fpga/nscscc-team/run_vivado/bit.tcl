# bit.tcl
proc ClockFrequencyMHz {clock_name} {
    set clock [get_clocks -quiet $clock_name]
    if {[llength $clock] != 1} {
        error "Expected exactly one timing clock named '$clock_name'"
    }

    set period [get_property PERIOD $clock]
    if {$period <= 0.0} {
        error "Clock '$clock_name' has invalid period '$period'"
    }
    return [expr {1000.0 / double($period)}]
}

proc RequireClockFrequency {clock_name actual expected tolerance} {
    if {[expr {abs($actual - $expected)}] > $tolerance} {
        error [format "%s is %.6f MHz; expected %.6f MHz (+/- %.6f MHz)" \
            $clock_name $actual $expected $tolerance]
    }
}

open_project project/loongson.xpr
launch_runs impl_1 -to_step write_bitstream
wait_on_run impl_1  

open_run impl_1
report_timing_summary -delay_type min_max -report_unconstrained \
    -file project/loongson.runs/impl_1/timing_summary.rpt

set build_kind ""
set requested_cpu_mhz ""
if {$argc >= 1} {
    set build_kind [lindex $argv 0]
}
if {$argc >= 2} {
    set requested_cpu_mhz [expr {double([lindex $argv 1])}]
}

set actual_cpu_mhz [ClockFrequencyMHz cpu_clk]
set actual_sys_mhz [ClockFrequencyMHz sys_clk]
set actual_ddr_mhz [ClockFrequencyMHz ddr_clk]

RequireClockFrequency sys_clk $actual_sys_mhz 100.0 0.001
RequireClockFrequency ddr_clk $actual_ddr_mhz 200.0 0.001

if {$build_kind eq "perf"} {
    if {$requested_cpu_mhz eq ""} {
        error "The perf build requires the requested CPU frequency"
    }
    set cpu_tolerance [expr {max(0.001, $requested_cpu_mhz * 0.01)}]
    RequireClockFrequency cpu_clk $actual_cpu_mhz $requested_cpu_mhz $cpu_tolerance
}

set setup_path [lindex [get_timing_paths -delay_type max -max_paths 1 -nworst 1] 0]
set hold_path [lindex [get_timing_paths -delay_type min -max_paths 1 -nworst 1] 0]
if {$setup_path eq "" || $hold_path eq ""} {
    error "Unable to obtain setup and hold timing paths"
}

set setup_wns [get_property SLACK $setup_path]
set hold_wns [get_property SLACK $hold_path]

set validation_file [open \
    project/loongson.runs/impl_1/clock_timing_validation.txt w]
puts $validation_file [format "build_kind=%s" $build_kind]
puts $validation_file [format "requested_cpu_mhz=%s" $requested_cpu_mhz]
puts $validation_file [format "actual_cpu_mhz=%.6f" $actual_cpu_mhz]
puts $validation_file [format "actual_sys_mhz=%.6f" $actual_sys_mhz]
puts $validation_file [format "actual_ddr_mhz=%.6f" $actual_ddr_mhz]
puts $validation_file [format "setup_wns_ns=%.6f" $setup_wns]
puts $validation_file [format "hold_wns_ns=%.6f" $hold_wns]
close $validation_file

puts [format \
    "Clock/timing validation: cpu=%.6f MHz sys=%.6f MHz ddr=%.6f MHz setup_WNS=%.6f ns hold_WNS=%.6f ns" \
    $actual_cpu_mhz $actual_sys_mhz $actual_ddr_mhz $setup_wns $hold_wns]

if {$setup_wns < 0.0 || $hold_wns < 0.0} {
    puts [format \
        "WARNING: implementation has negative timing slack: setup_WNS=%.6f ns hold_WNS=%.6f ns" \
        $setup_wns $hold_wns]
}
