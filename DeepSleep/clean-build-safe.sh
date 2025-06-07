#!/bin/bash

echo "🧹 안전한 빌드 캐시 정리 시작..."

# 1. Xcode 종료 확인
echo "⚠️  Xcode가 실행 중이면 종료해주세요!"
read -p "Xcode를 종료했나요? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Xcode를 먼저 종료해주세요."
    exit 1
fi

# 2. Package.resolved 백업 (중요!)
echo "📦 패키지 설정 백업 중..."
PACKAGE_RESOLVED="./DeepSleep.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"
if [ -f "$PACKAGE_RESOLVED" ]; then
    cp "$PACKAGE_RESOLVED" "${PACKAGE_RESOLVED}.backup"
    echo "✅ Package.resolved 백업 완료"
else
    echo "⚠️  Package.resolved 파일을 찾을 수 없습니다"
fi

# 3. 빌드 캐시만 정리 (패키지 캐시는 보존)
echo "🗑️  빌드 캐시 정리 중..."
rm -rf ~/Library/Developer/Xcode/DerivedData/DeepSleep*
echo "✅ DerivedData 정리 완료"

# 4. 프로젝트 내 빌드 파일 정리
echo "🗑️  프로젝트 빌드 파일 정리 중..."
find . -name "*.xcuserstate" -delete
find . -name "*.xcworkspacedata" -type d -exec rm -rf {} + 2>/dev/null || true
echo "✅ 프로젝트 빌드 파일 정리 완료"

# 5. Package.resolved 복원 확인
if [ -f "${PACKAGE_RESOLVED}.backup" ] && [ ! -f "$PACKAGE_RESOLVED" ]; then
    echo "📦 패키지 설정 복원 중..."
    cp "${PACKAGE_RESOLVED}.backup" "$PACKAGE_RESOLVED"
    echo "✅ Package.resolved 복원 완료"
fi

echo ""
echo "🎉 안전한 캐시 정리 완료!"
echo "이제 Xcode를 실행하고 빌드하세요."
echo ""
echo "💡 패키지 오류가 발생하면:"
echo "   1. Xcode에서 File → Packages → Reset Package Caches"
echo "   2. Product → Clean Build Folder (⌘+Shift+K)"
echo "   3. 그래도 안되면 ./fix-fscalendar.sh 실행" 