# 온디바이스 LLM 배포·런타임 통합 가이드 (서버 다운로드 전용 · 4모델 SSOT · llama.cpp)

본 문서는 DeepSleep 앱의 온디바이스 LLM을 “서버 다운로드 전용(Background Assets 미사용)” 방식으로 배포·검증·로딩하는 전 과정을 정의합니다. 모든 모델 메타는 SSOT(ModelCatalog) 기준으로 유지하며, 과거 270M/IQ4_XS/Qwen2.5 관련 내용은 전면 폐기했습니다.

핵심 원칙
- SSOT: 모델 메타(파일명·SHA256·표시명·권장 파라미터)는 ModelCatalog 단일 출처로만 관리
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
- ID: qwen05b_q4km
  - 파일: kexplo_hyperclovax-seed-text-instruct-0.5b-q4_k_m.gguf
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
- presigned URL(우선) → CDN(폴백) 순서로 GET
- 다운로드 완료 후 SHA256 검증(불일치 시 즉시 폐기 및 재시도)
- 저장 경로(앱 샌드박스 내): Application Support/OnDeviceModels/<modelID>/<fileName>
  - 디렉터리는 모델 ID 기준으로 분리
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

- [ ] 4개 모델 CDN 200 응답 및 파일 크기/해시 검증 완료
- [ ] Presign → CDN 폴백 정상 동작(네트워크 장애 시나리오 포함)
- [ ] 설치·진행률·활성화 UI 일관(별명 노출)
- [ ] 재시작 후 선호 모델 자동 활성화
- [ ] 폴백 순서(작은 클로버 → 클로버 → 잼민이 → 작은 잼민이) 정상
- [ ] 카탈로그 외 모델 파일 자동 정리
- [ ] 문서·코드 모두 270M/IQ4_XS/Qwen2.5 언급 제거(레거시 청산)

끝.