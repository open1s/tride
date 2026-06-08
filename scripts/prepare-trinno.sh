#!/usr/bin/env bash
set -e

cd "$(dirname "$0")/.." || { echo "Run from repo root"; exit 1; }

echo "=== Preparing trinno IDE ==="

# -------------------------------------------------
# 1. Apply product.json overlay
# -------------------------------------------------
echo "[1/6] Patching product.json..."
cp product.json{,.bak}
jq -s '.[0] * .[1]' product.json build/trinno-product-overlay.json > product.json.tmp
mv product.json.tmp product.json

# -------------------------------------------------
# 2. Update package.json metadata
# -------------------------------------------------
echo "[2/6] Patching package.json..."
cp package.json{,.bak}
jq '.version = "0.1.0"' package.json > package.json.tmp
mv package.json.tmp package.json

# Replace publisher name in package.json
sed -i '' 's/Microsoft Corporation/open1s/g' package.json

# -------------------------------------------------
# 3. Update electron build config
# -------------------------------------------------
echo "[3/6] Patching build/electron config..."
sed -i '' 's/Microsoft Corporation/open1s/g' build/lib/electron.ts

# -------------------------------------------------
# 4. Update Linux packaging metadata
# -------------------------------------------------
echo "[4/6] Patching Linux packaging templates..."

# appdata.xml
if [ -f resources/linux/code.appdata.xml ]; then
  sed -i '' 's|Visual Studio Code|Trinno IDE|g' resources/linux/code.appdata.xml
  sed -i '' 's|https://code.visualstudio.com|https://github.com/open1s/tride|g' resources/linux/code.appdata.xml
  sed -i '' 's|https://code.visualstudio.com/docs/setup/linux|https://github.com/open1s/tride|g' resources/linux/code.appdata.xml
  sed -i '' 's|https://code.visualstudio.com/home/home-screenshot-linux-lg.png||g' resources/linux/code.appdata.xml
fi

# Debian control
if [ -f resources/linux/debian/control.template ]; then
  sed -i '' 's|Microsoft Corporation <vscode-linux@microsoft.com>|open1s <hello@open1s.org>|g' resources/linux/debian/control.template
  sed -i '' 's|Visual Studio Code|Trinno IDE|g' resources/linux/debian/control.template
  sed -i '' 's|https://code.visualstudio.com|https://github.com/open1s/tride|g' resources/linux/debian/control.template
fi

# RPM spec
if [ -f resources/linux/rpm/code.spec.template ]; then
  sed -i '' 's|Microsoft Corporation|open1s|g' resources/linux/rpm/code.spec.template
  sed -i '' 's|Visual Studio Code Team <vscode-linux@microsoft.com>|open1s <hello@open1s.org>|g' resources/linux/rpm/code.spec.template
  sed -i '' 's|Visual Studio Code|Trinno IDE|g' resources/linux/rpm/code.spec.template
  sed -i '' 's|https://code.visualstudio.com|https://github.com/open1s/tride|g' resources/linux/rpm/code.spec.template
fi

# -------------------------------------------------
# 5. Update Windows installer metadata
# -------------------------------------------------
echo "[5/6] Patching Windows packaging templates..."
if [ -f build/win32/code.iss ]; then
  sed -i '' 's|https://code.visualstudio.com|https://github.com/open1s/tride|g' build/win32/code.iss
  sed -i '' 's|Microsoft Corporation|open1s|g' build/win32/code.iss
fi

# -------------------------------------------------
# 6. Disable telemetry in source
# -------------------------------------------------
echo "[6/6] Disabling telemetry..."
# Set telemetry level to off by default in product.json
jq '.enableTelemetry = false' product.json > product.json.tmp && mv product.json.tmp product.json

echo ""
echo "=== trinno IDE preparation complete ==="
echo "Run 'npm install' then 'npm run watch' to build in dev mode"
echo "Or 'npm run gulp vscode-darwin-arm64' to package for macOS"
