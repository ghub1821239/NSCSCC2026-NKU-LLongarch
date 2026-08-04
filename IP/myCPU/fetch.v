module fetch #(
    parameter inbus_width  = 32,
    parameter outbus_width = 64
)
(
    input  wire        clk,
    input  wire        resetn,
    //control signal
    input  wire        IF_allow_in,
    output reg         IF_valid,
    output wire        IF_ready_go,
    input  wire [inbus_width-1:0] preIF2_IF_bus,
    input  wire        preIF2_IF_valid,
    
    output wire [outbus_width-1:0] IF_ID_bus,
    //cancel
    input  wire        need_cancel,
    //stall
    input  wire        need_stall,
    //handshake
    input  wire        inst_sram_data_ok,
    input  wire [31:0] inst_sram_rdata,
    input  wire        ID_allow_in,
    input  wire        inst_resp_discard,
    //req_to_dataok_trigger
    input  wire        req_to_dataok_trigger
);
//------------------------{����inst}begin-------------------------//
reg [31:0] inst_reg;
reg        inst_reg_valid;
always @ (posedge clk)begin
    if(!resetn)begin
        inst_reg <= 32'b0;
        inst_reg_valid <= 1'b0;
    end
    else if(need_cancel)begin
        inst_reg_valid <= 1'b0;
    end
   /* else if(inst_sram_data_ok & ~inst_resp_discard)begin
        inst_reg <= inst_sram_rdata;
        inst_reg_valid <= 1'b1;
    end
    // ͬʱ����ôҲ��ȡ��������Ϊ�Ѿ��յ���discard
    else if(inst_sram_data_ok & inst_resp_discard)begin
        inst_reg_valid <= 1'b0;
    end*/
    else if (inst_resp_valid & req_to_dataok_trigger & ~deliver_now) begin
        // 或：~ID_allow_in 时锁存
        inst_reg       <= inst_sram_rdata;
        inst_reg_valid <= 1'b1;
    end
    else if(ID_allow_in | preIF2_IF_valid)begin
        inst_reg_valid <= 1'b0;
    end
end
//------------------------{����inst}end-------------------------//

//------------------------{bus}begin-------------------------//
wire [31:0] pc;
wire        ex_ADEF;
wire        ex_tlb_reload0;//tlb��������
wire        ex_tlb_preif_unvalid;//tlb��ȡָҳ��Ч
wire        ex_tlb_plv0;//tlb��ҳ��Ȩ���Ϲ�
wire        btb_query_hit;//valid��tag
wire [31:0] btb_query_target;        
wire        ras_query_hit;//valid��tag
wire [31:0] ras_query_target;        
wire [ 1:0] query_type;              
wire        query_taken;//Ԥ���Ƿ���ת 
        
reg [inbus_width-1:0] bus;
always @(posedge clk)begin
    if(!resetn)begin
        bus<={inbus_width{1'b0}};
    end
    else if(preIF2_IF_valid && IF_allow_in) begin
        bus<=preIF2_IF_bus;
    end
end
assign {pc,ex_ADEF,ex_tlb_reload0,ex_tlb_preif_unvalid,ex_tlb_plv0,
        btb_query_hit,btb_query_target,ras_query_hit,ras_query_target,query_type,query_taken} = bus;
assign IF_ID_bus=inst_reg_valid ? {pc,inst_reg,ex_ADEF,ex_tlb_reload0,ex_tlb_preif_unvalid,ex_tlb_plv0,
                                   btb_query_hit,btb_query_target,ras_query_hit,ras_query_target,query_type,query_taken} :
                 {pc,inst_sram_rdata,ex_ADEF,ex_tlb_reload0,ex_tlb_preif_unvalid,ex_tlb_plv0,
                  btb_query_hit,btb_query_target,ras_query_hit,ras_query_target,query_type,query_taken};
//------------------------{bus}end-------------------------//

//------------------------{ready_go}begin-------------------------//
wire inst_resp_valid = inst_sram_data_ok & ~inst_resp_discard;
// 本拍若 IF 能把当前指令交给 ID，则优先走旁路 rdata，不必依赖 reg 当 ready
wire deliver_now = IF_valid & inst_resp_valid & req_to_dataok_trigger & ID_allow_in
                 & ~need_stall & ~need_cancel;

assign IF_ready_go = (need_stall | need_cancel) ? 1'b0 :
                     (inst_resp_valid & req_to_dataok_trigger) | inst_reg_valid;
always @(posedge clk) begin
    if(!resetn)begin
        IF_valid<=1'b0;
    end
    else if (need_cancel)begin
        IF_valid<=1'b0;
    end  
    else if(IF_allow_in)begin
        IF_valid<=preIF2_IF_valid;
    end
end
//------------------------{ready_go}end-------------------------//
endmodule
