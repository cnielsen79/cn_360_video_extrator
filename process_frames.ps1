Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class UxTheme {
    [DllImport("uxtheme.dll", CharSet = CharSet.Unicode)]
    public static extern int SetWindowTheme(IntPtr hWnd, string pszSubAppName, string pszSubIdList);
}
"@

$scriptDir            = [System.IO.Path]::GetDirectoryName($MyInvocation.MyCommand.Path)
$binDir               = Join-Path $scriptDir "bin"
$legacyDir            = Join-Path $binDir "legacy"
$ffmpegPath           = Join-Path $binDir "ffmpeg.exe"
$aliceVisionPath      = Join-Path $binDir "aliceVision_split360Images.exe"
$aliceVisionLegacyPath= Join-Path $legacyDir "aliceVision_utils_split360Images.exe"
$ocioPath             = Join-Path $binDir "share/aliceVision/config.ocio"

# ── Colors ─────────────────────────────────────────────────────────────────────
$bgDark      = [System.Drawing.Color]::FromArgb(18, 18, 18)
$bgPanel     = [System.Drawing.Color]::FromArgb(28, 28, 28)
$bgGroup     = [System.Drawing.Color]::FromArgb(36, 36, 36)
$accent      = [System.Drawing.Color]::FromArgb(255, 80, 0)
$accentHover = [System.Drawing.Color]::FromArgb(255, 110, 40)
$textPrimary = [System.Drawing.Color]::White
$textMuted   = [System.Drawing.Color]::FromArgb(160, 160, 160)
$inputBg     = [System.Drawing.Color]::FromArgb(48, 48, 48)
$inputBorder = [System.Drawing.Color]::FromArgb(70, 70, 70)
$green       = [System.Drawing.Color]::FromArgb(80, 200, 120)
$red         = [System.Drawing.Color]::FromArgb(255, 80, 80)

$fontLabel  = New-Object System.Drawing.Font("Segoe UI", 9)
$fontButton = New-Object System.Drawing.Font("Segoe UI Semibold", 10)
$fontSub    = New-Object System.Drawing.Font("Segoe UI", 8)
$fontStep   = New-Object System.Drawing.Font("Segoe UI Semibold", 8)

# ── Helpers ────────────────────────────────────────────────────────────────────
function Set-Status($msg, $color = [System.Drawing.Color]::FromArgb(160,160,160)) {
    $StatusLabel.Text = $msg
    $StatusLabel.ForeColor = $color
    $Form.Refresh()
}

function Set-StepState($stepPanel, $state) {
    # state: "idle" | "running" | "done" | "error"
    $dot  = $stepPanel.Controls | Where-Object { $_.Tag -eq "dot" }
    $lbl  = $stepPanel.Controls | Where-Object { $_.Tag -eq "label" }
    switch ($state) {
        "idle"    { $dot.BackColor = $inputBorder; $lbl.ForeColor = $textMuted }
        "running" { $dot.BackColor = $accent;      $lbl.ForeColor = $textPrimary }
        "done"    { $dot.BackColor = $green;        $lbl.ForeColor = $green }
        "error"   { $dot.BackColor = $red;          $lbl.ForeColor = $red }
    }
    $stepPanel.Refresh()
}

function New-StepIndicator($parent, $x, $y, $w, $text) {
    $p = New-Object System.Windows.Forms.Panel
    $p.Location  = New-Object System.Drawing.Point($x, $y)
    $p.Size      = New-Object System.Drawing.Size($w, 20)
    $p.BackColor = [System.Drawing.Color]::Transparent

    $dot = New-Object System.Windows.Forms.Panel
    $dot.Location  = New-Object System.Drawing.Point(0, 5)
    $dot.Size      = New-Object System.Drawing.Size(10, 10)
    $dot.BackColor = $inputBorder
    $dot.Tag       = "dot"
    $p.Controls.Add($dot)

    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text      = $text
    $lbl.Location  = New-Object System.Drawing.Point(18, 2)
    $lbl.Size      = New-Object System.Drawing.Size(([int]$w - 18), 16)
    $lbl.Font      = $fontStep
    $lbl.ForeColor = $textMuted
    $lbl.BackColor = [System.Drawing.Color]::Transparent
    $lbl.Tag       = "label"
    $p.Controls.Add($lbl)

    $parent.Controls.Add($p)
    return $p
}

function Browse-File($textBox, $filter) {
    $dlg = New-Object System.Windows.Forms.OpenFileDialog
    $dlg.Filter = $filter
    if ($dlg.ShowDialog() -eq "OK") { $textBox.Text = $dlg.FileName }
}

function New-Label($text, $x, $y, $w = 200, $h = 18, $font = $fontLabel, $color = $textMuted) {
    $l = New-Object System.Windows.Forms.Label
    $l.Text = $text; $l.Location = New-Object System.Drawing.Point($x, $y)
    $l.Size = New-Object System.Drawing.Size($w, $h)
    $l.Font = $font; $l.ForeColor = $color; $l.BackColor = [System.Drawing.Color]::Transparent
    return $l
}

function New-TextInput($x, $y, $w, $h = 28) {
    $t = New-Object System.Windows.Forms.TextBox
    $t.Location = New-Object System.Drawing.Point($x, $y)
    $t.Size = New-Object System.Drawing.Size($w, $h)
    $t.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $t.ForeColor = $textPrimary; $t.BackColor = $inputBg
    $t.BorderStyle = "FixedSingle"; $t.AllowDrop = $true
    $t.Add_DragEnter({ $_.Effect = 'Copy' })
    $t.Add_DragDrop({ $this.Text = $_.Data.GetData("FileDrop")[0] })
    return $t
}

function New-SmallInput($x, $y, $w, $default) {
    $t = New-Object System.Windows.Forms.TextBox
    $t.Location = New-Object System.Drawing.Point($x, $y)
    $t.Size = New-Object System.Drawing.Size($w, 28)
    $t.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $t.ForeColor = $textPrimary; $t.BackColor = $inputBg
    $t.BorderStyle = "FixedSingle"; $t.Text = $default; $t.TextAlign = "Center"
    return $t
}

function New-GhostButton($text, $x, $y, $w, $h = 28) {
    $b = New-Object System.Windows.Forms.Button
    $b.Text = $text; $b.Location = New-Object System.Drawing.Point($x, $y)
    $b.Size = New-Object System.Drawing.Size($w, $h)
    $b.Font = $fontStep; $b.ForeColor = $textMuted; $b.BackColor = $bgGroup
    $b.FlatStyle = "Flat"; $b.FlatAppearance.BorderSize = 1
    $b.FlatAppearance.BorderColor = $inputBorder
    $b.Cursor = [System.Windows.Forms.Cursors]::Hand
    $b.Add_MouseEnter({ $this.ForeColor = $textPrimary })
    $b.Add_MouseLeave({ $this.ForeColor = [System.Drawing.Color]::FromArgb(160,160,160) })
    return $b
}

# ── Form ───────────────────────────────────────────────────────────────────────
$Form = New-Object System.Windows.Forms.Form
$Form.Text = "CN - 360 Video Extractor"
$Form.Size = New-Object System.Drawing.Size(520, 560)
$Form.MinimumSize = New-Object System.Drawing.Size(520, 560)
$Form.StartPosition = "CenterScreen"
$Form.BackColor = $bgDark
$Form.ForeColor = $textPrimary
$Form.Font = $fontLabel
$Form.FormBorderStyle = "Sizable"
$Form.MaximizeBox = $false

# ── Header ─────────────────────────────────────────────────────────────────────
$headerPanel = New-Object System.Windows.Forms.Panel
$headerPanel.Location = New-Object System.Drawing.Point(0, 0)
$headerPanel.Size = New-Object System.Drawing.Size(520, 64)
$headerPanel.BackColor = $bgPanel

$titleLabel = New-Object System.Windows.Forms.Label
$titleLabel.Text = "CN"
$titleLabel.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 13)
$titleLabel.ForeColor = $textPrimary
$titleLabel.Location = New-Object System.Drawing.Point(18, 10)
$titleLabel.AutoSize = $true
$titleLabel.BackColor = [System.Drawing.Color]::Transparent
$headerPanel.Controls.Add($titleLabel)

$subtitleLabel = New-Object System.Windows.Forms.Label
$subtitleLabel.Text = "360 Video Extractor"
$subtitleLabel.Font = New-Object System.Drawing.Font("Segoe UI Light", 10)
$subtitleLabel.ForeColor = $accent
$subtitleLabel.Location = New-Object System.Drawing.Point(20, 36)
$subtitleLabel.AutoSize = $true
$subtitleLabel.BackColor = [System.Drawing.Color]::Transparent
$headerPanel.Controls.Add($subtitleLabel)

$headerBorder = New-Object System.Windows.Forms.Panel
$headerBorder.Location = New-Object System.Drawing.Point(0, 63)
$headerBorder.Size = New-Object System.Drawing.Size(520, 1)
$headerBorder.BackColor = $inputBorder
$headerPanel.Controls.Add($headerBorder)
$Form.Controls.Add($headerPanel)

# ── Settings panel ─────────────────────────────────────────────────────────────
$settingsPanel = New-Object System.Windows.Forms.Panel
$settingsPanel.Location = New-Object System.Drawing.Point(16, 76)
$settingsPanel.Size = New-Object System.Drawing.Size(488, 310)
$settingsPanel.BackColor = $bgGroup

$accentLine = New-Object System.Windows.Forms.Panel
$accentLine.Location = New-Object System.Drawing.Point(0, 0)
$accentLine.Size = New-Object System.Drawing.Size(488, 3)
$accentLine.BackColor = $accent
$settingsPanel.Controls.Add($accentLine)

$sectionLbl = New-Object System.Windows.Forms.Label
$sectionLbl.Text = "  SETTINGS"
$sectionLbl.Location = New-Object System.Drawing.Point(14, 10)
$sectionLbl.AutoSize = $true
$sectionLbl.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 9)
$sectionLbl.ForeColor = $accent
$sectionLbl.BackColor = [System.Drawing.Color]::Transparent
$settingsPanel.Controls.Add($sectionLbl)

# Video file
$videoLbl = New-Label "Video file" 14 38 80 18
$settingsPanel.Controls.Add($videoLbl)

$VideoTextBox = New-TextInput 14 56 390 28
$settingsPanel.Controls.Add($VideoTextBox)

$BrowseBtn = New-GhostButton "Browse..." 410 56 64 28
$BrowseBtn.Add_Click({ Browse-File $VideoTextBox "Video files (*.mp4,*.mov,*.avi,*.mkv,*.mxf)|*.mp4;*.mov;*.avi;*.mkv;*.mxf|All files (*.*)|*.*" })
$settingsPanel.Controls.Add($BrowseBtn)

# Row: FPS / Splits / Resolution
$fpsLbl = New-Label "Frames / sec" 14 100 90 18
$settingsPanel.Controls.Add($fpsLbl)
$FpsBox = New-SmallInput 14 118 90 "1"
$settingsPanel.Controls.Add($FpsBox)

$splitsLbl = New-Label "Splits" 120 100 70 18
$settingsPanel.Controls.Add($splitsLbl)
$SplitBox = New-SmallInput 120 118 70 "8"
$settingsPanel.Controls.Add($SplitBox)

$resLbl = New-Label "Split res (px)" 206 100 110 18
$settingsPanel.Controls.Add($resLbl)
$ResBox = New-SmallInput 206 118 110 "1200"
$settingsPanel.Controls.Add($ResBox)

# FOV toggle
$FovCheckBox = New-Object System.Windows.Forms.CheckBox
$FovCheckBox.Text = "Custom FOV"
$FovCheckBox.Location = New-Object System.Drawing.Point(332, 100)
$FovCheckBox.Size = New-Object System.Drawing.Size(110, 18)
$FovCheckBox.Font = $fontLabel
$FovCheckBox.ForeColor = $textMuted
$FovCheckBox.BackColor = [System.Drawing.Color]::Transparent
$FovCheckBox.Checked = $false
$FovCheckBox.Add_CheckedChanged({ $FovBox.Enabled = $FovCheckBox.Checked })
$settingsPanel.Controls.Add($FovCheckBox)

$fovLbl = New-Label "FOV (deg)" 272 100 80 18
$fovLbl.Visible = $false   # replaced by checkbox label above
$FovBox = New-SmallInput 432 118 50 "90"
$FovBox.Enabled = $false
$settingsPanel.Controls.Add($FovBox)

# Divider
$div = New-Object System.Windows.Forms.Panel
$div.Location = New-Object System.Drawing.Point(14, 158)
$div.Size = New-Object System.Drawing.Size(460, 1)
$div.BackColor = $inputBorder
$settingsPanel.Controls.Add($div)

# Pipeline steps indicator
$stepsLbl = New-Label "Pipeline" 14 168 60 16 $fontStep $textMuted
$settingsPanel.Controls.Add($stepsLbl)

$step1Indicator = New-StepIndicator $settingsPanel 14 188 220 "1  Extract frames from video"
$step2Indicator = New-StepIndicator $settingsPanel 14 212 220 "2  Split 360 images"
$step3Indicator = New-StepIndicator $settingsPanel 14 236 220 "3  Build combined sequence"

# Progress bar
$ProgressBar = New-Object System.Windows.Forms.ProgressBar
$ProgressBar.Location = New-Object System.Drawing.Point(14, 268)
$ProgressBar.Size = New-Object System.Drawing.Size(460, 10)
$ProgressBar.Minimum = 0
$ProgressBar.Maximum = 100
$ProgressBar.Value = 0
$ProgressBar.Visible = $false
$ProgressBar.Add_HandleCreated({
    [UxTheme]::SetWindowTheme($this.Handle, "", "") | Out-Null
    $this.ForeColor = [System.Drawing.Color]::FromArgb(255, 80, 0)
    $this.BackColor = [System.Drawing.Color]::FromArgb(48, 48, 48)
})
$settingsPanel.Controls.Add($ProgressBar)

$Form.Controls.Add($settingsPanel)

# ── Run button ─────────────────────────────────────────────────────────────────
$RunButton = New-Object System.Windows.Forms.Button
$RunButton.Text = "PROCESS VIDEO"
$RunButton.Location = New-Object System.Drawing.Point(16, 398)
$RunButton.Size = New-Object System.Drawing.Size(488, 48)
$RunButton.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 12)
$RunButton.ForeColor = $textPrimary
$RunButton.BackColor = $accent
$RunButton.FlatStyle = "Flat"
$RunButton.FlatAppearance.BorderSize = 0
$RunButton.Cursor = [System.Windows.Forms.Cursors]::Hand
$RunButton.Add_MouseEnter({ $this.BackColor = $accentHover })
$RunButton.Add_MouseLeave({ $this.BackColor = $accent })
$Form.Controls.Add($RunButton)

# Open output button (hidden until done)
$OpenOutputBtn = New-GhostButton "Open Output Folder" 16 458 200 32
$OpenOutputBtn.Visible = $false
$OpenOutputBtn.Add_Click({
    if ($script:finalOutputFolder) { Start-Process "explorer.exe" $script:finalOutputFolder }
})
$Form.Controls.Add($OpenOutputBtn)

# ── Status bar ─────────────────────────────────────────────────────────────────
$statusBar = New-Object System.Windows.Forms.Panel
$statusBar.Location = New-Object System.Drawing.Point(0, 502)
$statusBar.Size = New-Object System.Drawing.Size(520, 50)
$statusBar.BackColor = $bgPanel

$statusBorder = New-Object System.Windows.Forms.Panel
$statusBorder.Location = New-Object System.Drawing.Point(0, 0)
$statusBorder.Size = New-Object System.Drawing.Size(520, 1)
$statusBorder.BackColor = $inputBorder
$statusBar.Controls.Add($statusBorder)

$StatusLabel = New-Object System.Windows.Forms.Label
$StatusLabel.Text = "Ready"
$StatusLabel.Location = New-Object System.Drawing.Point(14, 8)
$StatusLabel.Size = New-Object System.Drawing.Size(490, 16)
$StatusLabel.Font = $fontSub
$StatusLabel.ForeColor = $textMuted
$StatusLabel.BackColor = [System.Drawing.Color]::Transparent
$statusBar.Controls.Add($StatusLabel)

$versionLabel = New-Object System.Windows.Forms.Label
$versionLabel.Text = "cn360.app"
$versionLabel.Location = New-Object System.Drawing.Point(14, 28)
$versionLabel.AutoSize = $true
$versionLabel.Font = $fontSub
$versionLabel.ForeColor = [System.Drawing.Color]::FromArgb(70, 70, 70)
$versionLabel.BackColor = [System.Drawing.Color]::Transparent
$statusBar.Controls.Add($versionLabel)

$Form.Controls.Add($statusBar)

# ── Pipeline logic ─────────────────────────────────────────────────────────────
$RunButton.Add_Click({
    # Validate
    if (-not $VideoTextBox.Text) {
        [System.Windows.Forms.MessageBox]::Show("Please select a video file.", "Missing input"); return
    }
    if ($FpsBox.Text -notmatch '^[0-9]*\.?[0-9]+$') {
        [System.Windows.Forms.MessageBox]::Show("Frames/sec must be a number.", "Invalid"); return
    }
    if ($SplitBox.Text -notmatch '^\d+$') {
        [System.Windows.Forms.MessageBox]::Show("Splits must be a whole number.", "Invalid"); return
    }
    if ($ResBox.Text -notmatch '^\d+$') {
        [System.Windows.Forms.MessageBox]::Show("Split resolution must be a whole number.", "Invalid"); return
    }
    if ($FovCheckBox.Checked -and $FovBox.Text -notmatch '^\d+$') {
        [System.Windows.Forms.MessageBox]::Show("FOV must be a whole number.", "Invalid"); return
    }
    if (-not (Test-Path $ffmpegPath)) {
        [System.Windows.Forms.MessageBox]::Show("ffmpeg.exe not found in the bin folder.", "Missing binary"); return
    }

    # Store all settings in script scope so timer callbacks can reach them
    $script:p_videoPath    = $VideoTextBox.Text
    $script:p_fps          = $FpsBox.Text
    $script:p_splits       = $SplitBox.Text
    $script:p_resolution   = $ResBox.Text
    $script:p_useFov       = $FovCheckBox.Checked
    $script:p_fov          = $FovBox.Text
    $script:p_inputDir     = [System.IO.Path]::GetDirectoryName($script:p_videoPath)
    $script:p_videoName    = [System.IO.Path]::GetFileNameWithoutExtension($script:p_videoPath)
    $script:p_framesFolder = Join-Path $script:p_inputDir "$($script:p_videoName)_$($script:p_fps)fps"

    # Reset UI
    $RunButton.Enabled     = $false
    $OpenOutputBtn.Visible = $false
    Set-StepState $step1Indicator "idle"
    Set-StepState $step2Indicator "idle"
    Set-StepState $step3Indicator "idle"
    $ProgressBar.Style              = [System.Windows.Forms.ProgressBarStyle]::Marquee
    $ProgressBar.MarqueeAnimationSpeed = 20
    $ProgressBar.Visible            = $true

    # ── Step 1: FFmpeg ─────────────────────────────────────────────────────────
    Set-StepState $step1Indicator "running"
    Set-Status "Step 1/3 - Extracting frames..." $textMuted

    if (!(Test-Path $script:p_framesFolder)) { New-Item -ItemType Directory -Path $script:p_framesFolder | Out-Null }
    $script:p_outputPath = Join-Path $script:p_framesFolder "image_%04d.jpg"

    $script:pipe_proc = Start-Process -FilePath $ffmpegPath `
        -ArgumentList "-i `"$($script:p_videoPath)`" -vf fps=$($script:p_fps) -qscale:v 1 `"$($script:p_outputPath)`"" `
        -NoNewWindow -PassThru

    $script:pipe_timer = New-Object System.Windows.Forms.Timer
    $script:pipe_timer.Interval = 250
    $script:pipe_timer.Add_Tick({
        if (-not $script:pipe_proc.HasExited) { return }
        $script:pipe_timer.Stop()

        $frameCount = (Get-ChildItem $script:p_framesFolder -File -Filter "*.jpg" -ErrorAction SilentlyContinue).Count
        if ($frameCount -eq 0) {
            Set-StepState $step1Indicator "error"
            $ProgressBar.Visible = $false
            $RunButton.Enabled   = $true
            Set-Status "Step 1 failed — no frames were extracted. Check the video file." $red
            [System.Windows.Forms.MessageBox]::Show("FFmpeg ran but produced no frames. Check the video file and try again.", "Error")
            return
        }
        Set-StepState $step1Indicator "done"
        Set-Status "Step 2/3 - Splitting 360 images ($frameCount frames extracted)..." $textMuted
        Set-StepState $step2Indicator "running"

        # ── Step 2: AliceVision ───────────────────────────────────────────────
        # Auto-detect which binary is available; prefer the newer one
        $folderName = [System.IO.Path]::GetFileName($script:p_framesFolder)
        $prefix     = ($folderName -split "_")[0]

        $hasNew    = Test-Path $aliceVisionPath
        $hasLegacy = Test-Path $aliceVisionLegacyPath

        if (-not $hasNew -and -not $hasLegacy) {
            Set-StepState $step2Indicator "error"
            $ProgressBar.Visible = $false
            $RunButton.Enabled   = $true
            Set-Status "No AliceVision binary found in bin/ or bin/legacy/." $red
            [System.Windows.Forms.MessageBox]::Show("Could not find aliceVision_split360Images.exe in the bin folder, nor aliceVision_utils_split360Images.exe in bin/legacy.", "Missing binary")
            return
        }

        if ($hasNew) {
            # New binary: supports --fov flag
            $fovArg = if ($script:p_useFov) { $script:p_fov } else { "90" }
            $script:av_outputFolder = Join-Path $script:p_inputDir "${prefix}_$($script:p_splits)splits_output"
            $outSfMData = Join-Path $script:av_outputFolder "sfm_data.json"
            if (!(Test-Path $script:av_outputFolder)) { New-Item -ItemType Directory -Path $script:av_outputFolder | Out-Null }
            [System.Environment]::SetEnvironmentVariable("ALICEVISION_ROOT", $binDir, "Process")
            $script:p_avArgs = "-i `"$($script:p_framesFolder)`" -o `"$($script:av_outputFolder)`" --outSfMData `"$outSfMData`" --equirectangularNbSplits $($script:p_splits) --equirectangularSplitResolution $($script:p_resolution) --fov $fovArg"
            $script:p_avExe  = $aliceVisionPath
        } else {
            # Legacy binary: no --fov flag
            $script:av_outputFolder = Join-Path $script:p_inputDir "${prefix}_$($script:p_splits)splits_output"
            if (!(Test-Path $script:av_outputFolder)) { New-Item -ItemType Directory -Path $script:av_outputFolder | Out-Null }
            [System.Environment]::SetEnvironmentVariable("ALICEVISION_ROOT", $legacyDir, "Process")
            $script:p_avArgs = "-i `"$($script:p_framesFolder)`" -o `"$($script:av_outputFolder)`" --equirectangularNbSplits $($script:p_splits) --equirectangularSplitResolution $($script:p_resolution)"
            $script:p_avExe  = $aliceVisionLegacyPath
        }

        $script:pipe_proc = Start-Process -FilePath $script:p_avExe -ArgumentList $script:p_avArgs -NoNewWindow -PassThru

        $script:pipe_timer2 = New-Object System.Windows.Forms.Timer
        $script:pipe_timer2.Interval = 250
        $script:pipe_timer2.Add_Tick({
            if (-not $script:pipe_proc.HasExited) { return }
            $script:pipe_timer2.Stop()
            [System.Environment]::SetEnvironmentVariable("ALICEVISION_ROOT", $null, "Process")

        $avOutputCount = (Get-ChildItem $script:av_outputFolder -Recurse -File -ErrorAction SilentlyContinue).Count
            if ($avOutputCount -eq 0) {
                Set-StepState $step2Indicator "error"
                $ProgressBar.Visible = $false
                $RunButton.Enabled   = $true
                Set-Status "Step 2 failed — AliceVision produced no output files." $red
                [System.Windows.Forms.MessageBox]::Show("AliceVision ran but produced no output. Check the split settings and try again.", "Error")
                return
            }

            Set-StepState $step2Indicator "done"
            Set-Status "Step 3/3 - Building combined frame sequence..." $textMuted
            Set-StepState $step3Indicator "running"

            # ── Step 3: Combine ───────────────────────────────────────────────
            $avOut     = $script:av_outputFolder
            $rigFolder = Join-Path $avOut "rig"

            if (-not (Test-Path $rigFolder)) {
                if ([System.IO.Path]::GetFileName($avOut) -eq "rig") {
                    $rigFolder = $avOut
                } else {
                    Set-StepState $step3Indicator "error"
                    $ProgressBar.Visible = $false
                    $RunButton.Enabled   = $true
                    Set-Status "Could not find 'rig' subfolder in AliceVision output." $red
                    return
                }
            }

            $combinedFolder = Join-Path $rigFolder "combined_sequence"
            if (!(Test-Path $combinedFolder)) { New-Item -ItemType Directory -Path $combinedFolder | Out-Null }

            $subfolders = Get-ChildItem $rigFolder -Directory |
                          Where-Object { $_.FullName -ne $combinedFolder } |
                          Sort-Object Name
            $maxFrames = ($subfolders | ForEach-Object { (Get-ChildItem $_.FullName -File).Count } | Measure-Object -Maximum).Maximum
            $total     = $maxFrames * $subfolders.Count

            $ProgressBar.Style   = [System.Windows.Forms.ProgressBarStyle]::Continuous
            $ProgressBar.Maximum = [Math]::Max($total, 1)
            $ProgressBar.Value   = 0

            $done = 0
            for ($i = 0; $i -lt $maxFrames; $i++) {
                foreach ($folder in $subfolders) {
                    $images = Get-ChildItem $folder.FullName -File | Sort-Object Name
                    if ($i -lt $images.Count) {
                        $dest = "$combinedFolder\frame_$([System.String]::Format('{0:D4}', ($i+1)))_$($folder.Name).jpg"
                        Copy-Item $images[$i].FullName -Destination $dest
                    }
                    $done++
                    $ProgressBar.Value = [Math]::Min($done, $total)
                    [System.Windows.Forms.Application]::DoEvents()
                }
            }

            $destFolder = (Get-Item $rigFolder).Parent.FullName
            Get-ChildItem $combinedFolder | ForEach-Object { Move-Item $_.FullName -Destination $destFolder -Force }
            foreach ($p in @("$destFolder\rig", "$destFolder\sfm_data.json", $combinedFolder)) {
                if (Test-Path $p) { Remove-Item $p -Recurse -Force }
            }

            $script:finalOutputFolder = $destFolder
            Set-StepState $step3Indicator "done"
            $ProgressBar.Visible   = $false
            $RunButton.Enabled     = $true
            $OpenOutputBtn.Visible = $true
            Set-Status "Done! $maxFrames frames ready in: $destFolder" $green
            [System.Windows.Forms.MessageBox]::Show("All done!`n`n$maxFrames frames saved to:`n$destFolder", "Complete")
        })
        $script:pipe_timer2.Start()
    })
    $script:pipe_timer.Start()
})

if (-not (Test-Path $ocioPath)) {
    Set-Status "Warning: config.ocio not found - AliceVision OCIO config may be missing." $red
}

$Form.ShowDialog()



