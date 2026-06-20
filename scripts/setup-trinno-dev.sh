#!/usr/bin/env bash
set -e

cd "$(dirname "$0")/.." || { echo "Run from repo root"; exit 1; }

TRINNO_PATH="/Users/gaosg/Projects/trinno"
CONTROL_DIR="$HOME/.vscode-oss-dev/extensions"
CONTROL_FILE="$CONTROL_DIR/control.json"

echo "=== Setting up Trinno IDE development environment ==="

# -------------------------------------------------
# 1. Verify trinno project exists and is compiled
# -------------------------------------------------
if [ ! -d "$TRINNO_PATH" ]; then
  echo "Error: trinno project not found at $TRINNO_PATH"
  exit 1
fi

if [ ! -f "$TRINNO_PATH/dist/extension.js" ]; then
  echo "Building trinno extension..."
  (cd "$TRINNO_PATH" && npm run compile)
fi

# -------------------------------------------------
# 2. Create control.json for built-in extension loading
# -------------------------------------------------
mkdir -p "$CONTROL_DIR"

if [ -f "$CONTROL_FILE" ]; then
  CONTROL=$(cat "$CONTROL_FILE")
else
  CONTROL="{}"
fi

# Add trinno-research as local extension
CONTROL=$(echo "$CONTROL" | jq --arg p "$TRINNO_PATH" '.["open1s.trinno-research"] = $p')

# Also look for Tinymist in user's installed extensions
TINYMIST_PATH=$(ls -d "$HOME/.vscode/extensions/myriad-dreamin.tinymist-"* 2>/dev/null | sort -V | tail -1 || echo "")
if [ -n "$TINYMIST_PATH" ] && [ -f "$TINYMIST_PATH/package.json" ]; then
  CONTROL=$(echo "$CONTROL" | jq --arg p "$TINYMIST_PATH" '.["myriad-dreamin.tinymist"] = $p')
  echo "  Found Tinymist at: $TINYMIST_PATH"
else
  echo "  Note: Tinymist Typst not found in ~/.vscode/extensions/"
  echo "  Install it from marketplace or run: code --install-extension myriad-dreamin.tinymist"
fi

echo "$CONTROL" > "$CONTROL_FILE"
echo "  Created $CONTROL_FILE"

# -------------------------------------------------
# 3. Print status
# -------------------------------------------------
echo ""
echo "=== Dev environment ready ==="
echo "  trinno-research: $TRINNO_PATH"
echo "  Tinymist: ${TINYMIST_PATH:-not installed}"
echo ""
echo "Now run 'npm run watch' in tride to start developing."
echo "trinno-research will be automatically loaded from its project directory."
