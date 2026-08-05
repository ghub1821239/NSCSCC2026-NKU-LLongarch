`include "csr_def.vh"
module csr_regfile#(
    parameter TLBNUM  = 16
)(
    input  wire        clk,
    input  wire        resetn,
    // write
    input  wire        csr_we,
    input  wire [31:0] csr_wmask,
    input  wire [13:0] csr_num,
    // д������ڵı��?������Ϊcsrwcfg���ָ����漰��rj��д�������⣬�����Ƿŵ���csr����д���������Ҳ������decode�Ĺؼ�·���䳤
    input  wire [31:0] csr_wvalue,
    // read port
    input  wire        csr_re,
    output wire [31:0] csr_rvalue,
    // ex �����쳣
    input  wire        wb_ex,

    input  wire  [5:0] wb_ecode,
    input  wire  [8:0] wb_esubcode,

    // Ӳ���쳣8λ
    input  wire [7:0]  hw_int_in,
    input  wire        ipi_int_in,

    // ERA �洢ʹ�ã������쳣��pc
    input  wire [31:0] wb_pc,
    // BAVD ��¼����ĵ��?
    input  wire [31:0] wb_vaddr,

    // decode
    output wire        has_int,
    
    //coreid
    input  wire [31:0] coreid_in,

    // TLB CSR outputs for EXE/WB
    output wire [31:0] csr_TLBEHI,
    output wire [31:0] csr_TLBIDX,
    // CRMD ������ˮ������PLVȨ���ж�
    output wire  [1:0] csr_CRMD_PLV,
    
    //tlbrd�ӿ� read port
    output  wire [$clog2(TLBNUM)-1:0] r_index,
    output  wire [9:0]  s0_asid,
    output  wire [9:0]  s1_asid_without_invtlb,
    input   wire        tlbrd_we,
    input   wire        r_e,
    input   wire [18:0] r_vppn,
    input   wire [5:0]  r_ps,
    input   wire [9:0]  r_asid,
    input   wire        r_g,
    input   wire [19:0] r_ppn0,
    input   wire [1:0]  r_plv0,
    input   wire [1:0]  r_mat0,
    input   wire        r_d0,
    input   wire        r_v0,
    input   wire [19:0] r_ppn1,
    input   wire [1:0]  r_plv1,
    input   wire [1:0]  r_mat1,
    input   wire        r_d1,
    input   wire        r_v1,
    // write port
    output  wire [$clog2(TLBNUM)-1:0] w_index,
    output  wire        w_e,
    output  wire [18:0] w_vppn,
    output  wire [5:0]  w_ps,
    output  wire [9:0]  w_asid,
    output  wire        w_g,
    output  wire [19:0] w_ppn0,
    output  wire [1:0]  w_plv0,
    output  wire [1:0]  w_mat0,
    output  wire        w_d0,
    output  wire        w_v0,
    output  wire [19:0] w_ppn1,
    output  wire [1:0]  w_plv1,
    output  wire [1:0]  w_mat1,
    output  wire        w_d1,
    output  wire        w_v1,
    // CRMD ��������?�߽����ж����뷽ʽ
    output  wire        csr_CRMD_DA,
    output  wire        csr_CRMD_PG,
    // CRMD�����쳣
    input   wire        ex_tlb_reload,
    // DMW0/1 
    input   wire  [2:0] dmw_vseg0,
    output  wire        dmw_found0,
    output  wire  [2:0] dmw_pseg0,

    input   wire  [2:0] dmw_vseg1,
    output  wire        dmw_found1,
    output  wire  [2:0] dmw_pseg1,

    //ERTN ����ָ��ظ���CRMD
    input   wire        inst_ertn,
    
    //BADV
    input   wire        csr_tlb_reload0,
    input   wire        csr_tlb_plv0   ,
    input   wire        csr_tlb_reload1,  
    input   wire        csr_tlb_plv1   ,
    // ex_tlb TLBEHI
    input   wire        ex_tlb,
    //mat:�洢��������
    output   wire  [1:0] csr_CRMD_DATF,
    output   wire  [1:0] csr_CRMD_DATM,
    output   wire  [1:0] dmw_mat0,
    output   wire  [1:0] dmw_mat1,
    //LLbit
    input    wire        LLbit_wb,
    output   wire        LLbit
);

// ----------DEFINE--------------
reg [31:0] CRMD;
reg [31:0] PRMD;
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
// ----------DEFINE END----------

// ----------WRITE IN--------------

//��CRMD PLV�� ��Ȩ�ȼ�
always @ (posedge clk)begin
    // �����ֲ�6.3��λָ��
    if(!resetn)begin
        CRMD[`CSR_CRMD_PLV] <= 2'b0;
    end
    // ���д�ؽ׶α��������?ת���ں�̬�����쳣����
    else if(wb_ex)begin
        CRMD[`CSR_CRMD_PLV] <= 2'b0;
    end
    // �������ertn����ʾ�쳣�Ѿ������꣬��Ҫ�ָ����쳣����ǰ����Ȩ�ȼ�
    else if (inst_ertn) begin
        CRMD[`CSR_CRMD_PLV] <= PRMD [`CSR_PRMD_PPLV];
    end
    // ���дCRMD����д������£�?
    // 1. ����Ϊ1��λд��csr_wvalue��Ӧλ
    // 2. ����Ϊ0��λ����ԭֵ
    // ��������ְ�λ��ϲ�
    else if (csr_we & csr_num == `CSR_CRMD)begin
        CRMD[`CSR_CRMD_PLV] <= (csr_wmask[`CSR_CRMD_PLV] & csr_wvalue[`CSR_CRMD_PLV]) | 
                               (~csr_wmask[`CSR_CRMD_PLV] & CRMD[`CSR_CRMD_PLV]);
    end
end
//��CRMD IE���Ƿ�������Ӧ�ж�
always @ (posedge clk)begin
    if(!resetn)begin
        CRMD[`CSR_CRMD_IE] <= 1'b0;
    end
    // �����쳣���������CRMD��IEλ��0���������쳣�����ڼ��ٴ���Ӧ�ж�
    else if(wb_ex)begin
        CRMD[`CSR_CRMD_IE] <= 1'b0;
    end
    else if (inst_ertn) begin
        CRMD[`CSR_CRMD_IE] <= PRMD [`CSR_PRMD_PIE];
    end
    else if (csr_we & csr_num == `CSR_CRMD)begin
        CRMD[`CSR_CRMD_IE] <= (csr_wmask[`CSR_CRMD_IE] & csr_wvalue[`CSR_CRMD_IE]) | 
                               (~csr_wmask[`CSR_CRMD_IE] & CRMD[`CSR_CRMD_IE]);
    end
end
//��CRMD DA & PG & DATF & DATM����Щ�ֶ�������TLB��Ż�ʹ�ã��˴������ø�λ�?
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
        else if (inst_ertn && ESTAT[`CSR_ESTAT_ECODE] == 6'h3F) begin
            CRMD[`CSR_CRMD_DA]   <= 1'b0;
            CRMD[`CSR_CRMD_PG]   <= 1'b1;
            // �Ƽ��� ����ָ���ֲ�����
//            CRMD[`CSR_CRMD_DATF] <= 2'b00;
//            CRMD[`CSR_CRMD_DATM] <= 2'b01;
        end
        else begin
            if (csr_we & csr_num == `CSR_CRMD)begin
                CRMD[`CSR_CRMD_DA] <= (csr_wmask[`CSR_CRMD_DA] & csr_wvalue[`CSR_CRMD_DA]) | 
                                    (~csr_wmask[`CSR_CRMD_DA] & CRMD[`CSR_CRMD_DA]);
            end
            if (csr_we & csr_num == `CSR_CRMD)begin
                CRMD[`CSR_CRMD_PG] <= (csr_wmask[`CSR_CRMD_PG] & csr_wvalue[`CSR_CRMD_PG]) | 
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

//��PRMD PPLV�������쳣����ǰ����Ȩ�ȼ�
always @(posedge clk)begin
    if(wb_ex)begin
        PRMD[`CSR_PRMD_PPLV] <= CRMD[`CSR_CRMD_PLV];
    end
    else if (csr_we & csr_num == `CSR_PRMD)begin
        PRMD[`CSR_PRMD_PPLV] <= (csr_wmask[`CSR_PRMD_PPLV] & csr_wvalue[`CSR_PRMD_PPLV]) | 
                               (~csr_wmask[`CSR_PRMD_PPLV] & PRMD[`CSR_PRMD_PPLV]);
    end
end
//��PRMD PIE�������쳣����ǰ��ȫ���ж�ʹ��λ
always @(posedge clk)begin
    if (wb_ex)begin
        PRMD[`CSR_PRMD_PIE] <= CRMD[`CSR_CRMD_IE];
    end
    else if (csr_we & csr_num == `CSR_PRMD)begin
        PRMD[`CSR_PRMD_PIE] <= (csr_wmask[`CSR_PRMD_PIE] & csr_wvalue[`CSR_PRMD_PIE]) | 
                               (~csr_wmask[`CSR_PRMD_PIE] & PRMD[`CSR_PRMD_PIE]);
    end
end

//��ERA���쳣���ص�ַ
// �����쳣��ʱ��wb_ex�ᴥ���ѵ�ǰ���쳣pcд��era
// ����syscall��brk����ֻ��Ҫ����ת��eentry����
always @(posedge clk)begin
    if (wb_ex)begin
        ERA[`CSR_ERA_PC] <= wb_pc;
    end
    else if (csr_we & csr_num == `CSR_ERA)begin
        ERA[`CSR_ERA_PC] <= (csr_wmask[`CSR_ERA_PC] & csr_wvalue[`CSR_ERA_PC]) |
                            (~csr_wmask[`CSR_ERA_PC] & ERA[`CSR_ERA_PC]);
    end
end

//��EENTRY���쳣��ڵ��?
always @ (posedge clk)begin
    if (csr_we & csr_num == `CSR_EENTRY)begin
        EENTRY[`CSR_EENTRY_VA] <= (csr_wmask[`CSR_EENTRY_VA] & csr_wvalue[`CSR_EENTRY_VA]) |
                                  (~csr_wmask[`CSR_EENTRY_VA] & EENTRY[`CSR_EENTRY_VA]);
    end
end

//��SAVE 0~3�����ݱ���Ĵ���?
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

//��TICLR����ʱ���ж�����Ĵ���?

//��ECFG��
//��todo�� checkһ��������ESTAT ���� ECFG
always @ (posedge clk)begin
    if(!resetn)begin
        ECFG[`CSR_ECFG_LIE] <= 13'b0;
    end
    else if (csr_we & csr_num == `CSR_ECFG)begin
        ECFG[`CSR_ECFG_LIE] <= (csr_wmask[`CSR_ECFG_LIE] & csr_wvalue[`CSR_ECFG_LIE] & 13'h1bff) |
                                (~csr_wmask[`CSR_ECFG_LIE] & ECFG[`CSR_ECFG_LIE] & 13'h1bff);
    end
end
    

//��BADV���쳣������ַ
wire wb_ex_addr_err;
wire ex_preIF_tlb;
assign wb_ex_addr_err = wb_ecode == `ECODE_ADE || wb_ecode == `ECODE_ALE || wb_ecode == `ECODE_PIL ||
                        wb_ecode == `ECODE_PIS || wb_ecode == `ECODE_PIF || wb_ecode == `ECODE_PME ||
                        wb_ecode == `ECODE_PPI || wb_ecode == `ECODE_TLBR;
assign ex_preIF_tlb   = (wb_ecode == `ECODE_PIF) | (wb_ecode == `ECODE_TLBR & csr_tlb_reload0) | (wb_ecode == `ECODE_PPI & csr_tlb_plv0);
always @ (posedge clk)begin
    if(wb_ex && wb_ex_addr_err)begin
        BADV[`CSR_BADV_VADDR] <= (wb_ecode == `ECODE_ADE & wb_esubcode == `ESUBCODE_ADEF) | ex_preIF_tlb
                                ? wb_pc : wb_vaddr;
    end
end

//��TID����λʱ����coreid��Ҳ��ͨ��CSRָ��д��
always @ (posedge clk)begin
    if(!resetn)begin
        TID[`CSR_TID_TID] <= coreid_in;
    end
    else if (csr_we && csr_num == `CSR_TID)begin
        TID[`CSR_TID_TID] <= (csr_wmask[`CSR_TID_TID] & csr_wvalue[`CSR_TID_TID]) |
                            (~csr_wmask[`CSR_TID_TID] & TID[`CSR_TID_TID]);
    end
end

//��TCFG�����ƶ�ʱ���ĳ�ʼֵ��ѭ��ģʽ��ʹ��λ
always @ (posedge clk)begin
    if(!resetn)begin
        TCFG[`CSR_TCFG_EN] <= 1'b0;
    end
    else if (csr_we && csr_num == `CSR_TCFG)begin
        TCFG[`CSR_TCFG_EN] <= (csr_wmask[`CSR_TCFG_EN] & csr_wvalue[`CSR_TCFG_EN]) |
                            (~csr_wmask[`CSR_TCFG_EN] & TCFG[`CSR_TCFG_EN]);
    end
    if(csr_we && csr_num == `CSR_TCFG)begin
        TCFG[`CSR_TCFG_PERIOD] <= (csr_wmask[`CSR_TCFG_PERIOD] & csr_wvalue[`CSR_TCFG_PERIOD]) |
                            (~csr_wmask[`CSR_TCFG_PERIOD] & TCFG[`CSR_TCFG_PERIOD]);
        TCFG[`CSR_TCFG_INITVAL] <= (csr_wmask[`CSR_TCFG_INITVAL] & csr_wvalue[`CSR_TCFG_INITVAL]) |
                            (~csr_wmask[`CSR_TCFG_INITVAL] & TCFG[`CSR_TCFG_INITVAL]);
    end
end

reg [31:0] timer_cnt;
// �µ�TCFG
wire [31:0] TCFG_next_val;
assign TCFG_next_val = csr_wmask[31:0] & csr_wvalue[31:0] | ~csr_wmask[31:0] & TCFG[31:0];
always @ (posedge clk) begin
    if (!resetn) begin
        timer_cnt <= 32'hffffffff;
    end
    // ��Ч&�Լ�
    else if (csr_we && csr_num == `CSR_TCFG && TCFG_next_val[`CSR_TCFG_EN]) begin
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

//��ESTAT IS���ж�״̬λ
always @(posedge clk)begin
    //�����жϡ�
    if (!resetn)begin
        ESTAT[`CSR_ESTAT_IS1_0] <= 2'b0;
    end
    else if (csr_we & csr_num == `CSR_ESTAT)begin
        ESTAT[`CSR_ESTAT_IS1_0] <= (csr_wmask[`CSR_ESTAT_IS1_0] & csr_wvalue[`CSR_ESTAT_IS1_0]) | 
                                    (~csr_wmask[`CSR_ESTAT_IS1_0] & ESTAT[`CSR_ESTAT_IS1_0]);
    end                            
    //��Ӳ�жϡ���hw_int_in���룻δ����Ӳ���ж�ԴʱӦ����0
    ESTAT[`CSR_ESTAT_IS9_2] <= hw_int_in[7:0];

    //������λ��
    ESTAT[10] <= 1'b0;

    //����ʱ���жϡ�
    if(timer_cnt[31:0] == 32'b0)begin
        ESTAT[`CSR_ESTAT_IS11] <= 1'b1;
    end
    // TICLR�Ķ�ֵ��Ϊ0��д��CLRλʱֱ�������ʱ���ж�״�?
    else if (csr_we && csr_num == `CSR_TICLR && csr_wmask[`CSR_TICLR_CLR] && csr_wvalue[`CSR_TICLR_CLR])begin
        ESTAT[`CSR_ESTAT_IS11] <= 1'b0;
    end

    //���˼��жϡ�
    ESTAT[`CSR_ESTAT_IS12] <= ipi_int_in;
end
//��ESTAT Ecode & Esubcode���쳣���ͺ��쳣������
always @(posedge clk)begin
    if(wb_ex)begin
        ESTAT[`CSR_ESTAT_ECODE] <= wb_ecode;
        ESTAT[`CSR_ESTAT_ESUBCODE] <= wb_esubcode;
    end
end

//��TLBIDX INDEX��TLB��Index��
always @(posedge clk) begin
    if(csr_we && csr_num == `CSR_TLBIDX) begin
        TLBIDX[`CSR_TLBIDX_INDEX] <= (csr_wmask[`CSR_TLBIDX_INDEX] & csr_wvalue[`CSR_TLBIDX_INDEX]) |
                                     (~csr_wmask[`CSR_TLBIDX_INDEX] & TLBIDX[`CSR_TLBIDX_INDEX]);
    end
end
//��TLBIDX PS��TLB��ҳ����?(4KB/4MB)
always @(posedge clk) begin
    //tlbrd��ȡ������Ч��
    if (tlbrd_we & r_e == 1) begin
        TLBIDX[`CSR_TLBIDX_PS] <= r_ps;
    end
    //tlbrd��ȡ������Ч��
    if (tlbrd_we & r_e == 0) begin
        TLBIDX[`CSR_TLBIDX_PS] <= 6'b0;
    end
    if (csr_we && csr_num == `CSR_TLBIDX) begin
        TLBIDX[`CSR_TLBIDX_PS] <= (csr_wmask[`CSR_TLBIDX_PS] & csr_wvalue[`CSR_TLBIDX_PS]) |
                                  (~csr_wmask[`CSR_TLBIDX_PS] & TLBIDX[`CSR_TLBIDX_PS]);
    end
end
//��TLBIDX NE��TLB����Чλ
always @(posedge clk) begin
    //tlbrd��ȡ������Ч��
    if (tlbrd_we & r_e == 1) begin
        TLBIDX[`CSR_TLBIDX_NE] <= 1'b0;
    end
    //tlbrd��ȡ������Ч��
    if (tlbrd_we & r_e == 0) begin
        TLBIDX[`CSR_TLBIDX_NE] <= 1'b1;
    end
    if (csr_we && csr_num == `CSR_TLBIDX) begin
        TLBIDX[`CSR_TLBIDX_NE] <= (csr_wmask[`CSR_TLBIDX_NE] & csr_wvalue[`CSR_TLBIDX_NE]) |
                                  (~csr_wmask[`CSR_TLBIDX_NE] & TLBIDX[`CSR_TLBIDX_NE]);
    end
end

//��TLBEHI VPPN��TLB�����λ��VPPN
wire [18:0] err_vppn;
assign err_vppn = ex_preIF_tlb ? wb_pc[31:13] : wb_vaddr[31:13]; 
always @(posedge clk) begin
    //tlbrd��ȡ������Ч��
    if (tlbrd_we & r_e == 1) begin
        TLBEHI[`CSR_TLBEHI_VPPN] <= r_vppn;
    end
    //tlbrd��ȡ������Ч��
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

//��TLBELO0��TLB����ĵ�λ���?,ż��ҳ��
always @(posedge clk) begin
    //tlbrd��ȡ������Ч��
    if (tlbrd_we & r_e == 1) begin
        TLBELO0[`CSR_TLBELO0_V] <= r_v0;
        TLBELO0[`CSR_TLBELO0_D] <= r_d0;
        TLBELO0[`CSR_TLBELO0_PLV] <= r_plv0;
        TLBELO0[`CSR_TLBELO0_MAT] <= r_mat0;
        TLBELO0[`CSR_TLBELO0_G]   <= r_g;
        TLBELO0[`CSR_TLBELO0_PPN] <= r_ppn0;
    end
    //tlbrd��ȡ������Ч��
    if (tlbrd_we & r_e == 0) begin
        TLBELO0[`CSR_TLBELO0_V] <= 1'b0;
        TLBELO0[`CSR_TLBELO0_D] <= 1'b0;
        TLBELO0[`CSR_TLBELO0_PLV] <= 2'b0;
        TLBELO0[`CSR_TLBELO0_MAT] <= 2'b0;
        TLBELO0[`CSR_TLBELO0_G]   <= 1'b0;
        TLBELO0[`CSR_TLBELO0_PPN] <= 24'b0;
    end
    if (csr_we && csr_num == `CSR_TLBELO0) begin
        TLBELO0[`CSR_TLBELO0_V] <= (csr_wmask[`CSR_TLBELO0_V] & csr_wvalue[`CSR_TLBELO0_V]) |
                                 (~csr_wmask[`CSR_TLBELO0_V] & TLBELO0[`CSR_TLBELO0_V]);
        TLBELO0[`CSR_TLBELO0_D] <= (csr_wmask[`CSR_TLBELO0_D] & csr_wvalue[`CSR_TLBELO0_D]) |
                                 (~csr_wmask[`CSR_TLBELO0_D] & TLBELO0[`CSR_TLBELO0_D]);
        TLBELO0[`CSR_TLBELO0_PLV] <= (csr_wmask[`CSR_TLBELO0_PLV] & csr_wvalue[`CSR_TLBELO0_PLV]) |
                                 (~csr_wmask[`CSR_TLBELO0_PLV] & TLBELO0[`CSR_TLBELO0_PLV]);
        TLBELO0[`CSR_TLBELO0_MAT] <= (csr_wmask[`CSR_TLBELO0_MAT] & csr_wvalue[`CSR_TLBELO0_MAT]) |
                                 (~csr_wmask[`CSR_TLBELO0_MAT] & TLBELO0[`CSR_TLBELO0_MAT]);
        TLBELO0[`CSR_TLBELO0_G] <= (csr_wmask[`CSR_TLBELO0_G] & csr_wvalue[`CSR_TLBELO0_G]) |
                                 (~csr_wmask[`CSR_TLBELO0_G] & TLBELO0[`CSR_TLBELO0_G]);
        TLBELO0[`CSR_TLBELO0_PPN] <= (csr_wmask[`CSR_TLBELO0_PPN] & csr_wvalue[`CSR_TLBELO0_PPN]) |
                                 (~csr_wmask[`CSR_TLBELO0_PPN] & TLBELO0[`CSR_TLBELO0_PPN]);
    end
end

//��TLBELO1��TLB����ĵ�λ���?,����ҳ��
always @(posedge clk) begin
    //tlbrd��ȡ������Ч��
    if (tlbrd_we & r_e == 1) begin
        TLBELO1[`CSR_TLBELO1_V] <= r_v1;
        TLBELO1[`CSR_TLBELO1_D] <= r_d1;
        TLBELO1[`CSR_TLBELO1_PLV] <= r_plv1;
        TLBELO1[`CSR_TLBELO1_MAT] <= r_mat1;
        TLBELO1[`CSR_TLBELO1_G]   <= r_g;
        TLBELO1[`CSR_TLBELO1_PPN] <= r_ppn1;
    end
    //tlbrd��ȡ������Ч��
    if (tlbrd_we & r_e == 0) begin
        TLBELO1[`CSR_TLBELO1_V] <= 1'b0;
        TLBELO1[`CSR_TLBELO1_D] <= 1'b0;
        TLBELO1[`CSR_TLBELO1_PLV] <= 2'b0;
        TLBELO1[`CSR_TLBELO1_MAT] <= 2'b0;
        TLBELO1[`CSR_TLBELO1_G]   <= 1'b0;
        TLBELO1[`CSR_TLBELO1_PPN] <= 24'b0;
    end
    if (csr_we && csr_num == `CSR_TLBELO1) begin
        TLBELO1[`CSR_TLBELO1_V] <= (csr_wmask[`CSR_TLBELO1_V] & csr_wvalue[`CSR_TLBELO1_V]) |
                                 (~csr_wmask[`CSR_TLBELO1_V] & TLBELO1[`CSR_TLBELO1_V]);
        TLBELO1[`CSR_TLBELO1_D] <= (csr_wmask[`CSR_TLBELO1_D] & csr_wvalue[`CSR_TLBELO1_D]) |
                                 (~csr_wmask[`CSR_TLBELO1_D] & TLBELO1[`CSR_TLBELO1_D]);
        TLBELO1[`CSR_TLBELO1_PLV] <= (csr_wmask[`CSR_TLBELO1_PLV] & csr_wvalue[`CSR_TLBELO1_PLV]) |
                                 (~csr_wmask[`CSR_TLBELO1_PLV] & TLBELO1[`CSR_TLBELO1_PLV]);
        TLBELO1[`CSR_TLBELO1_MAT] <= (csr_wmask[`CSR_TLBELO1_MAT] & csr_wvalue[`CSR_TLBELO1_MAT]) |
                                 (~csr_wmask[`CSR_TLBELO1_MAT] & TLBELO1[`CSR_TLBELO1_MAT]);
        TLBELO1[`CSR_TLBELO1_G] <= (csr_wmask[`CSR_TLBELO1_G] & csr_wvalue[`CSR_TLBELO1_G]) |
                                 (~csr_wmask[`CSR_TLBELO1_G] & TLBELO1[`CSR_TLBELO1_G]);
        TLBELO1[`CSR_TLBELO1_PPN] <= (csr_wmask[`CSR_TLBELO1_PPN] & csr_wvalue[`CSR_TLBELO1_PPN]) |
                                 (~csr_wmask[`CSR_TLBELO1_PPN] & TLBELO1[`CSR_TLBELO1_PPN]);
    end
end

//��ASID��TLBָ��ĵ�ַ�ռ��ʶ��
always @(posedge clk) begin
    //ASIDBITS
    if (!resetn) begin
        ASID[`CSR_ASID_ASIDBITS] <= 8'ha;
    end
    //tlbrd��ȡ������Ч��
    if (tlbrd_we & r_e == 0) begin
        ASID[`CSR_ASID_ASID] <= 10'b0;
    end
    //tlbrd��ȡ������Ч��
    if (tlbrd_we & r_e == 1) begin
        ASID[`CSR_ASID_ASID] <= r_asid;
    end
    if (csr_we && csr_num == `CSR_ASID) begin
        ASID[`CSR_ASID_ASID] <= (csr_wmask[`CSR_ASID_ASID] & csr_wvalue[`CSR_ASID_ASID]) |
                                 (~csr_wmask[`CSR_ASID_ASID] & ASID[`CSR_ASID_ASID]);
    end
end

//��TLBRENTY PA��TLB������������ʱ��д��������������?
always @(posedge clk) begin
    if (csr_we && csr_num == `CSR_TLBRENTRY) begin
        TLBRENTRY[`CSR_TLBRENTRY_PA] <= (csr_wmask[`CSR_TLBRENTRY_PA] & csr_wvalue[`CSR_TLBRENTRY_PA]) |
                                        (~csr_wmask[`CSR_TLBRENTRY_PA] & TLBRENTRY[`CSR_TLBRENTRY_PA]);
    end
end

//��DMW0�� 
always @(posedge clk)begin
    if(!resetn)begin
        DMW0[`CSR_DMW0_PLV0] <= 1'b0;
        DMW0[`CSR_DMW0_PLV3] <= 1'b0;
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
            DMW0[`CSR_DMW0_MAT] <= (csr_wmask[`CSR_DMW0_MAT] & csr_wvalue[`CSR_DMW0_MAT]) |
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

//��DMW1�� 
always @(posedge clk)begin
    if(!resetn)begin
        DMW1[`CSR_DMW1_PLV0] <= 1'b0;
        DMW1[`CSR_DMW1_PLV3] <= 1'b0;
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
            DMW1[`CSR_DMW1_MAT] <= (csr_wmask[`CSR_DMW1_MAT] & csr_wvalue[`CSR_DMW1_MAT]) |
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

//��LLBCTL��
always @(posedge clk)begin
    if(LLbit_wb)begin
        LLBCTL[`CSR_LLBCTL_ROLLB] <= 1'b1;
    end
    else if (csr_we && csr_num == `CSR_LLBCTL)begin
        if(csr_wmask[`CSR_LLBCTL_WCLLB] & csr_wvalue[`CSR_LLBCTL_WCLLB])begin
            LLBCTL[`CSR_LLBCTL_ROLLB] <= 1'b0;
        end
    end
    else if (inst_ertn & ~LLBCTL[`CSR_LLBCTL_KLO])begin
        LLBCTL[`CSR_LLBCTL_ROLLB] <= 1'b0;
    end
end

always @ (posedge clk)begin
    if (csr_we && csr_num == `CSR_LLBCTL)begin
        if(csr_wmask[`CSR_LLBCTL_WCLLB] & csr_wvalue[`CSR_LLBCTL_WCLLB])begin
            LLBCTL[`CSR_LLBCTL_WCLLB] <= 1'b1;
        end
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
    else if (inst_ertn & LLBCTL[`CSR_LLBCTL_KLO])begin
        LLBCTL[`CSR_LLBCTL_KLO] <= 1'b0;
    end
end
// ----------WRITE IN END--------------

// ----------TO PIPELINE END--------------
assign has_int = (((ESTAT[`CSR_ESTAT_IS] & ECFG[`CSR_ECFG_LIE])!=13'b0) && (CRMD[`CSR_CRMD_IE] == 1'b1));
assign csr_CRMD_DA  = CRMD[`CSR_CRMD_DA];
assign csr_CRMD_PG  = CRMD[`CSR_CRMD_PG];
assign csr_CRMD_PLV = CRMD[`CSR_CRMD_PLV];
// ----------TO PIPELINE IN END--------------

// ----------LLbit begin--------------
assign LLbit = LLBCTL[`CSR_LLBCTL_ROLLB];
// ----------LLbit END--------------

// ---------- DMW0/1 begin --------------
wire vseg0_0;   
wire vseg0_1;
wire dmw0_plv_ok;
wire dmw1_plv_ok;
assign dmw0_plv_ok= DMW0[`CSR_DMW0_PLV0] ? (csr_CRMD_PLV == 2'b00) :
                    DMW0[`CSR_DMW0_PLV3] ? (csr_CRMD_PLV == 2'b11) :
                    1'b0;
assign dmw1_plv_ok= DMW1[`CSR_DMW1_PLV0] ? (csr_CRMD_PLV == 2'b00) :
                    DMW1[`CSR_DMW1_PLV3] ? (csr_CRMD_PLV == 2'b11) :
                    1'b0;   
assign vseg0_0    = (dmw_vseg0 == DMW0[`CSR_DMW0_VSEG]);
assign vseg0_1    = (dmw_vseg0 == DMW1[`CSR_DMW0_VSEG]);
//assign dmw_found0 = (vseg0_0 | vseg0_1) & (dmw0_plv_ok | dmw1_plv_ok);
assign dmw_found0 = (vseg0_0 & dmw0_plv_ok) | (vseg0_1 & dmw1_plv_ok);
assign dmw_mat0   = vseg0_0 ? DMW0[`CSR_DMW0_MAT]  : DMW1[`CSR_DMW1_MAT];
assign dmw_pseg0  = vseg0_0 ? DMW0[`CSR_DMW0_PSEG] : DMW1[`CSR_DMW0_PSEG];

wire vseg1_0;   
wire vseg1_1;   
assign vseg1_0    = (dmw_vseg1 == DMW0[`CSR_DMW0_VSEG]);
assign vseg1_1    = (dmw_vseg1 == DMW1[`CSR_DMW0_VSEG]);
assign dmw_found1 = (vseg1_0 & dmw0_plv_ok) | (vseg1_1 & dmw1_plv_ok);
assign dmw_mat1   = vseg1_0 ? DMW0[`CSR_DMW0_MAT]  : DMW1[`CSR_DMW1_MAT];
assign dmw_pseg1  = vseg1_0 ? DMW0[`CSR_DMW0_PSEG] : DMW1[`CSR_DMW0_PSEG];
// ---------- DMW0/1 end --------------

// ---------- READ --------------
wire [31:0] csr_crmd_rvalue;
wire [31:0] csr_prmd_rvalue;
wire [31:0] csr_estat_rvalue;
wire [31:0] csr_era_rvalue;
wire [31:0] csr_eentry_rvalue;
wire [31:0] csr_save0_rvalue;
wire [31:0] csr_save1_rvalue;
wire [31:0] csr_save2_rvalue;
wire [31:0] csr_save3_rvalue;
wire [31:0] csr_ticlr_rvalue;
wire [31:0] csr_ecfg_rvalue;
wire [31:0] csr_badv_rvalue;
wire [31:0] csr_tid_rvalue;
wire [31:0] csr_tcfg_rvalue;
wire [31:0] csr_tval_rvalue;
wire [31:0] csr_tlbidx_rvalue;
wire [31:0] csr_tlbehi_rvalue;
wire [31:0] csr_tlbelo0_rvalue;
wire [31:0] csr_tlbelo1_rvalue;
wire [31:0] csr_asid_rvalue;
wire [31:0] csr_tlbrentry_rvalue;
wire [31:0] csr_dmw0_rvalue;
wire [31:0] csr_dmw1_rvalue;
wire [31:0] csr_llbctl_rvalue;

assign csr_crmd_rvalue  = {{23{1'b0}},CRMD[`CSR_CRMD_DATM],CRMD[`CSR_CRMD_DATF],CRMD[`CSR_CRMD_PG],CRMD[`CSR_CRMD_DA], CRMD[`CSR_CRMD_IE],CRMD[`CSR_CRMD_PLV]};
assign csr_prmd_rvalue  = {{29{1'b0}},PRMD[`CSR_PRMD_PIE],PRMD[`CSR_PRMD_PPLV]};
assign csr_estat_rvalue = {{1{1'b0}},ESTAT[`CSR_ESTAT_ESUBCODE],ESTAT[`CSR_ESTAT_ECODE],{3{1'b0}},ESTAT[`CSR_ESTAT_IS12],ESTAT[`CSR_ESTAT_IS11],{1{1'b0}},ESTAT[`CSR_ESTAT_IS9_2],ESTAT[`CSR_ESTAT_IS1_0]};
assign csr_era_rvalue   = ERA[`CSR_ERA_PC];
assign csr_eentry_rvalue= {EENTRY[`CSR_EENTRY_VA],{6{1'b0}}};
assign csr_save0_rvalue = SAVE0[`CSR_SAVE_DATA];
assign csr_save1_rvalue = SAVE1[`CSR_SAVE_DATA];
assign csr_save2_rvalue = SAVE2[`CSR_SAVE_DATA];
assign csr_save3_rvalue = SAVE3[`CSR_SAVE_DATA];
assign csr_ticlr_rvalue = 32'b0;
assign csr_badv_rvalue  = BADV[`CSR_BADV_VADDR];
assign csr_ecfg_rvalue  = {{19{1'b0}},ECFG[`CSR_ECFG_LIE]};
assign csr_tid_rvalue   = TID[`CSR_TID_TID];
assign csr_tcfg_rvalue  = {TCFG[`CSR_TCFG_INITVAL],TCFG[`CSR_TCFG_PERIOD],TCFG[`CSR_TCFG_EN]};
assign csr_tval_rvalue  = timer_cnt[31:0];
assign csr_tlbidx_rvalue = {TLBIDX[`CSR_TLBIDX_NE],{1'b0},TLBIDX[`CSR_TLBIDX_PS],{8'b0},{16-$clog2(TLBNUM){1'b0}},TLBIDX[`CSR_TLBIDX_INDEX]};
assign csr_tlbehi_rvalue = {TLBEHI[`CSR_TLBEHI_VPPN],{13'b0}};
assign csr_tlbelo0_rvalue= {{4'b0},TLBELO0[`CSR_TLBELO0_PPN],{1'b0},TLBELO0[`CSR_TLBELO0_G],TLBELO0[`CSR_TLBELO0_MAT],
                            TLBELO0[`CSR_TLBELO0_PLV],TLBELO0[`CSR_TLBELO0_D],TLBELO0[`CSR_TLBELO0_V]};
assign csr_tlbelo1_rvalue= {{4'b0},TLBELO1[`CSR_TLBELO1_PPN],{1'b0},TLBELO1[`CSR_TLBELO1_G],TLBELO1[`CSR_TLBELO1_MAT],
                            TLBELO1[`CSR_TLBELO1_PLV],TLBELO1[`CSR_TLBELO1_D],TLBELO1[`CSR_TLBELO1_V]};
assign csr_asid_rvalue   = {{8'b0},{8'ha},{6'b0},ASID[`CSR_ASID_ASID]};
assign csr_tlbrentry_rvalue = {TLBRENTRY[`CSR_TLBRENTRY_PA],{6'b0}};
assign csr_dmw0_rvalue = {DMW0[`CSR_DMW0_VSEG],{1{1'b0}},DMW0[`CSR_DMW0_PSEG],{19{1'b0}},DMW0[`CSR_DMW0_MAT],DMW0[`CSR_DMW0_PLV3],{2{1'b0}},DMW0[`CSR_DMW0_PLV0]};
assign csr_dmw1_rvalue = {DMW1[`CSR_DMW1_VSEG],{1{1'b0}},DMW1[`CSR_DMW1_PSEG],{19{1'b0}},DMW1[`CSR_DMW1_MAT],DMW1[`CSR_DMW1_PLV3],{2{1'b0}},DMW1[`CSR_DMW1_PLV0]};
assign csr_llbctl_rvalue = {29'h0,LLBCTL[`CSR_LLBCTL_KLO],LLBCTL[`CSR_LLBCTL_WCLLB],LLBCTL[`CSR_LLBCTL_ROLLB]};

//csr��tlb�Ľӿڽ���
assign r_index = TLBIDX[`CSR_TLBIDX_INDEX];
assign s0_asid = ASID[`CSR_ASID_ASID];
assign s1_asid_without_invtlb = ASID[`CSR_ASID_ASID];

//TLB���ӿ�,tlb�Ĵ�������д�ӿڽӵ�TLB
assign csr_TLBIDX  = csr_tlbidx_rvalue;
assign csr_TLBEHI  = csr_tlbehi_rvalue;

//mat:�洢��������
assign csr_CRMD_DATF = CRMD[`CSR_CRMD_DATF];
assign csr_CRMD_DATM = CRMD[`CSR_CRMD_DATM];

//write TLB�ӿ�
assign w_index    = TLBIDX[`CSR_TLBIDX_INDEX];
assign w_e        = (ESTAT[`CSR_ESTAT_ECODE] == 6'h3F) | ~TLBIDX[`CSR_TLBIDX_NE];
assign w_vppn     = TLBEHI[`CSR_TLBEHI_VPPN];
assign w_ps       = TLBIDX[`CSR_TLBIDX_PS];
assign w_asid     = ASID[`CSR_ASID_ASID];
assign w_g        = TLBELO0[`CSR_TLBELO0_G] & TLBELO1[`CSR_TLBELO1_G];
assign w_ppn0     = TLBELO0[`CSR_TLBELO0_PPN];
assign w_plv0     = TLBELO0[`CSR_TLBELO0_PLV];
assign w_mat0     = TLBELO0[`CSR_TLBELO0_MAT];
assign w_d0       = TLBELO0[`CSR_TLBELO0_D];
assign w_v0       = TLBELO0[`CSR_TLBELO0_V];
assign w_ppn1     = TLBELO1[`CSR_TLBELO1_PPN];
assign w_plv1     = TLBELO1[`CSR_TLBELO1_PLV];
assign w_mat1     = TLBELO1[`CSR_TLBELO1_MAT];
assign w_d1       = TLBELO1[`CSR_TLBELO1_D];  
assign w_v1       = TLBELO1[`CSR_TLBELO1_V];  
 
//����CSR���ӿ�   
assign csr_rvalue = ({32{csr_num == `CSR_CRMD}} & csr_crmd_rvalue)          |
                    ({32{csr_num == `CSR_PRMD}} & csr_prmd_rvalue)          |
                    ({32{csr_num == `CSR_ESTAT}} & csr_estat_rvalue)        |
                    ({32{csr_num == `CSR_ERA}} & csr_era_rvalue)            |
                    ({32{csr_num == `CSR_EENTRY}} & csr_eentry_rvalue)      |
                    ({32{csr_num == `CSR_SAVE0}} & csr_save0_rvalue)        |
                    ({32{csr_num == `CSR_SAVE1}} & csr_save1_rvalue)        |
                    ({32{csr_num == `CSR_SAVE2}} & csr_save2_rvalue)        |
                    ({32{csr_num == `CSR_SAVE3}} & csr_save3_rvalue)        |
                    ({32{csr_num == `CSR_TICLR}} & csr_ticlr_rvalue)        |
                    ({32{csr_num == `CSR_ECFG}} & csr_ecfg_rvalue)          |
                    ({32{csr_num == `CSR_BADV}} & csr_badv_rvalue)          |
                    ({32{csr_num == `CSR_TID}} & csr_tid_rvalue)            |
                    ({32{csr_num == `CSR_TCFG}} & csr_tcfg_rvalue)          |
                    ({32{csr_num == `CSR_TVAL}}     & csr_tval_rvalue)      |
                    ({32{csr_num == `CSR_TLBIDX}}   & csr_tlbidx_rvalue)    |
                    ({32{csr_num == `CSR_TLBEHI}}   & csr_tlbehi_rvalue)    |
                    ({32{csr_num == `CSR_TLBELO0}}  & csr_tlbelo0_rvalue)   |
                    ({32{csr_num == `CSR_TLBELO1}}  & csr_tlbelo1_rvalue)   |
                    ({32{csr_num == `CSR_ASID}}     & csr_asid_rvalue)      |
                    ({32{csr_num == `CSR_TLBRENTRY}} & csr_tlbrentry_rvalue)|
                    ({32{csr_num == `CSR_DMW0}} & csr_dmw0_rvalue)          |
                    ({32{csr_num == `CSR_DMW1}} & csr_dmw1_rvalue)          |
                    ({32{csr_num == `CSR_LLBCTL}} & csr_llbctl_rvalue);

// ---------- READ END --------------
endmodule
