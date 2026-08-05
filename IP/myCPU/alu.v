module alu(
  input  wire clk,
  input  wire resetn,
  input  wire EXE1_valid,
  input  wire EXE1_need_cancel,
  input  wire [18:0] alu_op,
  input  wire [31:0] alu_src1,
  input  wire [31:0] alu_src2,
  output wire [31:0] alu_result,
  output wire [31:0] add_result,
  output wire  divide_ready_go
);

wire op_add;   //add operation
wire op_sub;   //sub operation
wire op_slt;   //signed compared and set less than
wire op_sltu;  //unsigned compared and set less than
wire op_and;   //bitwise and
wire op_nor;   //bitwise nor
wire op_or;    //bitwise or
wire op_xor;   //bitwise xor
wire op_sll;   //logic left shift
wire op_srl;   //logic right shift
wire op_sra;   //arithmetic right shift
wire op_lui;   //Load Upper Immediate
wire op_mul;   //Multiply 
wire op_mulh;
wire op_mulh_wu;
wire op_div;   //division
wire op_mod;
wire op_modu;
wire op_divu;


// control code decomposition
assign op_add  = alu_op[ 0];
assign op_sub  = alu_op[ 1];
assign op_slt  = alu_op[ 2];
assign op_sltu = alu_op[ 3];
assign op_and  = alu_op[ 4];
assign op_nor  = alu_op[ 5];
assign op_or   = alu_op[ 6];
assign op_xor  = alu_op[ 7];
assign op_sll  = alu_op[ 8];
assign op_srl  = alu_op[ 9];
assign op_sra  = alu_op[10];
assign op_lui  = alu_op[11];
assign op_mul  = alu_op[12];
assign op_mulh = alu_op[13];
assign op_mulh_wu = alu_op[14];
assign op_div  = alu_op[15];
assign op_mod  = alu_op[16];
assign op_divu = alu_op[17];
assign op_modu = alu_op[18];

wire [31:0] add_sub_result;
wire [31:0] slt_result;
wire [31:0] sltu_result;
wire [31:0] and_result;
wire [31:0] nor_result;
wire [31:0] or_result;
wire [31:0] xor_result;
wire [31:0] lui_result;
wire [31:0] sll_result;
wire [63:0] sr64_result;
wire [31:0] sr_result;
wire [65:0] mul_result;
wire [32:0] mul_src1 = op_mulh_wu ? {1'b0,alu_src1} : {alu_src1[31],alu_src1};
wire [32:0] mul_src2 = op_mulh_wu ? {1'b0,alu_src2} : {alu_src2[31],alu_src2};
wire [63:0] div_result;
wire [63:0] div_result_u;

// 32-bit adder
wire [31:0] adder_a;
wire [31:0] adder_b;
wire        adder_cin;
wire [31:0] adder_result;
wire        adder_cout;

assign adder_a   = alu_src1;
assign adder_b   = (op_sub | op_slt | op_sltu) ? ~alu_src2 : alu_src2;  //src1 - src2 rj-rk
assign adder_cin = (op_sub | op_slt | op_sltu) ? 1'b1      : 1'b0;
assign {adder_cout, adder_result} = adder_a + adder_b + adder_cin;
assign add_result = adder_result;

// ADD, SUB result
assign add_sub_result = adder_result;

// SLT result
assign slt_result[31:1] = 31'b0;   //rj < rk 1
assign slt_result[0]    = (alu_src1[31] & ~alu_src2[31])
                        | ((alu_src1[31] ~^ alu_src2[31]) & adder_result[31]);

// SLTU result
assign sltu_result[31:1] = 31'b0;
assign sltu_result[0]    = ~adder_cout;

// bitwise operation
assign and_result = alu_src1 & alu_src2;
assign or_result  = alu_src1 | alu_src2;
assign nor_result = ~or_result;
assign xor_result = alu_src1 ^ alu_src2;
assign lui_result = alu_src2;

// SLL result
assign sll_result = alu_src1 << alu_src2[4:0];   //rj << i5

// SRL, SRA result
assign sr64_result = {{32{op_sra & alu_src1[31]}}, alu_src1[31:0]} >> alu_src2[4:0]; //rj >> i5

assign sr_result   = sr64_result[31:0];

assign mul_result =$signed(mul_src1)* $signed(mul_src2);

//divide
wire dividend_tready;
wire divisor_tready;
reg divisor_tvalid;
reg dividend_tvalid;
reg is_dividing;
wire div_ready_go;
wire divide_begin;
assign divide_begin= (op_div | op_mod) & EXE1_valid;
reg  kill;//�����flush����div��ָ����Ҫȡ������ķ���
always @(posedge clk) begin
    if (~resetn) begin
        kill <= 1'b0;
    end
    else if (div_ready_go) begin
        kill <= 1'b0;
    end
    else if (EXE1_need_cancel & divide_begin) begin
        kill <= 1'b1;
    end
end
always@(posedge clk)begin
    if(!resetn)begin
        divisor_tvalid  <=  1'b0;
        dividend_tvalid <=  1'b0;
        is_dividing     <=  1'b0;
    end
    else if (divide_begin & !is_dividing)begin
        divisor_tvalid  <=  1'b1;
        dividend_tvalid <=  1'b1;
        is_dividing     <=  1'b1;
   end
   else begin
        if( divisor_tvalid&divisor_tready)begin
            divisor_tvalid  <=  1'b0;
        end
        if( dividend_tvalid&dividend_tready)begin
            dividend_tvalid <=  1'b0;
        end
        if(div_ready_go)begin
            is_dividing<=1'b0;
        end
    end
end
divider u_divider(
    .aclk(clk),
    .s_axis_divisor_tvalid(divisor_tvalid),    // input wire s_axis_divisor_tvalid
    .s_axis_divisor_tready(divisor_tready),    // output wire s_axis_divisor_tready
    .s_axis_divisor_tdata(alu_src2),      // input wire [31 : 0] s_axis_divisor_tdata
    .s_axis_dividend_tvalid(dividend_tvalid),  // input wire s_axis_dividend_tvalid
    .s_axis_dividend_tready(dividend_tready),  // output wire s_axis_dividend_tready
    .s_axis_dividend_tdata(alu_src1),    // input wire [31 : 0] s_axis_dividend_tdata
    .m_axis_dout_tvalid(div_ready_go),          // output wire m_axis_dout_tvalid
    .m_axis_dout_tdata(div_result)            // output wire [63 : 0] m_axis_dout_tdata
);
//unsigned divider 
wire dividend_tready_u;
wire divisor_tready_u;
reg divisor_tvalid_u;
reg dividend_tvalid_u;
wire div_ready_go_u;
reg is_dividing_u;
wire divide_begin_u;
assign divide_begin_u= (op_divu | op_modu) & EXE1_valid;
reg  kill_u;//�����flush����div��ָ����Ҫȡ������ķ���
always @(posedge clk) begin
    if (~resetn) begin
        kill_u <= 1'b0;
    end
    else if (div_ready_go_u) begin
        kill_u <= 1'b0;
    end
    else if (EXE1_need_cancel & divide_begin_u) begin
        kill_u <= 1'b1;
    end
end
always@(posedge clk)begin
    if(!resetn)begin
        divisor_tvalid_u<=1'b0;
        dividend_tvalid_u<=1'b0;
        is_dividing_u<=1'b0;
    end
    else if (divide_begin_u & !is_dividing_u)begin
        divisor_tvalid_u    <=  EXE1_valid;
        dividend_tvalid_u   <=  EXE1_valid;
        is_dividing_u       <=  EXE1_valid;
   end
   else begin
        if( divisor_tvalid_u & divisor_tready_u)begin
            divisor_tvalid_u    <=  1'b0;
        end
        if( dividend_tvalid_u & dividend_tready_u)begin
            dividend_tvalid_u   <=  1'b0;
        end
        if(div_ready_go_u)begin
            is_dividing_u       <=  1'b0;
        end
    end
end
divider_unsigned u_divideru(
  .aclk(clk),                                      // input wire aclk
  .s_axis_divisor_tvalid(divisor_tvalid_u),    // input wire s_axis_divisor_tvalid
  .s_axis_divisor_tready(divisor_tready_u),    // output wire s_axis_divisor_tready
  .s_axis_divisor_tdata(alu_src2),      // input wire [31 : 0] s_axis_divisor_tdata
  .s_axis_dividend_tvalid(dividend_tvalid_u),  // input wire s_axis_dividend_tvalid
  .s_axis_dividend_tready(dividend_tready_u),  // output wire s_axis_dividend_tready
  .s_axis_dividend_tdata(alu_src1),    // input wire [31 : 0] s_axis_dividend_tdata
  .m_axis_dout_tvalid(div_ready_go_u),          // output wire m_axis_dout_tvalid
  .m_axis_dout_tdata(div_result_u)            // output wire [63 : 0] m_axis_dout_tdata
);
assign divide_ready_go = (div_ready_go & ~kill) | (div_ready_go_u & ~kill_u);
// final result mux
assign alu_result = ({32{op_add|op_sub}} & add_sub_result)
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
