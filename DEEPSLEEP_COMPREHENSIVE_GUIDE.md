# DeepSleep Comprehensive Guide
### 🆕 2025-09-12 동기화: 스트리밍 롤아웃·UX 개선·서버 캐시 SSOT
- 프록시 `/v1/chat/stream` 운영 적용. 서버가 Gemini streamGenerateContent의 SSE/NDJSON을 표준 SSE(`data: <text>`)로 정규화하여 첫 토큰 즉시 UI 갱신 가능.
- iOS ChatViewController: 스트리밍 중 테이블 전체 reload를 금지하고, 보이는 셀만 "잉크 퍼짐(왼→오) + 타이핑"으로 텍스트 업데이트(틱 0.083s/1자, 페이드 0.6s). 줄바꿈/문자 누적/시간 기준으로 간헐 reflow(begin/endUpdates) 수행해 화면 흔들림 제거.
- 로딩 버블: 첫 델타에서 제거(타이핑 타이머 시작). 델타 0건(네트워크/업스트림 이슈) 시 폴백 호출 전 강제 제거로 이중 버블 방지.
- 인증 LRU: 프록시가 UID→secret을 5~10분 TTL로 메모리 캐시. `Server-Timing`에 `authCache=hit|miss` 반영.
- Gemini 캐시 SSOT: 캐시 생성은 1024 토큰 이상에서만 시도. 미달 시 `X-Cache-Action=bypass:too-small(1024)` 및 `X-Cache-Tokens=readIn=…;min=1024;action=…` 헤더로 가시화.

[정책 SSOT] 구독/결제/환불/복원/7일 무료체험 관련 최신 정책·문구는 SUB_GUIDE.md를 참조하십시오. 모든 UI/링크/문구는 SUB_GUIDE.md 기준으로 유지합니다.

### 🆕 2025-09-10 동기화: 신경망 피드백→추천 플로우 완성 + BGTask 학습 스케줄러
- 세션 시작/중간저장/종료 흐름을 SessionManager로 일원화: PresetFeedback/BehaviorEvent가 실행 중에도 안전하게 저장되며 체인 무결성 보장
- FeedbackCollectionViewController 제출 시 중간 스냅샷(PresetFeedback) 저장 및 즉시 학습 트리거 경로 확립
- EnhancedSoundRecommendationEngine.updateUserProfile(UserProfileVector) 실구현: 선호 사운드 볼륨/시간대 선호 갱신, lastUpdated 관리
- 랜덤 제거 및 결정적 버전/볼륨 선택(SoundPresetUtilities): safePresetName, generateOptimalVersions를 DRY/SSoT로 통합해 재현성 확보
- RecommendationContext/UserProfileVector 기반 추천 후보/랭킹 로직 정합성 강화(외부 모델 프리셋 추천 재사용 준비)
- BGTaskScheduler(AppDelegate) 등록/스케줄: 백그라운드에서 FeedbackIntegrationManager.performIncrementalLearning 주기 실행
- 로깅/메트릭 정밀화: BehaviorEvent(.feedback) 추가 기록, 백그라운드 진입 시 SessionManager.flush로 저장 안정성 강화


### 🆕 2025-09-10 업데이트: 페르소나 캐시/레거시 정리/로그 정돈
- System Prompt 캐시 키에서 메모리 요약 fingerprint 제거(캐시 안정화, 히트율 상승 예상)
- 페르소나 캐시 전면 마이그레이션: components 기반(composite=core+mode+model+tone)
- LEGACY API(getSystemPrompt(personaSignature:)) 제거 → components API 단일화(SSoT)
- InvalidationReason.legacyPath 제거(레거시 경로 완전 폐기)
- 앱 버전 변경 무효화는 .manual + caller("AppDelegate.appVersionChange")로 단순화
- UsageLimitManager 내부 로깅 침묵화 기본값 유지, DebugFlags.internalUsageVerbose로 세부 로그 토글
- UnifiedAIServiceImpl: components 기반 캐시 호출로 리팩터 완료
- SessionManager 로그 체계 1차 정리(INIT/LOAD). RETENTION/READY 단계는 선택적 후속
- 로그 소음 감축 제안(선택): ContextMetrics age 포맷 개선, AIContextManager.clearCache debounce, MemoryGuard dedupe
