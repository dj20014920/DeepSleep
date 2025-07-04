#!/usr/bin/env bash
set -euxo pipefail

# ----------------------------------------
# 사용자 Apple Developer Team ID 설정
# ----------------------------------------

echo "⏳ Clearing DerivedData..."
rm -rf ~/Library/Developer/Xcode/DerivedData

echo "⏳ Clearing .build..."
rm -rf .build
if [ -f Package.swift ]; then
  echo "⏳ Clearing SwiftPM caches..."
  swift package clean
  swift package reset
  swift package resolve
else
  echo "ℹ️ No Package.swift found; skipping SwiftPM cache cleanup"
fi

echo "⏳ Cleaning XcodeGen user data and SwiftPM cache inside the workspace..."
rm -rf DeepSleep.xcodeproj/xcuserdata
rm -rf DeepSleep.xcodeproj/project.xcworkspace/xcuserdata
rm -rf DeepSleep.xcodeproj/project.xcworkspace/xcshareddata/swiftpm

echo "⏳ Regenerating Xcode project via XcodeGen..."
xcodegen generate

# ----------------------------------------
# Xcode 프로젝트에 Development Team 자동 설정
# ----------------------------------------
# DEVELOPMENT_TEAM을 지정된 TEAM_ID로 업데이트

echo "✅ Reset complete. Next steps to finalize FSCalendar sync fix:"
echo "   1. Open DeepSleep.xcodeproj in Xcode"
echo "   2. File > Packages > Reset Package Caches"
echo "   3. File > Packages > Resolve Package Versions"
echo "   4. Product > Clean Build Folder (⇧⌘K)"
echo "   5. Build and run (⌘B) to confirm no FSCalendar errors" 