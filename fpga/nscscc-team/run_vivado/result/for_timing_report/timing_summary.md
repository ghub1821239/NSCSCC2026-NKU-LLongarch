# 流水级时序汇总

按每一级最差 Slack 从小到大排列。Slack 越小，越需要优先处理。

| 优先级 | 流水级 | 最差 Slack (ns) | 数据延迟 (ns) | 逻辑/布线 (ns) | 布线占比 | Levels | 判断 |
| ---: | --- | ---: | ---: | ---: | ---: | ---: | --- |
| 1 | EXE1 | 1.122 | 13.264 | 3.603/9.661 | 72.8% | 17 | 布线主导 |
| 2 | WB | 1.356 | 13.003 | 2.670/10.333 | 79.5% | 16 | 布线主导 |
| 3 | ID | 1.406 | 13.064 | 2.933/10.131 | 77.5% | 17 | 布线主导 |
| 4 | preIF1 | 1.922 | 12.446 | 2.286/10.160 | 81.6% | 11 | 布线主导 |
| 5 | MEM | 2.202 | 12.203 | 2.285/9.918 | 81.3% | 14 | 布线主导 |
| 6 | EXE2 | 3.443 | 10.915 | 7.209/3.706 | 34.0% | 18 | 逻辑主导 |
| 7 | preIF2 | 6.144 | 8.263 | 1.530/6.733 | 81.5% | 8 | 布线主导 |
| 8 | IF | 8.704 | 5.214 | 0.872/4.342 | 83.3% | 4 | 布线主导 |

## 各级最差路径

### preIF1

- Slack：`1.922 ns`，数据路径：`12.446 ns`。
- 逻辑：`2.286 ns`，布线：`10.160 ns`（`81.6%`）。
- 逻辑级数：`11`（CARRY4=1 LUT2=3 LUT5=2 LUT6=5）。
- 判断：布线主导。
- 起点：`u_pre_IF1/pc_reg[27]/C`
- 终点：`u_pre_IF2/bus_reg[111]/D`

### preIF2

- Slack：`6.144 ns`，数据路径：`8.263 ns`。
- 逻辑：`1.530 ns`，布线：`6.733 ns`（`81.5%`）。
- 逻辑级数：`8`（LUT3=1 LUT5=1 LUT6=2 MUXF7=2 MUXF8=2）。
- 判断：布线主导。
- 起点：`u_pre_IF2/bus_reg[110]/C`
- 终点：`u_Icache/dirty_way0_r_reg/D`

### IF

- Slack：`8.704 ns`，数据路径：`5.214 ns`。
- 逻辑：`0.872 ns`，布线：`4.342 ns`（`83.3%`）。
- 逻辑级数：`4`（LUT5=1 LUT6=3）。
- 判断：布线主导。
- 起点：`u_fetch/inst_reg_valid_reg/C`
- 终点：`u_pre_IF2/bus_reg[104]/CE`

### ID

- Slack：`1.406 ns`，数据路径：`13.064 ns`。
- 逻辑：`2.933 ns`，布线：`10.131 ns`（`77.5%`）。
- 逻辑级数：`17`（CARRY4=1 LUT2=1 LUT3=1 LUT4=4 LUT5=4 LUT6=6）。
- 判断：布线主导。
- 起点：`u_decode/bus_reg[98]/C`
- 终点：`br_afterpred_target_r_reg[6]/D`

### EXE1

- Slack：`1.122 ns`，数据路径：`13.264 ns`。
- 逻辑：`3.603 ns`，布线：`9.661 ns`（`72.8%`）。
- 逻辑级数：`17`（CARRY4=5 LUT3=1 LUT4=2 LUT5=3 LUT6=6）。
- 判断：布线主导。
- 起点：`u_exe1/bus_reg[155]/C`
- 终点：`u_exe2/bus_reg[8]/D`

### EXE2

- Slack：`3.443 ns`，数据路径：`10.915 ns`。
- 逻辑：`7.209 ns`，布线：`3.706 ns`（`34.0%`）。
- 逻辑级数：`18`（CARRY4=12 DSP48E1=2 LUT2=1 LUT5=2 LUT6=1）。
- 判断：逻辑主导。
- 起点：`u_exe2/bus[92]_i_1__2_psdsp_1/C`
- 终点：`u_exe2/bus_reg[197]/D`

### MEM

- Slack：`2.202 ns`，数据路径：`12.203 ns`。
- 逻辑：`2.285 ns`，布线：`9.918 ns`（`81.3%`）。
- 逻辑级数：`14`（LUT3=3 LUT4=2 LUT5=1 LUT6=4 MUXF7=2 MUXF8=2）。
- 判断：布线主导。
- 起点：`u_mem/bus_reg[4]/C`
- 终点：`u_Icache/dirty_way0_r_reg/D`

### WB

- Slack：`1.356 ns`，数据路径：`13.003 ns`。
- 逻辑：`2.670 ns`，布线：`10.333 ns`（`79.5%`）。
- 逻辑级数：`16`（CARRY4=3 LUT2=2 LUT3=2 LUT4=1 LUT5=3 LUT6=5）。
- 判断：布线主导。
- 起点：`u_wb/bus_reg[5]/C`
- 终点：`br_afterpred_target_r_reg[6]/D`

## 全局最差 20 条唯一路径

| 排名 | 流水级 | Slack (ns) | Delay (ns) | Levels | Route | Source | Destination |
| ---: | --- | ---: | ---: | ---: | ---: | --- | --- |
| 1 | EXE1 | 1.122 | 13.264 | 17 | 72.8% | `u_exe1/bus_reg[155]/C` | `u_exe2/bus_reg[8]/D` |
| 2 | WB | 1.356 | 13.003 | 16 | 79.5% | `u_wb/bus_reg[5]/C` | `br_afterpred_target_r_reg[6]/D` |
| 3 | ID | 1.406 | 13.064 | 17 | 77.5% | `u_decode/bus_reg[98]/C` | `br_afterpred_target_r_reg[6]/D` |
| 4 | preIF1 | 1.922 | 12.446 | 11 | 81.6% | `u_pre_IF1/pc_reg[27]/C` | `u_pre_IF2/bus_reg[111]/D` |
| 5 | preIF1 | 2.030 | 12.338 | 11 | 81.9% | `u_pre_IF1/pc_reg[26]/C` | `u_pre_IF2/bus_reg[111]/D` |
| 6 | MEM | 2.202 | 12.203 | 14 | 81.3% | `u_mem/bus_reg[4]/C` | `u_Icache/dirty_way0_r_reg/D` |
| 7 | MEM | 2.263 | 12.142 | 14 | 80.9% | `u_mem/bus_reg[4]/C` | `u_Icache/dirty_way0_r_reg/D` |
| 8 | MEM | 2.264 | 12.140 | 14 | 81.2% | `u_mem/bus_reg[6]/C` | `u_Icache/dirty_way0_r_reg/D` |
| 9 | MEM | 2.266 | 12.139 | 14 | 81.0% | `u_mem/bus_reg[4]/C` | `u_Icache/dirty_way0_r_reg/D` |
| 10 | MEM | 2.309 | 12.096 | 13 | 80.1% | `u_mem/bus_reg[4]/C` | `u_Icache/dirty_way0_r_reg/D` |
| 11 | MEM | 2.324 | 12.080 | 14 | 80.8% | `u_mem/bus_reg[6]/C` | `u_Icache/dirty_way0_r_reg/D` |
| 12 | MEM | 2.327 | 12.077 | 14 | 80.9% | `u_mem/bus_reg[6]/C` | `u_Icache/dirty_way0_r_reg/D` |
| 13 | MEM | 2.370 | 12.034 | 13 | 80.0% | `u_mem/bus_reg[6]/C` | `u_Icache/dirty_way0_r_reg/D` |
| 14 | EXE2 | 3.443 | 10.915 | 18 | 34.0% | `u_exe2/bus[92]_i_1__2_psdsp_1/C` | `u_exe2/bus_reg[197]/D` |
| 15 | preIF2 | 6.144 | 8.263 | 8 | 81.5% | `u_pre_IF2/bus_reg[110]/C` | `u_Icache/dirty_way0_r_reg/D` |
| 16 | preIF2 | 6.210 | 8.196 | 8 | 80.9% | `u_pre_IF2/bus_reg[110]/C` | `u_Icache/dirty_way0_r_reg/D` |
| 17 | preIF2 | 6.213 | 8.193 | 8 | 81.0% | `u_pre_IF2/bus_reg[110]/C` | `u_Icache/dirty_way0_r_reg/D` |
| 18 | preIF2 | 6.345 | 8.062 | 8 | 81.1% | `u_pre_IF2/bus_reg[110]/C` | `u_Icache/dirty_way0_r_reg/D` |
| 19 | preIF2 | 6.399 | 8.008 | 8 | 80.8% | `u_pre_IF2/bus_reg[110]/C` | `u_Icache/dirty_way0_r_reg/D` |
| 20 | preIF2 | 6.403 | 8.004 | 8 | 80.9% | `u_pre_IF2/bus_reg[110]/C` | `u_Icache/dirty_way0_r_reg/D` |
