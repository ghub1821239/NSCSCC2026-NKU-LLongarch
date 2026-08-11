module decode #(
    parameter  inbus_width  = 138,
    parameter  outbus_width = 244,
    parameter  ISSUE        = 2   
)(
    input  wire                    clk,
    input  wire                    resetn,
    //control signal
    input  wire                    IF_ID_valid,
    input  wire                    ID_allow_in,
    output reg                     ID_valid,
    output wire                    ID_ready_go,
    
    //bus
    input  wire [inbus_width-1:0]  IF_ID_bus[ISSUE - 1 : 0],//bus
    output wire [outbus_width-1:0] ID_EXE1_bus[ISSUE - 1 : 0],
    //regfile
    output wire [4:0]              rf_raddr1[ISSUE - 1 : 0],
    output wire [4:0]              rf_raddr2[ISSUE - 1 : 0],
    input  wire [31:0]             rf_rdata1[ISSUE - 1 : 0],
    input  wire [31:0]             rf_rdata2[ISSUE - 1 : 0],
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
    input  wire [1:0]              csr_CRMD_PLV
);
//------------------------{bus decode}begin-------------------------//
reg     [inbus_width-1:0] bus[ISSUE - 1 : 0];
integer                   k;
always @(posedge clk)begin
    if(!resetn)begin
        for (k = 0; k < ISSUE; k = k + 1) begin
            bus[k] <= {inbus_width{1'b0}};
        end
    end
    else if(IF_ID_valid && ID_allow_in) begin
        for (k = 0; k < ISSUE; k = k + 1) begin
            bus[k] <= IF_ID_bus[k];
        end
    end
end
wire          slot_valid[ISSUE - 1 : 0];
wire   [31:0] pc[ISSUE - 1 : 0];
wire   [31:0] inst[ISSUE - 1 : 0];
wire          ex_ADEF[ISSUE - 1 : 0];
wire          ex_tlb_reload0[ISSUE - 1 : 0];//tlb重填异常
wire          ex_tlb_preif_unvalid[ISSUE - 1 : 0];//tlb的取指页无效
wire          ex_tlb_plv0[ISSUE - 1 : 0];//tlb的页权限上访

wire          btb_query_hit[ISSUE - 1 : 0];//valid且tag
wire   [31:0] btb_query_target[ISSUE - 1 : 0];        
wire          ras_query_hit[ISSUE - 1 : 0];//valid且tag
wire   [31:0] ras_query_target[ISSUE - 1 : 0];        
wire   [ 1:0] query_type[ISSUE - 1 : 0];              
wire          query_taken[ISSUE - 1 : 0];//预测是否跳转 

genvar        gi;
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
        } = bus[gi];
    end 
endgenerate

wire  pred_not_neighbor = slot_valid[0] & slot_valid[1] & (pc[1] != (pc[0] + 32'd4));
wire  pred_is_neighbor  = slot_valid[0] & slot_valid[1] & (pc[1] == (pc[0] + 32'd4));
//------------------------{bus decode}end-------------------------//

//------------------------{module}begin--------------------------//
wire                    can_update_pred = ID_valid & ID_ready_go & ~ID_need_cancel & ID_allow_in;

wire [outbus_width-2:0] exe_payload    [ISSUE-1:0]; // 不含 slot_valid；组装 ID_EXE1 时再拼 1'b1
wire                    real_taken     [ISSUE-1:0];
wire [31:0]             real_target    [ISSUE-1:0];
wire                    pred_taken     [ISSUE-1:0];
wire                    pred_valid     [ISSUE-1:0];
wire                    pred_ok        [ISSUE-1:0];
wire                    redirect       [ISSUE-1:0];
wire                    is_cond        [ISSUE-1:0];
wire                    is_call        [ISSUE-1:0];
wire                    is_ret         [ISSUE-1:0];
wire                    is_jump        [ISSUE-1:0];
wire                    is_br          [ISSUE-1:0];
wire                    is_mem         [ISSUE-1:0];
wire                    is_system_break[ISSUE-1:0];
wire                    is_csr_write   [ISSUE-1:0];
wire                    is_csr_read    [ISSUE-1:0];
wire                    is_tlb         [ISSUE-1:0];
wire [4:0]              rf_dest        [ISSUE-1:0];
wire                    rf_gr_we       [ISSUE-1:0];
wire                    update_need    [ISSUE-1:0];
wire                    bht_update_need[ISSUE-1:0];
wire                    push_need      [ISSUE-1:0];
wire                    pop_need       [ISSUE-1:0];
wire [1:0]              br_type        [ISSUE-1:0];
wire                    ex_INE         [ISSUE-1:0];
wire                    ex_IPE         [ISSUE-1:0];

generate
  for (gi = 0; gi < ISSUE; gi = gi + 1) begin : gen_alu_res
    inst_to_alu_resource #(
      .outbus_width         (outbus_width - 1           )
    ) 
    u_inst_to_alu_resource (
      .pc                   (pc[gi]                     ),
      .inst                 (inst[gi]                   ),
      .slot_valid           (slot_valid[gi]             ),
      .ex_ADEF              (ex_ADEF[gi]                ),
      .ex_tlb_reload0       (ex_tlb_reload0[gi]         ),
      .ex_tlb_preif_unvalid (ex_tlb_preif_unvalid[gi]   ),
      .ex_tlb_plv0          (ex_tlb_plv0[gi]            ),
      .btb_query_hit        (btb_query_hit[gi]          ),
      .btb_query_target     (btb_query_target[gi]       ),
      .ras_query_hit        (ras_query_hit[gi]          ),
      .ras_query_target     (ras_query_target[gi]       ),
      .query_type           (query_type[gi]             ),
      .query_taken          (query_taken[gi]            ),
      .rf_rdata1            (rf_rdata1[gi]              ),
      .rf_rdata2            (rf_rdata2[gi]              ),
      .csr_CRMD_PLV         (csr_CRMD_PLV               ),
      .has_int              ((gi == 0) ? has_int : 1'b0 ),//只在slot0判中断
      .rf_raddr1            (rf_raddr1[gi]              ),
      .rf_raddr2            (rf_raddr2[gi]              ),
      .exe_payload          (exe_payload[gi]            ),
      .real_taken           (real_taken[gi]             ),
      .real_target          (real_target[gi]            ),
      .pred_taken           (pred_taken[gi]             ),
      .pred_valid           (pred_valid[gi]             ),
      .pred_ok              (pred_ok[gi]                ),
      .redirect             (redirect[gi]               ),
      .is_cond              (is_cond[gi]                ),
      .is_call              (is_call[gi]                ),
      .is_ret               (is_ret[gi]                 ),
      .is_jump              (is_jump[gi]                ),
      .is_br                (is_br[gi]                  ),
      .is_mem               (is_mem[gi]                 ),
      .is_system_break      (is_system_break[gi]        ),  //system/break/ertn/idle/ibar/dbar/cacop
      .is_csr_write         (is_csr_write[gi]           ),    //csrwr/csrxchg
      .is_csr_read          (is_csr_read[gi]            ),     //csrrd/rdcntid/rdcntvl/rdcntdvh
      .is_tlb               (is_tlb[gi]                 ),          //tlbrd/tlbfill/tlbsrch/invtlb/tlbwr
      .rf_dest              (rf_dest[gi]                ),
      .rf_gr_we             (rf_gr_we[gi]               )
      .update_need          (update_need[gi]            ),       // pred_valid & ~ex_ADEF & ~pred_ok
      .bht_update_need      (bht_update_need[gi]        ),   // is_cond & ~ex_ADEF
      .push_need            (push_need[gi]              ),
      .pop_need             (pop_need[gi]               ),
      .br_type              (br_type[gi]                ),         // COND/JUMP/CALL/RET
      .ex_INE               (ex_INE[gi]                 ),
      .ex_IPE               (ex_IPE[gi]                 )
    );
  end
endgenerate
//------------------------{module}end--------------------------//

//------------------------{issue}begin-----------------------------//
// s1 src1/2 是 s0 的 dest 写需要下一个 clk 才能读到
wire       RAW_s1_s0                 = slot_valid[0] & slot_valid[1] & rf_gr_we[0] & (rf_dest[0] != 5'b0) &
                                       ((rf_raddr1[1] == rf_dest[0]) | (rf_raddr2[1] == rf_dest[0]));//发生写后读事件
// 写后写
wire       WAW_s1_s0                 = slot_valid[0] & slot_valid[1] & rf_gr_we[0] & rf_gr_we[1] & (rf_dest[0] != 5'b0) & (rf_dest[0] == rf_dest[1]);//发生写后写事件
//
wire       struct_comflict           = slot_valid[0] & slot_valid[1] & (
                                            (is_mem[0] & is_mem[1])                                    | // store / ld
                                            (is_system_break[0] | is_system_break[1])                  | // system/break/ertn/idle/ibar/dbar/cacop
                                            (is_csr_write[0] | is_tlb[0])                              | // 存在 csr写/tlb写 就单发
                                            (is_csr_write[1] | is_tlb[1])                              | // 存在 csr写/tlb写 就单发
                                            (is_csr_read[0]  | is_csr_read[1])                         |
                                            ((is_csr_read[0] | is_csr_write[0] | is_tlb[0]) & (is_csr_read[1] | is_csr_write[1] | is_tlb[1])) // tlb & csr / csr & csr / tlb & tlb 单发
                                        );
//  1. 如果本身不跳 但是 pc 不是 pc+4 就是错的；2.如果本身跳但是跳转错了也要冲刷
wire       pred_not_neighbor_kill_s1 = pred_not_neighbor & (~real_taken[0] | redirect[0]);//不是邻居，并且要么不是真跳转，要么要更新，即第一个跳转是错的
// 同上
wire       pred_is_neighbor_kill_s1  = pred_is_neighbor  & (real_taken[0]  | redirect[0]);//是邻居，但是要跳转或者更新
wire       slot0_fetch_ex            = ex_ADEF[0] | ex_tlb_reload0[0] | ex_tlb_preif_unvalid[0] | ex_tlb_plv0[0] | ex_INE[0] | ex_IPE[0] | has_int;

wire       kill_slot1                = slot0_fetch_ex | RAW_s1_s0 | WAW_s1_s0 | struct_comflict | pred_not_neighbor_kill_s1 | pred_is_neighbor_kill_s1 | (is_br[0] & is_br[1]);//注意这里不要走双发
wire [1:0] slot_issue                = {slot_valid[1] & ~kill_slot1, slot_valid[0]};
//------------------------{issue}end-----------------------------//

//------------------------{pred_update}begin--------------------------------------//
wire    redirect0           = slot_issue[0] & redirect[0];
wire    redirect1           = slot_issue[1] & redirect[1] & ~redirect0;//禁止双分支，slot0 跳了 slot1就不能跳

assign  br_afterpred_taken  = (redirect0 | redirect1) & can_update_pred;
assign  br_afterpred_target = redirect0 ? (real_taken[0] ? real_target[0] : (pc[0] + 32'd4)) :
                              redirect1 ? (real_taken[1] ? real_target[1] : (pc[1] + 32'd4)) :
                              32'b0;
//预测失败需要更新
wire    take_update0        = slot_issue[0] & update_need[0];//真正要更新slot0
wire    take_update1        = slot_issue[1] & update_need[1] & ~take_update0;//slot0 跳了 slot1就不能跳
// 等到 ready_go 的时候再去更新
assign  update_valid        = can_update_pred & (take_update0 | take_update1);
assign  update_pc           = take_update0 ? pc[0]          : pc[1];
assign  update_target       = take_update0 ? real_target[0] : real_target[1];
assign  update_taken        = take_update0 ? real_taken[0]  : real_taken[1];
assign  update_type         = take_update0 ? br_type[0]     : br_type[1];

assign  bht_update_valid    = can_update_pred       & (slot_issue[0] & bht_update_need[0] |
                              slot_issue[1]         & bht_update_need[1] & ~bht_update_need[0]);

wire    take_push0          = slot_issue[0] & push_need[0];
wire    take_push1          = slot_issue[1] & push_need[1] & ~take_push0;

assign  push_valid          = can_update_pred & (take_push0 | take_push1);
assign  push_target         = take_push0 ? (pc[0] + 32'd4) :
                              take_push1 ? (pc[1] + 32'd4) :
                              32'b0;
assign  pop_valid           = can_update_pred       & (slot_issue[0] & pop_need[0] |
                              slot_issue[1]         & pop_need[1] & ~pop_need[0]);
//------------------------{pred_update}begin--------------------------------------//

//------------------------{bus}begin-------------------------//
generate
    for (gi = 0; gi < ISSUE; gi = gi + 1) begin : gen_id_exe
    //最高位对应的就是slot_valid_from_decode
        assign  ID_EXE1_bus[gi] = slot_issue[gi] ? {1'b1, exe_payload[gi]} : {outbus_width{1'b0}};
    end
endgenerate
//------------------------{bus}end-------------------------//

//------------------------{ready_go}begin-------------------------//
assign  ID_ready_go = need_stall ? 1'b0 : 1'b1;

always @(posedge clk) begin
    if(!resetn)begin
        ID_valid <= 1'b0;
    end
    else if(ID_need_cancel)begin
        ID_valid <= 1'b0;
    end
    else if(ID_allow_in)begin
        ID_valid <= (redirect0 | redirect1) ? 1'b0 : IF_ID_valid;
    end
end
//------------------------{ready_go}end-------------------------//
endmodule

