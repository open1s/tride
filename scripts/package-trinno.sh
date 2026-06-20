#!/usr/bin/env bash
set -e

cd "$(dirname "$0")/.." || { echo "Run from repo root"; exit 1; }

TRINNO_PATH="${TRINNO_PATH:-/Users/gaosg/Projects/trinno}"
STAGING_DIR=".build/trinno-research"
VSIX_OUTPUT="build/extensions/trinno-research.vsix"

echo "=== Packaging trinno-research extension ==="

# -------------------------------------------------
# 1. Verify and compile trinno
# -------------------------------------------------
if [ ! -d "$TRINNO_PATH" ]; then
  echo "Error: trinno project not found at $TRINNO_PATH"
  exit 1
fi

echo "[1/4] Compiling trinno..."
(cd "$TRINNO_PATH" && npm run compile)

# -------------------------------------------------
# 2. Copy compiled output + production deps
# -------------------------------------------------
echo "[2/4] Staging extension files..."
rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"

# Copy compiled output
cp -r "$TRINNO_PATH/dist" "$STAGING_DIR/dist"

# Copy package.json, README, CHANGELOG, LICENSE
cp "$TRINNO_PATH/package.json" "$STAGING_DIR/"
[ -f "$TRINNO_PATH/README.md" ] && cp "$TRINNO_PATH/README.md" "$STAGING_DIR/"
[ -f "$TRINNO_PATH/CHANGELOG.md" ] && cp "$TRINNO_PATH/CHANGELOG.md" "$STAGING_DIR/"
[ -f "$TRINNO_PATH/LICENSE" ] && cp "$TRINNO_PATH/LICENSE" "$STAGING_DIR/"

# Copy webview assets (already in dist/chat/webview/ from compile step)
# Copy icon if exists
[ -f "$TRINNO_PATH/icon.png" ] && cp "$TRINNO_PATH/icon.png" "$STAGING_DIR/"

# -------------------------------------------------
# 3. Install production dependencies
# -------------------------------------------------
echo "[3/4] Installing production dependencies..."
cp "$TRINNO_PATH/package.json" "$STAGING_DIR/package.json"
cp "$TRINNO_PATH/yarn.lock" "$STAGING_DIR/" 2>/dev/null || true
(cd "$STAGING_DIR" && npm install --production --ignore-scripts)

# Verify main entry exists
if [ ! -f "$STAGING_DIR/dist/extension.js" ]; then
  echo "Error: extension.js not found after staging"
  exit 1
fi

# -------------------------------------------------
# 4. Package as VSIX
# -------------------------------------------------
echo "[4/4] Creating VSIX..."
mkdir -p "$(dirname "$VSIX_OUTPUT")"

# Use vsce to package from the staging dir
(cd "$STAGING_DIR" && vsce package --out "../../$VSIX_OUTPUT" --no-update-package-json 2>&1) || {
  # If vsce fails (e.g. missing icon, repository), try with --allow-missing-repo
  echo "  Retrying with relaxed options..."
  (cd "$STAGING_DIR" && vsce package --out "../../$VSIX_OUTPUT" --no-update-package-json --allow-missing-repo 2>&1) || {
    # Fallback: manual VSIX creation
    echo "  vsce failed, creating manual VSIX..."
    node -e "
    const fs = require('fs');
    const path = require('path');
    const { execSync } = require('child_process');

    const staging = path.resolve('$STAGING_DIR');
    const vsixPath = path.resolve('$VSIX_OUTPUT');
    
    // Create VSIX using zip (it's just a zip file with .vsix extension)
    execSync(\`cd \"\${staging}\" && zip -r \"\${vsixPath}\" . -x \"node_modules/.cache/**\" \"node_modules/.bin/**\"\`, { stdio: 'inherit' });
    "
  }
}

echo ""
echo "=== VSIX created at $VSIX_OUTPUT ==="

# Compute SHA256 for product.json
SHA256=$(shasum -a 256 "$VSIX_OUTPUT" | cut -d' ' -f1)
echo "SHA256: $SHA256"
