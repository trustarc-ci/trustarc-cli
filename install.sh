#!/bin/bash

# TrustArc CLI — Go Edition (golang-migration branch)
#
# Usage:
#   REPO_REF=golang-migration sh -c "$(curl -fsSL https://raw.githubusercontent.com/trustarc-ci/trustarc-cli/refs/heads/main/install.sh)"
# or directly:
#   APP_VERSION=feature/... sh -c "$(curl -fsSL https://raw.githubusercontent.com/trustarc-ci/trustarc-cli/refs/heads/golang-migration/install.sh)"

set -e

BRANCH="golang-migration"
REPO="trustarc-ci/trustarc-cli"
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

# ── check Go ─────────────────────────────────────────────────────────────────
if ! command -v go >/dev/null 2>&1; then
  echo "Error: Go is required to run the CLI on the golang-migration branch."
  echo ""
  echo "Install Go from https://go.dev/dl/ and re-run, or use the stable shell version:"
  echo "  sh -c \"\$(curl -fsSL https://raw.githubusercontent.com/trustarc-ci/trustarc-cli/refs/heads/main/install.sh)\""
  exit 1
fi

GO_VERSION=$(go version | awk '{print $3}')
echo "→ TrustArc CLI  (Go Edition · branch: $BRANCH)"
echo "  Go: $GO_VERSION"
echo ""

# ── download source ───────────────────────────────────────────────────────────
echo "→ Downloading source..."

SRC_DIR="$TMP_DIR/src"
mkdir -p "$SRC_DIR"

ARCHIVE_URL="https://github.com/${REPO}/archive/refs/heads/${BRANCH}.tar.gz"

if command -v curl >/dev/null 2>&1; then
  curl -fsSL "$ARCHIVE_URL" | tar xz -C "$SRC_DIR"
elif command -v wget >/dev/null 2>&1; then
  wget -qO- "$ARCHIVE_URL" | tar xz -C "$SRC_DIR"
else
  echo "Error: curl or wget is required."
  exit 1
fi

EXTRACTED=$(ls "$SRC_DIR" | head -1)
BUILD_DIR="$SRC_DIR/$EXTRACTED"
BINARY="$TMP_DIR/trustarc-cli"

# ── build ─────────────────────────────────────────────────────────────────────
echo "→ Building..."
cd "$BUILD_DIR"
go mod tidy -e 2>/dev/null || true
go build -ldflags="-s -w" -o "$BINARY" ./cmd/
echo "✓ Build complete"
echo ""

# ── run ───────────────────────────────────────────────────────────────────────
exec env \
  TRUSTARC_TOKEN="${TRUSTARC_TOKEN:-}" \
  APP_VERSION="${APP_VERSION:-}" \
  MAC_DOMAIN="${MAC_DOMAIN:-}" \
  WEBSITE="${WEBSITE:-}" \
  "$BINARY"
