# AI 아키텍처 리팩토링 마스터 플랜 (Master Plan for AI Architecture Refactoring)

**최종 목표 (Goal)**: 모든 AI 관련 요청을 단일 진입점(`LLMRouter`)으로 통합하고, 사용자가 직접 모델을 선택할 수 있는 유연하고 확장 가능한 아키텍처를 구축한다. 향후 온디바이스 AI 모델까지 손쉽게 통합할 수 있는 구조를 목표로 한다.

**핵심 원칙 (Core Principles)**:
1.  **단일 진입점 (Single Entry Point)**: 모든 AI 기능 요청은 `LLMRouter.send(task:)`를 통해서만 이루어진다.
2.  **중앙 집중 제어 (Centralized Control)**: `LLMRouter`가 사용자의 모델 선택, 태스크 종류, 플랫폼(OS) 버전에 따라 적절한 `LLMService`로 요청을 분기한다.
3.  **역할과 책임 분리 (Separation of Concerns)**: View는 `AITask`를 생성하는 책임만, Router는 요청을 분기하는 책임만, Service는 API와 통신하는 책임만 가진다.
4.  **유지보수성 (Maintainability)**: 신규 AI 모델 또는 신규 AI 기능 추가 시, 최소한의 파일만 수정하도록 구조를 단순화한다.
5.  **명확성 (Clarity)**: `AITask` 열거형을 통해 각 AI 요청의 의도, 데이터, 설정을 코드상에서 명확하게 표현한다.

---

### 3단계 실행 계획 (3-Phase Execution Plan)

#### ✅ 1단계: 새로운 아키텍처 뼈대 구축 (Phase 1: Foundation) - 완료

-   [x] `REFACTORING_PLAN.md` 상세 계획 업데이트 (본 문서)
-   [x] `SettingsManager`에 `selectedLLM` 속성 추가 완료.
-   [x] **`AITask` 열거형 정의**: AI에 요청할 모든 작업의 종류와 필요 데이터를 명세하는 "작업 명세서"를 생성한다.
    -   **파일 위치**: `Sources/Core/Domain/Entities/AITask.swift` (신규 생성)
    -   **구현 내용**: `generalChat`, `analyzeEmotionDiary`, `recommendTodo` 등 모든 AI 기능 케이스를 정의. 각 케이스는 필요한 데이터를 연관값(associated value)으로 가진다.
    -   **`// TODO`**: 각 케이스에 필요한 `systemPrompt`와 `LLMRequestConfig`를 반환하는 로직을 추가한다.
-   [x] **`LLMRouter` 재설계**: 모든 AI 요청을 처리하는 중앙 허브로 리팩토링한다.
    -   **파일 위치**: `Sources/Core/Domain/Services/LLMRouter.swift`
    -   **핵심 메소드**: `func send(task: AITask) async throws -> LLMResponse`
    -   **구현 내용**: 내부적으로 `SettingsManager`에서 사용자가 선택한 모델(`selectedLLM`)을 확인. `if #available(iOS 18, *)` 분기 처리를 통해 온디바이스 모델 사용 가능성을 미리 구조에 반영. `LLMServiceFactory`를 통해 적절한 서비스 인스턴스를 받아와 실제 요청을 위임한다.
-   [x] **`LLMServiceFactory` 개선**: `LLMServiceType`에 따라 적절한 서비스 인스턴스를 생성하는 팩토리를 개선한다.
    -   **파일 위치**: `Sources/Core/Data/Factory/LLMServiceFactory.swift`
    -   **`// TODO`**: 향후 추가될 `.onDevice` 케이스에 대한 생성 로직을 미리 주석으로 남겨둔다.

#### ✅ 2단계: 사용자 인터페이스 연결 (Phase 2: UI Connection) - 완료

-   [x] **`AIModelSettingsView` 및 `ViewModel` 신규 제작**: 사용자가 AI 모델을 선택하고 저장할 수 있는 UI와 로직을 구현한다.
    -   **파일 위치**: `Sources/Core/Presentation/Views/AIModelSettingsView.swift`, `Sources/Core/Presentation/ViewModels/AIModelSettingsViewModel.swift` (신규 생성)
    -   **구현 내용**: `SettingsManager.shared.availableLLMs` 목록을 표시하고, 사용자가 모델을 선택하면 `SettingsManager.shared.selectedLLM`을 업데이트한다.
-   [x] **기존 설정 메뉴와 `AIModelSettingsView` 통합**: 사용자가 설정 화면에서 AI 모델 선택 화면으로 진입할 수 있도록 네비게이션을 연결한다.
    -   **`// TODO`**: `PersonaSettingsView.swift` 또는 관련 설정 파일에 `NavigationLink`를 추가할 위치를 식별하고 주석을 남긴다.

#### ✅ 3단계: 전면 교체 및 정리 (Phase 3: Integration & Cleanup) - 완료

-   [x] **`ChatViewController.swift` 리팩토링**: 기존 AI 호출 로직을 `LLMRouter.send(task: .generalChat(...))`로 교체.
-   [x] **`TodoCalendarViewController.swift` 리팩토링**: 기존 AI 조언 요청 로직을 `LLMRouter.send(task: .recommendTodo(...))`로 교체.
-   [x] **`EmotionAnalysisChatViewController.swift` 리팩토링**: 기존 일기 분석 요청 로직을 `LLMRouter.send(task: .analyzeEmotionDiary(...))`로 교체.
-   [x] **`SoundManager.swift` 리팩토링**: 기존 사운드 추천 로직을 `LLMRouter.send(task: .recommendSound(...))`로 교체.
-   [x] **`EnhancedAIRecommendationService.swift` 리팩토링**: 서비스 자체가 불필요해져 과감히 삭제 완료.
-   [x] **`LegacyStubs.swift` 에서 `ReplicateChatService` 관련 코드 최종 삭제**: 더 이상 사용하지 않는 레거시 코드를 완전히 제거.
-   [x] **프로젝트 전체 정리**: 프로젝트 전체에서 "Replicate", "ClaudeService", "GeminiService" 등 구형 서비스 이름을 직접 호출하는 코드가 남아있지 않은지 검색 후, 전부 `LLMRouter` 사용으로 수정 완료. 