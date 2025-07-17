#!/bin/bash

echo "🔧 DeepSleep 빌드 테스트 시작..."

# 프로젝트 디렉토리로 이동
cd /Users/dj20014920/Desktop/DeepSleep

# 빌드 로그 디렉토리 확인
mkdir -p logs

# 빌드 실행
echo "📱 iOS 시뮬레이터용 빌드 실행 중..."
xcodebuild -project DeepSleep.xcodeproj -scheme DeepSleep -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build > logs/build_test.log 2>&1

# 빌드 결과 확인
if [ $? -eq 0 ]; then
    echo "✅ 빌드 성공!"
    echo "📝 로그 파일: logs/build_test.log"
else
    echo "❌ 빌드 실패"
    echo "📝 에러 로그:"
    tail -20 logs/build_test.log
    exit 1
fi

echo "🎉 빌드 테스트 완료!"