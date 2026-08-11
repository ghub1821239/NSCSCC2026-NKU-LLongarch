# Linux-pass 八级 CPU 阶段性 Bug 修改包规格

适用工程：

- 工程根目录：`D:\fpga\chiplab-fullinst-0808-1`
- CPU RTL：`D:\fpga\chiplab-fullinst-0808-1\IP\myCPU`
- Vivado 工程：`D:\fpga\chiplab-fullinst-0808-1\fpga\loongson\2023.2\system_run.xpr`
- 冻结系统基线：CPU → U-Boot → Linux → rootfs → BusyBox shell 已实际打通。

本规格只定义后续实施边界、验收条件与提交规划；不包含 RTL patch，不扩大台账范围。

## 修改包总览

| 阶段 | Bug | 等级 | 严重度 | 修改风险 | 流水冲突 | 预计文件 | Linux 门禁 |
|---|---|---|---|---|---|---|---|
| 1                              | NB-03 CACOP 重复提交            | A  | 高 | 中 | 中 | `mycpu_core.v`，必要时 `EXE1.v`                          | 阶段 1 完成后 |
| 1                              | NB-05 RDCNTVL.W r0 INE      | A  | 中 | 低 | 低 | `decode.v`                                           | 阶段 1 完成后 |
| 2                              | NB-02 serial flush 穿透 store | A  | 高 | 中 | 中 | `EXE2.v`、`mycpu_core.v`                              | 阶段 2 完成后 |
| 2                              | NB-01 INVTLB 提前副作用          | A  | 高 | 高 | 高 | `EXE1.v`、`mycpu_core.v`、`tlb.v`；可能扩展 EXE2/MEM/WB bus | 阶段 2 完成后 |
| 3                              | NB-04 Divider ownership     | A2 | 高 | 高 | 高 | `alu.v`、`EXE1.v`；必要时 transaction state               | 阶段 3 完成后 |

NB-01、NB-02、NB-03 共享“squash/cancel 与不可撤销 side effect 边界不统一”的设计主题，但修复点独立，必须保持三个独立 Bug、独立提交、独立回归。

---

# NB-03 I-Cache CACOP cancel 漏掉 EXE1，导致 pc+4 指令重复提交

## 1. 最终裁决

A。

## 2. 严重程度

高。可导致同一顺序指令真实双退休、重复写寄存器和重复架构副作用。

## 3. 动态证据

类型：**full-core**。

已有 testbench：

`C:\Users\user\AppData\Local\Temp\codex-nb03-restart-3243c24f\nb03_tb.sv`

- CACOP PC：`0x1c000024`
- 后继 PC：`0x1c000028`
- 第一次 WB commit：cycle 76，`WB_valid=1`、`WB_pc=1c000028`、`rf_we=f`、`rf_waddr=4`、`rf_wdata=1`
- 第二次 WB commit：cycle 89，`WB_valid=1`、`WB_pc=1c000028`、`rf_we=f`、`rf_waddr=4`、`rf_wdata=2`
- cycle 77～88：`WB_valid=0`
- 前端已明确重取 P+4，且 P+4 随后重新进入 EXE1。
- 最终：`r4=2`、`result=2`。

## 4. 当前错误机制

```
CACOP 进入 EXE2 并等待 cache 完成
→ cacop_need_cancel 清除前端、IF、ID
→ P+4 已在 EXE1，EXE1_need_cancel 未包含 cacop_need_cancel
→ P+4 原副本继续等待、随后进入 EXE2
→ 前端恢复地址又为 P+4，产生重取副本
→ 原副本与重取副本分别退休
```

## 5. 根因

CACOP cancel cone 没有覆盖 EXE1，而恢复 PC 又指向被保留的 `pc+4`。

## 6. Architectural consequence

同一个 PC 的同一顺序指令重复提交；对寄存器、存储、CSR 或 MMIO 都可能产生重复架构副作用。

## 7. Linux-pass 为什么遗漏

启动链不保证覆盖“CACOP 后紧邻非幂等 P+4 指令、且 I-Cache 操作发生等待”的组合。即便 CACOP 被执行，紧邻指令也可能是 NOP、barrier 或结果不可见的操作，无法暴露双提交。

## 8. 推荐修改方向

最小方案：

- 将 CACOP cancel 语义覆盖 EXE1 中已进入的 P+4 副本，例如使 EXE1 接收该 cancel，使原副本被取消后只保留前端重取副本。
- 需确认 CACOP 完成同拍的 EXE1/EXE2 transfer 不会重新产生“双保留”。

结构更完整方案：

- 引入明确的 CACOP resume ownership：在恢复 P+4 前，保证流水线中不存在可继续执行的相同 P+4 副本；可以采用 epoch/tag、恢复屏障或等价的唯一性机制。

取舍：

- 最小方案改动小、易定向验证，但必须覆盖 CACOP 与 DIV、访存、branch 等 EXE1 指令交叉。
- 结构方案更易表达唯一性不变量，但会扩大前端与流水协调面。

推荐：先实施最小方案；若无法对所有 `cacop_done` 边界给出单副本证明，再采用结构方案。

## 9. 允许修改文件

- `D:\fpga\chiplab-fullinst-0808-1\IP\myCPU\mycpu_core.v`
- 必要时：`D:\fpga\chiplab-fullinst-0808-1\IP\myCPU\EXE1.v`

## 10. 禁止夹带修改

- `cache.v` replacement、writeback 或 CACOP 算法清理；
- XCI、Generate Output Products；
- branch predictor、AXI、reset、格式化；
- 任何 NB-01/NB-02/NB-04/NB-05 修复。

## 11. 与八级流水冲突程度

中。

## 12. 修改前已有复现

完整 core 动态复现；两次 WB commit 和最终 `r4/result=2` 已确认。

## 13. 修改后通过条件

- P+4 对目标寄存器最多产生一次 `WB_valid && rf_we` commit。
- `result=1`，而非 2。
- 不允许在同一用例中再次观测 P+4 重入 EXE1 后产生第二次 WB commit。
- CACOP 自身必须正常完成，前端恢复地址必须保持 `pc+4` 语义。

## 14. 最小定向回归

- 现有 NB-03 full-core 用例。
- P+4 为普通 ALU 写回。
- P+4 为 store，检查只出现一次下游写。
- P+4 为 DIV，确认 CACOP cancel 不造成错误 divider 生命周期。
- 现有 I-Cache CACOP 功能测试。

## 15. 相关旧修复回归

- OLD-S-02：CACOP op2 dirty-hit tag/address/line 一致性。
- OLD-F-08：DIV 未完成时 branch hazard。
- 保护已有异常 flush 路径，避免引入 OLD-F-01 类优先级倒置。

## 16. Linux 门禁

需要。阶段 1 的两个独立提交完成并通过定向回归后，必须重跑：

```
U-Boot → Linux → BusyBox shell
```

---

# NB-05 合法 RDCNTVL.W r0 被错误判为 INE

## 1. 最终裁决

A。

## 2. 严重程度

中。属于合法编码被误判异常，破坏 ISA 兼容性与精确异常语义。

## 3. 动态证据

类型：**模块级后端链路**（decode → EXE1 → EXE2 → MEM → WB → regfile）。

已有 testbench：

`C:\Users\user\AppData\Local\Temp\codex-nb05-rdcnt\nb05_tb.sv`

编码 `32'h00006000`：

- `rk=11000`
- `rj=0`
- `rd=0`
- `inst_rdcntvl_w=0`
- `ex_INE=1`

最终：

- `WB_valid=1`
- `wb_ex=1`
- `ECODE=INE`
- `flush=1`
- marker 未按顺序执行，最终 `marker=1`、`result=0`。

## 4. 当前错误机制

```
0x00006000
→ decode 对 RDCNTVL.W 附加 rd != 0
→ 三种 counter decode 都不命中
→ ex_INE=1
→ 经 EXE1/EXE2/MEM 传播
→ WB 提交 INE 并 flush
```

## 5. 根因

decode 把“写 r0 的结果会丢弃”错误提升为“该编码非法”。

## 6. Architectural consequence

合法的 `RDCNTVL.W r0` / `RDTIMEL.W r0,r0` 被中断为 INE，打断本应继续的顺序执行。

## 7. Linux-pass 为什么遗漏

编译器通常不会主动生成“读取计数器后立刻丢弃结果”的编码，因此启动链和常规 Linux workload 很难自然覆盖 `rd=r0` 这个边界。

## 8. 推荐修改方向

最小且推荐方案：

- 仅移除 `inst_rdcntvl_w` 中的 `rd != 0` 限制。

边界要求：

- 仅新增 `rk=11000、rj=0、rd=0` 的现有译码角落。
- 不扩展完整双目标 RDTIME 支持。
- 不改变 RDCNTVH.W、RDCNTID、非零目的寄存器 RDCNTVL.W 的定义。

结构更完整方案：

- 无需在本 Bug 包内实施。不得顺手加入 `rf[0]` 物理写抑制；那属于后续清理阶段议题。

## 9. 允许修改文件

- `D:\fpga\chiplab-fullinst-0808-1\IP\myCPU\decode.v`

## 10. 禁止夹带修改

- `regfile.v` 的 `rf[0]` 物理写抑制；
- 完整双目标 RDTIME；
- RDCNTVH.W、RDCNTID 的语义重构；
- 其他 decode cleanup、格式化或重命名。

## 11. 与八级流水冲突程度

低。

## 12. 修改前已有复现

已有后端模块级动态复现，已观察到 INE 到 WB 的传播和顺序路径中断。

## 13. 修改后通过条件

- `0x00006000`：`inst_rdcntvl_w=1`、`ex_INE=0`。
- 指令正常退休，不产生 `wb_ex/INE/flush`。
- 架构读 r0 始终为 0。
- marker/result 最终均为 2。
- 普通 RDCNTVL.W、RDCNTVH.W、RDCNTID 行为保持。

## 14. 最小定向回归

- 现有 NB-05 用例。
- 既有 `n58_rdcnt.S`。
- 非零 rd 的 RDCNTVL.W。
- RDCNTVH.W。
- RDCNTID。
- 一条普通非法指令仍必须产生 INE。

## 15. 相关旧修复回归

- OLD-F-01：异常优先级与入口选择。
- 仅保护 INE 正常提交路径；不将 OLD-F-01～03 重列为待修问题。

## 16. Linux 门禁

需要，作为阶段 1 结束门禁的一部分。

---

# NB-02 normal serial flush 同拍年轻 store 越过取消边界

## 1. 最终裁决

A。

## 2. 严重程度

高。对 uncache/MMIO store 可造成不可撤销的重复外部写。

## 3. 动态证据

类型：**模块级**（WB + EXE2 + Cache；使用当前 cache RTL）。

已有 testbench：

`C:\Users\user\AppData\Local\Temp\codex-nb02-b9284a27\nb02_tb.sv`

已观察：

- CSRWR 在 WB：`flush=1`
- store 在 EXE2：`EXE2_valid=1`
- 同拍：`data_sram_req=1`、`addr_ok=1`、request accepted
- 旧请求进入 cache 并形成下游 `wr_req & wr_rdy`
- flush 后同 PC store 被重取，再形成第二次下游 write request。

full-core 可达性已确认：

```
CSRWR → 独立 filler → store
```

在 CSRWR\@WB 时，filler\@MEM、store\@EXE2；现有 RAW stall 不会阻止该独立排列。

## 4. 当前错误机制

```
CSR/TLB serial 指令在 WB normal flush
→ EXE2_need_cancel 同拍拉高
→ data_sram_req 未检查 EXE2_need_cancel/flush
→ cache 在时钟沿锁存年轻 store request
→ 流水线随后 squash store，但 cache 无 cancel
→ 旧 request 继续下游写
→ flush 后重取同一 store，再写一次
```

## 5. 根因

EXE2 memory request acceptance qualification 没有覆盖当拍 normal serial flush。

## 6. Architectural consequence

本应被 squash 的年轻 store 穿过不可撤销请求边界；对普通内存可能被同值覆盖掩盖，对 MMIO/uncache 地址可产生双触发。

## 7. Linux-pass 为什么遗漏

需要特定的 CSR/TLB serial、独立 filler、独立 store、cache 可接受窗口和可观察写目标同时对齐。常规启动路径即使包含 CSR 写和存储，也未必形成该周期组合；普通内存同值写还可能掩盖后果。

## 8. 推荐修改方向

最小且推荐方案：

- 在 EXE2 发起不可撤销 memory request 之前，以当拍 `EXE2_need_cancel/flush` 阻止被 squash 的年轻 request。
- 证明 request/fire 与 EXE2 state clear 同拍时，不可能被 cache 接受。

结构更完整方案：

- 建立 serial-inflight fence，使年轻 memory instruction 在 serial 指令完成精确提交/重取边界前不能跨入 request acceptance。
- 仅在前端门控无法满足精确性时，才评估 cache request rollback；不推荐先做 rollback。

取舍：

- 当拍门控改动小、针对性强，但需确认组合路径与全部 request 类型。
- serial fence 更保守，但可能扩大 stall 范围并影响八级吞吐。

## 9. 允许修改文件

- `D:\fpga\chiplab-fullinst-0808-1\IP\myCPU\EXE2.v`
- 必要时：`D:\fpga\chiplab-fullinst-0808-1\IP\myCPU\mycpu_core.v`

只读检查对象，不应先修改：

- `D:\fpga\chiplab-fullinst-0808-1\IP\myCPU\cache.v`
- `D:\fpga\chiplab-fullinst-0808-1\IP\myCPU\bridge_SRAM_AXI.v`

## 10. 禁止夹带修改

- Cache 已接受 request 的回滚重构，除非前端门控被证明不正确；
- AXI error response、MMIO size、bridge 重写；
- cache replacement、write buffer、XCI；
- 其他 serial 指令功能重构。

## 11. 与八级流水冲突程度

中。

## 12. 修改前已有复现

已有 WB+EXE2+Cache 动态复现；已有 full-core 可达性推导。未声称已经完成完整 AXI B-response 动态闭环。

## 13. 修改后通过条件

- CSRWR/CSRXCHG/TLB serial flush 同拍的年轻 store：`request_fire=0`。
- cache 不得锁存旧 store address/data。
- 重取后的 store 恰好产生一次下游 write。
- 不得丢失合法、未被 flush 的 load/store 请求。

## 14. 最小定向回归

- 现有 NB-02 用例。
- 完整 core + cache + bridge + AXI monitor：统计 AW/W/B，旧 store 0 次、重取 store 1 次。
- CSRWR、CSRXCHG、TLB serial 各一例。
- cacheable 与 uncache/MMIO store 各一例。
- 正常 store/load 吞吐回归。

## 15. 相关旧修复回归

- OLD-F-01：异常/serial WB priority。
- OLD-F-02：ERTN commit qualification。
- OLD-F-03：TLB 异常 selected-ecode side effect。
- OLD-S-02：Cache CACOP dirty-hit 行为。

## 16. Linux 门禁

阶段 2 最终门禁必须重跑 Linux；NB-02 单独提交完成后先跑全部定向回归。

---

# NB-01 INVTLB 在 EXE1 提前产生 TLB architectural side effect

## 1. 最终裁决

A。

## 2. 严重程度

高。被 squash 的系统指令改变 TLB architectural state，可影响后续地址翻译、TLBR 路径和异常可见性。

## 3. 动态证据

类型：**模块级**（EXE1 + TLB），并已有 full-core 可达性审计。

已有 testbench：

`C:\Users\user\AppData\Local\Temp\codex-nb01-204ea47d\nb01_tb.sv`

已观察：

- INVTLB 在 EXE1 时 `invtlb_valid=1`；
- 目标 TLB entry 直接 `e:1→0`；
- 随后更老异常到 WB、`flush=1`；
- INVTLB 被 squash，但 TLB entry 不恢复。

full-core 可达排列包括：

```
异常指令 → INVTLB
异常指令 → filler → filler → INVTLB
```

分别覆盖“较老异常@EXE2、INVTLB\@EXE1”和“WB flush、INVTLB\@EXE1 同拍”。

## 4. 当前错误机制

```
INVTLB 位于 EXE1
→ invtlb_valid 仅依赖 inst_invtlb / EXE1_valid / 局部合法性
→ TLB posedge 直接 invalidate
→ 更老异常或 WB flush 随后取消 INVTLB
→ TLB architectural state 无恢复路径
```

## 5. 根因

INVTLB architectural side effect 没有精确 squash/older-exception/commit qualification。

## 6. Architectural consequence

从架构顺序看未执行的 INVTLB 已经改变 TLB state，可能导致不应出现的 TLB miss、TLBR 或地址翻译变化。

## 7. Linux-pass 为什么遗漏

需要较老异常或中断精确落在年轻 INVTLB 的危险窗口。正常内核 TLB 管理路径不一定产生这种异常/INVTLB 叠加，且后果可能在后续翻译时才显现。

## 8. 推荐修改方向

方向 A：保留 EXE1 执行，但增加精确 qualification。

- `invtlb_valid` 必须受所有可 squash 当前 INVTLB 的 cancel、older exception、WB flush 条件限制。
- 必须证明 EXE2/MEM/WB 更老异常以及同拍 WB flush 都在 TLB 写沿前有效。
- 需明确操作数在 EXE1 的生命周期，以及 TLB 查询端口与 INVTLB 复用关系。

优点：改动较小，保留原有早期执行时序。
风险：容易遗漏某一种 squash 来源，且 WB→EXE1/TLB 组合路径可能变长。

方向 B：将 INVTLB architectural side effect 推迟到精确提交点。

- 把 INVTLB op、ASID、VPPN 等 payload 随流水带到精确提交点。
- 仅当该条 INVTLB 确定提交时才修改 TLB。

优点：精确性最强、核心不变量最清晰。
风险：bus 改动面大，必须重新审视 TLBWR/TLBFILL 优先级、TLB operand 生命周期和系统指令时序。

推荐：以方向 B 为完整性优先的推荐方向；若实施方向 A，必须先证明其覆盖所有 cancel 与更老异常来源，再允许进入代码评审。

## 9. 允许修改文件

- `D:\fpga\chiplab-fullinst-0808-1\IP\myCPU\EXE1.v`
- `D:\fpga\chiplab-fullinst-0808-1\IP\myCPU\mycpu_core.v`
- `D:\fpga\chiplab-fullinst-0808-1\IP\myCPU\tlb.v`

若采用方向 B，可必要扩展：

- `EXE2.v`
- `MEM.v`
- `WB.v`
- 对应 stage bus 定义。

## 10. 禁止夹带修改

- TLB replacement、TLB 结构容量、页表格式；
- DMW、TLBWR/TLBFILL 功能重构；
- 其他 exception cleanup；
- XCI、Generate Output Products；
- 无关 CSR/Cache 改动。

## 11. 与八级流水冲突程度

高。

## 12. 修改前已有复现

模块级动态复现已确认 TLB entry 不可恢复的提前失效；完整 core 可达性已确认。

## 13. 修改后通过条件

- 被 squash 的 INVTLB 不得改变目标 TLB entry。
- 合法且最终提交的 INVTLB 必须准确完成 invalidate。
- 不得影响 TLBWR、TLBFILL、TLBRD 的既有提交语义与优先级。
- 当异常、flush、INVTLB 同拍时，TLB state 与精确提交序一致。

## 14. 最小定向回归

- 异常 → INVTLB。
- 异常 → 两个 filler → INVTLB。
- interrupt → INVTLB。
- WB flush 与 INVTLB\@EXE1 同拍。
- INVTLB op 0～6 合法范围回归。
- TLBWR/TLBFILL/TLBRD 与 INVTLB 相邻和交叉。
- TLB exception、TLBR、重取路径回归。

## 15. 相关旧修复回归

- OLD-F-01：异常入口优先级。
- OLD-F-02：ERTN 必须 commit-qualified。
- OLD-F-03：最终 selected exception 才允许 TLB side effect。

## 16. Linux 门禁

需要。NB-01 完成且定向回归通过后，必须重跑完整 Linux 启动；若 NB-02 与 NB-01 连续合并，则两者完成后执行一次完整：

```
U-Boot → Linux → BusyBox shell
```

---

# NB-04 Divider transaction operand / kill / result ownership 脱节

## 1. 最终裁决

A2。不得上调为 A。

## 2. 严重程度

高。存在把旧 DIV output 错交给新 DIV 的内部路径，但尚未完成 WB/GPR 错写动态闭环。

## 3. 动态证据

类型：**模块级**（ALU + 当前生成的 signed divider）。

已有 testbench：

`C:\Users\user\AppData\Local\Temp\codex-nb04-2abe30b9\nb04_tb.sv`

已真实观察：

- 原异常 DIV：`100/7`
- Divider 最终 input handshake：`81/9`
- flush 到达时：`EXE1_need_cancel=1`，但当前 EXE1 已不是原 DIV，故 `divide_begin=0、kill=0`
- 新合法 DIV：`20/4`，正确结果应为 5
- 旧 transaction 返回结果：9
- 旧 output-valid 使当前新 DIV：`divide_ready_go=1`、EXE1 advance，结果取到 9。

unsigned 仅证明 RTL 结构同构，未动态证明。

## 4. 当前错误机制

```
旧 DIV 启动 transaction
→ TVALID 被寄存，但 TDATA 仍接实时 alu_src1/alu_src2
→ 原 DIV 因异常/notice 先离开 EXE1
→ 实时 operand 被年轻指令替换
→ divider 接受错误 operand
→ flush 到来时，kill 只检查“当前 EXE1 是否 DIV”
→ outstanding 旧 transaction 不被 kill
→ 新 DIV 在 EXE1 等待
→ 旧 output-valid 被新 DIV 误消费
```

## 5. 根因

operand、transaction owner、kill、output consumption 没有绑定到同一个 outstanding DIV transaction。

## 6. Architectural consequence

新 DIV 可能获得旧 transaction 的 quotient/remainder，最终存在错误写回 GPR 的风险；当前尚未动态证明该最终提交。

## 7. Linux-pass 为什么遗漏

需要异常/中断恰好让旧 DIV 在 input handshake 前离开 EXE1，之后还要有新的合法 DIV 在旧结果返回前到达。普通 Linux 启动不易自然形成这种长延迟时序组合。

## 8. 推荐修改方向

必须采用 transaction ownership 修复，不接受仅增加一个 flush OR 条件的局部补丁。

推荐结构：

- 在真正启动/接受 DIV transaction 时锁存 operand。
- 锁存 transaction valid、signed/unsigned owner、操作类别和必要 result-select 信息。
- kill 绑定 outstanding transaction owner，而非当前 EXE1 instruction。
- output-valid 只能由与 owner 匹配、仍在等待的指令消费。
- 新 DIV admission 必须与当前 outstanding transaction 明确互斥或具备可证明的 tag/队列关系。
- signed 与 unsigned 两路均须明确 owner。

替代方案：

- 采用单 outstanding transaction 的严格 stall 模型：未完成 transaction 存在时，新 DIV/MOD 不能进入可消费 output 的状态。

取舍：

- 严格 stall 模型较易证明正确，但可能牺牲吞吐。
- owner/tag 模型扩展性好，但状态机与验证复杂度更高。

## 9. 允许修改文件

- `D:\fpga\chiplab-fullinst-0808-1\IP\myCPU\alu.v`
- `D:\fpga\chiplab-fullinst-0808-1\IP\myCPU\EXE1.v`
- 必要时增加与 transaction ownership 有关的 pipeline state。

## 10. 禁止夹带修改

- `divider.xci`、`divider_unsigned.xci`；
- Generate Output Products；
- 乘法、普通 ALU、cache、TLB 清理；
- 无关 ready/valid 重构；
- 格式化、rename、dead code 清理。

## 11. 与八级流水冲突程度

高。

## 12. 修改前已有复现

模块级真实 divider 动态复现已证明 operand 错采样、kill 错 owner、旧结果误释放新 DIV。尚未有完整 EXE2→MEM→WB→GPR 错写复现。

## 13. 修改后通过条件

- 原 DIV transaction 只能使用启动时锁存的 operand。
- 被 kill 的 transaction output 不得释放任何后续 DIV/MOD。
- 新 DIV 不得消费旧 transaction output。
- signed/unsigned 两路均满足 owner 一致性。
- 完整 core 验收中，目标 GPR 必须写入新 DIV/MOD 的正确结果。

## 14. 最小定向回归

修复前先冻结完整 core 验收 test，至少包括：

- signed：异常 DIV → flush → 新 DIV → EXE2/MEM/WB/GPR。
- unsigned：相同路径。
- DIV、DIVU、MOD、MODU。
- 相邻 DIV。
- DIV → branch。
- interrupt、exception、flush。
- CACOP/serial 与 DIV 交叉。
- 普通除法性能与结果回归。

## 15. 相关旧修复回归

- OLD-F-08：DIV 未完成时 branch forward/hazard。
- OLD-F-01：异常优先级。
- OLD-F-02：ERTN/flush 精确性。

## 16. Linux 门禁

必须。第三阶段所有 Divider 定向回归通过后，完整启动 Linux。

---

## 每阶段 Git commit 规划

不得实际创建 commit；实施时采用以下独立提交边界：

1. `fix(cacop): prevent duplicate pc+4 execution across icache cacop cancel`
2. `fix(decode): accept legal rdcntvl.w r0 encoding`
3. `fix(memory): block squashed exe2 memory request on serial flush`
4. `fix(tlb): qualify invtlb side effects against squash`
5. `fix(div): bind divider request lifecycle to transaction ownership`

每个 commit 必须：

- 只解决一个 NB；
- 无 cleanup、无重命名、无格式化；
- 可独立 revert；
- 提交前后均有该 NB 的明确 pass/fail 证据。

## 明确禁止的 cleanup

整个修改阶段禁止夹带：

- implicit net；
- unused wire；
- dead code；
- bus 瘦身；
- 注释整理；
- 模块重命名；
- 格式化；
- EXE2\_ex 声明顺序；
- `rf[0]` 物理写抑制；
- reset 合同项；
- AXI error response；
- MMIO size；
- 外部 interrupt 接口；
- 当前台账之外的任何问题。

## 总体验收矩阵

| Test | NB-01 | NB-02 | NB-03 | NB-04 | NB-05 | OLD regressions | Linux |
|---|---|---|---|---|---|---|---|
| CACOP full-core 单提交用例                             | —    | —    | 阶段 1     | DIV 交叉保护 | —    | OLD-S-02                | 阶段 1 后 |
| RDCNT r0 / n58\_rdcnt                             | —    | —    | —        | —        | 阶段 1 | OLD-F-01 INE 路径         | 阶段 1 后 |
| serial flush + store + AXI monitor                | —    | 阶段 2 | —        | —        | —    | OLD-F-01/02/03、OLD-S-02 | 阶段 2 后 |
| exception/interrupt + INVTLB                      | 阶段 2 | —    | —        | —        | —    | OLD-F-01/02/03          | 阶段 2 后 |
| signed/unsigned DIV ownership full-core           | —    | —    | CACOP 交叉 | 阶段 3     | —    | OLD-F-08、OLD-F-01/02    | 阶段 3 后 |
| U-Boot → Linux → BusyBox                          | 阶段 2 | 阶段 2 | 阶段 1     | 阶段 3     | 阶段 1 | 全部旧修复保护                 | 每阶段末   |

所有矩阵项都是**未来实施后的必跑项**，不表示本规格生成时已经通过。

## 最终实施顺序

```
阶段 1：
NB-03
→ 定向验证
→ NB-05
→ 定向验证
→ U-Boot → Linux → BusyBox

阶段 2：
NB-02
→ 定向验证
→ NB-01
→ 定向验证
→ U-Boot → Linux → BusyBox

阶段 3：
NB-04
→ 全部 Divider 回归
→ U-Boot → Linux → BusyBox
```

## 实施前门禁

实施人员在开始第一个 RTL commit 前必须完成：

1. 备份当前 Linux-pass CPU 与当前可启动 Linux bitstream，保存位置和 SHA-256 必须记录。
2. 记录 `IP/myCPU` 全部 32 个受控文件的 SHA-256 manifest。
3. 记录 `system_run.xpr` SHA-256。当前冻结值为：

   `044A2B6CD4B10CD103673D075C64B163A62F26D519AE2FBAE85947E4B1CA80C0`
4. 记录四个 XCI SHA-256：
   - divider：`2534046A03DB8EB9DFDA4628DC431F321256B4869B3A3D5635BB8760A7405C5D`
   - divider\_unsigned：`98CB1DA0E595CBE7B1FCCA22EE5487D510874CA0B91621B02085B02A3D2918AE`
   - data\_bank\_ram：`3B13E5D804100787717592DE99A3F06D9864C75C9DCEFCA532E69B1B0E6A50A2`
   - tagv\_ram：`8D14332238F40A0B7ACE4704419CF2B9A996C2B80D2DD087625BC04CF6E063FA`
5. 确认四个 IP 已有 Generate Output Products 可复用，实施期间禁止重新 Generate Output Products。
6. 记录 Git 工作树已有变化；不得将其误判为本修改包产生，也不得覆盖。
7. 确认 `IP/myCPU` 当前无待提交 diff 后，才允许开始第一个独立 Bug commit。
8. 禁止覆盖、替换或删除当前 Linux-pass 基线、工程文件、XCI 与可启动 bitstream。