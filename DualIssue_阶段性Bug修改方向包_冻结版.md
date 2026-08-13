# 顺序双发 CPU 阶段性 Bug 修改方向包

> 文档属性：冻结版修改方向规格；供 RTL 队友实施与验收使用。  
> 本文不是 RTL 补丁，不授权修改 Xilinx IP 配置，也不代表任何修复已经完成。

## 1. 基线

| 项目 | 冻结值 |
|---|---|
| 工程路径 | `D:\fpga\chiplab_dualissue_debug_0812` |
| CPU 形态 | 顺序双发，`ISSUE=2` |
| 流水结构 | `Pre_IF1 → Pre_IF2 → IF/fetch → ID/decode → EXE1 → EXE2 → MEM → WB` |
| `decode.sv` SHA-256 | `2BD0D9267EB1BE9BBE05BAC8ED178D830685B95634DE99B7986A183681B825B4` |
| RTL/header aggregate SHA-256 | `B910BF3451EDCB034163FEF5470BAA550D0C8499FDD07C529DA8C7131EDCCBC1` |
| FPGA perf 基线 | Chiplab perf 20/20 PASS；这是用户提供的队友实际 FPGA 上板结果，不是本机日志或本修改包重新验证的结果 |
| 已关闭问题 | `DI-01 — A / Closed` |

DI-01 的既有修复事实：已训练且预测正确的 `b +4`，target 位于 neighbor slot1 时，不再被错误 hard-kill。该问题不属于本修改包的修改范围；联合回归必须保留防回退用例。

本修改包只适用于上表冻结源码。若 `IP/myCPU` 的 RTL/header aggregate 变化，必须先确认变化内容与三个 Open Bug 的证据链和责任边界是否仍一致，不能把本文结论无条件映射到新版本。

## 2. 修改总原则

三个 Open Bug 共享一个上层原则：architectural age/liveness 必须约束所有 side effect。但它们分属两个具体修复域，不能靠一根粗粒度 `architecturally_live` 组合线在一处全部修完。

### Rule 1：Architectural launch qualification

任何可能产生以下行为的动态指令，在 launch 前都必须确认没有被任何 dynamically older instruction 取消：

- redirect 或 cancel；
- cache operation；
- long-latency transaction；
- persistent/global side effect。

资格判断不能只看当前指令的 `valid` 和自身 exception，也不能只阻止 older exception 而遗漏 older non-exception serializing flush。资格必须覆盖会杀死该级动态指令的全部更老事件，并明确区分“同一指令产生的控制”与“更老指令施加的 cancel”，避免自取消。

### Rule 2：Transaction ownership

对于 divider/cache 等跨多个 cycle 的 transaction：

- 请求尚未 handshake：必须能够撤销，或将 pending request 标为无效，保证接口以后不会再接受它；
- 请求已经 handshake，且外部单元不可取消：必须记录 owner 的 alive/stale 状态；
- stale response 到来：只允许完成协议清理和释放资源，不得令当前 EXE1 指令 ready，不得作为当前指令结果进入后级；
- 后来的动态指令占据相同 lane/EXE1 时，不得自动继承旧 transaction 的 response。

### Rule 3：Redirect age arbitration

多个 redirect/cancel source 同时存在时必须：

1. 先剔除 architecturally dead source；
2. 再按动态年龄保证 older redirect 不被 younger redirect 覆盖；
3. 对跨拍保存的 redirect/cancel state 同样保留 owner/liveness 语义，不能只保证第一拍 mux 正确。

不得依赖 `IBAR > CACOP > WB` 这种固定“模块名优先级”替代年龄仲裁。

## 3. 根因分域

| 修复域 | 包含 Bug | 具体责任 |
|---|---|---|
| A：EXE2 global control/cache side-effect age qualification | DI-R1-01、DI-R1-02 | IBAR/CACOP launch 资格、CACOP cancel-state ownership、全局 redirect 年龄仲裁 |
| B：long-latency divider transaction ownership | DI-R2-01 | DIV/MOD pending request、handshake 后 owner/stale、response 归属与清理 |

两个域共享 Rules 1–3 的上层原则，但实施和验证必须分开。域 A 的主要错误发生在 EXE2/全局控制，域 B 的主要错误发生在 EXE1/ALU 与 divider 请求响应生命周期。

## 4. 修复域 A：EXE2 IBAR / CACOP

### 4.1 DI-R1-01 — A / Open

#### 4.1.1 问题

较老 WB `syscall` exception flush 与较年轻 EXE2 `IBAR` 同拍。年轻 IBAR 已被 older flush 杀死，却仍产生 `ibar_cancel`，并在全局 target mux 中覆盖 EENTRY。

#### 4.1.2 最小动态指令序列

```text
syscall @ 0x1c000040
NOP     @ 0x1c000044
IBAR    @ 0x1c000048
```

异常入口为 `0x1c010000`，IBAR 自带 target 为 `0x1c00004c`。

#### 4.1.3 决定性 stage overlap

决定周期 C43：

| Older WB | Younger EXE2 |
|---|---|
| PC=`0x1c000040` | PC=`0x1c000048` |
| instruction=`0x002b0000` (`syscall`) | instruction=`0x38720000` (`IBAR`) |
| `flush=1` | `older_ex_for_exe2=1` |
| `flush_target=0x1c010000` | `EXE2_need_cancel=1` |
|  | `ibar_cancel=1` |
|  | `ibar_pc=0x1c00004c` |

#### 4.1.4 Expected

- younger IBAR 被视为 architecturally dead；
- dead IBAR 不得成为有效全局 redirect source；
- final target=`0x1c010000`；
- 下一拍 Pre_IF1 进入 EENTRY，handler 能执行。

#### 4.1.5 Actual

当前 mux 为 `IBAR > CACOP > WB flush`。C43 最终选择 `0x1c00004c`，C44 Pre_IF1 实际进入 `0x1c00004c`；仿真结束时 `handler_seen=0`。

#### 4.1.6 第一处分歧

第一处分歧就在 C43 的 target source 选择：older WB 已提供正确 EENTRY，但 dead younger IBAR 仍携带有效 select 并覆盖它。错误不是 Pre_IF1 采样，也不是 `flush_target` 生产错误。

#### 4.1.7 为什么是年龄错误

流水位置已确定 WB syscall 比 EXE2 IBAR 更老；`older_ex_for_exe2=1` 与 `EXE2_need_cancel=1` 又明确表明 IBAR 应被取消。IBAR 的 `valid` 不能再等价于 architectural liveness。

#### 4.1.8 为什么 20/20 perf PASS 不能排除

20 项 perf 全过只能证明那些程序没有触发或暴露该精确 overlap。该问题要求 exception flush 与年轻 IBAR 在特定流水位置同拍，属于低概率控制流组合；perf 覆盖结果不能反证动态定向用例中的错误 PC。

#### 4.1.9 Active disproof

去掉中间 NOP，使 IBAR 与 WB flush 错开：IBAR 在 C42 独立处理，syscall 在 C43 独立 flush；C44 Pre_IF1 正确为 `0x1c010000`，`handler_seen=1`。这排除了 EENTRY 配置、instruction-memory 时序和 testbench PC 采样问题。

#### 4.1.10 建议修改责任边界

- `EXE2.sv`：产生 `ibar_cancel` 前使用年龄正确、无自依赖的 launch qualification；
- `mycpu_core.sv`：提供明确的 older-cancel/liveness 语义，并使 global target 仲裁按有效 source 与动态年龄工作；
- `Pre_IF1.sv`：无需修改，它只是消费上游给出的 cancel/target；
- `WB.sv`：无需为该 Bug 修改，当前 flush 与 EENTRY target 已动态证明正确；
- `decode.sv`：无需修改，IBAR/syscall decode 不是分歧来源。

#### 4.1.11 修改完成验收条件

- 原碰撞周期中，older flush、`EXE2_need_cancel` 仍可按设计成立；
- dead IBAR 不得作为 architectural cancel/redirect source；
- final target 必须等于 EENTRY；
- 下一拍 Pre_IF1 必须等于 EENTRY，handler 必须执行；
- 单独合法 IBAR 必须仍正常完成一次 PC+4 cancel；
- 不得引入组合环、自取消或合法 IBAR 永久失效。

### 4.2 DI-R1-02 — A+cache / Open

#### 4.2.1 问题

较老 WB 非异常 serializing `CSRWR` flush 与较年轻 EXE2 `CACOP` 同拍。`EXE2_need_cancel=1`，但 `older_ex_for_exe2=0`，当前 `cacop_valid` 只看 older exception，没有覆盖非异常 serializing flush，因此 dead CACOP 被真实 cache controller 接受并留下跨拍 cancel state。

#### 4.2.2 最小动态指令序列

```text
CSRWR EENTRY,r0 @ 0x1c000040
NOP             @ 0x1c000044
CACOP code0     @ 0x1c000048
```

CSRWR 的架构 redirect target 为 `0x1c000044`，CACOP cancel target 为 `0x1c00004c`。

#### 4.2.3 决定性 stage overlap

决定周期 C43：

| Older WB | Younger EXE2/cache |
|---|---|
| PC=`0x1c000040` | PC=`0x1c000048` |
| instruction=`0x04003020` | instruction=`0x06000000` |
| `flush=1` | `EXE2_need_cancel=1` |
| `flush_target=0x1c000044` | `older_ex_for_exe2=0` |
|  | `cacop_valid=1` |
|  | cache `lookup_begin=1` |

之后：

```text
C43 cache 接受 dead CACOP
C44 cache state=001，cacop_need_cancel=1，Pre_IF1 暂时进入 0x1c000044
C45 cache state=010，cacop_need_cancel=1，Pre_IF1 被改到 0x1c00004c
C46 cache state=100，cacop_done=1
```

#### 4.2.4 Expected

- younger CACOP 被 older serializing flush 杀死；
- dead CACOP 不得使 cache `lookup_begin` 成立；
- 不得锁存属于 dead CACOP 的 `cacop_need_cancel`；
- Pre_IF1 应保持 older CSRWR 决定的 `0x1c000044`；
- 从 `0x1c000044` 重新取指后，架构上再次出现的合法 CACOP 应正常执行一次。

#### 4.2.5 Actual

C43 的同拍 mux 因 `cacop_need_cancel` 尚未锁存而暂时选择正确 CSR target；但 cache 已经接受 dead CACOP。C44 起 `cacop_need_cancel=1`，C45 把 Pre_IF1 改到 `0x1c00004c`，跳过原本应从 `0x1c000044` 开始的架构路径。

#### 4.2.6 第一处分歧

第一处分歧不是 C45 的 target mux，而是 C43 的 side-effect launch：`EXE2_need_cancel=1` 时仍有 `cacop_valid=1` 和 cache `lookup_begin=1`。后续错误 PC 是这个错误 launch 与错误 cancel-state ownership 的结果。

#### 4.2.7 为什么是年龄错误

当前 `older_ex_for_exe2` 只表达 older exception，不表达 WB 非异常 serializing flush。`EXE2_need_cancel` 已确认该 EXE2 指令应取消，但 CACOP launch qualification 没有覆盖它。

#### 4.2.8 为什么 20/20 perf PASS 不能排除

perf 20/20 不代表测试包含 CSR serializing flush 与年轻 CACOP 的精确同拍，也不能覆盖真实 cache 状态机接受后产生的跨拍 cancel。动态日志已经证明控制流和 cache controller 状态实际改变。

#### 4.2.9 Active disproof

将 CACOP 再错开一拍：C43 CSRWR flush 单独发生，C44 Pre_IF1 正确进入 `0x1c000044`；原年轻 CACOP 未在碰撞周期被接受。之后重新取指到架构合法 CACOP 时，cache 才正常接受并完成。这区分了错误的 dead launch 与合法 refetch 行为。

#### 4.2.10 建议修改责任边界

- `EXE2.sv`：在 cache 接收前阻止 architecturally dead CACOP launch；资格必须覆盖非异常 serializing flush；
- `mycpu_core.sv`：确保 `cacop_need_cancel` 只由仍有 owner 的合法 CACOP 设置和保持；全局 redirect 不能让 dead/stale CACOP state 覆盖 older redirect；
- `cache.sv`/`icache.sv`：优先作为协议消费者和回归观察点。若上游可在 `lookup_begin` 前阻止 dead CACOP，不应在 cache 内打 workaround；
- 如果最终协议允许 CACOP 在 handshake 后才收到 older cancel，则还需定义 accepted transaction 的 stale/cleanup 行为，但不能把这个机制当成缺失 launch qualification 的替代品；
- `Pre_IF1.sv`、`WB.sv`、`decode.sv`：当前证据不要求修改。

#### 4.2.11 修改完成验收条件

- 原碰撞周期 dead CACOP 的 `cacop_valid`/cache accept 必须无效；
- `lookup_begin` 不得因该 dead CACOP 成立；
- 不得留下该动态指令的 `cacop_need_cancel` 或其他 persistent cache-control state；
- Pre_IF1 必须保持 CSRWR 的 `PC+4` redirect；
- 重新取指后的合法 CACOP 必须正常执行且恰好一次；
- 合法 CACOP 的 cache 状态机、`cacop_done` 和 cancel/refetch 契约必须保持正常。

### 4.3 修复域 A 的共同责任边界

| 文件 | 责任建议 |
|---|---|
| `EXE2.sv` | IBAR/CACOP side-effect launch qualification；区分自身控制与 older cancel |
| `mycpu_core.sv` | 各级 older-cancel/liveness、redirect source 有效性、动态年龄仲裁、CACOP cancel-state owner |
| `cache.sv`/`icache.sv` | 首选只作为消费者与回归观察；只有协议确需 accepted-operation cancel/cleanup 时才扩展接口 |
| `Pre_IF1.sv` | 明确排除：当前行为是正确消费上游 target，无证据要求修改 |
| `WB.sv` | 原则上排除：flush/flush_target 已证明正确 |
| `decode.sv` | 排除：DI-01 已关闭，三个 Open Bug 无 decode 修改证据 |

### 4.4 修复域 A 严禁的错误修法

#### 不允许只交换 target mux priority

仅改为 `WB > IBAR > CACOP` 可能掩盖 DI-R1-01 的决定周期，但不能消除 dead IBAR side effect。对 DI-R1-02 更不充分：C43 cache 已接受 CACOP，C44 锁存的 `cacop_need_cancel` 可在 WB flush 消失后再次污染 PC。

#### 不允许直接反门控形成自依赖

不得直接写成概念上的：

```text
ibar_cancel &= ~EXE2_need_cancel
```

当前依赖为：

```text
EXE2_need_cancel = flush | ibar_cancel
```

上述粗暴门控会使 `ibar_cancel` 组合依赖自身。合法 IBAR 在 `flush=0` 时落入 `ibar_cancel = raw_ibar & ~ibar_cancel`，可能形成组合反馈/无稳定逻辑含义。应从不包含本 instruction 自身 redirect 的 older-cancel/liveness 定义出发。

#### 不允许用 cache 内补丁掩盖上游资格错误

第一责任是保证 dead CACOP 不被 launch。如果上游已经知道 `EXE2_need_cancel`/older serializing flush，却仍把请求送到 cache，再由 cache 猜测 owner，是错误的责任倒置。

### 4.5 修复域 A 验收 testcase

#### T1：`syscall → NOP → IBAR`

主断言：

- 重现原 WB/EXE2 overlap；
- dead IBAR 不产生有效 architectural cancel；
- final target 与下一拍 Pre_IF1 都为 EENTRY；
- handler 确实执行。

反向断言：

- 单独合法 IBAR 正常工作；
- syscall flush 单独发生时进入 EENTRY；
- 不得破坏 DI-01 已训练 `b +4` neighbor slot1 行为。

#### T2：`CSRWR → NOP → CACOP`

主断言：

- dead CACOP 不被 cache 接受；
- cache `lookup_begin` 不因该 dead CACOP 成立；
- 不留下 `cacop_need_cancel`；
- CSRWR redirect 后 PC 不被 CACOP 改写。

反向断言：

- 重新取指后的合法 CACOP 正常执行且恰好一次；
- 单独合法 I-cache/D-cache CACOP 正常；
- serializing CSR flush 单独工作；
- cache accept、state、`cacop_done` 计数与动态指令一一对应。

## 5. 修复域 B：Divider transaction ownership

### 5.1 DI-R2-01 — A / Open

#### 5.1.1 最小动态序列

```text
main:
  syscall                    @ 0x1c000040
  div.w r6,r4,r5             @ 0x1c000044   ; 100 / 4 = 25，wrong-path

handler:
  div.w r9,r7,r8             @ 0x1c010000   ; 77 / 7 = 11，合法
```

#### 5.1.2 决定性时间线

| Cycle | 事件 |
|---:|---|
| C41 | older syscall 在 EXE2 产生 exception，`older_ex_for_exe1=1`；younger wrong DIV 在 EXE1，仍有 `divide_begin=1` |
| C42 | wrong DIV pending input `tvalid=1/1`，`is_dividing=1` |
| C43 | syscall 到 WB，`flush=1`、`EXE1_need_cancel=1`；但 pending `tvalid=1/1` 保留，`kill=0` |
| C45 | EXE1 已无有效 wrong instruction，Xilinx divider 仍接受 `100/4` 请求 |
| C82 | 旧 response 25 返回；此时 EXE1 PC/op 属于 handler DIV，handler 没有自己的 request |
| C85 | WB 为 handler PC、`rd=r9`，但写入旧结果 25；正确值应为 11 |

最终可见错误：`r6=0` 证明 wrong DIV 本身没有架构提交；`r9=25` 证明其 transaction response 越过 flush，被合法 handler DIV 继承。

### 5.2 当前 ownership 缺口

1. `divide_begin` 没有覆盖 `older_ex_for_exe1`：older exception 已在 EXE2 时，WB flush 尚未产生，wrong DIV 可以先建立 pending transaction；
2. pending input `dividend_tvalid/divisor_tvalid` 的生命周期没有与发起动态指令的 liveness/owner 绑定；
3. flush 到来时，pending request 没有可靠撤销；已 handshake transaction 也没有可靠 stale 标记；
4. response 没有 owner tag、generation 或等价的 alive/stale 信息；
5. lane-local `is_dividing`/response-ready 被后来占据 EXE1 的 DIV 共享，当前 handler DIV 因而可直接消费旧 response；
6. signed 与 unsigned divider 各有相似状态机，修复不能只覆盖 signed DIV 定向用例。

### 5.3 当前 kill 条件的结构矛盾

当前概念关系为：

```text
divide_begin = div_or_mod & ~EXE1_need_cancel & ~EXE1_ex
kill set     = EXE1_need_cancel & divide_begin
```

`divide_begin` 成立要求 `EXE1_need_cancel=0`，而 `kill` 置位又要求二者同时为 1。因此不能把该条件当作可靠的 flush cleanup。即使单独清 `is_dividing`，pending `tvalid` 或 Xilinx IP 内已经接受的 request/未来 response 仍然存在。

### 5.4 建议设计方向

以下是可选择的协议方案，不是 RTL 补丁。无论选择哪种，都必须满足 Rules 1–2。

#### 方案 B1：pending transaction valid + owner alive/stale

建议语义：

- launch 时建立 lane-local owner，并记录 request pending/handshaken；
- older cancel 到达且请求未 handshake：撤销两个 input valid，清 pending owner；
- older cancel 到达且请求已 handshake：owner 标 stale，保留足以 drain response 的状态；
- stale response 到来：只清 transaction/busy/stale，不产生当前指令 `ready_go`，不把结果送往后级；
- handler/下一条合法 DIV 只有在资源可创建新 owner 时才能 launch；不得以旧 response 满足它。

对于当前单 outstanding、lane-local divider，B1 通常比完整 transaction ID 更直接：每个 divider 实例只需明确区分 `idle / request_pending / inflight_alive / inflight_stale` 或等价状态。具体编码由 RTL 队友决定。

#### 方案 B2：generation/epoch ownership

建议语义：

- divider transaction 建立时记录当前 generation/epoch；
- 会杀死 owner 的 flush/cancel 提升 generation，或令旧 epoch 失效；
- response 只有与当前有效 owner epoch 匹配时，才能令 EXE1 DIV ready 并提供结果；
- 不匹配 response 只 drain/discard。

B2 更适合未来扩展多个 outstanding 或统一多个长延迟单元，但当前单 outstanding divider 可能增加不必要复杂度。不得因为不采用 transaction ID 就省略 stale/owner 语义；B1 已可满足不变量。

#### 共同要求

- launch qualification 应接收年龄正确的 cancel/liveness，不能只等 WB flush；
- 两路输入通道可能分开 ready，必须定义部分握手时的撤销/ownership；
- signed DIV/MOD 与 unsigned DIV/MOD 必须一致；
- 必须明确 response drain 与 pipeline instruction ready 的区别；
- 不要求、也不建议修改或重新配置 Xilinx Divider Generator XCI。

### 5.5 修改责任边界

| 文件 | 责任建议 |
|---|---|
| `alu.sv` | 主要责任：pending/handshake/inflight/stale 状态、response ownership、signed/unsigned 一致性 |
| `EXE1.sv` | 将 lane-valid、动态指令资格及年龄正确 cancel 传给 ALU；保证 ready/result 只属于当前 owner |
| `mycpu_core.sv` | 提供覆盖 EXE2/MEM/WB older events 的年龄信息，区分 older cancel 与晚到全局 flush |
| Divider XCI/generated model | 明确排除：不得把重新配置 IP 当作解决 ownership 错误的方案 |

### 5.6 T3 验收 testcase

冻结主用例：

```text
main:    syscall → wrong-path DIV 100/4
handler: valid DIV 77/7
```

严格要求：

- wrong transaction 未 handshake：必须撤销 pending request，之后接口不得再接受；
- wrong transaction 已 handshake：必须标 stale，response 只 drain/discard；
- handler DIV 必须建立自己的合法 ownership/request；
- handler response 必须为 11；
- 最终 `r9=11`，不得为 25；
- wrong DIV 不得写 `r6`。

必须记录：

- request handshake count、cycle、lane、operands；
- response count、cycle、raw result；
- owner alive/stale/discard；
- input pending valid、部分/完整 handshake；
- `is_dividing` 或替代 transaction state；
- handler DIV request；
- handler EXE1/MEM/WB PC、rd 与结果。

### 5.7 Divider 反向回归矩阵

| 编号 | 用例 | 必查点 |
|---|---|---|
| B-R1 | 普通 signed `DIV.W` | 正负操作数、商、请求/响应一一对应 |
| B-R2 | unsigned `DIV.W` | 高位为 1 的无符号操作数不走 signed 路径 |
| B-R3 | signed `MOD.W` | 正负余数语义与 response 选择正确 |
| B-R4 | unsigned `MOD.W` | 无符号余数与 ownership 正确 |
| B-R5 | back-to-back 合法 DIV | 第二条不能继承第一条 response；两次请求、两次结果 |
| B-R6 | back-to-back DIV/MOD | op/result 选择不串线 |
| B-R7 | 两个 issue lane 分别使用 divider | lane owner、rd、PC 不串线；按当前结构约束验证实际允许的时序 |
| B-R8 | cancel before launch | 不产生 request，不建立 inflight owner |
| B-R9 | cancel while input valid、handshake 前 | pending request 完整撤销，包括两个 AXIS input valid |
| B-R10 | cancel after handshake、response 前 | 标 stale；response drain 但不 ready 当前指令 |
| B-R11 | response 与下一条 DIV 接近/同拍 | 旧 response 不得满足新 owner；资源释放/新 launch 次序明确 |
| B-R12 | signed/unsigned 单元交错 | 两套 divider 的 busy/stale/ready 状态互不污染 |

这些反向回归用于证明实现的是 transaction ownership，不是只对 T3 的 syscall/数值打特判。

## 6. 两个修复域的实施顺序

### Stage A

只处理：

- IBAR/CACOP age qualification；
- CACOP cancel-state ownership；
- global redirect age arbitration。

建议只修改 Stage A 必需文件，运行 T1、T2 与合法 IBAR/CACOP、exception flush、serializing CSR flush 反向测试。通过后记录源码 hash 和测试证据，冻结 Stage A。

### Stage B

在 Stage A 冻结基础上再处理 divider ownership。运行 T3 和完整 divider 反向矩阵，通过后记录源码 hash 和测试证据，冻结 Stage B。

不要把两个修复域一次大改。否则出现回归时无法区分 global control、cache side effect 与 divider transaction 的责任。

## 7. 最终联合回归

| 层级 | 内容 | 通过标准 |
|---|---|---|
| 第一层 | T1、T2、T3 | 三个原始动态错误全部消失，所有 active disproof/合法路径仍工作 |
| 第二层 | DI-01 防回退 | 已训练且预测正确的 `b +4`：neighbor target slot1 进入 EXE1/MEM/WB 并恰好提交一次，最终 GPR side effect 正确 |
| 第三层 | Chiplab functional tests | 全部通过；记录具体命令、环境与结果 |
| 第四层 | Chiplab perf 20 项 | 20/20 PASS；逐项保留结果摘要 |
| 可选系统层 | U-Boot/Linux/其他用户基线 | 是否执行由用户决定；本修改包不预先声明完成 |

## 8. 风险提示

- 不要分别为 T1、T2、T3 打 opcode/PC/异常类型局部特判；
- 正确修改应实现 architectural liveness、transaction ownership、age-correct redirect arbitration 三个通用不变量；
- 20/20 perf PASS 不能说明低概率 exception/serializing overlap 不存在；
- 修改 IBAR 门控时尤其防止 `ibar_cancel` 与 `EXE2_need_cancel` 自依赖；
- 修改 CACOP 时同时检查 launch 与跨拍 `cacop_need_cancel` owner，不能只修 target mux；
- 修改 divider 时不能只清 busy；必须区分 pending、handshaken、alive、stale 与 response drain；
- 不修改 Xilinx divider XCI，不以 IP 重配置规避 CPU transaction ownership 缺陷；
- 每个 Stage 通过后先冻结 hash 与证据，再进入下一 Stage。

## 9. 最终 Bug Ledger

| 编号 | 等级/状态 | 修改阶段 | 说明 |
|---|---|---|---|
| DI-01 | A / Closed | 仅防回退 | 已训练 `b +4` neighbor slot1 hard-kill 问题已修复，不重新修改 |
| DI-R1-01 | A / Open | Stage A | dead younger IBAR 覆盖 older WB exception target |
| DI-R1-02 | A+cache / Open | Stage A | dead younger CACOP 被真实 cache 接受并跨拍污染 PC |
| DI-R2-01 | A / Open | Stage B | wrong-path DIV transaction response 被 handler DIV 继承 |

“older CACOP → younger DIV”只保留为静态 potential sibling；在新增动态证据前，不得写成 DI-R2-01 已确认触发源。

## 10. 证据索引

| 项目 | 现有 TEMP 证据 |
|---|---|
| DI-R1-01 主用例 | `.codex-tmp/di_r1_01/final_gap1/di_r1_01_final_gap1.sim/sim_1/behav/xsim/simulate.log` |
| DI-R1-01 active disproof | `.codex-tmp/di_r1_01/final_gap0/di_r1_01_final_gap0.sim/sim_1/behav/xsim/simulate.log` |
| DI-R1-02 主用例 | `.codex-tmp/di_r1_02/serial_main/di_r1_02_serial_main.sim/sim_1/behav/xsim/simulate.log` |
| DI-R1-02 active disproof | `.codex-tmp/di_r1_02/serial_shift/di_r1_02_serial_shift.sim/sim_1/behav/xsim/simulate.log` |
| DI-R2-01 主用例 | `.codex-tmp/di_r2_01/main_detail/di_r2_01_main_detail.sim/sim_1/behav/xsim/simulate.log` |
| DI-R2-01 active disproof | `.codex-tmp/di_r2_01/disproof/di_r2_01_disproof.sim/sim_1/behav/xsim/simulate.log` |
| DI-01 防回退环境 | `.codex-tmp/bplus4_directed/` |

## 11. 队友实施完成后的回传材料

请不要只回复“修好了”。无需提供大段完整 RTL，但至少回传 diff 摘要、关键逻辑说明和以下验证材料。

### Stage A

- 修改文件清单与修改前后 SHA-256；
- IBAR/CACOP architectural liveness 与 redirect 仲裁思路；
- 是否改变 `cacop_need_cancel` owner/lifecycle；
- T1 决定周期与下一拍 PC；
- T2 cache accept、state、`cacop_need_cancel` 与前端 PC；
- 合法 IBAR、合法 CACOP、exception flush、serializing CSR flush 的反向回归结果；
- Stage A RTL/header aggregate。

### Stage B

- 修改文件清单与修改前后 SHA-256；
- 采用 B1、B2 或等价机制的说明；
- pending、handshake、alive/stale、response discard 的状态语义；
- T3 完整 timeline，包括 request/response count、stale/discard、handler request 与 WB；
- signed/unsigned DIV/MOD 及 back-to-back 回归结果；
- Stage B RTL/header aggregate。

### 最终联合材料

- DI-01 防回退结果；
- T1/T2/T3 联合结果；
- Chiplab functional test 结果；
- Chiplab perf 20 项结果；
- 最终修改文件/diff 摘要；
- 最终 `decode.sv` SHA-256 与 RTL/header aggregate；
- 若执行 U-Boot/Linux/系统软件回归，单独注明环境、镜像与结果；未执行则明确写未执行。

## 12. 实施完成定义

只有同时满足以下条件，才能将对应 Open Bug 提交关闭验收：

1. 修改遵守本文件三个设计不变量；
2. 原定向主用例 PASS；
3. active disproof 与合法反向路径 PASS；
4. 没有通过 opcode/PC 特判绕过问题；
5. Stage 级 hash、diff 摘要和验证证据齐全；
6. 最终联合回归未引入 DI-01 回退。

本文冻结的是修改方向与验收契约，不代表 DI-R1-01、DI-R1-02、DI-R2-01 已关闭。在队友提交 RTL 修改并完成上述动态验收前，三项状态保持 Open。
