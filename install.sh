#!/bin/bash
set -e

REPO="trustarc-ci/trustarc-cli"
TAG="golang-migration-latest"
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

# ── detect OS / arch ──────────────────────────────────────────────────────────
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)

case "$ARCH" in
  x86_64)        ARCH="amd64" ;;
  aarch64|arm64) ARCH="arm64" ;;
  *)
    echo "Error: unsupported architecture: $ARCH"
    exit 1
    ;;
esac

case "$OS" in
  darwin|linux) ;;
  *)
    echo "Error: unsupported OS: $OS (Windows is not supported)"
    exit 1
    ;;
esac

# ── download binary ───────────────────────────────────────────────────────────
BINARY_URL="https://github.com/${REPO}/releases/download/${TAG}/trustarc-cli-${OS}-${ARCH}"
BINARY="$TMP_DIR/trustarc-cli"

echo "→ TrustArc CLI  (Go Edition)"
echo "  Platform: ${OS}/${ARCH}"
echo ""
echo "→ Downloading..."

if command -v curl >/dev/null 2>&1; then
  curl -fsSL "$BINARY_URL" -o "$BINARY"
elif command -v wget >/dev/null 2>&1; then
  wget -qO "$BINARY" "$BINARY_URL"
else
  echo "Error: curl or wget is required."
  exit 1
fi

chmod +x "$BINARY"

# Ad-hoc sign on macOS — newer dyld requires LC_UUID which codesign restores
if [ "$OS" = "darwin" ] && command -v codesign >/dev/null 2>&1; then
  codesign -s - "$BINARY" 2>/dev/null || true
fi

echo "✓ Ready"
echo ""

# ── run ───────────────────────────────────────────────────────────────────────
exec env \
  TRUSTARC_TOKEN="${TRUSTARC_TOKEN:-}" \
  APP_VERSION="${APP_VERSION:-}" \
  MAC_DOMAIN="${MAC_DOMAIN:-}" \
  WEBSITE="${WEBSITE:-}" \
  "$BINARY"
