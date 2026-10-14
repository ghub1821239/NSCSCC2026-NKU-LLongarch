module pre_IF1 #(
    parameter  outbus_width = 32,
    parameter  TLBNUM       = 16 
)
(
    input  wire                      clk,
    input  wire                      resetn,
    //control signal
    input  wire                      valid_in,
    input  wire                      preIF1_allow_in,
    output reg                       preIF1_valid,
    output wire                      preIF1_ready_go,
    
    output wire [outbus_width-1:0]   preIF1_preIF2_bus,//bus
    //br
    input  wire [31:0]               br_target,
    input  wire                      br_taken,
    //cancel
    input  wire                      preIF1_need_cancel,
    //stall
    input  wire                      need_stall,
    input  wire [31:0]               flush_target,
    // tlb port s0
    output wire [18:0]               s0_vppn,
    output wire                      s0_va_bit12,
    input  wire                      s0_found,
    input  wire [$clog2(TLBNUM)-1:0] s0_index, // 先向上取整再 log2（），这样来求出来位宽
    input  wire [19:0]               s0_ppn,
    input  wire [5:0]                s0_ps,
    input  wire [1:0]                s0_plv,
    input  wire [1:0]                s0_mat,
    input  wire                      s0_d,
    input  wire                      s0_v,
    //tlb_ex
    input  wire                      ex_tlb_reload0,//tlb重填例外
    input  wire                      ex_tlb_preif_unvalid,//tlb中取指页无效
    input  wire                      ex_tlb_plv0,//tlb中页特权不合规
    output wire                      tlb_inst_req,
    //DMW
    output wire [2:0]                dmw_vseg0,
    input  wire                      dmw_found0,
    input  wire [2:0]                dmw_pseg0,
    //CRMD PG DA
    input  wire                      csr_CRMD_DA,
    input  wire                      csr_CRMD_PG,
    //mat:存储访问类型
    input  wire [1:0]                csr_CRMD_DATF,//直接地址：取指
    input  wire [1:0]                csr_CRMD_DATM,//直接地址：ld/st
    input  wire [1:0]                dmw_mat0,    //直接映射
    //branch prediction
    //查询端口：preIF取指时来查BTB
    output wire                      query_valid,
    output wire [31:0]               query_pc,
    input  wire                      btb_query_hit,//valid且tag匹配
    input  wire [31:0]               btb_query_target,
    input  wire                      ras_query_hit,//valid且tag匹配
    input  wire [31:0]               ras_query_target,
    input  wire [ 1:0]               query_type,
    input  wire                      query_taken,//预测是否跳转
    input  wire                      preIF1_IDLE_stall
);
localparam  TYPE_COND = 2'b00;//2'b00  COND   条件分支 beq/bne/blt/bge/bltu/bgeu
localparam  TYPE_JUMP = 2'b01;//2'b01  JUMP   无条件直接跳 b
localparam  TYPE_CALL = 2'b10;//2'b10  CALL   bl，或 jirl 且 rd!=0
localparam  TYPE_RET  = 2'b11;//2'b11  RET    jirl 且 rd==0
//------------------------{PC}begin-------------------------//
reg    [31:0] pc;
wire   [31:0] seq_PC  = pc + 4;
wire   [31:0] next_PC;
assign        next_PC = br_taken ? br_target :
                        ras_query_hit & (query_type == TYPE_RET) ? ras_query_target : 
                        btb_query_hit & (query_type == TYPE_CALL | query_type == TYPE_JUMP)? btb_query_target : 
                        query_taken & btb_query_hit & (query_type == TYPE_COND)? btb_query_target : 
                        seq_PC;
//assign next_PC = br_taken ? br_target : seq_PC;//根据是否跳转更改seqPC THE UPDATE OF PC SHOULD CONSTRAIN MORE!

always @(posedge clk) begin
    if (!resetn) begin
        pc <= 32'h1bfffffc; //nextpc=1c000000
//        pc <= 32'h1c000000;
    end
    else if (preIF1_need_cancel)begin
        pc <= flush_target;
    end
    // 直接br_taken在当前clk更改pc那么就可以把preIF的错指令给覆盖掉
    else if(preIF1_allow_in | br_taken) begin
        pc <= next_PC;
    end
end
//------------------------{PC}end-------------------------//

//------------------------{branch prediciton}begin------------------//
assign  query_valid = preIF1_valid;//preIF1_valid表示指令有效
assign  query_pc    = pc;          //拿pc

//------------------------{branch prediciton}end------------------//

//------------------------{ex_ADEF}begin-------------------------//
wire    ex_ADEF;
assign  ex_ADEF = (pc[1:0] != 2'b00);
//------------------------{ex_ADEF}end-------------------------//

//------------------------{DMW}begin-------------------------//
assign  dmw_vseg0 = pc[31:29];
//------------------------{DMW}end-------------------------//

//------------------------{虚地址转物理地址}begin-------------------------//
assign        s0_vppn      = pc[31:13];
assign        s0_va_bit12  = pc[12];
wire   [31:0] tlb_paddr;
assign        tlb_inst_req = preIF1_valid && !preIF1_need_cancel && !csr_CRMD_DA &&  csr_CRMD_PG && !dmw_found0;
assign        tlb_paddr    = (s0_ps == 6'd21) ? {s0_ppn[19:9], pc[20:0]}// 4MB页
                             : {s0_ppn[19:0],  pc[11:0]}; // 4KB页
//------------------------{虚地址转物理地址}end-------------------------//

//------------------------{ready_go}begin-------------------------//
assign  preIF1_ready_go = need_stall | preIF1_IDLE_stall ? 1'b0 : 1'b1;
always @(posedge clk) begin
    if(!resetn)begin
        preIF1_valid <= 1'b0;
    end
    else if(preIF1_allow_in)begin
        preIF1_valid <= valid_in;
    end
    else if (br_taken) begin
        preIF1_valid <= valid_in;
    end
end
assign  preIF1_preIF2_bus = {pc,ex_ADEF,ex_tlb_reload0,ex_tlb_preif_unvalid,ex_tlb_plv0,
                            dmw_found0,dmw_pseg0,dmw_mat0,s0_mat,csr_CRMD_DATF,tlb_paddr,
                            btb_query_hit,btb_query_target,ras_query_hit,ras_query_target,query_type,query_taken};
//------------------------{ready_go}end-------------------------//
endmodule