`timescale 1ns/1ps

module tb_ipc_profile_counters;

reg         clk;
reg         resetn;
reg         freeze;
reg         cycle_event;
reg  [1:0]  retired_event;
reg  [1:0]  issue_event;
reg         recoverable_load_branch_event;
reg         dependency_stall_event;
reg         backend_stall_event;
reg         frontend_starve_event;
reg         pair_conflict_event;
reg         redirect_penalty_event;
reg         dcache_load_wait_event;
wire [383:0] counters;

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

ipc_profile_counters dut (
    .clk                           (clk                          ),
    .resetn                        (resetn                       ),
    .freeze                        (freeze                       ),
    .cycle_event                   (cycle_event                  ),
    .retired_event                 (retired_event                ),
    .issue_event                   (issue_event                  ),
    .recoverable_load_branch_event (recoverable_load_branch_event),
    .dependency_stall_event        (dependency_stall_event       ),
    .backend_stall_event           (backend_stall_event          ),
    .frontend_starve_event         (frontend_starve_event        ),
    .pair_conflict_event           (pair_conflict_event          ),
    .redirect_penalty_event        (redirect_penalty_event       ),
    .dcache_load_wait_event        (dcache_load_wait_event       ),
    .counters                      (counters                     )
);

always #5 clk = ~clk;

task clear_events;
begin
    retired_event                 = 2'b00;
    issue_event                   = 2'b00;
    recoverable_load_branch_event = 1'b0;
    dependency_stall_event        = 1'b0;
    backend_stall_event           = 1'b0;
    frontend_starve_event         = 1'b0;
    pair_conflict_event           = 1'b0;
    redirect_penalty_event        = 1'b0;
    dcache_load_wait_event        = 1'b0;
end
endtask

task count_one_cycle;
begin
    @(posedge clk);
    #1;
end
endtask

reg [383:0] frozen_snapshot;
reg [31:0]  named_category_sum;
reg [31:0]  other_cycle;
reg [31:0]  category_sum;

initial begin
    clk         = 1'b0;
    resetn      = 1'b0;
    freeze      = 1'b0;
    cycle_event = 1'b1;
    clear_events();

    repeat (2) @(posedge clk);
    @(negedge clk);
    resetn       = 1'b1;
    retired_event = 2'b11;
    issue_event   = 2'b11;
    count_one_cycle();

    @(negedge clk);
    clear_events();
    retired_event       = 2'b01;
    issue_event         = 2'b01;
    pair_conflict_event = 1'b1;
    count_one_cycle();

    @(negedge clk);
    clear_events();
    dependency_stall_event = 1'b1;
    dcache_load_wait_event = 1'b1;
    count_one_cycle();

    @(negedge clk);
    clear_events();
    backend_stall_event = 1'b1;
    count_one_cycle();

    @(negedge clk);
    clear_events();
    redirect_penalty_event = 1'b1;
    count_one_cycle();

    @(negedge clk);
    clear_events();
    frontend_starve_event = 1'b1;
    count_one_cycle();

    @(negedge clk);
    clear_events();
    recoverable_load_branch_event = 1'b1;
    count_one_cycle();

    named_category_sum = dual_issue_cycle + single_issue_cycle +
                         dependency_stall_cycle + backend_stall_cycle +
                         redirect_penalty_cycle + frontend_starve_cycle;
    other_cycle = cycle_count - named_category_sum;
    category_sum = named_category_sum + other_cycle;

    if (cycle_count                   !== 32'd7 ||
        inst_retired_count            !== 32'd3 ||
        issue_inst_count              !== 32'd3 ||
        dual_issue_cycle              !== 32'd1 ||
        single_issue_cycle            !== 32'd1 ||
        recoverable_load_branch_cycle !== 32'd1 ||
        dependency_stall_cycle        !== 32'd1 ||
        backend_stall_cycle           !== 32'd1 ||
        frontend_starve_cycle         !== 32'd1 ||
        pair_conflict_cycle           !== 32'd1 ||
        redirect_penalty_cycle        !== 32'd1 ||
        dcache_load_wait_cycle        !== 32'd1 ||
        other_cycle                   !== 32'd1 ||
        category_sum                  !== cycle_count) begin
        $display("IPC PROFILE COUNTER TEST FAIL");
        $display("cycle=%0d retired=%0d issue=%0d dual=%0d single=%0d",
                 cycle_count, inst_retired_count, issue_inst_count,
                 dual_issue_cycle, single_issue_cycle);
        $finish;
    end

    @(negedge clk);
    freeze = 1'b1;
    retired_event = 2'b11;
    issue_event   = 2'b11;
    frozen_snapshot = counters;
    repeat (3) count_one_cycle();

    if (counters !== frozen_snapshot) begin
        $display("IPC PROFILE FREEZE TEST FAIL");
        $fatal(1);
    end

    $display("IPC PROFILE COUNTER TEST PASS");
    $finish;
end

endmodule
