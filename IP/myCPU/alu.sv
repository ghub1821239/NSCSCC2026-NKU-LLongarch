module alu(
  input  wire        clk,
  input  wire        resetn,
  input  wire        EXE1_ex,
  input  wire        ex_div_need_notice,
  input  wire        older_ex_for_exe1,
  input  wire        EXE1_slot_valid,
  input  wire        EXE1_need_cancel,
  input  wire [18:0] alu_op,
  input  wire [31:0] alu_src1,
  input  wire [31:0] alu_src2,
  output wire [31:0] alu_result,
  output wire [31:0] add_result,
  output wire        divide_ready_go
);

wire          op_add;   //add operation
wire          op_sub;   //sub operation
wire          op_slt;   //signed compared and set less than
wire          op_sltu;  //unsigned compared and set less than
wire          op_and;   //bitwise and
wire          op_nor;   //bitwise nor
wire          op_or;    //bitwise or
wire          op_xor;   //bitwise xor
wire          op_sll;   //logic left shift
wire          op_srl;   //logic right shift
wire          op_sra;   //arithmetic right shift
wire          op_lui;   //Load Upper Immediate
wire          op_mul;   //Multiply 
wire          op_mulh;
wire          op_mulh_wu;
wire          op_div;   //division
wire          op_mod;
wire          op_modu;
wire          op_divu;


// control code decomposition ― 整槽 valid 门控，泡槽/无效时所有 op（含 mul/div）都不拉起
wire   [18:0] alu_op_m                   = alu_op & {19{EXE1_slot_valid}};
assign        op_add                     = alu_op_m[ 0];
assign        op_sub                     = alu_op_m[ 1];
assign        op_slt                     = alu_op_m[ 2];
assign        op_sltu                    = alu_op_m[ 3];
assign        op_and                     = alu_op_m[ 4];
assign        op_nor                     = alu_op_m[ 5];
assign        op_or                      = alu_op_m[ 6];
assign        op_xor                     = alu_op_m[ 7];
assign        op_sll                     = alu_op_m[ 8];
assign        op_srl                     = alu_op_m[ 9];
assign        op_sra                     = alu_op_m[10];
assign        op_lui                     = alu_op_m[11];
assign        op_mul                     = alu_op_m[12];
assign        op_mulh                    = alu_op_m[13];
assign        op_mulh_wu                 = alu_op_m[14];
assign        op_div                     = alu_op_m[15];
assign        op_mod                     = alu_op_m[16];
assign        op_divu                    = alu_op_m[17];
assign        op_modu                    = alu_op_m[18];

wire   [31:0] add_sub_result;
wire   [31:0] slt_result;
wire   [31:0] sltu_result;
wire   [31:0] and_result;
wire   [31:0] nor_result;
wire   [31:0] or_result;
wire   [31:0] xor_result;
wire   [31:0] lui_result;
wire   [31:0] sll_result;
wire   [63:0] sr64_result;
wire   [31:0] sr_result;
wire   [65:0] mul_result;
// 无效槽的乘积不会被 alu_result 选中，扩展模式无需经过 EXE1_slot_valid 门控。
// 有效 mulh.wu 仍由 alu_op[14] 选择零扩展，同时切断 valid -> DSP 输入关键路径。
wire          mul_unsigned_mode          = alu_op[14];
wire   [32:0] mul_src1                   = mul_unsigned_mode ? {1'b0,alu_src1} : {alu_src1[31],alu_src1};
wire   [32:0] mul_src2                   = mul_unsigned_mode ? {1'b0,alu_src2} : {alu_src2[31],alu_src2};
wire   [63:0] div_result;
wire   [63:0] div_result_u;

// 32-bit adder
wire   [31:0] adder_a;
wire   [31:0] adder_b;
wire          adder_cin;
wire   [31:0] adder_result;
wire          adder_cout;

assign        adder_a                    = alu_src1;
assign        adder_b                    = (op_sub | op_slt | op_sltu) ? ~alu_src2 : alu_src2;  //src1 - src2 rj-rk
assign        adder_cin                  = (op_sub | op_slt | op_sltu) ? 1'b1      : 1'b0;
assign        {adder_cout, adder_result} = adder_a + adder_b + adder_cin;
assign        add_result                 = adder_result;

// ADD, SUB result
assign        add_sub_result             = adder_result;

// SLT result
assign        slt_result[31:1]           = 31'b0;   //rj < rk 1
assign        slt_result[0]              = (alu_src1[31] & ~alu_src2[31])
                                           | ((alu_src1[31] ~^ alu_src2[31]) & adder_result[31]);

// SLTU result
assign        sltu_result[31:1]          = 31'b0;
assign        sltu_result[0]             = ~adder_cout;

// bitwise operation
assign        and_result                 = alu_src1 & alu_src2;
assign        or_result                  = alu_src1 | alu_src2;
assign        nor_result                 = ~or_result;
assign        xor_result                 = alu_src1 ^ alu_src2;
assign        lui_result                 = alu_src2;

// SLL result
assign        sll_result                 = alu_src1 << alu_src2[4:0];   //rj << i5

// SRL, SRA result
assign        sr64_result                = {{32{op_sra & alu_src1[31]}}, alu_src1[31:0]} >> alu_src2[4:0]; //rj >> i5

assign        sr_result                  = sr64_result[31:0];

assign        mul_result                 = $signed(mul_src1)* $signed(mul_src2);

//divide
wire          dividend_tready;
wire          divisor_tready;
reg           divisor_tvalid;
reg           dividend_tvalid;
reg           is_dividing;
wire          div_ready_go;
wire          divide_begin;
assign        divide_begin               = (op_div | op_mod) & ~EXE1_need_cancel & ~ex_div_need_notice & ~older_ex_for_exe1 & ~is_dividing; // 已含 EXE1_valid（经 alu_op_m）
wire          div_calculating_cancel     = (EXE1_need_cancel | older_ex_for_exe1) & is_dividing;
wire          div_without_handshake      = dividend_tvalid & divisor_tvalid & ~dividend_tready & ~divisor_tready;
reg           kill;//如果有flush掉的div等指令需要取消错误的返回
reg    [31:0] dividend_tdata_r;
reg    [31:0] divisor_tdata_r;

always @(posedge clk) begin
    if (!resetn) begin
        dividend_tvalid  <= 1'b0;
        divisor_tvalid   <= 1'b0;
        is_dividing      <= 1'b0;
        kill             <= 1'b0;
        dividend_tdata_r <= 32'b0;
        divisor_tdata_r  <= 32'b0;
    end
    else if (divide_begin) begin
        dividend_tvalid  <= 1'b1;
        divisor_tvalid   <= 1'b1;
        is_dividing      <= 1'b1;
        kill             <= 1'b0;
        dividend_tdata_r <= alu_src1;
        divisor_tdata_r  <= alu_src2;
    end
    else if (div_calculating_cancel & ~kill) begin
        // 本拍完成握手的通道照常清掉
        if (dividend_tvalid & dividend_tready) 
            dividend_tvalid  <= 1'b0;
        if (divisor_tvalid  & divisor_tready ) 
            divisor_tvalid   <= 1'b0;
        if (div_ready_go) begin
            // cancel 和 response 同拍：直接丢弃并清 busy
            is_dividing      <= 1'b0;
        end
        else if (div_without_handshake) begin
            // 还没任何通道被接受：整笔撤销
            dividend_tvalid  <= 1'b0;
            divisor_tvalid   <= 1'b0;
            is_dividing      <= 1'b0;
        end
        else begin
            // 已部分/全部握手：标 stale，继续驱动剩余 tvalid 直到 response drain
            kill             <= 1'b1;
        end
    end
    else begin
        if (divisor_tvalid & divisor_tready)   
            divisor_tvalid   <= 1'b0;
        if (dividend_tvalid & dividend_tready) 
            dividend_tvalid  <= 1'b0;
        if (div_ready_go) begin
            is_dividing      <= 1'b0;
            kill             <= 1'b0;
        end
    end
end
divider u_divider(
    .aclk                   (clk              ),
    .s_axis_divisor_tvalid  (divisor_tvalid   ),    // input wire s_axis_divisor_tvalid
    .s_axis_divisor_tready  (divisor_tready   ),    // output wire s_axis_divisor_tready
    .s_axis_divisor_tdata   (divisor_tdata_r  ),      // input wire [31 : 0] s_axis_divisor_tdata
    .s_axis_dividend_tvalid (dividend_tvalid  ),  // input wire s_axis_dividend_tvalid
    .s_axis_dividend_tready (dividend_tready  ),  // output wire s_axis_dividend_tready
    .s_axis_dividend_tdata  (dividend_tdata_r ),    // input wire [31 : 0] s_axis_dividend_tdata
    .m_axis_dout_tvalid     (div_ready_go     ),          // output wire m_axis_dout_tvalid
    .m_axis_dout_tdata      (div_result       )            // output wire [63 : 0] m_axis_dout_tdata
);
//unsigned divider 
//unsigned divider
wire          dividend_tready_u;
wire          divisor_tready_u;
reg           divisor_tvalid_u;
reg           dividend_tvalid_u;
reg           is_dividing_u;
wire          div_ready_go_u;
wire          divide_begin_u;
assign        divide_begin_u           = (op_divu | op_modu) & ~EXE1_need_cancel & ~ex_div_need_notice & ~older_ex_for_exe1 & ~is_dividing_u; // 已含 EXE1_valid（经 alu_op_m）
wire          div_calculating_cancel_u = (EXE1_need_cancel | older_ex_for_exe1) & is_dividing_u;
wire          div_without_handshake_u  = dividend_tvalid_u & divisor_tvalid_u & ~dividend_tready_u & ~divisor_tready_u;
reg           kill_u;
reg    [31:0] dividend_tdata_u_r;
reg    [31:0] divisor_tdata_u_r;

always @(posedge clk) begin
    if (!resetn) begin
        dividend_tvalid_u  <= 1'b0;
        divisor_tvalid_u   <= 1'b0;
        is_dividing_u      <= 1'b0;
        kill_u             <= 1'b0;
        dividend_tdata_u_r <= 32'b0;
        divisor_tdata_u_r  <= 32'b0;
    end
    else if (divide_begin_u) begin
        dividend_tvalid_u  <= 1'b1;
        divisor_tvalid_u   <= 1'b1;
        is_dividing_u      <= 1'b1;
        kill_u             <= 1'b0;
        dividend_tdata_u_r <= alu_src1;
        divisor_tdata_u_r  <= alu_src2;
    end
    else if (div_calculating_cancel_u & ~kill_u) begin
        // 本拍完成握手的通道照常清掉
        if (dividend_tvalid_u & dividend_tready_u) dividend_tvalid_u <= 1'b0;
        if (divisor_tvalid_u  & divisor_tready_u ) divisor_tvalid_u  <= 1'b0;
        if (div_ready_go_u) begin
            // cancel 和 response 同拍：直接丢弃并清 busy
            is_dividing_u      <= 1'b0;
        end
        else if (div_without_handshake_u) begin
            // 还没任何通道被接受：整笔撤销
            dividend_tvalid_u  <= 1'b0;
            divisor_tvalid_u   <= 1'b0;
            is_dividing_u      <= 1'b0;
        end
        else begin
            // 已部分/全部握手：标 stale，继续驱动剩余 tvalid 直到 response drain
            kill_u             <= 1'b1;
        end
    end
    else begin
        if (divisor_tvalid_u & divisor_tready_u)   divisor_tvalid_u  <= 1'b0;
        if (dividend_tvalid_u & dividend_tready_u) dividend_tvalid_u <= 1'b0;
        if (div_ready_go_u) begin
            is_dividing_u      <= 1'b0;
            kill_u             <= 1'b0;
        end
    end
end

divider_unsigned u_divideru(
  .aclk                   (clk                ),                                      // input wire aclk
  .s_axis_divisor_tvalid  (divisor_tvalid_u   ),    // input wire s_axis_divisor_tvalid
  .s_axis_divisor_tready  (divisor_tready_u   ),    // output wire s_axis_divisor_tready
  .s_axis_divisor_tdata   (divisor_tdata_u_r  ),      // input wire [31 : 0] s_axis_divisor_tdata
  .s_axis_dividend_tvalid (dividend_tvalid_u  ),  // input wire s_axis_dividend_tvalid
  .s_axis_dividend_tready (dividend_tready_u  ),  // output wire s_axis_dividend_tready
  .s_axis_dividend_tdata  (dividend_tdata_u_r ),    // input wire [31 : 0] s_axis_dividend_tdata
  .m_axis_dout_tvalid     (div_ready_go_u     ),          // output wire m_axis_dout_tvalid
  .m_axis_dout_tdata      (div_result_u       )            // output wire [63 : 0] m_axis_dout_tdata
);



assign  divide_ready_go = (div_ready_go   & ~kill & ~div_calculating_cancel) |
                          (div_ready_go_u & ~kill_u & ~div_calculating_cancel_u);
// final result mux
assign  alu_result      = ({32{op_add|op_sub}} & add_sub_result)
                                     | ({32{op_slt       }} & slt_result)
                                     | ({32{op_sltu      }} & sltu_result)
                                     | ({32{op_and       }} & and_result)
                                     | ({32{op_nor       }} & nor_result)
                                     | ({32{op_or        }} & or_result)
                                     | ({32{op_xor       }} & xor_result)
                                     | ({32{op_lui       }} & lui_result)
                                     | ({32{op_sll       }} & sll_result)
                                     | ({32{op_srl|op_sra}} & sr_result)
                                     | ({32{op_mul       }} & mul_result[31: 0])
                                     | ({32{op_mulh      }} & mul_result[63:32])
                                     | ({32{op_mulh_wu   }} & mul_result[63:32])
                                     | ({32{op_div       }} & div_result[63:32])
                                     | ({32{op_mod       }} & div_result[31: 0])
                                     | ({32{op_divu      }} & div_result_u[63:32])
                                     | ({32{op_modu      }} & div_result_u[31: 0]);

endmodule
