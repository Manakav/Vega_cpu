transcript off
onbreak {quit -force}
onerror {quit -force}
transcript on

vlib work
vlib riviera/xpm
vlib riviera/axi_lite_ipif_v3_0_4
vlib riviera/axi_uartlite_v2_0_39
vlib riviera/xil_defaultlib

vmap xpm riviera/xpm
vmap axi_lite_ipif_v3_0_4 riviera/axi_lite_ipif_v3_0_4
vmap axi_uartlite_v2_0_39 riviera/axi_uartlite_v2_0_39
vmap xil_defaultlib riviera/xil_defaultlib

vlog -work xpm  -incr "+incdir+D:/xilinx/2025.2/Vivado/data/rsb/busdef" -l xpm -l axi_lite_ipif_v3_0_4 -l axi_uartlite_v2_0_39 -l xil_defaultlib \
"D:/xilinx/2025.2/Vivado/data/ip/xpm/xpm_cdc/hdl/xpm_cdc.sv" \
"D:/xilinx/2025.2/Vivado/data/ip/xpm/xpm_memory/hdl/xpm_memory.sv" \

vcom -work xpm -93  -incr \
"D:/xilinx/2025.2/Vivado/data/ip/xpm/xpm_VCOMP.vhd" \

vcom -work axi_lite_ipif_v3_0_4 -93  -incr \
"../../../ipstatic/hdl/axi_lite_ipif_v3_0_vh_rfs.vhd" \

vcom -work axi_uartlite_v2_0_39 -93  -incr \
"../../../ipstatic/hdl/axi_uartlite_v2_0_vh_rfs.vhd" \

vcom -work xil_defaultlib -93  -incr \
"../../../../Vega.gen/sources_1/ip/axi_uartlite_0/sim/axi_uartlite_0.vhd" \

vlog -work xil_defaultlib \
"glbl.v"

