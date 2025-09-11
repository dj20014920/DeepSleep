$1

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
