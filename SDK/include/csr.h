#ifndef __VEGA_CSR_H__
#define __VEGA_CSR_H__

// ============================================================================
// RISC-V Machine-Level CSR Addresses (RV64)
// ============================================================================

// Machine Information Registers
#define CSR_MVENDORID   0xF11
#define CSR_MARCHID     0xF12
#define CSR_MIMPID      0xF13
#define CSR_MHARTID     0xF14

// Machine Trap Setup
#define CSR_MSTATUS     0x300
#define CSR_MISA        0x301
#define CSR_MIE         0x304
#define CSR_MTVEC       0x305

// Machine Trap Handling
#define CSR_MSCRATCH    0x340
#define CSR_MEPC        0x341
#define CSR_MCAUSE      0x342
#define CSR_MTVAL       0x343
#define CSR_MIP         0x344

// Machine Counter / Timer
#define CSR_MCYCLE      0xB00
#define CSR_MTIME       0xB01
#define CSR_MTIMECMP    0xB02
#define CSR_MINSTRET    0xB02

// mstatus bit fields
#define MSTATUS_MIE     0x0000000000000008ULL
#define MSTATUS_MPIE    0x0000000000000080ULL
#define MSTATUS_MPP     0x0000000000001800ULL
#define MSTATUS_FS      0x0000000000006000ULL
#define MSTATUS_XS      0x0000000000018000ULL
#define MSTATUS_MPRV    0x0000000000020000ULL

// mie / mip bit fields
#define MIP_SSI         0x0000000000000001ULL
#define MIP_MSI         0x0000000000000008ULL
#define MIP_STI         0x0000000000000020ULL
#define MIP_MTI         0x0000000000000080ULL
#define MIP_SEI         0x0000000000000100ULL
#define MIP_MEI         0x0000000000000800ULL

// Machine trap causes
#define MCAUSE_ECALL    0x000000000000000BULL
#define MCAUSE_EBREAK   0x0000000000000003ULL

// Helper macros for CSR read/write
#define csr_read(r)     ({ uint64_t __v; \
    asm volatile ("csrr %0, %1" : "=r" (__v) : "i" (r)); __v; })

#define csr_write(r, v) ({ \
    asm volatile ("csrw %0, %1" :: "i" (r), "r" (v)); })

#define csr_set(r, v)   ({ \
    asm volatile ("csrs %0, %1" :: "i" (r), "r" (v)); })

#define csr_clear(r, v) ({ \
    asm volatile ("csrc %0, %1" :: "i" (r), "r" (v)); })

#endif // __VEGA_CSR_H__
