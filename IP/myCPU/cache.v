`timescale 1ns / 1ps
`include "cache_def.vh"
module cache #(
    parameter code2_0 = 3'b0
)
(
    input  wire  clk,
    input  wire  resetn,
    //                                                          来自(input)/去往（output)
    input  wire         valid,//表明请求有效                                       CPU
    input  wire         op, // op：0读，1写                                        CPU
    input  wire [7 :0]  index,// CPU 直接截取的12：4(肯定不涉及虚实映射)     CPU
    input  wire [19:0]  tag,  // CPU处理好的paddr    (虚实映射)              CPU
    input  wire [3 :0]  offset,// CPU 直接截取的3:0 (肯定不涉及虚实映射)     CPU
    input  wire [3 :0]  wstrb,//                                            CPU
    input  wire [31:0]  wdata,//                                            CPU
    input  wire         uncache_valid,
    input  wire         uncache_wr, // ld:0 st:1

    output wire         addr_ok,//接收到转接桥的 读/写 的 addrok 给CPU               CPU（O）                                   
    input  wire         rd_rdy,   // arready                                      总线
    output wire [31:0]  rd_addr, // CPU给的paddr VA 他拼接一下             总线（O）

    output wire         data_ok,//总线返回的                                       CPU（O）
    output wire [31:0]  rdata,// 总线读出来的数据                           CPU（O）
    output wire         rd_req,// CPU 的读请求                                     总线（O）
    output wire [2 :0]  rd_type, // 和总线的size直接接                      总线：rsize 010   arlen 8'd3 （O）  
    output wire [7 :0]  ar_len,    
    input  wire         ret_valid,// 总线返回的数是有效的                           总线：rvalid
    input  wire         ret_last, // 总线返回结束了                                 总线: last
    input  wire [31:0]  ret_data,// 总线给的读数据 rdata                    总线


    output wire         wr_req,//CPU发起的                                        总线（O）
    output wire [2 :0]  wr_type,//                                        总线（O）
    output wire [31:0]  wr_addr,//                                        总线（O）
    output wire [3 :0]  wr_wstrb,//                                       总线（O）
    output wire [127:0] wr_data,//                                        总线（O）
    output wire [7 :0]  aw_len,
    input  wire         wr_rdy,//                                                  总线

    // cacop
    input  wire [ 4:0]  cache_code,
    input  wire         cacop_valid,
    output wire         cacop_done
);

//----------------------------- 寄存器定义开始 --------------------------
// 主状态机和 Write Buffer 状态机
// 存储主状态 & 写状态
reg [2:0] main_state;
reg wb_state;

// 最近最少使用
reg  LRU  [`GROUP_NUM-1:0];
// 伪随机替换
// reg [22:0] LFSR;

// 脏位表
reg                    dirty_way0 [`GROUP_NUM-1:0];
reg                    dirty_way1 [`GROUP_NUM-1:0];
// 把当前 LOOKUP 的这个index的脏位锁存，用于在 MISS 的时候判断写回
reg                    dirty_way0_r;
reg                    dirty_way1_r;

//Request Buffer：锁存当前进入LOOKUP的请求
reg                    req_valid_r;
reg                    req_op_r;
reg [`INDEX_WIDTH-1:0]  req_index_r;
reg [`TAG_WIDTH-1:0]    req_tag_r;
reg [`OFFSET_WIDTH-1:0] req_offset_r;
reg [3:0]              req_wstrb_r; // 发起请求时刻先缓存下来 方便之后命中给wb_wstrb_r
reg [31:0]             req_wdata_r; // 原始写data
reg                    uncache_valid_r;
reg                    uncache_wr_r;
reg                    cacop_this_cache_r;
reg [4:0]              cache_code_r;

//Miss Buffer：锁存当前缺失事务的上下文
reg                    miss_op_r;
reg [`INDEX_WIDTH-1:0] miss_index_r;
reg [`TAG_WIDTH-1:0]   miss_tag_r;
reg [`OFFSET_WIDTH-1:0]miss_offset_r;
reg [3:0]              miss_wstrb_r;
reg [31:0]             miss_wdata_r;
// 根据 LRU & 随机替换算法 找到的replace的way
reg                    replace_way_r;
reg [`TAG_WIDTH-1:0]   replace_tag_r;
reg                    replace_valid_r;
reg                    replace_dirty_r;
reg[127:0]             replace_line_r;

//Write Buffer：命中写先暂存，再单独写 Data Bank
reg                    wb_valid_r;
reg                    wb_way_r;
reg [`INDEX_WIDTH-1:0] wb_index_r;
reg [1:0]              wb_bank_r;
reg [3:0]              wb_wstrb_r; // wdata 以及被
reg [31:0]             wb_wdata_r;

// 【受限于比赛的AXI RAM 我们妥协的采用了一次32位返回的打拍】
// cnt就是打拍，buf是存放这cache line数据的寄存器
reg [1:0]              refill_cnt_r;
//存储的是直接从data_ram/inst_ram中拿回来的cache line
reg [127:0]            refill_buf_r;
reg                    rd_req_sent_r;
reg                    wr_req_sent_r;

integer i;
//----------------------------- 寄存器定义结束 --------------------------

//----------------------------- 线网定义开始 --------------------------
wire [`TAG_WIDTH-1:0]  way0_tag;
wire [`TAG_WIDTH-1:0]  way1_tag;
wire                   way0_v;
wire                   way1_v;
wire                   way0_d;
wire                   way1_d;
// way0/1所选择的word 以及我们选择的word
wire [31:0]           way0_word;
wire [31:0]           way1_word;
wire                  way0_hit;
wire                  way1_hit;
wire                  cache_hit;
wire                  hit_way;
wire [31:0]           hit_word;
// st通过掩码来写入（st_h,st_b)
wire [31:0]           merged_hit_word;

//refill_buf_r是缓存器，因此必然比ret_data慢一个周期，这个wire就相当于可以瞬时变化，在ret_data
//返回的瞬时这个cache line中的值就会变成新的
wire [127:0]          refill_line_next;
// 【inst_data/ld要拿】 || 【st要改的那一个word】
wire [31:0]           refill_word;
// 这个针对的是st_h.w.b 这种要新写入的值
wire [31:0]           refill_merged_word;


// 有无效路 replace去选择替换的位置
// 需要替换那一路对应的旧数据
wire                  has_invalid_way;
wire                  invalid_way;
wire                  policy_way;
wire                  replace_way;
wire [`TAG_WIDTH-1:0]  replace_tag;
wire                  replace_valid;
wire                  replace_dirty;
wire                  replace_need_writeback;
wire [127:0]          replace_line;

// 经过st写数据的判定之后，要往cache中写回的line
wire [127:0]          refill_final_line;
wire [31:0]           refill_final_word;
wire [31:0]           refill_final_bank0;
wire [31:0]           refill_final_bank1;
wire [31:0]           refill_final_bank2;
wire [31:0]           refill_final_bank3;

wire                  can_accept_req;
wire                  lookup_begin;
wire                  lookup_read_hit;
wire                  lookup_write_hit;
wire                  lookup_miss;
// refill再从I/D RAM拿回cache line之后要进入写cache阶段
wire                  refill_write;
wire                  wb_write;

// TagV RAM 端口
// 写TAGV
wire [0:0]             tagv_way0_wea;
wire [0:0]             tagv_way1_wea;
wire                   tagv_way0_code2;
wire                   tagv_way1_code2;
wire [`INDEX_WIDTH-1:0] tagv_way0_addr;
wire [`INDEX_WIDTH-1:0] tagv_way1_addr;
wire [`TAGV_WIDTH-1:0]  tagv_way0_dina;
wire [`TAGV_WIDTH-1:0]  tagv_way1_dina;
wire [`TAGV_WIDTH-1:0]  tagv_way0_r;
wire [`TAGV_WIDTH-1:0]  tagv_way1_r;

// Data Bank RAM 端口
wire [3:0]             data_way0_bank0_wea;
wire [3:0]             data_way0_bank1_wea;
wire [3:0]             data_way0_bank2_wea;
wire [3:0]             data_way0_bank3_wea;
wire [3:0]             data_way1_bank0_wea;
wire [3:0]             data_way1_bank1_wea;
wire [3:0]             data_way1_bank2_wea;
wire [3:0]             data_way1_bank3_wea;

wire [`INDEX_WIDTH-1:0] data_way0_bank0_addr;
wire [`INDEX_WIDTH-1:0] data_way0_bank1_addr;
wire [`INDEX_WIDTH-1:0] data_way0_bank2_addr;
wire [`INDEX_WIDTH-1:0] data_way0_bank3_addr;
wire [`INDEX_WIDTH-1:0] data_way1_bank0_addr;
wire [`INDEX_WIDTH-1:0] data_way1_bank1_addr;
wire [`INDEX_WIDTH-1:0] data_way1_bank2_addr;
wire [`INDEX_WIDTH-1:0] data_way1_bank3_addr;

wire [`BANK_SIZE-1:0]  data_way0_bank0_dina;
wire [`BANK_SIZE-1:0]  data_way0_bank1_dina;
wire [`BANK_SIZE-1:0]  data_way0_bank2_dina;
wire [`BANK_SIZE-1:0]  data_way0_bank3_dina;
wire [`BANK_SIZE-1:0]  data_way1_bank0_dina;
wire [`BANK_SIZE-1:0]  data_way1_bank1_dina;
wire [`BANK_SIZE-1:0]  data_way1_bank2_dina;
wire [`BANK_SIZE-1:0]  data_way1_bank3_dina;

wire [`BANK_SIZE-1:0]  data_way0_bank0_r;
wire [`BANK_SIZE-1:0]  data_way0_bank1_r;
wire [`BANK_SIZE-1:0]  data_way0_bank2_r;
wire [`BANK_SIZE-1:0]  data_way0_bank3_r;
wire [`BANK_SIZE-1:0]  data_way1_bank0_r;
wire [`BANK_SIZE-1:0]  data_way1_bank1_r;
wire [`BANK_SIZE-1:0]  data_way1_bank2_r;
wire [`BANK_SIZE-1:0]  data_way1_bank3_r;
//----------------------------- 线网定义结束 --------------------------

//----------------------------- CACOP begin  --------------------------
wire   cacop_this_cache;
assign cacop_this_cache = cacop_valid && (cache_code[2:0] == code2_0);
// code == 3'b0
wire VA_0;
wire code0;
wire code1;
wire code2;

assign VA_0 = req_offset_r[0];
assign code0 = (cacop_this_cache_r && cache_code_r[4:3] == 2'b00);
assign code1 = (cacop_this_cache_r && cache_code_r[4:3] == 2'b01);
assign code2 = (cacop_this_cache_r && cache_code_r[4:3] == 2'b10);

assign cacop_done = ((main_state == `MAIN_REFILL) && (code0 || code1)) ||
                    ((main_state == `MAIN_LOOKUP) && code2 && !cache_hit) ||
                    ((wb_state   == `WB_WRITE)    && code2);
//----------------------------- CACOP end  --------------------------

//----------------------------- TAGV RAM 访问逻辑 begin --------------------------
assign tagv_way0_wea       = (refill_write && !replace_way_r);
assign tagv_way0_code2     = (wb_write && code2 && !wb_way_r);
assign tagv_way1_wea       = (refill_write &&  replace_way_r);
assign tagv_way1_code2     = (wb_write && code2 &&  wb_way_r);
// 如果是写 就等到写的时候再去触发 
// 如果是读 那就直接在传入的瞬间从TAGV的两路先把数据读出来，之后再选
// 如果是CACOP 这里其实也是index的addr
assign tagv_way0_addr = tagv_way0_code2 ? wb_index_r : tagv_way0_wea ? miss_index_r : index;
assign tagv_way1_addr = tagv_way1_code2 ? wb_index_r : tagv_way1_wea ? miss_index_r : index;
// 写数据
assign tagv_way0_dina = (tagv_way0_wea & code0) ? {21'b0} :
                        (tagv_way0_wea & code1) ? {replace_tag_r,1'b0} :
                        (tagv_way0_code2&code2) ? {20'b0,1'b0} :
                        {miss_tag_r, 1'b1};
assign tagv_way1_dina = (tagv_way1_wea & code0) ? {21'b0} :
                        (tagv_way1_wea & code1) ? {replace_tag_r,1'b0} :
                        (tagv_way1_code2&code2) ? {20'b0,1'b0} :
                        {miss_tag_r, 1'b1};
// TagV RAM：每路一张 256x21 表，位[20:1]为标签，位[0]为有效位
tagv_ram tagv_way0 (
    .clka  (clk),
    .wea   (tagv_way0_wea | tagv_way0_code2),
    .addra (tagv_way0_addr),
    .dina  (tagv_way0_dina),
    .douta (tagv_way0_r)
);

tagv_ram tagv_way1 (
    .clka  (clk),
    .wea   (tagv_way1_wea | tagv_way1_code2),
    .addra (tagv_way1_addr),
    .dina  (tagv_way1_dina),
    .douta (tagv_way1_r)
);
//----------------------------- TAGV RAM 访问逻辑 end --------------------------

//----------------------------- DATA BANK RAM 访问逻辑 begin --------------------------
// 每一个bank的写/读使能 
// wb_write：write buffer

//(refill_write && !replace_way_r):从 inst/data RAM 读回替换
//(wb_write && !wb_way_r && (wb_bank_r == 2'b00) cache 命中下的st
assign data_way0_bank0_wea = (refill_write && !cacop_this_cache_r && !replace_way_r) ? 4'b1111 :
                             (wb_write && !wb_way_r && (wb_bank_r == 2'b00) && !cacop_this_cache_r) ? wb_wstrb_r : 4'b0000;
assign data_way0_bank1_wea = (refill_write && !cacop_this_cache_r && !replace_way_r) ? 4'b1111 :
                             (wb_write && !wb_way_r && (wb_bank_r == 2'b01) && !cacop_this_cache_r) ? wb_wstrb_r : 4'b0000;
assign data_way0_bank2_wea = (refill_write && !cacop_this_cache_r && !replace_way_r) ? 4'b1111 :
                             (wb_write && !wb_way_r && (wb_bank_r == 2'b10) && !cacop_this_cache_r) ? wb_wstrb_r : 4'b0000;
assign data_way0_bank3_wea = (refill_write && !cacop_this_cache_r && !replace_way_r) ? 4'b1111 :
                             (wb_write && !wb_way_r && (wb_bank_r == 2'b11) && !cacop_this_cache_r) ? wb_wstrb_r : 4'b0000;
assign data_way1_bank0_wea = (refill_write && !cacop_this_cache_r &&  replace_way_r) ? 4'b1111 :
                             (wb_write &&  wb_way_r && (wb_bank_r == 2'b00) && !cacop_this_cache_r) ? wb_wstrb_r : 4'b0000;
assign data_way1_bank1_wea = (refill_write && !cacop_this_cache_r &&  replace_way_r) ? 4'b1111 :
                             (wb_write &&  wb_way_r && (wb_bank_r == 2'b01) && !cacop_this_cache_r) ? wb_wstrb_r : 4'b0000;
assign data_way1_bank2_wea = (refill_write && !cacop_this_cache_r &&  replace_way_r) ? 4'b1111 :
                             (wb_write &&  wb_way_r && (wb_bank_r == 2'b10) && !cacop_this_cache_r) ? wb_wstrb_r : 4'b0000;
assign data_way1_bank3_wea = (refill_write && !cacop_this_cache_r &&  replace_way_r) ? 4'b1111 :
                             (wb_write &&  wb_way_r && (wb_bank_r == 2'b11) && !cacop_this_cache_r) ? wb_wstrb_r : 4'b0000;

assign data_way0_bank0_addr = (|data_way0_bank0_wea) ? ((refill_write && !replace_way_r) ? miss_index_r : wb_index_r) : index;
assign data_way0_bank1_addr = (|data_way0_bank1_wea) ? ((refill_write && !replace_way_r) ? miss_index_r : wb_index_r) : index;
assign data_way0_bank2_addr = (|data_way0_bank2_wea) ? ((refill_write && !replace_way_r) ? miss_index_r : wb_index_r) : index;
assign data_way0_bank3_addr = (|data_way0_bank3_wea) ? ((refill_write && !replace_way_r) ? miss_index_r : wb_index_r) : index;
assign data_way1_bank0_addr = (|data_way1_bank0_wea) ? ((refill_write &&  replace_way_r) ? miss_index_r : wb_index_r) : index;
assign data_way1_bank1_addr = (|data_way1_bank1_wea) ? ((refill_write &&  replace_way_r) ? miss_index_r : wb_index_r) : index;
assign data_way1_bank2_addr = (|data_way1_bank2_wea) ? ((refill_write &&  replace_way_r) ? miss_index_r : wb_index_r) : index;
assign data_way1_bank3_addr = (|data_way1_bank3_wea) ? ((refill_write &&  replace_way_r) ? miss_index_r : wb_index_r) : index;

assign data_way0_bank0_dina = (refill_write && !replace_way_r) ? refill_final_bank0 : wb_wdata_r;
assign data_way0_bank1_dina = (refill_write && !replace_way_r) ? refill_final_bank1 : wb_wdata_r;
assign data_way0_bank2_dina = (refill_write && !replace_way_r) ? refill_final_bank2 : wb_wdata_r;
assign data_way0_bank3_dina = (refill_write && !replace_way_r) ? refill_final_bank3 : wb_wdata_r;
assign data_way1_bank0_dina = (refill_write &&  replace_way_r) ? refill_final_bank0 : wb_wdata_r;
assign data_way1_bank1_dina = (refill_write &&  replace_way_r) ? refill_final_bank1 : wb_wdata_r;
assign data_way1_bank2_dina = (refill_write &&  replace_way_r) ? refill_final_bank2 : wb_wdata_r;
assign data_way1_bank3_dina = (refill_write &&  replace_way_r) ? refill_final_bank3 : wb_wdata_r;

// 数据按每路 4 个 Data Bank 组织
data_bank_ram data_way0_bank0 (
    .clka  (clk),
    .wea   (data_way0_bank0_wea),
    .addra (data_way0_bank0_addr),
    .dina  (data_way0_bank0_dina),
    .douta (data_way0_bank0_r)
);

data_bank_ram data_way0_bank1 (
    .clka  (clk),
    .wea   (data_way0_bank1_wea),
    .addra (data_way0_bank1_addr),
    .dina  (data_way0_bank1_dina),
    .douta (data_way0_bank1_r)
);

data_bank_ram data_way0_bank2 (
    .clka  (clk),
    .wea   (data_way0_bank2_wea),
    .addra (data_way0_bank2_addr),
    .dina  (data_way0_bank2_dina),
    .douta (data_way0_bank2_r)
);

data_bank_ram data_way0_bank3 (
    .clka  (clk),
    .wea   (data_way0_bank3_wea),
    .addra (data_way0_bank3_addr),
    .dina  (data_way0_bank3_dina),
    .douta (data_way0_bank3_r)
);

data_bank_ram data_way1_bank0 (
    .clka  (clk),
    .wea   (data_way1_bank0_wea),
    .addra (data_way1_bank0_addr),
    .dina  (data_way1_bank0_dina),
    .douta (data_way1_bank0_r)
);

data_bank_ram data_way1_bank1 (
    .clka  (clk),
    .wea   (data_way1_bank1_wea),
    .addra (data_way1_bank1_addr),
    .dina  (data_way1_bank1_dina),
    .douta (data_way1_bank1_r)
);

data_bank_ram data_way1_bank2 (
    .clka  (clk),
    .wea   (data_way1_bank2_wea),
    .addra (data_way1_bank2_addr),
    .dina  (data_way1_bank2_dina),
    .douta (data_way1_bank2_r)
);

data_bank_ram data_way1_bank3 (
    .clka  (clk),
    .wea   (data_way1_bank3_wea),
    .addra (data_way1_bank3_addr),
    .dina  (data_way1_bank3_dina),
    .douta (data_way1_bank3_r)
);
//----------------------------- DATA BANK RAM 访问逻辑 begin --------------------------

//----------------------------- LOOKUP/REPLACE/REFILL 组合逻辑开始 --------------------------
assign way0_tag = tagv_way0_r[20:1];
assign way1_tag = tagv_way1_r[20:1];
assign way0_v   = tagv_way0_r[0];
assign way1_v   = tagv_way1_r[0];
assign way0_d   = dirty_way0_r;
assign way1_d   = dirty_way1_r;

assign way0_word = (req_offset_r[3:2] == 2'b00) ? data_way0_bank0_r :
                   (req_offset_r[3:2] == 2'b01) ? data_way0_bank1_r :
                   (req_offset_r[3:2] == 2'b10) ? data_way0_bank2_r :
                                                   data_way0_bank3_r;
assign way1_word = (req_offset_r[3:2] == 2'b00) ? data_way1_bank0_r :
                   (req_offset_r[3:2] == 2'b01) ? data_way1_bank1_r :
                   (req_offset_r[3:2] == 2'b10) ? data_way1_bank2_r :
                                                   data_way1_bank3_r;

assign way0_hit  = req_valid_r && way0_v && (way0_tag == req_tag_r);
assign way1_hit  = req_valid_r && way1_v && (way1_tag == req_tag_r);
assign cache_hit = way0_hit || way1_hit;
assign hit_way   = way1_hit;

assign hit_word        = hit_way ? way1_word : way0_word;
assign merged_hit_word = (hit_word    & ~{{8{req_wstrb_r[3]}}, {8{req_wstrb_r[2]}}, {8{req_wstrb_r[1]}}, {8{req_wstrb_r[0]}}})
                       | (req_wdata_r &  {{8{req_wstrb_r[3]}}, {8{req_wstrb_r[2]}}, {8{req_wstrb_r[1]}}, {8{req_wstrb_r[0]}}});

//MISS 时优先填无效路，否则再按替换策略选择被替换路
assign has_invalid_way       = !way0_v || !way1_v;
assign invalid_way           = !way0_v ? 1'b0 : 1'b1;
//assign policy_way            = (`REPLACE_MODE == 1'b0) ? LRU[req_index_r] : LFSR[0];
assign policy_way            = LRU[req_index_r];
assign replace_way           = code0 | code1 ? VA_0 : has_invalid_way ? invalid_way : policy_way;
assign replace_tag           = replace_way ? way1_tag : way0_tag;
assign replace_valid         = replace_way ? way1_v   : way0_v;
assign replace_dirty         = replace_way ? way1_d   : way0_d;
assign replace_need_writeback = replace_valid && replace_dirty;

assign replace_line = replace_way_r ? {data_way1_bank3_r, data_way1_bank2_r, data_way1_bank1_r, data_way1_bank0_r}
                                : {data_way0_bank3_r, data_way0_bank2_r, data_way0_bank1_r, data_way0_bank0_r};

// 写缺失时，回填完成后还要对目标字再合并一次
// ret_last 当拍返回的最后一个数据拍也必须并入最终缓存行
assign refill_line_next = ret_valid ? {(refill_cnt_r == 2'b11) ? ret_data : refill_buf_r[127:96],
                                       (refill_cnt_r == 2'b10) ? ret_data : refill_buf_r[95:64],
                                       (refill_cnt_r == 2'b01) ? ret_data : refill_buf_r[63:32],
                                       (refill_cnt_r == 2'b00) ? ret_data : refill_buf_r[31:0]}
                                    : refill_buf_r;
assign refill_word      = (miss_offset_r[3:2] == 2'b00) ? refill_line_next[31:0]   :
                          (miss_offset_r[3:2] == 2'b01) ? refill_line_next[63:32]  :
                          (miss_offset_r[3:2] == 2'b10) ? refill_line_next[95:64]  :
                                                          refill_line_next[127:96];
assign refill_merged_word = (refill_word  & ~{{8{miss_wstrb_r[3]}}, {8{miss_wstrb_r[2]}}, {8{miss_wstrb_r[1]}}, {8{miss_wstrb_r[0]}}})
                          | (miss_wdata_r &  {{8{miss_wstrb_r[3]}}, {8{miss_wstrb_r[2]}}, {8{miss_wstrb_r[1]}}, {8{miss_wstrb_r[0]}}});

assign refill_final_line  = miss_op_r ? {(miss_offset_r[3:2] == 2'b11) ? refill_merged_word : refill_line_next[127:96],
                                     (miss_offset_r[3:2] == 2'b10) ? refill_merged_word : refill_line_next[95:64],
                                     (miss_offset_r[3:2] == 2'b01) ? refill_merged_word : refill_line_next[63:32],
                                     (miss_offset_r[3:2] == 2'b00) ? refill_merged_word : refill_line_next[31:0]}
                                  : refill_line_next;
assign refill_final_word  = miss_op_r ? refill_merged_word : refill_word;
assign refill_final_bank0 = refill_final_line[31:0];
assign refill_final_bank1 = refill_final_line[63:32];
assign refill_final_bank2 = refill_final_line[95:64];
assign refill_final_bank3 = refill_final_line[127:96];

//只有主状态机空闲、Write Buffer 也空闲时，才接收新的缓存请求。
//assign can_accept_req   = (main_state == `MAIN_IDLE) && (wb_state == `WB_IDLE) && !wb_valid_r;
// cacop_this_cache也应该进入
assign lookup_begin     = (valid | cacop_this_cache) && can_accept_req;
// 如果是读的Hit强制uncache miss
assign lookup_read_hit  = cache_hit && !req_op_r && ~(uncache_valid_r && ~uncache_wr_r) && ~code0 && ~code1;
// 同样写也是
assign lookup_write_hit = cache_hit &&  req_op_r && ~(uncache_valid_r && uncache_wr_r) && ~cacop_this_cache_r;
// 强制miss
assign lookup_miss      = !cache_hit | uncache_valid_r | code0 | code1;
// refill_write：处于refill状态，要把cache line重填回cache
assign refill_write     = (main_state == `MAIN_REFILL) && ((ret_valid && ret_last && ~uncache_valid_r) || code0 || code1);
assign wb_write         = (wb_state == `WB_WRITE);

wire is_icache = (code2_0 == 3'b000);
wire lookup_read_pipe = is_icache &&
                        (main_state == `MAIN_LOOKUP) &&
                        lookup_read_hit &&
                        !cacop_this_cache_r;

assign can_accept_req =
    ((main_state == `MAIN_IDLE) && (wb_state == `WB_IDLE) && !wb_valid_r) ||
    (lookup_read_pipe && (wb_state == `WB_IDLE) && !wb_valid_r);

assign addr_ok = can_accept_req;

//----------------------------- LOOKUP/REPLACE/REFILL 组合逻辑结束 --------------------------

always @(posedge clk or negedge resetn) begin
    if (!resetn) begin
        main_state           <= `MAIN_IDLE;
        wb_state             <= `WB_IDLE;
        req_valid_r          <= 1'b0;
        req_op_r             <= 1'b0;
        req_index_r          <= {`INDEX_WIDTH{1'b0}};
        req_tag_r            <= {`TAG_WIDTH{1'b0}};
        req_offset_r         <= {`OFFSET_WIDTH{1'b0}};
        req_wstrb_r          <= 4'b0;
        req_wdata_r          <= 32'b0;
        miss_op_r            <= 1'b0;
        miss_index_r         <= {`INDEX_WIDTH{1'b0}};
        miss_tag_r           <= {`TAG_WIDTH{1'b0}};
        miss_offset_r        <= {`OFFSET_WIDTH{1'b0}};
        miss_wstrb_r         <= 4'b0;
        miss_wdata_r         <= 32'b0;
        replace_way_r        <= 1'b0;
        replace_tag_r   <= {`TAG_WIDTH{1'b0}};
        replace_valid_r <= 1'b0;
        replace_dirty_r <= 1'b0;
        replace_line_r  <= 128'b0;
        refill_cnt_r         <= 2'b0;
        refill_buf_r         <= {`LINE_SIZE{1'b0}};
        rd_req_sent_r        <= 1'b0;
        wr_req_sent_r        <= 1'b0;
        wb_valid_r           <= 1'b0;
        wb_way_r             <= 1'b0;
        wb_index_r           <= {`INDEX_WIDTH{1'b0}};
        wb_bank_r            <= 2'b0;
        wb_wstrb_r           <= 4'b0;
        wb_wdata_r           <= 32'b0;
        dirty_way0_r         <= 1'b0;
        dirty_way1_r         <= 1'b0;
        //LFSR                 <= 23'h1;
        uncache_valid_r      <= 1'b0;
        uncache_wr_r         <= 1'b0;
        cacop_this_cache_r   <= 1'b0;
        cache_code_r         <= 5'b0;

        // 这里只清元数据，不整片清零 Data RAM，避免破坏 BRAM 推断风格。
        for (i = 0; i < `GROUP_NUM; i = i + 1) begin
            dirty_way0[i] <= 1'b0;
            dirty_way1[i] <= 1'b0;
            LRU[i]        <= 1'b0;
        end
    end
    else begin
        // 伪随机替换
        // 伪随机使用位数查询手册可以查询低位是哪些异或
        //LFSR <= {LFSR[21:0], LFSR[22] ^ LFSR[17]};

        case (main_state)
            `MAIN_IDLE: begin
                if (lookup_begin) begin
                    // 第一拍：锁存请求，并向两路 TagV/Data Bank 发读地址
                    req_valid_r  <= 1'b1;
                    req_op_r     <= cacop_this_cache ? 1'b0: op;// 因为命中cache需要V置为0,所以其实相当于ld但是要写
                    req_index_r  <= index;
                    req_tag_r    <= tag;
                    req_offset_r <= offset;
                    req_wstrb_r  <= wstrb;
                    req_wdata_r  <= wdata;
                    uncache_valid_r <= uncache_valid & ~cacop_this_cache;// 必须在非cacop指令的时候才能uncache
                    uncache_wr_r <= uncache_wr;
                    cacop_this_cache_r <= cacop_this_cache;
                    cache_code_r  <= cache_code;


                    dirty_way0_r <= dirty_way0[index];
                    dirty_way1_r <= dirty_way1[index];
                    main_state   <= `MAIN_LOOKUP;
                end
                else begin
                    req_valid_r      <= 1'b0;
                end
            end

            `MAIN_LOOKUP: begin
                if (lookup_read_hit) begin
                    LRU[req_index_r] <= ~hit_way;
                    req_valid_r      <= 1'b0;
                    
                    if (is_icache && valid && addr_ok) begin
                        req_valid_r       <= 1'b1;
                        req_op_r          <= op;
                        req_index_r       <= index;
                        req_tag_r         <= tag;
                        req_offset_r      <= offset;
                        req_wstrb_r       <= wstrb;
                        req_wdata_r       <= wdata;
                        uncache_valid_r   <= uncache_valid;
                        uncache_wr_r      <= uncache_wr;
                        dirty_way0_r      <= dirty_way0[index];
                        dirty_way1_r      <= dirty_way1[index];
                        main_state        <= `MAIN_LOOKUP;
                    end else begin
                        req_valid_r <= 1'b0;
                        main_state  <= `MAIN_IDLE;
                    end

                    if (code2 &&
                        (code2_0 != 3'b000) &&
                        (hit_way ? way1_d : way0_d)) begin

                        // D-cache code2 脏命中：锁存命中行，先写回
                        miss_index_r         <= req_index_r;

                        replace_way_r        <= hit_way;
                        replace_tag_r        <= hit_way ? way1_tag : way0_tag;
                        replace_valid_r      <= 1'b1;
                        replace_dirty_r      <= 1'b1;
                        replace_line_r       <= hit_way ? {data_way1_bank3_r, data_way1_bank2_r,
                                                               data_way1_bank1_r, data_way1_bank0_r} : 
                                                               {data_way0_bank3_r, data_way0_bank2_r,
                                                                data_way0_bank1_r, data_way0_bank0_r};

                        wr_req_sent_r        <= 1'b0;
                        main_state           <= `MAIN_REPLACE;
                    end
                    else begin
                        if (code2) begin
                            // I-cache命中，或者D-cache干净命中，直接清V
                            wb_valid_r <= 1'b1;
                            wb_way_r   <= hit_way;
                            wb_index_r <= req_index_r;
                        end

                        main_state <= `MAIN_IDLE;
                    end
                end
                else if (lookup_write_hit) begin
                    // 写命中：主状态机只负责确认命中
                    // 真正写 Data Bank 的动作交给 Write Buffer 状态机
                    wb_valid_r <= 1'b1;
                    wb_way_r   <= hit_way;
                    wb_index_r <= req_index_r;
                    wb_bank_r  <= req_offset_r[3:2];
                    wb_wstrb_r <= req_wstrb_r;
                    // LOOKUP 拍已经读出命中字，这里保存合并后的新字
                    wb_wdata_r <= merged_hit_word;

                    // 命中一路后，把另一路标成"更旧"
                    LRU[req_index_r] <= ~hit_way;
                    req_valid_r      <= 1'b0;
                    main_state       <= `MAIN_IDLE;
                end
                else if (lookup_miss) begin
                    if(code2)begin
                        req_valid_r          <= 1'b0;
                        rd_req_sent_r        <= 1'b0;
                        wr_req_sent_r        <= 1'b0;
                        main_state           <= `MAIN_IDLE;
                        cacop_this_cache_r   <= 1'b0;
                    end
                    else begin
                    // LOOKUP 缺失：把当前缺失事务搬进 Miss Buffer
                        miss_op_r            <= req_op_r;
                        miss_index_r         <= req_index_r;
                        miss_tag_r           <= req_tag_r;
                        miss_offset_r        <= req_offset_r;
                        miss_wstrb_r         <= req_wstrb_r;
                        miss_wdata_r         <= req_wdata_r;
                        replace_way_r   <= replace_way;
                        replace_tag_r   <= replace_tag;
                        replace_valid_r <= replace_valid;
                        replace_dirty_r <= replace_dirty;
                        replace_line_r <= replace_way ? {data_way1_bank3_r, data_way1_bank2_r,
                                                         data_way1_bank1_r, data_way1_bank0_r} : 
                                                         {data_way0_bank3_r, data_way0_bank2_r,
                                                          data_way0_bank1_r, data_way0_bank0_r};
                        req_valid_r          <= 1'b0;
                        rd_req_sent_r        <= 1'b0;
                        wr_req_sent_r        <= 1'b0;
                        main_state           <= `MAIN_MISS;
                    end
                end
                else begin
                    // 保护分支
                    req_valid_r      <= 1'b0;
                    main_state       <= `MAIN_IDLE;
                end
            end

            `MAIN_MISS: begin
                // MISS：先决定被替换路是否需要写回
                if(code0)begin
                    refill_cnt_r   <= 2'b0;
                    refill_buf_r   <= {`LINE_SIZE{1'b0}};
                    main_state     <= `MAIN_REFILL;
                end
                else if (code1)begin
                    // 只有有效&脏位需要replace写回到ram
                    if(replace_valid_r & replace_dirty_r)begin
                        refill_cnt_r   <= 2'b0;
                        refill_buf_r   <= {`LINE_SIZE{1'b0}};
                        main_state     <= `MAIN_REPLACE;
                    end
                    else begin
                        main_state     <= `MAIN_REFILL;
                    end
                end
                else if (uncache_valid_r && ~uncache_wr_r)begin
                    refill_cnt_r   <= 2'b0;
                    refill_buf_r   <= {`LINE_SIZE{1'b0}};
                    rd_req_sent_r  <= 1'b0;
                    main_state     <= `MAIN_REFILL;
                end
                else if(uncache_valid_r && uncache_wr_r)begin
                    refill_cnt_r   <= 2'b0;
                    refill_buf_r   <= {`LINE_SIZE{1'b0}};
                    rd_req_sent_r  <= 1'b0;
                    main_state     <= `MAIN_REPLACE;
                end
                else if (!replace_valid_r) begin
                    // 被替换路无效，说明该路是空槽，可直接回填
                    refill_cnt_r  <= 2'b0;
                    refill_buf_r  <= {`LINE_SIZE{1'b0}};
                    rd_req_sent_r        <= 1'b0;
                    main_state    <= `MAIN_REFILL;
                end
                else if (!replace_dirty_r) begin
                    // 被替换路有效但不脏，不需要 REPLACE，直接进入 REFILL
                    refill_cnt_r  <= 2'b0;
                    refill_buf_r  <= {`LINE_SIZE{1'b0}};
                    rd_req_sent_r        <= 1'b0;
                    main_state    <= `MAIN_REFILL;
                end
                else begin
                    // 被替换路有效且为脏块，必须先整体写回
                    wr_req_sent_r        <= 1'b0;
                    main_state    <= `MAIN_REPLACE;
                end
            end

            `MAIN_REPLACE: begin
                // REPLACE：等待总线接受写回请求
                if (code1)begin
                    if(code2_0 != 3'b0)begin
                        if(!wr_req_sent_r && wr_rdy)begin
                            wr_req_sent_r <= 1'b1;
                            refill_cnt_r  <= 2'b0;
                            refill_buf_r  <= {`LINE_SIZE{1'b0}};
                            rd_req_sent_r <= 1'b0;
                            main_state    <= `MAIN_REFILL;
                        end
                    end
                    else begin
                        main_state    <= `MAIN_REFILL;
                    end
                end
                else if (code2) begin
                    if (!wr_req_sent_r && wr_rdy) begin
                        // 脏行写回已经被总线接收，接下来通过WB清V
                        wr_req_sent_r <= 1'b1;

                        wb_valid_r    <= 1'b1;
                        wb_way_r      <= replace_way_r;
                        wb_index_r    <= miss_index_r;

                        main_state    <= `MAIN_IDLE;
                    end
                end
                // uncache的写
                else if(uncache_valid_r && uncache_wr_r)begin
                    if (!wr_req_sent_r && wr_rdy) begin
                        wr_req_sent_r   <= 1'b1;
                        uncache_valid_r <= 1'b0;
                        uncache_wr_r    <= 1'b0;
                        main_state      <= `MAIN_IDLE;
                    end
                end
                else if (!wr_req_sent_r && wr_rdy) begin
                    // 写回请求只发送一次；总线接受后立即转入缺失行回填
                    wr_req_sent_r <= 1'b1;
                    refill_cnt_r  <= 2'b0;
                    refill_buf_r  <= {`LINE_SIZE{1'b0}};
                    rd_req_sent_r <= 1'b0;
                    main_state    <= `MAIN_REFILL;
                end
            end

            `MAIN_REFILL: begin
                // REFILL：先发缺失行请求，再接收 4 个数据拍
                if (code0 | code1) begin
                    cacop_this_cache_r <= 1'b0;
                    rd_req_sent_r      <= 1'b0;
                    wr_req_sent_r      <= 1'b0;
                    main_state         <= `MAIN_IDLE;
                end
                else if (!rd_req_sent_r && rd_rdy) begin
                    // 读请求只发送一次，之后等待总线逐拍返回 4 个 32位数据
                    rd_req_sent_r <= 1'b1;
                end
                // uncache的读
                else if(uncache_valid_r & ~uncache_wr_r)begin
                    if (ret_valid && ret_last) begin
                        rd_req_sent_r   <= 1'b0;
                        uncache_valid_r <= 1'b0;
                        uncache_wr_r    <= 1'b0;
                        main_state      <= `MAIN_IDLE;
                    end
                end
                else if (ret_valid) begin
                    case (refill_cnt_r)
                        2'b00: refill_buf_r[31:0] <= ret_data;
                        2'b01: refill_buf_r[63:32] <= ret_data;
                        2'b10: refill_buf_r[95:64] <= ret_data;
                        default: refill_buf_r[127:96] <= ret_data;
                    endcase
                    refill_cnt_r <= refill_cnt_r + 2'b01;

                    if (ret_last) begin
                        // REFILL 结束：更新 TagV/Dirty/LRU/Data Bank
                        // 这里统一把最终缓存行拆回 4 个 Data Bank 写入目标路
                        if (replace_way_r) begin
                            dirty_way1[miss_index_r] <= miss_op_r;
                        end
                        else begin
                            dirty_way0[miss_index_r] <= miss_op_r;
                        end

                        LRU[miss_index_r] <= ~replace_way_r;
                        refill_cnt_r      <= 2'b0;
                        rd_req_sent_r     <= 1'b0;
                        wr_req_sent_r     <= 1'b0;
                        main_state        <= `MAIN_IDLE;
                    end
                end
            end

            default: begin
                main_state <= `MAIN_IDLE;
            end
        endcase


        // Write Buffer 小状态机
        case (wb_state)
            `WB_IDLE: begin
                if (wb_valid_r) begin
                    wb_state <= `WB_WRITE;
                end
            end

            `WB_WRITE: begin
                // 命中写的数据由 Data Bank 访问块统一写入，这里只维护脏位
                if(code2)begin
                    cacop_this_cache_r <= 1'b0;
                end
                else if (wb_way_r) begin
                    dirty_way1[wb_index_r] <= 1'b1;
                end
                else begin
                    dirty_way0[wb_index_r] <= 1'b1;
                end

                wb_valid_r <= 1'b0;
                wb_state   <= `WB_IDLE;
            end

            default: begin
                wb_state   <= `WB_IDLE;
            end
        endcase
    end
end

//assign addr_ok = (main_state == `MAIN_IDLE) && can_accept_req;

assign data_ok = ((main_state == `MAIN_LOOKUP) && (lookup_read_hit || lookup_write_hit) && ~cacop_this_cache_r) ||
                 ((main_state == `MAIN_REPLACE) && uncache_valid_r && uncache_wr_r && wr_rdy) ||
                 ((main_state == `MAIN_REFILL) && ret_valid && ret_last) ||
                 cacop_done;

assign rdata = ((main_state == `MAIN_LOOKUP) && (lookup_read_hit || lookup_write_hit)) ? (req_op_r ? merged_hit_word : 
                                                                                                     hit_word) : 
               ((main_state == `MAIN_REFILL) && ret_valid && ret_last) ? ((uncache_valid_r && !uncache_wr_r) ? ret_data : 
                                                                                                               refill_final_word) : 
               32'b0;

assign rd_req  = (main_state == `MAIN_REFILL) && !rd_req_sent_r && !code0 && !code1;
assign rd_type = 3'b010;
assign rd_addr = (main_state == `MAIN_REFILL)
               ? ((uncache_valid_r && !uncache_wr_r)
                  ? {miss_tag_r, miss_index_r, miss_offset_r[3:2], 2'b00}
                  : {miss_tag_r, miss_index_r, 4'b0000})
               : 32'b0;
assign ar_len  = (main_state == `MAIN_REFILL) && ((uncache_valid_r && !uncache_wr_r) || (code0 | code1))
               ? 8'd0
               : 8'd3;

assign wr_req  = (main_state == `MAIN_REPLACE) && !wr_req_sent_r && !code0 && !(code1 & code2_0 == 3'b000) & 
                 ~(cache_code_r[2:0] == 3'b00 & cacop_this_cache_r);
assign wr_type = 3'b010;
assign wr_addr = ((main_state == `MAIN_REPLACE) && ~(cache_code_r[2:0] == 3'b00 & cacop_this_cache_r)) 
                                               ? ((uncache_valid_r && uncache_wr_r) 
                                               ? {miss_tag_r,miss_index_r,miss_offset_r[3:2],2'b00} 
                                               : {replace_tag_r,miss_index_r,4'b0000})                             
                   : 32'b0;
assign wr_wstrb = ((main_state == `MAIN_REPLACE) && uncache_valid_r && uncache_wr_r) & ~(cache_code_r[2:0] == 3'b00 & cacop_this_cache_r)
                ? miss_wstrb_r
                : 4'b1111;
assign wr_data = (main_state == `MAIN_REPLACE) & ~(cache_code_r[2:0] == 3'b00 & cacop_this_cache_r)
               ? ((uncache_valid_r && uncache_wr_r)
                  ? {96'b0, miss_wdata_r}
                  : replace_line_r)
               : 128'b0;
assign aw_len = ((main_state == `MAIN_REPLACE) && uncache_valid_r && uncache_wr_r)
              ? 8'd0
              : 8'd3;
              
endmodule
