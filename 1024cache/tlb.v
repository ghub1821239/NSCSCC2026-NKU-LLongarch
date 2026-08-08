`include "csr_def.vh"
`timescale 1ns / 1ps

module tlb
#(
    parameter TLBNUM = 16
)
(
    input wire                  clk,
    input wire                  resetn,

    // search port 0 (for fetch the inst) 【preIF】
    input  wire [18:0] s0_vppn,
    input  wire        s0_va_bit12,
    input  wire [9:0]  s0_asid,
    output wire        s0_found,
    output wire [$clog2(TLBNUM)-1:0] s0_index, // 先向上取整再 log2（），这样来求出来位宽
    output wire [19:0] s0_ppn,
    output wire [5:0]  s0_ps,
    output wire [1:0]  s0_plv,
    output wire [1:0]  s0_mat,
    output wire        s0_d,
    output wire        s0_v,

    // search port 1 (for load/store the data) 【EXE】
    input  wire [18:0] s1_vppn,
    input  wire        s1_va_bit12,
    input  wire [9:0]  s1_asid,
    output wire        s1_found,
    output wire [$clog2(TLBNUM)-1:0] s1_index,
    output wire [19:0] s1_ppn,
    output wire [5:0]  s1_ps,
    output wire [1:0]  s1_plv,
    output wire [1:0]  s1_mat,
    output wire        s1_d,
    output wire        s1_v,

    // write port 【CSR】
    input wire        we,
    input wire [$clog2(TLBNUM)-1:0] w_index,
    input wire        w_e,
    input wire [18:0] w_vppn,
    input wire [5:0]  w_ps,
    input wire [9:0]  w_asid,
    input wire        w_g,
    input wire [19:0] w_ppn0,
    input wire [1:0]  w_plv0,
    input wire [1:0]  w_mat0,
    input wire        w_d0,
    input wire        w_v0,
    input wire [19:0] w_ppn1,
    input wire [1:0]  w_plv1,
    input wire [1:0]  w_mat1,
    input wire        w_d1,
    input wire        w_v1,

    // read port 【CSR】
    input wire [$clog2(TLBNUM)-1:0] r_index,
    output wire        r_e,
    output wire [18:0] r_vppn,
    output wire [5:0]  r_ps,
    output wire [9:0]  r_asid,
    output wire        r_g,
    output wire [19:0] r_ppn0,
    output wire [1:0]  r_plv0,
    output wire [1:0]  r_mat0,
    output wire        r_d0,
    output wire        r_v0,
    output wire [19:0] r_ppn1,
    output wire [1:0]  r_plv1,
    output wire [1:0]  r_mat1,
    output wire        r_d1,
    output wire        r_v1,
    input  wire [1:0]  csr_CRMD_PLV,

    //invtlb
    input wire        invtlb_valid,
    input wire [4:0]  invtlb_op,

    //tlb_ex
    output wire       ex_tlb_reload0,//tlb重填例外_s0
    output wire       ex_tlb_reload1,//tlb重填例外_s1
    output wire       ex_tlb_ld_unvalid,//tlb中load页无效
    output wire       ex_tlb_st_unvalid,//tlb中store页无效
    output wire       ex_tlb_preif_unvalid,//tlb中取指页无效
    output wire       ex_tlb_plv0,//tlb中页特权不合规_s0
    output wire       ex_tlb_plv1,//tlb中页特权不合规_s1
    output wire       ex_tlb_page_modify,//tlb中页修改
    
    input  wire       tlb_inst_req,
    input  wire       tlb_data_req,
    input  wire       tlb_load_req,
    input  wire       tlb_store_req,

    //DMW
    input  wire        dmw_found0,
    input  wire        dmw_found1
);
//----------------------------- regfile begin --------------------------
    reg [TLBNUM-1:0] tlb_e;
    reg [TLBNUM-1:0] tlb_ps4MB; // 1: 4MB, 0: 4KB
    reg [18:0] tlb_vppn [TLBNUM-1:0];
    reg [9:0]  tlb_asid [TLBNUM-1:0];
    reg        tlb_g    [TLBNUM-1:0];
    reg [19:0] tlb_ppn0 [TLBNUM-1:0];
    reg [1:0]  tlb_plv0 [TLBNUM-1:0];
    reg [1:0]  tlb_mat0 [TLBNUM-1:0];
    reg        tlb_d0   [TLBNUM-1:0];
    reg        tlb_v0   [TLBNUM-1:0];
    reg [19:0] tlb_ppn1 [TLBNUM-1:0];
    reg [1:0]  tlb_plv1 [TLBNUM-1:0];
    reg [1:0]  tlb_mat1 [TLBNUM-1:0];
    reg        tlb_d1   [TLBNUM-1:0];
    reg        tlb_v1   [TLBNUM-1:0];
//----------------------------- regfile end --------------------------

//----------------------------- query begin --------------------------
    wire [TLBNUM-1:0] match0;
    wire [TLBNUM-1:0] match1;
    wire        s0_ps4MB_sel;
    wire        s1_ps4MB_sel;
    wire        s0_odd_page;
    wire        s1_odd_page;
    wire [19:0] s0_ppn0_sel;
    wire [19:0] s0_ppn1_sel;
    wire [1:0]  s0_plv0_sel;
    wire [1:0]  s0_plv1_sel;
    wire [1:0]  s0_mat0_sel;
    wire [1:0]  s0_mat1_sel;
    wire        s0_d0_sel;
    wire        s0_d1_sel;
    wire        s0_v0_sel;
    wire        s0_v1_sel;
    wire [19:0] s1_ppn0_sel;
    wire [19:0] s1_ppn1_sel;
    wire [1:0]  s1_plv0_sel;
    wire [1:0]  s1_plv1_sel;
    wire [1:0]  s1_mat0_sel;
    wire [1:0]  s1_mat1_sel;
    wire        s1_d0_sel;
    wire        s1_d1_sel;
    wire        s1_v0_sel;
    wire        s1_v1_sel;
    reg  [TLBNUM-1:0] invtlb_clear;
    
    assign match0[ 0] = (s0_vppn[18:9] == tlb_vppn[ 0][18:9])
                     && (tlb_ps4MB[ 0] || s0_vppn[8:0] == tlb_vppn[ 0][8:0])
                     && ((s0_asid == tlb_asid[ 0]) || tlb_g[ 0]) && tlb_e[ 0];
    assign match0[ 1] = (s0_vppn[18:9] == tlb_vppn[ 1][18:9])
                     && (tlb_ps4MB[ 1] || s0_vppn[8:0] == tlb_vppn[ 1][8:0])
                     && ((s0_asid == tlb_asid[ 1]) || tlb_g[ 1]) && tlb_e[ 1];
    assign match0[ 2] = (s0_vppn[18:9] == tlb_vppn[ 2][18:9])
                     && (tlb_ps4MB[ 2] || s0_vppn[8:0] == tlb_vppn[ 2][8:0])
                     && ((s0_asid == tlb_asid[ 2]) || tlb_g[ 2]) && tlb_e[ 2];
    assign match0[ 3] = (s0_vppn[18:9] == tlb_vppn[ 3][18:9])
                     && (tlb_ps4MB[ 3] || s0_vppn[8:0] == tlb_vppn[ 3][8:0])
                     && ((s0_asid == tlb_asid[ 3]) || tlb_g[ 3]) && tlb_e[ 3];
    assign match0[ 4] = (s0_vppn[18:9] == tlb_vppn[ 4][18:9])
                     && (tlb_ps4MB[ 4] || s0_vppn[8:0] == tlb_vppn[ 4][8:0])
                     && ((s0_asid == tlb_asid[ 4]) || tlb_g[ 4]) && tlb_e[ 4];
    assign match0[ 5] = (s0_vppn[18:9] == tlb_vppn[ 5][18:9])
                     && (tlb_ps4MB[ 5] || s0_vppn[8:0] == tlb_vppn[ 5][8:0])
                     && ((s0_asid == tlb_asid[ 5]) || tlb_g[ 5]) && tlb_e[ 5];
    assign match0[ 6] = (s0_vppn[18:9] == tlb_vppn[ 6][18:9])
                     && (tlb_ps4MB[ 6] || s0_vppn[8:0] == tlb_vppn[ 6][8:0])
                     && ((s0_asid == tlb_asid[ 6]) || tlb_g[ 6]) && tlb_e[ 6];
    assign match0[ 7] = (s0_vppn[18:9] == tlb_vppn[ 7][18:9])
                     && (tlb_ps4MB[ 7] || s0_vppn[8:0] == tlb_vppn[ 7][8:0])
                     && ((s0_asid == tlb_asid[ 7]) || tlb_g[ 7]) && tlb_e[ 7];
    assign match0[ 8] = (s0_vppn[18:9] == tlb_vppn[ 8][18:9])
                     && (tlb_ps4MB[ 8] || s0_vppn[8:0] == tlb_vppn[ 8][8:0])
                     && ((s0_asid == tlb_asid[ 8]) || tlb_g[ 8]) && tlb_e[ 8];
    assign match0[ 9] = (s0_vppn[18:9] == tlb_vppn[ 9][18:9])
                     && (tlb_ps4MB[ 9] || s0_vppn[8:0] == tlb_vppn[ 9][8:0])
                     && ((s0_asid == tlb_asid[ 9]) || tlb_g[ 9]) && tlb_e[ 9];
    assign match0[10] = (s0_vppn[18:9] == tlb_vppn[10][18:9])
                     && (tlb_ps4MB[10] || s0_vppn[8:0] == tlb_vppn[10][8:0])
                     && ((s0_asid == tlb_asid[10]) || tlb_g[10]) && tlb_e[10];
    assign match0[11] = (s0_vppn[18:9] == tlb_vppn[11][18:9])
                     && (tlb_ps4MB[11] || s0_vppn[8:0] == tlb_vppn[11][8:0])
                     && ((s0_asid == tlb_asid[11]) || tlb_g[11]) && tlb_e[11];
    assign match0[12] = (s0_vppn[18:9] == tlb_vppn[12][18:9])
                     && (tlb_ps4MB[12] || s0_vppn[8:0] == tlb_vppn[12][8:0])
                     && ((s0_asid == tlb_asid[12]) || tlb_g[12]) && tlb_e[12];
    assign match0[13] = (s0_vppn[18:9] == tlb_vppn[13][18:9])
                     && (tlb_ps4MB[13] || s0_vppn[8:0] == tlb_vppn[13][8:0])
                     && ((s0_asid == tlb_asid[13]) || tlb_g[13]) && tlb_e[13];
    assign match0[14] = (s0_vppn[18:9] == tlb_vppn[14][18:9])
                     && (tlb_ps4MB[14] || s0_vppn[8:0] == tlb_vppn[14][8:0])
                     && ((s0_asid == tlb_asid[14]) || tlb_g[14]) && tlb_e[14];
    assign match0[15] = (s0_vppn[18:9] == tlb_vppn[15][18:9])
                     && (tlb_ps4MB[15] || s0_vppn[8:0] == tlb_vppn[15][8:0])
                     && ((s0_asid == tlb_asid[15]) || tlb_g[15]) && tlb_e[15];

    assign match1[ 0] = (s1_vppn[18:9] == tlb_vppn[ 0][18:9])
                     && (tlb_ps4MB[ 0] || s1_vppn[8:0] == tlb_vppn[ 0][8:0])
                     && ((s1_asid == tlb_asid[ 0]) || tlb_g[ 0]) && tlb_e[ 0];
    assign match1[ 1] = (s1_vppn[18:9] == tlb_vppn[ 1][18:9])
                     && (tlb_ps4MB[ 1] || s1_vppn[8:0] == tlb_vppn[ 1][8:0])
                     && ((s1_asid == tlb_asid[ 1]) || tlb_g[ 1]) && tlb_e[ 1];
    assign match1[ 2] = (s1_vppn[18:9] == tlb_vppn[ 2][18:9])
                     && (tlb_ps4MB[ 2] || s1_vppn[8:0] == tlb_vppn[ 2][8:0])
                     && ((s1_asid == tlb_asid[ 2]) || tlb_g[ 2]) && tlb_e[ 2];
    assign match1[ 3] = (s1_vppn[18:9] == tlb_vppn[ 3][18:9])
                     && (tlb_ps4MB[ 3] || s1_vppn[8:0] == tlb_vppn[ 3][8:0])
                     && ((s1_asid == tlb_asid[ 3]) || tlb_g[ 3]) && tlb_e[ 3];
    assign match1[ 4] = (s1_vppn[18:9] == tlb_vppn[ 4][18:9])
                     && (tlb_ps4MB[ 4] || s1_vppn[8:0] == tlb_vppn[ 4][8:0])
                     && ((s1_asid == tlb_asid[ 4]) || tlb_g[ 4]) && tlb_e[ 4];
    assign match1[ 5] = (s1_vppn[18:9] == tlb_vppn[ 5][18:9])
                     && (tlb_ps4MB[ 5] || s1_vppn[8:0] == tlb_vppn[ 5][8:0])
                     && ((s1_asid == tlb_asid[ 5]) || tlb_g[ 5]) && tlb_e[ 5];
    assign match1[ 6] = (s1_vppn[18:9] == tlb_vppn[ 6][18:9])
                     && (tlb_ps4MB[ 6] || s1_vppn[8:0] == tlb_vppn[ 6][8:0])
                     && ((s1_asid == tlb_asid[ 6]) || tlb_g[ 6]) && tlb_e[ 6];
    assign match1[ 7] = (s1_vppn[18:9] == tlb_vppn[ 7][18:9])
                     && (tlb_ps4MB[ 7] || s1_vppn[8:0] == tlb_vppn[ 7][8:0])
                     && ((s1_asid == tlb_asid[ 7]) || tlb_g[ 7]) && tlb_e[ 7];
    assign match1[ 8] = (s1_vppn[18:9] == tlb_vppn[ 8][18:9])
                     && (tlb_ps4MB[ 8] || s1_vppn[8:0] == tlb_vppn[ 8][8:0])
                     && ((s1_asid == tlb_asid[ 8]) || tlb_g[ 8]) && tlb_e[ 8];
    assign match1[ 9] = (s1_vppn[18:9] == tlb_vppn[ 9][18:9])
                     && (tlb_ps4MB[ 9] || s1_vppn[8:0] == tlb_vppn[ 9][8:0])
                     && ((s1_asid == tlb_asid[ 9]) || tlb_g[ 9]) && tlb_e[ 9];
    assign match1[10] = (s1_vppn[18:9] == tlb_vppn[10][18:9])
                     && (tlb_ps4MB[10] || s1_vppn[8:0] == tlb_vppn[10][8:0])
                     && ((s1_asid == tlb_asid[10]) || tlb_g[10]) && tlb_e[10];
    assign match1[11] = (s1_vppn[18:9] == tlb_vppn[11][18:9])
                     && (tlb_ps4MB[11] || s1_vppn[8:0] == tlb_vppn[11][8:0])
                     && ((s1_asid == tlb_asid[11]) || tlb_g[11]) && tlb_e[11];
    assign match1[12] = (s1_vppn[18:9] == tlb_vppn[12][18:9])
                     && (tlb_ps4MB[12] || s1_vppn[8:0] == tlb_vppn[12][8:0])
                     && ((s1_asid == tlb_asid[12]) || tlb_g[12]) && tlb_e[12];
    assign match1[13] = (s1_vppn[18:9] == tlb_vppn[13][18:9])
                     && (tlb_ps4MB[13] || s1_vppn[8:0] == tlb_vppn[13][8:0])
                     && ((s1_asid == tlb_asid[13]) || tlb_g[13]) && tlb_e[13];
    assign match1[14] = (s1_vppn[18:9] == tlb_vppn[14][18:9])
                     && (tlb_ps4MB[14] || s1_vppn[8:0] == tlb_vppn[14][8:0])
                     && ((s1_asid == tlb_asid[14]) || tlb_g[14]) && tlb_e[14];
    assign match1[15] = (s1_vppn[18:9] == tlb_vppn[15][18:9])
                     && (tlb_ps4MB[15] || s1_vppn[8:0] == tlb_vppn[15][8:0])
                     && ((s1_asid == tlb_asid[15]) || tlb_g[15]) && tlb_e[15];

    // 只要不全为 0 就算是匹配成功了
    assign s0_found = |match0;
    assign s1_found = |match1;
    // inst 找到的页表项
    assign s0_index = ({4{match0[ 0]}} & 4'd0 ) |
                      ({4{match0[ 1]}} & 4'd1 ) |
                      ({4{match0[ 2]}} & 4'd2 ) |
                      ({4{match0[ 3]}} & 4'd3 ) |
                      ({4{match0[ 4]}} & 4'd4 ) |
                      ({4{match0[ 5]}} & 4'd5 ) |
                      ({4{match0[ 6]}} & 4'd6 ) |
                      ({4{match0[ 7]}} & 4'd7 ) |
                      ({4{match0[ 8]}} & 4'd8 ) |
                      ({4{match0[ 9]}} & 4'd9 ) |
                      ({4{match0[10]}} & 4'd10) |
                      ({4{match0[11]}} & 4'd11) |
                      ({4{match0[12]}} & 4'd12) |
                      ({4{match0[13]}} & 4'd13) |
                      ({4{match0[14]}} & 4'd14) |
                      ({4{match0[15]}} & 4'd15);
    // data 找到的页表项索引
    assign s1_index = ({4{match1[ 0]}} & 4'd0 ) |
                      ({4{match1[ 1]}} & 4'd1 ) |
                      ({4{match1[ 2]}} & 4'd2 ) |
                      ({4{match1[ 3]}} & 4'd3 ) |
                      ({4{match1[ 4]}} & 4'd4 ) |
                      ({4{match1[ 5]}} & 4'd5 ) |
                      ({4{match1[ 6]}} & 4'd6 ) |
                      ({4{match1[ 7]}} & 4'd7 ) |
                      ({4{match1[ 8]}} & 4'd8 ) |
                      ({4{match1[ 9]}} & 4'd9 ) |
                      ({4{match1[10]}} & 4'd10) |
                      ({4{match1[11]}} & 4'd11) |
                      ({4{match1[12]}} & 4'd12) |
                      ({4{match1[13]}} & 4'd13) |
                      ({4{match1[14]}} & 4'd14) |
                      ({4{match1[15]}} & 4'd15);
    // 当前inst这次处理的页表项对应的是否是 4MB 的
    assign s0_ps4MB_sel = ((s0_index == 4'd0 ) & tlb_ps4MB[ 0]) |
                          ((s0_index == 4'd1 ) & tlb_ps4MB[ 1]) |
                          ((s0_index == 4'd2 ) & tlb_ps4MB[ 2]) |
                          ((s0_index == 4'd3 ) & tlb_ps4MB[ 3]) |
                          ((s0_index == 4'd4 ) & tlb_ps4MB[ 4]) |
                          ((s0_index == 4'd5 ) & tlb_ps4MB[ 5]) |
                          ((s0_index == 4'd6 ) & tlb_ps4MB[ 6]) |
                          ((s0_index == 4'd7 ) & tlb_ps4MB[ 7]) |
                          ((s0_index == 4'd8 ) & tlb_ps4MB[ 8]) |
                          ((s0_index == 4'd9 ) & tlb_ps4MB[ 9]) |
                          ((s0_index == 4'd10) & tlb_ps4MB[10]) |
                          ((s0_index == 4'd11) & tlb_ps4MB[11]) |
                          ((s0_index == 4'd12) & tlb_ps4MB[12]) |
                          ((s0_index == 4'd13) & tlb_ps4MB[13]) |
                          ((s0_index == 4'd14) & tlb_ps4MB[14]) |
                          ((s0_index == 4'd15) & tlb_ps4MB[15]);
    // 当前data这次处理的页表项对应的是否是 4MB 的
    assign s1_ps4MB_sel = ((s1_index == 4'd0 ) & tlb_ps4MB[ 0]) |
                          ((s1_index == 4'd1 ) & tlb_ps4MB[ 1]) |
                          ((s1_index == 4'd2 ) & tlb_ps4MB[ 2]) |
                          ((s1_index == 4'd3 ) & tlb_ps4MB[ 3]) |
                          ((s1_index == 4'd4 ) & tlb_ps4MB[ 4]) |
                          ((s1_index == 4'd5 ) & tlb_ps4MB[ 5]) |
                          ((s1_index == 4'd6 ) & tlb_ps4MB[ 6]) |
                          ((s1_index == 4'd7 ) & tlb_ps4MB[ 7]) |
                          ((s1_index == 4'd8 ) & tlb_ps4MB[ 8]) |
                          ((s1_index == 4'd9 ) & tlb_ps4MB[ 9]) |
                          ((s1_index == 4'd10) & tlb_ps4MB[10]) |
                          ((s1_index == 4'd11) & tlb_ps4MB[11]) |
                          ((s1_index == 4'd12) & tlb_ps4MB[12]) |
                          ((s1_index == 4'd13) & tlb_ps4MB[13]) |
                          ((s1_index == 4'd14) & tlb_ps4MB[14]) |
                          ((s1_index == 4'd15) & tlb_ps4MB[15]);
    // 如果是 4MB 那么对应的就需要看传入的[8]来判定是否是 也就是判定 PPN 0/1 的 
    // 如果是 1 的话那么就选择 PPN1
    assign s0_odd_page = s0_ps4MB_sel ? s0_vppn[8] : s0_va_bit12;
    assign s1_odd_page = s1_ps4MB_sel ? s1_vppn[8] : s1_va_bit12;
    // inst 选中的页表的索引（19：0 -- 4KB ； 19：9 -- 4MB）
    // 这里 PALEN 目前默认是 32 所以是 32-12=20
    assign s0_ppn0_sel = ({20{(s0_index == 4'd0 )}} & tlb_ppn0[ 0]) |
                         ({20{(s0_index == 4'd1 )}} & tlb_ppn0[ 1]) |
                         ({20{(s0_index == 4'd2 )}} & tlb_ppn0[ 2]) |
                         ({20{(s0_index == 4'd3 )}} & tlb_ppn0[ 3]) |
                         ({20{(s0_index == 4'd4 )}} & tlb_ppn0[ 4]) |
                         ({20{(s0_index == 4'd5 )}} & tlb_ppn0[ 5]) |
                         ({20{(s0_index == 4'd6 )}} & tlb_ppn0[ 6]) |
                         ({20{(s0_index == 4'd7 )}} & tlb_ppn0[ 7]) |
                         ({20{(s0_index == 4'd8 )}} & tlb_ppn0[ 8]) |
                         ({20{(s0_index == 4'd9 )}} & tlb_ppn0[ 9]) |
                         ({20{(s0_index == 4'd10)}} & tlb_ppn0[10]) |
                         ({20{(s0_index == 4'd11)}} & tlb_ppn0[11]) |
                         ({20{(s0_index == 4'd12)}} & tlb_ppn0[12]) |
                         ({20{(s0_index == 4'd13)}} & tlb_ppn0[13]) |
                         ({20{(s0_index == 4'd14)}} & tlb_ppn0[14]) |
                         ({20{(s0_index == 4'd15)}} & tlb_ppn0[15]);
    assign s0_ppn1_sel = ({20{(s0_index == 4'd0 )}} & tlb_ppn1[ 0]) |
                         ({20{(s0_index == 4'd1 )}} & tlb_ppn1[ 1]) |
                         ({20{(s0_index == 4'd2 )}} & tlb_ppn1[ 2]) |
                         ({20{(s0_index == 4'd3 )}} & tlb_ppn1[ 3]) |
                         ({20{(s0_index == 4'd4 )}} & tlb_ppn1[ 4]) |
                         ({20{(s0_index == 4'd5 )}} & tlb_ppn1[ 5]) |
                         ({20{(s0_index == 4'd6 )}} & tlb_ppn1[ 6]) |
                         ({20{(s0_index == 4'd7 )}} & tlb_ppn1[ 7]) |
                         ({20{(s0_index == 4'd8 )}} & tlb_ppn1[ 8]) |
                         ({20{(s0_index == 4'd9 )}} & tlb_ppn1[ 9]) |
                         ({20{(s0_index == 4'd10)}} & tlb_ppn1[10]) |
                         ({20{(s0_index == 4'd11)}} & tlb_ppn1[11]) |
                         ({20{(s0_index == 4'd12)}} & tlb_ppn1[12]) |
                         ({20{(s0_index == 4'd13)}} & tlb_ppn1[13]) |
                         ({20{(s0_index == 4'd14)}} & tlb_ppn1[14]) |
                         ({20{(s0_index == 4'd15)}} & tlb_ppn1[15]);
    assign s0_plv0_sel = ({2{(s0_index == 4'd0 )}} & tlb_plv0[ 0]) |
                         ({2{(s0_index == 4'd1 )}} & tlb_plv0[ 1]) |
                         ({2{(s0_index == 4'd2 )}} & tlb_plv0[ 2]) |
                         ({2{(s0_index == 4'd3 )}} & tlb_plv0[ 3]) |
                         ({2{(s0_index == 4'd4 )}} & tlb_plv0[ 4]) |
                         ({2{(s0_index == 4'd5 )}} & tlb_plv0[ 5]) |
                         ({2{(s0_index == 4'd6 )}} & tlb_plv0[ 6]) |
                         ({2{(s0_index == 4'd7 )}} & tlb_plv0[ 7]) |
                         ({2{(s0_index == 4'd8 )}} & tlb_plv0[ 8]) |
                         ({2{(s0_index == 4'd9 )}} & tlb_plv0[ 9]) |
                         ({2{(s0_index == 4'd10)}} & tlb_plv0[10]) |
                         ({2{(s0_index == 4'd11)}} & tlb_plv0[11]) |
                         ({2{(s0_index == 4'd12)}} & tlb_plv0[12]) |
                         ({2{(s0_index == 4'd13)}} & tlb_plv0[13]) |
                         ({2{(s0_index == 4'd14)}} & tlb_plv0[14]) |
                         ({2{(s0_index == 4'd15)}} & tlb_plv0[15]);
    assign s0_plv1_sel = ({2{(s0_index == 4'd0 )}} & tlb_plv1[ 0]) |
                         ({2{(s0_index == 4'd1 )}} & tlb_plv1[ 1]) |
                         ({2{(s0_index == 4'd2 )}} & tlb_plv1[ 2]) |
                         ({2{(s0_index == 4'd3 )}} & tlb_plv1[ 3]) |
                         ({2{(s0_index == 4'd4 )}} & tlb_plv1[ 4]) |
                         ({2{(s0_index == 4'd5 )}} & tlb_plv1[ 5]) |
                         ({2{(s0_index == 4'd6 )}} & tlb_plv1[ 6]) |
                         ({2{(s0_index == 4'd7 )}} & tlb_plv1[ 7]) |
                         ({2{(s0_index == 4'd8 )}} & tlb_plv1[ 8]) |
                         ({2{(s0_index == 4'd9 )}} & tlb_plv1[ 9]) |
                         ({2{(s0_index == 4'd10)}} & tlb_plv1[10]) |
                         ({2{(s0_index == 4'd11)}} & tlb_plv1[11]) |
                         ({2{(s0_index == 4'd12)}} & tlb_plv1[12]) |
                         ({2{(s0_index == 4'd13)}} & tlb_plv1[13]) |
                         ({2{(s0_index == 4'd14)}} & tlb_plv1[14]) |
                         ({2{(s0_index == 4'd15)}} & tlb_plv1[15]);
    assign s0_mat0_sel = ({2{(s0_index == 4'd0 )}} & tlb_mat0[ 0]) |
                         ({2{(s0_index == 4'd1 )}} & tlb_mat0[ 1]) |
                         ({2{(s0_index == 4'd2 )}} & tlb_mat0[ 2]) |
                         ({2{(s0_index == 4'd3 )}} & tlb_mat0[ 3]) |
                         ({2{(s0_index == 4'd4 )}} & tlb_mat0[ 4]) |
                         ({2{(s0_index == 4'd5 )}} & tlb_mat0[ 5]) |
                         ({2{(s0_index == 4'd6 )}} & tlb_mat0[ 6]) |
                         ({2{(s0_index == 4'd7 )}} & tlb_mat0[ 7]) |
                         ({2{(s0_index == 4'd8 )}} & tlb_mat0[ 8]) |
                         ({2{(s0_index == 4'd9 )}} & tlb_mat0[ 9]) |
                         ({2{(s0_index == 4'd10)}} & tlb_mat0[10]) |
                         ({2{(s0_index == 4'd11)}} & tlb_mat0[11]) |
                         ({2{(s0_index == 4'd12)}} & tlb_mat0[12]) |
                         ({2{(s0_index == 4'd13)}} & tlb_mat0[13]) |
                         ({2{(s0_index == 4'd14)}} & tlb_mat0[14]) |
                         ({2{(s0_index == 4'd15)}} & tlb_mat0[15]);
    assign s0_mat1_sel = ({2{(s0_index == 4'd0 )}} & tlb_mat1[ 0]) |
                         ({2{(s0_index == 4'd1 )}} & tlb_mat1[ 1]) |
                         ({2{(s0_index == 4'd2 )}} & tlb_mat1[ 2]) |
                         ({2{(s0_index == 4'd3 )}} & tlb_mat1[ 3]) |
                         ({2{(s0_index == 4'd4 )}} & tlb_mat1[ 4]) |
                         ({2{(s0_index == 4'd5 )}} & tlb_mat1[ 5]) |
                         ({2{(s0_index == 4'd6 )}} & tlb_mat1[ 6]) |
                         ({2{(s0_index == 4'd7 )}} & tlb_mat1[ 7]) |
                         ({2{(s0_index == 4'd8 )}} & tlb_mat1[ 8]) |
                         ({2{(s0_index == 4'd9 )}} & tlb_mat1[ 9]) |
                         ({2{(s0_index == 4'd10)}} & tlb_mat1[10]) |
                         ({2{(s0_index == 4'd11)}} & tlb_mat1[11]) |
                         ({2{(s0_index == 4'd12)}} & tlb_mat1[12]) |
                         ({2{(s0_index == 4'd13)}} & tlb_mat1[13]) |
                         ({2{(s0_index == 4'd14)}} & tlb_mat1[14]) |
                         ({2{(s0_index == 4'd15)}} & tlb_mat1[15]);
    assign s0_d0_sel = ({1{(s0_index == 4'd0 )}} & tlb_d0[ 0]) |
                         ({1{(s0_index == 4'd1 )}} & tlb_d0[ 1]) |
                         ({1{(s0_index == 4'd2 )}} & tlb_d0[ 2]) |
                         ({1{(s0_index == 4'd3 )}} & tlb_d0[ 3]) |
                         ({1{(s0_index == 4'd4 )}} & tlb_d0[ 4]) |
                         ({1{(s0_index == 4'd5 )}} & tlb_d0[ 5]) |
                         ({1{(s0_index == 4'd6 )}} & tlb_d0[ 6]) |
                         ({1{(s0_index == 4'd7 )}} & tlb_d0[ 7]) |
                         ({1{(s0_index == 4'd8 )}} & tlb_d0[ 8]) |
                         ({1{(s0_index == 4'd9 )}} & tlb_d0[ 9]) |
                         ({1{(s0_index == 4'd10)}} & tlb_d0[10]) |
                         ({1{(s0_index == 4'd11)}} & tlb_d0[11]) |
                         ({1{(s0_index == 4'd12)}} & tlb_d0[12]) |
                         ({1{(s0_index == 4'd13)}} & tlb_d0[13]) |
                         ({1{(s0_index == 4'd14)}} & tlb_d0[14]) |
                         ({1{(s0_index == 4'd15)}} & tlb_d0[15]);
    assign s0_d1_sel = ({1{(s0_index == 4'd0 )}} & tlb_d1[ 0]) |
                         ({1{(s0_index == 4'd1 )}} & tlb_d1[ 1]) |
                         ({1{(s0_index == 4'd2 )}} & tlb_d1[ 2]) |
                         ({1{(s0_index == 4'd3 )}} & tlb_d1[ 3]) |
                         ({1{(s0_index == 4'd4 )}} & tlb_d1[ 4]) |
                         ({1{(s0_index == 4'd5 )}} & tlb_d1[ 5]) |
                         ({1{(s0_index == 4'd6 )}} & tlb_d1[ 6]) |
                         ({1{(s0_index == 4'd7 )}} & tlb_d1[ 7]) |
                         ({1{(s0_index == 4'd8 )}} & tlb_d1[ 8]) |
                         ({1{(s0_index == 4'd9 )}} & tlb_d1[ 9]) |
                         ({1{(s0_index == 4'd10)}} & tlb_d1[10]) |
                         ({1{(s0_index == 4'd11)}} & tlb_d1[11]) |
                         ({1{(s0_index == 4'd12)}} & tlb_d1[12]) |
                         ({1{(s0_index == 4'd13)}} & tlb_d1[13]) |
                         ({1{(s0_index == 4'd14)}} & tlb_d1[14]) |
                         ({1{(s0_index == 4'd15)}} & tlb_d1[15]);
    assign s0_v0_sel = ({1{(s0_index == 4'd0 )}} & tlb_v0[ 0]) |
                         ({1{(s0_index == 4'd1 )}} & tlb_v0[ 1]) |
                         ({1{(s0_index == 4'd2 )}} & tlb_v0[ 2]) |
                         ({1{(s0_index == 4'd3 )}} & tlb_v0[ 3]) |
                         ({1{(s0_index == 4'd4 )}} & tlb_v0[ 4]) |
                         ({1{(s0_index == 4'd5 )}} & tlb_v0[ 5]) |
                         ({1{(s0_index == 4'd6 )}} & tlb_v0[ 6]) |
                         ({1{(s0_index == 4'd7 )}} & tlb_v0[ 7]) |
                         ({1{(s0_index == 4'd8 )}} & tlb_v0[ 8]) |
                         ({1{(s0_index == 4'd9 )}} & tlb_v0[ 9]) |
                         ({1{(s0_index == 4'd10)}} & tlb_v0[10]) |
                         ({1{(s0_index == 4'd11)}} & tlb_v0[11]) |
                         ({1{(s0_index == 4'd12)}} & tlb_v0[12]) |
                         ({1{(s0_index == 4'd13)}} & tlb_v0[13]) |
                         ({1{(s0_index == 4'd14)}} & tlb_v0[14]) |
                         ({1{(s0_index == 4'd15)}} & tlb_v0[15]);
    assign s0_v1_sel = ({1{(s0_index == 4'd0 )}} & tlb_v1[ 0]) |
                         ({1{(s0_index == 4'd1 )}} & tlb_v1[ 1]) |
                         ({1{(s0_index == 4'd2 )}} & tlb_v1[ 2]) |
                         ({1{(s0_index == 4'd3 )}} & tlb_v1[ 3]) |
                         ({1{(s0_index == 4'd4 )}} & tlb_v1[ 4]) |
                         ({1{(s0_index == 4'd5 )}} & tlb_v1[ 5]) |
                         ({1{(s0_index == 4'd6 )}} & tlb_v1[ 6]) |
                         ({1{(s0_index == 4'd7 )}} & tlb_v1[ 7]) |
                         ({1{(s0_index == 4'd8 )}} & tlb_v1[ 8]) |
                         ({1{(s0_index == 4'd9 )}} & tlb_v1[ 9]) |
                         ({1{(s0_index == 4'd10)}} & tlb_v1[10]) |
                         ({1{(s0_index == 4'd11)}} & tlb_v1[11]) |
                         ({1{(s0_index == 4'd12)}} & tlb_v1[12]) |
                         ({1{(s0_index == 4'd13)}} & tlb_v1[13]) |
                         ({1{(s0_index == 4'd14)}} & tlb_v1[14]) |
                         ({1{(s0_index == 4'd15)}} & tlb_v1[15]);
    // data 开始匹配选择
    assign s1_ppn0_sel = ({20{(s1_index == 4'd0 )}} & tlb_ppn0[ 0]) |
                         ({20{(s1_index == 4'd1 )}} & tlb_ppn0[ 1]) |
                         ({20{(s1_index == 4'd2 )}} & tlb_ppn0[ 2]) |
                         ({20{(s1_index == 4'd3 )}} & tlb_ppn0[ 3]) |
                         ({20{(s1_index == 4'd4 )}} & tlb_ppn0[ 4]) |
                         ({20{(s1_index == 4'd5 )}} & tlb_ppn0[ 5]) |
                         ({20{(s1_index == 4'd6 )}} & tlb_ppn0[ 6]) |
                         ({20{(s1_index == 4'd7 )}} & tlb_ppn0[ 7]) |
                         ({20{(s1_index == 4'd8 )}} & tlb_ppn0[ 8]) |
                         ({20{(s1_index == 4'd9 )}} & tlb_ppn0[ 9]) |
                         ({20{(s1_index == 4'd10)}} & tlb_ppn0[10]) |
                         ({20{(s1_index == 4'd11)}} & tlb_ppn0[11]) |
                         ({20{(s1_index == 4'd12)}} & tlb_ppn0[12]) |
                         ({20{(s1_index == 4'd13)}} & tlb_ppn0[13]) |
                         ({20{(s1_index == 4'd14)}} & tlb_ppn0[14]) |
                         ({20{(s1_index == 4'd15)}} & tlb_ppn0[15]);
    assign s1_ppn1_sel = ({20{(s1_index == 4'd0 )}} & tlb_ppn1[ 0]) |
                         ({20{(s1_index == 4'd1 )}} & tlb_ppn1[ 1]) |
                         ({20{(s1_index == 4'd2 )}} & tlb_ppn1[ 2]) |
                         ({20{(s1_index == 4'd3 )}} & tlb_ppn1[ 3]) |
                         ({20{(s1_index == 4'd4 )}} & tlb_ppn1[ 4]) |
                         ({20{(s1_index == 4'd5 )}} & tlb_ppn1[ 5]) |
                         ({20{(s1_index == 4'd6 )}} & tlb_ppn1[ 6]) |
                         ({20{(s1_index == 4'd7 )}} & tlb_ppn1[ 7]) |
                         ({20{(s1_index == 4'd8 )}} & tlb_ppn1[ 8]) |
                         ({20{(s1_index == 4'd9 )}} & tlb_ppn1[ 9]) |
                         ({20{(s1_index == 4'd10)}} & tlb_ppn1[10]) |
                         ({20{(s1_index == 4'd11)}} & tlb_ppn1[11]) |
                         ({20{(s1_index == 4'd12)}} & tlb_ppn1[12]) |
                         ({20{(s1_index == 4'd13)}} & tlb_ppn1[13]) |
                         ({20{(s1_index == 4'd14)}} & tlb_ppn1[14]) |
                         ({20{(s1_index == 4'd15)}} & tlb_ppn1[15]);
    assign s1_plv0_sel = ({2{(s1_index == 4'd0 )}} & tlb_plv0[ 0]) |
                         ({2{(s1_index == 4'd1 )}} & tlb_plv0[ 1]) |
                         ({2{(s1_index == 4'd2 )}} & tlb_plv0[ 2]) |
                         ({2{(s1_index == 4'd3 )}} & tlb_plv0[ 3]) |
                         ({2{(s1_index == 4'd4 )}} & tlb_plv0[ 4]) |
                         ({2{(s1_index == 4'd5 )}} & tlb_plv0[ 5]) |
                         ({2{(s1_index == 4'd6 )}} & tlb_plv0[ 6]) |
                         ({2{(s1_index == 4'd7 )}} & tlb_plv0[ 7]) |
                         ({2{(s1_index == 4'd8 )}} & tlb_plv0[ 8]) |
                         ({2{(s1_index == 4'd9 )}} & tlb_plv0[ 9]) |
                         ({2{(s1_index == 4'd10)}} & tlb_plv0[10]) |
                         ({2{(s1_index == 4'd11)}} & tlb_plv0[11]) |
                         ({2{(s1_index == 4'd12)}} & tlb_plv0[12]) |
                         ({2{(s1_index == 4'd13)}} & tlb_plv0[13]) |
                         ({2{(s1_index == 4'd14)}} & tlb_plv0[14]) |
                         ({2{(s1_index == 4'd15)}} & tlb_plv0[15]);
    assign s1_plv1_sel = ({2{(s1_index == 4'd0 )}} & tlb_plv1[ 0]) |
                         ({2{(s1_index == 4'd1 )}} & tlb_plv1[ 1]) |
                         ({2{(s1_index == 4'd2 )}} & tlb_plv1[ 2]) |
                         ({2{(s1_index == 4'd3 )}} & tlb_plv1[ 3]) |
                         ({2{(s1_index == 4'd4 )}} & tlb_plv1[ 4]) |
                         ({2{(s1_index == 4'd5 )}} & tlb_plv1[ 5]) |
                         ({2{(s1_index == 4'd6 )}} & tlb_plv1[ 6]) |
                         ({2{(s1_index == 4'd7 )}} & tlb_plv1[ 7]) |
                         ({2{(s1_index == 4'd8 )}} & tlb_plv1[ 8]) |
                         ({2{(s1_index == 4'd9 )}} & tlb_plv1[ 9]) |
                         ({2{(s1_index == 4'd10)}} & tlb_plv1[10]) |
                         ({2{(s1_index == 4'd11)}} & tlb_plv1[11]) |
                         ({2{(s1_index == 4'd12)}} & tlb_plv1[12]) |
                         ({2{(s1_index == 4'd13)}} & tlb_plv1[13]) |
                         ({2{(s1_index == 4'd14)}} & tlb_plv1[14]) |
                         ({2{(s1_index == 4'd15)}} & tlb_plv1[15]);
    assign s1_mat0_sel = ({2{(s1_index == 4'd0 )}} & tlb_mat0[ 0]) |
                         ({2{(s1_index == 4'd1 )}} & tlb_mat0[ 1]) |
                         ({2{(s1_index == 4'd2 )}} & tlb_mat0[ 2]) |
                         ({2{(s1_index == 4'd3 )}} & tlb_mat0[ 3]) |
                         ({2{(s1_index == 4'd4 )}} & tlb_mat0[ 4]) |
                         ({2{(s1_index == 4'd5 )}} & tlb_mat0[ 5]) |
                         ({2{(s1_index == 4'd6 )}} & tlb_mat0[ 6]) |
                         ({2{(s1_index == 4'd7 )}} & tlb_mat0[ 7]) |
                         ({2{(s1_index == 4'd8 )}} & tlb_mat0[ 8]) |
                         ({2{(s1_index == 4'd9 )}} & tlb_mat0[ 9]) |
                         ({2{(s1_index == 4'd10)}} & tlb_mat0[10]) |
                         ({2{(s1_index == 4'd11)}} & tlb_mat0[11]) |
                         ({2{(s1_index == 4'd12)}} & tlb_mat0[12]) |
                         ({2{(s1_index == 4'd13)}} & tlb_mat0[13]) |
                         ({2{(s1_index == 4'd14)}} & tlb_mat0[14]) |
                         ({2{(s1_index == 4'd15)}} & tlb_mat0[15]);
    assign s1_mat1_sel = ({2{(s1_index == 4'd0 )}} & tlb_mat1[ 0]) |
                         ({2{(s1_index == 4'd1 )}} & tlb_mat1[ 1]) |
                         ({2{(s1_index == 4'd2 )}} & tlb_mat1[ 2]) |
                         ({2{(s1_index == 4'd3 )}} & tlb_mat1[ 3]) |
                         ({2{(s1_index == 4'd4 )}} & tlb_mat1[ 4]) |
                         ({2{(s1_index == 4'd5 )}} & tlb_mat1[ 5]) |
                         ({2{(s1_index == 4'd6 )}} & tlb_mat1[ 6]) |
                         ({2{(s1_index == 4'd7 )}} & tlb_mat1[ 7]) |
                         ({2{(s1_index == 4'd8 )}} & tlb_mat1[ 8]) |
                         ({2{(s1_index == 4'd9 )}} & tlb_mat1[ 9]) |
                         ({2{(s1_index == 4'd10)}} & tlb_mat1[10]) |
                         ({2{(s1_index == 4'd11)}} & tlb_mat1[11]) |
                         ({2{(s1_index == 4'd12)}} & tlb_mat1[12]) |
                         ({2{(s1_index == 4'd13)}} & tlb_mat1[13]) |
                         ({2{(s1_index == 4'd14)}} & tlb_mat1[14]) |
                         ({2{(s1_index == 4'd15)}} & tlb_mat1[15]);
    assign s1_d0_sel = ({1{(s1_index == 4'd0 )}} & tlb_d0[ 0]) |
                         ({1{(s1_index == 4'd1 )}} & tlb_d0[ 1]) |
                         ({1{(s1_index == 4'd2 )}} & tlb_d0[ 2]) |
                         ({1{(s1_index == 4'd3 )}} & tlb_d0[ 3]) |
                         ({1{(s1_index == 4'd4 )}} & tlb_d0[ 4]) |
                         ({1{(s1_index == 4'd5 )}} & tlb_d0[ 5]) |
                         ({1{(s1_index == 4'd6 )}} & tlb_d0[ 6]) |
                         ({1{(s1_index == 4'd7 )}} & tlb_d0[ 7]) |
                         ({1{(s1_index == 4'd8 )}} & tlb_d0[ 8]) |
                         ({1{(s1_index == 4'd9 )}} & tlb_d0[ 9]) |
                         ({1{(s1_index == 4'd10)}} & tlb_d0[10]) |
                         ({1{(s1_index == 4'd11)}} & tlb_d0[11]) |
                         ({1{(s1_index == 4'd12)}} & tlb_d0[12]) |
                         ({1{(s1_index == 4'd13)}} & tlb_d0[13]) |
                         ({1{(s1_index == 4'd14)}} & tlb_d0[14]) |
                         ({1{(s1_index == 4'd15)}} & tlb_d0[15]);
    assign s1_d1_sel = ({1{(s1_index == 4'd0 )}} & tlb_d1[ 0]) |
                         ({1{(s1_index == 4'd1 )}} & tlb_d1[ 1]) |
                         ({1{(s1_index == 4'd2 )}} & tlb_d1[ 2]) |
                         ({1{(s1_index == 4'd3 )}} & tlb_d1[ 3]) |
                         ({1{(s1_index == 4'd4 )}} & tlb_d1[ 4]) |
                         ({1{(s1_index == 4'd5 )}} & tlb_d1[ 5]) |
                         ({1{(s1_index == 4'd6 )}} & tlb_d1[ 6]) |
                         ({1{(s1_index == 4'd7 )}} & tlb_d1[ 7]) |
                         ({1{(s1_index == 4'd8 )}} & tlb_d1[ 8]) |
                         ({1{(s1_index == 4'd9 )}} & tlb_d1[ 9]) |
                         ({1{(s1_index == 4'd10)}} & tlb_d1[10]) |
                         ({1{(s1_index == 4'd11)}} & tlb_d1[11]) |
                         ({1{(s1_index == 4'd12)}} & tlb_d1[12]) |
                         ({1{(s1_index == 4'd13)}} & tlb_d1[13]) |
                         ({1{(s1_index == 4'd14)}} & tlb_d1[14]) |
                         ({1{(s1_index == 4'd15)}} & tlb_d1[15]);
    assign s1_v0_sel = ({1{(s1_index == 4'd0 )}} & tlb_v0[ 0]) |
                         ({1{(s1_index == 4'd1 )}} & tlb_v0[ 1]) |
                         ({1{(s1_index == 4'd2 )}} & tlb_v0[ 2]) |
                         ({1{(s1_index == 4'd3 )}} & tlb_v0[ 3]) |
                         ({1{(s1_index == 4'd4 )}} & tlb_v0[ 4]) |
                         ({1{(s1_index == 4'd5 )}} & tlb_v0[ 5]) |
                         ({1{(s1_index == 4'd6 )}} & tlb_v0[ 6]) |
                         ({1{(s1_index == 4'd7 )}} & tlb_v0[ 7]) |
                         ({1{(s1_index == 4'd8 )}} & tlb_v0[ 8]) |
                         ({1{(s1_index == 4'd9 )}} & tlb_v0[ 9]) |
                         ({1{(s1_index == 4'd10)}} & tlb_v0[10]) |
                         ({1{(s1_index == 4'd11)}} & tlb_v0[11]) |
                         ({1{(s1_index == 4'd12)}} & tlb_v0[12]) |
                         ({1{(s1_index == 4'd13)}} & tlb_v0[13]) |
                         ({1{(s1_index == 4'd14)}} & tlb_v0[14]) |
                         ({1{(s1_index == 4'd15)}} & tlb_v0[15]);
    assign s1_v1_sel = ({1{(s1_index == 4'd0 )}} & tlb_v1[ 0]) |
                         ({1{(s1_index == 4'd1 )}} & tlb_v1[ 1]) |
                         ({1{(s1_index == 4'd2 )}} & tlb_v1[ 2]) |
                         ({1{(s1_index == 4'd3 )}} & tlb_v1[ 3]) |
                         ({1{(s1_index == 4'd4 )}} & tlb_v1[ 4]) |
                         ({1{(s1_index == 4'd5 )}} & tlb_v1[ 5]) |
                         ({1{(s1_index == 4'd6 )}} & tlb_v1[ 6]) |
                         ({1{(s1_index == 4'd7 )}} & tlb_v1[ 7]) |
                         ({1{(s1_index == 4'd8 )}} & tlb_v1[ 8]) |
                         ({1{(s1_index == 4'd9 )}} & tlb_v1[ 9]) |
                         ({1{(s1_index == 4'd10)}} & tlb_v1[10]) |
                         ({1{(s1_index == 4'd11)}} & tlb_v1[11]) |
                         ({1{(s1_index == 4'd12)}} & tlb_v1[12]) |
                         ({1{(s1_index == 4'd13)}} & tlb_v1[13]) |
                         ({1{(s1_index == 4'd14)}} & tlb_v1[14]) |
                         ({1{(s1_index == 4'd15)}} & tlb_v1[15]);
    // inst & data 选择的page size
    assign s0_ps  = s0_ps4MB_sel ? 6'h15 : 6'h0c;
    assign s1_ps  = s1_ps4MB_sel ? 6'h15 : 6'h0c;
    // PPN
    assign s0_ppn = s0_odd_page ? s0_ppn1_sel : s0_ppn0_sel;
    assign s1_ppn = s1_odd_page ? s1_ppn1_sel : s1_ppn0_sel;
    // PLV
    assign s0_plv = s0_odd_page ? s0_plv1_sel : s0_plv0_sel;
    assign s1_plv = s1_odd_page ? s1_plv1_sel : s1_plv0_sel;
    // MAT
    assign s0_mat = s0_odd_page ? s0_mat1_sel : s0_mat0_sel;
    assign s1_mat = s1_odd_page ? s1_mat1_sel : s1_mat0_sel;
    // D-dirty
    assign s0_d   = s0_odd_page ? s0_d1_sel   : s0_d0_sel;
    assign s1_d   = s1_odd_page ? s1_d1_sel   : s1_d0_sel;
    // V-valid
    assign s0_v   = s0_odd_page ? s0_v1_sel   : s0_v0_sel;
    assign s1_v   = s1_odd_page ? s1_v1_sel   : s1_v0_sel;
//----------------------------- query begin --------------------------

//----------------------------- write begin --------------------------
    integer reset_index;
    always @(posedge clk) begin
        if (!resetn) begin
            tlb_e     <= {TLBNUM{1'b0}};
            tlb_ps4MB <= {TLBNUM{1'b0}};
            for (reset_index = 0; reset_index < TLBNUM; reset_index = reset_index + 1) begin
                tlb_vppn[reset_index] <= 19'b0;
                tlb_asid[reset_index] <= 10'b0;
                tlb_g   [reset_index] <= 1'b0;
                tlb_ppn0[reset_index] <= 20'b0;
                tlb_plv0[reset_index] <= 2'b0;
                tlb_mat0[reset_index] <= 2'b0;
                tlb_d0  [reset_index] <= 1'b0;
                tlb_v0  [reset_index] <= 1'b0;
                tlb_ppn1[reset_index] <= 20'b0;
                tlb_plv1[reset_index] <= 2'b0;
                tlb_mat1[reset_index] <= 2'b0;
                tlb_d1  [reset_index] <= 1'b0;
                tlb_v1  [reset_index] <= 1'b0;
            end
        end
        else if (invtlb_valid) begin
            tlb_e <= tlb_e & ~invtlb_clear;
        end
        else if (we) begin
            tlb_e    [w_index] <= w_e;
            tlb_vppn [w_index] <= w_vppn;
            tlb_ps4MB[w_index] <= (w_ps == 6'h15);
            tlb_asid [w_index] <= w_asid;
            tlb_g    [w_index] <= w_g;
            tlb_ppn0 [w_index] <= w_ppn0;
            tlb_plv0 [w_index] <= w_plv0;
            tlb_mat0 [w_index] <= w_mat0;
            tlb_d0   [w_index] <= w_d0;
            tlb_v0   [w_index] <= w_v0;
            tlb_ppn1 [w_index] <= w_ppn1;
            tlb_plv1 [w_index] <= w_plv1;
            tlb_mat1 [w_index] <= w_mat1;
            tlb_d1   [w_index] <= w_d1;
            tlb_v1   [w_index] <= w_v1;
        end
    end
//----------------------------- write end --------------------------

//----------------------------- read begin --------------------------
    // read
    assign r_e    = tlb_e   [r_index];
    assign r_vppn = tlb_vppn[r_index];
    assign r_ps   = tlb_ps4MB[r_index] ? 6'h15 : 6'h0c;
    assign r_asid = tlb_asid[r_index];
    assign r_g    = tlb_g   [r_index];
    assign r_ppn0 = tlb_ppn0[r_index];
    assign r_plv0 = tlb_plv0[r_index];
    assign r_mat0 = tlb_mat0[r_index];
    assign r_d0   = tlb_d0  [r_index];
    assign r_v0   = tlb_v0  [r_index];
    assign r_ppn1 = tlb_ppn1[r_index];
    assign r_plv1 = tlb_plv1[r_index];
    assign r_mat1 = tlb_mat1[r_index];
    assign r_d1   = tlb_d1  [r_index];
    assign r_v1   = tlb_v1  [r_index];
//----------------------------- read end --------------------------

//----------------------------- INVTLB begin --------------------------
wire condition1_G0  [TLBNUM-1:0];
wire condition2_G1  [TLBNUM-1:0];
wire condition3_ASID[TLBNUM-1:0];// 对比s1_asid
wire condition4_VPPN[TLBNUM-1:0];// s1_vppn是否匹配VPPN和PS
integer invtlb_index;

genvar i;
generate
    for (i = 0; i < TLBNUM; i = i + 1) begin: gen_invtlb_condition // 循环块的名字
        assign condition1_G0[i]   = ~tlb_g[i];
        assign condition2_G1[i]   =  tlb_g[i];
        assign condition3_ASID[i] = (s1_asid == tlb_asid[i]);
        assign condition4_VPPN[i] = (s1_vppn[18:9] == tlb_vppn[i][18:9]) && (tlb_ps4MB[i] || (s1_vppn[8:0] == tlb_vppn[i][8:0]));
    end
endgenerate

always @(*) begin
    invtlb_clear = {TLBNUM{1'b0}};
    case (invtlb_op)
        5'h00: begin
            // op=0：清除所有页表项
            invtlb_clear = {TLBNUM{1'b1}};
        end
        5'h01: begin
            // op=1：清除所有页表项，效果与op=0相同
            invtlb_clear = {TLBNUM{1'b1}};
        end
        5'h02: begin
            // op=2：清除所有G=1的页表项
            for (invtlb_index = 0; invtlb_index < TLBNUM; invtlb_index = invtlb_index + 1)
                invtlb_clear[invtlb_index] = condition2_G1[invtlb_index];
        end
        5'h03: begin
            // op=3：清除所有G=0的页表项
            for (invtlb_index = 0; invtlb_index < TLBNUM; invtlb_index = invtlb_index + 1)
                invtlb_clear[invtlb_index] = condition1_G0[invtlb_index];
        end
        5'h04: begin
            // op=4：清除G=0且ASID匹配的页表项
            for (invtlb_index = 0; invtlb_index < TLBNUM; invtlb_index = invtlb_index + 1)
                invtlb_clear[invtlb_index] = condition1_G0[invtlb_index]
                                                   && condition3_ASID[invtlb_index];
        end
        5'h05: begin
            // op=5：清除G=0、ASID匹配且VPPN匹配的页表项
            for (invtlb_index = 0; invtlb_index < TLBNUM; invtlb_index = invtlb_index + 1)
                invtlb_clear[invtlb_index] = condition1_G0[invtlb_index]
                                                   && condition3_ASID[invtlb_index]
                                                   && condition4_VPPN[invtlb_index];
        end
        5'h06: begin
            // op=6：清除G=1或ASID匹配，并且VPPN匹配的页表项
            for (invtlb_index = 0; invtlb_index < TLBNUM; invtlb_index = invtlb_index + 1)
                invtlb_clear[invtlb_index] = (condition2_G1[invtlb_index] || condition3_ASID[invtlb_index])
                                                   && condition4_VPPN[invtlb_index];
        end
        default: begin
            // 其他操作码不清除任何页表项
            invtlb_clear = {TLBNUM{1'b0}};
        end
    endcase
end
//----------------------------- INVTLB end --------------------------

//----------------------------tlb_ex--------------
// wire       ex_tlb_reload0,//tlb重填例外_s0
// wire       ex_tlb_reload1,//tlb重填例外_s1
// wire       ex_tlb_ld_unvalid,//tlb中load页无效
// wire       ex_tlb_st_unvalid,//tlb中store页无效
// wire       ex_tlb_preif_unvalid,//tlb中取指页无效
// wire       ex_tlb_plv0,//tlb中页特权不合规_s0
// wire       ex_tlb_plv1,//tlb中页特权不合规_s1
// wire       ex_tlb_page_modify//tlb中页修改
assign ex_tlb_reload0       = ~s0_found & tlb_inst_req & ~dmw_found0;
assign ex_tlb_reload1       = ~s1_found & tlb_data_req & ~dmw_found1;
assign ex_tlb_ld_unvalid    = (s1_found & ~s1_v) & tlb_load_req;
assign ex_tlb_st_unvalid    = (s1_found & ~s1_v) & tlb_store_req;
assign ex_tlb_preif_unvalid = (s0_found & ~s0_v) & tlb_inst_req;
assign ex_tlb_plv0          = s0_found & s0_v &
                              (csr_CRMD_PLV > s0_plv) & tlb_inst_req;
assign ex_tlb_plv1          = s1_found & s1_v &
                              (csr_CRMD_PLV > s1_plv) & tlb_data_req;
assign ex_tlb_page_modify   = s1_found & s1_v &
                              (csr_CRMD_PLV <= s1_plv) &
                              ~s1_d & tlb_store_req;
//------------------------------------------------
endmodule
