#!/bin/bash

# 🚀 DeepSleep 빠른 시작 스크립트

echo "🌟 DeepSleep 개발 환경 빠른 시작"
echo "=================================="
echo ""

# 색상 코드
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}무엇을 하시겠습니까?${NC}"
echo ""
echo "1. 🔍 실시간 로그 모니터링 시작"
echo "2. 🚀 TestFlight 빌드 시작"
echo "3. 📱 시뮬레이터에서 앱 테스트"
echo "4. 🧹 프로젝트 Clean & Build"
echo "5. 📊 프로젝트 상태 확인"
echo "6. 🔧 개발 도구 설정"
echo ""
read -p "선택하세요 (1-6): " choice

case $choice in
    1)
        echo -e "${GREEN}🔍 실시간 로그 모니터링 시작...${NC}"
        ./start_console_logging.sh
        ;;
    2)
        echo -e "${PURPLE}🚀 TestFlight 빌드 시작...${NC}"
        ./build_for_testflight.sh
        ;;
    3)
        echo -e "${BLUE}📱 시뮬레이터 테스트 시작...${NC}"
        
        # 시뮬레이터 부팅
        DEVICE_ID=$(xcrun simctl list devices | grep "iPhone 16 Pro (" | head -1 | grep -o '\([A-F0-9-]*\)' | head -1)
        if [ ! -z "$DEVICE_ID" ]; then
            echo "iPhone 16 Pro 시뮬레이터 부팅 중..."
            xcrun simctl boot "$DEVICE_ID" 2>/dev/null || echo "시뮬레이터가 이미 실행 중입니다."
            
            # 시뮬레이터 열기
            open -a Simulator
            
            # 앱 빌드 및 실행
            echo "앱 빌드 및 실행 중..."
            xcodebuild build -project DeepSleep.xcodeproj -scheme DeepSleep -destination "platform=iOS Simulator,id=$DEVICE_ID"
            
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}✅ 빌드 성공!${NC}"
                echo "시뮬레이터에서 앱을 확인하세요."
            else
                echo -e "${RED}❌ 빌드 실패${NC}"
            fi
        else
            echo -e "${RED}❌ iPhone 16 Pro 시뮬레이터를 찾을 수 없습니다.${NC}"
        fi
        ;;
    4)
        echo -e "${YELLOW}🧹 프로젝트 Clean & Build...${NC}"
        
        # Clean
        echo "프로젝트 정리 중..."
        xcodebuild clean -project DeepSleep.xcodeproj -scheme DeepSleep
        
        # DerivedData 정리
        echo "DerivedData 정리 중..."
        rm -rf ~/Library/Developer/Xcode/DerivedData/DeepSleep-*
        
        # Build
        echo "프로젝트 빌드 중..."
        xcodebuild build -project DeepSleep.xcodeproj -scheme DeepSleep
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✅ Clean & Build 완료!${NC}"
        else
            echo -e "${RED}❌ Build 실패${NC}"
        fi
        ;;
    5)
        echo -e "${CYAN}📊 프로젝트 상태 확인...${NC}"
        echo ""
        
        # Git 상태
        echo -e "${BLUE}📋 Git 상태:${NC}"
        git status --short
        echo ""
        
        # 최근 커밋
        echo -e "${BLUE}📝 최근 커밋:${NC}"
        git log --oneline -5
        echo ""
        
        # 브랜치 정보
        echo -e "${BLUE}🌿 브랜치 정보:${NC}"
        git branch -v
        echo ""
        
        # 프로젝트 설정
        echo -e "${BLUE}⚙️  프로젝트 설정:${NC}"
        BUNDLE_ID=$(xcodebuild -project DeepSleep.xcodeproj -showBuildSettings | grep PRODUCT_BUNDLE_IDENTIFIER | awk '{print $3}' | head -1)
        VERSION=$(xcodebuild -project DeepSleep.xcodeproj -showBuildSettings | grep MARKETING_VERSION | awk '{print $3}' | head -1)
        BUILD=$(xcodebuild -project DeepSleep.xcodeproj -showBuildSettings | grep CURRENT_PROJECT_VERSION | awk '{print $3}' | head -1)
        
        echo "Bundle ID: $BUNDLE_ID"
        echo "Version: $VERSION"
        echo "Build: $BUILD"
        echo ""
        
        # 디스크 사용량
        echo -e "${BLUE}💾 디스크 사용량:${NC}"
        du -sh . 2>/dev/null || echo "디스크 사용량을 확인할 수 없습니다."
        echo ""
        ;;
    6)
        echo -e "${PURPLE}🔧 개발 도구 설정...${NC}"
        echo ""
        
        # Xcode 버전 확인
        echo -e "${BLUE}🛠️  Xcode 정보:${NC}"
        xcodebuild -version
        echo ""
        
        # 시뮬레이터 목록
        echo -e "${BLUE}📱 사용 가능한 시뮬레이터:${NC}"
        xcrun simctl list devices | grep -E "(iPhone|iPad)" | grep -v "unavailable" | head -10
        echo ""
        
        # 서명 인증서
        echo -e "${BLUE}🔐 서명 인증서:${NC}"
        security find-identity -v -p codesigning | head -5
        echo ""
        
        # 유용한 명령어 안내
        echo -e "${CYAN}📋 유용한 명령어들:${NC}"
        echo "• 로그 모니터링: ./start_console_logging.sh"
        echo "• TestFlight 빌드: ./build_for_testflight.sh"
        echo "• 시뮬레이터 리셋: xcrun simctl erase all"
        echo "• DerivedData 정리: rm -rf ~/Library/Developer/Xcode/DerivedData"
        echo "• 프로젝트 정리: xcodebuild clean"
        echo ""
        ;;
    *)
        echo -e "${RED}❌ 잘못된 선택입니다.${NC}"
        exit 1
        ;;
esac

echo ""
echo -e "${GREEN}🎉 작업 완료!${NC}"
echo "다른 작업이 필요하면 다시 실행하세요: ./quick_start.sh" 