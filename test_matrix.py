"""
Host script for the FPGA systolic array accelerator (Basys 3, 115,200 baud).

Protocol:
  send    32 bytes : matrix A (16 bytes, row-major) then matrix B (16 bytes, row-major)
  receive 64 bytes : C = A x B, 16 x uint32 little-endian, row-major

Usage:
  pip install pyserial
  python test_matrix.py --port /dev/ttyUSB1 --trials 20      (Windows: --port COM4)
"""
import argparse
import random
import struct
import sys

import serial

N = 4


def matmul(a, b):
    return [sum(a[i * N + k] * b[k * N + j] for k in range(N)) for i in range(N) for j in range(N)]


def run_one(ser, a, b):
    ser.reset_input_buffer()
    ser.write(bytes(a + b))
    reply = ser.read(64)
    if len(reply) != 64:
        raise RuntimeError(f"timeout: got {len(reply)}/64 bytes back")
    return list(struct.unpack("<16I", reply))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", default="/dev/ttyUSB1")
    ap.add_argument("--baud", type=int, default=115200)
    ap.add_argument("--trials", type=int, default=10, help="random matrix pairs after the fixed tests")
    args = ap.parse_args()

    tests = [
        ("identity x all-3s", [1 if i % 5 == 0 else 0 for i in range(16)], [3] * 16),
        ("all-0xFF x all-0xFF (max = 260,100)", [255] * 16, [255] * 16),
        ("zeros x all-0xFF", [0] * 16, [255] * 16),
    ]
    tests += [(f"random #{t}", [random.randrange(256) for _ in range(16)],
               [random.randrange(256) for _ in range(16)]) for t in range(args.trials)]

    fails = 0
    with serial.Serial(args.port, args.baud, timeout=2) as ser:
        for name, a, b in tests:
            got, exp = run_one(ser, a, b), matmul(a, b)
            ok = got == exp
            fails += not ok
            print(f"{'PASS' if ok else 'FAIL'}  {name}")
            if not ok:
                print(f"   expected {exp}\n   got      {got}")
    print(f"\n{len(tests) - fails}/{len(tests)} matrix pairs matched on hardware")
    sys.exit(1 if fails else 0)


if __name__ == "__main__":
    main()
