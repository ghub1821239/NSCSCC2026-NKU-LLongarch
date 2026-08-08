`include "csr_def.vh"
module wb #(
    parameter inbus_width  = 32
)(
    input  wire        clk,
    input  wire        resetn,
    // 流水线控制信号
    input  wire        MEM_WB_valid,
    input  wire        WB_allow_in,
    output wire        WB_ready_go,
    output reg         WB_valid,
    
    input  wire [inbus_width-1:0]MEM_WB_bus,// MEM到WB级总线
    // 调试接口
    output wire [31:0] debug_wb_pc,
    output wire [ 3:0] debug_wb_rf_we,
    output wire [ 4:0] debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata,
    // 通用寄存器堆写回接口
    output wire [ 4:0] rf_waddr,
    output wire [31:0] rf_wdata,
    output wire        rf_we,
    // 数据相关与停顿控制
    output wire [ 4:0] WB_rf_dest,
    output wire        need_stall_csr,
    // 写回级数据前递
    output wire [31:0] wb_front_data,
    output wire [ 4:0] wb_front_addr,
    // CSR读写接口
    output wire [13:0] csr_num,
    output wire        csr_re,
    input  wire [31:0] csr_rvalue,
    output wire        csr_we,
    output wire [31:0] csr_wdata,
    output wire [31:0] csr_wmask,
    // ERTN或异常发生时冲刷流水线，并给出跳转目标
    output wire        flush,
    output wire [31:0] flush_target,
    // 流水线取消控制
    input  wire        WB_need_cancel,
    // 异常信息
    output wire [31:0] wb_pc,
    output wire        wb_ex,
    output wire [5:0]  ecode,
    output wire [8:0]  esubcode,
    output wire [31:0] wb_vaddr,
    // 向前级反馈异常控制信号
    output wire        WB_ex,
    // tlbrd 控制csr的写入
    output wire        tlbrd_we,
    // tlbwr,tlbfill 控制tlb写入
    output wire        tlbwr_we,
    output wire        tlbfill_we,
    // tlbidx
    input  wire [31:0] csr_TLBIDX,
    //tlbreload 重填传入CSR
    output wire        ex_tlb_reload,
    // ERTN　更改　CRMD
    output wire        ertn_valid,
    // BADV
    output wire        csr_tlb_reload0,
    output wire        csr_tlb_plv0   ,//tlb中页特权不合规
    output wire        csr_tlb_reload1,//tlb重填例外  
    output wire        csr_tlb_plv1,    //tlb中页特权不合规 
    // ex_tlb --> TLBEHI
    output wire        ex_tlb,
    //can_not_front_push
    output wire        wb_can_not_front_push,
    //IDLE
    input  wire        csr_has_int,
    input  wire        csr_tcfg_init0, // TCFG.InitVal==0
    output wire        IDLE_stall
);
wire [31:0] pc;

wire        rf_gr_we_ex;
wire [4:0]  rf_dest;
wire [31:0] rf_alu_wdata;
wire [31:0] rkd_value;
wire [31:0] rj_value;
wire        mem_we;
reg [inbus_width-1:0] bus;

//-------------CSR-------------
wire        inst_csrrd;
wire        inst_csrwr;
wire        inst_csrxchg;
wire [13:0] csr_num_wr;
// 异常类型标志
wire        inst_syscall;
wire        inst_break;
wire        ex_INE;
wire        ex_IPE;
wire        ex_ADEF;
wire        ex_ALE;
//tlb_ex
wire        ex_tlb_reload0;//tlb重填例外
wire        ex_tlb_preif_unvalid;//tlb中取指页无效
wire        ex_tlb_plv0;//tlb中页特权不合规
wire        ex_tlb_reload1;//tlb重填例外        
wire        ex_tlb_ld_unvalid;//tlb中load页无效 
wire        ex_tlb_st_unvalid;//tlb中store页无效
wire        ex_tlb_plv1;//tlb中页特权不合规        
wire        ex_tlb_page_modify;//tlb中页修改
wire        ex_tlb_plv;     
// 计时器读取指令
wire        inst_idle;
wire        inst_ertn;

wire        has_int;

//**************** tlb begin ****************
wire        inst_rdcntvl_w;
wire        inst_rdcntvh_w;
wire        inst_rdcntid;

//**************** tlb end ****************
wire        inst_tlbsrch;
wire        inst_tlbrd;
wire [10:0] TLBIDX_new_tlbsrch;
wire        inst_tlbwr;
wire        inst_tlbfill;
wire        inst_invtlb;

assign tlbrd_we   = inst_tlbrd & WB_valid & ~wb_ex;
assign tlbwr_we   = inst_tlbwr & WB_valid & ~wb_ex;
assign tlbfill_we = inst_tlbfill & WB_valid & ~wb_ex;
// csr_num_wr是MEM级传入的指令原始CSR编号；ERTN、异常和RDCNTID会在WB级改选其他CSR

wire [31:0] alu_result_with_rdct;
wire        csr_WB_rd;
wire        csr_rd_WB_each;
assign csr_WB_rd = (inst_csrrd | inst_csrwr | inst_csrxchg | inst_rdcntid) & WB_valid & ~wb_ex;
assign csr_rd_WB_each = (inst_csrwr | inst_csrxchg) & WB_valid & ~wb_ex;
always @(posedge clk) begin
    if(!resetn)begin
        bus <= {inbus_width{1'b0}};
    end
    else if(MEM_WB_valid & WB_allow_in)begin
        bus <= MEM_WB_bus;
    end
end
// tlb 异常
assign {
        pc,need_stall_csr,alu_result_with_rdct,
        inst_csrrd, inst_csrwr,inst_csrxchg,inst_ertn,inst_syscall,inst_break,ex_INE,ex_IPE,ex_ADEF,ex_ALE,has_int,inst_rdcntvl_w,inst_rdcntvh_w,inst_rdcntid,csr_num_wr,mem_we,rj_value,rkd_value,rf_dest,rf_alu_wdata,rf_gr_we_ex,
        inst_tlbsrch,TLBIDX_new_tlbsrch,inst_tlbrd,inst_tlbwr,inst_tlbfill,inst_invtlb,//WB
        ex_tlb_reload0,ex_tlb_preif_unvalid,ex_tlb_plv0,ex_tlb_reload1,ex_tlb_ld_unvalid,ex_tlb_st_unvalid,ex_tlb_plv1,ex_tlb_page_modify,inst_idle
    }=bus;

//------------------------{IDLE}begin-------------------------//
// golden / 参考模型：
// - TCFG.InitVal==0：写 TCFG 后立即 TI，IDLE 视为被抢占，ERA = IDLE
// - 其余（含短定时器在流水线中到期）：IDLE 仍进入等待，唤醒 ERA = IDLE+4
//   （深流水下 timer=0x4 只有 4 拍，TI 常在 IDLE 提交前已置位，不能再用 csr_has_int 判断）
reg         is_idle;
reg  [31:0] idle_era_r;
wire        idle_ex_other;
wire        idle_valid;
wire        idle_wake_ex;
wire        idle_preempt; // timer=0 的抢占

assign idle_ex_other = inst_syscall | inst_break | ex_INE | ex_IPE | ex_ADEF | ex_ALE |
                       ex_tlb_reload0 | ex_tlb_preif_unvalid | ex_tlb_plv0 |
                       ex_tlb_reload1 | ex_tlb_ld_unvalid | ex_tlb_st_unvalid |
                       ex_tlb_plv1 | ex_tlb_page_modify;
assign idle_valid    = inst_idle & WB_valid & ~idle_ex_other;
assign idle_preempt  = idle_valid & csr_has_int & csr_tcfg_init0; // 提交时已有 TI(InitVal=0)
assign idle_wake_ex  = is_idle & csr_has_int;
// 抢占本拍直接取中断（不进 is_idle）；等待唤醒走 idle_wake_ex
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
            // idle 与抢占中断同时：不进 idle，ERA=IDLE
            is_idle    <= 1'b0;
            idle_era_r <= pc;
        end
        else begin
            // 真正进入等待
            is_idle    <= 1'b1;
            idle_era_r <= pc + 32'd4;
        end
    end
end
//------------------------{IDLE}end-------------------------//

assign rf_wdata   = csr_WB_rd ? csr_rvalue :  rf_alu_wdata;
assign rf_waddr   = rf_dest;
assign rf_we      = rf_gr_we_ex & WB_valid & ~wb_ex;
assign csr_wmask  = (inst_csrwr | inst_tlbsrch) ? 32'hffffffff : rj_value;
assign csr_wdata  = inst_tlbsrch ? {TLBIDX_new_tlbsrch[10],csr_TLBIDX[30:10],TLBIDX_new_tlbsrch[9:0]} : rkd_value;
assign csr_we     = (inst_tlbsrch | csr_rd_WB_each) & WB_valid & ~wb_ex;
assign flush      = ((inst_ertn | inst_csrwr | inst_csrxchg | inst_tlbfill | inst_tlbwr | inst_tlbrd | inst_tlbsrch | wb_ex | inst_idle) & WB_valid)
                    | idle_wake_ex;
assign csr_re     = ((csr_WB_rd | flush) & WB_valid) | idle_wake_ex;
assign csr_num    = idle_ex                ? `CSR_EENTRY      :
                    (has_int & ~inst_idle) ? `CSR_EENTRY      :
                    ex_ADEF         ? `CSR_EENTRY      :
                    ex_tlb_preif_unvalid ? `CSR_EENTRY :
                    ex_tlb_plv0     ? `CSR_EENTRY      :
                    ex_tlb_reload0  ? `CSR_TLBRENTRY   :
                    ex_INE          ? `CSR_EENTRY      :
                    ex_IPE          ? `CSR_EENTRY      :
                    inst_idle       ? `CSR_EENTRY      :
                    inst_syscall    ? `CSR_EENTRY      :
                    inst_break      ? `CSR_EENTRY      :
                    inst_ertn       ? `CSR_ERA         : 
                    ex_ALE          ? `CSR_EENTRY      :
                    ex_tlb_plv1     ? `CSR_EENTRY      :
                    ex_tlb_reload1  ? `CSR_TLBRENTRY   :
                    ex_tlb_ld_unvalid ? `CSR_EENTRY    :
                    ex_tlb_st_unvalid ? `CSR_EENTRY    :
                    ex_tlb_page_modify? `CSR_EENTRY    :
                    inst_rdcntid    ? `CSR_TID         : 
                    inst_tlbsrch    ? `CSR_TLBIDX      : 
                    csr_num_wr;
assign flush_target = wb_ex ? csr_rvalue :
                      (inst_csrwr | inst_csrxchg | inst_tlbfill |
                       inst_tlbwr | inst_tlbrd | inst_tlbsrch | inst_idle)
                      ? pc + 4
                      : csr_rvalue;

assign ex_tlb_reload = WB_valid & (ecode == `ECODE_TLBR);
assign ex_tlb        = WB_valid & ((ecode == `ECODE_PIF)  |
                                   (ecode == `ECODE_PPI)  |
                                   (ecode == `ECODE_TLBR) |
                                   (ecode == `ECODE_PIL)  |
                                   (ecode == `ECODE_PIS)  |
                                   (ecode == `ECODE_PME));

// IDLE 不走流水线 has_int；抢占用 pc，唤醒用 idle_era_r
assign wb_pc = idle_preempt ? pc :
               idle_wake_ex ? idle_era_r :
                              pc;
assign wb_ex      = ((inst_syscall | inst_break           | ex_INE | ex_ADEF | 
                     ex_ALE       | (has_int & ~inst_idle)| ex_tlb | ex_IPE  ) & WB_valid)
                    | idle_ex;
assign ex_tlb_plv = ex_tlb_plv0 | ex_tlb_plv1;

assign wb_vaddr   = alu_result_with_rdct;
assign ecode      = idle_ex | (has_int & ~inst_idle) ? `ECODE_INT  :
                    ex_ADEF         ? `ECODE_ADE  :
                    ex_tlb_preif_unvalid ? `ECODE_PIF :
                    ex_tlb_plv0     ? `ECODE_PPI  :
                    ex_tlb_reload0  ? `ECODE_TLBR :
                    ex_INE          ? `ECODE_INE  :
                    ex_IPE          ? `ECODE_IPE  :
                    inst_syscall    ? `ECODE_SYS  :
                    inst_break      ? `ECODE_BRK  :
                    ex_ALE          ? `ECODE_ALE  :
                    ex_tlb_plv1     ? `ECODE_PPI  :
                    ex_tlb_reload1  ? `ECODE_TLBR :
                    ex_tlb_ld_unvalid ? `ECODE_PIL :
                    ex_tlb_st_unvalid ? `ECODE_PIS :
                    ex_tlb_page_modify ? `ECODE_PME :
                                        6'b0;

assign esubcode    = idle_ex | (has_int & ~inst_idle) ? `ESUBCODE_INT   : 
                     ex_ADEF              ? `ESUBCODE_ADEF  :
                     ex_tlb_preif_unvalid ? `ESUBCODE_PIF   : 
                     ex_tlb_plv0          ? `ESUBCODE_PPI   :
                     ex_tlb_reload0       ? `ESUBCODE_TLBR  :
                     ex_INE               ? `ESUBCODE_INE   :
                     ex_IPE               ? `ESUBCODE_IPE   :
                     inst_syscall         ? `ESUBCODE_SYS   :  
                     inst_break           ? `ESUBCODE_BRK   :  
                     ex_ALE               ? `ESUBCODE_ALE   :
                     ex_tlb_plv1          ? `ESUBCODE_PPI   :
                     ex_tlb_reload1       ? `ESUBCODE_TLBR  :
                     ex_tlb_ld_unvalid    ? `ESUBCODE_PIL   : 
                     ex_tlb_st_unvalid    ? `ESUBCODE_PIS   : 
                     ex_tlb_page_modify   ? `ESUBCODE_PME   :
                                            9'b0;

assign csr_tlb_reload0 = ex_tlb_reload0 & WB_valid;
assign csr_tlb_plv0    = ex_tlb_plv0    & WB_valid;
assign csr_tlb_reload1 = ex_tlb_reload1 & WB_valid;
assign csr_tlb_plv1    = ex_tlb_plv1    & WB_valid;

assign WB_ready_go=1'b1;
always @(posedge clk) begin
    if(!resetn)begin
        WB_valid<=1'b0;
    end
    else if(WB_need_cancel)begin
        WB_valid<=1'b0;
    end
    else if(WB_allow_in)begin
        WB_valid<=MEM_WB_valid;
    end
end

assign ertn_valid = inst_ertn & WB_valid & ~wb_ex;

assign wb_front_data = rf_wdata;
assign wb_front_addr = rf_dest;
assign wb_can_not_front_push = ~rf_gr_we_ex;

// 本拍组合停取指，避免晚一拍
assign IDLE_stall = (idle_valid & ~csr_has_int) | (is_idle & ~csr_has_int);

assign WB_ex = (WB_valid &
               (inst_syscall | inst_ertn | inst_break              | ex_INE | ex_IPE |
                ex_ADEF      | ex_ALE    | (has_int & ~inst_idle)  | ex_tlb ))
               | idle_ex;

assign debug_wb_pc = pc;
assign debug_wb_rf_wdata = rf_wdata;
assign debug_wb_rf_we = {4{rf_we}};
assign debug_wb_rf_wnum = rf_dest;
assign WB_rf_dest = rf_dest;

endmodule
