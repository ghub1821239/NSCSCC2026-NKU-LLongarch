module pre_IF1 #(
    parameter  slot0_outbus_width = 144,
    parameter  outbus_width       = 142,
    parameter  TLBNUM             = 16,
    parameter  ISSUE              = 2,
    parameter  ICACHE_OFFSET_W    = 4
)
(
    input  wire                          clk,
    input  wire                          resetn,
    //control signal
    input  wire                          valid_in,
    input  wire                          preIF1_allow_in,
    output reg                           preIF1_valid,
    output wire                          preIF1_ready_go,
    
    output wire [slot0_outbus_width-1:0] preIF1_preIF2_bus_slot0,
    output wire [outbus_width-1:0]       preIF1_preIF2_bus      [ISSUE - 1 : 1],
    //cancel
    input  wire                          preIF1_need_cancel,
    input  wire [31:0]                   cancel_target,
    //stall
    input  wire                          need_stall,
    // tlb port s0
    output wire [18:0]                   s0_vppn                [ISSUE - 1 : 0],
    output wire                          s0_va_bit12            [ISSUE - 1 : 0],
    input  wire                          s0_found               [ISSUE - 1 : 0],
    input  wire [$clog2(TLBNUM)-1:0]     s0_index               [ISSUE - 1 : 0], // 先向上取整再 log2，这样求出位宽
    input  wire [19:0]                   s0_ppn                 [ISSUE - 1 : 0],
    input  wire [5:0]                    s0_ps                  [ISSUE - 1 : 0],
    input  wire [1:0]                    s0_plv                 [ISSUE - 1 : 0],
    input  wire [1:0]                    s0_mat                 [ISSUE - 1 : 0],
    input  wire                          s0_d                   [ISSUE - 1 : 0],
    input  wire                          s0_v                   [ISSUE - 1 : 0],
    //tlb_ex
    input  wire                          ex_tlb_reload0         [ISSUE - 1 : 0],//tlb重填例外
    input  wire                          ex_tlb_preif_unvalid   [ISSUE - 1 : 0],//tlb中取指页无效
    input  wire                          ex_tlb_plv0            [ISSUE - 1 : 0],//tlb中页特权不合规
    output wire                          tlb_inst_req,
    //DMW
    output wire [2:0]                    dmw_vseg0              [ISSUE - 1 : 0],
    input  wire                          dmw_found0             [ISSUE - 1 : 0],
    input  wire [2:0]                    dmw_pseg0              [ISSUE - 1 : 0],
    //CRMD PG DA
    input  wire                          csr_CRMD_DA,
    input  wire                          csr_CRMD_PG,
    input  wire [1:0]                    csr_CRMD_DATF,
    input  wire [1:0]                    dmw_mat0               [ISSUE - 1 : 0],
    //branch prediction
    //查询端口：preIF取指时来查BTB
    output wire                          query_valid            [ISSUE-1:0],
    output wire [31:0]                   query_pc               [ISSUE-1:0],
    input  wire                          btb_query_hit          [ISSUE - 1 : 0],//valid且tag匹配
    input  wire [31:0]                   btb_query_target       [ISSUE - 1 : 0],
    input  wire                          ras_query_hit          [ISSUE - 1 : 0],//valid且tag匹配
    input  wire [31:0]                   ras_query_target       [ISSUE - 1 : 0],
    input  wire [ 1:0]                   query_type             [ISSUE - 1 : 0],
    input  wire                          query_taken            [ISSUE - 1 : 0],//预测是否跳转
    input  wire [7:0]                    query_ghr_snap,
    input  wire                          preIF1_IDLE_stall
);
localparam  TYPE_COND = 2'b00;//2'b00  COND   条件分支 beq/bne/blt/bge/bltu/bgeu
localparam  TYPE_JUMP = 2'b01;//2'b01  JUMP   无条件直接跳 b
localparam  TYPE_CALL = 2'b10;//2'b10  CALL   bl，或 jirl 且 rd!=0
localparam  TYPE_RET  = 2'b11;//2'b11  RET    jirl 且 rd==0
//------------------------{PC}begin-------------------------//
reg    [31:0]          pc;
wire   [31:0]          slot_pc   [ISSUE - 1 : 0];
wire   [ISSUE - 1 : 0] slot_valid;
wire   [31:0]          seq_PC     = slot_valid == 2'b11 ? pc + 8 :
                                    slot_valid == 2'b01 ? pc + 4 :
                                                          pc;
wire   [31:0]          next_PC;
genvar                 i;
/*
generate
    for (i = 0;i < ISSUE;i = i + 1) begin : gen_slot_pc
        assign slot_pc[i] = pc + 4 * i;
    end
endgenerate
*/
assign  slot_pc[0]     = pc;
assign  slot_pc[1]     = pred_redirect0 ? pred_target0 : pc + 4;
assign  slot_valid     = !preIF1_valid | preIF1_need_cancel              ? {ISSUE{1'b0}}          :
                         preIF1_ex     | ~same_cacheline | uncache_fetch ? {1'b0,{ISSUE-1{1'b1}}} :
                                                                           {ISSUE{1'b1}};
wire    same_cacheline = (slot_pc[0][31:ICACHE_OFFSET_W] == slot_pc[1][31:ICACHE_OFFSET_W]);//两条指令在同一个cacheline
assign  next_PC        = (slot_valid == 2'b11 && pred_redirect1) ? pred_target1                                            :
                         pred_redirect0                          ? (slot_valid == 2'b11 ? pred_target0 + 4 : pred_target0) :
                                                                   seq_PC;

always @(posedge clk) begin
    if (!resetn) begin
//        pc <= 32'h1bfffffc; //nextpc=1c000000
        pc <= 32'h1c000000;
    end
    else if (preIF1_need_cancel)begin
        pc <= cancel_target;
    end
    else if(preIF1_allow_in) begin
        pc <= next_PC;
    end
end

//------------------------{PC}end-------------------------//

//----------------------pred{begin}-------------------------------------------------
wire        pred_ras0      = ras_query_hit[0] && (query_type[0] == TYPE_RET);
wire        pred_btb0      = btb_query_hit[0] &&
                             ((query_type[0] == TYPE_CALL) ||
                              (query_type[0] == TYPE_JUMP) ||
                              (query_taken[0] && (query_type[0] == TYPE_COND)));
wire        pred_redirect0 = pred_ras0 || pred_btb0;
// pred_target* 仅在 pred_redirect* 为 1 时使用，未命中值无需清零。
wire [31:0] pred_target0   = pred_ras0 ? ras_query_target[0] : btb_query_target[0];

wire        pred_ras1      = ras_query_hit[1] && (query_type[1] == TYPE_RET);
wire        pred_btb1      = btb_query_hit[1] &&
                             ((query_type[1] == TYPE_CALL) ||
                              (query_type[1] == TYPE_JUMP) ||
                              (query_taken[1] && (query_type[1] == TYPE_COND)));
wire        pred_redirect1 = pred_ras1 || pred_btb1;
wire [31:0] pred_target1   = pred_ras1 ? ras_query_target[1] : btb_query_target[1];
//----------------------pred{end}-------------------------------------------------

//------------------------{uncache}begin-------------------------//
wire [1:0] inst_mat      = (csr_CRMD_DA  && !csr_CRMD_PG)                   ? csr_CRMD_DATF :
                           (!csr_CRMD_DA &&  csr_CRMD_PG &&  dmw_found0[0]) ? dmw_mat0[0]   :
                           (!csr_CRMD_DA &&  csr_CRMD_PG && !dmw_found0[0]) ? s0_mat[0]     :
                                                                              2'b0;
wire       uncache_fetch = (inst_mat == 2'b00);//uncache只发一个
//------------------------{uncache}end-------------------------//

//------------------------{branch prediction}begin------------------//
//【优·EXP11 查表的可以不用cancel信号取消，减少前递】
assign  query_valid[0] = preIF1_valid;//preIF1_valid表示指令有效
assign  query_pc[0]    = slot_pc[0];          //拿pc
//【优·EXP11 查表的可以不用cancel信号取消，减少前递】
assign  query_valid[1] = preIF1_valid & same_cacheline & ~uncache_fetch & ~preIF1_ex;//preIF1_valid表示指令有效
assign  query_pc[1]    = slot_pc[1];          //拿pc
//------------------------{branch prediction}end------------------//

//------------------------{ex}begin-------------------------//
wire  ex_ADEF[ISSUE - 1 : 0];
//assign  ex_ADEF[0] = (pc[1:0] != 2'b00);
generate
    for (i = 0; i < ISSUE; i = i + 1) begin : gen_ex_adef
        assign  ex_ADEF[i] = slot_pc[i][1:0] != 2'b00;
    end
endgenerate

wire  preIF1_ex = ex_ADEF[0] |
                  ex_tlb_reload0[0] |  
                  ex_tlb_preif_unvalid[0] |  
                  ex_tlb_plv0[0];
//------------------------{ex}end-------------------------//

//------------------------{DMW}begin-------------------------//
generate
    for (i = 0; i < ISSUE; i = i + 1) begin : gen_dmw_vseg
        assign  dmw_vseg0[i] = slot_pc[i][31:29];
    end
endgenerate
//------------------------{DMW}end-------------------------//

//------------------------{虚地址转物理地址}begin-------------------------//
generate
    for (i = 0; i < ISSUE; i = i + 1) begin : gen_tlb_query_addr
        assign  s0_vppn[i]     = slot_pc[i][31:13];
        assign  s0_va_bit12[i] = slot_pc[i][12];
    end
endgenerate
wire   [31:0] tlb_paddr   [ISSUE - 1 : 0];
//【优·EXP11 查表的可以不用cancel信号取消，减少前递】
assign        tlb_inst_req = preIF1_valid && !csr_CRMD_DA &&  csr_CRMD_PG && !dmw_found0[0];
generate
    for (i = 0;i < ISSUE;i = i + 1) begin : gen_tlb_paddr
        assign  tlb_paddr[i] = (s0_ps[i] == 6'd21) ? {s0_ppn[i][19:9], slot_pc[i][20:0]}// 4MB页
                               : {s0_ppn[i][19:0],  slot_pc[i][11:0]}; // 4KB页
    end
endgenerate
//------------------------{虚地址转物理地址}end-------------------------//

//------------------------{ready_go}begin-------------------------//

assign  preIF1_ready_go = (preIF1_IDLE_stall) ? 1'b0 : 1'b1;

always @(posedge clk) begin
    if(!resetn)begin
        preIF1_valid <= 1'b0;
    end
    else if(preIF1_allow_in)begin
        preIF1_valid <= valid_in;
    end
end

// slot0: 144bit，字段顺序必须与 Pre_IF2 解包一致（含 inst_mat）
assign  preIF1_preIF2_bus_slot0 = {
                                   slot_valid[0]    ,
                                   slot_pc[0]       ,
                                   ex_ADEF[0]       ,
                                   ex_tlb_reload0[0], ex_tlb_preif_unvalid[0], ex_tlb_plv0[0],
                                   dmw_found0[0]    , dmw_pseg0[0]           ,
                                   inst_mat         ,// 必须是本模块算的 inst_mat，不是 s0_mat
                                   tlb_paddr[0]     ,
                                   btb_query_hit[0] , btb_query_target[0]    ,
                                   ras_query_hit[0] , ras_query_target[0]    ,
                                   query_type[0]    , query_taken[0]         ,
                                   query_ghr_snap
                                  };
// slot1..: 142bit，无 inst_mat
generate
  for (i = 1; i < ISSUE; i = i + 1) begin : gen_bus1
    assign  preIF1_preIF2_bus[i] = {
                                    slot_valid[i]    ,
                                    slot_pc[i]       ,
                                    ex_ADEF[i]       ,
                                    ex_tlb_reload0[i], ex_tlb_preif_unvalid[i], ex_tlb_plv0[i],
                                    dmw_found0[i]    , dmw_pseg0[i]           ,
                                    tlb_paddr[i]     ,// 注意：这里后面不要拼 s0_mat
                                    btb_query_hit[i] , btb_query_target[i]    ,
                                    ras_query_hit[i] , ras_query_target[i]    ,
                                    query_type[i]    , query_taken[i]         ,
                                    query_ghr_snap
                                   };
  end
endgenerate
//------------------------{ready_go}end-------------------------//
endmodule
