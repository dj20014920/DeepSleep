# 🤖 DeepSleep AI 시스템

DeepSleep 앱의 통합 AI 시스템입니다.

## 📂 폴더 구조

```
AI/
├── Services/               # AI 모델 통합 서비스
│   ├── AIServiceTypes.swift                  # 공통 타입 및 에러 정의
│   ├── UnifiedAIService.swift               # 통합 인터페이스 프로토콜
│   ├── UnifiedAIServiceImpl.swift           # 통합 서비스 구현체 (730라인)
│   ├── OpenRouterFallbackManager.swift      # 🆕 무료 모델 폴백 시스템 (25개 모델)
│   ├── ClaudeAPIService.swift               # Claude API 서비스
│   ├── OpenAIAPIService.swift               # OpenAI API 서비스
│   ├── GeminiAPIService.swift               # Gemini API 서비스
│   ├── NaverAPIService.swift                # Naver API 서비스
│   ├── UnifiedAIServiceTests.swift          # 테스트 유틸리티
│   ├── UnifiedAIServiceExample.swift        # 사용 예시
│   └── README.md                            # 상세 가이드
│
└── README.md               # 이 파일
```

## 🚀 주요 기능

### 통합 AI 서비스 (2025-08-08 최신 업데이트)
- **5개 AI 모델 통합**: Claude, OpenAI GPT-4o Mini, Google Gemini, Naver HyperCLOVA X, **🆕 통합 무료 모델**
- **통합 무료 모델 시스템**: 25개 OpenRouter 무료 모델의 순차적 폴백
  - **Tier 1**: DeepSeek R1, Qwen 2.5 Coder 32B (O3급 성능)
  - **Tier 2**: Llama 3.3 70B, Mistral Small (고성능 중형)
  - **Tier 3**: Gemini 2.0 Flash, NVIDIA Nemotron (실험적)
  - **Tier 4-6**: 중형/경량 백업 모델들 (총 25개)
- **지능형 순차 폴백**: 한국어 대화 + JSON 파싱 최적화 순서
- **11가지 AI 모드**: 일반 대화, 감정 분석, 할일 조언, 프리셋 추천 등
- **자동 Fallback**: 모델 실패 시 가장 저렴한 모델로 자동 전환
- **보안 통합**: AISecurityManager와 완전 통합
- **비용 최적화**: 실시간 비용 계산 및 모니터링

## 🔧 사용법

### 기본 사용
```swift
let aiService = UnifiedAIServiceImpl.shared
let response = try await aiService.sendMessage(
    content: "안녕하세요",
    model: .claude,
    mode: .generalConversation,
    context: AIContext(userId: "user123", sessionId: "session1"),
    tokenConfig: nil
)
print(response.content)
```

### 🆕 통합 무료 모델 사용
```swift
// 25개 무료 모델을 순차적으로 시도
let response = try await aiService.sendMessage(
    content: "한국어로 대답해주세요",
    model: .freeModel,  // 통합된 무료 모델
    mode: .generalConversation,
    context: context,
    tokenConfig: nil
)
// DeepSeek R1 → Qwen 2.5 → Llama 3.3 → ... 순서로 자동 시도
```

### 감정 분석
```swift
let response = try await aiService.sendMessage(
    content: "오늘은 기분이 좋지 않았어요...",
    model: .claude,
    mode: .emotionDiaryAnalysis,
    context: context,
    tokenConfig: nil
)
```

### 프리셋 추천
```swift
let response = try await aiService.sendMessage(
    content: "스트레스 해소에 좋은 음악을 추천해주세요",
    model: .gemini,
    mode: .presetRecommendation,
    context: context,
    tokenConfig: TokenConfiguration(maxTokens: 100, responseFormat: .json)
)
```

## 📊 시스템 플로우

```
사용자 입력
    ↓
[보안 검증 (AISecurityManager)]
    ↓
[AI 모델 호출 (UnifiedAIService)]
    ↓
[응답 검증]
    ↓
최종 응답
```

## 🔒 보안

- 모든 입력은 AISecurityManager를 통해 검증
- 프롬프트 인젝션 방지
- API 키는 Secrets.xcconfig에서 안전하게 관리

## 💰 비용 관리 (2025-08-20 업데이트)

| 모델 | 특징 | 권장 사용 | 비용 |
|------|------|-----------|------|
| **🆕 통합 무료 모델** | **25개 모델 순차 폴백** | **베타 테스트, 대량 사용** | **무료** |
| Claude Haiku 3.5      | 고품질, 한국어 우수  | 일기 분석, 깊은 대화   | $0.80/$4.00 (Prompt caching Write $1 / MTok  Read $0.08 / MTok)|
| OpenAI GPT-4o Mini    | 빠름, 구조화된 출력  | 할일 조언, 실용적 응답  | $0.15/$0.60 |
| OpenAI GPT-5 nano     | 빠름, 구조화된 출력  | 프리셋 추천용(대화X)    | $$0.05/$0.40 | 
| Gemini 2.0 Flash-Lite | 다국어, 안전 필터   | 창의적 응답           | $0.075/$0.30 |
| Naver (HCX-DASH-002)  | 한국어 특화        | 일반 대화, 한국 정서    | (1000토큰당)₩0.25/(1000토큰당)₩1 |
### 🎯 Fallback 우선순위 (비용 기준)
1. **통합 무료 모델** (25개 모델 순차 시도)
2. **Gemini 2.0 Flash-Lite** (가장 저렴한 유료 모델)
3. **OpenAI GPT-4o Mini** (중간 비용, 안정성)
4. **Naver HyperCLOVA X** (한국어 특화)
5. **Claude Haiku 3.5** (최고 품질)

## 📚 상세 문서

자세한 내용은 [Services/README.md](Services/README.md)를 참조하세요.

## 🧪 테스트

### Local build/test smoke
- scripts/dev_build_test_smoke.sh: Clean build and unit tests for DeepSleep scheme targeting iPhone 16 Pro simulator (Debug).

### Parser tests
- Fuzz coverage: malformed JSON, weird Unicode, code fences, provider-specific paths, and streaming-like scenarios (partial chunks, out-of-order, mid-stream termination).

```swift
// 빠른 연결 테스트
let testUtil = UnifiedAIServiceTests()
await testUtil.quickConnectionTest()

// 전체 테스트
await testUtil.runFullSystemTest()

// 사용 예시 실행
let example = UnifiedAIServiceExample()
await example.runAllExamples()
```

## 🆕 2025-08-08 주요 업데이트

### OpenRouter 무료 모델 통합 시스템
- **25개 무료 모델**: DeepSeek R1, Qwen 2.5 Coder, Llama 3.3 등
- **순차적 폴백**: 병렬 호출 → 순차 호출로 변경하여 안정성 향상
- **지능형 순서**: 한국어 대화 + JSON 파싱 특화 순서로 재배열
- **완벽한 통합**: testModel → freeModel 통합으로 코드 정리

### 기술적 개선사항
- **API 키 검증**: OPENROUTER_API_KEY 통합 관리
- **서비스 초기화**: API 키 있을 때만 freeModelService 활성화
- **안전한 호출**: guard 문으로 옵셔널 언래핑 처리
- **빌드 성공**: 모든 컴파일 오류 해결 완료

### 사용법
```swift
// Secrets.xcconfig에 추가
OPENROUTER_API_KEY = sk-or-v1-...

// 코드에서 사용
let response = try await aiService.sendMessage(
    content: "한국어로 JSON 형태로 답변해주세요",
    model: .freeModel,  // 25개 모델 자동 폴백
    mode: .presetRecommendation,
    context: context
)
```

---

**💡 팁**: 개발 중에는 `AppConfig.Development.isDebugMode = true`로 설정하여 상세한 디버그 정보를 확인할 수 있습니다.

**🚀 베타 테스트**: 통합 무료 모델을 우선 사용하여 비용 절감과 안정성을 동시에 확보하세요!
