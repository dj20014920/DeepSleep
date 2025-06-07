#!/bin/bash

# 🔍 DeepSleep 앱 실시간 로그 모니터링 스크립트

echo "🚀 DeepSleep 앱 로그 모니터링 시작..."
echo "======================================"
echo ""

# 1. 시뮬레이터 부팅 (iPhone 16 Pro)
echo "📱 iPhone 16 Pro 시뮬레이터 부팅 중..."
DEVICE_ID=$(xcrun simctl list devices | grep "iPhone 16 Pro (" | head -1 | grep -o '\([A-F0-9-]*\)' | head -1)
echo "기기 ID: $DEVICE_ID"

if [ ! -z "$DEVICE_ID" ]; then
    xcrun simctl boot "$DEVICE_ID" 2>/dev/null || echo "시뮬레이터가 이미 실행 중이거나 부팅되었습니다."
    sleep 2
    echo "✅ 시뮬레이터 준비 완료"
else
    echo "❌ iPhone 16 Pro 시뮬레이터를 찾을 수 없습니다."
    exit 1
fi

# 2. 앱 빌드 및 설치
echo ""
echo "🔨 DeepSleep 앱 빌드 및 설치 중..."
xcodebuild build -project DeepSleep.xcodeproj -scheme DeepSleep -destination "platform=iOS Simulator,id=$DEVICE_ID" -quiet

if [ $? -eq 0 ]; then
    echo "✅ 앱 빌드 성공"
    
    # 앱 설치
    APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "DeepSleep.app" -type d | head -1)
    if [ ! -z "$APP_PATH" ]; then
        xcrun simctl install "$DEVICE_ID" "$APP_PATH"
        echo "✅ 앱 설치 완료"
    fi
else
    echo "❌ 앱 빌드 실패"
    exit 1
fi

# 3. 로그 파일 준비
LOG_DIR="./logs"
mkdir -p "$LOG_DIR"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="$LOG_DIR/deepsleep_logs_$TIMESTAMP.log"

echo ""
echo "📝 로그 파일: $LOG_FILE"
echo "🔍 실시간 로그 모니터링 시작..."
echo "======================================"
echo ""
echo "📌 터미널에서 Ctrl+C로 중지할 수 있습니다."
echo "📌 다른 터미널에서 'tail -f $LOG_FILE'로 로그를 실시간 확인할 수 있습니다."
echo ""

# 4. 실시간 로그 모니터링 시작
echo "🎯 DeepSleep 앱 관련 로그만 필터링하여 표시합니다:"
echo ""

# 앱 실행
echo "🚀 DeepSleep 앱 실행 중..."
xcrun simctl launch "$DEVICE_ID" com.dj20014920.DeepSleep 2>/dev/null || echo "앱 실행 시도 중..."

# 로그 스트리밍 (여러 필터 옵션)
{
    echo "=== $(date) DeepSleep 로그 모니터링 시작 ==="
    
    # DeepSleep 관련 로그 + RemoteLogger 로그
    log stream --device --predicate 'process CONTAINS "DeepSleep" OR subsystem CONTAINS "deepsleep" OR category CONTAINS "RemoteLogger" OR messageText CONTAINS "DeepSleep"' 2>/dev/null
    
} | tee "$LOG_FILE" | while IFS= read -r line; do
    # 중요한 로그들 색상으로 강조
    if echo "$line" | grep -i "error\|critical\|fail" >/dev/null; then
        echo -e "\033[1;31m$line\033[0m"  # 빨간색
    elif echo "$line" | grep -i "warning\|warn" >/dev/null; then
        echo -e "\033[1;33m$line\033[0m"  # 노란색  
    elif echo "$line" | grep -i "AI\|RemoteLogger\|UserAction" >/dev/null; then
        echo -e "\033[1;36m$line\033[0m"  # 청록색
    elif echo "$line" | grep -i "success\|완료\|성공" >/dev/null; then
        echo -e "\033[1;32m$line\033[0m"  # 초록색
    else
        echo "$line"  # 기본 색상
    fi
done 