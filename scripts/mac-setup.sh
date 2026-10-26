#!/usr/bin/env bash
# Build, test and run on a Mac. Safe to re-run.
set -euo pipefail

cd "$(dirname "$0")/.."

if ! xcode-select -p >/dev/null 2>&1; then
  echo "Xcode command line tools are missing. Installing; re-run this script when it finishes."
  xcode-select --install
  exit 1
fi

echo "macOS $(sw_vers -productVersion), $(swift --version 2>&1 | head -1)"
swift build
swift test
echo "Starting the menu bar app. Look for the waveform icon, then press Option+Space."
exec swift run assistant-app
