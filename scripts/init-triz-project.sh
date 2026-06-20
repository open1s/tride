#!/usr/bin/env bash
set -e

cd "$(dirname "$0")/.." || { echo "Run from repo root"; exit 1; }

TEMPLATE_DIR="build/config/triz-workspace"
TARGET_DIR="${1:-./my-triz-project}"

if [ -d "$TARGET_DIR" ]; then
  echo "Error: Target directory '$TARGET_DIR' already exists"
  exit 1
fi

echo "=== Creating new TRIZ Research Project ==="
echo "  Template: $TEMPLATE_DIR"
echo "  Target:   $TARGET_DIR"

cp -r "$TEMPLATE_DIR" "$TARGET_DIR"

echo ""
echo "Project created at: $TARGET_DIR"
echo ""
echo "Next steps:"
echo "  1. Open the project: trinno $TARGET_DIR"
echo "  2. Open Research Assistant: Cmd+Shift+C"
echo "  3. Run /init to start your research"
