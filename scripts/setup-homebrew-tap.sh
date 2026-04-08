#!/usr/bin/env bash
# Creates the WZBbiao/homebrew-tap repository on GitHub
# so users can run: brew install WZBbiao/tap/lookin-cli
# or after tapping: brew install lookin-cli
#
# Prerequisites: gh CLI authenticated

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FORMULA_SRC="${SCRIPT_DIR}/../Formula/lookin-cli.rb"
TMPDIR="${TMPDIR:-/tmp}"
TAP_DIR="${TMPDIR}/homebrew-tap-$$"

if ! command -v gh >/dev/null 2>&1; then
  echo "Error: GitHub CLI (gh) required. Install via: brew install gh" >&2
  exit 1
fi

echo "Creating WZBbiao/homebrew-tap repository..."

# Create repo if it doesn't exist
if ! gh repo view WZBbiao/homebrew-tap >/dev/null 2>&1; then
  gh repo create WZBbiao/homebrew-tap --public \
    --description "Homebrew formulae for Lookin CLI" \
    --clone="$TAP_DIR"
else
  git clone "https://github.com/WZBbiao/homebrew-tap.git" "$TAP_DIR"
fi

# Copy formula
mkdir -p "$TAP_DIR/Formula"
cp "$FORMULA_SRC" "$TAP_DIR/Formula/lookin-cli.rb"

# Create README
cat > "$TAP_DIR/README.md" << 'EOF'
# WZBbiao/homebrew-tap

Homebrew formulae for [Lookin CLI](https://github.com/WZBbiao/Lookin).

## Install

```bash
brew install WZBbiao/tap/lookin-cli
```

Or tap first, then install by name:

```bash
brew tap WZBbiao/tap
brew install lookin-cli
```

## Update

```bash
brew upgrade lookin-cli
```
EOF

# Commit and push
cd "$TAP_DIR"
git add -A
git commit -m "Add lookin-cli formula" 2>/dev/null || true
git push origin main 2>/dev/null || git push origin master 2>/dev/null

rm -rf "$TAP_DIR"
echo ""
echo "Done! Users can now install with:"
echo "  brew install WZBbiao/tap/lookin-cli"
echo ""
echo "Or:"
echo "  brew tap WZBbiao/tap"
echo "  brew install lookin-cli"
