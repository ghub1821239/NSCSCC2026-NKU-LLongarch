// Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
// Copyright 2022-2023 Advanced Micro Devices, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2023.2_AR000036317 (win64) Build 4029153 Fri Oct 13 20:14:34 MDT 2023
// Date        : Sun Aug  2 15:47:01 2026
// Host        : mini running 64-bit major release  (build 9200)
// Command     : write_verilog -force -mode synth_stub
//               d:/chiplab/loongson.gen/sources_1/ip/data_bank_ram/data_bank_ram_stub.v
// Design      : data_bank_ram
// Purpose     : Stub declaration of top-level module interface
// Device      : xc7a200tfbg676-2
// --------------------------------------------------------------------------------

// This empty module with port declaration file causes synthesis tools to infer a black box for IP.
// The synthesis directives are for Synopsys Synplify support to prevent IO buffer insertion.
// Please paste the declaration into a Verilog source file or add the file as an additional source.
(* x_core_info = "blk_mem_gen_v8_4_7,Vivado 2023.2_AR000036317" *)
module data_bank_ram(clka, wea, addra, dina, douta)
/* synthesis syn_black_box black_box_pad_pin="wea[3:0],addra[7:0],dina[31:0],douta[31:0]" */
/* synthesis syn_force_seq_prim="clka" */;
  input clka /* synthesis syn_isclock = 1 */;
  input [3:0]wea;
  input [7:0]addra;
  input [31:0]dina;
  output [31:0]douta;
endmodule
