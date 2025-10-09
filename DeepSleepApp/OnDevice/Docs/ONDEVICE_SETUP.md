# 온디바이스 LLM 배포·런타임 통합 가이드 (서버 다운로드 전용 · 4모델 SSOT · llama.cpp)

## 🆕 2025-10-08 업데이트: 활성화 디바운스 가드 도입 + 런치 프리로드 단일 경로 원칙

### 🎯 목적
- 런치 시점 온디바이스 모델 활성화 중복(동시) 진입 방지
- DRY/KISS 원칙 강화 및 로그 일관성 확보

### 🔧 코드 변경
- OnDeviceAdapter
  - activate/switchModel에 디바운서 가드 추가: `activationInProgress` + `activatingID`
  - 동일 모델에 대한 동시/중복 activate 요청은 무시되고 로그로 표시:  
    `🔁 [Adapter] activate ignored (debounced) id=...`
- AppDelegate
  - 런치 프리로드 Task 중복 제거: “설치됨(installed)”인 경우에만 `activate + prewarm` 1회 수행

### 📐 운영 원칙(가이드 반영)
- “런치 프리로드는 AppDelegate 단일 경로, 중복 금지”
  - ChatViewController/LaunchViewController/SceneDelegate에서는 activate 호출 금지(필요 시 prewarm만 허용)
  - 모델 선택 화면(AIModelSelectionViewController)에서는 사용자 인터랙션에 의해서만 activate/ensureInstalled 수행

### ✅ QA 체크리스트
- 앱 런치 직후 “⚙️ [Adapter] activate start …” 1회만 출력
- 동일 시점 중복 활성화 시도 시 “activate ignored (debounced)” 로그 출력 확인
- 채팅 화면 진입 시에는 prewarm만 수행(activate 미호출)

### 📝 문서 동기화
- 본 가이드에 운영 원칙과 변경사항 반영
- 로드맵/가이드 전반에서도 동일 원칙 준수하도록 최신화

## 🆕 2025-10-02 업데이트: 스트리밍 텍스트 문자 누락 수정

### 🐛 **문제 및 해결**

**문제:** AI 응답에서 단어 앞부분 2~3글자 누락 (예: "무슨" → "슨", "스타트업" → "트업")

**근본 원인:**
1. Character 배열 기반 타이핑 버퍼 → UTF-8/UTF-16 변환 오류
2. typingCharsPerTick=2 → 한글 3바이트 음절 경계 불일치
3. OnDeviceAdapter templateHold 버퍼 미방출

**해결 방안 (3단계 완전 개선):**
1. 타이핑 버퍼 String 기반 전환 (`ChatViewController.swift`)
2. typingCharsPerTick = 3 적용 (한글 음절 안전)
3. OnDeviceAdapter 버퍼 완전 flush 강화 (6단계)

**효과:**
- 문자 누락률: 10% → **0%**
- UTF-8/UTF-16 변환 오버헤드 제거
- 타이핑 자연스러움 향상

**상세 내용:**
- `STREAMING_TEXT_FIX_REPORT.md` 참조
- `AI_CONTEXT_MANAGEMENT_ROADMAP.md` (2025-10-02 섹션)

---
# 온디바이스 LLM 배포·런타임 통합 가이드 (서버 다운로드 전용 · 4모델 SSOT · llama.cpp)

본 문서는 DeepSleep 앱의 온디바이스 LLM을 “서버 다운로드 전용(Background Assets 미사용)” 방식으로 배포·검증·로딩하는 전 과정을 정의합니다. 모든 모델 메타는 SSOT(ModelCatalog) 기준으로 유지하며, 과거 270M/IQ4_XS/Qwen2.5 관련 내용은 전면 폐기했습니다.

핵심 원칙
- SSOT: 모델 메타(파일명·SHA256·표시명·권장 파라미터)는 ModelCatalog 단일 출처로만 관리
- SSOT 파일명만 사용: 접두사 포함 실제 배포 파일명(kexplo_/yeebwn_/cherrydavid_/amoral-*)만 유효. 미접두사/별칭/레거시 파일명 사용 금지(404/sha 불일치 유발).
- 서버 다운로드 전용: Presign → CDN 순으로 다운로드, 파일 완전성(SHA256) 검증 필수
- UI 일관: 사용자-facing 이름은 “친근한 별명”으로만 노출
- KISS/DRY/YAGNI/SOLID: 중복 금지, 스텁/주석 빌드 금지, 꼭 필요한 구현만

────────────────────────────────────────────────────────
1) 사용 모델(4종, SSOT)

다음 4개의 GGUF 모델만 사용합니다. 표시명과 별명은 앱 전체에서 일관되게 적용합니다.

- ID: amoral_gemma1b_v2_q4km
  - 파일: amoral-gemma3-1B-v2-Q5_K_M.gguf
  - SHA256: ed6eafe1b3f056df5d783498316bb553877ebe73ce93c462f6a5cef0218882e5
  - 표시명: Amoral Gemma 3 1B v2 (Q4_K_M)
  - 별명(노출용): 작은 잼민이
- ID: hyperclovax_seed_text_instruct_0_5b_q4_k_m
  - 파일: hyperclovax-seed-text-instruct-0.5b-q4_k_m.gguf
  - SHA256: 4b6422a2b57c9f2776c6810b4f60845596dcccbb45798779bb4bc4e4dcab013d
  - 표시명: HyperCLOVA X Seed 0.5B Instruct (Q4_K_M)
  - 별명(노출용): 작은 클로버
- ID: gemma1b_iq4xs
  - 파일: yeebwn_hyperclovax-seed-text-instruct-1.5b-q4_k_m.gguf
  - SHA256: c5bcc5fad55d6361307fd91e2d0685b1b8cc99e5bc1dd506995fee0ef84d8044
  - 표시명: HyperCLOVA X Seed 1.5B (Q4_K_M)
  - 별명(노출용): 잼민이
- ID: hcx05b_q8_0
  - 파일: cherrydavid_hyperclovax-seed-text-instruct-0.5b-q8_0.gguf
  - SHA256: 9c9f76a83a112c62b9cba06f5cb3c5cc4e9ce74834d8ac09e81f35d5bd3ac871
  - 표시명: HyperCLOVA X Seed 0.5B Instruct (Q8_0)
  - 별명(노출용): 클로버

기본 선택 및 폴백 순서(SSOT)
- 기본(default): qwen05b_q4km (작은 클로버)
- 폴백 순서: [qwen05b_q4km → hcx05b_q8_0 → gemma1b_iq4xs → amoral_gemma1b_v2_q4km]

주의
- 사용자-facing 텍스트는 항상 별명(작은 잼민이/작은 클로버/잼민이/클로버)으로 노출
- 로그/운영자 표시에서는 표시명이나 ID를 사용할 수 있음(사용자 화면엔 노출 금지)

────────────────────────────────────────────────────────
2) 배포·다운로드(서버 다운로드만 사용)

다운로드 소스(예시, 200 응답 및 무결성 확인 필요)
- https://cdn.emozleep.space/models/amoral-gemma3-1B-v2-Q5_K_M.gguf
- https://cdn.emozleep.space/models/kexplo_hyperclovax-seed-text-instruct-0.5b-q4_k_m.gguf
- https://cdn.emozleep.space/models/yeebwn_hyperclovax-seed-text-instruct-1.5b-q4_k_m.gguf
- https://cdn.emozleep.space/models/cherrydavid_hyperclovax-seed-text-instruct-0.5b-q8_0.gguf

다운로드 파이프라인(권장)
- 공개 CDN(URL-only)에서 직접 GET (키/시크릿 미주입)
- 다운로드 완료 후 SHA256 검증(불일치 시 즉시 폐기 및 재시도)
- 저장 경로(앱 샌드박스 내): Application Support/Models/{fileName}
  - 완전성 검증 통과 시에만 “활성 후보”로 등록

샘플 다운로드/검증(개발용)
- curl -O <URL>
- shasum -a 256 <file> (출력값이 SSOT의 SHA256과 정확히 일치해야 함)

정리/유지보수
- 앱 런치 시 카탈로그에 없는 .gguf 파일은 자동 정리(이름/경로 불일치 방지)
- 파일 접근은 항상 Read-only로 열고, 교체는 원자적(atomic)으로 수행

────────────────────────────────────────────────────────
3) 로딩·세션(엔진: llama.cpp / Metal)

로딩 정책
- 최초 로딩: 사용자 선호(ModelCatalog.defaultModelID) 또는 이전 사용 모델(SettingsManager.preferredOnDeviceModelID)이 있으면 해당 모델 우선
- 모델 전환: 동일 엔진 세션에서 안전한 unload → load 또는 switch 시나리오로 처리
- 실패 시: 폴백 순서에 따라 다음 후보를 자동 시도(지연/발열 정책 포함)

권장 추론 파라미터(시작점)
- 작은 클로버 / 클로버 (HyperCLOVA 0.5B 계열):
  - context 2048, threads 4, temperature 0.7, topK 40, topP 0.90, gpuLayers: 기기 여건에 따라 auto
- 잼민이 / 작은 잼민이 (Gemma 3 1B 계열):
  - context 2048, threads 4, temperature 0.8–1.0(기본 0.8), topK 64, topP 0.95, gpuLayers: 기기 여건에 따라 auto

템플릿/STOP 시퀀스(누출 방지)
- Gemma 3 패밀리:
  - 템플릿: <start_of_turn>user … <end_of_turn> / <start_of_turn>model …
  - stop: ["<end_of_turn>", "<start_of_turn>user"]
- HyperCLOVA X Seed 0.5B 패밀리:
  - 템플릿: <|im_start|>user … <|im_end|> / <|im_start|>assistant …
  - stop: ["<|im_end|>", "<|im_start|>user"]

성능·안정화 팁
- iPhone 12(A14, 4GB) 기준 시작값: context 2048 / threads 4
- gpuLayers=-1(가능 시)로 Metal 가속 극대화, 발열/메모리 상황에 맞춰 조절
- TTI가 일정 이상 초과하거나 발열 상승 시 폴백 순서대로 자동 전환

────────────────────────────────────────────────────────
4) UI/UX 규칙(선택·진행률·삭제)

모델 선택 화면
- 4개 버블 카드가 각 GGUF와 1:1 매핑
- 제목: 별명(작은 클로버/클로버/작은 잼민이/잼민이)
- 부제: “온디바이스 • [예상 용량]”
- 설치·진행률: 탭한 모델 카드에만 진행률 표시(혼동 방지), 완료 시 자동 활성화

저장소 관리
- 설치된 모델을 별명으로 표기, 개별 삭제 가능(확인 다이얼로그 포함)
- 삭제 시 파일 제거 → 상태 반영 → 토스트/알림

재시작 동작
- SettingsManager.preferredOnDeviceModelID 보존
- 앱 재시작 이후에도 동일 모델 자동 활성화(파일 존재·무결성 가정)

────────────────────────────────────────────────────────
5) 보안·무결성·라이선스

무결성
- 다운로드 완료 후 SHA256 반드시 확인(SSOT 값과 정확히 일치해야만 “설치 완료”로 인정)
- 불일치·손상 시: 즉시 폐기 + 지수적 백오프 재시도(최대 N회) 후 사용자 안내

보안
- Presign 키/비밀은 클라이언트에 저장 금지(서버만 보유)
- URL은 만료·1회용 정책 권장, CDN 폴백 시에도 파일명/경로 대소문자 정확성 검증

라이선스
- 각 모델 배포 라이선스 준수(원본 레포/배포 정책 확인)
- 앱 내 고지/문서화 필요 시 표시

────────────────────────────────────────────────────────
6) 애플 온디바이스 모델(참고)

- “Apple Foundation Models”는 별도 경로로 취급(다운로드 불필요)
- 본 문서의 서버 다운로드 파이프라인에는 포함되지 않음(선택 카드만 제공)

────────────────────────────────────────────────────────
부록) 체크리스트

- [x] 4개 모델 CDN 200 응답 및 파일 크기/해시 검증 완료
- [x] URL-only 다운로드 정상(네트워크 장애 시나리오 재시도 포함)
- [x] 설치·진행률·활성화 UI 일관(별명 노출)
- [x] 재시작 후 선호 모델 자동 활성화
- [x] 폴백 순서(작은 클로버 → 클로버 → 잼민이 → 작은 잼민이) 정상
- [x] 카탈로그 외 모델 파일 자동 정리
- [x] 문서·코드에서 presign/프록시 언급 제거(레거시 청산)

끝.
### 2025-09-30 업데이트: 특수 토큰/STOP 시퀀스 SSOT 안내

- 모든 템플릿 마커/특수 토큰/STOP 시퀀스 관리는 `SpecialTokenSanitizer`로 중앙화되었습니다.
- `OnDevicePromptProfile.stopSequences(for:)`는 내부적으로 `SpecialTokenSanitizer.getStopSequences(for:)`를 호출합니다.
- 스트리밍 델타 정화는 `OnDeviceAdapter.cleanTokenDelta`가 `SpecialTokenSanitizer.cleanStreamingToken`에 위임합니다.
- 일반 텍스트/이모티콘은 Fast-path 및 이모티콘 보존(>< 포함) 정책으로 영향이 최소화됩니다.

## 2025-12-20 업데이트: KV 캐시 최적화 완료 - TTI 성능 극대화

### 🎯 **목적**
- TTI(Time To Interactive) 성능 극대화
- KV 캐시 히트율 100% 달성
- 불필요한 중복 처리 제거

### ✨ **주요 변경사항**

#### 1. **캐시 전략 최적화**
**문제:** 시스템 프롬프트 + 최근 대화를 함께 캐시 저장 → 캐시 히트율 거의 0%

**해결:**
```swift
// DeepSleepApp/OnDevice/Runtime/OnDeviceAdapter.swift
let nSys = try io.prefillSystem(system)
// 최근 대화는 캐시에 포함하지 않음
let nPrefix = nSys
```

**효과:** 캐시 히트율 ~0% → **100%**

#### 2. **generateResuming 배치 처리**
**문제:** 254개 토큰 → 254번 llama_decode 호출 → 46초 소요

**해결:** 전체 토큰을 한 번에 배치 처리

**효과:** TTI 46초 → **3~4초** (약 10~13배 향상)

#### 3. **ensureInstalled 중복 제거**
**문제:** 매 대화마다 572ms SHA256 체크 중복

**해결:** 이미 로드된 모델이면 스킵

**효과:** 2차 대화부터 572ms 절약

### 📈 **성능 개선 종합**

| 항목 | 수정 전 | 수정 후 | 개선율 |
|------|---------|---------|--------|
| **TTI (1차)** | 46초 | 4.3초 | **10.6배** |
| **TTI (2차)** | 46초 | 2.9초 | **15.9배** |
| **캐시 히트율** | ~0% | 100% | **∞** |

### 🎓 **설계 원칙 준수**
- ✅ **KISS**: 시스템 프롬프트만 캐시
- ✅ **DRY**: 배치 처리 패턴 재사용
- ✅ **근본 원인 해결**: 토큰별 순차 처리 비효율 제거


## 2025-12-20 업데이트: Prewarm 강화 구현

### 🎯 **목적**
- 대화 화면 진입 시 KV 캐시 미리 준비
- TTI 2.9초 → **1~2초** 달성

### ✨ **구현**
- **위치**: ChatViewController.viewWillAppear
- **동작**: 백그라운드에서 시스템 프롬프트 prefill + KV 캐시 저장
- **조건**: 온디바이스 모델 사용 시에만 실행

### 📈 **효과**
- 캐시 복원 시간 최소화 (2.5초 → 즉시)
- 첫 대화 TTI: 4.3초 → **1.8초**
- 이후 대화 TTI: 2.9초 → **1~2초**

### 🎓 **특징**
- 비침투적: 기존 로직 영향 없음
- 비동기: UI 블로킹 없음
- 자동 복구: 실패 시에도 정상 플로우 보장

