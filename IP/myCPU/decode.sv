module decode #(
    parameter  inbus_width  = 148,
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
    input  wire [inbus_width-1:0]  IF_ID_bus          [ISSUE - 1 : 0],//bus
    output wire [outbus_width-1:0] ID_EXE1_bus        [ISSUE - 1 : 0],
    //regfile
        // addr
    output wire [4:0]              rf_raddr1          [ISSUE - 1 : 0],
    output wire [4:0]              rf_raddr2          [ISSUE - 1 : 0],
        // data
    input  wire [31:0]             rf_rdata1          [ISSUE - 1 : 0],
    input  wire [31:0]             rf_rdata2          [ISSUE - 1 : 0],
        // br相关使用的都是非ld前递的
    input  wire [31:0]             br_rdata1          [ISSUE - 1 : 0],
    input  wire [31:0]             br_rdata2          [ISSUE - 1 : 0],
    output wire                    br_use_rj          [ISSUE - 1 : 0],
    output wire                    br_use_rk          [ISSUE - 1 : 0],
    output wire                    ID_need_alu1_rj   [ISSUE - 1 : 0],
    output wire                    ID_need_src2_withST   [ISSUE - 1 : 0],
    output wire                    ID_need_alu2_rk[ISSUE - 1 : 0],
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
    output wire                    update_valid,
    output wire                    bht_update_valid,
    output wire [31:0]             bht_update_pc,
    output wire                    bht_update_taken,
    output wire [31:0]             update_pc,
    output wire [31:0]             update_target,//真实目标地址
    output wire [1:0]              update_type,
    output wire                    update_taken,//真实是否跳转
    // 是不是 call 调用
    output wire                    push_valid,
    output wire [31:0]             push_target,
    // 是不是 return 返回
    output wire                    pop_valid,
    //PLV
    input  wire [1:0]              csr_CRMD_PLV,
    //ID_can_accept_IF
    output wire                    ID_can_accept_IF
);
wire                    id_fire         = ID_valid & ID_ready_go & ~ID_need_cancel & ID_allow_in;
//------------------------{bus decode}begin-------------------------//
reg     [inbus_width-1:0] bus         [ISSUE - 1 : 0];
reg                       bus_has_inst;//bus中有未完成的IF的指令

integer                   k;
always @(posedge clk)begin
    if(!resetn || ID_need_cancel)begin
        for (k = 0; k < ISSUE; k = k + 1) begin
            bus[k]       <= {inbus_width{1'b0}};
        end
        bus_has_inst <= 1'b0;
    end
    else if (id_fire & (redirect0 | redirect1))begin
        for (k = 0; k < ISSUE; k = k + 1) begin
            bus[k]       <= {inbus_width{1'b0}};
        end
        bus_has_inst <= 1'b0;
    end
    else if (accept_IF_in_bus) begin
        for (k = 0; k < ISSUE; k = k + 1) begin
            bus[k]       <= IF_ID_bus[k];
        end
        bus_has_inst <= 1'b1;
    end
    else if(consume_bus) begin
        for (k = 0; k < ISSUE; k = k + 1) begin
            bus[k]       <= {inbus_width{1'b0}};
        end
        bus_has_inst <= 1'b0;
    end
end
wire        slot_valid          [ISSUE - 1 : 0];
wire [31:0] pc                  [ISSUE - 1 : 0];
wire [31:0] inst                [ISSUE - 1 : 0];
wire [ 4:0] pre_raddr1_eff      [ISSUE - 1 : 0];
wire [ 4:0] pre_raddr2_eff      [ISSUE - 1 : 0];
wire        ex_ADEF             [ISSUE - 1 : 0];
wire        ex_tlb_reload0      [ISSUE - 1 : 0];//tlb重填异常
wire        ex_tlb_preif_unvalid[ISSUE - 1 : 0];//tlb的取指页无效
wire        ex_tlb_plv0         [ISSUE - 1 : 0];//tlb的页权限非法

wire        btb_query_hit       [ISSUE - 1 : 0];//valid且tag
wire [31:0] btb_query_target    [ISSUE - 1 : 0];        
wire        ras_query_hit       [ISSUE - 1 : 0];//valid且tag
wire [31:0] ras_query_target    [ISSUE - 1 : 0];        
wire [ 1:0] query_type          [ISSUE - 1 : 0];              
wire        query_taken         [ISSUE - 1 : 0];//预测是否跳转 

wire        bus0_valid           = bus[0][inbus_width-1];
wire        bus1_valid           = bus[1][inbus_width-1];

//-------------------------{hold}begin---------------------------------------------//
reg                        hold_valid;
reg    [inbus_width-1:0]   hold_bus;
wire   [inbus_width-1 : 0] bus_eff              [ISSUE - 1 : 0];//有效包，经过hold筛选后的bus
wire                       create_hold;//hold开始信号
wire                       update_hold;//hold更新信号
wire                       clear_hold;//hold清空信号
wire                       packed_mode;

//assign create_hold = id_fire & soft_kill_slot1 & slot_issue[0];
//assign drain_hold  = id_fire & hold_valid;//
//assign packed_mode = hold_valid & bus_has_inst;

wire                       create_hold_from_soft = id_fire & ~hold_valid & soft_kill_slot1;//无hold指令，soft kill只发出slot0到后端，slot1住hold
wire                       create_hold_from_tail = id_fire & hold_valid & bus_has_inst & slot_issue[0] & slot_issue[1] & bus1_valid;//重新拼包且双发成功，且原始包的slot1进hold
wire                       pack_soft_keep_bus    = id_fire & hold_valid & slot_issue[0] & ~slot_issue[1] & soft_kill_slot1;//hold与下一条指令重新拼包后soft kill,则hold指令下一条指令留在bus
wire                       consume_for_accept;

wire                       consume_bus           = id_fire & bus_has_inst & ~pack_soft_keep_bus & (
                                                   //无hold指令并且发出slot0
                                                   (~hold_valid & slot_issue[0]) |
                                                   //重新拼包后next发出或者被hard丢弃
                                                   (hold_valid & (slot_issue[1] | hard_kill_slot1))
                                                   );
wire                       accept_IF_in_bus      = IF_ID_valid & ID_allow_in & (~bus_has_inst | consume_for_accept);
wire   [inbus_width-1 : 0] hold_din              = create_hold_from_soft ? bus_eff[1] :
                                                   create_hold_from_tail ? bus[1]     :
                                                                           hold_bus;

//output
assign                     ID_can_accept_IF      = (~bus_has_inst | consume_for_accept) &
                                                   ~(ID_need_cancel);

always @(posedge clk) begin
    if (!resetn) begin
        hold_valid <= 1'b0;
        hold_bus   <= {inbus_width{1'b0}};
    end
    else if (ID_need_cancel) begin
        hold_valid <= 1'b0;
    end
    else if (id_fire & (redirect0 | redirect1)) begin
        hold_valid <= 1'b0;
    end
    else if (create_hold_from_soft | create_hold_from_tail) begin
        hold_valid <= 1'b1;
        hold_bus   <= hold_din;
    end
    else if (id_fire & hold_valid & slot_issue[0]) begin
        hold_valid <= 1'b0;
    end
end

//-------------------------{hold}end---------------------------------------------//
assign  bus_eff[0] = hold_valid ? hold_bus : bus[0];
assign  bus_eff[1] = hold_valid ? bus[0] : bus[1];
genvar  gi;
generate
    for (gi = 0; gi < ISSUE; gi = gi + 1) begin : gen_i 
         assign {
                 slot_valid[gi]          ,
                 pc[gi]                  ,
                 inst[gi]                ,
                 pre_raddr1_eff[gi]      ,
                 pre_raddr2_eff[gi]      ,
                 ex_ADEF[gi]             ,
                 ex_tlb_reload0[gi]      ,
                 ex_tlb_preif_unvalid[gi],
                 ex_tlb_plv0[gi]         ,
                 btb_query_hit[gi]       ,
                 btb_query_target[gi]    ,
                 ras_query_hit[gi]       ,
                 ras_query_target[gi]    ,
                 query_type[gi]          ,
                 query_taken[gi]
                } = bus_eff[gi];
         assign  rf_raddr1[gi] = pre_raddr1_eff[gi];
         assign  rf_raddr2[gi] = pre_raddr2_eff[gi];
    end 
endgenerate

wire  pred_not_neighbor = slot_valid[0] & slot_valid[1] & (pc[1] != (pc[0] + 32'd4));
wire  pred_is_neighbor  = slot_valid[0] & slot_valid[1] & (pc[1] == (pc[0] + 32'd4));
//------------------------{bus decode}end-------------------------//

//------------------------{module}begin--------------------------//

wire [outbus_width-2:0] exe_payload    [ISSUE-1:0];
wire                    real_taken     [ISSUE-1:0];
wire [31:0]             real_target    [ISSUE-1:0];
wire                    target_not_seq [ISSUE-1:0];
wire                    pred_taken     [ISSUE-1:0];
wire                    pred_valid     [ISSUE-1:0];
wire                    pred_ok        [ISSUE-1:0];
wire                    redirect_lane  [ISSUE-1:0];
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
// 若按上面加了可选端口：
wire                    upd_need       [ISSUE-1:0];
wire                    bht_upd_need   [ISSUE-1:0];
wire                    push_need      [ISSUE-1:0];
wire                    pop_need       [ISSUE-1:0];
wire [1:0]              br_type        [ISSUE-1:0];
wire                    ex_INE         [ISSUE-1:0];
wire                    ex_IPE         [ISSUE-1:0];

generate
  for (gi = 0; gi < ISSUE; gi = gi + 1) begin : gen_alu_res
    inst_to_alu_resource #(
      .outbus_width         (outbus_width               )
    ) u_inst_to_alu (
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
      .br_rdata1            (br_rdata1[gi]              ),
      .br_rdata2            (br_rdata2[gi]              ),
      .br_use_rj            (br_use_rj[gi]              ),
      .br_use_rk            (br_use_rk[gi]              ),
      .ID_need_alu1_rj     (ID_need_alu1_rj[gi]    ),
      .ID_need_src2_withST     (ID_need_src2_withST[gi]    ),
      .ID_need_alu2_rk  (ID_need_alu2_rk[gi] ),

      .csr_CRMD_PLV         (csr_CRMD_PLV               ),
      .has_int              ((gi == 0) ? has_int : 1'b0 ),//只在slot0判中断
      //.id_fire              (id_fire & slot_valid[gi]), 
      .exe_payload          (exe_payload[gi]            ),
      .real_taken           (real_taken[gi]             ),
      .real_target          (real_target[gi]            ),
      .target_not_seq       (target_not_seq[gi]         ),
      .pred_taken           (pred_taken[gi]             ),
      .pred_valid           (pred_valid[gi]             ),
      .pred_ok              (pred_ok[gi]                ),
      .redirect             (redirect_lane[gi]          ),
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
      .rf_gr_we             (rf_gr_we[gi]               ),
      // .upd_need(upd_need[gi]), ...
      .upd_need             (upd_need[gi]               ),       // pred_valid & ~ex_ADEF & ~pred_ok
      .bht_upd_need         (bht_upd_need[gi]           ),   // is_cond & ~ex_ADEF
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
wire       RAW_s1_s0                 = slot_valid[0] & slot_valid[1] & rf_gr_we[0] & (rf_dest[0] != 5'b0) &
                                       ((rf_raddr1[1] == rf_dest[0]) | (rf_raddr2[1] == rf_dest[0]));//发生写后读事件
wire       WAW_s1_s0                 = slot_valid[0] & slot_valid[1] & rf_gr_we[0] & rf_gr_we[1] & (rf_dest[0] != 5'b0) & (rf_dest[0] == rf_dest[1]);//发生写后写事件
wire       struct_comflict           =  slot_valid[0] & slot_valid[1] & ((is_mem[0] & is_mem[1]) |
                                       (is_system_break[0]                                       | is_system_break[1])         |
                                       ((is_csr_write[0]                                         | is_tlb[0]) & slot_valid[1]) |
                                       ((is_csr_write[1]                                         | is_tlb[1]) & slot_valid[0]) |
                                       (is_csr_read[0]                                           | is_csr_read[1])             |
                                       (slot_valid[0] & (is_csr_read[0]                          | is_csr_write[0]             | is_tlb[0]) & slot_valid[1] & (is_csr_read[1] | is_csr_write[1] | is_tlb[1])));

wire       pred_not_neighbor_kill_s1 = pred_not_neighbor & (~real_taken[0] | redirect_lane[0]);//不是邻居，并且要么不是真跳转，要么要更新，即第一个跳转是错的
wire       pred_is_neighbor_kill_s1  = pred_is_neighbor  & (real_taken[0] & target_not_seq[0] | redirect_lane[0]);//是邻居，但是要跳转或者更新
wire       slot0_fetch_ex            = ex_ADEF[0] | ex_tlb_reload0[0] | ex_tlb_preif_unvalid[0] | ex_tlb_plv0[0] | ex_INE[0] | ex_IPE[0] | has_int;

wire       slot0_trap                = slot_valid[0] & (ex_ADEF[0] | ex_tlb_reload0[0] |
                                       ex_tlb_preif_unvalid[0]     | ex_tlb_plv0[0]    |
                                       ex_INE[0]                   | ex_IPE[0]         | has_int);//会让slot1被杀的情况，名字叫slot0陷阱
wire       hard_kill_slot1           = slot0_trap | pred_not_neighbor_kill_s1 | pred_is_neighbor_kill_s1;//直接不要slot1,这里的逻辑是如果预测正确则至多soft kill,只有预测错误或者异常才会是hard kill被直接丢弃
wire       soft_kill_slot1           = slot_valid[0] & slot_valid[1] & ~hard_kill_slot1 & (
                                       RAW_s1_s0 | WAW_s1_s0 | struct_comflict | (is_br[0] & is_br[1]));//slot1只是暂时发不了，不能丢弃
wire       kill_slot1                = hard_kill_slot1 | soft_kill_slot1;
//wire kill_slot1 = slot0_fetch_ex | RAW_s1_s0 | WAW_s1_s0 | struct_comflict | pred_not_neighbor_kill_s1 | pred_is_neighbor_kill_s1 | (is_br[0] & is_br[1]);//注意这里不要走双分支
wire [1:0] slot_issue                = {slot_valid[1] & ~kill_slot1, slot_valid[0]};

// slot0有异常，强制杀
wire       hard_kill_no_br           = slot0_trap;
// slot0是st/ld/cacop这种我们不让发
wire       soft_kill_no_br           = slot_valid[0] & slot_valid[1] & ~hard_kill_no_br & (
                                       RAW_s1_s0 | WAW_s1_s0 | struct_comflict | (is_br[0] & is_br[1]));
// 以上两种都不是就可以发
wire       slot_issue1_no_br         = slot_valid[1] & ~hard_kill_no_br & ~soft_kill_no_br;
// hold_valid 时，effective slot0 来自 hold_bus；
// slot0 发射，但 effective slot1（原 bus[0]）因 soft kill 未发射，
// 因此原 bus 必须保留。
wire       pack_keep_no_br           = id_fire & hold_valid & slot_issue[0] & ~slot_issue1_no_br & soft_kill_no_br;
// bus这拍结束后能不能换成新包
assign     consume_for_accept        = id_fire & bus_has_inst & ~pack_keep_no_br & (
                                       (~hold_valid & slot_issue[0]) |
                                       (hold_valid & (slot_issue1_no_br | hard_kill_no_br))
                                       );
//------------------------{issue}end-----------------------------//

//------------------------{pred_update}begin--------------------------------------//
wire    redirect0           = redirect_lane[0];//inst_to_alu_resource中会保证valid的
wire    redirect1           = slot_issue[1] & redirect_lane[1] & ~redirect0;//禁止双分支

assign  br_afterpred_taken  = (redirect0 | redirect1) & id_fire;
assign  br_afterpred_target = redirect0 ? (real_taken[0] ? real_target[0] : (pc[0] + 32'd4)) :
                              redirect1 ? (real_taken[1] ? real_target[1] : (pc[1] + 32'd4)) :
                                          32'b0;

wire    take_update0        = slot_issue[0] & upd_need[0];//真正要更新slot0
wire    take_update1        = slot_issue[1] & upd_need[1] & ~take_update0;//真正要更新slot1

assign  update_valid        = id_fire & (take_update0 | take_update1);
assign  update_pc           = take_update0 ? pc[0]          : pc[1];
assign  update_target       = take_update0 ? real_target[0] : real_target[1];
assign  update_taken        = take_update0 ? real_taken[0]  : real_taken[1];
assign  update_type         = take_update0 ? br_type[0]     : br_type[1];

wire    take_bht0           = slot_issue[0] & bht_upd_need[0];
wire    take_bht1           = slot_issue[1] & bht_upd_need[1] & ~take_bht0;
assign  bht_update_valid    = id_fire & (take_bht0 | take_bht1);
assign  bht_update_pc       = take_bht0 ? pc[0]         : pc[1];
assign  bht_update_taken    = take_bht0 ? real_taken[0] : real_taken[1];

wire    take_push0          = slot_issue[0] & push_need[0];
wire    take_push1          = slot_issue[1] & push_need[1] & ~take_push0;

assign  push_valid          = id_fire & (take_push0 | take_push1);
assign  push_target         = take_push0 ? (pc[0] + 32'd4) :
                              take_push1 ? (pc[1] + 32'd4) :
                                           32'b0;
assign  pop_valid           = id_fire       & (slot_issue[0] & pop_need[0] |
                              slot_issue[1] & pop_need[1] & ~pop_need[0]);
//------------------------{pred_update}end--------------------------------------//

//------------------------{bus}begin-------------------------//
//try to minimize the bus_size
generate
    for (gi = 0; gi < ISSUE; gi = gi + 1) begin : gen_id_exe
        assign  ID_EXE1_bus[gi] = slot_issue[gi] ? {1'b1,exe_payload[gi]} : {outbus_width{1'b0}};
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
        if (id_fire & (redirect0 | redirect1)) begin
            ID_valid <= 1'b0;
        end
        else begin 
            ID_valid <= (create_hold_from_soft | create_hold_from_tail) |
                        (hold_valid & ~(id_fire & slot_issue[0] & ~create_hold_from_tail)) |
                        (accept_IF_in_bus) |
                        (bus_has_inst & ~consume_bus) | 
                        (IF_ID_valid & ~accept_IF_in_bus & ~bus_has_inst & 
                        ~(hold_valid | create_hold_from_soft | create_hold_from_tail));
        end
    end
end
//------------------------{ready_go}end-------------------------//
endmodule
