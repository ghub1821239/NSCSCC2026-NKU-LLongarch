module core_top(
    input  wire        aclk,
    input  wire        aresetn,
    input  wire [ 7:0] intrpt,

    // AXI read address channel
    output wire [ 3:0] arid,
    output wire [31:0] araddr,
    output wire [ 7:0] arlen,
    output wire [ 2:0] arsize,
    output wire [ 1:0] arburst,
    output wire [ 1:0] arlock,
    output wire [ 3:0] arcache,
    output wire [ 2:0] arprot,
    output wire        arvalid,
    input  wire        arready,

    // AXI read data channel
    input  wire [ 3:0] rid,
    input  wire [31:0] rdata,
    input  wire [ 1:0] rresp,
    input  wire        rlast,
    input  wire        rvalid,
    output wire        rready,

    // AXI write address channel
    output wire [ 3:0] awid,
    output wire [31:0] awaddr,
    output wire [ 7:0] awlen,
    output wire [ 2:0] awsize,
    output wire [ 1:0] awburst,
    output wire [ 1:0] awlock,
    output wire [ 3:0] awcache,
    output wire [ 2:0] awprot,
    output wire        awvalid,
    input  wire        awready,

    // AXI write data channel
    output wire [ 3:0] wid,
    output wire [31:0] wdata,
    output wire [ 3:0] wstrb,
    output wire        wlast,
    output wire        wvalid,
    input  wire        wready,

    // AXI write response channel
    input  wire [ 3:0] bid,
    input  wire [ 1:0] bresp,
    input  wire        bvalid,
    output wire        bready,

    // debug control interface
    input  wire        break_point,
    input  wire        infor_flag,
    input  wire [ 4:0] reg_num,
    output wire        ws_valid,
    output wire [31:0] rf_rdata,

    // trace debug interface
    output wire [31:0] debug0_wb_pc,
    output wire [ 3:0] debug0_wb_rf_wen,
    output wire [ 4:0] debug0_wb_rf_wnum,
    output wire [31:0] debug0_wb_rf_wdata
);

// cpu inst sram
wire        cpu_inst_req;
wire        cpu_inst_wr;
wire [ 1:0] cpu_inst_size;
wire [ 3:0] cpu_inst_wstrb;
wire [31:0] cpu_inst_addr;
wire [31:0] cpu_inst_wdata;
wire        cpu_inst_addr_ok;
wire        cpu_inst_data_ok;
wire [31:0] cpu_inst_rdata;
wire        inst_uncache_valid;
wire        inst_uncache_wr;

// cpu data sram
wire        cpu_data_req;
wire        cpu_data_wr;
wire [ 1:0] cpu_data_size;
wire [ 3:0] cpu_data_wstrb;
wire [31:0] cpu_data_addr;
wire [31:0] cpu_data_wdata;
wire        cpu_data_addr_ok;
wire        cpu_data_data_ok;
wire [31:0] cpu_data_rdata;
wire        data_uncache_valid;
wire        data_uncache_wr;

//Icache                                        ����(input)/ȥ����output)
wire            inst_valid;//����������Ч                                       CPU
wire            inst_op; // op��0����1д                                        CPU
wire [7 :0]     inst_index;// CPU ֱ�ӽ�ȡ��12��4(�϶����漰��ʵӳ��)     CPU
wire [19:0]     inst_tag;  // CPU�����õ�paddr    (��ʵӳ��)              CPU
wire [3 :0]     inst_offset;// CPU ֱ�ӽ�ȡ��3:0 (�϶����漰��ʵӳ��)     CPU
wire [3 :0]     inst_wstrb;//                                            CPU
wire [31:0]     inst_wdata;//                                            CPU
wire            inst_addr_ok;//���յ�ת���ŵ� ��/д �� addrok ��CPU               CPU��O��                                   
wire            inst_rd_rdy;   // arready                                      ת����
wire  [31:0]    inst_rd_addr; // CPU����paddr VA ��ƴ��һ��             ת���ţ�O��
wire            inst_data_ok;//���߷��ص�                                       CPU��O��
wire  [31:0]    inst_rdata;// ���߶�����������                           CPU��O��
wire            inst_rd_req;// CPU �Ķ�����                                     ת���ţ�O��
wire  [2 :0]    inst_rd_type; // �����ߵ�sizeֱ�ӽ�                      ���ߣ�rsize 010   arlen 8'd3 ��O��       
wire            inst_ret_valid;// ���߷��ص�������Ч��                           ���ߣ�rvalid
wire  [0:0]     inst_ret_last;// ���߷��ؽ�����                                 ����: last
wire  [31:0]    inst_ret_data;// ���߸��Ķ����� rdata                    CPU
wire            inst_wr_req;//CPU�����                                        ���ߣ�O��
wire  [2 :0]    inst_wr_type;//                                        ���ߣ�O��
wire  [31:0]    inst_wr_addr;//                                        ���ߣ�O��
wire  [3 :0]    inst_wr_wstrb;//                                       ���ߣ�O��
wire  [127:0]   inst_wr_wdata;//                                        ���ߣ�O��
wire            inst_wr_rdy;// 
wire            inst_cacop_done;

//Dcache                                        ����(input)/ȥ����output)
wire            data_valid;//����������Ч                                       CPU
wire            data_op; // op��0����1д                                        CPU
wire [7 :0]     data_index;// CPU ֱ�ӽ�ȡ��12��4(�϶����漰��ʵӳ��)     CPU
wire [19:0]     data_tag;  // CPU�����õ�paddr    (��ʵӳ��)              CPU
wire [3 :0]     data_offset;// CPU ֱ�ӽ�ȡ��3:0 (�϶����漰��ʵӳ��)     CPU
wire [3 :0]     data_wstrb;//                                            CPU
wire [31:0]     data_wdata;//                                            CPU
wire            data_addr_ok;//���յ�ת���ŵ� ��/д �� addrok ��CPU               CPU��O��                                   
wire            data_rd_rdy;   // arready                                      ת����
wire  [31:0]    data_rd_addr; // CPU����paddr VA ��ƴ��һ��             ת���ţ�O��
wire            data_data_ok;//���߷��ص�                                       CPU��O��
wire  [31:0]    data_rdata;// ���߶�����������                           CPU��O��
wire            data_rd_req;// CPU �Ķ�����                                     ת���ţ�O��
wire  [2 :0]    data_rd_type; // �����ߵ�sizeֱ�ӽ�                      ���ߣ�rsize 010   arlen 8'd3 ��O��       
wire            data_ret_valid;// ���߷��ص�������Ч��                           ���ߣ�rvalid
wire  [0:0]     data_ret_last;// ���߷��ؽ�����                                 ����: last
wire  [31:0]    data_ret_data;// ���߸��Ķ����� rdata                    CPU
wire            data_wr_req;//CPU�����                                        ���ߣ�O��
wire  [2 :0]    data_wr_type;//                                        ���ߣ�O��
wire  [31:0]    data_wr_addr;//                                        ���ߣ�O��
wire  [3 :0]    data_wr_wstrb;//                                       ���ߣ�O��
wire  [127:0]   data_wr_wdata;//                                        ���ߣ�O��
wire            data_wr_rdy;// 
wire            data_cacop_done;

wire  [7:0]     inst_arlen;
wire  [7:0]     data_arlen;
wire  [7:0]     inst_awlen;
wire  [7:0]     data_awlen;

//cacop
wire            cacop_valid;
wire  [4:0]     cache_code;
wire            cacop_done;

assign cacop_done = inst_cacop_done | data_cacop_done;

mycpu_core u_mycpu_core(
    .clk                (aclk   ),
    .resetn             (aresetn),

    .inst_sram_req      (cpu_inst_req    ),
    .inst_sram_wr       (cpu_inst_wr     ),
    .inst_sram_size     (cpu_inst_size   ),
    .inst_sram_wstrb    (cpu_inst_wstrb  ),
    .inst_sram_addr     (cpu_inst_addr   ),
    .inst_sram_wdata    (cpu_inst_wdata  ),
    .inst_sram_addr_ok  (cpu_inst_addr_ok),
    .inst_sram_data_ok  (cpu_inst_data_ok),
    .inst_sram_rdata    (cpu_inst_rdata  ),
    .inst_uncache_valid (inst_uncache_valid),
    .inst_uncache_wr    (inst_uncache_wr),

    .data_sram_req      (cpu_data_req    ),
    .data_sram_wr       (cpu_data_wr     ),
    .data_sram_size     (cpu_data_size   ),
    .data_sram_wstrb    (cpu_data_wstrb  ),
    .data_sram_addr     (cpu_data_addr   ),
    .data_sram_wdata    (cpu_data_wdata  ),
    .data_sram_addr_ok  (cpu_data_addr_ok),
    .data_sram_data_ok  (cpu_data_data_ok),
    .data_sram_rdata    (cpu_data_rdata  ),
    .data_uncache_valid (data_uncache_valid),
    .data_uncache_wr    (data_uncache_wr),
    
    //cache_cacop
    .cacop_valid        (cacop_valid),
    .cache_code         (cache_code),
    .cacop_done         (cacop_done),

    .debug_wb_pc        (debug0_wb_pc      ),
    .debug_wb_rf_we     (debug0_wb_rf_wen  ),
    .debug_wb_rf_wnum   (debug0_wb_rf_wnum ),
    .debug_wb_rf_wdata  (debug0_wb_rf_wdata)
);

bridge_SRAM_AXI u_bridge_SRAM_AXI(
    .clk               (aclk             ),
    .resetn            (aresetn          ),

    // inst cache interface
    .inst_rd_req       (inst_rd_req      ),
    .inst_rd_type      (inst_rd_type     ),
    .inst_rd_addr      (inst_rd_addr     ),
    .inst_rd_rdy       (inst_rd_rdy      ),
    .inst_ret_valid    (inst_ret_valid   ),
    .inst_ret_last     (inst_ret_last    ),
    .inst_ret_data     (inst_ret_data    ),
    .inst_wr_req       (inst_wr_req      ),
    .inst_wr_type      (inst_wr_type     ),
    .inst_wr_addr      (inst_wr_addr     ),
    .inst_wr_wstrb     (inst_wr_wstrb    ),
    .inst_wr_wdata     (inst_wr_wdata    ),
    .inst_wr_rdy       (inst_wr_rdy      ),

    // data cache interface
    .data_rd_req       (data_rd_req      ),
    .data_rd_type      (data_rd_type     ),
    .data_rd_addr      (data_rd_addr     ),
    .data_rd_rdy       (data_rd_rdy      ),
    .data_ret_valid    (data_ret_valid   ),
    .data_ret_last     (data_ret_last    ),
    .data_ret_data     (data_ret_data    ),
    .data_wr_req       (data_wr_req      ),
    .data_wr_type      (data_wr_type     ),
    .data_wr_addr      (data_wr_addr     ),
    .data_wr_wstrb     (data_wr_wstrb    ),
    .data_wr_wdata     (data_wr_wdata     ),
    .data_wr_rdy       (data_wr_rdy      ),

    .arid              (arid             ),
    .araddr            (araddr           ),
    .arlen             (arlen            ),
    .arsize            (arsize           ),
    .arburst           (arburst          ),
    .arlock            (arlock           ),
    .arcache           (arcache          ),
    .arprot            (arprot           ),
    .arvalid           (arvalid          ),
    .arready           (arready          ),

    .rid               (rid              ),
    .rdata             (rdata            ),
    .rresp             (rresp            ),
    .rlast             (rlast            ),
    .rvalid            (rvalid           ),
    .rready            (rready           ),

    .awid              (awid             ),
    .awaddr            (awaddr           ),
    .awlen             (awlen            ),
    .awsize            (awsize           ),
    .awburst           (awburst          ),
    .awlock            (awlock           ),
    .awcache           (awcache          ),
    .awprot            (awprot           ),
    .awvalid           (awvalid          ),
    .awready           (awready          ),

    .wid               (wid              ),
    .wdata             (wdata            ),
    .wstrb             (wstrb            ),
    .wlast             (wlast            ),
    .wvalid            (wvalid           ),
    .wready            (wready           ),

    .bid               (bid              ),
    .bresp             (bresp            ),
    .bvalid            (bvalid           ),
    .bready            (bready           ),
    
    .inst_arlen        (inst_arlen       ),
    .data_arlen        (data_arlen       ),
    .inst_awlen        (inst_awlen       ),
    .data_awlen        (data_awlen       )
);

//icache����:cpu----icache
assign inst_valid           = cpu_inst_req;
assign inst_op              = cpu_inst_wr;
assign inst_index           = cpu_inst_addr[11:4];
assign inst_tag             = cpu_inst_addr[31:12];
assign inst_offset          = cpu_inst_addr[3:0];
assign inst_wstrb           = cpu_inst_wstrb;
assign inst_wdata           = cpu_inst_wdata;
assign cpu_inst_addr_ok     = inst_addr_ok;
assign cpu_inst_data_ok     = inst_data_ok;
assign cpu_inst_rdata       = inst_rdata;
//icache���ߣ�icache-----bridge


icache u_Icache (
    .clk        (aclk),
    .resetn     (aresetn  ),
//                                                                 ����(input)/ȥ����output)
    .valid      (inst_valid   ),//����������Ч                                       CPU
    .op         (inst_op      ), // op��0����1д                                        CPU
    .index      (inst_index   ),// CPU ֱ�ӽ�ȡ��12��4(�϶����漰��ʵӳ��)     CPU
    .tag        (inst_tag     ),  // CPU�����õ�paddr    (��ʵӳ��)              CPU
    .offset     (inst_offset  ),// CPU ֱ�ӽ�ȡ��3:0 (�϶����漰��ʵӳ��)     CPU
    .wstrb      (inst_wstrb   ),//                                            CPU
    .wdata      (inst_wdata   ),//                                            CPU

    .addr_ok    (inst_addr_ok ),//���յ�ת���ŵ� ��/д �� addrok ��CPU               CPU��O��                                   
    .rd_rdy     (inst_rd_rdy  ),   // arready                                      ת����
    .rd_addr    (inst_rd_addr ), // CPU����paddr VA ��ƴ��һ��             ת���ţ�O��

    .data_ok    (inst_data_ok  ),//���߷��ص�                                       CPU��O��
    .rdata      (inst_rdata    ),// ���߶�����������                           CPU��O��
    .rd_req     (inst_rd_req   ),// CPU �Ķ�����                                     ת���ţ�O��
    .rd_type    (inst_rd_type  ), // �����ߵ�sizeֱ�ӽ�                      ���ߣ�rsize 010   arlen 8'd3 ��O��       
    .ret_valid  (inst_ret_valid),// ���߷��ص�������Ч��                           ���ߣ�rvalid
    .ret_last   (inst_ret_last ), // ���߷��ؽ�����                                 ����: last
    .ret_data   (inst_ret_data ),// ���߸��Ķ����� rdata                    CPU

    .wr_req     (inst_wr_req  ),//CPU�����                                        ���ߣ�O��
    .wr_type    (inst_wr_type ),//                                        ���ߣ�O��
    .wr_addr    (inst_wr_addr ),//                                        ���ߣ�O��
    .wr_wstrb   (inst_wr_wstrb),//                                       ���ߣ�O��
    .wr_data    (inst_wr_wdata),//                                        ���ߣ�O��
    .wr_rdy     (inst_wr_rdy  ),// 
    
    .uncache_valid   (inst_uncache_valid),
    .uncache_wr      (inst_uncache_wr   ),
    .ar_len          (inst_arlen),
    .aw_len          (inst_awlen),
    //cacop
    .cacop_valid     (cacop_valid),
    .cache_code      (cache_code),

    .cacop_done      (inst_cacop_done)
);

//Dcache ����
assign data_valid           = cpu_data_req;
assign data_op              = cpu_data_wr;
assign data_index           = cpu_data_addr[11:4];
assign data_tag             = cpu_data_addr[31:12];
assign data_offset          = cpu_data_addr[3:0];
assign data_wstrb           = cpu_data_wstrb;
assign data_wdata           = cpu_data_wdata;
assign cpu_data_addr_ok     = data_addr_ok;
assign cpu_data_data_ok     = data_data_ok;
assign cpu_data_rdata       = data_rdata;

cache #(
    .code2_0(3'b001)
)   u_Dcache(
    .clk        (aclk),
    .resetn     (aresetn  ),
//                                                                 ����(input)/ȥ����output)
    .valid      (data_valid   ),//����������Ч                                       CPU
    .op         (data_op      ), // op��0����1д                                        CPU
    .index      (data_index   ),// CPU ֱ�ӽ�ȡ��12��4(�϶����漰��ʵӳ��)     CPU
    .tag        (data_tag     ),  // CPU�����õ�paddr    (��ʵӳ��)              CPU
    .offset     (data_offset  ),// CPU ֱ�ӽ�ȡ��3:0 (�϶����漰��ʵӳ��)     CPU
    .wstrb      (data_wstrb   ),//                                            CPU
    .wdata      (data_wdata   ),//                                            CPU

    .addr_ok    (data_addr_ok ),//���յ�ת���ŵ� ��/д �� addrok ��CPU               CPU��O��                                   
    .rd_rdy     (data_rd_rdy  ),   // arready                                      ת����
    .rd_addr    (data_rd_addr ), // CPU����paddr VA ��ƴ��һ��             ת���ţ�O��

    .data_ok    (data_data_ok  ),//���߷��ص�                                       CPU��O��
    .rdata      (data_rdata    ),// ���߶�����������                           CPU��O��
    .rd_req     (data_rd_req   ),// CPU �Ķ�����                                     ת���ţ�O��
    .rd_type    (data_rd_type  ), // �����ߵ�sizeֱ�ӽ�                      ���ߣ�rsize 010   arlen 8'd3 ��O��       
    .ret_valid  (data_ret_valid),// ���߷��ص�������Ч��                           ���ߣ�rvalid
    .ret_last   (data_ret_last ), // ���߷��ؽ�����                                 ����: last
    .ret_data   (data_ret_data ),// ���߸��Ķ����� rdata                    CPU

    .wr_req     (data_wr_req  ),//CPU�����                                        ���ߣ�O��
    .wr_type    (data_wr_type ),//                                        ���ߣ�O��
    .wr_addr    (data_wr_addr ),//                                        ���ߣ�O��
    .wr_wstrb   (data_wr_wstrb),//                                       ���ߣ�O��
    .wr_data    (data_wr_wdata),//                                        ���ߣ�O��
    .wr_rdy     (data_wr_rdy  ),// 
    
    .uncache_valid  (data_uncache_valid),
    .uncache_wr     (data_uncache_wr   ),
    .aw_len          (data_awlen),
    .ar_len          (data_arlen),
    //cacop
    .cacop_valid     (cacop_valid),
    .cache_code      (cache_code),

    .cacop_done      (data_cacop_done)
);
endmodule
