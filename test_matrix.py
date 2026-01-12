import serial
import time
import struct

# --- CONFIGURATION ---
SERIAL_PORT = '/dev/ttyUSB1' 
BAUD_RATE = 115200

def send_matrix_data():
    try:
        # 1. Open Serial Connection
        print(f"Opening serial port {SERIAL_PORT}...")
        ser = serial.Serial(SERIAL_PORT, BAUD_RATE, timeout=1)
        time.sleep(2)  # Wait for connection to stabilize
        print("Connected!")

        # 2. Define Matrices (4x4)
        # Simple Identity Matrix for A (Diagonal is 1)
        matrix_A = [
            1, 0, 0, 0,
            0, 1, 0, 0,
            0, 0, 1, 0,
            0, 0, 0, 1
        ]

        # Simple Value Matrix for B (All 2s)
        matrix_B = [
            2, 2, 2, 2,
            2, 2, 2, 2,
            2, 2, 2, 2,
            2, 2, 2, 2
        ]

        # 3. Combine Data (Order: Matrix A then Matrix B)
        # We need to send 32 bytes total (16 + 16)
        full_payload = matrix_A + matrix_B
        
        print(f"Sending {len(full_payload)} bytes...")
        print(f"Matrix A: {matrix_A}")
        print(f"Matrix B: {matrix_B}")

        # 4. Transmit Byte by Byte
        # We use struct.pack('B') to ensure we send raw binary bytes, not text
        for num in full_payload:
            ser.write(struct.pack('B', num))
            time.sleep(0.01) # Small delay to be safe (optional)

        print("------------------------------------------------")
        print("Data Sent Successfully!")
        print("Check your FPGA LEDs:")
        print("  - DONE LED should be ON (Green)")
        print("  - DEBUG LEDs should show the result of Bottom-Right element")
        print("  - Leftmost LEDs should lights up, indicating that it finished loading")
        print("------------------------------------------------")

        ser.close()

    except serial.SerialException as e:
        print(f"Error: Could not open port {SERIAL_PORT}.")
        print("Did you run 'sudo chmod 666 /dev/ttyUSB0'?")
        print(f"Details: {e}")

if __name__ == "__main__":
    send_matrix_data()
