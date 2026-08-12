module mem #(
    parameter  inbus_width  = 32,
    parameter  outbus_width = 64,
    parameter  ISSUE        = 2
)(
  input  wire                    clk,
  input  wire                    resetn,
  //control signal
  input  wire                    EXE2_MEM_valid,
  input  wire                    MEM_allow_in,
  output reg                     MEM_valid,
  output wire                    MEM_ready_go,
  input  wire [inbus_width-1:0]  EXE2_MEM_bus          [ISSUE - 1 : 0],//bus
  output wire [outbus_width-1:0] MEM_WB_bus            [ISSUE - 1 : 0],
  //stall
  output wire [ 4:0]             MEM_rf_dest           [ISSUE - 1 : 0],
  output wire                    need_stall_inst       [ISSUE - 1 : 0],
  output wire                    need_stall_csr        [ISSUE - 1 : 0],
  //front_push
  output wire [31:0]             mem_front_data        [ISSUE - 1 : 0],
  output wire [ 4:0]             mem_front_addr        [ISSUE - 1 : 0],
  //cancel control
  input  wire                    MEM_need_cancel,
  //exception front
  output wire                    MEM_ex,
  //ex
  input  wire                    older_ex_for_mem,
  //handshake
  input  wire                    data_sram_data_ok,
  input  wire [31:0]             data_sram_rdata,
  input  wire                    WB_allow_in,
  //can_not_front_push
  output wire                    mem_can_not_front_push[ISSUE - 1 : 0]
);

//------------------------{bus}begin-------------------------//
wire                     slot_valid_from_exe2[ISSUE - 1 : 0];
wire   [31:0]            pc                  [ISSUE - 1 : 0];
wire                     res_from_mem        [ISSUE - 1 : 0];
wire                     mem_we              [ISSUE - 1 : 0];
wire                     need_stall_csr_b    [ISSUE - 1 : 0]; // 与 output need_stall_csr 区分
wire   [31:0]            alu_result_with_rdct[ISSUE - 1 : 0];

wire                     inst_ld_b           [ISSUE - 1 : 0];
wire                     inst_ld_h           [ISSUE - 1 : 0];
wire                     inst_ld_bu          [ISSUE - 1 : 0];
wire                     inst_ld_hu          [ISSUE - 1 : 0];

wire   [31:0]            rf_wdata            [ISSUE - 1 : 0];
wire   [4:0]             rf_dest             [ISSUE - 1 : 0];
wire                     rf_gr_we            [ISSUE - 1 : 0];
wire                     rf_gr_we_ex         [ISSUE - 1 : 0];
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

//tlb_ex
wire                     inst_sc_w           [ISSUE - 1 : 0];
wire                     sc_success          [ISSUE - 1 : 0];

//[todo 异常记得与上]
wire                     inst_idle           [ISSUE - 1 : 0];

wire   [31:0]            rkd_value           [ISSUE - 1 : 0];
reg    [inbus_width-1:0] bus                 [ISSUE - 1 : 0];

wire   [31:0]            ld_data;
wire   [7:0]             ld_data_byte;
wire   [15:0]            ld_data_half;
wire   [1:0]             data_sram_addr_l    [ISSUE - 1 : 0];

wire                     ex_tlb_reload0      [ISSUE - 1 : 0];//tlb重填例外
wire                     ex_tlb_preif_unvalid[ISSUE - 1 : 0];//tlb中取指页无效
wire                     ex_tlb_plv0         [ISSUE - 1 : 0];//tlb中页特权不合规
wire                     ex_tlb_reload1      [ISSUE - 1 : 0];//tlb重填例外
wire                     ex_tlb_ld_unvalid   [ISSUE - 1 : 0];//tlb中load页无效
wire                     ex_tlb_st_unvalid   [ISSUE - 1 : 0];//tlb中store页无效
wire                     ex_tlb_plv1         [ISSUE - 1 : 0];//tlb中页特权不合规
wire                     ex_tlb_page_modify  [ISSUE - 1 : 0];//tlb中页修改

genvar                   i;
generate
    for(i = 0; i < ISSUE; i = i + 1) begin : gen_MEM_bus
        always @(posedge clk) begin
            if(!resetn) begin
                bus[i] <= {inbus_width{1'b0}};
            end
            else if (EXE2_MEM_valid && MEM_allow_in) begin
                bus[i] <= EXE2_MEM_bus[i];
            end
        end
        assign {slot_valid_from_exe2[i],
                pc[i]                  ,
                rkd_value[i]           , res_from_mem[i]        , mem_we[i]      , need_stall_csr_b[i], inst_ld_b[i]        , inst_ld_h[i]        , inst_ld_bu[i] , inst_ld_hu[i]        , data_sram_addr_l[i], alu_result_with_rdct[i],//MEM
                inst_csrrd[i]          , inst_csrwr[i]          , inst_csrxchg[i], inst_ertn[i]       , inst_syscall[i]     , inst_break[i]       , ex_INE[i]     , ex_IPE[i]            , ex_ADEF[i]         , ex_ALE[i]              , has_int[i]  , inst_rdcntvl_w[i], inst_rdcntvh_w[i], inst_rdcntid[i], csr_num[i], rj_value[i], rf_dest[i], rf_gr_we[i],
                inst_tlbsrch[i]        , TLBIDX_new_tlbsrch[i]  , inst_tlbrd[i]  , inst_tlbwr[i]      , inst_tlbfill[i]     , inst_invtlb[i]      ,//WB
                ex_tlb_reload0[i]      , ex_tlb_preif_unvalid[i], ex_tlb_plv0[i] , ex_tlb_reload1[i]  , ex_tlb_ld_unvalid[i], ex_tlb_st_unvalid[i], ex_tlb_plv1[i], ex_tlb_page_modify[i], inst_sc_w[i]       , sc_success[i]          , inst_idle[i]
               } = bus[i];
    end
endgenerate
//------------------------{bus}end-------------------------//

//------------------------{ld_data}begin-------------------------//
wire  ld_index;
wire  ld_inst_valid[ISSUE - 1 : 0];
generate
    for(i = 0; i < ISSUE; i = i + 1) begin : gen_ld_inst_valid
        assign  ld_inst_valid[i] = slot_valid_from_exe2[i] & res_from_mem[i];
    end
    assign  ld_index = ld_inst_valid[0] ? 0 : 1;
endgenerate

assign  ld_data_byte = data_sram_addr_l[ld_index] == 2'b00 ? data_sram_rdata [7:0] :
                       data_sram_addr_l[ld_index] == 2'b01 ? data_sram_rdata [15:8] :
                       data_sram_addr_l[ld_index] == 2'b10 ? data_sram_rdata [23:16] :
                       data_sram_rdata [31:24];
assign  ld_data_half = data_sram_addr_l[ld_index] == 2'b00 ? data_sram_rdata [15:0] : data_sram_rdata[31:16];
assign  ld_data      = inst_ld_b[ld_index]  ? {{24{ld_data_byte[7]}},ld_data_byte} :
                       inst_ld_bu[ld_index] ? {{24{1'b0}},ld_data_byte} :
                       inst_ld_h[ld_index]  ? {{16{ld_data_half[15]}},ld_data_half} :
                       inst_ld_hu[ld_index] ? {{16{1'b0}},ld_data_half} :
                       data_sram_rdata;
//------------------------{ld_data}end-------------------------//

//------------------------{ready_go}begin-------------------------//
generate
    for(i = 0; i < ISSUE; i = i + 1) begin : gen_MEM_WB_bus
        assign  rf_gr_we_ex[i] = rf_gr_we[i]        & ~inst_ertn[i]         & ~inst_syscall[i]         & ~inst_break[i]         &
                                 ~ex_INE[i]         & ~ex_ADEF[i]           & ~ex_ALE[i]               & ~has_int[i]            &
                                 ~ex_tlb_reload0[i] & ~ex_tlb_reload1[i]    & ~ex_tlb_preif_unvalid[i] & ~ex_tlb_plv0[i]        &
                                 ~ex_tlb_plv1[i]    & ~ex_tlb_ld_unvalid[i] & ~ex_tlb_st_unvalid[i]    & ~ex_tlb_page_modify[i] &
                                 ~ex_IPE[i];
        assign  MEM_WB_bus[i]  = {
                                  slot_valid_from_exe2[i],
                                  pc[i]                  , need_stall_csr_b[i]    , alu_result_with_rdct[i],
                                  inst_csrrd[i]          , inst_csrwr[i]          , inst_csrxchg[i]        , inst_ertn[i]     , inst_syscall[i]     , inst_break[i]       , ex_INE[i]     , ex_IPE[i]            , ex_ADEF[i]  , ex_ALE[i], has_int[i], inst_rdcntvl_w[i], inst_rdcntvh_w[i], inst_rdcntid[i], csr_num[i], mem_we[i], rj_value[i], rkd_value[i], rf_dest[i], rf_wdata[i], rf_gr_we_ex[i],
                                  inst_tlbsrch[i]        , TLBIDX_new_tlbsrch[i]  , inst_tlbrd[i]          , inst_tlbwr[i]    , inst_tlbfill[i]     , inst_invtlb[i]      ,//WB
                                  ex_tlb_reload0[i]      , ex_tlb_preif_unvalid[i], ex_tlb_plv0[i]         , ex_tlb_reload1[i], ex_tlb_ld_unvalid[i], ex_tlb_st_unvalid[i], ex_tlb_plv1[i], ex_tlb_page_modify[i], inst_idle[i]
                                 };
    end
endgenerate
//------------------------{ready_go}end-------------------------//

//------------------------{exp_front}begin-------------------------//
wire  MEM_slot_ready_go[ISSUE - 1 : 0];
generate
    for(i = 0; i < ISSUE; i = i + 1) begin : gen_MEM_slot_ready_go
        assign  MEM_slot_ready_go[i] = ((res_from_mem[i] | (mem_we[i] & ~(inst_sc_w[i] & ~sc_success[i])))
                                        & ~MEM_slot_ex[i] & ~older_ex_for_mem & ~((i != 0) & MEM_slot_ex[0])) // 并且 slot1的时候 slot0 不是异常 就需要等待
                                        ? data_sram_data_ok
                                        : 1'b1;
    end
endgenerate
assign  MEM_ready_go = MEM_slot_ready_go[0] & MEM_slot_ready_go[1];

always @(posedge clk) begin
    if(!resetn)begin
        MEM_valid <= 1'b0;
    end
    else if(MEM_need_cancel)begin
        MEM_valid <= 1'b0;
    end
    else if(MEM_allow_in)begin
        MEM_valid <= EXE2_MEM_valid;
    end
end
//------------------------{exp_front}end-------------------------//

//------------------------{front_push}begin-------------------------//
wire  MEM_slot_ex[ISSUE - 1 : 0];
generate
    for(i = 0; i < ISSUE; i = i + 1) begin : gen_MEM_slot_ex
        assign  MEM_slot_ex[i]     = MEM_valid & slot_valid_from_exe2[i] &
                                     (inst_syscall[i]   | inst_ertn[i]         | inst_break[i]           | ex_INE[i]             |
                                      ex_tlb_reload0[i] | ex_tlb_reload1[i]    | ex_tlb_preif_unvalid[i] | ex_tlb_plv0[i]        |
                                      ex_tlb_plv1[i]    | ex_tlb_ld_unvalid[i] | ex_tlb_st_unvalid[i]    | ex_tlb_page_modify[i] |
                                      has_int[i]        | ex_IPE[i]            | ex_ADEF[i]              | ex_ALE[i]            );
        // 需要前递使用的dest & load/需要阻塞的 csr  
        assign  MEM_rf_dest[i]     = rf_dest[i];
        assign  need_stall_inst[i] = res_from_mem[i];
        assign  need_stall_csr[i]  = need_stall_csr_b[i];
    end
endgenerate
assign  MEM_ex = MEM_slot_ex[0]| MEM_slot_ex[1];                                   
//------------------------{front_push}end-------------------------//

//------------------------{front_push}begin-------------------------//
generate
    for(i = 0; i < ISSUE; i = i + 1) begin : gen_mem_front_data
        assign  rf_wdata[i]               = res_from_mem[i] ? ld_data :// 或 ld_data[i]，非 load 槽可 0
                                            inst_sc_w[i]    ? {31'b0, sc_success[i]} :
                                            alu_result_with_rdct[i];
        assign  mem_front_data[i]         = res_from_mem[i] ? ld_data :
                                            inst_sc_w[i]    ? {31'b0, sc_success[i]} :
                                            mem_we[i]       ? rkd_value[i] :
                                            alu_result_with_rdct[i];// is ld_w?
        assign  mem_front_addr[i]         = rf_dest[i];
        // ((i != 0) & MEM_slot_ex[0]) 如果 slot0 对应异常，直接不前递，如果是 slot1 且 slot0 异常也不前递
        assign  mem_can_not_front_push[i] = ~rf_gr_we[i] | MEM_slot_ex[i] | older_ex_for_mem | ~slot_valid_from_exe2[i] | need_stall_csr[i] | ((i != 0) & MEM_slot_ex[0]) | 
                                            ~data_sram_data_ok;
    end
endgenerate
//------------------------{front_push}end-------------------------//

endmodule
