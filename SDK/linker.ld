/* ========================================================================== */
/* Vega SoC Linker Script                                                     */
/* CPU reset vector: 0x1000 (boot ROM)                                       */
/* Data RAM: 0x80000000 (64KB)                                                */
/* ========================================================================== */

OUTPUT_ARCH("riscv")
ENTRY(_start)

MEMORY
{
    rom (rx)  : ORIGIN = 0x1000,        LENGTH = 16K
    ram (rwx) : ORIGIN = 0x80000000,    LENGTH = 64K
}

SECTIONS
{
    /* --- Boot ROM (code + read-only data) --- */
    .text : {
        *(.text.init)
        *(.text)
        *(.text.*)
    } > rom

    .rodata : ALIGN(4) {
        *(.rodata)
        *(.rodata.*)
    } > rom

    /* .data initial values stored in ROM (LMA), copied to RAM at startup */
    _la_data = .;
    .data : AT(_la_data) {
        _data_start = .;
        *(.data)
        *(.data.*)
        _sdata = .;
        *(.sdata)
        *(.sdata.*)
        _data_end = .;
    } > ram

    /* --- Data RAM (uninitialized) --- */
    .bss (NOLOAD) : ALIGN(8) {
        _bss_start = .;
        *(.bss)
        *(.bss.*)
        *(.sbss)
        *(.sbss.*)
        *(COMMON)
        _bss_end = .;
    } > ram

    /* Stack grows downward from top of RAM */
    _sp = ORIGIN(ram) + LENGTH(ram);

    /* Global pointer (midpoint of .sdata region) */
    __global_pointer$ = MIN(_sdata + 0x800, _data_end);
}

/* Provide weak aliases for symbols used by .init / .fini */
PROVIDE(_end = .);
