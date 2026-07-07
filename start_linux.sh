#!/bin/bash
# CN - 360 Video Extractor
# Linux launcher

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check for Python 3
if ! command -v python3 &>/dev/null; then
    echo "Error: python3 is required but not installed."
    echo "Install it with: sudo apt install python3 python3-tk"
    exit 1
fi

# Check for tkinter
if ! python3 -c "import tkinter" &>/dev/null; then
    echo "Error: python3-tk is required but not installed."
    echo "Install it with: sudo apt install python3-tk"
    exit 1
fi

python3 "$SCRIPT_DIR/process_frames.py"

