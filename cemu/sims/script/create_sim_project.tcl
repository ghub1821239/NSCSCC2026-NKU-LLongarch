# 脚本在 cemu/sims/script/ → 上三级到仓库根
set root [file normalize [file join [file dirname [info script]] ../../..]]
set sims [file join $root cemu/sims]

create_project cpu_sim [file join $sims vivado_sim] -part xc7a200tfbg676-2 -force

add_files [glob -nocomplain [file join $root IP/myCPU/*.sv]]
add_files [glob -nocomplain [file join $root IP/myCPU/*.v]]
add_files [file join $root IP/myCPU/xilinx_ip/divider/divider.xci]
add_files [file join $root IP/myCPU/xilinx_ip/divider_unsigned/divider_unsigned.xci]
add_files [file join $root chip/soc_demo/nscscc-team/CONFREG/confreg.v]

add_files [file join $sims socs/axi_sim_ram.v]
add_files [file join $sims socs/soc_sim_top.v]
add_files [file join $sims testbench/golden_dual_slot_cmp.v]
add_files [file join $sims testbench/tb_top.v]

set_property top tb_top [get_filesets sim_1]