#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# CN 360 Extractor — macOS .app + .dmg builder
# Run this script on a Mac from the repo root:
#
#   chmod +x macos/build_dmg.sh
#   ./macos/build_dmg.sh
#
# Requirements:
#   - macOS 11+
#   - Python 3 with tkinter  (brew install python-tk  or  python.org installer)
#   - Optional: ffmpeg and aliceVision binaries in bin/ for a portable build
# ─────────────────────────────────────────────────────────────────────────────

set -e

APP_NAME="CN 360 Extractor"
BUNDLE_NAME="CN360Extractor"
DMG_NAME="${BUNDLE_NAME}.dmg"
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$SCRIPT_DIR/build_mac"
APP_DIR="$BUILD_DIR/${BUNDLE_NAME}.app"

echo ">>> Building: $APP_NAME"
echo ">>> Source:   $SCRIPT_DIR"
echo ""

# ── Clean previous build ──────────────────────────────────────────────────────
rm -rf "$BUILD_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

# ── Copy app files ────────────────────────────────────────────────────────────
cp "$SCRIPT_DIR/process_frames.py"   "$APP_DIR/Contents/Resources/"
cp "$SCRIPT_DIR/macos/Info.plist"    "$APP_DIR/Contents/"

# Copy bin/ if it exists (portable mode — place macOS binaries there)
if [ -d "$SCRIPT_DIR/bin" ]; then
    cp -r "$SCRIPT_DIR/bin" "$APP_DIR/Contents/Resources/bin"
    echo ">>> Bundled bin/ directory"
fi

# ── Write launcher script ─────────────────────────────────────────────────────
LAUNCHER="$APP_DIR/Contents/MacOS/launch"
cat > "$LAUNCHER" << 'EOF'
#!/bin/bash
RESOURCES="$(cd "$(dirname "$0")/../Resources" && pwd)"
cd "$RESOURCES"

# Prefer Homebrew python-tk build, then system python3
for py in /opt/homebrew/bin/python3 /usr/local/bin/python3 python3; do
    if command -v "$py" &>/dev/null && "$py" -c "import tkinter" &>/dev/null 2>&1; then
        exec "$py" "$RESOURCES/process_frames.py"
    fi
done

osascript -e 'display alert "Python 3 + tkinter not found" message "Install from python.org or run: brew install python-tk"'
exit 1
EOF
chmod +x "$LAUNCHER"

echo ">>> .app bundle created: $APP_DIR"

# ── Optional: code sign (skip if no certificate) ─────────────────────────────
if security find-identity -v -p codesigning 2>/dev/null | grep -q "Developer ID"; then
    CERT=$(security find-identity -v -p codesigning | grep "Developer ID" | head -1 | awk '{print $3}')
    echo ">>> Code signing with: $CERT"
    codesign --deep --force --options runtime --sign "$CERT" "$APP_DIR"
else
    echo ">>> No Developer ID found — skipping code signing (app will show Gatekeeper warning)"
    echo "    Users can right-click > Open to bypass it."
    # Ad-hoc sign so macOS will at least allow local execution
    codesign --deep --force --sign - "$APP_DIR"
fi

# ── Create DMG ────────────────────────────────────────────────────────────────
STAGING="$BUILD_DIR/dmg_staging"
mkdir -p "$STAGING"
cp -r "$APP_DIR" "$STAGING/"

# Symlink to /Applications for drag-to-install
ln -s /Applications "$STAGING/Applications"

DMG_PATH="$SCRIPT_DIR/$DMG_NAME"
rm -f "$DMG_PATH"

hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$STAGING" \
    -ov \
    -format UDZO \
    -imagekey zlib-level=9 \
    "$DMG_PATH"

echo ""
echo ">>> Done!"
echo ">>> DMG: $DMG_PATH"
echo ""
echo "Distribute $DMG_NAME — users open it, drag the app to Applications, and launch."

