module regfile#(
    parameter  ISSUE = 2
)(
    input  wire        clk,
    input  wire        resetn,
    // READ PORT 1
    input  wire [ 4:0] raddr1[ISSUE - 1 : 0],
    output wire [31:0] rdata1[ISSUE - 1 : 0],
    // READ PORT 2
    input  wire [ 4:0] raddr2[ISSUE - 1 : 0],
    output wire [31:0] rdata2[ISSUE - 1 : 0],
    // WRITE PORT
    input  wire        we    [ISSUE - 1 : 0],       //write enable, HIGH valid
    input  wire [ 4:0] waddr [ISSUE - 1 : 0],
    input  wire [31:0] wdata [ISSUE - 1 : 0]
);
reg     [31:0] rf[31:0];

//WRITE
integer        i;
always @(posedge clk) begin
    if (~resetn) begin
        for (i=0;i<32;i=i+1) begin
            rf[i]        <= 32'b0;
        end
    end
    else begin
        if (we[0] & (waddr[0] != 5'b0))begin
            rf[waddr[0]] <= wdata[0];
        end
        if (ISSUE >= 2) begin
            if (we[1] & (waddr[1] != 5'b0)) begin
                rf[waddr[1]] <= wdata[1];
            end
        end
    end
end

genvar  gi;
generate
    for (gi = 0; gi < ISSUE; gi = gi + 1)begin : gen_rd 
        //这里的写入是由先后顺序的，所以读的时候要判断：如果一读一写，特判是否有写后读
        wire    hit_w1_r1  = (ISSUE >= 2) & we[1] & (waddr[1] != 5'b0) & (waddr[1] == raddr1[gi]);//写入addr1,同时读addr1,直接读addr1的wdata[1]
        wire    hit_w0_r1  = we[0] & (waddr[0] != 5'b0) & (waddr[0] == raddr1[gi]);//写后读同一个addr1，直接读addr1的wdata[0]
        wire    hit_w1_r2  = (ISSUE >= 2) & we[1] & (waddr[1] != 5'b0) & (waddr[1] == raddr2[gi]);//同时写入和读addr2,直接读addr1的wdata[1]
        wire    hit_w0_r2  = we[0] & (waddr[0] != 5'b0) & (waddr[0] == raddr2[gi]);//写后读同一个addr2,直接读addr2的wdata[0]

        // assign  rdata1[gi] = (raddr1[gi] == 5'b0) ? 32'b0     :
        //                      hit_w1_r1             ? wdata[1]  :
        //                      hit_w0_r1             ? wdata[0]  :
        //                      rf[raddr1[gi]];
        // assign  rdata2[gi] = (raddr2[gi] == 5'b0) ? 32'b0     :
        //                      hit_w1_r2            ? wdata[1]  :
        //                      hit_w0_r2            ? wdata[0]  :
        //                      rf[raddr2[gi]];

        assign rdata1[gi] = (raddr1[gi] == 5'b0) ? 32'b0 : rf[raddr1[gi]];
        assign rdata2[gi] = (raddr2[gi] == 5'b0) ? 32'b0 : rf[raddr2[gi]];
    end 
endgenerate

endmodule
