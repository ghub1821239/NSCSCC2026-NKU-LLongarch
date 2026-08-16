module ifq #(
    parameter BUS_WIDTH = 106,
    parameter ISSUE     = 2,
    parameter DEPTH     = 2
)(
    input  wire                   clk,
    input  wire                   resetn,
    input  wire                   flush,

    input  wire                   in_valid,
    output wire                   in_allow,
    input  wire [BUS_WIDTH-1:0]   in_bus [ISSUE-1:0],//输入的bus

    output wire                   out_valid,
    input  wire                   out_allow,
    output wire [BUS_WIDTH-1:0]   out_bus [ISSUE-1:0]
);
localparam PTR_W = 1; // DEPTH==2,共有0，1两层

reg [BUS_WIDTH-1:0] mem [DEPTH-1:0][ISSUE-1:0];
reg [PTR_W:0]       count;//维护当前IFQ的指令数
reg [PTR_W-1:0]     wr_ptr;//写指针
reg [PTR_W-1:0]     rd_ptr;//读指针

wire push = in_valid  & in_allow  & ~flush;//从PreIF2压入
wire pop  = out_valid & out_allow & ~flush;//传送给decode

assign in_allow  = (count != DEPTH[PTR_W:0]); // 只看本模块计数，不要组合 out_allow,不满的时候可以进入
assign out_valid = (count != {PTR_W+1{1'b0}}) || (in_valid & in_allow);//IFQ不为空时可以输出，并且要减少一个空拍

integer si;
always @(posedge clk) begin
    if (!resetn) begin
        count  <= {(PTR_W+1){1'b0}};
        wr_ptr <= {PTR_W{1'b0}};
        rd_ptr <= {PTR_W{1'b0}};
    end
    else if (flush) begin
        //flush时冲刷IFQ
        count  <= {(PTR_W+1){1'b0}};
        wr_ptr <= {PTR_W{1'b0}};
        rd_ptr <= {PTR_W{1'b0}};
    end
    else begin
        if (push) begin
            for (si = 0; si < ISSUE; si = si + 1) begin
                mem[wr_ptr][si] <= in_bus[si];
            end
            wr_ptr <= wr_ptr + 1'b1;
        end
        if (pop) begin
            rd_ptr <= rd_ptr + 1'b1;
        end
        case ({push, pop})
            2'b10: count <= count + 1'b1;//只push的时候count+1
            2'b01: count <= count - 1'b1;//只pop的时候count-1
            default: count <= count;//都有或都没有则不变
        endcase
    end
end

genvar gi;
generate
    for (gi = 0; gi < ISSUE; gi = gi + 1) begin : gen_out
        //减少一个空拍
        assign out_bus[gi] = (count != {(PTR_W+1){1'b0}}) ? mem[rd_ptr][gi] : in_bus[gi];
    end
endgenerate

endmodule