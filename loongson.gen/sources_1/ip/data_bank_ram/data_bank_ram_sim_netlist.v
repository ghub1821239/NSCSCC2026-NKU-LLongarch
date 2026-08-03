// Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
// Copyright 2022-2023 Advanced Micro Devices, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2023.2_AR000036317 (win64) Build 4029153 Fri Oct 13 20:14:34 MDT 2023
// Date        : Sun Aug  2 15:47:01 2026
// Host        : mini running 64-bit major release  (build 9200)
// Command     : write_verilog -force -mode funcsim
//               d:/chiplab/loongson.gen/sources_1/ip/data_bank_ram/data_bank_ram_sim_netlist.v
// Design      : data_bank_ram
// Purpose     : This verilog netlist is a functional simulation representation of the design and should not be modified
//               or synthesized. This netlist cannot be used for SDF annotated simulation.
// Device      : xc7a200tfbg676-2
// --------------------------------------------------------------------------------
`timescale 1 ps / 1 ps

(* CHECK_LICENSE_TYPE = "data_bank_ram,blk_mem_gen_v8_4_7,{}" *) (* downgradeipidentifiedwarnings = "yes" *) (* x_core_info = "blk_mem_gen_v8_4_7,Vivado 2023.2_AR000036317" *) 
(* NotValidForBitStream *)
module data_bank_ram
   (clka,
    wea,
    addra,
    dina,
    douta);
  (* x_interface_info = "xilinx.com:interface:bram:1.0 BRAM_PORTA CLK" *) (* x_interface_parameter = "XIL_INTERFACENAME BRAM_PORTA, MEM_SIZE 8192, MEM_WIDTH 32, MEM_ECC NONE, MASTER_TYPE OTHER, READ_LATENCY 1" *) input clka;
  (* x_interface_info = "xilinx.com:interface:bram:1.0 BRAM_PORTA WE" *) input [3:0]wea;
  (* x_interface_info = "xilinx.com:interface:bram:1.0 BRAM_PORTA ADDR" *) input [7:0]addra;
  (* x_interface_info = "xilinx.com:interface:bram:1.0 BRAM_PORTA DIN" *) input [31:0]dina;
  (* x_interface_info = "xilinx.com:interface:bram:1.0 BRAM_PORTA DOUT" *) output [31:0]douta;

  wire [7:0]addra;
  wire clka;
  wire [31:0]dina;
  wire [31:0]douta;
  wire [3:0]wea;
  wire NLW_U0_dbiterr_UNCONNECTED;
  wire NLW_U0_rsta_busy_UNCONNECTED;
  wire NLW_U0_rstb_busy_UNCONNECTED;
  wire NLW_U0_s_axi_arready_UNCONNECTED;
  wire NLW_U0_s_axi_awready_UNCONNECTED;
  wire NLW_U0_s_axi_bvalid_UNCONNECTED;
  wire NLW_U0_s_axi_dbiterr_UNCONNECTED;
  wire NLW_U0_s_axi_rlast_UNCONNECTED;
  wire NLW_U0_s_axi_rvalid_UNCONNECTED;
  wire NLW_U0_s_axi_sbiterr_UNCONNECTED;
  wire NLW_U0_s_axi_wready_UNCONNECTED;
  wire NLW_U0_sbiterr_UNCONNECTED;
  wire [31:0]NLW_U0_doutb_UNCONNECTED;
  wire [7:0]NLW_U0_rdaddrecc_UNCONNECTED;
  wire [3:0]NLW_U0_s_axi_bid_UNCONNECTED;
  wire [1:0]NLW_U0_s_axi_bresp_UNCONNECTED;
  wire [7:0]NLW_U0_s_axi_rdaddrecc_UNCONNECTED;
  wire [31:0]NLW_U0_s_axi_rdata_UNCONNECTED;
  wire [3:0]NLW_U0_s_axi_rid_UNCONNECTED;
  wire [1:0]NLW_U0_s_axi_rresp_UNCONNECTED;

  (* C_ADDRA_WIDTH = "8" *) 
  (* C_ADDRB_WIDTH = "8" *) 
  (* C_ALGORITHM = "1" *) 
  (* C_AXI_ID_WIDTH = "4" *) 
  (* C_AXI_SLAVE_TYPE = "0" *) 
  (* C_AXI_TYPE = "1" *) 
  (* C_BYTE_SIZE = "8" *) 
  (* C_COMMON_CLK = "0" *) 
  (* C_COUNT_18K_BRAM = "1" *) 
  (* C_COUNT_36K_BRAM = "0" *) 
  (* C_CTRL_ECC_ALGO = "NONE" *) 
  (* C_DEFAULT_DATA = "0" *) 
  (* C_DISABLE_WARN_BHV_COLL = "0" *) 
  (* C_DISABLE_WARN_BHV_RANGE = "0" *) 
  (* C_ELABORATION_DIR = "./" *) 
  (* C_ENABLE_32BIT_ADDRESS = "0" *) 
  (* C_EN_DEEPSLEEP_PIN = "0" *) 
  (* C_EN_ECC_PIPE = "0" *) 
  (* C_EN_RDADDRA_CHG = "0" *) 
  (* C_EN_RDADDRB_CHG = "0" *) 
  (* C_EN_SAFETY_CKT = "0" *) 
  (* C_EN_SHUTDOWN_PIN = "0" *) 
  (* C_EN_SLEEP_PIN = "0" *) 
  (* C_EST_POWER_SUMMARY = "Estimated Power for IP     :     3.53845 mW" *) 
  (* C_FAMILY = "artix7" *) 
  (* C_HAS_AXI_ID = "0" *) 
  (* C_HAS_ENA = "0" *) 
  (* C_HAS_ENB = "0" *) 
  (* C_HAS_INJECTERR = "0" *) 
  (* C_HAS_MEM_OUTPUT_REGS_A = "0" *) 
  (* C_HAS_MEM_OUTPUT_REGS_B = "0" *) 
  (* C_HAS_MUX_OUTPUT_REGS_A = "0" *) 
  (* C_HAS_MUX_OUTPUT_REGS_B = "0" *) 
  (* C_HAS_REGCEA = "0" *) 
  (* C_HAS_REGCEB = "0" *) 
  (* C_HAS_RSTA = "0" *) 
  (* C_HAS_RSTB = "0" *) 
  (* C_HAS_SOFTECC_INPUT_REGS_A = "0" *) 
  (* C_HAS_SOFTECC_OUTPUT_REGS_B = "0" *) 
  (* C_INITA_VAL = "0" *) 
  (* C_INITB_VAL = "0" *) 
  (* C_INIT_FILE = "data_bank_ram.mem" *) 
  (* C_INIT_FILE_NAME = "no_coe_file_loaded" *) 
  (* C_INTERFACE_TYPE = "0" *) 
  (* C_LOAD_INIT_FILE = "0" *) 
  (* C_MEM_TYPE = "0" *) 
  (* C_MUX_PIPELINE_STAGES = "0" *) 
  (* C_PRIM_TYPE = "1" *) 
  (* C_READ_DEPTH_A = "256" *) 
  (* C_READ_DEPTH_B = "256" *) 
  (* C_READ_LATENCY_A = "1" *) 
  (* C_READ_LATENCY_B = "1" *) 
  (* C_READ_WIDTH_A = "32" *) 
  (* C_READ_WIDTH_B = "32" *) 
  (* C_RSTRAM_A = "0" *) 
  (* C_RSTRAM_B = "0" *) 
  (* C_RST_PRIORITY_A = "CE" *) 
  (* C_RST_PRIORITY_B = "CE" *) 
  (* C_SIM_COLLISION_CHECK = "ALL" *) 
  (* C_USE_BRAM_BLOCK = "0" *) 
  (* C_USE_BYTE_WEA = "1" *) 
  (* C_USE_BYTE_WEB = "1" *) 
  (* C_USE_DEFAULT_DATA = "1" *) 
  (* C_USE_ECC = "0" *) 
  (* C_USE_SOFTECC = "0" *) 
  (* C_USE_URAM = "0" *) 
  (* C_WEA_WIDTH = "4" *) 
  (* C_WEB_WIDTH = "4" *) 
  (* C_WRITE_DEPTH_A = "256" *) 
  (* C_WRITE_DEPTH_B = "256" *) 
  (* C_WRITE_MODE_A = "WRITE_FIRST" *) 
  (* C_WRITE_MODE_B = "WRITE_FIRST" *) 
  (* C_WRITE_WIDTH_A = "32" *) 
  (* C_WRITE_WIDTH_B = "32" *) 
  (* C_XDEVICEFAMILY = "artix7" *) 
  (* downgradeipidentifiedwarnings = "yes" *) 
  (* is_du_within_envelope = "true" *) 
  data_bank_ram_blk_mem_gen_v8_4_7 U0
       (.addra(addra),
        .addrb({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .clka(clka),
        .clkb(1'b0),
        .dbiterr(NLW_U0_dbiterr_UNCONNECTED),
        .deepsleep(1'b0),
        .dina(dina),
        .dinb({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .douta(douta),
        .doutb(NLW_U0_doutb_UNCONNECTED[31:0]),
        .eccpipece(1'b0),
        .ena(1'b0),
        .enb(1'b0),
        .injectdbiterr(1'b0),
        .injectsbiterr(1'b0),
        .rdaddrecc(NLW_U0_rdaddrecc_UNCONNECTED[7:0]),
        .regcea(1'b0),
        .regceb(1'b0),
        .rsta(1'b0),
        .rsta_busy(NLW_U0_rsta_busy_UNCONNECTED),
        .rstb(1'b0),
        .rstb_busy(NLW_U0_rstb_busy_UNCONNECTED),
        .s_aclk(1'b0),
        .s_aresetn(1'b0),
        .s_axi_araddr({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .s_axi_arburst({1'b0,1'b0}),
        .s_axi_arid({1'b0,1'b0,1'b0,1'b0}),
        .s_axi_arlen({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .s_axi_arready(NLW_U0_s_axi_arready_UNCONNECTED),
        .s_axi_arsize({1'b0,1'b0,1'b0}),
        .s_axi_arvalid(1'b0),
        .s_axi_awaddr({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .s_axi_awburst({1'b0,1'b0}),
        .s_axi_awid({1'b0,1'b0,1'b0,1'b0}),
        .s_axi_awlen({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .s_axi_awready(NLW_U0_s_axi_awready_UNCONNECTED),
        .s_axi_awsize({1'b0,1'b0,1'b0}),
        .s_axi_awvalid(1'b0),
        .s_axi_bid(NLW_U0_s_axi_bid_UNCONNECTED[3:0]),
        .s_axi_bready(1'b0),
        .s_axi_bresp(NLW_U0_s_axi_bresp_UNCONNECTED[1:0]),
        .s_axi_bvalid(NLW_U0_s_axi_bvalid_UNCONNECTED),
        .s_axi_dbiterr(NLW_U0_s_axi_dbiterr_UNCONNECTED),
        .s_axi_injectdbiterr(1'b0),
        .s_axi_injectsbiterr(1'b0),
        .s_axi_rdaddrecc(NLW_U0_s_axi_rdaddrecc_UNCONNECTED[7:0]),
        .s_axi_rdata(NLW_U0_s_axi_rdata_UNCONNECTED[31:0]),
        .s_axi_rid(NLW_U0_s_axi_rid_UNCONNECTED[3:0]),
        .s_axi_rlast(NLW_U0_s_axi_rlast_UNCONNECTED),
        .s_axi_rready(1'b0),
        .s_axi_rresp(NLW_U0_s_axi_rresp_UNCONNECTED[1:0]),
        .s_axi_rvalid(NLW_U0_s_axi_rvalid_UNCONNECTED),
        .s_axi_sbiterr(NLW_U0_s_axi_sbiterr_UNCONNECTED),
        .s_axi_wdata({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .s_axi_wlast(1'b0),
        .s_axi_wready(NLW_U0_s_axi_wready_UNCONNECTED),
        .s_axi_wstrb({1'b0,1'b0,1'b0,1'b0}),
        .s_axi_wvalid(1'b0),
        .sbiterr(NLW_U0_sbiterr_UNCONNECTED),
        .shutdown(1'b0),
        .sleep(1'b0),
        .wea(wea),
        .web({1'b0,1'b0,1'b0,1'b0}));
endmodule
`pragma protect begin_protected
`pragma protect version = 1
`pragma protect encrypt_agent = "XILINX"
`pragma protect encrypt_agent_info = "Xilinx Encryption Tool 2023.2"
`pragma protect key_keyowner="Synopsys", key_keyname="SNPS-VCS-RSA-2", key_method="rsa"
`pragma protect encoding = (enctype="BASE64", line_length=76, bytes=128)
`pragma protect key_block
jLV29U0rrfMIZhYJzdoUrPoqB9eHQ5NXmWyCdqnN3Wgm+GU4C3zthrN1m4QGiaj0thPCIynZbX+0
7yjtkv+T5ByJ6NhiofAwWseGLvPXlYu6ERAPvi4SAYpF2VUqQHtPAbPmnPubGdDRgIEpeobF7hsz
rEcpEru1pyiScUriyuo=

`pragma protect key_keyowner="Aldec", key_keyname="ALDEC15_001", key_method="rsa"
`pragma protect encoding = (enctype="BASE64", line_length=76, bytes=256)
`pragma protect key_block
vsoizVrOONWw/DhjRLEYrtRmtji+Ok63CbpSg/l9VnoKAi8tAzqRbQ57atGB2N6IGGbKHkbK2Uzh
EHgWvYZeyt4hE+bpQX91vc9PNxfjQMGzPoFD3jCWk30EmEk+AND39eWx+DhJ8xhFuucoOQ2GwyAk
B+Mjs15naPE7DvlHel8hnD4dfSdYhGKp96oozu8JeBto8aHG6poOuYkxSwaut7NCI+mabCkMxtMp
RrydgmRuTvhRTbJMyx5CxFSZTRDrS5aU1vaRlnMiqKCI7g2KY9pemYaJsFeVodBuo6IyKGynyEhs
wr+VtUhQDtaVhMkwB95WwmMoDk9F2L5Au1I+TQ==

`pragma protect key_keyowner="Mentor Graphics Corporation", key_keyname="MGC-VELOCE-RSA", key_method="rsa"
`pragma protect encoding = (enctype="BASE64", line_length=76, bytes=128)
`pragma protect key_block
W081dPMCWhKs5YlQD7n3zvf7+PTcnb8eFWxoVs8+zHLkxDMA1klITbsfztGYvJFce8Yao5XQLLqZ
oUE5Pq2arq+zwICFUcLjdMsmP1WmL82znHOPHm83zNwrxWMloHkySAqzFbgJeHa973uZqj0M8ydc
sYmzCYVlGVjt0QX0xqA=

`pragma protect key_keyowner="Mentor Graphics Corporation", key_keyname="MGC-VERIF-SIM-RSA-2", key_method="rsa"
`pragma protect encoding = (enctype="BASE64", line_length=76, bytes=256)
`pragma protect key_block
Zpc3MmdLWaVOv+S4z2POuoyslYoAbWc+Npxq2UyQRtDwf566IId3uwAetolMAgfLo/G3ezuSOXMn
8NznS37h9XvmVrxA50SAux68P87WgkLtiUYqM3CMBKkxNlZ/TR8WzTuQyFdvzkOE9lp8HC7LXnk5
RDsnOM+su46FW7ysY01COslo9Xc7rhs6WFqx29+Xcqk8+ZMLSzaJfuwZdNmJFS3Q1vhlq3ZeYqMl
wMieB731KsPxjxp7VKNHpTbgFryC2isqc4ohBDOt52M/Bz4B/rIpFeHfZ7X3jWSiKtSuBsDN2NXf
EMjfAT248dlK7NxJ+NBNPhS5sLxTiGyQhta57A==

`pragma protect key_keyowner="Real Intent", key_keyname="RI-RSA-KEY-1", key_method="rsa"
`pragma protect encoding = (enctype="BASE64", line_length=76, bytes=256)
`pragma protect key_block
rPMYqnkKhJKV1wltOfDrKos9ZbucaoX3WGTuqsdLkGpcKObzslHBwlGrKtWV7bZYmS2SM+QuEMfa
CE+tCUdsSiprp+n5BuSQlJa6BJ8mlqccjoo/JLw2QEmUhyMXQ3TLGomGGoZdeTmMPXhUBAOyLPea
Ddc8mgtTN8Kpy117GOTXDKP+IKJqW01fLrPJpgEhFiJCbyElLgtCRWmI94gX+y4XNVS0Cd1YwNw6
4nHgnEdC7fXARDKcYO3VsWC/pdzPQgursXloNLrVYa6i2xr+8E1V0+nSWwNYQZP7XUIVqXKMU8Ea
bT4acXrRCF/5tJJ5B9JparYI0zxXSbaakn1dIw==

`pragma protect key_keyowner="Xilinx", key_keyname="xilinxt_2022_10", key_method="rsa"
`pragma protect encoding = (enctype="BASE64", line_length=76, bytes=256)
`pragma protect key_block
mfroTgL8g2pyIXQ/mGO9YHm19cd5mOlJ++qpusOYeVxGmkIhvF4aKx+AyIUz2yGGAeCtOzIasHty
pyqKgZhibSqxcpHgR0m6GOxXXOXJiHaK8NzxUzXeRJovcBI/WjtDhXeb1LRMI1J97jVBtJPJQH0Y
fGOD7jWvkvQwxnrZdyLp6kPWgSIcavHHDbO7iJv4gnyGp6W3/FCDo2RKWNLoW+SNjSdLZ6YRP8a+
ldaGU8TYvJ03KWlmik7repuN6AwxCjg2KeQ+x1sBAEXzROXomuSbvX3ZAo8UiIKAQY1SJumHLG3L
QI/S4Wbl1Hz6LDTsttMwP480gq6+tb6s1E4oWw==

`pragma protect key_keyowner="Metrics Technologies Inc.", key_keyname="DSim", key_method="rsa"
`pragma protect encoding = (enctype="BASE64", line_length=76, bytes=256)
`pragma protect key_block
QJIabgm8dx/gVHbOQFwt8maOKVHFgkpZTPR6dzD8fqoGo9M9oGPTqBqchtPZWgv2UYFF2KEUSlV4
L3SDXBKrLs+NsAVTcICaEMiEi6j82zj/C1LsPkQfS8RLrg0ab8lbDMb5YqJ7lkHs3iM65x2iN1Mf
66cTgCbkAdl3rDpab75btpTQt5ZKiq5CSY3RZfyIW0uWbTGTELm6liuRKM9+K8BQwTU7A+FFFQBA
/9eJwQYzNNA/iwoYJ2WTPd6pBlzXriNLu9M+/2bYicNBSuH1PBR9v2ESrTB6k7EiV1zvBXV9NuG/
sFt4MumWMuSNwP2W38bQATxxW/l0IrmaXGOC/w==

`pragma protect key_keyowner="Atrenta", key_keyname="ATR-SG-RSA-1", key_method="rsa"
`pragma protect encoding = (enctype="BASE64", line_length=76, bytes=384)
`pragma protect key_block
lhKf/Vgj6pHpme1ji4HVe36BU8pMkam/2I9lFeyOiBnIbzgdEGfLJBcEvkL33A7s0hxa6LFbHnkT
upgMpPjmIghBz3xUQ13vpiY152thFec6qvlcdg1r+GTmnBOSFl6g/OfZ3eFUhfsve6ZjQHpXnKFo
a55hN2+eP1EG9+VxGeM7XkHaeFhEIry52qtnmg072KEFIwRiGs2d/TJ4AqupuIdIiP1kTN9k+oqa
2ta1vdtqPY0dDHqrf+5YSd0CejkhQeCqg/bauLP3755SwdOPRgooG5ANT8hUpTiFMFXtU+GC9NSp
evJtMHUy1NbgMmhFHO+w3URLEdjSaBxZPD7YLdWkF65jY526tJzoek+BzEKoBaGfCaY7O1nHKXm+
89k3rPUy0Xo4/0nHpno+N/Db09heJPbnGsCwN/l+KnR6Lz8kvWziBjZe0ijOkKI+T12y3T1VeOtY
H/aqtNlQt1mhFwrbw6ezaAiDPVbCQXnly6b4tbb8+nFsxWOGIGAfLozB

`pragma protect key_keyowner="Cadence Design Systems.", key_keyname="CDS_RSA_KEY_VER_1", key_method="rsa"
`pragma protect encoding = (enctype="BASE64", line_length=76, bytes=256)
`pragma protect key_block
PNsQ8uEcQYrl+GaDuBaq1tQ5br5aAdaqHnyrc0NVu/JnQUk53jaiLx8Oz5fNACvWelUUk2/C+P5I
b2rbU1bb/dC6TqC5J1N0yoMYRYw58u4Lrl8Kgqgt9Rlph5Qgzzfxp+oblXF/pO4mRyAXpZhpNkFT
0Ar9BUtPOTOtJ9/g53SRnZ6GjxzfeD+25J4fcXBNo2gCTgUkwiLSsJRwTB/cJmn+dZPwPdIOHEP9
TkfDK+OrbLYO3T+DFBTCMRNH2NB1J9sc5s+nPU8iYnjgPTo6HoGW+LIlCz6yNJMZzJzoeW708utc
0fJXkT7vLDVh7olvy3V9AAY8Do0YR1kiZlhVhQ==

`pragma protect key_keyowner="Synplicity", key_keyname="SYNP15_1", key_method="rsa"
`pragma protect encoding = (enctype="BASE64", line_length=76, bytes=256)
`pragma protect key_block
zAz8RnGHFebkJFAS+gjC+mXHW7m7We+JgSmIz15mS01u/4+9Ng0sJfkeXOClmVPTQ2Mp2Yuv6/6f
ehzUTcANilWsqLM6Q1FToCPNX/NTqodlcHirGM7b5R9yevouNT/aqH12nmbunBQmBHmehNutdCjG
r6Z7kZgeZ2ZE7MMOF0rTy1XHEPkqgMNTRoS8R/pPWPTW4/j+bn3aJj0Q/fTz4Gi3mbSUKWs2fREQ
UKiuolNJkN6DiDvhlVYHUyytXNJG44ikmBXehoQQRLapkYaxnQmMRT1ok9uY6pKoy71CtvJ3Mt2x
EQv1GU2i4qQyAOwa0mkEohWXduicU6tDz3zQwQ==

`pragma protect key_keyowner="Mentor Graphics Corporation", key_keyname="MGC-PREC-RSA", key_method="rsa"
`pragma protect encoding = (enctype="BASE64", line_length=76, bytes=256)
`pragma protect key_block
TK3eE9V+v1z2P1KjG4GrjhA1n3qDOpNzLGXdtjnjhF0QBFPSuhC+nmNqTPOb3p2a9r5KD0miY3Cd
+KpjH6Ao09E2/LD2Go4aLQh6vP+9BldlSKEwCGfx2NjBQrXWVH21lQR7IRjOvyTOclpd7SgtUJLw
dvebETyLiKr9C6RfnIBeptuCA3iJlXfwkh6I0JfzD5WBizQkotioZmmrXv5105pCXQ4Ta1WThFsA
2ll9dZeSjEDHUxxhfyfjryv9m4VL89ZDU/rGITsdptwB1BC1jLqmPDymY05lyECnjA6NIR5GGfI4
K2y2f4GfikKoN5r9IOvFzw963Wm82ZZPtXOKGg==

`pragma protect data_method = "AES128-CBC"
`pragma protect encoding = (enctype = "BASE64", line_length = 76, bytes = 19472)
`pragma protect data_block
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
`pragma protect end_protected
`ifndef GLBL
`define GLBL
`timescale  1 ps / 1 ps

module glbl ();

    parameter ROC_WIDTH = 100000;
    parameter TOC_WIDTH = 0;
    parameter GRES_WIDTH = 10000;
    parameter GRES_START = 10000;

//--------   STARTUP Globals --------------
    wire GSR;
    wire GTS;
    wire GWE;
    wire PRLD;
    wire GRESTORE;
    tri1 p_up_tmp;
    tri (weak1, strong0) PLL_LOCKG = p_up_tmp;

    wire PROGB_GLBL;
    wire CCLKO_GLBL;
    wire FCSBO_GLBL;
    wire [3:0] DO_GLBL;
    wire [3:0] DI_GLBL;
   
    reg GSR_int;
    reg GTS_int;
    reg PRLD_int;
    reg GRESTORE_int;

//--------   JTAG Globals --------------
    wire JTAG_TDO_GLBL;
    wire JTAG_TCK_GLBL;
    wire JTAG_TDI_GLBL;
    wire JTAG_TMS_GLBL;
    wire JTAG_TRST_GLBL;

    reg JTAG_CAPTURE_GLBL;
    reg JTAG_RESET_GLBL;
    reg JTAG_SHIFT_GLBL;
    reg JTAG_UPDATE_GLBL;
    reg JTAG_RUNTEST_GLBL;

    reg JTAG_SEL1_GLBL = 0;
    reg JTAG_SEL2_GLBL = 0 ;
    reg JTAG_SEL3_GLBL = 0;
    reg JTAG_SEL4_GLBL = 0;

    reg JTAG_USER_TDO1_GLBL = 1'bz;
    reg JTAG_USER_TDO2_GLBL = 1'bz;
    reg JTAG_USER_TDO3_GLBL = 1'bz;
    reg JTAG_USER_TDO4_GLBL = 1'bz;

    assign (strong1, weak0) GSR = GSR_int;
    assign (strong1, weak0) GTS = GTS_int;
    assign (weak1, weak0) PRLD = PRLD_int;
    assign (strong1, weak0) GRESTORE = GRESTORE_int;

    initial begin
	GSR_int = 1'b1;
	PRLD_int = 1'b1;
	#(ROC_WIDTH)
	GSR_int = 1'b0;
	PRLD_int = 1'b0;
    end

    initial begin
	GTS_int = 1'b1;
	#(TOC_WIDTH)
	GTS_int = 1'b0;
    end

    initial begin 
	GRESTORE_int = 1'b0;
	#(GRES_START);
	GRESTORE_int = 1'b1;
	#(GRES_WIDTH);
	GRESTORE_int = 1'b0;
    end

endmodule
`endif
