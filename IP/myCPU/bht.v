module bht(
    input         clk,
    input         resetn,
    //查询端口
    input  wire        query_valid,
    input  wire [31:0] query_pc,//当前预测的指令pc
    output wire        query_taken,//预测是否跳转
    //更新端口
    input  wire        update_valid,//是否要更新 BHT
    input  wire [31:0] update_pc,//分支指令自己的 PC
    input  wire        update_taken,//真实是否跳转
    input  wire        update_cancel//如果取消就不同步更新
);

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

reg [1:0] bht_counter [0:63];//BHT数组，64个2位计数器

wire [5:0] query_index;
wire [5:0] update_index;

assign query_index  = query_pc[7:2];//BHT索引
assign update_index = update_pc_r[7:2];
//最高位是1即可跳转
assign query_taken = query_valid &
                     bht_counter[query_index][1];
//复位循环
integer i;

always @(posedge clk) begin
    if (!resetn) begin
        for (i = 0; i < 64; i = i + 1) begin
            bht_counter[i] <= 2'b01;//初始化为01
        end
    end
    else if (update_valid_r & ~update_cancel) begin//没有复位并且本周期更新有效时修改计数器
        if (update_taken_r) begin//真实跳转时的更新
            if (bht_counter[update_index] != 2'b11)
                bht_counter[update_index]
                    <= bht_counter[update_index] + 2'b01;
        end
        else begin
            if (bht_counter[update_index] != 2'b00)//真实不跳转时的更新
                bht_counter[update_index]
                    <= bht_counter[update_index] - 2'b01;
        end
    end
end

endmodule