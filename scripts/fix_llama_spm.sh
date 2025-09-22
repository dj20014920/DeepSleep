#!/bin/zsh
set -euo pipefail

# Resolve paths
SCRIPT_DIR="$(cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P)"
PROJ_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJ_XCODEPROJ="$PROJ_ROOT/DeepSleep.xcodeproj"
LLAMA_SRC="$PROJ_ROOT/llama.xcframework"

if [ ! -d "$LLAMA_SRC" ]; then
  echo "[fix_llama_spm] ERROR: Not found: $LLAMA_SRC"
  exit 1
fi

# Ensure DerivedData exists for this project (xcodebuild will create it on first resolve)
DERIVED="$(ls -d ~/Library/Developer/Xcode/DerivedData/DeepSleep-*/ 2>/dev/null | head -n1 || true)"
if [ -z "${DERIVED}" ]; then
  echo "[fix_llama_spm] No DerivedData yet. Resolving packages to initialize..."
  xcodebuild -resolvePackageDependencies -project "$PROJ_XCODEPROJ" || true
  DERIVED="$(ls -d ~/Library/Developer/Xcode/DerivedData/DeepSleep-*/ 2>/dev/null | head -n1 || true)"
fi

if [ -z "${DERIVED}" ]; then
  echo "[fix_llama_spm] ERROR: Could not determine DerivedData path for DeepSleep-*"
  exit 1
fi

echo "[fix_llama_spm] Using DerivedData: $DERIVED"
TARGET_DIR="$DERIVED/SourcePackages/checkouts/llmfarm_core.swift/llama.cpp/build-apple"
mkdir -p "$TARGET_DIR"

# Sync xcframework
rsync -a --delete "$LLAMA_SRC" "$TARGET_DIR/"

echo "[fix_llama_spm] Copied -> $TARGET_DIR/llama.xcframework"

# Re-resolve with explicit clonedSourcePackagesDirPath to avoid re-clone to a new spot
xcodebuild -resolvePackageDependencies -project "$PROJ_XCODEPROJ" \
  -clonedSourcePackagesDirPath "$DERIVED/SourcePackages"

echo "[fix_llama_spm] Done."
