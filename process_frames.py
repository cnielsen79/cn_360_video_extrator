#!/usr/bin/env python3
"""
CN - 360 Video Extractor
Linux / macOS version
"""

import os
import sys
import platform
import shutil
import threading
import subprocess
from pathlib import Path
import tkinter as tk
from tkinter import ttk, filedialog, messagebox

SCRIPT_DIR = Path(__file__).parent.resolve()
BIN_DIR    = SCRIPT_DIR / "bin"
PLATFORM   = platform.system()  # "Linux" or "Darwin"

# ── Colors ─────────────────────────────────────────────────────────────────────
BG_DARK  = "#121212"
BG_PANEL = "#1c1c1c"
BG_GROUP = "#242424"
ACCENT   = "#FF5000"
TEXT     = "#FFFFFF"
MUTED    = "#A0A0A0"
INPUT_BG = "#303030"
GREEN    = "#50C878"
RED      = "#FF5050"

# ── Binary resolution ──────────────────────────────────────────────────────────
def find_bin(name):
    local = BIN_DIR / name
    if local.exists() and os.access(str(local), os.X_OK):
        return str(local)
    return shutil.which(name)

FFMPEG_PATH   = find_bin("ffmpeg")
ALICE_PATH    = find_bin("aliceVision_split360Images")
ALICE_LEGACY  = find_bin("aliceVision_utils_split360Images")

# ── App ────────────────────────────────────────────────────────────────────────
class App(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title("CN - 360 Video Extractor")
        self.configure(bg=BG_DARK)
        self.resizable(True, True)
        self.minsize(520, 560)
        self.geometry("540x590")

        self._proc               = None
        self._av_output_folder   = None
        self._final_output_folder = None
        self._s                  = {}

        self._build_ui()
        self._check_binaries()

    # ── UI ─────────────────────────────────────────────────────────────────────
    def _build_ui(self):
        # Header
        header = tk.Frame(self, bg=BG_PANEL, height=64)
        header.pack(fill="x")
        header.pack_propagate(False)

        tk.Label(header, text="CN", bg=BG_PANEL, fg=TEXT,
                 font=("Helvetica", 14, "bold")).place(x=18, y=10)
        tk.Label(header, text="360 Video Extractor", bg=BG_PANEL, fg=ACCENT,
                 font=("Helvetica", 11)).place(x=20, y=36)

        tk.Frame(self, bg="#464646", height=1).pack(fill="x")

        # Settings panel
        outer = tk.Frame(self, bg=BG_DARK)
        outer.pack(fill="both", expand=True, padx=16, pady=(12, 0))

        panel = tk.Frame(outer, bg=BG_GROUP)
        panel.pack(fill="both", expand=True)

        tk.Frame(panel, bg=ACCENT, height=3).pack(fill="x")

        tk.Label(panel, text="  SETTINGS", bg=BG_GROUP, fg=ACCENT,
                 font=("Helvetica", 9, "bold")).pack(anchor="w", padx=14, pady=(8, 4))

        # Video file row
        tk.Label(panel, text="Video file", bg=BG_GROUP, fg=MUTED,
                 font=("Helvetica", 9)).pack(anchor="w", padx=14)

        file_row = tk.Frame(panel, bg=BG_GROUP)
        file_row.pack(fill="x", padx=14, pady=(2, 12))

        self.video_var = tk.StringVar()
        entry = tk.Entry(file_row, textvariable=self.video_var,
                         bg=INPUT_BG, fg=TEXT, insertbackground=TEXT,
                         relief="flat", font=("Helvetica", 9))
        entry.pack(side="left", fill="x", expand=True, ipady=5)

        tk.Button(file_row, text="Browse...", bg=BG_GROUP, fg=MUTED,
                  relief="flat", font=("Helvetica", 8, "bold"), cursor="hand2",
                  activebackground=BG_GROUP, activeforeground=TEXT,
                  command=self._browse_video).pack(side="left", padx=(6, 0), ipady=4, ipadx=6)

        # Numeric settings row
        row = tk.Frame(panel, bg=BG_GROUP)
        row.pack(fill="x", padx=14, pady=(0, 12))

        def num_col(parent, label, var_val, width=8):
            col = tk.Frame(parent, bg=BG_GROUP)
            col.pack(side="left", padx=(0, 14))
            tk.Label(col, text=label, bg=BG_GROUP, fg=MUTED,
                     font=("Helvetica", 9)).pack(anchor="w")
            v = tk.StringVar(value=var_val)
            tk.Entry(col, textvariable=v, width=width,
                     bg=INPUT_BG, fg=TEXT, insertbackground=TEXT,
                     relief="flat", font=("Helvetica", 9),
                     justify="center").pack(ipady=5)
            return v

        self.fps_var    = num_col(row, "Frames / sec", "1")
        self.splits_var = num_col(row, "Splits", "8", 6)
        self.res_var    = num_col(row, "Split res (px)", "1200")

        fov_col = tk.Frame(row, bg=BG_GROUP)
        fov_col.pack(side="left")
        self.fov_enabled = tk.BooleanVar(value=False)
        tk.Checkbutton(fov_col, text="Custom FOV", variable=self.fov_enabled,
                       bg=BG_GROUP, fg=MUTED, selectcolor=INPUT_BG,
                       activebackground=BG_GROUP, activeforeground=TEXT,
                       font=("Helvetica", 9),
                       command=self._toggle_fov).pack(anchor="w")
        self.fov_var = tk.StringVar(value="90")
        self.fov_entry = tk.Entry(fov_col, textvariable=self.fov_var, width=6,
                                  bg=INPUT_BG, fg=TEXT, insertbackground=TEXT,
                                  relief="flat", font=("Helvetica", 9),
                                  justify="center", state="disabled",
                                  disabledbackground=INPUT_BG, disabledforeground="#555")
        self.fov_entry.pack(ipady=5)

        # Divider
        tk.Frame(panel, bg="#464646", height=1).pack(fill="x", padx=14, pady=(4, 8))

        # Pipeline indicators
        tk.Label(panel, text="Pipeline", bg=BG_GROUP, fg=MUTED,
                 font=("Helvetica", 8, "bold")).pack(anchor="w", padx=14)

        self.step_dots   = []
        self.step_labels = []
        for step in ["1  Extract frames from video",
                     "2  Split 360 images",
                     "3  Build combined sequence"]:
            f = tk.Frame(panel, bg=BG_GROUP)
            f.pack(anchor="w", padx=14, pady=1)
            dot = tk.Label(f, text="●", bg=BG_GROUP, fg="#464646",
                           font=("Helvetica", 8))
            dot.pack(side="left")
            lbl = tk.Label(f, text=step, bg=BG_GROUP, fg=MUTED,
                           font=("Helvetica", 8, "bold"))
            lbl.pack(side="left", padx=(4, 0))
            self.step_dots.append(dot)
            self.step_labels.append(lbl)

        # Progress bar
        style = ttk.Style()
        style.theme_use("default")
        style.configure("Orange.Horizontal.TProgressbar",
                        troughcolor=INPUT_BG, background=ACCENT,
                        darkcolor=ACCENT, lightcolor=ACCENT,
                        bordercolor=INPUT_BG, thickness=8)

        self.progress = ttk.Progressbar(panel, style="Orange.Horizontal.TProgressbar",
                                        mode="indeterminate", length=460)
        self.progress.pack(padx=14, pady=(10, 14), fill="x")
        self.progress.pack_forget()

        # Run button
        btn_frame = tk.Frame(self, bg=BG_DARK)
        btn_frame.pack(fill="x", padx=16, pady=12)

        self.run_btn = tk.Button(btn_frame, text="PROCESS VIDEO",
                                 bg=ACCENT, fg=TEXT,
                                 font=("Helvetica", 12, "bold"),
                                 relief="flat", cursor="hand2",
                                 activebackground="#FF6A28", activeforeground=TEXT,
                                 command=self._run_pipeline)
        self.run_btn.pack(fill="x", ipady=14)

        self.open_btn = tk.Button(btn_frame, text="Open Output Folder",
                                  bg=BG_GROUP, fg=MUTED,
                                  font=("Helvetica", 9, "bold"),
                                  relief="flat", cursor="hand2",
                                  activebackground=BG_GROUP, activeforeground=TEXT,
                                  command=self._open_output)

        # Status bar
        tk.Frame(self, bg="#464646", height=1).pack(fill="x")
        status_bar = tk.Frame(self, bg=BG_PANEL, height=50)
        status_bar.pack(fill="x", side="bottom")
        status_bar.pack_propagate(False)

        self.status_var = tk.StringVar(value="Ready")
        self.status_lbl = tk.Label(status_bar, textvariable=self.status_var,
                                   bg=BG_PANEL, fg=MUTED,
                                   font=("Helvetica", 8), anchor="w")
        self.status_lbl.pack(anchor="w", padx=14, pady=(8, 0))
        tk.Label(status_bar, text="cn360.app", bg=BG_PANEL, fg="#464646",
                 font=("Helvetica", 8)).pack(anchor="w", padx=14)

    # ── Helpers ────────────────────────────────────────────────────────────────
    def _check_binaries(self):
        missing = []
        if not FFMPEG_PATH:
            missing.append("ffmpeg")
        if not ALICE_PATH and not ALICE_LEGACY:
            missing.append("aliceVision_split360Images")
        if missing:
            self.set_status(
                f"Warning: {', '.join(missing)} not found. Install via package manager or place in bin/.", RED)

    def set_status(self, msg, color=MUTED):
        self.status_var.set(msg)
        self.status_lbl.configure(fg=color)

    def set_step(self, index, state):
        dot_colors  = {"idle": "#464646", "running": ACCENT, "done": GREEN, "error": RED}
        text_colors = {"idle": MUTED,     "running": TEXT,   "done": GREEN, "error": RED}
        self.step_dots[index].configure(fg=dot_colors.get(state, MUTED))
        self.step_labels[index].configure(fg=text_colors.get(state, MUTED))

    def _toggle_fov(self):
        self.fov_entry.configure(state="normal" if self.fov_enabled.get() else "disabled")

    def _browse_video(self):
        path = filedialog.askopenfilename(
            filetypes=[("Video files", "*.mp4 *.mov *.avi *.mkv *.mxf"), ("All files", "*.*")])
        if path:
            self.video_var.set(path)

    def _open_output(self):
        if not self._final_output_folder:
            return
        if PLATFORM == "Darwin":
            subprocess.Popen(["open", self._final_output_folder])
        else:
            subprocess.Popen(["xdg-open", self._final_output_folder])

    def _fail(self, step, msg):
        self.set_step(step, "error")
        self.progress.stop()
        self.progress.pack_forget()
        self.run_btn.configure(state="normal")
        self.set_status(msg, RED)
        messagebox.showerror("Error", msg)

    def _finish(self, frame_count):
        self.set_step(2, "done")
        self.progress.pack_forget()
        self.run_btn.configure(state="normal")
        self.open_btn.pack(fill="x", pady=(8, 0))
        self.set_status(
            f"Done! {frame_count} frames ready in: {self._final_output_folder}", GREEN)
        messagebox.showinfo("Complete",
            f"All done!\n\n{frame_count} frames saved to:\n{self._final_output_folder}")

    # ── Validation ─────────────────────────────────────────────────────────────
    def _validate(self):
        if not self.video_var.get():
            messagebox.showerror("Missing input", "Please select a video file."); return False
        try:
            float(self.fps_var.get())
        except ValueError:
            messagebox.showerror("Invalid", "Frames/sec must be a number."); return False
        if not self.splits_var.get().isdigit():
            messagebox.showerror("Invalid", "Splits must be a whole number."); return False
        if not self.res_var.get().isdigit():
            messagebox.showerror("Invalid", "Split resolution must be a whole number."); return False
        if self.fov_enabled.get() and not self.fov_var.get().isdigit():
            messagebox.showerror("Invalid", "FOV must be a whole number."); return False
        if not FFMPEG_PATH:
            messagebox.showerror("Missing binary",
                "ffmpeg not found.\nInstall it (brew install ffmpeg / apt install ffmpeg)\nor place the binary in the bin/ folder.")
            return False
        if not ALICE_PATH and not ALICE_LEGACY:
            messagebox.showerror("Missing binary",
                "AliceVision not found.\nPlace aliceVision_split360Images in the bin/ folder.")
            return False
        return True

    # ── Pipeline ───────────────────────────────────────────────────────────────
    def _run_pipeline(self):
        if not self._validate():
            return

        video_path = Path(self.video_var.get())
        self._s = {
            "video":         str(video_path),
            "fps":           self.fps_var.get(),
            "splits":        self.splits_var.get(),
            "res":           self.res_var.get(),
            "use_fov":       self.fov_enabled.get(),
            "fov":           self.fov_var.get(),
            "input_dir":     video_path.parent,
            "video_name":    video_path.stem,
            "frames_folder": video_path.parent / f"{video_path.stem}_{self.fps_var.get()}fps",
        }

        self.run_btn.configure(state="disabled")
        self.open_btn.pack_forget()
        for i in range(3):
            self.set_step(i, "idle")
        self.progress.configure(mode="indeterminate")
        self.progress.pack(padx=14, pady=(10, 14), fill="x")
        self.progress.start(15)

        threading.Thread(target=self._step1_ffmpeg, daemon=True).start()

    def _step1_ffmpeg(self):
        self.after(0, lambda: self.set_step(0, "running"))
        self.after(0, lambda: self.set_status("Step 1/3 - Extracting frames..."))

        frames_folder = self._s["frames_folder"]
        frames_folder.mkdir(parents=True, exist_ok=True)
        output_path = str(frames_folder / "image_%04d.jpg")

        cmd = [FFMPEG_PATH, "-y", "-i", self._s["video"],
               "-vf", f"fps={self._s['fps']}", "-qscale:v", "1", output_path]

        self._proc = subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        self._proc.wait()

        frames = list(frames_folder.glob("*.jpg"))
        if not frames:
            self.after(0, lambda: self._fail(0,
                "Step 1 failed - no frames extracted. Check the video file."))
            return

        count = len(frames)
        self.after(0, lambda: self.set_step(0, "done"))
        self.after(0, lambda: self.set_status(
            f"Step 2/3 - Splitting 360 images ({count} frames extracted)..."))
        threading.Thread(target=self._step2_alicevision, daemon=True).start()

    def _step2_alicevision(self):
        self.after(0, lambda: self.set_step(1, "running"))

        frames_folder = self._s["frames_folder"]
        input_dir     = self._s["input_dir"]
        prefix        = frames_folder.name.split("_")[0]
        splits        = self._s["splits"]
        res           = self._s["res"]
        fov           = self._s["fov"] if self._s["use_fov"] else "90"

        output_folder = input_dir / f"{prefix}_{splits}splits_output"
        output_folder.mkdir(parents=True, exist_ok=True)
        self._av_output_folder = output_folder

        env = os.environ.copy()

        if ALICE_PATH:
            sfm_data = str(output_folder / "sfm_data.json")
            env["ALICEVISION_ROOT"] = str(BIN_DIR)
            cmd = [ALICE_PATH,
                   "-i", str(frames_folder), "-o", str(output_folder),
                   "--outSfMData", sfm_data,
                   "--equirectangularNbSplits", splits,
                   "--equirectangularSplitResolution", res,
                   "--fov", fov]
        else:
            env["ALICEVISION_ROOT"] = str(BIN_DIR / "legacy")
            cmd = [ALICE_LEGACY,
                   "-i", str(frames_folder), "-o", str(output_folder),
                   "--equirectangularNbSplits", splits,
                   "--equirectangularSplitResolution", res]

        self._proc = subprocess.Popen(cmd, env=env,
                                      stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        self._proc.wait()

        if not any(True for _ in output_folder.rglob("*") if _.is_file()):
            self.after(0, lambda: self._fail(1,
                "Step 2 failed - AliceVision produced no output. Check split settings."))
            return

        self.after(0, lambda: self.set_step(1, "done"))
        self.after(0, lambda: self.set_status("Step 3/3 - Building combined frame sequence..."))
        threading.Thread(target=self._step3_combine, daemon=True).start()

    def _step3_combine(self):
        self.after(0, lambda: self.set_step(2, "running"))

        av_out     = self._av_output_folder
        rig_folder = av_out / "rig"

        if not rig_folder.exists():
            if av_out.name == "rig":
                rig_folder = av_out
            else:
                self.after(0, lambda: self._fail(2,
                    "Could not find 'rig' subfolder in AliceVision output."))
                return

        combined   = rig_folder / "combined_sequence"
        combined.mkdir(exist_ok=True)
        subfolders = sorted(d for d in rig_folder.iterdir() if d.is_dir() and d != combined)
        max_frames = max((len(list(d.iterdir())) for d in subfolders), default=0)
        total      = max_frames * len(subfolders)

        self.after(0, lambda: self.progress.configure(mode="determinate",
                                                       maximum=max(total, 1), value=0))
        self.after(0, self.progress.stop)

        done = 0
        for i in range(max_frames):
            for folder in subfolders:
                images = sorted(folder.iterdir())
                if i < len(images):
                    dest = combined / f"frame_{i+1:04d}_{folder.name}.jpg"
                    shutil.copy2(images[i], dest)
                done += 1
                v = done
                self.after(0, lambda val=v: self.progress.configure(value=val))

        dest_folder = rig_folder.parent
        for f in combined.iterdir():
            shutil.move(str(f), str(dest_folder / f.name))

        for path in [dest_folder / "rig", dest_folder / "sfm_data.json", combined]:
            if path.exists():
                shutil.rmtree(path) if path.is_dir() else path.unlink()

        self._final_output_folder = str(dest_folder)
        self.after(0, lambda: self._finish(max_frames))


if __name__ == "__main__":
    app = App()
    app.mainloop()

