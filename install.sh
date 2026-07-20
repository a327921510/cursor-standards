#!/usr/bin/env bash
# install.sh — bootstrap the cursor-std CLI onto your PATH (macOS / Linux).
#
# Recommended usage (safe: clone first, then run locally — no curl|bash):
#   git clone <cursor-standards repo> ~/dev/cursor-standards
#   cd ~/dev/cursor-standards && ./install.sh
#
# Creates a symlink to bin/cursor-std in a PATH directory. Override with:
#   BIN_DIR=/usr/local/bin ./install.sh
#
# Windows (Git Bash): use ./install-windows.sh instead.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$REPO_ROOT/bin/cursor-std"
[ -f "$SRC" ] || { echo "error: $SRC not found" >&2; exit 1; }
chmod +x "$SRC" 2>/dev/null || true

BIN_DIR="${BIN_DIR:-$HOME/.local/bin}"
mkdir -p "$BIN_DIR"
ln -sf "$SRC" "$BIN_DIR/cursor-std"

echo "Linked cursor-std -> $BIN_DIR/cursor-std"
case ":$PATH:" in
  *":$BIN_DIR:"*) : ;;
  *) echo "note: $BIN_DIR is not on your PATH. Add this to your shell profile:"
     echo "      export PATH=\"$BIN_DIR:\$PATH\"" ;;
esac
echo
echo "Tip: set STANDARDS_HOME so any project can install offline:"
echo "      export STANDARDS_HOME=\"$REPO_ROOT\""
echo "Then: cursor-std install /path/to/your-project"
