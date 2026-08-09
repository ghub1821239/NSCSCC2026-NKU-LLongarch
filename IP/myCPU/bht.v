module bht(
    input              clk,
    input              resetn,
    //��ѯ�˿�
    input  wire        query_valid0,
    input  wire [31:0] query_pc0,//��ǰԤ���ָ��pc
    output wire        query_taken0,//Ԥ���Ƿ���ת

    input  wire        query_valid1,
    input  wire [31:0] query_pc1,//��ǰԤ���ָ��pc
    output wire        query_taken1,//Ԥ���Ƿ���ת
    //���¶˿�
    input  wire        update_valid,//�Ƿ�Ҫ���� BHT
    input  wire [31:0] update_pc,//��ָ֧���Լ��� PC
    input  wire        update_taken,//��ʵ�Ƿ���ת
    input  wire        update_cancel//���ȡ���Ͳ�ͬ������
);

//------------------------{reg ����������Ƶ}begin-------------------------//
reg        update_valid_r;
reg [31:0] update_pc_r;
reg        update_taken_r;
always @(posedge clk) begin
    if (!resetn) begin
        update_valid_r <= 1'b0;
        update_pc_r    <= 32'b0;
        update_taken_r <= 1'b0;
    end
    else begin
        update_valid_r <= update_cancel ? 1'b0 : update_valid;
        update_pc_r    <= update_pc;
        update_taken_r <= update_taken;
    end
end

//------------------------{reg ����������Ƶ}end-------------------------//

reg     [1:0] bht_counter [0:63];//BHT���飬64��2λ������

wire    [5:0] query_index0;
wire    [5:0] query_index1;
wire    [5:0] update_index;

assign        query_index0  = query_pc0[7:2];//BHT����
assign        query_index1  = query_pc1[7:2];//BHT����

assign        update_index = update_pc_r[7:2];
//���λ��1������ת
assign        query_taken0  = query_valid0 & bht_counter[query_index0][1];
assign        query_taken1  = query_valid1 & bht_counter[query_index1][1];

//��λѭ��
integer       i;

always @(posedge clk) begin
    if (!resetn) begin
        for (i = 0; i < 64; i = i + 1) begin
            bht_counter[i] <= 2'b01;//��ʼ��Ϊ01
        end
    end
    else if (update_valid_r & ~update_cancel) begin//û�и�λ���ұ����ڸ�����Чʱ�޸ļ�����
        if (update_taken_r) begin//��ʵ��תʱ�ĸ���
            if (bht_counter[update_index] != 2'b11)
                bht_counter[update_index]
                    <= bht_counter[update_index] + 2'b01;
        end
        else begin
            if (bht_counter[update_index] != 2'b00)//��ʵ����תʱ�ĸ���
                bht_counter[update_index]
                    <= bht_counter[update_index] - 2'b01;
        end
    end
end

endmodule