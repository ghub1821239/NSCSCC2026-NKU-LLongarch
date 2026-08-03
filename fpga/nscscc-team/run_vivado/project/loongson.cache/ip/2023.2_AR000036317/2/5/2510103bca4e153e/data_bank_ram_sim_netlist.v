// Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
// Copyright 2022-2023 Advanced Micro Devices, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2023.2_AR000036317 (win64) Build 4029153 Fri Oct 13 20:14:34 MDT 2023
// Date        : Sun Aug  2 15:47:00 2026
// Host        : mini running 64-bit major release  (build 9200)
// Command     : write_verilog -force -mode funcsim -rename_top decalper_eb_ot_sdeen_pot_pi_dehcac_xnilix -prefix
//               decalper_eb_ot_sdeen_pot_pi_dehcac_xnilix_ data_bank_ram_sim_netlist.v
// Design      : data_bank_ram
// Purpose     : This verilog netlist is a functional simulation representation of the design and should not be modified
//               or synthesized. This netlist cannot be used for SDF annotated simulation.
// Device      : xc7a200tfbg676-2
// --------------------------------------------------------------------------------
`timescale 1 ps / 1 ps

(* CHECK_LICENSE_TYPE = "data_bank_ram,blk_mem_gen_v8_4_7,{}" *) (* downgradeipidentifiedwarnings = "yes" *) (* x_core_info = "blk_mem_gen_v8_4_7,Vivado 2023.2_AR000036317" *) 
(* NotValidForBitStream *)
module decalper_eb_ot_sdeen_pot_pi_dehcac_xnilix
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
  decalper_eb_ot_sdeen_pot_pi_dehcac_xnilix_blk_mem_gen_v8_4_7 U0
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
`pragma protect encoding = (enctype = "BASE64", line_length = 76, bytes = 19488)
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
