// ============================================================================
// AXI UART Lite Driver for Vega SoC
// ============================================================================

#include "uart.h"
#include "../include/soc.h"

#define reg32(addr)     (*(volatile uint32_t *)(addr))

static inline uint32_t uart_read(int offset) {
    return reg32(UART_BASE + offset);
}

static inline void uart_write(int offset, uint32_t val) {
    reg32(UART_BASE + offset) = val;
}

void uart_init(void) {
    uart_write(UART_CONTROL, CR_RST_TX | CR_RST_RX);
    uart_write(UART_CONTROL, 0);
}

void uart_putc(char c) {
    while (uart_read(UART_STATUS) & SR_TX_FIFO_FULL);
    uart_write(UART_TX_FIFO, (uint8_t)c);
}

void uart_puts(const char *s) {
    while (*s) {
        if (*s == '\n') uart_putc('\r');
        uart_putc(*s++);
    }
}

void uart_puthex(uint64_t x) {
    char buf[19];
    int i;
    buf[0] = '0'; buf[1] = 'x';
    for (i = 0; i < 16; i++) {
        uint8_t nib = (x >> (60 - i * 4)) & 0xF;
        buf[2 + i] = nib < 10 ? '0' + nib : 'a' + nib - 10;
    }
    buf[18] = 0;
    uart_puts(buf);
}

void uart_putdec(int64_t x) {
    char buf[24];
    int idx = 0;
    if (x < 0) {
        uart_putc('-');
        x = -x;
    }
    if (x == 0) {
        uart_putc('0');
        return;
    }
    while (x) {
        buf[idx++] = '0' + (x % 10);
        x /= 10;
    }
    while (idx) uart_putc(buf[--idx]);
}

int uart_rx_ready(void) {
    return (uart_read(UART_STATUS) & SR_RX_FIFO_VALID) != 0;
}

char uart_getc(void) {
    return (char)uart_read(UART_RX_FIFO);
}

void uart_flush(void) {
    while (!(uart_read(UART_STATUS) & SR_TX_FIFO_EMPTY));
}
