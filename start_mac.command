#!/bin/bash
# CN - 360 Video Extractor
# macOS launcher (double-click to run)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check for Python 3
if ! command -v python3 &>/dev/null; then
    osascript -e 'display alert "Python 3 not found" message "Install Python 3 from python.org or via Homebrew: brew install python"'
    exit 1
fi

# Check for tkinter
if ! python3 -c "import tkinter" &>/dev/null; then
    osascript -e 'display alert "tkinter not found" message "Install Python with tkinter support from python.org (the Homebrew version may lack tkinter)."'
    exit 1
fi

python3 "$SCRIPT_DIR/process_frames.py"

