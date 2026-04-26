// ============================================================================
// Vega CPU Bootloader — crt0.S
// Reset vector at 0x1000
// ============================================================================

.section .text.init
.globl _start

_start:
    // Clear all general-purpose registers (x1..x31)
    li  x1,  0;  li  x2,  0;  li  x3,  0;  li  x4,  0
    li  x5,  0;  li  x6,  0;  li  x7,  0;  li  x8,  0
    li  x9,  0;  li  x10, 0;  li  x11, 0;  li  x12, 0
    li  x13, 0;  li  x14, 0;  li  x15, 0;  li  x16, 0
    li  x17, 0;  li  x18, 0;  li  x19, 0;  li  x20, 0
    li  x21, 0;  li  x22, 0;  li  x23, 0;  li  x24, 0
    li  x25, 0;  li  x26, 0;  li  x27, 0;  li  x28, 0
    li  x29, 0;  li  x30, 0;  li  x31, 0

    // Set global pointer (gp) to .sdata section
.option push
.option norelax
    la  gp, __global_pointer$
.option pop

    // Set stack pointer (sp) to top of data RAM
    la  sp, _sp

    // Copy .data section from ROM (LMA) to RAM (VMA)
    //   _la_data = start of .data in ROM
    //   _data_start = runtime address of .data in RAM
    //   _data_end = end of .data in RAM
    la  t0, _la_data
    la  t1, _data_start
    la  t2, _data_end
    beq t0, t1, 2f              // skip if LMA == VMA
1:
    lw  t3, 0(t0)
    sw  t3, 0(t1)
    addi t0, t0, 4
    addi t1, t1, 4
    blt t1, t2, 1b
2:

    // Zero .bss section
    la  t0, _bss_start
    la  t1, _bss_end
    beq t0, t1, 4f
3:
    sw  zero, 0(t0)
    addi t0, t0, 4
    blt t0, t1, 3b
4:

    // Zero .sbss section
    la  t0, _sbss_start
    la  t1, _sbss_end
    beq t0, t1, 6f
5:
    sw  zero, 0(t0)
    addi t0, t0, 4
    blt t0, t1, 5b
6:

    // Call main (with argc=0, argv=NULL)
    li  a0, 0
    li  a1, 0
    jal main

    // On return, loop forever
1:
    j 1b
