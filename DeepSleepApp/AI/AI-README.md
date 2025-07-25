# 🤖 DeepSleep AI 시스템

DeepSleep 앱의 통합 AI 시스템입니다.

## 📂 폴더 구조

```
AI/
├── Services/               # AI 모델 통합 서비스
│   ├── AIServiceTypes.swift                  # 공통 타입 및 에러 정의
│   ├── UnifiedAIService.swift               # 통합 인터페이스 프로토콜
│   ├── UnifiedAIServiceImpl.swift           # 통합 서비스 구현체
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

### 통합 AI 서비스
- **4개 AI 모델 통합**: Claude, OpenAI GPT-4o Mini, Google Gemini, Naver HyperCLOVA X
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

## 💰 비용 관리

| 모델 | 특징 | 권장 사용 |
|------|------|-----------|
| Claude | 고품질, 한국어 우수 | 감정 분석, 깊은 대화 |
| OpenAI | 빠름, 구조화된 출력 | 할일 조언, 실용적 응답 |
| Gemini | 다국어, 안전 필터 | 프리셋 추천, 창의적 응답 |
| Naver | 한국어 특화, 가장 저렴 | 일반 대화, 비용 절감 |

## 📚 상세 문서

자세한 내용은 [Services/README.md](Services/README.md)를 참조하세요.

## 🧪 테스트

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

---

**💡 팁**: 개발 중에는 `AppConfig.Development.isDebugMode = true`로 설정하여 상세한 디버그 정보를 확인할 수 있습니다.