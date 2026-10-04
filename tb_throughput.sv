// tb_throughput.sv - back-to-back throughput of systolic_array_NxN: 1,000 random 4x4 matmuls,
// one every (3N-2) compute + 1 clear cycle; prints cycles per matmul and mismatch count. Run:
//   iverilog -g2012 -o thr.vvp tb_throughput.sv "source code.sv" UART.sv && vvp thr.vvp
`timescale 1ns/1ps
module tb;
  localparam N=4,W=8,AW=32, M=1000;
  reg clk=0, rst=1; always #5 clk=~clk;
  reg [N*W-1:0] a_bus=0, b_bus=0; wire [N*N*AW-1:0] c;
  systolic_array_NxN #(N,W,AW) dut(clk,rst,a_bus,b_bus,c);
  reg [7:0] A[0:N-1][0:N-1], B[0:N-1][0:N-1]; integer m,t,i,j,k,err=0,exp,cyc=0,c0;
  always @(posedge clk) cyc<=cyc+1;
  initial begin
    repeat(2) @(posedge clk); 
    c0=cyc;
    for(m=0;m<M;m=m+1) begin
      for(i=0;i<N;i=i+1) for(j=0;j<N;j=j+1) begin A[i][j]=$random; B[i][j]=$random; end
      if(m<2) begin for(i=0;i<N;i=i+1) for(j=0;j<N;j=j+1) begin A[i][j]=m?255:0; B[i][j]=255; end end
      @(negedge clk) rst=0;
      for(t=0;t<3*N-2;t=t+1) begin
        for(i=0;i<N;i=i+1) begin
          a_bus[i*W+:W] = (t-i>=0 && t-i<N) ? A[i][t-i] : 0;
          b_bus[i*W+:W] = (t-i>=0 && t-i<N) ? B[t-i][i] : 0;
        end
        @(negedge clk);
      end
      for(i=0;i<N;i=i+1) for(j=0;j<N;j=j+1) begin exp=0; for(k=0;k<N;k=k+1) exp=exp+A[i][k]*B[k][j];
        if(c[(i*N+j)*AW+:AW]!==exp) err=err+1; end
      rst=1; a_bus=0; b_bus=0;
    end
    @(negedge clk);
    $display("matmuls=%0d mismatches=%0d cycles=%0d cyc/matmul=%0.2f", M, err, cyc-c0, (cyc-c0)*1.0/M);
    $finish;
  end
endmodule
