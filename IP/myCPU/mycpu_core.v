`include "csr_def.vh"
module mycpu_core #(
    parameter TLBNUM = 16
)(
    input  wire        clk,
    input  wire        resetn,
    // inst sram interface [handshake]
    output wire        inst_sram_req,
    output wire        inst_sram_wr, // 1???write 0???read
    output wire [ 3:0] inst_sram_wstrb,// wstrb ???????????????
    output wire [ 1:0] inst_sram_size,
    output wire [31:0] inst_sram_addr,// 
    output wire [31:0] inst_sram_wdata,
    input  wire [31:0] inst_sram_rdata,
    input  wire        inst_sram_addr_ok,
    input  wire        inst_sram_data_ok,
    output wire        inst_uncache_valid,
    output wire        inst_uncache_wr,
    // data sram interface
    output wire        data_sram_req,
    output wire        data_sram_wr, // 1???write 0???read
    output wire [ 3:0] data_sram_wstrb,// wstrb ???????????????
    output wire [ 1:0] data_sram_size,//
    output wire [31:0] data_sram_addr,// 
    output wire [31:0] data_sram_wdata,
    input  wire        data_sram_addr_ok,
    input  wire        data_sram_data_ok,
    input  wire [31:0] data_sram_rdata,
    output wire        data_uncache_valid,
    output wire        data_uncache_wr,
    //cache_code
    output wire        cacop_valid,
    output wire [4:0]  cache_code,
    input  wire        cacop_done,
    // trace debug interface
    output wire [31:0] debug_wb_pc,
    output wire [ 3:0] debug_wb_rf_we,
    output wire [ 4:0] debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata
);
//------------------------{5-stage pipeline control signals define}begin-------------------------//
wire valid_in;
wire preIF1_preIF2_valid;
wire preIF2_IF_valid;
wire IF_ID_valid;
wire ID_EXE1_valid;
wire EXE1_EXE2_valid;
wire EXE2_MEM_valid;
wire MEM_WB_valid;

wire preIF1_allow_in;
wire preIF2_allow_in;
wire IF_allow_in;
wire ID_allow_in;
wire EXE1_allow_in;
wire EXE2_allow_in;
wire MEM_allow_in;
wire WB_allow_in;

wire preIF1_valid;
wire preIF2_valid;
wire IF_valid;
wire ID_valid;
wire EXE1_valid;
wire EXE2_valid;
wire MEM_valid;
wire WB_valid;

wire preIF1_ready_go;
wire preIF2_ready_go;
wire IF_ready_go;
wire ID_ready_go;
wire EXE1_ready_go;
wire EXE2_ready_go;
wire MEM_ready_go;
wire WB_ready_go;
//------------------------{5-stage pipeline control signals define}end-------------------------//

//------------------------{5-stage pipeline control signals assignment}begin-------------------------//
assign preIF1_allow_in  = !preIF1_valid || (preIF2_allow_in && preIF1_ready_go);
assign preIF2_allow_in  = !preIF2_valid || (IF_allow_in && preIF2_ready_go);
assign IF_allow_in     = !IF_valid || (ID_allow_in && IF_ready_go);
assign ID_allow_in     = !ID_valid || (EXE1_allow_in && ID_ready_go);
assign EXE1_allow_in   = !EXE1_valid || (EXE2_allow_in && EXE1_ready_go);
assign EXE2_allow_in   = !EXE2_valid || (MEM_allow_in && EXE2_ready_go);
assign MEM_allow_in    = !MEM_valid || (WB_allow_in && MEM_ready_go);
assign WB_allow_in     = !WB_valid || (WB_ready_go);

assign valid_in       = 1'b1;
assign preIF1_preIF2_valid = preIF1_valid & preIF1_ready_go;
assign preIF2_IF_valid    = preIF2_valid & preIF2_ready_go;
assign IF_ID_valid    = IF_valid & IF_ready_go;
assign ID_EXE1_valid  = ID_valid & ID_ready_go;
assign EXE1_EXE2_valid= EXE1_valid & EXE1_ready_go;
assign EXE2_MEM_valid = EXE2_valid & EXE2_ready_go;
assign MEM_WB_valid   = MEM_valid & MEM_ready_go;
//------------------------{5-stage pipeline control signals assignment}end-------------------------//

//------------------------{cacop}begin-------------------------//
wire [31:0] inst_sram_addr_without_cacop;
assign inst_sram_addr = (cacop_valid && cache_code[2:0] == 3'b0) ? data_sram_addr : inst_sram_addr_without_cacop;

reg cacop_need_cancel;
always @(posedge clk)begin
    if(!resetn)begin
        cacop_need_cancel <= 1'b0;
    end
    else if(cacop_done)begin
        cacop_need_cancel <= 1'b0;
    end
    else if (cacop_valid & cache_code[2:0] == 3'b0)begin
        cacop_need_cancel <= 1'b1;
    end
end
//------------------------{cacop}end-------------------------//

//------------------------{regfile}begin-------------------------//
wire [4:0] rf_raddr1;
wire [4:0] rf_raddr2;
wire [4:0] rf_waddr;

wire [31:0] rf_rdata1;
wire [31:0] front_push_rdata1;
wire [31:0] rf_rdata2;
wire [31:0] front_push_rdata2;
wire [31:0] rf_wdata;

wire        rf_we;

//regfile instantiation
regfile u_regfile(
    .clk    (clk      ),
    .resetn (resetn   ),
    .raddr1 (rf_raddr1),
    .rdata1 (rf_rdata1),
    .raddr2 (rf_raddr2),
    .rdata2 (rf_rdata2),
    .we     (rf_we    ),
    .waddr  (rf_waddr ),
    .wdata  (rf_wdata )
);
//------------------------{regfile}end-------------------------//

//------------------------{Stable counter}begin-------------------------//
reg [63:0] stable_counter;
always @ (posedge clk)begin
    if(!resetn)begin
        stable_counter<=64'b0;
    end
    else begin
        stable_counter<=stable_counter+64'b1;
    end
end
//------------------------{Stable counter}end-------------------------//

//------------------------{DMW define}begin-------------------------//
wire  [2:0] dmw_vseg0;
wire        dmw_found0;
wire  [2:0] dmw_pseg0;
wire  [2:0] dmw_vseg1;
wire        dmw_found1;
wire  [2:0] dmw_pseg1;
//------------------------{DMW define}end-------------------------//

//------------------------{TLB}begin-------------------------//
wire [31:0] csr_TLBEHI;
wire [31:0] csr_TLBIDX;
wire [1:0]  csr_CRMD_PLV;

wire        tlbrd_we;
wire        tlbsrch_we;
wire        tlbwr_we;
wire        tlbfill_we;
wire        flush;
reg [3:0]   tlbfill_random;

// tlbfill random begin
always @(posedge clk) begin
    if (!resetn)
        tlbfill_random <= 4'b0001; // ????????? 0
    else if (tlbfill_we)
        tlbfill_random <= {tlbfill_random[2:0],
                           tlbfill_random[3] ^ tlbfill_random[2]};
end

// search port 0 (for fetch the inst)
wire [18:0] s0_vppn;
wire        s0_va_bit12;
wire [9:0]  s0_asid;
wire        s0_found;
wire [$clog2(TLBNUM)-1:0] s0_index; // ??????????? log2?????????????????????
wire [19:0] s0_ppn;
wire [5:0]  s0_ps;
wire [1:0]  s0_plv;
wire [1:0]  s0_mat;
wire        s0_d;
wire        s0_v;

// search port 1 (for load/store the data)
wire [18:0] s1_vppn;
wire        s1_va_bit12;
wire [9:0]  s1_asid;
wire [9:0]  tlbinv_asid;
wire [9:0]  s1_asid_without_invtlb;
wire       s1_found;
wire [$clog2(TLBNUM)-1:0] s1_index;
wire [19:0] s1_ppn;
wire [5:0]  s1_ps;
wire [1:0]  s1_plv;
wire [1:0]  s1_mat;
wire        s1_d;
wire        s1_v;

// invtlb opcode
wire        invtlb_valid;
wire [4:0]  invtlb_op;

assign s1_asid = invtlb_valid ? tlbinv_asid : s1_asid_without_invtlb;

// write port
wire        we;
wire [$clog2(TLBNUM)-1:0] w_index_from_csr;
wire [$clog2(TLBNUM)-1:0] w_index;
wire        w_e;
wire [18:0] w_vppn;
wire [5:0]  w_ps;
wire [9:0]  w_asid;
wire        w_g;
wire [19:0] w_ppn0;
wire [1:0]  w_plv0;
wire [1:0]  w_mat0;
wire        w_d0;
wire        w_v0;
wire [19:0] w_ppn1;
wire [1:0]  w_plv1;
wire [1:0]  w_mat1;
wire        w_d1;
wire        w_v1;

assign we = tlbwr_we | tlbfill_we;
assign w_index = tlbwr_we ? w_index_from_csr : tlbfill_we ? tlbfill_random : 4'h0;

// read port
wire [$clog2(TLBNUM)-1:0] r_index;
wire        r_e;
wire [18:0] r_vppn;
wire [5:0]  r_ps;
wire [9:0]  r_asid;
wire        r_g;
wire [19:0] r_ppn0;
wire [1:0]  r_plv0;
wire [1:0]  r_mat0;
wire        r_d0;
wire        r_v0;
wire [19:0] r_ppn1;
wire [1:0]  r_plv1;
wire [1:0]  r_mat1;
wire        r_d1;
wire        r_v1;

//tlb_ex
wire       ex_tlb_reload0;//tlb????????
wire       ex_tlb_reload1;//tlb????????
wire       ex_tlb_ld_unvalid;//tlb??load????
wire       ex_tlb_st_unvalid;//tlb??store????
wire       ex_tlb_preif_unvalid;//tlb????????
wire       ex_tlb_plv0;//tlb???????????
wire       ex_tlb_plv1;//tlb???????????
wire       ex_tlb_page_modify;//tlb??????

wire tlb_inst_req;
wire tlb_data_req;
wire tlb_load_req;
wire tlb_store_req;

tlb u_tlb(
    .clk(clk),
    .resetn(resetn),

    // search port 0 (for fetch the inst)
    .s0_vppn(s0_vppn),
    .s0_va_bit12(s0_va_bit12),
    .s0_asid(s0_asid),
    .s0_found(s0_found),
    .s0_index(s0_index), // ??????????? log2?????????????????????
    .s0_ppn(s0_ppn),
    .s0_ps(s0_ps),
    .s0_plv(s0_plv),
    .s0_mat(s0_mat),
    .s0_d(s0_d),
    .s0_v(s0_v),

    // search port 1 (for load/store the data)
    .s1_vppn(s1_vppn),
    .s1_va_bit12(s1_va_bit12),
    .s1_asid(s1_asid),
    .s1_found(s1_found),
    .s1_index(s1_index),
    .s1_ppn(s1_ppn),
    .s1_ps(s1_ps),
    .s1_plv(s1_plv),
    .s1_mat(s1_mat),
    .s1_d(s1_d),
    .s1_v(s1_v),

    // invtlb opcode
    .invtlb_valid(invtlb_valid),
    .invtlb_op(invtlb_op),
    
    // write port
    .we(we),
    .w_index(w_index),
    .w_e(w_e),
    .w_vppn(w_vppn),
    .w_ps(w_ps),
    .w_asid(w_asid),
    .w_g(w_g),
    .w_ppn0(w_ppn0),
    .w_plv0(w_plv0),
    .w_mat0(w_mat0),
    .w_d0(w_d0),
    .w_v0(w_v0),
    .w_ppn1(w_ppn1),
    .w_plv1(w_plv1),
    .w_mat1(w_mat1),
    .w_d1(w_d1),
    .w_v1(w_v1),

    // read port
    .r_index(r_index),
    .r_e(r_e),
    .r_vppn(r_vppn),
    .r_ps(r_ps),
    .r_asid(r_asid),
    .r_g(r_g),
    .r_ppn0(r_ppn0),
    .r_plv0(r_plv0),
    .r_mat0(r_mat0),
    .r_d0(r_d0),
    .r_v0(r_v0),
    .r_ppn1(r_ppn1),
    .r_plv1(r_plv1),
    .r_mat1(r_mat1),
    .r_d1(r_d1),
    .r_v1(r_v1),
    .csr_CRMD_PLV(csr_CRMD_PLV),

    //tlb_ex
    .ex_tlb_reload0         (ex_tlb_reload0),//tlb????????
    .ex_tlb_reload1         (ex_tlb_reload1),//tlb????????
    .ex_tlb_ld_unvalid      (ex_tlb_ld_unvalid),//tlb??load????
    .ex_tlb_st_unvalid      (ex_tlb_st_unvalid),//tlb??store????
    .ex_tlb_preif_unvalid   (ex_tlb_preif_unvalid),//tlb????????
    .ex_tlb_plv0            (ex_tlb_plv0),//tlb???????????
    .ex_tlb_plv1            (ex_tlb_plv1),//tlb???????????
    .ex_tlb_page_modify     (ex_tlb_page_modify),//tlb??????
    .tlb_inst_req(tlb_inst_req),
    .tlb_data_req (tlb_data_req),
    .tlb_load_req (tlb_load_req),
    .tlb_store_req(tlb_store_req),

    //DWM
    .dmw_found0(dmw_found0),
    .dmw_found1(dmw_found1)
);
//------------------------{TLB}end-------------------------//

//------------------------{csr_ex_front}begin-------------------------//
wire MEM_ex;
wire WB_ex;

wire older_ex_for_exe2;
wire older_ex_for_mem;
assign older_ex_for_exe2 = MEM_ex | WB_ex;
assign older_ex_for_mem = WB_ex;
//------------------------{csr_ex_front}end-------------------------//

//------------------------{front_push}begin-------------------------//
wire [31:0] exe1_front_data;
wire [31:0] exe2_front_data;
wire [31:0] mem_front_data;
wire [31:0] wb_front_data;
wire [ 4:0] exe1_front_addr;
wire [ 4:0] exe2_front_addr;
wire [ 4:0] mem_front_addr;
wire [ 4:0] wb_front_addr;
wire        exe2_can_not_front_push;
wire        mem_can_not_front_push;
wire         wb_can_not_front_push;
assign front_push_rdata1 = rf_raddr1 == 5'b0 ? 32'b0 : (exe2_front_addr == rf_raddr1 & EXE2_valid & ~exe2_can_not_front_push) ? exe2_front_data :
                                                       (mem_front_addr == rf_raddr1 & MEM_valid & ~mem_can_not_front_push) ? mem_front_data :
                                                       (wb_front_addr  == rf_raddr1 & WB_valid & !flush & ~ wb_can_not_front_push) ? wb_front_data  :
                                                       rf_rdata1;
assign front_push_rdata2 = rf_raddr2 == 5'b0 ? 32'b0 : (exe2_front_addr == rf_raddr2 & EXE2_valid & ~exe2_can_not_front_push) ? exe2_front_data :
                                                       (mem_front_addr == rf_raddr2 & MEM_valid & ~mem_can_not_front_push) ? mem_front_data :
                                                       (wb_front_addr  == rf_raddr2 & WB_valid & !flush & ~ wb_can_not_front_push) ? wb_front_data  :
                                                       rf_rdata2;                        
//------------------------{front_push}end-------------------------//

//------------------------{stall}begin-------------------------//
wire        EXE1_rf_gr_we;
wire [ 4:0] EXE1_rf_dest;
wire [ 4:0] EXE2_rf_dest;
wire [ 4:0] MEM_rf_dest;
wire [ 4:0] WB_rf_dest;
wire src1_stall;
wire src2_stall;
wire need_stall;
wire exe2_need_stall_inst;
wire exe2_need_stall_csr;
wire mem_need_stall_inst;
wire mem_need_stall_csr;
wire wb_need_stall_csr;
//need to distribute inst for increasing effciency [todo]
wire mem_load_wait;
assign mem_load_wait = mem_need_stall_inst & ~data_sram_data_ok;
assign src1_stall = (rf_raddr1 != 5'd0) &&
                    ID_valid &&
                    (((rf_raddr1 == EXE1_rf_dest) && EXE1_valid && EXE1_rf_gr_we) ||
                     ((rf_raddr1 == EXE2_rf_dest) && EXE2_valid && (exe2_need_stall_inst || exe2_need_stall_csr)) ||
                     ((rf_raddr1 == MEM_rf_dest) && MEM_valid && (mem_load_wait || mem_need_stall_csr)) ||
                     ((rf_raddr1 == WB_rf_dest) && WB_valid && wb_need_stall_csr));
assign src2_stall = (rf_raddr2 != 5'd0) &&
                    ID_valid &&
                    (((rf_raddr2 == EXE1_rf_dest) && EXE1_valid && EXE1_rf_gr_we) ||
                     ((rf_raddr2 == EXE2_rf_dest) && EXE2_valid && (exe2_need_stall_inst || exe2_need_stall_csr)) ||
                     ((rf_raddr2 == MEM_rf_dest) && MEM_valid && (mem_load_wait || mem_need_stall_csr)) ||
                     ((rf_raddr2 == WB_rf_dest) && WB_valid && wb_need_stall_csr));
assign need_stall = src1_stall | src2_stall;
//------------------------{stall}end-------------------------//

//------------------------{req_to_dataok_trigger}begin-------------------------//
wire req_to_dataok_trigger;
wire inst_resp_discard;
//------------------------{req_to_dataok_trigger}end-------------------------//

//------------------------{branch prediction}begin---------------------------//
//btb
// query port: preIF lookup
wire        query_valid;
wire [31:0] query_pc;
wire        btb_query_hit;//valid and tag match
wire [31:0] btb_query_target;
wire [ 1:0] query_type;
// update port: Decode writes back real result
wire        update_valid;
wire [31:0] update_pc;
wire [31:0] update_target;//real target
wire [ 1:0] update_type;
btb u_btb(
    .clk                (clk   ),
    .resetn             (resetn),
    // query port: preIF lookup
    .query_valid        (query_valid ),
    .query_pc           (query_pc    ),
    .query_hit          (btb_query_hit   ),//valid and tag match
    .query_target       (btb_query_target),
    .query_type         (query_type  ),
    // update port: Decode writes back real result
    .update_valid       (update_valid ),
    .update_pc          (update_pc    ),
    .update_target      (update_target),//real target
    .update_type        (update_type  ),
    // Èç¹ûÈ¡Ïû¾Í²»Í¬²½¸üÐÂ
    .update_cancel (need_cancel | cacop_need_cancel)
);

wire query_taken;
wire update_taken;
wire bht_update_valid;
//bht
bht u_bht(
    .clk            (clk   ),
    .resetn         (resetn),
    // query port
    .query_valid    (query_valid),
    .query_pc       (query_pc   ),//pc being predicted
    .query_taken    (query_taken),//predict taken
    // update port
    .update_valid   (bht_update_valid),//update BHT
    .update_pc      (update_pc   ),//branch pc
    .update_taken   (update_taken),//real taken
    .update_cancel  (need_cancel | cacop_need_cancel)//Èç¹ûÈ¡Ïû¾Í²»Í¬²½¸üÐÂ
);

//ras
wire push_valid;
wire [31:0] push_target;
wire pop_valid;
wire        ras_query_hit;
wire [31:0] ras_query_target;
ras u_ras(
    .clk            (clk   ),
    .resetn         (resetn),
    // frontend query
    .query_valid    (query_valid ),
    .query_hit      (ras_query_hit   ),
    .query_target   (ras_query_target),
    // backend real call update
    .push_valid     (push_valid ),
    .push_target    (push_target),
    // backend real return update
    .pop_valid      (pop_valid)
);
//------------------------{branch prediction}end---------------------------//

//------------------------{Ô¤ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½Ò?ï¿½ï¿½×ªï¿½ï¿½ï¿½Åºï¿½ï¿½ï¿½ï¿½ï¿½}begin-------------------------//
wire        br_taken;
wire [31:0] br_target;

wire        br_afterpred_taken;
wire [31:0] br_afterpred_target;

reg         br_afterpred_taken_r;
reg  [31:0] br_afterpred_target_r;

// this is the csr need to cancel all
wire need_cancel;
// this is the br inst need to cancel the preIF IF ID
wire need_br_cancel;
assign need_cancel = flush;

//cacop cancel
wire [31:0] cacop_pc;
//[NOTICE:Ñ§»áÒ»ÕÐ]CE²»Èç·Åµ½ <= Ñ¡Ôñ,WNS¿ÉÄÜºÃÒ»µã
always @(posedge clk) begin
    if (!resetn) begin
        br_afterpred_taken_r  <= 1'b0;
        br_afterpred_target_r <= 32'b0;
    end
    else begin
        br_afterpred_taken_r <= (need_cancel || cacop_need_cancel) ? 1'b0
                                : br_afterpred_taken;

        br_afterpred_target_r <= br_afterpred_target;
    end
end

assign br_taken       = br_afterpred_taken_r;
assign br_target      = br_afterpred_target_r;
assign need_br_cancel = br_afterpred_taken_r;
//------------------------{Ô¤ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½Ò?ï¿½ï¿½×ªï¿½ï¿½ï¿½Åºï¿½ï¿½ï¿½ï¿½ï¿½}end-------------------------//


//------------------------{5 pipeline bus + inst ram control}begin-------------------------//
localparam preIF1_preIF2_bus_width = 147;
localparam preIF2_IF_bus_width    = 105;
localparam IF_ID_bus_width    = 137;
localparam ID_EXE1_bus_width   = 237;//263+5+1-32
localparam EXE1_EXE2_bus_width  = 271;//226-32
localparam EXE2_MEM_bus_width  = 194;//226-32
localparam MEM_WB_bus_width   = 219;

wire [preIF1_preIF2_bus_width-1:0] preIF1_preIF2_bus;
wire [preIF2_IF_bus_width-1:0] preIF2_IF_bus;
wire [IF_ID_bus_width-1:0] IF_ID_bus;
wire [ID_EXE1_bus_width-1:0]ID_EXE1_bus;
wire [EXE1_EXE2_bus_width-1:0] EXE1_EXE2_bus;
wire [EXE2_MEM_bus_width-1:0] EXE2_MEM_bus;
wire [MEM_WB_bus_width-1:0] MEM_WB_bus;
//------------------------{5-stage pipeline bus + inst ram control}end------------------------//

//------------------------{csr_regfile}begin-------------------------//
wire [13:0] csr_num;
wire [31:0] csr_rvalue;
wire        csr_we;
wire [31:0] csr_wdata;

wire [31:0] csr_wmask;
wire        csr_re;
wire        wb_ex;
wire [31:0] timer_cnt;
wire [7:0]  hw_int_in;
wire        ipi_int_in;
wire [31:0] wb_pc;
wire [31:0] wb_vaddr;
wire [5:0]  wb_ecode;
wire [8:0]  wb_esubcode;
wire [31:0] csr_target;
wire        has_int;
wire        csr_CRMD_DA;
wire        csr_CRMD_PG;
//tlbreload ??????CSR
wire        ex_tlb_reload;

// ERTN ???? CRMD
wire        inst_ertn;
// ????BADV
wire csr_tlb_reload0;
wire csr_tlb_plv0   ;
wire csr_tlb_reload1; 
wire csr_tlb_plv1   ;     
// ????TLBEHI ex_tlb
wire ex_tlb;
//mat:??????????
wire   [1:0] csr_CRMD_DATF;
wire   [1:0] csr_CRMD_DATM;
wire   [1:0] dmw_mat0;
wire   [1:0] dmw_mat1;
//????s1_mat???????????????
wire   [1:0] inst_mat;
wire   [1:0] data_mat;

assign hw_int_in = 8'h0;
assign ipi_int_in= 1'h0;

//----------------Icache?????????-----------
assign inst_uncache_valid   = (inst_mat == 2'b00);
assign inst_uncache_wr      =  inst_wr;
//---------------------------------------------

//----------------Dcache?????????-----------
assign data_uncache_valid   = (data_mat == 2'b00);
assign data_uncache_wr      =  data_wr;
//---------------------------------------------

csr_regfile #(
    .TLBNUM(TLBNUM)
)u_csr_regfile (
    .clk         (clk),
    .resetn      (resetn),
    .csr_num     (csr_num),
    .csr_we      (csr_we),
    .csr_wmask   (csr_wmask),
    .csr_wvalue  (csr_wdata),
    .csr_re      (csr_re),
    .csr_rvalue  (csr_rvalue),
    .wb_ex       (wb_ex),
    .wb_ecode    (wb_ecode),
    .wb_esubcode (wb_esubcode),
    .hw_int_in   (hw_int_in),
    .ipi_int_in  (ipi_int_in),
    .wb_pc       (wb_pc),
    .wb_vaddr    (wb_vaddr),
    .has_int     (has_int),
    .coreid_in   (32'b0  ),
    //TLB??csr????
    .csr_TLBEHI  (csr_TLBEHI),
    .csr_TLBIDX  (csr_TLBIDX),
    .csr_CRMD_PLV(csr_CRMD_PLV),
    //tlbrd??? read port,???csr
    .r_index     (r_index),
    .s0_asid     (s0_asid),
    .s1_asid_without_invtlb(s1_asid_without_invtlb),
    .r_e         (r_e),
    .r_vppn      (r_vppn),
    .r_ps        (r_ps),
    .r_asid      (r_asid),
    .r_g         (r_g),
    .r_ppn0      (r_ppn0),
    .r_plv0      (r_plv0),
    .r_mat0      (r_mat0),
    .r_d0        (r_d0),
    .r_v0        (r_v0),
    .r_ppn1      (r_ppn1),
    .r_plv1      (r_plv1),
    .r_mat1      (r_mat1),
    .r_d1        (r_d1),
    .r_v1        (r_v1),
    // write port [csr-tlb]
    .w_index(w_index_from_csr),
    .w_e(w_e),
    .w_vppn(w_vppn),
    .w_ps(w_ps),
    .w_asid(w_asid),
    .w_g(w_g),
    .w_ppn0(w_ppn0),
    .w_plv0(w_plv0),
    .w_mat0(w_mat0),
    .w_d0(w_d0),
    .w_v0(w_v0),
    .w_ppn1(w_ppn1),
    .w_plv1(w_plv1),
    .w_mat1(w_mat1),
    .w_d1(w_d1),
    .w_v1(w_v1),
    //rlbrd
    .tlbrd_we    (tlbrd_we),
    .csr_CRMD_DA (csr_CRMD_DA),
    .csr_CRMD_PG (csr_CRMD_PG),
    //tlbreload ??????CSR
    .ex_tlb_reload  (ex_tlb_reload),
    //DMW
    .dmw_vseg0(dmw_vseg0),
    .dmw_found0(dmw_found0),
    .dmw_pseg0(dmw_pseg0),
    .dmw_vseg1(dmw_vseg1),
    .dmw_found1(dmw_found1),
    .dmw_pseg1(dmw_pseg1),
    // ERTN ???? CRMD
    .inst_ertn(inst_ertn),
    // BADV
    .csr_tlb_reload0(csr_tlb_reload0),
    .csr_tlb_plv0   (csr_tlb_plv0   ),
    .csr_tlb_reload1(csr_tlb_reload1),  
    .csr_tlb_plv1   (csr_tlb_plv1   ),
    //ex_tlb TLBEHI
    .ex_tlb         (ex_tlb         ),
    //mat:??????????
    .csr_CRMD_DATF          (csr_CRMD_DATF),
    .csr_CRMD_DATM          (csr_CRMD_DATM),
    .dmw_mat0               (dmw_mat0),
    .dmw_mat1               (dmw_mat1)
);
//------------------------{csr_regfile}end-------------------------//

//------------------------{5-stage pipeline instantiation}begin-------------------------//
pre_IF1 #(
    .outbus_width(preIF1_preIF2_bus_width)
) u_pre_IF1
(
    .clk(clk),
    .resetn(resetn),
    //control signal
    .valid_in(valid_in),
    .preIF1_allow_in(preIF1_allow_in),
    .preIF1_valid(preIF1_valid),
    .preIF1_ready_go(preIF1_ready_go),

    .preIF1_preIF2_bus(preIF1_preIF2_bus),
    
    .br_target(br_target),
    .br_taken(br_taken),
    //cancel
    .need_cancel(need_cancel | cacop_need_cancel),
    //stall
    .need_stall(need_stall),
    .csr_target(cacop_need_cancel ? cacop_pc : csr_target),
    // search port 0 (for fetch the inst)
    .s0_vppn(s0_vppn),
    .s0_va_bit12(s0_va_bit12),
    .s0_found(s0_found),
    .s0_index(s0_index), // ??????????? log2?????????????????????
    .s0_ppn(s0_ppn),
    .s0_ps(s0_ps),
    .s0_plv(s0_plv),
    .s0_mat(s0_mat),
    .s0_d(s0_d),
    .s0_v(s0_v),
    //tlb_ex
    .ex_tlb_reload0         (ex_tlb_reload0),//tlb????????
    .ex_tlb_preif_unvalid   (ex_tlb_preif_unvalid),//tlb????????
    .ex_tlb_plv0            (ex_tlb_plv0),//tlb???????????
    .tlb_inst_req           (tlb_inst_req),
    //DMW
    .dmw_vseg0(dmw_vseg0),
    .dmw_found0(dmw_found0),
    .dmw_pseg0(dmw_pseg0),
    //CRMD PG DA
    .csr_CRMD_DA     (csr_CRMD_DA),
    .csr_CRMD_PG     (csr_CRMD_PG),
    //mat:??????????
    .csr_CRMD_DATF          (csr_CRMD_DATF),
    .csr_CRMD_DATM          (csr_CRMD_DATM),
    .dmw_mat0               (dmw_mat0),
    //branch prediction
    // query port: preIF lookup
    .query_valid        (query_valid ),
    .query_pc           (query_pc    ),
    .btb_query_hit      (btb_query_hit   ),//valid and tag match
    .btb_query_target   (btb_query_target),
    .ras_query_hit      (ras_query_hit   ),//valid and tag match
    .ras_query_target   (ras_query_target),
    .query_type         (query_type  ),
    .query_taken        (query_taken)//predict taken
);

pre_IF2 #(
    .inbus_width(preIF1_preIF2_bus_width),
    .outbus_width(preIF2_IF_bus_width)
) u_pre_IF2
(
    .clk(clk),
    .resetn(resetn),
    //control signal
    .preIF1_preIF2_valid(preIF1_preIF2_valid),
    .preIF2_allow_in(preIF2_allow_in),
    .preIF2_valid(preIF2_valid),
    .preIF2_ready_go(preIF2_ready_go),

    .preIF1_preIF2_bus(preIF1_preIF2_bus),
    .preIF2_IF_bus(preIF2_IF_bus),

    .br_taken(br_taken),
    //cancel
    .need_cancel(need_cancel | cacop_need_cancel),
    //stall
    .need_stall(need_stall),
    //handshake
    .inst_sram_req(inst_sram_req),
    .inst_sram_wr(inst_sram_wr), // 1???write 0???read
    .inst_sram_wstrb(inst_sram_wstrb),// wstrb ???????????????
    .inst_sram_size(inst_sram_size),
    .inst_sram_addr_without_cacop(inst_sram_addr_without_cacop),
    .inst_sram_wdata(inst_sram_wdata),
    .inst_sram_addr_ok(inst_sram_addr_ok),
    .IF_allow_in(IF_allow_in),
    .inst_sram_data_ok(inst_sram_data_ok),
    .req_to_dataok_trigger(req_to_dataok_trigger),
    .inst_resp_discard(inst_resp_discard),
    //CRMD
    .csr_CRMD_DA(csr_CRMD_DA),
    .csr_CRMD_PG(csr_CRMD_PG),
    //????s1_mat???????????????
    .inst_mat               (inst_mat),
    .inst_wr                (inst_wr)
);

fetch #(
    .inbus_width(preIF2_IF_bus_width),
    .outbus_width(IF_ID_bus_width)
)u_fetch(
    .clk(clk),
    .resetn(resetn),
    //control signal
    .preIF2_IF_valid(preIF2_IF_valid),
    .IF_valid(IF_valid),
    .IF_allow_in(IF_allow_in),
    .IF_ready_go(IF_ready_go),
    //bus
    .preIF2_IF_bus(preIF2_IF_bus),
    .IF_ID_bus(IF_ID_bus),
    //cancel
    .need_cancel(need_cancel | need_br_cancel | cacop_need_cancel),
    //stall
    .need_stall(need_stall),
    //handshake
    .inst_sram_data_ok(inst_sram_data_ok),
    .inst_sram_rdata(inst_sram_rdata),
    .ID_allow_in(ID_allow_in),
    .inst_resp_discard(inst_resp_discard),
    .req_to_dataok_trigger(req_to_dataok_trigger)
);
decode #(
    .inbus_width(IF_ID_bus_width),
    .outbus_width(ID_EXE1_bus_width)
)u_decode(
    .clk(clk),
    .resetn(resetn),
    //control signal
    .ID_valid(ID_valid),
    .IF_ID_valid(IF_ID_valid),
    .ID_allow_in(ID_allow_in),
    .ID_ready_go(ID_ready_go),
    
    .IF_ID_bus(IF_ID_bus),//bus
    .ID_EXE1_bus(ID_EXE1_bus),
    //br_prediction
    .br_afterpred_taken(br_afterpred_taken),
    .br_afterpred_target(br_afterpred_target),

    .rf_raddr1(rf_raddr1),//decode src1&2 address   ---- stall need use 
    .rf_raddr2(rf_raddr2),
    .rf_rdata1(front_push_rdata1),
    .rf_rdata2(front_push_rdata2),//have been front_push 
    //cancel
    .need_cancel(need_cancel | cacop_need_cancel),
    //stall
    .need_stall(need_stall),
    //???
    .has_int(has_int),
    //branch prediction
    // update port: Decode writes back real result
    .update_valid       (update_valid ),
    .bht_update_valid   (bht_update_valid),
    .update_pc          (update_pc    ),
    .update_target      (update_target),//real target
    .update_type        (update_type  ),
    .update_taken       (update_taken),//real taken
    // backend real call update
    .push_valid         (push_valid ),
    .push_target        (push_target),
    // backend real return update
    .pop_valid          (pop_valid)
);

exe1 #(
    .inbus_width(ID_EXE1_bus_width),
    .outbus_width(EXE1_EXE2_bus_width)
)u_exe1(
    .clk(clk),
    .resetn(resetn),
    //control signal
    .EXE1_ready_go(EXE1_ready_go),
    .EXE1_valid(EXE1_valid),
    .ID_EXE1_valid(ID_EXE1_valid),
    .EXE1_allow_in(EXE1_allow_in),
    
    .ID_EXE1_bus(ID_EXE1_bus),//bus
    .EXE1_EXE2_bus(EXE1_EXE2_bus),
    //stall
    .EXE1_rf_dest(EXE1_rf_dest),
    .EXE1_rf_gr_we(EXE1_rf_gr_we),
    //cancel
    .need_cancel(need_cancel),
    //stable counter
    .stable_counter(stable_counter),
    // search port 1 (for load/store the data)
    .s1_vppn(s1_vppn),
    .s1_va_bit12(s1_va_bit12),
    .tlbinv_asid(tlbinv_asid),
    .s1_found(s1_found),
    .s1_index(s1_index),
    .s1_ppn(s1_ppn),
    .s1_ps(s1_ps),
    .s1_plv(s1_plv),
    .s1_mat(s1_mat),
    .s1_d(s1_d),
    .s1_v(s1_v),
    .csr_TLBEHI  (csr_TLBEHI),
    //invtlb
    .invtlb_valid(invtlb_valid),
    .invtlb_op(invtlb_op),
    //CRMD PG DA
    .csr_CRMD_DA     (csr_CRMD_DA),
    .csr_CRMD_PG     (csr_CRMD_PG),
    //tlb_ex
    .ex_tlb_reload1         (ex_tlb_reload1),//tlb????????
    .ex_tlb_ld_unvalid      (ex_tlb_ld_unvalid),//tlb??load????
    .ex_tlb_st_unvalid      (ex_tlb_st_unvalid),//tlb??store????
    .ex_tlb_plv1            (ex_tlb_plv1),//tlb???????????
    .ex_tlb_page_modify     (ex_tlb_page_modify),//tlb??????
    .tlb_data_req           (tlb_data_req),
    .tlb_load_req           (tlb_load_req),
    .tlb_store_req          (tlb_store_req),
    //DMW
    .dmw_vseg1              (dmw_vseg1),
    .dmw_found1             (dmw_found1),
    .dmw_pseg1              (dmw_pseg1),
    //mat:??????????
    .csr_CRMD_DATF          (csr_CRMD_DATF),
    .csr_CRMD_DATM          (csr_CRMD_DATM),
    .dmw_mat1               (dmw_mat1)
);

exe2 #(
    .inbus_width(EXE1_EXE2_bus_width),
    .outbus_width(EXE2_MEM_bus_width)
)u_exe2(
    .clk(clk),
    .resetn(resetn),
    //control signal
    .EXE2_ready_go(EXE2_ready_go),
    .EXE2_valid(EXE2_valid),
    .EXE1_EXE2_valid(EXE1_EXE2_valid),
    .EXE2_allow_in(EXE2_allow_in),
    
    .EXE1_EXE2_bus(EXE1_EXE2_bus),//bus
    .EXE2_MEM_bus(EXE2_MEM_bus),
    //stall
    .EXE2_rf_dest(EXE2_rf_dest),
    .need_stall_inst(exe2_need_stall_inst),
    .need_stall_csr(exe2_need_stall_csr),
    //front_push
    .exe2_front_data(exe2_front_data),
    .exe2_front_addr(exe2_front_addr),
    //can_not_front_push
    .exe2_can_not_front_push(exe2_can_not_front_push),
    //cancel
    .need_cancel(need_cancel),
    //ex
    .older_ex_for_exe2(older_ex_for_exe2),
    //handshake
    .data_sram_req    (data_sram_req    ),
    .data_sram_wr     (data_sram_wr     ),
    .data_sram_wstrb  (data_sram_wstrb  ),
    .data_sram_size   (data_sram_size   ),
    .data_sram_addr   (data_sram_addr   ),
    .data_sram_wdata  (data_sram_wdata  ),
    .data_sram_addr_ok(data_sram_addr_ok),
    .data_sram_data_ok(data_sram_data_ok),
    .MEM_allow_in     (MEM_allow_in     ),
    //uncache
    .data_mat         (data_mat),
    .data_wr          (data_wr),
    //cacop
    .csr_CRMD_PLV     (csr_CRMD_PLV),
    .cache_code       (cache_code  ),
    .cacop_valid      (cacop_valid ),
    .cacop_done       (cacop_done  ),
    .cacop_pc         (cacop_pc    )
);

mem #(
    .inbus_width(EXE2_MEM_bus_width),
    .outbus_width(MEM_WB_bus_width)
)u_mem(
    .clk(clk),
    .resetn(resetn),
    //control signal
    .MEM_valid(MEM_valid),
    .EXE2_MEM_valid(EXE2_MEM_valid),
    .MEM_allow_in(MEM_allow_in),
    .MEM_ready_go(MEM_ready_go),
    .EXE2_MEM_bus(EXE2_MEM_bus),//bus
    .MEM_WB_bus(MEM_WB_bus),
    //stall
    .MEM_rf_dest(MEM_rf_dest),
    .need_stall_inst(mem_need_stall_inst),
    .need_stall_csr(mem_need_stall_csr),
    //front_push
    .mem_front_data(mem_front_data),
    .mem_front_addr(mem_front_addr),
    //cancel
    .need_cancel(need_cancel),
    .older_ex_for_mem(older_ex_for_mem),
    //ex_front
    .MEM_ex(MEM_ex),
    //handshake
    .data_sram_data_ok(data_sram_data_ok),
    .data_sram_rdata  (data_sram_rdata  ),
    .WB_allow_in(WB_allow_in),
     //can_not_front_push
    .mem_can_not_front_push(mem_can_not_front_push)
);

wb #(
    .inbus_width(MEM_WB_bus_width)
)u_wb(
    .clk(clk),
    .resetn(resetn),
    //control signal
    .WB_valid(WB_valid),
    .MEM_WB_valid(MEM_WB_valid),
    .WB_allow_in(WB_allow_in),
    .WB_ready_go(WB_ready_go),
    
    .MEM_WB_bus(MEM_WB_bus),
    .debug_wb_pc(debug_wb_pc),
    .debug_wb_rf_wdata(debug_wb_rf_wdata),
    .debug_wb_rf_we(debug_wb_rf_we),
    .debug_wb_rf_wnum(debug_wb_rf_wnum),
    .rf_waddr(rf_waddr),
    .rf_wdata(rf_wdata),
    .rf_we(rf_we),
    //stall
    .WB_rf_dest(WB_rf_dest),
    .need_stall_csr(wb_need_stall_csr),
    //front_push
    .wb_front_data(wb_front_data),
    .wb_front_addr(wb_front_addr),
     //can_not_front_push
    .wb_can_not_front_push(wb_can_not_front_push),
    //csr   
    .csr_rvalue(csr_rvalue),
    .csr_num(csr_num),
    .csr_wdata(csr_wdata),
    .csr_wmask(csr_wmask),
    .csr_we(csr_we),
    .csr_re(csr_re),
    .csr_target(csr_target),
    .flush(flush),
    //cancel
    .need_cancel(need_cancel),
    //wb?????
    .wb_pc(wb_pc),
    .wb_ex(wb_ex),
    .wb_vaddr(wb_vaddr),
    .ecode(wb_ecode),
    .esubcode(wb_esubcode),
    //ex_front
    .WB_ex(WB_ex),
    //tlbrd
    .tlbrd_we(tlbrd_we),
    .tlbwr_we(tlbwr_we),
    .tlbfill_we(tlbfill_we),
    //tlbidx
    .csr_TLBIDX(csr_TLBIDX),
    //tlbreload ??????CSR
    .ex_tlb_reload(ex_tlb_reload),
    //ERTN ???? CRMD
    .inst_ertn(inst_ertn),
    // ???? csr_regfile ?????? BADV
    .csr_tlb_reload0(csr_tlb_reload0),
    .csr_tlb_plv0   (csr_tlb_plv0   ),
    .csr_tlb_reload1(csr_tlb_reload1),  
    .csr_tlb_plv1   (csr_tlb_plv1   ),
    //ex_tlb TLBEHI
    .ex_tlb         (ex_tlb         )
);
//------------------------{5-stage pipeline instantiation}end-------------------------//

endmodule
