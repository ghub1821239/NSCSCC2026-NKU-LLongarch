`timescale 1ns/1ps
// Dual-slot compare: slot0 then slot1; CSR then GPR (match CEMU trace order)
// Compare all writeback events of this cycle against golden in one clock edge.
// golden format:
//   1 <pc> <rd>      <wdata>
//   2 <pc> <csr_num> <wdata>
module golden_dual_slot_cmp #(
    parameter TRACE_FILE      = "D:/chiplab/repository/NSCSCC2026-LLongarch/cemu/sims/trace/golden_trace.txt",
    parameter EXPECTED_EVENTS = 91907
)(
    input  wire        clk,
    input  wire        resetn,

    // slot0 (pc0)
    input  wire        s0_valid,
    input  wire [31:0] s0_pc,
    input  wire        s0_rf_wen,
    input  wire [4:0]  s0_rf_wnum,
    input  wire [31:0] s0_rf_wdata,
    input  wire        s0_csr_wen,
    input  wire [13:0] s0_csr_num,
    input  wire [31:0] s0_csr_wdata,

    // slot1 (pc1)
    input  wire        s1_valid,
    input  wire [31:0] s1_pc,
    input  wire        s1_rf_wen,
    input  wire [4:0]  s1_rf_wnum,
    input  wire [31:0] s1_rf_wdata,
    input  wire        s1_csr_wen,
    input  wire [13:0] s1_csr_num,
    input  wire [31:0] s1_csr_wdata,

    output reg         err,
    output reg         pass,
    output reg         eof_hit,
    output reg [31:0]  cmp_count,

    // any writeback event this cycle (for waveform)
    output wire        cycle_cmp_en,
    output wire        cycle_s0_gpr,
    output wire        cycle_s0_csr,
    output wire        cycle_s1_gpr,
    output wire        cycle_s1_csr,
    output wire [31:0] cycle_s0_pc,
    output wire [31:0] cycle_s1_pc
);

    parameter INIT_BIN = "D:/chiplab/repository/NSCSCC2026-LLongarch/cemu/sims/bin/main.bin";

    reg [7:0] prog_mem [0:1024*1024-1];
    integer bin_fd, bin_n;

    initial begin
        bin_fd = $fopen(INIT_BIN, "rb");
        if (bin_fd == 0) begin
            $display("[TRACE] WARN: cannot open %s for rdcnt decode", INIT_BIN);
        end else begin
            bin_n = $fread(prog_mem, bin_fd);
            $fclose(bin_fd);
            $display("[TRACE] rdcnt-skip: loaded %0d bytes from %s", bin_n, INIT_BIN);
        end
    end

    function automatic [31:0] fetch_inst_word;
        input [31:0] va;
        reg [31:0] pa;
        integer b;
        begin
            pa = {12'h0, va[19:0]}; // same as axi_sim_ram map_addr
            b  = pa[31:0];
            fetch_inst_word = {prog_mem[b+3], prog_mem[b+2], prog_mem[b+1], prog_mem[b]};
        end
    endfunction

    // RDCNTVL/RDCNTVH: rk=11000/11001, rj=0, rd!=0; RDCNTID (rd=0) not included
    function automatic is_rdcnt_unstable_gpr;
        input [31:0] pc;
        input [4:0]  wnum;
        reg [31:0] inst;
        begin
            is_rdcnt_unstable_gpr = 1'b0;
            if (wnum == 5'd0)
                is_rdcnt_unstable_gpr = 1'b0;
            else begin
                inst = fetch_inst_word(pc);
                if ((inst[31:15] == 15'h0) &&
                    ((inst[14:10] == 5'b11000) || (inst[14:10] == 5'b11001)) &&
                    (inst[9:5] == 5'b0))
                    is_rdcnt_unstable_gpr = 1'b1;
            end
        end
    endfunction

    // CSR: inst[31:24]==8'h04  (CSRRD/CSRWR/CSRXCHG)
    function automatic is_csr_op;
        input [31:0] pc;
        reg [31:0] inst;
        begin
            inst = fetch_inst_word(pc);
            is_csr_op = (inst[31:24] == 8'h04);
        end
    endfunction

    // Verilog-2001：任意位 X/Z 则为 1（替代 $isunknown）
    function automatic has_xz;
        input [31:0] wdata;
        begin
            has_xz = ((wdata ^ wdata) !== 32'h0);
        end
    endfunction

    // DUT wdata 含 X/Z，且来自 CSR 读旧值 / CSR 写
    function automatic csr_wdata_dontcare;
        input [1:0]  dut_type;
        input [31:0] dut_pc;
        input [31:0] dut_wdata;
        begin
            csr_wdata_dontcare = has_xz(dut_wdata) &&
                                ((dut_type == 2'd2) || is_csr_op(dut_pc));
        end
    endfunction

    integer fd;
    integer r;
    integer ref_type;
    reg [31:0] ref_pc;
    reg [31:0] ref_id;
    reg [31:0] ref_wdata;
    reg        opened;

    // this-cycle event detect
    wire s0_gpr = s0_valid && s0_rf_wen && (s0_rf_wnum != 5'd0);
    wire s0_csr = s0_valid && s0_csr_wen;
    wire s1_gpr = s1_valid && s1_rf_wen && (s1_rf_wnum != 5'd0);
    wire s1_csr = s1_valid && s1_csr_wen;

    assign cycle_cmp_en = s0_gpr | s0_csr | s1_gpr | s1_csr;
    assign cycle_s0_gpr = s0_gpr;
    assign cycle_s0_csr = s0_csr;
    assign cycle_s1_gpr = s1_gpr;
    assign cycle_s1_csr = s1_csr;
    assign cycle_s0_pc  = s0_pc;
    assign cycle_s1_pc  = s1_pc;

    initial begin
        err       = 1'b0;
        pass      = 1'b0;
        eof_hit   = 1'b0;
        cmp_count = 32'd0;
        opened    = 1'b0;
        fd = $fopen(TRACE_FILE, "r");
        if (fd == 0) begin
            $display("[TRACE] ERROR: cannot open %s", TRACE_FILE);
            err = 1'b1;
        end else begin
            opened = 1'b1;
            $display("[TRACE] open %s (dual-slot mode)", TRACE_FILE);
        end
    end

    // read one golden line; eof_hit=1 at EOF
    task automatic read_next_ref;
        begin
            ref_type = 0;
            r = $fscanf(fd, "%d %h %h %h", ref_type, ref_pc, ref_id, ref_wdata);
            if (r != 4) begin
                eof_hit = 1'b1;
            end
        end
    endtask

    // compare one DUT event; fail=1 means mismatch
    task automatic compare_one;
        input  [1:0]  dut_type;
        input  [31:0] dut_pc;
        input  [13:0] dut_id;
        input  [31:0] dut_wdata;
        input  [1:0]  dut_slot;
        input  [2:0]  dut_kind;
        output        fail;
        begin
            fail      = 1'b0;
            skip_this = 1'b0;

            if (!opened || err || pass) begin
                fail = 1'b0;
            end else if ((dut_type == 2'd1) && (dut_kind == 3'd0)) begin
                skip_rd   = dut_id[4:0];
                skip_inst = fetch_inst_word(dut_pc);
                skip_rj   = skip_inst[9:5];
                skip_rk   = skip_inst[14:10];

                if (is_rdcnt_unstable_gpr(dut_pc, skip_rd)) begin
                    unstable_gpr[skip_rd] = 1'b1;
                    skip_this = 1'b1;
                    $display("[TRACE] SKIP rdcnt unstable GPR slot%0d PC=0x%08x rd=r%0d dut=0x%08x",
                            dut_slot, dut_pc, skip_rd, dut_wdata);
                end
                else if ((skip_rj != 5'd0 && unstable_gpr[skip_rj]) ||
                        (skip_inst[31:22] == 10'd0 && skip_rk != 5'd0 &&
                        skip_rk != 5'd24 && skip_rk != 5'd25 &&
                        unstable_gpr[skip_rk])) begin
                        unstable_gpr[skip_rd] = 1'b1;
                        skip_this = 1'b1;
                        read_next_ref();
                        if (eof_hit) begin
                            if (cmp_count >= EXPECTED_EVENTS) begin
                                $display("[TRACE] skip-unstable at EOF, already compared %0d, treat as done",
                                        cmp_count);
                            end else begin
                                $display("[TRACE] EOF while skipping unstable GPR (slot%0d) PC=0x%08x rd=r%0d count=%0d",
                                        dut_slot, dut_pc, skip_rd, cmp_count);
                                fail = 1'b1;
                            end
                        end else if (ref_type[1:0] != 2'd1 ||
                                    ref_pc !== dut_pc ||
                                    ref_id[4:0] !== skip_rd) begin
                            $display("[TRACE] MISMATCH #%0d while skipping unstable GPR (pc/rd must still match)",
                                    cmp_count);
                            $display("  ref : type=%0d PC=0x%08x id=0x%04x wdata=0x%08x",
                                    ref_type, ref_pc, ref_id[13:0], ref_wdata);
                            $display("  dut : type=1 PC=0x%08x id=0x%04x wdata=0x%08x (wdata ignored)",
                                    dut_pc, skip_rd, dut_wdata);
                            fail = 1'b1;
                        end else begin
                            cmp_count = cmp_count + 32'd1;
                        end
                    end
                else if (is_csr_op(dut_pc) && has_xz(dut_wdata)) begin
                    // CSRWR/CSRRD/CSRXCHG 把未初始化 CSR 写回 GPR：消费 golden，不比 wdata
                    unstable_gpr[skip_rd] = 1'b1;
                    $display("[TRACE] IGNORE uninit-CSR GPR slot%0d PC=0x%08x rd=r%0d dut=0x%08x",
                            dut_slot, dut_pc, skip_rd, dut_wdata);
                end
                else begin
                    unstable_gpr[skip_rd] = 1'b0;
                end
            end

            if (!opened || err || pass || skip_this) begin
            end else begin
                read_next_ref();
                if (eof_hit) begin
                    if (cmp_count >= EXPECTED_EVENTS) begin
                        $display("[TRACE] EOF after EXPECTED_EVENTS=%0d, treat as done", cmp_count);
                    end else begin
                        $display("[TRACE] EOF while expecting event (slot%0d %s) count=%0d",
                                dut_slot, dut_kind ? "CSR" : "GPR", cmp_count);
                        fail = 1'b1;
                    end
               end else if (dut_type != ref_type[1:0] ||
                            dut_pc   !== ref_pc ||
                            (!csr_wdata_dontcare(dut_type, dut_pc, dut_wdata) &&
                            (dut_wdata !== ref_wdata)) ||
                            ((dut_type == 2'd1) && (dut_id[4:0]  !== ref_id[4:0])) ||
                            ((dut_type == 2'd2) && (dut_id[13:0] !== ref_id[13:0])) ||
                            ((dut_type != 2'd1) && (dut_type != 2'd2))) begin
                    $display("[TRACE] MISMATCH #%0d at slot%0d %s",
                            cmp_count, dut_slot, dut_kind ? "CSR" : "GPR");
                    $display("  ref : type=%0d PC=0x%08x id=0x%04x wdata=0x%08x",
                            ref_type, ref_pc, ref_id[13:0], ref_wdata);
                    $display("  dut : type=%0d PC=0x%08x id=0x%04x wdata=0x%08x",
                            dut_type, dut_pc, dut_id[13:0], dut_wdata);
                    $display("  ctx : s0_pc=0x%08x s1_pc=0x%08x  (this cycle dual-slot ctx)",
                            s0_pc, s1_pc);
                    fail = 1'b1;
                end else begin
                    if (csr_wdata_dontcare(dut_type, dut_pc, dut_wdata)) begin
                        $display("[TRACE] IGNORE uninit-CSR wdata slot%0d type=%0d PC=0x%08x id=0x%04x",
                                dut_slot, dut_type, dut_pc, dut_id[13:0]);
                    end
                    cmp_count = cmp_count + 32'd1;
                end
            end
        end
    endtask

    reg [31:0] unstable_gpr;    
    reg [4:0]  skip_rd;
    reg [31:0] skip_inst;
    reg [4:0]  skip_rj;
    reg [4:0]  skip_rk;
    reg        skip_this;

    reg local_fail;
    reg [31:0] n_cmp;

    always @(posedge clk) begin
        if (!resetn) begin
            err   <= 1'b0;
            pass  <= 1'b0;
            unstable_gpr <= 32'b0;
        end 
        else if (opened && !err && !pass && cycle_cmp_en) begin
            local_fail = 1'b0;
            n_cmp      = cmp_count;

            // ---- same-cycle order: slot0 -> slot1; CSR then GPR (match CEMU) ----
            if (s0_csr) begin
                compare_one(2'd2, s0_pc, s0_csr_num, s0_csr_wdata,
                            2'd0, 3'd1, local_fail);
            end
            if (!local_fail && s0_gpr) begin
                compare_one(2'd1, s0_pc, {9'b0, s0_rf_wnum}, s0_rf_wdata,
                            2'd0, 3'd0, local_fail);
            end
            if (!local_fail && s1_csr) begin
                compare_one(2'd2, s1_pc, s1_csr_num, s1_csr_wdata,
                            2'd1, 3'd1, local_fail);
            end
            if (!local_fail && s1_gpr) begin
                compare_one(2'd1, s1_pc, {9'b0, s1_rf_wnum}, s1_rf_wdata,
                            2'd1, 3'd0, local_fail);
            end

            if (local_fail) begin
                err <= 1'b1;
            end else if (cmp_count >= EXPECTED_EVENTS) begin
                pass <= 1'b1;
                $display("[TRACE] reached EXPECTED_EVENTS=%0d", EXPECTED_EVENTS);
            end
        end
    end

endmodule