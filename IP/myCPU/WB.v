`include "csr_def.vh"
module wb #(
    parameter inbus_width  = 32
)(
    input  wire        clk,
    input  wire        resetn,
    // ��ˮ�߿����ź�
    input  wire        MEM_WB_valid,
    input  wire        WB_allow_in,
    output wire        WB_ready_go,
    output reg         WB_valid,
    
    input  wire [inbus_width-1:0]MEM_WB_bus,// MEM��WB������
    // ���Խӿ�
    output wire [31:0] debug_wb_pc,
    output wire [ 3:0] debug_wb_rf_we,
    output wire [ 4:0] debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata,
    // ͨ�üĴ�����д�ؽӿ�
    output wire [ 4:0] rf_waddr,
    output wire [31:0] rf_wdata,
    output wire        rf_we,
    // ���������ͣ�ٿ���?
    output wire [ 4:0] WB_rf_dest,
    output wire        need_stall_csr,
    // д�ؼ�����ǰ��
    output wire [31:0] wb_front_data,
    output wire [ 4:0] wb_front_addr,
    // CSR��д�ӿ�
    output wire [13:0] csr_num,
    output wire        csr_re,
    input  wire [31:0] csr_rvalue,
    output wire        csr_we,
    output wire [31:0] csr_wdata,
    output wire [31:0] csr_wmask,
    // ERTN���쳣����ʱ��ˢ��ˮ�ߣ���������תĿ��
    output wire        flush,
    output wire [31:0] flush_target,
    // ��ˮ��ȡ������
    input  wire        WB_need_cancel,
    // �쳣��Ϣ
    output wire [31:0] wb_pc,
    output wire        wb_ex,
    output wire [5:0]  ecode,
    output wire [8:0]  esubcode,
    output wire [31:0] wb_vaddr,
    // ��ǰ�������쳣�����ź�
    output wire        WB_ex,
    // tlbrd ����csr��д��
    output wire        tlbrd_we,
    // tlbwr,tlbfill ����tlbд��
    output wire        tlbwr_we,
    output wire        tlbfill_we,
    // tlbidx
    input  wire [31:0] csr_TLBIDX,
    //tlbreload �����CSR
    output wire        ex_tlb_reload,
    // ERTN�����ġ�CRMD
    output wire        ertn_valid,
    // BADV
    output wire        csr_tlb_reload0,
    output wire        csr_tlb_plv0   ,//tlb��ҳ��Ȩ���Ϲ�
    output wire        csr_tlb_reload1,//tlb��������  
    output wire        csr_tlb_plv1,    //tlb��ҳ��Ȩ���Ϲ� 
    // ex_tlb --> TLBEHI
    output wire        ex_tlb,
    //can_not_front_push
    output wire        wb_can_not_front_push,
    //IDLE_stall
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
// �쳣���ͱ�־
wire        inst_syscall;
wire        inst_break;
wire        ex_INE;
wire        ex_IPE;
wire        ex_ADEF;
wire        ex_ALE;
//tlb_ex
wire        ex_tlb_reload0;//tlb��������
wire        ex_tlb_preif_unvalid;//tlb��ȡָҳ��Ч
wire        ex_tlb_plv0;//tlb��ҳ��Ȩ���Ϲ�
wire        ex_tlb_reload1;//tlb��������        
wire        ex_tlb_ld_unvalid;//tlb��loadҳ��Ч 
wire        ex_tlb_st_unvalid;//tlb��storeҳ��Ч
wire        ex_tlb_plv1;//tlb��ҳ��Ȩ���Ϲ�        
wire        ex_tlb_page_modify;//tlb��ҳ�޸�
wire        ex_tlb_plv;     
//IDLE
wire        inst_idle;
wire        inst_ertn;

wire        has_int;

// ��ʱ����ȡָ��
wire        inst_rdcntvl_w;
wire        inst_rdcntvh_w;
wire        inst_rdcntid;

//**************** tlb begin ****************
wire        inst_tlbsrch;
wire        inst_tlbrd;
wire [10:0] TLBIDX_new_tlbsrch;
wire        inst_tlbwr;
wire        inst_tlbfill;
wire        inst_invtlb;

assign tlbrd_we   = inst_tlbrd & WB_valid & ~wb_ex;
assign tlbwr_we   = inst_tlbwr & WB_valid & ~wb_ex;
assign tlbfill_we = inst_tlbfill & WB_valid & ~wb_ex;
//**************** tlb end ****************

wire [31:0] alu_result_with_rdct;
wire        csr_WB_rd;
wire        csr_rd_WB_each;

assign csr_WB_rd = inst_csrrd | inst_csrwr | inst_csrxchg | inst_rdcntid;
assign csr_rd_WB_each = inst_csrwr | inst_csrxchg;
always @(posedge clk)begin
    if(!resetn)begin
        bus<={inbus_width{1'b0}};
    end
    else if (MEM_WB_valid && WB_allow_in) begin
        bus<=MEM_WB_bus;
    end
end
// csr_num_wr��MEM�������ָ���?ʼCSR��ţ�ERTN���쳣��RDCNTID����WB����ѡ����CSR
assign {
        pc,need_stall_csr,alu_result_with_rdct,
        inst_csrrd, inst_csrwr,inst_csrxchg,inst_ertn,inst_syscall,inst_break,ex_INE,ex_IPE,ex_ADEF,ex_ALE,has_int,inst_rdcntvl_w,inst_rdcntvh_w,inst_rdcntid,csr_num_wr,mem_we,rj_value,rkd_value,rf_dest,rf_alu_wdata,rf_gr_we_ex,
        inst_tlbsrch,TLBIDX_new_tlbsrch,inst_tlbrd,inst_tlbwr,inst_tlbfill,inst_invtlb,//WB
        ex_tlb_reload0,ex_tlb_preif_unvalid,ex_tlb_plv0,ex_tlb_reload1,ex_tlb_ld_unvalid,ex_tlb_st_unvalid,ex_tlb_plv1,ex_tlb_page_modify,inst_idle
    }=bus;

assign rf_wdata   = csr_WB_rd ? csr_rvalue :  rf_alu_wdata;
assign rf_waddr   = rf_dest;
assign rf_we      = rf_gr_we_ex & WB_valid & ~wb_ex;
assign csr_wmask  = (inst_csrwr | inst_tlbsrch) ? 32'hffffffff : rj_value;
assign csr_wdata  = inst_tlbsrch ? {TLBIDX_new_tlbsrch[10],csr_TLBIDX[30:10],TLBIDX_new_tlbsrch[9:0]} : rkd_value;
assign csr_we     = (inst_tlbsrch | csr_rd_WB_each) & WB_valid & ~wb_ex;
assign flush      = (inst_ertn | inst_csrwr | inst_csrxchg | inst_tlbfill | inst_tlbwr | inst_tlbrd | inst_tlbsrch | wb_ex | inst_idle) & WB_valid;
assign csr_re     = (csr_WB_rd | flush) & WB_valid;
assign csr_num    = has_int         ? `CSR_EENTRY      :
                    ex_ADEF         ? `CSR_EENTRY      :
                    ex_tlb_preif_unvalid ? `CSR_EENTRY :
                    ex_tlb_plv0     ? `CSR_EENTRY      :
                    ex_tlb_reload0  ? `CSR_TLBRENTRY   :
                    ex_INE          ? `CSR_EENTRY      :
                    ex_IPE          ? `CSR_EENTRY      :
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
                      ? wb_pc + 4
                      : csr_rvalue;
// tlb �쳣
// 真的有异常才能触发 防止 reg 旧缓存影响
/*
assign ex_tlb_reload = WB_valid & (ex_tlb_reload0 | ex_tlb_reload1);
assign ex_tlb        = WB_valid & (ex_tlb_reload0 | ex_tlb_reload1 | ex_tlb_preif_unvalid |
                                ex_tlb_plv0 | ex_tlb_plv1 | ex_tlb_ld_unvalid |
                                ex_tlb_st_unvalid | ex_tlb_page_modify);
*/
assign ex_tlb_reload = WB_valid & (ecode == `ECODE_TLBR);
assign ex_tlb        = WB_valid & ((ecode == `ECODE_PIF)  |
                                   (ecode == `ECODE_PPI)  |
                                   (ecode == `ECODE_TLBR) |
                                   (ecode == `ECODE_PIL)  |
                                   (ecode == `ECODE_PIS)  |
                                   (ecode == `ECODE_PME));

assign wb_pc      = pc;
assign wb_ex      = (inst_syscall | inst_break | ex_INE | ex_ADEF | 
                     ex_ALE       | has_int    | ex_tlb | ex_IPE  ) & WB_valid;
assign ex_tlb_plv = ex_tlb_plv0 | ex_tlb_plv1;
// ��ַ�������쳣ʱ����¼load/storeָ�������ķô���?
assign wb_vaddr   = alu_result_with_rdct;
assign ecode      = has_int         ? `ECODE_INT  :
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

assign esubcode    = has_int              ? `ESUBCODE_INT   : 
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
//-------------CSR-------------

//------------------------{BADV}begin-------------------------//
assign csr_tlb_reload0 = ex_tlb_reload0 & WB_valid;
assign csr_tlb_plv0    = ex_tlb_plv0    & WB_valid;
assign csr_tlb_reload1 = ex_tlb_reload1 & WB_valid;
assign csr_tlb_plv1    = ex_tlb_plv1    & WB_valid;
//------------------------{BADV}begin-------------------------//

//------------------------{ready_go}begin-------------------------//
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
//------------------------{ready_go}end-------------------------//

//------------------------{ertn_valid}begin-------------------------//
assign ertn_valid = inst_ertn & WB_valid & ~wb_ex;
//------------------------{ertn_valid}end-------------------------//

//------------------------{front_push}begin-------------------------//
assign wb_front_data = rf_wdata;
assign wb_front_addr = rf_dest;
assign wb_can_not_front_push = ~rf_gr_we_ex;
//------------------------{front_push}end-------------------------//

//------------------------{IDLE_stall}end-------------------------//
assign IDLE_stall = inst_idle & WB_valid & ~WB_ex;
//------------------------{IDLE_stall}end-------------------------//

//------------------------{exp_front}begin-------------------------//
assign WB_ex = WB_valid &
               (inst_syscall | inst_ertn | inst_break | ex_INE | ex_IPE |
                ex_ADEF      | ex_ALE    | has_int    | ex_tlb );
//------------------------{exp_front}end-------------------------//

//------------------------{debug_var}begin-------------------------//
assign debug_wb_pc = pc;
assign debug_wb_rf_wdata = rf_wdata;
assign debug_wb_rf_we = {4{rf_we}};
assign debug_wb_rf_wnum = rf_dest;
assign WB_rf_dest = rf_dest;
//------------------------{debug_var}end-------------------------//

endmodule
