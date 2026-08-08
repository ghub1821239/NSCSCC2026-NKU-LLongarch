`include "csr_def.vh"
module exe2 #(
    parameter  inbus_width  = 32,
    parameter  outbus_width = 64,
    parameter  TLBNUM       = 16
)(
    input  wire                    clk,
    input  wire                    resetn,
    // control signal
    output wire                    EXE2_ready_go,
    output reg                     EXE2_valid,
    input  wire                    EXE1_EXE2_valid,
    input  wire                    EXE2_allow_in,
    // bus
    input  wire [inbus_width-1:0]  EXE1_EXE2_bus,
    output wire [outbus_width-1:0] EXE2_MEM_bus,
    //stall
    output wire [ 4:0]             EXE2_rf_dest,
    output wire                    need_stall_inst, //bus传递
    output wire                    need_stall_csr,  //bus传递
    //front_push
    output wire [31:0]             exe2_front_data,
    output wire [ 4:0]             exe2_front_addr,
    output wire                    exe2_can_not_front_push,// 写回级数据前递目标不能前推
    //cancel control
    input  wire                    EXE2_need_cancel,
    //ex_cancel 取消write              exe2
    input  wire                    older_ex_for_exe2,
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
wire [31:0]            pc;
wire                   res_from_mem;
wire                   mem_we;
wire [31:0]            alu_result_with_rdct;

wire                   inst_ld_b;
wire                   inst_ld_h;
wire                   inst_ld_bu;
wire                   inst_ld_hu;


wire [4:0]             rf_dest;
wire                   rf_gr_we;

// ex enum
wire                   inst_ertn;
wire                   inst_syscall;
wire                   inst_break;
wire                   ex_INE;
wire                   ex_IPE;
wire                   ex_ADEF;
wire                   ex_ALE;
wire                   has_int;

wire [31:0]            rj_value;
//chapter 7 exp 12:new_add
wire                   inst_csrrd;
wire                   inst_csrwr;
wire                   inst_csrxchg;
wire [13:0]            csr_num;

// timer_inst
wire                   inst_rdcntvl_w;
wire                   inst_rdcntvh_w;
wire                   inst_rdcntid;

//tlb
wire                   inst_tlbrd;
wire                   inst_tlbsrch;
wire [10:0]            TLBIDX_new_tlbsrch;
wire                   inst_tlbwr;
wire                   inst_tlbfill;
wire                   inst_invtlb;

wire [31:0]            rkd_value;
reg  [inbus_width-1:0] bus;

//tlb_ex
wire                   ex_tlb_reload0;//tlb重填异常
wire                   ex_tlb_preif_unvalid;//tlb的取指页无效
wire                   ex_tlb_plv0;//tlb的页权限上访
wire                   ex_tlb_reload1;//tlb重填异常        
wire                   ex_tlb_ld_unvalid;//tlb的load页无效 
wire                   ex_tlb_st_unvalid;//tlb的store页无效
wire                   ex_tlb_plv1;//tlb的页权限上访        
wire                   ex_tlb_page_modify;//tlb的页修改   

wire                   inst_cacop;

//system inst
wire                   inst_ibar;
wire                   inst_dbar;
wire                   inst_sc_w;
wire                   inst_ll_w;

//IDLE
wire                   inst_idle;

always @(posedge clk)begin
    if(!resetn)begin
        bus <= {inbus_width{1'b0}};
    end
    else if (EXE1_EXE2_valid && EXE2_allow_in)begin
        bus <= EXE1_EXE2_bus;
    end
end
assign {
        pc,
        rkd_value,res_from_mem,mem_we,need_stall_csr,inst_ld_b,inst_ld_h,inst_ld_bu ,inst_ld_hu,alu_result_with_rdct,//MEM
        inst_csrrd, inst_csrwr,inst_csrxchg,inst_ertn,inst_syscall,inst_break,ex_INE,ex_IPE,ex_ADEF,ex_ALE,has_int,inst_rdcntvl_w,inst_rdcntvh_w,inst_rdcntid,csr_num,rj_value,rf_dest,rf_gr_we,//WB
        inst_tlbsrch,TLBIDX_new_tlbsrch,inst_tlbrd,inst_tlbwr,inst_tlbfill,inst_invtlb,
        ex_tlb_reload0,ex_tlb_preif_unvalid,ex_tlb_plv0,ex_tlb_reload1,ex_tlb_ld_unvalid,ex_tlb_st_unvalid,ex_tlb_plv1,ex_tlb_page_modify,
        data_sram_addr,data_sram_wdata,data_sram_size,data_sram_wstrb,data_mat,data_wr,inst_cacop,cache_code,inst_ibar,inst_dbar,inst_sc_w,inst_ll_w,inst_idle
        }=bus;
//------------------------{bus解析&传递}end-------------------------//

//------------------------{ll&sc}begin-------------------------//
reg    [29:0] LLaddr;
wire          sc_success;
wire          ll_finish;
wire          sc_finish;

assign        sc_success = LLbit && (data_sram_addr[31:2] == LLaddr);

assign        ll_finish  = EXE2_valid && inst_ll_w &&
                           data_sram_req && data_sram_addr_ok &&
                           ~EXE2_need_cancel;

assign        sc_finish  = EXE2_valid && inst_sc_w &&
                           EXE2_ready_go && MEM_allow_in &&
                           ~EXE2_ex && ~older_ex_for_exe2 &&
                           ~EXE2_need_cancel;

always @(posedge clk) begin
    if (!resetn)
        LLaddr <= 30'b0;
    else if (ll_finish)
        LLaddr <= data_sram_addr[31:2];
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
assign  need_stall_inst = res_from_mem;
//------------------------{need_stall_inst}end-------------------------//

//------------------------{i/dbar need cancel}begins-------------------------//
assign  ibar_cancel = inst_ibar & EXE2_valid;
assign  dbar_cancel = inst_dbar & EXE2_valid;
//------------------------{i/dbar need cancel}end-------------------------//

//------------------------{dataRAM handshake}begin-------------------------//
wire    EXE2_ex;
assign  data_sram_req = (res_from_mem | mem_we) & ~req_without_dataok & MEM_allow_in & ~(inst_sc_w & ~sc_success) &
                        ~EXE2_ex & ~older_ex_for_exe2 & EXE2_valid;
assign  data_sram_wr  = |data_sram_wstrb & ~older_ex_for_exe2 & ~EXE2_ex & EXE2_valid;

assign  cacop_valid   = EXE2_valid & inst_cacop & ~EXE2_ex & ~older_ex_for_exe2 &
                        (cache_code[4:3] == 2'b10 | csr_CRMD_PLV == 2'b00);
assign  cacop_pc      = pc + 4;
//------------------------{dataRAM handshake}end-------------------------//

//------------------------{front_push}begin-------------------------//
assign  exe2_front_data         = inst_sc_w ? {31'b0, sc_success} :
                                  mem_we    ? rkd_value :
                                  alu_result_with_rdct;
assign  exe2_front_addr         = rf_dest;
assign  exe2_can_not_front_push = ~rf_gr_we;

assign  EXE2_ex                 = EXE2_valid &
                                  (inst_syscall   | inst_ertn         | inst_break           | ex_INE             |
                                  ex_tlb_reload0 | ex_tlb_reload1    | ex_tlb_preif_unvalid | ex_tlb_plv0        |
                                  ex_tlb_plv1    | ex_tlb_ld_unvalid | ex_tlb_st_unvalid    | ex_tlb_page_modify |
                                  has_int        | ex_IPE            | ex_ADEF              | ex_ALE  );
//------------------------{front_push}end-------------------------//

//------------------------{ready_go}begin-------------------------//
assign  EXE2_ready_go = (EXE2_ex | older_ex_for_exe2) ? 1'b1 :
                        cacop_valid ? cacop_done :
                        (res_from_mem | (mem_we & ~(inst_sc_w & ~sc_success))) ? (data_sram_addr_ok & data_sram_req) :
                        1'b1;
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
assign  EXE2_MEM_bus = {
                       pc,
                       rkd_value,res_from_mem,mem_we,need_stall_csr,inst_ld_b,inst_ld_h,inst_ld_bu ,inst_ld_hu,data_sram_addr[1:0],alu_result_with_rdct,//MEM
                       inst_csrrd, inst_csrwr,inst_csrxchg,inst_ertn,inst_syscall,inst_break,ex_INE,ex_IPE,ex_ADEF,ex_ALE,has_int,inst_rdcntvl_w,inst_rdcntvh_w,inst_rdcntid,csr_num,rj_value,rf_dest,rf_gr_we,//WB
                       inst_tlbsrch,TLBIDX_new_tlbsrch,inst_tlbrd,inst_tlbwr,inst_tlbfill,inst_invtlb,
                       ex_tlb_reload0,ex_tlb_preif_unvalid,ex_tlb_plv0,ex_tlb_reload1,ex_tlb_ld_unvalid,ex_tlb_st_unvalid,ex_tlb_plv1,ex_tlb_page_modify,inst_sc_w,sc_success,inst_idle
                       };                                                      
assign  EXE2_rf_dest = rf_dest;                               
//------------------------{bus}end-------------------------//
endmodule