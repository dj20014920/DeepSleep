#!/bin/bash
# -------------------------------------------------------------
# spm_xcodegen_reset.sh
# Resets SPM caches and regenerates the Xcode project via XcodeGen
# Usage: sh spm_xcodegen_reset.sh
# -------------------------------------------------------------
set -euo pipefail

PROJECT_NAME="DeepSleep"

function info() {
  echo "[INFO] $1"
}

info "Removing DerivedData for $PROJECT_NAME"
rm -rf ~/Library/Developer/Xcode/DerivedData/${PROJECT_NAME}-*

info "Removing local build caches (.build, .swiftpm, xcuserdata, WorkspaceSettings)"
rm -rf .build .swiftpm
rm -rf ${PROJECT_NAME}.xcodeproj/project.xcworkspace/xcshareddata/SwiftPM
rm -rf ${PROJECT_NAME}.xcodeproj/xcuserdata
rm -rf ${PROJECT_NAME}.xcodeproj/xcshareddata/WorkspaceSettings.xcsettings || true

info "Re-generating Xcode project with XcodeGen"
if ! command -v xcodegen >/dev/null 2>&1; then
  echo "[ERROR] XcodeGen is not installed. Install via 'brew install xcodegen' and re-run." >&2
  exit 1
fi
xcodegen generate

info "Resetting and resolving Swift Package caches"
# Reset package caches & resolve package versions
xcodebuild -resolvePackageDependencies -project ${PROJECT_NAME}.xcodeproj -scheme ${PROJECT_NAME}

info "Cleaning build folder"
xcodebuild clean -project ${PROJECT_NAME}.xcodeproj -scheme ${PROJECT_NAME} -configuration Debug

info "SPM/XcodeGen reset complete. Open ${PROJECT_NAME}.xcodeproj and build again." 