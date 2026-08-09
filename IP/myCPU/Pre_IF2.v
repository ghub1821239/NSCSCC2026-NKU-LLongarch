module pre_IF2 #(
    parameter  slot0_inbus_width = 144,
    parameter  inbus_width       = 142,
    parameter  outbus_width      = 32,
    parameter  ISSUE             = 2
)
(
    input  wire                    clk,
    input  wire                    resetn,
    //control signal
    input  wire                    preIF1_preIF2_valid,
    input  wire                    preIF2_allow_in,
    output reg                     preIF2_valid,
    output wire                    preIF2_ready_go,
    
    input  wire [slot0_inbus_width-1:0] preIF1_preIF2_bus_slot0,
    input  wire [inbus_width-1:0]       preIF1_preIF2_bus [ISSUE-1:1],
    output wire [outbus_width-1:0]      preIF2_IF_bus [ISSUE-1:0],//bus
    //br_taken
    input  wire                    br_taken,
    //cancel
    input  wire                    preIF2_need_cancel,
    //stall
    input  wire                    need_stall,
    //handshake
    output wire                    inst_sram_req,
    output wire                    inst_sram_wr, // 1表示需要write 0表示需要read
    output wire [ 3:0]             inst_sram_wstrb,// wstrb也就是表示需要写的位置 0 1 2 分别对应b h w 
    output wire [ 1:0]             inst_sram_size,
    output wire [31:0]             inst_sram_addr_without_cacop,
    output wire [31:0]             inst_sram_wdata,
    input  wire                    inst_sram_addr_ok,
    input  wire                    IF_allow_in,
    input  wire                    inst_sram_data_ok,
    //req&addr -> 1 dataok->0
    output wire                    req_to_dataok_trigger,
    // 当前返回属于已被跳转/异常取消的取指请求
    output wire                    inst_resp_discard,
    //CRMD PG DA
    input  wire                    csr_CRMD_DA,
    input  wire                    csr_CRMD_PG,
    //还有s0_mat上面已经定义过了    // tlb页表映射
    output wire [1:0]              inst_mat,
    output wire                    inst_wr
);
//------------------------{bus}begin-------------------------//
wire                   slot_valid [ISSUE-1:0];
wire [31:0]            pc [ISSUE-1:0];
wire                   ex_ADEF [ISSUE-1:0];
wire                   ex_tlb_reload0 [ISSUE-1:0];//tlb重填例外
wire                   ex_tlb_preif_unvalid [ISSUE-1:0];//tlb中取指页无效
wire                   ex_tlb_plv0 [ISSUE-1:0];//tlb中页特权不合规
wire                   dmw_found0 [ISSUE-1:0];
wire [2:0]             dmw_pseg0 [ISSUE-1:0];
wire [31:0]            tlb_paddr [ISSUE-1:0];
wire                   btb_query_hit [ISSUE-1:0];//valid且tag
wire [31:0]            btb_query_target [ISSUE-1:0];        
wire                   ras_query_hit [ISSUE-1:0];//valid且tag
wire [31:0]            ras_query_target [ISSUE-1:0];        
wire [ 1:0]            query_type [ISSUE-1:0];              
wire                   query_taken [ISSUE-1:0];//预测是否跳转  

reg                    req_without_dataok;   

wire                   inst_req_accept      = inst_sram_req && inst_sram_addr_ok;
        
reg  [slot0_inbus_width-1:0] bus_slot0;
reg  [inbus_width-1:0]       bus [ISSUE-1:1];

genvar i;
always @(posedge clk) begin
    if (!resetn) begin
        bus_slot0 <= {slot0_inbus_width{1'b0}};
    end
    else if (preIF1_preIF2_valid && preIF2_allow_in) begin
        bus_slot0 <= preIF1_preIF2_bus_slot0;
    end
end

assign {slot_valid[0],pc[0],ex_ADEF[0],ex_tlb_reload0[0],ex_tlb_preif_unvalid[0],ex_tlb_plv0[0],
        dmw_found0[0],dmw_pseg0[0],inst_mat,tlb_paddr[0],
        btb_query_hit[0],btb_query_target[0],ras_query_hit[0],ras_query_target[0],query_type[0],query_taken[0]}=bus_slot0;

generate 
    for(i=1;i<ISSUE;i=i+1)begin:gen_bus
        always @(posedge clk)begin
            if(!resetn)begin
                bus[i] <= {inbus_width{1'b0}};
            end
            else if(preIF1_preIF2_valid && preIF2_allow_in) begin
                bus[i] <= preIF1_preIF2_bus[i];
            end
        end
        assign {slot_valid[i],pc[i],ex_ADEF[i],ex_tlb_reload0[i],ex_tlb_preif_unvalid[i],ex_tlb_plv0[i],
                dmw_found0[i],dmw_pseg0[i],tlb_paddr[i],
                btb_query_hit[i],btb_query_target[i],ras_query_hit[i],ras_query_target[i],query_type[i],query_taken[i]}=bus[i];
    end
endgenerate
//------------------------{bus}end-------------------------//

//------------------------{缓存req&addr_ok}begin-------------------------//
always @ (posedge clk)begin
    if(!resetn)begin
        req_without_dataok <= 1'b0;
    end 
    else if(inst_req_accept)begin
        req_without_dataok <= 1'b1;
    end
    else if (inst_sram_data_ok)begin
        req_without_dataok <= 1'b0;
    end
end
assign  req_to_dataok_trigger = req_without_dataok;
//------------------------{缓存req&addr_ok}end-------------------------//

//------------------------{丢弃已取消取指响应}begin-------------------------//
reg     discard_resp_pending;
wire    redirect_now;
assign  redirect_now         = preIF2_need_cancel | br_taken;
always @(posedge clk) begin
    if(!resetn)begin
        discard_resp_pending <= 1'b0;
    end
    else if(inst_sram_data_ok)begin
        discard_resp_pending <= 1'b0;
    end
    else if(redirect_now & req_without_dataok)begin
        discard_resp_pending <= 1'b1;
    end
end
// redirect 与 data_ok 同周期时也必须直接丢弃，不能等寄存器下一拍生效。
assign  inst_resp_discard = discard_resp_pending |
                            (redirect_now & req_without_dataok);
//------------------------{丢弃已取消取指响应}end-------------------------//

//------------------------{instRAM handshake}begin-------------------------//
assign  inst_sram_wstrb              = 4'b0;
assign  inst_sram_wr                 = |inst_sram_wstrb;
assign  inst_sram_addr_without_cacop = (csr_CRMD_DA == 1 & csr_CRMD_PG == 0) ? pc[0] :
                                       (csr_CRMD_DA == 0 & csr_CRMD_PG == 1) & dmw_found0[0]  ? {dmw_pseg0[0],pc[0][28:0]} :
                                       (csr_CRMD_DA == 0 & csr_CRMD_PG == 1) & ~dmw_found0[0] ? tlb_paddr[0] :
                                       32'b0;
assign  inst_sram_wdata              = 32'b0;
//1. 跳转之后的preIF的指令直接让他的req为0，那么当前clk就一定不会ready_go
//2. 为了防止preIF ready go IF不allow_in 就只在allow_in的时候发起req
//3. 为了防止多个req之后才响应dataok所以需要在一次req之后手动拉低

//------------------------{instRAM handshake}end-------------------------//
wire    can_issue_inst = !req_without_dataok || inst_sram_data_ok;
assign  inst_sram_req  = preIF2_valid & slot_valid[0]
                                      & ~slot0_has_ex
                                      & IF_allow_in & ~br_taken
                                      & ~preIF2_need_cancel & ~need_stall
                                      & can_issue_inst;
assign  inst_sram_size = 2'b10;
assign  inst_wr        = 1'b0;
//------------------------{instRAM handshake}end-------------------------//

//------------------------{ready_go}begin-------------------------//
wire slot0_has_ex = ex_ADEF[0] | ex_tlb_reload0[0] |
                    ex_tlb_preif_unvalid[0] | ex_tlb_plv0[0];

assign  preIF2_ready_go = need_stall ? 1'b0 :
                          !slot_valid[0] ? 1'b1 :
                          slot0_has_ex   ? 1'b1 :
                          //握手成功
                          (inst_sram_req & inst_sram_addr_ok);
always @(posedge clk) begin
    if(!resetn)begin
        preIF2_valid <= 1'b0;
    end
    else if (preIF2_need_cancel || br_taken)begin
        preIF2_valid <= 1'b0;
    end
    else if(preIF2_allow_in)begin
        preIF2_valid <= preIF1_preIF2_valid;
    end
end



genvar i2;
generate 
    for(i2=0;i2<ISSUE;i2=i2+1)begin:gen_preIF2_IF_bus
        assign  preIF2_IF_bus[i2] = {slot_valid[i2],pc[i2],ex_ADEF[i2],ex_tlb_reload0[i2],ex_tlb_preif_unvalid[i2],ex_tlb_plv0[i2],
                                    btb_query_hit[i2],btb_query_target[i2],ras_query_hit[i2],ras_query_target[i2],query_type[i2],query_taken[i2]};
    end
endgenerate

//------------------------{ready_go}end-------------------------//

endmodule