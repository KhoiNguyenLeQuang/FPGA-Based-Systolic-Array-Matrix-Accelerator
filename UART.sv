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

    reg [15:0] r_Clock_Count = 0; // Tăng bit để tránh tràn
    reg [2:0]  r_Bit_Index = 0;
    reg [2:0]  r_SM_Main = 0;

// --- Synchronization Registers ---
// The FSM below must ONLY read r_Rx_Data (the synchronized copy), never the raw pin.
    reg r_Rx_Data_R = 1'b1;
    reg r_Rx_Data   = 1'b1;

    always @(posedge i_Clock) begin
        // Double-flop to sync async input to our clock domain
        r_Rx_Data_R <= i_Rx_Serial;
        r_Rx_Data   <= r_Rx_Data_R;
    end

    always @(posedge i_Clock) begin
        case (r_SM_Main)
            IDLE: begin
                o_Rx_DV <= 1'b0;
                r_Clock_Count <= 0;
                r_Bit_Index <= 0;
                if (r_Rx_Data == 1'b0) r_SM_Main <= START;
            end
            START: begin
                if (r_Clock_Count == (CLKS_PER_BIT-1)/2) begin
                    if (r_Rx_Data == 1'b0) begin
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
                    o_Rx_Byte[r_Bit_Index] <= r_Rx_Data;
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


// UART TRANSMITTER (8-N-1). Pulse i_Tx_DV for one cycle with i_Tx_Byte while o_Tx_Active is low.
module uart_tx #(parameter CLKS_PER_BIT = 868) (
    input            i_Clock,
    input            i_Tx_DV,
    input      [7:0] i_Tx_Byte,
    output reg       o_Tx_Active = 1'b0,
    output reg       o_Tx_Serial = 1'b1,
    output reg       o_Tx_Done   = 1'b0
);
    localparam IDLE = 2'd0, START = 2'd1, DATA = 2'd2, STOP = 2'd3;

    reg [1:0]  r_State       = IDLE;
    reg [15:0] r_Clock_Count = 0;
    reg [2:0]  r_Bit_Index   = 0;
    reg [7:0]  r_Byte        = 0;

    always @(posedge i_Clock) begin
        o_Tx_Done <= 1'b0;
        case (r_State)
            IDLE: begin
                o_Tx_Serial   <= 1'b1;
                r_Clock_Count <= 0;
                r_Bit_Index   <= 0;
                if (i_Tx_DV) begin
                    o_Tx_Active <= 1'b1;
                    r_Byte      <= i_Tx_Byte;
                    r_State     <= START;
                end
            end
            START: begin                                   // start bit = 0
                o_Tx_Serial <= 1'b0;
                if (r_Clock_Count < CLKS_PER_BIT-1) r_Clock_Count <= r_Clock_Count + 1;
                else begin r_Clock_Count <= 0; r_State <= DATA; end
            end
            DATA: begin                                    // 8 data bits, LSB first
                o_Tx_Serial <= r_Byte[r_Bit_Index];
                if (r_Clock_Count < CLKS_PER_BIT-1) r_Clock_Count <= r_Clock_Count + 1;
                else begin
                    r_Clock_Count <= 0;
                    if (r_Bit_Index < 7) r_Bit_Index <= r_Bit_Index + 1;
                    else begin r_Bit_Index <= 0; r_State <= STOP; end
                end
            end
            STOP: begin                                    // stop bit = 1
                o_Tx_Serial <= 1'b1;
                if (r_Clock_Count < CLKS_PER_BIT-1) r_Clock_Count <= r_Clock_Count + 1;
                else begin
                    r_Clock_Count <= 0;
                    o_Tx_Done     <= 1'b1;
                    o_Tx_Active   <= 1'b0;
                    r_State       <= IDLE;
                end
            end
        endcase
    end
endmodule
