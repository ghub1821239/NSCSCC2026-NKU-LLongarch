// Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
// Copyright 2022-2023 Advanced Micro Devices, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2023.2_AR000036317 (win64) Build 4029153 Fri Oct 13 20:14:34 MDT 2023
// Date        : Sun Aug  2 15:47:01 2026
// Host        : mini running 64-bit major release  (build 9200)
// Command     : write_verilog -force -mode funcsim d:/chiplab/loongson.gen/sources_1/ip/tagv_ram/tagv_ram_sim_netlist.v
// Design      : tagv_ram
// Purpose     : This verilog netlist is a functional simulation representation of the design and should not be modified
//               or synthesized. This netlist cannot be used for SDF annotated simulation.
// Device      : xc7a200tfbg676-2
// --------------------------------------------------------------------------------
`timescale 1 ps / 1 ps

(* CHECK_LICENSE_TYPE = "tagv_ram,blk_mem_gen_v8_4_7,{}" *) (* downgradeipidentifiedwarnings = "yes" *) (* x_core_info = "blk_mem_gen_v8_4_7,Vivado 2023.2_AR000036317" *) 
(* NotValidForBitStream *)
module tagv_ram
   (clka,
    wea,
    addra,
    dina,
    douta);
  (* x_interface_info = "xilinx.com:interface:bram:1.0 BRAM_PORTA CLK" *) (* x_interface_parameter = "XIL_INTERFACENAME BRAM_PORTA, MEM_SIZE 8192, MEM_WIDTH 32, MEM_ECC NONE, MASTER_TYPE OTHER, READ_LATENCY 1" *) input clka;
  (* x_interface_info = "xilinx.com:interface:bram:1.0 BRAM_PORTA WE" *) input [0:0]wea;
  (* x_interface_info = "xilinx.com:interface:bram:1.0 BRAM_PORTA ADDR" *) input [7:0]addra;
  (* x_interface_info = "xilinx.com:interface:bram:1.0 BRAM_PORTA DIN" *) input [20:0]dina;
  (* x_interface_info = "xilinx.com:interface:bram:1.0 BRAM_PORTA DOUT" *) output [20:0]douta;

  wire [7:0]addra;
  wire clka;
  wire [20:0]dina;
  wire [20:0]douta;
  wire [0:0]wea;
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
  wire [20:0]NLW_U0_doutb_UNCONNECTED;
  wire [7:0]NLW_U0_rdaddrecc_UNCONNECTED;
  wire [3:0]NLW_U0_s_axi_bid_UNCONNECTED;
  wire [1:0]NLW_U0_s_axi_bresp_UNCONNECTED;
  wire [7:0]NLW_U0_s_axi_rdaddrecc_UNCONNECTED;
  wire [20:0]NLW_U0_s_axi_rdata_UNCONNECTED;
  wire [3:0]NLW_U0_s_axi_rid_UNCONNECTED;
  wire [1:0]NLW_U0_s_axi_rresp_UNCONNECTED;

  (* C_ADDRA_WIDTH = "8" *) 
  (* C_ADDRB_WIDTH = "8" *) 
  (* C_ALGORITHM = "1" *) 
  (* C_AXI_ID_WIDTH = "4" *) 
  (* C_AXI_SLAVE_TYPE = "0" *) 
  (* C_AXI_TYPE = "1" *) 
  (* C_BYTE_SIZE = "9" *) 
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
  (* C_EST_POWER_SUMMARY = "Estimated Power for IP     :     3.08085 mW" *) 
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
  (* C_INIT_FILE = "tagv_ram.mem" *) 
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
  (* C_READ_WIDTH_A = "21" *) 
  (* C_READ_WIDTH_B = "21" *) 
  (* C_RSTRAM_A = "0" *) 
  (* C_RSTRAM_B = "0" *) 
  (* C_RST_PRIORITY_A = "CE" *) 
  (* C_RST_PRIORITY_B = "CE" *) 
  (* C_SIM_COLLISION_CHECK = "ALL" *) 
  (* C_USE_BRAM_BLOCK = "0" *) 
  (* C_USE_BYTE_WEA = "0" *) 
  (* C_USE_BYTE_WEB = "0" *) 
  (* C_USE_DEFAULT_DATA = "1" *) 
  (* C_USE_ECC = "0" *) 
  (* C_USE_SOFTECC = "0" *) 
  (* C_USE_URAM = "0" *) 
  (* C_WEA_WIDTH = "1" *) 
  (* C_WEB_WIDTH = "1" *) 
  (* C_WRITE_DEPTH_A = "256" *) 
  (* C_WRITE_DEPTH_B = "256" *) 
  (* C_WRITE_MODE_A = "WRITE_FIRST" *) 
  (* C_WRITE_MODE_B = "WRITE_FIRST" *) 
  (* C_WRITE_WIDTH_A = "21" *) 
  (* C_WRITE_WIDTH_B = "21" *) 
  (* C_XDEVICEFAMILY = "artix7" *) 
  (* downgradeipidentifiedwarnings = "yes" *) 
  (* is_du_within_envelope = "true" *) 
  tagv_ram_blk_mem_gen_v8_4_7 U0
       (.addra(addra),
        .addrb({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .clka(clka),
        .clkb(1'b0),
        .dbiterr(NLW_U0_dbiterr_UNCONNECTED),
        .deepsleep(1'b0),
        .dina(dina),
        .dinb({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .douta(douta),
        .doutb(NLW_U0_doutb_UNCONNECTED[20:0]),
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
        .s_axi_rdata(NLW_U0_s_axi_rdata_UNCONNECTED[20:0]),
        .s_axi_rid(NLW_U0_s_axi_rid_UNCONNECTED[3:0]),
        .s_axi_rlast(NLW_U0_s_axi_rlast_UNCONNECTED),
        .s_axi_rready(1'b0),
        .s_axi_rresp(NLW_U0_s_axi_rresp_UNCONNECTED[1:0]),
        .s_axi_rvalid(NLW_U0_s_axi_rvalid_UNCONNECTED),
        .s_axi_sbiterr(NLW_U0_s_axi_sbiterr_UNCONNECTED),
        .s_axi_wdata({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .s_axi_wlast(1'b0),
        .s_axi_wready(NLW_U0_s_axi_wready_UNCONNECTED),
        .s_axi_wstrb(1'b0),
        .s_axi_wvalid(1'b0),
        .sbiterr(NLW_U0_sbiterr_UNCONNECTED),
        .shutdown(1'b0),
        .sleep(1'b0),
        .wea(wea),
        .web(1'b0));
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
`pragma protect encoding = (enctype = "BASE64", line_length = 76, bytes = 19968)
`pragma protect data_block
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
EkYKW+nA6Gcx+YdQ+3NKmhWl
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
