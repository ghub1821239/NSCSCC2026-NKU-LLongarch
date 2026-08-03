# Generate the platform-owned performance Clock Wizard configuration.
#
# Usage:
#   vivado -mode batch -source generate_perf_pll.tcl \
#       -tclargs <cpu_mhz> ?<clk_pll.xci>? ?<report_file>?
#
# The existing platform XCI is used as a known-good template. Only the CPU
# target frequency is variable; sys_clk and the MIG reference clock remain
# fixed platform settings.

proc ActualFrequencyFromSummary {ip property_name clock_name} {
    set summary [get_property $property_name $ip]
    if {![regexp {__([0-9]+[.][0-9]+)__} $summary matched frequency]} {
        error "Unable to parse actual $clock_name frequency from '$summary'"
    }
    return [expr {double($frequency)}]
}

proc RequireFrequency {clock_name actual expected tolerance} {
    if {[expr {abs($actual - $expected)}] > $tolerance} {
        error [format "%s frequency %.6f MHz differs from required %.6f MHz by more than %.6f MHz" \
            $clock_name $actual $expected $tolerance]
    }
}

if {$argc < 1 || $argc > 3} {
    error "Usage: generate_perf_pll.tcl <cpu_mhz> ?<clk_pll.xci>? ?<report_file>?"
}

set cpu_mhz_text [lindex $argv 0]
if {![regexp {^[0-9]+([.][0-9]+)?$} $cpu_mhz_text]} {
    error "CPU frequency must be a decimal number in MHz, got '$cpu_mhz_text'"
}

set cpu_mhz [expr {double($cpu_mhz_text)}]
if {$cpu_mhz < 10.0 || $cpu_mhz > 200.0} {
    error [format "CPU frequency %.6f MHz is outside the supported 10-200 MHz range" \
        $cpu_mhz]
}

set script_dir [file dirname [file normalize [info script]]]
set default_xci [file normalize [file join $script_dir \
    ../../../chip/soc_demo/nscscc-team/xilinx_ip/clk_pll/clk_pll.xci]]
set xci_file $default_xci
if {$argc >= 2} {
    set xci_file [file normalize [lindex $argv 1]]
}
if {![file exists $xci_file]} {
    error "Platform Clock Wizard XCI was not found: $xci_file"
}

# A runner snapshot can contain ignored generated IP output from an earlier
# build. Remove only this IP's derived output before opening the XCI, otherwise
# Vivado can treat its configuration properties as read-only.
set generated_ip_dir [file join [file dirname $xci_file] gen]
file delete -force $generated_ip_dir

set report_file ""
if {$argc >= 3} {
    set report_file [file normalize [lindex $argv 2]]
}

create_project -in_memory -part xc7a200tfbg676-2
read_ip $xci_file

set clock_ip [get_ips -quiet clk_pll]
if {[llength $clock_ip] != 1} {
    error "Expected exactly one clk_pll IP after reading $xci_file"
}

set_property -dict [list \
    CONFIG.CLKOUT1_REQUESTED_OUT_FREQ [format %.6f $cpu_mhz] \
    CONFIG.CLKOUT2_REQUESTED_OUT_FREQ {100.000000} \
    CONFIG.CLKOUT3_REQUESTED_OUT_FREQ {200.000000} \
    CONFIG.CLK_OUT1_PORT {cpu_clk} \
    CONFIG.CLK_OUT2_PORT {sys_clk} \
    CONFIG.CLK_OUT3_PORT {ddr_clk} \
] $clock_ip

generate_target all $clock_ip

set actual_cpu [ActualFrequencyFromSummary $clock_ip CONFIG.C_OUTCLK_SUM_ROW1 cpu_clk]
set actual_sys [ActualFrequencyFromSummary $clock_ip CONFIG.C_OUTCLK_SUM_ROW2 sys_clk]
set actual_ddr [ActualFrequencyFromSummary $clock_ip CONFIG.C_OUTCLK_SUM_ROW3 ddr_clk]

# Clock Wizard may approximate a requested CPU frequency. Accept at most one
# percent error and publish the actual frequency for scoring and diagnosis.
set cpu_tolerance [expr {max(0.001, $cpu_mhz * 0.01)}]
RequireFrequency cpu_clk $actual_cpu $cpu_mhz $cpu_tolerance
RequireFrequency sys_clk $actual_sys 100.0 0.001
RequireFrequency ddr_clk $actual_ddr 200.0 0.001

set result [format \
    "requested_cpu_mhz=%.6f\nactual_cpu_mhz=%.6f\nactual_sys_mhz=%.6f\nactual_ddr_mhz=%.6f" \
    $cpu_mhz $actual_cpu $actual_sys $actual_ddr]
puts $result

if {$report_file ne ""} {
    set report_channel [open $report_file w]
    puts $report_channel $result
    close $report_channel
}

close_project
