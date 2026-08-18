`timescale 1ns/1ps
// golden 格式：
//   1 <pc> <rd>       <wdata>
//   2 <pc> <csr_num>  <wdata>
module golden_trace_cmp #(
    parameter TRACE_FILE = "D:/chiplab/repository/NSCSCC2026-LLongarch/cemu/sims/trace/golden_trace.txt"
)(
    input  wire        clk,
    input  wire        resetn,
    input  wire        en,
    input  wire [1:0]  dut_type,    // 1=GPR, 2=CSR
    input  wire [31:0] dut_pc,
    input  wire [13:0] dut_id,
    input  wire [31:0] dut_wdata,
    output reg         match,       // 本拍比对成功（供 TB pop）
    output reg         err,
    output reg         eof_hit,
    output reg [31:0]  cmp_count
);

    integer fd;
    integer r;
    integer ref_type;
    reg [31:0] ref_pc;
    reg [31:0] ref_id;
    reg [31:0] ref_wdata;
    reg        opened;

    initial begin
        match     = 1'b0;
        err       = 1'b0;
        eof_hit   = 1'b0;
        cmp_count = 32'd0;
        opened    = 1'b0;
        fd = $fopen(TRACE_FILE, "r");
        if (fd == 0) begin
            $display("[TRACE] ERROR: cannot open %s", TRACE_FILE);
            err = 1'b1;
        end else begin
            opened = 1'b1;
            $display("[TRACE] open %s", TRACE_FILE);
        end
    end

    task automatic read_next_ref;
        begin
            ref_type = 0;
            while (opened && !eof_hit && (ref_type == 0)) begin
                r = $fscanf(fd, "%d %h %h %h", ref_type, ref_pc, ref_id, ref_wdata);
                if (r != 4) begin
                    eof_hit = 1'b1;
                    $display("[TRACE] EOF after %0d compares", cmp_count);
                end
            end
        end
    endtask

    always @(posedge clk) begin
    match <= 1'b0;
    if (!resetn) begin
        err <= 1'b0;
    end else if (en && opened && !err && !eof_hit) begin
        read_next_ref();
        if (!eof_hit) begin
            if (dut_type != ref_type[1:0] ||
                dut_pc !== ref_pc ||
                dut_wdata !== ref_wdata ||
                ((dut_type == 2'd1) && (dut_id[4:0]  !== ref_id[4:0])) ||
                ((dut_type == 2'd2) && (dut_id[13:0] !== ref_id[13:0])) ||
                ((dut_type != 2'd1) && (dut_type != 2'd2))) begin
                $display("[TRACE] MISMATCH at compare #%0d", cmp_count);
                $display("  ref : type=%0d PC=0x%08x id=0x%04x wdata=0x%08x",
                         ref_type, ref_pc, ref_id[13:0], ref_wdata);
                $display("  dut : type=%0d PC=0x%08x id=0x%04x wdata=0x%08x",
                         dut_type, dut_pc, dut_id[13:0], dut_wdata);
                err <= 1'b1;
            end else begin
                cmp_count <= cmp_count + 32'd1;
                match     <= 1'b1;
            end
        end
    end
end

endmodule