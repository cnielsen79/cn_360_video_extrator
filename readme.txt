CN - 360 Video Extractor
==========================================

A portable, single-click pipeline for extracting and processing 360 video
into split frame sequences ready for photogrammetry or 3D reconstruction.

No installation required.


Launching
---------
  Windows   Double-click start_gui.bat
  macOS     Double-click start_mac.command
            (Right-click > Open the first time to bypass Gatekeeper)
  Linux     Run: bash start_linux.sh
            Requires: python3, python3-tk  (sudo apt install python3-tk)

macOS / Linux also require Python 3 with tkinter:
  macOS:  brew install python-tk
  Linux:  sudo apt install python3-tk


How it works
------------
1. Browse or drag in a 360 video file
2. Set your settings (FPS, splits, resolution)
3. Click PROCESS VIDEO

The app runs three steps automatically:

  Step 1 - Extract Frames
    FFmpeg extracts individual frames from the video at the chosen rate.
    Output is saved in a folder next to the source video.

  Step 2 - Split 360 Images
    AliceVision splits each equirectangular frame into perspective tiles.
    The app auto-detects which AliceVision binary is available.

  Step 3 - Build Combined Sequence
    The tiles from all frames are interleaved into a single flat image
    sequence ready for photogrammetry software (RealityCapture, Metashape,
    COLMAP, etc.).

When complete, an "Open Output Folder" button appears.


Settings
--------
  Frames / sec     Frames to extract per second. 1 = one frame/s, 0.5 = one every 2 s.
  Splits           Number of perspective tiles per frame. Default: 8
  Split res (px)   Width/height of each output tile. Default: 1200
  Custom FOV       Set a custom field of view in degrees for the splitter.
                   Default is 90 when unchecked. Requires the newer AliceVision binary.


Binaries
--------
Place platform binaries in the bin/ folder for portable use.
If not present, the app will look for system-installed versions.

  Windows bin/        ffmpeg.exe, aliceVision_split360Images.exe (included)
  macOS   bin/        ffmpeg, aliceVision_split360Images
  Linux   bin/        ffmpeg, aliceVision_split360Images

System install alternatives:
  macOS:  brew install ffmpeg
  Linux:  sudo apt install ffmpeg
  AliceVision: https://github.com/alicevision/AliceVision/releases


Building the macOS DMG
----------------------
Run on a Mac (from the repo root):

  chmod +x macos/build_dmg.sh
  ./macos/build_dmg.sh

This creates CN360Extractor.dmg in the repo root.
Requires Python 3 + tkinter (brew install python-tk).


Licenses
--------
FFmpeg
  GNU LGPL v2.1 or later (portions GPL v2+).
  https://ffmpeg.org/legal.html

AliceVision
  Mozilla Public License 2.0.
  https://github.com/alicevision/AliceVision/blob/develop/LICENSE


Credits
-------
CN
https://cn360.app

