#!/bin/bash

# 🚀 DeepSleep TestFlight 자동 빌드 & 업로드 스크립트

echo "🚀 DeepSleep TestFlight 빌드 시작..."
echo "======================================"
echo ""

# 색상 코드
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 1. 환경 설정 확인
echo -e "${BLUE}📋 환경 설정 확인 중...${NC}"
PROJECT_NAME="DeepSleep"
SCHEME_NAME="DeepSleep"
BUILD_DIR="./build"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
ARCHIVE_PATH="$BUILD_DIR/DeepSleep_$TIMESTAMP.xcarchive"
IPA_PATH="$BUILD_DIR/DeepSleep_$TIMESTAMP.ipa"

# Build 디렉토리 생성
mkdir -p "$BUILD_DIR"

echo "프로젝트: $PROJECT_NAME"
echo "스킴: $SCHEME_NAME"
echo "아카이브 경로: $ARCHIVE_PATH"
echo "IPA 경로: $IPA_PATH"
echo ""

# 2. Bundle ID 확인
echo -e "${BLUE}📦 Bundle ID 확인 중...${NC}"
BUNDLE_ID=$(xcodebuild -project DeepSleep.xcodeproj -showBuildSettings -configuration Release | grep PRODUCT_BUNDLE_IDENTIFIER | awk '{print $3}' | head -1)
echo "Bundle ID: $BUNDLE_ID"
echo ""

# 3. 프로비저닝 프로파일 확인
echo -e "${BLUE}🔐 프로비저닝 프로파일 확인 중...${NC}"
security find-identity -v -p codesigning | head -5
echo ""

# 4. Clean Build
echo -e "${YELLOW}🧹 Clean Build 수행 중...${NC}"
xcodebuild clean -project DeepSleep.xcodeproj -scheme DeepSleep -configuration Release
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Clean 완료${NC}"
else
    echo -e "${RED}❌ Clean 실패${NC}"
    exit 1
fi
echo ""

# 5. Archive 생성
echo -e "${PURPLE}📦 Archive 생성 중...${NC}"
echo "이 과정은 몇 분 정도 소요될 수 있습니다..."

xcodebuild archive \
    -project DeepSleep.xcodeproj \
    -scheme DeepSleep \
    -configuration Release \
    -archivePath "$ARCHIVE_PATH" \
    -allowProvisioningUpdates \
    CODE_SIGN_STYLE=Automatic \
    -destination generic/platform=iOS

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Archive 생성 완료${NC}"
    echo "Archive 위치: $ARCHIVE_PATH"
else
    echo -e "${RED}❌ Archive 생성 실패${NC}"
    echo "오류 해결 방법:"
    echo "1. Xcode에서 프로젝트 열기"
    echo "2. Product > Archive로 수동 빌드 테스트"
    echo "3. 서명 설정 확인"
    exit 1
fi
echo ""

# 6. IPA 내보내기
echo -e "${PURPLE}📱 IPA 파일 생성 중...${NC}"

# Export options plist 생성
EXPORT_OPTIONS_PLIST="$BUILD_DIR/ExportOptions.plist"
cat > "$EXPORT_OPTIONS_PLIST" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store</string>
    <key>teamID</key>
    <string></string>
    <key>uploadBitcode</key>
    <false/>
    <key>uploadSymbols</key>
    <true/>
    <key>compileBitcode</key>
    <false/>
</dict>
</plist>
EOF

xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$BUILD_DIR" \
    -exportOptionsPlist "$EXPORT_OPTIONS_PLIST"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ IPA 생성 완료${NC}"
    # 실제 IPA 파일 찾기
    IPA_FILE=$(find "$BUILD_DIR" -name "*.ipa" | head -1)
    echo "IPA 파일: $IPA_FILE"
else
    echo -e "${RED}❌ IPA 생성 실패${NC}"
    exit 1
fi
echo ""

# 7. App Store Connect 업로드
echo -e "${CYAN}☁️  App Store Connect 업로드${NC}"
echo "업로드 방법을 선택하세요:"
echo "1. 자동 업로드 (App Store Connect API Key 필요)"
echo "2. 수동 업로드 안내"
echo "3. 건너뛰기"
read -p "선택 (1-3): " upload_choice

case $upload_choice in
    1)
        echo -e "${CYAN}🚀 자동 업로드 시도 중...${NC}"
        # API Key가 설정되어 있다면 자동 업로드
        if [ -f "$HOME/.private_keys/AuthKey_*.p8" ]; then
            xcrun altool --upload-app -f "$IPA_FILE" -t ios --apiKey "YOUR_API_KEY" --apiIssuer "YOUR_ISSUER_ID"
        else
            echo -e "${YELLOW}⚠️  API Key가 설정되어 있지 않습니다.${NC}"
            echo "수동 업로드를 진행하세요."
        fi
        ;;
    2)
        echo -e "${CYAN}📋 수동 업로드 방법:${NC}"
        echo "1. Xcode 열기"
        echo "2. Window > Organizer"
        echo "3. Archives 탭에서 방금 생성된 Archive 선택"
        echo "4. 'Distribute App' 클릭"
        echo "5. 'App Store Connect' 선택"
        echo "6. 'Upload' 선택"
        echo "7. 서명 옵션 확인 후 'Upload' 클릭"
        echo ""
        echo "또는 Application Loader 사용:"
        echo "1. Application Loader 실행"
        echo "2. 'Deliver Your App' 선택"
        echo "3. Apple ID로 로그인"
        echo "4. IPA 파일 선택: $IPA_FILE"
        ;;
    3)
        echo -e "${YELLOW}⏭️  업로드 건너뛰기${NC}"
        ;;
esac

echo ""
echo -e "${GREEN}🎉 빌드 프로세스 완료!${NC}"
echo "======================================"
echo "📦 Archive: $ARCHIVE_PATH"
echo "📱 IPA: $IPA_FILE"
echo "📊 Build 로그: $BUILD_DIR/build_$TIMESTAMP.log"
echo ""
echo -e "${CYAN}📋 다음 단계:${NC}"
echo "1. TestFlight에서 빌드 확인 (10-15분 소요)"
echo "2. 테스터 그룹에 빌드 배포"
echo "3. 베타 테스트 시작"
echo ""
echo -e "${PURPLE}🔗 유용한 링크:${NC}"
echo "• App Store Connect: https://appstoreconnect.apple.com"
echo "• TestFlight: https://apps.apple.com/app/testflight/id899247664" 