# Vega SoC Build Scripts

## Converting .bin to .coe (for boot_rom IP)

```bash
# Method 1: raw hex dump
hexdump -v -e '/4 "0x%08X\n"' hello.bin | \
    sed '1i memory_initialization_radix=16;\nmemory_initialization_vector=' > hello.coe

# Method 2: using objcopy (adjusts address offset)
riscv64-unknown-elf-objcopy -O binary --change-addresses=-0x1000 hello.elf /tmp/adj.bin
hexdump -v -e '/4 "0x%08X\n"' /tmp/adj.bin | \
    sed '1i memory_initialization_radix=16;\nmemory_initialization_vector=' > hello.coe
```

Then replace `test/workbench/soft/start_inst.coe` with the generated `.coe` and regenerate the boot_rom IP in Vivado.

## Updating bitstream

```tcl
# In Vivado Tcl:
update_compile_order -fileset sources_1
reset_run synth_1
launch_runs synth_1 -jobs 4
wait_on_run synth_1
launch_runs impl_1 -jobs 4
wait_on_run impl_1
write_bitstream -force Vega.runs/impl_1/vega_soc_top.bit
```
