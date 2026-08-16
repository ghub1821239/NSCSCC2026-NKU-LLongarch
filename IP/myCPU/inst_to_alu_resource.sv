module inst_to_alu_resource #(
    parameter  outbus_width = 243
)(
    input  wire [31:0]             pc,
    input  wire [31:0]             inst,
    input  wire                    slot_valid,
    input  wire                    ex_ADEF,
    input  wire                    ex_tlb_reload0,
    input  wire                    ex_tlb_preif_unvalid,
    input  wire                    ex_tlb_plv0,
    input  wire                    btb_query_hit,
    input  wire [31:0]             btb_query_target,
    input  wire                    ras_query_hit,
    input  wire [31:0]             ras_query_target,
    input  wire [1:0]              query_type,
    input  wire                    query_taken,
    input  wire [31:0]             rf_rdata1,
    input  wire [31:0]             rf_rdata2,
    input  wire [31:0]             rf_rdata1_br,
    input  wire [31:0]             rf_rdata2_br,
    input  wire [1:0]              csr_CRMD_PLV,
    input  wire                    has_int,          // 建议仅 lane0 接真 has_int，lane1=0
    output wire [4:0]              rf_raddr1,
    output wire [4:0]              rf_raddr2,
    output wire [outbus_width-2:0] exe_payload, // 与现 ID_EXE1_bus 同序
    output wire                    real_taken,
    output wire [31:0]             real_target,
    output wire                    pred_taken,
    output wire                    pred_valid,
    output wire                    pred_ok,
    output wire                    redirect,    // 本槽预测错误需冲刷
    output wire                    is_cond,
    output wire                    is_call,
    output wire                    is_ret,
    output wire                    is_jump,
    output wire                    is_br,            // cond|jump|call|ret
    output wire                    is_mem,           // ld/st/ll/sc
    output wire                    is_system_break,  //system/break/ertn/idle/ibar/dbar/cacop
    output wire                    is_csr_write,    //csrwr/csrxchg
    output wire                    is_csr_read,     //csrrd/rdcntid/rdcntvl/rdcntdvh
    output wire                    is_tlb,          //tlbrd/tlbfill/tlbsrch/invtlb/tlbwr
    output wire [4:0]              rf_dest,
    output wire                    rf_gr_we,
    output wire                    result_not_fast,//本拍没有alu_result_fast
    output wire                    src1_is_reg,
    output wire                    src2_is_reg,
    output wire                    is_store,
    output wire                    is_cpucfg_inst,
    output wire                    upd_need,       // pred_valid & ~ex_ADEF & ~pred_ok
    output wire                    bht_upd_need,   // is_cond & ~ex_ADEF
    output wire                    push_need,
    output wire                    pop_need,
    output wire [1:0]              br_type,      // COND/JUMP/CALL/RET
    output wire                    ex_INE,
    output wire                    ex_IPE
);

wire [18:0] alu_op;
wire        src1_is_pc;
wire        src2_is_imm;
wire        res_from_mem;
wire        dst_is_r1;

wire        mem_we;
wire        src_reg_is_rd;
//wire [4: 0] rf_dest;
wire [31:0] rj_value;
wire [31:0] rkd_value;
wire [31:0] cpucfg_value;
wire [31:0] imm;
wire [31:0] br_offs;
wire [31:0] jirl_offs;

wire [ 5:0] op_31_26;
wire [ 3:0] op_25_22;
wire [ 1:0] op_21_20;
wire [ 4:0] op_19_15;
wire [ 1:0] op_25_24;
wire [ 4:0] op_14_10;

wire [ 4:0] rd;
wire [ 4:0] rj;
wire [ 4:0] rk;
wire [13:0] csr_num;
wire [ 4:0] hint;


wire [11:0] i12;
wire [13:0] i14;
wire [19:0] i20;
wire [15:0] i16;
wire [25:0] i26;

wire [63:0] op_31_26_d;
wire [15:0] op_25_22_d;
wire [ 3:0] op_21_20_d;
wire [31:0] op_19_15_d;
wire        op_25_d;
wire [3:0]  op_25_24_d;
wire [31:0] op_14_10_d;

wire        inst_add_w;
wire        inst_sub_w;
wire        inst_slt;
wire        inst_sltu;
wire        inst_nor;
wire        inst_and;
wire        inst_or;
wire        inst_xor;
wire        inst_slli_w;
wire        inst_srli_w;
wire        inst_srai_w;
wire        inst_addi_w;
wire        inst_ld_w;
wire        inst_st_w;
wire        inst_jirl;
wire        inst_b;
wire        inst_bl;
wire        inst_beq;
wire        inst_bne;
wire        inst_lu12i_w;
//chapter6:new_add
wire        inst_slti;
wire        inst_sltui;
wire        inst_andi;
wire        inst_ori;
wire        inst_xori;
wire        inst_sll_w;
wire        inst_srl_w;
wire        inst_sra_w;
wire        inst_pcaddu12i_w;
wire        inst_mul_w;
wire        inst_mulh_w;
wire        inst_mulh_wu;
wire        inst_div;
wire        inst_divu;
wire        inst_mod;
wire        inst_modu;
//chapter 6 exp 11:new_add
wire        inst_ld_b;
wire        inst_ld_h;
wire        inst_ld_bu;
wire        inst_ld_hu;
wire        inst_st_b;
wire        inst_st_h;
wire        inst_blt;
wire        inst_bge;
wire        inst_bltu;
wire        inst_bgeu;
//chapter 7 exp 12:new_add
wire        inst_csrrd;
wire        inst_csrwr;
wire        inst_csrxchg;
wire        inst_csr;
wire        inst_ertn;
wire        inst_syscall;
wire        inst_break;
wire        inst_rdcntvl_w;
wire        inst_rdcntvh_w;
wire        inst_rdcntid;
//chapter 9 : new add
wire        inst_tlbsrch;
wire        inst_tlbrd;
wire        inst_tlbwr;
wire        inst_tlbfill;
wire        inst_invtlb;
//chapter 10 : cache_cacop
wire        inst_cacop;
//cpucfg
wire        inst_cpucfg;
//system inst
wire        inst_ibar;
wire        inst_dbar;
wire        inst_ll_w;
wire        inst_sc_w;
// IDLE
wire        inst_idle;
// preld
wire        inst_preld;

wire        need_ui5;
wire        need_ui12;
wire        need_si12;
wire        need_si14;
wire        need_si16;
wire        need_si20;
wire        need_si26;
wire        src2_is_4;

wire [31:0] alu_src1;
wire [31:0] alu_src2;

wire [4:0]  cache_code;

//------------------------{Decode match}begin-------------------------//
assign  op_31_26 = inst[31:26];
assign  op_25_22 = inst[25:22];
assign  op_21_20 = inst[21:20];
assign  op_19_15 = inst[19:15];
assign  op_25_d  = inst[25];
assign  op_25_24 = inst[25:24];
assign  op_14_10 = inst[14:10];

assign  rd       = inst[ 4: 0];
assign  rj       = inst[ 9: 5];
assign  rk       = inst[14:10];
assign  csr_num  = inst[23:10];
assign  hint     = inst[ 4: 0];

assign  i12      = inst[21:10];
assign  i14      = inst[23:10];
assign  i16      = inst[25:10];
assign  i20      = inst[24: 5];
assign  i26      = {inst[ 9: 0], inst[25:10]};

decoder_6_64 u_dec0(.in(op_31_26 ), .out(op_31_26_d ));
decoder_4_16 u_dec1(.in(op_25_22 ), .out(op_25_22_d ));
decoder_2_4  u_dec2(.in(op_21_20 ), .out(op_21_20_d ));
decoder_5_32 u_dec3(.in(op_19_15 ), .out(op_19_15_d ));
decoder_2_4  u_dec4(.in(op_25_24 ), .out(op_25_24_d ));
decoder_5_32 u_dec5(.in(op_14_10 ), .out(op_14_10_d ));
//------------------------{Decode match}end-------------------------//

//------------------------{one hot}begin-------------------------//
assign  inst_add_w       = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h00];
assign  inst_sub_w       = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h02];
assign  inst_slt         = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h04];
assign  inst_sltu        = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h05];
assign  inst_nor         = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h08];
assign  inst_and         = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h09];
assign  inst_or          = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0a];
assign  inst_xor         = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0b];
assign  inst_slli_w      = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h01];
assign  inst_srli_w      = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h09];
assign  inst_srai_w      = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h11];
assign  inst_addi_w      = op_31_26_d[6'h00] & op_25_22_d[4'ha];
assign  inst_ld_w        = op_31_26_d[6'h0a] & op_25_22_d[4'h2];
assign  inst_st_w        = op_31_26_d[6'h0a] & op_25_22_d[4'h6];
assign  inst_jirl        = op_31_26_d[6'h13];
assign  inst_b           = op_31_26_d[6'h14];
assign  inst_bl          = op_31_26_d[6'h15];
assign  inst_beq         = op_31_26_d[6'h16];
assign  inst_bne         = op_31_26_d[6'h17];
assign  inst_lu12i_w     = op_31_26_d[6'h05] & ~inst[25];
//chapter6:new add
assign  inst_slti        = op_31_26_d[6'h00] & op_25_22_d[4'h8];
assign  inst_sltui       = op_31_26_d[6'h00] & op_25_22_d[4'h9];
assign  inst_andi        = op_31_26_d[6'h00] & op_25_22_d[4'hd];
assign  inst_ori         = op_31_26_d[6'h00] & op_25_22_d[4'he];
assign  inst_xori        = op_31_26_d[6'h00] & op_25_22_d[4'hf];
assign  inst_sll_w       = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0e];
assign  inst_srl_w       = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0f];
assign  inst_sra_w       = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h10];
assign  inst_pcaddu12i_w = op_31_26_d[6'h07] & ~op_25_d;
assign  inst_mul_w       = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h18];
assign  inst_mulh_w      = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h19];
assign  inst_mulh_wu     = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h1a];
assign  inst_div         = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h00];
assign  inst_mod         = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h01];
assign  inst_divu        = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h02];
assign  inst_modu        = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h03];
//chapter 6 exp 11:new_add
assign  inst_ld_b        = op_31_26_d[6'h0a] & op_25_22_d[4'h0];
assign  inst_ld_h        = op_31_26_d[6'h0a] & op_25_22_d[4'h1];
assign  inst_ld_bu       = op_31_26_d[6'h0a] & op_25_22_d[4'h8];
assign  inst_ld_hu       = op_31_26_d[6'h0a] & op_25_22_d[4'h9];
assign  inst_st_b        = op_31_26_d[6'h0a] & op_25_22_d[4'h4];
assign  inst_st_h        = op_31_26_d[6'h0a] & op_25_22_d[4'h5];
assign  inst_blt         = op_31_26_d[6'h18];
assign  inst_bge         = op_31_26_d[6'h19];
assign  inst_bltu        = op_31_26_d[6'h1a];
assign  inst_bgeu        = op_31_26_d[6'h1b];
//chapter 7 exp 12:new_add
assign  inst_csrrd       = op_31_26_d[6'h01] & op_25_24_d[2'h0] & rj == 5'b0;
assign  inst_csrwr       = op_31_26_d[6'h01] & op_25_24_d[2'h0] & rj == 5'b1;
assign  inst_csrxchg     = op_31_26_d[6'h01] & op_25_24_d[2'h0] & rj != 5'b0 & rj != 5'b1;
assign  inst_ertn        = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h10] & rk == 5'b01110 & rj == 5'b00000 & rd == 5'b00000;
assign  inst_syscall     = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h16];
assign  inst_break       = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h14];
assign  inst_csr         = inst_csrrd | inst_csrwr | inst_csrxchg;
assign  inst_rdcntvl_w   = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h0] & op_19_15_d[5'h0] & rk == 5'b11000 & rj == 5'b00000;//notice:& rd != 5'b00000 我新加的!=的condition，操作手册上没写，但加上更完善，因为0号寄存器和不写一样，可以排除，但是如果直接排除会被认为 INE
assign  inst_rdcntvh_w   = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h0] & op_19_15_d[5'h0] & rk == 5'b11001 & rj == 5'b00000;
assign  inst_rdcntid     = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h0] & op_19_15_d[5'h0] & rk == 5'b11000 & rj != 5'b00000 & rd == 5'b00000;
//chapter 9 exp18:new add
assign  inst_tlbsrch     = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h10] & rk == 5'b01010 & rj == 5'b00000 & rd == 5'b00000;
assign  inst_tlbrd       = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h10] & rk == 5'b01011 & rj == 5'b00000 & rd == 5'b00000;
assign  inst_tlbwr       = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h10] & rk == 5'b01100 & rj == 5'b00000 & rd == 5'b00000;
assign  inst_tlbfill     = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h10] & rk == 5'b01101 & rj == 5'b00000 & rd == 5'b00000;
assign  inst_invtlb      = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h13];
//chapter 10 exp23:new add cache_cacop
assign  inst_cacop       = op_31_26_d[6'h01] & op_25_22_d[4'h8];
//cpucfg
assign  inst_cpucfg      = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h0] & op_19_15_d[5'h0] & rk == 5'b11011;
//system inst
assign  inst_ibar        = op_31_26_d[6'h0e] & op_25_22_d[4'h1] & op_21_20_d[2'h3] & op_19_15_d[5'h5];
assign  inst_dbar        = op_31_26_d[6'h0e] & op_25_22_d[4'h1] & op_21_20_d[2'h3] & op_19_15_d[5'h4];
assign  inst_ll_w        = op_31_26_d[6'h08] & op_25_24_d[2'h0];
assign  inst_sc_w        = op_31_26_d[6'h08] & op_25_24_d[2'h1];
// IDLE
assign  inst_idle        = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h11];
//preld
assign  inst_preld       = op_31_26_d[6'h0a] & op_25_22_d[4'hb];


assign  alu_op[ 0]       = inst_add_w | inst_addi_w | inst_ld_w        | inst_st_w |
                           inst_jirl  | inst_bl     | inst_pcaddu12i_w | inst_ld_b |
                           inst_ld_h  | inst_ld_bu  | inst_ld_hu       | inst_st_b |
                           inst_st_h  | inst_cacop  | inst_cpucfg      | inst_ll_w |
                           inst_sc_w  | inst_preld ;
assign  alu_op[ 1]       = inst_sub_w;
assign  alu_op[ 2]       = inst_slt   | inst_slti;
assign  alu_op[ 3]       = inst_sltu  | inst_sltui;
assign  alu_op[ 4]       = inst_and   | inst_andi;
assign  alu_op[ 5]       = inst_nor;
assign  alu_op[ 6]       = inst_or    | inst_ori;
assign  alu_op[ 7]       = inst_xor   | inst_xori;
assign  alu_op[ 8]       = inst_slli_w| inst_sll_w;
assign  alu_op[ 9]       = inst_srli_w| inst_srl_w;
assign  alu_op[10]       = inst_srai_w| inst_sra_w;
assign  alu_op[11]       = inst_lu12i_w;
assign  alu_op[12]       = inst_mul_w;
assign  alu_op[13]       = inst_mulh_w;
assign  alu_op[14]       = inst_mulh_wu;
assign  alu_op[15]       = inst_div;
assign  alu_op[16]       = inst_mod;
assign  alu_op[17]       = inst_divu;
assign  alu_op[18]       = inst_modu;

//the insts need to write back regfile
//wire    rf_gr_we;
assign  rf_gr_we         = ~inst_st_w    & ~inst_beq   & ~inst_bne   & ~inst_b       & ~inst_blt  &
                           ~inst_bge     & ~inst_bltu  & ~inst_bgeu  & ~inst_st_b    & ~inst_st_h &
                           ~inst_tlbsrch & ~inst_tlbrd & ~inst_tlbwr & ~inst_tlbfill & ~inst_invtlb &
                           ~inst_cacop   & ~inst_ibar  & ~inst_dbar  & ~inst_idle    & ~inst_preld;

assign  need_ui5         = inst_slli_w | inst_srli_w | inst_srai_w;
assign  need_ui12        = inst_andi   | inst_ori    | inst_xori;
assign  need_si12        = inst_addi_w | inst_ld_w  | inst_st_w  | inst_slti  | inst_sltui |
                           inst_ld_b   | inst_ld_h  | inst_ld_bu | inst_ld_hu | inst_st_b  |
                           inst_st_h   | inst_cacop | inst_preld;
assign  need_si14        = inst_ll_w | inst_sc_w;
assign  need_si16        = inst_jirl | inst_beq | inst_bne
                                     | inst_blt | inst_bge | inst_bltu | inst_bgeu;
assign  need_si20        = inst_lu12i_w | inst_pcaddu12i_w;
assign  need_si26        = inst_b | inst_bl;
assign  src2_is_4        = inst_jirl | inst_bl;


assign  imm              = src2_is_4 ? 32'h4                         :
                           need_si20 ? {i20[19:0], 12'b0}            :
                           need_ui12 ? {{20{1'b0}},i12[11:0]}        :
                           need_si14 ? {{16{i14[13]}},i14[13:0],2'b0}:
                           /*need_ui5 || need_si12*/{{20{i12[11]}}, i12[11:0]} ;

assign  br_offs          = need_si26 ? {{ 4{i26[25]}}, i26[25:0], 2'b0} :
                           {{14{i16[15]}}, i16[15:0], 2'b0} ;

assign  jirl_offs        = {{14{i16[15]}}, i16[15:0], 2'b0};

assign  src_reg_is_rd    = inst_beq  | inst_bne  | inst_st_w  | inst_blt     | inst_bge  | inst_bltu | inst_bgeu |
                           inst_st_b | inst_st_h | inst_csrwr | inst_csrxchg | inst_sc_w;

assign  src1_is_pc       = inst_jirl | inst_bl | inst_pcaddu12i_w;

assign  src2_is_imm      = inst_slli_w |
                           inst_srli_w |
                           inst_srai_w |
                           inst_addi_w |
                           inst_ld_w   |
                           inst_st_w   |
                           inst_lu12i_w|
                           inst_jirl   |
                           inst_bl     |
                           inst_slti   |
                           inst_sltui  |
                           inst_andi   |
                           inst_ori    |
                           inst_xori   |
                           inst_pcaddu12i_w | 
                           inst_ld_b   | 
                           inst_ld_h   | 
                           inst_ld_bu  | 
                           inst_ld_hu  | 
                           inst_st_b   | 
                           inst_st_h   |
                           inst_cacop  |
                           inst_ll_w   |
                           inst_sc_w   |
                           inst_preld;
                       
//------------------------{one hot}end-------------------------//

//------------------------{summary}begin-------------------------//
assign  dst_is_r1    = inst_bl;
assign  res_from_mem = inst_ld_w | inst_ld_b | inst_ld_h | inst_ld_bu | inst_ld_hu | inst_ll_w;
assign  mem_we       = inst_st_w | inst_st_b | inst_st_h | inst_sc_w;
assign  rf_dest      = dst_is_r1 ? 5'd1 : (inst_rdcntid ? rj : rd);
// src1/2不会同时使用
wire    src1_unused  = inst_b | inst_bl | inst_lu12i_w | inst_pcaddu12i_w;
wire    src2_unused  = (src2_is_imm && !mem_we) | inst_b;

assign  rf_raddr1    = src1_unused ? 5'b0 : rj;
assign  rf_raddr2    = src2_unused   ? 5'b0 :
                       src_reg_is_rd ? rd :rk;

assign  src1_is_reg  = ~src1_is_pc  & ~inst_csr & ~inst_cpucfg & ~src1_unused;
assign  src2_is_reg  = ~src2_is_imm & ~inst_cpucfg;
assign  is_store     = mem_we;
assign  is_cpucfg_inst = inst_cpucfg;

assign  rj_value     = rf_rdata1;
assign  rkd_value    = rf_rdata2;
wire [31:0]    rj_value_br  = rf_rdata1_br;
wire [31:0]    rkd_value_br = rf_rdata2_br;

assign  cache_code   = rd;

//beq bne b bl pc+off
//bl $GR[1]=pc+4 pc+off
//jirl pc= GR[rj]+off  GR[rd]=pc+4

//------------- cpucfg begin -------------
cpucfg u_cpucfg(
    .rj_value     (rj_value     ),
    .cpucfg_value (cpucfg_value )
);
//------------- cpucfg end ---------------

assign  alu_src1 = inst_csr | inst_cpucfg ? 32'b0 : (src1_is_pc  ? pc[31:0] : rj_value);
assign  alu_src2 = inst_cpucfg ? cpucfg_value :
                   src2_is_imm ? imm : rkd_value;
//------------------------{summary}end-------------------------//

//------------------------{stall}begin-------------------------//
wire    need_stall_inst;
wire    need_stall_csr;
assign  need_stall_inst = inst_ld_w | inst_ld_b | inst_ld_h | inst_ld_bu | inst_ld_hu | inst_ll_w;
assign  need_stall_csr  = inst_csrrd | inst_csrwr | inst_csrxchg | inst_rdcntid | inst_rdcntvl_w | inst_rdcntvh_w;
assign  result_not_fast = need_stall_inst | need_stall_csr | inst_sc_w |
                          alu_op[12] | alu_op[13] | alu_op[14] | alu_op[15] |
                          alu_op[16] | alu_op[17] | alu_op[18];
//------------------------{stall}end-------------------------//

//------------------------{ex_INE}begin-------------------------//
wire    ex_tlbinv_op;
assign  ex_tlbinv_op  =  ~((rf_dest == 5'd0) | (rf_dest == 5'd1) | (rf_dest == 5'd2) |
                        (rf_dest == 5'd3)    | (rf_dest == 5'd4) | (rf_dest == 5'd5) |
                        (rf_dest == 5'd6));

//[TODO 新增指令未完成]
//wire    ex_INE;
assign  ex_INE        = ~(inst_add_w     | inst_sub_w     | inst_slt       | inst_sltu                   |
                        inst_nor         | inst_and       | inst_or        | inst_xor                    |
                        inst_slli_w      | inst_srli_w    | inst_srai_w    | inst_addi_w                 |
                        inst_ld_w        | inst_st_w      | inst_jirl      | inst_b                      |
                        inst_bl          | inst_beq       | inst_bne       | inst_lu12i_w                |
                        inst_slti        | inst_sltui     | inst_andi      | inst_ori                    |
                        inst_xori        | inst_sll_w     | inst_srl_w     | inst_sra_w                  |
                        inst_pcaddu12i_w | inst_mul_w     | inst_mulh_w    | inst_mulh_wu                |
                        inst_div         | inst_divu      | inst_mod       | inst_modu                   |
                        inst_ld_b        | inst_ld_h      | inst_ld_bu     | inst_ld_hu                  |
                        inst_st_b        | inst_st_h      | inst_blt       | inst_bge                    |
                        inst_bltu        | inst_bgeu      | inst_csrrd     | inst_csrwr                  |
                        inst_csrxchg     | inst_ertn      | inst_syscall   | inst_break                  |
                        inst_rdcntid     | inst_rdcntvl_w | inst_rdcntvh_w | inst_tlbsrch                |
                        inst_tlbrd       | inst_tlbwr     | inst_tlbfill   | inst_invtlb & ~ex_tlbinv_op |
                        inst_cacop       | inst_cpucfg    | inst_dbar      | inst_ibar                   |
                        inst_ll_w        | inst_sc_w      | inst_idle      | inst_preld                 );

//wire    ex_IPE;
wire    IPE_inst_plv0 = (inst_csrrd   | inst_csrwr                          | inst_csrxchg | inst_idle  |
                          inst_tlbfill | inst_tlbrd                          | inst_tlbsrch | inst_tlbwr |
                          inst_invtlb  | inst_ertn) & (csr_CRMD_PLV != 2'b00);
wire    cacop_ipe     = inst_cacop & (cache_code [4:3] == 2'b00 | cache_code [4:3] == 2'b01) & (csr_CRMD_PLV != 2'b00);
assign  ex_IPE        = IPE_inst_plv0 | cacop_ipe;
//------------------------{ex_INE}end-------------------------//

//-------------------------{branch prediction updata}begin---------------//
localparam        TYPE_COND     = 2'b00;//2'b00  COND   条件分支 beq/bne/blt/bge/bltu/bgeu
localparam        TYPE_JUMP     = 2'b01;//2'b01  JUMP   无条件直接跳转 b
localparam        TYPE_CALL     = 2'b10;//2'b10  CALL   bl跳转或 jirl 且 rd!=0
localparam        TYPE_RET      = 2'b11;//2'b11  RET    jirl 且 rd==0

//wire              real_taken;
//wire       [31:0] real_target;
//wire              pred_taken;
wire       [31:0] pred_target;
wire       [31:0] direct_target;

    //---------------{跳转分类}begin---------------//
 //   wire    is_cond ;
    wire    is_jirl_call;// jirl $rd==$r1 时当作调用call
 //   wire    is_jump ;// b 或 jirl 且 rd!=0
//  wire    is_call ;
 //   wire    is_ret  ;
    wire    is_indirect_jump;
    assign  is_cond          = inst_beq | inst_bne | inst_blt | inst_bge | inst_bltu | inst_bgeu;
    assign  is_jirl_call     = inst_jirl && (rd == 5'd1);
    assign  is_jump          = inst_b | is_indirect_jump;
    assign  is_call          = inst_bl | is_jirl_call;
    assign  is_ret           = inst_jirl & (rd == 5'd0) & (rj == 5'b1) & (i16 == 16'b0);
    assign  is_indirect_jump = inst_jirl && !is_jirl_call && !is_ret;//除了call和return的jirl都是间接跳转
    //output
    assign  is_br            = is_cond | is_jump | is_call | is_ret;
    assign  is_mem           = inst_ld_b | inst_ld_bu | inst_ld_h | inst_ld_hu | inst_ld_w |
                               inst_st_b | inst_st_h  | inst_st_w |
                               inst_ll_w | inst_sc_w ;

    assign  is_system_break  = inst_ertn | inst_syscall | inst_break | inst_idle | inst_ibar | inst_dbar | inst_cacop;
    assign  is_csr_write     = inst_csrwr | inst_csrxchg;
    assign  is_csr_read      = inst_csrrd | inst_rdcntid | inst_rdcntvl_w | inst_rdcntvh_w;
    assign  is_tlb           = inst_tlbfill  | inst_tlbrd | inst_tlbsrch | inst_tlbwr | inst_invtlb;   
    //---------------{跳转分类}end---------------//

    //---------------{跳转和对比表 有效 & 匹配}begin---------------//
   // wire  pred_valid;// 表示预测有效
   // wire  pred_ok ;
    /*
        之前做的是 dcache->rj->rj+imm->对比real->btb
        所以可以拆出来?
            dache->rj
                        ->对比real-imm & rj ->btb
            real-imm
        再比如jirl_pred_rj target_match
        assign pred_ok = pred_valid & (real_taken == pred_taken) & (!real_taken || (real_target == pred_target));//预测一致
    */
    wire   [31:0] jirl_pred_rj;
    wire          target_match;
    assign        jirl_pred_rj = pred_target - jirl_offs;
    assign        target_match = inst_jirl ? (rj_value_br == jirl_pred_rj) : (direct_target == pred_target);
    assign        pred_valid   = is_cond | is_jump | is_call | is_ret;//只需要这几种的br
    assign        pred_ok      = pred_valid & (real_taken == pred_taken) & (!real_taken || target_match);//预测一致
    //---------------{跳转和对比表 有效 & 匹配}end---------------//


assign  pred_taken  = (ras_query_hit && (query_type == TYPE_RET)) ||
                      (btb_query_hit && (query_type == TYPE_CALL || query_type == TYPE_JUMP)) ||
                      (query_taken && btb_query_hit && (query_type == TYPE_COND));
                    
assign  pred_target = (ras_query_hit && (query_type == TYPE_RET)) ? ras_query_target :
                      (btb_query_hit && (query_type == TYPE_CALL || query_type == TYPE_JUMP ||
                      (query_type == TYPE_COND && query_taken))) ? btb_query_target :
                      (pc + 32'd4);
assign  redirect    = slot_valid   & ~ex_ADEF & ((pred_valid & (real_taken != pred_taken)) |
                      (pred_valid  & real_taken & ~target_match)                           |
                      (~pred_valid & pred_taken));

/*                              );
assign  br_afterpred_taken  = redirect;
assign  br_afterpred_target = real_taken ? real_target : pc + 4;
assign  update_valid        = id_fire & pred_valid & ~ex_ADEF & ~pred_ok;
assign  bht_update_valid    = id_fire &&
                              is_cond && !ex_ADEF; 
assign  update_pc           = pc;
assign  update_target       = real_target;
assign  update_type         = is_cond ? TYPE_COND :
                              is_ret  ? TYPE_RET  :
                              is_call ? TYPE_CALL :
                              is_jump ? TYPE_JUMP :
                              TYPE_COND;
assign  update_taken        = real_taken;
assign  push_valid          = id_fire  & is_call & ~ex_ADEF;//真实call 要 push
assign  push_target         = pc + 32'd4;
assign  pop_valid           = is_ret & id_fire  & ~ex_ADEF;//真实return 要 pop
*/
//assign real_target = inst_jirl ? rf_rdata1 + jirl_offs : pc + br_offs;
//写回时只有inst_jirl执行完之后才会使用pc+br_offs
assign  direct_target   = pc + br_offs;
assign  real_target     = inst_jirl ? rf_rdata1_br + jirl_offs : direct_target;
assign  real_taken      = slot_valid & (
                           inst_jirl                                                  | inst_b | inst_bl |
                          (inst_beq & (rj_value_br == rkd_value_br))                        |
                          (inst_bne & (rj_value_br != rkd_value_br))                        |
                          (inst_blt & ($signed(rj_value_br) <  $signed(rkd_value_br)))      |
                          (inst_bge & ($signed(rj_value_br) >= $signed(rkd_value_br)))      |
                          (inst_bltu & ($unsigned(rj_value_br) <  $unsigned(rkd_value_br))) |
                          (inst_bgeu & ($unsigned(rj_value_br) >= $unsigned(rkd_value_br))));
                           //   ) & ID_ready_go & ID_valid;
//output
assign  upd_need        = pred_valid & ~ex_ADEF & ~pred_ok;//预测失败
assign  bht_upd_need    = is_cond & ~ex_ADEF;//条件分支预测失败
assign  push_need       = is_call & ~ex_ADEF;//真实call 要 push
assign  pop_need        = is_ret  & ~ex_ADEF;//真实return 要 pop
assign  br_type         = is_cond ? 2'b00 : is_ret ? 2'b11 : is_call ? 2'b10 : 2'b01;//条件分支/返回/调用/跳转
//-------------------------{branch prediction updata}end---------------//
assign  exe_payload = {
                       pc            ,
                       rkd_value     , alu_op              , alu_src1    , alu_src2    , need_stall_inst, need_stall_csr, inst_st_b, inst_st_h, inst_st_w, inst_ld_w,//EXE
                       res_from_mem  , mem_we              , inst_ld_b   , inst_ld_h   , inst_ld_bu     , inst_ld_hu    ,//MEM read and write
                       inst_csrrd    , inst_csrwr          , inst_csrxchg, inst_ertn   , inst_syscall   , inst_break    , ex_INE   , ex_IPE   , ex_ADEF  , has_int  , inst_rdcntvl_w, inst_rdcntvh_w, inst_rdcntid, csr_num, rj_value, rf_dest, rf_gr_we,//WB destination and write_enable
                       inst_tlbsrch  , inst_tlbrd          , inst_tlbwr  , inst_tlbfill, inst_invtlb    ,
                       ex_tlb_reload0, ex_tlb_preif_unvalid, ex_tlb_plv0 ,
                       cache_code    , inst_cacop          , inst_ibar   , inst_dbar   , inst_sc_w      , inst_ll_w     , inst_idle
                      };

endmodule