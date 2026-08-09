module pre_IF1 #(
    parameter  slot0_outbus_width = 144,
    parameter  outbus_width       = 142,
    parameter  TLBNUM       = 16,
    parameter  ISSUE        = 2,
    parameter  ICACHE_OFFSET_W = 4
)
(
    input  wire                      clk,
    input  wire                      resetn,
    //control signal
    input  wire                      valid_in,
    input  wire                      preIF1_allow_in,
    output reg                       preIF1_valid,
    output wire                      preIF1_ready_go,
    
    output wire [slot0_outbus_width-1:0] preIF1_preIF2_bus_slot0,
    output wire [outbus_width-1:0]       preIF1_preIF2_bus[ISSUE - 1 : 1],
    //br
    input  wire [31:0]               br_target,
    input  wire                      br_taken,
    //cancel
    input  wire                      preIF1_need_cancel,
    //stall
    input  wire                      need_stall,
    input  wire [31:0]               flush_target,
    // tlb port s0
    output wire [18:0]               s0_vppn[ISSUE - 1 : 0],
    output wire                      s0_va_bit12[ISSUE - 1 : 0],
    input  wire                      s0_found[ISSUE - 1 : 0],
    input  wire [$clog2(TLBNUM)-1:0] s0_index[ISSUE - 1 : 0], // ������ȡ���� log2�����������������λ��
    input  wire [19:0]               s0_ppn[ISSUE - 1 : 0],
    input  wire [5:0]                s0_ps[ISSUE - 1 : 0],
    input  wire [1:0]                s0_plv[ISSUE - 1 : 0],
    input  wire [1:0]                s0_mat[ISSUE - 1 : 0],
    input  wire                      s0_d[ISSUE - 1 : 0],
    input  wire                      s0_v[ISSUE - 1 : 0],
    //tlb_ex
    input  wire                      ex_tlb_reload0[ISSUE - 1 : 0],//tlb��������
    input  wire                      ex_tlb_preif_unvalid[ISSUE - 1 : 0],//tlb��ȡָҳ��Ч
    input  wire                      ex_tlb_plv0[ISSUE - 1 : 0],//tlb��ҳ��Ȩ���Ϲ�
    output wire                      tlb_inst_req,
    //DMW
    output wire [2:0]                dmw_vseg0[ISSUE - 1 : 0],
    input  wire                      dmw_found0[ISSUE - 1 : 0],
    input  wire [2:0]                dmw_pseg0[ISSUE - 1 : 0],
    //CRMD PG DA
    input  wire                      csr_CRMD_DA,
    input  wire                      csr_CRMD_PG,
    input  wire [1:0]                csr_CRMD_DATF,
    input  wire [1:0]                dmw_mat0[ISSUE - 1 : 0],
    //branch prediction
    //��ѯ�˿ڣ�preIFȡָʱ����BTB
    output wire                      query_valid[ISSUE-1:0],
    output wire [31:0]               query_pc   [ISSUE-1:0],
    input  wire                      btb_query_hit[ISSUE - 1 : 0],//valid��tagƥ��
    input  wire [31:0]               btb_query_target[ISSUE - 1 : 0],
    input  wire                      ras_query_hit[ISSUE - 1 : 0],//valid��tagƥ��
    input  wire [31:0]               ras_query_target[ISSUE - 1 : 0],
    input  wire [ 1:0]               query_type[ISSUE - 1 : 0],
    input  wire                      query_taken[ISSUE - 1 : 0],//Ԥ���Ƿ���ת
    input  wire                      preIF1_IDLE_stall
);
localparam  TYPE_COND = 2'b00;//2'b00  COND   ������֧ beq/bne/blt/bge/bltu/bgeu
localparam  TYPE_JUMP = 2'b01;//2'b01  JUMP   ������ֱ���� b
localparam  TYPE_CALL = 2'b10;//2'b10  CALL   bl���� jirl �� rd!=0
localparam  TYPE_RET  = 2'b11;//2'b11  RET    jirl �� rd==0
//------------------------{PC}begin-------------------------//
reg    [31:0] pc;
wire   [31:0] slot_pc[ISSUE - 1 : 0];
wire   [ISSUE - 1 : 0] slot_valid;
wire   [31:0] seq_PC  = slot_valid == 2'b11 ? pc + 8 :
                        slot_valid == 2'b01 ? pc + 4 :
                        pc;
wire   [31:0] next_PC;
genvar i;
generate
    for (i = 0;i < ISSUE;i = i + 1) begin
        assign slot_pc[i] = pc + 4 * i;
    end
endgenerate

wire same_cacheline = (slot_pc[0][31:ICACHE_OFFSET_W] == slot_pc[1][31:ICACHE_OFFSET_W]);//����ָ����ͬһ��cacheline
//----------------------pred{begin}-------------------------------------------------
//----------------------pred{begin}-------------------------------------------------
wire pred_redirect0 = (ras_query_hit[0] && (query_type[0] == TYPE_RET)) || 
                      (btb_query_hit[0] && (query_type[0] == TYPE_CALL || query_type[0] == TYPE_JUMP)) || 
                      (query_taken[0] && btb_query_hit[0] && (query_type[0] == TYPE_COND));
wire [31:0] pred_target0 =  (ras_query_hit[0] && (query_type[0] == TYPE_RET)) ? ras_query_target[0] :
                            (btb_query_hit[0] && (query_type[0] == TYPE_CALL || query_type[0] == TYPE_JUMP)) ? btb_query_target[0] :
                            (query_taken[0] && btb_query_hit[0] && (query_type[0] == TYPE_COND)) ? btb_query_target[0] :
                            32'b0; // ���ᱻ�õ�

wire pred_redirect1 = (ras_query_hit[1] && (query_type[1] == TYPE_RET)) || 
                      (btb_query_hit[1] && (query_type[1] == TYPE_CALL || query_type[1] == TYPE_JUMP)) || 
                      (query_taken[1] && btb_query_hit[1] && (query_type[1] == TYPE_COND));
wire [31:0] pred_target1 =  (ras_query_hit[1] && (query_type[1] == TYPE_RET)) ? ras_query_target[1] :
                            (btb_query_hit[1] && (query_type[1] == TYPE_CALL || query_type[1] == TYPE_JUMP)) ? btb_query_target[1] :
                            (query_taken[1] && btb_query_hit[1] && (query_type[1] == TYPE_COND)) ? btb_query_target[1] :
                            32'b0; // ���ᱻ�õ�
//----------------------pred{end}-------------------------------------------------
wire [1:0] inst_mat = (csr_CRMD_DA  && !csr_CRMD_PG) ? csr_CRMD_DATF :
                      (!csr_CRMD_DA &&  csr_CRMD_PG &&  dmw_found0[0]) ? dmw_mat0[0] :
                      (!csr_CRMD_DA &&  csr_CRMD_PG && !dmw_found0[0]) ? s0_mat[0] :
                      2'b0;
wire uncache_fetch = (inst_mat == 2'b00);//uncacheֻ��һ��

wire preIF1_ex = ex_ADEF[0] |  
                 ex_tlb_reload0[0] |  
                 ex_tlb_preif_unvalid[0] |  
                 ex_tlb_plv0[0];

assign slot_valid = !preIF1_valid | br_taken  | preIF1_need_cancel? {ISSUE{1'b0}} : 
                    preIF1_ex | pred_redirect0 | ~same_cacheline | uncache_fetch ? {1'b0,{ISSUE-1{1'b1}}} :
                    {ISSUE{1'b1}};
assign next_PC = br_taken       ? br_target     :
                 pred_redirect0 ? pred_target0  :
                 (same_cacheline & !preIF1_ex & !pred_redirect0 & pred_redirect1 & !uncache_fetch) ? pred_target1 :
                 seq_PC;
//assign next_PC = br_taken ? br_target : seq_PC;//�����Ƿ���ת����seqPC THE UPDATE OF PC SHOULD CONSTRAIN MORE!

always @(posedge clk) begin
    if (!resetn) begin
        pc <= 32'h1bfffffc; //nextpc=1c000000
//        pc <= 32'h1c000000;
    end
    else if (preIF1_need_cancel)begin
        pc <= flush_target;
    end
    // ֱ��br_taken�ڵ�ǰclk����pc��ô�Ϳ��԰�preIF�Ĵ�ָ������ǵ�
    else if(preIF1_allow_in | br_taken) begin
        pc <= next_PC;
    end
end
//------------------------{PC}end-------------------------//

//------------------------{branch prediciton}begin------------------//
assign  query_valid[0] = preIF1_valid & ~br_taken & ~preIF1_need_cancel;//preIF1_valid��ʾָ����Ч
assign  query_pc[0]    = slot_pc[0];          //��pc
assign  query_valid[1] = preIF1_valid & ~br_taken & ~preIF1_need_cancel & same_cacheline & ~uncache_fetch & ~preIF1_ex;//preIF1_valid��ʾָ����Ч
assign  query_pc[1]    = slot_pc[1];          //��pc
//------------------------{branch prediciton}end------------------//

//------------------------{ex_ADEF}begin-------------------------//
wire    ex_ADEF[ISSUE - 1 : 0];
//assign  ex_ADEF[0] = (pc[1:0] != 2'b00);
generate
    for (i = 0; i < ISSUE; i = i + 1) begin
        assign ex_ADEF[i] = slot_pc[i][1:0] != 2'b00;
    end
endgenerate
//------------------------{ex_ADEF}end-------------------------//

//------------------------{DMW}begin-------------------------//
generate
    for (i = 0; i < ISSUE; i = i + 1) begin
        assign  dmw_vseg0[i] = slot_pc[i][31:29];
    end
endgenerate
//------------------------{DMW}end-------------------------//

//------------------------{���ַת������ַ}begin-------------------------//
generate
    for (i = 0; i < ISSUE; i = i + 1) begin
        assign        s0_vppn[i]      = slot_pc[i][31:13];
        assign        s0_va_bit12[i]  = slot_pc[i][12];
    end
endgenerate
wire   [31:0] tlb_paddr[ISSUE - 1 : 0];
assign        tlb_inst_req = preIF1_valid && !preIF1_need_cancel && !csr_CRMD_DA &&  csr_CRMD_PG && !dmw_found0[0];
generate
    for (i = 0;i < ISSUE;i = i + 1) begin
        assign        tlb_paddr[i]    = (s0_ps[0] == 6'd21) ? {s0_ppn[0][19:9], slot_pc[i][20:0]}// 4MBҳ
                             : {s0_ppn[0][19:0],  slot_pc[i][11:0]}; // 4KBҳ
    end
endgenerate
//------------------------{���ַת������ַ}end-------------------------//

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

// slot0: 144bit���ֶ�˳������� Pre_IF2 ���һ�£��� inst_mat��
assign preIF1_preIF2_bus_slot0 = {
  slot_valid[0],
  slot_pc[0],
  ex_ADEF[0],
  ex_tlb_reload0[0], ex_tlb_preif_unvalid[0], ex_tlb_plv0[0],
  dmw_found0[0], dmw_pseg0[0],
  inst_mat,                 // �����Ǳ�ģ����� inst_mat������ s0_mat
  tlb_paddr[0],
  btb_query_hit[0], btb_query_target[0],
  ras_query_hit[0], ras_query_target[0],
  query_type[0], query_taken[0]
};
// slot1..: 142bit���� inst_mat
generate
  for (i = 1; i < ISSUE; i = i + 1) begin : gen_bus1
    assign preIF1_preIF2_bus[i] = {
      slot_valid[i],
      slot_pc[i],
      ex_ADEF[i],
      ex_tlb_reload0[i], ex_tlb_preif_unvalid[i], ex_tlb_plv0[i],
      dmw_found0[i], dmw_pseg0[i],
      tlb_paddr[i],          // ע�⣺������治Ҫƴ s0_mat
      btb_query_hit[i], btb_query_target[i],
      ras_query_hit[i], ras_query_target[i],
      query_type[i], query_taken[i]
    };
  end
endgenerate
//------------------------{ready_go}end-------------------------//
endmodule