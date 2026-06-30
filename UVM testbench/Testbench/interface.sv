`timescale 1ns/1ps
// gộp các data pipeline lại thành 1 pipeline lớn
interface gemm_if #(parameter N=4, parameter WIDTH=8, parameter ACC_WIDTH=32) (
    input logic clk 
);
    logic rst;       
    logic [N*WIDTH-1:0]       a_in_bus;
    logic [N*WIDTH-1:0]       b_in_bus;
    wire  [N*N*ACC_WIDTH-1:0] c_out_bus;
endinterface
