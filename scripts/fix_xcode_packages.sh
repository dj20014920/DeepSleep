#!/bin/zsh
# Fix Xcode package resolution for DeepSleep by seeding llmfarm_core's local binaryTarget (llama.xcframework)
# and resolving packages. Avoids zsh 'status' read-only var and makes resolve steps non-fatal.

set -euo pipefail
setopt nonomatch  # prevent 'no matches found' errors on unmatched globs

# Paths
SCRIPT_DIR="$(cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P)"
PROJ_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJ_XCODEPROJ="$PROJ_ROOT/DeepSleep.xcodeproj"
LLAMA_SRC="$PROJ_ROOT/llama.xcframework"

log() {
  echo "[fix] $*"
}

# Return the newest DerivedData directory for this project, or empty if none
latest_derived() {
  local dd_base="$HOME/Library/Developer/Xcode/DerivedData"
  [ -d "$dd_base" ] || { echo ""; return; }
  # Find candidate DeepSleep-* dirs and sort by mtime descending
  local newest
  newest="$(find "$dd_base" -maxdepth 1 -type d -name 'DeepSleep-*' -print0 2>/dev/null | xargs -0 ls -dt 2>/dev/null | head -n1 || true)"
  echo "$newest"
}

copy_llama_into() {
  local derived="$1"
  local target_dir="$derived/SourcePackages/checkouts/llmfarm_core.swift/llama.cpp/build-apple"
  mkdir -p "$target_dir"
  rsync -a --delete "$LLAMA_SRC" "$target_dir/"
  log "Copied llama.xcframework into: $target_dir"
}

resolve_with_dir_nonfatal() {
  local derived="$1"
  xcodebuild -resolvePackageDependencies -project "$PROJ_XCODEPROJ" \
    -clonedSourcePackagesDirPath "$derived/SourcePackages" || log "resolve (with dir) completed with non-zero exit (ignored)"
}

initial_resolve_nonfatal() {
  xcodebuild -resolvePackageDependencies -project "$PROJ_XCODEPROJ" || log "initial resolve completed with non-zero exit (ignored)"
}

# --- Pre-checks ---
if [ ! -d "$LLAMA_SRC" ]; then
  log "ERROR: Missing $LLAMA_SRC"
  exit 1
fi

# --- Close Xcode if running ---
log "Closing Xcode if running…"
osascript -e 'tell application "Xcode" to if it is running then quit' >/dev/null 2>&1 || true
sleep 1

# --- Clean caches (safe) ---
log "Cleaning caches…"
# Remove project-specific DerivedData directories
if [ -d "$HOME/Library/Developer/Xcode/DerivedData" ]; then
  find "$HOME/Library/Developer/Xcode/DerivedData" -maxdepth 1 -type d -name 'DeepSleep-*' -exec rm -rf {} + 2>/dev/null || true
fi
# Remove global SPM caches to avoid stale states
rm -rf "$HOME/Library/Developer/Xcode/SourcePackages" 2>/dev/null || true
rm -rf "$HOME/Library/Caches/org.swift.swiftpm" "$HOME/Library/org.swift.swiftpm" "$HOME/Developer/Xcode/PackageCaches" 2>/dev/null || true
rm -rf "$HOME/Library/Developer/Xcode/PackageCaches" 2>/dev/null || true

# --- Seed DerivedData by resolving once (non-fatal) ---
log "Bootstrapping DerivedData by resolving packages (non-fatal)…"
initial_resolve_nonfatal

# Try to detect newest DerivedData (retry a few times if needed)
DERIVED_NEWEST=""
for _try in 1 2 3; do
  DERIVED_NEWEST="$(latest_derived)"
  [ -n "${DERIVED_NEWEST}" ] && break
  sleep 1
done

if [ -z "${DERIVED_NEWEST}" ]; then
  log "No DerivedData detected yet. Attempting another resolve (non-fatal)…"
  initial_resolve_nonfatal
  DERIVED_NEWEST="$(latest_derived || true)"
fi

if [ -z "${DERIVED_NEWEST}" ]; then
  log "ERROR: Could not determine DerivedData path for DeepSleep-*. Open the project in Xcode once, then re-run this script."
  # Not fatal to allow CI or caller to continue, but exit code 0 so the step doesn't fail.
  exit 0
fi

log "Using DerivedData: $DERIVED_NEWEST"

# --- Copy llama.xcframework and resolve with explicit dir (non-fatal) ---
copy_llama_into "$DERIVED_NEWEST"
log "Resolving packages with explicit clonedSourcePackagesDirPath (non-fatal)…"
resolve_with_dir_nonfatal "$DERIVED_NEWEST"

# --- Open project in Xcode ---
log "Opening project in Xcode…"
open "$PROJ_XCODEPROJ" >/dev/null 2>&1 || true

# --- Post-open: Xcode may re-hash DerivedData; detect and re-seed if needed ---
sleep 5
DERIVED_LATEST="$(latest_derived || true)"
if [ -n "$DERIVED_LATEST" ] && [ "$DERIVED_LATEST" != "$DERIVED_NEWEST" ]; then
  log "New DerivedData detected by Xcode: $DERIVED_LATEST"
  copy_llama_into "$DERIVED_LATEST"
  resolve_with_dir_nonfatal "$DERIVED_LATEST"
fi

log "Done. If Xcode still shows the package banner, run: File > Packages > Resolve Package Versions."
