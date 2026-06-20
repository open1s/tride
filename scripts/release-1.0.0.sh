#!/usr/bin/env bash
# Release Trinno Research IDE v1.0.0 via GitHub Actions.
#
# Usage:
#   bash scripts/release-1.0.0.sh                  # default: v1.0.0, draft=false
#   bash scripts/release-1.0.0.sh --draft         # create draft release
#   bash scripts/release-1.0.0.sh --prerelease     # mark as pre-release
#   bash scripts/release-1.0.0.sh --tag            # push v1.0.0 tag instead (auto-trigger)
#
# Requires: gh (GitHub CLI), already authenticated.

set -e

VERSION="${VERSION:-1.0.0}"
DRAFT="false"
PRERELEASE="false"
MODE="workflow"

for arg in "$@"; do
  case $arg in
    --draft)      DRAFT="true" ;;
    --prerelease) PRERELEASE="true" ;;
    --tag)        MODE="tag" ;;
    --workflow)   MODE="workflow" ;;
    --version=*)  VERSION="${arg#*=}" ;;
    -h|--help)
      grep '^#' "$0" | sed 's/^# \?//'
      exit 0
      ;;
  esac
done

cd "$(dirname "$0")/.." || { echo "Run from repo root"; exit 1; }

if ! command -v gh >/dev/null 2>&1; then
  echo "Error: gh (GitHub CLI) not installed. Install via 'brew install gh'"
  exit 1
fi

echo "=== Trinno Research IDE Release ==="
echo "  Version:    ${VERSION}"
echo "  Draft:      ${DRAFT}"
echo "  Prerelease: ${PRERELEASE}"
echo "  Mode:       ${MODE}"
echo ""

if [ "${MODE}" = "tag" ]; then
  TAG="v${VERSION}"
  echo "Pushing tag ${TAG} (auto-triggers release workflow)..."
  git tag -a "${TAG}" -m "Trinno Research IDE ${VERSION}"
  git push origin "${TAG}"
else
  echo "Triggering release workflow via gh..."
  gh workflow run release.yml \
    -f version="${VERSION}" \
    -f draft="${DRAFT}" \
    -f prerelease="${PRERELEASE}"
fi

echo ""
echo "Watch the run with:"
echo "  gh run watch"
echo "Or view status:"
echo "  gh run list --workflow=release.yml"
