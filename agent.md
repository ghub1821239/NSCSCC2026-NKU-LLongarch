# Agent 工作日志

## 2026-08-18：ASID 寄存器复制（70MHz 提频）

### 背景
B 类时序路径（ASID → TLB/BTB → preIF1 pc_reg/D）的源头是 ASID[9:0] 对 TLB s0 16 路比较器的广播扇出（fanout 35，单段 route 1.021ns）。

### RTL 改动（仅 `IP/myCPU/csr_regfile.sv`）

1. **新增声明**（原 ASID 声明下方）：
   - `(* keep = "true" *) reg [9:0] ASID_tlb;`（TLB 专用副本）
   - `reg [9:0] asid_next;`（组合 next）

2. **ASID 更新块重构**：
   - 原时序块里 3 个独立 if（tlbrd r_e==0 / r_e==1 / CSR write）提取为组合 `always @(*)` 计算 `asid_next`，优先级不变（CSR write 最后覆盖，最高）；
   - 时序块改为 `ASID[9:0] <= asid_next; ASID_tlb <= asid_next;`（两 FF 同拍同值，无延迟）；
   - reset 行为保持：只写 ASIDBITS，不显式清零 [9:0]。

3. **消费改线**：
   - `s0_asid = ASID_tlb`（TLB 取指查询改由副本驱动）；
   - `s1_asid_without_invtlb`、`w_asid`、CSR readback 仍用原 `ASID[9:0]`。

### 综合验证（已确认）
- `ASID_tlb_reg[0..9]` 恰好 10 个 FF，未被合并；
- ASID_tlb 每 bit fanout=16（= TLB s0 16 路比较器）；
- `ASID_tlb/D` 路径 slack +5.671ns（无新增 critical path）；
- 原 ASID_reg[0..8] fanout 20-21，位 9 为 68（TLB 内部写口 16 + s1 比较器 ~40 + misc，均在非取指路径）。

### 备注
- 全局 WNS 仍可能被 Dcache tag BRAM 路径族（16 条）压住，属预期，尚未处理。
- 后续 impl 验收：单独看 B 类 4 条路径（ASID→TLB→BTB→pc_reg[4/31/27/29/28]/D），须基于重新综合的结果。
