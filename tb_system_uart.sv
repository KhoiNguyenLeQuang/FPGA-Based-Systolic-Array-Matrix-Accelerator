// tb_system_uart.sv - end-to-end test of matrix_system_top: sends A,B over UART exactly like
// test_matrix.py, reads the 64-byte reply, checks all 16 results. Run:
//   iverilog -g2012 -o sys.vvp tb_system_uart.sv "source code.sv" UART.sv && vvp sys.vvp
`timescale 1ns/1ps
// End-to-end test: Python-host-equivalent sends A,B over UART, reads 64 bytes back, checks C = A x B
module tb_top;
  localparam CPB = 16, N = 4, PAIRS = 50;
  reg clk = 0, rst = 1, rx = 1; always #5 clk = ~clk;
  wire tx, done; wire [3:0] led;
  matrix_system_top #(.CLKS_PER_BIT(CPB)) dut(.sys_clk(clk), .sys_rst_btn(rst), .uart_rx_pin(rx),
                                              .uart_tx_pin(tx), .done_led(done), .debug_led(led));
  task send_byte(input [7:0] b); integer k; begin
    rx = 0; repeat(CPB) @(posedge clk);
    for (k = 0; k < 8; k = k + 1) begin rx = b[k]; repeat(CPB) @(posedge clk); end
    rx = 1; repeat(CPB) @(posedge clk);
  end endtask
  task recv_byte(output [7:0] b); integer k; begin
    @(negedge tx); repeat(CPB/2) @(posedge clk);            // middle of start bit
    for (k = 0; k < 8; k = k + 1) begin repeat(CPB) @(posedge clk); b[k] = tx; end
    repeat(CPB) @(posedge clk);                              // stop bit
  end endtask
  reg [7:0] A[0:15], B[0:15], rb; reg [31:0] got, exp; integer s, p, i, j, k, errs = 0, checks = 0;
  initial begin
    repeat(5) @(posedge clk); rst = 0; repeat(5) @(posedge clk);
    for (p = 0; p < PAIRS; p = p + 1) begin
      for (i = 0; i < 16; i = i + 1) begin
        A[i] = (p == 0) ? 8'hFF : (p == 1) ? ((i % 5 == 0) ? 1 : 0) : $random;
        B[i] = (p == 0) ? 8'hFF : $random;
      end
      fork
        begin for (s = 0; s < 16; s = s + 1) send_byte(A[s]); for (s = 0; s < 16; s = s + 1) send_byte(B[s]); end
        begin
          for (i = 0; i < 4; i = i + 1) for (j = 0; j < 4; j = j + 1) begin
            for (k = 0; k < 4; k = k + 1) begin recv_byte(rb); got[k*8 +: 8] = rb; end
            exp = 0; for (k = 0; k < 4; k = k + 1) exp = exp + A[i*4+k] * B[k*4+j];
            checks = checks + 1;
            if (got !== exp) begin errs = errs + 1; $display("pair %0d C[%0d][%0d] got %0d exp %0d", p, i, j, got, exp); end
          end
        end
      join
    end
    repeat(40) @(posedge clk);
    $display("pairs=%0d  result checks=%0d  mismatches=%0d  done_led=%b", PAIRS, checks, errs, done);
    $finish;
  end
  initial begin #50_000_000; $display("TIMEOUT"); $finish; end
endmodule
