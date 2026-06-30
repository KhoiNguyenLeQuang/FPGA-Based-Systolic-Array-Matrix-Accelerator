`timescale 1ns/1ps

`include "interface.sv"
`include "package.sv"

module tb_top;
    import uvm_pkg::*;
    import gemm_pkg::*;

    logic clk;

    // Instantiate interface
    gemm_if #(.N(4), .WIDTH(8), .ACC_WIDTH(32)) vif(.clk(clk));

    // Instantiate DUT 
    systolic_array_NxN #(.N(4), .WIDTH(8), .ACC_WIDTH(32)) dut (
        .clk      (clk),
        .rst      (vif.rst), 
        .a_in_bus (vif.a_in_bus),
        .b_in_bus (vif.b_in_bus),
        .c_out_bus(vif.c_out_bus)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    // Initial Power-On Sequence
    initial begin
        vif.a_in_bus = 0;
        vif.b_in_bus = 0;
        vif.rst = 1;
        repeat(3) @(posedge clk);
        vif.rst = 0;
    end

    // Standard UVM execution hook
    initial begin
        uvm_config_db#(virtual gemm_if #(.N(4), .WIDTH(8), .ACC_WIDTH(32)))::set(null, "*", "vif", vif);
      run_test("gemm_all_test");
    end

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_top);
    end
endmodule