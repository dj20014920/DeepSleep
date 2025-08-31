# AI Context Management Roadmap

[Note: Existing content retained above]

## 2025-08-25 Updates (스토리지 관리·알림·내보내기·보존 정책 정리)

이번 업데이트는 저장소 관리 화면과 알림 설정, 채팅 내보내기 보안, 삭제 UX의 일관성을 코드와 문서에 반영합니다. AI 컨텍스트/캐시 로드맵과 충돌 없이, 사용자 데이터 보존·보호 정책과 개인정보 보호 원칙을 강화하는 변경입니다.

핵심 변경 요약
- 대화 재개(ResumeConversationForDate): 저장소 관리 화면의 날짜행에서 "이어서 대화"를 누르면 해당 날짜 세션을 로드하여 ChatViewController로 진입합니다. 네비게이션 계층(AppDelegate/SceneDelegate)에서 Notification(Name: ResumeConversationForDate)을 구독하고, ChatRouter를 통해 ChatViewController를 생성합니다. 해당 날짜에 대화가 없으면 안내 Alert를 표시합니다.
- 즐겨찾기 상한(무료 3개 / 프리미엄·트라이얼 10개):
  - SettingsManager.favoriteDates(Set<yyyy-MM-dd>)를 단일 진실의 원천으로 유지.
  - SubscriptionStatusCenter.isPremium 변화를 구독하여 상한 초과 시 자동 정리(오래된 항목부터) 및 토스트 안내.
  - 저장소 관리 상단에 상한 배지(예: 2/3, 7/10) 표시. 필요 시 자세히(모달/툴팁) 확장 가능.
- 알림 설정 "1시간 전" 토글:
  - SettingsManager.notificationsTodoOneHourBeforeEnabled(Boolean) 추가 및 변경 시 Notification 방송.
  - NotificationSettings 화면에 스위치(UI) 추가. 켜면 CentralNotificationScheduler/TodoManager가 모든 해당 Todo에 대해 "마감 1시간 전" 알림을 예약, 끄면 해제. 마스터 알림 스위치와 정합성 유지.
- 채팅 내보내기(텍스트 전용, PII 마스킹):
  - ChatViewController 네비게이션바에 "내보내기" 버튼 추가.
  - 최근 메시지를 사용자(나) / 모델(모델) 교대로 텍스트-only로 빌드하여 공유 시트(UIActivityViewController) 띄움.
  - SettingsManager.maskPIIForExport()로 전화/이메일 등 민감 패턴을 마스킹. SettingsManager.exportUserDataSanitized()가 기본값으로 사용되도록 정리.
- 삭제 UX 강화 및 버튼 정리:
  - "전체 삭제"는 2단계 확인(첫 경고 → 최종 파괴 확인)으로 오작동 방지.
  - 수동 "60일 삭제" 버튼은 제거. 기존 "30일 삭제" 버튼은 "선택한 날짜 삭제"로 재용도화(다중 선택 후 삭제)하여 사용자가 명시적으로 지정.
- 압축 UI/경로 제거(또는 비표시):
  - 기존 압축 관련 UI/코드는 유지보수 대상에서 제외하고, 자동 보존/삭제 정책(30/60일, 최근 7일 보호, 즐겨찾기 제외)에 일치하도록 정리.
- 보존 정책 문구 정비(레이블/도움말):
  - 자동 삭제: 30일/60일 정책, 최근 7일 보호창, 즐겨찾기 제외를 명시. 수동 60일 삭제 버튼은 제거되었음을 반영.

검증 체크리스트(8/25)
- [x] 저장소 관리 → 이어서 대화: 해당 날짜 세션 열림, 미존재 시 Alert.
- [x] 즐겨찾기 상한: 무료=3, Pro/Trial=10, 구독 변경 시 초과분 정리 및 토스트.
- [x] 알림: "1시간 전" 토글 On → 예약, Off → 해제. 마스터 스위치와 정합.
- [x] 내보내기: 공유 시트 노출, 텍스트-only, PII 마스킹 적용.
- [x] 삭제: 전체 삭제 2단계 확인. 60일 삭제 버튼 제거. 선택 삭제 정상 동작.
- [x] 압축 UI 비노출. 보존 정책 레이블 최신화.

후속 추천(옵션)
- 선택 삭제에도 즐겨찾기/최근 7일 보호 예외를 적용할지(삭제 제외 or 경고) 결정.
- 즐겨찾기 상한 배지 옆 "자세히" 버튼으로 무료/프리미엄 안내 및 초과 시 정리 정책 설명 모달 제공.
- 내보내기 전 경로 전수 스캔(검색/검증) 요청 시, 모든 경로에 maskPIIForExport/exportUserDataSanitized 강제 적용 보장.

### 2025-08-25 추가 업데이트: 보호 배지/상단 배지/내보내기 자동 검사

- 보호 조건 표기 강화: 저장소 관리 테이블 셀에 보호 배지(🛡)를 노출하여 보호 대상임을 즉시 인지 가능하게 개선. 즐겨/최근/요일 보호 조건을 조합해 "🛡 즐겨·최근·요일" 형태로 표시합니다.
- 보존 정책 고정 텍스트 상단 배지화: 저장소 관리 화면 상단 통계 섹션에 "🔒 최근 N일 보호"/"⭐ 즐겨찾기 제외" 배지를 추가해 핵심 정책을 한눈에 안내합니다(N=SettingsManager.protectedDaysWindow).
- 내보내기 전수 스캔 자동화 스크립트: UIActivityViewController 경로의 텍스트 공유가 SettingsManager.maskPIIForExport 또는 exportUserDataSanitized를 반드시 거치도록 스크립트 기반 정적 점검을 추가합니다.

검증 체크리스트(8/25 추가)
- [x] 보호 배지: 즐겨/최근/요일 조건에 따라 배지 텍스트가 올바르게 조합되는지 확인.
- [x] 상단 배지: 보호일수/즐겨 제외 안내가 보이고, 구독 상한 배지와 충돌하지 않는지 확인.
- [x] 자동 스캔: 아래 스크립트를 실행해 위반 시 실패(exit 1)하는지 확인.

실행 방법(로컬/CI)
- 로컬: 아래 명령을 실행합니다.
```bash path=null start=null
bash scripts/verify_export_pii.sh
```
- CI: GitHub Actions 등에서 빌드 전 단계에 위 스크립트를 호출하세요. 위반 발생 시 워크플로우가 실패하도록 유지합니다.

샘플(통과 사례)
```swift path=null start=null
let message = "사용자 메모: \(raw)"
let safe = SettingsManager.shared.maskPIIForExport(message)
let vc = UIActivityViewController(activityItems: [safe], applicationActivities: nil)
```

## 2025-08-23 Updates (컨텍스트/캐시 최신 정책 확정)

이번 업데이트는 실제 코드베이스와 완전히 동기화된 컨텍스트·캐시 정책을 문서에 반영합니다. 핵심은 단일 진입점(SessionManager), 조립의 중앙화(AIContextBuilder), 3시간 TTL의 시스템 프롬프트 캐시(AIContextManager), 그리고 명확한 무효화 트리거입니다.

- 단일 진입점: 모든 외부 AI 호출은 SessionManager.sendMessage(...) 경로만 허용됩니다. UnifiedAIServiceImpl에 대한 직접 호출은 금지(내부 전용)되었으며, sendMessageStream도 동일한 assembledPrompt 경로로 중앙집중화했습니다.
- 컨텍스트 조립(assembledPrompt):
  - 구성 순서: [시스템 프롬프트(캐시)] → [핵심 기억 요약(있으면)] → [최근 대화 16턴(사용자 8 + AI 8)] → [현재 입력]
  - TokenOptimizer로 모델별 토큰 예산 내 적합화(시스템>기억>최근대화 우선순위 유지)
- 시스템 프롬프트 캐시: AIContextManager.getSystemPrompt(personaSignature:generator:)
  - TTL=3시간(10800초), ConfigReader로 오버라이드 가능
  - personaSignature = 모드 + 선택 모델 + 핵심기억 요약 지문(해시). 외부 전송 금지, 내부 캐시 키 전용
- 캐시 무효화 트리거 (코드 반영 완료)
  - 모델 변경(SettingsManager.updateSelectedModelAtomically) → .modelSelectionChanged
  - 페르소나/규칙 변경(PersonaMemoryManager, UserRulesManager.addRule) → .personaChanged / .userRulesChanged
  - 핵심 기억 변경(MemoryManager) → .coreMemoryUpdated
  - 앱 버전/환경 중요 변경 시 → .environmentChanged
- 보안/PII: 외부 AI에는 비식별 서술형 컨텍스트만 전달. 페르소나 해시는 캐시 식별에만 사용되며 외부로 절대 전송하지 않습니다.
- 메트릭/관측성: ContextMetrics가 요청 시작/종료, 모델/모드 분포, Fallback 시도, 캐시 HIT/MISS, 품질 점수 경고를 통합 수집합니다.

검증 체크리스트(8/23)
- [x] Settings/Persona/Rules 변경 시 AIContextManager.clearCache(reason: …) 호출 경로 존재
- [x] SessionManager.buildBalancedRecent(raw, userMax:8, assistantMax:8) 적용
- [x] UnifiedAIServiceImpl.generateOptimizedSystemPrompt → AIContextManager 캐시 사용
- [x] sendMessageStream 경로도 assembledPrompt 우선 사용(인터페이스 정렬)

## 2025-08-20 Updates (페르소나 캐싱 및 AI 컨텍스트 관리 완성)

### ✅ 완료된 핵심 작업

1) **페르소나 캐싱 시스템 완벽 작동**
- AIContextManager에 상세 디버깅 로그 추가
- 캐시 HIT/MISS 로직 검증: 첫 요청 MISS → 두 번째 요청 HIT
- TTL(3시간) 및 personaSignature 해시 일치 확인
- 테스트 결과: 20초 이내 재요청 시 100% 캐시 히트

2) **AI 컨텍스트 및 페르소나 통합**
- AIContextBuilder에서 UserSettingsModel.generateAIContext() 호출
- 시스템 프롬프트에 사용자 컨텍스트 포함
- UserRulesManager.personaSignature()에 디버그 로그 추가
- AI 응답에서 페르소나 정보 반영 확인 ("동동님", "25세", "피곰한 애")

3) **설정 관리 및 JSON 파싱 개선**
- Info.plist에 Secrets.xcconfig 키 매핑 추가
- UsageLimitManager에서 사용량 제한 정상 로드 (30회 일일 제한)
- ChatViewController의 parseJSONIntelligently 메서드 개선 (```json 코드 블록 제거)

### 📋 성과 측정
- **캐시 적중률**: 첫 요청 이후 100%
- **캐시 TTL**: 10800초 (3시간) 정상 작동
- **응답 시간**: 무료 모델 8-10초
- **사용량 추적**: 2/30 정상 카운트
- **대화 컨텍스트**: 최근 16턴(사용자 8 + AI 8) 균형 유지

### 🔍 디버그 로그 개선 사항
```
🆔 [UserRulesManager] PersonaSignature 생성 로그
  - 사용자 설정 로드 및 트레이트 결합 표시
  - SHA256 해시 생성 및 출력

🔍 [AIContextManager] 캐시 관리 로그
  - getSystemPrompt 호출 시 personaSignature 표시
  - 캐시 존재 여부, 해시 비교, TTL 검증 상세 로그
  - 캐시 HIT/MISS 및 새 프롬프트 생성 로그

🏗️ [AIContextBuilder] 프롬프트 구성 로그
  - 사용자 컨텍스트 포함 여부 표시
  - 최종 프롬프트 크기 및 구성 요소
```

### 🔄 남은 작업 (우선순위)

### 🆕 2025-08-20 추가: 컨텍스트 윈도우/요약/캐시 최종 정책 확정
- 단기 기억(최근 대화) 정책을 다음과 같이 확정함.
  - 포함 개수: 최신 16턴(사용자 8 + AI 8) 균형 선별
  - 정렬: 최종 프롬프트 내 포함 순서는 최신순(가장 최근 발화가 상단)으로 유지하여 즉시성 강화
  - 선별 로직: SessionManager.buildBalancedRecent(raw, userMax: 8, assistantMax: 8)
- 핵심 기억 요약(fallback) 정책
  - MemoryManager.getMemorySummary()가 비어있으면 summarizeRecent(recent)로 경량 요약 생성
  - 요약 포맷: 역할 라벨(User/AI) + 키 문장, 최신순 상위 16개만 압축
- 시스템 프롬프트 캐시(페르소나) 정책
  - AIContextManager.getSystemPrompt(personaSignature:generator:) 캐시 TTL=3시간(기본 10800초)
  - personaSignature가 동일하면 100% 캐시 HIT, 모델을 바꾸면 시그니처가 달라져 최초 1회 MISS 후 HIT
- 토큰 예산/상한 정책
  - AIContextBuilder.fitRecentMessages는 TokenOptimizer.maxTokens(for:) 예산 내에서만 최근 대화 포함
  - 모델 호출 레벨에서 TokenConfiguration.maxTokens를 API에 전달함(OpenAI: max_tokens, Gemini: maxOutputTokens, Claude: max_tokens)
  - 기본값: AI_GENERAL_CONVERSATION_MAX_TOKENS=800 (Secrets.xcconfig→Info.plist로 주입 가능)

**Must-fix (즉시 해결 필요)**
- [ ] CompilerFixStubs/ChatBubbleCell Stub 제거 또는 실구현
- [ ] weak IBOutlet 즉시 해제 버그 수정
- [ ] ZeroTokenAPIChecker 동시성 안전화 (Swift 6 대비)

**Should-fix (1주 내)**

---

## 2025-08-29 동기화: 사용량 한도·라벨·폴백 정책

## 2025-08-31 동기화: 인사 억제·브랜딩 카피·온보딩 UI(한국어)

이번 동기화는 컨텍스트/응답 후처리와 사용자-facing 카피 정책, 온보딩 UI 개선을 문서에 반영합니다.

핵심 변경
- 반복 인사 억제: 시스템 프롬프트에 "반복 인사/닉네임 과다 사용 금지" 지침 추가 + AIResponsePostProcessor로 후속 턴 인사 제거(첫 인사 유지)
- 브랜딩 카피 중앙화: BrandingCopy.swift 생성 및 구독/추천/분석 관련 문구를 상수화(DRY). 프로젝트 전역 UI에서 "AI 모델/AI 추천/AI가" → 브랜드 톤으로 치환
- 온보딩 UI 인식 강화: 페르소나 단계에 핵심 버튼 비활성(미리보기) + 캡션 추가. 구독 미리보기 라벨은 BrandingCopy 상수 사용

치환 가이드(사용자-facing 텍스트만)
- "AI 모델" → "대나무숲 친구 모델"
- "AI 추천" → BrandingCopy.recommendationName 또는 quickActionAIRecommendationTitle()
- "AI가 ~" → "대나무숲 친구가 ~"
- "AI " 접두사 → 문맥에 따라 "대나무숲/대나무숲 친구"로 조정

검증 체크리스트(8/31)
- [x] OnboardingViewController: 구독 미리보기에 BrandingCopy.subscriptionFreeLabel/ProLabel 사용
- [x] Persona/Settings/UsageAnalytics 주요 화면의 사용자-facing 텍스트 치환 완료
- [x] UnifiedAIServiceImpl 경로에서 인사 후처리 로그/메타데이터 확인 가능

추가 코드 동기화(2025-08-31)
- ChatViewController에 restoreMessagesFromStorage 구현(저장 → UI 모델 매핑) 및 showTutorialIfNeeded(간단 알림) 추가
- SettingsViewController에서 튜토리얼 호출 제거(설정 화면은 미표시 정책)
- OnboardingViewController의 메인 진입 방식 표준화: SceneDelegate.showOptimizedMainInterface 우선, 불가 시 Notification("GoToMainScreen") 폴백

후속 권장
- 주요 CTA(예: 추천 시작, 분석 실행)에도 미리보기+캡션 패턴 확장 여부 협의
- BrandingCopy에 추가 카피(analysisCompleteTitle, analysisReasonLabel 등) 지속 통합
- 전역 정적 텍스트에 대한 스크립트 기반 검증(치환 누락 자동 탐지) 도입

요약
- 한도/티어/주간 정책은 코드 단일화(UsageLimitManager)로 관리하며, 화면은 얇은 어댑터(AIUsageManager)로만 사용함.
- 채팅: Free/Pro/Max 티어별 한도 적용. 80%/100% 도달 시 Alert로 남은 횟수/자정 리셋/업그레이드 CTA 제공.
- Claude: Premium 30회 상한 초과 시 자동으로 Gemini(또는 다음 폴백) 라우팅. 성공 시에만 Claude 카운트 증가.
- 월간 통계: 주간 1회(KST, 월요일 00:00 리셋) 정책으로 통일. 시작 전 안내에 이번 주 남은 횟수/리셋 시각 표기.
- 버튼 라벨: 일기 분석/월간(주간) 분석/일기 편집·작성 화면의 대나무숲 버튼까지 “(남은 N/총 M)” 또는 “(이번주 n/1)”로 표준화.
- 프록시(Cloudflare Workers): `USE_PROXY=YES`일 때 UnifiedAIServiceImpl이 `/v1/chat`로 라우팅(HMAC 인증). 서버는 티어/상한 보조 집행 및 통일 포맷 반환.

관련 코드
- UsageLimitManager: 일일/주간 한도, 티어별 키 적용, 80%/100% 알림 발행
- UnifiedAIServiceImpl: Claude 상한 체크와 자동 폴백, 성공 시 카운트 증가
- AIUsageManager: 위임/브로드캐스트만 수행(DRY)
- ChatViewController: Alert 수신 및 Paywall 전환 CTA
- EmotionDiary/EmotionCalendar/EditDiary/DiaryWrite VC: 버튼 라벨 표준화 및 실시간 갱신
- Proxy: emozleep/src/worker.js, wrangler.toml(바인딩/Vars), Info/Secrets 매핑(USE_PROXY, PROXY_BASE_URL, CLIENT_PROXY_HMAC_SECRET)

운영/관측 포인트

Immutable Proxy Contract(절대 변경 금지) — 반드시 준수
- HMAC 서명 원문: "{ts}:{uid}:{tier}:{nonce?}" (Nonce 사용 시 포함, 순서 고정)
- 요청 헤더: X-Emozleep-UID/Tier/Timestamp/(Nonce?)/Sig (대소문자/하이픈 포함 정확히 일치)
- Origin: https://emozleep.app (ProxyAuthConfig.origin 상수로 관리, 하드코딩 분산 금지)
- 엔드포인트/메서드: POST /v1/enroll, POST /v1/chat, POST /v1/subscription/report, OPTIONS /v1/chat
- 정책 헤더: X-Provider, X-Policy-Tier, X-Policy-ResetAt(+09:00), X-Policy-Claude-Remaining
- Naver 키: NAVER_CLOUD_API_KEY=key:secret (단일 키). 과거 NAVER_API_KEY/NAVER_API_SECRET 표기는 폐기.

이유(Why)
- 클라이언트-서버 간 인증/정책 헤더는 프로토콜 계약입니다. 사소한 오타나 순서 변경은 인증 실패를 유발합니다.
- Origin 상수화로 누락/오탈자 리스크 제거(DRY). 서버 ALLOWED_ORIGINS와의 정합성 보장.
- Naver 키 단일화로 문서/대시보드/코드의 중복 제거 및 운영 안정성 향상.
- Alert 트리거 시점과 리셋 시각(자정, KST 주간)을 로그에 함께 남겨 CS/분석에 활용
- 폴백 발생 로그는 모델쌍(from→to)과 사유를 함께 기록(ContextMetrics)
- [ ] UnifiedAIServiceImpl 메트릭 TODO를 ContextMetrics로 통합
- [ ] MemoryOptimizationManager 최소 정책 구현
- [ ] ConfigReader 유틸 공통화 (DRY 달성)

---

## 2025-08-20 Updates

- 메트릭 확장: 모델/모드별 요청 분포 카운터(requestsByModel/requestsByMode)와 폴백 시도 카운터(fallbackAttempts) 추가. oneLineSummary() 및 modelModeSummary(topK:) 제공.
- 주기적 요약 로그: UnifiedAIServiceImpl에서 20건마다 메트릭 요약/분포 로그를 출력하여 운영 가시성 강화.
- 라이프사이클 요약: 앱 비활성화 시점(WillResignActive)에도 메트릭 요약 및 모델/모드 분포 로그를 남김.
- 퍼즈 테스트 보강: 대용량/이상 유니코드 혼합 JSON, 코드펜스 제거, 공급자별 JSON 경로 + 스트리밍 유사(부분 청크/순서 교란/중간 종료) 검증 강화.
- 빌드 상태: iPhone 16 Pro 시뮬레이터 기준 BUILD SUCCEEDED.

- ContextMetrics: 품질 점수 임계치 경고 로깅 추가(기본 60, ConfigReader로 오버라이드 가능).
- ContextMetrics: 캐시 HIT/MISS 카운터 및 cacheSummary() 제공. AIContextManager.getSystemPrompt 경로에서 자동 집계.
- SettingsViewController/UnifiedAIServiceImpl: 캐시 무효화 트리거 재확인(모델/페르소나 변경 시 .clearCache(reason: …) 호출). 이미 구현된 경로 검증 완료.
- 빌드 검증: iPhone 16 Pro 시뮬레이터 대상으로 BUILD SUCCEEDED. 테스트 스킴 미구성으로 test 액션은 비활성 상태.

## 2025-08-19 Updates

- Persona signature hash usage clarified: strictly internal for cache invalidation detection; never sent to external AI.
- External AI receives filtered, anonymized natural language context (e.g., "This user is in their 30s"), preserving utility without PII.
- Centralized system prompt caching in AIContextManager.getSystemPrompt(personaSignature:generator:), with TTL via ConfigReader (default 10800s).
- Unified cache invalidation reasons (InvalidationReason) and event logging via ContextMetrics.
- SettingsManager.updateSelectedModelAtomically(_:): atomic model switching now persists selection, clears context cache with .modelSelectionChanged, then posts .aiModelChanged.
- UnifiedAIServiceImpl observes .aiModelChanged and defensively clears cache again; also generates optimized system prompts using AIContextManager cache with personaSignature composed from mode/model/memory summary fingerprint.
- SettingsViewController and UserBasicInfoViewController now invoke AIContextManager.shared.clearCache with precise reasons on save/updates (modelSelectionChanged, personaChanged).
- ZeroTokenAPIChecker refactored for Swift 6 concurrency safety: removed captured var mutation, added synchronized ResumeState to ensure single continuation resume.
- UnifiedAIService.sendMessageStream supports assembledPrompt path to match sendMessage signature; streaming and non-streaming paths are centralized.
- Build verified: succeeded for iPhone 16 Pro simulator. Remaining warnings tracked for cleanup (no functional regressions).

## Detailed TODO for Production Hardening (Aligned with 2025-08-19)

다음은 상용 수준 고도화를 위한 상세 작업지시 TODO 리스트입니다. 이 문서만으로도 작업 목적, 이유, 연결부를 파악하고 수행할 수 있도록 자세하게 작성했습니다.

1) 원칙 검증 및 범위 확정
•  목적: DRY/KISS/YAGNI/SOLID와 “중앙집중형 호출” 원칙을 모든 변경의 기준으로 삼고, ‘이미 다른 로직으로 완성된 부분’과 충돌 없이 통합.
•  해야 할 일:
•  모델 전환, 구성 로딩(Info.plist/xcconfig), 캐시 무효화, 메트릭 수집 경로를 전수 조사.
•  명칭만 다른 동일 로직을 식별해 단일 진입점으로 통합 계획 수립.
•  완료 기준: 동일 책임은 1개 진입점만 남고, 중복·분기 편차 제거.

2) 모델 전환 시스템 통합(완료된 구현 반영)
•  근거: 모델 전환은 AIModelSelectionViewController.swift로 구현 완료됨.
•  해야 할 일:
•  ChatViewController 내 “모델 전환 시스템 통합 예정/임시 주석” 제거 또는 AIModelSelectionViewController로 위임.
•  SettingsManager → UnifiedAIServiceImpl → AIContextManager.clearCache(reason: .modelSelectionChanged)을 단일 이벤트 파이프로 일원화.
•  완료 기준: 모델 변경 시 캐시 무효화/재초기화가 원자적으로 수행. 중복 경로 제거.

3) 스트리밍 assembledPrompt 중앙집중화
•  문제: sendMessageStream이 assembledPrompt를 받지 않아 경로가 분기.
•  해야 할 일:
•  UnifiedAIService.sendMessageStream 인터페이스를 sendMessage와 동일하게 assembledPrompt 우선(최종 시스템 프롬프트 포함)으로 확장.
•  SessionManager → AIContextBuilder → assembledPrompt 생성 → UnifiedAIService(동일 인터페이스)로 일원화.
•  기존 메시지 배열 전달은 내부 변환에 한정.
•  완료 기준: 스트리밍/일반/특정모델 호출 경로 모두 동일한 중앙집중형 assembledPrompt 체계.

4) 캐시 무효화 트리거 최종 점검
•  해야 할 일:
•  트리거 목록: 모델 변경, 설정 변경, 앱 버전 변경(AppDelegate), 페르소나 변경, 핵심메모리 요약 변화.
•  모두 AIContextManager.clearCache(reason: …)로 집결하는지 확인. 누락 추가, 중복 제거.
•  CacheLogEntry와 InvalidationReason Codable 직렬화 재검증.
•  완료 기준: 캐시 일관성 보장, 로그/메트릭 상 이유 추적 가능.

5) 메트릭 일원화(ContextMetrics)
•  해야 할 일:
•  UnifiedAIServiceImpl 전체 경로(요청/응답/실패/스트리밍)에서 공통 메트릭을 ContextMetrics로 수집.
•  요청 수, 성공률, 에러율, p95 레이턴시, 모델별/모드별 카운터 구현.
•  완료 기준: 산재 TODO 제거, 대시보드화 가능한 이벤트 스키마 확립.

6) ZeroTokenAPIChecker 동시성 안정화
•  문제: captured var(hasResumed) 경고(향후 Swift 6 오류 승격 가능).
•  해야 할 일:
•  Actor 혹은 AsyncStream/CheckedContinuation 안전 패턴으로 재작성.
•  동시성 단위테스트 작성.
•  완료 기준: 경고 제거, 회귀 테스트 통과.

7) Performance/Battery/Memory Manager 액터 격리 위반 수정
•  해야 할 일:
•  @MainActor 싱글톤 접근을 nonisolated에서 호출한 경로 수정.
•  필요한 범위에만 메인 격리 적용, 래퍼 제공.
•  완료 기준: 경고 제거, 성능 저하 없음.

8) 스토리보드 미사용 정책 반영
•  전제: 본 앱은 스토리보드 미사용(코드 UI).
•  해야 할 일:
•  init(coder:) fatalError 제거 또는 @available(*, unavailable)로 명시.
•  weak IBOutlet에 새 인스턴스 할당하는 코드 제거(예: FeedbackVisualizationViewController), 코드 기반 레이아웃으로 대체.
•  완료 기준: UI 생성이 전부 코드 경로로 일관, 취약 패턴 제거.

9) CompilerFixStubs 및 Stub 코드 제거/실구현 이관
•  해야 할 일:
•  CompilerFixStubs.swift, ChatBubbleCell의 Stub 제거 또는 실제 구현으로 이관.
•  남길 경우 명확한 계약 정의와 단위테스트 동반.
•  완료 기준: TODO=0, Stub=0.

10) Config 일원화(Secrets.xcconfig → Info.plist → Bundle 참조 강제)
•  문제: 일부 하드코딩/강제주입 상수 사용.
•  해야 할 일:
•  모든 키를 xcconfig → Info.plist로 주입 후 Bundle.main.object(forInfoDictionaryKey:)로만 접근.
•  하드코딩 제거. 누락될 기본값은 Info.plist에 명시(깃 노출 위험 방지).
•  대상 키: AI_GENERAL_CONVERSATION_MAX_TOKENS, AI_GENERAL_CONVERSATION_TEMPERATURE, DAILY_TODO_ADVICE_LIMIT, AI_LIMITS_TODO_ADVICE, MAX_TODO_ITEMS 등.
•  완료 기준: 번들 참조 흐름 100%, 소스 내 비밀/상수 노출 0.

11) Config 접근 유틸 공통화
•  해야 할 일:
•  AppConfig/SecurityConfig/UsageLimitManager 등 분산 접근을 ConfigReader로 통합(타입 세이프 변환, 로깅/기본값 정책 포함).
•  완료 기준: DRY 달성, 키 변경 시 단일 지점 수정.

12) UsageLimitManager 중앙 체크/증가 진입점 보강
•  해야 할 일:
•  UnifiedAIServiceImpl 입구에서 canUse→거부 처리→성공 시 increase까지 일괄 수행.
•  산재 호출 제거. 80%/100% 도달 Notification 표준화.
•  완료 기준: 중복 계산/누락 방지, 사용자 알림 후속 연결 준비.

13) UnifiedAIServiceImpl 메트릭/로그 품질 향상
•  해야 할 일:
•  요청 ID 트레이싱, 모델/모드 태그 표준화.
•  오류 유형 구분(네트워크/할당량/파서), OpenRouterFallback 분기 명시.
•  불필요 default 케이스 제거.
•  완료 기준: 디버깅·관측성 향상.

14) AIResponseParser 스트리밍 경로 퍼즈 테스트 추가
•  해야 할 일:
•  청크 분리, 중간 JSON, 깨진 토큰 등 비정상 입력 퍼즈.
•  assembledPrompt 도입 이후 파서 일관성 검증.
•  완료 기준: 스트리밍 파서 안정성 확보.

15) MemoryOptimizationManager 최소 정책 구현
•  해야 할 일:
•  LRU/나이 기반 캐시 정리, 이미지 캐시 압축.
•  메모리 워닝/백그라운드 진입 훅 연계.
•  완료 기준: 과도한 사전 최적화는 배제하면서 필수 안정성 확보.

16) EnhancedSoundRecommendationEngine 범위 확정
•  원칙: 지금은 너무 큰 작업이면 로드맵으로 이관.
•  해야 할 일:
•  UserProfileVector 최소 스키마 정의 또는 제거(YAGNI).
•  로컬 신경망 결합은 별도 이니셔티브 항목으로 계획만 명시.
•  완료 기준: 현재 릴리스 범위의 안정된 인터페이스만 유지.

17) ClaudeAPIService 정합성 점검
•  해야 할 일:
•  다른 API 서비스 구현과 비교, AI/AI-README.md 기준으로 공통 모델/필드/오류 모델 일치 여부 확인.
•  필요 없는 TODO 삭제, 필요한 기능만 구현. 공통 프로토콜 도입 고려.
•  완료 기준: 서비스 간 일관성/DRY 확보.

18) Deprecated/불필요 분기/Dead Code 정리
•  해야 할 일:
•  UIColorExtensions의 불필요 #available 제거, CoreData isIndexed 대체, UIApplication.windows 최신화.
•  항상 true/false 분기, 미사용 지역 변수 제거.
•  완료 기준: 경고 대폭 축소.

19) 캐시 식별자/PII 보호 재점검
•  해야 할 일:
•  personaSignature는 내부 캐시 키 해시 전용으로 유지.
•  외부 AI에는 비식별 서술형 컨텍스트만 전달.
•  완료 기준: 문서/코드 일치, 데이터 보호 재확인.

20) SessionManager 중앙집중형 호출 흐름 검증
•  해야 할 일:
•  buildPrompt → assembledPrompt → UnifiedAIService 동일 인터페이스로 호출.
•  모든 경로(일반/스트리밍/특정모델)에 일관 적용.
•  완료 기준: 호출 루트 하나, 예외 분기 내부 변환으로만 처리.

21) AIModelSelectionViewController와 Settings 연동 재점검
•  해야 할 일:
•  선택 변경→Settings 저장→UnifiedAIServiceImpl 모델 갱신→AIContextManager 캐시 무효화가 원자적으로 수행되는지 확인.
•  완료 기준: 사용자 관점의 즉시 반영과 안정성.

22) 문서 업데이트(ROADMAP/COMPREHENSIVE_GUIDE/AI-README)
•  해야 할 일:
•  중앙집중형 assembledPrompt, 캐시/메트릭 일원화, Config 정책, 스토리보드 미사용, 모델 전환 통합 완료 반영.
•  완료 기준: 문서 진실의 단일 출처화.

23) 테스트 보강(단위/통합/회귀)
•  해야 할 일:
•  ZeroTokenAPIChecker 동시성, ConfigReader, UsageLimitManager, UnifiedAIService 메트릭/한도, 스트리밍 파서 퍼즈.
•  완료 기준: 핵심 경로 자동 검증.

24) 빌드 검증 파이프라인 정리
•  해야 할 일:
•  클린 빌드→유닛 테스트→스모크 플로우(모델 전환/요청/스트리밍/캐시 무효화) 스크립트.
•  로그 위치 표준화(build/xcodebuild_last.log).
•  완료 기준: 반복 가능·재현 가능 환경.

25) 코드 삭제 후보 일괄 정리
•  해야 할 일:
•  가르치기 잔존 코드/주석, 임시 로깅, 미사용 타입/프로토콜 일괄 제거.
•  PR에 삭제 사유/대체 경로 명시.
•  완료 기준: YAGNI 준수, 코드베이스 경량화.

26) 리스크/롤백 계획 수립
•  해야 할 일:
•  중앙집중화로 인한 회귀 대비. 이전 인터페이스 어댑터를 얇게 유지하여 단기 우회 가능(일시적).
•  완료 기준: 릴리스 안정성 보장.

27) 최종 품질 점검 체크리스트
•  목표: 경고=0(불가피 경고는 문서화), TODO=0, Stub=0, 테스트 통과 100%, 문서 최신, 런 스모크 OK, PII 검증 완료.

# 🧠 DeepSleep AI 컨텍스트 관리 시스템 로드맵

## 🆕 2025-08-19 업데이트 (컨텍스트/한도/UX 정합 · 빌드 안정화)

이번 업데이트는 컨텍스트 캐시의 실제 적용, AIMode/시그니처 정합성, 사용량 한도 정책 통일, 채팅버블 UX 개선, 스트리밍 API의 중앙집중형 호출 일관화 적용, 구성 접근 보안 일원화(ConfigReader), 모델 전환 단일 진입점 확립을 반영합니다.

1) 시스템 프롬프트 캐시 적용 및 키 설계
- UnifiedAIServiceImpl에서 AIContextManager.getSystemPrompt(personaSignature:generator:) 사용으로 3시간 TTL 캐시 활성화
- personaSignature = mode.rawValue + 선택 모델 + 핵심 기억 요약 해시(내부 캐시 키 전용)
- 외부 LLM에는 비식별 서술형 컨텍스트만 전달(해시 자체 전송 금지) 원칙 재확인

2) AIMode 및 호출 시그니처 정합성
- AIServiceTypes.swift의 AIMode를 단일 진실의 원천으로 유지하고, 과거 임시 케이스 명칭 전면 정규화
- DailySummaryViewController 등 호출부에서 존재하지 않는 케이스 사용 금지, 유효 케이스로 치환 완료

3) UsageLimitManager 정책 통일(하드코딩 제거)
- 제한값은 Secrets.xcconfig → Info.plist → Bundle 경로로만 로드, 기본 하드코딩 값 완전 제거
- 누락 시 0(비활성)로 간주, incrementUsage에서 80%/100% Notification 발행(토스트/Alert 연동 지점 표준화)

4) 구성 접근 보안 일원화(ConfigReader)
- 보안/설정 값 접근은 ConfigReader로 단일화(민감 값 로그 미노출, 기본값 강제 주입 제거)
- AppConfig/SecurityConfig/UsageLimitManager 등 핵심 지점 리팩터링 완료

5) 모델 전환 단일 진입점 + 캐시 무효화 원자 흐름
- SettingsManager.updateSelectedModelAtomically(model): 저장 → AIContextManager.clearCache(reason:.modelSelectionChanged) → Notification.Name.aiModelChanged 방송
- AIModelSelectionViewController는 이 단일 진입점만 호출하도록 통일

4) 채팅버블 길게누르기 UX(모든 버블 대상)
- 모든 채팅 메시지(사용자/AI)에서 길게 누르면: 기억하기/복사하기/공유하기
- iOS 16+: UIEditMenuInteraction + UIActivityViewController(카카오톡 등 네이티브 공유 시트)
- iOS 15 이하: UIMenuController에 동일 메뉴 제공
- 기억하기 실행 → MemoryManager.addMemory → AIContextManager.clearCache(reason: .coreMemoryUpdated) 연동 확인

5) 빌드 안정화 및 중복 선언 정리
- MemoryManager.swift 중복 선언 단일화 및 문법 오류 정리
- UnifiedAIServiceImpl.swift의 잘못된 문법(하이픈 → 화살표) 및 누락 인자 보완

6) 스트리밍 API 중앙집중화(assembledPrompt 지원)
- UnifiedAIService.sendMessageStream(...)에 assembledPrompt 파라미터 추가(프로토콜/구현 동시 반영)
- UnifiedAIServiceImpl.sendMessageStream(...)은 내부적으로 sendMessage(...)와 동일한 중앙집중형 assembledPrompt 경로를 우선 사용하도록 통일
- 앱 코드(DeepSleepApp/*) 내 스트리밍 호출부 점검 결과: 현재 직접 호출 없음(향후 도입 시 동일 경로로만 사용 명시)

7) 다음 단계 권장(단기)
- 캐시 적중률/무효화 사유 로깅 지표 추가로 가시성 강화
- 경고 정리: 약한 참조 대입, 불필요 #available, 미사용 변수/도달 불가 코드 제거
- 통합 테스트: 동일 세션 내 캐시 HIT, 캐시 무효화 이벤트 발생 시 MISS, 한도 경고/차단 UI까지 일련 플로우 검증

### 🧪 2025-08-19 점검 결과 및 스프린트 플랜(추가)

무엇을 어떻게 점검했는가
- 전역 소스 스캔: TODO/FIXME/stub/unimplemented/fatalError/assertionFailure 등 신호를 전수 검색
- 전체 빌드: DeepSleep 스킴을 iPhone 16 Pro 시뮬레이터 대상으로 클린 빌드해 경고·잠재 결함 수집
- 결과: 빌드는 성공(오류 없음). 다수의 경고와 TODO/Stub를 확인

핵심 발견사항(상용화 관점 우선순위)
- Must-fix(출시 전 해소 권장)
  1) CompilerFixStubs 및 Stub 코드 잔존: CompilerFixStubs.swift, ChatBubbleCell.swift 내 Stub 존재 → 실제 구현 대체 또는 삭제
  2) 모델 전환 시스템 미구현 표식: ChatViewController 내 “모델 전환 시스템 통합 예정/임시 주석” → AIModelSelectionViewController 기반 단일 진입점으로 통합, Settings→UnifiedAIServiceImpl→AIContextManager.clearCache(reason:.modelSelectionChanged) 일원화. 스트리밍도 assembledPrompt로 통일(완료)
  3) ZeroTokenAPIChecker 동시성 경고: captured var(hasResumed) 변이/참조 → Actor/AsyncStream/CheckedContinuation 패턴으로 안전 재작성
  4) weak IBOutlet에 즉시 인스턴스 할당: FeedbackVisualizationViewController 등 → 코드 기반 강한 참조 프로퍼티로 전환(스토리보드 미사용 정책에 부합)
  5) @MainActor 싱글톤 접근의 격리 위반: Performance/Battery/Memory Manager 호출부 정리
- Should-fix(가급적 빠른 시점)
  6) UnifiedAIServiceImpl 메트릭 TODO: ContextMetrics 연동으로 요청/응답/실패·p95·성공률 수집
  7) MemoryOptimizationManager: LRU/나이 기반 정리, 이미지 캐시 압축, 온디바이스 모델 언로드 훅(백그라운드/메모리 워닝)
  8) EnhancedSoundRecommendationEngine Stub: UserProfileVector 최소 스키마 정의 또는 제거(YAGNI)
  9) ClaudeAPIService TODO: 제품 범위 밖이면 제거, 필요 시 UnifiedAIServiceImpl 생성 값 주입
  10) Deprecated/논리 경고: UIColorExtensions 불필요 #available, CoreData isIndexed, UIApplication.shared.windows 등 최신 API로 정리
- Nice-to-have(기술부채/정돈)
  11) 불필요 ‘init(coder:) has not been implemented’ fatalError 제거(@available(*, unavailable) 등)
  12) 미사용 변수/항상 true/false 분기 제거
  13) Info/Config 키 누락 대비 경고 로그 정책 통일(Config 접근 유틸 공통화)

로드맵 정합성 체크(8/18 결정사항 연계)
- 스트리밍 assembledPrompt: 인터페이스 확장·구현 통일(완료)
- 캐시 무효화 트리거: 모델/설정/앱 버전 변경 연결 검증, 페르소나/핵심 기억 요약 변화 트리거 재검증 예정
- 메트릭 일원화: TODO 잔존 → ContextMetrics로 흡수 예정
- 퍼즈 테스트: 스트리밍 파서 경로 커버리지 확장 예정

권장 수정 순서(짧은 스프린트 플랜)
1) ZeroTokenAPIChecker 동시성 안전 리팩터링(Actor/AsyncStream)
2) FeedbackVisualizationViewController weak IBOutlet 즉시 해제 버그 수정(코드 UI 일관화)
3) CompilerFixStubs/ChatBubbleCell Stub 제거 또는 실구현 이관
4) UnifiedAIServiceImpl 메트릭 TODO 구현(ContextMetrics 연동)
5) MemoryOptimizationManager 최소 정책 구현
6) Deprecated/불필요 분기/Dead code 정리

상위 원칙(반드시 준수)
- 비슷한 로직의 중복 금지(DRY)
- 두더지 잡기식 개별 오류 수정 금지(근본 원인 해결)
- KISS/YAGNI/SOLID 준수(단순·필요·확장 가능한 설계)

---

## 🆕 2025-08-18 업데이트 (빌드 안정화 및 컨텍스트 정합성)

이번 업데이트에서는 컨텍스트 관리 정책을 코드와 문서 전반에 일치시키고, 캐시 무효화/모드 정의 체계를 명확히 했습니다.

1) 캐시 무효화(reason) 사용 일원화
- AIContextManager.shared.clearCache(reason:caller:) 호출부를 점검하여, 페르소나 변경 등 사용자 행동에 따른 캐시 무효화를 명시적으로 수행
- 예시: clearCache(reason: .personaChanged, caller: "UserBasicInfo")

2) AIMode 정의 단일화
- AI/Services/AIServiceTypes.swift의 AIMode를 단일 진실의 원천(SSOT)으로 채택
- 과거 임시 명칭(.diaryAnalysis, .todoAdvice, .fortune, .monthlyReport 등)을 공식 케이스(.emotionDiaryAnalysis, .taskAdvice, .fortuneTelling, .monthlyStatistics 등)로 정규화
- 존재하지 않는 케이스 사용 금지. DailySummaryViewController 등은 .generalConversation 등 유효 케이스 사용

3) 시스템 프롬프트 캐시 정책 재확인
- TTL 3시간으로 확정(문서·코드 동기화). 30분 언급은 삭제/정정
- 캐시 키는 페르소나 서명 등 내부용 식별자(해시)로 관리하되, 외부 LLM에는 비식별 서술형 컨텍스트만 전달(해시 자체 전송 금지)

4) 후속 작업 권장(단기)
- 경고 정리: 약한 참조에 강한 인스턴스 대입, 불필요 #available, 미사용 변수, 도달 불가 코드 제거
- Swift 6 동시성 경고 정리: 캡쳐 변수 변경/참조 패턴 수정 또는 Task/actor 격리 강화
- AIContextManager: 캐시 적중률/무효화 사유 로깅 지표 추가(가시성 향상)

본 정리는 컨텍스트 일관성과 안전성을 높여 추후 대화 품질 향상 및 비용 최적화에 기여합니다.

## 🆕 2025-08-15 업데이트 (채팅 저장·정렬·보안 강화)
- 💬 채팅 정렬 고정: 사용자 메시지=오른쪽, AI=왼쪽. `.text` 타입도 sender 기준으로 렌더링.
- 🧹 JSON 노출 차단: AI 응답은 `parseAIResponse()`로 우선 JSON 키(message/response/text/content)에서 본문 추출 → 정규식/이스케이프 정리 → 보안 살균 순으로 처리. 원문 JSON 버블 노출 방지.
- 🧱 이중 저장 제거: `SessionManager.sendMessage()` 호출부는 `saveMessages: false`로 통일. 실제 저장은 `appendChat()` 단일 경로에서만 수행(Single Writer).
- 🧷 타입/역할 정규화: 저장 시 `role`은 ai→assistant로 표준화, `.text`는 sender에 따라 `.user/.bot/.system`으로 보정.
- 🚫 비영구: `.loading` 메시지는 영구 저장하지 않음(재진입 시 로딩 버블 미등장).
- 🔁 중복 제거: 복원 시 인접(≤5초)·동일 sender·동일 텍스트 메시지 자동 제거로 과거 이중 저장 노이즈 제거.

## 📋 개요

이 문서는 DeepSleep 앱의 **장기 비전**으로서 AI 컨텍스트 관리 시스템의 전체 아이디어와 구현 계획을 담고 있습니다. 

**🎉 2025-08-14 업데이트**: 
- ✅ **기본기 완전 완성**: BUILD SUCCEEDED 19.224초 달성!
- ✅ **SessionManager.sendMessage()**: 모든 AI 호출 중앙집중 처리 완성
- ✅ **채팅 버블 수정**: 사용자/AI 메시지 올바른 구분 표시 완료
- 🚀 **다음 단계**: 이제 중장기적으로 구현할 고급 AI 컨텍스트 관리 기능입니다.

## 🎯 최종 목표

**"AI가 사용자와의 대화를 효과적으로 기억하는 비용 효율적이고 확장 가능한 시스템"**

- 복잡한 RAG(검색 증강 생성) 시스템 없이 구현
- 사용자 지정 기억을 포함한 계층적 컨텍스트 관리
- 단기 기억, 장기 기억, AI 정체성의 3계층 구조

## 🏗️ 최종 확정 아키텍처

---

### 🆕 2025-08-18 최종 아키텍처 및 개인정보 보호 정책 확정

**배경**: "페르소나 정보와 같은 개인화 컨텍스트를 외부 AI 모델에 어떻게 안전하게 전달할 것인가?"라는 핵심 질문에 대해, 수차례의 기술적, 정책적 논의를 거쳐 최종 방향성을 확정했습니다. 초기에는 해시 처리, 단순 동의 등의 방안이 논의되었으나, 기능(개인화)과 보안(개인정보보호)을 모두 만족시키지 못했습니다. 최종적으로, 앱스토어의 '데이터 최소화 원칙'과 사용자 신뢰를 모두 충족시키는 가장 현실적이고 안전한 방안으로 아래의 **'다층 방어 전략'**을 채택하기로 결정했습니다.

**핵심 원칙: '기능 분리 아키텍처'**
> "민감한 작업은 디바이스 안에서, 창의적인 작업은 외부에서"

1.  **UI 계층 (정책적 보호)**: 사용자가 페르소나(특히 자기소개) 입력 시, "이름, 연락처 등 민감 정보는 피하고 자신의 성향과 관심사 위주로 작성해주세요"와 같은 명확한 **경고 문구**를 표시하여 1차적으로 사용자의 주의를 환기합니다.
2.  **On-Device 처리 (기술적 보호)**: 사용자가 경고에도 불구하고 민감 정보를 입력할 가능성에 대비한 '안전망'으로서, 외부 AI에 컨텍스트를 전달하기 직전 디바이스 내부에서 **간단한 필터링**을 수행합니다. 이 필터는 정규식과 키워드 매칭을 통해 전화번호, 이메일 등 명백한 PII 패턴을 찾아 `[개인정보]` 등으로 익명화합니다. 이는 **완벽한 이해가 아닌, 현실적인 리스크 감소**를 목표로 하며, '기술적 보호 조치를 취했다'는 명확한 근거가 됩니다.
3.  **External LLM (외부 AI)**: 이렇게 안전하게 가공된 **'비식별 서술형 컨텍스트'** 만을 전달받아 개인화된 응답 생성에만 집중합니다. 이 과정에서 API 호출 시 **'학습 비활성화(Opt-out)'** 옵션을 명시적으로 설정하여 데이터 주권을 지킵니다.

이 다층 방어 전략은, 사용자에게 책임을 환기시키는 동시에 서비스 제공자로서의 기술적 책임을 다하는, 상용화 수준의 앱이 갖춰야 할 가장 성숙하고 올바른 접근 방식입니다.

> 중요 정정: 해시와 컨텍스트의 역할 완전 분리 (2025-08-18 최종)
- 페르소나 시그니처 해시(Persona Signature Hash): 캐시 관리 전용 식별자입니다. 사용자의 페르소나/설정이 바뀌었는지를 판단해 캐시 무효화(clearCache)를 트리거하는 용도로만 사용합니다. 이 해시는 외부 AI로 절대 전달되지 않습니다.
- 비식별 서술형 컨텍스트(Anonymized Descriptive Context): 외부 AI에 실제로 전달되는 내용입니다. 디바이스에서 PII를 필터링한 뒤, “이 사용자는 30대입니다.”처럼 의미가 보존되는 자연어 요약을 전송합니다.
- 배경 이유: 해시값 자체(a1b2c3...)는 의미 상실된 지문이므로 AI가 개인화를 수행할 수 없습니다. 개인화를 위해서는 의미가 담긴 비식별 서술형 컨텍스트가 반드시 필요합니다. 따라서 “해시만 전달” 방식은 금지되며, 본 문서와 코드 전반은 이 분리를 엄격히 준수합니다.

---

---

### 🆕 2025-08-18 최종 아키텍처 및 정책 확정

**배경**: "페르소나 정보와 같은 개인화 컨텍스트를 외부 AI 모델에 어떻게 안전하게 전달할 것인가?"라는 핵심 질문에 대해, 수차례의 기술적, 정책적 논의를 거쳐 최종 방향성을 확정했습니다. 초기에는 해시 처리, 단순 동의 등의 방안이 논의되었으나, 기능(개인화)과 보안(개인정보보호)을 모두 만족시키지 못했습니다. 최종적으로, 앱스토어의 '데이터 최소화 원칙'과 사용자 신뢰를 모두 충족시키는 가장 현실적이고 안전한 방안으로 아래의 **'다층 방어 전략'**을 채택하기로 결정했습니다.

**핵심 원칙: '기능 분리 아키텍처'**
> "민감한 작업은 디바이스 안에서, 창의적인 작업은 외부에서"

1.  **UI 계층 (정책적 보호)**: 사용자가 페르소나(특히 자기소개) 입력 시, "이름, 연락처 등 민감 정보는 피하고 자신의 성향과 관심사 위주로 작성해주세요"와 같은 명확한 **경고 문구**를 표시하여 1차적으로 사용자의 주의를 환기합니다.
2.  **On-Device 처리 (기술적 보호)**: 사용자가 경고에도 불구하고 민감 정보를 입력할 가능성에 대비한 '안전망'으로서, 외부 AI에 컨텍스트를 전달하기 직전 디바이스 내부에서 **간단한 필터링**을 수행합니다. 이 필터는 정규식과 키워드 매칭을 통해 전화번호, 이메일 등 명백한 PII 패턴을 찾아 `[개인정보]` 등으로 익명화합니다. 이는 **완벽한 이해가 아닌, 현실적인 리스크 감소**를 목표로 하며, '기술적 보호 조치를 취했다'는 명확한 근거가 됩니다.
3.  **External LLM (외부 AI)**: 이렇게 안전하게 가공된 **'비식별 서술형 컨텍스트'** 만을 전달받아 개인화된 응답 생성에만 집중합니다. 이 과정에서 API 호출 시 **'학습 비활성화(Opt-out)'-모델 별 적용 방법 찾기** 옵션을 명시적으로 설정하여 데이터 주권을 지킵니다.

이 다층 방어 전략은, 사용자에게 책임을 환기시키는 동시에 서비스 제공자로서의 기술적 책임을 다하는, 상용화 수준의 앱이 갖춰야 할 가장 성숙하고 올바른 접근 방식입니다.

---


### 계층 1: 단기 기억 (Sliding Window)
**목표:** AI가 방금 나눈 대화 내용을 기억하여 대화의 연속성 보장

**구현 방식:**
- API 호출 시 현재 대화 세션의 최신 메시지 10개 본문을 컨텍스트에 포함
- 담당 모듈: `SessionManager.swift` (ChatManager 통합 완료)

**기술적 세부사항:**
```swift
// SessionManager.swift에서 구현 예시 (ChatManager 통합 완료)
func buildConversationContext() -> String {
    let recentMessages = getRecentChatMessages(limit: 10)
    return recentMessages.map { "\($0.role): \($0.content)" }.joined(separator: "\n")
}
```

### 계층 2: AI 정체성 (시스템 프롬프트 캐싱)
**목표:** AI의 역할, 말투, 기본 지침 등 반복 정보를 효율적으로 관리하여 API 비용 절감

**구현 방식:**
- `AIContextManager.swift`에서 시스템 프롬프트 생성
- 3시간 동안 캐시하여 재사용
- 담당 모듈: `AIContextManager.swift`

**기술적 세부사항:**
```swift
// AIContextManager.swift에서 구현 예시
private var cachedSystemPrompt: (prompt: String, timestamp: Date)?
private let cacheValidityDuration: TimeInterval = 3 * 60 * 60 // 3시간

func getSystemPrompt() -> String {
    if let cached = cachedSystemPrompt, 
       Date().timeIntervalSince(cached.timestamp) < cacheValidityDuration {
        return cached.prompt
    }
    
    let newPrompt = generateSystemPrompt()
    cachedSystemPrompt = (newPrompt, Date())
    return newPrompt
}
```

### 계층 3: 장기 기억 (사용자 지정 '핵심 기억' 시스템)
**목표:** 사용자가 중요하다고 판단한 과거 정보를 AI가 잊지 않도록 하여 개인화된 장기 기억 구현

**구현 방식:**

#### 3.1 UI/UX 인터페이스
- 사용자가 채팅 버블을 길게 눌러 [기억하기/기억 해제] 선택
- 기억된 메시지는 시각적으로 구분 (별표, 색상 변경 등)

#### 3.2 등급별 차등 제공
```
무료 사용자: 최대 5개의 '핵심 기억' 슬롯
프리미엄 사용자: 최대 20개의 '핵심 기억' 슬롯
```

#### 3.3 자동 요약 및 저장 시스템
1. **변경 감지:** '핵심 기억' 목록에 추가/삭제 발생 시
2. **원문 수집:** 저장된 모든 '핵심 기억' 메시지 원문을 묶음
3. **AI 요약:** 경량 AI 모델(Gemini 2.0 Flash‑Lite)로 '핵심 기억 요약본' 생성
4. **로컬 저장:** CoreData 또는 UserDefaults에 요약본 저장
5. **컨텍스트 주입:** 메인 AI 대화 시 요약본만 포함하여 토큰 사용량 최소화

#### 3.4 관리 화면
- 사용자가 현재 기억된 목록 확인 및 삭제 가능한 '기억 관리 창' UI

## 📊 API 호출 시 최종 컨텍스트 구조

```
[메인 AI 모델로 전송될 최종 컨텍스트]
=================================
(계층 2) 시스템 프롬프트 (3시간 캐시에서 로드)
---------------------------------
(계층 3) 사용자 지정 '핵심 기억' 요약본
---------------------------------
(계층 1) 최근 대화 1 (본문)
... 
(계층 1) 최근 대화 10 (본문)
---------------------------------
사용자의 현재 메시지
=================================
```

## 🎉 **현재 달성 상황 (2025-08-14)**

### ✅ **완성된 기반 시스템**
- **SessionManager.sendMessage()**: 모든 AI 호출의 중앙집중 처리 완성
- **채팅 메시지 저장**: StoredChatMessage를 통한 완전한 대화 기록 관리
- **사용자/AI 구분**: 채팅 버블에서 올바른 sender 표시 완료
- **BUILD SUCCEEDED**: 19.224초만에 100% 빌드 성공

### 🚀 **다음 구현 단계**
위의 3계층 컨텍스트 관리 시스템은 현재 기반이 완성된 상태에서 구현할 수 있는 고급 기능입니다:

1. **계층 1 (단기 기억)**: SessionManager.getRecentChatMessages()로 이미 구현 가능
2. **계층 2 (AI 정체성)**: AIContextManager 캐싱 시스템 구현 필요
3. **계층 3 (장기 기억)**: 사용자 지정 '핵심 기억' UI/UX 개발 필요

이제 안정적인 기반 위에서 이러한 고급 AI 컨텍스트 관리 기능들을 단계적으로 구현할 수 있습니다.

## 🎯 기대 효과

### 사용자 경험
- AI가 단기 및 장기 기억을 모두 보유
- 훨씬 더 개인적이고 깊이 있는 대화 가능
- 사용자가 직접 기억을 제어하여 높은 만족도와 신뢰 제공

### 비용 효율성
- 시스템 프롬프트 캐싱으로 반복 비용 절감
- '핵심 기억' 요약 시스템으로 토큰 사용량 획기적 감소
- 운영 비용 최소화

### 구현 현실성
- 복잡한 벡터 데이터베이스나 검색 알고리즘 불필요
- 기존 아키텍처를 점진적으로 확장하여 구현 가능

### 사업적 가치
- '핵심 기억' 슬롯 개수로 무료/유료 모델 명확 구분
- 자연스러운 유료 구독 유도 가능한 비즈니스 모델

## 🗓️ 상세 구현 로드맵 및 작업 지시 (2025-08-18 전면 개정)

**배경**: AI 모델(GPT-5, Gemini 등)의 심층 분석과 사용자의 최종 검토를 통해, 기존의 개괄적인 로드맵을 아래와 같이 구체적이고 실행 가능한 작업 지시(Actionable Work Instructions) 형태로 전면 개정합니다.

> **✅ 프로젝트 최상위 개발 원칙 (반드시 준수)**
> 모든 구현은 아래의 원칙을 최우선으로 따릅니다. 이는 단순한 기술적 지침을 넘어, 프로젝트의 품질과 장기적인 성공을 보장하는 핵심 철학입니다.
> - **"비슷한 로직이 다른 이름으로 여러곳에 산재해 있는 것을 절대 금지" (DRY 원칙):** 모든 기능은 단일 책임을 갖는 모듈이나 함수로 구현하여 코드 중복을 원천적으로 방지합니다.
> - **"근본 원인을 무시한 개별 오류 수정 금지 (두더지 잡기식 접근 엄금)":** 모든 버그 수정은 반드시 근본 원인을 분석하고, 아키텍처 차원에서 해결하여 동일한 문제가 재발하지 않도록 합니다.
> - **"소프트웨어 기본 원칙 준수 (KISS, YAGNI, SOLID)":** 불필요한 복잡성을 피하고(KISS), 현재 꼭 필요한 기능만 구현하며(YAGNI), 확장 가능하고 유지보수하기 쉬운 구조(SOLID)를 지향합니다.

**우선순위 추천: B(빌더) → A(무효화) → C(파서) → D(요약) → E/F(메트릭/QA) → G(문서)**

### A. 캐시 무효화 정책 완성
- **목표**: AI가 항상 최신 정보를 기반으로 응답하도록 보장.
- **주요 관련 파일**: `AIContextManager.swift`, `SettingsViewController.swift`, `MemoryManager.swift`
- **체크리스트**:
  - [ ] **코드 구현**: 다음 이벤트 발생 시 `AIContextManager.clearCache()`를 호출하는 로직 추가.
    - 1. 페르소나 저장/변경 (`SettingsViewController`)
    - 2. 언어/톤/모드 설정 변경 시
    - 3. '핵심 기억' 추가/삭제/요약 재생성 시 (`MemoryManager`)
    - 4. 사용자가 AI 모델을 직접 변경 시
    - 5. 앱 버전 업데이트 후 첫 실행 시
  - [ ] **로그 강화**: 캐시 무효화 시 로그에 "사유(e.g., PersonaChanged), 캐시 키, 호출자(e.g., SettingsVC)"를 기록.
- **수용 기준**:
  - ✅ 정책 테이블이 이 문서와 종합 가이드에 동일하게 명시됨.
  - ✅ 무효화 이벤트 직후의 첫 AI 호출 시, 로그에 캐시 MISS가 100% 기록됨.
  - ✅ 회귀 테스트: 페르소나 변경 후, 다음 AI 응답의 말투나 내용에 변경사항이 즉시 반영됨.

### B. 컨텍스트 어셈블러 단일화
- **목표**: 컨텍스트 생성 로직을 중앙에서 관리하여 일관성 확보 및 유지보수 편의성 증대.
- **주요 관련 파일**: `AIContextBuilder.swift`, `TokenOptimizer.swift`, `SessionManager.swift`
- **체크리스트**:
  - [ ] **단일 빌더 함수 구현**: `AIContextBuilder.buildPrompt(for:mode:)` 와 같은 단일 함수를 생성. (DRY 원칙 준수)
    - 이 함수는 "시스템 프롬프트(캐시) + 핵심기억 요약 + 최근 n턴"을 정해진 순서로 조합.
  - [ ] **TokenOptimizer 연동**: 빌더 함수 내에서 토큰 예산을 체크하고, 초과 시 우선순위(시스템>기억>최근대화)에 따라 최근 대화부터 동적으로 축약/감축하는 로직 적용.
  - [ ] **품질 스코어 계산**: 컨텍스트의 충실도(데이터 유무, 길이 등)를 기반으로 0~100점의 품질 스코어를 계산하고, 기준점(예: 65점) 미만 시 경고 로그를 출력.
- **수용 기준**:
  - ✅ 코드 리뷰: 모든 AI 호출이 동일 빌더를 경유하며, 다른 곳에 컨텍스트 조합 로직이 중복으로 존재하지 않음.
  - ✅ 로그 확인: 토큰 예산을 초과하여 컨텍스트가 잘리는(cut-off) 예외 상황이 발생하지 않음.

### C. AI 응답 파서 매트릭스 도입
- **목표**: 여러 AI 공급자의 다양한 응답 포맷에 안정적으로 대응.
- **주요 관련 파일**: `AIResponseParser.swift`, `UnifiedAIServiceImpl.swift`
- **체크리스트**:
  - [ ] **3단계 파싱 로직 구현**: `AIResponseParser.parse(response:from:)`
    - 1. **1차(공통 키)**: `message`, `response`, `text`, `content` 등 공통 키 우선 탐색.
    - 2. **2차(공급자별 어댑터)**: 1차 실패 시, 공급자(e.g., `.openAI`)에 맞는 어댑터를 호출하여 지정된 경로(`choices[0].message.content`) 탐색.
    - 3. **3차(폴백)**: 모두 실패 시, 원문에서 JSON/마크다운 제거 등 보안 살균 처리 후 텍스트 반환.
  - [ ] **퍼즈 테스트 케이스 추가**: 비정상적인 JSON, 이스케이프 문자가 포함된 마크다운, 특수 유니코드 등이 포함된 1,000개 이상의 테스트 케이스 작성.
- **수용 기준**:
  - ✅ 파싱 실패율(3차 폴백까지 간 비율)이 0.5% 미만.
  - ✅ 퍼즈 테스트 케이스를 100% 오류 없이 통과.

### D. 프리셋 추천 상호작용 요약 저장
- **목표**: 대화 맥락의 가독성을 높이고 불필요한 토큰 낭비 방지.
- **주요 관련 파일**: `PresetInteractionSummarizer.swift`, `SessionManager.swift`
- **체크리스트**:
  - [ ] **요약 포맷 확정**: "사용자: 프리셋을 요청했습니다.", "AI: 프리셋을 추천했습니다: [프리셋 이름]" 과 같은 명확한 포맷 정의.
  - [ ] **민감정보 필터링**: 요약 과정에서 사용자 입력에 포함될 수 있는 개인정보(이름, 장소 등)를 필터링하는 로직 추가.
  - [ ] **저장 로직 구현**: `SessionManager`에서 메시지 저장 시, 해당 타입의 메시지는 요약 포맷으로 변환하여 `Core Data`에 저장.
- **수용 기준**:
  - ✅ 샘플 대화에서 프리셋 관련 대화가 요약되어 저장됨을 확인.
  - ✅ 장기 대화 컨텍스트에서 불필요한 노이즈가 50% 이상 감소됨.

### E. 이벤트/성능 메트릭 표준화
- **목표**: 시스템 상태를 정량적으로 파악하고 데이터 기반 의사결정 지원.
- **주요 관련 파일**: `ContextMetrics.swift` 및 관련 호출부 전체
- **체크리스트**:
  - [ ] **대시보드 항목 정의**: 캐시 HIT/MISS 비율, 컨텍스트 길이/토큰(평균/최대), 응답시간(ms), 모델별/폴백 단계별 호출 수, 품질 스코어 분포, 요약 길이 및 갱신 주기.
  - [ ] **로깅 구현**: `UnifiedLogger`를 통해 위 항목들을 구조화된 형식으로 기록.
- **수용 기준**:
  - ✅ 정의된 모든 메트릭이 로그를 통해 수집되고, 쿼리를 통해 주간/월간 리포트 생성이 가능함.
  - ✅ 캐시 전략 변경 등 A/B 테스트 시, 성능 변화를 메트릭으로 명확히 비교 가능함.

### F. QA, 회귀 테스트 및 장애 주입
- **목표**: 엣지 케이스 및 예외 상황에 대한 시스템의 안정성 및 복원력 검증.
- **주요 관련 파일**: `DeepSleepTests/`, `DeepSleepUITests/` 내 신규 테스트 파일
- **체크리스트**:
  - [ ] **테스트 스크립트 작성**:
    - 1. 캐시 무효화 테스트: 페르소나 변경 → 다음 응답에 즉시 반영되는지 검증.
    - 2. 네트워크 장애 주입: API 타임아웃, 429(Too Many Requests), 5xx(서버 오류) 발생 시 폴백 시스템이 정상 동작하는지 검증.
    - 3. 컨텍스트 품질 테스트: 의도적으로 낮은 품질의 컨텍스트를 주입했을 때 경고 로그가 발생하는지 확인.
- **수용 기준**:
  - ✅ 폴백 성공률 99% 이상.
  - ✅ 캐시 무효화 후 1턴 내에 100% 최신 설정이 반영됨.

### G. 문서 정합성 확보
- **목표**: 모든 관련 문서에서 일관된 정보 제공.
- **주요 관련 파일**: `AI_CONTEXT_MANAGEMENT_ROADMAP.md`, `DEEPSLEEP_COMPREHENSIVE_GUIDE.md`
- **체크리스트**:
  - [ ] **숫자 통일**: OpenRouter 모델 개수를 실제 리스트 기준으로 통일 (예: 25개).
  - [ ] **용어 정리**: "세션 캐시"와 "시스템 프롬프트 캐시"의 용어를 명확히 구분하거나, 현재 정책(3시간 단일화)에 맞게 표현을 수정.
- **수용 기준**:
  - ✅ 두 문서 간의 정책, 수치, 용어 표현이 100% 일치함.

## 🔧 기술적 구현 세부사항

### 데이터 모델
```swift
struct CoreMemory {
    let id: UUID
    let originalMessage: String
    let summary: String
    let timestamp: Date
    let importance: Int
    let userID: String
}

class MemoryManager {
    func addMemory(_ message: String) -> Bool
    func removeMemory(id: UUID) -> Bool
    func getMemorySummary() -> String
    func canAddMemory() -> Bool // 슬롯 확인
}
```

### UI 컴포넌트
```swift
// ChatBubbleView.swift - 길게 누르기 제스처
@objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
    if gesture.state == .began {
        showMemoryActionSheet()
    }
}

// MemoryManagementViewController.swift - 기억 관리 화면(설정 탭에 추가)
class MemoryManagementViewController: UIViewController {
    @IBOutlet weak var memoryTableView: UITableView!
    // 기억 목록 표시 및 관리
}
```

### 비용 최적화
```swift
// TokenOptimizer.swift
class TokenOptimizer {
    func optimizeContext(
        systemPrompt: String,
        memories: String,
        recentMessages: [String]
    ) -> String {
        // 토큰 수 계산 및 최적화
        // 우선순위에 따른 컨텍스트 조정
    }
}
```

## ⚠️ 주의사항 및 고려사항

### 🔐 악용 리스크와 대응(2025-08-15)
- 프롬프트 인젝션/JSON 인젝션
  - 대응: 50,000자 초과 JSON 거부, 우선순위 키 추출, 정규식·이스케이프 정리, `InputValidationManager(.aiResponse)` 살균.
- 과금 유도 시나리오(과도한 외부 AI 호출 유발)
  - 대응: UsageLimitManager 일일 한도, 무료·로컬 우선 라우팅, 캐싱/폴백, 화면 재진입 시 자동 재호출 금지(로드만 수행).
- 저장소 오염/용량 공격
  - 대응: `.loading` 미저장, 중복 제거, 메시지 페이지네이션(20개), JSON 크기 상한.
- 키/설정 탈취 시도
  - 대응: Secrets.xcconfig+Info.plist 간접 로드, 깃 제외, 로그에 민감 정보 미출력.

### 기술적 고려사항
1. **토큰 제한:** AI 모델별 컨텍스트 길이 제한 고려
2. **성능 최적화:** 대화 기록이 많아질 때의 성능 관리
3. **데이터 동기화:** 여러 기기 간 기억 동기화 방안

### 사용자 경험 고려사항
1. **직관적 UI:** 기억 기능이 복잡하지 않도록 설계
2. **투명성:** 사용자가 AI가 무엇을 기억하는지 명확히 알 수 있도록
3. **제어권:** 사용자가 언제든 기억을 수정/삭제할 수 있도록

### 비즈니스 고려사항
1. **차등 서비스:** 무료/유료 기억 슬롯 차이의 적절성
2. **마이그레이션:** 기존 사용자의 데이터 이전 방안
3. **확장성:** 향후 더 고급 기능 추가 가능성

## 🔥 결론

### 🆕 2025-08-20 코드베이스 최종 실사 및 평가
- **검증 개요**: 8월 18일에 최종 확정된 아키텍처와 상세 로드맵(A~G)의 작업 항목들이 현재 코드베이스에 실제 구현되었는지, 여러 페르소나(기술 총괄, 프로덕트 매니저 등)의 관점에서 정밀 실사를 진행했습니다.
- **검증 결론**: 로드맵의 모든 핵심 기능(`AIContextBuilder`, `TokenOptimizer`, `AIResponseParser`, `MemoryManager` 등)이 이미 코드베이스에 매우 높은 완성도로 구현되어 있음을 확인했습니다. 현재 코드는 단순한 비전을 넘어, 캐시 관리, 토큰 최적화, 동적 컨텍스트 조립, 공급자별 파싱, 핵심 기억 관리 및 관련 보안 정책이 모두 반영된, **즉시 운영 가능한(Production-Ready) 수준**의 성숙도를 갖추고 있습니다.
- **보완 필요점**: 다만, 상용화 직전 단계에서 안정성을 극대화하기 위해 **1) 핵심 로직에 대한 단위/통합 테스트 보강**, **2) 분산된 설정값 접근을 단일화된 `ConfigReader`로 리팩터링**, **3) 실제 구독 시스템과의 연동** 작업이 필요합니다.

이 AI 컨텍스트 관리 시스템은 **DeepSleep 앱의 장기 비전**으로서 매우 가치 있는 아이디어입니다. 

**핵심 가치:**
- 기술적으로 탄탄한 설계
- 사용자 경험과 비즈니스 모델의 완벽한 조화
- 단계적 구현으로 리스크 최소화

**현재 상황 (2025-08-14):**
- ✅ **기본기 완성**: SessionManager 통합, Core Data 전환, 빌드 성공 달성
- ✅ **중앙집중형 처리**: ChatManager.sendMessage() 단일 진입점 완성
- ✅ **아키텍처 안정화**: UsageAnalyticsViewController 타입 불일치 해결
- 🚀 **다음 단계**: AI 컨텍스트 관리 시스템 구현 준비 완료
- 구독 시스템 구현 후 단계적 접근 필요

**최종 권장사항:**
1. **현재:** 기본기 완성에 집중
2. **향후:** 이 로드맵을 따라 단계적 구현
3. **목표:** 사용자가 진정으로 "나를 이해하는 AI"를 경험할 수 있는 시스템 구축

**이 시스템이 완성되면 DeepSleep은 단순한 수면 앱을 넘어 사용자의 진정한 AI 동반자가 될 것입니다.** 🚀
