`timescale 1ns/1ps
module golden_event_queue #(
    parameter DEPTH = 8
)(
    input  wire        clk,
    input  wire        resetn,

    input  wire        debug0_commit_valid,
    input  wire [31:0] debug0_commit_pc,
    input  wire        debug0_commit_rf_wen,
    input  wire [4:0]  debug0_commit_rf_wnum,
    input  wire [31:0] debug0_commit_rf_wdata,
    input  wire        debug0_commit_csr_wen,
    input  wire [13:0] debug0_commit_csr_num,
    input  wire [31:0] debug0_commit_csr_wdata,

    input  wire        debug1_commit_valid,
    input  wire [31:0] debug1_commit_pc,
    input  wire        debug1_commit_rf_wen,
    input  wire [4:0]  debug1_commit_rf_wnum,
    input  wire [31:0] debug1_commit_rf_wdata,
    input  wire        debug1_commit_csr_wen,
    input  wire [13:0] debug1_commit_csr_num,
    input  wire [31:0] debug1_commit_csr_wdata,

    output wire        head_valid,
    output wire [1:0]  head_type,
    output wire [31:0] head_pc,
    output wire [13:0] head_id,
    output wire [31:0] head_wdata,
    output reg         overflow,
    output wire [3:0]  count,
    input  wire        pop
);

    localparam WIDTH = 80;

    reg [WIDTH-1:0] mem [0:DEPTH-1];
    reg [3:0]       wr_ptr;
    reg [3:0]       rd_ptr;
    reg [3:0]       fifo_count;

    wire ev0_gpr = debug0_commit_valid && debug0_commit_rf_wen &&
                   (debug0_commit_rf_wnum != 5'd0);
    wire ev0_csr = debug0_commit_valid && debug0_commit_csr_wen;
    wire ev1_gpr = debug1_commit_valid && debug1_commit_rf_wen &&
                   (debug1_commit_rf_wnum != 5'd0);
    wire ev1_csr = debug1_commit_valid && debug1_commit_csr_wen;

    assign count      = fifo_count;
    assign head_valid = (fifo_count != 4'd0);
    assign head_type  = mem[rd_ptr][79:78];
    assign head_pc    = mem[rd_ptr][77:46];
    assign head_id    = mem[rd_ptr][45:32];
    assign head_wdata = mem[rd_ptr][31:0];

    function [WIDTH-1:0] make_pkt;
        input [1:0]  t;
        input [31:0] pc;
        input [13:0] id;
        input [31:0] wdata;
        begin
            make_pkt = {t, pc, id, wdata};
        end
    endfunction

    reg [WIDTH-1:0] pending [0:3];
    reg [2:0]       pending_cnt;
    integer         k;

    always @* begin
        pending_cnt = 3'd0;
        if (ev0_gpr) begin
            pending[pending_cnt] = make_pkt(2'd1, debug0_commit_pc,
                {9'b0, debug0_commit_rf_wnum}, debug0_commit_rf_wdata);
            pending_cnt = pending_cnt + 1;
        end
        if (ev0_csr) begin
            pending[pending_cnt] = make_pkt(2'd2, debug0_commit_pc,
                debug0_commit_csr_num, debug0_commit_csr_wdata);
            pending_cnt = pending_cnt + 1;
        end
        if (ev1_gpr) begin
            pending[pending_cnt] = make_pkt(2'd1, debug1_commit_pc,
                {9'b0, debug1_commit_rf_wnum}, debug1_commit_rf_wdata);
            pending_cnt = pending_cnt + 1;
        end
        if (ev1_csr) begin
            pending[pending_cnt] = make_pkt(2'd2, debug1_commit_pc,
                debug1_commit_csr_num, debug1_commit_csr_wdata);
            pending_cnt = pending_cnt + 1;
        end
    end

    always @(posedge clk) begin
        if (!resetn) begin
            wr_ptr     <= 4'd0;
            rd_ptr     <= 4'd0;
            fifo_count <= 4'd0;
            overflow   <= 1'b0;
        end else begin
            begin : upd
                reg [3:0] next_count;
                reg [3:0] next_wr;
                reg [3:0] next_rd;
                integer   k;

                next_count = fifo_count;
                next_wr    = wr_ptr;
                next_rd    = rd_ptr;

                if (pop && fifo_count != 0) begin
                    next_rd    = (rd_ptr + 4'd1) & (DEPTH-1);
                    next_count = next_count - 4'd1;
                end

                if (pending_cnt != 0) begin
                    if (next_count + pending_cnt > DEPTH) begin
                        overflow <= 1'b1;
                    end else begin
                        for (k = 0; k < 4; k = k + 1) begin
                            if (k < pending_cnt)
                                mem[(next_wr + k) & (DEPTH-1)] <= pending[k];
                        end
                        next_wr    = (next_wr + pending_cnt[3:0]) & (DEPTH-1);
                        next_count = next_count + pending_cnt[3:0];
                    end
                end

                wr_ptr     <= next_wr;
                rd_ptr     <= next_rd;
                fifo_count <= next_count;
            end
        end
    end

endmodule