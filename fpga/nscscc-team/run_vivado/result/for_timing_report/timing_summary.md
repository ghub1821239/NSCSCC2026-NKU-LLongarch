# 最新时序路径汇总

由 `analyze_timing_full.py` 自动生成。Slack 越小越优先处理。

| 指标 | 值 |
| --- | ---: |
| 时钟周期（出现最多的 Requirement） | 10.000 ns |
| 当前主频 | 100.0 MHz |
| 解析路径数（去重） | 10405 |
| 最差 Slack | 0.009 ns |
| WNS (setup) | 2.546 ns |
| TNS (setup) | 0.0 ns |
| WHS (hold) | 0.076 ns |


## 全局最差路径

| 排名 | 起点级 | Slack (ns) | Delay (ns) | Route% | Levels | 扇出 | Source → Destination |
| ---: | --- | ---: | ---: | ---: | ---: | ---: | --- |
| 1 | ? | 0.009 | 9.809 | 87.0% | 7 | 15 | `pushCC_pushPtrGray_reg[2]/C` → `last_count_reg[8]/CE` |
| 2 | ? | 0.009 | 9.809 | 87.0% | 7 | 3584 | `ddr3.u_axi_wrap_ddr/u_Axi_CDC/wFifo/pushCC_pushPtrGray_reg[2]/C` → `u_jtag_axi_wrap/u_jtag_axi/inst/axi_bridge_u/write_axi_full_u/last_count_reg[8]/CE` |
| 3 | ? | 0.029 | 9.788 | 86.0% | 7 | 15 | `pushCC_pushPtrGray_reg[2]/C` → `last_count_reg[2]/CE` |
| 4 | ? | 0.029 | 9.788 | 86.0% | 7 | 15 | `pushCC_pushPtrGray_reg[2]/C` → `last_count_reg[5]/CE` |
| 5 | ? | 0.029 | 9.788 | 87.0% | 7 | 3584 | `ddr3.u_axi_wrap_ddr/u_Axi_CDC/wFifo/pushCC_pushPtrGray_reg[2]/C` → `u_jtag_axi_wrap/u_jtag_axi/inst/axi_bridge_u/write_axi_full_u/last_count_reg[2]/CE` |
| 6 | ? | 0.029 | 9.788 | 87.0% | 7 | 3584 | `ddr3.u_axi_wrap_ddr/u_Axi_CDC/wFifo/pushCC_pushPtrGray_reg[2]/C` → `u_jtag_axi_wrap/u_jtag_axi/inst/axi_bridge_u/write_axi_full_u/last_count_reg[5]/CE` |
| 7 | ? | 0.061 | 9.755 | 87.0% | 7 | 3584 | `ddr3.u_axi_wrap_ddr/u_Axi_CDC/wFifo/pushCC_pushPtrGray_reg[2]/C` → `u_jtag_axi_wrap/u_jtag_axi/inst/axi_bridge_u/write_axi_full_u/last_count_reg[3]/CE` |
| 8 | ? | 0.061 | 9.755 | 87.0% | 7 | 3584 | `ddr3.u_axi_wrap_ddr/u_Axi_CDC/wFifo/pushCC_pushPtrGray_reg[2]/C` → `u_jtag_axi_wrap/u_jtag_axi/inst/axi_bridge_u/write_axi_full_u/last_count_reg[4]/CE` |
| 9 | ? | 0.061 | 9.755 | 86.0% | 7 | 15 | `pushCC_pushPtrGray_reg[2]/C` → `last_count_reg[3]/CE` |
| 10 | ? | 0.061 | 9.755 | 86.0% | 7 | 15 | `pushCC_pushPtrGray_reg[2]/C` → `last_count_reg[4]/CE` |
| 11 | ? | 0.074 | 14.104 | 66.0% | 18 | 164 | `DEVICE_7SERIES.NO_BMM_INFO.SP.WIDE_PRIM18.ram/CLKARDCLK` → `bus_reg[101]/D` |
| 12 | dcache | 0.074 | 14.104 | 66.0% | 18 | 11395 | `u_Dcache/tagv_way1/U0/inst_blk_mem_gen/gnbram.gnativebmg.native_blk_mem_gen/valid.cstr/ramloop[0].ram.r/prim_init.ram/DEVICE_7SERIES.NO_BMM_INFO.SP.WIDE_PRIM18.ram/CLKARDCLK` → `u_exe1/bus_reg[101]/D` |
| 13 | ? | 0.083 | 9.733 | 86.0% | 7 | 15 | `pushCC_pushPtrGray_reg[2]/C` → `last_count_reg[0]/CE` |
| 14 | ? | 0.083 | 9.733 | 86.0% | 7 | 15 | `pushCC_pushPtrGray_reg[2]/C` → `last_count_reg[1]/CE` |
| 15 | ? | 0.083 | 9.733 | 86.9% | 7 | 3584 | `ddr3.u_axi_wrap_ddr/u_Axi_CDC/wFifo/pushCC_pushPtrGray_reg[2]/C` → `u_jtag_axi_wrap/u_jtag_axi/inst/axi_bridge_u/write_axi_full_u/last_count_reg[0]/CE` |
| 16 | ? | 0.083 | 9.733 | 86.9% | 7 | 3584 | `ddr3.u_axi_wrap_ddr/u_Axi_CDC/wFifo/pushCC_pushPtrGray_reg[2]/C` → `u_jtag_axi_wrap/u_jtag_axi/inst/axi_bridge_u/write_axi_full_u/last_count_reg[1]/CE` |
| 17 | dcache | 0.100 | 21.497 | 66.6% | 33 | 249 | `u_Dcache/tagv_way1/U0/inst_blk_mem_gen/gnbram.gnativebmg.native_blk_mem_gen/valid.cstr/ramloop[0].ram.r/prim_init.ram/DEVICE_7SERIES.NO_BMM_INFO.SP.SIMPLE_PRIM36.ram/CLKARDCLK` → `u_pre_IF2/bus_slot0_reg[15]/CE` |
| 18 | dcache | 0.100 | 21.497 | 66.6% | 33 | 249 | `u_Dcache/tagv_way1/U0/inst_blk_mem_gen/gnbram.gnativebmg.native_blk_mem_gen/valid.cstr/ramloop[0].ram.r/prim_init.ram/DEVICE_7SERIES.NO_BMM_INFO.SP.SIMPLE_PRIM36.ram/CLKARDCLK` → `u_pre_IF2/bus_slot0_reg[23]/CE` |
| 19 | dcache | 0.100 | 21.497 | 66.6% | 33 | 17365 | `u_Dcache/tagv_way1/U0/inst_blk_mem_gen/gnbram.gnativebmg.native_blk_mem_gen/valid.cstr/ramloop[0].ram.r/prim_init.ram/DEVICE_7SERIES.NO_BMM_INFO.SP.SIMPLE_PRIM36.ram/CLKARDCLK` → `u_pre_IF2/gen_bus[1].bus_reg[1][22]/CE` |
| 20 | dcache | 0.144 | 14.066 | 65.9% | 18 | 11395 | `u_Dcache/tagv_way1/U0/inst_blk_mem_gen/gnbram.gnativebmg.native_blk_mem_gen/valid.cstr/ramloop[0].ram.r/prim_init.ram/DEVICE_7SERIES.NO_BMM_INFO.SP.WIDE_PRIM18.ram/CLKARDCLK` → `u_decode/bus[101]_i_1__0_psdsp_1/D` |
| 21 | ? | 0.144 | 14.066 | 65.0% | 18 | 164 | `DEVICE_7SERIES.NO_BMM_INFO.SP.WIDE_PRIM18.ram/CLKARDCLK` → `bus[101]_i_1__0_psdsp_1/D` |
| 22 | ? | 0.189 | 14.014 | 65.0% | 18 | 164 | `DEVICE_7SERIES.NO_BMM_INFO.SP.WIDE_PRIM18.ram/CLKARDCLK` → `bus[101]_i_1__0_psdsp/D` |
| 23 | dcache | 0.189 | 14.014 | 65.8% | 18 | 11395 | `u_Dcache/tagv_way1/U0/inst_blk_mem_gen/gnbram.gnativebmg.native_blk_mem_gen/valid.cstr/ramloop[0].ram.r/prim_init.ram/DEVICE_7SERIES.NO_BMM_INFO.SP.WIDE_PRIM18.ram/CLKARDCLK` → `u_decode/bus[101]_i_1__0_psdsp/D` |
| 24 | dcache | 0.214 | 21.370 | 66.4% | 33 | 17365 | `u_Dcache/tagv_way1/U0/inst_blk_mem_gen/gnbram.gnativebmg.native_blk_mem_gen/valid.cstr/ramloop[0].ram.r/prim_init.ram/DEVICE_7SERIES.NO_BMM_INFO.SP.SIMPLE_PRIM36.ram/CLKARDCLK` → `u_pre_IF1/pc_reg[24]/CE` |
| 25 | dcache | 0.214 | 21.370 | 66.4% | 33 | 17365 | `u_Dcache/tagv_way1/U0/inst_blk_mem_gen/gnbram.gnativebmg.native_blk_mem_gen/valid.cstr/ramloop[0].ram.r/prim_init.ram/DEVICE_7SERIES.NO_BMM_INFO.SP.SIMPLE_PRIM36.ram/CLKARDCLK` → `u_pre_IF2/gen_bus[1].bus_reg[1][105]/CE` |
| 26 | dcache | 0.217 | 21.366 | 66.4% | 33 | 17365 | `u_Dcache/tagv_way1/U0/inst_blk_mem_gen/gnbram.gnativebmg.native_blk_mem_gen/valid.cstr/ramloop[0].ram.r/prim_init.ram/DEVICE_7SERIES.NO_BMM_INFO.SP.SIMPLE_PRIM36.ram/CLKARDCLK` → `u_pre_IF1/pc_reg[5]/CE` |
| 27 | dcache | 0.223 | 21.395 | 66.4% | 33 | 17365 | `u_Dcache/tagv_way1/U0/inst_blk_mem_gen/gnbram.gnativebmg.native_blk_mem_gen/valid.cstr/ramloop[0].ram.r/prim_init.ram/DEVICE_7SERIES.NO_BMM_INFO.SP.SIMPLE_PRIM36.ram/CLKARDCLK` → `u_pre_IF2/gen_bus[1].bus_reg[1][54]/CE` |
| 28 | dcache | 0.223 | 21.395 | 66.4% | 33 | 17365 | `u_Dcache/tagv_way1/U0/inst_blk_mem_gen/gnbram.gnativebmg.native_blk_mem_gen/valid.cstr/ramloop[0].ram.r/prim_init.ram/DEVICE_7SERIES.NO_BMM_INFO.SP.SIMPLE_PRIM36.ram/CLKARDCLK` → `u_pre_IF2/gen_bus[1].bus_reg[1][57]/CE` |
| 29 | ? | 0.228 | 9.553 | 86.7% | 7 | 3584 | `ddr3.u_axi_wrap_ddr/u_Axi_CDC/wFifo/pushCC_pushPtrGray_reg[2]/C` → `u_jtag_axi_wrap/u_jtag_axi/inst/axi_bridge_u/write_axi_full_u/last_count_reg[6]/CE` |
| 30 | ? | 0.228 | 9.553 | 86.7% | 7 | 3584 | `ddr3.u_axi_wrap_ddr/u_Axi_CDC/wFifo/pushCC_pushPtrGray_reg[2]/C` → `u_jtag_axi_wrap/u_jtag_axi/inst/axi_bridge_u/write_axi_full_u/last_count_reg[7]/CE` |
| 31 | ? | 0.228 | 9.553 | 86.0% | 7 | 15 | `pushCC_pushPtrGray_reg[2]/C` → `last_count_reg[6]/CE` |
| 32 | ? | 0.228 | 9.553 | 86.0% | 7 | 15 | `pushCC_pushPtrGray_reg[2]/C` → `last_count_reg[7]/CE` |
| 33 | dcache | 0.235 | 21.355 | 66.3% | 33 | 17365 | `u_Dcache/tagv_way1/U0/inst_blk_mem_gen/gnbram.gnativebmg.native_blk_mem_gen/valid.cstr/ramloop[0].ram.r/prim_init.ram/DEVICE_7SERIES.NO_BMM_INFO.SP.SIMPLE_PRIM36.ram/CLKARDCLK` → `u_pre_IF2/bus_slot0_reg[20]/CE` |
| 34 | dcache | 0.235 | 21.355 | 66.3% | 33 | 17365 | `u_Dcache/tagv_way1/U0/inst_blk_mem_gen/gnbram.gnativebmg.native_blk_mem_gen/valid.cstr/ramloop[0].ram.r/prim_init.ram/DEVICE_7SERIES.NO_BMM_INFO.SP.SIMPLE_PRIM36.ram/CLKARDCLK` → `u_pre_IF2/gen_bus[1].bus_reg[1][14]/CE` |
| 35 | dcache | 0.235 | 21.355 | 66.3% | 33 | 17365 | `u_Dcache/tagv_way1/U0/inst_blk_mem_gen/gnbram.gnativebmg.native_blk_mem_gen/valid.cstr/ramloop[0].ram.r/prim_init.ram/DEVICE_7SERIES.NO_BMM_INFO.SP.SIMPLE_PRIM36.ram/CLKARDCLK` → `u_pre_IF2/gen_bus[1].bus_reg[1][18]/CE` |
| 36 | dcache | 0.235 | 21.355 | 66.3% | 33 | 17365 | `u_Dcache/tagv_way1/U0/inst_blk_mem_gen/gnbram.gnativebmg.native_blk_mem_gen/valid.cstr/ramloop[0].ram.r/prim_init.ram/DEVICE_7SERIES.NO_BMM_INFO.SP.SIMPLE_PRIM36.ram/CLKARDCLK` → `u_pre_IF2/gen_bus[1].bus_reg[1][30]/CE` |
| 37 | dcache | 0.236 | 21.385 | 66.4% | 33 | 17365 | `u_Dcache/tagv_way1/U0/inst_blk_mem_gen/gnbram.gnativebmg.native_blk_mem_gen/valid.cstr/ramloop[0].ram.r/prim_init.ram/DEVICE_7SERIES.NO_BMM_INFO.SP.SIMPLE_PRIM36.ram/CLKARDCLK` → `u_pre_IF2/bus_slot0_reg[105]/CE` |
| 38 | dcache | 0.236 | 21.385 | 66.4% | 33 | 17365 | `u_Dcache/tagv_way1/U0/inst_blk_mem_gen/gnbram.gnativebmg.native_blk_mem_gen/valid.cstr/ramloop[0].ram.r/prim_init.ram/DEVICE_7SERIES.NO_BMM_INFO.SP.SIMPLE_PRIM36.ram/CLKARDCLK` → `u_pre_IF2/bus_slot0_reg[10]/CE` |
| 39 | dcache | 0.236 | 21.385 | 66.4% | 33 | 17365 | `u_Dcache/tagv_way1/U0/inst_blk_mem_gen/gnbram.gnativebmg.native_blk_mem_gen/valid.cstr/ramloop[0].ram.r/prim_init.ram/DEVICE_7SERIES.NO_BMM_INFO.SP.SIMPLE_PRIM36.ram/CLKARDCLK` → `u_pre_IF2/bus_slot0_reg[65]/CE` |
| 40 | dcache | 0.236 | 21.385 | 66.4% | 33 | 17365 | `u_Dcache/tagv_way1/U0/inst_blk_mem_gen/gnbram.gnativebmg.native_blk_mem_gen/valid.cstr/ramloop[0].ram.r/prim_init.ram/DEVICE_7SERIES.NO_BMM_INFO.SP.SIMPLE_PRIM36.ram/CLKARDCLK` → `u_pre_IF2/gen_bus[1].bus_reg[1][13]/CE` |

## 高扇出网络

| 扇出 | 网络 |
| ---: | --- |
| 17365 | `u_Dcache/tagv_way1/U0/inst_blk_mem_gen/gnbram.gnativebmg.native_blk_mem_gen/valid.cstr/ramloop[0].ram.r/prim_init.ram/clka` |
| 17365 | `u_csr_regfile/cpu_clk` |
| 17365 | `u_pre_IF1/cpu_clk` |
| 7005 | `ddr3.u_axi_wrap_ddr/mig_axi/u_mig_axi_32_mig/u_memc_ui_top_axi/u_ui_top/ui_cmd0/CLK` |
| 7005 | `ddr3.u_axi_wrap_ddr/mig_axi/u_mig_axi_32_mig/u_memc_ui_top_axi/CLK` |
| 7005 | `ddr3.u_axi_wrap_ddr/u_Axi_CDC/wFifo/ui_clk` |
| 7005 | `ddr3.u_axi_wrap_ddr/u_Axi_CDC/arFifo/ui_clk` |
| 7005 | `ddr3.u_axi_wrap_ddr/mig_axi/u_mig_axi_32_mig/u_memc_ui_top_axi/u_axi_mc/USE_UPSIZER.upsizer_d2/USE_WRITE.write_data_inst/CLK` |
| 7005 | `ddr3.u_axi_wrap_ddr/mig_axi/u_mig_axi_32_mig/u_memc_ui_top_axi/u_axi_mc/axi_mc_b_channel_0/bid_fifo_0/CLK` |
| 7005 | `ddr3.u_axi_wrap_ddr/mig_axi/u_mig_axi_32_mig/u_memc_ui_top_axi/u_ui_top/ui_wr_data0/CLK` |
| 7005 | `ddr3.u_axi_wrap_ddr/u_Axi_CDC/rFifo/popToPushGray_buffercc/ui_clk` |
| 7005 | `ddr3.u_axi_wrap_ddr/mig_axi/u_mig_axi_32_mig/u_memc_ui_top_axi/u_axi_mc/axi_mc_aw_channel_0/aw_cmd_fsm_0/CLK` |
| 7005 | `ddr3.u_axi_wrap_ddr/mig_axi/u_mig_axi_32_mig/u_memc_ui_top_axi/mem_intfc0/ddr_phy_top0/u_ddr_calib_top/dqsfind_calib_left.u_ddr_phy_dqs_found_cal_hr/CLK` |
| 7005 | `ddr3.u_axi_wrap_ddr/mig_axi/u_mig_axi_32_mig/u_memc_ui_top_axi/u_axi_mc/axi_mc_w_channel_0/CLK` |
| 7005 | `ddr3.u_axi_wrap_ddr/mig_axi/u_mig_axi_32_mig/u_memc_ui_top_axi/u_axi_mc/USE_UPSIZER.upsizer_d2/si_register_slice_inst/aw_pipe/CLK` |

## 判断标准

- Slack < 0：违例，必须处理；
- 布线占比 ≥ 70%：先查长线/扇出/跨模块，再考虑拆级；
- 逻辑占比 ≥ 50% 或 Levels ≥ 20：组合深度问题，考虑拆级/提前译码；
- 扇出 ≥ 50：复制寄存器或把全局控制改局部。
