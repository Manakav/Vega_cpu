vlib questa_lib/work
vlib questa_lib/msim

vlib questa_lib/msim/xpm
vlib questa_lib/msim/blk_mem_gen_v8_4_12
vlib questa_lib/msim/xil_defaultlib

vmap xpm questa_lib/msim/xpm
vmap blk_mem_gen_v8_4_12 questa_lib/msim/blk_mem_gen_v8_4_12
vmap xil_defaultlib questa_lib/msim/xil_defaultlib

vlog -work xpm  -incr -mfcu  -sv "+incdir+D:/xilinx/2025.2/Vivado/data/rsb/busdef" \
"D:/xilinx/2025.2/Vivado/data/ip/xpm/xpm_cdc/hdl/xpm_cdc.sv" \
"D:/xilinx/2025.2/Vivado/data/ip/xpm/xpm_memory/hdl/xpm_memory.sv" \

vcom -work xpm  -93  \
"D:/xilinx/2025.2/Vivado/data/ip/xpm/xpm_VCOMP.vhd" \

vlog -work blk_mem_gen_v8_4_12  -incr -mfcu  "+incdir+D:/xilinx/2025.2/Vivado/data/rsb/busdef" \
"../../../ipstatic/simulation/blk_mem_gen_v8_4.v" \

vlog -work xil_defaultlib  -incr -mfcu  "+incdir+D:/xilinx/2025.2/Vivado/data/rsb/busdef" \
"../../../../Vega.gen/sources_1/ip/data_ram_b/sim/data_ram_b.v" \

vlog -work xil_defaultlib \
"glbl.v"

