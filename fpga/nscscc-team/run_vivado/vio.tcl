proc WaitForDdrReady {vio status_probe timeout_ms {quiet 0}} {
    set interval_ms 100
    set elapsed_ms 0
    set status 0

    while {$elapsed_ms <= $timeout_ms} {
        refresh_hw_vio $vio
        set status_raw [get_property INPUT_VALUE $status_probe]
        if {[scan $status_raw %x status] != 1} {
            error "Invalid DDR readiness value '$status_raw'"
        }

        if {($status & 0x7) == 0x7} {
            if {!$quiet} {
                puts [format "DDR ready after %d ms: sys_resetn=1 calib=1 clock_pll=1" \
                    $elapsed_ms]
            }
            return
        }

        after $interval_ms
        incr elapsed_ms $interval_ms
    }

    error [format "DDR readiness timeout after %d ms: status=0x%X sys_resetn=%d calib=%d clock_pll=%d" \
        $timeout_ms $status \
        [expr {($status >> 2) & 1}] \
        [expr {($status >> 1) & 1}] \
        [expr {$status & 1}]]
}

proc ResetTestSystem {vio reset_probe status_probe timeout_ms {quiet 0}} {
    # Match a physical Reset press: reset PLL, MIG, AXI fabric and the complete
    # SoC. DDR contents are not rewritten, so the image downloaded once by
    # JTAG remains available after MIG recalibration on the competition board.
    set_property OUTPUT_VALUE 0 $reset_probe
    commit_hw_vio $reset_probe
    after 100
    set_property OUTPUT_VALUE 1 $reset_probe
    commit_hw_vio $reset_probe
    WaitForDdrReady $vio $status_probe $timeout_ms $quiet
}

proc WaitForFuncResult {vio result_probe flag_probe expected_result timeout_ms} {
    set interval_ms 250
    set elapsed_ms 0
    set result 0
    set correct_flag 0

    while {$elapsed_ms <= $timeout_ms} {
        refresh_hw_vio $vio
        set result_raw [get_property INPUT_VALUE $result_probe]
        set flag_raw [get_property INPUT_VALUE $flag_probe]
        if {[scan $result_raw %x result] != 1} {
            error "Invalid functional result value '$result_raw'"
        }
        if {[scan $flag_raw %x correct_flag] != 1} {
            error "Invalid functional flag value '$flag_raw'"
        }

        if {$result == $expected_result} {
            return [list pass $result $correct_flag $elapsed_ms]
        }
        if {$correct_flag == 0x2} {
            return [list fail $result $correct_flag $elapsed_ms]
        }

        after $interval_ms
        incr elapsed_ms $interval_ms
    }

    return [list timeout $result $correct_flag $timeout_ms]
}

proc WaitForPerfResult {vio flag_probe timeout_ms} {
    set interval_ms 250
    set elapsed_ms 0
    set correct_flag 0

    while {$elapsed_ms <= $timeout_ms} {
        refresh_hw_vio $vio
        set flag_raw [get_property INPUT_VALUE $flag_probe]
        if {[scan $flag_raw %x correct_flag] != 1} {
            error "Invalid performance flag value '$flag_raw'"
        }

        switch $correct_flag {
            0 {
                # Reset, boot and in-progress all use zero. A CPU that hangs
                # also remains zero and is distinguished by the timeout.
            }
            1 {
                return [list pass $correct_flag $elapsed_ms]
            }
            2 {
                return [list fail $correct_flag $elapsed_ms]
            }
            default {
                return [list invalid $correct_flag $elapsed_ms]
            }
        }

        after $interval_ms
        incr elapsed_ms $interval_ms
    }

    return [list timeout $correct_flag $timeout_ms]
}

open_hw_manager
connect_hw_server
open_hw_target
set_property PROBES.FILE [lindex $argv 1] [get_hw_devices xc7a200t_0]
set_property FULL_PROBES.FILE [lindex $argv 1] [get_hw_devices xc7a200t_0]
set_property PROGRAM.FILE [lindex $argv 0] [get_hw_devices xc7a200t_0]
program_hw_devices [get_hw_devices xc7a200t_0]
refresh_hw_device [lindex [get_hw_devices xc7a200t_0] 0]

set vio [lindex [get_hw_vios] 0]
set reset_probe [lindex [get_hw_probes -quiet resetn_vio] 0]
set status_probe [lindex [get_hw_probes -quiet ddr_status_vio] 0]
set switch_probe [lindex [get_hw_probes -quiet switch_vio] 0]
set result_probe [lindex [get_hw_probes -quiet num_data] 0]
set flag_probe [lindex [get_hw_probes -quiet led_rg0_OBUF] 0]
if {$vio eq "" || $reset_probe eq "" || $status_probe eq "" ||
    $switch_probe eq "" || $result_probe eq "" || $flag_probe eq ""} {
    error "Required VIO control, result or readiness probe was not found"
}

# Select the first test before resetting the complete SoC. CPU/confreg start
# automatically when the normal reset tree is released, matching a physical
# Reset-button run.
set test [lindex $argv 2]
switch $test {
    "perf" {
        set_property OUTPUT_VALUE 7E $switch_probe
    }
    "func" {
        set_property OUTPUT_VALUE F0 $switch_probe
    }
}
commit_hw_vio $switch_probe

# Use a deterministic post-configuration reset before the first download. The
# first JTAG AXI transaction is issued only after the shared clock PLL, MIG
# calibration and AXI reset tree are ready.
ResetTestSystem $vio $reset_probe $status_probe 30000

# jtag_axi_master.tcl asserts the JTAG wrapper's CPU reset, writes the image,
# and releases that reset at the end.
# Successful JTAG AXI writes otherwise print the complete program image as
# hundreds of long INFO lines. Suppress only that data echo; transaction
# failures use different ERROR message IDs and remain visible.
set_msg_config -id {Labtoolstcl 44-481} -suppress
source ../jtag_axi_master.tcl

switch $test {
    "perf" {
        set benchmark_names [list \
            bitcount bubble_sort coremark crc32 dhrystone quick_sort \
            select_sort sha stream_copy stringsearch fireye_A0 fireye_B2 \
            fireye_C0 fireye_D1 fireye_I2 inner_product lookup_table \
            loop_induction my_memcmp minmax_sequence]
        set benchmark_count [llength $benchmark_names]
        set runs_per_benchmark 2
        set total_runs [expr {$benchmark_count * $runs_per_benchmark}]
        set perf_timeout_ms 30000
        set result_settle_ms 500

        set selected_outfile [open "perf_vio.csv" w]
        puts $selected_outfile "correct_flag,soc_count,cpu_count"
        set runs_outfile [open "perf_vio_runs.csv" w]
        puts $runs_outfile \
            "benchmark_index,benchmark,run,switch,correct_flag,soc_count,cpu_count,valid,selected"

        for {set benchmark_number 1} {
            $benchmark_number <= $benchmark_count
        } {incr benchmark_number} {
            set benchmark [lindex $benchmark_names [expr {$benchmark_number - 1}]]
            set switch_value [expr {127 - $benchmark_number}]
            set run_records {}

            for {set run_number 1} {
                $run_number <= $runs_per_benchmark
            } {incr run_number} {
                set total_run_number [expr {
                    ($benchmark_number - 1) * $runs_per_benchmark + $run_number
                }]
                puts [format \
                    {PERF [%02d/%02d] %s run %d/%d} \
                    $total_run_number $total_runs $benchmark $run_number \
                    $runs_per_benchmark]
                flush stdout

                # Select a benchmark, pulse the complete system reset, and let
                # the CPU start automatically when the reset tree is ready.
                set_property OUTPUT_VALUE \
                    [format %02X $switch_value] $switch_probe
                commit_hw_vio $switch_probe
                ResetTestSystem \
                    $vio $reset_probe $status_probe 30000 1

                lassign [WaitForPerfResult \
                    $vio $flag_probe $perf_timeout_ms] \
                    perf_status correct_flag perf_elapsed_ms
                puts [format \
                    {PERF COMPLETION [%02d/%02d] %s run %d/%d status=%s flag=0x%X elapsed=%d ms} \
                    $total_run_number $total_runs $benchmark $run_number \
                    $runs_per_benchmark [string toupper $perf_status] \
                    $correct_flag $perf_elapsed_ms]
                flush stdout

                set soc_count 0
                set cpu_count 0
                if {$perf_status ne "timeout"} {
                    # The performance software currently publishes LED_RG0
                    # before writing CR0/CR1 and entering test_finish, where it
                    # copies the switch-selected counter into num_data. Allow
                    # that result service to become active before sampling.
                    after $result_settle_ms
                    refresh_hw_vio $vio
                    set soc_count_raw \
                        [get_property INPUT_VALUE $result_probe]
                    if {[scan $soc_count_raw %x soc_count] != 1} {
                        error "Invalid performance SoC count '$soc_count_raw'"
                    }

                    set_property OUTPUT_VALUE \
                        [format %02X [expr {$switch_value + 128}]] \
                        $switch_probe
                    commit_hw_vio $switch_probe

                    after $result_settle_ms
                    refresh_hw_vio $vio
                    set cpu_count_raw \
                        [get_property INPUT_VALUE $result_probe]
                    if {[scan $cpu_count_raw %x cpu_count] != 1} {
                        error "Invalid performance CPU count '$cpu_count_raw'"
                    }
                }

                set run_valid [expr {
                    $correct_flag == 1 && $soc_count > 0 && $cpu_count > 0
                }]
                lappend run_records [list \
                    $run_number $correct_flag $soc_count $cpu_count $run_valid]
            }

            # A benchmark is repeatable only if both independent runs pass.
            # When both pass, the larger CPU count is the conservative result.
            # Otherwise select the first failing run so perf_vio.csv cannot be
            # mistaken for a valid benchmark by the scoring script.
            set benchmark_valid 1
            set selected_record [lindex $run_records 0]
            set first_invalid_record {}
            foreach record $run_records {
                lassign $record \
                    run_number correct_flag soc_count cpu_count run_valid
                if {!$run_valid} {
                    set benchmark_valid 0
                    if {$first_invalid_record eq ""} {
                        set first_invalid_record $record
                    }
                }
                if {$run_valid &&
                    [lindex $selected_record 4] &&
                    $cpu_count > [lindex $selected_record 3]} {
                    set selected_record $record
                }
            }
            if {!$benchmark_valid} {
                set selected_record $first_invalid_record
            }

            lassign $selected_record \
                selected_run selected_flag selected_soc selected_cpu \
                selected_valid
            foreach record $run_records {
                lassign $record \
                    run_number correct_flag soc_count cpu_count run_valid
                puts $runs_outfile [format \
                    "%d,%s,%d,%02X,%X,%08X,%08X,%s,%d" \
                    $benchmark_number $benchmark $run_number $switch_value \
                    $correct_flag $soc_count $cpu_count \
                    [expr {$run_valid ? "pass" : "fail"}] \
                    [expr {$run_number == $selected_run}]]
            }
            flush $runs_outfile

            puts $selected_outfile [format "%X,%08X,%08X" \
                $selected_flag $selected_soc $selected_cpu]
            flush $selected_outfile

            set run_summaries {}
            foreach record $run_records {
                lassign $record \
                    run_number correct_flag soc_count cpu_count run_valid
                if {$run_valid} {
                    lappend run_summaries [format \
                        "r%d=PASS cpu=0x%08X" \
                        $run_number $cpu_count]
                } else {
                    lappend run_summaries [format \
                        "r%d=FAIL flag=0x%X soc=0x%08X cpu=0x%08X" \
                        $run_number $correct_flag $soc_count $cpu_count]
                }
            }
            puts [format \
                {PERF RESULT [%02d/%02d] %s %s | %s | selected=r%d} \
                $benchmark_number $benchmark_count $benchmark \
                [expr {$benchmark_valid ? "PASS" : "FAIL"}] \
                [join $run_summaries " | "] $selected_run]
            flush stdout
        }
        close $selected_outfile
        close $runs_outfile
        puts [format \
            "Performance collection complete: %d benchmarks, %d independent runs, worst valid run selected" \
            $benchmark_count $total_runs]
    }
    "func" {
        set outfile [open "func_vio.csv" w]
        puts $outfile "seed,status,result,correct_flag,elapsed_ms"

        # Releasing confreg reset reloads its pseudo-random AXI delay generator
        # from switch_vio. After reset, the functional
        # program reads the live switch repeatedly in idle_1s to choose a
        # human-visible inter-test delay. Keep those two meanings separate:
        # preserve each reset seed, then select FF to remove only the software
        # delay. Always run a no-delay AXI baseline and the historical default,
        # plus one logged stress seed selected by CI (or A5 manually).
        set stress_seed [string toupper [lindex $argv 3]]
        if {$stress_seed eq ""} {
            set stress_seed A5
        }
        if {![regexp {^[0-9A-F]{2}$} $stress_seed]} {
            error "Functional stress seed must be exactly two hexadecimal digits"
        }
        set func_seeds {}
        foreach func_seed [list F0 FF $stress_seed] {
            if {[lsearch -exact $func_seeds $func_seed] < 0} {
                lappend func_seeds $func_seed
            }
        }
        set expected_func_result 0x3A00003A
        set func_timeout_ms 60000
        set func_results {}
        set func_failures {}
        foreach func_seed $func_seeds {
            set_property OUTPUT_VALUE $func_seed $switch_probe
            commit_hw_vio $switch_probe
            puts "Running functional test with switch/random seed 0x$func_seed"
            ResetTestSystem \
                $vio $reset_probe $status_probe 30000 1

            # The AXI LFSR seed is loaded while system reset is asserted.
            # Keep the seed stable until reset release has crossed sys_clk.
            after 1

            # The AXI LFSR seed has now been latched by confreg. FF makes
            # SW_INTER ^ 0xAAAA zero in the functional program's idle_1s
            # routine. It does not change the already-running AXI LFSR.
            set_property OUTPUT_VALUE FF $switch_probe
            commit_hw_vio $switch_probe
            puts "Functional seed 0x$func_seed latched; runtime wait switch set to 0xFF"

            lassign [WaitForFuncResult \
                $vio $result_probe $flag_probe $expected_func_result \
                $func_timeout_ms] \
                func_status func_result func_flag func_elapsed_ms
            puts $outfile [format "%s,%s,%08X,%X,%d" \
                $func_seed $func_status $func_result $func_flag \
                $func_elapsed_ms]
            flush $outfile
            lappend func_results [list \
                $func_seed $func_status $func_result $func_flag \
                $func_elapsed_ms]
            if {$func_status ne "pass"} {
                lappend func_failures $func_seed
            }
        }
        close $outfile

        puts "FUNCTIONAL TEST SUMMARY"
        foreach func_record $func_results {
            lassign $func_record \
                func_seed func_status func_result func_flag \
                func_elapsed_ms
            puts [format \
                "  seed=0x%s status=%s elapsed=%d ms result=0x%08X flag=0x%X" \
                $func_seed [string toupper $func_status] \
                $func_elapsed_ms $func_result $func_flag]
        }
        if {[llength $func_failures] > 0} {
            set formatted_func_failures {}
            foreach failed_seed $func_failures {
                lappend formatted_func_failures \
                    [format "0x%s" $failed_seed]
            }
            error [format \
                "Functional test failed after all %d seeds completed: failed seeds=%s expected=0x%08X" \
                [llength $func_seeds] \
                [join $formatted_func_failures ","] \
                $expected_func_result]
        }
        puts [format "All %d functional random seeds passed" \
            [llength $func_seeds]]
    }
    default {
        puts "No VIO result collection requested for '$test'"
    }

}

close_hw_manager
