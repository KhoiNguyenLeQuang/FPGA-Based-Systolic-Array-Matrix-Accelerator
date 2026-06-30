`timescale 1ns / 1ps

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

module uart_rx #(parameter CLKS_PER_BIT = 868) (
    input        i_Clock,
    input        i_Rx_Serial,
    output reg   o_Rx_DV,
    output reg [7:0] o_Rx_Byte
);
    localparam IDLE  = 3'b000;
    localparam START = 3'b001;
    localparam DATA  = 3'b010;
    localparam STOP  = 3'b011;
    localparam CLEAN = 3'b100;

    reg [15:0] r_Clock_Count = 0; 
    reg [2:0]  r_Bit_Index = 0;
    reg [2:0]  r_SM_Main = 0;
    reg r_Rx_Data_R = 1'b1;
    reg r_Rx_Data   = 1'b1;

    always @(posedge i_Clock) begin
        r_Rx_Data_R <= i_Rx_Serial;
        r_Rx_Data   <= r_Rx_Data_R;
    end

    always @(posedge i_Clock) begin
        case (r_SM_Main)
            IDLE: begin
                o_Rx_DV <= 1'b0;
                r_Clock_Count <= 0;
                r_Bit_Index <= 0;
                if (i_Rx_Serial == 1'b0) r_SM_Main <= START;
            end
            START: begin
                if (r_Clock_Count == (CLKS_PER_BIT-1)/2) begin
                    if (i_Rx_Serial == 1'b0) begin
                        r_Clock_Count <= 0;
                        r_SM_Main <= DATA;
                    end else r_SM_Main <= IDLE;
                end else begin
                    r_Clock_Count <= r_Clock_Count + 1;
                end
            end
            DATA: begin
                if (r_Clock_Count < CLKS_PER_BIT-1) begin
                    r_Clock_Count <= r_Clock_Count + 1;
                end else begin
                    r_Clock_Count <= 0;
                    o_Rx_Byte[r_Bit_Index] <= i_Rx_Serial;
                    if (r_Bit_Index < 7) r_Bit_Index <= r_Bit_Index + 1;
                    else begin
                        r_Bit_Index <= 0;
                        r_SM_Main <= STOP;
                    end
                end
            end
            STOP: begin
                if (r_Clock_Count < CLKS_PER_BIT-1) begin
                    r_Clock_Count <= r_Clock_Count + 1;
                end else begin
                    o_Rx_DV <= 1'b1;
                    r_Clock_Count <= 0;
                    r_SM_Main <= CLEAN;
                end
            end
            CLEAN: begin
                r_SM_Main <= IDLE;
                o_Rx_DV <= 1'b0;
            end
            default: r_SM_Main <= IDLE;
        endcase
    end
endmodule

module matrix_system_top(
    input wire sys_clk,
    input wire sys_rst_btn,
    input wire uart_rx_pin,
    output wire done_led,
    output wire [3:0] debug_led
);

    parameter N = 4;
    parameter WIDTH = 8;
    parameter ACC_WIDTH = 32;
    parameter MATRIX_SIZE = N * N; 

    wire rst = sys_rst_btn;

    wire [7:0] rx_byte;
    wire rx_dv;
    
    uart_rx #(.CLKS_PER_BIT(868)) rx_inst (
        .i_Clock(sys_clk),
        .i_Rx_Serial(uart_rx_pin),
        .o_Rx_DV(rx_dv),
        .o_Rx_Byte(rx_byte)
    );

    reg [WIDTH-1:0] mem_A [0:MATRIX_SIZE-1];
    reg [WIDTH-1:0] mem_B [0:MATRIX_SIZE-1];
    
    reg [4:0] load_idx;       
    reg loading_complete;    

    always @(posedge sys_clk) begin
        if (rst) begin
            load_idx <= 0;
            loading_complete <= 0;
        end else if (rx_dv) begin
            if (load_idx < MATRIX_SIZE) begin
                mem_A[load_idx] <= rx_byte;
                load_idx <= load_idx + 1;
            end 
            else if (load_idx < 2*MATRIX_SIZE) begin
                mem_B[load_idx - MATRIX_SIZE] <= rx_byte;
                load_idx <= load_idx + 1;
            end
            
            if (load_idx == (2*MATRIX_SIZE - 1)) begin
                loading_complete <= 1;
            end
        end
    end
    
reg [5:0] compute_cycle; 
    reg [N*WIDTH-1:0] a_drive;
    reg [N*WIDTH-1:0] b_drive;
    
    integer i;
    reg signed [5:0] data_idx;

    always @(posedge sys_clk) begin
        if (rst) begin
            compute_cycle <= 0;
            a_drive <= 0;
            b_drive <= 0;
        end else if (loading_complete) begin
            if (compute_cycle < 30) compute_cycle <= compute_cycle + 1;

            for (i = 0; i < N; i = i + 1) begin
                data_idx = compute_cycle - i;

                if (data_idx >= 0 && data_idx < N) begin
                    a_drive[(i*WIDTH) +: WIDTH] <= mem_A[i*N + data_idx];
                end else begin
                    a_drive[(i*WIDTH) +: WIDTH] <= 0;
                end

                if (data_idx >= 0 && data_idx < N) begin
                    b_drive[(i*WIDTH) +: WIDTH] <= mem_B[data_idx*N + i];
                end else begin
                    b_drive[(i*WIDTH) +: WIDTH] <= 0;
                end
            end
        end
    end

    wire [N*N*ACC_WIDTH-1:0] result_bus;
    
    systolic_array_NxN #(.N(N), .WIDTH(WIDTH), .ACC_WIDTH(ACC_WIDTH)) core (
        .clk(sys_clk),
        .rst(rst),
        .a_in_bus(a_drive),
        .b_in_bus(b_drive),
        .c_out_bus(result_bus)
    );

    assign done_led = loading_complete; 
    assign debug_led = result_bus[3:0];

endmodule
