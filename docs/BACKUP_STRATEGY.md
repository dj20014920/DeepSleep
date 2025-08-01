# 🛡️ DeepSleep 프로젝트 백업 전략

> 작성일: 2025-08-01
> 
> 중요 문서 및 코드의 손실을 방지하기 위한 체계적인 백업 전략

## 📋 목차
1. [핵심 문서 목록](#핵심-문서-목록)
2. [백업 방법](#백업-방법)
3. [복구 절차](#복구-절차)
4. [예방 조치](#예방-조치)

---

## 1. 핵심 문서 목록

### 🔴 최우선 보호 문서
- **DEEPSLEEP_COMPREHENSIVE_GUIDE.md** - 프로젝트 전체 가이드
- **Secrets.xcconfig** - API 키 설정 (Git 제외, 로컬 백업 필수)
- **README.md** - 프로젝트 소개
- **CLAUDE.md** - AI 지침서

### 🟡 중요 문서
- **DEEPSLEEP_FIRES_TREE.md** - 프로젝트 구조
- **NAMING_CONVENTIONS.md** - 네이밍 규칙
- **BATTERY_EFFICIENCY_REPORT.md** - 성능 보고서
- **docs/*.md** - 모든 문서

### 🟢 코드 파일
- **ChatManager.swift** - 핵심 AI 통합
- **UnifiedAIServiceImpl.swift** - AI 서비스 구현
- **Info.plist** - 앱 설정

---

## 2. 백업 방법

### 2.1 자동 백업 (Git)
```bash
# 매일 커밋 습관화
git add .
git commit -m "📅 Daily backup: $(date +%Y-%m-%d)"
git push origin ai-hybrid

# 중요 변경 후 즉시 커밋
git add <중요파일>
git commit -m "🔧 중요 변경: <설명>"
git push
```

### 2.2 로컬 백업
```bash
# 주간 백업 스크립트 생성
#!/bin/bash
BACKUP_DIR="$HOME/Desktop/DeepSleep_Backup_$(date +%Y%m%d)"
mkdir -p "$BACKUP_DIR"

# 핵심 파일 복사
cp DEEPSLEEP_COMPREHENSIVE_GUIDE.md "$BACKUP_DIR/"
cp -r DeepSleepApp/Secrets.xcconfig "$BACKUP_DIR/" 2>/dev/null || echo "Secrets.xcconfig not found"
cp README.md "$BACKUP_DIR/"
cp -r docs/ "$BACKUP_DIR/docs/"

echo "✅ 백업 완료: $BACKUP_DIR"
```

### 2.3 클라우드 백업
1. **iCloud Drive** 
   - `~/Documents/DeepSleep_Backup/` 폴더 생성
   - 주요 문서 정기 복사

2. **GitHub Private Gist** (민감정보 제외)
   ```bash
   # Gist로 문서 백업 (API 키 제외)
   gh gist create DEEPSLEEP_COMPREHENSIVE_GUIDE.md --public -d "DeepSleep Project Guide"
   ```

---

## 3. 복구 절차

### 3.1 Git에서 삭제된 파일 복구
```bash
# 삭제된 파일 히스토리 확인
git log --all --full-history -- <파일명>

# 특정 커밋에서 파일 복구
git checkout <commit-hash> -- <파일명>

# 또는 최근 커밋에서 복구
git checkout HEAD~1 -- <파일명>
```

### 3.2 실수로 삭제한 경우
1. **휴지통 확인** (macOS)
2. **Time Machine** 백업 확인
3. **Git 히스토리** 검색
4. **로컬 백업 폴더** 확인

### 3.3 Claude AI를 통한 복구
- Claude가 이전에 읽은 파일은 메모리에서 복원 가능
- 전체 내용을 읽었다면 거의 완벽하게 복구 가능

---

## 4. 예방 조치

### 4.1 .gitignore 최적화
```gitignore
# 중요 문서는 반드시 예외 처리
!DEEPSLEEP_COMPREHENSIVE_GUIDE.md
!README.md
!docs/*.md
```

### 4.2 파일 보호 설정
```bash
# 중요 파일 쓰기 보호 (실수 방지)
chmod 444 DEEPSLEEP_COMPREHENSIVE_GUIDE.md

# 수정 필요시
chmod 644 DEEPSLEEP_COMPREHENSIVE_GUIDE.md
```

### 4.3 정기 점검 체크리스트
- [ ] 매주 월요일: 로컬 백업 실행
- [ ] 매일: Git 커밋 확인
- [ ] 매월 1일: 전체 백업 상태 점검
- [ ] 분기별: 백업 복구 테스트

### 4.4 Git Hook 설정
```bash
# .git/hooks/pre-commit 파일 생성
#!/bin/bash
if ! [ -f "DEEPSLEEP_COMPREHENSIVE_GUIDE.md" ]; then
    echo "⚠️ 경고: DEEPSLEEP_COMPREHENSIVE_GUIDE.md 파일이 없습니다!"
    echo "이 파일은 프로젝트의 핵심 문서입니다. 복구하세요."
    exit 1
fi
```

---

## 5. 비상 연락처

문서 손실 시:
1. Git 히스토리 확인
2. 로컬 백업 확인
3. Claude AI에게 복구 요청
4. 팀원에게 백업 요청

---

## 🚨 중요 알림

**DEEPSLEEP_COMPREHENSIVE_GUIDE.md는 절대 삭제하지 마세요!**

이 파일은:
- 프로젝트의 모든 정보를 담고 있음
- 신규 개발자 온보딩의 핵심
- 818줄의 상세한 가이드

매번 중요한 변경 후에는 반드시:
1. Git 커밋
2. 로컬 백업
3. 팀원과 공유

---

*이 문서를 정기적으로 검토하고 업데이트하여 백업 전략을 최신 상태로 유지하세요.*