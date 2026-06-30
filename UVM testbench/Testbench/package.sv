package gemm_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"
 
    localparam N         = 4;
    localparam WIDTH     = 8;
    localparam ACC_WIDTH = 32;
 
    // Infrastructure
    `include "sequence_item.sv"
    `include "driver.sv"
    `include "monitor.sv"
    `include "agent.sv"
    `include "scoreboard.sv"
    `include "coverage.sv"
    `include "environment.sv"
 
    // Sequences
    `include "base_sequence.sv"
 
    // Tests
    `include "base_test.sv"
    `include "corner_test.sv"
    `include "rand_test.sv"
    `include "stress_test.sv"
    `include "reset_test.sv"
 
    // Master test
    `include "all_test.sv"
 
endpackage
