# 온디바이스 LLM 배포·런타임 통합 가이드 (iOS · Background Assets · llama.cpp)

본 문서는 iOS 앱(DeepSleep)에 온디바이스 LLM 3종(GGUF)을 Background Assets(BA, Apple-hosted asset packs)로 동적 배포하고, 공통 엔진(laama.cpp·Metal)에서 핫스왑 전환까지 구현하는 엔드투엔드 실무 가이드입니다. 문서의 모든 지침은 KISS/DRY/YAGNI/SOLID 원칙을 따르며, “비슷한 로직을 다른 이름으로 중복”하는 것을 금지합니다.

목표와 성공 기준
- 목표: iOS 앱에 GGUF 모델 3종을 BA로 배포, llama.cpp(메탈) 공통 엔진에서 재시작 없이 전환 가능.
- 코스트/UX: 클라우드 과금 절감, 프라이버시 강화, 오프라인 대응. TTI 2~4초(기본 모델).
- 성공 기준:
  1) iPhone 12(4GB, A14) 실기에서 기본 모델(≈300MB) TTI 2~4초
  2) 설정 화면에서 0.5B(한국어↑) / 1B(품질↑) 다운로드→설치→핫스왑
  3) 시스템 프롬프트의 공감/존댓말 톤 안정 적용
  4) 런타임 OOM/실패 시 안전 폴백(270M 또는 클라우드)

핵심 산출물(프로젝트 내 반영됨)
- 런타임/카탈로그/BA 추상화(단일 출처, DRY 유지)
  - DeepSleepApp/OnDevice/Runtime/ModelCatalog.swift
  - DeepSleepApp/OnDevice/Runtime/ModelLoader.swift
  - DeepSleepApp/OnDevice/BackgroundAssets/BackgroundAssetClient.swift
- 문서(본 파일)
  - DeepSleepApp/OnDevice/Docs/ONDEVICE_SETUP.md

주의: 실제 BA API 연동 및 llama.cpp 바인딩 연결 지점은 // MLtodo 로 표기되어 있습니다. 필수 권한·시크릿 없이 위험한 하드코딩/임시 주석·스텁으로 “빌드만 성공”하는 행위를 금지합니다.

────────────────────────────────────────────────────────

1. 범위(모델·포맷·엔진)

모델(정확 파일)
- 기본(자동 설치): unsloth/gemma-3-270m-it-GGUF → gemma-3-270m-it-Q8_0.gguf (~292 MB)
- 절약 대안: gemma-3-270m-it-Q4_K_M.gguf (~253 MB) [선택: 카탈로그 보조]
- 선택① 한국어↑: Qwen/Qwen2.5-0.5B-Instruct-GGUF → qwen2.5-0.5b-instruct-q4_k_m.gguf (~491 MB)
- 선택② 품질↑: bartowski/google_gemma-3-1b-it-GGUF → gemma-3-1b-it-IQ4_XS.gguf (~714 MB)

공통 포맷/엔진
- 포맷: GGUF (3종 공통)
- 엔진: llama.cpp(메탈) iOS XCFramework + Swift 바인딩(또는 C API 직접 래핑)
- 채팅 템플릿/토크나이저: GGUF 메타 자동 사용(수동 포맷팅 금지)

────────────────────────────────────────────────────────

2. 아키텍처(요약)

배포/저장소
- Background Assets(옵션1, Apple-hosted): 앱 외부 대용량 모델 다운로드·보관
- ODR(옵션2, 백업): 코드에 스텁만 존재(기본 비활성)

앱 레이어(주요 컴포넌트)
- BackgroundAssetClient: BA 요청/상태/경로 획득 추상화
  - 구현: SystemBackgroundAssetClient(폴리필 포함), NoopBackgroundAssetClient
- ModelCatalog: 모델 메타(파일명, Sha256, 예상 크기, 권장 파라미터) 단일 출처
- LlamaModelLoader: llama.cpp 초기화/해제/세션 교체
- UnifiedAIService 접점: 온디바이스 경로 추가(추후 단계)
- FallbackPolicy: 에러/발열/지연 시 자동 전환 정책
- Settings UI: 모델 선택/다운로드/상태 표시/전환

핫스왑 UX(설정 → 모델)
1) BA 설치 여부 확인 → 미설치면 다운로드 예약/진행 표시
2) 설치 완료되면 ModelLoader.switch(...) 호출 → 세션 재생성
3) 실패/OOM 시 기본(270M) 또는 클라우드로 즉시 폴백

────────────────────────────────────────────────────────

3. 개발 환경 준비(Setup)

요구사항
- Xcode 15.4+ (권장 최신), Swift 5.9+, iOS 18 SDK 권장
- iPhone 12(iOS 18+ 실기 성능검증), 테스트용 케이블/프로비저닝
- 개발기(Homebrew 등) + huggingface-cli (모델 다운로드/해시)

엔진(laama.cpp) 통합 전략(2안 중 택1)
A) 사전 빌드된 XCFramework를 SPM binaryTarget로 추가
- 장점: 앱 빌드 간소화, 안전한 배포
- 단점: 아키텍처/옵션 변경 시 재빌드 필요

B) 소스 통합 + CMake로 iOS/Metal 타깃 빌드
- 장점: 옵션 튜닝 유연
- 단점: 빌드 복잡성↑, 유지보수 부담

Metal 백엔드 플래그(참고)
- LLAMA_METAL=1
- n_gpu_layers: 최대치(가능하면 전 레이어) 권장, 단 단말 리소스 한계 고려
- iPhone 12: 270M은 “max”, 0.5B/1B는 실측으로 적정치 산정

샘플 빌드 지침(참고; 실제 리포/스크립트에 맞춰 조정)
```
# iOS+Metal용 빌드(예시)
git clone https://github.com/ggerganov/llama.cpp.git
cd llama.cpp
# iOS toolchain/SDK path 환경 설정 필요
cmake -B build-ios -DLLAMA_METAL=ON -DLLAMA_ACCELERATE=ON -DCMAKE_SYSTEM_NAME=iOS -DCMAKE_OSX_ARCHITECTURES="arm64" .
cmake --build build-ios --config Release
# 산출물 → XCFramework 래핑 후 SPM binaryTarget로 연결
```

────────────────────────────────────────────────────────

4. 모델 획득(개발기) 및 무결성 기록

다운로드(개발기 로컬 캐시)
```
# 준비: pipx/venv 등으로 huggingface-cli 설치
huggingface-cli login  # 토큰 필요 시

mkdir -p ./models
huggingface-cli download unsloth/gemma-3-270m-it-GGUF gemma-3-270m-it-Q8_0.gguf -d ./models --local-dir-use-symlinks False
huggingface-cli download Qwen/Qwen2.5-0.5B-Instruct-GGUF qwen2.5-0.5b-instruct-q4_k_m.gguf -d ./models --local-dir-use-symlinks False
huggingface-cli download bartowski/google_gemma-3-1b-it-GGUF gemma-3-1b-it-IQ4_XS.gguf -d ./models --local-dir-use-symlinks False

shasum -a 256 ./models/*.gguf > ./models/sha256sum.txt
```

manifest.json(예시; 앱/서버 관리)
```
{
  "models": [
    {
      "id": "gemma270_q8",
      "file": "gemma-3-270m-it-Q8_0.gguf",
      "sizeBytes": 306315264,
      "sha256": "YOUR_SHA256_HEX",
      "packID": "pack.model.gemma270.q8",
      "params": { "context": 2048, "threads": 4, "temperature": 1.0, "topK": 64, "topP": 0.95 }
    },
    {
      "id": "qwen05b_q4km",
      "file": "qwen2.5-0.5b-instruct-q4_k_m.gguf",
      "sizeBytes": 514850816,
      "sha256": "YOUR_SHA256_HEX",
      "packID": "pack.model.qwen05b.q4",
      "params": { "context": 2048, "threads": 4, "temperature": 0.85, "topK": 64, "topP": 0.95 }
    },
    {
      "id": "gemma1b_iq4xs",
      "file": "gemma-3-1b-it-IQ4_XS.gguf",
      "sizeBytes": 748281856,
      "sha256": "YOUR_SHA256_HEX",
      "packID": "pack.model.gemma1b.iq4",
      "params": { "context": 2048, "threads": 4, "temperature": 0.8, "topK": 64, "topP": 0.95 }
    }
  ]
}
```

무결성 전략(권장)
- 앱은 설치된 파일에 대해 sha256 검증(선택). 미일치 시 재시도 또는 팩 재설치.
- 본 프로젝트에서는 CatalogResolver가 sha256이 제공된 경우에만 검증합니다.

────────────────────────────────────────────────────────

5. Background Assets 구성(옵션1, 권장)

App Store Connect
- Apple-hosted Background Assets 활성화 후 asset packs 생성(3개)
  - pack.model.gemma270.q8 → gemma-3-270m-it-Q8_0.gguf
  - pack.model.qwen05b.q4 → qwen2.5-0.5b-instruct-q4_k_m.gguf
  - pack.model.gemma1b.iq4 → gemma-3-1b-it-IQ4_XS.gguf
- 앱 버전과 연결, 심사 가이드에 모델 라이선스 표기 포함

Xcode 프로젝트
- Background Assets Capability 추가
- Apple-hosted 옵션 켜기
- Entitlements 확인(네트워크 권한, 백그라운드 다운로드 관련 사항)

앱 최초 실행 플로우(권장)
- 기본 팩(gemma270 Q8) 다운로드 예약(와이파이 필요 정책 반영)
- 선택팩(Qwen 0.5B / Gemma 1B)은 설정 화면에서 “설치” 시 예약

코드(본 프로젝트 생성된 핵심 파일)
- BackgroundAssetClient 추상화
  - iOS18+용 SystemBackgroundAssetClient(현재 폴리필 방식; 실제 BA API 연동 지점 // MLtodo)
  - NoopBackgroundAssetClient(iOS17- 또는 미지원 환경)
- 사용 예(요지)
  - BackgroundAssetClientFactory.make()로 환경별 클라이언트 획득
  - CatalogResolver.resolveLocalURL(for:)로 설치 보장+무결성 검증(선택) 후 URL 반환

────────────────────────────────────────────────────────

6. 런타임 로딩/전환(핫스왑) — llama.cpp

권장 파라미터(아이폰12 시작점)
- 공통: context=2048, threads=4, ngl=max(가능하면 모든 레이어 메탈), emb-hbm=auto
- 샘플링:
  - 270M: temp=1.0, top_k=64, top_p=0.95
  - 0.5B/1B: temp=0.7~0.9, top_k=64, top_p=0.95

시스템 프롬프트(상수, 한국어 공감/존댓말 톤)
```
당신은 한국어로 다정하고 담백하게 공감하는 대화 파트너입니다.
판단·충고보다 공감 먼저, 존댓말, 과장 없음. 1~3문단.
마지막에 “제가 제대로 이해했나요?”로 확인 질문 1개.
```

엔진/로더(핵심 스텁)
- LlamaModelLoader: 로드(load), 생성(generate), 전환(switchModel), 해제(unload)
- LlamaCppBinding: 실제 llama.cpp 바인딩 인터페이스(조건부 컴파일로 분리)
- GGUF 메타의 chat-template 자동 사용(수동 포맷팅 금지)

샘플 사용(요지)
```swift
let ba = BackgroundAssetClientFactory.make()
let resolver = CatalogResolver(baClient: ba)
let loader: OnDeviceModelLoader = LlamaModelLoader()

let rec = ModelCatalog.record(for: .gemma270_q8)
let modelURL = try await resolver.resolveLocalURL(for: .gemma270_q8) { p in
  print("BA progress:", Int(p*100), "%")
}
try loader.load(modelURL: modelURL, modelID: .gemma270_q8, params: rec.recommended)

var out = ""
try await loader.generate(input: "오늘 너무 힘들었어.", systemPrompt: SystemPrompts.empathyKR, params: rec.recommended) { delta in
  out += delta
}
print("RESP=", out)
```

핫스왑
```swift
let nextRec = ModelCatalog.record(for: .qwen05b_q4km)
let nextURL = try await resolver.resolveLocalURL(for: .qwen05b_q4km)
try await loader.switchModel(to: .qwen05b_q4km, modelURL: nextURL, params: nextRec.recommended)
```

────────────────────────────────────────────────────────

7. UnifiedAIService 접합(계획)

현 상태
- 기존 UnifiedAIService는 AIModel에 on-device가 아직 없습니다(AIModelType.onDevice는 있음).
- 현재 on-device 선택 시 freeModel로 매핑되는 실험상태(임시).

계획(권장 절차 — DRY/단일 출처 유지)
- AIModel에 case onDevice 추가(표시명/가격/정책 메타 포함)
- UnifiedAIServiceImpl에 온디바이스 분기 추가:
  - 모델 선택 시 onDevice → OnDeviceAdapter 호출
  - OnDeviceAdapter가 LlamaModelLoader를 사용해 스트리밍/단발 생성 제공
  - 실패/지연/OOM 시 FallbackPolicy로 270M→0.5B→1B→클라우드 순 시도
- 시스템 프롬프트는 기존 makeSystemPrompt 재사용(단일 출처 유지)

주의
- 동일한 전처리/후처리/로깅 경로를 공유하여 “비슷한 로직 중복”을 금지
- 토큰 설정 최적화(optimizeTokenConfigForModel) 재사용

────────────────────────────────────────────────────────

8. FallbackPolicy(권장 정책)

정책 요약
- 1B: 2회 연속 TTI > 4s 또는 Thermal state 상승 → 0.5B로 다운스케일
- 0.5B: 동일 조건 → 270M으로 다운스케일
- 270M: 동일 조건 지속 → 클라우드(서버 프록시)로 폴백(옵션)
- OOM/엔진 실패: 즉시 한 단계 다운스케일

의사코드
```swift
func decideNext(current: OnDeviceModelID, ttiMs: Int, thermal: Bool, oom: Bool) -> Next {
  if oom { return .downscaleOrCloud }
  if ttiMs > 4000 || thermal { return .downscale }
  return .stay
}
```

────────────────────────────────────────────────────────

9. 텔레메트리/가드

수집 지표(개인정보 제외)
- TTI(ms), tok/s(대략치), OOM 발생여부, Thermal 변화, 전환 이벤트
- BA 설치 시간/실패 원인(sha256 불일치 등)

로그 원칙
- 민감 텍스트/사용자 메시지 원문을 로그에 남기지 않음
- 지표/상태/오류코드 중심

자동 전환
- 정책 위반 감지 시 즉시 다운스케일/폴백
- 전환 사유를 메타에 남겨 추후 분석

────────────────────────────────────────────────────────

10. 성능 튜닝 가이드(iPhone 12 기준)

빠른 TTI를 위해
- threads=4 권장(빅리틀 코어 균형)
- ngl: 가능한 한 최대 레이어를 Metal로(메모리/발열 한계 내)
- 짧은 입력/짧은 답변: 일반대화는 1~2단락(모드별 토큰 상한 준수)
- 시스템 프롬프트는 짧고 안정된 톤 프리셋 사용(본 문서의 공감 프롬프트)

메모리 안전
- 1B는 장시간 스트리밍 금지(짧은 턴)
- 백투백 롱턴 제한(쿨다운 삽입)
- 세션 교체 시 unload로 즉시 리소스 반환

────────────────────────────────────────────────────────

11. 테스트/검증(실기)

시나리오
- 프롬프트: “오늘 너무 힘들었어.” → 24초 내 25문장 공감 응답(예시 목표)
- 모델별(270M/0.5B/1B)로 각 5회 측정 → TTI/tok·s 평균/표준편차 기록
- 언어/톤 검증: 존댓말/공감어휘 포함 안정성(필요 시 temperature 조정)
- BA 무결성: sha256 미일치/중단/재시도 흐름 점검
- 폴백: BA 실패 시 클라우드 경로로 전환 로그 확인

안정성/회귀
- 장시간 사용(>20회 요청) 누수/발열/성능저하 모니터링
- 앱 포그라운드/백그라운드 전환 시 세션 상태

산출물(권장)
- docs/MODEL_CATALOG.md: 파일명/크기/sha/권장 파라미터
- scripts/fetch_models.sh: 개발기 캐시 스크립트
- QA/perf_report_iPhone12.md: 그래프 포함 성능 리포트

────────────────────────────────────────────────────────

12. 보안/라이선스/배포

앱 번들 포함 금지
- 모델 파일은 앱 번들에 포함하지 말 것(심사/패키지 크기/규정)
- 반드시 BA 다운로드(또는 테스트 경로 폴리필)만 사용

시크릿 분리
- Hugging Face 토큰/프록시 키는 .xcconfig/Keychain
- 저장소 커밋 금지(환경설정 문서화)

라이선스 고지(예시)
- Gemma: Google / License(참고 링크)
- Qwen2.5: Alibaba / License(참고 링크)
- bartowski(GGUF 변환 배포): 리포지토리 라이선스 표기
- llama.cpp: MIT
- Apple Background Assets 정책/가이드 준수

프라이버시
- 온디바이스 추론 기본 경로
- 로그에 민감 텍스트 저장 금지

────────────────────────────────────────────────────────

13. 실패 기준 & 폴백

자동 폴백 조건
- BA 설치 불가/sha 불일치/메모리 부족/지연>4s 반복 → 270M 또는 클라우드

FAILURE_REPORT.md(권장 템플릿)
```
# FAILURE REPORT
- 증상:
- 재현 스텝:
- 기기/OS:
- 로그(개인정보 제거):
- 성능지표 스냅샷:
- 추정 근본 원인:
- 제안 조치:
```

────────────────────────────────────────────────────────

14. 파일 구조(본 통합에서 추가된 핵심)

- DeepSleepApp/OnDevice/Runtime/ModelCatalog.swift
  - 모델 메타(팩ID/파일명/권장 파라미터/sha256) 단일 출처
  - SystemPrompts.empathyKR 포함
- DeepSleepApp/OnDevice/Runtime/ModelLoader.swift
  - LlamaModelLoader(엔진 로드/생성/전환/해제)
  - LlamaCppBinding(조건부 컴파일) + Noop 바인딩
- DeepSleepApp/OnDevice/BackgroundAssets/BackgroundAssetClient.swift
  - iOS18+용 SystemBackgroundAssetClient(현재 폴리필, 실제 BA 연동 // MLtodo)
  - NoopBackgroundAssetClient, Factory

참고: 실제 llama.cpp XCFramework/SPM 연결과 iOS Background Assets API 호출부는 이후 단계에서 안전하게 대체 구현합니다.

────────────────────────────────────────────────────────

15. 요청 목록(필수 권한/시크릿)

아래 항목을 제공받아야 “스텁/폴리필”이 아닌 실제 BA·엔진 경로를 완성할 수 있습니다.

- App Store Connect Background Assets 생성/업로드 권한
  - BA pack 생성(3개) 및 Apple-hosted 활성화
- (선택) Hugging Face access token
  - 개발기 다운로드/sha256 생성 자동화
- Apple 개발자 팀 ID / 번들 ID
  - BA/XCFramework 서명·배포 연결
- llama.cpp iOS XCFramework 또는 소스 빌드 파이프라인 접근
  - SPM binaryTarget(권장) 또는 CMake 스크립트

위 항목 준비가 끝나면, 다음 작업을 진행합니다:
- // MLtodo-1: SystemBackgroundAssetClient.ensureInstalled 내부에 iOS 18 Background Assets API 연동
- // MLtodo-2: llama.cpp iOS XCFramework 연결 및 LlamaCppBindingImpl 구현(메탈 백엔드 옵션 포함)
- // MLtodo-3: UnifiedAIService에 onDevice 경로 추가(중앙 토큰/프롬프트/로깅 재사용)

────────────────────────────────────────────────────────

16. 자주 묻는 질문(FAQ)

Q1. 왜 GGUF 메타의 채팅 템플릿을 “엔진 자동”으로 강제하나요?
- 수동 포맷팅은 모델/토크나이저/템플릿 차이에 취약합니다. GGUF 메타 신뢰가 가장 견고합니다.

Q2. iPhone 12에서 1B 모델은 가능합니까?
- 짧은 턴, 낮은 온도에서 가능하지만 장시간 스트림은 권장하지 않습니다. 폴백 정책 필수.

Q3. BA 대신 ODR로도 가능한가요?
- 이 프로젝트에서는 ODR을 예비 옵션2로만 두며, 실제 배포는 BA(Apple-hosted)를 권장합니다.

Q4. tok/s는 어떻게 추정하나요?
- 스트리밍 델타 카운트/시간으로 근사값을 기록(정확한 토크나이저 일치가 필요하면 엔진 노출)

────────────────────────────────────────────────────────

부록 A. 설정 화면 통합(요지)

- 현재 UI
  - DeepSleepApp/Views/AIModelSettingsView.swift (SwiftUI)
  - DeepSleepApp/AIModelSelectionViewController.swift (UIKit)
- 단계
  1) 모델 카드에 “온디바이스” 항목을 표시(AIModelType.onDevice)
  2) 선택 시 BA 설치 상태 표시/다운로드 버튼 제공
  3) 설치 완료 → ModelLoader.switch(...) 호출
  4) 실패/OOM → 메시지+자동 폴백

부록 B. 성능 보고서(권장 양식)
```
# iPhone12 성능 측정(모델 3종)
- 날짜/OS/앱버전:
- 테스트 문장:
- 모델별 5회 측정:
  - TTI(ms) 평균/표준편차
  - tok/s(근사)
  - Thermal 이벤트/발열 체감
  - 실패/폴백 발생 여부
- 요약/권고 파라미터:
```

부록 C. 개발기 스크립트(scripts/fetch_models.sh, 예시)
```
#!/usr/bin/env bash
set -euo pipefail
mkdir -p models
huggingface-cli download unsloth/gemma-3-270m-it-GGUF gemma-3-270m-it-Q8_0.gguf -d ./models --local-dir-use-symlinks False
huggingface-cli download Qwen/Qwen2.5-0.5B-Instruct-GGUF qwen2.5-0.5b-instruct-q4_k_m.gguf -d ./models --local-dir-use-symlinks False
huggingface-cli download bartowski/google_gemma-3-1b-it-GGUF gemma-3-1b-it-IQ4_XS.gguf -d ./models --local-dir-use-symlinks False
shasum -a 256 ./models/*.gguf > ./models/sha256sum.txt
echo "OK: models downloaded & sha256sum.txt generated"
```

────────────────────────────────────────────────────────

마지막 점검(체크리스트)
- [ ] iPhone 12 실기 성능표(3모델, TTI/tok·s)
- [ ] 전환 UX(설치→전환→복귀) 스크린캡쳐/GIF
- [ ] BA 팩/파일 경로/sha256 일치 검증 보고
- [ ] 문서 3종(SETUP, CATALOG, PERF) 포함 PR

끝. 이 가이드는 실제 배포/심사/운영까지 고려하여 작성되었습니다. 상기 “요청 목록”이 충족되면 // MLtodo 지점의 실제 구현을 안전하게 진행할 수 있습니다.