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
//------------------------{reg 锁存提升主频}begin-------------------------//
reg        update_valid_r;
reg [31:0] update_pc_r;
reg [31:0] update_target_r;//真实目标地址
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

reg            btb_valid  [0:63];//64个1位有效位
reg     [23:0] btb_tag    [0:63];//64个24位tag
reg     [31:0] btb_target [0:63];//64个32位跳转目标地址
reg     [ 1:0] btb_type   [0:63];//64个2位分支类型

wire    [ 5:0] query_index0;
wire    [ 5:0] query_index1;
wire    [ 5:0] update_index;
wire    [23:0] query_tag0;
wire    [23:0] query_tag1;
wire    [23:0] update_tag;

//pc拆分成tag+index+字节偏移
assign         query_index0  = query_pc0[7:2];
assign         query_tag0    = query_pc0[31:8];

assign         query_index1  = query_pc1[7:2];
assign         query_tag1    = query_pc1[31:8];

assign         update_index  = update_pc_r[7:2];
assign         update_tag    = update_pc_r[31:8];

//查表：查询有效&当前项有效&tag匹配
assign         query_hit0    = query_valid0 & btb_valid[query_index0] &
                               (btb_tag[query_index0] == query_tag0);
assign         query_target0 = query_hit0 ? btb_target[query_index0] : 32'b0;
assign         query_type0   = query_hit0 ? btb_type[query_index0] : 2'b0;

assign         query_hit1    = query_valid1 & btb_valid[query_index1] &
                               (btb_tag[query_index1] == query_tag1);
assign         query_target1 = query_hit1 ? btb_target[query_index1] : 32'b0;
assign         query_type1   = query_hit1 ? btb_type[query_index1] : 2'b0;

//更新
integer        i;
always @(posedge clk) begin
    if (!resetn) begin
        for (i = 0; i < 64; i = i + 1) begin
            btb_valid[i]             <= 1'b0;//复位时所有valid清0
        end
    end
    else if (update_valid_r & ~update_cancel) begin//运行时需要更新就写入
        btb_valid [update_index] <= 1'b1;
        btb_tag   [update_index] <= update_tag;
        btb_target[update_index] <= update_target_r;
        btb_type  [update_index] <= update_type_r;
    end
end

endmodule
