module bht(
    input              clk,
    input              resetn,
    input  wire        query_valid0,
    input  wire [31:0] query_pc0,
    output wire        query_taken0,
    input  wire        query_valid1,
    input  wire [31:0] query_pc1,
    output wire        query_taken1,
    output wire [7:0]  query_ghr_snap,
    input  wire [7:0]  update_ghr_snap,
    input  wire        update_valid,
    input  wire [31:0] update_pc,
    input  wire        update_taken,
    input  wire        update_cancel,
    // PreIF 推测移位（allow_in 打拍，不要组合改 GHR）
    input  wire        spec_shift_valid,
    input  wire        spec_shift_taken,
    // 冲刷：spec 回到 arch（不要清 0）
    input  wire        restore
);

localparam BHT_N     = 256;
localparam BHT_IDX_W = 8;

reg        update_valid_r;
reg [31:0] update_pc_r;
reg        update_taken_r;
reg [7:0]  update_ghr_r;
reg [7:0]  arch_ghr;
reg [7:0]  spec_ghr;

wire        arch_shift = update_valid_r & ~update_cancel;
wire [7:0]  arch_ghr_n = {arch_ghr[6:0], update_taken_r};

always @(posedge clk) begin
    if (!resetn) begin
        update_valid_r <= 1'b0;
        update_pc_r    <= 32'b0;
        update_taken_r <= 1'b0;
        update_ghr_r   <= 8'b0;
        arch_ghr       <= 8'b0;
        spec_ghr       <= 8'b0;
    end
    else begin
        update_valid_r <= update_cancel ? 1'b0 : update_valid;
        update_pc_r    <= update_pc;
        update_taken_r <= update_taken;
        update_ghr_r   <= update_ghr_snap;

        if (arch_shift)
            arch_ghr <= arch_ghr_n;

        if (restore)
            spec_ghr <= arch_shift ? arch_ghr_n : arch_ghr;
        else if (spec_shift_valid)
            spec_ghr <= {spec_ghr[6:0], spec_shift_taken};
    end
end

assign query_ghr_snap = spec_ghr;

reg [1:0] bht_counter [0:BHT_N-1];

wire [BHT_IDX_W-1:0] query_index0;
wire [BHT_IDX_W-1:0] query_index1;
wire [BHT_IDX_W-1:0] update_index;

assign query_index0 = query_pc0[9:2] ^ spec_ghr;
assign query_index1 = query_pc1[9:2] ^ spec_ghr;
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