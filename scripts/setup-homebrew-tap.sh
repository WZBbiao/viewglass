#!/usr/bin/env bash
# Creates the WZBbiao/homebrew-tap repository on GitHub
# so users can run: brew install WZBbiao/tap/viewglass
# or after tapping: brew install viewglass
#
# Prerequisites: gh CLI authenticated

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FORMULA_SRC="${SCRIPT_DIR}/../Formula/viewglass.rb"
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
    --description "Homebrew formulae for Viewglass" \
    --clone="$TAP_DIR"
else
  git clone "https://github.com/WZBbiao/homebrew-tap.git" "$TAP_DIR"
fi

# Copy formula
mkdir -p "$TAP_DIR/Formula"
cp "$FORMULA_SRC" "$TAP_DIR/Formula/viewglass.rb"

# Create README
cat > "$TAP_DIR/README.md" << 'EOF'
# WZBbiao/homebrew-tap

Homebrew formulae for [Viewglass](https://github.com/WZBbiao/viewglass).

## Install

```bash
brew install WZBbiao/tap/viewglass
```

Or tap first, then install by name:

```bash
brew tap WZBbiao/tap
brew install viewglass
```

## Update

```bash
brew upgrade viewglass
```
EOF

# Commit and push
cd "$TAP_DIR"
git add -A
git commit -m "Add viewglass formula" 2>/dev/null || true
git push origin main 2>/dev/null || git push origin master 2>/dev/null

rm -rf "$TAP_DIR"
echo ""
echo "Done! Users can now install with:"
echo "  brew install WZBbiao/tap/viewglass"
echo ""
echo "Or:"
echo "  brew tap WZBbiao/tap"
echo "  brew install viewglass"
