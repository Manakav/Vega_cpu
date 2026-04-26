TOOL	:=	riscv64-unknown-elf-
CC		:=	$(TOOL)gcc
OBJCOPY	:=	$(TOOL)objcopy
OBJDUMP :=  $(TOOL)objdump

ARCH	:=	rv64imc
ABI		:=	lp64

CFLAGS	:=	-march=$(ARCH) -mabi=$(ABI) -O3 -nostdlib -static -fno-builtin-printf

.PHONY: clean all

all: start_inst.hex start_data_byte.hex dump.S

start_inst.hex: start.bin
	od -t x4 -An -w4 -v $< > $@

# Byte format hex for iverilog $readmemh
start_data_byte.hex: start.bin
	od -t x1 -An -w1 -v $< > $@

start.bin: start.elf
	$(OBJCOPY) -O binary $< $@

start.elf: start.S main.c linker.ld
	$(CC) $(CFLAGS) -T linker.ld start.S main.c -lgcc -o $@

dump.S: start.elf
	$(OBJDUMP) -D $< > $@

clean:
	rm -f start_inst.hex start_data.hex start_data_byte.hex start.bin start.elf dump.S
