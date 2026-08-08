module ras(
    input         clk,
    input         resetn,
    // 前端预测查询
    input         query_valid,
    output        query_hit,
    output [31:0] query_target,
    // 后端真实 call 更新
    input         push_valid,
    input  [31:0] push_target,
    // 后端真实 return 更新
    input         pop_valid
);

reg  [31:0] ras_stack [15:0];//16个32位的目标地址
reg  [4:0]  ras_sp;//指向下一个空位置，16个地址的下标对应的是(1~16),0表示空栈，16表示满

assign query_hit = query_valid && (ras_sp != 0) ? 1'b1 :
                   1'b0;
assign query_target = query_valid && (ras_sp != 0) ? ras_stack[ras_sp - 1] :
                      32'b0;

always @(posedge clk)begin
    if(!resetn)begin
        ras_sp<=5'd0;//复位时栈指针清0，RAS空
    end
    else if (push_valid) begin
        if (ras_sp < 5'd16) begin//栈未满时才能push
            ras_stack[ras_sp] <= push_target;
            ras_sp <= ras_sp + 5'd1;//有效地址数+1
        end
    end
    else if (pop_valid) begin
        if (ras_sp != 5'd0) begin//栈非空时才能pop
            ras_sp <= ras_sp - 5'd1;
        end
    end
end
endmodule 