`ifndef __CACHE_DEF_VH__
`define __CACHE_DEF_VH__

//----------------------------- config begin --------------------------
`define REPLACE_MODE  1'b0  //0:LRU; 1:pseudo-random

// 2-way set-assoc, 1024 sets, 16B line => 32KB per cache
// address: tag[31:14] | index[13:4] | offset[3:0]
`define GROUP_NUM      1024
`define INDEX_WIDTH    10
`define TAG_WIDTH      18
`define OFFSET_WIDTH   4
`define TAGV_WIDTH     21   // {2'b0, tag[17:0], V} fixed 21-bit BRAM
`define BANK_NUM       4
`define BANK_SIZE      32
`define LINE_SIZE      128

// main FSM
`define MAIN_IDLE      3'd0
`define MAIN_LOOKUP    3'd1
`define MAIN_MISS      3'd2
`define MAIN_REPLACE   3'd3
`define MAIN_REFILL    3'd4

// Write Buffer
`define WB_IDLE        1'b0
`define WB_WRITE       1'b1
//----------------------------- config end --------------------------
`endif
