#!/usr/bin/env bash
set -euo pipefail

SCHEME="DeepSleep"
DEST="platform=iOS Simulator,name=iPhone 16 Pro"
CONFIG="Debug"

echo "[1/3] Clean build..."
xcodebuild -scheme "$SCHEME" -destination "$DEST" -configuration "$CONFIG" clean build -quiet

echo "[2/3] Unit tests..."
xcodebuild -scheme "$SCHEME" -destination "$DEST" -configuration "$CONFIG" test -quiet

echo "[3/3] Smoke summary:"
echo "BUILD+TEST OK on $DEST ($CONFIG)"

