module bht(
    input              clk,
    input              resetn,
    //查询端口
    input  wire        query_valid0,
    input  wire [31:0] query_pc0,//当前预测的指令pc
    output wire        query_taken0,//预测是否跳转

    input  wire        query_valid1,
    input  wire [31:0] query_pc1,//当前预测的指令pc
    output wire        query_taken1,//预测是否跳转
    //更新端口
    input  wire        update_valid,//是否要更新 BHT
    input  wire [31:0] update_pc,//分支指令自己的 PC
    input  wire        update_taken,//真实是否跳转
    input  wire        update_cancel//如果取消就不同步更新
);

localparam BHT_N     = 256;
localparam BHT_IDX_W = 8; // pc[9:2]，指令对齐后 1KB 窗口内不互相别名

//------------------------{reg 锁存提升主频}begin-------------------------//
reg        update_valid_r;
reg [31:0] update_pc_r;
reg        update_taken_r;
always @(posedge clk) begin
    if (!resetn) begin
        update_valid_r <= 1'b0;
        update_pc_r    <= 32'b0;
        update_taken_r <= 1'b0;
    end
    else begin
        update_valid_r <= update_cancel ? 1'b0 : update_valid;
        update_pc_r    <= update_pc;
        update_taken_r <= update_taken;
    end
end
//------------------------{reg 锁存提升主频}end-------------------------//

reg     [1:0] bht_counter [0:BHT_N-1];

wire    [BHT_IDX_W-1:0] query_index0;
wire    [BHT_IDX_W-1:0] query_index1;
wire    [BHT_IDX_W-1:0] update_index;

assign        query_index0 = query_pc0[9:2];
assign        query_index1 = query_pc1[9:2];
assign        update_index = update_pc_r[9:2];

assign        query_taken0 = query_valid0 & bht_counter[query_index0][1];
assign        query_taken1 = query_valid1 & bht_counter[query_index1][1];

integer       i;

always @(posedge clk) begin
    if (!resetn) begin
        for (i = 0; i < BHT_N; i = i + 1) begin
            bht_counter[i] <= 2'b01;
        end
    end
    else if (update_valid_r & ~update_cancel) begin
        if (update_taken_r) begin
            if (bht_counter[update_index] != 2'b11)
                bht_counter[update_index]
                    <= bht_counter[update_index] + 2'b01;
        end
        else begin
            if (bht_counter[update_index] != 2'b00)
                bht_counter[update_index]
                    <= bht_counter[update_index] - 2'b01;
        end
    end
end

endmodule