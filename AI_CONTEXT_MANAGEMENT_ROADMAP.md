# 🧠 DeepSleep AI 컨텍스트 관리 시스템 로드맵

## 📋 개요

이 문서는 DeepSleep 앱의 **장기 비전**으로서 AI 컨텍스트 관리 시스템의 전체 아이디어와 구현 계획을 담고 있습니다. 현재 기본기 완성 후 중장기적으로 구현할 고급 기능입니다.

## 🎯 최종 목표

**"AI가 사용자와의 대화를 효과적으로 기억하는 비용 효율적이고 확장 가능한 시스템"**

- 복잡한 RAG(검색 증강 생성) 시스템 없이 구현
- 사용자 지정 기억을 포함한 계층적 컨텍스트 관리
- 단기 기억, 장기 기억, AI 정체성의 3계층 구조

## 🏗️ 최종 확정 아키텍처

### 계층 1: 단기 기억 (Sliding Window)
**목표:** AI가 방금 나눈 대화 내용을 기억하여 대화의 연속성 보장

**구현 방식:**
- API 호출 시 현재 대화 세션의 최신 메시지 10개 본문을 컨텍스트에 포함
- 담당 모듈: `ChatManager.swift`

**기술적 세부사항:**
```swift
// ChatManager.swift에서 구현 예시
func buildConversationContext() -> String {
    let recentMessages = conversationHistory.suffix(10)
    return recentMessages.map { "\($0.role): \($0.content)" }.joined(separator: "\n")
}
```

### 계층 2: AI 정체성 (시스템 프롬프트 캐싱)
**목표:** AI의 역할, 말투, 기본 지침 등 반복 정보를 효율적으로 관리하여 API 비용 절감

**구현 방식:**
- `AIContextManager.swift`에서 시스템 프롬프트 생성
- 3시간 동안 캐시하여 재사용
- 담당 모듈: `AIContextManager.swift`

**기술적 세부사항:**
```swift
// AIContextManager.swift에서 구현 예시
private var cachedSystemPrompt: (prompt: String, timestamp: Date)?
private let cacheValidityDuration: TimeInterval = 3 * 60 * 60 // 3시간

func getSystemPrompt() -> String {
    if let cached = cachedSystemPrompt,
       Date().timeIntervalSince(cached.timestamp) < cacheValidityDuration {
        return cached.prompt
    }
    
    let newPrompt = generateSystemPrompt()
    cachedSystemPrompt = (newPrompt, Date())
    return newPrompt
}
```

### 계층 3: 장기 기억 (사용자 지정 '핵심 기억' 시스템)
**목표:** 사용자가 중요하다고 판단한 과거 정보를 AI가 잊지 않도록 하여 개인화된 장기 기억 구현

**구현 방식:**

#### 3.1 UI/UX 인터페이스
- 사용자가 채팅 버블을 길게 눌러 [기억하기/기억 해제] 선택
- 기억된 메시지는 시각적으로 구분 (별표, 색상 변경 등)

#### 3.2 등급별 차등 제공
```
무료 사용자: 최대 5개의 '핵심 기억' 슬롯
프리미엄 사용자: 최대 20개의 '핵심 기억' 슬롯
```

#### 3.3 자동 요약 및 저장 시스템
1. **변경 감지:** '핵심 기억' 목록에 추가/삭제 발생 시
2. **원문 수집:** 저장된 모든 '핵심 기억' 메시지 원문을 묶음
3. **AI 요약:** 경량 AI 모델(Gemini 1.5 Flash)로 '핵심 기억 요약본' 생성
4. **로컬 저장:** CoreData 또는 UserDefaults에 요약본 저장
5. **컨텍스트 주입:** 메인 AI 대화 시 요약본만 포함하여 토큰 사용량 최소화

#### 3.4 관리 화면
- 사용자가 현재 기억된 목록 확인 및 삭제 가능한 '기억 관리 창' UI

## 📊 API 호출 시 최종 컨텍스트 구조

```
[메인 AI 모델로 전송될 최종 컨텍스트]
=================================
(계층 2) 시스템 프롬프트 (3시간 캐시에서 로드)
---------------------------------
(계층 3) 사용자 지정 '핵심 기억' 요약본
---------------------------------
(계층 1) 최근 대화 1 (본문)
...
(계층 1) 최근 대화 10 (본문)
---------------------------------
사용자의 현재 메시지
=================================
```

## 🎯 기대 효과

### 사용자 경험
- AI가 단기 및 장기 기억을 모두 보유
- 훨씬 더 개인적이고 깊이 있는 대화 가능
- 사용자가 직접 기억을 제어하여 높은 만족도와 신뢰 제공

### 비용 효율성
- 시스템 프롬프트 캐싱으로 반복 비용 절감
- '핵심 기억' 요약 시스템으로 토큰 사용량 획기적 감소
- 운영 비용 최소화

### 구현 현실성
- 복잡한 벡터 데이터베이스나 검색 알고리즘 불필요
- 기존 아키텍처를 점진적으로 확장하여 구현 가능

### 사업적 가치
- '핵심 기억' 슬롯 개수로 무료/유료 모델 명확 구분
- 자연스러운 유료 구독 유도 가능한 비즈니스 모델

## 🗓️ 구현 로드맵

### 📋 현재 상황 (2025-08-10)
**완료해야 할 기본기:**
- ❌ 페르소나 시스템 AI 연동 (90% 완료, 1줄 코드 수정 필요)
- ❌ 학습 시스템 데드 코드 정리 (4,000+ 라인 제거 필요)
- ❌ 구독 시스템 구현 (모든 사용자 동일 제한 상태)

**관련 가이드 파일:**
- `PERSONA_SYSTEM_ACTIVATION_GUIDE.md` - 페르소나 시스템 활성화
- `PERSONA_SYSTEM_DETAILED_ANALYSIS.md` - 페르소나 시스템 상세 분석
- `LEARNING_SYSTEM_CLEANUP_GUIDE.md` - 학습 시스템 정리
- `LEARNING_SYSTEM_DETAILED_ANALYSIS.md` - 학습 시스템 상세 분석

### Phase 1: 기본기 완성 (1-2주) - **우선 실행 필수**
1. **페르소나 시스템 활성화**
   - ChatManager에서 AIContextManager 연동 (1줄 코드)
   - 사용자 맞춤형 AI 응답 구현

2. **데드 코드 정리**
   - PersonalizedHarmonyLearner.swift 제거
   - EnhancedSoundRecommendationEngine.swift 제거
   - 4,000+ 라인 정리로 성능 향상

### Phase 2: 기본 컨텍스트 관리 (1-2개월)
1. **구독 시스템 기본 구현**
   - 무료/프리미엄 사용자 구분
   - 기본적인 차등 제한 적용

2. **단순 대화 기록 시스템**
   - 최근 10개 메시지 컨텍스트 포함
   - 계층 1 (단기 기억) 구현

### Phase 3: 고급 컨텍스트 관리 (3-6개월)
1. **시스템 프롬프트 캐싱**
   - 계층 2 (AI 정체성) 구현
   - 3시간 캐싱으로 비용 절감

2. **핵심 기억 시스템 기본**
   - 사용자 지정 기억 UI/UX
   - 기본적인 기억 저장/불러오기

### Phase 4: 완전한 기억 관리 (6-12개월)
1. **자동 요약 시스템**
   - AI 기반 기억 요약 생성
   - 토큰 최적화 완성

2. **고급 관리 기능**
   - 기억 관리 화면
   - 등급별 차등 슬롯 제공

## 🔧 기술적 구현 세부사항

### 데이터 모델
```swift
// CoreMemory.swift
struct CoreMemory {
    let id: UUID
    let originalMessage: String
    let summary: String
    let timestamp: Date
    let importance: Int
    let userID: String
}

// MemoryManager.swift
class MemoryManager {
    func addMemory(_ message: String) -> Bool
    func removeMemory(id: UUID) -> Bool
    func getMemorySummary() -> String
    func canAddMemory() -> Bool // 슬롯 확인
}
```

### UI 컴포넌트
```swift
// ChatBubbleView.swift - 길게 누르기 제스처
@objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
    if gesture.state == .began {
        showMemoryActionSheet()
    }
}

// MemoryManagementViewController.swift - 기억 관리 화면
class MemoryManagementViewController: UIViewController {
    @IBOutlet weak var memoryTableView: UITableView!
    // 기억 목록 표시 및 관리
}
```

### 비용 최적화
```swift
// TokenOptimizer.swift
class TokenOptimizer {
    func optimizeContext(
        systemPrompt: String,
        memories: String,
        recentMessages: [String]
    ) -> String {
        // 토큰 수 계산 및 최적화
        // 우선순위에 따른 컨텍스트 조정
    }
}
```

## ⚠️ 주의사항 및 고려사항

### 기술적 고려사항
1. **토큰 제한:** AI 모델별 컨텍스트 길이 제한 고려
2. **성능 최적화:** 대화 기록이 많아질 때의 성능 관리
3. **데이터 동기화:** 여러 기기 간 기억 동기화 방안

### 사용자 경험 고려사항
1. **직관적 UI:** 기억 기능이 복잡하지 않도록 설계
2. **투명성:** 사용자가 AI가 무엇을 기억하는지 명확히 알 수 있도록
3. **제어권:** 사용자가 언제든 기억을 수정/삭제할 수 있도록

### 비즈니스 고려사항
1. **차등 서비스:** 무료/유료 기억 슬롯 차이의 적절성
2. **마이그레이션:** 기존 사용자의 데이터 이전 방안
3. **확장성:** 향후 더 고급 기능 추가 가능성

## 🔥 결론

이 AI 컨텍스트 관리 시스템은 **DeepSleep 앱의 장기 비전**으로서 매우 가치 있는 아이디어입니다. 

**핵심 가치:**
- 기술적으로 탄탄한 설계
- 사용자 경험과 비즈니스 모델의 완벽한 조화
- 단계적 구현으로 리스크 최소화

**현재 상황:**
- 기본기 완성이 우선 (페르소나 활성화, 데드 코드 정리)
- 구독 시스템 구현 후 단계적 접근 필요

**최종 권장사항:**
1. **현재:** 기본기 완성에 집중
2. **향후:** 이 로드맵을 따라 단계적 구현
3. **목표:** 사용자가 진정으로 "나를 이해하는 AI"를 경험할 수 있는 시스템 구축

**이 시스템이 완성되면 DeepSleep은 단순한 수면 앱을 넘어 사용자의 진정한 AI 동반자가 될 것입니다.** 🚀