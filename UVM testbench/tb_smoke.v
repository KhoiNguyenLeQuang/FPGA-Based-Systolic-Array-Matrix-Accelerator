`timescale 1ns/1ps
module tb_smoke;
    reg clk = 0;
    reg rst = 1;

    // Drive a_in_bus and b_in_bus
    reg [31:0] a_in_bus = 0;
    reg [31:0] b_in_bus = 0;
    wire [511:0] c_out_bus;

    always #5 clk = ~clk;

    // Instantiate the systolic array directly
    systolic_array_NxN #(.N(4), .WIDTH(8), .ACC_WIDTH(32)) dut (
        .clk      (clk),
        .rst      (rst),
        .a_in_bus (a_in_bus),
        .b_in_bus (b_in_bus),
        .c_out_bus(c_out_bus)
    );

    initial begin
        #20 rst = 0;

        // Feed identity matrix A and all-2s matrix B
        // Row 0 of A = [1,0,0,0], skewed: feed col by col
        // Cycle 0
        a_in_bus = {8'd0, 8'd0, 8'd0, 8'd1}; // row3,row2,row1,row0 col 0
        b_in_bus = {8'd0, 8'd0, 8'd0, 8'd2}; // col3,col2,col1,col0 row 0
        #10;

        // Cycle 1
        a_in_bus = {8'd0, 8'd0, 8'd1, 8'd0};
        b_in_bus = {8'd0, 8'd0, 8'd2, 8'd2};
        #10;

        // Cycle 2
        a_in_bus = {8'd0, 8'd1, 8'd0, 8'd0};
        b_in_bus = {8'd0, 8'd2, 8'd2, 8'd2};
        #10;

        // Cycle 3
        a_in_bus = {8'd1, 8'd0, 8'd0, 8'd0};
        b_in_bus = {8'd2, 8'd2, 8'd2, 8'd2};
        #10;

        // Drain cycles
        a_in_bus = 0; b_in_bus = 0;
        #60;

        // Print result
        $display("C[0][0] = %0d (expect 2)", c_out_bus[31:0]);
        $display("C[0][1] = %0d (expect 2)", c_out_bus[63:32]);
        $display("C[1][1] = %0d (expect 2)", c_out_bus[127:96]);
        $display("C[3][3] = %0d (expect 2)", c_out_bus[511:480]);
        $finish;
    end

    // Dump waveform
    initial begin
        $dumpfile("smoke.vcd");
        $dumpvars(0, tb_smoke);
    end
endmodule
