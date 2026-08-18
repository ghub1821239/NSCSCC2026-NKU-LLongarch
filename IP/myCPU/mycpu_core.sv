`include "csr_def.vh"
module mycpu_core #(
    parameter  TLBNUM = 16,
    parameter  ISSUE  = 2
)(
    input  wire                clk,
    input  wire                resetn,
    // inst sram interface [handshake]
    output wire                inst_sram_req,
    output wire                inst_sram_wr, // 1表示write 0表示read
    output wire [ 3:0]         inst_sram_wstrb,// wstrb 对应原始数据的字节写使能
    output wire [ 1:0]         inst_sram_size,
    output wire [31:0]         inst_sram_addr,// 
    output wire [31:0]         inst_sram_wdata,
    input  wire [127:0]        inst_sram_rdata,
    input  wire                inst_sram_addr_ok,
    input  wire                inst_sram_data_ok,
    output wire                inst_uncache_valid,
    output wire                inst_uncache_wr,
    // data sram interface
    output wire                data_sram_req,
    output wire                data_sram_wr, // 1表示write 0表示read
    output wire [ 3:0]         data_sram_wstrb,// wstrb 对应原始数据的字节写使能
    output wire [ 1:0]         data_sram_size,//
    output wire [31:0]         data_sram_addr,// 
    output wire [31:0]         data_sram_wdata,
    input  wire                data_sram_addr_ok,
    input  wire                data_sram_data_ok,
    input  wire [31:0]         data_sram_rdata,
    output wire                data_uncache_valid,
    output wire                data_uncache_wr,
    //cache_code
    output wire                cacop_valid,
    output wire [4:0]          cache_code,
    input  wire                cacop_done,
    // trace debug interface
    output wire [31:0]         debug_wb_pc,
    output wire [ 3:0]         debug_wb_rf_we,
    output wire [ 4:0]         debug_wb_rf_wnum,
    output wire [31:0]         debug_wb_rf_wdata,
    output wire [ISSUE-1:0]    debug_commit_valid,
    output wire [ISSUE-1:0]    debug_commit_exception,
    output wire [5:0]          debug_commit_ecode,
    output wire [8:0]          debug_commit_esubcode,
    output wire [ISSUE*32-1:0] debug_commit_pc,
    output wire [ISSUE*4-1:0]  debug_commit_rf_wen,
    output wire [ISSUE*5-1:0]  debug_commit_rf_wnum,
    output wire [ISSUE*32-1:0] debug_commit_rf_wdata,
    //硬件中断输入
    input  wire [ 7:0]         hw_int_in
);
//------------------------{5-stage pipeline control signals define}begin-------------------------//
wire  valid_in;
wire  preIF1_preIF2_valid;
wire  preIF2_IF_valid;
wire  IF_ID_valid;
wire  ID_EXE1_valid;
wire  EXE1_EXE2_valid;
wire  EXE2_MEM_valid;
wire  MEM_WB_valid;

wire  preIF1_allow_in;
wire  preIF2_allow_in;
wire  IF_allow_in;
wire  ID_allow_in;
wire  EXE1_allow_in;
wire  EXE2_allow_in;
wire  MEM_allow_in;
wire  WB_allow_in;

wire  preIF1_valid;
wire  preIF2_valid;
wire  IF_valid;
wire  ID_valid;
wire  EXE1_valid;
wire  EXE2_valid;
wire  MEM_valid;
wire  WB_valid;

wire  preIF1_ready_go;
wire  preIF2_ready_go;
wire  IF_ready_go;
wire  ID_ready_go;
wire  EXE1_ready_go;
wire  EXE2_ready_go;
wire  MEM_ready_go;
wire  WB_ready_go;
//------------------------{5-stage pipeline control signals define}end-------------------------//

//------------------------{5-stage pipeline control signals assignment}begin-------------------------//
wire    ID_can_accept_IF;

assign  preIF1_allow_in     = !preIF1_valid || (preIF2_allow_in && preIF1_ready_go);
assign  preIF2_allow_in     = !preIF2_valid || (IF_allow_in && preIF2_ready_go);
assign  IF_allow_in         = !IF_valid || (ID_allow_in && IF_ready_go && ID_can_accept_IF);
assign  ID_allow_in         = !ID_valid || (EXE1_allow_in && ID_ready_go);
assign  EXE1_allow_in       = !EXE1_valid || (EXE2_allow_in && EXE1_ready_go);
assign  EXE2_allow_in       = !EXE2_valid || (MEM_allow_in && EXE2_ready_go);
assign  MEM_allow_in        = !MEM_valid || (WB_allow_in && MEM_ready_go);
assign  WB_allow_in         = !WB_valid || (WB_ready_go);

assign  valid_in            = 1'b1;
assign  preIF1_preIF2_valid = preIF1_valid & preIF1_ready_go;
assign  preIF2_IF_valid     = preIF2_valid & preIF2_ready_go;
assign  IF_ID_valid         = IF_valid & IF_ready_go;
assign  ID_EXE1_valid       = ID_valid & ID_ready_go;
assign  EXE1_EXE2_valid     = EXE1_valid & EXE1_ready_go & ~EXE1_need_cancel;
assign  EXE2_MEM_valid      = EXE2_valid & EXE2_ready_go;
assign  MEM_WB_valid        = MEM_valid & MEM_ready_go;
//------------------------{5-stage pipeline control signals assignment}end-------------------------//

//------------------------{regfile}begin-------------------------//
wire [4:0]  rf_raddr1[ISSUE - 1 : 0];
wire [4:0]  rf_raddr2[ISSUE - 1 : 0];
wire [4:0]  rf_waddr [ISSUE - 1 : 0];

wire [31:0] rf_rdata1[ISSUE - 1 : 0];
wire [31:0] rf_rdata2[ISSUE - 1 : 0];
wire [31:0] rf_wdata [ISSUE - 1 : 0];

wire        rf_we    [ISSUE - 1 : 0];

//regfile instantiation
regfile u_regfile(
    .clk    (clk       ),
    .resetn (resetn    ),
    .raddr1 (rf_raddr1 ),
    .rdata1 (rf_rdata1 ),
    .raddr2 (rf_raddr2 ),
    .rdata2 (rf_rdata2 ),
    .we     (rf_we     ),
    .waddr  (rf_waddr  ),
    .wdata  (rf_wdata  )
);
//------------------------{regfile}end-------------------------//

//------------------------{Stable counter}begin-------------------------//
reg [63:0] stable_counter;
always @ (posedge clk)begin
    if(!resetn)begin
        stable_counter <= 64'b0;
    end
    else begin
        stable_counter <= stable_counter+64'b1;
    end
end
//------------------------{Stable counter}end-------------------------//

//------------------------{DMW define}begin-------------------------//
wire [2:0] dmw_vseg0 [ISSUE-1:0];
wire       dmw_found0[ISSUE-1:0];
wire [2:0] dmw_pseg0 [ISSUE-1:0];
wire [2:0] dmw_vseg1 [ISSUE-1:0];
wire       dmw_found1[ISSUE-1:0];
wire [2:0] dmw_pseg1 [ISSUE-1:0];
//------------------------{DMW define}end-------------------------//

//------------------------{TLB}begin-------------------------//
wire [31:0] csr_TLBEHI;
wire [31:0] csr_TLBIDX;
wire [1:0]  csr_CRMD_PLV;

wire        tlbrd_we;
wire        tlbsrch_we;
wire        tlbwr_we;
wire        tlbfill_we;
reg  [3:0]  tlbfill_random;

// tlbfill random begin
always @(posedge clk) begin
    if (!resetn)
        tlbfill_random <= 4'b0001; // 初始值不为 0
    else if (tlbfill_we)
        tlbfill_random <= {tlbfill_random[2:0],
                           tlbfill_random[3] ^ tlbfill_random[2]};
end

// search port 0 (for fetch the inst)
wire   [18:0]               s0_vppn               [ISSUE-1:0];
wire                        s0_va_bit12           [ISSUE-1:0];
wire   [9:0]                s0_asid;
wire                        s0_found              [ISSUE-1:0];
wire   [$clog2(TLBNUM)-1:0] s0_index              [ISSUE-1:0]; // 实际使用的index位宽为log2(TLBNUM)
wire   [19:0]               s0_ppn                [ISSUE-1:0];
wire   [5:0]                s0_ps                 [ISSUE-1:0];
wire   [1:0]                s0_plv                [ISSUE-1:0];
wire   [1:0]                s0_mat                [ISSUE-1:0];
wire                        s0_d                  [ISSUE-1:0];
wire                        s0_v                  [ISSUE-1:0];

// search port 1 (for load/store the data)
wire   [18:0]               s1_vppn               [ISSUE-1:0];
wire                        s1_va_bit12           [ISSUE-1:0];
wire   [9:0]                s1_asid               [ISSUE-1:0];
wire   [9:0]                tlbinv_asid; // 标量，来自 EXE1 选出的 invtlb 槽
wire   [9:0]                s1_asid_without_invtlb;
wire                        s1_found              [ISSUE-1:0];
wire   [$clog2(TLBNUM)-1:0] s1_index              [ISSUE-1:0];
wire   [19:0]               s1_ppn                [ISSUE-1:0];
wire   [5:0]                s1_ps                 [ISSUE-1:0];
wire   [1:0]                s1_plv                [ISSUE-1:0];
wire   [1:0]                s1_mat                [ISSUE-1:0];
wire                        s1_d                  [ISSUE-1:0];
wire                        s1_v                  [ISSUE-1:0];

// invtlb opcode（标量）
wire                        invtlb_valid;
wire                        invtlb_None_ex;
wire                        invtlb_index;
wire   [4:0]                invtlb_op;

genvar                      s1_asid_i;
generate
    for(s1_asid_i = 0; s1_asid_i < ISSUE; s1_asid_i = s1_asid_i + 1) begin : gen_s1_asid
        // invtlb 当拍各 search 槽共用同一 ASID（同行无 mem）
        assign  s1_asid[s1_asid_i] = invtlb_None_ex ? tlbinv_asid : s1_asid_without_invtlb;
    end
endgenerate

// write port
wire                        we;
wire   [$clog2(TLBNUM)-1:0] w_index_from_csr;
wire   [$clog2(TLBNUM)-1:0] w_index;
wire                        w_e;
wire   [18:0]               w_vppn;
wire   [5:0]                w_ps;
wire   [9:0]                w_asid;
wire                        w_g;
wire   [19:0]               w_ppn0;
wire   [1:0]                w_plv0;
wire   [1:0]                w_mat0;
wire                        w_d0;
wire                        w_v0;
wire   [19:0]               w_ppn1;
wire   [1:0]                w_plv1;
wire   [1:0]                w_mat1;
wire                        w_d1;
wire                        w_v1;

assign                      we                   = tlbwr_we | tlbfill_we;
assign                      w_index              = tlbwr_we ? w_index_from_csr : tlbfill_we ? tlbfill_random : 4'h0;

// read port
wire   [$clog2(TLBNUM)-1:0] r_index;
wire                        r_e;
wire   [18:0]               r_vppn;
wire   [5:0]                r_ps;
wire   [9:0]                r_asid;
wire                        r_g;
wire   [19:0]               r_ppn0;
wire   [1:0]                r_plv0;
wire   [1:0]                r_mat0;
wire                        r_d0;
wire                        r_v0;
wire   [19:0]               r_ppn1;
wire   [1:0]                r_plv1;
wire   [1:0]                r_mat1;
wire                        r_d1;
wire                        r_v1;

//tlb_ex
wire                        ex_tlb_reload0      [ISSUE-1:0];//tlb重填异常
wire                        ex_tlb_reload1      [ISSUE-1:0];//tlb重填异常
wire                        ex_tlb_ld_unvalid   [ISSUE-1:0];//tlb的load页无效
wire                        ex_tlb_st_unvalid   [ISSUE-1:0];//tlb的store页无效
wire                        ex_tlb_preif_unvalid[ISSUE-1:0];//tlb取指页无效
wire                        ex_tlb_plv0         [ISSUE-1:0];//tlb的页权限上访
wire                        ex_tlb_plv1         [ISSUE-1:0];//tlb的页权限上访
wire                        ex_tlb_page_modify  [ISSUE-1:0];//tlb页修改

wire                        tlb_inst_req;
wire                        tlb_data_req        [ISSUE-1:0];
wire                        tlb_load_req        [ISSUE-1:0];
wire                        tlb_store_req       [ISSUE-1:0];

tlb #(
    .TLBNUM               (TLBNUM               ),
    .ISSUE                (ISSUE                )
) u_tlb(
    .clk                  (clk                  ),
    .resetn               (resetn               ),

    // search port 0 (for fetch the inst)
    .s0_vppn              (s0_vppn              ),
    .s0_va_bit12          (s0_va_bit12          ),
    .s0_asid              (s0_asid              ),
    .s0_found             (s0_found             ),
    .s0_index             (s0_index             ), // 实际使用的index位宽为log2(TLBNUM)
    .s0_ppn               (s0_ppn               ),
    .s0_ps                (s0_ps                ),
    .s0_plv               (s0_plv               ),
    .s0_mat               (s0_mat               ),
    .s0_d                 (s0_d                 ),
    .s0_v                 (s0_v                 ),

    // search port 1 (for load/store the data)
    .s1_vppn              (s1_vppn              ),
    .s1_va_bit12          (s1_va_bit12          ),
    .s1_asid              (s1_asid              ),
    .s1_found             (s1_found             ),
    .s1_index             (s1_index             ),
    .s1_ppn               (s1_ppn               ),
    .s1_ps                (s1_ps                ),
    .s1_plv               (s1_plv               ),
    .s1_mat               (s1_mat               ),
    .s1_d                 (s1_d                 ),
    .s1_v                 (s1_v                 ),

    // invtlb opcode
    .invtlb_valid         (invtlb_valid         ),
    .invtlb_index         (invtlb_index         ),
    .invtlb_op            (invtlb_op            ),
    
    // write port
    .we                   (we                   ),
    .w_index              (w_index              ),
    .w_e                  (w_e                  ),
    .w_vppn               (w_vppn               ),
    .w_ps                 (w_ps                 ),
    .w_asid               (w_asid               ),
    .w_g                  (w_g                  ),
    .w_ppn0               (w_ppn0               ),
    .w_plv0               (w_plv0               ),
    .w_mat0               (w_mat0               ),
    .w_d0                 (w_d0                 ),
    .w_v0                 (w_v0                 ),
    .w_ppn1               (w_ppn1               ),
    .w_plv1               (w_plv1               ),
    .w_mat1               (w_mat1               ),
    .w_d1                 (w_d1                 ),
    .w_v1                 (w_v1                 ),

    // read port
    .r_index              (r_index              ),
    .r_e                  (r_e                  ),
    .r_vppn               (r_vppn               ),
    .r_ps                 (r_ps                 ),
    .r_asid               (r_asid               ),
    .r_g                  (r_g                  ),
    .r_ppn0               (r_ppn0               ),
    .r_plv0               (r_plv0               ),
    .r_mat0               (r_mat0               ),
    .r_d0                 (r_d0                 ),
    .r_v0                 (r_v0                 ),
    .r_ppn1               (r_ppn1               ),
    .r_plv1               (r_plv1               ),
    .r_mat1               (r_mat1               ),
    .r_d1                 (r_d1                 ),
    .r_v1                 (r_v1                 ),
    .csr_CRMD_PLV         (csr_CRMD_PLV         ),

    //tlb_ex
    .ex_tlb_reload0       (ex_tlb_reload0       ),//tlb重填异常
    .ex_tlb_reload1       (ex_tlb_reload1       ),//tlb重填异常
    .ex_tlb_ld_unvalid    (ex_tlb_ld_unvalid    ),//tlb的load页无效
    .ex_tlb_st_unvalid    (ex_tlb_st_unvalid    ),//tlb的store页无效
    .ex_tlb_preif_unvalid (ex_tlb_preif_unvalid ),//tlb取指页无效
    .ex_tlb_plv0          (ex_tlb_plv0          ),//tlb的页权限上访
    .ex_tlb_plv1          (ex_tlb_plv1          ),//tlb的页权限上访
    .ex_tlb_page_modify   (ex_tlb_page_modify   ),//tlb页修改
    .tlb_inst_req         (tlb_inst_req         ),
    .tlb_data_req         (tlb_data_req         ),
    .tlb_load_req         (tlb_load_req         ),
    .tlb_store_req        (tlb_store_req        ),

    //DWM
    .dmw_found0           (dmw_found0           ),
    .dmw_found1           (dmw_found1           )
);
//------------------------{TLB}end-------------------------//

//------------------------{csr_ex_front}begin-------------------------//
wire    EXE2_ex;
wire    MEM_ex;
wire    WB_ex;

wire    older_ex_for_exe1;
wire    older_ex_for_exe2;
wire    older_ex_for_mem;
assign  older_ex_for_exe1 = EXE2_ex | MEM_ex | WB_ex;
assign  older_ex_for_exe2 = MEM_ex | WB_ex;
assign  older_ex_for_mem  = WB_ex;
//------------------------{csr_ex_front}end-------------------------//

//------------------------{cacop}begin-------------------------//
wire   [31:0] inst_sram_addr_without_cacop;
assign        inst_sram_addr               = (cacop_valid && cache_code[2:0] == 3'b0) ? data_sram_addr : inst_sram_addr_without_cacop;
// cacop_need_cancel当出现了要清除 icache 的时候说明从 preIF1->EXE1 拿到的指令都是不可信的，需要重取
// 和 ibar 这种纯血 cancel 不同，他不应该取消 exe2
reg           cacop_need_cancel;
always @(posedge clk)begin
    if(!resetn)begin
        cacop_need_cancel <= 1'b0;
    end
    else if(flush | older_ex_for_exe2)begin
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

//------------------------{front_push}begin-------------------------//
wire          flush;
wire   [31:0] flush_target;
wire   [31:0] cancel_target;//cacop flush br 融合 target

wire   [31:0] front_push_rdata1      [ISSUE - 1 : 0];
wire   [31:0] front_push_rdata2      [ISSUE - 1 : 0];
reg    [31:0] front_push_br_rdata1   [ISSUE - 1 : 0];
reg    [31:0] front_push_br_rdata2   [ISSUE - 1 : 0];// 是为了always * case选择，不是为了打拍


wire   [31:0] exe2_front_data        [ISSUE - 1 : 0];
wire   [31:0] mem_front_data         [ISSUE - 1 : 0];
wire   [31:0] mem_front_data_nonld   [ISSUE - 1 : 0];
wire          wb_front_valid         [ISSUE - 1 : 0];
wire   [31:0] wb_front_data          [ISSUE - 1 : 0];
wire   [ 4:0] exe2_front_addr        [ISSUE - 1 : 0];
wire   [ 4:0] mem_front_addr         [ISSUE - 1 : 0];
wire   [ 4:0] wb_front_addr          [ISSUE - 1 : 0];
wire          exe2_can_not_front_push[ISSUE - 1 : 0];
wire          mem_can_not_front_push [ISSUE - 1 : 0];
wire          wb_can_not_front_push  [ISSUE - 1 : 0];

genvar        i;

//【优·EXP8B-HIER：branch forwarding 先在各流水级内缩减 slot，再在流水级间选择】
// stage match[1:0] = {slot0, slot1}
wire   [1:0]  exe2_br_match_rdata1   [ISSUE-1:0];
wire   [1:0]  mem_br_match_rdata1    [ISSUE-1:0];
wire   [1:0]  wb_br_match_rdata1     [ISSUE-1:0];
wire          exe2_br_hit_rdata1     [ISSUE-1:0];
wire          mem_br_hit_rdata1      [ISSUE-1:0];
wire          wb_br_hit_rdata1       [ISSUE-1:0];
wire   [31:0] exe2_br_data_rdata1    [ISSUE-1:0];
wire   [31:0] mem_br_data_rdata1     [ISSUE-1:0];
wire   [31:0] wb_br_data_rdata1      [ISSUE-1:0];

wire   [1:0]  exe2_br_match_rdata2   [ISSUE-1:0];
wire   [1:0]  mem_br_match_rdata2    [ISSUE-1:0];
wire   [1:0]  wb_br_match_rdata2     [ISSUE-1:0];
wire          exe2_br_hit_rdata2     [ISSUE-1:0];
wire          mem_br_hit_rdata2      [ISSUE-1:0];
wire          wb_br_hit_rdata2       [ISSUE-1:0];
wire   [31:0] exe2_br_data_rdata2    [ISSUE-1:0];
wire   [31:0] mem_br_data_rdata2     [ISSUE-1:0];
wire   [31:0] wb_br_data_rdata2      [ISSUE-1:0];

generate
    for (i = 0; i < ISSUE; i = i + 1) begin : gen_front_push
        // 给br的都不是从dcache来的ld拿回来的
        // 专门给br开了一个wb可以前递的

        assign  exe2_br_match_rdata1[i] = {
                                                   EXE2_valid & ~exe2_can_not_front_push[0] & (exe2_front_addr[0] == rf_raddr1[i]),
                                                   EXE2_valid & ~exe2_can_not_front_push[1] & (exe2_front_addr[1] == rf_raddr1[i])
                                          };
        assign  mem_br_match_rdata1[i]  = {
                                                   MEM_valid & ~mem_can_not_front_push[0] & ~mem_need_stall_inst[0] & (mem_front_addr[0] == rf_raddr1[i]),
                                                   MEM_valid & ~mem_can_not_front_push[1] & ~mem_need_stall_inst[1] & (mem_front_addr[1] == rf_raddr1[i])
                                           };
        assign  wb_br_match_rdata1[i]   = {
                                                   WB_valid & wb_front_valid[0] & (wb_front_addr[0] == rf_raddr1[i]),
                                                   WB_valid & wb_front_valid[1] & (wb_front_addr[1] == rf_raddr1[i])
                                          };

        assign  exe2_br_match_rdata2[i] = {
                                                   EXE2_valid & ~exe2_can_not_front_push[0] & (exe2_front_addr[0] == rf_raddr2[i]),
                                                   EXE2_valid & ~exe2_can_not_front_push[1] & (exe2_front_addr[1] == rf_raddr2[i])
                                          };
        assign  mem_br_match_rdata2[i]  = {
                                                   MEM_valid & ~mem_can_not_front_push[0] & ~mem_need_stall_inst[0] & (mem_front_addr[0] == rf_raddr2[i]),
                                                   MEM_valid & ~mem_can_not_front_push[1] & ~mem_need_stall_inst[1] & (mem_front_addr[1] == rf_raddr2[i])
                                          };
        assign  wb_br_match_rdata2[i]   = {
                                                   WB_valid & wb_front_valid[0] & (wb_front_addr[0] == rf_raddr2[i]),
                                                   WB_valid & wb_front_valid[1] & (wb_front_addr[1] == rf_raddr2[i])
                                          };

        assign  exe2_br_hit_rdata1[i]  = |exe2_br_match_rdata1[i];
        assign  mem_br_hit_rdata1[i]   = |mem_br_match_rdata1[i];
        assign  wb_br_hit_rdata1[i]    = |wb_br_match_rdata1[i];
        assign  exe2_br_data_rdata1[i] = exe2_br_match_rdata1[i][1] ? exe2_front_data[0]      : exe2_front_data[1];
        assign  mem_br_data_rdata1[i]  = mem_br_match_rdata1[i][1]  ? mem_front_data_nonld[0] : mem_front_data_nonld[1];
        assign  wb_br_data_rdata1[i]   = wb_br_match_rdata1[i][1]   ? wb_front_data[0]        : wb_front_data[1];

        assign  exe2_br_hit_rdata2[i]  = |exe2_br_match_rdata2[i];
        assign  mem_br_hit_rdata2[i]   = |mem_br_match_rdata2[i];
        assign  wb_br_hit_rdata2[i]    = |wb_br_match_rdata2[i];
        assign  exe2_br_data_rdata2[i] = exe2_br_match_rdata2[i][1] ? exe2_front_data[0]      : exe2_front_data[1];
        assign  mem_br_data_rdata2[i]  = mem_br_match_rdata2[i][1]  ? mem_front_data_nonld[0] : mem_front_data_nonld[1];
        assign  wb_br_data_rdata2[i]   = wb_br_match_rdata2[i][1]   ? wb_front_data[0]        : wb_front_data[1];

        always @(*) begin
            if (rf_raddr1[i] == 5'd0) begin
                front_push_br_rdata1[i] = 32'd0;
            end
            else begin
                casez ({exe2_br_hit_rdata1[i], mem_br_hit_rdata1[i], wb_br_hit_rdata1[i]})
                    3'b1??:  front_push_br_rdata1[i] = exe2_br_data_rdata1[i];
                    3'b01?:  front_push_br_rdata1[i] = mem_br_data_rdata1[i];
                    3'b001:  front_push_br_rdata1[i] = wb_br_data_rdata1[i];
                    default: front_push_br_rdata1[i] = rf_rdata1[i];
                endcase
            end
        end
        always @(*) begin
            if (rf_raddr2[i] == 5'd0) begin
                front_push_br_rdata2[i] = 32'd0;
            end
            else begin
                casez ({exe2_br_hit_rdata2[i], mem_br_hit_rdata2[i], wb_br_hit_rdata2[i]})
                    3'b1??:  front_push_br_rdata2[i] = exe2_br_data_rdata2[i];
                    3'b01?:  front_push_br_rdata2[i] = mem_br_data_rdata2[i];
                    3'b001:  front_push_br_rdata2[i] = wb_br_data_rdata2[i];
                    default: front_push_br_rdata2[i] = rf_rdata2[i];
                endcase
            end
        end


        // 普通路径：CSR producer 已在注册的 wb_front_valid 中排除
        assign  front_push_rdata1[i] =
                                       (rf_raddr1[i] == 5'b0) ? 32'b0 :
                                       (EXE2_valid & ~exe2_can_not_front_push[0] & (exe2_front_addr[0] == rf_raddr1[i])) ? exe2_front_data[0] :
                                       (EXE2_valid & ~exe2_can_not_front_push[1] & (exe2_front_addr[1] == rf_raddr1[i])) ? exe2_front_data[1] :
                                       (MEM_valid  & ~mem_can_not_front_push[0]  & (mem_front_addr[0]  == rf_raddr1[i])) ? mem_front_data[0]  :
                                       (MEM_valid  & ~mem_can_not_front_push[1]  & (mem_front_addr[1]  == rf_raddr1[i])) ? mem_front_data[1]  :
                                       (WB_valid & wb_front_valid[0] & (wb_front_addr[0] == rf_raddr1[i])) ? wb_front_data[0] :
                                       (WB_valid & wb_front_valid[1] & (wb_front_addr[1] == rf_raddr1[i])) ? wb_front_data[1] :
                                       rf_rdata1[i];
        assign  front_push_rdata2[i] =
                                       (rf_raddr2[i] == 5'b0) ? 32'b0 :
                                       (EXE2_valid & ~exe2_can_not_front_push[0] & (exe2_front_addr[0] == rf_raddr2[i])) ? exe2_front_data[0] :
                                       (EXE2_valid & ~exe2_can_not_front_push[1] & (exe2_front_addr[1] == rf_raddr2[i])) ? exe2_front_data[1] :
                                       (MEM_valid  & ~mem_can_not_front_push[0]  & (mem_front_addr[0]  == rf_raddr2[i])) ? mem_front_data[0]  :
                                       (MEM_valid  & ~mem_can_not_front_push[1]  & (mem_front_addr[1]  == rf_raddr2[i])) ? mem_front_data[1]  :
                                       (WB_valid & wb_front_valid[0] & (wb_front_addr[0] == rf_raddr2[i])) ? wb_front_data[0] :
                                       (WB_valid & wb_front_valid[1] & (wb_front_addr[1] == rf_raddr2[i])) ? wb_front_data[1] :
                                       rf_rdata2[i];
    end
endgenerate 
//ibar也在EXE2 所以可以直接赋值cacop_pc
assign  cancel_target = flush             ? flush_target :
                        ibar_cancel       ? idbar_pc     :
                        cacop_need_cancel ? cacop_pc     : 
                        br_taken          ? br_target    : flush_target;
//------------------------{front_push}end-------------------------//

//------------------------{stall}begin-------------------------//
wire  br_use_rj  [ISSUE - 1 : 0];
wire  br_use_rk  [ISSUE - 1 : 0];
wire  mem_load_we[ISSUE-1:0];
wire  rj_same_ld [ISSUE-1:0];
wire  rk_same_ld [ISSUE-1:0];
generate
    for (i = 0; i < ISSUE; i = i + 1) begin : mem_ID_stall_same_ld
        assign  mem_load_we[i] = MEM_valid & mem_need_stall_inst[i] & ~mem_can_not_front_push[i]
                                           & (MEM_rf_dest[i] != 5'd0);
        assign  rj_same_ld[i]  = ID_valid & br_use_rj[i] & (rf_raddr1[i] != 5'd0) &
                                 ( (mem_load_we[0] & (rf_raddr1[i] == MEM_rf_dest[0]))
                                 | (mem_load_we[1] & (rf_raddr1[i] == MEM_rf_dest[1])) );
        assign  rk_same_ld[i]  = ID_valid & br_use_rk[i] & (rf_raddr2[i] != 5'd0) &
                                 ( (mem_load_we[0] & (rf_raddr2[i] == MEM_rf_dest[0]))
                                 | (mem_load_we[1] & (rf_raddr2[i] == MEM_rf_dest[1])) );
    end
endgenerate


wire        EXE1_rf_gr_we       [ISSUE - 1 : 0];
wire [ 4:0] EXE1_rf_dest        [ISSUE - 1 : 0];
wire        EXE1_can_front    [ISSUE - 1 : 0];
wire [ 4:0] EXE2_rf_dest        [ISSUE - 1 : 0];
wire [ 4:0] MEM_rf_dest         [ISSUE - 1 : 0];
wire [ 4:0] WB_rf_dest          [ISSUE - 1 : 0];
wire        src1_stall          [ISSUE - 1 : 0];
wire        src2_stall          [ISSUE - 1 : 0];
wire        need_stall;
wire        exe2_need_stall_inst[ISSUE - 1 : 0];
wire        exe2_need_stall_csr [ISSUE - 1 : 0];
wire        mem_need_stall_inst [ISSUE - 1 : 0];
wire        mem_need_stall_csr  [ISSUE - 1 : 0];
wire        wb_need_stall_csr   [ISSUE - 1 : 0];
wire        mem_load_wait       [ISSUE - 1 : 0];

// =========================  decode 先发起请求，然后进入exe1再进行替换  ==========================
wire        ID_need_alu1_rj    [ISSUE - 1 : 0];
wire        ID_need_src2_withST    [ISSUE - 1 : 0];
wire        ID_need_alu2_rk [ISSUE - 1 : 0];
wire [ 1:0] src1_capture_sel    [ISSUE - 1 : 0];
wire [ 1:0] src2_capture_sel    [ISSUE - 1 : 0];
// 和前面front_push的match格式一致：[1:0] = {slot0, slot1}
wire [ 1:0] exe1_capture_match_rdata1[ISSUE - 1 : 0];
wire [ 1:0] exe1_capture_match_rdata2[ISSUE - 1 : 0];
wire        src1_capture_valid  [ISSUE - 1 : 0];
wire        src2_capture_valid  [ISSUE - 1 : 0];

generate
    for(i=0;i<ISSUE;i=i+1)begin:gen_ID_EXE1_similar_front
        // 也就是exe1的dest刚好是decode的src的match
        //1. decode有两个slot
        //2. 一个有两个src
        //3. 一个src需要与exe1中两个slot计算出来的对比
        assign  exe1_capture_match_rdata1[i] = {
                    (rf_raddr1[i] != 5'd0) && ID_valid && EXE1_valid && EXE1_rf_gr_we[0] &&
                    (rf_raddr1[i] == EXE1_rf_dest[0]),//slot0
                    (rf_raddr1[i] != 5'd0) && ID_valid && EXE1_valid && EXE1_rf_gr_we[1] &&
                    (rf_raddr1[i] == EXE1_rf_dest[1])//slot1
                };
        assign  exe1_capture_match_rdata2[i] = {
                    (rf_raddr2[i] != 5'd0) && ID_valid && EXE1_valid && EXE1_rf_gr_we[0] &&
                    (rf_raddr2[i] == EXE1_rf_dest[0]),
                    (rf_raddr2[i] != 5'd0) && ID_valid && EXE1_valid && EXE1_rf_gr_we[1] &&
                    (rf_raddr2[i] == EXE1_rf_dest[1])
                };

        // 正常issue不会让两个EXE1 lane同时写同一个寄存器
        // 这里仍写完整：两个都命中时必须两个都能capture，并优先更年轻的lane1
        assign  src1_capture_valid[i] = ID_need_alu1_rj[i] & EXE1_allow_in &
                                        ~EXE1_need_cancel &
                                        // 匹配成功 & 对应槽可以前递
                                        (|exe1_capture_match_rdata1[i]) &
                                        (~exe1_capture_match_rdata1[i][1] | EXE1_can_front[0]) &
                                        (~exe1_capture_match_rdata1[i][0] | EXE1_can_front[1]);
        assign  src2_capture_valid[i] = ID_need_src2_withST[i] & EXE1_allow_in &
                                        ~EXE1_need_cancel &
                                        (|exe1_capture_match_rdata2[i]) &
                                        (~exe1_capture_match_rdata2[i][1] | EXE1_can_front[0]) &
                                        (~exe1_capture_match_rdata2[i][0] | EXE1_can_front[1]);
        // slot0 : 10 
        // slot1 : 01
        assign  src1_capture_sel[i] = ~src1_capture_valid[i]             ? 2'b00 :
                                       exe1_capture_match_rdata1[i][0]   ? 2'b10 : 2'b01;
        assign  src2_capture_sel[i] = ~src2_capture_valid[i]             ? 2'b00 :
                                       exe1_capture_match_rdata2[i][0]   ? 2'b10 : 2'b01;
    end
endgenerate
        
// =========================  decode 先发起请求，然后进入exe1再进行替换  ==========================


generate
    for (i = 0; i < ISSUE; i = i + 1) begin : gen_stall
        assign  mem_load_wait[i] = mem_need_stall_inst[i] & ~data_sram_data_ok;
        assign  src1_stall[i]    =
                                   (rf_raddr1[i] != 5'd0) && ID_valid &&
                                   ~src1_capture_valid[i] &&//无法exe1类前递就要stall
                                   ((|exe1_capture_match_rdata1[i]) ||
                                   ((rf_raddr1[i] == EXE2_rf_dest[0]) && EXE2_valid && (exe2_need_stall_inst[0] || exe2_need_stall_csr[0])) ||
                                   ((rf_raddr1[i] == EXE2_rf_dest[1]) && EXE2_valid && (exe2_need_stall_inst[1] || exe2_need_stall_csr[1])) ||
                                   ((rf_raddr1[i] == MEM_rf_dest[0])  && MEM_valid  && (mem_load_wait[0] || mem_need_stall_csr[0])) ||
                                   ((rf_raddr1[i] == MEM_rf_dest[1])  && MEM_valid  && (mem_load_wait[1] || mem_need_stall_csr[1])) ||
                                   ((rf_raddr1[i] == WB_rf_dest[0])   && WB_valid   && !flush & ~wb_can_not_front_push[0] && wb_need_stall_csr[0]) ||
                                   ((rf_raddr1[i] == WB_rf_dest[1])   && WB_valid   && !flush & ~wb_can_not_front_push[1] && wb_need_stall_csr[1]));
        assign  src2_stall[i]    =
                                   (rf_raddr2[i] != 5'd0) && ID_valid &&
                                   ~src2_capture_valid[i] &&
                                   ((|exe1_capture_match_rdata2[i]) ||
                                   ((rf_raddr2[i] == EXE2_rf_dest[0]) && EXE2_valid && (exe2_need_stall_inst[0] || exe2_need_stall_csr[0])) ||
                                   ((rf_raddr2[i] == EXE2_rf_dest[1]) && EXE2_valid && (exe2_need_stall_inst[1] || exe2_need_stall_csr[1])) ||
                                   ((rf_raddr2[i] == MEM_rf_dest[0])  && MEM_valid  && (mem_load_wait[0] || mem_need_stall_csr[0])) ||
                                   ((rf_raddr2[i] == MEM_rf_dest[1])  && MEM_valid  && (mem_load_wait[1] || mem_need_stall_csr[1])) ||
                                   ((rf_raddr2[i] == WB_rf_dest[0])   && WB_valid   && !flush & ~wb_can_not_front_push[0] && wb_need_stall_csr[0]) ||
                                   ((rf_raddr2[i] == WB_rf_dest[1])   && WB_valid   && !flush & ~wb_can_not_front_push[1] && wb_need_stall_csr[1]));
    end
endgenerate

assign  need_stall        = src1_stall[0] | src1_stall[1] | src2_stall[0] | src2_stall[1] |
                            rj_same_ld[0] | rj_same_ld[1] | rk_same_ld[0] | rk_same_ld[1];// 给br的都不是从dcache来的ld拿回来的，如果冲突就需要阻塞

wire    IDLE_stall;
reg     preIF1_IDLE_stall;
always @(posedge clk)begin
    if(!resetn)begin
        preIF1_IDLE_stall <= 1'b0;
    end
    else if (has_int)begin
        preIF1_IDLE_stall <= 1'b0;
    end
    else if (IDLE_stall)begin
        preIF1_IDLE_stall <= 1'b1;
    end
end
// 本拍 IDLE_stall 也要挡住取指，不能等寄存器晚一拍
wire  preIF1_idle_block = preIF1_IDLE_stall | IDLE_stall;
//------------------------{stall}end-------------------------//

//------------------------{req_to_dataok_trigger}begin-------------------------//
wire  req_to_dataok_trigger;
wire  inst_resp_discard;
//------------------------{req_to_dataok_trigger}end-------------------------//

//------------------------{branch prediction}begin---------------------------//
//btb
// query port: preIF lookup
wire        query_valid     [ISSUE-1:0];
wire [31:0] query_pc        [ISSUE-1:0];
wire        btb_query_hit   [ISSUE-1:0];//valid and tag match
wire [31:0] btb_query_target[ISSUE-1:0];
wire [ 1:0] query_type      [ISSUE-1:0];
// update port: Decode writes back real result
wire        update_valid;
wire [31:0] update_pc;
wire [31:0] update_target;//real target
wire [ 1:0] update_type;
btb u_btb(
    .clk           (clk                       ),
    .resetn        (resetn                    ),
    // query port: preIF lookup
    .query_valid0  (query_valid[0]            ),
    .query_pc0     (query_pc[0]               ),
    .query_hit0    (btb_query_hit[0]          ),//valid and tag match
    .query_target0 (btb_query_target[0]       ),
    .query_type0   (query_type[0]             ),

    .query_valid1  (query_valid[1]            ),
    .query_pc1     (query_pc[1]               ),
    .query_hit1    (btb_query_hit[1]          ),//valid and tag match
    .query_target1 (btb_query_target[1]       ),
    .query_type1   (query_type[1]             ),
    // update port: Decode writes back real result
    .update_valid  (update_valid              ),
    .update_pc     (update_pc                 ),
    .update_target (update_target             ),//real target
    .update_type   (update_type               ),
    //取消取指和错误预测
    .update_cancel (flush | cacop_need_cancel )
);

wire        query_taken     [ISSUE-1:0];
wire        update_taken;
wire        bht_update_valid;
wire [31:0] bht_update_pc;
wire        bht_update_taken;
//bht
bht u_bht(
    .clk           (clk                       ),
    .resetn        (resetn                    ),
    // query port
    .query_valid0  (query_valid[0]            ),
    .query_pc0     (query_pc[0]               ),//pc being predicted
    .query_taken0  (query_taken[0]            ),//predict taken

    .query_valid1  (query_valid[1]            ),
    .query_pc1     (query_pc[1]               ),//pc being predicted
    .query_taken1  (query_taken[1]            ),//predict taken
    // update port
    .update_valid  (bht_update_valid          ),//update BHT
    .update_pc     (bht_update_pc             ),//branch pc
    .update_taken  (bht_update_taken          ),//real taken
    .update_cancel (flush | cacop_need_cancel )//取消取指和错误预测
);

//ras
wire        push_valid;
wire [31:0] push_target;
wire        pop_valid;
wire        ras_query_hit   [ISSUE-1:0];
wire [31:0] ras_query_target[ISSUE-1:0];
ras u_ras(
    .clk           (clk                 ),
    .resetn        (resetn              ),
    // frontend query
    .query_valid0  (query_valid[0]      ),
    .query_hit0    (ras_query_hit[0]    ),
    .query_target0 (ras_query_target[0] ),

    .query_valid1  (query_valid[1]      ),
    .query_hit1    (ras_query_hit[1]    ),
    .query_target1 (ras_query_target[1] ),
    // backend real call update
    .push_valid    (push_valid          ),
    .push_target   (push_target         ),
    // backend real return update
    .pop_valid     (pop_valid           )
);
//------------------------{branch prediction}end---------------------------//

//------------------------{预测输出与跳转信号处理}begin-------------------------//
wire        br_taken;
wire [31:0] br_target;

wire        br_afterpred_taken;
wire [31:0] br_afterpred_target;

reg         br_afterpred_taken_r;
reg  [31:0] br_afterpred_target_r;

// this is the br inst need to cancel the preIF IF ID
wire        need_br_cancel;

//cacop cancel
wire [31:0] cacop_pc;
//[NOTICE:学一下]CE出口寄存器 <= 选通,WNS会好一些
always @(posedge clk) begin
    if (!resetn) begin
        br_afterpred_taken_r  <= 1'b0;
        br_afterpred_target_r <= 32'b0;
    end
    else begin
        br_afterpred_taken_r  <= (flush || cacop_need_cancel) ? 1'b0
                                 : br_afterpred_taken;

        br_afterpred_target_r <= br_afterpred_target;
    end
end

assign  br_taken       = br_afterpred_taken_r;
assign  br_target      = br_afterpred_target_r;
assign  need_br_cancel = br_afterpred_taken_r;
//------------------------{预测输出与跳转信号处理}end-------------------------//

//------------------------{i/dbar need cancel}begins-------------------------//
wire          ibar_cancel;
wire          dbar_cancel;
wire   [31:0] idbar_pc;

wire          preIF_IF_ID_need_cancel;
wire          EXE1_need_cancel;
wire          EXE2_need_cancel;
wire          MEM_need_cancel;
wire          WB_need_cancel;

assign        preIF_IF_ID_need_cancel = flush | need_br_cancel    | cacop_need_cancel | ibar_cancel;
assign        EXE1_need_cancel        = flush | ibar_cancel       | cacop_need_cancel;
// cacop_need_cancel当出现了要清除 icache 的时候说明从 preIF1->EXE1 拿到的指令都是不可信的，需要重取
// 和 ibar 这种纯血 cancel 不同，他不应该取消 exe2
assign        EXE2_need_cancel        = flush | ibar_cancel;
assign        MEM_need_cancel         = flush;
assign        WB_need_cancel          = flush;
//------------------------{i/dbar need cancel}end-------------------------//

//------------------------{5 pipeline bus + inst ram control}begin-------------------------//
localparam                                     preIF1_preIF2_slot0_bus_width = 144;
localparam                                     preIF1_preIF2_bus_width       = 142;
localparam                                     preIF2_IF_bus_width           = 106;
localparam                                     IF_ID_bus_width               = 148;
localparam                                     ID_EXE1_bus_width             = 244; // +1: slot_valid
localparam                                     EXE1_EXE2_bus_width           = 279; // +1: EXE1_ex
localparam                                     EXE2_MEM_bus_width            = 199;
localparam                                     MEM_WB_bus_width              = 223;

wire       [preIF1_preIF2_slot0_bus_width-1:0] preIF1_preIF2_bus_slot0;
wire       [preIF1_preIF2_bus_width-1:0]       preIF1_preIF2_bus            [ISSUE-1:1];
wire       [preIF2_IF_bus_width-1:0]           preIF2_IF_bus                [ISSUE-1:0];
wire       [IF_ID_bus_width-1:0]               IF_ID_bus                    [ISSUE-1:0];
wire       [ID_EXE1_bus_width-1:0]             ID_EXE1_bus                  [ISSUE-1:0];
wire       [EXE1_EXE2_bus_width-1:0]           EXE1_EXE2_bus                [ISSUE-1:0];
wire       [EXE2_MEM_bus_width-1:0]            EXE2_MEM_bus                 [ISSUE-1:0];
wire       [MEM_WB_bus_width-1:0]              MEM_WB_bus                   [ISSUE-1:0];
//------------------------{5-stage pipeline bus + inst ram control}end------------------------//

//------------------------{csr_regfile}begin-------------------------//
wire   [13:0] csr_num;
wire   [31:0] csr_rvalue;
wire          csr_we;
wire   [31:0] csr_wdata;

wire   [31:0] csr_wmask;
wire          csr_re;
wire          wb_ex;
wire          ipi_int_in;
wire   [31:0] wb_pc;
wire   [31:0] wb_vaddr;
wire   [5:0]  wb_ecode;
wire   [8:0]  wb_esubcode;
assign        debug_commit_ecode    = wb_ecode;
assign        debug_commit_esubcode = wb_esubcode;
wire          has_int;
wire          csr_tcfg_init0;
wire          csr_CRMD_DA;
wire          csr_CRMD_PG;
//tlbreload 重填传入CSR
wire          ex_tlb_reload;

//ERTN 更改 CRMD
wire          ertn_valid;
// 更新BADV
wire          csr_tlb_reload0;
wire          csr_tlb_plv0;
wire          csr_tlb_reload1; 
wire          csr_tlb_plv1;     
// 更新TLBEHI ex_tlb
wire          ex_tlb;
//mat:存储访问类型
wire   [1:0]  csr_CRMD_DATF;
wire   [1:0]  csr_CRMD_DATM;
wire   [1:0]  dmw_mat0             [ISSUE-1:0];
wire   [1:0]  dmw_mat1             [ISSUE-1:0];
//mat
wire   [1:0]  inst_mat;
wire   [1:0]  data_mat;

//LLbit
wire          LLbit_wb;
wire          LLbit_wdata;
wire          LLbit;

assign        ipi_int_in            = 1'h0;


//----------------Icache 相关信号-----------
assign  inst_uncache_valid = (inst_mat == 2'b00);
assign  inst_uncache_wr    = inst_wr;
//---------------------------------------------

//----------------Dcache 相关信号-----------
assign  data_uncache_valid = (data_mat == 2'b00);
assign  data_uncache_wr    = data_wr;
//---------------------------------------------

csr_regfile #(
    .TLBNUM                 (TLBNUM                 ),
    .ISSUE                  (ISSUE                  )
)u_csr_regfile (
    .clk                    (clk                    ),
    .resetn                 (resetn                 ),
    .csr_num                (csr_num                ),
    .csr_we                 (csr_we                 ),
    .csr_wmask              (csr_wmask              ),
    .csr_wvalue             (csr_wdata              ),
    .csr_re                 (csr_re                 ),
    .csr_rvalue             (csr_rvalue             ),
    .wb_ex                  (wb_ex                  ),
    .wb_ecode               (wb_ecode               ),
    .wb_esubcode            (wb_esubcode            ),
    .hw_int_in              (hw_int_in              ),
    .ipi_int_in             (ipi_int_in             ),
    .wb_pc                  (wb_pc                  ),
    .wb_vaddr               (wb_vaddr               ),
    .has_int                (has_int                ),
    .csr_tcfg_init0         (csr_tcfg_init0         ),
    .coreid_in              (32'b0                  ),
    //TLB与csr接口
    .csr_TLBEHI             (csr_TLBEHI             ),
    .csr_TLBIDX             (csr_TLBIDX             ),
    .csr_CRMD_PLV           (csr_CRMD_PLV           ),
    //tlbrd读 read port,写csr
    .r_index                (r_index                ),
    .s0_asid                (s0_asid                ),
    .s1_asid_without_invtlb (s1_asid_without_invtlb ),
    .r_e                    (r_e                    ),
    .r_vppn                 (r_vppn                 ),
    .r_ps                   (r_ps                   ),
    .r_asid                 (r_asid                 ),
    .r_g                    (r_g                    ),
    .r_ppn0                 (r_ppn0                 ),
    .r_plv0                 (r_plv0                 ),
    .r_mat0                 (r_mat0                 ),
    .r_d0                   (r_d0                   ),
    .r_v0                   (r_v0                   ),
    .r_ppn1                 (r_ppn1                 ),
    .r_plv1                 (r_plv1                 ),
    .r_mat1                 (r_mat1                 ),
    .r_d1                   (r_d1                   ),
    .r_v1                   (r_v1                   ),
    // write port [csr-tlb]
    .w_index                (w_index_from_csr       ),
    .w_e                    (w_e                    ),
    .w_vppn                 (w_vppn                 ),
    .w_ps                   (w_ps                   ),
    .w_asid                 (w_asid                 ),
    .w_g                    (w_g                    ),
    .w_ppn0                 (w_ppn0                 ),
    .w_plv0                 (w_plv0                 ),
    .w_mat0                 (w_mat0                 ),
    .w_d0                   (w_d0                   ),
    .w_v0                   (w_v0                   ),
    .w_ppn1                 (w_ppn1                 ),
    .w_plv1                 (w_plv1                 ),
    .w_mat1                 (w_mat1                 ),
    .w_d1                   (w_d1                   ),
    .w_v1                   (w_v1                   ),
    //rlbrd
    .tlbrd_we               (tlbrd_we               ),
    .csr_CRMD_DA            (csr_CRMD_DA            ),
    .csr_CRMD_PG            (csr_CRMD_PG            ),
    //tlbreload 重填传入CSR
    .ex_tlb_reload          (ex_tlb_reload          ),
    //DMW
    .dmw_vseg0              (dmw_vseg0              ),
    .dmw_found0             (dmw_found0             ),
    .dmw_pseg0              (dmw_pseg0              ),
    .dmw_vseg1              (dmw_vseg1              ),
    .dmw_found1             (dmw_found1             ),
    .dmw_pseg1              (dmw_pseg1              ),
    //ERTN 更改 CRMD
    .ertn_valid             (ertn_valid             ),
    // 更新BADV
    .csr_tlb_reload0        (csr_tlb_reload0        ),
    .csr_tlb_plv0           (csr_tlb_plv0           ),
    .csr_tlb_reload1        (csr_tlb_reload1        ),  
    .csr_tlb_plv1           (csr_tlb_plv1           ),
    //ex_tlb TLBEHI
    .ex_tlb                 (ex_tlb                 ),
    //mat:存储访问类型
    .csr_CRMD_DATF          (csr_CRMD_DATF          ),
    .csr_CRMD_DATM          (csr_CRMD_DATM          ),
    .dmw_mat0               (dmw_mat0               ),
    .dmw_mat1               (dmw_mat1               ),
    //LLbit
    .LLbit_wb               (LLbit_wb               ),
    .LLbit_wdata            (LLbit_wdata            ),
    .LLbit                  (LLbit                  )
);
//------------------------{csr_regfile}end-------------------------//

//------------------------{5-stage pipeline instantiation}begin-------------------------//
pre_IF1 #(
    .slot0_outbus_width      (preIF1_preIF2_slot0_bus_width ),
    .outbus_width            (preIF1_preIF2_bus_width       ),
    .ISSUE                   (ISSUE                         )
) u_pre_IF1
(
    .clk                     (clk                           ),
    .resetn                  (resetn                        ),
    //control signal
    .valid_in                (valid_in                      ),
    .preIF1_allow_in         (preIF1_allow_in               ),
    .preIF1_valid            (preIF1_valid                  ),
    .preIF1_ready_go         (preIF1_ready_go               ),

    .preIF1_preIF2_bus_slot0 (preIF1_preIF2_bus_slot0       ),
    .preIF1_preIF2_bus       (preIF1_preIF2_bus             ),
    //cancel
    .preIF1_need_cancel      (preIF_IF_ID_need_cancel       ),
    //stall
    .need_stall              (need_stall                    ),
    .cancel_target           (cancel_target                 ),
    // search port 0 (for fetch the inst)
    .s0_vppn                 (s0_vppn                       ),
    .s0_va_bit12             (s0_va_bit12                   ),
    .s0_found                (s0_found                      ),
    .s0_index                (s0_index                      ), // 实际使用的index位宽为log2(TLBNUM)
    .s0_ppn                  (s0_ppn                        ),
    .s0_ps                   (s0_ps                         ),
    .s0_plv                  (s0_plv                        ),
    .s0_mat                  (s0_mat                        ),
    .s0_d                    (s0_d                          ),
    .s0_v                    (s0_v                          ),
    //tlb_ex
    .ex_tlb_reload0          (ex_tlb_reload0                ),//tlb重填异常
    .ex_tlb_preif_unvalid    (ex_tlb_preif_unvalid          ),//tlb取指页无效
    .ex_tlb_plv0             (ex_tlb_plv0                   ),//tlb的页权限上访
    .tlb_inst_req            (tlb_inst_req                  ),
    //DMW
    .dmw_vseg0               (dmw_vseg0                     ),
    .dmw_found0              (dmw_found0                    ),
    .dmw_pseg0               (dmw_pseg0                     ),
    //CRMD PG DA
    .csr_CRMD_DA             (csr_CRMD_DA                   ),
    .csr_CRMD_PG             (csr_CRMD_PG                   ),
    .csr_CRMD_DATF           (csr_CRMD_DATF                 ),
    .dmw_mat0                (dmw_mat0                      ),
    //branch prediction
    // query port: preIF lookup
    .query_valid             (query_valid                   ),
    .query_pc                (query_pc                      ),
    .btb_query_hit           (btb_query_hit                 ),//valid and tag match
    .btb_query_target        (btb_query_target              ),
    .ras_query_hit           (ras_query_hit                 ),//valid and tag match
    .ras_query_target        (ras_query_target              ),
    .query_type              (query_type                    ),
    .query_taken             (query_taken                   ),//predict taken
    //IDLE
    .preIF1_IDLE_stall       (preIF1_idle_block             )
);

pre_IF2 #(
    .slot0_inbus_width            (preIF1_preIF2_slot0_bus_width ),
    .inbus_width                  (preIF1_preIF2_bus_width       ),
    .outbus_width                 (preIF2_IF_bus_width           ),
    .ISSUE                        (ISSUE                         )
) u_pre_IF2
(
    .clk                          (clk                           ),
    .resetn                       (resetn                        ),
    //control signal
    .preIF1_preIF2_valid          (preIF1_preIF2_valid           ),
    .preIF2_allow_in              (preIF2_allow_in               ),
    .preIF2_valid                 (preIF2_valid                  ),
    .preIF2_ready_go              (preIF2_ready_go               ),

    .preIF1_preIF2_bus_slot0      (preIF1_preIF2_bus_slot0       ),
    .preIF1_preIF2_bus            (preIF1_preIF2_bus             ),
    .preIF2_IF_bus                (preIF2_IF_bus                 ),
    //cancel
    .preIF2_need_cancel           (preIF_IF_ID_need_cancel       ),
    //stall
    .need_stall                   (need_stall                    ),
    //handshake
    .inst_sram_req                (inst_sram_req                 ),
    .inst_sram_wr                 (inst_sram_wr                  ), // 1表示write 0表示read
    .inst_sram_wstrb              (inst_sram_wstrb               ),// wstrb 对应原始数据的字节写使能
    .inst_sram_size               (inst_sram_size                ),
    .inst_sram_addr_without_cacop (inst_sram_addr_without_cacop  ),
    .inst_sram_wdata              (inst_sram_wdata               ),
    .inst_sram_addr_ok            (inst_sram_addr_ok             ),
    .IF_allow_in                  (IF_allow_in                   ),
    .inst_sram_data_ok            (inst_sram_data_ok             ),
    .req_to_dataok_trigger        (req_to_dataok_trigger         ),
    .inst_resp_discard            (inst_resp_discard             ),
    //CRMD
    .csr_CRMD_DA                  (csr_CRMD_DA                   ),
    .csr_CRMD_PG                  (csr_CRMD_PG                   ),
    //说明s1_mat是已经换算好的？
    .inst_mat                     (inst_mat                      ),
    .inst_wr                      (inst_wr                       )
);

fetch #(
    .inbus_width           (preIF2_IF_bus_width     ),
    .outbus_width          (IF_ID_bus_width         ),
    .ISSUE                 (ISSUE                   )
)u_fetch(
    .clk                   (clk                     ),
    .resetn                (resetn                  ),
    //control signal
    .preIF2_IF_valid       (preIF2_IF_valid         ),
    .IF_valid              (IF_valid                ),
    .IF_allow_in           (IF_allow_in             ),
    .IF_ready_go           (IF_ready_go             ),
    //bus
    .preIF2_IF_bus         (preIF2_IF_bus           ),
    .IF_ID_bus             (IF_ID_bus               ),
    //cancel
    .IF_need_cancel        (preIF_IF_ID_need_cancel ),
    //stall
    .need_stall            (need_stall              ),
    //handshake
    .inst_sram_data_ok     (inst_sram_data_ok       ),
    .inst_sram_rdata       (inst_sram_rdata         ),
    .ID_allow_in           (ID_allow_in             ),
    .inst_resp_discard     (inst_resp_discard       ),
    .req_to_dataok_trigger (req_to_dataok_trigger   ),
    //ID_can_accept_IF
    .ID_can_accept_IF      (ID_can_accept_IF        )
);
decode #(
    .inbus_width         (IF_ID_bus_width         ),
    .outbus_width        (ID_EXE1_bus_width       ),
    .ISSUE               (ISSUE                   )
)u_decode(
    .clk                 (clk                     ),
    .resetn              (resetn                  ),
    //control signal
    .ID_valid            (ID_valid                ),
    .IF_ID_valid         (IF_ID_valid             ),
    .ID_allow_in         (ID_allow_in             ),
    .ID_ready_go         (ID_ready_go             ),
    
    .IF_ID_bus           (IF_ID_bus               ),//bus
    .ID_EXE1_bus         (ID_EXE1_bus             ),
    //br_prediction
    .br_afterpred_taken  (br_afterpred_taken      ),
    .br_afterpred_target (br_afterpred_target     ),

    .rf_raddr1           (rf_raddr1               ),//decode src1&2 address   ---- stall need use 
    .rf_raddr2           (rf_raddr2               ),
    .rf_rdata1           (front_push_rdata1       ),
    .rf_rdata2           (front_push_rdata2       ),//have been front_push 
    // br前递数据没有ld相关
    .br_rdata1           (front_push_br_rdata1    ),
    .br_rdata2           (front_push_br_rdata2    ),
    .br_use_rj           (br_use_rj               ),
    .br_use_rk           (br_use_rk               ),
    .ID_need_alu1_rj    (ID_need_alu1_rj         ),
    .ID_need_src2_withST    (ID_need_src2_withST         ),
    .ID_need_alu2_rk (ID_need_alu2_rk      ),
    //cancel
    .ID_need_cancel      (preIF_IF_ID_need_cancel ),
    //stall
    .need_stall          (need_stall              ),
    //中断
    .has_int             (has_int                 ),
    //branch prediction
    // update port: Decode writes back real result
    .update_valid        (update_valid            ),
    .bht_update_valid    (bht_update_valid        ),
    .bht_update_pc       (bht_update_pc           ),
    .bht_update_taken    (bht_update_taken        ),
    .update_pc           (update_pc               ),
    .update_target       (update_target           ),//real target
    .update_type         (update_type             ),
    .update_taken        (update_taken            ),//real taken
    // backend real call update
    .push_valid          (push_valid              ),
    .push_target         (push_target             ),
    // backend real return update
    .pop_valid           (pop_valid               ),
    //PLV
    .csr_CRMD_PLV        (csr_CRMD_PLV            ),
    //ID_can_accept_IF
    .ID_can_accept_IF    (ID_can_accept_IF        )
);

exe1 #(
    .inbus_width        (ID_EXE1_bus_width   ),
    .outbus_width       (EXE1_EXE2_bus_width ),
    .ISSUE              (ISSUE               )
)u_exe1(
    .clk                (clk                 ),
    .resetn             (resetn              ),
    //control signal
    .EXE1_ready_go      (EXE1_ready_go       ),
    .EXE1_valid         (EXE1_valid          ),
    .ID_EXE1_valid      (ID_EXE1_valid       ),
    .EXE1_allow_in      (EXE1_allow_in       ),
    
    .ID_EXE1_bus        (ID_EXE1_bus         ),//bus
    .src1_capture_sel   (src1_capture_sel     ),
    .src2_capture_sel   (src2_capture_sel     ),
    .ID_need_alu2_rk(ID_need_alu2_rk  ),
    .EXE1_EXE2_bus      (EXE1_EXE2_bus       ),
    //stall
    .EXE1_rf_dest       (EXE1_rf_dest        ),
    .EXE1_rf_gr_we      (EXE1_rf_gr_we       ),
    .EXE1_can_front   (EXE1_can_front    ),
    //cancel
    .EXE1_need_cancel   (EXE1_need_cancel    ),
    //stable counter
    .stable_counter     (stable_counter      ),
    // search port 1 (for load/store the data)
    .s1_vppn            (s1_vppn             ),
    .s1_va_bit12        (s1_va_bit12         ),
    .tlbinv_asid        (tlbinv_asid         ),
    .s1_found           (s1_found            ),
    .s1_index           (s1_index            ),
    .s1_ppn             (s1_ppn              ),
    .s1_ps              (s1_ps               ),
    .s1_plv             (s1_plv              ),
    .s1_mat             (s1_mat              ),
    .s1_d               (s1_d                ),
    .s1_v               (s1_v                ),
    .csr_TLBEHI         (csr_TLBEHI          ),
    //invtlb
    .invtlb_None_ex     (invtlb_None_ex      ),
    .invtlb_valid       (invtlb_valid        ),
    .invtlb_index       (invtlb_index        ),
    .invtlb_op          (invtlb_op           ),
    //CRMD PG DA
    .csr_CRMD_DA        (csr_CRMD_DA         ),
    .csr_CRMD_PG        (csr_CRMD_PG         ),
    //tlb_ex
    .ex_tlb_reload1     (ex_tlb_reload1      ),//tlb重填异常
    .ex_tlb_ld_unvalid  (ex_tlb_ld_unvalid   ),//tlb的load页无效
    .ex_tlb_st_unvalid  (ex_tlb_st_unvalid   ),//tlb的store页无效
    .ex_tlb_plv1        (ex_tlb_plv1         ),//tlb的页权限上访
    .ex_tlb_page_modify (ex_tlb_page_modify  ),//tlb页修改
    .tlb_data_req       (tlb_data_req        ),
    .tlb_load_req       (tlb_load_req        ),
    .tlb_store_req      (tlb_store_req       ),
    //DMW
    .dmw_vseg1          (dmw_vseg1           ),
    .dmw_found1         (dmw_found1          ),
    .dmw_pseg1          (dmw_pseg1           ),
    //mat:存储访问类型
    .csr_CRMD_DATM      (csr_CRMD_DATM       ),
    .dmw_mat1           (dmw_mat1            ),
    //from exe2 mem wb
    .older_ex_for_exe1  (older_ex_for_exe1   )
);

exe2 #(
    .inbus_width             (EXE1_EXE2_bus_width     ),
    .outbus_width            (EXE2_MEM_bus_width      ),
    .ISSUE                   (ISSUE                   )
)u_exe2(
    .clk                     (clk                     ),
    .resetn                  (resetn                  ),
    //control signal
    .EXE2_ready_go           (EXE2_ready_go           ),
    .EXE2_valid              (EXE2_valid              ),
    .EXE1_EXE2_valid         (EXE1_EXE2_valid         ),
    .EXE2_allow_in           (EXE2_allow_in           ),
    
    .EXE1_EXE2_bus           (EXE1_EXE2_bus           ),//bus
    .EXE2_MEM_bus            (EXE2_MEM_bus            ),
    //stall
    .EXE2_rf_dest            (EXE2_rf_dest            ),
    .need_stall_inst         (exe2_need_stall_inst    ),
    .need_stall_csr          (exe2_need_stall_csr     ),
    //front_push
    .exe2_front_data         (exe2_front_data         ),
    .exe2_front_addr         (exe2_front_addr         ),
    //can_not_front_push
    .exe2_can_not_front_push (exe2_can_not_front_push ),
    //cancel
    .EXE2_need_cancel        (EXE2_need_cancel        ),
    .flush                   (flush                   ),
    //ex
    .older_ex_for_exe2       (older_ex_for_exe2       ),
    .EXE2_ex                 (EXE2_ex                 ),
    //handshake
    .data_sram_req           (data_sram_req           ),
    .data_sram_wr            (data_sram_wr            ),
    .data_sram_wstrb         (data_sram_wstrb         ),
    .data_sram_size          (data_sram_size          ),
    .data_sram_addr          (data_sram_addr          ),
    .data_sram_wdata         (data_sram_wdata         ),
    .data_sram_addr_ok       (data_sram_addr_ok       ),
    .data_sram_data_ok       (data_sram_data_ok       ),
    .MEM_allow_in            (MEM_allow_in            ),
    //uncache
    .data_mat                (data_mat                ),
    .data_wr                 (data_wr                 ),
    //cacop
    .csr_CRMD_PLV            (csr_CRMD_PLV            ),
    .cache_code              (cache_code              ),
    .cacop_valid             (cacop_valid             ),
    .cacop_done              (cacop_done              ),
    .cacop_pc                (cacop_pc                ),
    //system inst_need_cancel
    .ibar_cancel             (ibar_cancel             ),
    .dbar_cancel             (dbar_cancel             ),
    .idbar_pc                (idbar_pc                ),
    .LLbit_wb                (LLbit_wb                ),
    .LLbit_wdata             (LLbit_wdata             ),
    .LLbit                   (LLbit                   )
);

mem #(
    .inbus_width            (EXE2_MEM_bus_width     ),
    .outbus_width           (MEM_WB_bus_width       ),
    .ISSUE                  (ISSUE                  )
)u_mem(
    .clk                    (clk                    ),
    .resetn                 (resetn                 ),
    //control signal
    .MEM_valid              (MEM_valid              ),
    .EXE2_MEM_valid         (EXE2_MEM_valid         ),
    .MEM_allow_in           (MEM_allow_in           ),
    .MEM_ready_go           (MEM_ready_go           ),
    .EXE2_MEM_bus           (EXE2_MEM_bus           ),//bus
    .MEM_WB_bus             (MEM_WB_bus             ),
    //stall
    .MEM_rf_dest            (MEM_rf_dest            ),
    .need_stall_inst        (mem_need_stall_inst    ),
    .need_stall_csr         (mem_need_stall_csr     ),
    //front_push
    .mem_front_data_nonld   (mem_front_data_nonld   ),
    .mem_front_data         (mem_front_data         ),
    .mem_front_addr         (mem_front_addr         ),
    //cancel
    .MEM_need_cancel        (MEM_need_cancel        ),
    .older_ex_for_mem       (older_ex_for_mem       ),
    //ex_front
    .MEM_ex                 (MEM_ex                 ),
    //handshake
    .data_sram_data_ok      (data_sram_data_ok      ),
    .data_sram_rdata        (data_sram_rdata        ),
    .WB_allow_in            (WB_allow_in            ),
     //can_not_front_push
    .mem_can_not_front_push (mem_can_not_front_push )
);

wb #(
    .inbus_width            (MEM_WB_bus_width       ),
    .ISSUE                  (ISSUE                  )
)u_wb(
    .clk                    (clk                    ),
    .resetn                 (resetn                 ),
    //control signal
    .WB_valid               (WB_valid               ),
    .MEM_WB_valid           (MEM_WB_valid           ),
    .WB_allow_in            (WB_allow_in            ),
    .WB_ready_go            (WB_ready_go            ),
    
    .MEM_WB_bus             (MEM_WB_bus             ),
    .debug_wb_pc            (debug_wb_pc            ),
    .debug_wb_rf_wdata      (debug_wb_rf_wdata      ),
    .debug_wb_rf_we         (debug_wb_rf_we         ),
    .debug_wb_rf_wnum       (debug_wb_rf_wnum       ),
    .debug_commit_valid     (debug_commit_valid     ),
    .debug_commit_exception (debug_commit_exception ),
    .debug_commit_pc        (debug_commit_pc        ),
    .debug_commit_rf_wen    (debug_commit_rf_wen    ),
    .debug_commit_rf_wnum   (debug_commit_rf_wnum   ),
    .debug_commit_rf_wdata  (debug_commit_rf_wdata  ),
    .rf_waddr               (rf_waddr               ),
    .rf_wdata               (rf_wdata               ),
    .rf_we                  (rf_we                  ),
    //stall
    .WB_rf_dest             (WB_rf_dest             ),
    .need_stall_csr         (wb_need_stall_csr      ),
    //front_push
    .wb_front_valid         (wb_front_valid         ),
    .wb_front_data          (wb_front_data          ),
    .wb_front_addr          (wb_front_addr          ),
     //can_not_front_push
    .wb_can_not_front_push  (wb_can_not_front_push  ),
    //csr   
    .csr_rvalue             (csr_rvalue             ),
    .csr_num                (csr_num                ),
    .csr_wdata              (csr_wdata              ),
    .csr_wmask              (csr_wmask              ),
    .csr_we                 (csr_we                 ),
    .csr_re                 (csr_re                 ),
    .flush_target           (flush_target           ),
    .flush                  (flush                  ),
    //cancel
    .WB_need_cancel         (WB_need_cancel         ),
    //wb接口
    .wb_pc                  (wb_pc                  ),
    .wb_ex                  (wb_ex                  ),
    .wb_vaddr               (wb_vaddr               ),
    .ecode                  (wb_ecode               ),
    .esubcode               (wb_esubcode            ),
    //ex_front
    .WB_ex                  (WB_ex                  ),
    //tlbrd
    .tlbrd_we               (tlbrd_we               ),
    .tlbwr_we               (tlbwr_we               ),
    .tlbfill_we             (tlbfill_we             ),
    //tlbidx
    .csr_TLBIDX             (csr_TLBIDX             ),
    //tlbreload 重填传入CSR
    .ex_tlb_reload          (ex_tlb_reload          ),
    //ERTN 更改 CRMD
    .ertn_valid             (ertn_valid             ),
    // 更新 csr_regfile 相关的 BADV
    .csr_tlb_reload0        (csr_tlb_reload0        ),
    .csr_tlb_plv0           (csr_tlb_plv0           ),
    .csr_tlb_reload1        (csr_tlb_reload1        ),  
    .csr_tlb_plv1           (csr_tlb_plv1           ),
    //ex_tlb TLBEHI
    .ex_tlb                 (ex_tlb                 ),
    //IDLE
    .csr_has_int            (has_int                ),
    .csr_tcfg_init0         (csr_tcfg_init0         ),
    .IDLE_stall             (IDLE_stall             )
);
//------------------------{5-stage pipeline instantiation}end-------------------------//

endmodule
