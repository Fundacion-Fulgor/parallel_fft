#!/bin/bash
set -e

PYTHON_SCRIPT="generate_signals.py"
VERILOG_FILES="twiddle_interface.v complex_multiplier.v SatTruncFP.v tb_twiddle_interface.v"
OUTPUT_EXE="test_twiddle.vvp"

echo "--- Step 1: Generating test vectors with Python... ---"
python3 $PYTHON_SCRIPT

echo "--- Step 2: Compiling Verilog files with Icarus... ---"
iverilog -o $OUTPUT_EXE $VERILOG_FILES

echo "--- Step 3: Running simulation... ---"
vvp $OUTPUT_EXE