#!/usr/bin/env bash
set -e

cd "$(dirname "$0")/.." || { echo "Run from repo root"; exit 1; }

BRANDING_DIR="build/branding"

echo "=== Installing Trinno branding ==="

# -------------------------------------------------
# 0. Re-render brand assets from SVG if needed
# -------------------------------------------------
if [ ! -f "$BRANDING_DIR/trinno.icns" ] || [ ! -f "$BRANDING_DIR/trinno.ico" ]; then
  if ! command -v rsvg-convert >/dev/null 2>&1; then
    echo "Error: rsvg-convert not found. Install via 'brew install librsvg'"
    exit 1
  fi

  echo "[1/4] Rendering Trinno PNGs..."
  for size in 16 32 48 64 70 128 150 256 512 1024; do
    rsvg-convert -w $size -h $size "$BRANDING_DIR/trinno-logo.svg" -o "$BRANDING_DIR/trinno-logo-${size}.png"
  done
  # Mark (monochrome)
  for size in 16 24 32 48 64; do
    rsvg-convert -w $size -h $size "$BRANDING_DIR/trinno-mark.svg" -o "$BRANDING_DIR/trinno-mark-${size}.png"
  done

  echo "[2/4] Building macOS .icns..."
  mkdir -p "$BRANDING_DIR/trinno.iconset"
  for size_pair in "16x16" "32x32" "64x64" "128x128" "256x256" "512x512" "1024x1024"; do
    size=$(echo $size_pair | cut -dx -f1)
    rsvg-convert -w $size -h $size "$BRANDING_DIR/trinno-logo.svg" -o "$BRANDING_DIR/trinno.iconset/icon_${size_pair}.png"
    if [ "$size" -lt "512" ]; then
      size2x=$((size*2))
      rsvg-convert -w $size2x -h $size2x "$BRANDING_DIR/trinno-logo.svg" -o "$BRANDING_DIR/trinno.iconset/icon_${size_pair}@2x.png"
    fi
  done
  iconutil -c icns "$BRANDING_DIR/trinno.iconset" -o "$BRANDING_DIR/trinno.icns"
  rm -rf "$BRANDING_DIR/trinno.iconset"

  echo "[3/4] Building Windows .ico..."
  if command -v magick >/dev/null 2>&1; then
    magick "$BRANDING_DIR/trinno-logo-16.png" \
           "$BRANDING_DIR/trinno-logo-32.png" \
           "$BRANDING_DIR/trinno-logo-48.png" \
           "$BRANDING_DIR/trinno-logo-64.png" \
           "$BRANDING_DIR/trinno-logo-128.png" \
           "$BRANDING_DIR/trinno-logo-256.png" \
           "$BRANDING_DIR/trinno.ico"
  fi

  echo "[4/4] Generating extension icon..."
  cp "$BRANDING_DIR/trinno-logo-128.png" "$BRANDING_DIR/extension-icon.png"
fi

# -------------------------------------------------
# Install icons at the conventional locations
# (overwrite upstream assets so build pipeline picks them up automatically)
# -------------------------------------------------
echo "Installing icons at conventional locations..."

# macOS
cp "$BRANDING_DIR/trinno.icns"       "resources/darwin/code.icns"

# Windows
cp "$BRANDING_DIR/trinno.ico"               "resources/win32/code.ico"
cp "$BRANDING_DIR/trinno-logo-70.png"       "resources/win32/code_70x70.png"
cp "$BRANDING_DIR/trinno-logo-150.png"      "resources/win32/code_150x150.png"

# Linux
cp "$BRANDING_DIR/trinno-logo-512.png"      "resources/linux/code.png"

echo ""
echo "Branding installed."
echo ""
echo "File layout after install:"
ls -lh resources/darwin/code.icns           resources/win32/code.ico \
      resources/win32/code_70x70.png        resources/win32/code_150x150.png \
      resources/linux/code.png 2>/dev/null | awk '{printf "  %-45s %s\n", $NF, $5}'
