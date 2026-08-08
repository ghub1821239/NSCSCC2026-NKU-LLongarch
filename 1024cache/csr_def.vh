`ifndef __CSR_DEF_VH__
`define __CSR_DEF_VH__

// csr address
`define CSR_CRMD      14'h0
`define CSR_PRMD      14'h1
`define CSR_ECFG      14'h4
`define CSR_ESTAT     14'h5
`define CSR_ERA       14'h6
`define CSR_BADV      14'h7
`define CSR_EENTRY    14'hc
`define CSR_TLBIDX    14'h10
`define CSR_TLBEHI    14'h11
`define CSR_TLBELO0   14'h12
`define CSR_TLBELO1   14'h13
`define CSR_ASID      14'h18
`define CSR_CPUID     14'h20
`define CSR_SAVE0     14'h30
`define CSR_SAVE1     14'h31
`define CSR_SAVE2     14'h32
`define CSR_SAVE3     14'h33
`define CSR_TID       14'h40
`define CSR_TCFG      14'h41
`define CSR_TVAL      14'h42
`define CSR_TICLR     14'h44
`define CSR_TLBRENTRY 14'h88
`define CSR_DMW0      14'h180
`define CSR_DMW1      14'h181

// csr ecode
`define ECODE_INT     6'h0
`define ECODE_PIL     6'h1
`define ECODE_PIS     6'h2
`define ECODE_PIF     6'h3
`define ECODE_PME     6'h4
`define ECODE_PPI     6'h7
`define ECODE_ADE     6'h8
`define ECODE_ALE     6'h9
`define ECODE_SYS     6'hB
`define ECODE_BRK     6'hC
`define ECODE_INE     6'hD
`define ECODE_IPE     6'hE
`define ECODE_FPD     6'hF
`define ECODE_FPE     6'h12
`define ECODE_TLBR    6'h3F
// csr esubcode
`define ESUBCODE_INT     9'h0
`define ESUBCODE_PIL     9'h0
`define ESUBCODE_PIS     9'h0
`define ESUBCODE_PIF     9'h0
`define ESUBCODE_PME     9'h0
`define ESUBCODE_PPI     9'h0
`define ESUBCODE_ADEF    9'h0
`define ESUBCODE_ADEM    9'h1
`define ESUBCODE_ALE     9'h0
`define ESUBCODE_SYS     9'h0
`define ESUBCODE_BRK     9'h0
`define ESUBCODE_INE     9'h0
`define ESUBCODE_IPE     9'h0
`define ESUBCODE_FPD     9'h0
`define ESUBCODE_FPE     9'h0
`define ESUBCODE_TLBR    9'h0


// CRMD
`define CSR_CRMD_PLV  1:0
`define CSR_CRMD_IE   2
`define CSR_CRMD_DA   3
`define CSR_CRMD_PG   4
`define CSR_CRMD_DATF 6:5
`define CSR_CRMD_DATM 8:7

// PRMD
`define CSR_PRMD_PPLV  1:0
`define CSR_PRMD_PIE  2

// ESTAT
`define CSR_ESTAT_IS1_0 1:0
`define CSR_ESTAT_IS9_2 9:2
`define CSR_ESTAT_IS11 11
`define CSR_ESTAT_IS12 12
`define CSR_ESTAT_IS   12:0
`define CSR_ESTAT_ECODE 21:16
`define CSR_ESTAT_ESUBCODE 30:22

//ERA
`define CSR_ERA_PC     31:0

// EENTRY
`define CSR_EENTRY_VA  31:6

// SAVE0-3
`define CSR_SAVE_DATA  31:0

// TICLR
`define CSR_TICLR_CLR  0

// ECFG
`define CSR_ECFG_LIE  12:0

// BADV
`define CSR_BADV_VADDR  31:0

// TID
`define CSR_TID_TID  31:0

// coreID
`define CSR_COREID_ID  8:0

// TCFG
`define CSR_TCFG_EN  0
`define CSR_TCFG_PERIOD  1
`define CSR_TCFG_INITVAL  31:2

// CPUID
`define CSR_CPUID_COREID 8:0

//TLBIDX
`define TLBNUM 16;
`define CSR_TLBIDX_INDEX $clog2(TLBNUM)-1:0
`define CSR_TLBIDX_PS 29:24
`define CSR_TLBIDX_NE 31

//TLBEHI
`define CSR_TLBEHI_VPPN 31:13

//TLBELO0
`define CSR_TLBELO0_V 0
`define CSR_TLBELO0_D 1
`define CSR_TLBELO0_PLV 3:2
`define CSR_TLBELO0_MAT 5:4
`define CSR_TLBELO0_G 6
`define CSR_TLBELO0_PPN 27:8

//TLBELO1
`define CSR_TLBELO1_V 0
`define CSR_TLBELO1_D 1
`define CSR_TLBELO1_PLV 3:2
`define CSR_TLBELO1_MAT 5:4
`define CSR_TLBELO1_G 6
`define CSR_TLBELO1_PPN 27:8

//ASID
`define CSR_ASID_ASID 9:0
`define CSR_ASID_ASIDBITS 23:16

//TLBRENTRY
`define CSR_TLBRENTRY_PA 31:6

//DMW0
`define CSR_DMW0_PLV0 0
`define CSR_DMW0_PLV3 3
`define CSR_DMW0_MAT  5:4
`define CSR_DMW0_PSEG 27:25
`define CSR_DMW0_VSEG 31:29

//DMW1
`define CSR_DMW1_PLV0 0
`define CSR_DMW1_PLV3 3
`define CSR_DMW1_MAT  5:4
`define CSR_DMW1_PSEG 27:25
`define CSR_DMW1_VSEG 31:29

`endif