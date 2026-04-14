transcript off
onbreak {quit -force}
onerror {quit -force}
transcript on

asim +access +r +m+data_ram_b  -L xil_defaultlib -L xpm -L blk_mem_gen_v8_4_12 -L unisims_ver -L unimacro_ver -L secureip -O5 xil_defaultlib.data_ram_b xil_defaultlib.glbl

do {data_ram_b.udo}

run 1000ns

endsim

quit -force
