# DeepSleep Comprehensive Guide

### 🆕 2025-09-24 업데이트: 캐시/세션 풀/운영 키/모니터링

본 섹션은 캐시 백엔드/세션 풀 전환 상황에서 상용 운영을 위한 통합 대상, 설정 키, 모니터링, QA 가이드를 정리합니다.

- HyperCacheBackend 통합 대상(코드베이스 탐색 결과)
  - AIContextManager (시스템 프롬프트 캐시)
    - 현황: 프로세스 메모리 내 캐시(3h TTL, components 기반 키), 디스크 영속화 없음.
    - 권장: 선택적으로 HyperCacheBackend 연결(네임스페이스 예: "ai_system_prompt")로 TTL/용량 SSOT 적용과 공통 메트릭 확보.
    - 주의: 시스템 프롬프트는 크기가 작으므로 디스크 상한은 기본값(100MB)로 충분. 장애/재시작 후 프롬프트 재생성 비용도 낮아 “필수 아님”.
  - AppleFMCache (응답 텍스트 캐시; 레거시)
    - 현황: 기본 Off(긴급 롤백 시에만 사용). 기존 UserDefaults 기반.
    - 권장: 레거시 경로 유지가 필요한 환경에서만 HyperCacheBackend로 백엔드 대체 가능(네임스페이스 "applefm_legacy"). 단, 정상 경로에서는 세션 풀 사용.
  - AppleFMSessionPool (세션 재사용)
    - 현황: 메모리 전용(세션 직렬화 불가), TTL/LRU/동시 초기화 병합, 무효화 트리거 연결(모델 변경/응급 정리).
    - 비고: HyperCacheBackend 적용 대상 아님(세션은 디스크로 내리면 의미 상실).
  - KVPromptCache (llama.cpp용 KV 프리필)
    - 현황: 엔진 특화 메모리 캐시, 세션 스냅샷 직렬화/복원 전용, TTL/LRU 자체 구현.
    - 권장: HyperCacheBackend 미적용(설계 목적이 상이).
  - LRUCache.swift (범용 소형 in-memory 유틸)
    - 현황: 일부 경량 로컬 캐시에 사용.
    - 권장: 규모가 작고 엔진/세션 특화가 아닌 경우에는 그대로 유지. 광범위 치환 필요 없음.

- 적용 가이드(샘플)
  - 생성/연결
    - let cache = CacheBackendFactory.makeHyper(namespace: "ai_system_prompt")
    - CacheMetricsLogger.shared.attach(to: cache)  // 이벤트 메트릭 로깅(옵션)
  - 사용 예시
    - await cache.setString(systemPrompt, forKey: components.composite)
    - let cached = try await cache.getString(forKey: components.composite)
  - 트림(옵션)
    - await cache.trimToMemory(bytes: GlobalCachePolicy.defaultMemoryLimitBytes / 2)

- 운영 키(Info.plist)
  - 범용
    - CACHE_TTL_SECONDS_DEFAULT = 10800
    - CACHE_MEM_LIMIT_MB = 64
    - CACHE_DISK_LIMIT_MB = 100
  - AFM 전용
    - APPLE_FM_SESSION_POOL_ENABLED = true
    - APPLE_FM_RESPONSE_CACHE_ENABLED = false
    - APPLE_FM_SESSION_TTL_SECONDS = 10800 (선택)
    - APPLE_FM_SESSION_MAX_COUNT = 16 (선택)
  - 관측성
    - CACHE_METRICS_VERBOSE = false (상세 이벤트 로깅 토글; 운영 기본은 false 권장)
    - AFM_SESSION_STATS_LOG_INTERVAL = 60 (세션 풀 통계 주기 로깅; 운영 30~120초 권장)

- 모니터링/로그
  - 세션 풀(AppleFMSessionPool)
    - ACQUIRE (hit|miss|join-inflight|miss→create), EXPIRE, EVICT, CLEAR_ALL 로그 확인
    - 주기 통계: enabled/count/ttl/max/H/M/E/X 요약
  - 캐시 백엔드(HyperCacheBackend)
    - hit/miss/set/remove/trim/expire/evict/error 이벤트를 CacheMetricsLogger로 수집
  - 클라이언트 경로(UnifiedAIServiceImpl)
    - AFM 완료/스트림 로그에 세션 키 요약(coreHash:mode:model:toneHash:sysDigest 앞 8자)와 poolEnabled 표시

- QA 체크리스트(적용 검증)
  - 동일 persona/mode/model/tone/systemPromptDigest로 3회 호출 시 1턴 miss→create, 2·3턴 hit로 TTI/완료시간 감소
  - TTL(3h) 이후 동일 키 요청 시 miss로 재생성
  - 동시 다중 요청에서 초기화 단 1회만 발생(join-inflight 확인)
  - 모델 변경(Settings) 및 응급 정리(메모리 경고) 직후 invalidateAll 로그 출력 및 이후 miss→create 재확인
  - llama.cpp/KVPromptCache 경로 영향 없음, 시스템 프롬프트 캐시(AIContextManager)와 정책 충돌 없음
### 🆕 2025-09-16 동기화: 온디바이스 분기/폴백 + 원격 설정/UX 반영
- 온디바이스 원격 설정 게이트 추가: ONDEVICE_ENABLED, ONDEVICE_FORCE_CLOUD, ONDEVICE_MAX_TTI_MS (Info.plist/원격 재구성 연계).
- 열 완화 정책 적용: 심각/치명 열 상태에서 경량 모델 우선(선호 무시), 자동 다운스케일.
- 온디바이스 실패 시 클라우드 폴백 경로 명확화: 모든 온디바이스 후보 실패 시 안전 폴백(응답 말미 안내 문구).
- 설정 화면 내 온디바이스 카드 인라인 설치/취소/삭제/진행률 UI 유지(중앙 정렬·연속 퍼센트).
- 로깅/계측: TTI(ms), 활성 모델 ID, 설치/무결성 결과, 전환 성공/실패, 세션 길이 OSLog 기록.

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


### 🆕 2025-09-16 동기화: 온디바이스 경로·스트리밍 폴백·UI 라벨링
- 온디바이스 경로
  - Adapter.generate: 첫 델타 도착 시점에 TTI(ms) 측정, summary(ttiMilliseconds, modelID) 반환
  - UnifiedAIServiceImpl.sendToOnDevice: ResponseMetadata.additionalInfo에 { provider: ondevice, ondeviceModelID, ttiMs } 저장
- 스트리밍 폴백(클라이언트)
  - ChatViewController: 스트리밍 델타가 0건이면 비스트리밍 호출로 폴백
  - 권장: 폴백은 AIResponse 반환 오버로드를 사용하여 메타데이터(모델/TTI/프로바이더)를 보존 → UI 라벨 일관화
- UI 라벨링(권장 포맷)
  - 온디바이스: "온디바이스 · {ModelCatalog.displayName} · TTI {n.n}s"
  - 클라우드: "{AIModel.displayName} · {additionalInfo.model | provider}"
- 온디바이스 후보/fallback (SSOT)
  - Gemma 3 270M (Q8_0) → Qwen 0.5B (Q4_K_M) → Gemma 3 1B (IQ4_XS)
- 앱 레벨 폴백 순서
  - freeModel(OpenRouter 통합) → gemini → openAI → naver → claude
- presign 실패 처리
  - presign 실패는 CDN 고정 경로로 자동 폴백. sha256 불일치 시 백오프 재시도(3회)

### 🆕 2025-09-22 동기화: Apple Foundation Models(iOS 26+) 가드·온디바이스 라우팅·출력 필터링 정책
- AFM 호출 가드: `AppleFMAdapter.generateFull(sys:user:)` 사용 지점에 `#available(iOS 26.0, *)` 추가. iOS 26 미만/미가용 시 `AppleFMError.notAvailable`로 안전 종료 후 기존 경로로 폴백.
  - 적용 위치: `UnifiedAIServiceImpl.sendMessageStream`(원청크 스트림 브랜치), `UnifiedAIServiceImpl.sendMessage`(완료형 브랜치)
- 온디바이스 라우팅: `.onDevice` 선택 시 우선 AFM(가용 시)→ 비가용이면 `OnDeviceAdapter`(llama.cpp)로 자동 폴백. 메타데이터에 `provider=applefm|llama.cpp`, `ttiMs` 기록 유지.
- Gemma 전용 지침(중요): Gemma IT 모델은 system 역할 미지원. 시스템 지시는 초기 user 턴에 내재화하고, 프롬프트는 반드시 `<start_of_turn>user ... <end_of_turn>\n<start_of_turn>model` 포맷을 따른다. 스톱 토큰은 `<end_of_turn>` 외에도 `<start_of_turn>`이 출력되면 즉시 중단하도록 가드한다.
- 컴파일 오류 정리
  - `'generateFull(sys:user:)' is only available in iOS 26.0 or newer` 경고 해결(가드 추가)
  - `fallbackOrder` 심볼 스코프 오류 해결: 앱 레벨 최종 폴백은 `.freeModel`로 단순화(클라우드 선택은 기존 맵핑 로직 유지)
  - 존재하지 않던 `sendToOnDevice(...)` 호출 제거 → 내부 코어(`sendMessageInternal`) 재사용 경로로 통일해 DRY/SSOT 유지
- 출력 후처리(필터링) 정책 업데이트
  - 과도한 인사말 억제 금지: 첫 턴의 “저는 리플릿의 대나무숲 친구예요! 동동님 반가워요!” 같은 라이트한 인사는 허용
  - 후처리는 코드펜스 전체 감싸기 제거, 선행 화자 라벨([AI 친구]:, AI:, assistant:) 제거에 국한
  - 반복 인사 제거는 “이전에 assistant 턴이 존재할 때만” 제한적으로 적용 → UX 저해 최소화
- 문서/로그
  - Apple Developer Docs(FoundationModels/LanguageModelSession) 기준으로 가용성·API 확인 및 주석 반영
  - 로깅: AFM 응답 시간 `🍎 Apple FM complete/stream` 로그 유지, 폴백 경로 명확 출력


### 🆕 2025-09-23 동기화: AFM one‑chunk 스트리밍 폴백 오탐 제거 + 기본 모델 onDevice
- 증상: Apple을 선택해도 응답 마지막에 서버 프록시 로그(`AICallSummary provider=gemini …`)가 따라붙는 문제가 간헐적으로 발생.
- 원인: Apple FM이 one‑chunk 스트림(완료 조각 1개)로 응답할 때, ChatViewController 스트리밍 루프가 `gotAnyDelta`를 `isComplete=false` 조각에서만 true로 설정하여 “델타 무(없음)”로 오인 → 비스트리밍 폴백 호출이 추가로 발생(서버 경유, provider=gemini 노출).
- 변경점(코드 반영됨):
  - 스트리밍 루프 개선: 어떤 조각이든 수신 시 `gotAnyDelta = true`. 완료 조각도 `delta`를 타이핑 버퍼에 적재하고 `typingCompletedStream = true`로 자연 종료.
  - 폴백 호출 정렬: 스트림이 진짜 0조각일 때만 비스트리밍 폴백. 폴백 호출의 UI 반영은 `AIResponse.content`만 사용.
  - 방어적 기본값: `SessionManager` 문자열 오버로드의 기본 `model`을 `.onDevice`로 변경(오버로드 오용 시에도 Apple 기본).
- 기대 로그(성공 케이스):
  - `🍎 AppleFM responded (...)` → `🍎 Apple FM stream (one-chunk) durationMs=...`
  - 이후에 `🎯 [AICallSummary] ... provider=gemini ...`가 나타나지 않음(추가 서버 호출 없음).
- 폴백이 의도적으로 발생하는 케이스:
  - iOS 26 미만 또는 AFM 미가용 → `llama.cpp` 경로 사용(메타 `provider=llama.cpp`). 이때도 서버 프록시 로그는 없어야 함.
- QA 체크리스트:
  - Apple 선택 · 일반 대화 1회: 상기 “기대 로그”만 출력되는지 확인.
  - iOS 26 미만/AFM 미가용 환경: `provider=llama.cpp`만 보이고 서버 로그 미표출 확인.
  - 외부 모델 강제 선택(프리셋 추천 등): 기존 정책대로 프록시 로그가 정상 노출.
- 운영/UX 메모:
  - 라이트한 인사말은 후처리에서 제거하지 않음. 코드펜스/화자 라벨만 정리(필터링 정책 유지).