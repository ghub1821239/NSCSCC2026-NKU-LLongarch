module bridge_SRAM_AXI(
    input  wire         clk,
    input  wire         resetn,

    // inst sram-like interface  [cache]
    input  wire         inst_rd_req,
    input  wire [ 2:0]  inst_rd_type,
    input  wire [31:0]  inst_rd_addr,
    output wire         inst_rd_rdy,
    output wire         inst_ret_valid,
    output wire         inst_ret_last,
    output wire [31:0]  inst_ret_data,
    input  wire         inst_wr_req,
    input  wire [ 2:0]  inst_wr_type,
    input  wire [31:0]  inst_wr_addr,
    input  wire [ 3:0]  inst_wr_wstrb,
    input  wire [127:0] inst_wr_wdata,
    output wire         inst_wr_rdy,

    // data sram-like interface
    input  wire         data_rd_req,
    input  wire [ 2:0]  data_rd_type,
    input  wire [31:0]  data_rd_addr,
    output wire         data_rd_rdy,
    output wire         data_ret_valid,
    output wire         data_ret_last,
    output wire [31:0]  data_ret_data,
    input  wire         data_wr_req,
    input  wire [ 2:0]  data_wr_type,
    input  wire [31:0]  data_wr_addr,
    input  wire [ 3:0]  data_wr_wstrb,
    input  wire [127:0] data_wr_wdata,
    output wire         data_wr_rdy,

    // AXI read address channel
    output wire [ 3:0]  arid,
    output wire [31:0]  araddr,
    output wire [ 7:0]  arlen,
    output wire [ 2:0]  arsize,
    output wire [ 1:0]  arburst,
    output wire [ 1:0]  arlock,
    output wire [ 3:0]  arcache,
    output wire [ 2:0]  arprot,
    output wire         arvalid,
    input  wire         arready,

    // AXI read data channel
    input  wire [ 3:0]  rid,
    input  wire [31:0]  rdata,
    input  wire [ 1:0]  rresp,
    input  wire         rlast,
    input  wire         rvalid,
    output wire         rready,

    // AXI write address channel
    output wire [ 3:0]  awid,
    output wire [31:0]  awaddr,
    output wire [ 7:0]  awlen,
    output wire [ 2:0]  awsize,
    output wire [ 1:0]  awburst,
    output wire [ 1:0]  awlock,
    output wire [ 3:0]  awcache,
    output wire [ 2:0]  awprot,
    output wire         awvalid,
    input  wire         awready,

    // AXI write data channel
    output wire [ 3:0]  wid,
    output wire [31:0]  wdata,
    output wire [ 3:0]  wstrb,
    output wire         wlast,
    output wire         wvalid,
    input  wire         wready,

    // AXI write response channel
    input  wire [ 3:0]  bid,
    input  wire [ 1:0]  bresp,
    input  wire         bvalid,
    output wire         bready,

    input  wire [ 7:0]  inst_arlen,
    input  wire [ 7:0]  data_arlen,
    input  wire [ 7:0]  inst_awlen,
    input  wire [ 7:0]  data_awlen
);

localparam  [3:0] AXI_ID_INST = 4'd0;
localparam  [3:0] AXI_ID_DATA = 4'd1;

//----------------------------- 读写req赋值 begin -------------------------------

//表示是否已经成功读握手，如果成功就把对应的req拉低
reg     inst_rd_req_and_addrok;
reg     data_rd_req_and_addrok;

wire    inst_read_data_ok;
wire    data_read_data_ok;
wire    read_data_ok;
wire    inst_read_req_addr_ok;
wire    data_read_req_addr_ok;
wire    inst_read_req_accept;
wire    data_read_req_accept;
assign  read_data_ok           = rvalid & rready;
assign  inst_read_data_ok      = read_data_ok & (rid == AXI_ID_INST);
assign  data_read_data_ok      = read_data_ok & (rid == AXI_ID_DATA);

always @(posedge clk) begin
    if (!resetn) begin
        inst_rd_req_and_addrok <= 1'b0;
        data_rd_req_and_addrok <= 1'b0;
    end
    else begin
        if (inst_read_data_ok & rlast) begin
            inst_rd_req_and_addrok <= 1'b0;
        end
        if (data_read_data_ok & rlast) begin
            data_rd_req_and_addrok <= 1'b0;
        end
        if (inst_read_req_accept) begin
            inst_rd_req_and_addrok <= 1'b1;
        end
        if (data_read_req_accept) begin
            data_rd_req_and_addrok <= 1'b1;
        end
    end
end
// 读写请求
wire          inst_read_req;
wire          data_read_req;
wire          data_write_req;
wire          inst_read_can_req;
wire          data_read_can_req;
assign        inst_read_req                    = inst_rd_req;
assign        data_read_req                    = data_rd_req;
assign        data_write_req                   = data_wr_req;

//AXI要求发送arvalid之后arsize和araddr就不能变了,因此我们要存一下这个valid表示当前的是否能够改变(valid=1表示占用)
//也就是我们要把他给缓存下来
reg           read_req_is_buffering;
wire          read_can_get_new_req;//新的就是当前无缓存/成功握手
wire          read_req_addr_ok;
assign        read_can_get_new_req             = ~read_req_is_buffering | read_req_addr_ok;
// 判定当前读请求缓存是否来自于data_ram
reg           read_req_buffer_from_dataRAM;
wire          new_read_req_buffer_from_dataRAM;
assign        new_read_req_buffer_from_dataRAM = data_read_req_accept;
// 可以发送新请求 & 是读请求
wire          new_read_req_valid;
assign        data_read_req_accept             = read_can_get_new_req & data_read_can_req;
assign        inst_read_req_accept             = read_can_get_new_req & ~data_read_can_req & inst_read_can_req;
assign        new_read_req_valid               = data_read_req_accept | inst_read_req_accept;
// 缓存请求的addr和size
reg    [31:0] read_req_addr;
reg    [ 2:0] read_req_size;

// 只要发送请求 & 当前没有req&addrok & 没有读缓存来自 XX RAM
assign        inst_read_can_req                = inst_read_req & ~inst_rd_req_and_addrok & ~(read_req_is_buffering & ~read_req_buffer_from_dataRAM);
assign        data_read_can_req                = data_read_req & ~data_rd_req_and_addrok & ~(read_req_is_buffering &  read_req_buffer_from_dataRAM);

always @(posedge clk) begin
    if (!resetn) begin
        read_req_is_buffering        <= 1'b0;
        read_req_buffer_from_dataRAM <= 1'b0;
        read_req_addr                <= 32'b0;
        read_req_size                <= 3'b0;
    end
    else if (read_can_get_new_req) begin
        read_req_is_buffering        <= new_read_req_valid;
        if (new_read_req_valid) begin
            read_req_buffer_from_dataRAM <= new_read_req_buffer_from_dataRAM;
            read_req_addr                <= new_read_req_buffer_from_dataRAM ? data_rd_addr : inst_rd_addr;
            read_req_size                <= new_read_req_buffer_from_dataRAM ? data_rd_type : inst_rd_type;
        end
    end
end
//----------------------------- 读写req赋值 end -------------------------------

//----------------------------- 读事务addr相关 begin -------------------------------
wire    write_req_addr_ok;
wire    write_data_ok;

assign  read_req_addr_ok      = arvalid & arready;
assign  data_read_req_addr_ok = read_req_addr_ok &  read_req_buffer_from_dataRAM;
assign  inst_read_req_addr_ok = read_req_addr_ok & ~read_req_buffer_from_dataRAM;

// SRAM-like 的 addr_ok 表示 bridge 已经接收并缓存请求，而不是 AXI AR 已经握手。
// 这样请求被 flush 时，CPU 仍能知道 bridge 中存在一个必须等待/丢弃返回的事务。
//assign inst_rd_rdy = ~read_req_buffer_from_dataRAM & arready;
//assign data_rd_rdy = read_req_buffer_from_dataRAM & arready;
assign  inst_rd_rdy           = inst_read_req_accept;
assign  data_rd_rdy           = data_read_req_accept;
assign  data_sram_addr_ok     = data_read_req_accept | write_req_addr_ok;

assign  inst_sram_return_data = inst_read_data_ok;
assign  data_sram_return_data = data_read_data_ok | write_data_ok;
assign  inst_ret_valid        = rvalid & (rid == AXI_ID_INST);
assign  data_ret_valid        = rvalid & (rid == AXI_ID_DATA);
assign  inst_ret_last         = (inst_read_data_ok & rlast);
assign  data_ret_last         = (data_read_data_ok & rlast);
assign  data_sram_data_ok     = (data_read_data_ok ) | (write_data_ok );
assign  inst_ret_data         = inst_read_data_ok ? rdata : 32'b0;
assign  data_ret_data         = data_read_data_ok ? rdata : 32'b0;
//----------------------------- 读事务addr相关 end -------------------------------

//----------------------------- 读请求通道赋值 begin -------------------------------
assign  arid    = read_req_buffer_from_dataRAM ? AXI_ID_DATA : AXI_ID_INST;
assign  araddr  = read_req_addr;
assign  arlen   = read_req_buffer_from_dataRAM ? data_arlen : inst_arlen;
assign  arsize  = read_req_size;
assign  arburst = 2'b01;
assign  arlock  = 2'b00;
assign  arcache = 4'b0000;
assign  arprot  = 3'b000;
assign  arvalid = read_req_is_buffering;
//----------------------------- 读请求通道赋值 end -------------------------------

//----------------------------- 读响应通道赋值 begin -------------------------------
assign  rready      = inst_rd_req_and_addrok | data_rd_req_and_addrok;
assign  inst_wr_rdy = 1'b1;
//----------------------------- 读响应通道赋值 end -------------------------------

//----------------------------- 写事务状态机 begin -------------------------------
reg       aw_done;//写请求
reg       w_done;//写数据
reg       wr_wait_b;//已经完成写请求和写数据,正在等待写返回
// 【Note】 因为cache 保证了进入refill的时候等到wr_rdy才会更改状态，所以不用reg寄存 
reg [1:0] dirty_wb_r;
always @(posedge clk) begin
    if (!resetn) begin
        wr_wait_b  <= 1'b0;
        aw_done    <= 1'b0;
        w_done     <= 1'b0;
        dirty_wb_r <= 2'b0;
    end
    else begin
        // 等待bvalid & bready握手
        if (write_data_ok) begin
             wr_wait_b  <= 1'b0;
            aw_done    <= 1'b0;
            w_done     <= 1'b0;
            dirty_wb_r <= 2'd0;
        end
        else if (write_req_addr_ok) begin
            // 等待写回握手
            wr_wait_b  <= 1'b1;
            aw_done    <= 1'b0;
            w_done     <= 1'b0;
            dirty_wb_r <= 2'd0;
        end
        else if (!wr_wait_b) begin
            if (awvalid & awready) begin
                aw_done    <= 1'b1;
            end
            if (wvalid & wready) begin
                if (wlast) begin
                    w_done     <= 1'b1;
                    dirty_wb_r <= 2'd0;
                end
                else begin
                    dirty_wb_r <= dirty_wb_r + 2'd1;
                end
            end

        end
    end
end
//----------------------------- 写事务状态机 end -------------------------------

//----------------------------- 写请求通道赋值 begin -------------------------------
assign  awid    = AXI_ID_DATA;
assign  awaddr  = data_wr_addr;
assign  awlen   = data_write_req ? data_awlen : inst_awlen;
assign  awsize  = data_wr_type;
assign  awburst = 2'b01;
assign  awlock  = 2'b00;
assign  awcache = 4'b0000;
assign  awprot  = 3'b000;
assign  awvalid = data_write_req & ~wr_wait_b & ~aw_done;
//----------------------------- 写请求通道赋值 end -------------------------------

//----------------------------- 写数据赋值数据 begin -------------------------------
assign  wvalid = data_write_req & ~wr_wait_b & ~w_done;
assign  wid    = AXI_ID_DATA;
assign  wdata  = (dirty_wb_r == 2'd0) ? data_wr_wdata[31:0]   :
                 (dirty_wb_r == 2'd1) ? data_wr_wdata[63:32]  :
                 (dirty_wb_r == 2'd2) ? data_wr_wdata[95:64]  :
                 data_wr_wdata[127:96];
assign  wstrb  = data_wr_wstrb;
assign  wlast  = (dirty_wb_r == data_awlen[1:0]);
//----------------------------- 写数据赋值数据 end -------------------------------

//----------------------------- 写响应赋值数据 begin -------------------------------
assign  write_req_addr_ok = ~wr_wait_b &
                            (aw_done | (awvalid & awready)) &     
                            (w_done  | (wvalid  & wready & wlast ));
assign  data_wr_rdy       = write_req_addr_ok;
assign  bready            = wr_wait_b;
assign  write_data_ok     = bvalid & bready;
//----------------------------- 写响应赋值数据 end -------------------------------

endmodule
