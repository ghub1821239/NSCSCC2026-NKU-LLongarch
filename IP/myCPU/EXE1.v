`include "csr_def.vh"
module exe1 #(
    parameter  inbus_width  = 32,
    parameter  outbus_width = 64,
    parameter  TLBNUM       = 16
)(
  input  wire                      clk,
  input  wire                      resetn,
  //control signal
  output wire                      EXE1_ready_go,
  output reg                       EXE1_valid,
  input  wire                      ID_EXE1_valid,
  input  wire                      EXE1_allow_in,
  
  input  wire [inbus_width-1:0]    ID_EXE1_bus,//bus
  output wire [outbus_width-1:0]   EXE1_EXE2_bus,
  //stall
  output wire [ 4:0]               EXE1_rf_dest,
  output wire                      EXE1_rf_gr_we,
  //cancel control
  input  wire                      EXE1_need_cancel,
  //stable counter
  input  wire [63:0]               stable_counter,
  //tlb port s1
  output wire [18:0]               s1_vppn,
  output wire                      s1_va_bit12,
  output wire [9:0]                tlbinv_asid,
  input  wire                      s1_found,
  input  wire [$clog2(TLBNUM)-1:0] s1_index,
  input  wire [19:0]               s1_ppn,
  input  wire [5:0]                s1_ps,
  input  wire [1:0]                s1_plv,
  input  wire [1:0]                s1_mat,
  input  wire                      s1_d,
  input  wire                      s1_v,
  input  wire [31:0]               csr_TLBEHI,
  //invtlb 
  output wire                      invtlb_valid,
  output wire [4:0]                invtlb_op,
  //CRMD PG DA
  input  wire                      csr_CRMD_DA,
  input  wire                      csr_CRMD_PG,
  //tlb_ex
  input  wire                      ex_tlb_reload1,//tlb重填异常
  input  wire                      ex_tlb_ld_unvalid,//tlb的load页无效
  input  wire                      ex_tlb_st_unvalid,//tlb的store页无效
  input  wire                      ex_tlb_plv1,//tlb的页权限上访
  input  wire                      ex_tlb_page_modify,//tlb的页修改
  output wire                      tlb_load_req,
  output wire                      tlb_store_req,
  output wire                      tlb_data_req,
  //DMW
  output wire [2:0]                dmw_vseg1,
  input  wire                      dmw_found1,
  input  wire [2:0]                dmw_pseg1,
  //mat:存储访问类型
  input  wire [1:0]                csr_CRMD_DATM,//直接地址ld/st
  input  wire [1:0]                dmw_mat1    //直接映射
);
wire                   res_from_mem;
wire                   mem_we;
wire [18:0]            alu_op;
wire [31:0]            alu_src1;
wire [31:0]            alu_src2;
wire [4:0]             rf_dest;
wire [31:0]            pc;
wire                   rf_gr_we;
wire                   need_stall_inst;
wire                   need_stall_csr;
wire                   inst_ld_b;
wire                   inst_ld_h;
wire                   inst_ld_bu;
wire                   inst_ld_hu;
wire                   inst_st_b;
wire                   inst_st_h;
wire                   inst_st_w;
wire                   inst_ld_w;
reg  [inbus_width-1:0] bus;
wire [31:0]            rkd_value;
wire [31:0]            rj_value;

//chapter 7 exp 12:new_add
wire                   inst_csrrd;
wire                   inst_csrwr;
wire                   inst_csrxchg;
wire [13:0]            csr_num;

//chapter 10 exp23:new add
wire                   inst_cacop;
wire [4:0]             cache_code;

// ex enum
wire                   inst_ertn;
wire                   inst_syscall;
wire                   inst_break;
wire                   ex_INE;
wire                   ex_IPE;
wire                   ex_ADEF;
wire                   ex_ALE;
wire                   has_int;

wire                   EXE1_ex;

// timer_inst
wire                   inst_rdcntvl_w;
wire                   inst_rdcntvh_w;
wire                   inst_rdcntid;

// tlb
wire                   inst_tlbsrch;
wire                   inst_tlbrd;
wire                   inst_tlbwr;
wire                   inst_tlbfill;
wire                   inst_invtlb;

//tlb_ex
wire                   ex_tlb_reload0;//tlb重填异常
wire                   ex_tlb_preif_unvalid;//tlb的取指页无效
wire                   ex_tlb_plv0;//tlb的页权限上访

//system inst
wire                   inst_ibar;
wire                   inst_dbar;
wire                   inst_ll_w;
wire                   inst_sc_w;

// IDLE
wire                   inst_idle;

always @(posedge clk)begin
    if(!resetn)begin
        bus <= {inbus_width{1'b0}};
    end
    else if (ID_EXE1_valid && EXE1_allow_in)begin
        bus <= ID_EXE1_bus;
    end
end
assign {
            pc,
            rkd_value,alu_op,alu_src1,alu_src2,need_stall_inst,need_stall_csr,inst_st_b,inst_st_h,inst_st_w,inst_ld_w,//EXE
            res_from_mem,mem_we,inst_ld_b,inst_ld_h,inst_ld_bu ,inst_ld_hu,//MEM read and write
            inst_csrrd, inst_csrwr,inst_csrxchg,inst_ertn,inst_syscall,inst_break,ex_INE,ex_IPE,ex_ADEF,has_int,inst_rdcntvl_w,inst_rdcntvh_w,inst_rdcntid,csr_num,rj_value,rf_dest,rf_gr_we,//WB destination and write_enable
            inst_tlbsrch,inst_tlbrd,inst_tlbwr,inst_tlbfill,inst_invtlb,
            ex_tlb_reload0,ex_tlb_preif_unvalid,ex_tlb_plv0,
            cache_code,inst_cacop,inst_ibar,inst_dbar,inst_sc_w,inst_ll_w,inst_idle
        }=bus;
//------------------------{alu}begin-------------------------//
wire [31:0] alu_result;
wire [31:0] mem_vaddr;
wire        div_mod         = alu_op[15] | alu_op[16] | alu_op[17] | alu_op[18];
wire        divide_ready_go;
alu u_alu(
    .clk              (clk              ),
    .resetn           (resetn           ),
    .EXE1_valid       (EXE1_valid       ),
    .EXE1_need_cancel (EXE1_need_cancel ),
    .alu_op           (alu_op           ),
    .alu_src1         (alu_src1         ),
    .alu_src2         (alu_src2         ),
    .alu_result       (alu_result       ),
    .add_result       (mem_vaddr        ),
    .divide_ready_go  (divide_ready_go  )
);
//------------------------{alu}end-------------------------//

//------------------------{TLB}begin-------------------------//
assign        s1_vppn            = inst_tlbsrch ? csr_TLBEHI[`CSR_TLBEHI_VPPN]
                                   : inst_invtlb ? rkd_value[31:13]
                                   : mem_vaddr[31:13];
assign        s1_va_bit12        = mem_vaddr[12];
assign        tlbinv_asid        = alu_src1[9:0];
assign        invtlb_op          = rf_dest;
assign        invtlb_valid       = inst_invtlb & ~ex_INE & ~ex_IPE & EXE1_valid; // 也检查op是否有效，未添加?

wire   [10:0] TLBIDX_new_tlbsrch;
assign        TLBIDX_new_tlbsrch = {~s1_found,{6{1'b0}},s1_index};

// tlb映射得到的物理地址
wire   [31:0] tlb_paddr;
assign        tlb_paddr          = (s1_ps == 6'd21) ? {s1_ppn[19:9], mem_vaddr[20:0]}
                                   : {s1_ppn[19:0],  mem_vaddr[11:0]};

wire          tlb_translate_en;
assign        tlb_translate_en   = EXE1_valid && !csr_CRMD_DA && csr_CRMD_PG && !dmw_found1;

assign        tlb_load_req       = tlb_translate_en && (res_from_mem || (inst_cacop && cache_code[4:3] == 2'b10));

assign        tlb_store_req      = tlb_translate_en && mem_we;
assign        tlb_data_req       = tlb_load_req | tlb_store_req;
//------------------------{TLB}end-------------------------//

//------------------------{ready_go}begin-------------------------//
/*[NOTICE：学习笔记]
一开始ready_go不能直接写死
assign EXE1_ready_go = EXE1_ex ? 1'b1 :
                       div_mod ? divide_ready_go :
                                 1'b1;
所以这样写，一旦有tlb异常就会先去前面冲刷流水线；但既然EXE级已经分开，可以让EXE1先产生数据前递异常，再由EXE2处理st/ld相关异常。
所以st/ld相关异常放在EXE1后，逻辑上实际应该出现的数据前递问题最后统一收拢。
wire ex_other;
assign ex_other = EXE1_valid &
               (inst_syscall | inst_ertn | inst_break | ex_INE | ex_ADEF |
                ex_tlb_reload0 | ex_tlb_preif_unvalid | ex_tlb_plv0 | has_int);
assign EXE1_ready_go =  ex_other | ~div_mod | divide_ready_go;

其他异常也类似，ex_other这些异常都是根据inst的opcode判断，不会被~div_mod屏蔽。
其中inst_syscall | inst_ertn | inst_break | ex_INE等判断省去。
*/
wire    ex_div_need_notice;
assign  ex_div_need_notice = EXE1_valid & (has_int | ex_ADEF | ex_tlb_reload0 | ex_tlb_preif_unvalid | ex_tlb_plv0);
assign  EXE1_ready_go      = ex_div_need_notice | ~div_mod | divide_ready_go;
always @(posedge clk) begin
    if(!resetn)begin
        EXE1_valid <= 1'b0;
    end
    else if(EXE1_need_cancel)begin
        EXE1_valid <= 1'b0;
    end
    else if(EXE1_allow_in)begin
        EXE1_valid <= ID_EXE1_valid;
    end
end
//------------------------{ready_go}end-------------------------//

//------------------------{dataRAM handshake}begin-------------------------//
//data_sram
wire   [31:0] data_sram_addr;
wire   [31:0] data_sram_wdata;
wire   [3:0]  data_sram_wstrb;
wire   [1:0]  data_sram_size;
//说明s1_mat是已经换算好的？    // tlb页映射
wire   [1:0]  data_mat;
wire          data_wr;
wire   [31:0] st_data;
assign        st_data         = inst_st_b ? {4{rkd_value[7:0]}} :
                                inst_st_h ? {2{rkd_value[15:0]}} :
                                rkd_value;
assign        data_sram_wstrb = (mem_we ? (
                                inst_st_b ? (
                                (data_sram_addr[1:0] == 2'b00) ? 4'b0001 :
                                (data_sram_addr[1:0] == 2'b01) ? 4'b0010 :
                                (data_sram_addr[1:0] == 2'b10) ? 4'b0100 :
                                4'b1000
                                )
                                :
                                inst_st_h ?  (
                                (data_sram_addr[1:0] == 2'b00) ? 4'b0011 :
                                4'b1100
                                )
                                :
                                4'b1111)
                                :4'b0000);
assign        data_sram_size  = inst_st_b ? 2'b00 :
                                inst_st_h ? 2'b01 :
                                2'b10;
assign        data_sram_addr  = (csr_CRMD_DA == 1 & csr_CRMD_PG == 0) | (inst_cacop & cache_code[4:3] == 2'b00 | inst_cacop & cache_code[4:3] == 2'b01) ? mem_vaddr :
                                ((csr_CRMD_DA == 0 & csr_CRMD_PG == 1) | (inst_cacop & cache_code[4:3] == 2'b10)) & dmw_found1  ? {dmw_pseg1,mem_vaddr[28:0]} :
                                ((csr_CRMD_DA == 0 & csr_CRMD_PG == 1) | (inst_cacop & cache_code[4:3] == 2'b10)) & ~dmw_found1 ? tlb_paddr :
                                32'b0;
assign        data_sram_wdata = st_data;
assign        data_mat        = (csr_CRMD_DA == 1 & csr_CRMD_PG == 0) ? csr_CRMD_DATM :
                                (csr_CRMD_DA == 0 & csr_CRMD_PG == 1) &  dmw_found1  ? dmw_mat1 :
                                (csr_CRMD_DA == 0 & csr_CRMD_PG == 1) & ~dmw_found1  ?  s1_mat:
                                2'b0;
assign        data_wr         = mem_we;
//------------------------{dataRAM handshake}end-------------------------//

//------------------------{DMW}begin-------------------------//
assign  dmw_vseg1 = mem_vaddr[31:29];
//------------------------{DMW}end-------------------------//

//------------------------{front_push}begin-------------------------//
wire [31:0] alu_result_with_rdct = inst_rdcntvl_w ? stable_counter[31:0] :
                                   inst_rdcntvh_w ? stable_counter[63:32] : 
                                   alu_result;
//------------------------{front_push}end-------------------------//

//------------------------{ex_ALE}end-------------------------//
wire    ex_half;
wire    ex_word;

assign  ex_half = (inst_st_h | inst_ld_h | inst_ld_hu) & (mem_vaddr[0]!=1'b0);
assign  ex_word = (inst_st_w | inst_ld_w | inst_sc_w | inst_ll_w) & (mem_vaddr[1:0]!=2'b00);
assign  ex_ALE  = (ex_half | ex_word);
//------------------------{ex_ALE}end-------------------------//

//------------------------{exp_front}begin-------------------------//
assign  EXE1_ex = EXE1_valid &
                  (inst_syscall   | inst_ertn         | inst_break           | ex_INE             |
                  ex_tlb_reload0 | ex_tlb_reload1    | ex_tlb_preif_unvalid | ex_tlb_plv0        |
                  ex_tlb_plv1    | ex_tlb_ld_unvalid | ex_tlb_st_unvalid    | ex_tlb_page_modify |
                  has_int        | ex_IPE            | ex_ADEF              | ex_ALE  );
//------------------------{exp_front}end-------------------------//

//------------------------{bus}begin-------------------------//
assign  EXE1_EXE2_bus = {pc,
                        rkd_value,res_from_mem,mem_we,need_stall_csr,inst_ld_b,inst_ld_h,inst_ld_bu ,inst_ld_hu,alu_result_with_rdct,//MEM
                        inst_csrrd, inst_csrwr,inst_csrxchg,inst_ertn,inst_syscall,inst_break,ex_INE,ex_IPE,ex_ADEF,ex_ALE,has_int,inst_rdcntvl_w,inst_rdcntvh_w,inst_rdcntid,csr_num,rj_value,rf_dest,rf_gr_we,//WB
                        inst_tlbsrch,TLBIDX_new_tlbsrch,inst_tlbrd,inst_tlbwr,inst_tlbfill,inst_invtlb,
                        ex_tlb_reload0,ex_tlb_preif_unvalid,ex_tlb_plv0,ex_tlb_reload1,ex_tlb_ld_unvalid,ex_tlb_st_unvalid,ex_tlb_plv1,ex_tlb_page_modify,
                        data_sram_addr,data_sram_wdata,data_sram_size,data_sram_wstrb,data_mat,data_wr,inst_cacop,cache_code,inst_ibar,inst_dbar,inst_sc_w,inst_ll_w,inst_idle
                        };                                                      
assign  EXE1_rf_dest  = rf_dest;
assign  EXE1_rf_gr_we = rf_gr_we;                               
//------------------------{bus}end-------------------------//
                                                            
endmodule
