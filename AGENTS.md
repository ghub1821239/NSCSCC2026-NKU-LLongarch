# AGENTS

## 语言

始终使用**简体中文**回复。

## 代码审阅对话规则

用户贴代码 / 说「看一下对不对」时：

1. **直接列错误点**，不要先绕概念、不要先夸方向。
2. 每条格式：**错在哪 → 怎么改**（必要时给最小改法代码）。
3. 只评用户当前负责的模块；队友模块默认会对齐，除非用户明确要联调。
4. 少讲「建议以后再…」；有问题就标成错误或明确的待补接线。
5. 顶层未接好时，不反复扯顶层，除非阻塞本模块自洽。

## 多发射：`parameter` / `FETCH_WIDTH` 改造约定

适用于 `IP/myCPU/Pre_IF*.v` 及前后级 bus 对接（如 `pre_IF1` → `pre_IF2` → IF / icache）。

### 核心原则

1. 在模块 `#()` 中增加发射宽度参数（如 `FETCH_WIDTH`），并据此重算 `inbus_width` / `outbus_width`。
2. **不是**几乎每个变量都加 `[num]`。
3. 只把「每条指令各有一份」的信号做成数组 / `generate` 循环；控制与握手多数仍保持**一套**。

### 应该数组化（按 slot）

- 每条指令的 PC、异常标志（`ex_ADEF`、TLB 相关等）
- DMW / TLB 译出的 per-inst 字段（若每条各一份）
- 分支预测相关 per-inst 字段（`btb_*`、`ras_*`、`query_*`）
- bus 解包 / 打包中按指令槽位排列的字段

示例：

```verilog
module pre_IF2 #(
    parameter  FETCH_WIDTH  = 2,
    parameter  inbus_width  = 64,   // 按 FETCH_WIDTH 重算
    parameter  outbus_width = 32
) ( /* ... */ );

wire [31:0] pc      [0:FETCH_WIDTH-1];
wire        ex_ADEF [0:FETCH_WIDTH-1];

genvar i;
generate
  for (i = 0; i < FETCH_WIDTH; i = i + 1) begin : gen_slot
    // 解 bus、组 outbus 中 per-slot 字段
  end
endgenerate
```

### 不应机械数组化

- `clk` / `resetn`
- `br_taken`、`need_stall`、cancel / flush 类全局控制
- `preIF*_valid` / `ready_go` / `allow_in`（流水级握手，先保持单套，除非明确改为按 slot 握手）
- `inst_sram_*` 握手、`req_without_dataok`、`inst_resp_discard`（默认仍按**单次取指请求**）

### `pre_IF2` 取指策略（默认）

优先：**一次 `inst_sram_req`，取一整块（cache line / 双字等），再在 IF 拆成 `FETCH_WIDTH` 条**，与 icache 对齐。

不要默认做成「每个 slot 各自发 req」，除非明确要求多口访存。

### 改造顺序建议

1. 与 `pre_IF1`、顶层共同约定 `FETCH_WIDTH` 与 bus 位宽。
2. 将 bus 解包/打包改为按 slot 的字段数组。
3. 握手 / discard 逻辑先保持单请求。
4. `outbus` 扩成 `FETCH_WIDTH` 份指令元数据；指令数据多由一次返回再切分。
