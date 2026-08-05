module mem #(
    parameter inbus_width  = 32,
    parameter outbus_width = 64
)(
  input  wire         clk,
  input  wire         resetn,
  //control signal
  input  wire         EXE2_MEM_valid,
  input  wire         MEM_allow_in,
  output reg          MEM_valid,
  output wire         MEM_ready_go,
  input  wire [inbus_width-1:0] EXE2_MEM_bus,//bus
  output wire [outbus_width-1:0] MEM_WB_bus,
  //stall
  output wire [ 4:0]  MEM_rf_dest,
  output wire         need_stall_inst,
  output wire         need_stall_csr,
  //front_push
  output wire [31:0]  mem_front_data,
  output wire [ 4:0]  mem_front_addr,
  //cancel control
  input  wire         MEM_need_cancel,
  //exception front
  output wire         MEM_ex,
  //ex
  input  wire         older_ex_for_mem,
  //handshake
  input  wire         data_sram_data_ok,
  input  wire [31:0]  data_sram_rdata,
  input  wire         WB_allow_in,
  //can_not_front_push
  output wire         mem_can_not_front_push
);

//------------------------{bus}begin-------------------------//
wire [31:0] pc;
wire        res_from_mem;
wire        mem_we;
wire [31:0] alu_result_with_rdct;

wire        inst_ld_b;
wire        inst_ld_h;
wire        inst_ld_bu;
wire        inst_ld_hu;

wire [31:0] rf_wdata;
wire [4:0]  rf_dest;
wire        rf_gr_we;
wire        rf_gr_we_ex;
// ex enum
wire        inst_ertn;
wire        inst_syscall;
wire        inst_break;
wire        ex_INE;
wire        ex_ADEF;
wire        ex_ALE;
wire        has_int;

wire [31:0] rj_value;
//chapter 7 exp 12:new_add
wire        inst_csrrd;
wire        inst_csrwr;
wire        inst_csrxchg;
wire [13:0] csr_num;

// timer_inst
wire        inst_rdcntvl_w;
wire        inst_rdcntvh_w;
wire        inst_rdcntid;

//tlb
wire        inst_tlbrd;
wire        inst_tlbsrch;
wire [10:0] TLBIDX_new_tlbsrch;
wire        inst_tlbwr;
wire        inst_tlbfill;
wire        inst_invtlb;

// sc_w
wire        inst_sc_w;

wire [31:0] rkd_value;
reg  [inbus_width-1:0] bus;

wire [31:0] ld_data;
wire [7:0]  ld_data_byte;
wire [15:0] ld_data_half;
wire [1:0]   data_sram_addr_l;


//tlb_ex
wire       ex_tlb_reload0;//tlb��������
wire       ex_tlb_preif_unvalid;//tlb��ȡָҳ��Ч
wire       ex_tlb_plv0;//tlb��ҳ��Ȩ���Ϲ�
wire       ex_tlb_reload1;//tlb��������        
wire       ex_tlb_ld_unvalid;//tlb��loadҳ��Ч 
wire       ex_tlb_st_unvalid;//tlb��storeҳ��Ч
wire       ex_tlb_plv1;//tlb��ҳ��Ȩ���Ϲ�        
wire       ex_tlb_page_modify;//tlb��ҳ�޸�     

assign ld_data_byte = data_sram_addr_l == 2'b00 ? data_sram_rdata [7:0] :
                      data_sram_addr_l == 2'b01 ? data_sram_rdata [15:8] :
                      data_sram_addr_l == 2'b10 ? data_sram_rdata [23:16] :
                      data_sram_rdata [31:24];
assign ld_data_half = data_sram_addr_l == 2'b00 ? data_sram_rdata [15:0] :
                      data_sram_rdata [31:16];
assign ld_data = inst_ld_b  ? {{24{ld_data_byte[7]}},ld_data_byte} :
                 inst_ld_bu ? {{24{1'b0}},ld_data_byte} :
                 inst_ld_h  ? {{16{ld_data_half[15]}},ld_data_half} :
                 inst_ld_hu ? {{16{1'b0}},ld_data_half} :
                 data_sram_rdata;
assign rf_wdata = (res_from_mem ? ld_data : alu_result_with_rdct);

always @(posedge clk)begin
    if(!resetn)begin
        bus<={inbus_width{1'b0}};
    end
    else if (EXE2_MEM_valid && MEM_allow_in)begin
        bus<=EXE2_MEM_bus;
    end
end
assign {
        pc,
        rkd_value,res_from_mem,mem_we,need_stall_csr,inst_ld_b,inst_ld_h,inst_ld_bu ,inst_ld_hu,data_sram_addr_l,alu_result_with_rdct,//MEM
        inst_csrrd, inst_csrwr,inst_csrxchg,inst_ertn,inst_syscall,inst_break,ex_INE,ex_ADEF,ex_ALE,has_int,inst_rdcntvl_w,inst_rdcntvh_w,inst_rdcntid,csr_num,rj_value,rf_dest,rf_gr_we,
        inst_tlbsrch,TLBIDX_new_tlbsrch,inst_tlbrd,inst_tlbwr,inst_tlbfill,inst_invtlb,//WB
        ex_tlb_reload0,ex_tlb_preif_unvalid,ex_tlb_plv0,ex_tlb_reload1,ex_tlb_ld_unvalid,ex_tlb_st_unvalid,ex_tlb_plv1,ex_tlb_page_modify,inst_sc_w
    }=bus;
assign MEM_rf_dest = rf_dest;
assign need_stall_inst = res_from_mem;
//[todo �쳣�ǵ�����]
assign rf_gr_we_ex = rf_gr_we & ~inst_ertn & ~inst_syscall & ~inst_break &
                     ~ex_INE & ~ex_ADEF & ~ex_ALE & ~has_int & 
                     ~ex_tlb_reload0 & ~ex_tlb_reload1 & ~ex_tlb_preif_unvalid & ~ex_tlb_plv0 & ~ex_tlb_plv1 & ~ex_tlb_ld_unvalid & ~ex_tlb_st_unvalid & ~ex_tlb_page_modify;
assign MEM_WB_bus ={ 
        pc,need_stall_csr,alu_result_with_rdct,
        inst_csrrd, inst_csrwr,inst_csrxchg,inst_ertn,inst_syscall,inst_break,ex_INE,ex_ADEF,ex_ALE,has_int,inst_rdcntvl_w,inst_rdcntvh_w,inst_rdcntid,csr_num,mem_we,rj_value,rkd_value,rf_dest,rf_wdata,rf_gr_we_ex,
        inst_tlbsrch,TLBIDX_new_tlbsrch,inst_tlbrd,inst_tlbwr,inst_tlbfill,inst_invtlb,//WB
        ex_tlb_reload0,ex_tlb_preif_unvalid,ex_tlb_plv0,ex_tlb_reload1,ex_tlb_ld_unvalid,ex_tlb_st_unvalid,ex_tlb_plv1,ex_tlb_page_modify
    };//[todo: change bus]
//------------------------{bus}end-------------------------//

//------------------------{ready_go}begin-------------------------//
assign MEM_ready_go = (res_from_mem | mem_we) & ~(MEM_ex | older_ex_for_mem)
                    ? data_sram_data_ok
                    : 1'b1;

always @(posedge clk) begin
    if(!resetn)begin
        MEM_valid<=1'b0;
    end
    else if(MEM_need_cancel)begin
        MEM_valid<=1'b0;
    end
    else if(MEM_allow_in)begin
        MEM_valid<=EXE2_MEM_valid;
    end
end
//------------------------{ready_go}end-------------------------//

//------------------------{exp_front}begin-------------------------//
assign MEM_ex = MEM_valid &
                (inst_syscall | inst_ertn | inst_break | ex_INE | ex_ADEF | ex_ALE |
                 ex_tlb_reload0 | ex_tlb_reload1 | ex_tlb_preif_unvalid | ex_tlb_plv0 |
                 ex_tlb_plv1 | ex_tlb_ld_unvalid | ex_tlb_st_unvalid | ex_tlb_page_modify |
                 has_int);
//------------------------{exp_front}end-------------------------//

//------------------------{front_push}begin-------------------------//
assign mem_front_data = res_from_mem ? ld_data : mem_we ? rkd_value : alu_result_with_rdct;// is ld_w?
assign mem_front_addr = rf_dest;
assign mem_can_not_front_push = ~rf_gr_we;
//------------------------{front_push}end-------------------------//

endmodule
