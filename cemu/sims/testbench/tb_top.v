`timescale 1ns/1ps
module tb_top;
    reg aclk = 0;
    reg aresetn = 0;
    always #5 aclk = ~aclk; // 100MHz

    wire        debug0_commit_valid;
    wire [31:0] debug0_commit_pc;
    wire        debug0_commit_rf_wen;
    wire [4:0]  debug0_commit_rf_wnum;
    wire [31:0] debug0_commit_rf_wdata;
    wire        debug0_commit_csr_wen;
    wire [13:0] debug0_commit_csr_num;
    wire [31:0] debug0_commit_csr_wdata;

    wire        debug1_commit_valid;
    wire [31:0] debug1_commit_pc;
    wire        debug1_commit_rf_wen;
    wire [4:0]  debug1_commit_rf_wnum;
    wire [31:0] debug1_commit_rf_wdata;
    wire        debug1_commit_csr_wen;
    wire [13:0] debug1_commit_csr_num;
    wire [31:0] debug1_commit_csr_wdata;

    soc_sim_top u_soc (
        .aclk(aclk),
        .aresetn(aresetn),

        .debug0_commit_valid     (debug0_commit_valid),
        .debug0_commit_pc        (debug0_commit_pc),
        .debug0_commit_rf_wen    (debug0_commit_rf_wen),
        .debug0_commit_rf_wnum   (debug0_commit_rf_wnum),
        .debug0_commit_rf_wdata  (debug0_commit_rf_wdata),
        .debug0_commit_csr_wen   (debug0_commit_csr_wen),
        .debug0_commit_csr_num   (debug0_commit_csr_num),
        .debug0_commit_csr_wdata (debug0_commit_csr_wdata),

        .debug1_commit_valid     (debug1_commit_valid),
        .debug1_commit_pc        (debug1_commit_pc),
        .debug1_commit_rf_wen    (debug1_commit_rf_wen),
        .debug1_commit_rf_wnum   (debug1_commit_rf_wnum),
        .debug1_commit_rf_wdata  (debug1_commit_rf_wdata),
        .debug1_commit_csr_wen   (debug1_commit_csr_wen),
        .debug1_commit_csr_num   (debug1_commit_csr_num),
        .debug1_commit_csr_wdata (debug1_commit_csr_wdata)
    );

    wire        cmp_err;
    wire        cmp_pass;
    wire        cmp_eof;
    wire [31:0] cmp_count;
    wire        cycle_cmp_en;
    wire        cycle_s0_gpr, cycle_s0_csr;
    wire        cycle_s1_gpr, cycle_s1_csr;
    wire [31:0] cycle_s0_pc, cycle_s1_pc;

    golden_dual_slot_cmp #(
        .TRACE_FILE("D:/chiplab/repository/NSCSCC2026-LLongarch/cemu/sims/trace/golden_trace.txt"),
        .EXPECTED_EVENTS(29831)
    ) u_dual_cmp (
        .clk(aclk),
        .resetn(aresetn),

        .s0_valid    (debug0_commit_valid),
        .s0_pc       (debug0_commit_pc),
        .s0_rf_wen   (debug0_commit_rf_wen),
        .s0_rf_wnum  (debug0_commit_rf_wnum),
        .s0_rf_wdata (debug0_commit_rf_wdata),
        .s0_csr_wen  (debug0_commit_csr_wen),
        .s0_csr_num  (debug0_commit_csr_num),
        .s0_csr_wdata(debug0_commit_csr_wdata),

        .s1_valid    (debug1_commit_valid),
        .s1_pc       (debug1_commit_pc),
        .s1_rf_wen   (debug1_commit_rf_wen),
        .s1_rf_wnum  (debug1_commit_rf_wnum),
        .s1_rf_wdata (debug1_commit_rf_wdata),
        .s1_csr_wen  (debug1_commit_csr_wen),
        .s1_csr_num  (debug1_commit_csr_num),
        .s1_csr_wdata(debug1_commit_csr_wdata),

        .err         (cmp_err),
        .pass        (cmp_pass),
        .eof_hit     (cmp_eof),
        .cmp_count   (cmp_count),

        .cycle_cmp_en (cycle_cmp_en),
        .cycle_s0_gpr (cycle_s0_gpr),
        .cycle_s0_csr (cycle_s0_csr),
        .cycle_s1_gpr (cycle_s1_gpr),
        .cycle_s1_csr (cycle_s1_csr),
        .cycle_s0_pc  (cycle_s0_pc),
        .cycle_s1_pc  (cycle_s1_pc)
    );

    initial begin
        aresetn = 0;
        repeat (20) @(posedge aclk);
        aresetn = 1;
    end

    // 可选：观察双发同拍比对
    always @(posedge aclk) begin
        if (aresetn && cycle_cmp_en && (cycle_s0_gpr | cycle_s0_csr) &&
                                  (cycle_s1_gpr | cycle_s1_csr)) begin
            $display("[TB] dual-slot cmp @ s0_pc=0x%08x s1_pc=0x%08x count=%0d",
                     cycle_s0_pc, cycle_s1_pc, cmp_count);
        end
    end

    always @(posedge aclk) begin
        if (aresetn && cmp_err) begin
            $display("[TB] STOP on mismatch, compares=%0d", cmp_count);
            #100 $finish;
        end
        if (aresetn && cmp_pass) begin
            $display("[TB] PASS: dual-slot golden compare done, count=%0d", cmp_count);
            #100 $finish;
        end
    end

    // 来自 soc 内部 packed 口（需在 soc_sim_top 引出 debug_commit_valid/pc）
    // 若未引出，可直接在 soc_sim_top 加 output 并连接 core_top
    always @(posedge aclk) begin
        if (aresetn && debug1_commit_valid) begin
            $display("[TB] slot1 WB fire: pc1=0x%08x rf_we=%b csr_we=%b",
                    debug1_commit_pc,
                    debug1_commit_rf_wen,
                    debug1_commit_csr_wen);
        end
    end

    initial begin
        #2000000000;
        $display("[TB] TIMEOUT, compares=%0d", cmp_count);
        $display("  hint: check s0_pc/s1_pc stall, AXI, confreg");
        $finish;
    end

endmodule