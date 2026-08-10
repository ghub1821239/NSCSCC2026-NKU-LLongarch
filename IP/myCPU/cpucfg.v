module cpucfg (
    input  wire [31:0] rj_value,
    output wire [31:0] cpucfg_value
);
//word0
wire [31:0]  word0_PRID             = 32'h14800100;
//word1
wire [1:0]   word1_ARCH             = 2'b00;//LA32精简架构
wire         word1_PGMMU            = 1'b1;//支持MMU页映射
wire         word1_IOCSR            = 1'b0;//支持IOCSR指令
wire [11:4]  word1_PALEN            = 8'd31;//物理地址PALEN=32
wire [19:12] word1_VALEN            = 8'd31;//虚拟地址VALEN=32
wire         word1_UAL              = 1'b0;//支持非对齐访存
wire         word1_RI               = 1'b0;//支持读禁止页属性
wire         word1_EP               = 1'b0;//支持执行保护页属性
wire         word1_RPLV             = 1'b0;//支持RPLV页属性
wire         word1_HP               = 1'b1;//支持huge page页属性
wire         word1_CRC              = 1'b0;//支持CSC校验指令
wire         word1_MSG_INT          = 1'b0;//支持外部中断采用消息中断方式
//word2
wire         word2_FP               = 1'b0;//支持浮点数
wire         word2_FP_SP            = 1'b0;//支持单精度浮点数
wire         word2_FP_DP            = 1'b0;//支持双精度浮点数
wire [5:3]   word2_FP_ver           = 2'b01;//浮点运算版本号
wire         word2_LSX              = 1'b0;//支持128位向量扩展
wire         word2_LASX             = 1'b0;//支持256位向量扩展
wire         word2_COMPLEX          = 1'b0;//支持复数向量运算
wire         word2_CRYPTO           = 1'b0;//支持加解密向量
wire         word2_LVZ              = 1'b0;//支持虚拟化扩展
wire [13:11] word2_LVZ_ver          = 3'b001;//虚拟化硬件加速规范版本号
wire         word2_LLFTP            = 1'b1;//支持恒定频率计时器和定时器
wire [17:15] word2_LLFTP_ver        = 3'b001;//恒定频率计时器和定时器版本号
wire         word2_LBT_X86          = 1'b0;//支持X86二进制翻译扩展
wire         word2_LBT_ARM          = 1'b0;//支持ARM二进制扩展
wire         word2_LBT_MIPS         = 1'b0;//支持MIPS二进制扩展
wire         word2_LSPW             = 1'b0;//支持软件页表遍历指令
wire         word2_LAM              = 1'b0;//支持AM原子指令    
wire         word2_HPTW             = 1'b0;//支持硬件页表遍历  
wire         word2_FRECIPE          = 1'b0;//支持向量扩展的4个指令
wire         word2_DIV32            = 1'b1;//64位机器上的div.w和mod.w仅根据低32位计算
wire         word2_LAM_BH           = 1'b0;//支持AW的8条指令
wire         word2_LAMCAS           = 1'b0;//支持AMCAS的8条指令
wire         word2_LLACQ_SCREL      = 1'b0;//支持LLACQ的4条指令
wire         word2_SCQ              = 1'b0;//支持SCQ指令
//word3
wire         word3_CCDMA            = 1'b0;//支持硬件DMA
wire         word3_SFB              = 1'b0;//支持Store Fill Buffer
wire         word3_UCACC            = 1'b0;//支持 ucacc win
wire         word3_LLEXC            = 1'b0;//支持 LL指令去独占块
wire         word3_SCDLY            = 1'b0;//支持 SC指令随机延迟
wire         word3_LLDBAR           = 1'b0;//支持LL指令自动带dbar
wire         word3_ITLBHMC          = 1'b0;//硬件维护ITLB和TLB一致性
wire         word3_ICHMC            = 1'b0;//硬件维护同一处理器内ICache和Dcache一致性
wire [10:8]  word3_SPW_LVL          = 3'b0;//page walk支持的最大目录层数
wire         word3_SPW_HP_HF        = 1'b0;//page walk遇到大页时将折半填入TLB
wire         word3_RVA              = 1'b0;//软件配置缩短虚拟地址范围的功能
wire [16:13] word3_RVAMAX_1         = 4'b0;//最大可以配置虚拟地址缩短位数-1
wire         word3_DBAR_hints       = 1'b0;//DBAR的非0值按手册推荐含义实现
wire         word3_LD_SEQ_SA        = 1'b0;//保证同地址load操作顺序执行
//word4
wire [31:0]  word4_CC_FREQ          = 32'd75;//恒定频率计时器和定时器的晶振频率
//word5
wire [15:0]  word5_CC_MUL           = 16'd1;//时钟的倍频因子
wire [31:16] word5_CC_DIV           = 16'd1;//时钟的分频系数
//word6
wire         word6_PMP              = 1'b0;//支持性能计数器
wire [3:1]   word6_PMVER            = 3'b1;//性能检测器中的版本号
wire [7:4]   word6_PMNUM            = 4'b0;//性能检测器个数-1
wire [13:8]  word6_PMBITS           = 6'd31;//性能检测器位宽-1
wire         word6_UPM              = 1'b0;//支持用户读取性能计数器
//word10
wire         word10_L1_IU_Present   = 1'b1;//存在1级指令Cache或统一Cache
wire         word10_L1_IU_Unify     = 1'b0;//1级指令Cache是统一Cache
wire         word10_L1_D_Present    = 1'b1;//存在1级数据Cache或统一Cache
wire         word10_L2_IU_Present   = 1'b0;//存在2级指令Cache或统一Cache
wire         word10_L2_IU_Unify     = 1'b0;//2级指令Cache是统一Cache  
wire         word10_L2_IU_Private   = 1'b0;//2级指令Cache是每个核私有的
wire         word10_L2_IU_Inclusive = 1'b0;// 2级指令Cache对更低层级是包含关系                  
wire         word10_L2_D_Present    = 1'b0;//存在2级数据Cache
wire         word10_L2_D_Private    = 1'b0;//2级数据Cache是每个核私有的
wire         word10_L2_D_Inclusive  = 1'b0;//2级数据Cache对更低层级是包含关系
wire         word10_L3_IU_Present   = 1'b0;//存在3级指令Cache或统一Cache
wire         word10_L3_IU_Unify     = 1'b0;//3级指令Cache是统一Cache
wire         word10_L3_IU_Private   = 1'b0;//3级指令Cache是每个核私有的
wire         word10_L3_IU_Inclusive = 1'b0;//3级指令Cache对更低层级是包含关系
wire         word10_L3_D_Present    = 1'b0;//存在3级数据Cache
wire         word10_L3_D_Private    = 1'b0;//3级数据Cache是每个核私有的
wire         word10_L3_D_Inclusive  = 1'b0;//3级数据Cache对更低层次是包含关系
//word11
wire [15:0]  word11_Way_1           = 16'd1;//1级指令Cache的Way数-1
wire [23:16] word11_Index_log2      = 8'd10;//1级指令Cache的一路行数取log2
wire [30:24] word11_Linesize_log2   = 7'd4;//1级指令Cache的一行字节数取log2
//word12
wire [15:0]  word12_Way_1           = 16'd1;//1级数据Cache的Way数-1
wire [23:16] word12_Index_log2      = 8'd10;//1级数据ache的一路行数取log2
wire [30:24] word12_Linesize_log2   = 7'd4;//1级数据ache的一行字节数取log2
//word13
wire [15:0]  word13_Way_1           = 16'd0;//2级指令Cache的Way数-1
wire [23:16] word13_Index_log2      = 8'd0;//2级指令Cache的一路行数取log2
wire [30:24] word13_Linesize_log2   = 7'd0;//2级指令Cache的一行字节数取log2
//word14
wire [15:0]  word14_Way_1           = 16'd0;//3级指令Cache的Way数-1
wire [23:16] word14_Index_log2      = 8'd0;//3级指令Cache的一路行数取log2
wire [30:24] word14_Linesize_log2   = 7'd0;//3级指令Cache的一行字节数取log2

//--------------- cpucfg begin ---------------
assign  cpucfg_value = (rj_value == 32'h0) ? {word0_PRID} :
                       (rj_value == 32'h1) ? {{5'b0},word1_MSG_INT,word1_CRC,word1_HP,word1_RPLV,word1_EP,word1_RI,word1_UAL,word1_VALEN,word1_PALEN,word1_IOCSR,word1_PGMMU,word1_ARCH} :
                       (rj_value == 32'h2) ? {{1'b0},word2_SCQ,word2_LLACQ_SCREL,word2_LAMCAS,word2_LAM_BH,word2_DIV32,word2_FRECIPE,word2_HPTW,word2_LAM,word2_LSPW,word2_LBT_MIPS,word2_LBT_ARM,word2_LBT_X86,word2_LLFTP_ver,word2_LLFTP,word2_LVZ_ver,word2_LVZ,word2_CRYPTO,word2_COMPLEX,word2_LASX,word2_LSX,word2_FP_ver,word2_FP_DP,word2_FP_SP,word2_FP} :
                       (rj_value == 32'h3) ? {{8'b0},word3_LD_SEQ_SA,{5'b0},word3_DBAR_hints,word3_RVAMAX_1,word3_RVA,word3_SPW_HP_HF,word3_ICHMC,word3_ITLBHMC,word3_LLDBAR,word3_SCDLY,word3_LLEXC,word3_UCACC,word3_SFB,word3_CCDMA} :
                       (rj_value == 32'h4) ? {word4_CC_FREQ} :
                       (rj_value == 32'h5) ? {word5_CC_DIV,word5_CC_MUL} :
                       (rj_value == 32'h6) ? {{17'b0},word6_UPM,word6_PMBITS,word6_PMNUM,word6_PMVER,word6_PMP} :
                       (rj_value == 32'h10) ? {{5'b0},word10_L3_D_Inclusive,word10_L3_D_Private,word10_L3_D_Present,word10_L3_IU_Inclusive,word10_L3_IU_Private,word10_L3_IU_Unify,word10_L3_IU_Present,word10_L2_D_Inclusive,word10_L2_D_Private,word10_L2_D_Present,word10_L2_IU_Inclusive,word10_L2_IU_Private,word10_L2_IU_Unify,word10_L2_IU_Present,word10_L1_D_Present,word10_L1_IU_Unify,word10_L1_IU_Present} :
                       (rj_value == 32'h11) ? {{1'b0},word11_Linesize_log2,word11_Index_log2,word11_Way_1} :
                       (rj_value == 32'h12) ? {{1'b0},word12_Linesize_log2,word12_Index_log2,word12_Way_1} :
                       (rj_value == 32'h13) ? {{1'b0},word13_Linesize_log2,word13_Index_log2,word13_Way_1} :
                       (rj_value == 32'h14) ? {{1'b0},word14_Linesize_log2,word14_Index_log2,word14_Way_1} :
                       32'h0;
//--------------- cpucfg end -----------------

endmodule 