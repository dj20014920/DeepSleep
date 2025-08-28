#!/usr/bin/env bash
set -euo pipefail

SCHEME="DeepSleep"
DEST="platform=iOS Simulator,name=iPhone 16 Pro"
CONFIG="Debug"

# Use workspace-local paths to avoid sandbox-denied writes to ~/Library
DD="$(pwd)/build_test/DerivedData"
SP="$(pwd)/build_test/SourcePackages"
mkdir -p "$DD" "$SP"

echo "[1/3] Clean build (workspace-local DerivedData/Packages)..."
xcodebuild \
  -scheme "$SCHEME" \
  -destination "$DEST" \
  -configuration "$CONFIG" \
  -derivedDataPath "$DD" \
  -clonedSourcePackagesDirPath "$SP" \
  -quiet \
  clean build COMPILER_INDEX_STORE_ENABLE=NO

echo "[2/3] Unit tests (workspace-local DerivedData/Packages)..."
xcodebuild \
  -scheme "$SCHEME" \
  -destination "$DEST" \
  -configuration "$CONFIG" \
  -derivedDataPath "$DD" \
  -clonedSourcePackagesDirPath "$SP" \
  -quiet \
  test COMPILER_INDEX_STORE_ENABLE=NO

echo "[3/3] Smoke summary:"
echo "BUILD+TEST OK on $DEST ($CONFIG)"
