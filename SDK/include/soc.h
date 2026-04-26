#ifndef __VEGA_SOC_H__
#define __VEGA_SOC_H__

// ============================================================================
// Vega SoC Memory Map
// ============================================================================

// Boot ROM: 16KB at 0x1000 (CPU reset vector)
#define ROM_BASE        0x0000000000001000ULL
#define ROM_SIZE        0x0000000000004000ULL    // 16KB

// Data RAM: 64KB at 0x80000000
#define RAM_BASE        0x0000000080000000ULL
#define RAM_SIZE        0x0000000000010000ULL    // 64KB
#define RAM_TOP         (RAM_BASE + RAM_SIZE)

// AXI UART Lite: 4KB at 0x60100000
#define UART_BASE       0x0000000060100000ULL
#define UART_SIZE       0x0000000000001000ULL    // 4KB

// GPIO (LED): data_addr[5:2] mapped to LED[3:0]
#define LED_BASE        0x0000000000000000ULL    // Not memory-mapped

// ============================================================================
// Clock frequency
// ============================================================================
#define CPU_CLOCK_HZ    100000000ULL             // 100 MHz

#endif // __VEGA_SOC_H__
