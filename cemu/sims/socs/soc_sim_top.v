// soc_sim_top.v
// 轻量仿真 SoC：core_top + axi_sim_ram + confreg
// 地址：
//   0x1faf_xxxx / 0xbfaf_xxxx -> confreg
//   其它                         -> axi_sim_ram（内部再折到低 1MB）
module soc_sim_top #(
    parameter MEM_BYTES = 1024*1024,
    parameter INIT_BIN  = "D:/chiplab/repository/NSCSCC2026-LLongarch/cemu/sims/bin/main.bin"
)(
    input  wire        aclk,
    input  wire        aresetn,

    output wire [1:0]  debug_commit_valid,
    output wire [1:0]  debug_commit_exception,
    output wire [5:0]  debug_commit_ecode,
    output wire [8:0]  debug_commit_esubcode,
    output wire [63:0] debug_commit_pc,
    output wire [7:0]  debug_commit_rf_wen,
    output wire [9:0]  debug_commit_rf_wnum,
    output wire [63:0] debug_commit_rf_wdata,

    // slot0
    output wire        debug0_commit_valid,
    output wire [31:0] debug0_commit_pc,
    output wire        debug0_commit_rf_wen,
    output wire [4:0]  debug0_commit_rf_wnum,
    output wire [31:0] debug0_commit_rf_wdata,
    output wire        debug0_commit_csr_wen,
    output wire [13:0] debug0_commit_csr_num,
    output wire [31:0] debug0_commit_csr_wdata,
    //slot1
    output wire        debug1_commit_valid,
    output wire [31:0] debug1_commit_pc,
    output wire        debug1_commit_rf_wen,
    output wire [4:0]  debug1_commit_rf_wnum,
    output wire [31:0] debug1_commit_rf_wdata,
    output wire        debug1_commit_csr_wen,
    output wire [13:0] debug1_commit_csr_num,
    output wire [31:0] debug1_commit_csr_wdata
);

    // ---------------- CPU AXI master ----------------
    wire [3:0]  cpu_arid;
    wire [31:0] cpu_araddr;
    wire [7:0]  cpu_arlen;
    wire [2:0]  cpu_arsize;
    wire [1:0]  cpu_arburst;
    wire [1:0]  cpu_arlock;
    wire [3:0]  cpu_arcache;
    wire [2:0]  cpu_arprot;
    wire        cpu_arvalid;
    wire        cpu_arready;

    wire [3:0]  cpu_rid;
    wire [31:0] cpu_rdata;
    wire [1:0]  cpu_rresp;
    wire        cpu_rlast;
    wire        cpu_rvalid;
    wire        cpu_rready;

    wire [3:0]  cpu_awid;
    wire [31:0] cpu_awaddr;
    wire [7:0]  cpu_awlen;
    wire [2:0]  cpu_awsize;
    wire [1:0]  cpu_awburst;
    wire [1:0]  cpu_awlock;
    wire [3:0]  cpu_awcache;
    wire [2:0]  cpu_awprot;
    wire        cpu_awvalid;
    wire        cpu_awready;

    wire [3:0]  cpu_wid;
    wire [31:0] cpu_wdata;
    wire [3:0]  cpu_wstrb;
    wire        cpu_wlast;
    wire        cpu_wvalid;
    wire        cpu_wready;

    wire [3:0]  cpu_bid;
    wire [1:0]  cpu_bresp;
    wire        cpu_bvalid;
    wire        cpu_bready;

    // debug0（TB 暂不用，可悬空）
    wire [31:0] debug0_wb_pc;
    wire [3:0]  debug0_wb_rf_wen;
    wire [4:0]  debug0_wb_rf_wnum;
    wire [31:0] debug0_wb_rf_wdata;
    wire        ws_valid;
    wire [31:0] rf_rdata;

    core_top u_core (
        .aclk      (aclk),
        .aresetn   (aresetn),
        .intrpt    (8'd0),

        .arid      (cpu_arid),
        .araddr    (cpu_araddr),
        .arlen     (cpu_arlen),
        .arsize    (cpu_arsize),
        .arburst   (cpu_arburst),
        .arlock    (cpu_arlock),
        .arcache   (cpu_arcache),
        .arprot    (cpu_arprot),
        .arvalid   (cpu_arvalid),
        .arready   (cpu_arready),

        .rid       (cpu_rid),
        .rdata     (cpu_rdata),
        .rresp     (cpu_rresp),
        .rlast     (cpu_rlast),
        .rvalid    (cpu_rvalid),
        .rready    (cpu_rready),

        .awid      (cpu_awid),
        .awaddr    (cpu_awaddr),
        .awlen     (cpu_awlen),
        .awsize    (cpu_awsize),
        .awburst   (cpu_awburst),
        .awlock    (cpu_awlock),
        .awcache   (cpu_awcache),
        .awprot    (cpu_awprot),
        .awvalid   (cpu_awvalid),
        .awready   (cpu_awready),

        .wid       (cpu_wid),
        .wdata     (cpu_wdata),
        .wstrb     (cpu_wstrb),
        .wlast     (cpu_wlast),
        .wvalid    (cpu_wvalid),
        .wready    (cpu_wready),

        .bid       (cpu_bid),
        .bresp     (cpu_bresp),
        .bvalid    (cpu_bvalid),
        .bready    (cpu_bready),

        .break_point (1'b0),
        .infor_flag  (1'b0),
        .reg_num     (5'd0),
        .ws_valid    (ws_valid),
        .rf_rdata    (rf_rdata),

        .debug0_wb_pc       (debug0_wb_pc),
        .debug0_wb_rf_wen   (debug0_wb_rf_wen),
        .debug0_wb_rf_wnum  (debug0_wb_rf_wnum),
        .debug0_wb_rf_wdata (debug0_wb_rf_wdata),

        .debug_commit_valid     (debug_commit_valid),
        .debug_commit_exception (debug_commit_exception),
        .debug_commit_ecode     (debug_commit_ecode),
        .debug_commit_esubcode  (debug_commit_esubcode),
        .debug_commit_pc        (debug_commit_pc),
        .debug_commit_rf_wen    (debug_commit_rf_wen),
        .debug_commit_rf_wnum   (debug_commit_rf_wnum),
        .debug_commit_rf_wdata  (debug_commit_rf_wdata),

        .debug0_commit_valid    (debug0_commit_valid    ),
        .debug0_commit_pc       (debug0_commit_pc       ),
        .debug0_commit_rf_wen   (debug0_commit_rf_wen   ),
        .debug0_commit_rf_wnum  (debug0_commit_rf_wnum  ),
        .debug0_commit_rf_wdata (debug0_commit_rf_wdata ),
        .debug0_commit_csr_wen  (debug0_commit_csr_wen  ),
        .debug0_commit_csr_num  (debug0_commit_csr_num  ),
        .debug0_commit_csr_wdata(debug0_commit_csr_wdata),

        .debug1_commit_valid    (debug1_commit_valid    ),
        .debug1_commit_pc       (debug1_commit_pc       ),
        .debug1_commit_rf_wen   (debug1_commit_rf_wen   ),
        .debug1_commit_rf_wnum  (debug1_commit_rf_wnum  ),
        .debug1_commit_rf_wdata (debug1_commit_rf_wdata ),
        .debug1_commit_csr_wen  (debug1_commit_csr_wen  ),
        .debug1_commit_csr_num  (debug1_commit_csr_num  ),
        .debug1_commit_csr_wdata(debug1_commit_csr_wdata)
    );

    // ---------------- 地址译码 ----------------
    function automatic is_confreg;
        input [31:0] addr;
        begin
            is_confreg = (addr[31:16] == 16'h1faf) || (addr[31:16] == 16'hbfaf);
        end
    endfunction

    // sticky：一次事务锁到同一从设备
    reg r_sel_conf, r_busy;
    reg w_sel_conf, w_aw_done, w_busy;

    wire ar_is_conf = is_confreg(cpu_araddr);
    wire aw_is_conf = is_confreg(cpu_awaddr);

    // ---------------- RAM AXI ----------------
    wire        ram_arvalid = cpu_arvalid & ~ar_is_conf & (~r_busy | ~r_sel_conf);
    wire        ram_arready;
    wire [3:0]  ram_rid;
    wire [31:0] ram_rdata;
    wire [1:0]  ram_rresp;
    wire        ram_rlast;
    wire        ram_rvalid;
    wire        r_sel_now  = r_busy ? r_sel_conf : ar_is_conf;
    wire        ram_rready = cpu_rready & ~r_sel_now;

    wire        ram_awvalid = cpu_awvalid & ~aw_is_conf & (~w_busy | ~w_sel_conf);
    wire        ram_awready;
    wire        ram_wvalid  = cpu_wvalid & w_busy & ~w_sel_conf & w_aw_done;
    wire        ram_wready;
    wire [3:0]  ram_bid;
    wire [1:0]  ram_bresp;
    wire        ram_bvalid;
    wire        ram_bready  = cpu_bready & w_busy & ~w_sel_conf;

    axi_sim_ram #(
        .MEM_BYTES (MEM_BYTES),
        .INIT_BIN  (INIT_BIN)
    ) u_ram (
        .aclk      (aclk),
        .aresetn   (aresetn),
        .s_arid    (cpu_arid),
        .s_araddr  (cpu_araddr),
        .s_arlen   (cpu_arlen),
        .s_arsize  (cpu_arsize),
        .s_arburst (cpu_arburst),
        .s_arvalid (ram_arvalid),
        .s_arready (ram_arready),
        .s_rid     (ram_rid),
        .s_rdata   (ram_rdata),
        .s_rresp   (ram_rresp),
        .s_rlast   (ram_rlast),
        .s_rvalid  (ram_rvalid),
        .s_rready  (ram_rready),
        .s_awid    (cpu_awid),
        .s_awaddr  (cpu_awaddr),
        .s_awlen   (cpu_awlen),
        .s_awsize  (cpu_awsize),
        .s_awburst (cpu_awburst),
        .s_awvalid (ram_awvalid),
        .s_awready (ram_awready),
        .s_wid     (cpu_wid),
        .s_wdata   (cpu_wdata),
        .s_wstrb   (cpu_wstrb),
        .s_wlast   (cpu_wlast),
        .s_wvalid  (ram_wvalid),
        .s_wready  (ram_wready),
        .s_bid     (ram_bid),
        .s_bresp   (ram_bresp),
        .s_bvalid  (ram_bvalid),
        .s_bready  (ram_bready)
    );

    // ---------------- confreg AXI ----------------
    wire        conf_arvalid = cpu_arvalid &  ar_is_conf & (~r_busy |  r_sel_conf);
    wire        conf_arready;
    wire [3:0]  conf_rid;
    wire [31:0] conf_rdata;
    wire [1:0]  conf_rresp;
    wire        conf_rlast;
    wire        conf_rvalid;
    wire        conf_rready = cpu_rready & r_sel_now;

    wire        conf_awvalid = cpu_awvalid &  aw_is_conf & (~w_busy |  w_sel_conf);
    wire        conf_awready;
    wire        conf_wvalid  = cpu_wvalid & w_busy & w_sel_conf & w_aw_done;
    wire        conf_wready;
    wire [3:0]  conf_bid;
    wire [1:0]  conf_bresp;
    wire        conf_bvalid;
    wire        conf_bready  = cpu_bready & w_busy & w_sel_conf;

    wire [15:0] led;
    wire [1:0]  led_rg0, led_rg1;
    wire [7:0]  num_csn;
    wire [6:0]  num_a_g;
    wire [31:0] num_data;
    wire [3:0]  btn_key_col;
    wire [4:0]  ram_random_mask;

    confreg #(
        .SIMULATION(1'b1)
    ) u_confreg (
        .aclk        (aclk),
        .timer_clk   (aclk),
        .aresetn     (aresetn),
        .sys_resetn  (aresetn),

        .arid        (cpu_arid),
        .araddr      (cpu_araddr),
        .arlen       (cpu_arlen),
        .arsize      (cpu_arsize),
        .arburst     (cpu_arburst),
        .arlock      (cpu_arlock[0]),
        .arcache     (cpu_arcache),
        .arprot      (cpu_arprot),
        .arvalid     (conf_arvalid),
        .arready     (conf_arready),

        .rid         (conf_rid),
        .rdata       (conf_rdata),
        .rresp       (conf_rresp),
        .rlast       (conf_rlast),
        .rvalid      (conf_rvalid),
        .rready      (conf_rready),

        .awid        (cpu_awid),
        .awaddr      (cpu_awaddr),
        .awlen       (cpu_awlen),
        .awsize      (cpu_awsize),
        .awburst     (cpu_awburst),
        .awlock      (cpu_awlock[0]),
        .awcache     (cpu_awcache),
        .awprot      (cpu_awprot),
        .awvalid     (conf_awvalid),
        .awready     (conf_awready),

        // confreg 是 AXI4-like W（无 wid）
        .wdata       (cpu_wdata),
        .wstrb       (cpu_wstrb),
        .wlast       (cpu_wlast),
        .wvalid      (conf_wvalid),
        .wready      (conf_wready),

        .bid         (conf_bid),
        .bresp       (conf_bresp),
        .bvalid      (conf_bvalid),
        .bready      (conf_bready),

        .ram_random_mask (ram_random_mask),
        .led         (led),
        .led_rg0     (led_rg0),
        .led_rg1     (led_rg1),
        .num_csn     (num_csn),
        .num_a_g     (num_a_g),
        .num_data    (num_data),
        // 与 CEMU set_switch(0) 空闲态一致：sw_inter = 0xAAAA
        .switch      (8'hFF),
        .btn_key_col (btn_key_col),
        .btn_key_row (4'hF),
        .btn_step    (2'b00)
    );

    // ---------------- sticky + master mux ----------------
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            r_busy <= 1'b0;
            r_sel_conf <= 1'b0;
        end else begin
            if (!r_busy && cpu_arvalid && cpu_arready) begin
                r_busy <= 1'b1;
                r_sel_conf <= ar_is_conf;
            end else if (r_busy && cpu_rvalid && cpu_rready && cpu_rlast) begin
                r_busy <= 1'b0;
            end
        end
    end

    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            w_busy <= 1'b0;
            w_sel_conf <= 1'b0;
            w_aw_done <= 1'b0;
        end else begin
            if (!w_busy && cpu_awvalid && cpu_awready) begin
                w_busy <= 1'b1;
                w_sel_conf <= aw_is_conf;
                w_aw_done <= 1'b1;
            end else if (w_busy && cpu_bvalid && cpu_bready) begin
                w_busy <= 1'b0;
                w_aw_done <= 1'b0;
            end
        end
    end

    assign cpu_arready = r_busy ? 1'b0 :
                         (ar_is_conf ? conf_arready : ram_arready);

    assign cpu_rid     = r_sel_conf ? conf_rid   : ram_rid;
    assign cpu_rdata   = r_sel_conf ? conf_rdata : ram_rdata;
    assign cpu_rresp   = r_sel_conf ? conf_rresp : ram_rresp;
    assign cpu_rlast   = r_sel_conf ? conf_rlast : ram_rlast;
    assign cpu_rvalid  = r_sel_now ? conf_rvalid : ram_rvalid;

    assign cpu_awready = w_busy ? 1'b0 :
                         (aw_is_conf ? conf_awready : ram_awready);

    assign cpu_wready  = w_busy & w_aw_done &
                         (w_sel_conf ? conf_wready : ram_wready);

    assign cpu_bid     = w_sel_conf ? conf_bid   : ram_bid;
    assign cpu_bresp   = w_sel_conf ? conf_bresp : ram_bresp;
    assign cpu_bvalid  = w_busy & (w_sel_conf ? conf_bvalid : ram_bvalid);

endmodule