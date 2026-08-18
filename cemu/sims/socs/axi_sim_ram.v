module axi_sim_ram #(
    parameter MEM_BYTES = 1024*1024,
    parameter INIT_BIN  = "D:/chiplab/repository/NSCSCC2026-LLongarch/cemu/sims/bin/main.bin",
    parameter BASE_ADDR = 32'h1c00_0000
)(
    input  wire        aclk,
    input  wire        aresetn,
    input  wire [3:0]  s_arid,
    input  wire [31:0] s_araddr,
    input  wire [7:0]  s_arlen,
    input  wire [2:0]  s_arsize,
    input  wire [1:0]  s_arburst,
    input  wire        s_arvalid,
    output reg         s_arready,
    output reg  [3:0]  s_rid,
    output reg  [31:0] s_rdata,
    output wire [1:0]  s_rresp,
    output reg         s_rlast,
    output reg         s_rvalid,
    input  wire        s_rready,
    input  wire [3:0]  s_awid,
    input  wire [31:0] s_awaddr,
    input  wire [7:0]  s_awlen,
    input  wire [2:0]  s_awsize,
    input  wire [1:0]  s_awburst,
    input  wire        s_awvalid,
    output reg         s_awready,
    input  wire [3:0]  s_wid,
    input  wire [31:0] s_wdata,
    input  wire [3:0]  s_wstrb,
    input  wire        s_wlast,
    input  wire        s_wvalid,
    output reg         s_wready,
    output reg  [3:0]  s_bid,
    output wire [1:0]  s_bresp,
    output reg         s_bvalid,
    input  wire        s_bready
);
assign s_rresp = 2'b00;
assign s_bresp = 2'b00;

reg [7:0] mem [0:MEM_BYTES-1];
integer fd, i, n;

function automatic [31:0] map_addr(input [31:0] a);
    begin
        // 统一折到 1MB：与 CEMU 多镜像 alias 近似
        map_addr = {12'h0, a[19:0]};
    end
endfunction

initial begin
    for (i = 0; i < MEM_BYTES; i = i + 1) mem[i] = 8'h0;
    fd = $fopen(INIT_BIN, "rb");
    if (fd == 0) $display("[RAM] WARN: cannot open %s", INIT_BIN);
    else begin
        n = $fread(mem, fd);
        $display("[RAM] loaded %0d bytes from %s", n, INIT_BIN);
        $fclose(fd);
    end
end

// ---------------- READ ----------------
reg        r_busy;
reg [3:0]  r_id;
reg [31:0] r_addr;
reg [7:0]  r_left;
reg [2:0]  r_size;

always @(posedge aclk or negedge aresetn) begin
    if (!aresetn) begin
        s_arready <= 1'b1;
        s_rvalid  <= 1'b0;
        s_rlast   <= 1'b0;
        s_rid     <= 4'd0;
        s_rdata   <= 32'd0;
        r_busy    <= 1'b0;
        r_left    <= 8'd0;
        r_size    <= 3'd2;
        r_addr    <= 32'd0;
        r_id      <= 4'd0;
    end else begin
        // 1) 只在完全空闲时接 AR（rvalid 也必须为 0）
        if (s_arready && s_arvalid) begin
            s_arready <= 1'b0;
            r_busy    <= 1'b1;
            r_id      <= s_arid;
            r_addr    <= map_addr(s_araddr);
            r_left    <= s_arlen;   // AXI: beats = arlen+1
            r_size    <= s_arsize;
        end

        // 2) 有事务：先出拍，握手后再走下一拍；last 握手后才释放 AR
        if (r_busy) begin
            if (!s_rvalid) begin
                s_rid    <= r_id;
                s_rdata  <= {mem[r_addr+3], mem[r_addr+2], mem[r_addr+1], mem[r_addr]};
                s_rvalid <= 1'b1;
                s_rlast  <= (r_left == 8'd0);
            end else if (s_rready) begin
                if (s_rlast) begin
                    s_rvalid  <= 1'b0;
                    s_rlast   <= 1'b0;
                    r_busy    <= 1'b0;
                    s_arready <= 1'b1;
                end else begin
                    r_addr   <= r_addr + (32'd1 << r_size);
                    r_left   <= r_left - 8'd1;
                    s_rdata  <= {mem[r_addr+(32'd1<<r_size)+3],
                                 mem[r_addr+(32'd1<<r_size)+2],
                                 mem[r_addr+(32'd1<<r_size)+1],
                                 mem[r_addr+(32'd1<<r_size)]};
                    s_rlast  <= (r_left == 8'd1);
                end
            end
        end
    end
end

// ---------------- WRITE ----------------
reg        w_busy;
reg [3:0]  w_id;
reg [31:0] w_addr;
reg [2:0]  w_size;

always @(posedge aclk or negedge aresetn) begin
    if (!aresetn) begin
        s_awready <= 1'b1;
        s_wready  <= 1'b0;
        s_bvalid  <= 1'b0;
        s_bid     <= 4'd0;
        w_busy    <= 1'b0;
        w_addr    <= 32'd0;
        w_id      <= 4'd0;
        w_size    <= 3'd2;
    end else begin
        if (s_awready && s_awvalid && !w_busy && !s_bvalid) begin
            w_busy    <= 1'b1;
            w_id      <= s_awid;
            w_addr    <= map_addr(s_awaddr);
            w_size    <= s_awsize;
            s_awready <= 1'b0;
            s_wready  <= 1'b1;
        end

        if (w_busy && s_wready && s_wvalid) begin
            if (s_wstrb[0]) mem[w_addr+0] <= s_wdata[7:0];
            if (s_wstrb[1]) mem[w_addr+1] <= s_wdata[15:8];
            if (s_wstrb[2]) mem[w_addr+2] <= s_wdata[23:16];
            if (s_wstrb[3]) mem[w_addr+3] <= s_wdata[31:24];
            w_addr <= w_addr + (32'd1 << w_size);
            if (s_wlast) begin
                s_wready <= 1'b0;
                s_bvalid <= 1'b1;
                s_bid    <= w_id;
            end
        end

        if (s_bvalid && s_bready) begin
            s_bvalid  <= 1'b0;
            w_busy    <= 1'b0;
            s_awready <= 1'b1;
        end
    end
end
endmodule