/*
 * matmul_bench.c — CPU baseline for the 4x4 systolic array accelerator
 *
 * Measures how long one CPU core takes to compute C = A x B for 4x4 matrices
 * with the SAME data types as the FPGA design (uint8 inputs, uint32 accumulators),
 * then compares it with the systolic array's measured 11 cycles per matmul @ 100 MHz.
 *
 * Build & run (Linux/macOS, or Windows with MinGW/WSL):
 *     gcc -O3 -march=native matmul_bench.c -o matmul_bench
 *     ./matmul_bench 2.1          <- argument = your CPU's base clock in GHz
 *
 * Also try -O0 and -O2 to see how much the compiler matters.
 */
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <time.h>

#define N        4
#define SETS     1024          /* distinct random matrix pairs, cycled through */
#define REPS     2000000L      /* total matmuls timed */

/* FPGA numbers (from simulation of systolic_array_NxN) */
#define FPGA_CYCLES_PER_MATMUL 11.0   /* 10 compute (3N-2) + 1 reset cycle */
#define FPGA_CLOCK_HZ          100e6

static uint8_t  A[SETS][N][N], B[SETS][N][N];
static volatile uint32_t sink;        /* stops the compiler deleting the work */

/* Same math as the hardware: 8-bit x 8-bit products into 32-bit sums.
 * noinline so each call is a real, complete 4x4 multiply.            */
__attribute__((noinline))
static void matmul4(const uint8_t a[N][N], const uint8_t b[N][N], uint32_t c[N][N])
{
    for (int i = 0; i < N; i++)
        for (int j = 0; j < N; j++) {
            uint32_t s = 0;
            for (int k = 0; k < N; k++)
                s += (uint32_t)a[i][k] * b[k][j];
            c[i][j] = s;
        }
}

static double now_ns(void)
{
    struct timespec t;
    clock_gettime(CLOCK_MONOTONIC, &t);
    return t.tv_sec * 1e9 + t.tv_nsec;
}

int main(int argc, char **argv)
{
    double cpu_ghz = (argc > 1) ? atof(argv[1]) : 2.1;

    srand(1);
    for (int r = 0; r < SETS; r++)
        for (int i = 0; i < N; i++)
            for (int j = 0; j < N; j++) {
                A[r][i][j] = rand() & 0xFF;
                B[r][i][j] = rand() & 0xFF;
            }

    /* sanity check against a known case: I x B = B */
    uint8_t I[N][N] = {{1,0,0,0},{0,1,0,0},{0,0,1,0},{0,0,0,1}};
    uint32_t C[N][N];
    matmul4(I, B[0], C);
    for (int i = 0; i < N; i++)
        for (int j = 0; j < N; j++)
            if (C[i][j] != B[0][i][j]) { printf("self-check FAILED\n"); return 1; }

    /* warm-up, then timed loop */
    for (long r = 0; r < 100000; r++) matmul4(A[r % SETS], B[r % SETS], C);
    double t0 = now_ns();
    for (long r = 0; r < REPS; r++) {
        matmul4(A[r % SETS], B[r % SETS], C);
        sink += C[r & 3][0];
    }
    double ns_cpu = (now_ns() - t0) / REPS;

    const double ops = 2.0 * N * N * N;          /* 64 MACs = 128 ops (mul + add) */
    double ns_fpga   = FPGA_CYCLES_PER_MATMUL / FPGA_CLOCK_HZ * 1e9;
    double cpu_cyc   = ns_cpu * cpu_ghz;         /* cycles at base clock */
    double cpu_opc   = ops / cpu_cyc;
    double fpga_opc  = ops / FPGA_CYCLES_PER_MATMUL;

    printf("                     time/matmul   GOPS    ops/clock\n");
    printf("CPU  (%.2f GHz)      %8.1f ns   %5.2f   %6.2f\n", cpu_ghz, ns_cpu, ops / ns_cpu, cpu_opc);
    printf("FPGA (100 MHz)       %8.1f ns   %5.2f   %6.2f\n", ns_fpga, ops / ns_fpga, fpga_opc);
    printf("\nWall-clock: FPGA is %.2fx the speed of the CPU\n", ns_cpu / ns_fpga);
    printf("Per clock : FPGA does %.2fx more ops per cycle\n", fpga_opc / cpu_opc);
    printf("(Per-clock uses the BASE clock; with turbo boost the CPU runs more cycles,\n"
           " so the real per-clock ratio is at least this large.)\n");
    return 0;
}
