module ras(
    input          clk,
    input          resetn,
    // ǰ��Ԥ���ѯ
    input          query_valid0,
    output         query_hit0,
    output  [31:0] query_target0,

    input          query_valid1,
    output         query_hit1,
    output  [31:0] query_target1,
    // �����ʵ call ����
    input          push_valid,
    input   [31:0] push_target,
    // �����ʵ return ����
    input          pop_valid
);

reg    [31:0] ras_stack [15:0];//16��32λ��Ŀ���ַ
reg    [4:0]  ras_sp;//ָ����һ����λ�ã�16����ַ���±��Ӧ����(1~16),0��ʾ��ջ��16��ʾ��

assign        query_hit0    = query_valid0 && (ras_sp != 5'b0) ? 1'b1 :
                             1'b0;
assign        query_target0 = query_valid0 && (ras_sp != 5'b0) ? ras_stack[ras_sp - 1] :
                             32'b0;
assign        query_hit1    = query_valid1 && (ras_sp != 5'b0) ? 1'b1 :
                             1'b0;
assign        query_target1 = query_valid1 && (ras_sp != 5'b0) ? ras_stack[ras_sp - 1] :
                             32'b0;

always @(posedge clk)begin
    if(!resetn)begin
        ras_sp            <= 5'd0;//��λʱջָ����0��RAS��
    end
    else if (push_valid) begin
        if (ras_sp < 5'd16) begin//ջδ��ʱ����push
            ras_stack[ras_sp] <= push_target;
            ras_sp            <= ras_sp + 5'd1;//��Ч��ַ��+1
        end
    end
    else if (pop_valid) begin
        if (ras_sp != 5'd0) begin//ջ�ǿ�ʱ����pop
            ras_sp            <= ras_sp - 5'd1;
        end
    end
end
endmodule 