# 最新时序路径汇总

由 `analyze_timing_full.py` 自动生成。Slack 越小越优先处理。

| 指标 | 值 |
| --- | ---: |
| 时钟周期（出现最多的 Requirement） | 10.000 ns |
| 当前主频 | 100.0 MHz |
| 解析路径数（去重） | 9720 |
| 最差 Slack | 0.068 ns |
| WNS (setup) | 3.913 ns |
| TNS (setup) | 0.0 ns |
| WHS (hold) | 0.081 ns |


## 全局最差路径

| 排名 | 起点级 | Slack (ns) | Delay (ns) | Route% | Levels | 扇出 | Source → Destination |
| ---: | --- | ---: | ---: | ---: | ---: | ---: | --- |
| 1 | ID | 0.068 | 21.510 | 79.9% | 30 | 266 | `u_decode/hold_bus_reg[100]/C` → `u_pre_IF1/pc_reg[30]/CE` |
| 2 | ID | 0.096 | 21.488 | 79.9% | 30 | 266 | `u_decode/hold_bus_reg[100]/C` → `u_pre_IF1/pc_reg[22]/CE` |
| 3 | ID | 0.155 | 21.421 | 79.8% | 30 | 266 | `u_decode/bus_reg[0][101]/C` → `u_pre_IF1/pc_reg[30]/CE` |
| 4 | ID | 0.170 | 21.408 | 79.8% | 30 | 266 | `u_decode/hold_bus_reg[100]/C` → `u_pre_IF1/pc_reg[30]/CE` |
| 5 | ID | 0.176 | 21.402 | 80.9% | 30 | 138 | `u_decode/hold_bus_reg[100]/C` → `u_pre_IF1/pc_reg[30]/CE` |
| 6 | ID | 0.182 | 21.399 | 79.8% | 30 | 266 | `u_decode/bus_reg[0][101]/C` → `u_pre_IF1/pc_reg[22]/CE` |
| 7 | ID | 0.188 | 21.391 | 79.8% | 30 | 266 | `u_decode/hold_bus_reg[100]/C` → `u_pre_IF1/pc_reg[24]/CE` |
| 8 | ID | 0.188 | 21.391 | 79.8% | 30 | 266 | `u_decode/hold_bus_reg[100]/C` → `u_pre_IF1/pc_reg[28]/CE` |
| 9 | ID | 0.190 | 21.390 | 79.8% | 30 | 266 | `u_decode/hold_bus_reg[100]/C` → `u_pre_IF1/pc_reg[18]/CE` |
| 10 | ID | 0.192 | 21.386 | 79.8% | 30 | 266 | `u_decode/hold_bus_reg[100]/C` → `u_pre_IF1/pc_reg[30]/CE` |
| 11 | ID | 0.198 | 21.386 | 79.8% | 30 | 266 | `u_decode/hold_bus_reg[100]/C` → `u_pre_IF1/pc_reg[22]/CE` |
| 12 | ID | 0.203 | 21.380 | 80.8% | 30 | 138 | `u_decode/hold_bus_reg[100]/C` → `u_pre_IF1/pc_reg[22]/CE` |
| 13 | ID | 0.210 | 21.368 | 80.7% | 30 | 138 | `u_decode/hold_bus_reg[100]/C` → `u_pre_IF1/pc_reg[30]/CE` |
| 14 | ID | 0.217 | 21.361 | 81.3% | 29 | 266 | `u_decode/hold_bus_reg[100]/C` → `u_pre_IF1/pc_reg[30]/CE` |
| 15 | ID | 0.218 | 21.368 | 79.8% | 30 | 17527 | `u_decode/hold_bus_reg[100]/C` → `u_pre_IF1/pc_reg[15]/CE` |
| 16 | ID | 0.218 | 21.368 | 79.8% | 30 | 17527 | `u_decode/hold_bus_reg[100]/C` → `u_pre_IF1/pc_reg[21]/CE` |
| 17 | ID | 0.232 | 21.343 | 79.7% | 30 | 17527 | `u_decode/hold_bus_reg[100]/C` → `u_pre_IF2/bus_slot0_reg[105]/CE` |
| 18 | ID | 0.236 | 21.346 | 79.7% | 30 | 17527 | `u_decode/hold_bus_reg[100]/C` → `u_pre_IF2/bus_slot0_reg[90]/CE` |
| 19 | ID | 0.236 | 21.346 | 79.7% | 30 | 17527 | `u_decode/hold_bus_reg[100]/C` → `u_pre_IF2/bus_slot0_reg[93]/CE` |
| 20 | ID | 0.257 | 21.354 | 79.8% | 30 | 17527 | `u_decode/hold_bus_reg[100]/C` → `u_pre_IF2/gen_bus[1].bus_reg[1][106]/CE` |
| 21 | ID | 0.274 | 21.313 | 79.7% | 30 | 17527 | `u_decode/hold_bus_reg[100]/C` → `u_pre_IF1/pc_reg[2]/CE` |
| 22 | ID | 0.279 | 21.307 | 79.7% | 30 | 17527 | `u_decode/hold_bus_reg[100]/C` → `u_pre_IF1/pc_reg[10]/CE` |
| 23 | ID | 0.279 | 21.307 | 79.7% | 30 | 17527 | `u_decode/hold_bus_reg[100]/C` → `u_pre_IF1/pc_reg[12]/CE` |
| 24 | ID | 0.281 | 21.295 | 79.7% | 30 | 17527 | `u_decode/hold_bus_reg[100]/C` → `u_pre_IF2/gen_bus[1].bus_reg[1][107]/CE` |
| 25 | ID | 0.287 | 21.300 | 79.7% | 30 | 17527 | `u_decode/hold_bus_reg[100]/C` → `u_pre_IF1/pc_reg[19]/CE` |
| 26 | ID | 0.287 | 21.300 | 79.7% | 30 | 17527 | `u_decode/hold_bus_reg[100]/C` → `u_pre_IF1/pc_reg[31]/CE` |
| 27 | ID | 0.287 | 21.300 | 79.7% | 30 | 17527 | `u_decode/hold_bus_reg[100]/C` → `u_pre_IF1/pc_reg[6]/CE` |
| 28 | ID | 0.306 | 21.270 | 79.7% | 30 | 17527 | `u_decode/hold_bus_reg[100]/C` → `u_pre_IF2/bus_slot0_reg[85]/CE` |
| 29 | ID | 0.306 | 21.270 | 79.7% | 30 | 17527 | `u_decode/hold_bus_reg[100]/C` → `u_pre_IF2/bus_slot0_reg[86]/CE` |
| 30 | ID | 0.306 | 21.270 | 79.7% | 30 | 17527 | `u_decode/hold_bus_reg[100]/C` → `u_pre_IF2/bus_slot0_reg[99]/CE` |
| 31 | ID | 0.331 | 21.251 | 79.7% | 30 | 17527 | `u_decode/hold_bus_reg[100]/C` → `u_fetch/bus_reg[0][46]/CE` |
| 32 | ID | 0.331 | 21.251 | 79.7% | 30 | 17527 | `u_decode/hold_bus_reg[100]/C` → `u_fetch/bus_reg[0][48]/CE` |
| 33 | ID | 0.331 | 21.251 | 79.7% | 30 | 17527 | `u_decode/hold_bus_reg[100]/C` → `u_fetch/bus_reg[0][65]/CE` |
| 34 | ID | 0.331 | 21.251 | 79.7% | 30 | 17527 | `u_decode/hold_bus_reg[100]/C` → `u_fetch/bus_reg[1][28]/CE` |
| 35 | ID | 0.331 | 21.251 | 79.7% | 30 | 17527 | `u_decode/hold_bus_reg[100]/C` → `u_fetch/bus_reg[1][37]/CE` |
| 36 | ID | 0.331 | 21.251 | 79.7% | 30 | 17527 | `u_decode/hold_bus_reg[100]/C` → `u_fetch/bus_reg[1][38]/CE` |
| 37 | ID | 0.331 | 21.251 | 79.7% | 30 | 17527 | `u_decode/hold_bus_reg[100]/C` → `u_fetch/bus_reg[1][84]/CE` |
| 38 | ID | 0.331 | 21.251 | 79.7% | 30 | 17527 | `u_decode/hold_bus_reg[100]/C` → `u_fetch/bus_reg[1][96]/CE` |
| 39 | ID | 0.331 | 21.244 | 79.6% | 30 | 17527 | `u_decode/hold_bus_reg[100]/C` → `u_pre_IF2/bus_slot0_reg[103]/CE` |
| 40 | ID | 0.331 | 21.244 | 79.6% | 30 | 17527 | `u_decode/hold_bus_reg[100]/C` → `u_pre_IF2/bus_slot0_reg[104]/CE` |

## 高扇出网络

| 扇出 | 网络 |
| ---: | --- |
| 17527 | `u_decode/cpu_clk` |
| 17527 | `u_wb/cpu_clk` |
| 17527 | `u_pre_IF1/cpu_clk` |
| 7005 | `ddr3.u_axi_wrap_ddr/mig_axi/u_mig_axi_32_mig/u_memc_ui_top_axi/CLK` |
| 7005 | `ddr3.u_axi_wrap_ddr/mig_axi/u_mig_axi_32_mig/u_memc_ui_top_axi/u_ui_top/ui_wr_data0/CLK` |
| 7005 | `ddr3.u_axi_wrap_ddr/mig_axi/u_mig_axi_32_mig/u_memc_ui_top_axi/u_axi_mc/USE_UPSIZER.upsizer_d2/si_register_slice_inst/aw_pipe/CLK` |
| 7005 | `ddr3.u_axi_wrap_ddr/mig_axi/u_mig_axi_32_mig/u_memc_ui_top_axi/u_ui_top/ui_cmd0/CLK` |
| 7005 | `ddr3.u_axi_wrap_ddr/mig_axi/u_mig_axi_32_mig/u_memc_ui_top_axi/u_axi_mc/USE_UPSIZER.upsizer_d2/USE_WRITE.write_data_inst/CLK` |
| 7005 | `ddr3.u_axi_wrap_ddr/mig_axi/u_mig_axi_32_mig/u_memc_ui_top_axi/u_axi_mc/USE_UPSIZER.upsizer_d2/USE_READ.read_addr_inst/CLK` |
| 7005 | `ddr3.u_axi_wrap_ddr/mig_axi/u_mig_axi_32_mig/u_memc_ui_top_axi/mem_intfc0/ddr_phy_top0/u_ddr_mc_phy_wrapper/u_ddr_mc_phy/ddr_phy_4lanes_0.u_ddr_phy_4lanes/ddr_byte_lane_B.ddr_byte_lane_B/CLK` |
| 7005 | `ddr3.u_axi_wrap_ddr/mig_axi/u_mig_axi_32_mig/u_memc_ui_top_axi/mem_intfc0/ddr_phy_top0/u_ddr_calib_top/u_ddr_phy_init/CLK` |
| 7005 | `ddr3.u_axi_wrap_ddr/u_Axi_CDC/awFifo/ui_clk` |
| 7005 | `ddr3.u_axi_wrap_ddr/mig_axi/u_mig_axi_32_mig/u_memc_ui_top_axi/mem_intfc0/mc0/bank_mach0/arb_mux0/arb_row_col0/col_arb0/CLK` |
| 7005 | `ddr3.u_axi_wrap_ddr/mig_axi/u_mig_axi_32_mig/u_memc_ui_top_axi/u_axi_mc/axi_mc_w_channel_0/CLK` |
| 7005 | `ddr3.u_axi_wrap_ddr/mig_axi/u_mig_axi_32_mig/u_memc_ui_top_axi/u_axi_mc/axi_mc_aw_channel_0/aw_cmd_fsm_0/CLK` |

## 判断标准

- Slack < 0：违例，必须处理；
- 布线占比 ≥ 70%：先查长线/扇出/跨模块，再考虑拆级；
- 逻辑占比 ≥ 50% 或 Levels ≥ 20：组合深度问题，考虑拆级/提前译码；
- 扇出 ≥ 50：复制寄存器或把全局控制改局部。
