// Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
// Copyright 2022-2023 Advanced Micro Devices, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2023.2_AR000036317 (win64) Build 4029153 Fri Oct 13 20:14:34 MDT 2023
// Date        : Sun Aug  2 15:47:00 2026
// Host        : mini running 64-bit major release  (build 9200)
// Command     : write_verilog -force -mode funcsim -rename_top decalper_eb_ot_sdeen_pot_pi_dehcac_xnilix -prefix
//               decalper_eb_ot_sdeen_pot_pi_dehcac_xnilix_ tagv_ram_sim_netlist.v
// Design      : tagv_ram
// Purpose     : This verilog netlist is a functional simulation representation of the design and should not be modified
//               or synthesized. This netlist cannot be used for SDF annotated simulation.
// Device      : xc7a200tfbg676-2
// --------------------------------------------------------------------------------
`timescale 1 ps / 1 ps

(* CHECK_LICENSE_TYPE = "tagv_ram,blk_mem_gen_v8_4_7,{}" *) (* downgradeipidentifiedwarnings = "yes" *) (* x_core_info = "blk_mem_gen_v8_4_7,Vivado 2023.2_AR000036317" *) 
(* NotValidForBitStream *)
module decalper_eb_ot_sdeen_pot_pi_dehcac_xnilix
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
  decalper_eb_ot_sdeen_pot_pi_dehcac_xnilix_blk_mem_gen_v8_4_7 U0
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
`pragma protect encoding = (enctype = "BASE64", line_length = 76, bytes = 20048)
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
