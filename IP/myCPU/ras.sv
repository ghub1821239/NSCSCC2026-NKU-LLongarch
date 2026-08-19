module ras(
    input          clk,
    input          resetn,
    input          query_valid0,
    output         query_hit0,
    output  [31:0] query_target0,
    input          query_valid1,
    output         query_hit1,
    output  [31:0] query_target1,
    input          push_valid,
    input   [31:0] push_target,
    input          pop_valid
);

reg    [31:0] ras_stack [15:0];
reg    [4:0]  ras_sp;

assign query_hit0    = query_valid0 && (ras_sp != 5'b0);
assign query_target0 = query_hit0 ? ras_stack[ras_sp - 1] : 32'b0;
assign query_hit1    = query_valid1 && (ras_sp != 5'b0);
assign query_target1 = query_hit1 ? ras_stack[ras_sp - 1] : 32'b0;

always @(posedge clk) begin
    if (!resetn) begin
        ras_sp <= 5'd0;
    end
    else if (push_valid) begin
        if (ras_sp < 5'd16) begin
            ras_stack[ras_sp] <= push_target;
            ras_sp            <= ras_sp + 5'd1;
        end
    end
    else if (pop_valid) begin
        if (ras_sp != 5'd0) begin
            ras_sp <= ras_sp - 5'd1;
        end
    end
end
endmodule