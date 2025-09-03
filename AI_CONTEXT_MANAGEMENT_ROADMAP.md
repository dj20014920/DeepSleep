# 2025-09-01 업데이트: 컨텍스트/캐싱/프록시 최신 상태 요약

- iOS 프록시 인증 안정화
  - UnifiedAIServiceImpl.sendViaProxy에서 HMAC 서명(ts/nonce)과 전송 헤더의 값이 일치하도록 한 번의 시점에서 생성/사용하도록 수정.
  - 401 루프 원인이던 ts/nonce 불일치 제거. 1회 재등록 후 재시도 동작은 그대로 유지.
  - 보조 헬퍼 추가: emitMetricsSummaryLog(), mapPreferredModelForProxy(_:)로 SSOT 및 로깅 일원화.
- 관측성 강화(앱/서버)
  - Server-Timing(auth, parse, provider) 파싱/로깅. DEBUG 모드에서 X-Cache-* 샘플 헤더 1회 로깅.
  - 프록시 응답 헤더: X-Provider, X-Cache-Provider/Action/TTL/Tokens 노출 및 앱에서 파싱/메타 기록.
  - /v1/metrics(공개)로 provider별 cache writes/reads, hitRate, 예상 절감액 집계.
- 모델별 캐싱 전략(서버)
  - Gemini: caches.create(ttl=3600s) 생성 후 요청마다 caches.patch(updateMask=ttl)로 1시간 TTL 연장 → 최대 3시간 운용. 사용량 메타 기반 writeIn/readIn 집계.
  - Anthropic: cache_control.ephemeral ttl=3600s. 30분 경과 시 write 강제(운영 정책), 그 외 read.
  - OpenAI: 안정 프리픽스(hash) 관찰/지표만, 본체 캐싱은 미지원.
  - Naver: 현재 캐시 미지원 경로로 bypass.
  - iOS는 providerCaching 기본 enable=true, ttlSeconds=3600 전송. cacheKey 미전송 시 서버가 system+model 해시로 내부 키 생성.
- 앱 3시간 시스템 프롬프트 캐시(클라이언트)
  - AIContextManager: 기본 TTL=3h(Info.plist 키 AI_SYSTEM_PROMPT_CACHE_TTL로 오버라이드 가능).
  - 로그 예: 첫 호출 Cache MISS 후 캐시 저장, 이후 동일 페르소나/모드에서 HIT 반환.
- 현재 운영 관찰 결과(실단말 로그 기준)
  - Server-Timing: provider;dur≈18s, X-Cache-Provider=none, Action=bypass.
  - /v1/metrics: totalWrites/Reads=0. → 프록시가 OpenRouter 경로로 라우팅되며(GEMINI_API_KEY 등 미설정) 캐시 미작동 상태임을 의미.
- 조치 사항(성능/캐시 활성화)
  1) Cloudflare Worker에 환경 변수/시크릿 설정: GEMINI_API_KEY(필수), OPENAI_API_KEY/CLAUDE_API_KEY(선택), NAVER_API_KEY/NAVER_API_SECRET(선택).
  2) 필요 시 DEFAULT_GEMINI_MODEL=gemini-2.0-flash-lite 설정으로 빠른 응답 확보.
  3) 동일 프롬프트 2회 호출해 X-Cache-Action이 read로 전환되는지 확인. /v1/metrics에서 writes/reads 누적 및 hitRate>0 확인.
  4) 성능 기준: Gemini 활성 시 provider;dur 보통 <2s(네트워크 상황에 따라 변동).

---

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

## 2025-09-01 정정: 3시간 앱 캐시는 비용 절감 없음 · 공급자 캐싱으로 전환(토큰 절약)

현황
- 현재 3시간 시스템 프롬프트 캐시는 클라이언트 내부 문자열 캐시로, 외부 LLM에 전달되는 프롬프트 길이는 동일합니다.
- 따라서 이 캐시만으로는 외부 모델 과금(토큰) 절감 효과가 없었습니다.

계획: 모델별 캐싱 전략(간략)
- Claude(Anthropic) — 운영 30분
  - API는 cache_control.ephemeral의 ttl로 5분/1시간을 지원합니다. 운영상 “30분” 정책은 1시간 TTL로 작성 후 30분 주기 재작성(또는 강제 무효화)로 실현합니다.
  - 구현: Cloudflare Worker에서 안정 프리픽스(시스템+페르소나+핵심기억 요약) 청크에 cache_control { type: "ephemeral", ttl: "1h" }를 지정. 최대 4개 breakpoints 구성.
  - 키/로깅: personaSignature로 내부 매핑(외부 전송 금지). usage.cache_creation_input_tokens / cache_read_input_tokens 로 히트/미스 계측.
- Gemini — 1시간
  - 구현: caches.create(ttl: "3600s") → 반환된 cache.name을 저장 → generateContent에 cachedContent 사용 → 필요 시 caches.patch로 ttl 연장(누적 3시간 운용은 1시간 단위 연장으로 달성).
  - 키/로깅: personaSignature 기반 캐시 키. UsageMetadata(예: totalTokenCount 등)로 비용 효과 추적.
- OpenAI — 자동(프리픽스 캐싱)
  - 구현: 별도 API 없이, 바이트 동일한 긴 프리픽스에 자동 캐시가 적용됩니다.
  - 조치: 시스템/페르소나/핵심기억 블록을 “안정 프리픽스”로 고정하고 usage 내 캐시 관련 지표를 모니터링.
- Naver HyperCLOVA X — 미지원
  - 구현: 공식 프롬프트 캐싱이 없어 컨텍스트 축약·요약·템플릿 경량화로 토큰 절감.

프록시(Cloudflare Workers) 구현 메모
- 요청 옵션 추가: providerCaching { provider, strategy, ttlSeconds, cacheKey(personaSignature) }.
- 로깅: provider별 cache_write/read 토큰, 히트율, 추정 절감액 집계.
- 무효화: 모델·페르소나·핵심기억 변경 시 캐시 폐기(서버/클라이언트 모두 일관 처리).

적용 순서(제안)
1) Gemini(1시간) → 2) Claude(운영 30분) → 3) OpenAI 프리픽스 안정화 → 4) HyperCLOVA 컨텍스트 최적화.

## 2025-09-01 동기화: 감정일기 분석 ‘에페메랄 세션’ 원칙 확정 (SSoT)

배경
- 감정일기 분석은 저장소 복원/재개/오버라이드가 개입되면 UX가 혼동되고, 원래의 자동 분석 플로우(SSoT)가 훼손될 수 있음.
- 따라서 일기 분석은 ‘에페메랄 세션’으로 진입하여, 기존 대화 복원·재개를 차단하고 즉시 분석을 시작하는 것이 원칙.

결정(코드 반영 완료)
- Router: ChatRouter.chatViewController(context: .diaryAnalysis(diary:)) → chatContext(.emotionDiaryAnalysis) + diaryContext + isEphemeralSession = true
- Controller: ChatViewController는 isEphemeralSession이면 아래를 모두 무시
  - 저장소 복원(restoreMessagesFromStorage)
  - 재개 알림(presentResumeInfoAlertIfNeeded)
  - 세션 오버라이드(adoptOverrideSessionIfNeeded)
- Trigger: setupInitialMessages() → requestDiaryAnalysisWithTracking(diary:) → SessionManager.sendMessage(mode: .emotionDiaryAnalysis)
- 모델: Gemini로 고정 전송(model=.gemini). 프록시 모드에서 서버는 동일 선호를 우선 적용.
- 적용 화면: DiaryWriteViewController / EditDiaryViewController 모두 Router(.diaryAnalysis)로 통일

검증 체크리스트
- [ ] Write/Edit에서 “대나무숲에서 이 일기 이야기하기” → Chat에서 자동 분석 시작
- [ ] 저장소 복원 알림/과거 페이징 로그 없음
- [ ] /v1/chat 호출이 mode=emotionDiaryAnalysis로 기록됨
- [ ] 사용량 한도 도달 시 Diary 화면에서 사전 차단(Alert)

—

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
•  CompilerFixStubs.swift, ChatBubbleCell의 Stub 제거 또는 실제 구현로 이관.
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

# 2025-09-02 동기화: 하이브리드 캐시 안정키/최근 16턴/프록시 헤더 강화

- 클라이언트(앱)
  - UnifiedAIServiceImpl.sendViaProxy:
    - providerCaching.cacheKey에 PersonaCoreSignature를 전달(안정 키). TTL=3600 유지.
    - assembledPrompt 경로에서도 최근 16턴 대화를 역할 메시지로 원본 그대로 포함(histTurns>0 보장).
    - 정책 로그 보강: [ProviderCaching] enable/ttlSeconds/cacheKey 접두 출력.
  - 기대 효과: 1회차 bypass → 2회차부터 X-Cache-Action=read, X-Cache-TTL≈3600.

- 서버(Cloudflare Worker)
  - Gemini 캐시 API를 v1beta/cachedContents로 전환, 인증은 x-goog-api-key 헤더 사용.
  - 생성 시 systemInstruction를 명시, read 시 TTL 연장(PATCH cachedContents/{name}?updateMask=ttl, 3600s).
  - 응답 헤더 보강: X-Fallback-Chain(시도 순서), X-Last-Error(마지막 에러 요약).

- 정정(문서-코드 일치)
  - 기존 표기 "caches.create" → 실제 구현 "cachedContents(create/patch)"로 정정.

- 검증 체크리스트(실기기)
  1) 같은 페르소나/모드로 연속 2회 호출 → 2회차에 X-Cache-Action=read 관측.
  2) AICallSummary: cacheUsed=true, cacheTTL≈3600, tokens에 cachedContentTokenCount 증가.
  3) 품질: histTurns>0로 맥락 반영(응답 자연스러움 개선).

# 2025-09-03 동기화: 캐나리 롤아웃 · 멱등성 강화

정의
- 캐나리(Canary): 기능/정책을 전체에 일괄 적용하지 않고 일부 비율(예: 5→10→50→100%)에만 점진 적용해 위험을 줄이는 배포 방식.
- 멱등성(Idempotency): 동일 요청이 여러 번 들어와도 한 번만 처리하고 같은 결과를 반환하는 성질(중복 비용/지연 방지).

앱(iOS)
- UnifiedAIServiceImpl
  - isSending 게이트로 동시 중복 방지.
  - inflightKeys Set으로 동일 요청 재진입 차단.
  - X-Idempotency-Key 생성: mode + PersonaCoreSignature + SHA256(userInput) → 64자 prefix, 프록시에 헤더로 전송.
  - AICallSummary에 canary/idempotency 헤더 로깅.

서버(Cloudflare Worker)
- X-Idempotency-Key 처리: USAGE_KV에 idemp:{uid}:{key}
  - 값 부재 → inflight 마킹(30s TTL) → 완료 시 {status:done, provider, content} 120s 저장
  - 값 inflight → 409 duplicate_inflight
  - 값 done → 200 캐시 결과 반환
- 캐나리: CANARY_PERCENT(0..100)로 providerCaching.enable을 게이팅. uid:날짜 해시→버킷 매핑.
- 응답 헤더: X-Idempotency-Status=hit|inflight|stored, X-Canary=hit(pct%)|miss(pct%).

롤아웃 계획(권장)
- Day 0: CANARY_PERCENT=5 (로그/지표 정상)
- Day 1: 10%
- Day 3: 50%
- Day 7: 100%
- 이슈 발생 시 즉시 0%로 롤백(Variables에서 수정 후 재배포).

검증 체크리스트
- 멱등성: 동일 입력 즉시 2회 → 1회차 stored, 2회차 hit
- 캐나리: hit 요청만 X-Cache-Action!=bypass 비율 상승

후속(옵션)
- 서버 측 중복응답 TTL 조정(120s→300s)
- /v1/metrics에 idempotency.{hits,inflights} 카운터 추가

# 2025-09-03 동기화: 시스템 프롬프트 경량화 · 지시 강화 · 토큰 절약 + 프록시 generation 파라미터 전달

요약
- 시스템 프롬프트 경량화(클라이언트):
  - AIContextBuilder.generateDefaultSystemPrompt를 간결한 지시문으로 축약.
  - UnifiedAIServiceImpl의 getBaseSystemPromptForMode / getModelSpecificOptimization 지침을 한 줄/핵심 요점으로 정리.
  - 지시 강화: 첫 응답만 인사 허용, 이후 인사/서두 반복 금지, 시스템 텍스트 복사 금지, 결론/문장 반복 금지, 새 관점 또는 구체 예시 1개 포함.
- 프록시 generation 파라미터 전달(클라이언트):
  - UnifiedAIServiceImpl.sendViaProxy가 temperature / maxTokens / topP / frequencyPenalty / presencePenalty / responseFormat을 /v1/chat 바디에 포함.
  - 서버는 선택적으로 수용하며, 미수용 시 무해(no-op). 수용 시 공급자별 파라미터로 매핑 권장.

기대 효과
- 토큰 절약: 장황한 서문/예시 제거로 프롬프트 길이 단축. 캐시/동일 프리픽스 정책과 함께 통합 비용 절감 기대.
- 품질 개선: 반복 인사/상투어 억제, 공감→요약→실행 제안 루틴 고정으로 일관 품질 상승.

코드 반영(요약)
- DeepSleepApp/AI/Context/AIContextBuilder.swift: generateDefaultSystemPrompt 경량화.
- DeepSleepApp/AI/Services/UnifiedAIServiceImpl.swift: 모드/모델별 지침 축약, sendViaProxy 바디에 generation 파라미터 추가.

서버/문서 정합성
- DEEPSLEEP_FROXYSERVER.md에 /v1/chat 요청 스키마 선택 필드(topP, frequencyPenalty, presencePenalty, responseFormat)를 추가해 클라이언트 변경을 문서화.

검증 체크리스트(9/03)
- [ ] /v1/chat 요청 바디에 temperature/maxTokens가 포함되고, 필요 시 topP/frequencyPenalty/presencePenalty/responseFormat도 포함되는지 서버 로그로 확인.
- [ ] 동일 요청 2회: 캐시 동작/헤더(X-Cache-*)는 기존과 동일.
- [ ] 응답에서 반복 인사 감소/구체적 실행 제안 증가를 눈으로 확인.
