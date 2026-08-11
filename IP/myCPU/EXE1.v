`include "csr_def.vh"
module exe1 #(
    parameter  inbus_width  = 32,
    parameter  outbus_width = 64,
    parameter  TLBNUM       = 16,
    parameter  ISSUE        = 2
)(
  input  wire                      clk,
  input  wire                      resetn,
  //control signal
  output wire                      EXE1_ready_go,
  output reg                       EXE1_valid,
  input  wire                      ID_EXE1_valid,
  input  wire                      EXE1_allow_in,
  
  input  wire [inbus_width-1:0]    ID_EXE1_bus[ISSUE - 1 : 0],//bus
  output wire [outbus_width-1:0]   EXE1_EXE2_bus[ISSUE - 1 : 0],
  //stall
  output wire [ 4:0]               EXE1_rf_dest[ISSUE - 1 : 0],
  output wire                      EXE1_rf_gr_we[ISSUE - 1 : 0],
  //cancel control
  input  wire                      EXE1_need_cancel,
  //stable counter
  input  wire [63:0]               stable_counter,
  //tlb port s1
  output wire [18:0]               s1_vppn[ISSUE - 1 : 0],
  output wire                      s1_va_bit12[ISSUE - 1 : 0],
  output wire [9:0]                tlbinv_asid[ISSUE - 1 : 0],
  input  wire                      s1_found[ISSUE - 1 : 0],
  input  wire [$clog2(TLBNUM)-1:0] s1_index[ISSUE - 1 : 0],
  input  wire [19:0]               s1_ppn[ISSUE - 1 : 0],
  input  wire [5:0]                s1_ps[ISSUE - 1 : 0],
  input  wire [1:0]                s1_plv[ISSUE - 1 : 0],
  input  wire [1:0]                s1_mat[ISSUE - 1 : 0],
  input  wire                      s1_d[ISSUE - 1 : 0],
  input  wire                      s1_v[ISSUE - 1 : 0],
  input  wire [31:0]               csr_TLBEHI,
  //invtlb 
  output wire                      invtlb_valid,
  output wire [4:0]                invtlb_op,
  output wire                      invtlb_index,
  //CRMD PG DA
  input  wire                      csr_CRMD_DA,
  input  wire                      csr_CRMD_PG,
  //tlb_ex
  input  wire                      ex_tlb_reload1[ISSUE - 1 : 0],//tlb重填异常
  input  wire                      ex_tlb_ld_unvalid[ISSUE - 1 : 0],//tlb的load页无效
  input  wire                      ex_tlb_st_unvalid[ISSUE - 1 : 0],//tlb的store页无效
  input  wire                      ex_tlb_plv1[ISSUE - 1 : 0],//tlb的页权限上访
  input  wire                      ex_tlb_page_modify[ISSUE - 1 : 0],//tlb的页修改
  output wire                      tlb_load_req[ISSUE - 1 : 0],
  output wire                      tlb_store_req[ISSUE - 1 : 0],
  output wire                      tlb_data_req[ISSUE - 1 : 0],
  //DMW
  output wire [2:0]                dmw_vseg1[ISSUE - 1 : 0],
  input  wire                      dmw_found1[ISSUE - 1 : 0],
  input  wire [2:0]                dmw_pseg1[ISSUE - 1 : 0],
  //mat:存储访问类型
  input  wire [1:0]                csr_CRMD_DATM,//直接地址ld/st
  input  wire [1:0]                dmw_mat1[ISSUE - 1 : 0]    //直接映射
);

wire                     res_from_mem[ISSUE - 1 : 0];
wire                     mem_we[ISSUE - 1 : 0];
wire   [18:0]            alu_op[ISSUE - 1 : 0];
wire   [31:0]            alu_src1[ISSUE - 1 : 0];
wire   [31:0]            alu_src2[ISSUE - 1 : 0];
wire   [4:0]             rf_dest[ISSUE - 1 : 0];
wire   [31:0]            pc[ISSUE - 1 : 0];
wire                     rf_gr_we[ISSUE - 1 : 0];
wire                     need_stall_inst[ISSUE - 1 : 0];
wire                     need_stall_csr[ISSUE - 1 : 0];
wire                     inst_ld_b[ISSUE - 1 : 0];
wire                     inst_ld_h[ISSUE - 1 : 0];
wire                     inst_ld_bu[ISSUE - 1 : 0];
wire                     inst_ld_hu[ISSUE - 1 : 0];
wire                     inst_st_b[ISSUE - 1 : 0];
wire                     inst_st_h[ISSUE - 1 : 0];
wire                     inst_st_w[ISSUE - 1 : 0];
wire                     inst_ld_w[ISSUE - 1 : 0];
reg    [inbus_width-1:0] bus[ISSUE - 1 : 0];
wire   [31:0]            rkd_value[ISSUE - 1 : 0];
wire   [31:0]            rj_value[ISSUE - 1 : 0];

//chapter 7 exp 12:new_add
wire                     inst_csrrd[ISSUE - 1 : 0];
wire                     inst_csrwr[ISSUE - 1 : 0];
wire                     inst_csrxchg[ISSUE - 1 : 0];
wire   [13:0]            csr_num[ISSUE - 1 : 0];

//chapter 10 exp23:new add
wire                     inst_cacop[ISSUE - 1 : 0];
wire   [4:0]             cache_code[ISSUE - 1 : 0];

// ex enum
wire                     inst_ertn[ISSUE - 1 : 0];
wire                     inst_syscall[ISSUE - 1 : 0];
wire                     inst_break[ISSUE - 1 : 0];
wire                     ex_INE[ISSUE - 1 : 0];
wire                     ex_IPE[ISSUE - 1 : 0];
wire                     ex_ADEF[ISSUE - 1 : 0];
wire                     ex_ALE[ISSUE - 1 : 0];
wire                     has_int[ISSUE - 1 : 0];

wire                     EXE1_ex[ISSUE - 1 : 0];

// timer_inst
wire                     inst_rdcntvl_w[ISSUE - 1 : 0];
wire                     inst_rdcntvh_w[ISSUE - 1 : 0];
wire                     inst_rdcntid[ISSUE - 1 : 0];

// tlb
wire                     inst_tlbsrch[ISSUE - 1 : 0];
wire                     inst_tlbrd[ISSUE - 1 : 0];
wire                     inst_tlbwr[ISSUE - 1 : 0];
wire                     inst_tlbfill[ISSUE - 1 : 0];
wire                     inst_invtlb[ISSUE - 1 : 0];

//tlb_ex
wire                     ex_tlb_reload0[ISSUE - 1 : 0];//tlb重填异常
wire                     ex_tlb_preif_unvalid[ISSUE - 1 : 0];//tlb的取指页无效
wire                     ex_tlb_plv0[ISSUE - 1 : 0];//tlb的页权限上访

//system inst
wire                     inst_ibar[ISSUE - 1 : 0];
wire                     inst_dbar[ISSUE - 1 : 0];
wire                     inst_ll_w[ISSUE - 1 : 0];
wire                     inst_sc_w[ISSUE - 1 : 0];

// IDLE
wire                     inst_idle[ISSUE - 1 : 0];
wire                     slot_valid_from_decode[ISSUE - 1 : 0]; // 本槽是否发射有效指令（来自 ID bus）

genvar                   i;
generate 
    for(i = 0; i < ISSUE; i = i + 1) begin : gen_bus
        always @(posedge clk)begin
            if(!resetn)begin
                bus[i] <= {inbus_width{1'b0}};
            end
            else if (ID_EXE1_valid && EXE1_allow_in)begin
                bus[i] <= ID_EXE1_bus[i];
            end
        end
        assign {    slot_valid_from_decode[i],
                    pc[i],
                    rkd_value[i],alu_op[i],alu_src1[i],alu_src2[i],need_stall_inst[i],need_stall_csr[i],inst_st_b[i],inst_st_h[i],inst_st_w[i],inst_ld_w[i],//EXE
                    res_from_mem[i],mem_we[i],inst_ld_b[i],inst_ld_h[i],inst_ld_bu [i],inst_ld_hu[i],//MEM read and write
                    inst_csrrd[i], inst_csrwr[i],inst_csrxchg[i],inst_ertn[i],inst_syscall[i],inst_break[i],ex_INE[i],ex_IPE[i],ex_ADEF[i],has_int[i],inst_rdcntvl_w[i],inst_rdcntvh_w[i],inst_rdcntid[i],csr_num[i],rj_value[i],rf_dest[i],rf_gr_we[i],//WB destination and write_enable
                    inst_tlbsrch[i],inst_tlbrd[i],inst_tlbwr[i],inst_tlbfill[i],inst_invtlb[i],
                    ex_tlb_reload0[i],ex_tlb_preif_unvalid[i],ex_tlb_plv0[i],
                    cache_code[i],inst_cacop[i],inst_ibar[i],inst_dbar[i],inst_sc_w[i],inst_ll_w[i],inst_idle[i]
                }=bus[i];
    end
endgenerate
//------------------------{alu}begin-------------------------//
wire [31:0] alu_result[ISSUE - 1 : 0];
wire [31:0] mem_vaddr[ISSUE - 1 : 0];
wire        div_mod[ISSUE - 1 : 0];
wire        divide_ready_go[ISSUE - 1 : 0];
wire        EXE1_slot_valid[ISSUE - 1 : 0];
generate 
    for(i = 0; i < ISSUE; i = i + 1) begin : gen_alu
        // 按槽 valid：级 valid & 本槽有指令；alu 内部会用它门控全部 alu_op（含 mul/div）
        assign  EXE1_slot_valid[i] = EXE1_valid & slot_valid_from_decode[i];
        assign  div_mod[i] = EXE1_slot_valid[i] & (alu_op[i][15] | alu_op[i][16] | alu_op[i][17] | alu_op[i][18]);
        alu u_alu(
            .clk              (clk                ),
            .resetn           (resetn             ),
            .EXE1_slot_valid  (EXE1_slot_valid[i]  ),
            .EXE1_need_cancel (EXE1_need_cancel   ),
            .alu_op           (alu_op[i]          ),
            .alu_src1         (alu_src1[i]        ),
            .alu_src2         (alu_src2[i]        ),
            .alu_result       (alu_result[i]      ),
            .add_result       (mem_vaddr[i]       ),
            .divide_ready_go  (divide_ready_go[i] )
        );
    end
endgenerate
//------------------------{alu}end-------------------------//

//------------------------{TLB}begin-------------------------//
wire          tlb_translate_en[ISSUE - 1 : 0];
wire   [31:0] tlb_paddr[ISSUE - 1 : 0];
wire   [10:0] TLBIDX_new_tlbsrch[ISSUE - 1 : 0];

// [多发记得改]
assign        invtlb_index       = (inst_invtlb[0] & ~ex_INE[0] & ~ex_IPE[0] & EXE1_slot_valid[0]) ? 1'b0 : 1'b1;
assign        invtlb_valid       = ((inst_invtlb[0] & ~ex_INE[0] & ~ex_IPE[0] & EXE1_slot_valid[0]) |
                                    (inst_invtlb[1] & ~ex_INE[1] & ~ex_IPE[1] & EXE1_slot_valid[1])) & EXE1_valid;
assign        invtlb_op          = invtlb_index == 1'b0 ? rf_dest[0] : rf_dest[1];
assign        tlbinv_asid        = invtlb_index == 1'b0 ? alu_src1[0][9:0] : alu_src1[1][9:0];

generate
    for(i = 0; i < ISSUE; i = i + 1) begin : gen_tlb_paddr
        assign  s1_vppn[i]            = inst_tlbsrch[i] ? csr_TLBEHI[`CSR_TLBEHI_VPPN]
                                        : inst_invtlb[i]  ? rkd_value[i][31:13]
                                        : mem_vaddr[i][31:13];
        assign  s1_va_bit12[i]        = mem_vaddr[i][12];

        assign  TLBIDX_new_tlbsrch[i] = {~s1_found[i], {6{1'b0}}, s1_index[i]};

        assign  tlb_paddr[i]          = (s1_ps[i] == 6'd21) ? {s1_ppn[i][19:9], mem_vaddr[i][20:0]}
                                        : {s1_ppn[i][19:0], mem_vaddr[i][11:0]};

        assign  tlb_translate_en[i]   = EXE1_slot_valid[i] && !csr_CRMD_DA && csr_CRMD_PG && !dmw_found1[i];
        assign  tlb_load_req[i]       = tlb_translate_en[i] && (res_from_mem[i] || (inst_cacop[i] && cache_code[i][4:3] == 2'b10));
        assign  tlb_store_req[i]      = tlb_translate_en[i] && mem_we[i];
        assign  tlb_data_req[i]       = tlb_load_req[i] | tlb_store_req[i];
    end
endgenerate
//------------------------{TLB}end-------------------------//

//------------------------{dataRAM handshake}begin-------------------------//
//data_sram
wire [31:0] data_sram_addr[ISSUE - 1 : 0];
wire [31:0] data_sram_wdata[ISSUE - 1 : 0];
wire [3:0]  data_sram_wstrb[ISSUE - 1 : 0];
wire [1:0]  data_sram_size[ISSUE - 1 : 0];
//说明s1_mat是已经换算好的？    // tlb页映射
wire [1:0]  data_mat[ISSUE - 1 : 0];
wire        data_wr[ISSUE - 1 : 0];
wire [31:0] st_data[ISSUE - 1 : 0];
generate
    for(i = 0; i < ISSUE; i = i + 1) begin : gen_st_data
        assign  st_data[i]         = inst_st_b[i] ? {4{rkd_value[i][7:0]}} :
                                     inst_st_h[i] ? {2{rkd_value[i][15:0]}} :
                                     rkd_value[i];
        assign  data_sram_wstrb[i] = (mem_we[i] ? (
                                        inst_st_b[i] ? (
                                            (data_sram_addr[i][1:0] == 2'b00) ? 4'b0001 :
                                            (data_sram_addr[i][1:0] == 2'b01) ? 4'b0010 :
                                            (data_sram_addr[i][1:0] == 2'b10) ? 4'b0100 :
                                            4'b1000
                                        )
                                        :
                                        (
                                            inst_st_h[i] ?  (
                                                (data_sram_addr[i][1:0] == 2'b00) ? 4'b0011 :
                                                4'b1100
                                            )
                                            :
                                            4'b1111
                                        )
                                    )
                                    :4'b0000);
        assign  data_sram_size[i]  = inst_st_b[i] ? 2'b00 :
                                     inst_st_h[i] ? 2'b01 :
                                     2'b10;
        assign  data_sram_addr[i]  = (csr_CRMD_DA == 1 & csr_CRMD_PG == 0) | (inst_cacop[i] & cache_code[i][4:3] == 2'b00 | inst_cacop[i] & cache_code[i][4:3] == 2'b01) ? mem_vaddr[i] :
                                     ((csr_CRMD_DA == 0 & csr_CRMD_PG == 1) | (inst_cacop[i] & cache_code[i][4:3] == 2'b10)) & dmw_found1[i]  ? {dmw_pseg1[i],mem_vaddr[i][28:0]} :
                                     ((csr_CRMD_DA == 0 & csr_CRMD_PG == 1) | (inst_cacop[i] & cache_code[i][4:3] == 2'b10)) & ~dmw_found1[i] ? tlb_paddr[i] :
                                     32'b0;
        assign  data_sram_wdata[i] = st_data[i];
        assign  data_mat[i]        = (csr_CRMD_DA == 1 & csr_CRMD_PG == 0) ? csr_CRMD_DATM :
                                     (csr_CRMD_DA == 0 & csr_CRMD_PG == 1) &  dmw_found1[i]  ? dmw_mat1[i] :
                                     (csr_CRMD_DA == 0 & csr_CRMD_PG == 1) & ~dmw_found1[i]  ?  s1_mat[i]:
                                     2'b0;
        assign  data_wr[i]         = mem_we[i];// ld:0 st:1
    end
endgenerate
//------------------------{dataRAM handshake}end-------------------------//

//------------------------{DMW}begin-------------------------//
generate 
    for(i = 0; i < ISSUE; i = i + 1) begin : gen_dmw_vseg1
        assign  dmw_vseg1[i] = mem_vaddr[i][31:29];
    end
endgenerate
//------------------------{DMW}end-------------------------//

//------------------------{front_push}begin-------------------------//
wire [31:0] alu_result_with_rdct[ISSUE-1:0];
generate 
    for(i = 0; i < ISSUE; i = i + 1) begin : gen_alu_result_with_rdct
        assign  alu_result_with_rdct[i] = inst_rdcntvl_w[i] ? stable_counter[31:0] :
                                          inst_rdcntvh_w[i] ? stable_counter[63:32] : 
                                          alu_result[i];
    end
endgenerate
//------------------------{front_push}end-------------------------//

//------------------------{ex_ALE}end-------------------------//
wire  ex_half[ISSUE - 1 : 0];
wire  ex_word[ISSUE - 1 : 0];
generate 
    for(i = 0; i < ISSUE; i = i + 1) begin : gen_ex_ALE
        assign  ex_half[i] = (inst_st_h[i] | inst_ld_h[i] | inst_ld_hu[i]) & (mem_vaddr[i][0]!=1'b0);
        assign  ex_word[i] = (inst_st_w[i] | inst_ld_w[i] | inst_sc_w[i] | inst_ll_w[i]) & (mem_vaddr[i][1:0]!=2'b00);
        assign  ex_ALE[i]  = (ex_half[i]   | ex_word[i]);
    end
endgenerate
//------------------------{ex_ALE}end-------------------------//

//------------------------{exp_front}begin-------------------------//
generate 
    for(i = 0; i < ISSUE; i = i + 1) begin : gen_EXE1_ex
        assign  EXE1_ex[i] = EXE1_slot_valid[i] &
                             (inst_syscall[i]   | inst_ertn[i]         | inst_break[i]           | ex_INE[i]             |
                             ex_tlb_reload0[i] | ex_tlb_reload1[i]    | ex_tlb_preif_unvalid[i] | ex_tlb_plv0[i]        |
                             ex_tlb_plv1[i]    | ex_tlb_ld_unvalid[i] | ex_tlb_st_unvalid[i]    | ex_tlb_page_modify[i] |
                             has_int[i]        | ex_IPE[i]            | ex_ADEF[i]              | ex_ALE[i]  );
    end
endgenerate
//------------------------{exp_front}end-------------------------//

//------------------------{bus}begin-------------------------//
generate
    for(i = 0; i < ISSUE; i = i + 1) begin : gen_EXE1_EXE2_bus
        assign  EXE1_EXE2_bus[i] = {
                                    EXE1_slot_valid[i],
                                    pc[i],
                                    rkd_value[i],res_from_mem[i],mem_we[i],need_stall_csr[i],inst_ld_b[i],inst_ld_h[i],inst_ld_bu [i],inst_ld_hu[i],alu_result_with_rdct[i],//MEM
                                    inst_csrrd[i], inst_csrwr[i],inst_csrxchg[i],inst_ertn[i],inst_syscall[i],inst_break[i],ex_INE[i],ex_IPE[i],ex_ADEF[i],ex_ALE[i],has_int[i],inst_rdcntvl_w[i],inst_rdcntvh_w[i],inst_rdcntid[i],csr_num[i],rj_value[i],rf_dest[i],rf_gr_we[i],//WB
                                    inst_tlbsrch[i],TLBIDX_new_tlbsrch[i],inst_tlbrd[i],inst_tlbwr[i],inst_tlbfill[i],inst_invtlb[i],
                                    ex_tlb_reload0[i],ex_tlb_preif_unvalid[i],ex_tlb_plv0[i],ex_tlb_reload1[i],ex_tlb_ld_unvalid[i],ex_tlb_st_unvalid[i],ex_tlb_plv1[i],ex_tlb_page_modify[i],
                                    EXE1_ex[i],
                                    data_sram_addr[i],data_sram_wdata[i],data_sram_size[i],data_sram_wstrb[i],data_mat[i],data_wr[i],inst_cacop[i],cache_code[i],inst_ibar[i],inst_dbar[i],inst_sc_w[i],inst_ll_w[i],inst_idle[i]
                                   };                                                      
        assign  EXE1_rf_dest[i]  = rf_dest[i];
        assign  EXE1_rf_gr_we[i] = rf_gr_we[i] & EXE1_slot_valid[i];     
    end
endgenerate
//------------------------{bus}end-------------------------//


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
wire  ex_div_need_notice[ISSUE - 1 : 0];
wire  EXE1_slot_ready_go[ISSUE-1:0];
generate
    for(i = 0; i < ISSUE; i = i + 1) begin : gen_ex_div_need_notice
        assign  ex_div_need_notice[i] = EXE1_slot_valid[i] & (has_int[i] | ex_ADEF[i] | ex_tlb_reload0[i] | ex_tlb_preif_unvalid[i] | ex_tlb_plv0[i]);
        assign  EXE1_slot_ready_go[i] = ~EXE1_slot_valid[i] | ex_div_need_notice[i] | ~div_mod[i] | divide_ready_go[i];
    end
endgenerate
assign  EXE1_ready_go = &EXE1_slot_ready_go;
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
                                                            
endmodule
