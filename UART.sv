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
