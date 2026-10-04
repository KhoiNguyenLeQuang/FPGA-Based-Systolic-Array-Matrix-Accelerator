`timescale 1ns / 1ps
// We are using FSM here, but we are not defining the parameters like the traditional way. Instead, my FSM is based on load_idx and load_complete. 
// MODULE 1: PROCESSING ELEMENT (PE, aka THE MATH)
module pe #(
    parameter WIDTH = 8,
    parameter ACC_WIDTH = 32
)(
    input wire clk, rst,
    input wire [WIDTH-1:0] a_in, b_in,
    output reg [WIDTH-1:0] a_out, b_out,
    output reg [ACC_WIDTH-1:0] c_out
);
    always @(posedge clk) begin
        if (rst) begin
            a_out <= 0; b_out <= 0; c_out <= 0;
        end else begin
            c_out <= c_out + (a_in * b_in);       
            a_out <= a_in;
            b_out <= b_in;
        end
    end
endmodule

// MODULE 2: SYSTOLIC ARRAY NxN
module systolic_array_NxN #(
    parameter N = 4,           
    parameter WIDTH = 8,
    parameter ACC_WIDTH = 32
)(
    input wire clk, rst,
    input wire [N*WIDTH-1:0] a_in_bus, 
    input wire [N*WIDTH-1:0] b_in_bus,
    output wire [N*N*ACC_WIDTH-1:0] c_out_bus
);
    wire [WIDTH-1:0] h_wire [0:N-1][0:N]; 
    wire [WIDTH-1:0] v_wire [0:N][0:N-1];
    
    genvar i, j;
    generate
        for (i = 0; i < N; i = i + 1) begin : ROWS
            for (j = 0; j < N; j = j + 1) begin : COLS
                
                if (j == 0) begin
                    assign h_wire[i][0] = a_in_bus[(i*WIDTH) +: WIDTH];
                end
                
                if (i == 0) begin
                    assign v_wire[0][j] = b_in_bus[(j*WIDTH) +: WIDTH];
                end
                
                 pe #(.WIDTH(WIDTH), .ACC_WIDTH(ACC_WIDTH)) pe_inst (
                    .clk(clk), .rst(rst),
                    .a_in(h_wire[i][j]),     
                    .b_in(v_wire[i][j]),     
                    .a_out(h_wire[i][j+1]),   
                    .b_out(v_wire[i+1][j]),
                    .c_out(c_out_bus[(i*N+j)*ACC_WIDTH +: ACC_WIDTH]) 
                );
            end
        end
    endgenerate
endmodule

// MODULE 3: TOP LEVEL -- UART load -> skewed compute -> UART readback of all 16 results
//
// Protocol (host side: test_matrix.py):
//   host sends 32 bytes : A (16 bytes, row-major) then B (16 bytes, row-major)
//   FPGA replies 64 bytes: C[0][0]..C[3][3], row-major, each 32-bit value little-endian
// After the reply the core is cleared and the board is ready for the next pair.
//
// Every one of the 512 result bits now reaches an output pin (through the UART TX),
// so synthesis keeps all 16 PEs. Previously only result_bus[3:0] reached the LEDs and
// Vivado pruned 15 of the 16 PEs as unused logic.
module matrix_system_top #(
    parameter N            = 4,
    parameter WIDTH        = 8,
    parameter ACC_WIDTH    = 32,
    parameter CLKS_PER_BIT = 868            // 100 MHz / 115,200 baud
)(
    input  wire       sys_clk,
    input  wire       sys_rst_btn,
    input  wire       uart_rx_pin,
    output wire       uart_tx_pin,
    output wire       done_led,             // lit while results are being / have been sent
    output wire [3:0] debug_led             // low nibble of C[0][0]
);
    localparam MATRIX_SIZE  = N * N;                    // 16 elements per matrix
    localparam RESULT_BYTES = N * N * ACC_WIDTH / 8;    // 64 bytes
    localparam COMPUTE_CYC  = 3*N + 1;                  // 2N-1 skew + N-1 drain + 2 margin (feeder & PE regs)

    localparam S_LOAD = 2'd0, S_COMPUTE = 2'd1, S_SEND = 2'd2, S_CLEAR = 2'd3;

    wire rst = sys_rst_btn;

    // UART RX
    wire [7:0] rx_byte;
    wire       rx_dv;
    uart_rx #(.CLKS_PER_BIT(CLKS_PER_BIT)) rx_inst (
        .i_Clock(sys_clk), .i_Rx_Serial(uart_rx_pin),
        .o_Rx_DV(rx_dv),   .o_Rx_Byte(rx_byte)
    );

    // UART TX 
    reg        tx_dv;
    reg  [7:0] tx_byte;
    wire       tx_active, tx_done;
    uart_tx #(.CLKS_PER_BIT(CLKS_PER_BIT)) tx_inst (
        .i_Clock(sys_clk), .i_Tx_DV(tx_dv), .i_Tx_Byte(tx_byte),
        .o_Tx_Active(tx_active), .o_Tx_Serial(uart_tx_pin), .o_Tx_Done(tx_done)
    );

    // Buffers & control 
    reg [WIDTH-1:0] mem_A [0:MATRIX_SIZE-1];
    reg [WIDTH-1:0] mem_B [0:MATRIX_SIZE-1];

    reg [1:0] state;
    reg [5:0] load_idx;        // 0..31
    reg [5:0] compute_cycle;   // 0..COMPUTE_CYC
    reg [6:0] send_idx;        // 0..63
    reg       tx_wait;         // a byte has been handed to uart_tx, waiting for tx_done
    reg       sent_flag;
    reg       core_clear;      // clears the PE accumulators between matrix pairs

    wire [N*N*ACC_WIDTH-1:0] result_bus;

    always @(posedge sys_clk) begin
        tx_dv      <= 1'b0;
        core_clear <= 1'b0;
        if (rst) begin
            state <= S_LOAD; load_idx <= 0; compute_cycle <= 0;
            send_idx <= 0; tx_wait <= 1'b0; sent_flag <= 1'b0;
        end else begin
            case (state)
                // Bytes 0-15 -> A, 16-31 -> B
                S_LOAD: if (rx_dv) begin
                    if (load_idx < MATRIX_SIZE) mem_A[load_idx]               <= rx_byte;
                    else                        mem_B[load_idx - MATRIX_SIZE] <= rx_byte;
                    sent_flag <= 1'b0;
                    if (load_idx == 2*MATRIX_SIZE - 1) begin
                        load_idx      <= 0;
                        compute_cycle <= 0;
                        state         <= S_COMPUTE;
                    end else
                        load_idx <= load_idx + 1;
                end
                // Skew feeder runs while compute_cycle counts; results are final after COMPUTE_CYC
                S_COMPUTE: begin
                    if (compute_cycle == COMPUTE_CYC) begin
                        send_idx <= 0;
                        state    <= S_SEND;
                    end else
                        compute_cycle <= compute_cycle + 1;
                end
                // Stream the 512-bit result bus out, byte 0 (LSB of C[0][0]) first.
                // Inputs are zero here, so the accumulators hold their values while we send.
                S_SEND: begin
                    if (!tx_wait && !tx_active) begin
                        tx_byte <= result_bus[send_idx*8 +: 8];
                        tx_dv   <= 1'b1;
                        tx_wait <= 1'b1;
                    end else if (tx_done) begin
                        tx_wait <= 1'b0;
                        if (send_idx == RESULT_BYTES - 1) begin
                            sent_flag <= 1'b1;
                            state     <= S_CLEAR;
                        end else
                            send_idx <= send_idx + 1;
                    end
                end
                // One-cycle accumulator clear, then wait for the next matrix pair
                S_CLEAR: begin
                    core_clear <= 1'b1;
                    state      <= S_LOAD;
                end
            endcase
        end
    end

    // Skew feeder
    // Lane i is delayed by i cycles: element index = compute_cycle - i, zero outside [0, N).
    reg [N*WIDTH-1:0] a_drive, b_drive;
    integer i;
    reg signed [7:0] data_idx;
    always @(posedge sys_clk) begin
        if (rst || state != S_COMPUTE) begin
            a_drive <= 0;
            b_drive <= 0;
        end else begin
            for (i = 0; i < N; i = i + 1) begin
                data_idx = $signed({2'b00, compute_cycle}) - i;
                if (data_idx >= 0 && data_idx < N) begin
                    a_drive[i*WIDTH +: WIDTH] <= mem_A[i*N + data_idx];   // A[i][k] into row i
                    b_drive[i*WIDTH +: WIDTH] <= mem_B[data_idx*N + i];   // B[k][i] into column i
                end else begin
                    a_drive[i*WIDTH +: WIDTH] <= 0;
                    b_drive[i*WIDTH +: WIDTH] <= 0;
                end
            end
        end
    end

    // Systolic core
    systolic_array_NxN #(.N(N), .WIDTH(WIDTH), .ACC_WIDTH(ACC_WIDTH)) core (
        .clk(sys_clk), .rst(rst | core_clear),
        .a_in_bus(a_drive), .b_in_bus(b_drive),
        .c_out_bus(result_bus)
    );

    assign done_led  = sent_flag;
    assign debug_led = result_bus[3:0];
endmodule
