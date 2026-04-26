transcript off
onbreak {quit -force}
onerror {quit -force}
transcript on

vlib work
vlib activehdl/xpm
vlib activehdl/axi_lite_ipif_v3_0_4
vlib activehdl/axi_uartlite_v2_0_39
vlib activehdl/xil_defaultlib

vmap xpm activehdl/xpm
vmap axi_lite_ipif_v3_0_4 activehdl/axi_lite_ipif_v3_0_4
vmap axi_uartlite_v2_0_39 activehdl/axi_uartlite_v2_0_39
vmap xil_defaultlib activehdl/xil_defaultlib

vlog -work xpm  -sv2k12 "+incdir+D:/xilinx/2025.2/Vivado/data/rsb/busdef" -l xpm -l axi_lite_ipif_v3_0_4 -l axi_uartlite_v2_0_39 -l xil_defaultlib \
"D:/xilinx/2025.2/Vivado/data/ip/xpm/xpm_cdc/hdl/xpm_cdc.sv" \
"D:/xilinx/2025.2/Vivado/data/ip/xpm/xpm_memory/hdl/xpm_memory.sv" \

vcom -work xpm -93  \
"D:/xilinx/2025.2/Vivado/data/ip/xpm/xpm_VCOMP.vhd" \

vcom -work axi_lite_ipif_v3_0_4 -93  \
"../../../ipstatic/hdl/axi_lite_ipif_v3_0_vh_rfs.vhd" \

vcom -work axi_uartlite_v2_0_39 -93  \
"../../../ipstatic/hdl/axi_uartlite_v2_0_vh_rfs.vhd" \

vcom -work xil_defaultlib -93  \
"../../../../Vega.gen/sources_1/ip/axi_uartlite_0/sim/axi_uartlite_0.vhd" \

vlog -work xil_defaultlib \
"glbl.v"

