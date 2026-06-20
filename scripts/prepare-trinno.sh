#!/usr/bin/env bash
set -e

cd "$(dirname "$0")/.." || { echo "Run from repo root"; exit 1; }

echo "=== Preparing Trinno Research IDE ==="

TRINNO_PATH="${TRINNO_PATH:-/Users/gaosg/Projects/trinno}"
BUILTIN_EXT_DIR="build/extensions"
TRINNO_VERSION=""
TRINNO_SHA256=""

# -------------------------------------------------
# 1. Apply product.json overlay (selective deep merge)
# -------------------------------------------------
echo "[1/8] Patching product.json..."
cp product.json{,.bak}

# Install branding (icons, splash) from build/branding/ into resources/
bash scripts/install-branding.sh

# Merge overlay fields, but deep-merge defaultChatAgent to preserve
# Copilot-specific fields (walkthroughCommand, entitlements, etc.)
# that the VS Code UI expects.
jq -s '
  (.[0] * .[1]) as $merged |
  (.[0].defaultChatAgent // {}) as $upstream |
  (.[1].defaultChatAgent // null) as $overlay |
  if $overlay then
    $merged | .defaultChatAgent = ($upstream * $overlay)
  else
    $merged
  end
' product.json build/trinno-product-overlay.json > product.json.tmp
mv product.json.tmp product.json

# -------------------------------------------------
# 2. Build and bundle trinno-research extension
# -------------------------------------------------
echo "[2/8] Building trinno-research extension..."

if [ -d "$TRINNO_PATH" ]; then
  echo "  Compiling trinno..."
  (cd "$TRINNO_PATH" && npm run compile)

  STAGING_DIR=".build/trinno-research"
  rm -rf "$STAGING_DIR"
  mkdir -p "$STAGING_DIR"

  cp -r "$TRINNO_PATH/dist" "$STAGING_DIR/dist"
  cp "$TRINNO_PATH/package.json" "$STAGING_DIR/"
  [ -f "$TRINNO_PATH/README.md" ] && cp "$TRINNO_PATH/README.md" "$STAGING_DIR/"
  [ -f "$TRINNO_PATH/CHANGELOG.md" ] && cp "$TRINNO_PATH/CHANGELOG.md" "$STAGING_DIR/"
  [ -f "$TRINNO_PATH/LICENSE" ] && cp "$TRINNO_PATH/LICENSE" "$STAGING_DIR/"
  [ -f "$TRINNO_PATH/icon.png" ] && cp "$TRINNO_PATH/icon.png" "$STAGING_DIR/"

  echo "  Copying production dependencies..."
  # Copy only production deps (not devDependencies) from trinno project
  mkdir -p "$STAGING_DIR/node_modules"
  PROD_DEPS=$(jq -r '.dependencies // {} | keys[]' "$TRINNO_PATH/package.json" 2>/dev/null || echo "")
  for dep in $PROD_DEPS; do
    if [ -d "$TRINNO_PATH/node_modules/$dep" ]; then
      cp -R "$TRINNO_PATH/node_modules/$dep" "$STAGING_DIR/node_modules/" 2>/dev/null || true
    fi
  done
  # Also copy .bin for any needed scripts
  [ -d "$TRINNO_PATH/node_modules/.bin" ] && cp -R "$TRINNO_PATH/node_modules/.bin" "$STAGING_DIR/node_modules/" 2>/dev/null || true

  # Inject Trinno IDE icon into the extension VSIX
  if [ -f "build/branding/trinno-logo-128.png" ]; then
    cp "build/branding/trinno-logo-128.png" "$STAGING_DIR/icon.png"
  fi

  echo "  Creating VSIX..."
  mkdir -p "$BUILTIN_EXT_DIR"
  VSIX_PATH="$BUILTIN_EXT_DIR/trinno-research.vsix"
  # Create VSIX using zip (VSIX is just a renamed zip archive)
  rm -f "$VSIX_PATH"
  (cd "$STAGING_DIR" && zip -qr "../../$VSIX_PATH" . -x "*.map" "*.ts" "*.tsbuildinfo" ".bin/*") 2>&1 || {
    # Fallback: try vsce without repo requirement
    vsce package --out "../../$VSIX_PATH" --no-dependencies --no-git-tag-version 2>&1 | tail -5 || true
  }
  echo "  VSIX created"

  TRINNO_SHA256=$(shasum -a 256 "$VSIX_PATH" | cut -d' ' -f1)
  TRINNO_VERSION=$(jq -r '.version' "$TRINNO_PATH/package.json")
  echo "  trinno-research@$TRINNO_VERSION packaged (SHA256: ${TRINNO_SHA256:0:16}...)"
else
  echo "  Warning: trinno project not found at $TRINNO_PATH, skipping"
fi

# -------------------------------------------------
# 3. Download/bundle Tinymist Typst extension
# -------------------------------------------------
echo "[3/8] Bundling Tinymist Typst extension..."

TINYMIST_VERSION="0.15.0"
TINYMIST_VSIX="$BUILTIN_EXT_DIR/tinymist-universal.vsix"
TINYMIST_SHA256=""

if [ ! -f "$TINYMIST_VSIX" ]; then
  echo "  Downloading Tinymist v$TINYMIST_VERSION..."
  mkdir -p "$BUILTIN_EXT_DIR"
  curl -sL --max-time 30 --connect-timeout 10 -o "$TINYMIST_VSIX.tmp" \
    "https://github.com/Myriad-Dreamin/tinymist/releases/download/v${TINYMIST_VERSION}/tinymist-universal.vsix" \
    && mv "$TINYMIST_VSIX.tmp" "$TINYMIST_VSIX" \
    || echo "  Warning: Tinymist download failed, will skip (network may be unreachable)"
fi

if [ -f "$TINYMIST_VSIX" ]; then
  TINYMIST_SHA256=$(shasum -a 256 "$TINYMIST_VSIX" | cut -d' ' -f1)
  echo "  SHA256: ${TINYMIST_SHA256:0:16}..."
else
  echo "  Skipping Tinymist (no VSIX available)"
  TINYMIST_SHA256=""
fi

# -------------------------------------------------
# 4. Inject extensions into product.json builtInExtensions
# -------------------------------------------------
echo "[4/8] Updating product.json built-in extensions..."

# Build jq filter: add tinymist if available, add trinno if built
JQ_ADDITIONS="[]"
if [ -n "$TRINNO_VERSION" ]; then
  JQ_ADDITIONS="[\$trinno]"
fi
if [ -n "$TINYMIST_SHA256" ]; then
  JQ_ADDITIONS="$(echo "$JQ_ADDITIONS" | jq -c ". + [\$tinymist]")"
fi

# Build the jq command
JQ_CMD="jq"

# Add trinno argjson if available
if [ -n "$TRINNO_VERSION" ]; then
  JQ_CMD="$JQ_CMD --argjson trinno '$(cat <<EOJSON
  {
    "name": "open1s.trinno-research",
    "version": "$TRINNO_VERSION",
    "sha256": "$TRINNO_SHA256",
    "vsix": "$BUILTIN_EXT_DIR/trinno-research.vsix",
    "repo": "https://github.com/open1s/trinno",
    "metadata": {
      "id": "open1s.trinno-research",
      "publisherId": {
        "publisherId": "open1s",
        "publisherName": "Open1s",
        "displayName": "Open1s",
        "flags": "verified"
      },
      "publisherDisplayName": "Open1s"
    }
  }
EOJSON
)'"
fi

# Add tinymist argjson if available
if [ -n "$TINYMIST_SHA256" ]; then
  JQ_CMD="$JQ_CMD --argjson tinymist '$(cat <<EOJSON
  {
    "name": "myriad-dreamin.tinymist",
    "version": "$TINYMIST_VERSION",
    "sha256": "$TINYMIST_SHA256",
    "vsix": "$TINYMIST_VSIX",
    "repo": "https://github.com/Myriad-Dreamin/tinymist",
    "platforms": ["darwin", "linux", "win32"],
    "metadata": {
      "id": "myriad-dreamin.tinymist",
      "publisherId": {
        "publisherId": "myriad-dreamin",
        "publisherName": "Myriad Dreamin",
        "displayName": "Myriad Dreamin",
        "flags": "verified"
      },
      "publisherDisplayName": "Myriad Dreamin"
    }
  }
EOJSON
)'"
fi

# -------------------------------------------------
# 4. Inject extensions into product.json builtInExtensions
# -------------------------------------------------
echo "[4/8] Updating product.json built-in extensions..."

JQ_FILTER=".builtInExtensions += $JQ_ADDITIONS"
eval "$JQ_CMD '$JQ_FILTER' product.json > product.json.tmp" && mv product.json.tmp product.json

# -------------------------------------------------
# 5. Add TRIZ workspace template to build output
# -------------------------------------------------
echo "[5/8] Copying TRIZ workspace template..."
mkdir -p ".build/triz-workspace-template"
cp -r "build/config/triz-workspace/." ".build/triz-workspace-template/"

# -------------------------------------------------
# 6. Update package.json metadata
# -------------------------------------------------
echo "[6/8] Patching package.json..."
cp package.json{,.bak}
jq '.version = "0.1.0"' package.json > package.json.tmp
mv package.json.tmp package.json
sed -i '' 's/Microsoft Corporation/open1s/g' package.json

# -------------------------------------------------
# 7. Update electron build config
# -------------------------------------------------
echo "[7/8] Patching build/electron config..."
sed -i '' 's/Microsoft Corporation/open1s/g' build/lib/electron.ts

# -------------------------------------------------
# 8. Update Linux packaging metadata
# -------------------------------------------------
echo "[8/8] Patching Linux packaging templates..."

[ -f resources/linux/code.appdata.xml ] && sed -i '' \
  -e 's|Visual Studio Code|Trinno IDE|g' \
  -e 's|https://code.visualstudio.com|https://github.com/open1s/tride|g' \
  -e 's|https://code.visualstudio.com/docs/setup/linux|https://github.com/open1s/tride|g' \
  -e 's|https://code.visualstudio.com/home/home-screenshot-linux-lg.png||g' \
  resources/linux/code.appdata.xml

[ -f resources/linux/debian/control.template ] && sed -i '' \
  -e 's|Microsoft Corporation <vscode-linux@microsoft.com>|open1s <hello@open1s.org>|g' \
  -e 's|Visual Studio Code|Trinno IDE|g' \
  -e 's|https://code.visualstudio.com|https://github.com/open1s/tride|g' \
  resources/linux/debian/control.template

[ -f resources/linux/rpm/code.spec.template ] && sed -i '' \
  -e 's|Microsoft Corporation|open1s|g' \
  -e 's|Visual Studio Code Team <vscode-linux@microsoft.com>|open1s <hello@open1s.org>|g' \
  -e 's|Visual Studio Code|Trinno IDE|g' \
  -e 's|https://code.visualstudio.com|https://github.com/open1s/tride|g' \
  resources/linux/rpm/code.spec.template

[ -f build/win32/code.iss ] && sed -i '' \
  -e 's|https://code.visualstudio.com|https://github.com/open1s/tride|g' \
  -e 's|Microsoft Corporation|open1s|g' \
  build/win32/code.iss

# Disable telemetry
jq '.enableTelemetry = false' product.json > product.json.tmp && mv product.json.tmp product.json

echo ""
echo "=== Trinno IDE preparation complete ==="
echo ""
echo "Bundled extensions:"
[ -n "$TRINNO_VERSION" ] && echo "  open1s.trinno-research@$TRINNO_VERSION"
echo "  myriad-dreamin.tinymist@$TINYMIST_VERSION"
echo "  vscode.mermaid-markdown-features (built-in)"
echo ""
echo "Run 'npm install' then 'npm run watch' for dev mode"
echo "Run 'npm run gulp vscode-darwin-arm64' to package for macOS"
echo ""
echo "NOTE: product.json.bak and package.json.bak saved for recovery"
