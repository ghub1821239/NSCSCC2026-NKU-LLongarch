`ifndef __CACHE_DEF_VH__
`define __CACHE_DEF_VH__

//----------------------------- 参数定义开始 --------------------------
`define REPLACE_MODE  1'b0  //0：LRU，1：伪随机

//2路组相连，每路256组，每行16字节
`define GROUP_NUM      256
`define INDEX_WIDTH    8
`define TAG_WIDTH      20
`define OFFSET_WIDTH   4
`define TAGV_WIDTH     21   //高位为标签，低位为有效位
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