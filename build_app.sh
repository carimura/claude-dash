#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

CONFIG="${1:-debug}"
APP="ClaudeDash.app"

echo "→ swift build ($CONFIG)"
swift build -c "$CONFIG"

BIN=".build/$CONFIG/ClaudeDash"
[ -f "$BIN" ] || { echo "binary not found at $BIN" >&2; exit 1; }

echo "→ assembling $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/ClaudeDash"
cp Resources/Info.plist "$APP/Contents/Info.plist"
codesign --force --sign - "$APP" >/dev/null 2>&1 || true

echo "✓ built $APP"
