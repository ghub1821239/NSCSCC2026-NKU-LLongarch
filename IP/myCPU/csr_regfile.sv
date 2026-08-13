`include "csr_def.vh"
module csr_regfile#(
    parameter  TLBNUM = 16,
    parameter  ISSUE  = 2
)(
    input  wire                      clk,
    input  wire                      resetn,
    // write
    input  wire                      csr_we,
    input  wire [31:0]               csr_wmask,
    input  wire [13:0]               csr_num,
    // 写掩码存在的必要就是因为csrxcfg这个指令会涉及到rj的写掩码问题，这里是放到了csr里进行处理，这样也不会让decode的关键路径变长
    input  wire [31:0]               csr_wvalue,
    // read port
    input  wire                      csr_re,
    output wire [31:0]               csr_rvalue,
    // ex 发起异常
    input  wire                      wb_ex,

    input  wire [5:0]                wb_ecode,
    input  wire [8:0]                wb_esubcode,

    // 硬件异常8位
    input  wire [7:0]                hw_int_in,
    input  wire                      ipi_int_in,

    // ERA 存储使用，发起异常的pc
    input  wire [31:0]               wb_pc,
    // BAVD 记录错误的地址
    input  wire [31:0]               wb_vaddr,

    // decode
    output wire                      has_int,
    
    //coreid
    input  wire [31:0]               coreid_in,

    // TLB CSR outputs for EXE/WB
    output wire [31:0]               csr_TLBEHI,
    output wire [31:0]               csr_TLBIDX,
    // CRMD 给到流水级进行PLV权限判定
    output wire [1:0]                csr_CRMD_PLV,
    
    //tlbrd接口 read port
    output wire [$clog2(TLBNUM)-1:0] r_index,
    output wire [9:0]                s0_asid,
    output wire [9:0]                s1_asid_without_invtlb,
    input  wire                      tlbrd_we,
    input  wire                      r_e,
    input  wire [18:0]               r_vppn,
    input  wire [5:0]                r_ps,
    input  wire [9:0]                r_asid,
    input  wire                      r_g,
    input  wire [19:0]               r_ppn0,
    input  wire [1:0]                r_plv0,
    input  wire [1:0]                r_mat0,
    input  wire                      r_d0,
    input  wire                      r_v0,
    input  wire [19:0]               r_ppn1,
    input  wire [1:0]                r_plv1,
    input  wire [1:0]                r_mat1,
    input  wire                      r_d1,
    input  wire                      r_v1,
    // write port
    output wire [$clog2(TLBNUM)-1:0] w_index,
    output wire                      w_e,
    output wire [18:0]               w_vppn,
    output wire [5:0]                w_ps,
    output wire [9:0]                w_asid,
    output wire                      w_g,
    output wire [19:0]               w_ppn0,
    output wire [1:0]                w_plv0,
    output wire [1:0]                w_mat0,
    output wire                      w_d0,
    output wire                      w_v0,
    output wire [19:0]               w_ppn1,
    output wire [1:0]                w_plv1,
    output wire [1:0]                w_mat1,
    output wire                      w_d1,
    output wire                      w_v1,
    // CRMD 输出给流水线进行判定翻译方式
    output wire                      csr_CRMD_DA,
    output wire                      csr_CRMD_PG,
    // CRMD重填异常
    input  wire                      ex_tlb_reload,
    // DMW0/1 
    input  wire [2:0]                dmw_vseg0             [ISSUE-1:0],
    output wire                      dmw_found0            [ISSUE-1:0],
    output wire [2:0]                dmw_pseg0             [ISSUE-1:0],

    input  wire [2:0]                dmw_vseg1             [ISSUE-1:0],
    output wire                      dmw_found1            [ISSUE-1:0],
    output wire [2:0]                dmw_pseg1             [ISSUE-1:0],

    //ERTN 例外指令返回更改CRMD
    input  wire                      ertn_valid,
    
    //BADV
    input  wire                      csr_tlb_reload0,
    input  wire                      csr_tlb_plv0,
    input  wire                      csr_tlb_reload1,  
    input  wire                      csr_tlb_plv1,
    // ex_tlb TLBEHI
    input  wire                      ex_tlb,
    //mat:存储访问类型
    output wire [1:0]                csr_CRMD_DATF,
    output wire [1:0]                csr_CRMD_DATM,
    output wire [1:0]                dmw_mat0              [ISSUE-1:0],
    output wire [1:0]                dmw_mat1              [ISSUE-1:0],
    // 操作手册6.3复位指出
    input  wire                      LLbit_wb,
    input  wire                      LLbit_wdata,
    output wire                      LLbit,

    // IDLE：TCFG.InitVal==0 时参考模型会在写 TCFG 后立刻抢占，ERA=IDLE 本身
    output wire                      csr_tcfg_init0,

    //用来切割csr的接口路径
    output wire [31:0]               csr_eentry_rvalue,
    output wire [31:0]               csr_era_rvalue,
    output wire [31:0]               csr_tlbrentry_rvalue
);

// ----------DEFINE--------------
reg [31:0] CRMD;
reg [31:0] PRMD;
reg [31:0] EUEN;
reg [31:0] ESTAT;
reg [31:0] ERA;
reg [31:0] EENTRY;
reg [31:0] SAVE0;
reg [31:0] SAVE1;
reg [31:0] SAVE2;
reg [31:0] SAVE3;
reg [31:0] TICLR;
reg [31:0] ECFG;
reg [31:0] BADV;
reg [31:0] TID;
reg [31:0] TCFG;
reg [31:0] TVAL;
reg [31:0] TLBIDX;
reg [31:0] TLBEHI;
reg [31:0] TLBELO0;
reg [31:0] TLBELO1;
reg [31:0] ASID;
reg [31:0] TLBRENTRY;
reg [31:0] DMW0;
reg [31:0] DMW1;
reg [31:0] LLBCTL;
reg [31:0] PGDL;
reg [31:0] PGDH;
// ----------DEFINE END----------

// ----------WRITE IN--------------

//【CRMD PLV】 特权等级
always @ (posedge clk)begin
    // 如果写回阶段报错，就要转成内核态进行异常处理
    if(!resetn)begin
        CRMD[`CSR_CRMD_PLV] <= 2'b0;
    end
    // 如果调用ertn，表示异常已经处理完，需要恢复到异常触发前的特权等级
    else if(wb_ex)begin
        CRMD[`CSR_CRMD_PLV] <= 2'b0;
    end
    // 如果写CRMD，则按写掩码更新：
    else if (ertn_valid) begin
        CRMD[`CSR_CRMD_PLV] <= PRMD [`CSR_PRMD_PPLV];
    end
    // 1. 掩码为1的位写入csr_wvalue对应位
    // 2. 掩码为0的位保持原值
    // 最后将两部分按位或合并
    // 进入异常处理程序后将CRMD的IE位置0，避免在异常处理期间再次响应中断
    else if (csr_we & csr_num == `CSR_CRMD)begin
        CRMD[`CSR_CRMD_PLV] <= (csr_wmask[`CSR_CRMD_PLV] & csr_wvalue[`CSR_CRMD_PLV]) |
                               (~csr_wmask[`CSR_CRMD_PLV] & CRMD[`CSR_CRMD_PLV]);
    end
end
//【CRMD IE】是否允许响应中断
always @ (posedge clk)begin
    if(!resetn)begin
        CRMD[`CSR_CRMD_IE] <= 1'b0;
    end
    // 有效&自减
    else if(wb_ex)begin
        CRMD[`CSR_CRMD_IE] <= 1'b0;
    end
    else if (ertn_valid) begin
        CRMD[`CSR_CRMD_IE] <= PRMD [`CSR_PRMD_PIE];
    end
    else if (csr_we & csr_num == `CSR_CRMD)begin
        CRMD[`CSR_CRMD_IE] <= (csr_wmask[`CSR_CRMD_IE] & csr_wvalue[`CSR_CRMD_IE]) |
                              (~csr_wmask[`CSR_CRMD_IE] & CRMD[`CSR_CRMD_IE]);
    end
end
//【CRMD DA & PG & DATF & DATM】这些字段在启用TLB后才会使用，此处先设置复位值
always @(posedge clk)begin
    if(!resetn)begin
        CRMD[`CSR_CRMD_DA]   <= 1'b1;
        CRMD[`CSR_CRMD_PG]   <= 1'b0;
        CRMD[`CSR_CRMD_DATF] <= 2'b0;
        CRMD[`CSR_CRMD_DATM] <= 2'b0;
    end
    else begin
        if (ex_tlb_reload) begin
            CRMD[`CSR_CRMD_DA]   <= 1'b1;
            CRMD[`CSR_CRMD_PG]   <= 1'b0;
        end
        else if (ertn_valid && ESTAT[`CSR_ESTAT_ECODE] == 6'h3F) begin
            CRMD[`CSR_CRMD_DA]   <= 1'b0;
            CRMD[`CSR_CRMD_PG]   <= 1'b1;
            // 推荐的 但是指令手册有误
//            CRMD[`CSR_CRMD_DATF] <= 2'b00;
//            CRMD[`CSR_CRMD_DATM] <= 2'b01;
        end
        else begin
            if (csr_we & csr_num == `CSR_CRMD)begin
                CRMD[`CSR_CRMD_DA]   <= (csr_wmask[`CSR_CRMD_DA] & csr_wvalue[`CSR_CRMD_DA]) |
                                        (~csr_wmask[`CSR_CRMD_DA] & CRMD[`CSR_CRMD_DA]);
            end
            if (csr_we & csr_num == `CSR_CRMD)begin
                CRMD[`CSR_CRMD_PG]   <= (csr_wmask[`CSR_CRMD_PG] & csr_wvalue[`CSR_CRMD_PG]) |
                                        (~csr_wmask[`CSR_CRMD_PG] & CRMD[`CSR_CRMD_PG]);
            end
            if (csr_we & csr_num == `CSR_CRMD)begin
                CRMD[`CSR_CRMD_DATF] <= (csr_wmask[`CSR_CRMD_DATF] & csr_wvalue[`CSR_CRMD_DATF]) |
                                        (~csr_wmask[`CSR_CRMD_DATF] & CRMD[`CSR_CRMD_DATF]);
            end
            if (csr_we & csr_num == `CSR_CRMD)begin
                CRMD[`CSR_CRMD_DATM] <= (csr_wmask[`CSR_CRMD_DATM] & csr_wvalue[`CSR_CRMD_DATM]) |
                                        (~csr_wmask[`CSR_CRMD_DATM] & CRMD[`CSR_CRMD_DATM]);
            end
        end
    end
end

//【PRMD PPLV】保存异常触发前的特权等级
always @(posedge clk)begin
    if(wb_ex)begin
        PRMD[`CSR_PRMD_PPLV] <= CRMD[`CSR_CRMD_PLV];
    end
    else if (csr_we & csr_num == `CSR_PRMD)begin
        PRMD[`CSR_PRMD_PPLV] <= (csr_wmask[`CSR_PRMD_PPLV] & csr_wvalue[`CSR_PRMD_PPLV]) |
                                (~csr_wmask[`CSR_PRMD_PPLV] & PRMD[`CSR_PRMD_PPLV]);
    end
end
//【PRMD PIE】保存异常触发前的全局中断使能位
always @(posedge clk)begin
    if (wb_ex)begin
        PRMD[`CSR_PRMD_PIE] <= CRMD[`CSR_CRMD_IE];
    end
    else if (csr_we & csr_num == `CSR_PRMD)begin
        PRMD[`CSR_PRMD_PIE] <= (csr_wmask[`CSR_PRMD_PIE] & csr_wvalue[`CSR_PRMD_PIE]) |
                               (~csr_wmask[`CSR_PRMD_PIE] & PRMD[`CSR_PRMD_PIE]);
    end
end

//【EUEN】
always @(posedge clk)begin
    if(!resetn)begin
        EUEN[`CSR_EUEN_FPE] <= 1'b0;
    end
    else if(csr_we & csr_num == `CSR_EUEN)begin
        EUEN[`CSR_EUEN_FPE] <= (csr_wmask[`CSR_EUEN_FPE] & csr_wvalue[`CSR_EUEN_FPE]) |
                               (~csr_wmask[`CSR_EUEN_FPE] & EUEN[`CSR_EUEN_FPE]);
    end
end

//【ERA】异常返回地址
// 触发异常的时候，wb_ex会触发把当前的异常pc写入era
// 这样syscall和brk这种只需要管跳转到eentry即可
always @(posedge clk)begin
    if (wb_ex)begin
        ERA[`CSR_ERA_PC] <= wb_pc;
    end
    else if (csr_we & csr_num == `CSR_ERA)begin
        ERA[`CSR_ERA_PC] <= (csr_wmask[`CSR_ERA_PC] & csr_wvalue[`CSR_ERA_PC]) |
                            (~csr_wmask[`CSR_ERA_PC] & ERA[`CSR_ERA_PC]);
    end
end

//【EENTRY】异常入口地址
always @ (posedge clk)begin
    if (csr_we & csr_num == `CSR_EENTRY)begin
        EENTRY[`CSR_EENTRY_VA] <= (csr_wmask[`CSR_EENTRY_VA] & csr_wvalue[`CSR_EENTRY_VA]) |
                                  (~csr_wmask[`CSR_EENTRY_VA] & EENTRY[`CSR_EENTRY_VA]);
    end
end

//【SAVE 0~3】数据保存寄存器
always @ (posedge clk)begin
    if (csr_we && csr_num == `CSR_SAVE0)begin
        SAVE0[`CSR_SAVE_DATA] <= (csr_wmask[`CSR_SAVE_DATA] & csr_wvalue[`CSR_SAVE_DATA]) |
                                 (~csr_wmask[`CSR_SAVE_DATA] & SAVE0[`CSR_SAVE_DATA]);
    end
    if (csr_we && csr_num == `CSR_SAVE1)begin
        SAVE1[`CSR_SAVE_DATA] <= (csr_wmask[`CSR_SAVE_DATA] & csr_wvalue[`CSR_SAVE_DATA]) |
                                 (~csr_wmask[`CSR_SAVE_DATA] & SAVE1[`CSR_SAVE_DATA]);
    end
    if (csr_we && csr_num == `CSR_SAVE2)begin
        SAVE2[`CSR_SAVE_DATA] <= (csr_wmask[`CSR_SAVE_DATA] & csr_wvalue[`CSR_SAVE_DATA]) |
                                 (~csr_wmask[`CSR_SAVE_DATA] & SAVE2[`CSR_SAVE_DATA]);
    end
    if (csr_we && csr_num == `CSR_SAVE3)begin
        SAVE3[`CSR_SAVE_DATA] <= (csr_wmask[`CSR_SAVE_DATA] & csr_wvalue[`CSR_SAVE_DATA]) |
                                 (~csr_wmask[`CSR_SAVE_DATA] & SAVE3[`CSR_SAVE_DATA]);
    end
end

//【TICLR】定时器中断清除寄存器

//【ECFG】
//【todo】 check一下这里是ESTAT 还是 ECFG
always @ (posedge clk)begin
    if(!resetn)begin
        ECFG[`CSR_ECFG_LIE] <= 13'b0;
    end
    else if (csr_we & csr_num == `CSR_ECFG)begin
        ECFG[`CSR_ECFG_LIE] <= (csr_wmask[`CSR_ECFG_LIE] & csr_wvalue[`CSR_ECFG_LIE] & 13'h1bff) |
                               (~csr_wmask[`CSR_ECFG_LIE] & ECFG[`CSR_ECFG_LIE] & 13'h1bff);
    end
end
    

//【BADV】异常相关虚地址
wire    wb_ex_addr_err;
wire    ex_preIF_tlb;
assign  wb_ex_addr_err = wb_ecode == `ECODE_ADE || wb_ecode == `ECODE_ALE || wb_ecode == `ECODE_PIL ||
                         wb_ecode == `ECODE_PIS || wb_ecode == `ECODE_PIF || wb_ecode == `ECODE_PME ||
                         wb_ecode == `ECODE_PPI || wb_ecode == `ECODE_TLBR;
assign  ex_preIF_tlb   = (wb_ecode == `ECODE_PIF) | (wb_ecode == `ECODE_TLBR & csr_tlb_reload0) | (wb_ecode == `ECODE_PPI & csr_tlb_plv0);
always @ (posedge clk)begin
    if(wb_ex && wb_ex_addr_err)begin
        BADV[`CSR_BADV_VADDR] <= (wb_ecode == `ECODE_ADE & wb_esubcode == `ESUBCODE_ADEF) | ex_preIF_tlb
                                 ? wb_pc : wb_vaddr;
    end
end

//【TID】复位时载入coreid，也可通过CSR指令写入
always @ (posedge clk)begin
    if(!resetn)begin
        TID[`CSR_TID_TID] <= coreid_in;
    end
    else if (csr_we && csr_num == `CSR_TID)begin
        TID[`CSR_TID_TID] <= (csr_wmask[`CSR_TID_TID] & csr_wvalue[`CSR_TID_TID]) |
                             (~csr_wmask[`CSR_TID_TID] & TID[`CSR_TID_TID]);
    end
end

//【TCFG】控制定时器的初始值、循环模式和使能位
always @ (posedge clk)begin
    if(!resetn)begin
        TCFG[`CSR_TCFG_EN]      <= 1'b0;
    end
    else if (csr_we && csr_num == `CSR_TCFG)begin
        TCFG[`CSR_TCFG_EN]      <= (csr_wmask[`CSR_TCFG_EN] & csr_wvalue[`CSR_TCFG_EN]) |
                                   (~csr_wmask[`CSR_TCFG_EN] & TCFG[`CSR_TCFG_EN]);
    end
    if(csr_we && csr_num == `CSR_TCFG)begin
        TCFG[`CSR_TCFG_PERIOD]  <= (csr_wmask[`CSR_TCFG_PERIOD] & csr_wvalue[`CSR_TCFG_PERIOD]) |
                                   (~csr_wmask[`CSR_TCFG_PERIOD] & TCFG[`CSR_TCFG_PERIOD]);
        TCFG[`CSR_TCFG_INITVAL] <= (csr_wmask[`CSR_TCFG_INITVAL] & csr_wvalue[`CSR_TCFG_INITVAL]) |
                                   (~csr_wmask[`CSR_TCFG_INITVAL] & TCFG[`CSR_TCFG_INITVAL]);
    end
end
//【timer――cnt】
reg    [31:0] timer_cnt;
// 新的TCFG
wire   [31:0] TCFG_next_val;
wire          TCFG_write_in_en1;
assign        TCFG_next_val     = csr_wmask[31:0] & csr_wvalue[31:0] | ~csr_wmask[31:0] & TCFG[31:0];
assign        TCFG_write_in_en1 = csr_we && csr_num == `CSR_TCFG && TCFG_next_val[`CSR_TCFG_EN];
always @ (posedge clk) begin
    if (!resetn) begin
        timer_cnt <= 32'hffffffff;
    end
    // 当写入tcfg & tcfg的EN是1时需要同步写入timer
    else if (TCFG_write_in_en1) begin
        timer_cnt <= {TCFG_next_val[`CSR_TCFG_INITVAL],{2{1'b0}}};
    end
    else if (TCFG[`CSR_TCFG_EN] && timer_cnt != 32'hffffffff) begin
        if (timer_cnt[31:0] == 32'b0 && TCFG[`CSR_TCFG_PERIOD]) begin
            timer_cnt <= {TCFG[`CSR_TCFG_INITVAL],{2{1'b0}}};
        end
        else begin
            timer_cnt <= timer_cnt - 1;
        end
    end
end

//【ESTAT IS】中断状态位
always @(posedge clk)begin
    //【软中断】
    if (!resetn)begin
        ESTAT[`CSR_ESTAT_IS1_0] <= 2'b0;
    end
    else if (csr_we & csr_num == `CSR_ESTAT)begin
        ESTAT[`CSR_ESTAT_IS1_0] <= (csr_wmask[`CSR_ESTAT_IS1_0] & csr_wvalue[`CSR_ESTAT_IS1_0]) |
                                   (~csr_wmask[`CSR_ESTAT_IS1_0] & ESTAT[`CSR_ESTAT_IS1_0]);
    end                            
   //【硬中断】由hw_int_in传入；未连接硬件中断源时应输入0
    ESTAT[`CSR_ESTAT_IS9_2] <= hw_int_in[7:0];

    //【保留位】
    ESTAT[10]               <= 1'b0;

    //【定时器中断】
    // InitVal==0 时与参考模型一致：写 TCFG.En 立即置 TI；其余保持 cnt==0 置位
    if (TCFG_write_in_en1 && (TCFG_next_val[`CSR_TCFG_INITVAL] == 30'b0)) begin
        ESTAT[`CSR_ESTAT_IS11]  <= 1'b1;
    end
    else if(timer_cnt[31:0] == 32'b0)begin
        ESTAT[`CSR_ESTAT_IS11]  <= 1'b1;
    end
    // TICLR的读值恒为0，写入CLR位时直接清除定时器中断状态
    else if (csr_we && csr_num == `CSR_TICLR && csr_wmask[`CSR_TICLR_CLR] && csr_wvalue[`CSR_TICLR_CLR])begin
        ESTAT[`CSR_ESTAT_IS11]  <= 1'b0;
    end

    //【核间中断】
    ESTAT[`CSR_ESTAT_IS12]  <= ipi_int_in;
end
//【ESTAT Ecode & Esubcode】异常类型和异常子类型
always @(posedge clk)begin
    if(wb_ex)begin
        ESTAT[`CSR_ESTAT_ECODE]    <= wb_ecode;
        ESTAT[`CSR_ESTAT_ESUBCODE] <= wb_esubcode;
    end
end

//【TLBIDX INDEX】TLB的Index域
always @(posedge clk) begin
    if(csr_we && csr_num == `CSR_TLBIDX) begin
        TLBIDX[`CSR_TLBIDX_INDEX] <= (csr_wmask[`CSR_TLBIDX_INDEX] & csr_wvalue[`CSR_TLBIDX_INDEX]) |
                                     (~csr_wmask[`CSR_TLBIDX_INDEX] & TLBIDX[`CSR_TLBIDX_INDEX]);
    end
end
//【TLBIDX PS】TLB的页面大小(4KB/4MB)
always @(posedge clk) begin
    //tlbrd读取的是无效项
    if (tlbrd_we & r_e == 1) begin
        TLBIDX[`CSR_TLBIDX_PS] <= r_ps;
    end
    //tlbrd读取的是有效项
    if (tlbrd_we & r_e == 0) begin
        TLBIDX[`CSR_TLBIDX_PS] <= 6'b0;
    end
    if (csr_we && csr_num == `CSR_TLBIDX) begin
        TLBIDX[`CSR_TLBIDX_PS] <= (csr_wmask[`CSR_TLBIDX_PS] & csr_wvalue[`CSR_TLBIDX_PS]) |
                                  (~csr_wmask[`CSR_TLBIDX_PS] & TLBIDX[`CSR_TLBIDX_PS]);
    end
end
//【TLBIDX NE】TLB的有效位
always @(posedge clk) begin
    //tlbrd读取的是无效项
    if (tlbrd_we & r_e == 1) begin
        TLBIDX[`CSR_TLBIDX_NE] <= 1'b0;
    end
    //tlbrd读取的是有效项
    if (tlbrd_we & r_e == 0) begin
        TLBIDX[`CSR_TLBIDX_NE] <= 1'b1;
    end
    if (csr_we && csr_num == `CSR_TLBIDX) begin
        TLBIDX[`CSR_TLBIDX_NE] <= (csr_wmask[`CSR_TLBIDX_NE] & csr_wvalue[`CSR_TLBIDX_NE]) |
                                  (~csr_wmask[`CSR_TLBIDX_NE] & TLBIDX[`CSR_TLBIDX_NE]);
    end
end

//【TLBEHI VPPN】TLB表项高位的VPPN
wire   [18:0] err_vppn;
assign        err_vppn = ex_preIF_tlb ? wb_pc[31:13] : wb_vaddr[31:13]; 
always @(posedge clk) begin
    //tlbrd读取的是无效项
    if (tlbrd_we & r_e == 1) begin
        TLBEHI[`CSR_TLBEHI_VPPN] <= r_vppn;
    end
    //tlbrd读取的是有效项
    if (tlbrd_we & r_e == 0) begin
        TLBEHI[`CSR_TLBEHI_VPPN] <= 19'b0;
    end
    if (ex_tlb) begin
        TLBEHI[`CSR_TLBEHI_VPPN] <= err_vppn;
    end
    if (csr_we && csr_num == `CSR_TLBEHI) begin
        TLBEHI[`CSR_TLBEHI_VPPN] <= (csr_wmask[`CSR_TLBEHI_VPPN] & csr_wvalue[`CSR_TLBEHI_VPPN]) |
                                    (~csr_wmask[`CSR_TLBEHI_VPPN] & TLBEHI[`CSR_TLBEHI_VPPN]);
    end
end

//【TLBELO0】TLB表项的低位信息,偶数页面
always @(posedge clk) begin
    //tlbrd读取的是无效项
    if (tlbrd_we & r_e == 1) begin
        TLBELO0[`CSR_TLBELO0_V]   <= r_v0;
        TLBELO0[`CSR_TLBELO0_D]   <= r_d0;
        TLBELO0[`CSR_TLBELO0_PLV] <= r_plv0;
        TLBELO0[`CSR_TLBELO0_MAT] <= r_mat0;
        TLBELO0[`CSR_TLBELO0_G]   <= r_g;
        TLBELO0[`CSR_TLBELO0_PPN] <= r_ppn0;
    end
    //tlbrd读取的是有效项
    if (tlbrd_we & r_e == 0) begin
        TLBELO0[`CSR_TLBELO0_V]   <= 1'b0;
        TLBELO0[`CSR_TLBELO0_D]   <= 1'b0;
        TLBELO0[`CSR_TLBELO0_PLV] <= 2'b0;
        TLBELO0[`CSR_TLBELO0_MAT] <= 2'b0;
        TLBELO0[`CSR_TLBELO0_G]   <= 1'b0;
        TLBELO0[`CSR_TLBELO0_PPN] <= 24'b0;
    end
    if (csr_we && csr_num == `CSR_TLBELO0) begin
        TLBELO0[`CSR_TLBELO0_V]   <= (csr_wmask[`CSR_TLBELO0_V] & csr_wvalue[`CSR_TLBELO0_V]) |
                                     (~csr_wmask[`CSR_TLBELO0_V] & TLBELO0[`CSR_TLBELO0_V]);
        TLBELO0[`CSR_TLBELO0_D]   <= (csr_wmask[`CSR_TLBELO0_D] & csr_wvalue[`CSR_TLBELO0_D]) |
                                     (~csr_wmask[`CSR_TLBELO0_D] & TLBELO0[`CSR_TLBELO0_D]);
        TLBELO0[`CSR_TLBELO0_PLV] <= (csr_wmask[`CSR_TLBELO0_PLV] & csr_wvalue[`CSR_TLBELO0_PLV]) |
                                     (~csr_wmask[`CSR_TLBELO0_PLV] & TLBELO0[`CSR_TLBELO0_PLV]);
        TLBELO0[`CSR_TLBELO0_MAT] <= (csr_wmask[`CSR_TLBELO0_MAT] & csr_wvalue[`CSR_TLBELO0_MAT]) |
                                     (~csr_wmask[`CSR_TLBELO0_MAT] & TLBELO0[`CSR_TLBELO0_MAT]);
        TLBELO0[`CSR_TLBELO0_G]   <= (csr_wmask[`CSR_TLBELO0_G] & csr_wvalue[`CSR_TLBELO0_G]) |
                                     (~csr_wmask[`CSR_TLBELO0_G] & TLBELO0[`CSR_TLBELO0_G]);
        TLBELO0[`CSR_TLBELO0_PPN] <= (csr_wmask[`CSR_TLBELO0_PPN] & csr_wvalue[`CSR_TLBELO0_PPN]) |
                                     (~csr_wmask[`CSR_TLBELO0_PPN] & TLBELO0[`CSR_TLBELO0_PPN]);
    end
end

//【TLBELO1】TLB表项的低位信息,奇数页面
always @(posedge clk) begin
    //tlbrd读取的是无效项
    if (tlbrd_we & r_e == 1) begin
        TLBELO1[`CSR_TLBELO1_V]   <= r_v1;
        TLBELO1[`CSR_TLBELO1_D]   <= r_d1;
        TLBELO1[`CSR_TLBELO1_PLV] <= r_plv1;
        TLBELO1[`CSR_TLBELO1_MAT] <= r_mat1;
        TLBELO1[`CSR_TLBELO1_G]   <= r_g;
        TLBELO1[`CSR_TLBELO1_PPN] <= r_ppn1;
    end
    //ASIDBITS
    if (tlbrd_we & r_e == 0) begin
        TLBELO1[`CSR_TLBELO1_V]   <= 1'b0;
        TLBELO1[`CSR_TLBELO1_D]   <= 1'b0;
        TLBELO1[`CSR_TLBELO1_PLV] <= 2'b0;
        TLBELO1[`CSR_TLBELO1_MAT] <= 2'b0;
        TLBELO1[`CSR_TLBELO1_G]   <= 1'b0;
        TLBELO1[`CSR_TLBELO1_PPN] <= 24'b0;
    end
    if (csr_we && csr_num == `CSR_TLBELO1) begin
        TLBELO1[`CSR_TLBELO1_V]   <= (csr_wmask[`CSR_TLBELO1_V] & csr_wvalue[`CSR_TLBELO1_V]) |
                                     (~csr_wmask[`CSR_TLBELO1_V] & TLBELO1[`CSR_TLBELO1_V]);
        TLBELO1[`CSR_TLBELO1_D]   <= (csr_wmask[`CSR_TLBELO1_D] & csr_wvalue[`CSR_TLBELO1_D]) |
                                     (~csr_wmask[`CSR_TLBELO1_D] & TLBELO1[`CSR_TLBELO1_D]);
        TLBELO1[`CSR_TLBELO1_PLV] <= (csr_wmask[`CSR_TLBELO1_PLV] & csr_wvalue[`CSR_TLBELO1_PLV]) |
                                     (~csr_wmask[`CSR_TLBELO1_PLV] & TLBELO1[`CSR_TLBELO1_PLV]);
        TLBELO1[`CSR_TLBELO1_MAT] <= (csr_wmask[`CSR_TLBELO1_MAT] & csr_wvalue[`CSR_TLBELO1_MAT]) |
                                     (~csr_wmask[`CSR_TLBELO1_MAT] & TLBELO1[`CSR_TLBELO1_MAT]);
        TLBELO1[`CSR_TLBELO1_G]   <= (csr_wmask[`CSR_TLBELO1_G] & csr_wvalue[`CSR_TLBELO1_G]) |
                                     (~csr_wmask[`CSR_TLBELO1_G] & TLBELO1[`CSR_TLBELO1_G]);
        TLBELO1[`CSR_TLBELO1_PPN] <= (csr_wmask[`CSR_TLBELO1_PPN] & csr_wvalue[`CSR_TLBELO1_PPN]) |
                                     (~csr_wmask[`CSR_TLBELO1_PPN] & TLBELO1[`CSR_TLBELO1_PPN]);
    end
end

//【ASID】TLB指令的地址空间标识符
always @(posedge clk) begin
    //tlbrd读取的是无效项
    if (!resetn) begin
        ASID[`CSR_ASID_ASIDBITS] <= 8'ha;
    end
    //tlbrd读取数据有效
    if (tlbrd_we & r_e == 0) begin
        ASID[`CSR_ASID_ASID]     <= 10'b0;
    end
    //tlbrd读取数据有效
    if (tlbrd_we & r_e == 1) begin
        ASID[`CSR_ASID_ASID]     <= r_asid;
    end
    if (csr_we && csr_num == `CSR_ASID) begin
        ASID[`CSR_ASID_ASID]     <= (csr_wmask[`CSR_ASID_ASID] & csr_wvalue[`CSR_ASID_ASID]) |
                                    (~csr_wmask[`CSR_ASID_ASID] & ASID[`CSR_ASID_ASID]);
    end
end

//【TLBRENTY PA】TLB发生重填例外时，写入这里的物理地址
always @(posedge clk) begin
    if (!resetn) begin
        TLBRENTRY[`CSR_TLBRENTRY_PA] <= 26'b0;
    end
    else if (csr_we && csr_num == `CSR_TLBRENTRY) begin
        TLBRENTRY[`CSR_TLBRENTRY_PA] <= (csr_wmask[`CSR_TLBRENTRY_PA] & csr_wvalue[`CSR_TLBRENTRY_PA]) |
                                        (~csr_wmask[`CSR_TLBRENTRY_PA] & TLBRENTRY[`CSR_TLBRENTRY_PA]);
    end
end

//【DMW0】 
always @(posedge clk)begin
    if(!resetn)begin
        DMW0[`CSR_DMW0_PLV0] <= 1'b0;
        DMW0[`CSR_DMW0_PLV3] <= 1'b0;
        DMW0[`CSR_DMW0_PSEG] <= 3'd0;
        DMW0[`CSR_DMW0_VSEG] <= 3'd0;
        DMW0[`CSR_DMW0_MAT]  <= 2'd0;
    end
    else begin
        if (csr_we && csr_num == `CSR_DMW0)begin
            DMW0[`CSR_DMW0_PLV0] <= (csr_wmask[`CSR_DMW0_PLV0] & csr_wvalue[`CSR_DMW0_PLV0]) |
                                    (~csr_wmask[`CSR_DMW0_PLV0] & DMW0[`CSR_DMW0_PLV0]);
        end                        
        if (csr_we && csr_num == `CSR_DMW0)begin
            DMW0[`CSR_DMW0_PLV3] <= (csr_wmask[`CSR_DMW0_PLV3] & csr_wvalue[`CSR_DMW0_PLV3]) |
                                    (~csr_wmask[`CSR_DMW0_PLV3] & DMW0[`CSR_DMW0_PLV3]);
        end
        if (csr_we && csr_num == `CSR_DMW0)begin
            DMW0[`CSR_DMW0_MAT]  <= (csr_wmask[`CSR_DMW0_MAT] & csr_wvalue[`CSR_DMW0_MAT]) |
                                    (~csr_wmask[`CSR_DMW0_MAT] & DMW0[`CSR_DMW0_MAT]);
        end
        if (csr_we && csr_num == `CSR_DMW0)begin
            DMW0[`CSR_DMW0_PSEG] <= (csr_wmask[`CSR_DMW0_PSEG] & csr_wvalue[`CSR_DMW0_PSEG]) |
                                    (~csr_wmask[`CSR_DMW0_PSEG] & DMW0[`CSR_DMW0_PSEG]);
        end
        if (csr_we && csr_num == `CSR_DMW0)begin
            DMW0[`CSR_DMW0_VSEG] <= (csr_wmask[`CSR_DMW0_VSEG] & csr_wvalue[`CSR_DMW0_VSEG]) |
                                    (~csr_wmask[`CSR_DMW0_VSEG] & DMW0[`CSR_DMW0_VSEG]);
        end
    end
end

//【DMW1】 
always @(posedge clk)begin
    if(!resetn)begin
        DMW1[`CSR_DMW1_PLV0] <= 1'b0;
        DMW1[`CSR_DMW1_PLV3] <= 1'b0;
        DMW1[`CSR_DMW1_PSEG] <= 3'd0;
        DMW1[`CSR_DMW1_VSEG] <= 3'd0;
        DMW1[`CSR_DMW1_MAT]  <= 2'd0;
    end
    else begin
        if (csr_we && csr_num == `CSR_DMW1)begin
            DMW1[`CSR_DMW1_PLV0] <= (csr_wmask[`CSR_DMW1_PLV0] & csr_wvalue[`CSR_DMW1_PLV0]) |
                                    (~csr_wmask[`CSR_DMW1_PLV0] & DMW1[`CSR_DMW1_PLV0]);
        end                        
        if (csr_we && csr_num == `CSR_DMW1)begin
            DMW1[`CSR_DMW1_PLV3] <= (csr_wmask[`CSR_DMW1_PLV3] & csr_wvalue[`CSR_DMW1_PLV3]) |
                                    (~csr_wmask[`CSR_DMW1_PLV3] & DMW1[`CSR_DMW1_PLV3]);
        end
        if (csr_we && csr_num == `CSR_DMW1)begin
            DMW1[`CSR_DMW1_MAT]  <= (csr_wmask[`CSR_DMW1_MAT] & csr_wvalue[`CSR_DMW1_MAT]) |
                                    (~csr_wmask[`CSR_DMW1_MAT] & DMW1[`CSR_DMW1_MAT]);
        end
        if (csr_we && csr_num == `CSR_DMW1)begin
            DMW1[`CSR_DMW1_PSEG] <= (csr_wmask[`CSR_DMW1_PSEG] & csr_wvalue[`CSR_DMW1_PSEG]) |
                                    (~csr_wmask[`CSR_DMW1_PSEG] & DMW1[`CSR_DMW1_PSEG]);
        end
        if (csr_we && csr_num == `CSR_DMW1)begin
            DMW1[`CSR_DMW1_VSEG] <= (csr_wmask[`CSR_DMW1_VSEG] & csr_wvalue[`CSR_DMW1_VSEG]) |
                                    (~csr_wmask[`CSR_DMW1_VSEG] & DMW1[`CSR_DMW1_VSEG]);
        end
    end
end

//【PGDL】
always @(posedge clk)begin
    if (csr_we && csr_num == `CSR_PGDL)begin
        PGDL[`CSR_PGDL_BASE] <= (csr_wmask[`CSR_PGDL_BASE] & csr_wvalue[`CSR_PGDL_BASE]) |
                                (~csr_wmask[`CSR_PGDL_BASE] & PGDL[`CSR_PGDL_BASE]);
    end
end

//【PGDH】
always @(posedge clk)begin
    if (csr_we && csr_num == `CSR_PGDH)begin
        PGDH[`CSR_PGDH_BASE] <= (csr_wmask[`CSR_PGDH_BASE] & csr_wvalue[`CSR_PGDH_BASE]) |
                                (~csr_wmask[`CSR_PGDH_BASE] & PGDH[`CSR_PGDH_BASE]);
    end
end

// ----------WRITE IN END--------------
always @(posedge clk)begin
    // 手册没说resetn 时resetn应该默认清零
    if (!resetn)
        LLBCTL[`CSR_LLBCTL_ROLLB] <= 1'b0;
    else if (csr_we && csr_num == `CSR_LLBCTL)begin
        if(csr_wmask[`CSR_LLBCTL_WCLLB] & csr_wvalue[`CSR_LLBCTL_WCLLB])begin
            LLBCTL[`CSR_LLBCTL_ROLLB] <= 1'b0;
        end
    end
    else if (ertn_valid & ~LLBCTL[`CSR_LLBCTL_KLO])begin
        LLBCTL[`CSR_LLBCTL_ROLLB] <= 1'b0;
    end
    else if(LLbit_wb)begin
        LLBCTL[`CSR_LLBCTL_ROLLB] <= LLbit_wdata;
    end
end

always @(posedge clk)begin
    if (!resetn)begin
        LLBCTL[`CSR_LLBCTL_KLO] <= 1'b0;
    end
    else if(csr_we && csr_num == `CSR_LLBCTL)begin
        LLBCTL[`CSR_LLBCTL_KLO] <= (csr_wmask[`CSR_LLBCTL_KLO] & csr_wvalue[`CSR_LLBCTL_KLO]) |
                                   (~csr_wmask[`CSR_LLBCTL_KLO] & LLBCTL[`CSR_LLBCTL_KLO]);
    end
    else if (ertn_valid & LLBCTL[`CSR_LLBCTL_KLO])begin
        LLBCTL[`CSR_LLBCTL_KLO] <= 1'b0;
    end
end
// ----------TO PIPELINE END--------------

// ----------TO PIPELINE IN END--------------
assign  has_int        = (((ESTAT[`CSR_ESTAT_IS] & ECFG[`CSR_ECFG_LIE])!=13'b0) && (CRMD[`CSR_CRMD_IE] == 1'b1));
assign  csr_tcfg_init0 = (TCFG[`CSR_TCFG_INITVAL] == 30'b0);
assign  csr_CRMD_DA    = CRMD[`CSR_CRMD_DA];
assign  csr_CRMD_PG    = CRMD[`CSR_CRMD_PG];
assign  csr_CRMD_PLV   = CRMD[`CSR_CRMD_PLV];
// ---------- DMW0/1 begin --------------

//assign dmw_found0 = (vseg0_0 | vseg0_1) & (dmw0_plv_ok | dmw1_plv_ok);
assign  LLbit = LLBCTL[`CSR_LLBCTL_ROLLB];
// ---------- DMW0/1 end --------------

// ---------- READ --------------
wire    dmw0_plv_ok;
wire    dmw1_plv_ok;
assign  dmw0_plv_ok = (DMW0[`CSR_DMW0_PLV0] && csr_CRMD_PLV == 2'b00) ||
                      (DMW0[`CSR_DMW0_PLV3] && csr_CRMD_PLV == 2'b11);
assign  dmw1_plv_ok = (DMW1[`CSR_DMW1_PLV0] && csr_CRMD_PLV == 2'b00) ||
                      (DMW1[`CSR_DMW1_PLV3] && csr_CRMD_PLV == 2'b11);
// ( DMW0/1 preIF2 begin )
genvar  i0;
generate
    for (i0 = 0; i0 < ISSUE; i0 = i0 + 1) begin : gen_dmw_preIF2
        wire    vseg0_0        = (dmw_vseg0[i0] == DMW0[`CSR_DMW0_VSEG]);
        wire    vseg0_1        = (dmw_vseg0[i0] == DMW1[`CSR_DMW1_VSEG]);
        wire    dmw0_hit       = vseg0_0 & dmw0_plv_ok;
        wire    dmw1_hit       = vseg0_1 & dmw1_plv_ok;
        assign  dmw_found0[i0] = dmw0_hit | dmw1_hit;
        assign  dmw_mat0[i0]   = dmw0_hit ? DMW0[`CSR_DMW0_MAT]  : DMW1[`CSR_DMW1_MAT];
        assign  dmw_pseg0[i0]  = dmw0_hit ? DMW0[`CSR_DMW0_PSEG] : DMW1[`CSR_DMW1_PSEG];

        // ( DMW0/1 preIF2 end )
        wire    vseg1_0;   
        wire    vseg1_1;   
        assign  vseg1_0        = (dmw_vseg1[i0] == DMW0[`CSR_DMW0_VSEG]);
        assign  vseg1_1        = (dmw_vseg1[i0] == DMW1[`CSR_DMW0_VSEG]);
        assign  dmw_found1[i0] = (vseg1_0 & dmw0_plv_ok) | (vseg1_1 & dmw1_plv_ok);
        assign  dmw_mat1[i0]   = vseg1_0 ? DMW0[`CSR_DMW0_MAT]  : DMW1[`CSR_DMW1_MAT];
        assign  dmw_pseg1[i0]  = vseg1_0 ? DMW0[`CSR_DMW0_PSEG] : DMW1[`CSR_DMW0_PSEG];
    end
endgenerate

//TLB读接口,tlb寄存器单独写接口接到TLB

//mat:存储访问类型
wire   [31:0] csr_crmd_rvalue;
wire   [31:0] csr_prmd_rvalue;
wire   [31:0] csr_estat_rvalue;
//wire   [31:0] csr_era_rvalue;
//wire   [31:0] csr_eentry_rvalue;
wire   [31:0] csr_save0_rvalue;
wire   [31:0] csr_save1_rvalue;
wire   [31:0] csr_save2_rvalue;
wire   [31:0] csr_save3_rvalue;
wire   [31:0] csr_ticlr_rvalue;
wire   [31:0] csr_ecfg_rvalue;
wire   [31:0] csr_badv_rvalue;
wire   [31:0] csr_tid_rvalue;
wire   [31:0] csr_tcfg_rvalue;
wire   [31:0] csr_tval_rvalue;
wire   [31:0] csr_tlbidx_rvalue;
wire   [31:0] csr_tlbehi_rvalue;
wire   [31:0] csr_tlbelo0_rvalue;
wire   [31:0] csr_tlbelo1_rvalue;
wire   [31:0] csr_asid_rvalue;
//wire   [31:0] csr_tlbrentry_rvalue;
wire   [31:0] csr_dmw0_rvalue;
wire   [31:0] csr_dmw1_rvalue;
wire   [31:0] csr_llbctl_rvalue;
wire   [31:0] csr_euen_rvalue;
wire   [31:0] csr_pgdl_rvalue;
wire   [31:0] csr_pgdh_rvalue;
wire   [31:0] csr_pgd_rvalue;

assign        csr_crmd_rvalue        = {{23{1'b0}},CRMD[`CSR_CRMD_DATM],CRMD[`CSR_CRMD_DATF],CRMD[`CSR_CRMD_PG],CRMD[`CSR_CRMD_DA], CRMD[`CSR_CRMD_IE],CRMD[`CSR_CRMD_PLV]};
assign        csr_prmd_rvalue        = {{29{1'b0}},PRMD[`CSR_PRMD_PIE],PRMD[`CSR_PRMD_PPLV]};
assign        csr_estat_rvalue       = {{1{1'b0}},ESTAT[`CSR_ESTAT_ESUBCODE],ESTAT[`CSR_ESTAT_ECODE],{3{1'b0}},ESTAT[`CSR_ESTAT_IS12],ESTAT[`CSR_ESTAT_IS11],{1{1'b0}},ESTAT[`CSR_ESTAT_IS9_2],ESTAT[`CSR_ESTAT_IS1_0]};
assign        csr_era_rvalue         = ERA[`CSR_ERA_PC];
assign        csr_eentry_rvalue      = {EENTRY[`CSR_EENTRY_VA],{6{1'b0}}};
assign        csr_save0_rvalue       = SAVE0[`CSR_SAVE_DATA];
assign        csr_save1_rvalue       = SAVE1[`CSR_SAVE_DATA];
assign        csr_save2_rvalue       = SAVE2[`CSR_SAVE_DATA];
assign        csr_save3_rvalue       = SAVE3[`CSR_SAVE_DATA];
assign        csr_ticlr_rvalue       = 32'b0;
assign        csr_badv_rvalue        = BADV[`CSR_BADV_VADDR];
assign        csr_ecfg_rvalue        = {{19{1'b0}},ECFG[`CSR_ECFG_LIE]};
assign        csr_tid_rvalue         = TID[`CSR_TID_TID];
assign        csr_tcfg_rvalue        = {TCFG[`CSR_TCFG_INITVAL],TCFG[`CSR_TCFG_PERIOD],TCFG[`CSR_TCFG_EN]};
assign        csr_tval_rvalue        = timer_cnt[31:0];
assign        csr_tlbidx_rvalue      = {TLBIDX[`CSR_TLBIDX_NE],{1'b0},TLBIDX[`CSR_TLBIDX_PS],{8'b0},{16-$clog2(TLBNUM){1'b0}},TLBIDX[`CSR_TLBIDX_INDEX]};
assign        csr_tlbehi_rvalue      = {TLBEHI[`CSR_TLBEHI_VPPN],{13'b0}};
assign        csr_tlbelo0_rvalue     = {{4'b0}                   , TLBELO0[`CSR_TLBELO0_PPN], {1'b0}                 , TLBELO0[`CSR_TLBELO0_G], TLBELO0[`CSR_TLBELO0_MAT],
                                        TLBELO0[`CSR_TLBELO0_PLV], TLBELO0[`CSR_TLBELO0_D]  , TLBELO0[`CSR_TLBELO0_V]};
assign        csr_tlbelo1_rvalue     = {{4'b0}                   , TLBELO1[`CSR_TLBELO1_PPN], {1'b0}                 , TLBELO1[`CSR_TLBELO1_G], TLBELO1[`CSR_TLBELO1_MAT],
                                        TLBELO1[`CSR_TLBELO1_PLV], TLBELO1[`CSR_TLBELO1_D]  , TLBELO1[`CSR_TLBELO1_V]};
assign        csr_asid_rvalue        = {{8'b0},{8'ha},{6'b0},ASID[`CSR_ASID_ASID]};
assign        csr_tlbrentry_rvalue   = {TLBRENTRY[`CSR_TLBRENTRY_PA],{6'b0}};
assign        csr_dmw0_rvalue        = {DMW0[`CSR_DMW0_VSEG],{1{1'b0}},DMW0[`CSR_DMW0_PSEG],{19{1'b0}},DMW0[`CSR_DMW0_MAT],DMW0[`CSR_DMW0_PLV3],{2{1'b0}},DMW0[`CSR_DMW0_PLV0]};
assign        csr_dmw1_rvalue        = {DMW1[`CSR_DMW1_VSEG],{1{1'b0}},DMW1[`CSR_DMW1_PSEG],{19{1'b0}},DMW1[`CSR_DMW1_MAT],DMW1[`CSR_DMW1_PLV3],{2{1'b0}},DMW1[`CSR_DMW1_PLV0]};
assign        csr_llbctl_rvalue      = {29'h0,LLBCTL[`CSR_LLBCTL_KLO],1'b0,LLBCTL[`CSR_LLBCTL_ROLLB]};

assign        csr_euen_rvalue        = {31'd0,EUEN[`CSR_EUEN_FPE]};
assign        csr_pgdl_rvalue        = {PGDL[`CSR_PGDL_BASE],12'd0};
assign        csr_pgdh_rvalue        = {PGDH[`CSR_PGDH_BASE],12'd0};
assign        csr_pgd_rvalue         = BADV[31] ? csr_pgdh_rvalue : csr_pgdl_rvalue;

//write TLB接口
assign        r_index                = TLBIDX[`CSR_TLBIDX_INDEX];
assign        s0_asid                = ASID[`CSR_ASID_ASID];
assign        s1_asid_without_invtlb = ASID[`CSR_ASID_ASID];

//其余CSR读接口   
assign        csr_TLBIDX             = csr_tlbidx_rvalue;
assign        csr_TLBEHI             = csr_tlbehi_rvalue;

// ---------- READ END --------------
assign  csr_CRMD_DATF = CRMD[`CSR_CRMD_DATF];
assign  csr_CRMD_DATM = CRMD[`CSR_CRMD_DATM];

//write TLB接口
assign  w_index       = TLBIDX[`CSR_TLBIDX_INDEX];
assign  w_e           = (ESTAT[`CSR_ESTAT_ECODE] == 6'h3F) | ~TLBIDX[`CSR_TLBIDX_NE];
assign  w_vppn        = TLBEHI[`CSR_TLBEHI_VPPN];
assign  w_ps          = TLBIDX[`CSR_TLBIDX_PS];
assign  w_asid        = ASID[`CSR_ASID_ASID];
assign  w_g           = TLBELO0[`CSR_TLBELO0_G] & TLBELO1[`CSR_TLBELO1_G];
assign  w_ppn0        = TLBELO0[`CSR_TLBELO0_PPN];
assign  w_plv0        = TLBELO0[`CSR_TLBELO0_PLV];
assign  w_mat0        = TLBELO0[`CSR_TLBELO0_MAT];
assign  w_d0          = TLBELO0[`CSR_TLBELO0_D];
assign  w_v0          = TLBELO0[`CSR_TLBELO0_V];
assign  w_ppn1        = TLBELO1[`CSR_TLBELO1_PPN];
assign  w_plv1        = TLBELO1[`CSR_TLBELO1_PLV];
assign  w_mat1        = TLBELO1[`CSR_TLBELO1_MAT];
assign  w_d1          = TLBELO1[`CSR_TLBELO1_D];  
assign  w_v1          = TLBELO1[`CSR_TLBELO1_V];  
 
//CSR读接口   
assign  csr_rvalue    = ({32{csr_num == `CSR_CRMD}}      & csr_crmd_rvalue)           |
                        ({32{csr_num == `CSR_PRMD}}      & csr_prmd_rvalue)           |
                        ({32{csr_num == `CSR_ESTAT}}     & csr_estat_rvalue)          |
                        ({32{csr_num == `CSR_ERA}}       & csr_era_rvalue)            |
                        ({32{csr_num == `CSR_EENTRY}}    & csr_eentry_rvalue)         |
                        ({32{csr_num == `CSR_SAVE0}}     & csr_save0_rvalue)          |
                        ({32{csr_num == `CSR_SAVE1}}     & csr_save1_rvalue)          |
                        ({32{csr_num == `CSR_SAVE2}}     & csr_save2_rvalue)          |
                        ({32{csr_num == `CSR_SAVE3}}     & csr_save3_rvalue)          |
                        ({32{csr_num == `CSR_TICLR}}     & csr_ticlr_rvalue)          |
                        ({32{csr_num == `CSR_ECFG}}      & csr_ecfg_rvalue)           |
                        ({32{csr_num == `CSR_BADV}}      & csr_badv_rvalue)           |
                        ({32{csr_num == `CSR_TID}}       & csr_tid_rvalue)            |
                        ({32{csr_num == `CSR_TCFG}}      & csr_tcfg_rvalue)           |
                        ({32{csr_num == `CSR_TVAL}}      & csr_tval_rvalue)           |
                        ({32{csr_num == `CSR_TLBIDX}}    & csr_tlbidx_rvalue)         |
                        ({32{csr_num == `CSR_TLBEHI}}    & csr_tlbehi_rvalue)         |
                        ({32{csr_num == `CSR_TLBELO0}}   & csr_tlbelo0_rvalue)        |
                        ({32{csr_num == `CSR_TLBELO1}}   & csr_tlbelo1_rvalue)        |
                        ({32{csr_num == `CSR_ASID}}      & csr_asid_rvalue)           |
                        ({32{csr_num == `CSR_TLBRENTRY}} & csr_tlbrentry_rvalue)      |
                        ({32{csr_num == `CSR_DMW0}}      & csr_dmw0_rvalue)           |
                        ({32{csr_num == `CSR_DMW1}}      & csr_dmw1_rvalue)           |
                        ({32{csr_num == `CSR_LLBCTL}}    & csr_llbctl_rvalue)         |
                        ({32{csr_num == `CSR_EUEN}}      & csr_euen_rvalue)           |
                        ({32{csr_num == `CSR_PGDL}}      & csr_pgdl_rvalue)           |
                        ({32{csr_num == `CSR_PGDH}}      & csr_pgdh_rvalue)           |
                        ({32{csr_num == `CSR_PGD}}       & csr_pgd_rvalue);

// ---------- READ END --------------
endmodule
