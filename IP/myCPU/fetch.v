module fetch #(
    parameter  inbus_width  = 106,
    parameter  outbus_width = 138,
    parameter  ISSUE        =  2
)
(
    input  wire                    clk,
    input  wire                    resetn,
    //control signal
    input  wire                    IF_allow_in,
    output reg                     IF_valid,
    output wire                    IF_ready_go,
    input  wire [inbus_width-1:0]  preIF2_IF_bus[ISSUE - 1 : 0],
    input  wire                    preIF2_IF_valid,
    
    output wire [outbus_width-1:0] IF_ID_bus[ISSUE - 1 : 0],
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
    input  wire                    req_to_dataok_trigger
);
//------------------------{缓存inst}begin-------------------------//
/*reg [31:0] inst_reg;
reg        inst_reg_valid;
always @ (posedge clk)begin
    if(!resetn)begin
        inst_reg       <= 32'b0;
        inst_reg_valid <= 1'b0;
    end
    else if(IF_need_cancel)begin
        inst_reg_valid <= 1'b0;
    end
    else if (inst_resp_valid & req_to_dataok_trigger & ~deliver_now) begin
        // 或：~ID_allow_in 时锁存
        inst_reg       <= inst_sram_rdata;
        inst_reg_valid <= 1'b1;
    end
    else if(ID_allow_in | preIF2_IF_valid)begin
        inst_reg_valid <= 1'b0;
    end
end*/
reg [127:0] inst_line_reg;//line的数据
reg         inst_line_reg_valid;//line数据是否有效

always @(posedge clk) begin
    if (!resetn) begin
        inst_line_reg_valid <= 1'b0;
    end
    else if (IF_need_cancel) begin
        inst_line_reg_valid <= 1'b0;
    end
    else if (inst_resp_valid & req_to_dataok_trigger & ~deliver_now) begin
        inst_line_reg       <= inst_sram_rdata;
        inst_line_reg_valid <= 1'b1;
    end
    else if (deliver_now) begin
        inst_line_reg_valid <= 1'b0;
    end
end

//------------------------{缓存inst}end-------------------------//

//------------------------{bus}begin-------------------------//
wire                   slot_valid[ISSUE - 1 : 0];
wire [31:0]            pc[ISSUE - 1 : 0];
wire                   ex_ADEF[ISSUE - 1 : 0];
wire                   ex_tlb_reload0[ISSUE - 1 : 0];//tlb重填例外
wire                   ex_tlb_preif_unvalid[ISSUE - 1 : 0];//tlb中取指页无效
wire                   ex_tlb_plv0[ISSUE - 1 : 0];//tlb中页特权不合规
wire                   btb_query_hit[ISSUE - 1 : 0];//valid且tag
wire [31:0]            btb_query_target[ISSUE - 1 : 0];        
wire                   ras_query_hit[ISSUE - 1 : 0];//valid且tag
wire [31:0]            ras_query_target[ISSUE - 1 : 0];        
wire [ 1:0]            query_type[ISSUE - 1 : 0];              
wire                   query_taken[ISSUE - 1 : 0];//预测是否跳转 
        
reg  [inbus_width-1:0] bus [ISSUE - 1 : 0];
integer k;
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

genvar i;
generate
    for (i = 0; i < ISSUE; i = i + 1) begin 
        assign {slot_valid[i], pc[i], ex_ADEF[i], ex_tlb_reload0[i],
            ex_tlb_preif_unvalid[i], ex_tlb_plv0[i],
            btb_query_hit[i], btb_query_target[i],
            ras_query_hit[i], ras_query_target[i],
            query_type[i], query_taken[i]} = bus[i];
    end
endgenerate

//------------------------{bus}end-------------------------//

//------------------------{ready_go}begin-------------------------//
wire    inst_resp_valid = inst_sram_data_ok & ~inst_resp_discard;//request 是有效的,discard表示已经发起req但是被取消，那么其返回的data_ok应是无效的,所以用discard取消
wire    deliver_now = IF_valid & IF_ready_go & ID_allow_in & ~need_stall & ~IF_need_cancel;
wire    slot0_has_ex = ex_ADEF[0] | ex_tlb_reload0[0] |
                       ex_tlb_preif_unvalid[0] | ex_tlb_plv0[0];
// 与 Pre_IF2 一致：空槽 / 例外不访存
wire no_need_mem = (~slot_valid[0]) | slot0_has_ex;
// 正常取指：data_ok（本拍）或 line 已锁存
wire mem_ready = (inst_resp_valid & req_to_dataok_trigger) | inst_line_reg_valid;

assign  IF_ready_go = (need_stall | IF_need_cancel) ? 1'b0 :
                      no_need_mem                   ? 1'b1 :
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
//------------------------{ready_go}end-------------------------//

wire [127 : 0] inst_line_use = inst_line_reg_valid ? inst_line_reg : inst_sram_rdata;
wire [31:0] inst_from_line[ISSUE - 1 : 0];//从line中拿到的inst
wire [31:0] inst_out      [ISSUE - 1 : 0];//从IF传递到ID的inst
generate
    for (i = 0; i < ISSUE; i = i + 1) begin 
        assign inst_from_line[i] =  (pc[i][3:2] == 2'b00) ? inst_line_use[31:0]   :
                                    (pc[i][3:2] == 2'b01) ? inst_line_use[63:32]  :
                                    (pc[i][3:2] == 2'b10) ? inst_line_use[95:64]  :
                                    inst_line_use[127:96];
        assign inst_out[i]       =  (no_need_mem | ~slot_valid[i]) ? 32'b0 : inst_from_line[i];
        assign IF_ID_bus[i]      = slot_valid[i] ? {
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
