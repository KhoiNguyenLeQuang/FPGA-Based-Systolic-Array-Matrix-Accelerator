# FPGA-Based Systolic Array Matrix Accelerator (UART-Interface)

An implementation of a 4x4 Systolic Array architecture on a Xilinx Artix-7 FPGA (Basys 3), designed to accelerate matrix-matrix multiplication ($C = A \times B$). This project features a real-time UART interface, allowing a Host PC to stream data directly into the hardware processing grid.

## Overview
This project demonstrates the core principles of AI acceleration hardware (similar to Google TPUs). It uses a grid of **Processing Elements (PEs)** that pass data rhythmically across the chip to maximize data reuse and minimize memory access overhead.

Unlike basic simulations, this implementation is a **closed-loop system**:
1. **Host PC** sends matrix data via Python/Serial.
2. **UART Receiver** on the FPGA captures data at 115,200 Baud.
3. **Systolic Array** processes the data in a pipelined fashion.
4. **On-board LEDs** provide immediate visual debugging of the result.

## Architecture
The system is composed of several hierarchical Verilog modules:

### 1. Processing Element (PE)
The fundamental unit of the array. It performs a Multiply-Accumulate (MAC) operation: 
$C_{out} = C_{in} + (A_{in} \times B_{in})$.

### 2. NxN Systolic Array
Interconnects 16 PEs (4x4) into a mesh. 
- **Matrix A** flows horizontally (West to East).
- **Matrix B** flows vertically (North to South).
- Data is passed to neighbors every clock cycle, achieving $O(N)$ throughput.

### 3. UART Receiver (`uart_rx.v`)
A robust state-machine-based asynchronous receiver. It samples the incoming bitstream at 115,200 bits per second and converts it into 8-bit parallel bytes for the processing logic.

### 4. Top-Level System (`matrix_system_top.v`)
Integrates the UART interface with the core logic. It handles system resets and latches incoming data into the array drive registers.



## Hardware Specifications
* **FPGA:** Xilinx Artix-7 (XC7A35T-1CPG236C)
* **Board:** Digilent Basys 3
* **Clock Frequency:** 100 MHz
* **Baud Rate:** 115,200 bps
* **Input Width:** 8-bit integers
* **Accumulator Width:** 32-bit (to prevent overflow)

## File Structure
```text
├── src/
│   ├── matrix_system_top.v   # Top-level integration & I/O
│   ├── uart_rx.v             # 115,200 Baud UART receiver
│   ├── systolic_array_NxN.v  # 4x4 Mesh interconnect logic
│   └── pe.v                  # Processing Element (MAC unit)
├── constraints/
│   └── basys3.xdc            # Pin mappings (Clock, Reset, UART, LEDs)
└── host/
    └── serial_test.py        # Python script to stream data to FPGA
