#!/usr/bin/env bash
# One-command install for macOS:
#   curl -fsSL https://raw.githubusercontent.com/suganya122/clara/main/install.sh | bash
# Downloads the source (no git needed), builds it, and starts the menu bar app.
# Re-run any time to update.
set -euo pipefail

REPO="suganya122/clara"
BRANCH="main"
DEST="$HOME/.local/share/assistant-app"

if [ "$(uname -s)" != "Darwin" ]; then
  echo "This app is for macOS only." >&2
  exit 1
fi

if ! xcode-select -p >/dev/null 2>&1; then
  echo "Xcode command line tools are missing. Installing; run this command again when it finishes."
  xcode-select --install
  exit 1
fi

echo "Downloading $REPO ($BRANCH)..."
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
curl -fsSL "https://github.com/$REPO/archive/refs/heads/$BRANCH.tar.gz" | tar -xz -C "$tmp"

rm -rf "$DEST"
mkdir -p "$(dirname "$DEST")"
mv "$tmp"/*/ "$DEST"

cd "$DEST"
echo "macOS $(sw_vers -productVersion), $(swift --version 2>&1 | head -1)"
echo "Building (first build takes a minute or two)..."
swift build -c release

echo "Starting. Look for the waveform icon in the menu bar, then press Option+Space."
echo "Source is in $DEST. To start it again later: $DEST/.build/release/assistant-app"
exec "$DEST/.build/release/assistant-app"
