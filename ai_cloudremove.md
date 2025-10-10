# AI 클라우드/프록시 완전 제거 리팩토링 보고서

본 문서는 DeepSleep 앱에서 과거 클라우드 기반 AI(Claude 3.5, OpenAI GPT-4o mini, HyperCLOVA X, Gemini 등) 호출을 제거하고, 100% 온디바이스 경로로 전환한 변경사항을 정리한 것입니다. 모델 파일 다운로드는 Cloudflare Workers 기반 presign 엔드포인트를 통해서만 수행합니다(presign-only). 앱은 키/시크릿을 보관하지 않으며, 공개 CDN(r2.dev 등) 폴백은 사용하지 않습니다.

## 목표
- 모든 AI 메시지 처리 경로를 온디바이스(Apple Foundation Models / llama.cpp) 단일 경로로 통일
- 클라우드 호출/프록시/키 관리/건강검진 등 관련 코드 및 빌드 항목 완전 제거
- 기존 기능·온디바이스 경로를 훼손하지 않으면서 연결고리만 안전하게 단절
- KISS/DRY/YAGNI, SOLID, 단일 진입점(SessionManager) 원칙 준수

## 변경 범위 요약
- 런타임 경로: UnifiedAIServiceImpl를 온디바이스 전용으로 단순화
- 초기화/설정: 프록시 인증/프리사인·CDN 주입 제거, 기본 모델을 온디바이스로 강제
- 구독/리포팅: 프록시 티어 리포팅 제거
- 빌드 설정: 삭제된 소스들의 BuildFile/FileReference 제거
- 테스트: 프록시 플래그 테스트는 유지(환경 플래그 확인만 수행, 기능 영향 없음)

---

## 상세 변경 내역

### 1) 런타임 서비스 경로(온디바이스 단일화)
- 수정: `DeepSleepApp/AI/Services/UnifiedAIServiceImpl.swift`
  - `availableModels`를 `[.onDevice]`만 반환하도록 단순화
  - 프록시 라우팅(`sendViaProxy`, `resolveProxyBaseURL`, provider cache 헤더 등) 전면 삭제
  - 클라우드 직접 호출 폴백(`sendDirectBypassingProxy`) 및 개별 서비스 핸들 제거
  - 클라우드 서비스 인스턴스(Claude/OpenAI/Gemini/Naver/OpenRouter) 전부 삭제
  - 온디바이스(AFMs/llama.cpp) 경로는 유지 및 일관성 강화

### 2) 앱 초기화/네트워킹 경로 정리
- 수정: `DeepSleepApp/AppDelegate.swift`
  - 프록시 시크릿 워밍(ProxyAuthClient) 제거
  - presign-only 주입(ONDEVICE_PRESIGN_ENDPOINT), CDN 주입 제거
  - BG URLSession 이벤트 핸드오버에서도 presign만 재주입
  - ZeroToken/APIs 상태 점검 루틴 전체 제거(온디바이스만 사용하므로 불필요)

### 3) 기본 모델/모델 선택 UI 정책
- 수정: `DeepSleepApp/SettingsManager.swift`
  - `availableAIModels` → `[.onDevice, .apple]`만 노출
  - `selectedLLM` 기본값을 `.onDevice`로 변경
  - 저장된 레거시/클라우드 모델은 로드 시 `.onDevice`로 자체 치유
- 수정: `DeepSleepApp/SessionManager.swift`
  - 과거 하드코딩된 클라우드 모델 호출 부분을 `.onDevice`로 변경
    - `analyzeEmotion(...)` → `.onDevice`
    - `recommendPreset(...)` → `.onDevice`
    - `chat(...)` → `.onDevice`

### 4) 클라우드/프록시/키 관리 관련 파일 삭제
- 클라우드 서비스 구현(삭제)
  - `DeepSleepApp/AI/Services/ClaudeAPIService.swift`
  - `DeepSleepApp/AI/Services/OpenAIAPIService.swift`
  - `DeepSleepApp/AI/Services/GeminiAPIService.swift`
  - `DeepSleepApp/AI/Services/NaverAPIService.swift`
  - `DeepSleepApp/AI/Services/OpenRouterFallbackManager.swift`
  - `DeepSleepApp/AI/Services/FreeAIModels.swift`
- 프록시 연동(삭제)
  - `DeepSleepApp/Subscription/ProxyTierReporter.swift`
  - `DeepSleepApp/Security/ProxyAuthSigner.swift`
  - `DeepSleepApp/Security/ProxySecretStore.swift`
  - `DeepSleepApp/Security/ProxyAuthConfig.swift`
- API 건강검진/키 관리(삭제)
  - `DeepSleepApp/APIConnectionValidator.swift`
  - `DeepSleepApp/APIHealthChecker.swift`
  - `DeepSleepApp/APIKeyManager.swift`
  - `DeepSleepApp/ZeroTokenAPIChecker.swift`

### 5) 빌드 설정 정리(.xcodeproj)
- 수정: `DeepSleep.xcodeproj/project.pbxproj`
  - 상기 삭제된 파일들의 `PBXBuildFile` 및 `PBXFileReference` 항목 제거
  - 일부 그룹(children) 잔여 레퍼런스는 objects 제거로 빌드 영향 없음(원하시면 그룹 정리까지 추가 수행 가능)

---

## 동작 영향 및 유의사항
- 모든 AI 호출은 온디바이스 경로로만 수행됩니다.
- 원격 프리사인/Cloudflare R2/CDN 다운로드 경로 제거로, 모델 다운로드는 앱 내 RemoteAssetClient의 presign/cdn 주입이 더 이상 이뤄지지 않습니다.
  - 설치된 모델이 없을 경우 `OnDeviceAdapter.ensureInstalled` 호출에서 원격 URL 해석이 실패할 수 있습니다.
  - 운영 정책상 "자동 다운로드 금지"가 의도된 경우, 이는 일관된 동작입니다. (설정 화면에서 명시적으로 유도)
- 기존 프록시 관련 사용자 메시지(일부 UI 로그/오류 문구) 잔여가 있을 수 있으나 실행 경로/기능에는 영향이 없습니다. 필요 시 텍스트만 후속 정리 가능.

---

## 다운로드 경로 구성 (presign-only)
- Info.plist(xcconfig)에서 `ONDEVICE_PRESIGN_ENDPOINT`를 설정합니다. 예: `https://<workers-domain>/presign`
- presign 계약: `GET /presign?file=<파일명.gguf>` → 200 JSON `{"url":"https://cdn.emozleep.space/models/<파일명>.gguf"}`
- 앱은 presign 실패 시 폴백하지 않으며, CDN 베이스(ONDEVICE_CDN_BASE)는 사용하지 않습니다.

## CDN 링크 검증 결과
- Base: `https://cdn.emozleep.space/models`
- 확인한 파일 (HTTP/2 200 OK, Content-Length 일치):
  - amoral-gemma3-1B-v2-Q5_K_M.gguf (851,345,760 bytes)
  - cherrydavid_hyperclovax-seed-text-instruct-0.5b-q8_0.gguf (726,205,280 bytes)
  - kexplo_hyperclovax-seed-text-instruct-0.5b-q4_k_m.gguf (431,883,104 bytes)
  - yeebwn_hyperclovax-seed-text-instruct-1.5b-q4_k_m.gguf (1,006,572,320 bytes)

## 확인(검증) 방법
- 빌드/스모크:
  - 예시: `xcodebuild -scheme DeepSleep -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build`
  - 또는 스크립트: `bash scripts/dev_build_test_smoke.sh` (프로젝트 스크립트 정책에 따름)
- 런치 후 확인 포인트:
  - 모델 선택 화면: 온디바이스/애플 카드만 보임
  - 온디바이스 모델이 설치되어 있으면 즉시 활성화되어 채팅 가능
  - 채팅/감정 분석/프리셋 추천 등 모든 AI 기능이 네트워크 없이 동작(설치 모델 전제)

---

## 추가 정리(요청 반영)
- 스크립트/서버 스냅샷 정리 완료
  - 삭제: `scripts/emozleep-presign-worker/*`, `scripts/deploy_models_r2.sh`
- Info.plist 정리 완료
  - 삭제: `USE_PROXY`, `PROXY_BASE_URL`, `PROXY_AUTH_USE_NONCE`, `CLIENT_PROXY_HMAC_SECRET`, `OPENROUTER_API_KEY`, `OPEN_AI_4oMINI_API_KEY`, `GEMINI_API_KEY`, `CLAUDE_API_KEY`, `NAVER_CLOUD_API_KEY`, `NAVER_CLOUD_API_SECRET`

## 후속 권장 작업(옵션)
- 문서/스크립트 정리
  - 가이드 문서 내 프록시/클라우드 언급 축소 또는 별도 폴더로 이동
- 그룹(children) 청소
  - `project.pbxproj`에서 그룹 children의 잔여 표시까지 깨끗이 제거 원하시면 추가 패치 가능

---

## 설계 원칙 반영 체크리스트
- KISS: 온디바이스 단일 경로로 복잡도 최소화
- DRY: 시스템 프롬프트/컨텍스트 조립은 기존 중앙집중 로직 유지(AIContextBuilder/AIContextManager)
- YAGNI: 클라우드 폴백/프록시/키검증 등 미사용 기능 제거
- SOLID: 단일 책임 분리(온디바이스 어댑터/다운로더/세션/토큰 최적화 등 기존 구조 유지)
- 단일 진입점: `SessionManager` → `UnifiedAIServiceImpl` → 온디바이스 어댑터 구조 일원화

---

## 변경 파일(수정)
- `DeepSleepApp/AI/Services/UnifiedAIServiceImpl.swift`
- `DeepSleepApp/AppDelegate.swift`
- `DeepSleepApp/SettingsManager.swift`
- `DeepSleepApp/SessionManager.swift`
- `DeepSleep.xcodeproj/project.pbxproj`

## 변경 파일(삭제)
- `DeepSleepApp/AI/Services/ClaudeAPIService.swift`
- `DeepSleepApp/AI/Services/OpenAIAPIService.swift`
- `DeepSleepApp/AI/Services/GeminiAPIService.swift`
- `DeepSleepApp/AI/Services/NaverAPIService.swift`
- `DeepSleepApp/AI/Services/OpenRouterFallbackManager.swift`
- `DeepSleepApp/AI/Services/FreeAIModels.swift`
- `DeepSleepApp/Subscription/ProxyTierReporter.swift`
- `DeepSleepApp/Security/ProxyAuthSigner.swift`
- `DeepSleepApp/Security/ProxySecretStore.swift`
- `DeepSleepApp/Security/ProxyAuthConfig.swift`
- `DeepSleepApp/APIConnectionValidator.swift`
- `DeepSleepApp/APIHealthChecker.swift`
- `DeepSleepApp/APIKeyManager.swift`
- `DeepSleepApp/ZeroTokenAPIChecker.swift`

---

## 메모
- 온디바이스 모델 파일이 미설치인 경우, 자동 다운로드는 시도하지 않습니다(의도). 설치 유도 UX는 AIModelSelectionViewController 내에서만 동작합니다.
- 설정 누락 시(ONDEVICE_PRESIGN_ENDPOINT 비어 있음), 친구 선택 시 presign 필요 얼럿을 표시하고 다운로드를 시작하지 않습니다.
- RemoteAssetClient는 presign-only로 동작합니다.
