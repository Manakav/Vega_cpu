// ============================================================================
// Vega SoC — Hello World Example
// Prints the Vega ASCII art logo via UART, then dumps mcycle/mtime CSRs.
// ============================================================================

#include <stdint.h>
#include "soc.h"
#include "uart.h"
#include "csr.h"

int main(void) {
    uart_init();

    uart_puts("\r\n");
    uart_puts("              vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv\r\n");
    uart_puts("                  vvvvvvvvvvvvvvvvvvvvvvvvvvvv\r\n");
    uart_puts("rrrrrrrrrrrrr       vvvvvvvvvvvvvvvvvvvvvvvvvv\r\n");
    uart_puts("rrrrrrrrrrrrrrrr      vvvvvvvvvvvvvvvvvvvvvvvv\r\n");
    uart_puts("rrrrrrrrrrrrrrrrrr    vvvvvvvvvvvvvvvvvvvvvvvv\r\n");
    uart_puts("rrrrrrrrrrrrrrrrrr    vvvvvvvvvvvvvvvvvvvvvvvv\r\n");
    uart_puts("rrrrrrrrrrrrrrrrrr    vvvvvvvvvvvvvvvvvvvvvvvv\r\n");
    uart_puts("rrrrrrrrrrrrrrrr      vvvvvvvvvvvvvvvvvvvvvv  \r\n");
    uart_puts("rrrrrrrrrrrrr       vvvvvvvvvvvvvvvvvvvvvv    \r\n");
    uart_puts("rr                vvvvvvvvvvvvvvvvvvvvvv      \r\n");
    uart_puts("rr            vvvvvvvvvvvvvvvvvvvvvvvv      rr\r\n");
    uart_puts("rrrr      vvvvvvvvvvvvvvvvvvvvvvvvvv      rrrr\r\n");
    uart_puts("rrrrrr      vvvvvvvvvvvvvvvvvvvvvv      rrrrrr\r\n");
    uart_puts("rrrrrrrr      vvvvvvvvvvvvvvvvvvvv      rrrrrrrr\r\n");
    uart_puts("rrrrrrrrrr      vvvvvvvvvvvvvvvvvv      rrrrrrrrrr\r\n");
    uart_puts("rrrrrrrrrrrr      vvvvvvvvvvvvvv      rrrrrrrrrrrr\r\n");
    uart_puts("rrrrrrrrrrrrrr      vvvvvv      rrrrrrrrrrrrrr\r\n");
    uart_puts("rrrrrrrrrrrrrrrr      vv      rrrrrrrrrrrrrrrr\r\n");
    uart_puts("rrrrrrrrrrrrrrrrrr          rrrrrrrrrrrrrrrrrr\r\n");
    uart_puts("rrrrrrrrrrrrrrrrrrrr      rrrrrrrrrrrrrrrrrrrr\r\n");
    uart_puts("rrrrrrrrrrrrrrrrrrrrrr  rrrrrrrrrrrrrrrrrrrrrr\r\n");
    uart_puts("\r\n");
    uart_puts("       INSTRUCTION SETS WANT TO BE FREE\r\n");
    uart_puts("\r\n");

    // Report system info
    uint64_t cycle = csr_read(CSR_MCYCLE);
    uint64_t time  = csr_read(CSR_MTIME);

    uart_puts("mcycle = ");
    uart_puthex(cycle);
    uart_puts("\r\n");

    uart_puts("mtime  = ");
    uart_puthex(time);
    uart_puts("\r\n");

    // Simple performance: read mcycle in a delay loop
    uint64_t start = csr_read(CSR_MCYCLE);
    volatile uint64_t delay = 0;
    for (int i = 0; i < 1000; i++) {
        delay += 1;
    }
    uint64_t elapsed = csr_read(CSR_MCYCLE) - start;

    uart_puts("1000 empty iterations: ");
    uart_putdec(elapsed);
    uart_puts(" cycles\r\n");

    uart_puts("CPU clock: ");
    uart_putdec(CPU_CLOCK_HZ);
    uart_puts(" Hz\r\n");

    uart_flush();
    return 0;
}
