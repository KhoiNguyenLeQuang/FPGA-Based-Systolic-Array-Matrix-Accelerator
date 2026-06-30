# Systolic Array GEMM Accelerator — FPGA Implementation + UVM Verification

A complete hardware/verification project for a 4×4 **systolic array** matrix multiplication accelerator. The repository contains two complementary halves:

1. **FPGA Implementation** — a real-time, UART-driven systolic array accelerator deployed on a Xilinx Artix-7 (Basys 3), where a Host PC streams matrix operands over serial and the result is visible on-board via LEDs.
2. **UVM Verification Environment** — a IEEE-1800.2 UVM testbench that exhaustively verifies the same `systolic_array_NxN` RTL core at the block level, achieving **100% functional coverage** across ~1,558 transactions with zero errors.

Together they demonstrate the full hardware lifecycle: RTL design → FPGA deployment → rigorous functional verification.

```
# KERNEL: UVM_INFO @ 233435000: uvm_test_top.env.coverage [COVERAGE]
# Total Functional Coverage: 100.00%
# UVM_INFO: 3122 | UVM_WARNING: 0 | UVM_ERROR: 0 | UVM_FATAL: 0
```

---

## Table of Contents

- [Project Overview](#project-overview)
- [Key Parameters](#key-parameters)
- [Part 1 — FPGA Implementation](#part-1--fpga-implementation)
  - [System Flow](#system-flow)
  - [Hardware Architecture](#hardware-architecture)
  - [Hardware Specifications](#hardware-specifications)
- [Part 2 — UVM Verification](#part-2--uvm-verification)
  - [Why Block-Level Verification](#why-block-level-verification)
  - [UVM Testbench Architecture](#uvm-testbench-architecture)
  - [File-by-File Reference](#file-by-file-reference)
  - [Verification Results](#verification-results)
- [Repository Structure](#repository-structure)
- [How to Run](#how-to-run)
  - [Run the FPGA Project](#run-the-fpga-project)
  - [Run the UVM Testbench](#run-the-uvm-testbench)
- [License](#license)

---

## Project Overview

This project demonstrates the core principles of AI acceleration hardware (similar to Google TPUs). It uses a grid of **Processing Elements (PEs)** that pass data rhythmically across the chip to maximize data reuse and minimize memory access overhead, performing $C = A \times B$ via a pipelined, mesh-connected array.

The same RTL core (`systolic_array_NxN`) is used in both halves of the project:

- On **real hardware**, it's wrapped by a UART receiver and matrix-loading logic so a Host PC can stream operands in and observe results on LEDs.
- In **simulation**, it's the Device Under Test (DUT) for a full UVM regression suite that drives parallel stimulus directly into the array, bypassing the UART path entirely to maximize simulation throughput.

## Key Parameters

| Parameter   | Value | Description                                |
|-------------|-------|---------------------------------------------|
| `N`         | 4     | Systolic array dimension (4×4 grid of PEs)   |
| `WIDTH`     | 8     | Input operand bit-width (unsigned 8-bit)     |
| `ACC_WIDTH` | 32    | Accumulator/output bit-width per PE          |

---

## Part 1 — FPGA Implementation

### System Flow

This is a **closed-loop system**, not a static simulation:

1. **Host PC** sends matrix data via Python/Serial.
2. **UART Receiver** on the FPGA captures data at 115,200 baud.
3. **Systolic Array** processes the data in a pipelined fashion.
4. **On-board LEDs** provide immediate visual debugging of the result.

### Hardware Architecture

The system is composed of several hierarchical Verilog modules:

#### 1. Processing Element (PE)
The fundamental unit of the array. It performs a Multiply-Accumulate (MAC) operation:

$$C_{out} = C_{in} + (A_{in} \times B_{in})$$

On `rst`, all outputs clear to zero. Otherwise, on every rising clock edge the PE accumulates the product of its two inputs into `c_out` and propagates `a_in` / `b_in` to its neighbors.

#### 2. NxN Systolic Array
Interconnects 16 PEs (4×4) into a mesh.
- **Matrix A** flows horizontally (West to East).
- **Matrix B** flows vertically (North to South).
- Data is passed to neighbors every clock cycle, achieving $O(N)$ throughput.

#### 3. UART Receiver (`uart_rx.v`)
A robust state-machine-based asynchronous receiver. It samples the incoming bitstream at 115,200 bits per second and converts it into 8-bit parallel bytes for the processing logic. A 5-state FSM (IDLE → START → DATA → STOP → CLEAN) samples bits at mid-period (`CLKS_PER_BIT = 868` at 100 MHz), raising `o_Rx_DV` for one cycle when a byte is ready.

#### 4. Top-Level System (`matrix_system_top.v`)
Integrates the UART interface with the core logic. It receives 32 bytes (matrix A) then 32 bytes (matrix B) over UART, drives the skewed input pattern into the systolic core once both matrices are loaded, asserts `done_led` when loading is complete, and exposes `debug_led[3:0]` driven from the LSBs of the result bus.

### Hardware Specifications

* **FPGA:** Xilinx Artix-7 (XC7A35T-1CPG236C)
* **Board:** Digilent Basys 3
* **Clock Frequency:** 100 MHz
* **Baud Rate:** 115,200 bps
* **Input Width:** 8-bit integers
* **Accumulator Width:** 32-bit (to prevent overflow)

---

## Part 2 — UVM Verification

### Why Block-Level Verification

This verification environment targets the `systolic_array_NxN` RTL module directly rather than the top-level UART-wrapped system. By bypassing the UART serial interface and driving parallel stimulus straight into the computational pipeline, simulation timing overhead is eliminated. This strategic isolation enabled 1,500+ high-density transactions and 100% functional coverage in a fraction of the simulation time that top-level verification would require.

The testbench validates all arithmetic, pipeline timing, data-skewing behavior, and reset recovery through a structured regression suite of four test types.

### UVM Testbench Architecture

```
tb_top (testbench.sv)
└── uvm_root
    └── gemm_all_test (all_test.sv)
        └── gemm_env (environment.sv)
            ├── gemm_agent
            │   ├── gemm_sequencer  ←── receives sequence items
            │   ├── gemm_driver     ←── drives DUT signals via vif; publishes to drv_ap
            │   └── gemm_monitor    ←── observes DUT outputs; publishes to mon_ap
            ├── gemm_scoreboard     ←── compares expected vs. actual matrix results
            └── gemm_coverage       ←── tracks functional coverage bins
```

Port connections in the connect phase:
- `driver.drv_ap` → `scoreboard.exp_fifo` (expected result side)
- `monitor.mon_ap` → `scoreboard.act_fifo` (actual result side)
- `driver.drv_ap` → `coverage.analysis_export` (coverage sampling)

### File-by-File Reference

#### `interface.sv` — `gemm_if`
A parameterised SystemVerilog interface that bundles all DUT signals into a single handle passed through `uvm_config_db`.

```
gemm_if #(N, WIDTH, ACC_WIDTH)(clk)
  - rst          : logic
  - a_in_bus     : logic [N*WIDTH-1:0]
  - b_in_bus     : logic [N*WIDTH-1:0]
  - c_out_bus    : wire  [N*N*ACC_WIDTH-1:0]
```

#### `package.sv` — `gemm_pkg`
Defines the three shared constants used across all files and `\`include`s every testbench file in dependency order:

```systemverilog
localparam N         = 4;
localparam WIDTH     = 8;
localparam ACC_WIDTH = 32;
```

Inclusion order: `sequence_item` → `driver` → `monitor` → `agent` → `scoreboard` → `coverage` → `environment` → sequences → tests → master test.

#### `testbench.sv` — `tb_top`
The top-level simulation module. It:
1. Generates a 10 ns period clock (`always #5 clk = ~clk`)
2. Instantiates `gemm_if` and connects it to `systolic_array_NxN` (the DUT)
3. Runs a power-on reset sequence (3 clock cycles with `rst = 1`)
4. Registers the virtual interface into `uvm_config_db` under the wildcard path `"*"`
5. Calls `run_test("gemm_all_test")` to launch the UVM regression
6. Enables VCD waveform dumping via `$dumpfile` / `$dumpvars`

#### `sequence_item.sv` — `gemm_seq_item`
The UVM transaction object. Carries one full matrix multiplication request and its results.

| Field           | Type                          | Role                                         |
|-----------------|-------------------------------|-----------------------------------------------|
| `matrix_A`      | `rand bit [WIDTH-1:0] [N][N]` | Randomizable 4×4 input matrix A              |
| `matrix_B`      | `rand bit [WIDTH-1:0] [N][N]` | Randomizable 4×4 input matrix B              |
| `exp_matrix_C`  | `bit [ACC_WIDTH-1:0] [N][N]`  | Software-computed reference result C = A×B   |
| `act_matrix_C`  | `bit [ACC_WIDTH-1:0] [N][N]`  | Captured hardware output from the DUT        |

**`compute_expected()`** — Implements the golden reference model using a standard triple-nested loop (O(N³)). Called immediately after randomization so the scoreboard always has the correct answer before hardware begins computation.

#### `base_sequence.sv` — `gemm_base_seq`
The foundation sequence. Runs `num_transactions` (default: 10) iterations. Each iteration:
1. Creates a new `gemm_seq_item` via the UVM factory
2. Calls `start_item()` to handshake with the sequencer
3. Randomizes `matrix_A` and `matrix_B`
4. Calls `item.compute_expected()` to pre-compute the reference answer
5. Calls `finish_item()` to deliver the item to the driver

#### `driver.sv` — `gemm_driver`
Translates software transaction objects into physical signal waveforms on the DUT interface.

**`build_phase()`** — Creates the `drv_ap` analysis port and retrieves the virtual interface from `uvm_config_db`.

**`run_phase()`** — The main driver loop:
1. Asserts reset and zeroes the input buses on startup
2. Waits for `negedge rst` before entering the active loop
3. For each item from `seq_item_port.get_next_item()`: calls `compute_expected()`, broadcasts the item via `drv_ap` (so the scoreboard and coverage receive the expected answer), calls `drive_transaction()`, then toggles reset for 2 cycles to flush the PE accumulators, and finally calls `item_done()`

**`drive_transaction(item)`** — Implements the **data-skewing** algorithm required by systolic arrays. Over `(2×N − 1)` clock cycles it staggers each lane's data by one cycle relative to the previous lane (`col_idx = t − lane`). After the skewing phase it drives zero for `N` additional cycles to flush the pipeline, matching the hardware's propagation latency exactly.

#### `monitor.sv` — `gemm_monitor`
A passive observer that captures the DUT's output without driving any signals.

**`build_phase()`** — Creates `mon_ap` and retrieves the virtual interface.

**`run_phase()`** — Continuously polls the input buses. When it detects non-zero activity (`a_in_bus !== '0 || b_in_bus !== '0`), it waits exactly `(3×N − 2)` clock cycles — the precise pipeline latency of the N×N array — then samples `c_out_bus`. It unpacks the flat 512-bit bus into a 4×4 array stored in `act_matrix_C`, broadcasts the item via `mon_ap`, then waits 4 cooldown cycles to skip the driver's reset pulse before resuming observation.

#### `scoreboard.sv` — `gemm_scoreboard`
The verification correctness checker. Uses two `uvm_tlm_analysis_fifo` queues to decouple timing between the driver and monitor:

- `exp_fifo` — receives items (with pre-computed expected results) from `driver.drv_ap`
- `act_fifo` — receives items (with captured hardware output) from `monitor.mon_ap`

**`run_phase()`** — Runs a `fork...join_any` construct with two parallel branches:

- **Branch 1 (checker):** Continuously calls `exp_fifo.get()` and `act_fifo.get()` in tandem, waits `#1ps` for delta-cycle stability, skips comparison if `rst` is high, then performs element-wise comparison across all N×N cells. Reports `UVM_ERROR` with row/column coordinates on any mismatch; logs `PASS` on a full match.

- **Branch 2 (reset watcher):** Blocks on `@(posedge vif.rst)`. If reset fires, this branch wins the `join_any`, kills Branch 1 via `disable fork`, flushes both FIFOs (to discard stale in-flight transactions), then waits for `negedge rst` and flushes again before the outer loop restarts.

#### `coverage.sv` — `gemm_coverage`
A `uvm_subscriber` that samples input operand values to track functional coverage.

**`gemm_cg` covergroup** (sampled with `function sample(bit[7:0] a, bit[7:0] b)`):

| Coverpoint | Bins                                                                       | Purpose                                       |
|------------|-----------------------------------------------------------------------------|------------------------------------------------|
| `cp_a`     | `zero={0}`, `low={1:63}`, `mid={64:191}`, `hi={192:254}`, `max_val={255}` | Tracks value range of A inputs                 |
| `cp_b`     | Same 5 bins                                                                | Tracks value range of B inputs                 |
| `cp_cross` | Cross of `cp_a × cp_b` = 25 combinations                                  | Ensures all input-range pairs are exercised    |

**`write(t)`** — Called automatically by the UVM subscriber mechanism whenever `drv_ap` publishes an item. Samples every element of `matrix_A` and `matrix_B` (all 16 pairs) into `gemm_cg`.

**`report_phase()`** — Prints the final aggregate coverage percentage at the end of simulation.

#### `environment.sv` — `gemm_env`
The UVM environment container. Instantiates and connects all sub-components.

**`build_phase()`** — Creates `agent`, `scoreboard`, and `coverage` via the UVM factory.

**`connect_phase()`** — Wires analysis ports:
- `agent.driver.drv_ap` → `scoreboard.exp_fifo.analysis_export`
- `agent.monitor.mon_ap` → `scoreboard.act_fifo.analysis_export`
- `agent.driver.drv_ap` → `coverage.analysis_export`

#### `base_test.sv` — `gemm_base_test`
The parent class for all test classes. Creates the `gemm_env` in `build_phase()` and runs 10 random transactions via `gemm_base_seq` in `run_phase()`. All other tests extend this class and override only `run_phase()`.

#### `corner_test.sv` — `gemm_corner_seq` + `gemm_corner_test`
Sends exactly 3 hand-crafted transactions designed to stress boundary conditions:

| Case               | Matrix A         | Matrix B                   | Mathematical goal                                                   |
|--------------------|------------------|------------------------------|------------------------------------------------------------------------|
| All-Zeros × Max    | All `0x00`       | All `0xFF`                  | Verify zero-result path; accumulator should stay 0                    |
| Max × Max          | All `0xFF`       | All `0xFF`                  | Verify 32-bit accumulators don't overflow (max = 255²×4 = 260,100)    |
| Identity × Pattern | Identity (`I₄`)  | Incrementing (0…15 scaled)  | Result must equal B exactly: I × B = B                                |

`gemm_corner_test` extends `gemm_base_test`, runs the corner sequence, then waits 30 clock cycles for the pipeline to fully drain before dropping its objection.

#### `rand_test.sv` — `gemm_rand_test`
Extends `gemm_base_test` and overrides `run_phase()` to run `gemm_base_seq` with `num_transactions = 500`, applying fully randomized 8-bit values to all 32 matrix elements per transaction.

#### `stress_test.sv` — `gemm_stress_seq` + `gemm_stress_test`
The highest-intensity test, designed to guarantee 100% cross-coverage while also verifying back-to-back throughput.

**Phase 1 — Targeted cross-coverage (25 transactions):** A double loop over 5 representative values (`0, 32, 100, 200, 255`) — one per coverage bin — generates every combination of `cp_a × cp_b`. All 16 cells of each matrix are forced to the same value, guaranteeing all 25 cross-bins are hit.

**Phase 2 — Back-to-back stress (1,000 transactions):** Fully randomized transactions driven without any inter-transaction gap, verifying the pipeline handles continuous load without accumulator carry-over between matrices.

`gemm_stress_test` runs the sequence, then waits an additional 30 drain cycles before querying and printing the final coverage percentage.

#### `reset_test.sv` — `gemm_reset_seq` + `gemm_reset_test`
Verifies correct hardware behavior when reset is asserted mid-computation.

`gemm_reset_test.run_phase()` forks two threads:
- **Stimulus thread:** Runs `gemm_base_seq` with 40 transactions
- **Reset thread:** After 15 clock cycles (mid-compute), asserts `vif.rst = 1` for 5 cycles, then de-asserts it

`join_any` + `disable fork` terminates whichever thread is still running once the reset fires. A **recovery phase** then runs 10 clean transactions to confirm the accumulators were zeroed correctly by the reset and produce valid results again.

`gemm_reset_seq` is a nested sequence variant that can also be embedded inside the master regression (used by `gemm_all_test`).

#### `all_test.sv` — `gemm_all_test` (Master Regression Test)
Runs all four test suites sequentially in a single simulation and prints a coverage snapshot after each phase:

| Phase     | Sequence Used     | Transactions | Purpose                              |
|-----------|--------------------|--------------|----------------------------------------|
| Test 1    | `gemm_corner_seq`  | 3            | Boundary conditions                    |
| Test 2    | `gemm_base_seq`    | 500          | Broad random coverage                  |
| Test 3    | `gemm_stress_seq`  | 1,025        | Cross-coverage + back-to-back stress   |
| Test 4    | `gemm_reset_seq`   | 30           | Reset robustness and recovery          |
| **Total** |                    | **~1,558**   | **100.00% functional coverage**        |

Between each test phase, 30 drain cycles are inserted to allow the pipeline to flush completely before coverage is sampled.

#### `tb_smoke.v` — Standalone Smoke Test
A lightweight, UVM-free Verilog testbench for rapid sanity checking. Instantiates `systolic_array_NxN` directly and manually drives a skewed identity-matrix × all-2s test, then prints four output cells and compares them to the expected value of `2`. Used for quick compilation and waveform checks before running the full UVM suite.

### Verification Results

| Metric                    | Result           |
|---------------------------|-------------------|
| Total Functional Coverage | **100.00%**      |
| Total Transactions        | ~1,558            |
| UVM_ERROR                 | **0**            |
| UVM_WARNING               | 0                 |
| UVM_FATAL                 | 0                 |
| Simulation Time           | 233,435 ns        |
| Coverage Database         | `fcover.acdb`     |

Coverage was achieved by combining:
- **Corner cases** to hit the `zero` and `max_val` bins
- **Random test** to populate `low`, `mid`, and `hi` bins organically
- **Targeted stress phase** to exhaustively hit all 25 cross-coverage combinations

---

## Repository Structure

```text
├── src/
│   ├── matrix_system_top.v     # FPGA top-level integration & I/O
│   ├── uart_rx.v                # 115,200 baud UART receiver
│   ├── systolic_array_NxN.v     # 4x4 mesh interconnect logic
│   └── pe.v                     # Processing Element (MAC unit)
├── constraints/
│   └── basys3.xdc               # Pin mappings (Clock, Reset, UART, LEDs)
├── host/
│   └── serial_test.py           # Python script to stream data to FPGA
├── verification/
│   ├── design.sv                # RTL design under test (DUT) used by the UVM env
│   ├── tb_smoke.v                # Standalone smoke testbench (no UVM)
│   └── Testbench/
│       ├── package.sv            # UVM package — ties all files together
│       ├── interface.sv          # SystemVerilog interface (signal bundle)
│       ├── testbench.sv          # Top-level simulation module (tb_top)
│       ├── sequence_item.sv      # Transaction data object (gemm_seq_item)
│       ├── base_sequence.sv      # Base randomized sequence
│       ├── driver.sv             # UVM driver with systolic data-skewing
│       ├── monitor.sv            # UVM monitor with pipeline latency handling
│       ├── scoreboard.sv         # Reference model comparator + reset handling
│       ├── coverage.sv           # Functional coverage collector
│       ├── environment.sv        # UVM environment (wires all components)
│       ├── base_test.sv          # Base test (parent for all other tests)
│       ├── corner_test.sv        # Corner-case sequence + test
│       ├── rand_test.sv          # 500-transaction random test
│       ├── stress_test.sv        # 1,025-transaction targeted + stress test
│       ├── reset_test.sv         # Mid-compute hardware reset test
│       └── all_test.sv           # Master regression test (runs all 4 suites)
└── README.md
```

> **Note:** The verification environment's `design.sv` is a self-contained copy of the same core RTL (`pe`, `systolic_array_NxN`, `uart_rx`, `matrix_system_top`) used by the FPGA `src/` files, packaged for simulator convenience (e.g. EDA Playground).

---

## How to Run

### Run the FPGA Project

1. Synthesize and implement the design in Vivado, targeting the Basys 3 (XC7A35T-1CPG236C) with `constraints/basys3.xdc`.
2. Program the bitstream onto the board.
3. Run the host-side script to stream matrices over serial:

```bash
python host/serial_test.py
```

4. Observe `done_led` and `debug_led[3:0]` on the board for status and result LSBs.

### Run the UVM Testbench

This project targets the Questa/ModelSim simulator (compatible with EDA Playground).

```bash
# Compile
vlog -sv verification/design.sv verification/Testbench/testbench.sv

# Simulate
vsim -c tb_top -do "run -all; quit"
```

For functional coverage database output:

```bash
vsim -c tb_top -coverage -do "run -all; coverage save fcover.acdb; quit"
```

---

## License

Add your preferred license here (e.g. MIT).
