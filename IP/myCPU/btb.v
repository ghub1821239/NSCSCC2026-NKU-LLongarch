module btb (
    input  wire        clk,
    input  wire        resetn,

    //查询端口：preIF取指时来查BTB
    input  wire        query_valid,
    input  wire [31:0] query_pc,
    output wire        query_hit,//valid且tag匹配
    output wire [31:0] query_target,
    output wire [ 1:0] query_type,

    //更新端口：Decode确定真实结果后回来更新BTB
    input  wire        update_valid,
    input  wire [31:0] update_pc,
    input  wire [31:0] update_target,//真实目标地址
    input  wire [ 1:0] update_type,
    input wire         update_cancel
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
    else if (update_cancel) begin
        update_valid_r <= 1'b0;
    end
    else begin
        update_valid_r <= update_valid;
        if (update_valid) begin
            update_pc_r     <= update_pc;
            update_target_r <= update_target;
            update_type_r   <= update_type;
        end
    end
end

//------------------------{reg 锁存提升主频}end-------------------------//

reg        btb_valid  [0:63];//64个1位有效位
reg [23:0] btb_tag    [0:63];//64个24位tag
reg [31:0] btb_target [0:63];//64个32位跳转目标地址
reg [ 1:0] btb_type   [0:63];//64个2位分支类型

wire [ 5:0] query_index;
wire [ 5:0] update_index;
wire [23:0] query_tag;
wire [23:0] update_tag;

//pc拆分成tag+index+字节偏移
assign query_index = query_pc[7:2];
assign query_tag   = query_pc[31:8];

assign update_index = update_pc_r[7:2];
assign update_tag   = update_pc_r[31:8];

//查表：查询有效&当前项有效&tag匹配
assign query_hit = query_valid &
                   btb_valid[query_index] &
                   (btb_tag[query_index] == query_tag);

assign query_target = query_hit
                    ? btb_target[query_index]
                    : 32'b0;

assign query_type = query_hit
                  ? btb_type[query_index]
                  : 2'b0;

//更新
integer i;
always @(posedge clk) begin
    if (!resetn) begin
        for (i = 0; i < 64; i = i + 1) begin
            btb_valid[i] <= 1'b0;//复位时所有valid清0
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