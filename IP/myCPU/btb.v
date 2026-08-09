module btb (
    input  wire        clk,
    input  wire        resetn,

    //��ѯ�˿ڣ�preIFȡָʱ����BTB
    input  wire        query_valid0,
    input  wire [31:0] query_pc0,
    output wire        query_hit0,//valid��tagƥ��
    output wire [31:0] query_target0,
    output wire [ 1:0] query_type0,

    input  wire        query_valid1,
    input  wire [31:0] query_pc1,
    output wire        query_hit1,//valid��tagƥ��
    output wire [31:0] query_target1,
    output wire [ 1:0] query_type1,

    //���¶˿ڣ�Decodeȷ����ʵ������������BTB
    input  wire        update_valid,
    input  wire [31:0] update_pc,
    input  wire [31:0] update_target,//��ʵĿ���ַ
    input  wire [ 1:0] update_type,
    input  wire        update_cancel
);
//------------------------{reg ����������Ƶ}begin-------------------------//
reg        update_valid_r;
reg [31:0] update_pc_r;
reg [31:0] update_target_r;//��ʵĿ���ַ
reg [ 1:0] update_type_r;
always @(posedge clk) begin
    if (!resetn) begin
        update_valid_r  <= 1'b0;
        update_pc_r     <= 32'b0;
        update_target_r <= 32'b0;
        update_type_r   <= 2'b0;
    end
    else begin
        update_valid_r  <= update_cancel ? 1'b0 : update_valid;
        update_pc_r     <= update_pc;
        update_target_r <= update_target;
        update_type_r   <= update_type;
    end
end

//------------------------{reg ����������Ƶ}end-------------------------//

reg            btb_valid  [0:63];//64��1λ��Чλ
reg     [23:0] btb_tag    [0:63];//64��24λtag
reg     [31:0] btb_target [0:63];//64��32λ��תĿ���ַ
reg     [ 1:0] btb_type   [0:63];//64��2λ��֧����

wire    [ 5:0] query_index0;
wire    [ 5:0] query_index1;
wire    [ 5:0] update_index;
wire    [23:0] query_tag0;
wire    [23:0] query_tag1;
wire    [23:0] update_tag;

//pc��ֳ�tag+index+�ֽ�ƫ��
assign         query_index0  = query_pc0[7:2];
assign         query_tag0    = query_pc0[31:8];

assign         query_index1  = query_pc1[7:2];
assign         query_tag1    = query_pc1[31:8];

assign         update_index = update_pc_r[7:2];
assign         update_tag   = update_pc_r[31:8];

//�������ѯ��Ч&��ǰ����Ч&tagƥ��
assign         query_hit0    = query_valid0 & btb_valid[query_index0] &
                              (btb_tag[query_index0] == query_tag0);
assign         query_target0 = query_hit0 ? btb_target[query_index0] : 32'b0;
assign         query_type0   = query_hit0 ? btb_type[query_index0] : 2'b0;

assign         query_hit1    = query_valid1 & btb_valid[query_index1] &
                              (btb_tag[query_index1] == query_tag1);
assign         query_target1 = query_hit1 ? btb_target[query_index1] : 32'b0;
assign         query_type1   = query_hit1 ? btb_type[query_index1] : 2'b0;

//����
integer        i;
always @(posedge clk) begin
    if (!resetn) begin
        for (i = 0; i < 64; i = i + 1) begin
            btb_valid[i]             <= 1'b0;//��λʱ����valid��0
        end
    end
    else if (update_valid_r & ~update_cancel) begin//����ʱ��Ҫ���¾�д��
        btb_valid [update_index] <= 1'b1;
        btb_tag   [update_index] <= update_tag;
        btb_target[update_index] <= update_target_r;
        btb_type  [update_index] <= update_type_r;
    end
end

endmodule