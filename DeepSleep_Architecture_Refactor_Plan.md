# DeepSleep iOS 앱 고도화 계획서 v2.0

## 📋 목표 요약
- **기존 기능 100% 보존** + 최신 iOS 기술 적용
- Clean Architecture + MVVM 강화
- 모듈화 SPM 패키지 분리
- SwiftUI 전환 (단계적)
- CI/CD 파이프라인 완성
- 테스트 커버리지 80%↑

## 🔍 현재 상태 분석
### 대용량 파일 (리팩터링 우선순위)
1. `ChatViewController.swift` - 3,109줄 → **최우선 분해 대상**
2. `ChatviewController+Actions.swift` - 2,610줄
3. `SoundPresetCatalog.swift` - 2,370줄
4. `EmotionAnalysisChatViewController.swift` - 1,853줄
5. `TodoCalendarViewController.swift` - 1,588줄

### 아키텍처 문제점
- Presentation + Business Logic 혼재
- 19개 ViewController → 책임 과다
- 모듈 경계 불분명
- SPM 패키지 분리 없음

## 🚀 단계별 실행 계획

### Phase 1: Clean Architecture 모듈 분리 (2-3시간)
#### 1.1 Core 모듈 생성
```
Sources/
├── Core/
│   ├── Domain/
│   │   ├── Entities/
│   │   ├── UseCases/
│   │   └── Repositories/
│   ├── Data/
│   │   ├── Repositories/
│   │   ├── DataSources/
│   │   └── Models/
│   └── Common/
│       ├── Extensions/
│       ├── Utilities/
│       └── Protocols/
└── Features/
    ├── Chat/
    ├── Sound/
    ├── EmotionDiary/
    ├── AI/
    └── Settings/
```

#### 1.2 모듈별 SPM 패키지 생성
- `DeepSleepCore` - 공통 로직
- `DeepSleepAI` - LLM, LoRA, ML 관련
- `DeepSleepSound` - 사운드 관리
- `DeepSleepUI` - UI 컴포넌트

### Phase 2: ChatViewController 리팩터링 (3-4시간)
#### 2.1 MVVM 패턴 적용
```swift
// 현재: ChatViewController (3,109줄)
// 목표: 
ChatView (SwiftUI) + ChatViewModel + ChatRepository
ChatMessageView, ChatInputView 등 세분화
```

#### 2.2 책임 분리
- **View**: UI 표시만
- **ViewModel**: 상태 관리, 비즈니스 로직
- **Repository**: 데이터 접근
- **UseCase**: 복잡한 비즈니스 규칙

### Phase 3: SwiftUI 전환 (4-5시간)
#### 3.1 전환 우선순위
1. 새로운 화면: SwiftUI + MVVM
2. 단순한 화면: UIKit → SwiftUI 전환
3. 복잡한 화면: UIKit 유지 (점진적 전환)

#### 3.2 Design System 구축
```swift
struct DSColor { }
struct DSFont { }
struct DSSpacing { }
// 일관성 있는 UI 컴포넌트 라이브러리
```

### Phase 4: AI/ML 모듈 고도화 (3-4시간)
#### 4.1 LLMRouter 강화
```swift
enum AIBackend {
    case foundation  // iOS 18+
    case claude35    // API 백업
    case localLoRA   // 온디바이스
}

protocol LLMService {
    func generateResponse(_ prompt: String) async throws -> String
}
```

#### 4.2 LoRA 어댑터 관리
- Dynamic loading
- 온디바이스 학습
- 메모리 최적화

### Phase 5: 테스트 및 CI/CD (2-3시간)
#### 5.1 테스트 전략
```swift
// Unit Tests
ChatViewModelTests
LLMRouterTests
LoRAAdapterTests

// Integration Tests
AIWorkflowTests
SoundEngineTests

// UI Tests (SwiftUI)
ChatFlowTests
SnapshotTests
```

#### 5.2 CI/CD 파이프라인
```yaml
# .github/workflows/ci.yml
- Build & Test (iOS 17, 18)
- SwiftLint --strict
- Coverage Report (80%+)
- TestFlight Deploy
```

### Phase 6: 성능 최적화 (2-3시간)
#### 6.1 메모리 관리
- Lazy Loading
- LRU Cache 활용
- Background Task 최적화

#### 6.2 배터리 최적화
- ANE(Apple Neural Engine) 활용
- Background App Refresh 최적화
- 불필요한 네트워크 호출 제거

## 📊 예상 결과
### Before vs After
| 항목 | Before | After |
|------|--------|-------|
| 최대 파일 크기 | 3,109줄 | 300줄 이하 |
| ViewController 수 | 19개 | 8-10개 |
| 테스트 커버리지 | ~40% | 80%+ |
| 빌드 시간 | 45초 | 30초 |
| 앱 크기 | 현재 | 20% 감소 |

### 품질 지표
- SwiftLint violations: 0
- Memory leaks: 0
- Crash rate: <0.1%
- Cold start time: <2초

## 🔧 도구 및 기술 스택
### 최신 기술 적용
- **Swift 5.9** + Xcode 15.3
- **iOS 17** minimum deployment
- **SwiftUI 5** + Combine
- **async/await** (Concurrency)
- **Core ML 7** + LoRA adapters
- **SPM** (Swift Package Manager)

### 개발 도구
- **SwiftLint** --strict
- **SwiftFormat**
- **XCTest** + Coverage
- **Snapshot Testing**
- **Fastlane**
- **GitHub Actions**

## 🚨 위험 요소 및 대응
### 위험 요소
1. 대용량 리팩터링 중 기능 손실
2. SwiftUI 전환 시 UX 변화
3. 모듈 분리 시 의존성 순환 참조

### 대응 방안
1. **점진적 접근**: 한 번에 하나씩 변경
2. **기능 테스트**: 각 단계마다 회귀 테스트
3. **롤백 계획**: Git 브랜치 전략 활용
4. **A/B 테스트**: 중요 화면은 병행 개발

## ⏰ 예상 일정
- **Phase 1**: 2-3시간 (모듈 구조)
- **Phase 2**: 3-4시간 (Chat 리팩터링)
- **Phase 3**: 4-5시간 (SwiftUI 전환)
- **Phase 4**: 3-4시간 (AI 모듈)
- **Phase 5**: 2-3시간 (테스트/CI)
- **Phase 6**: 2-3시간 (최적화)

**총 예상 시간: 16-22시간** (2-3일)

## 🎯 최종 목표
> 기존 DeepSleep 앱의 모든 기능을 보존하면서, 대기업 수준의 코드 품질과 최신 iOS 기술을 적용한 고성능 AI 개인비서 앱으로 완전히 업그레이드 