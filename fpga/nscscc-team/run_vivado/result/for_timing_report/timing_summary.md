# 流水级时序汇总

按每一级最差 Slack 从小到大排列。Slack 越小，越需要优先处理。

| 优先级 | 流水级 | 最差 Slack (ns) | 数据延迟 (ns) | 逻辑/布线 (ns) | 布线占比 | Levels | 判断 |
| ---: | --- | ---: | ---: | ---: | ---: | ---: | --- |
| 1 | EXE1 | 0.148 | 15.326 | 3.872/11.454 | 74.7% | 26 | 裕量极小、布线主导、逻辑级数较深 |
| 2 | ID | 0.782 | 14.414 | 3.610/10.804 | 75.0% | 22 | 裕量偏小、布线主导、逻辑级数较深 |
| 3 | WB | 0.794 | 14.335 | 3.038/11.297 | 78.8% | 19 | 裕量偏小、布线主导 |
| 4 | preIF1 | 2.184 | 13.500 | 2.469/11.031 | 81.7% | 12 | 布线主导 |
| 5 | EXE2 | 4.660 | 10.515 | 2.437/8.078 | 76.8% | 13 | 布线主导 |
| 6 | MEM | 4.692 | 10.792 | 2.243/8.549 | 79.2% | 13 | 布线主导 |
| 7 | preIF2 | 8.833 | 6.864 | 1.391/5.473 | 79.7% | 6 | 布线主导 |
| 8 | IF | 11.322 | 4.168 | 0.904/3.264 | 78.3% | 5 | 布线主导 |

## 各级最差路径

### preIF1

- Slack：`2.184 ns`，数据路径：`13.500 ns`。
- 逻辑：`2.469 ns`，布线：`11.031 ns`（`81.7%`）。
- 逻辑级数：`12`（CARRY4=1 LUT3=2 LUT4=2 LUT5=2 LUT6=5）。
- 判断：布线主导。
- 起点：`u_pre_IF1/pc_reg[13]/C`
- 终点：`u_pre_IF2/bus_reg[111]/D`

### preIF2

- Slack：`8.833 ns`，数据路径：`6.864 ns`。
- 逻辑：`1.391 ns`，布线：`5.473 ns`（`79.7%`）。
- 逻辑级数：`6`（LUT3=1 LUT5=1 LUT6=1 MUXF7=1 MUXF8=2）。
- 判断：布线主导。
- 起点：`u_pre_IF2/bus_reg[122]/C`
- 终点：`u_Icache/dirty_way1_r_reg/D`

### IF

- Slack：`11.322 ns`，数据路径：`4.168 ns`。
- 逻辑：`0.904 ns`，布线：`3.264 ns`（`78.3%`）。
- 逻辑级数：`5`（LUT3=1 LUT5=2 LUT6=2）。
- 判断：布线主导。
- 起点：`u_fetch/inst_reg_valid_reg/C`
- 终点：`u_Icache/dirty_way0_r_reg/CE`

### ID

- Slack：`0.782 ns`，数据路径：`14.414 ns`。
- 逻辑：`3.610 ns`，布线：`10.804 ns`（`75.0%`）。
- 逻辑级数：`22`（CARRY4=3 LUT2=2 LUT3=2 LUT4=2 LUT5=6 LUT6=7）。
- 判断：裕量偏小、布线主导、逻辑级数较深。
- 起点：`u_decode/bus_reg[100]/C`
- 终点：`u_btb/btb_tag_reg_0_63_18_20/RAMA/WE`

### EXE1

- Slack：`0.148 ns`，数据路径：`15.326 ns`。
- 逻辑：`3.872 ns`，布线：`11.454 ns`（`74.7%`）。
- 逻辑级数：`26`（CARRY4=9 LUT3=1 LUT4=3 LUT5=6 LUT6=7）。
- 判断：裕量极小、布线主导、逻辑级数较深。
- 起点：`u_exe1/bus_reg[156]/C`
- 终点：`u_Icache/dirty_way0_r_reg/CE`

### EXE2

- Slack：`4.660 ns`，数据路径：`10.515 ns`。
- 逻辑：`2.437 ns`，布线：`8.078 ns`（`76.8%`）。
- 逻辑级数：`13`（CARRY4=3 LUT2=2 LUT3=1 LUT4=1 LUT5=1 LUT6=5）。
- 判断：布线主导。
- 起点：`u_exe2/bus_reg[104]/C`
- 终点：`u_btb/btb_tag_reg_0_63_18_20/RAMA/WE`

### MEM

- Slack：`4.692 ns`，数据路径：`10.792 ns`。
- 逻辑：`2.243 ns`，布线：`8.549 ns`（`79.2%`）。
- 逻辑级数：`13`（LUT2=1 LUT3=2 LUT4=1 LUT5=5 LUT6=4）。
- 判断：布线主导。
- 起点：`u_mem/bus_reg[80]/C`
- 终点：`u_Icache/dirty_way0_r_reg/CE`

### WB

- Slack：`0.794 ns`，数据路径：`14.335 ns`。
- 逻辑：`3.038 ns`，布线：`11.297 ns`（`78.8%`）。
- 逻辑级数：`19`（CARRY4=1 LUT2=3 LUT3=1 LUT4=3 LUT5=3 LUT6=8）。
- 判断：裕量偏小、布线主导。
- 起点：`u_wb/bus_reg[5]/C`
- 终点：`u_btb/btb_tag_reg_0_63_18_20/RAMA/WE`

## 全局最差 20 条唯一路径

| 排名 | 流水级 | Slack (ns) | Delay (ns) | Levels | Route | Source | Destination |
| ---: | --- | ---: | ---: | ---: | ---: | --- | --- |
| 1 | EXE1 | 0.148 | 15.326 | 26 | 74.7% | `u_exe1/bus_reg[156]/C` | `u_Icache/dirty_way0_r_reg/CE` |
| 2 | ID | 0.782 | 14.414 | 22 | 75.0% | `u_decode/bus_reg[100]/C` | `u_btb/btb_tag_reg_0_63_18_20/RAMA/WE` |
| 3 | WB | 0.794 | 14.335 | 19 | 78.8% | `u_wb/bus_reg[5]/C` | `u_btb/btb_tag_reg_0_63_18_20/RAMA/WE` |
| 4 | WB | 0.794 | 14.335 | 19 | 78.8% | `u_wb/bus_reg[5]/C` | `u_btb/btb_tag_reg_0_63_18_20/RAMB/WE` |
| 5 | WB | 0.794 | 14.335 | 19 | 78.8% | `u_wb/bus_reg[5]/C` | `u_btb/btb_tag_reg_0_63_18_20/RAMC/WE` |
| 6 | WB | 0.794 | 14.335 | 19 | 78.8% | `u_wb/bus_reg[5]/C` | `u_btb/btb_tag_reg_0_63_18_20/RAMD/WE` |
| 7 | WB | 0.803 | 14.326 | 19 | 78.7% | `u_wb/bus_reg[5]/C` | `u_btb/btb_tag_reg_0_63_18_20/RAMA/WE` |
| 8 | WB | 0.803 | 14.326 | 19 | 78.7% | `u_wb/bus_reg[5]/C` | `u_btb/btb_tag_reg_0_63_18_20/RAMB/WE` |
| 9 | WB | 0.803 | 14.326 | 19 | 78.7% | `u_wb/bus_reg[5]/C` | `u_btb/btb_tag_reg_0_63_18_20/RAMC/WE` |
| 10 | WB | 0.803 | 14.326 | 19 | 78.7% | `u_wb/bus_reg[5]/C` | `u_btb/btb_tag_reg_0_63_18_20/RAMD/WE` |
| 11 | preIF1 | 2.184 | 13.500 | 12 | 81.7% | `u_pre_IF1/pc_reg[13]/C` | `u_pre_IF2/bus_reg[111]/D` |
| 12 | preIF1 | 2.195 | 13.489 | 12 | 81.7% | `u_pre_IF1/pc_reg[13]/C` | `u_pre_IF2/bus_reg[111]/D` |
| 13 | EXE2 | 4.660 | 10.515 | 13 | 76.8% | `u_exe2/bus_reg[104]/C` | `u_btb/btb_tag_reg_0_63_18_20/RAMA/WE` |
| 14 | MEM | 4.692 | 10.792 | 13 | 79.2% | `u_mem/bus_reg[80]/C` | `u_Icache/dirty_way0_r_reg/CE` |
| 15 | MEM | 4.718 | 10.768 | 13 | 80.6% | `u_mem/bus_reg[6]/C` | `u_Icache/dirty_way0_r_reg/CE` |
| 16 | MEM | 4.746 | 10.743 | 13 | 80.0% | `u_mem/bus_reg[4]/C` | `u_Icache/dirty_way0_r_reg/CE` |
| 17 | MEM | 4.767 | 10.685 | 13 | 79.0% | `u_mem/bus_reg[80]/C` | `u_Icache/dirty_way1_r_reg/CE` |
| 18 | MEM | 4.793 | 10.661 | 13 | 80.4% | `u_mem/bus_reg[6]/C` | `u_Icache/dirty_way1_r_reg/CE` |
| 19 | MEM | 4.821 | 10.636 | 13 | 79.8% | `u_mem/bus_reg[4]/C` | `u_Icache/dirty_way1_r_reg/CE` |
| 20 | MEM | 4.821 | 10.631 | 13 | 78.9% | `u_mem/bus_reg[80]/C` | `u_Icache/req_index_r_reg[1]/CE` |
