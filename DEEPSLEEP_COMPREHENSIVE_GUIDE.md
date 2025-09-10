$1

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
