# Generate the timing reports documented in 1.各流水级时序.md, then run the
# existing Python summarizer. Source this file from the Vivado Tcl Console
# after opening the project.

set script_dir [file normalize [file dirname [info script]]]
set repo_root  [file normalize [file join $script_dir ..]]
set report_dir [file normalize [file join $repo_root fpga nscscc-team run_vivado result for_timing_report]]
set analyzer   [file normalize [file join $script_dir analyze_timing_reports.py]]

if {[current_project -quiet] eq ""} {
    error "No Vivado project is open. Open the project before sourcing this script."
}

if {[llength [get_runs -quiet impl_1]] == 0} {
    error "Implementation run impl_1 does not exist in the current project."
}

file mkdir $report_dir

puts "Opening implemented design: impl_1"
open_run impl_1

puts "Report directory: $report_dir"

report_timing_summary \
    -setup \
    -hold \
    -max_paths 50 \
    -file [file join $report_dir timing_summary1.rpt]

report_design_analysis \
    -timing \
    -setup \
    -max_paths 100 \
    -logic_level_distribution \
    -logic_level_dist_paths 100 \
    -show_all \
    -file [file join $report_dir design_analysis1.rpt]

set preIF1_stage_regs [get_cells -hier -filter {
    REF_NAME =~ FD* && NAME =~ */u_pre_IF1/*
}]
set preIF2_stage_regs [get_cells -hier -filter {
    REF_NAME =~ FD* && NAME =~ */u_pre_IF2/*
}]
set IF_stage_regs [get_cells -hier -filter {
    REF_NAME =~ FD* && NAME =~ */u_fetch/*
}]
set ID_stage_regs [get_cells -hier -filter {
    REF_NAME =~ FD* && NAME =~ */u_decode/*
}]
set EXE1_stage_regs [get_cells -hier -filter {
    REF_NAME =~ FD* && NAME =~ */u_exe1/*
}]
set EXE2_stage_regs [get_cells -hier -filter {
    REF_NAME =~ FD* && NAME =~ */u_exe2/*
}]
set MEM_stage_regs [get_cells -hier -filter {
    REF_NAME =~ FD* && NAME =~ */u_mem/*
}]
set WB_stage_regs [get_cells -hier -filter {
    REF_NAME =~ FD* && NAME =~ */u_wb/*
}]

puts "preIF1_stage_count = [llength $preIF1_stage_regs]"
puts "preIF2_stage_count = [llength $preIF2_stage_regs]"
puts "IF_stage_count     = [llength $IF_stage_regs]"
puts "ID_stage_count     = [llength $ID_stage_regs]"
puts "EXE1_stage_count   = [llength $EXE1_stage_regs]"
puts "EXE2_stage_count   = [llength $EXE2_stage_regs]"
puts "MEM_stage_count    = [llength $MEM_stage_regs]"
puts "WB_stage_count     = [llength $WB_stage_regs]"

proc report_stage_top60 {stage_name stage_regs report_file} {
    if {[llength $stage_regs] == 0} {
        puts "WARNING: $stage_name register group is empty"
        return
    }

    set from_pins [get_pins -of_objects $stage_regs -filter {
        NAME =~ */Q
    }]

    if {[llength $from_pins] == 0} {
        puts "WARNING: $stage_name has no Q pins"
        return
    }

    puts "Reporting $stage_name -> $report_file"
    report_timing \
        -from $from_pins \
        -setup \
        -max_paths 60 \
        -nworst 1 \
        -sort_by slack \
        -path_type full \
        -input_pins \
        -file $report_file
}

report_stage_top60 "preIF1" $preIF1_stage_regs [file join $report_dir 01_preIF1_top60.rpt]
report_stage_top60 "preIF2" $preIF2_stage_regs [file join $report_dir 02_preIF2_top60.rpt]
report_stage_top60 "IF"     $IF_stage_regs     [file join $report_dir 03_IF_top60.rpt]
report_stage_top60 "ID"     $ID_stage_regs     [file join $report_dir 04_ID_top60.rpt]
report_stage_top60 "EXE1"   $EXE1_stage_regs   [file join $report_dir 05_EXE1_top60.rpt]
report_stage_top60 "EXE2"   $EXE2_stage_regs   [file join $report_dir 06_EXE2_top60.rpt]
report_stage_top60 "MEM"    $MEM_stage_regs    [file join $report_dir 07_MEM_top60.rpt]
report_stage_top60 "WB"     $WB_stage_regs     [file join $report_dir 08_WB_top60.rpt]

report_high_fanout_nets \
    -timing \
    -max_nets 100 \
    -file [file join $report_dir high_fanout_nets.rpt]

report_timing \
    -setup \
    -max_paths 20 \
    -nworst 1 \
    -sort_by slack \
    -path_type full \
    -input_pins \
    -file [file join $report_dir global_worst20_full_exp1.rpt]

proc find_python_command {} {
    foreach command {{python} {python3} {py -3}} {
        if {[auto_execok [lindex $command 0]] ne ""} {
            return $command
        }
    }
    return {}
}

set python_command [find_python_command]
if {[llength $python_command] == 0} {
    puts "WARNING: Python was not found in Vivado's PATH."
    puts "Run manually: python \"$analyzer\" --input \"$report_dir\" --output \"$report_dir\""
} elseif {![file exists $analyzer]} {
    puts "WARNING: Analyzer does not exist: $analyzer"
} else {
    puts "Running timing analyzer: $analyzer"
    if {[catch {
        exec {*}$python_command $analyzer --input $report_dir --output $report_dir 2>@1
    } analyzer_output]} {
        puts "WARNING: Timing analyzer failed:"
        puts $analyzer_output
        puts "Reports were generated successfully; run the analyzer manually if needed."
    } else {
        puts $analyzer_output
    }
}

puts "Timing report flow complete."
