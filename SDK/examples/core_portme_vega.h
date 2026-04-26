/* ========================================================================== */
/* Vega SoC — Coremark Porting Header                                        */
/* Copy this file to riscv-coremark/core_portme.h before building Coremark.  */
/* ========================================================================== */

#ifndef CORE_PORTME_H
#define CORE_PORTME_H

#include <stdint.h>

/* Vega uses mcycle CSR for timing */
#define NSECS_PER_SEC      1000000000ULL
#define CORETIMETYPE       uint64_t
#define GETMYTIME(t)      { asm volatile ("csrr %0, mcycle" : "=r" (t)); }
#define MYTIMEDIFF(fin, ini)  ((fin) - (ini))
#define TIMER_RES_DIVIDER  1
#define SAMPLE_TIME_IMPLEMENTATION 1

/* Vega has no FPU — disable floating-point in Coremark */
#define HAS_FLOAT          0
#define HAS_STDIO          0
#define HAS_PRINTF         1    /* Use Vega's UART-based ee_printf */
#define MAIN_HAS_NOARGC    1
#define MAIN_HAS_NORETURN  1

#define SEED_METHOD        SEED_VOLATILE
#define MEM_METHOD         MEM_STATIC
#define MULTITHREAD        1
#define MAIN_THREAD_ID     0

/* Override ee_printf for Vega UART */
int ee_printf(const char *fmt, ...);

/* Provide empty portable_init / portable_fini */
#define PORTABLE_INIT(t)  { /* no init needed */ }
#define PORTABLE_FINI(t)  { /* no fini needed */ }

/* Use default MAIN_TOTAL_ITERATIONS if not defined externally */
#ifndef MAIN_TOTAL_ITERATIONS
#define MAIN_TOTAL_ITERATIONS 1000
#endif

typedef uint64_t secs_ret;

#endif /* CORE_PORTME_H */
