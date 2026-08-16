module decode #(
    parameter  inbus_width  = 138,
    parameter  outbus_width = 247,
    parameter  ISSUE        = 2   
)(
    input  wire                    clk,
    input  wire                    resetn,
    //control signal
    input  wire                    IF_ID_valid,
    input  wire                    ID_allow_in,
   // output reg                     ID_valid,
    output wire                    ID_valid,
    output reg                     rr_valid,
    output wire                    ID_ready_go,
    
    //bus
    input  wire [inbus_width-1:0]  IF_ID_bus[1:0],//bus
    output wire [outbus_width-1:0] ID_EXE1_bus[1:0],
    //regfile
    output wire [4:0]              rf_raddr1[1:0],
    output wire [4:0]              rf_raddr2[1:0],
    input  wire [31:0]             rf_rdata1[1:0],
    input  wire [31:0]             rf_rdata2[1:0],
    input  wire [31:0]             rf_rdata1_br[1:0],
    input  wire [31:0]             rf_rdata2_br[1:0],
    //br前递
    output wire                    is_br[1:0],
    //cancel control
    input  wire                    ID_need_cancel,
    //prediction
    output wire                    br_afterpred_taken,
    output wire [31:0]             br_afterpred_target,
    //stall
    input  wire                    need_stall,
    input  wire                    has_int,
    //branch prediction
    //更新端口：Decode确定真实跳转后更新BTB
    output wire                    update_valid ,
    output wire                    bht_update_valid,
    output wire [31:0]             update_pc    ,
    output wire [31:0]             update_target,//真实目标地址
    output wire [1:0]              update_type  ,
    output wire                    update_taken ,//真实是否跳转
    // 是不是 call 调用
    output wire                    push_valid   ,
    output wire [31:0]             push_target  ,
    // 是不是 return 返回
    output wire                    pop_valid    ,
    //PLV
    input  wire [1:0]              csr_CRMD_PLV,
    //ID_can_accept_IF
    output wire                    ID_can_accept_IF,
    //skid
    input  wire                    skid_valid
);
//------------------------{bus decode}begin-------------------------//
reg [inbus_width-1:0] bus[1:0];
reg                   bus_has_inst;//bus中有未完成的IF的指令

integer k;
always @(posedge clk)begin
    if(!resetn || ID_need_cancel)begin
        for (k = 0; k < ISSUE; k = k + 1) begin
            bus[k] <= {inbus_width{1'b0}};
        end
        bus_has_inst <= 1'b0;
    end
    else if (hold_take_IF_young) begin
        bus[0]       <= IF_ID_bus[1];
        bus[1]       <= {inbus_width{1'b0}};
        bus_has_inst <= IF_ID_bus[1][inbus_width-1];
    end
    else if (accept_IF_in_bus) begin
        for (k = 0; k < ISSUE; k = k + 1) begin
            bus[k] <= IF_ID_bus[k];
        end
        bus_has_inst <= 1'b1;
    end
    else if(consume_bus) begin
        for (k = 0; k < ISSUE; k = k + 1) begin
            bus[k] <= {inbus_width{1'b0}};
        end
        bus_has_inst <= 1'b0;
    end
end
wire        slot_valid[1:0];
wire [31:0] pc[1:0];
wire [31:0] inst[1:0];
wire        ex_ADEF[1:0];
wire        ex_tlb_reload0[1:0];//tlb重填异常
wire        ex_tlb_preif_unvalid[1:0];//tlb的取指页无效
wire        ex_tlb_plv0[1:0];//tlb的页权限非法

wire        btb_query_hit[1:0];//valid且tag
wire [31:0] btb_query_target[1:0];        
wire        ras_query_hit[1:0];//valid且tag
wire [31:0] ras_query_target[1:0];        
wire [ 1:0] query_type[1:0];              
wire        query_taken[1:0];//预测是否跳转 

wire bus0_valid = bus[0][inbus_width-1];
wire bus1_valid = bus[1][inbus_width-1];

//-------------------------{hold}begin---------------------------------------------//
reg                      hold_valid;
reg  [inbus_width-1:0]   hold_bus;
wire [inbus_width-1 : 0] bus_eff [1:0];//有效包，经过hold筛选后的bus

wire                     IF_next_valid     = IF_ID_valid;//IF的下一条指令有效
wire                     pack_hold_with_IF = hold_valid  & ~bus_has_inst & IF_next_valid;//把hold中的指令和IF的指令拼包

wire create_hold_from_soft = id_fire_dec_raw & ~hold_valid & soft_kill_bus & slot_issue_dec[0];//无hold指令，soft kill只发出slot0到后端，slot1住hold
wire create_hold_from_tail = id_fire_dec_raw & hold_valid & slot_issue_dec[0] & ~soft_kill_bus & ~hard_kill_ex &
                             (bus_has_inst ? bus1_valid : (pack_hold_with_IF & IF_ID_bus[1][inbus_width-1]));//重新拼包且双发成功，且原始包的slot1进hold
wire hold_take_IF_young    = id_fire_dec_raw & pack_hold_with_IF & slot_issue_dec[0] & soft_kill_bus;//hold与IF拼包后又只发射了第一条,则IF的用来拼的那条进入hold，剩下那条指令留在bus

wire pack_soft_keep_bus    = id_fire_dec_raw & hold_valid & slot_issue_dec[0] & soft_kill_bus & bus_has_inst;//hold与下一条指令重新拼包后soft kill,则hold指令下一条指令留在bus
wire pack_dual_from_IF     = id_fire_dec_raw & pack_hold_with_IF & slot_issue_dec[0] & 
                             slot_valid[1] & ~soft_kill_bus & ~hard_kill_ex;//hold和IF指令拼包后两个都发出

wire consume_bus = id_fire_dec_raw & bus_has_inst & ~pack_soft_keep_bus & (
                   //无hold指令并且发出slot0
                   (~hold_valid & slot_issue_dec[0]) |
                   //重新拼包后next发出或者被hard丢弃
                   (hold_valid & (~soft_kill_bus | hard_kill_ex))
                   );
wire accept_IF_in_bus = IF_ID_valid & ID_allow_in & 
                        (~bus_has_inst | consume_bus) &
                        ~pack_dual_from_IF  & 
                        ~hold_take_IF_young &
                        ~(pack_hold_with_IF & id_fire_dec_raw & hard_kill_ex);

wire [inbus_width-1 : 0] hold_din = create_hold_from_soft ? bus_eff[1]                              :
                                    create_hold_from_tail ? (bus_has_inst ? bus[1] : IF_ID_bus[1])  :
                                    hold_take_IF_young    ? IF_ID_bus[0]                            :
                                    hold_bus;

//output
assign ID_can_accept_IF = (~bus_has_inst | consume_bus);

always @(posedge clk) begin
    if (!resetn) begin
        hold_valid <= 1'b0;
        hold_bus   <= {inbus_width{1'b0}};
    end
    else if (ID_need_cancel) begin
        hold_valid <= 1'b0;
    end
    else if (create_hold_from_soft | create_hold_from_tail | hold_take_IF_young) begin
        hold_valid <= 1'b1;
        hold_bus   <= hold_din;
    end
    else if (id_fire_dec_raw & hold_valid & slot_issue_dec[0]) begin
        hold_valid <= 1'b0;
    end
end

//-------------------------{hold}end---------------------------------------------//
assign bus_eff[0] = hold_valid        ? hold_bus     :   bus[0];
assign bus_eff[1] = ~hold_valid       ? bus[1]       :
                    bus_has_inst      ? bus[0]       :
                    pack_hold_with_IF ? IF_ID_bus[0] :
                    {inbus_width{1'b0}};
genvar gi;
generate
    for (gi = 0; gi < ISSUE; gi = gi + 1) begin : gen_i 
         assign {
            slot_valid[gi],
            pc[gi],
            inst[gi],
            ex_ADEF[gi],
            ex_tlb_reload0[gi],
            ex_tlb_preif_unvalid[gi],
            ex_tlb_plv0[gi],
            btb_query_hit[gi],
            btb_query_target[gi],
            ras_query_hit[gi],
            ras_query_target[gi],
            query_type[gi],
            query_taken[gi]
         } = bus_eff[gi];
    end 
endgenerate

wire        rr_slot_valid[1:0];
wire [31:0] rr_pc[1:0], rr_inst[1:0];
wire        rr_ex_ADEF[1:0], rr_ex_tlb_reload0[1:0];
wire        rr_ex_tlb_preif_unvalid[1:0], rr_ex_tlb_plv0[1:0];
wire        rr_btb_hit[1:0], rr_ras_hit[1:0], rr_query_taken[1:0];
wire [31:0] rr_btb_tgt[1:0], rr_ras_tgt[1:0];
wire [1:0]  rr_query_type[1:0];

generate
  for (gi = 0; gi < ISSUE; gi = gi + 1) begin : gen_rr_unpk
    assign {
      rr_slot_valid[gi], rr_pc[gi], rr_inst[gi],
      rr_ex_ADEF[gi], rr_ex_tlb_reload0[gi],
      rr_ex_tlb_preif_unvalid[gi], rr_ex_tlb_plv0[gi],
      rr_btb_hit[gi], rr_btb_tgt[gi],
      rr_ras_hit[gi], rr_ras_tgt[gi],
      rr_query_type[gi], rr_query_taken[gi]
    } = rr_bus_eff[gi];
  end
endgenerate

wire pred_not_neighbor = rr_slot_valid[0] & rr_slot_valid[1] & (rr_pc[1] != (rr_pc[0] + 32'd4));
wire pred_is_neighbor  = rr_slot_valid[0] & rr_slot_valid[1] & (rr_pc[1] == (rr_pc[0] + 32'd4));
//------------------------{bus decode}end-------------------------//

//--------------------------------------{dec}begin--------------------------------//
localparam EXE_PAYLOAD_W = 243;
// -------- DEC：只从 inst 译 rs / 结构，不读 RF --------
wire [4:0] rf_raddr1_dec[1:0];
wire [4:0] rf_raddr2_dec[1:0];
wire       is_cond_dec[1:0], is_call_dec[1:0], is_ret_dec[1:0], is_jump_dec[1:0];
wire       is_br_dec[1:0], is_mem_dec[1:0], is_system_break_dec[1:0];
wire       is_csr_write_dec[1:0], is_csr_read_dec[1:0], is_tlb_dec[1:0];
wire [4:0] rf_dest_dec[1:0];
wire       rf_gr_we_dec[1:0];
wire       ex_INE_dec[1:0], ex_IPE_dec[1:0];
wire       result_not_fast_dec[1:0];
wire       src1_is_reg_dec[1:0];
wire       src2_is_reg_dec[1:0];
wire       is_store_dec[1:0];
wire       is_cpucfg_dec[1:0];

wire [EXE_PAYLOAD_W-1:0] exe_payload_dec[1:0]; // 不用

generate
  for (gi = 0; gi < ISSUE; gi = gi + 1) begin : gen_dec
    inst_to_alu_resource #(
        .outbus_width(EXE_PAYLOAD_W+1)
    ) u_dec (
      .pc(pc[gi]), 
      .inst(inst[gi]), 
      .slot_valid(slot_valid[gi]),
      .ex_ADEF(ex_ADEF[gi]), 
      .ex_tlb_reload0(ex_tlb_reload0[gi]),
      .ex_tlb_preif_unvalid(ex_tlb_preif_unvalid[gi]), 
      .ex_tlb_plv0(ex_tlb_plv0[gi]),
      .btb_query_hit(btb_query_hit[gi]), 
      .btb_query_target(btb_query_target[gi]),
      .ras_query_hit(ras_query_hit[gi]), 
      .ras_query_target(ras_query_target[gi]),
      .query_type(query_type[gi]), 
      .query_taken(query_taken[gi]),
      .rf_rdata1(32'b0), 
      .rf_rdata2(32'b0),
      .rf_rdata1_br(32'b0),
      .rf_rdata2_br(32'b0),
      .csr_CRMD_PLV(csr_CRMD_PLV),
      .has_int((gi == 0) ? has_int : 1'b0),
      .rf_raddr1(rf_raddr1_dec[gi]), 
      .rf_raddr2(rf_raddr2_dec[gi]),
      .exe_payload(exe_payload_dec[gi]),
      .real_taken(), 
      .real_target(), 
      .pred_taken(), 
      .pred_valid(), 
      .pred_ok(), 
      .redirect(),
      .is_cond(is_cond_dec[gi]), 
      .is_call(is_call_dec[gi]), 
      .is_ret(is_ret_dec[gi]),
      .is_jump(is_jump_dec[gi]), 
      .is_br(is_br_dec[gi]), 
      .is_mem(is_mem_dec[gi]),
      .is_system_break(is_system_break_dec[gi]),
      .is_csr_write(is_csr_write_dec[gi]), 
      .is_csr_read(is_csr_read_dec[gi]), 
      .is_tlb(is_tlb_dec[gi]),
      .rf_dest(rf_dest_dec[gi]), 
      .rf_gr_we(rf_gr_we_dec[gi]),
      .result_not_fast(result_not_fast_dec[gi]),
      .src1_is_reg(src1_is_reg_dec[gi]),
      .src2_is_reg(src2_is_reg_dec[gi]),
      .is_store(is_store_dec[gi]),
      .is_cpucfg_inst(is_cpucfg_dec[gi]),
      .upd_need(), 
      .bht_upd_need(), 
      .push_need(), 
      .pop_need(), 
      .br_type(),
      .ex_INE(ex_INE_dec[gi]), 
      .ex_IPE(ex_IPE_dec[gi])
    );
  end
endgenerate
//--------------------------------------{dec}end--------------------------------//

//------------------------{module}begin--------------------------//
wire id_fire         = ID_valid  & ID_ready_go     & ~ID_need_cancel & ID_allow_in;
wire id_fire_dec_raw = dec_valid & rr_allow_in;//id_fire不考虑取消
wire id_fire_dec     = id_fire_dec_raw & ~ID_need_cancel;//id_fire解码

wire [EXE_PAYLOAD_W-1:0] exe_payload   [1:0];
wire        real_taken     [1:0];
wire [31:0] real_target    [1:0];
wire        pred_taken     [1:0];
wire        pred_valid     [1:0];
wire        pred_ok        [1:0];
wire        redirect_lane  [1:0];
wire        is_cond        [1:0];
wire        is_call        [1:0];
wire        is_ret         [1:0];
wire        is_jump        [1:0];
//wire        is_br          [1:0];
wire        is_mem         [1:0];
wire        is_system_break[1:0];
wire        is_csr_write   [1:0];
wire        is_csr_read    [1:0];
wire        is_tlb         [1:0];
wire [4:0]  rf_dest        [1:0];
wire        rf_gr_we       [1:0];
wire        result_not_fast[1:0];
wire        src1_is_reg    [1:0];
wire        src2_is_reg    [1:0];
wire        is_store       [1:0];
wire        is_cpucfg_inst [1:0];
// 若按上面加了可选端口：
wire        upd_need       [1:0];
wire        bht_upd_need   [1:0];
wire        push_need      [1:0];
wire        pop_need       [1:0];
wire [1:0]  br_type        [1:0];
wire        ex_INE         [1:0];
wire        ex_IPE         [1:0];

generate
  for (gi = 0; gi < ISSUE; gi = gi + 1) begin : gen_alu_res
    inst_to_alu_resource #(//inst_to_alu_rr
      .outbus_width(EXE_PAYLOAD_W+1)
    ) u_inst_to_alu (
      .pc                   (rr_pc[gi]),
      .inst                 (rr_inst[gi]),
      .slot_valid           (rr_slot_valid[gi]),
      .ex_ADEF              (rr_ex_ADEF[gi]),
      .ex_tlb_reload0       (rr_ex_tlb_reload0[gi]),
      .ex_tlb_preif_unvalid (rr_ex_tlb_preif_unvalid[gi]),
      .ex_tlb_plv0          (rr_ex_tlb_plv0[gi]),
      .btb_query_hit        (rr_btb_hit[gi]),
      .btb_query_target     (rr_btb_tgt[gi]),
      .ras_query_hit        (rr_ras_hit[gi]),
      .ras_query_target     (rr_ras_tgt[gi]),
      .query_type           (rr_query_type[gi]),
      .query_taken          (rr_query_taken[gi]),
      .rf_rdata1            (rf_rdata1[gi]),
      .rf_rdata2            (rf_rdata2[gi]),
      .rf_rdata1_br         (rf_rdata1_br[gi]),
      .rf_rdata2_br         (rf_rdata2_br[gi]),
      .csr_CRMD_PLV         (csr_CRMD_PLV),
      .has_int              ((gi == 0) ? has_int : 1'b0),//只在slot0判中断
      //.id_fire              (id_fire & slot_valid[gi]), 
      .rf_raddr1            (rf_raddr1[gi]),
      .rf_raddr2            (rf_raddr2[gi]),
      .exe_payload          (exe_payload[gi]),
      .real_taken           (real_taken[gi]),
      .real_target          (real_target[gi]),
      .pred_taken           (pred_taken[gi]),
      .pred_valid           (pred_valid[gi]),
      .pred_ok              (pred_ok[gi]),
      .redirect             (redirect_lane[gi]),
      .is_cond              (is_cond[gi]),
      .is_call              (is_call[gi]),
      .is_ret               (is_ret[gi]),
      .is_jump              (is_jump[gi]),
      .is_br                (is_br[gi]),
      .is_mem               (is_mem[gi]),
      .is_system_break      (is_system_break[gi]),  //system/break/ertn/idle/ibar/dbar/cacop
      .is_csr_write         (is_csr_write[gi]),    //csrwr/csrxchg
      .is_csr_read          (is_csr_read[gi]),     //csrrd/rdcntid/rdcntvl/rdcntdvh
      .is_tlb               (is_tlb[gi]),          //tlbrd/tlbfill/tlbsrch/invtlb/tlbwr
      .rf_dest              (rf_dest[gi]),
      .rf_gr_we             (rf_gr_we[gi]),
      .result_not_fast      (result_not_fast[gi]),
      .src1_is_reg          (src1_is_reg[gi]),
      .src2_is_reg          (src2_is_reg[gi]),
      .is_store             (is_store[gi]),
      .is_cpucfg_inst       (is_cpucfg_inst[gi]),
      // .upd_need(upd_need[gi]), ...
      .upd_need             (upd_need[gi]    ),       // pred_valid & ~ex_ADEF & ~pred_ok
      .bht_upd_need         (bht_upd_need[gi]),   // is_cond & ~ex_ADEF
      .push_need            (push_need[gi]   ),
      .pop_need             (pop_need[gi]    ),
      .br_type              (br_type[gi]     ),         // COND/JUMP/CALL/RET
      .ex_INE               (ex_INE[gi]),
      .ex_IPE               (ex_IPE[gi])
    );
  end
endgenerate
//------------------------{module}end--------------------------//

//------------------------{issue}begin-----------------------------//
wire RAW_s1_s0 = slot_valid[0] & slot_valid[1] & rf_gr_we_dec[0] & (rf_dest_dec[0] != 5'b0) & 
                 ((rf_raddr1_dec[1] == rf_dest_dec[0]) | (rf_raddr2_dec[1] == rf_dest_dec[0]));//发生写后读事件
wire WAW_s1_s0 = slot_valid[0] & slot_valid[1] & rf_gr_we_dec[0] & rf_gr_we_dec[1] & (rf_dest_dec[0] != 5'b0) & (rf_dest_dec[0] == rf_dest_dec[1]);//发生写后写事件
wire struct_comflict = slot_valid[0] & slot_valid[1] & (
    (is_mem_dec[0] & is_mem_dec[1]) |
    (is_system_break_dec[0] | is_system_break_dec[1]) |
    ((is_tlb_dec[0] & is_mem_dec[1]) | (is_mem_dec[0] & is_tlb_dec[1])) |
    ((is_csr_read_dec[0] | is_csr_write_dec[0] | is_tlb_dec[0]) &
     (is_csr_read_dec[1] | is_csr_write_dec[1] | is_tlb_dec[1]))
);

wire pred_not_neighbor_kill_s1 = pred_not_neighbor & (~real_taken[0] | redirect_lane[0]);//不是邻居，并且要么不是真跳转，要么要更新，即第一个跳转是错的
wire pred_is_neighbor_kill_s1  = pred_is_neighbor  & (real_taken[0] & (real_target[0] != rr_pc[0] + 32'd4)  | redirect_lane[0]);//是邻居，但是要跳转或者更新
wire slot0_fetch_ex = ex_ADEF[0] | ex_tlb_reload0[0] | ex_tlb_preif_unvalid[0] | ex_tlb_plv0[0] | ex_INE[0] | ex_IPE[0] | has_int;

wire slot0_trap      = slot_valid[0] & (ex_ADEF[0] | ex_tlb_reload0[0] | 
                                        ex_tlb_preif_unvalid[0] | ex_tlb_plv0[0] | 
                                        ex_INE[0] | ex_IPE[0] | has_int);//会让slot1被杀的情况，名字叫slot0陷阱
wire slot0_pair_fwd_ok = ~result_not_fast_dec[0] & ~is_tlb_dec[0] & ~is_system_break_dec[0];
wire slot1_pair_use_ok = ~is_br_dec[1] & ~is_csr_read_dec[1] & ~is_csr_write_dec[1] & ~is_tlb_dec[1] & ~is_system_break_dec[1] & ~is_cpucfg_dec[1];
//wire pair_alu_byp_ok   = slot0_pair_fwd_ok & slot1_pair_use_ok & (pair_byp_src1 | pair_byp_src2 | pair_byp_rkd);
wire RAW_s1_s0_issue   = RAW_s1_s0 & ~pair_alu_byp_ok;

//--------------------------------------------{hard_kill}begin---------------------------------------------------//
wire hard_kill_pred  = pred_not_neighbor_kill_s1 | pred_is_neighbor_kill_s1;
wire hard_kill_ex    = slot_valid[0] & (ex_ADEF[0] | ex_tlb_reload0[0] | ex_tlb_preif_unvalid[0] |
                                        ex_tlb_plv0[0] | ex_INE_dec[0] | ex_IPE_dec[0] | has_int);
wire hard_kill_slot1 = hard_kill_pred | (rr_slot_valid[0] & (rr_ex_ADEF[0] | rr_ex_tlb_reload0[0] |
                       rr_ex_tlb_preif_unvalid[0] | rr_ex_tlb_plv0[0] | ex_INE[0] | ex_IPE[0] | has_int));//直接不要slot1,这里的逻辑是如果预测正确则至多soft kill,只有预测错误或者异常才会是hard kill被直接丢弃
wire soft_kill_bus   = slot_valid[0] & slot_valid[1] & ~hard_kill_ex & (
                       RAW_s1_s0_issue | WAW_s1_s0 | struct_comflict | (is_br_dec[0] & is_br_dec[1]));//slot1只是暂时发不了，不能丢弃
//--------------------------------------------{hard_kill}end---------------------------------------------------//

wire soft_kill_slot1 = rr_slot_valid[0] & rr_slot_valid[1] & ~hard_kill_slot1 & (
                       RAW_s1_s0_issue | WAW_s1_s0 | struct_comflict | (is_br[0] & is_br[1]));//slot1只是暂时发不了，不能丢弃
wire kill_slot1      = hard_kill_slot1 | soft_kill_slot1;
//wire kill_slot1 = slot0_fetch_ex | RAW_s1_s0 | WAW_s1_s0 | struct_comflict | pred_not_neighbor_kill_s1 | pred_is_neighbor_kill_s1 | (is_br[0] & is_br[1]);//注意这里不要走双分支

wire [1:0] slot_issue = {rr_slot_valid[1] & ~hard_kill_pred, rr_slot_valid[0]};
wire [1:0] slot_issue_dec = {slot_valid[1] & ~soft_kill_bus & ~hard_kill_ex, slot_valid[0]};
//------------------------{issue}end-----------------------------//

//------------------------{pred_update}begin--------------------------------------//
wire redirect0 = slot_issue[0] & redirect_lane[0];
wire redirect1 = slot_issue[1] & redirect_lane[1] & ~redirect0;//禁止双分支

(* keep = "true" *) wire        redirect_lane_br [1:0];
(* keep = "true" *) wire        real_taken_br    [1:0];
(* keep = "true" *) wire [1:0]  slot_issue_br;
(* keep = "true" *) wire        id_fire_br;

assign redirect_lane_br[0] = redirect_lane[0];
assign redirect_lane_br[1] = redirect_lane[1];
assign real_taken_br[0]    = real_taken[0];
assign real_taken_br[1]    = real_taken[1];
assign id_fire_br          = id_fire;

assign slot_issue_br[0]    = rr_slot_valid[0];
assign slot_issue_br[1]    = rr_slot_valid[1] & ~hard_kill_pred;

wire  redirect0_br         = slot_issue_br[0] & redirect_lane_br[0];
wire  redirect1_br         = slot_issue_br[1] & redirect_lane_br[1] & ~redirect0_br;

assign br_afterpred_taken  = (redirect0_br | redirect1_br) & id_fire_br;

wire  [31:0] br_target_s0  = real_taken_br[0] ? real_target[0] : (rr_pc[0] + 32'd4);
wire  [31:0] br_target_s1  = real_taken_br[1] ? real_target[1] : (rr_pc[1] + 32'd4);
assign br_afterpred_target = redirect_lane_br[0] ? br_target_s0 : br_target_s1;//直接用taken决定是否发送，不管是不是slot_issue_br

wire take_update0 = slot_issue[0] & upd_need[0];//真正要更新slot0
wire take_update1 = slot_issue[1] & upd_need[1] & ~take_update0;//真正要更新slot1

assign update_valid = id_fire & (take_update0 | take_update1);
assign update_pc    = take_update0 ? rr_pc[0]          : rr_pc[1];
assign update_target= take_update0 ? real_target[0] : real_target[1];
assign update_taken = take_update0 ? real_taken[0]  : real_taken[1];
assign update_type  = take_update0 ? br_type[0]     : br_type[1];

assign bht_update_valid = id_fire & (slot_issue[0] & bht_upd_need[0] |
                                     slot_issue[1] & bht_upd_need[1] & ~bht_upd_need[0]);

wire take_push0     = slot_issue[0] & push_need[0];
wire take_push1     = slot_issue[1] & push_need[1] & ~take_push0;

assign push_valid   = id_fire & (take_push0 | take_push1);
assign push_target  = take_push0 ? (rr_pc[0] + 32'd4) :
                      take_push1 ? (rr_pc[1] + 32'd4) :
                      32'b0;
assign pop_valid    = id_fire & (slot_issue[0] & pop_need[0] |
                                 slot_issue[1] & pop_need[1] & ~pop_need[0]);
//------------------------{pred_update}end--------------------------------------//

//------------------------{bus}begin-------------------------//
//try to minimize the bus_size
// 槽1 被 hard_kill 时只清 valid 位，payload（含 alu_src）仍跟 rr_slot_valid，
// 避免 hard_kill_pred 乘进乘法器输入的宽 D。
wire pair_prod_dec = slot_valid[0] & slot_valid[1]
                   & rf_gr_we_dec[0] & (rf_dest_dec[0] != 5'b0)
                   & ~result_not_fast_dec[0];
wire byp_src1_dec  = pair_prod_dec & src1_is_reg_dec[1]
                   & (rf_raddr1_dec[1] == rf_dest_dec[0]);
wire byp_src2_dec  = pair_prod_dec & src2_is_reg_dec[1]
                   & (rf_raddr2_dec[1] == rf_dest_dec[0]);
wire byp_rkd_dec   = pair_prod_dec & is_store_dec[1]
                   & (rf_raddr2_dec[1] == rf_dest_dec[0]);
wire pair_alu_byp_ok = slot0_pair_fwd_ok & slot1_pair_use_ok
                     & (byp_src1_dec | byp_src2_dec | byp_rkd_dec);

generate
    for (gi = 0; gi < ISSUE; gi = gi + 1) begin : gen_id_exe
        if (gi == 0) begin
            assign ID_EXE1_bus[gi] = rr_slot_valid[gi] ?
                                     {1'b1, 3'b000, exe_payload[gi]} :
                                     {outbus_width{1'b0}};
        end
        else begin
            assign ID_EXE1_bus[gi] = rr_slot_valid[gi] ?
                                     {~hard_kill_pred, 
                                     rr_byp_src1 & ~hard_kill_pred,
                                     rr_byp_src2 & ~hard_kill_pred,
                                     rr_byp_rkd  & ~hard_kill_pred,
                                     exe_payload[gi]} :
                                     {outbus_width{1'b0}};
        end
    end
endgenerate
//------------------------{bus}end-------------------------//

//------------------------{ready_go}begin-------------------------//
assign  ID_ready_go = need_stall ? 1'b0 : 1'b1;
//------------------------{ready_go}end-------------------------//

//------------------------------------{ID_valid}begin--------------------------------//
reg                        dec_valid;
//reg                        rr_valid;
reg [inbus_width-1 : 0]    rr_bus_eff[1:0];

reg rr_byp_src1;
reg rr_byp_src2;
reg rr_byp_rkd;

wire rr_allow_in = !rr_valid || (ID_allow_in && ID_ready_go );
wire dec_fire    = dec_valid & rr_allow_in;

integer rk;
always @(posedge clk) begin
    if(!resetn || ID_need_cancel) begin
        rr_valid    <= 1'b0;
        rr_byp_src1 <= 1'b0;
        rr_byp_src2 <= 1'b0;
        rr_byp_rkd  <= 1'b0;
        for (rk = 0; rk < ISSUE; rk = rk + 1) begin
            rr_bus_eff[rk] <= {inbus_width{1'b0}};
        end
    end
    else if (rr_allow_in) begin
        rr_valid <= dec_fire;
        if (dec_fire) begin
            rr_bus_eff[0] <= slot_issue_dec[0] ? bus_eff[0] : {inbus_width{1'b0}};
            rr_bus_eff[1] <= slot_issue_dec[1] ? bus_eff[1] : {inbus_width{1'b0}};
            rr_byp_src1 <= slot_issue_dec[1] & byp_src1_dec;
            rr_byp_src2 <= slot_issue_dec[1] & byp_src2_dec;
            rr_byp_rkd  <= slot_issue_dec[1] & byp_rkd_dec;
        end
        else begin
            rr_byp_src1 <= 1'b0;
            rr_byp_src2 <= 1'b0;
            rr_byp_rkd  <= 1'b0;
        end
    end
end

assign ID_valid = rr_valid & ~ID_need_cancel;

always @(posedge clk) begin
    if(!resetn)begin
        dec_valid <= 1'b0;
    end
    else if(ID_need_cancel)begin
        dec_valid <= 1'b0;
    end
    else if(rr_allow_in)begin
        dec_valid <= (create_hold_from_soft | create_hold_from_tail | hold_take_IF_young) | 
                    (hold_valid & ~(id_fire_dec_raw & slot_issue_dec[0] & ~create_hold_from_tail & ~hold_take_IF_young)) |
                    (accept_IF_in_bus) |
                    (bus_has_inst & ~consume_bus) | 
                    (IF_ID_valid & ~accept_IF_in_bus & ~bus_has_inst & 
                    ~(hold_valid | create_hold_from_soft | create_hold_from_tail));
    end
end
//------------------------------------{ID_valid}end--------------------------------//
endmodule

