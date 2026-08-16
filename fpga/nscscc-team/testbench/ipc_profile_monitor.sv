`timescale 1ns/1ps

module ipc_profile_monitor (
    input wire         clk,
    input wire         resetn,
    input wire         test_end,
    input wire [383:0] counters
);

wire [31:0] cycle_count                   = counters[0*32 +: 32];
wire [31:0] inst_retired_count            = counters[1*32 +: 32];
wire [31:0] issue_inst_count              = counters[2*32 +: 32];
wire [31:0] dual_issue_cycle              = counters[3*32 +: 32];
wire [31:0] single_issue_cycle            = counters[4*32 +: 32];
wire [31:0] recoverable_load_branch_cycle = counters[5*32 +: 32];
wire [31:0] dependency_stall_cycle        = counters[6*32 +: 32];
wire [31:0] backend_stall_cycle           = counters[7*32 +: 32];
wire [31:0] frontend_starve_cycle         = counters[8*32 +: 32];
wire [31:0] pair_conflict_cycle           = counters[9*32 +: 32];
wire [31:0] redirect_penalty_cycle        = counters[10*32 +: 32];
wire [31:0] dcache_load_wait_cycle        = counters[11*32 +: 32];

wire [31:0] issue_cycle = dual_issue_cycle + single_issue_cycle;
wire [31:0] named_category_sum = issue_cycle + dependency_stall_cycle +
                                 backend_stall_cycle + redirect_penalty_cycle +
                                 frontend_starve_cycle;
wire [31:0] other_cycle = cycle_count - named_category_sum;

reg printed;
always @(posedge clk) begin
    if (!resetn) begin
        printed <= 1'b0;
    end
    else if (test_end && !printed) begin
        printed <= 1'b1;
        // 只打印；计数窗口由 benchmark 自己的两次 CPU-count marker 控制。
        #10;
        $display("==============================================================");
        $display("IPC profile: cycle                    = %0d", cycle_count);
        $display("IPC profile: retired instructions      = %0d", inst_retired_count);
        $display("IPC profile: issued instructions       = %0d", issue_inst_count);
        $display("IPC profile: dual issue cycles         = %0d", dual_issue_cycle);
        $display("IPC profile: single issue cycles       = %0d", single_issue_cycle);
        $display("IPC profile: recoverable load->branch  = %0d", recoverable_load_branch_cycle);
        $display("IPC profile: dependency stall cycles   = %0d", dependency_stall_cycle);
        $display("IPC profile: backend stall cycles      = %0d", backend_stall_cycle);
        $display("IPC profile: frontend starve cycles    = %0d", frontend_starve_cycle);
        $display("IPC profile: pair conflict cycles      = %0d", pair_conflict_cycle);
        $display("IPC profile: redirect penalty cycles   = %0d", redirect_penalty_cycle);
        $display("IPC profile: dcache load wait cycles   = %0d", dcache_load_wait_cycle);
        $display("IPC profile: derived other cycles      = %0d", other_cycle);
        $display("IPC profile: exclusive category sum    = %0d",
                 named_category_sum + other_cycle);
        if (named_category_sum > cycle_count)
            $error("IPC profile categories overlap");
        if (pair_conflict_cycle > single_issue_cycle)
            $error("pair_conflict is not a subset of single_issue");
    end
end

endmodule

bind tb_top ipc_profile_monitor u_ipc_profile_monitor (
    .clk      (cpu_clk                   ),
    .resetn   (resetn                    ),
    .test_end (test_end                  ),
    .counters (u_soc_top.perf_counters   )
);
