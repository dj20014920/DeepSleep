#!/bin/bash

# DeepSleep 프로젝트 중요 파일 백업 스크립트
# 사용법: ./backup_important_files.sh

echo "🛡️  DeepSleep 중요 파일 백업 시작..."

# 백업 디렉토리 생성
BACKUP_DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="$HOME/Desktop/DeepSleep_Backup_$BACKUP_DATE"
mkdir -p "$BACKUP_DIR"

# 색상 코드
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# 백업 함수
backup_file() {
    local file=$1
    local dest_dir=$2
    
    if [ -f "$file" ]; then
        cp "$file" "$dest_dir/"
        echo -e "${GREEN}✓${NC} $file"
    else
        echo -e "${RED}✗${NC} $file (파일 없음)"
    fi
}

# 핵심 문서 백업
echo -e "\n${YELLOW}📄 핵심 문서 백업중...${NC}"
backup_file "DEEPSLEEP_COMPREHENSIVE_GUIDE.md" "$BACKUP_DIR"
backup_file "README.md" "$BACKUP_DIR"
backup_file "CLAUDE.md" "$BACKUP_DIR"

# 설정 파일 백업 (민감정보 주의)
echo -e "\n${YELLOW}⚙️  설정 파일 백업중...${NC}"
mkdir -p "$BACKUP_DIR/config"
backup_file "DeepSleepApp/Secrets.xcconfig" "$BACKUP_DIR/config"
backup_file "DeepSleepApp/Info.plist" "$BACKUP_DIR/config"
backup_file ".gitignore" "$BACKUP_DIR/config"

# 문서 디렉토리 백업
echo -e "\n${YELLOW}📚 문서 디렉토리 백업중...${NC}"
if [ -d "docs" ]; then
    cp -r docs "$BACKUP_DIR/"
    echo -e "${GREEN}✓${NC} docs/ 디렉토리"
else
    echo -e "${RED}✗${NC} docs/ 디렉토리 없음"
fi

# 핵심 Swift 파일 백업
echo -e "\n${YELLOW}🔧 핵심 코드 파일 백업중...${NC}"
mkdir -p "$BACKUP_DIR/core_code"
backup_file "DeepSleepApp/ChatManager.swift" "$BACKUP_DIR/core_code"
backup_file "DeepSleepApp/AI/Services/UnifiedAIServiceImpl.swift" "$BACKUP_DIR/core_code"
backup_file "DeepSleepApp/AI/UsageLimitManager.swift" "$BACKUP_DIR/core_code"

# 백업 정보 파일 생성
echo -e "\n${YELLOW}📝 백업 정보 생성중...${NC}"
cat > "$BACKUP_DIR/backup_info.txt" << EOF
DeepSleep 프로젝트 백업
========================
백업 일시: $(date)
백업 위치: $BACKUP_DIR
Git 브랜치: $(git branch --show-current)
마지막 커밋: $(git log -1 --oneline)

중요: 
- Secrets.xcconfig 파일은 민감정보를 포함합니다
- 이 백업을 안전한 곳에 보관하세요
- 정기적으로 백업을 실행하세요
EOF

# 백업 크기 계산
BACKUP_SIZE=$(du -sh "$BACKUP_DIR" | cut -f1)

echo -e "\n${GREEN}✅ 백업 완료!${NC}"
echo -e "📂 백업 위치: ${YELLOW}$BACKUP_DIR${NC}"
echo -e "💾 백업 크기: ${YELLOW}$BACKUP_SIZE${NC}"
echo -e "\n💡 팁: 이 백업을 외부 드라이브나 클라우드에도 복사하세요!"

# 백업 폴더 열기 (macOS)
open "$BACKUP_DIR"