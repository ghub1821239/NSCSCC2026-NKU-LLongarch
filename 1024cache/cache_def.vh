`ifndef __CACHE_DEF_VH__
`define __CACHE_DEF_VH__

//----------------------------- 参数定义开始 --------------------------
`define REPLACE_MODE  1'b0  //0：LRU，1：伪随机

//2路组相连，每路1024组，每行16字节 → 每侧 32KB（16KB 为 512 组）
// 地址划分: tag[31:14] | index[13:4] | offset[3:0]
// 说明：优先扩容量优于同容量 4 路；4 路改动大且冲突 miss 收益通常小于容量翻倍
`define GROUP_NUM      1024
`define INDEX_WIDTH    10
`define TAG_WIDTH      18
`define OFFSET_WIDTH   4
`define TAGV_WIDTH     21   // {pad[2:0] 高位, tag[17:0], V} 固定 21bit BRAM
`define BANK_NUM       4
`define BANK_SIZE      32
`define LINE_SIZE      128

//主状态机
`define MAIN_IDLE      3'd0
`define MAIN_LOOKUP    3'd1
`define MAIN_MISS      3'd2
`define MAIN_REPLACE   3'd3
`define MAIN_REFILL    3'd4

//Write Buffer 使用两态结构
`define WB_IDLE        1'b0
`define WB_WRITE       1'b1
//----------------------------- 参数定义结束 --------------------------
`endif
