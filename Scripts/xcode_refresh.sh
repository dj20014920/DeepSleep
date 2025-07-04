#!/bin/bash

# Xcode Auto-Refresh Script
# 파일 변경사항을 감지하고 Xcode를 자동으로 새로고침합니다.

PROJECT_PATH="${1:-$(find . -name "*.xcodeproj" -maxdepth 1 | head -1)}"

if [ -z "$PROJECT_PATH" ]; then
    echo "Error: No Xcode project found"
    echo "Usage: $0 [path/to/project.xcodeproj]"
    exit 1
fi

echo "Monitoring: $PROJECT_PATH"
echo "Press Ctrl+C to stop..."

# Xcode 새로고침 함수
refresh_xcode() {
    osascript -e '
    tell application "Xcode"
        if (count of windows) > 0 then
            tell application "System Events"
                tell process "Xcode"
                    -- 프로젝트 네비게이터로 전환
                    keystroke "1" using command down
                    delay 0.2
                    -- 메뉴에서 새로고침
                    click menu item "Refresh" of menu "View" of menu bar 1
                end tell
            end tell
        end if
    end tell
    ' 2>/dev/null || true
    
    echo "$(date '+%H:%M:%S') - Xcode refreshed"
}

# fswatch를 사용한 파일 감시 (설치: brew install fswatch)
if command -v fswatch &> /dev/null; then
    fswatch -o -r -e ".*\.git.*" -e ".*DerivedData.*" -e ".*\.swiftpm.*" \
            -e ".*xcuserdata.*" -e ".*\.DS_Store" \
            --event Created --event Removed --event Renamed \
            "$(dirname "$PROJECT_PATH")" | while read change
    do
        refresh_xcode
    done
else
    echo "fswatch not found. Installing..."
    if command -v brew &> /dev/null; then
        brew install fswatch
        echo "fswatch installed. Please run the script again."
    else
        echo "Please install fswatch manually: brew install fswatch"
    fi
    exit 1
fi
