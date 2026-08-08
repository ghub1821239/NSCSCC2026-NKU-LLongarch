`timescale 1ns / 1ps
`include "cache_def.vh"
module cache #(
    parameter code2_0 = 3'b0
)
(
    input  wire  clk,
    input  wire  resetn,
    //                                                          ����(input)/ȥ����output)
    input  wire         valid,//����������Ч                                       CPU
    input  wire         op, // op��0����1д                                        CPU
    input  wire [9 :0]  index,// index[13:4]
    input  wire [17:0]  tag,  // tag[31:14]
    input  wire [3 :0]  offset,// CPU ֱ�ӽ�ȡ��3:0 (�϶����漰��ʵӳ��)     CPU
    input  wire [3 :0]  wstrb,//                                            CPU
    input  wire [31:0]  wdata,//                                            CPU
    input  wire         uncache_valid,
    input  wire         uncache_wr, // ld:0 st:1

    output wire         addr_ok,//���յ�ת���ŵ� ��/д �� addrok ��CPU               CPU��O��                                   
    input  wire         rd_rdy,   // arready                                      ����
    output wire [31:0]  rd_addr, // CPU����paddr VA ��ƴ��һ��             ���ߣ�O��

    output wire         data_ok,//���߷��ص�                                       CPU��O��
    output wire [31:0]  rdata,// ���߶�����������                           CPU��O��
    output wire         rd_req,// CPU �Ķ�����                                     ���ߣ�O��
    output wire [2 :0]  rd_type, // �����ߵ�sizeֱ�ӽ�                      ���ߣ�rsize 010   arlen 8'd3 ��O��  
    output wire [7 :0]  ar_len,    
    input  wire         ret_valid,// ���߷��ص�������Ч��                           ���ߣ�rvalid
    input  wire         ret_last, // ���߷��ؽ�����                                 ����: last
    input  wire [31:0]  ret_data,// ���߸��Ķ����� rdata                    ����


    output wire         wr_req,//CPU�����                                        ���ߣ�O��
    output wire [2 :0]  wr_type,//                                        ���ߣ�O��
    output wire [31:0]  wr_addr,//                                        ���ߣ�O��
    output wire [3 :0]  wr_wstrb,//                                       ���ߣ�O��
    output wire [127:0] wr_data,//                                        ���ߣ�O��
    output wire [7 :0]  aw_len,
    input  wire         wr_rdy,//                                                  ����

    // cacop
    input  wire [ 4:0]  cache_code,
    input  wire         cacop_valid,
    output wire         cacop_done
);

//----------------------------- �Ĵ������忪ʼ --------------------------
// ��״̬���� Write Buffer ״̬��
// �洢��״̬ & д״̬
reg [2:0] main_state;
reg wb_state;

// �������ʹ��
reg  LRU  [`GROUP_NUM-1:0];
// α����滻
// reg [22:0] LFSR;

// ��λ��
reg                    dirty_way0 [`GROUP_NUM-1:0];
reg                    dirty_way1 [`GROUP_NUM-1:0];
// �ѵ�ǰ LOOKUP �����index����λ���棬������ MISS ��ʱ���ж�д��
reg                    dirty_way0_r;
reg                    dirty_way1_r;

//Request Buffer�����浱ǰ����LOOKUP������
reg                    req_valid_r;
reg                    req_op_r;
reg [`INDEX_WIDTH-1:0]  req_index_r;
reg [`TAG_WIDTH-1:0]    req_tag_r;
reg [`OFFSET_WIDTH-1:0] req_offset_r;
reg [3:0]              req_wstrb_r; // ��������ʱ���Ȼ������� ����֮�����и�wb_wstrb_r
reg [31:0]             req_wdata_r; // ԭʼдdata
reg                    uncache_valid_r;
reg                    uncache_wr_r;
reg                    cacop_this_cache_r;
reg [4:0]              cache_code_r;

//Miss Buffer�����浱ǰȱʧ�����������
reg                    miss_op_r;
reg [`INDEX_WIDTH-1:0] miss_index_r;
reg [`TAG_WIDTH-1:0]   miss_tag_r;
reg [`OFFSET_WIDTH-1:0]miss_offset_r;
reg [3:0]              miss_wstrb_r;
reg [31:0]             miss_wdata_r;
// ���� LRU & ����滻�㷨 �ҵ���replace��way
reg                    replace_way_r;
reg [`TAG_WIDTH-1:0]   replace_tag_r;
reg                    replace_valid_r;
reg                    replace_dirty_r;
reg[127:0]             replace_line_r;

//Write Buffer������д���ݴ棬�ٵ���д Data Bank
reg                    wb_valid_r;
reg                    wb_way_r;
reg [`INDEX_WIDTH-1:0] wb_index_r;
reg [1:0]              wb_bank_r;
reg [3:0]              wb_wstrb_r; // wdata �Լ���
reg [31:0]             wb_wdata_r;

// �������ڱ�����AXI RAM ������Э�Ĳ�����һ��32λ���صĴ��ġ�
// cnt���Ǵ��ģ�buf�Ǵ����cache line���ݵļĴ���
reg [1:0]              refill_cnt_r;
//�洢����ֱ�Ӵ�data_ram/inst_ram���û�����cache line
reg [127:0]            refill_buf_r;
reg                    rd_req_sent_r;
reg                    wr_req_sent_r;

integer i;
//----------------------------- �Ĵ���������� --------------------------

//----------------------------- �������忪ʼ --------------------------
wire [`TAG_WIDTH-1:0]  way0_tag;
wire [`TAG_WIDTH-1:0]  way1_tag;
wire                   way0_v;
wire                   way1_v;
wire                   way0_d;
wire                   way1_d;
// way0/1��ѡ���word �Լ�����ѡ���word
wire [31:0]           way0_word;
wire [31:0]           way1_word;
wire                  way0_hit;
wire                  way1_hit;
wire                  cache_hit;
wire                  hit_way;
wire [31:0]           hit_word;
// stͨ��������д�루st_h,st_b)
wire [31:0]           merged_hit_word;

//refill_buf_r�ǻ���������˱�Ȼ��ret_data��һ�����ڣ����wire���൱�ڿ���˲ʱ�仯����ret_data
//���ص�˲ʱ���cache line�е�ֵ�ͻ����µ�
wire [127:0]          refill_line_next;
// ��inst_data/ldҪ�á� || ��stҪ�ĵ���һ��word��
wire [31:0]           refill_word;
// �����Ե���st_h.w.b ����Ҫ��д���ֵ
wire [31:0]           refill_merged_word;


// ����Ч· replaceȥѡ���滻��λ��
// ��Ҫ�滻��һ·��Ӧ�ľ�����
wire                  has_invalid_way;
wire                  invalid_way;
wire                  policy_way;
wire                  replace_way;
wire [`TAG_WIDTH-1:0]  replace_tag;
wire                  replace_valid;
wire                  replace_dirty;
wire                  replace_need_writeback;
wire [127:0]          replace_line;

// ����stд���ݵ��ж�֮��Ҫ��cache��д�ص�line
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
// refill�ٴ�I/D RAM�û�cache line֮��Ҫ����дcache�׶�
wire                  refill_write;
wire                  wb_write;

// TagV RAM �˿�
// дTAGV
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

// Data Bank RAM �˿�
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
//----------------------------- ����������� --------------------------

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

//----------------------------- TAGV RAM �����߼� begin --------------------------
assign tagv_way0_wea       = (refill_write && !replace_way_r);
assign tagv_way0_code2     = (wb_write && code2 && !wb_way_r);
assign tagv_way1_wea       = (refill_write &&  replace_way_r);
assign tagv_way1_code2     = (wb_write && code2 &&  wb_way_r);
// �����д �͵ȵ�д��ʱ����ȥ���� 
// ����Ƕ� �Ǿ�ֱ���ڴ����˲���TAGV����·�Ȱ����ݶ�������֮����ѡ
// �����CACOP ������ʵҲ��index��addr
assign tagv_way0_addr = tagv_way0_code2 ? wb_index_r : tagv_way0_wea ? miss_index_r : index;
assign tagv_way1_addr = tagv_way1_code2 ? wb_index_r : tagv_way1_wea ? miss_index_r : index;
// д����
// TagV entry layout (21b BRAM): {2'b0, tag[17:0], V}
assign tagv_way0_dina = (tagv_way0_wea & code0) ? 21'b0 :
                        (tagv_way0_wea & code1) ? {2'b0, replace_tag_r, 1'b0} :
                        (tagv_way0_code2 & code2) ? 21'b0 :
                        {2'b0, miss_tag_r, 1'b1};
assign tagv_way1_dina = (tagv_way1_wea & code0) ? 21'b0 :
                        (tagv_way1_wea & code1) ? {2'b0, replace_tag_r, 1'b0} :
                        (tagv_way1_code2 & code2) ? 21'b0 :
                        {2'b0, miss_tag_r, 1'b1};
// TagV RAM��ÿ·һ�� 256x21 ����λ[20:1]Ϊ��ǩ��λ[0]Ϊ��Чλ
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
//----------------------------- TAGV RAM �����߼� end --------------------------

//----------------------------- DATA BANK RAM �����߼� begin --------------------------
// ÿһ��bank��д/��ʹ�� 
// wb_write��write buffer

//(refill_write && !replace_way_r):�� inst/data RAM �����滻
//(wb_write && !wb_way_r && (wb_bank_r == 2'b00) cache �����µ�st
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

// ���ݰ�ÿ· 4 �� Data Bank ��֯
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
//----------------------------- DATA BANK RAM �����߼� begin --------------------------

//----------------------------- LOOKUP/REPLACE/REFILL ����߼���ʼ --------------------------
assign way0_tag = tagv_way0_r[18:1];
assign way1_tag = tagv_way1_r[18:1];
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

//MISS ʱ��������Ч·�������ٰ��滻����ѡ���滻·
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

// дȱʧʱ��������ɺ�Ҫ��Ŀ�����ٺϲ�һ��
// ret_last ���ķ��ص����һ��������Ҳ���벢�����ջ�����
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

//ֻ����״̬�����С�Write Buffer Ҳ����ʱ���Ž����µĻ�������
//assign can_accept_req   = (main_state == `MAIN_IDLE) && (wb_state == `WB_IDLE) && !wb_valid_r;
// cacop_this_cacheҲӦ�ý���
assign lookup_begin     = (valid | cacop_this_cache) && can_accept_req;
// ����Ƕ���Hitǿ��uncache miss
assign lookup_read_hit  = cache_hit && !req_op_r && ~(uncache_valid_r && ~uncache_wr_r) && ~code0 && ~code1;
// ͬ��дҲ��
assign lookup_write_hit = cache_hit &&  req_op_r && ~(uncache_valid_r && uncache_wr_r) && ~cacop_this_cache_r;
// ǿ��miss
assign lookup_miss      = !cache_hit | uncache_valid_r | code0 | code1;
// refill_write������refill״̬��Ҫ��cache line�����cache
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

//----------------------------- LOOKUP/REPLACE/REFILL ����߼����� --------------------------

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

        // ����ֻ��Ԫ���ݣ�����Ƭ���� Data RAM�������ƻ� BRAM �ƶϷ��
        for (i = 0; i < `GROUP_NUM; i = i + 1) begin
            dirty_way0[i] <= 1'b0;
            dirty_way1[i] <= 1'b0;
            LRU[i]        <= 1'b0;
        end
    end
    else begin
        // α����滻
        // α���ʹ��λ����ѯ�ֲ���Բ�ѯ��λ����Щ���
        //LFSR <= {LFSR[21:0], LFSR[22] ^ LFSR[17]};

        case (main_state)
            `MAIN_IDLE: begin
                if (lookup_begin) begin
                    // ��һ�ģ��������󣬲�����· TagV/Data Bank ������ַ
                    req_valid_r  <= 1'b1;
                    req_op_r     <= cacop_this_cache ? 1'b0: op;// ��Ϊ����cache��ҪV��Ϊ0,������ʵ�൱��ld����Ҫд
                    req_index_r  <= index;
                    req_tag_r    <= tag;
                    req_offset_r <= offset;
                    req_wstrb_r  <= wstrb;
                    req_wdata_r  <= wdata;
                    uncache_valid_r <= uncache_valid & ~cacop_this_cache;// �����ڷ�cacopָ���ʱ�����uncache
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

                        // D-cache code2 �����У����������У���д��
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
                            // I-cache���У�����D-cache�ɾ����У�ֱ����V
                            wb_valid_r <= 1'b1;
                            wb_way_r   <= hit_way;
                            wb_index_r <= req_index_r;
                        end

                        main_state <= `MAIN_IDLE;
                    end
                end
                else if (lookup_write_hit) begin
                    // д���У���״̬��ֻ����ȷ������
                    // ����д Data Bank �Ķ������� Write Buffer ״̬��
                    wb_valid_r <= 1'b1;
                    wb_way_r   <= hit_way;
                    wb_index_r <= req_index_r;
                    wb_bank_r  <= req_offset_r[3:2];
                    wb_wstrb_r <= req_wstrb_r;
                    // LOOKUP ���Ѿ����������֣����ﱣ��ϲ��������
                    wb_wdata_r <= merged_hit_word;

                    // ����һ·�󣬰���һ·���"����"
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
                    // LOOKUP ȱʧ���ѵ�ǰȱʧ������ Miss Buffer
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
                    // ������֧
                    req_valid_r      <= 1'b0;
                    main_state       <= `MAIN_IDLE;
                end
            end

            `MAIN_MISS: begin
                // MISS���Ⱦ������滻·�Ƿ���Ҫд��
                if(code0)begin
                    refill_cnt_r   <= 2'b0;
                    refill_buf_r   <= {`LINE_SIZE{1'b0}};
                    main_state     <= `MAIN_REFILL;
                end
                else if (code1)begin
                    // ֻ����Ч&��λ��Ҫreplaceд�ص�ram
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
                    // ���滻·��Ч��˵����·�ǿղۣ���ֱ�ӻ���
                    refill_cnt_r  <= 2'b0;
                    refill_buf_r  <= {`LINE_SIZE{1'b0}};
                    rd_req_sent_r        <= 1'b0;
                    main_state    <= `MAIN_REFILL;
                end
                else if (!replace_dirty_r) begin
                    // ���滻·��Ч�����࣬����Ҫ REPLACE��ֱ�ӽ��� REFILL
                    refill_cnt_r  <= 2'b0;
                    refill_buf_r  <= {`LINE_SIZE{1'b0}};
                    rd_req_sent_r        <= 1'b0;
                    main_state    <= `MAIN_REFILL;
                end
                else begin
                    // ���滻·��Ч��Ϊ��飬����������д��
                    wr_req_sent_r        <= 1'b0;
                    main_state    <= `MAIN_REPLACE;
                end
            end

            `MAIN_REPLACE: begin
                // REPLACE���ȴ����߽���д������
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
                        // ����д���Ѿ������߽��գ�������ͨ��WB��V
                        wr_req_sent_r <= 1'b1;

                        wb_valid_r    <= 1'b1;
                        wb_way_r      <= replace_way_r;
                        wb_index_r    <= miss_index_r;

                        main_state    <= `MAIN_IDLE;
                    end
                end
                // uncache��д
                else if(uncache_valid_r && uncache_wr_r)begin
                    if (!wr_req_sent_r && wr_rdy) begin
                        wr_req_sent_r   <= 1'b1;
                        uncache_valid_r <= 1'b0;
                        uncache_wr_r    <= 1'b0;
                        main_state      <= `MAIN_IDLE;
                    end
                end
                else if (!wr_req_sent_r && wr_rdy) begin
                    // д������ֻ����һ�Σ����߽��ܺ�����ת��ȱʧ�л���
                    wr_req_sent_r <= 1'b1;
                    refill_cnt_r  <= 2'b0;
                    refill_buf_r  <= {`LINE_SIZE{1'b0}};
                    rd_req_sent_r <= 1'b0;
                    main_state    <= `MAIN_REFILL;
                end
            end

            `MAIN_REFILL: begin
                // REFILL���ȷ�ȱʧ�������ٽ��� 4 ��������
                if (code0 | code1) begin
                    cacop_this_cache_r <= 1'b0;
                    rd_req_sent_r      <= 1'b0;
                    wr_req_sent_r      <= 1'b0;
                    main_state         <= `MAIN_IDLE;
                end
                else if (!rd_req_sent_r && rd_rdy) begin
                    // ������ֻ����һ�Σ�֮��ȴ��������ķ��� 4 �� 32λ����
                    rd_req_sent_r <= 1'b1;
                end
                // uncache�Ķ�
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
                        // REFILL ���������� TagV/Dirty/LRU/Data Bank
                        // ����ͳһ�����ջ����в�� 4 �� Data Bank д��Ŀ��·
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


        // Write Buffer С״̬��
        case (wb_state)
            `WB_IDLE: begin
                if (wb_valid_r) begin
                    wb_state <= `WB_WRITE;
                end
            end

            `WB_WRITE: begin
                // ����д�������� Data Bank ���ʿ�ͳһд�룬����ֻά����λ
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
