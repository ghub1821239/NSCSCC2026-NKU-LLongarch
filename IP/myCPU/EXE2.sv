`include "csr_def.vh"
module exe2 #(
    parameter  inbus_width  = 32,
    parameter  outbus_width = 64,
    parameter  TLBNUM       = 16,
    parameter  ISSUE        = 2
)(
    input  wire                    clk,
    input  wire                    resetn,
    // control signal
    output wire                    EXE2_ready_go,
    output reg                     EXE2_valid,
    input  wire                    EXE1_EXE2_valid,
    input  wire                    EXE2_allow_in,
    // bus
    input  wire [inbus_width-1:0]  EXE1_EXE2_bus          [ISSUE - 1 : 0],
    output wire [outbus_width-1:0] EXE2_MEM_bus           [ISSUE - 1 : 0],
    //stall
    output wire [ 4:0]             EXE2_rf_dest           [ISSUE - 1 : 0],
    output wire                    need_stall_inst        [ISSUE - 1 : 0], //bus传递
    output wire                    need_stall_csr         [ISSUE - 1 : 0],  //bus传递
    //front_push
    output wire [31:0]             exe2_front_data        [ISSUE - 1 : 0],
    output wire [ 4:0]             exe2_front_addr        [ISSUE - 1 : 0],
    output wire                    exe2_can_not_front_push[ISSUE - 1 : 0],// 写回级数据前递目标不能前推
    //cancel control
    input  wire                    EXE2_need_cancel,
    input  wire                    flush,
    //ex_cancel 取消write              exe2
    input  wire                    older_ex_for_exe2,
    output wire                    EXE2_ex,
    //handshake                        exe2
    output wire                    data_sram_req,
    output wire                    data_sram_wr, // 1表示write 0表示read
    output wire [ 3:0]             data_sram_wstrb,// wstrb 对应原始数据的字节写使能
    output wire [ 1:0]             data_sram_size,
    output wire [31:0]             data_sram_addr,
    output wire [31:0]             data_sram_wdata,
    input  wire                    data_sram_addr_ok,
    input  wire                    data_sram_data_ok,
    input  wire                    MEM_allow_in,
    //uncache使用
    output wire [1:0]              data_mat,
    output wire                    data_wr,
    //cache_code                      exe2
    input  wire [1:0]              csr_CRMD_PLV,
    output wire [4:0]              cache_code,
    output wire                    cacop_valid,
    input  wire                    cacop_done,
    output wire [31:0]             cacop_pc,
    //system inst_need_cancel
    output wire                    ibar_cancel,
    output wire                    dbar_cancel,
    //CSR_LLBCTL
    output wire                    LLbit_wb,
    output wire                    LLbit_wdata,
    input  wire                    LLbit
);

//------------------------{bus解析&传递}begin-------------------------//
wire                     slot_valid_from_exe1[ISSUE - 1 : 0];
wire   [31:0]            pc                  [ISSUE - 1 : 0];
wire                     res_from_mem        [ISSUE - 1 : 0];
wire                     mem_we              [ISSUE - 1 : 0];
wire   [31:0]            alu_result_with_rdct[ISSUE - 1 : 0];

wire                     inst_ld_b           [ISSUE - 1 : 0];
wire                     inst_ld_h           [ISSUE - 1 : 0];
wire                     inst_ld_bu          [ISSUE - 1 : 0];
wire                     inst_ld_hu          [ISSUE - 1 : 0];

wire   [4:0]             rf_dest             [ISSUE - 1 : 0];
wire                     rf_gr_we            [ISSUE - 1 : 0];

// ex enum
wire                     inst_ertn           [ISSUE - 1 : 0];
wire                     inst_syscall        [ISSUE - 1 : 0];
wire                     inst_break          [ISSUE - 1 : 0];
wire                     ex_INE              [ISSUE - 1 : 0];
wire                     ex_IPE              [ISSUE - 1 : 0];
wire                     ex_ADEF             [ISSUE - 1 : 0];
wire                     ex_ALE              [ISSUE - 1 : 0];
wire                     has_int             [ISSUE - 1 : 0];

wire   [31:0]            rj_value            [ISSUE - 1 : 0];
//chapter 7 exp 12:new_add
wire                     need_stall_csr_b    [ISSUE - 1 : 0];//bus 暂存
wire                     inst_csrrd          [ISSUE - 1 : 0];
wire                     inst_csrwr          [ISSUE - 1 : 0];
wire                     inst_csrxchg        [ISSUE - 1 : 0];
wire   [13:0]            csr_num             [ISSUE - 1 : 0];

// timer_inst
wire                     inst_rdcntvl_w      [ISSUE - 1 : 0];
wire                     inst_rdcntvh_w      [ISSUE - 1 : 0];
wire                     inst_rdcntid        [ISSUE - 1 : 0];

//tlb
wire                     inst_tlbrd          [ISSUE - 1 : 0];
wire                     inst_tlbsrch        [ISSUE - 1 : 0];
wire   [10:0]            TLBIDX_new_tlbsrch  [ISSUE - 1 : 0];
wire                     inst_tlbwr          [ISSUE - 1 : 0];
wire                     inst_tlbfill        [ISSUE - 1 : 0];
wire                     inst_invtlb         [ISSUE - 1 : 0];

wire   [31:0]            rkd_value           [ISSUE - 1 : 0];
reg    [inbus_width-1:0] bus                 [ISSUE - 1 : 0];

//tlb_ex
wire                     ex_tlb_reload0      [ISSUE - 1 : 0];//tlb重填异常
wire                     ex_tlb_preif_unvalid[ISSUE - 1 : 0];//tlb的取指页无效
wire                     ex_tlb_plv0         [ISSUE - 1 : 0];//tlb的页权限上访
wire                     ex_tlb_reload1      [ISSUE - 1 : 0];//tlb重填异常
wire                     ex_tlb_ld_unvalid   [ISSUE - 1 : 0];//tlb的load页无效
wire                     ex_tlb_st_unvalid   [ISSUE - 1 : 0];//tlb的store页无效
wire                     ex_tlb_plv1         [ISSUE - 1 : 0];//tlb的页权限上访
wire                     ex_tlb_page_modify  [ISSUE - 1 : 0];//tlb的页修改
wire                     EXE1_ex             [ISSUE - 1 : 0]; // EXE1 已汇总的异常，经流水线寄存器打一拍

// 总线侧按槽暂存，后级 mux 到 data_sram_* / data_mat / data_wr / cache_code
wire   [31:0]            data_sram_addr_b    [ISSUE - 1 : 0];
wire   [31:0]            data_sram_wdata_b   [ISSUE - 1 : 0];
wire   [1:0]             data_sram_size_b    [ISSUE - 1 : 0];
wire   [3:0]             data_sram_wstrb_b   [ISSUE - 1 : 0];
wire   [1:0]             data_mat_b          [ISSUE - 1 : 0];
wire                     data_wr_b           [ISSUE - 1 : 0];
wire   [4:0]             cache_code_b        [ISSUE - 1 : 0];

wire                     inst_cacop          [ISSUE - 1 : 0];

//system inst
wire                     inst_ibar           [ISSUE - 1 : 0];
wire                     inst_dbar           [ISSUE - 1 : 0];
wire                     inst_sc_w           [ISSUE - 1 : 0];
wire                     inst_ll_w           [ISSUE - 1 : 0];

//IDLE
wire                     inst_idle           [ISSUE - 1 : 0];

genvar                   i;
generate
    for(i = 0; i < ISSUE; i = i + 1) begin : gen_EXE2_bus
        always @(posedge clk) begin
            if(!resetn) begin
                bus[i] <= {inbus_width{1'b0}};
            end
            else if (EXE1_EXE2_valid && EXE2_allow_in) begin
                bus[i] <= EXE1_EXE2_bus[i];
            end
        end
        assign {slot_valid_from_exe1[i],
                pc[i]                  ,
                rkd_value[i]           , res_from_mem[i]        , mem_we[i]          , need_stall_csr_b[i] , inst_ld_b[i]        , inst_ld_h[i]        , inst_ld_bu[i] , inst_ld_hu[i]        , alu_result_with_rdct[i],//MEM
                inst_csrrd[i]          , inst_csrwr[i]          , inst_csrxchg[i]    , inst_ertn[i]        , inst_syscall[i]     , inst_break[i]       , ex_INE[i]     , ex_IPE[i]            , ex_ADEF[i]             , ex_ALE[i]   , has_int[i]  , inst_rdcntvl_w[i], inst_rdcntvh_w[i], inst_rdcntid[i], csr_num[i], rj_value[i], rf_dest[i], rf_gr_we[i],//WB
                inst_tlbsrch[i]        , TLBIDX_new_tlbsrch[i]  , inst_tlbrd[i]      , inst_tlbwr[i]       , inst_tlbfill[i]     , inst_invtlb[i]      ,
                ex_tlb_reload0[i]      , ex_tlb_preif_unvalid[i], ex_tlb_plv0[i]     , ex_tlb_reload1[i]   , ex_tlb_ld_unvalid[i], ex_tlb_st_unvalid[i], ex_tlb_plv1[i], ex_tlb_page_modify[i],
                EXE1_ex[i]             ,
                data_sram_addr_b[i]    , data_sram_wdata_b[i]   , data_sram_size_b[i], data_sram_wstrb_b[i], data_mat_b[i]       , data_wr_b[i]        , inst_cacop[i] , cache_code_b[i]      , inst_ibar[i]           , inst_dbar[i], inst_sc_w[i], inst_ll_w[i]     , inst_idle[i]
               } = bus[i];
    end
endgenerate
//------------------------{bus解析&传递}end-------------------------//

//------------------------{mux 选择 dram signal}begin-------------------------//
wire  dram_hit[ISSUE - 1 : 0];
generate
    for(i = 0; i < ISSUE; i = i + 1) begin : gen_dram_index
        assign  dram_hit[i] = slot_valid_from_exe1[i] & (res_from_mem[i] | mem_we[i] | inst_cacop[i]);
    end
endgenerate
wire    dram_hit_any    = dram_hit[0] | dram_hit[1];
wire    dram_index      = dram_hit[0] ? 1'b0 : 1'b1; // 仅在 dram_hit_any 时有意义

assign  data_sram_addr  = data_sram_addr_b[dram_index];
assign  data_sram_wdata = data_sram_wdata_b[dram_index];
assign  data_sram_size  = data_sram_size_b[dram_index];
assign  data_sram_wstrb = data_sram_wstrb_b[dram_index];
assign  data_mat        = data_mat_b[dram_index];
assign  data_wr         = data_wr_b[dram_index];
assign  cache_code      = cache_code_b[dram_index];
//------------------------{mux 选择 dram signal}end-------------------------//

//------------------------{ll&sc}begin-------------------------//
reg    [29:0] LLaddr;
wire          sc_success;
wire          ll_finish;
wire          sc_finish;

assign        sc_success = LLbit && (data_sram_addr[31:2] == LLaddr);

assign        ll_finish  = EXE2_valid & dram_hit_any && inst_ll_w[dram_index] &&
                           data_sram_req && data_sram_addr_ok &&
                           ~EXE2_need_cancel;

assign        sc_finish  = EXE2_valid && dram_hit_any && inst_sc_w[dram_index] &&
                           EXE2_ready_go && MEM_allow_in &&//SC 完成（改 LLbit）必须发生在指令真正离开 EXE2 的那一拍
                           ~older_ex_for_exe2 &&
                           ~EXE2_need_cancel && ~(dram_index & EXE2_slot_ex[0]);//第一个 为 sc 的时候不能为 ex ；第二个为 sc 访问的时候也不能为 ex

always @(posedge clk) begin
    if (!resetn)
        LLaddr <= 30'b0;
    else if (ll_finish)
        LLaddr <= dram_index == 1'b0 ? data_sram_addr_b[0][31:2] : data_sram_addr_b[1][31:2];
end

assign  LLbit_wb    = ll_finish | sc_finish;
assign  LLbit_wdata = ll_finish;  // LL置1写完后SC清零
//------------------------{ll&sc}end-------------------------//\

//------------------------{读写req&addr_ok}begin-------------------------//
reg  req_without_dataok;
always @ (posedge clk)begin
    if(!resetn)begin
        req_without_dataok <= 1'b0;
    end 
    else if (data_sram_data_ok)begin
        req_without_dataok <= 1'b0;
    end
    else if(data_sram_req & data_sram_addr_ok)begin
        req_without_dataok <= 1'b1;
    end
end
//------------------------{读写req&addr_ok}end-------------------------//

//------------------------{need_stall_inst}begins-------------------------//
generate
    for(i = 0; i < ISSUE; i = i + 1) begin : gen_need_stall_inst
        assign  need_stall_inst[i] = EXE2_valid & slot_valid_from_exe1[i] & res_from_mem[i];
        assign  need_stall_csr[i]  = EXE2_valid & slot_valid_from_exe1[i] & need_stall_csr_b[i];
    end
endgenerate
//------------------------{need_stall_inst}end-------------------------//

//------------------------{i/dbar need cancel}begins-------------------------//
// 因为已经限定了 i/dbar 只可能由 slot0 触发
assign  ibar_cancel = inst_ibar[0] & slot_valid_from_exe1[0] & EXE2_valid & ~older_ex_for_exe2 & ~flush;
assign  dbar_cancel = inst_dbar[0] & slot_valid_from_exe1[0] & EXE2_valid & ~older_ex_for_exe2 & ~flush;
//------------------------{i/dbar need cancel}end-------------------------//

//------------------------{dataRAM handshake}begin-------------------------//
wire    EXE2_slot_ex [ISSUE - 1 : 0];
assign  data_sram_req = dram_hit_any & (res_from_mem[dram_index] | mem_we[dram_index])
                                     & ~req_without_dataok & MEM_allow_in & ~(inst_sc_w[dram_index] & ~sc_success)
                                     & ~EXE2_slot_ex[dram_index] & ~(dram_index & EXE2_slot_ex[0]) & ~older_ex_for_exe2 & ~EXE2_need_cancel & EXE2_valid;
assign  data_sram_wr  = |data_sram_wstrb;

assign  cacop_valid   = EXE2_valid & inst_cacop[dram_index] & ~EXE2_slot_ex[dram_index] & ~older_ex_for_exe2 & slot_valid_from_exe1[dram_index] &
                        (cache_code[4:3] == 2'b10 | csr_CRMD_PLV == 2'b00) & ~(dram_index & EXE2_slot_ex[0]) & ~EXE2_need_cancel; // 在 slot1 是 cacop slot0 不能异常
assign  cacop_pc      = pc[dram_index] + 4;
//------------------------{dataRAM handshake}end-------------------------//

//------------------------{front_push}begin-------------------------//
generate
    for(i = 0; i < ISSUE; i = i + 1) begin : gen_EXE2_ex
        assign  exe2_front_data[i]         = inst_sc_w[i] ? {31'b0, sc_success} :
                                             mem_we[i]    ? rkd_value[i] :
                                             alu_result_with_rdct[i];
        assign  exe2_front_addr[i]         = rf_dest[i];
        assign  exe2_can_not_front_push[i] = ~rf_gr_we[i]       | ~slot_valid_from_exe1[i] |
                                             need_stall_inst[i] |  need_stall_csr[i];
        assign  EXE2_slot_ex[i]            = EXE2_valid & slot_valid_from_exe1[i] & EXE1_ex[i];
        assign  EXE2_rf_dest[i]            = rf_dest[i];
    end
endgenerate
assign  EXE2_ex = EXE2_slot_ex[0] | EXE2_slot_ex[1];
//------------------------{front_push}end-------------------------//

//------------------------{ready_go}begin-------------------------//
assign  EXE2_ready_go = (EXE2_ex      | older_ex_for_exe2) ? 1'b1 : // 如果有异常直接走
                        cacop_valid   ? cacop_done                : // 如果是 cache 操作就要等 done
                        (dram_hit_any & (res_from_mem[dram_index] | (mem_we[dram_index] & ~(inst_sc_w[dram_index] & ~sc_success))))
                        ? (data_sram_addr_ok & data_sram_req)     :
                        1'b1;// 如果是访存 mem 就要等 addr_ok 和 req 都满足

always @(posedge clk) begin
    if(!resetn)begin
        EXE2_valid <= 1'b0;
    end
    else if(EXE2_need_cancel)begin
        EXE2_valid <= 1'b0;
    end
    else if(EXE2_allow_in)begin
        EXE2_valid <= EXE1_EXE2_valid;
    end
end
//------------------------{ready_go}end-------------------------//

//------------------------{bus}begin-------------------------//
generate
    for(i = 0; i < ISSUE; i = i + 1) begin : gen_EXE2_MEM_bus
        assign  EXE2_MEM_bus[i] = {
                                   slot_valid_from_exe1[i],
                                   pc[i]                  ,
                                   rkd_value[i]           , res_from_mem[i]            , mem_we[i]      , need_stall_csr_b[i], inst_ld_b[i]        , inst_ld_h[i]        , inst_ld_bu[i] , inst_ld_hu[i]        , data_sram_addr_b[i][1:0], alu_result_with_rdct[i],//MEM
                                   inst_csrrd[i]          , inst_csrwr[i]              , inst_csrxchg[i], inst_ertn[i]       , inst_syscall[i]     , inst_break[i]       , ex_INE[i]     , ex_IPE[i]            , ex_ADEF[i]              , ex_ALE[i]              , has_int[i], inst_rdcntvl_w[i], inst_rdcntvh_w[i], inst_rdcntid[i], csr_num[i], rj_value[i], rf_dest[i], rf_gr_we[i],//WB
                                   inst_tlbsrch[i]        , TLBIDX_new_tlbsrch[i]      , inst_tlbrd[i]  , inst_tlbwr[i]      , inst_tlbfill[i]     , inst_invtlb[i]      ,
                                   ex_tlb_reload0[i]      , ex_tlb_preif_unvalid[i]    , ex_tlb_plv0[i] , ex_tlb_reload1[i]  , ex_tlb_ld_unvalid[i], ex_tlb_st_unvalid[i], ex_tlb_plv1[i], ex_tlb_page_modify[i],
                                   inst_sc_w[i]           , (inst_sc_w[i] & sc_success), inst_idle[i]
                                  };
    end
endgenerate
//------------------------{bus}end-------------------------//
endmodule