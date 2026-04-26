# ============================================================================
# Vega SoC SDK — Build System
# Target: RV64IMC, boot ROM at 0x1000, data RAM at 0x80000000
# ============================================================================

TOOL		:=	riscv64-unknown-elf-
CC			:=	$(TOOL)gcc
OBJCOPY		:=	$(TOOL)objcopy
OBJDUMP		:=	$(TOOL)objdump
SIZE		:=	$(TOOL)size

ARCH		:=	rv64imc_zicsr
ABI			:=	lp64

CFLAGS		:=	-march=$(ARCH) -mabi=$(ABI) -Os -nostdlib -static
CFLAGS		+=	-fno-builtin-printf -fno-stack-protector -nostartfiles
CFLAGS		+=	-Iinclude -Idrivers -ffreestanding

LDFLAGS		:=	-T linker.ld -lgcc

SRCDIR		:=	.
DRVDIR		:=	drivers
EXAMPDIR	:=	examples
BUILDDIR	:=	build

# Default target: build hello
.DEFAULT_GOAL := all

.PHONY: all clean hello coremark coe dump

# --- Detection of toolchain ---
ifeq (, $(shell which $(CC)))
$(warning RISC-V toolchain not found! Install with:)
$(warning   sudo apt-get install gcc-riscv64-unknown-elf)
$(warning Or download from: https://github.com/riscv-collab/riscv-gnu-toolchain)
endif

# --- Build rules ---
all: hello

hello: $(BUILDDIR)/hello.elf $(BUILDDIR)/hello.bin $(BUILDDIR)/hello.coe
coremark: $(BUILDDIR)/coremark.elf $(BUILDDIR)/coremark.bin $(BUILDDIR)/coremark.coe

# Create build directory
$(BUILDDIR):
	mkdir -p $(BUILDDIR)

# --- Assembled startup code ---
$(BUILDDIR)/crt0.o: crt0.S | $(BUILDDIR)
	$(CC) $(CFLAGS) -c $< -o $@

# --- UART driver ---
$(BUILDDIR)/uart.o: $(DRVDIR)/uart.c $(DRVDIR)/uart.h include/soc.h | $(BUILDDIR)
	$(CC) $(CFLAGS) -c $< -o $@

# --- Example: hello ---
$(BUILDDIR)/hello.elf: $(BUILDDIR)/crt0.o $(BUILDDIR)/uart.o $(EXAMPDIR)/hello.c
	$(CC) $(CFLAGS) $(LDFLAGS) $^ -o $@

$(BUILDDIR)/hello.bin: $(BUILDDIR)/hello.elf
	$(OBJCOPY) -O binary $< $@

$(BUILDDIR)/hello.coe: $(BUILDDIR)/hello.bin
	$(OBJCOPY) -O binary --change-addresses=-0x1000 $< $@.tmp 2>/dev/null; \
	hexdump -v -e '/4 "0x%08X\n"' $< | sed '1i memory_initialization_radix=16;\nmemory_initialization_vector=' > $@

# --- Example: coremark (assumes source files in riscv-coremark/) ---
COREMARK_SRC := $(wildcard ../riscv-coremark/core_*.c ../riscv-coremark/core_*.h)
COREMARK_OBJ := $(patsubst %.c, $(BUILDDIR)/%.o, $(notdir $(COREMARK_SRC)))

ifeq ($(COREMARK_SRC),)
$(BUILDDIR)/coremark.elf:
	@echo "Coremark sources not found in ../riscv-coremark/"
	@echo "Download from: https://github.com/eembc/coremark"
	@exit 1
else
$(BUILDDIR)/coremark.o: ../riscv-coremark/core_main.c ../riscv-coremark/core_portme.h | $(BUILDDIR)
	$(CC) $(CFLAGS) -I../riscv-coremark -c $< -o $@

../riscv-coremark/core_portme.o: ../riscv-coremark/core_portme.c ../riscv-coremark/core_portme.h | $(BUILDDIR)
	$(CC) $(CFLAGS) -I../riscv-coremark -c $< -o $@

COREMARK_OBJS := $(BUILDDIR)/crt0.o $(BUILDDIR)/uart.o ../riscv-coremark/core_portme.o $(BUILDDIR)/coremark.o

$(BUILDDIR)/coremark.elf: $(COREMARK_OBJS) linker.ld
	$(CC) $(CFLAGS) $(LDFLAGS) $(COREMARK_OBJS) -lgcc -o $@

$(BUILDDIR)/coremark.bin: $(BUILDDIR)/coremark.elf
	$(OBJCOPY) -O binary $< $@

$(BUILDDIR)/coremark.coe: $(BUILDDIR)/coremark.bin
	hexdump -v -e '/4 "0x%08X\n"' $< | sed '1i memory_initialization_radix=16;\nmemory_initialization_vector=' > $@
endif

# --- Utilities ---
# Disassembly dump
dump: $(BUILDDIR)/hello.elf
	$(OBJDUMP) -D $< > $(BUILDDIR)/hello.dump
	@echo "Dump written to $(BUILDDIR)/hello.dump"

# Generate COE from existing start.bin in test directory
coe: ../test/workbench/soft/start.bin
	hexdump -v -e '/4 "0x%08X\n"' $< | sed '1i memory_initialization_radix=16;\nmemory_initialization_vector=' > $(BUILDDIR)/start.coe
	@echo "COE written to $(BUILDDIR)/start.coe"

# Print section sizes
size: $(BUILDDIR)/hello.elf
	$(SIZE) $<
	$(OBJDUMP) -h $<

clean:
	rm -rf $(BUILDDIR)
