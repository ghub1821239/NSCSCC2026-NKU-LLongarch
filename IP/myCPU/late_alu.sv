module late_alu (
    input  wire [3:0]  op,
    input  wire [31:0] src1,
    input  wire [31:0] src2,
    output reg  [31:0] result
);

always @(*) begin
    case (op)
        4'd0:  result = src1 + src2;                       // add
        4'd1:  result = src1 - src2;                       // sub
        4'd2:  result = $signed(src1) < $signed(src2);     // slt
        4'd3:  result = src1 < src2;                       // sltu
        4'd4:  result = src1 & src2;
        4'd5:  result = ~(src1 | src2);
        4'd6:  result = src1 | src2;
        4'd7:  result = src1 ^ src2;
        4'd8:  result = src1 << src2[4:0];
        4'd9:  result = src1 >> src2[4:0];
        4'd10: result = $signed(src1) >>> src2[4:0];
        4'd11: result = src2;                              // lui
        default: result = 32'b0;
    endcase
end

endmodule