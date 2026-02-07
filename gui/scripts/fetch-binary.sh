#!/bin/bash
# Fetch paqet binary from GitHub Release for local development
# Usage: ./scripts/fetch-binary.sh [version]
# Example: ./scripts/fetch-binary.sh v1.0.0

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BIN_DIR="$SCRIPT_DIR/../bin"
REPO="omid3098/autopaqet"

VERSION="${1:-latest}"
ARCH="$(uname -m)"
OS="$(uname -s | tr '[:upper:]' '[:lower:]')"

case "$ARCH" in
  x86_64) ARCH="amd64" ;;
  aarch64) ARCH="arm64" ;;
esac

BINARY_NAME="paqet-${OS}-${ARCH}"

if [[ "$VERSION" == "latest" ]]; then
  DOWNLOAD_URL="https://github.com/${REPO}/releases/latest/download/${BINARY_NAME}"
else
  DOWNLOAD_URL="https://github.com/${REPO}/releases/download/${VERSION}/${BINARY_NAME}"
fi

mkdir -p "$BIN_DIR"

echo "Downloading ${BINARY_NAME}..."
echo "URL: ${DOWNLOAD_URL}"

curl -fsSL -o "${BIN_DIR}/paqet" "$DOWNLOAD_URL"
chmod +x "${BIN_DIR}/paqet"

echo "Binary saved to ${BIN_DIR}/paqet"
echo "SHA256: $(sha256sum "${BIN_DIR}/paqet" | cut -d' ' -f1)"
