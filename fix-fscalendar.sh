#!/bin/bash

echo "🔧 FSCalendar 패키지 문제 완전 해결..."

# 1. Xcode 종료 확인
echo "⚠️  먼저 Xcode를 완전히 종료해주세요!"
read -p "Xcode를 종료했나요? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Xcode를 먼저 종료해주세요."
    exit 1
fi

# 2. 모든 Swift Package Manager 캐시 완전 삭제
echo "🗑️  Swift Package Manager 캐시 완전 정리..."
rm -rf ~/Library/Caches/org.swift.swiftpm/
rm -rf ~/Library/org.swift.swiftpm/
rm -rf ~/Library/Developer/Xcode/DerivedData/
echo "✅ 캐시 완전 정리 완료"

# 3. 프로젝트 패키지 설정 초기화
echo "📦 프로젝트 패키지 설정 초기화..."
SWIFTPM_DIR="./DeepSleep.xcodeproj/project.xcworkspace/xcshareddata/swiftpm"
if [ -d "$SWIFTPM_DIR" ]; then
    rm -rf "$SWIFTPM_DIR"
    echo "✅ 기존 패키지 설정 삭제 완료"
fi

# 4. 패키지 디렉토리 재생성
echo "📁 패키지 디렉토리 재생성..."
mkdir -p "$SWIFTPM_DIR"

# 5. 새로운 Package.resolved 생성
echo "📦 새로운 Package.resolved 생성..."
cat > "${SWIFTPM_DIR}/Package.resolved" << 'EOF'
{
  "originHash" : "2210fcafa6e02a3f16f3c2d3cc45e0b8bfbabcff7a5be6325d5d2194bc31f854",
  "pins" : [
    {
      "identity" : "fscalendar",
      "kind" : "remoteSourceControl",
      "location" : "https://github.com/WenchaoD/FSCalendar.git",
      "state" : {
        "revision" : "0fbdec5172fccb90f707472eeaea4ffe095278f6",
        "version" : "2.8.4"
      }
    }
  ],
  "version" : 3
}
EOF

echo "✅ Package.resolved 재생성 완료"

# 6. 패키지 미리 다운로드
echo "📥 FSCalendar 패키지 미리 다운로드..."
if command -v xcodebuild &> /dev/null; then
    xcodebuild -resolvePackageDependencies -project DeepSleep.xcodeproj 2>/dev/null || true
    echo "✅ 패키지 다운로드 완료"
else
    echo "⚠️  xcodebuild를 찾을 수 없습니다. Xcode에서 수동으로 패키지를 해결해주세요."
fi

echo ""
echo "🎉 FSCalendar 패키지 문제 해결 완료!"
echo ""
echo "📝 다음 단계:"
echo "   1. Xcode 실행"
echo "   2. DeepSleep.xcodeproj 열기"  
echo "   3. File → Packages → Resolve Package Versions"
echo "   4. 빌드 실행 (⌘+B)"
echo ""
echo "💡 앞으로는 ./clean-build-safe.sh를 사용하세요!" 