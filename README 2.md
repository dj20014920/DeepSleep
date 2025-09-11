# 🚀 DeepSleep 통합 AI 시스템 가이드

## 📋 개요

[참고] 구독/결제/환불/복원/7일 무료체험 정책의 단일 SSOT는 SUB_GUIDE.md 입니다. Paywall/UI 문구/링크/동작은 SUB_GUIDE.md 기준으로 유지하세요.

DeepSleep 앱을 위한 4개 AI 모델 통합 시스템입니다. Claude, OpenAI, Gemini, Naver HyperCLOVA X를 하나의 인터페이스로 통합하여 사용할 수 있습니다.

## 🎯 주요 특징

### ✅ 구현 완료된 기능
- **4개 AI 모델 통합**: Claude, OpenAI GPT-4o Mini, Google Gemini, Naver HyperCLOVA X
- **11가지 AI 모드**: 일반 대화, 감정 분석, 할일 조언, 프리셋 추천 등
- **자동 Fallback**: 모델 실패 시 자동으로 다른 모델 사용
- **토큰 최적화**: 모드별 맞춤 토큰 설정
- **보안 시스템**: 기존 AISecurityManager와 완전 통합
- **비용 관리**: 실시간 비용 계산 및 모니터링
- **에러 처리**: 포괄적인 에러 핸들링 및 사용자 친화적 메시지

### 🔄 향후 구현 예정
- **실시간 스트리밍**: 현재는 일반 응답을 스트리밍으로 변환
- **사용량 통계**: 상세한 사용량 분석 및 리포트
- **모델 성능 모니터링**: 실시간 레이턴시 및 성공률 추적

## 📂 파일 구조

```
Services/AI/
├── AIServiceTypes.swift           # 공통 타입 및 에러 정의
├── UnifiedAIService.swift        # 통합 인터페이스 프로토콜
├── UnifiedAIServiceImpl.swift    # 실제 구현체
├── ClaudeAPIService.swift        # Anthropic Claude API 서비스
├── OpenAIAPIService.swift        # OpenAI GPT API 서비스  
├── GeminiAPIService.swift        # Google Gemini API 서비스
├── NaverAPIService.swift         # Naver HyperCLOVA X API 서비스
├── UnifiedAIServiceTests.swift   # 테스트 유틸리티
├── UnifiedAIServiceExample.swift # 사용 예시
└── README.md                     # 이 파일
```

## ⚙️ 설정 방법

### 1. Xcode 프로젝트에 파일 추가

1. Xcode에서 DeepSleep 프로젝트 열기
2. `Services/AI` 폴더를 프로젝트에 추가
3. 모든 `.swift` 파일이 DeepSleep 타겟에 포함되어 있는지 확인

### 2. API 키 설정

`Secrets.xcconfig` 파일에 다음 API 키들이 설정되어 있는지 확인:

```
// Claude API
CLAUDE_API_KEY = sk-ant-your-claude-api-key

// OpenAI API  
OPEN_AI_4oMINI_API_KEY = sk-your-openai-api-key

// Google Gemini API
GEMINI_API_KEY = AIzaYour-gemini-api-key

// Naver HyperCLOVA X API
NAVER_CLOUD_API_KEY = your-naver-api-key:your-secret
```

### 3. 의존성 확인

다음 패키지들이 프로젝트에 포함되어 있는지 확인:
- `GoogleGenerativeAI` (Gemini 사용을 위해)

## 🔧 사용법

### ✅ **권장 사용법** - SessionManager (3시간 캐싱 보장)

```swift
// SessionManager를 통한 AI 호출 - 3시간 캐싱 자동 보장
let response = try await SessionManager.shared.sendMessage(
    content: "안녕하세요!",
    mode: .generalConversation
)

print(response.content)
```

### 기존 사용법 (직접 호출 - 권장하지 않음)

```swift
let aiService = UnifiedAIServiceImpl.shared

let response = try await aiService.sendMessage(
    content: "안녕하세요!",
    model: .claude,
    mode: .generalConversation,
    context: AIContext(userId: "user123", sessionId: "session1"),
    tokenConfig: nil
)

print(response.content)
```

### 모드별 사용법

```swift
// 1. 감정 일기 분석 - SessionManager 사용 (추천)
let emotionResponse = try await SessionManager.shared.sendMessage(
    content: "오늘은 기분이 좋지 않았어요...",
    mode: .emotionDiaryAnalysis
)

// 2. 음악 프리셋 추천 - 특정 모델 지정
let musicResponse = try await SessionManager.shared.sendMessage(
    content: "스트레스 해소에 좋은 음악을 추천해주세요",
    mode: .presetRecommendation,
    model: .gemini  // Gemini 2.0 Flash-Lite 추천
)

// 3. 할일 조언
let taskResponse = try await SessionManager.shared.sendMessage(
    content: "내일 프레젠테이션 준비를 어떻게 해야 할까요?",
    mode: .taskAdvice
)
```

### 기존 방식 (직접 호출)

```swift
// 1. 감정 일기 분석
let emotionResponse = try await aiService.sendMessage(
    content: "오늘은 기분이 좋지 않았어요...",
    model: .claude,
    mode: .emotionDiaryAnalysis,
    context: context,
    tokenConfig: nil
)

// 2. 음악 프리셋 추천 (아이템 리스트 방식)
let musicResponse = try await aiService.sendMessage(
    content: "스트레스 해소에 좋은 음악을 추천해주세요",
    model: .gemini, // Gemini 2.0 Flash-Lite 권장
    mode: .presetRecommendation,
    context: context,
    tokenConfig: TokenConfiguration(maxTokens: 100, responseFormat: .json)
)

// 3. 할일 조언
let taskResponse = try await aiService.sendMessage(
    content: "내일 프레젠테이션 준비를 어떻게 해야 할까요?",
    model: .openAI,
    mode: .taskAdvice,
    context: context,
    tokenConfig: nil
)
```

### 기존 코드와 통합

```swift
// 기존 ChatViewController에서 사용
class ChatViewController: UIViewController {
    private let aiService = UnifiedAIServiceImpl.shared
    
    func sendMessage(_ userMessage: String) {
        Task {
            do {
                let response = try await aiService.sendMessage(
                    content: userMessage,
                    model: getCurrentSelectedModel(),
                    mode: .generalConversation,
                    context: createCurrentContext(),
                    tokenConfig: nil
                )
                
                await MainActor.run {
                    displayAIResponse(response.content)
                }
            } catch {
                await MainActor.run {
                    displayError(error)
                }
            }
        }
    }
}
```

## 🧪 테스트 방법

### 1. 기본 연결 테스트

```swift
let testUtil = UnifiedAIServiceTests()
await testUtil.quickConnectionTest()
```

### 2. 전체 시스템 테스트

```swift
let testUtil = UnifiedAIServiceTests()
await testUtil.runFullSystemTest()
```

### 3. 성능 벤치마크

```swift
let testUtil = UnifiedAIServiceTests()
await testUtil.runPerformanceBenchmark()
```

### 4. 사용 예시 실행

```swift
let example = UnifiedAIServiceExample()
await example.runAllExamples()
```

## 🔒 보안 고려사항

- ✅ 기존 `AISecurityManager`와 완전 통합
- ✅ 입력/출력 보안 검증
- ✅ API 키 안전한 저장 (Bundle에서 로드)
- ✅ 레이트 리미팅 및 사용량 제한
- ✅ 프롬프트 인젝션 방지

## 💰 비용 관리 (및 사용량/구독 정책 동기화)

### 모델별 정확한 비용 (2025년 7월 22일 최신)

| 모델 | Input (1K 토큰) | Output (1K 토큰) | 특징 | 무료 티어 | 순위 |
|------|-----------------|------------------|------|----------|------|
| **Gemini 2.0 Flash-Lite** | $0.000075 | $0.0003 | 가장 저렴, 빠른 응답 | Google AI Studio 무료 | 1위 |
| **Naver HyperCLOVA X** | $0.00075 (₩1) | $0.000188 (₩0.25) | 한국어 특화, 한국 정서 | 비공개 | 2위 |
| **GPT-4o Mini** | $0.00015 | $0.0006 | JSON 구조화 출력 우수 | ChatGPT 무료 플랜 제한적 | 3위 |
| **Claude 3.5 Sonnet** | $0.003 | $0.015 | 고품질, 깊은 공감 | Claude.ai 웹사이트 | 4위 |

**⚡ 2025년 7월 업데이트**: Gemini 2.5 Flash가 Gemini 1.5 Flash보다 성능 및 비용 효율성이 크게 개선됨

### 비용 최적화 팁

- **확정된 모드별 AI 모델 매핑**:
   - **프리셋 추천**: Gemini 2.0 Flash-Lite (아이템 리스트 JSON)
   - **감정 일기 분석**: Gemini 2.0 Flash-Lite (고정, 빠르고 일관된 분석)
   - **할일 조언**: Gemini 2.0 Flash-Lite (빠른 응답)
   - **일반 대화**: 사용자 설정 (미설정시 Gemini 2.0 Flash-Lite)
   - **월간 통계**: Gemini 2.0 Flash-Lite (큰 컨텍스트)
   - **운세**: Naver HyperCLOVA X (한국 정서)
   - **감정 분석**: OpenAI GPT-4o Mini (JSON 출력)

2. **토큰 제한 설정**: 각 모드별로 적절한 `maxTokens` 설정
2. **Fallback 순서** (비용 기준): free model tier(OpenRouter) → Gemini → OpenAI → Naver → Claude
3. **비용 절약 전략**: 
   - 무료 티어 활용 (Google AI Studio에서 Gemini 무료 사용)
   - 프롬프트 캐싱으로 Claude 90% 절약 가능
   - 배치 처리로 대부분 모델 50% 할인

8. **보안 프록시(Cloudflare Workers) 경유**:
   - 앱은 `USE_PROXY=YES` 설정 시 모든 LLM 호출을 `/v1/chat` 프록시로 전송(키 보호/사용량 집행)
   - HMAC 헤더(`X-Emozleep-*`)로 최소 인증, 티어 규칙/Claude 상한을 서버에서 보조 집행
   - 응답은 `{ provider, content, raw }` 통일 포맷

## 🚨 문제 해결

### 자주 발생하는 오류

1. **API 키 인증 실패**
   - `Secrets.xcconfig` 파일의 API 키 확인
   - API 키 형식이 올바른지 확인

2. **모델 사용 불가**
   - 해당 모델의 API 키가 설정되어 있는지 확인
   - Fallback 모델이 설정되어 있는지 확인

3. **토큰 제한 초과**
   - `maxTokens` 설정을 줄이거나
   - 입력 메시지 길이를 줄임

4. **네트워크 오류**
   - 인터넷 연결 확인
   - API 서버 상태 확인

5. **프록시 인증 오류(401/403)**
   - HMAC 헤더 누락/서명 불일치 여부 확인
   - Origin 제한(ALLOWED_ORIGINS) 또는 네이티브 앱(Origin 없음) 정책 확인
   - 클라이언트 비밀(CLIENT_PROXY_HMAC_SECRET)과 워커 비밀(EDGE_SIGNING_SECRET)의 일치 확인

### 디버깅 방법

1. **로그 확인**: 각 서비스는 상세한 로그를 출력
2. **시스템 상태**: `generateSystemStatusReport()` 호출
3. **개별 테스트**: `testSpecificModel()` 사용

## 📈 성능 최적화

### PERF-WARNING 표시된 부분들

1. **메모리 관리**: 
   - Instruments의 Allocations 프로파일러 사용
   - 대량 토큰 처리 시 메모리 사용량 모니터링

2. **네트워크 최적화**:
   - Network 프로파일러로 응답 시간 측정
   - 동시 연결 수 제한

3. **CPU 최적화**:
   - Time Profiler로 문자열 처리 성능 측정
   - 다국어 텍스트 인코딩 최적화

## 🔄 업데이트 로그

### 2025-09-03
- 프록시 경로(/v1/chat) generation 파라미터 전달(클라이언트): temperature, maxTokens, topP, frequencyPenalty, presencePenalty, responseFormat을 요청 바디에 포함하도록 업데이트. 서버가 미수용이어도 무해하며, 수용 시 공급자별 파라미터로 매핑 권장.
- 시스템 프롬프트 경량화: 모드별/모델별 프롬프트를 간결한 지시문으로 정리. 첫 응답만 짧은 인사 허용, 이후 인사/서두 반복 금지. 시스템 텍스트 복사 금지/결론 반복 금지/새 관점 또는 구체 예시 1개 포함.
- 영향 파일: AI/Services/UnifiedAIServiceImpl.swift, AI/Context/AIContextBuilder.swift

### v1.0.0 (2025-07-21)
- ✅ 4개 AI 모델 통합 완료
- ✅ 11가지 AI 모드 구현
- ✅ 보안 시스템 통합
- ✅ Fallback 로직 구현
- ✅ 테스트 유틸리티 제공
- ✅ 사용 예시 및 가이드 완성

## 📞 지원

문제가 발생하거나 추가 기능이 필요한 경우:

1. **로그 확인**: 콘솔에서 `[UnifiedAIService]` 태그로 필터링
2. **테스트 실행**: `UnifiedAIServiceTests` 클래스 사용
3. **예시 참조**: `UnifiedAIServiceExample` 클래스 확인

---

**💡 팁**: 개발 중에는 `AppConfig.Development.isDebugMode = true`로 설정하여 상세한 디버그 정보를 확인할 수 있습니다.

---

# 🧠 아키텍처 설계 결정 기록 (2025-07-23)

## 📋 설계 회의 기록
**참여자**: 개발자(사용자) + Claude Code AI  
**목표**: 모든 AI 호출을 단일 함수로 완전 통합

---

## 🎯 핵심 설계 결정사항

### 1. ✅ 단일 함수 통합 아키텍처 채택
**Claude 제안**: 3가지 접근 방식 제시
- 방식 1: 개별 메서드 유지 방식
- **방식 2: 통합 아키텍처 방식** (공통 타입 분리)
- 방식 3: 하이브리드 방식

**사용자 결정**: **방식 2 채택**  
**선택 이유**: 
> *"똑같은 로직을 여러 파일에 여러개 만드는 것보단 하나 만들어서 여기저기서 호출하는게 유지보수, 확장성에 유리하지않을까?"*

**최종 구현**:
```swift
// ChatManager.swift에서 단일 진입점 제공
public func sendMessage(userInput: String, modeString: String, modelString: String?) -> String
public func sendMessage(content: String, model: AIMode, mode: AIMode, context: AIContext?, tokenConfig: TokenConfiguration?) -> AIResponse
```

### 2. ✅ 메서드 네이밍 완전 통일
**기존 문제**: `sendMessage`, `sendChatMessage`, `sendAIMessage` 혼재로 혼란

**사용자 피드백**:
> *"sendchatmessage말고 sendmessage 함수는 있지않아? 확인 후 진행해줘"*  
> *"chatmessage와 sendmessage로 구분해서 진행하는 이유가 뭐야 하나로 통일해도 되는거아냐?"*

**Claude 분석**: 통일 필요성 공감 및 실행
**최종 결과**: 
- ❌ `sendAIMessage` → **완전 제거**
- ❌ `sendChatMessage` → **완전 제거**  
- ✅ `sendMessage` → **단일 통합 메서드**

### 3. ✅ 보안 설정 관리 방식 승인
**Claude 초기 우려**: API 키 노출 위험성 지적

**사용자 해명**:
> *"일부로 개발자인 내가 보기 편하고 깃허브에 커밋이 안되도록 ignore파일과 xcconfig 파일로 구성한거야 그리고 appinfo 파일을 이용하여 호출하여 사용하면되잖아 이래도 문제가 있어?"*

**Claude 재평가**: **"매우 우수한 구조, 베스트 프랙티스"**
**현재 구조의 우수성**:
- ✅ **보안**: API 키가 git에 노출되지 않음
- ✅ **유지보수**: 개발자가 config 파일만 수정하면 됨  
- ✅ **환경 분리**: Dev/Prod 키 분리 가능
- ✅ **팀 협업**: 각자 다른 키 사용 가능

### 4. ✅ 성능 vs 유지보수성 판단
**Claude 성능 분석**: 단일 함수 통합 시 미미한 오버헤드 존재

**사용자 중요 판단**:
> *"그런데 이걸 하나의 함수호출로 통합하지 않으면 나중에 유지보수에 어려움이 있을 것 같은데 지금의 await 비동기 방식을 유지해야할까? 그래도 성능상에 큰 문제는 없을 것 같은데 무시해도 될 정도의 오버헤드 일 것 같은데?"*

**Claude 정량적 분석**:
- **오버헤드**: 함수 호출 1회 추가 (~0.1ms) → **무시 가능**
- **네트워크 지연**: AI API 호출 (500-2000ms) → **실제 병목의 99.9%**
- **최종 성능 영향**: **0.01% 미만**

**최종 합의**: **유지보수성 우선 선택** ✅
- async/await 현대적 비동기 방식 유지
- 중앙 집중식 에러 처리, 로깅, 모니터링

### 5. ✅ 완전 통합 범위 확정
**사용자 최종 요구사항**:
> *"어쩄든 내가 원하는 방향은 chatmessage(외부 모델에게 입력하는 모든 채팅, 상담 포함)은 모두 단 하나의 함수로 작동하면 좋겠다는 거야 여러개의 인자를 가지고서 모델선택과 모드선택을 하여 Secrets.xcconfig 여기 파일에서 원활하게 개별로 제한을 하고 추후 유지보수에도 편리하게 할 수 있도록 말이야"*

**구현 방향**:
- 📱 **ChatViewController** → sendMessage 통합
- 📔 **감정 일기 분석** → sendMessage 통합  
- 📝 **할일 조언** → sendMessage 통합
- 🎵 **프리셋 추천** → sendMessage 통합
- 🔮 **운세** (하드코딩이지만 AIMode 통일)
- ❌ **꿈해몽, 패턴분석** (앱에 없음으로 제외)

### 6. ✅ 시스템 프롬프트 자동화
**Claude 제안**: AIMode별 시스템 프롬프트 자동 주입 방식

**사용자 동의**:
> *"2. 각 모드별 프롬프트템플릿 즉 시스템 프롬프트를 말하는거지? 이것도 aimode에 따라서 자동으로 같이 시스템 프롬프트가 입력되는 형식으로 전환해줘 아마 시스템프롬프트가 이미 하드코딩된 파일이 있을 거야 그 파일을 찾아봐"*

**구현 계획**: 
- 하드코딩된 프롬프트 파일 탐색
- AIMode enum과 프롬프트 매핑 테이블 구축
- 자동 프롬프트 주입 시스템 구현

---

## 🚀 기술적 우수성 평가

### Claude 최종 평가
> **"이 구조는 대기업급 아키텍처입니다"**  
> **"성능 걱정은 전혀 불필요하고, 유지보수성과 확장성 측면에서 최고의 선택입니다"**

### 아키텍처 강점
1. **🎯 단일 진입점**: 모든 AI 호출이 `ChatManager.sendMessage` 경유
2. **🔒 타입 안전성**: `AIMode`, `AIModel` enum을 통한 컴파일 타임 검증
3. **⚙️ 설정 중앙화**: `Secrets.xcconfig` 기반 API 키 및 제한 관리
4. **📈 확장성**: 새 AI 모델/기능 추가 시 최소한의 코드 변경
5. **🐛 디버깅 용이성**: 중앙 집중식 로깅 및 에러 처리
6. **🤖 자동화**: AIMode별 시스템 프롬프트 자동 주입

### 사용량 제한 통합 시스템 (Secrets.xcconfig)
```xcconfig
# Chat(티어별, SSOT)
AI_LIMITS_CHAT = 50
AI_LIMITS_CHAT_PRO = 100
AI_LIMITS_CHAT_MAX = 150

# 기능별 일일 제한(SSOT)
AI_LIMITS_PRESET_RECOMMENDATION_FREE = 3
AI_LIMITS_PRESET_RECOMMENDATION_PRO  = 5
AI_LIMITS_PRESET_RECOMMENDATION_MAX  = 7
AI_LIMITS_DIARY_ANALYSIS_FREE = 3
AI_LIMITS_DIARY_ANALYSIS_PRO  = 5
AI_LIMITS_DIARY_ANALYSIS_MAX  = 5
AI_LIMITS_TODO_ADVICE_FREE = 3
AI_LIMITS_TODO_ADVICE_PRO  = 6
AI_LIMITS_TODO_ADVICE_MAX  = 10
AI_LIMITS_TODO_ADVICE_EACH = 1
AI_LIMITS_TODO_OVERALL_ADVICE_FREE = 1
AI_LIMITS_TODO_OVERALL_ADVICE_PRO  = 3
AI_LIMITS_TODO_OVERALL_ADVICE_MAX  = 3
AI_LIMITS_EMOTION_ANALYSIS = 0
AI_LIMITS_MONTHLY_STATISTICS = 1

# 전역 보안 제한
MAX_DAILY_REQUESTS = 100
MAX_PROMPT_LENGTH = 2000
MAX_CONVERSATION_TURNS = 200
```

> 참고 파일: `WARP.md`(구성/흐름 개요), `DEEPSLEEP_COMPREHENSIVE_GUIDE.md`(검증 체크리스트), `AI_CONTEXT_MANAGEMENT_ROADMAP.md`(캐시/맥락/토큰 정책), `IOS_IAP_ROADMAP.md`(Paywall/IAP 동작)

---

## 📊 개발자 성장 인사이트

### 개발 패러다임 전환
**이전**: 
- "바이브 코딩" 중심의 즉흥적 구현
- 기능별 개별 구현 선호
- 단기적 개발 속도 우선

**현재**:
- 체계적 아키텍처 설계 중시
- 코드 재사용성과 유지보수성 우선
- 장기적 확장성 고려

### 의사결정 능력 향상
> *"성능상에 큰 문제는 없을 것 같은데 무시해도 될 정도의 오버헤드 일 것 같은데? 너의 생각은 어떄"*

**특징**: 
- 정량적 성능 분석 요구
- 트레이드오프 인식 및 합리적 판단
- 장기적 유지보수성 우선 선택

---

## 🎯 향후 작업 로드맵

### ✅ 완료된 작업
1. 아키텍처 설계 및 방향성 확정
2. 메서드 네이밍 통일 (sendMessage)
3. 기존 AI 서비스 통합 기반 마련
4. 보안 설정 시스템 검증

### 🔄 진행 예정 작업 (업데이트)
1. **시스템 프롬프트 파일 탐색 및 통합**
2. **AIMode enum 확장 및 매핑**
3. ~~UsageLimitManager 구현~~ (완료: 티어별 채팅/Claude 상한/주간 1회 정책/80% 알림/버튼 라벨 연동)
4. **분산된 AI 호출 지점 통합**
5. **ViewController 리팩토링**
6. **통합 테스트 및 성능 검증**

---

## 🆕 2025-08-29 업데이트 요약
- 티어별 채팅 한도 도입: Free/Pro/Max(50/100/200)
- Claude 일일 30회(Premium) 상한 + 초과 시 자동 Gemini 라우팅
- 월간 통계 → 주간 1회(KST, 월요일 00:00 리셋)로 정책 정합화
4. **Claude 상한·자동 라우팅**:
   - 프로덕션에서는 프록시 서버가 정책을 집행(클라이언트는 DAILY_* 미사용)
   - 초과 시 UnifiedAIServiceImpl이 자동으로 Gemini(또는 다음 폴백)로 라우팅(무경고, 자연스러운 UX)

5. **티어별 채팅 한도**:
   - Free/Pro/Max에 따라 SSOT 키만 사용
     • Max: `AI_LIMITS_CHAT_MAX` / Pro: `AI_LIMITS_CHAT_PRO` / Free: `AI_LIMITS_CHAT`
   - 80%/100% 도달 시 알림 브로드캐스트 → ChatViewController에서 Alert + “업그레이드” CTA 표시

6. **월간 통계 정책(주간 1회, KST)**:
   - `UsageLimitManager.canUseWeeklyLimitedFeature(.kstMonday, key: "monthly_statistics")`
   - 시작 전 안내에 이번 주 남은 횟수/리셋 시각 노출

7. **버튼 남은 횟수 라벨**:
   - 감정 일기 분석/월간(주간) 통계 버튼에 “(남은 n/총 m)” 또는 “(이번주 n/1)” 표시

- 채팅 80%/100% 도달 Alert + Paywall CTA
- 버튼 라벨에 남은 횟수 표시: 감정 일기 분석/월간(주간) 통계
- 모든 한도/키는 `Secrets.xcconfig` → `Info.plist` → `ConfigReader` 경로로 로드

---

## 💡 핵심 교훈

### 아키텍처 설계 원칙
- **단순함이 복잡함을 이긴다**: 복잡한 개별 구현보다 간단한 통합 시스템
- **타입 안전성의 힘**: enum을 통한 컴파일 타임 에러 방지
- **설정 중앙화**: 한 곳에서 모든 것을 관리하는 편리함

### 성능 vs 유지보수성
- **마이크로 최적화의 함정**: 0.01% 성능보다 100배 편한 유지보수
- **병목 지점 파악**: 네트워크 지연이 99.9%, 함수 호출은 0.01%
- **미래 대비**: 확장성 있는 구조가 장기적으로 더 빠른 개발

### 보안과 편의성 균형
- **xcconfig + .gitignore**: 보안과 개발 편의성의 완벽한 조화
- **환경별 분리**: 하나의 시스템으로 모든 환경 대응

---

**📝 작성일**: 2025-07-23  
**📊 상태**: 설계 완료, 구현 단계 진입  
**👥 기여자**: 개발자 + Claude Code AI  

*이 기록은 향후 아키텍처 결정 및 팀 온보딩 시 핵심 참고 자료로 활용됩니다.*

## 📑 프록시 계약 확장 — 엄격 JSON(Structured Output)
- /v1/chat 선택 필드 추가 지원:
  - responseFormat: "json" | "text" | "markdown"
  - responseMimeType: 예) "application/json"
  - responseSchema: JSON Schema 객체(≤20KB)
- 서버 폴백(엄격 JSON 모드): gemini → openai → claude → naver → openrouter (환경에 따라 openrouter 제외)
- 새 헤더: X-Strict-JSON
- 자세한 사용법은 `STRUCTURED_OUTPUT_GUIDE.md` 참조
