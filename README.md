# FPGA-Based Systolic Array Matrix Accelerator

![Language]: Verilog 
![Platform]: Xilinx Artix-7 FPGA (Basys 3)

## 🚀 Overview
This project implements a **Systolic Array Architecture** on an FPGA to accelerate dense matrix multiplication operations ($C = C + A \times B$). Unlike traditional CPU architectures that fetch data sequentially, this design utilizes **parallel Processing Elements (PEs)** and a rhythmic data flow to maximize data reuse and throughput.

This architecture is fundamental to modern AI Accelerators (e.g., Google TPU, NVIDIA Tensor Cores) for Deep Learning inference.

## 🧠 Architecture
The core is a **2x2 Systolic Array** (scalable to NxN) composed of interconnected Processing Elements (PEs).

* **Processing Element (PE):** Performs Multiply-Accumulate (MAC) operations and forwards data to neighbors (Right/Down) in a pipelined fashion.
* **Data Flow:** Matrix A flows horizontally (Left-to-Right), Matrix B flows vertically (Top-to-Bottom).
* **Skewing:** Input data is skewed in time to ensure correct intersection at PEs without pipeline stalls.

## 🛠️ Key Features
* **Fully Pipelined Design:** Achieves O(N) throughput for NxN matrix multiplication.
* **Localized Interconnects:** Minimizes long wire delays, allowing for high clock frequencies.
* **Self-Checking Hardware:** Includes an on-chip verification module that compares computed results against a Golden Model and outputs status via LEDs.
* **Zero-Overhead Control:** State machine-based data feeder requires minimal logic resources.

## 📂 File Structure
```text
├── src/
│   ├── pe.v               # Processing Element (MAC Unit)
│   ├── systolic_array.v   # Array Interconnect Logic
│   └── matrix_top.v       # Top module with Self-Checking Logic
├── constraints/
│   └── basys3.xdc         # Constraints file for Artix-7
├── sim/
│   └── tb_systolic.v      # Testbench for behavioral simulation
└── README.md
