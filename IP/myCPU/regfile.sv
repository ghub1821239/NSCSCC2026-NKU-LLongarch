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

// bank内先选择
function automatic [31:0] rf_bank_mux8(
    input [ 2:0] sel,
    input [31:0] data0,
    input [31:0] data1,
    input [31:0] data2,
    input [31:0] data3,
    input [31:0] data4,
    input [31:0] data5,
    input [31:0] data6,
    input [31:0] data7
);
begin
    case (sel)
        3'd0:    rf_bank_mux8 = data0;
        3'd1:    rf_bank_mux8 = data1;
        3'd2:    rf_bank_mux8 = data2;
        3'd3:    rf_bank_mux8 = data3;
        3'd4:    rf_bank_mux8 = data4;
        3'd5:    rf_bank_mux8 = data5;
        3'd6:    rf_bank_mux8 = data6;
        default: rf_bank_mux8 = data7;
    endcase
end
endfunction

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

        wire [31:0] rdata1_bank0 = rf_bank_mux8(raddr1[gi][2:0], rf[ 0], rf[ 1], rf[ 2], rf[ 3],
                                                                      rf[ 4], rf[ 5], rf[ 6], rf[ 7]);
        wire [31:0] rdata1_bank1 = rf_bank_mux8(raddr1[gi][2:0], rf[ 8], rf[ 9], rf[10], rf[11],
                                                                      rf[12], rf[13], rf[14], rf[15]);
        wire [31:0] rdata1_bank2 = rf_bank_mux8(raddr1[gi][2:0], rf[16], rf[17], rf[18], rf[19],
                                                                      rf[20], rf[21], rf[22], rf[23]);
        wire [31:0] rdata1_bank3 = rf_bank_mux8(raddr1[gi][2:0], rf[24], rf[25], rf[26], rf[27],
                                                                      rf[28], rf[29], rf[30], rf[31]);
        wire [31:0] rdata1_selected = (raddr1[gi][4:3] == 2'b00) ? rdata1_bank0 :
                                      (raddr1[gi][4:3] == 2'b01) ? rdata1_bank1 :
                                      (raddr1[gi][4:3] == 2'b10) ? rdata1_bank2 :
                                                                  rdata1_bank3;
        
        wire [31:0] rdata2_bank0 = rf_bank_mux8(raddr2[gi][2:0], rf[ 0], rf[ 1], rf[ 2], rf[ 3],
                                                                      rf[ 4], rf[ 5], rf[ 6], rf[ 7]);
        wire [31:0] rdata2_bank1 = rf_bank_mux8(raddr2[gi][2:0], rf[ 8], rf[ 9], rf[10], rf[11],
                                                                      rf[12], rf[13], rf[14], rf[15]);
        wire [31:0] rdata2_bank2 = rf_bank_mux8(raddr2[gi][2:0], rf[16], rf[17], rf[18], rf[19],
                                                                      rf[20], rf[21], rf[22], rf[23]);
        wire [31:0] rdata2_bank3 = rf_bank_mux8(raddr2[gi][2:0], rf[24], rf[25], rf[26], rf[27],
                                                                      rf[28], rf[29], rf[30], rf[31]);
        wire [31:0] rdata2_selected = (raddr2[gi][4:3] == 2'b00) ? rdata2_bank0 :
                                      (raddr2[gi][4:3] == 2'b01) ? rdata2_bank1 :
                                      (raddr2[gi][4:3] == 2'b10) ? rdata2_bank2 :
                                                                  rdata2_bank3;

        assign  rdata1[gi] = (raddr1[gi] == 5'b0) ? 32'b0 : rdata1_selected;
        assign  rdata2[gi] = (raddr2[gi] == 5'b0) ? 32'b0 : rdata2_selected;
    end 
endgenerate

endmodule
