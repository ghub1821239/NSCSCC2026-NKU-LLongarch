module fetch #(
    parameter  inbus_width  = 106,
    parameter  outbus_width = 138,
    parameter  ISSUE        = 2
)
(
    input  wire                    clk,
    input  wire                    resetn,
    //control signal
    input  wire                    IF_allow_in,
    output reg                     IF_valid,
    output wire                    IF_ready_go,
    input  wire [inbus_width-1:0]  preIF2_IF_bus        [1:0],
    input  wire                    preIF2_IF_valid,
    
    output wire [outbus_width-1:0] IF_ID_bus            [1:0],
    //cancel
    input  wire                    IF_need_cancel,
    //stall
    input  wire                    need_stall,
    //handshake
    input  wire                    inst_sram_data_ok,
    input  wire [127:0]            inst_sram_rdata,
    input  wire                    ID_allow_in,
    input  wire                    inst_resp_discard,
    //req_to_dataok_trigger
    input  wire                    req_to_dataok_trigger,
    input  wire                    ID_can_accept_IF,
    //skid
    input  wire                    skid_valid
);
//------------------------{ICache line queue}begin-------------------------//
// IFQ(2) + IF(1) 最多 3 条已返回、尚未交给 ID 的 cache line。
// data_ok 入队；IF 交出真正取指包时出队；空槽/例外包不出队。
localparam LINE_Q_DEPTH = 3;
localparam LINE_Q_PTR_W = 2;

reg  [127:0]              line_q      [LINE_Q_DEPTH-1:0];
reg  [LINE_Q_PTR_W:0]     line_q_count; // 已缓存、未交付的 line 数
reg  [LINE_Q_PTR_W-1:0]   line_q_wr;
reg  [LINE_Q_PTR_W-1:0]   line_q_rd;

wire line_q_push  = inst_resp_valid & req_to_dataok_trigger; // ICache 返回有效 line
wire line_q_pop   = deliver_now & ~no_need_mem;             // 取指包从 IF 交到 ID
wire line_q_empty = (line_q_count == {LINE_Q_PTR_W+1{1'b0}});

wire [LINE_Q_PTR_W-1:0] line_q_wr_next = (line_q_wr == (LINE_Q_DEPTH-1)) ? {LINE_Q_PTR_W{1'b0}} : (line_q_wr + 1'b1);
wire [LINE_Q_PTR_W-1:0] line_q_rd_next = (line_q_rd == (LINE_Q_DEPTH-1)) ? {LINE_Q_PTR_W{1'b0}} : (line_q_rd + 1'b1);

always @(posedge clk) begin
    if (!resetn) begin
        line_q_count <= {LINE_Q_PTR_W+1{1'b0}};
        line_q_wr    <= {LINE_Q_PTR_W{1'b0}};
        line_q_rd    <= {LINE_Q_PTR_W{1'b0}};
    end
    else if (IF_need_cancel) begin
        line_q_count <= {LINE_Q_PTR_W+1{1'b0}};
        line_q_wr    <= {LINE_Q_PTR_W{1'b0}};
        line_q_rd    <= {LINE_Q_PTR_W{1'b0}};
    end
    else begin
        if (line_q_push) begin
            line_q[line_q_wr] <= inst_sram_rdata;
            line_q_wr         <= line_q_wr_next;
        end
        if (line_q_pop) begin
            line_q_rd <= line_q_rd_next;
        end
        case ({line_q_push, line_q_pop})
            2'b10:   line_q_count <= line_q_count + 1'b1;
            2'b01:   line_q_count <= line_q_count - 1'b1;
            default: line_q_count <= line_q_count;
        endcase
    end
end
//------------------------{ICache line queue}end-------------------------//

//------------------------{bus}begin-------------------------//
wire                      slot_valid          [1:0];
wire    [31:0]            pc                  [1:0];
wire                      ex_ADEF             [1:0];
wire                      ex_tlb_reload0      [1:0]; // tlb 重填例外
wire                      ex_tlb_preif_unvalid[1:0]; // tlb 取指页无效
wire                      ex_tlb_plv0         [1:0]; // tlb 页特权不合规
wire                      btb_query_hit       [1:0]; // valid 且 tag 命中
wire    [31:0]            btb_query_target    [1:0];
wire                      ras_query_hit       [1:0]; // valid 且 tag 命中
wire    [31:0]            ras_query_target    [1:0];
wire    [ 1:0]            query_type          [1:0];
wire                      query_taken         [1:0]; // 预测是否跳转 
        
reg     [inbus_width-1:0] bus                 [1:0];
integer                   k;
always @(posedge clk)begin
    if(!resetn)begin
        for (k = 0; k < ISSUE; k = k + 1) begin
            bus[k] <= {inbus_width{1'b0}};
        end
    end
    else if(preIF2_IF_valid && IF_allow_in) begin
        for (k = 0; k < ISSUE; k = k + 1) begin
            bus[k] <= preIF2_IF_bus[k];
        end
    end
end

genvar  i;
generate
    for (i = 0; i < ISSUE; i = i + 1) begin:gen_bus_unpack
        assign {slot_valid[i]          , pc[i]              , ex_ADEF[i], ex_tlb_reload0[i],
                ex_tlb_preif_unvalid[i], ex_tlb_plv0[i]     ,
                btb_query_hit[i]       , btb_query_target[i],
                ras_query_hit[i]       , ras_query_target[i],
                query_type[i]          , query_taken[i]} = bus[i];
    end
endgenerate

//------------------------{bus}end-------------------------//

//------------------------{ready_go}begin-------------------------//
wire    inst_resp_valid = inst_sram_data_ok & ~inst_resp_discard; // 已发起的 req 被取消时，其 data_ok 无效
wire    deliver_now     = IF_valid & IF_ready_go & ~skid_valid;
wire    slot0_has_ex    = ex_ADEF[0]              | ex_tlb_reload0[0] |
                          ex_tlb_preif_unvalid[0] | ex_tlb_plv0[0]   ;
// 与 Pre_IF2 一致：空槽 / 例外不访存
wire    no_need_mem     = (~slot_valid[0]) | slot0_has_ex;
// 队列已有本包 line，或本拍 data_ok（队列空时走组合 rdata）
wire    mem_ready       = ~line_q_empty | (inst_sram_data_ok & req_to_dataok_trigger);

assign  IF_ready_go     = no_need_mem    ? 1'b1 :
                          mem_ready;
//------------------------{ready_go}end-------------------------//

always @(posedge clk) begin
    if(!resetn)begin
        IF_valid <= 1'b0;
    end
    else if (IF_need_cancel)begin
        IF_valid <= 1'b0;
    end  
    else if(IF_allow_in)begin
        IF_valid <= preIF2_IF_valid;
    end
end

wire [127:0]   inst_line_use = ~line_q_empty ? line_q[line_q_rd] : inst_sram_rdata;
wire [31:0]    inst_from_line[1:0]; // 按 PC[3:2] 从 line 中取出指令
wire [31:0]    inst_out      [1:0]; // 送到 ID 的指令字
generate
    for (i = 0; i < ISSUE; i = i + 1) begin :gen_inst_out
        assign  inst_from_line[i] = (pc[i][3:2] == 2'b00) ? inst_line_use[31:0]   :
                                    (pc[i][3:2] == 2'b01) ? inst_line_use[63:32]  :
                                    (pc[i][3:2] == 2'b10) ? inst_line_use[95:64]  :
                                    inst_line_use[127:96];
        assign  inst_out[i]       = (no_need_mem | ~slot_valid[i]) ? 32'b0 : inst_from_line[i];
        assign  IF_ID_bus[i]      = slot_valid[i] ? {
                                    slot_valid[i],
                                    pc[i],
                                    inst_out[i],
                                    ex_ADEF[i],
                                    ex_tlb_reload0[i],
                                    ex_tlb_preif_unvalid[i],
                                    ex_tlb_plv0[i],
                                    btb_query_hit[i],
                                    btb_query_target[i],
                                    ras_query_hit[i],
                                    ras_query_target[i],
                                    query_type[i],
                                    query_taken[i]
                                    } : {outbus_width{1'b0}};
    end
endgenerate

endmodule
