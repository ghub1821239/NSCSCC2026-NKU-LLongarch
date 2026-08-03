# 流水级时序汇总

按每一级最差 Slack 从小到大排列。Slack 越小，越需要优先处理。

| 优先级 | 流水级 | 最差 Slack (ns) | 数据延迟 (ns) | 逻辑/布线 (ns) | 布线占比 | Levels | 判断 |
| ---: | --- | ---: | ---: | ---: | ---: | ---: | --- |
| 1 | WB | 0.879 | 14.544 | 4.049/10.495 | 72.2% | 21 | 裕量偏小、布线主导、逻辑级数较深 |
| 2 | ID | 1.152 | 14.358 | 3.200/11.158 | 77.7% | 18 | 布线主导 |
| 3 | EXE1 | 1.424 | 14.303 | 3.761/10.542 | 73.7% | 20 | 布线主导、逻辑级数较深 |
| 4 | preIF1 | 2.437 | 13.124 | 2.266/10.858 | 82.7% | 11 | 布线主导 |
| 5 | MEM | 4.436 | 11.000 | 3.489/7.511 | 68.3% | 16 | 裕量充足 |
| 6 | EXE2 | 4.834 | 10.849 | 7.042/3.807 | 35.1% | 16 | 逻辑主导 |
| 7 | preIF2 | 6.857 | 8.821 | 1.543/7.278 | 82.5% | 8 | 布线主导 |
| 8 | IF | 10.183 | 5.098 | 0.799/4.299 | 84.3% | 4 | 布线主导 |

## 各级最差路径

### preIF1

- Slack：`2.437 ns`，数据路径：`13.124 ns`。
- 逻辑：`2.266 ns`，布线：`10.858 ns`（`82.7%`）。
- 逻辑级数：`11`（CARRY4=1 LUT3=1 LUT4=1 LUT5=3 LUT6=5）。
- 判断：布线主导。
- 起点：`u_pre_IF1/pc_reg[16]/C`
- 终点：`u_pre_IF2/bus_reg[111]/D`

### preIF2

- Slack：`6.857 ns`，数据路径：`8.821 ns`。
- 逻辑：`1.543 ns`，布线：`7.278 ns`（`82.5%`）。
- 逻辑级数：`8`（LUT3=1 LUT5=1 LUT6=2 MUXF7=2 MUXF8=2）。
- 判断：布线主导。
- 起点：`u_pre_IF2/bus_reg[110]/C`
- 终点：`u_Icache/dirty_way1_r_reg/D`

### IF

- Slack：`10.183 ns`，数据路径：`5.098 ns`。
- 逻辑：`0.799 ns`，布线：`4.299 ns`（`84.3%`）。
- 逻辑级数：`4`（LUT5=1 LUT6=3）。
- 判断：布线主导。
- 起点：`u_fetch/inst_reg_valid_reg/C`
- 终点：`u_pre_IF2/bus_reg[91]/CE`

### ID

- Slack：`1.152 ns`，数据路径：`14.358 ns`。
- 逻辑：`3.200 ns`，布线：`11.158 ns`（`77.7%`）。
- 逻辑级数：`18`（CARRY4=2 LUT2=1 LUT3=2 LUT4=2 LUT5=2 LUT6=7 MUXF7=1 MUXF8=1）。
- 判断：布线主导。
- 起点：`u_decode/bus_reg[104]/C`
- 终点：`u_btb/update_target_r_reg[15]/CE`

### EXE1

- Slack：`1.424 ns`，数据路径：`14.303 ns`。
- 逻辑：`3.761 ns`，布线：`10.542 ns`（`73.7%`）。
- 逻辑级数：`20`（CARRY4=8 LUT3=1 LUT4=2 LUT5=4 LUT6=5）。
- 判断：布线主导、逻辑级数较深。
- 起点：`u_exe1/bus_reg[155]/C`
- 终点：`u_exe2/bus_reg[7]/D`

### EXE2

- Slack：`4.834 ns`，数据路径：`10.849 ns`。
- 逻辑：`7.042 ns`，布线：`3.807 ns`（`35.1%`）。
- 逻辑级数：`16`（CARRY4=10 DSP48E1=2 LUT2=1 LUT5=2 LUT6=1）。
- 判断：逻辑主导。
- 起点：`u_exe2/bus[105]_i_1__0_psdsp_1/C`
- 终点：`u_exe2/bus_reg[194]/D`

### MEM

- Slack：`4.436 ns`，数据路径：`11.000 ns`。
- 逻辑：`3.489 ns`，布线：`7.511 ns`（`68.3%`）。
- 逻辑级数：`16`（CARRY4=6 LUT2=3 LUT3=1 LUT5=1 LUT6=5）。
- 判断：裕量充足。
- 起点：`u_mem/bus_reg[126]/C`
- 终点：`u_btb/update_target_r_reg[15]/CE`

### WB

- Slack：`0.879 ns`，数据路径：`14.544 ns`。
- 逻辑：`4.049 ns`，布线：`10.495 ns`（`72.2%`）。
- 逻辑级数：`21`（CARRY4=6 LUT2=3 LUT3=1 LUT4=1 LUT5=2 LUT6=8）。
- 判断：裕量偏小、布线主导、逻辑级数较深。
- 起点：`u_wb/bus_reg[23]/C`
- 终点：`u_btb/update_target_r_reg[15]/CE`

## 全局最差 20 条唯一路径

| 排名 | 流水级 | Slack (ns) | Delay (ns) | Levels | Route | Source | Destination |
| ---: | --- | ---: | ---: | ---: | ---: | --- | --- |
| 1 | WB | 0.879 | 14.544 | 21 | 72.2% | `u_wb/bus_reg[23]/C` | `u_btb/update_target_r_reg[15]/CE` |
| 2 | ID | 1.152 | 14.358 | 18 | 77.7% | `u_decode/bus_reg[104]/C` | `u_btb/update_target_r_reg[15]/CE` |
| 3 | EXE1 | 1.424 | 14.303 | 20 | 73.7% | `u_exe1/bus_reg[155]/C` | `u_exe2/bus_reg[7]/D` |
| 4 | preIF1 | 2.437 | 13.124 | 11 | 82.7% | `u_pre_IF1/pc_reg[16]/C` | `u_pre_IF2/bus_reg[111]/D` |
| 5 | preIF1 | 2.500 | 13.060 | 11 | 82.9% | `u_pre_IF1/pc_reg[15]/C` | `u_pre_IF2/bus_reg[111]/D` |
| 6 | MEM | 4.436 | 11.000 | 16 | 68.3% | `u_mem/bus_reg[126]/C` | `u_btb/update_target_r_reg[15]/CE` |
| 7 | EXE2 | 4.834 | 10.849 | 16 | 35.1% | `u_exe2/bus[105]_i_1__0_psdsp_1/C` | `u_exe2/bus_reg[194]/D` |
| 8 | preIF2 | 6.857 | 8.821 | 8 | 82.5% | `u_pre_IF2/bus_reg[110]/C` | `u_Icache/dirty_way1_r_reg/D` |
| 9 | preIF2 | 6.871 | 8.807 | 8 | 82.5% | `u_pre_IF2/bus_reg[110]/C` | `u_Icache/dirty_way1_r_reg/D` |
| 10 | preIF2 | 6.964 | 8.714 | 8 | 81.9% | `u_pre_IF2/bus_reg[110]/C` | `u_Icache/dirty_way1_r_reg/D` |
| 11 | preIF2 | 7.049 | 8.630 | 7 | 80.2% | `u_pre_IF2/bus_reg[110]/C` | `u_Icache/dirty_way1_r_reg/D` |
| 12 | preIF2 | 7.062 | 8.616 | 7 | 80.5% | `u_pre_IF2/bus_reg[110]/C` | `u_Icache/dirty_way1_r_reg/D` |
| 13 | preIF2 | 7.063 | 8.615 | 8 | 82.1% | `u_pre_IF2/bus_reg[110]/C` | `u_Icache/dirty_way1_r_reg/D` |
| 14 | preIF2 | 7.077 | 8.601 | 8 | 82.1% | `u_pre_IF2/bus_reg[110]/C` | `u_Icache/dirty_way1_r_reg/D` |
| 15 | preIF2 | 7.094 | 8.628 | 8 | 82.1% | `u_pre_IF2/bus_reg[110]/C` | `u_Icache/dirty_way0_r_reg/D` |
| 16 | IF | 10.183 | 5.098 | 4 | 84.3% | `u_fetch/inst_reg_valid_reg/C` | `u_pre_IF2/bus_reg[91]/CE` |
| 17 | IF | 10.311 | 5.008 | 4 | 84.0% | `u_fetch/inst_reg_valid_reg/C` | `u_pre_IF2/bus_reg[92]/CE` |
| 18 | IF | 10.403 | 4.885 | 4 | 83.6% | `u_fetch/inst_reg_valid_reg/C` | `u_pre_IF2/bus_reg[94]/CE` |
| 19 | IF | 10.441 | 4.877 | 4 | 83.6% | `u_fetch/inst_reg_valid_reg/C` | `u_pre_IF2/bus_reg[93]/CE` |
| 20 | IF | 10.450 | 4.830 | 3 | 85.6% | `u_fetch/inst_reg_valid_reg/C` | `u_pre_IF2/bus_reg[91]/CE` |
