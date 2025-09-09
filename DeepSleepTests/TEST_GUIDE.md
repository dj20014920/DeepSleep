# DeepSleep 채팅 메시지 저장/복원 테스트 가이드

## 📋 테스트 범위

### 1. 단위 테스트 (ChatManagerTests.swift)
- **Round-Trip 테스트**: 메시지 저장 → 복원 검증
- **경계값 테스트**: 0개, 1개, 1000개 메시지 처리
- **성능 테스트**: 대량 메시지 저장/조회 성능 측정
- **동시성 테스트**: 멀티스레드 환경에서의 안정성

### 2. UI 테스트 (ChatPersistenceUITests.swift)
- **메시지 지속성**: 화면 전환, 앱 재시작 후 메시지 유지
- **Storage 관리**: 저장소 화면에서 삭제 → 채팅창 반영
- **성능 측정**: 스크롤, 로딩 성능

## 🚀 테스트 실행 방법

### Xcode에서 실행

#### 모든 테스트 실행
```bash
# Command Line
xcodebuild test -project DeepSleep.xcodeproj -scheme DeepSleep -destination 'platform=iOS Simulator,name=iPhone 15 Pro'
```

#### 단위 테스트만 실행
```bash
xcodebuild test -project DeepSleep.xcodeproj -scheme DeepSleep -only-testing:DeepSleepTests
```

#### UI 테스트만 실행
```bash
xcodebuild test -project DeepSleep.xcodeproj -scheme DeepSleep -only-testing:DeepSleepUITests
```

### Xcode GUI에서 실행
1. Xcode 열기
2. `Cmd + U` 또는 `Product > Test` 메뉴 선택
3. 특정 테스트만 실행하려면 테스트 네비게이터에서 개별 테스트 선택 후 실행

## 📊 주요 테스트 시나리오

### 시나리오 1: 메시지 저장/복원 Round-Trip
```swift
// 1. 메시지 생성
let message = StoredChatMessage(...)

// 2. 저장
chatManager.addMessage(to: sessionId, message: message)
chatManager.flush()

// 3. 복원 검증
let restored = chatManager.getSession(id: sessionId)
assert(restored.messages.contains(message))
```

### 시나리오 2: 앱 재시작 후 메시지 유지
```swift
// 1. 메시지 전송
sendMessage("테스트 메시지")

// 2. 앱 종료
app.terminate()

// 3. 앱 재시작
app.launch()

// 4. 메시지 확인
assert(isMessageVisible("테스트 메시지"))
```

### 시나리오 3: Storage 화면 삭제 연동
```swift
// 1. 메시지 생성
sendMessage("삭제할 메시지")

// 2. Storage 화면에서 삭제
navigateToStorageScreen()
deleteLatestConversation()

// 3. 채팅창에서 확인
navigateToChatScreen()
assert(!isMessageVisible("삭제할 메시지"))
```

## 🔍 경계값 테스트 케이스

### 0개 메시지 (빈 세션)
- 빈 세션 생성 → 저장 → 복원
- 예상: 메시지 수 = 0, 세션은 존재

### 1개 메시지
- 단일 메시지 저장 → 복원
- 예상: 정확히 1개 메시지 복원

### 1000개 메시지
- 대량 메시지 저장 → 복원
- 예상: 모든 메시지 정확히 복원, 성능 저하 없음

## 📈 성능 기준 (Baseline)

### 저장 성능
- 100개 메시지 저장: < 100ms
- 1000개 메시지 저장: < 1s

### 조회 성능
- 최근 100개 메시지 조회: < 50ms
- 전체 세션 목록 조회: < 100ms

### UI 성능
- 메시지 로딩: < 500ms
- 스크롤 성능: 60fps 유지

## 🐛 알려진 이슈 및 해결방법

### 이슈 1: UI 테스트 식별자 문제
**문제**: UI 요소를 찾을 수 없음
**해결**: accessibility identifier 설정 확인
```swift
// ChatViewController에 추가 필요
messageTextField.accessibilityIdentifier = "메시지 입력"
sendButton.accessibilityIdentifier = "전송"
```

### 이슈 2: 비동기 저장 타이밍
**문제**: flush() 후 즉시 조회 시 데이터 없음
**해결**: CFPreferencesAppSynchronize 호출로 즉시 동기화

### 이슈 3: 메모리 누수
**문제**: 대량 메시지 처리 시 메모리 증가
**해결**: cleanupOldSessions() 주기적 호출

## 🎯 테스트 커버리지 목표

- **단위 테스트 커버리지**: 80% 이상
- **UI 테스트 커버리지**: 주요 사용자 시나리오 100%
- **성능 테스트**: 모든 주요 작업에 대한 측정

## 📝 테스트 결과 확인

### 성공 기준
✅ 모든 round-trip 테스트 통과
✅ 앱 재시작 후 메시지 유지
✅ Storage 삭제 → 채팅창 반영
✅ 경계값 테스트 모두 통과
✅ 성능 기준 충족

### 실패 시 디버깅
1. 콘솔 로그 확인
2. UserDefaults 데이터 직접 확인
3. 메모리 그래프 디버거 사용
4. Instruments로 성능 프로파일링

## 🔧 테스트 환경 설정

### 필수 설정
```swift
// AppDelegate에 추가
if ProcessInfo.processInfo.arguments.contains("--uitesting") {
    // UI 테스트 모드 설정
    UserDefaults.standard.set(true, forKey: "isUITesting")
    // 애니메이션 비활성화
    UIView.setAnimationsEnabled(false)
}
```

### 테스트 데이터 초기화
```swift
override func setUp() {
    super.setUp()
    ChatManager.shared.clearAllSessions()
}

override func tearDown() {
    ChatManager.shared.clearAllSessions()
    super.tearDown()
}
```

## 📱 디바이스별 테스트

### 시뮬레이터
- iPhone 15 Pro (iOS 17.0+)
- iPhone SE (작은 화면)
- iPad Pro (큰 화면)

### 실제 디바이스
- 최소 iOS 15.0 이상
- 메모리 제한 테스트 (구형 기기)

## 🚦 CI/CD 통합

### GitHub Actions 예제
```yaml
name: Tests
on: [push, pull_request]
jobs:
  test:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v2
      - name: Run Tests
        run: |
          xcodebuild test \
            -project DeepSleep.xcodeproj \
            -scheme DeepSleep \
            -destination 'platform=iOS Simulator,name=iPhone 15 Pro'
```

## 📚 참고 자료

- [XCTest Documentation](https://developer.apple.com/documentation/xctest)
- [UI Testing Best Practices](https://developer.apple.com/videos/play/wwdc2015/406/)
- [Performance Testing Guide](https://developer.apple.com/documentation/xctest/performance_tests)
