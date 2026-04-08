#!/usr/bin/env bash
# Lookin CLI installer
# Usage: curl -fsSL https://raw.githubusercontent.com/WZBbiao/Lookin/Develop/scripts/install.sh | bash

set -euo pipefail

REPO="WZBbiao/Lookin"
INSTALL_DIR="${INSTALL_DIR:-/usr/local/bin}"
TMPDIR="${TMPDIR:-/tmp}"

echo "Installing lookin-cli..."

# Detect architecture
ARCH=$(uname -m)
if [[ "$ARCH" != "arm64" && "$ARCH" != "x86_64" ]]; then
  echo "Error: Unsupported architecture: $ARCH" >&2
  exit 1
fi

# Helper: copy with sudo only if needed
install_bin() {
  local src="$1" dst="$2"
  if [ -w "$(dirname "$dst")" ]; then
    mkdir -p "$(dirname "$dst")"
    cp "$src" "$dst"
    chmod +x "$dst"
  else
    sudo mkdir -p "$(dirname "$dst")"
    sudo cp "$src" "$dst"
    sudo chmod +x "$dst"
  fi
}

# Try downloading pre-built binary from GitHub Releases
LATEST=$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" 2>/dev/null | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/' || true)

if [[ -n "$LATEST" ]]; then
  ASSET_NAME="lookin-cli-macos-${ARCH}.tar.gz"
  DOWNLOAD_URL="https://github.com/${REPO}/releases/download/${LATEST}/${ASSET_NAME}"

  if curl -fsSL --head "$DOWNLOAD_URL" >/dev/null 2>&1; then
    echo "Downloading ${LATEST} for ${ARCH}..."
    curl -fsSL "$DOWNLOAD_URL" -o "${TMPDIR}/lookin-cli.tar.gz"
    tar -xzf "${TMPDIR}/lookin-cli.tar.gz" -C "${TMPDIR}"
    install_bin "${TMPDIR}/lookin-cli" "${INSTALL_DIR}/lookin-cli"
    rm -f "${TMPDIR}/lookin-cli.tar.gz" "${TMPDIR}/lookin-cli"
    echo "Installed lookin-cli ${LATEST} to ${INSTALL_DIR}/lookin-cli"
    exit 0
  fi
fi

# Fallback: build from source using the latest tag (or HEAD if no tags)
echo "No pre-built binary found. Building from source..."

if ! command -v swift >/dev/null 2>&1; then
  echo "Error: Swift toolchain not found. Install Xcode or Swift from https://swift.org" >&2
  exit 1
fi

BUILD_TMP="${TMPDIR}/lookin-cli-build-$$"
if [[ -n "$LATEST" ]]; then
  git clone --depth 1 --branch "$LATEST" "https://github.com/${REPO}.git" "$BUILD_TMP" 2>/dev/null
else
  git clone --depth 1 "https://github.com/${REPO}.git" "$BUILD_TMP" 2>/dev/null
fi
cd "$BUILD_TMP"
swift build -c release --disable-sandbox
install_bin ".build/release/lookin-cli" "${INSTALL_DIR}/lookin-cli"
rm -rf "$BUILD_TMP"
echo "Installed lookin-cli (built from source) to ${INSTALL_DIR}/lookin-cli"
