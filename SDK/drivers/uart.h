#ifndef __VEGA_UART_H__
#define __VEGA_UART_H__

// ============================================================================
// AXI UART Lite Driver for Vega SoC
// Base address: 0x60100000
// Baud rate: 9600 (configurable in IP), 8N1
// ============================================================================

#include <stdint.h>

// Register offsets
#define UART_RX_FIFO    0x00
#define UART_TX_FIFO    0x04
#define UART_STATUS     0x08
#define UART_CONTROL    0x0C

// Status register bits
#define SR_TX_FIFO_FULL     (1 << 3)
#define SR_TX_FIFO_EMPTY    (1 << 2)
#define SR_RX_FIFO_FULL     (1 << 1)
#define SR_RX_FIFO_VALID    (1 << 0)

// Control register bits
#define CR_RST_TX       0x01
#define CR_RST_RX       0x02

// Initialize UART (reset FIFOs)
void uart_init(void);

// Send a single character (blocking)
void uart_putc(char c);

// Send a null-terminated string (blocking)
void uart_puts(const char *s);

// Send a 64-bit hex value with "0x" prefix
void uart_puthex(uint64_t x);

// Send a 64-bit decimal value
void uart_putdec(int64_t x);

// Check if receive data is available
int uart_rx_ready(void);

// Read a single character (non-blocking, returns 0 if no data)
char uart_getc(void);

// Flush - wait until TX FIFO is empty
void uart_flush(void);

#endif // __VEGA_UART_H__
