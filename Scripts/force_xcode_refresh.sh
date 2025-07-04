#!/bin/bash

# Force Xcode Refresh Script
# Xcode가 파일을 강제로 인식하도록 하는 스크립트

echo "🔄 Forcing Xcode to refresh..."

# 1. 프로젝트 파일의 타임스탬프 업데이트
touch DeepSleep.xcodeproj/project.pbxproj

# 2. 파생 데이터 정리 (선택적)
if [ "$1" == "--clean" ]; then
    echo "🧹 Cleaning derived data..."
    rm -rf ~/Library/Developer/Xcode/DerivedData/DeepSleep-*
fi

# 3. Xcode에서 프로젝트 다시 열기
osascript <<EOF
tell application "Xcode"
    if (count of windows) > 0 then
        set currentProject to path of document of front window
        
        -- 현재 프로젝트 닫기
        close every project document
        delay 0.5
        
        -- 프로젝트 다시 열기
        open currentProject
        delay 1
        
        -- 프로젝트 네비게이터 표시
        tell application "System Events"
            tell process "Xcode"
                keystroke "1" using command down
            end tell
        end tell
    else
        -- Xcode가 열려있지 않으면 프로젝트 열기
        open "$PWD/DeepSleep.xcodeproj"
    end if
end tell
EOF

echo "✅ Xcode project refreshed!"
echo ""
echo "💡 팁: 여전히 파일이 안 보이면:"
echo "   1. Xcode에서 File > Add Files to \"DeepSleep\"... 선택"
echo "   2. 추가하려는 파일/폴더 선택"
echo "   3. 'Copy items if needed' 체크 해제"
echo "   4. 'Add to targets' 에서 DeepSleep 선택"
