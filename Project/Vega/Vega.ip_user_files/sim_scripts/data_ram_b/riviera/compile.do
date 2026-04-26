transcript off
onbreak {quit -force}
onerror {quit -force}
transcript on

vlib work
vlib riviera/xpm
vlib riviera/blk_mem_gen_v8_4_12
vlib riviera/xil_defaultlib

vmap xpm riviera/xpm
vmap blk_mem_gen_v8_4_12 riviera/blk_mem_gen_v8_4_12
vmap xil_defaultlib riviera/xil_defaultlib

vlog -work xpm  -incr "+incdir+D:/xilinx/2025.2/Vivado/data/rsb/busdef" -l xpm -l blk_mem_gen_v8_4_12 -l xil_defaultlib \
"D:/xilinx/2025.2/Vivado/data/ip/xpm/xpm_cdc/hdl/xpm_cdc.sv" \
"D:/xilinx/2025.2/Vivado/data/ip/xpm/xpm_memory/hdl/xpm_memory.sv" \

vcom -work xpm -93  -incr \
"D:/xilinx/2025.2/Vivado/data/ip/xpm/xpm_VCOMP.vhd" \

vlog -work blk_mem_gen_v8_4_12  -incr -v2k5 "+incdir+D:/xilinx/2025.2/Vivado/data/rsb/busdef" -l xpm -l blk_mem_gen_v8_4_12 -l xil_defaultlib \
"../../../ipstatic/simulation/blk_mem_gen_v8_4.v" \

vlog -work xil_defaultlib  -incr -v2k5 "+incdir+D:/xilinx/2025.2/Vivado/data/rsb/busdef" -l xpm -l blk_mem_gen_v8_4_12 -l xil_defaultlib \
"../../../../Vega.gen/sources_1/ip/data_ram_b/sim/data_ram_b.v" \

vlog -work xil_defaultlib \
"glbl.v"

