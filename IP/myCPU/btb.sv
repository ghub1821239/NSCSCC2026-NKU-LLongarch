module btb (
    input  wire        clk,
    input  wire        resetn,

    //查询端口：preIF取指时来查BTB
    input  wire        query_valid0,
    input  wire [31:0] query_pc0,
    output wire        query_hit0,//valid且tag匹配
    output wire [31:0] query_target0,
    output wire [ 1:0] query_type0,

    input  wire        query_valid1,
    input  wire [31:0] query_pc1,
    output wire        query_hit1,//valid且tag匹配
    output wire [31:0] query_target1,
    output wire [ 1:0] query_type1,

    //更新端口：Decode确定真实结果后回来更新BTB
    input  wire        update_valid,
    input  wire [31:0] update_pc,
    input  wire [31:0] update_target,//真实目标地址
    input  wire [ 1:0] update_type,
    input  wire        update_cancel
);

localparam BTB_N     = 256;
localparam BTB_IDX_W = 8;  // pc[9:2]，与 BHT 对齐
localparam BTB_TAG_W = 22; // pc[31:10]

//------------------------{reg 锁存提升主频}begin-------------------------//
reg        update_valid_r;
reg [31:0] update_pc_r;
reg [31:0] update_target_r;
reg [ 1:0] update_type_r;
always @(posedge clk) begin
    if (!resetn) begin
        update_valid_r  <= 1'b0;
        update_pc_r     <= 32'b0;
        update_target_r <= 32'b0;
        update_type_r   <= 2'b0;
    end
    else begin
        update_valid_r  <= update_cancel ? 1'b0 : update_valid;
        update_pc_r     <= update_pc;
        update_target_r <= update_target;
        update_type_r   <= update_type;
    end
end
//------------------------{reg 锁存提升主频}end-------------------------//

reg                    btb_valid  [0:BTB_N-1];
reg [BTB_TAG_W-1:0]    btb_tag    [0:BTB_N-1];
reg [31:0]             btb_target [0:BTB_N-1];
reg [ 1:0]             btb_type   [0:BTB_N-1];

wire [BTB_IDX_W-1:0]   query_index0;
wire [BTB_IDX_W-1:0]   query_index1;
wire [BTB_IDX_W-1:0]   update_index;
wire [BTB_TAG_W-1:0]   query_tag0;
wire [BTB_TAG_W-1:0]   query_tag1;
wire [BTB_TAG_W-1:0]   update_tag;

assign query_index0  = query_pc0[9:2];
assign query_tag0    = query_pc0[31:10];
assign query_index1  = query_pc1[9:2];
assign query_tag1    = query_pc1[31:10];
assign update_index  = update_pc_r[9:2];
assign update_tag    = update_pc_r[31:10];

//查表：查询有效&当前项有效&tag匹配
assign         query_hit0    = query_valid0 & btb_valid[query_index0] &
                               (btb_tag[query_index0] == query_tag0);
// target 在 miss 时是 don't-care；消费者只在 query_hit 有效时选择它。
// 不用 query_hit 清零 32 位数据，避免命中信号驱动整条 target 总线。
assign         query_target0 = btb_target[query_index0];
assign         query_type0   = query_hit0 ? btb_type[query_index0] : 2'b0;

assign         query_hit1    = query_valid1 & btb_valid[query_index1] &
                               (btb_tag[query_index1] == query_tag1);
assign         query_target1 = btb_target[query_index1];
assign         query_type1   = query_hit1 ? btb_type[query_index1] : 2'b0;

integer i;
always @(posedge clk) begin
    if (!resetn) begin
        for (i = 0; i < BTB_N; i = i + 1) begin
            btb_valid[i] <= 1'b0;
        end
    end
    else if (update_valid_r & ~update_cancel) begin
        btb_valid [update_index] <= 1'b1;
        btb_tag   [update_index] <= update_tag;
        btb_target[update_index] <= update_target_r;
        btb_type  [update_index] <= update_type_r;
    end
end

endmodule
