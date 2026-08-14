`include "csr_def.vh"
module wb #(
    parameter  inbus_width = 222,
    parameter  ISSUE       = 2
)(
    input  wire                   clk,
    input  wire                   resetn,
    // 流水线控制信号
    input  wire                   MEM_WB_valid,
    input  wire                   WB_allow_in,
    output wire                   WB_ready_go,
    output reg                    WB_valid,
    
    input  wire [inbus_width-1:0] MEM_WB_bus           [ISSUE - 1 : 0],// MEM到WB的总线
    // 调试接口
    //考虑是否需要添加更多debug接口
    output wire [31:0]            debug_wb_pc,
    output wire [ 3:0]            debug_wb_rf_we,
    output wire [ 4:0]            debug_wb_rf_wnum,
    output wire [31:0]            debug_wb_rf_wdata,
    output wire [ISSUE-1:0]       debug_commit_valid,
    output wire [ISSUE-1:0]       debug_commit_exception,
    output wire [ISSUE*32-1:0]    debug_commit_pc,
    output wire [ISSUE*4-1:0]     debug_commit_rf_wen,
    output wire [ISSUE*5-1:0]     debug_commit_rf_wnum,
    output wire [ISSUE*32-1:0]    debug_commit_rf_wdata,
    // 通用寄存器堆写回接口
    output wire [ 4:0]            rf_waddr             [ISSUE - 1 : 0],
    output wire [31:0]            rf_wdata             [ISSUE - 1 : 0],
    output wire                   rf_we                [ISSUE - 1 : 0],
    // 数据冒险停顿相关控制
    output wire [ 4:0]            WB_rf_dest           [ISSUE - 1 : 0],
    output wire                   need_stall_csr       [ISSUE - 1 : 0],
    // 写回级数据前推
    output wire [31:0]            wb_front_data        [ISSUE - 1 : 0],
    output wire [ 4:0]            wb_front_addr        [ISSUE - 1 : 0],
    // CSR读写接口
    output wire [13:0]            csr_num,
    output wire                   csr_re,
    input  wire [31:0]            csr_rvalue,
    output wire                   csr_we,
    output wire [31:0]            csr_wdata,
    output wire [31:0]            csr_wmask,
    // ERTN或异常发生时刷新流水线，并给出跳转目标
    output wire                   flush,
    output wire [31:0]            flush_target,
    // 流水线取消信号
    input  wire                   WB_need_cancel,
    // 异常信息
    output wire [31:0]            wb_pc,
    output wire                   wb_ex,
    output wire [5:0]             ecode,
    output wire [8:0]             esubcode,
    output wire [31:0]            wb_vaddr,
    // 当前级是否有异常取消信号
    output wire                   WB_ex,
    // tlbrd 写到csr的写使能
    output wire                   tlbrd_we,
    // tlbwr,tlbfill 写到tlb写使能
    output wire                   tlbwr_we,
    output wire                   tlbfill_we,
    // tlbidx
    input  wire [31:0]            csr_TLBIDX,
    //tlbreload 结果传给CSR
    output wire                   ex_tlb_reload,
    // ERTN恢复时的CRMD
    output wire                   ertn_valid,
    // BADV
    output wire                   csr_tlb_reload0,
    output wire                   csr_tlb_plv0,//tlb中页特权不合规
    output wire                   csr_tlb_reload1,//tlb重填例外  
    output wire                   csr_tlb_plv1,    //tlb中页特权不合规 
    // ex_tlb --> TLBEHI
    output wire                   ex_tlb,
    //can_not_front_push
    output wire                   wb_can_not_front_push[ISSUE - 1 : 0],
    //IDLE
    input  wire                   csr_has_int,
    input  wire                   csr_tcfg_init0, // TCFG.InitVal==0
    output wire                   IDLE_stall
);
wire                   slot_valid          [ISSUE - 1 : 0];
wire [31:0]            pc                  [ISSUE - 1 : 0];
wire                   need_stall_csr_b    [ISSUE - 1 : 0];

wire                   rf_gr_we_ex         [ISSUE - 1 : 0];
wire [4:0]             rf_dest             [ISSUE - 1 : 0];
wire [31:0]            rf_alu_wdata        [ISSUE - 1 : 0];
wire [31:0]            rkd_value           [ISSUE - 1 : 0];
wire [31:0]            rj_value            [ISSUE - 1 : 0];
wire                   mem_we              [ISSUE - 1 : 0];
wire [31:0]            alu_result_with_rdct[ISSUE - 1 : 0];
reg  [inbus_width-1:0] bus                 [ISSUE - 1 : 0];

//-------------CSR-------------
wire        inst_csrrd          [ISSUE - 1 : 0];
wire        inst_csrwr          [ISSUE - 1 : 0];
wire        inst_csrxchg        [ISSUE - 1 : 0];
wire [13:0] csr_num_wr          [ISSUE - 1 : 0];
// 异常相关标志
wire        inst_syscall        [ISSUE - 1 : 0];
wire        inst_break          [ISSUE - 1 : 0];
wire        ex_INE              [ISSUE - 1 : 0];
wire        ex_IPE              [ISSUE - 1 : 0];
wire        ex_ADEF             [ISSUE - 1 : 0];
wire        ex_ALE              [ISSUE - 1 : 0];
//tlb_ex
wire        ex_tlb_reload0      [ISSUE - 1 : 0];//tlb重填例外
wire        ex_tlb_preif_unvalid[ISSUE - 1 : 0];//tlb中取指页无效
wire        ex_tlb_plv0         [ISSUE - 1 : 0];//tlb中页特权不合规
wire        ex_tlb_reload1      [ISSUE - 1 : 0];//tlb重填例外        
wire        ex_tlb_ld_unvalid   [ISSUE - 1 : 0];//tlb中load页无效 
wire        ex_tlb_st_unvalid   [ISSUE - 1 : 0];//tlb中store页无效
wire        ex_tlb_plv1         [ISSUE - 1 : 0];//tlb中页特权不合规        
wire        ex_tlb_page_modify  [ISSUE - 1 : 0];//tlb中页修改
wire        ex_tlb_plv          [ISSUE - 1 : 0];     
// 空闲等待取指令
wire        inst_idle           [ISSUE - 1 : 0];
wire        inst_ertn           [ISSUE - 1 : 0];

wire        has_int             [ISSUE - 1 : 0];

//**************** tlb begin ****************
wire        inst_rdcntvl_w[ISSUE - 1 : 0];
wire        inst_rdcntvh_w[ISSUE - 1 : 0];
wire        inst_rdcntid[ISSUE - 1 : 0];


wire        inst_tlbsrch[ISSUE - 1 : 0];
wire        inst_tlbrd[ISSUE - 1 : 0];
wire [10:0] TLBIDX_new_tlbsrch[ISSUE - 1 : 0];
wire        inst_tlbwr[ISSUE - 1 : 0];
wire        inst_tlbfill[ISSUE - 1 : 0];
wire        inst_invtlb[ISSUE - 1 : 0];
//**************** tlb end ****************

integer k;
always @(posedge clk) begin
    if(!resetn)begin
        for (k = 0; k < ISSUE; k = k + 1) begin
            bus[k] <= {inbus_width{1'b0}};
        end
    end
    else if(MEM_WB_valid & WB_allow_in)begin
        for (k = 0; k < ISSUE; k = k + 1) begin
            bus[k] <= MEM_WB_bus[k];
        end
    end
end

genvar gi;
generate
    for (gi = 0; gi < ISSUE; gi = gi + 1) begin
        assign {
        slot_valid[gi],
        pc[gi], need_stall_csr_b[gi], alu_result_with_rdct[gi],
        inst_csrrd[gi], inst_csrwr[gi], inst_csrxchg[gi], inst_ertn[gi],
        inst_syscall[gi], inst_break[gi], ex_INE[gi], ex_IPE[gi],
        ex_ADEF[gi], ex_ALE[gi], has_int[gi],
        inst_rdcntvl_w[gi], inst_rdcntvh_w[gi], inst_rdcntid[gi], csr_num_wr[gi],
        mem_we[gi], rj_value[gi], rkd_value[gi],
        rf_dest[gi], rf_alu_wdata[gi], rf_gr_we_ex[gi],
        inst_tlbsrch[gi], TLBIDX_new_tlbsrch[gi],
        inst_tlbrd[gi], inst_tlbwr[gi], inst_tlbfill[gi], inst_invtlb[gi],
        ex_tlb_reload0[gi], ex_tlb_preif_unvalid[gi], ex_tlb_plv0[gi],
        ex_tlb_reload1[gi], ex_tlb_ld_unvalid[gi], ex_tlb_st_unvalid[gi],
        ex_tlb_plv1[gi], ex_tlb_page_modify[gi],
        inst_idle[gi]
    } = bus[gi];
    end
endgenerate
// tlb 异常

//---------------------------{slot_ex}begin---------------------------------//
wire ex_slot     [ISSUE - 1 : 0];//slot中是否有异常（含tlb）
wire ex_slot_tlb [ISSUE - 1 : 0];//slot中是否有tlb异常（后面没有单独用到）
generate
    for (gi = 0; gi < ISSUE; gi = gi + 1) begin
        assign ex_slot_tlb[gi]  = ex_tlb_reload0[gi] | ex_tlb_preif_unvalid[gi] | ex_tlb_plv0[gi] |
                                  ex_tlb_reload1[gi] | ex_tlb_ld_unvalid[gi]    | ex_tlb_st_unvalid[gi] |
                                  ex_tlb_plv1[gi]    | ex_tlb_page_modify[gi];
        assign ex_slot[gi]      = inst_syscall[gi] | inst_break[gi] | ex_INE[gi] | ex_IPE[gi] |
                                  ex_ADEF[gi]      | ex_ALE[gi]     | (has_int[gi] & ~inst_idle[gi]) |
                                  ex_slot_tlb[gi];
    end
endgenerate
//---------------------------{slot_ex}end---------------------------------//

//------------------------{IDLE}begin-------------------------//
// golden / 参考模型：
// - TCFG.InitVal==0：写 TCFG 立即产生 TI，IDLE 变为“抢占”，ERA = IDLE
// - 正常（固定定时器在流水线中到期）：IDLE 以进入等待结束，ERA = IDLE+4
//   （本流水线 timer=0x4 只有 4 拍，TI 可能在 IDLE 提交前就置位，故用本拍 csr_has_int 判断）
reg         is_idle;
reg  [31:0] idle_era_r;
wire        idle_ex_other;
wire        idle_valid;
wire        idle_wake_ex;
wire        idle_preempt; // timer=0 时抢占

assign idle_ex_other = inst_syscall[0] | inst_break[0] | ex_INE[0] | ex_IPE[0] | ex_ADEF[0] | ex_ALE[0] |
                       ex_tlb_reload0[0] | ex_tlb_preif_unvalid[0] | ex_tlb_plv0[0] |
                       ex_tlb_reload1[0] | ex_tlb_ld_unvalid[0] | ex_tlb_st_unvalid[0] |
                       ex_tlb_plv1[0] | ex_tlb_page_modify[0];
assign idle_valid    = inst_idle[0] & slot_valid[0] & WB_valid & ~idle_ex_other;
assign idle_preempt  = idle_valid & csr_has_int & csr_tcfg_init0; // 提交时已有 TI(InitVal=0)
assign idle_wake_ex  = is_idle & csr_has_int;
// 抢占路径直接取中断，不进 is_idle；正常等待唤醒走 idle_wake_ex
wire   idle_ex       = idle_preempt | idle_wake_ex;

always @(posedge clk) begin
    if (~resetn) begin
        is_idle    <= 1'b0;
        idle_era_r <= 32'b0;
    end
    else if (idle_wake_ex) begin
        is_idle <= 1'b0;
    end
    else if (idle_valid) begin
        if (csr_has_int & csr_tcfg_init0) begin
            // idle 与抢占中断同时到来，不进 idle，ERA=IDLE
            is_idle    <= 1'b0;
            idle_era_r <= pc[0];
        end
        else begin
            // 正常进入等待
            is_idle    <= 1'b1;
            idle_era_r <= pc[0] + 32'd4;
        end
    end
end
//------------------------{IDLE}end-------------------------//

//-------------------------------------{slot_fire}begin--------------------------------//
wire slot0_present      = WB_valid & slot_valid[0];//选择slot0
wire slot1_present      = (ISSUE >= 2) & WB_valid & slot_valid[1];//选择slot1

wire slot0_trap         = slot0_present & (ex_slot[0] | idle_ex);//slot0选中且有异常
wire slot0_system_break = slot0_present & (inst_ertn[0] | inst_csrwr[0] | inst_csrxchg[0] |
                                           inst_tlbsrch[0] | inst_tlbrd[0] | inst_tlbwr[0] |
                                           inst_tlbfill[0] | inst_idle[0]);

wire slot_fire[ISSUE - 1 : 0];
assign slot_fire[0]     = slot0_present;//发射slot0
assign slot_fire[1]     = slot1_present & ~slot0_trap & ~slot0_system_break;//发射slot1

//-------------------------------------{slot_fire}end--------------------------------//

//-------------------------------------{异常选择slot0优先}begin-------------------------------------//
wire take_ex0 = slot_fire[0] & (ex_slot[0] | idle_ex);
wire take_ex1 = slot_fire[1] & ex_slot[1];//idle不允许走slot1,只允许slot0

// 用于 ecode 的“活跃异常源”标志（避免重复仲裁）
wire x_inst_syscall = take_ex0 ? inst_syscall[0] : (take_ex1 ? inst_syscall[1] : 1'b0);
wire x_inst_break   = take_ex0 ? inst_break[0]   : (take_ex1 ? inst_break[1]   : 1'b0);
wire x_ex_INE       = take_ex0 ? ex_INE[0]       : (take_ex1 ? ex_INE[1]       : 1'b0);
wire x_ex_IPE       = take_ex0 ? ex_IPE[0]       : (take_ex1 ? ex_IPE[1]       : 1'b0);
wire x_ex_ADEF      = take_ex0 ? ex_ADEF[0]      : (take_ex1 ? ex_ADEF[1]      : 1'b0);
wire x_ex_ALE       = take_ex0 ? ex_ALE[0]       : (take_ex1 ? ex_ALE[1]       : 1'b0);
wire x_has_int      = take_ex0 ? (has_int[0] & ~inst_idle[0]) :
                      take_ex1 ? (has_int[1] & ~inst_idle[1]) : 1'b0;
wire x_ex_tlb_reload0      = take_ex0 ? ex_tlb_reload0[0]      : (take_ex1 ? ex_tlb_reload0[1]      : 1'b0);
wire x_ex_tlb_preif_unvalid= take_ex0 ? ex_tlb_preif_unvalid[0]: (take_ex1 ? ex_tlb_preif_unvalid[1]: 1'b0);
wire x_ex_tlb_plv0         = take_ex0 ? ex_tlb_plv0[0]         : (take_ex1 ? ex_tlb_plv0[1]         : 1'b0);
wire x_ex_tlb_reload1      = take_ex0 ? ex_tlb_reload1[0]      : (take_ex1 ? ex_tlb_reload1[1]      : 1'b0);
wire x_ex_tlb_ld_unvalid   = take_ex0 ? ex_tlb_ld_unvalid[0]   : (take_ex1 ? ex_tlb_ld_unvalid[1]   : 1'b0);
wire x_ex_tlb_st_unvalid   = take_ex0 ? ex_tlb_st_unvalid[0]   : (take_ex1 ? ex_tlb_st_unvalid[1]   : 1'b0);
wire x_ex_tlb_plv1         = take_ex0 ? ex_tlb_plv1[0]         : (take_ex1 ? ex_tlb_plv1[1]         : 1'b0);
wire x_ex_tlb_page_modify  = take_ex0 ? ex_tlb_page_modify[0]  : (take_ex1 ? ex_tlb_page_modify[1]  : 1'b0);
wire [31:0] x_pc           = take_ex0 ? pc[0] : (take_ex1 ? pc[1] : pc[0]);
wire [31:0] x_vaddr        = take_ex0 ? alu_result_with_rdct[0] :
                             take_ex1 ? alu_result_with_rdct[1] : alu_result_with_rdct[0];

//-------------------------------------{异常选择slot0优先}end-------------------------------------//

//------------------------------{csr端口}begin--------------------------------//
wire   csr_port[ISSUE - 1 : 0];//要修改csr的指令和异常
generate
    for (gi = 0; gi < ISSUE; gi = gi + 1) begin : gen_csr_need
        assign csr_port[gi] = slot_fire[gi] & (inst_csrrd[gi] | inst_csrwr[gi] | inst_csrxchg[gi] | inst_rdcntid[gi] |
        inst_ertn[gi] | inst_tlbsrch[gi] | inst_tlbrd[gi] | inst_tlbwr[gi] |
        inst_tlbfill[gi] | inst_idle[gi] | ex_slot[gi]);
    end
endgenerate
wire   csr_select_slot    = wb_ex  ? (take_ex1 ? 1'b1 : 1'b0) ://take_ex1为1则选slot[1],否则选slot[0],默认选slot0
                            csr_port[0] ? 1'b0     :
                            (ISSUE >= 2 & csr_port[1]) ? 1'b1     :
                            1'b0;//选择是slot0还是slot1：0为slot0,1为slot1；后面用活跃仲裁：x_*表示异常相关,s_*表示指令相关,

wire [31:0] s_pc          = pc[csr_select_slot];
wire        s_csrrd       = inst_csrrd[csr_select_slot];
wire        s_csrwr       = inst_csrwr[csr_select_slot];
wire        s_csrxchg     = inst_csrxchg[csr_select_slot];
wire        s_ertn        = inst_ertn[csr_select_slot];
wire        s_syscall     = inst_syscall[csr_select_slot];
wire        s_break       = inst_break[csr_select_slot];
wire        s_INE         = ex_INE[csr_select_slot];
wire        s_IPE         = ex_IPE[csr_select_slot];
wire        s_ADEF        = ex_ADEF[csr_select_slot];
wire        s_ALE         = ex_ALE[csr_select_slot];
wire        s_has_int     = has_int[csr_select_slot];
wire        s_rdcntid     = inst_rdcntid[csr_select_slot];
wire [13:0] s_csr_num_wr  = csr_num_wr[csr_select_slot];
wire [31:0] s_rj          = rj_value[csr_select_slot];
wire [31:0] s_rkd         = rkd_value[csr_select_slot];
wire        s_tlbsrch     = inst_tlbsrch[csr_select_slot];
wire [10:0] s_TLBIDX_new_tlbsrch  = TLBIDX_new_tlbsrch[csr_select_slot];
wire        s_tlbrd       = inst_tlbrd[csr_select_slot];
wire        s_tlbwr       = inst_tlbwr[csr_select_slot];
wire        s_tlbfill     = inst_tlbfill[csr_select_slot];
wire        s_idle        = inst_idle[csr_select_slot];
wire        s_ex_tlb_preif= ex_tlb_preif_unvalid[csr_select_slot];
wire        s_ex_tlb_plv0 = ex_tlb_plv0[csr_select_slot];
wire        s_ex_tlb_re0  = ex_tlb_reload0[csr_select_slot];
wire        s_ex_tlb_re1  = ex_tlb_reload1[csr_select_slot];
wire        s_ex_tlb_plv1 = ex_tlb_plv1[csr_select_slot];
wire        s_ex_tlb_ld   = ex_tlb_ld_unvalid[csr_select_slot];
wire        s_ex_tlb_st   = ex_tlb_st_unvalid[csr_select_slot];
wire        s_ex_tlb_mod  = ex_tlb_page_modify[csr_select_slot];       

wire   s_no_ex    = wb_ex ? 1'b0 : ~(ex_slot[csr_select_slot]);//选中的slot没有异常
wire   s_slot_ok  = wb_ex ? (take_ex0 | take_ex1 | idle_ex) : csr_port[csr_select_slot];//选中的slot是有效的：要么有异常，要么是要修改csr的指令

wire        csr_WB_rd;
wire        csr_rd_WB_each;

assign csr_WB_rd  = s_slot_ok & ~wb_ex & (s_csrrd | s_csrwr | s_csrxchg | s_rdcntid);//要把csr写入rd的
assign csr_rd_WB_each = s_slot_ok & s_no_ex & ~wb_ex & (s_csrwr | s_csrxchg);//要把rd写入csr的

assign csr_wmask  = (s_csrwr | s_tlbsrch) ? 32'hffffffff : s_rj;
assign csr_wdata  = s_tlbsrch ? {s_TLBIDX_new_tlbsrch[10],csr_TLBIDX[30:10],s_TLBIDX_new_tlbsrch[9:0]} : s_rkd;
assign csr_we     = (s_tlbsrch | csr_rd_WB_each) & s_slot_ok & ~wb_ex & s_no_ex & WB_valid;

assign csr_re     = ((csr_WB_rd | flush) & WB_valid) | idle_wake_ex;

// csr_num_wr是MEM传来的指令原始CSR编号；ERTN、异常、RDCNTID等在WB重新选择目标CSR
assign csr_num    = idle_ex                            ? `CSR_EENTRY      :
                    x_has_int                          ? `CSR_EENTRY      :
                    x_ex_ADEF                          ? `CSR_EENTRY      :
                    x_ex_tlb_preif_unvalid             ? `CSR_EENTRY      :
                    x_ex_tlb_plv0                      ? `CSR_EENTRY      :
                    x_ex_tlb_reload0                   ? `CSR_TLBRENTRY   :
                    x_ex_INE                           ? `CSR_EENTRY      :
                    x_ex_IPE                           ? `CSR_EENTRY      :
                    (s_idle & s_slot_ok & ~wb_ex)      ? `CSR_EENTRY      :
                    x_inst_syscall                     ? `CSR_EENTRY      :
                    x_inst_break                       ? `CSR_EENTRY      :
                    (s_ertn & s_slot_ok & ~wb_ex)      ? `CSR_ERA         : 
                    x_ex_ALE                           ? `CSR_EENTRY      :
                    x_ex_tlb_plv1                      ? `CSR_EENTRY      :
                    x_ex_tlb_reload1                   ? `CSR_TLBRENTRY   :
                    x_ex_tlb_ld_unvalid                ? `CSR_EENTRY      :
                    x_ex_tlb_st_unvalid                ? `CSR_EENTRY      :
                    x_ex_tlb_page_modify               ? `CSR_EENTRY      :
                    (s_rdcntid & s_slot_ok & ~wb_ex)   ? `CSR_TID         : 
                    (s_tlbsrch & s_slot_ok & ~wb_ex)   ? `CSR_TLBIDX      : 
                                                         s_csr_num_wr;

assign flush        = (((s_ertn | s_csrwr | s_csrxchg | s_tlbfill | s_tlbwr | s_tlbrd | s_tlbsrch | s_idle) & s_slot_ok & ~wb_ex) |
                      wb_ex) & WB_valid |
                      idle_wake_ex;
assign flush_target = wb_ex ? csr_rvalue :
                      (s_csrwr | s_csrxchg | s_tlbfill |
                       s_tlbwr | s_tlbrd | s_tlbsrch | s_idle)
                      ? (s_pc + 32'd4)
                      : csr_rvalue;
//tlb output
assign tlbrd_we   = s_tlbrd   & WB_valid & ~wb_ex & s_slot_ok & s_no_ex;
assign tlbwr_we   = s_tlbwr   & WB_valid & ~wb_ex & s_slot_ok & s_no_ex;
assign tlbfill_we = s_tlbfill & WB_valid & ~wb_ex & s_slot_ok & s_no_ex;

assign ecode      = idle_ex | (x_has_int & ~idle_ex)   ? `ECODE_INT  :
                    x_ex_ADEF                          ? `ECODE_ADE  :
                    x_ex_tlb_preif_unvalid             ? `ECODE_PIF  :
                    x_ex_tlb_plv0                      ? `ECODE_PPI  :
                    x_ex_tlb_reload0                   ? `ECODE_TLBR :
                    x_ex_INE                           ? `ECODE_INE  :
                    x_ex_IPE                           ? `ECODE_IPE  :
                    x_inst_syscall                     ? `ECODE_SYS  :
                    x_inst_break                       ? `ECODE_BRK  :
                    x_ex_ALE                           ? `ECODE_ALE  :
                    x_ex_tlb_plv1                      ? `ECODE_PPI  :
                    x_ex_tlb_reload1                   ? `ECODE_TLBR :
                    x_ex_tlb_ld_unvalid                ? `ECODE_PIL  :
                    x_ex_tlb_st_unvalid                ? `ECODE_PIS  :
                    x_ex_tlb_page_modify               ? `ECODE_PME  :
                                                       6'b0;

assign esubcode    = idle_ex | (x_has_int & ~idle_ex)   ? `ESUBCODE_INT   : 
                     x_ex_ADEF                          ? `ESUBCODE_ADEF  :
                     x_ex_tlb_preif_unvalid             ? `ESUBCODE_PIF   : 
                     x_ex_tlb_plv0                      ? `ESUBCODE_PPI   :
                     x_ex_tlb_reload0                   ? `ESUBCODE_TLBR  :
                     x_ex_INE                           ? `ESUBCODE_INE   :
                     x_ex_IPE                           ? `ESUBCODE_IPE   :
                     x_inst_syscall                     ? `ESUBCODE_SYS   :  
                     x_inst_break                       ? `ESUBCODE_BRK   :  
                     x_ex_ALE                           ? `ESUBCODE_ALE   :
                     x_ex_tlb_plv1                      ? `ESUBCODE_PPI   :
                     x_ex_tlb_reload1                   ? `ESUBCODE_TLBR  :
                     x_ex_tlb_ld_unvalid                ? `ESUBCODE_PIL   : 
                     x_ex_tlb_st_unvalid                ? `ESUBCODE_PIS   : 
                     x_ex_tlb_page_modify               ? `ESUBCODE_PME   :
                                                        9'b0;


assign ex_tlb_reload   = WB_valid & (ecode == `ECODE_TLBR);
assign ex_tlb          = WB_valid & ((ecode == `ECODE_PIF)  |
                                   (ecode == `ECODE_PPI)  |
                                   (ecode == `ECODE_TLBR) |
                                   (ecode == `ECODE_PIL)  |
                                   (ecode == `ECODE_PIS)  |
                                   (ecode == `ECODE_PME));
//assign ex_tlb_plv      = ex_tlb_plv0 | ex_tlb_plv1;
assign csr_tlb_reload0 = x_ex_tlb_reload0 & WB_valid;
assign csr_tlb_plv0    = x_ex_tlb_plv0    & WB_valid;
assign csr_tlb_reload1 = x_ex_tlb_reload1 & WB_valid;
assign csr_tlb_plv1    = x_ex_tlb_plv1    & WB_valid;
//------------------------------{csr端口}end--------------------------------//

//-------------------------------{rf双写}begin------------------------------//
generate
    for (gi = 0; gi < ISSUE; gi = gi + 1) begin : gen_rf
        wire if_csr_write_in_rd = (inst_csrrd[gi] | inst_csrwr[gi] | inst_csrxchg[gi] | inst_rdcntid[gi]) &
                                  slot_fire[gi] & ~ex_slot[gi] & ~idle_ex;//命中该slot时，csr是否要写入rd
        wire if_use_csr_rdata   = if_csr_write_in_rd & ((gi == 0 & ~csr_select_slot) | (gi == 1 & csr_select_slot)) & csr_WB_rd;//是否使用csr_rdata

        assign rf_wdata[gi]     = if_use_csr_rdata ? csr_rvalue : rf_alu_wdata[gi];
        assign rf_waddr[gi]     = rf_dest[gi];
        assign rf_we[gi]        = rf_gr_we_ex[gi] & slot_fire[gi] & ~ex_slot[gi] & ~idle_ex &
                                  (~if_csr_write_in_rd | if_use_csr_rdata);//最后一个括号是防止年轻指令异常抢占年老csr指令写入rd
    end
endgenerate
//-------------------------------{rf双写}end------------------------------//

//--------------------------------{前推}begin-------------------------------//
generate
        for (gi = 0; gi < ISSUE; gi = gi + 1) begin : gen_fwd
            assign WB_rf_dest[gi]            = slot_fire[gi] ? rf_dest[gi] : 5'b0;
            assign need_stall_csr[gi]        = need_stall_csr_b[gi] & slot_fire[gi];
            assign wb_front_addr[gi]         = slot_fire[gi] ? rf_dest[gi] : 5'b0;
            assign wb_front_data[gi]         = slot_fire[gi] ? rf_wdata[gi]: 32'b0;
            assign wb_can_not_front_push[gi] = ~rf_gr_we_ex[gi] | ~slot_fire[gi] | ex_slot[gi] | ~rf_we[gi];
        end
endgenerate
//--------------------------------{前推}end-------------------------------//

//--------------------------------{WB}begin---------------------------------//

// IDLE 不走流水线 has_int；抢占用 pc，唤醒用 idle_era_r
assign wb_pc      = idle_preempt ? pc[0] :
                    idle_wake_ex ? idle_era_r :
                              x_pc;
assign wb_ex      = take_ex0 | take_ex1 | idle_ex;
assign wb_vaddr   = x_vaddr;

assign WB_ready_go     = 1'b1;
always @(posedge clk) begin
    if(!resetn)begin
        WB_valid <= 1'b0;
    end
    else if(WB_need_cancel)begin
        WB_valid <= 1'b0;
    end
    else if(WB_allow_in)begin
        WB_valid <= MEM_WB_valid;
    end
end

assign ertn_valid = s_ertn & s_slot_ok & s_no_ex & ~wb_ex & WB_valid;

// 本拍组合停取指，避免晚一拍
assign IDLE_stall = (idle_valid & ~csr_has_int) | (is_idle & ~csr_has_int);

assign WB_ex = wb_ex |
               (s_slot_ok & s_no_ex & (s_ertn | s_syscall | s_break | s_INE |
                s_IPE | s_ADEF | s_ALE | (s_has_int & ~s_idle)));
//--------------------------------{WB}end---------------------------------//

//----------------------{debug}begin------------------------------//
wire   debug_s0          = rf_we[0];
wire   debug_s1          = (ISSUE >= 2) & rf_we[1];
assign debug_wb_pc       = debug_s0 ? pc[0]       : (debug_s1 ? pc[1]       : pc[0]);
assign debug_wb_rf_wdata = debug_s0 ? rf_wdata[0] : (debug_s1 ? rf_wdata[1] : 32'b0);
assign debug_wb_rf_we    = {4{debug_s0 | debug_s1}};
assign debug_wb_rf_wnum  = debug_s0 ? rf_waddr[0] : (debug_s1 ? rf_waddr[1] : 5'b0);

generate
    for (gi = 0; gi < ISSUE; gi = gi + 1) begin : gen_debug_commit
        assign debug_commit_valid[gi] = slot_fire[gi] & ~idle_ex;
        assign debug_commit_exception[gi] = slot_fire[gi] & ex_slot[gi];
        assign debug_commit_pc[gi*32 +: 32] = pc[gi];
        assign debug_commit_rf_wen[gi*4 +: 4] = {4{rf_we[gi]}};
        assign debug_commit_rf_wnum[gi*5 +: 5] = rf_waddr[gi];
        assign debug_commit_rf_wdata[gi*32 +: 32] = rf_wdata[gi];
    end
endgenerate
//----------------------{debug}end------------------------------//

endmodule
