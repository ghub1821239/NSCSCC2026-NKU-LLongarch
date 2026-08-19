module bht(
    input              clk,
    input              resetn,
    //查询端口
    input  wire        query_valid0,
    input  wire [31:0] query_pc0,
    output wire        query_taken0,
    input  wire        query_valid1,
    input  wire [31:0] query_pc1,
    output wire        query_taken1,
    // 本拍查询实际用到的 GHR，随指令进流水，供 ID 按同一索引训练
    output wire [7:0]  query_ghr_snap,
    //更新端口
    input  wire        update_valid,
    input  wire [31:0] update_pc,
    input  wire        update_taken,
    input  wire [7:0]  update_ghr_snap,
    input  wire        update_cancel
);

localparam BHT_N     = 256;
localparam BHT_IDX_W = 8;

reg        update_valid_r;
reg [31:0] update_pc_r;
reg        update_taken_r;
reg [7:0]  update_ghr_r;
reg [7:0]  ghr;

always @(posedge clk) begin
    if (!resetn) begin
        update_valid_r <= 1'b0;
        update_pc_r    <= 32'b0;
        update_taken_r <= 1'b0;
        update_ghr_r   <= 8'b0;
        ghr            <= 8'b0;
    end
    else begin
        update_valid_r <= update_cancel ? 1'b0 : update_valid;
        update_pc_r    <= update_pc;
        update_taken_r <= update_taken;
        update_ghr_r   <= update_ghr_snap;
        // 非推测：只在 ID 已发出的条件分支上移位；flush 时与计数器一样不更新
        if (update_valid_r & ~update_cancel)
            ghr <= {ghr[6:0], update_taken_r};
    end
end

assign query_ghr_snap = ghr;

reg [1:0] bht_counter [0:BHT_N-1];

wire [BHT_IDX_W-1:0] query_index0;
wire [BHT_IDX_W-1:0] query_index1;
wire [BHT_IDX_W-1:0] update_index;

assign query_index0 = query_pc0[9:2] ^ ghr;
assign query_index1 = query_pc1[9:2] ^ ghr;
assign update_index = update_pc_r[9:2] ^ update_ghr_r;

assign query_taken0 = query_valid0 & bht_counter[query_index0][1];
assign query_taken1 = query_valid1 & bht_counter[query_index1][1];

integer i;
always @(posedge clk) begin
    if (!resetn) begin
        for (i = 0; i < BHT_N; i = i + 1)
            bht_counter[i] <= 2'b01;
    end
    else if (update_valid_r & ~update_cancel) begin
        if (update_taken_r) begin
            if (bht_counter[update_index] != 2'b11)
                bht_counter[update_index] <= bht_counter[update_index] + 2'b01;
        end
        else begin
            if (bht_counter[update_index] != 2'b00)
                bht_counter[update_index] <= bht_counter[update_index] - 2'b01;
        end
    end
end

endmodule