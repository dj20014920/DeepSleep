# DeepSleep 성능 관리 시스템 가이드

## 🎯 개요

DeepSleep 앱의 새로운 **의존성 주입 기반 성능 관리 시스템**입니다. 2025년 최신 iOS 성능 표준에 맞춰 설계되었으며, 배터리, 메모리, 발열 최적화를 최우선으로 합니다.

## 🏗️ 아키텍처

### 주요 구성 요소

1. **프로토콜 기반 의존성 주입**: `PerformanceManagementProtocols.swift`
2. **통합 성능 관리자**: `UnifiedPerformanceManager.swift`
3. **시스템 부트스트랩**: `PerformanceSystemBootstrap.swift`
4. **의존성 컨테이너**: `PerformanceContainer`

### 이전 Singleton → 새로운 의존성 주입

```swift
// ❌ 이전 방식 (강결합)
let batteryLevel = BatteryOptimizationManager.shared.batteryLevel

// ✅ 새로운 방식 (의존성 주입)
class MyViewController {
    private let performanceManager: PerformanceManagerProtocol
    
    init(performanceManager: PerformanceManagerProtocol) {
        self.performanceManager = performanceManager
    }
    
    func checkBattery() {
        let status = performanceManager.batteryManager.getBatteryStatus()
        print("배터리: \(status.levelPercentage)%")
    }
}
```

## 🚀 빠른 시작

### 1. 시스템 초기화 (이미 AppDelegate에 설정됨)

```swift
// AppDelegate.swift에서 자동 호출됨
PerformanceSystemBootstrap.shared.initializePerformanceSystem()
```

### 2. 기본 사용법

```swift
// 통합 성능 관리자 가져오기
guard let performanceManager = PerformanceSystemBootstrap.shared.getPerformanceManager() else {
    print("성능 관리 시스템이 초기화되지 않음")
    return
}

// 현재 시스템 상태 확인
let status = performanceManager.getSystemStatus()
print("성능 수준: \(status.performanceLevel.rawValue)")
print("배터리: \(status.batteryStatus.levelPercentage)%")
print("메모리: \(String(format: "%.1f", status.memoryStatus.currentUsageMB))MB")

// 즉시 최적화 실행
performanceManager.optimizeForCurrentConditions()
```

### 3. 편의 메서드 사용

```swift
// 빠른 최적화
PerformanceSystemBootstrap.quickOptimize()

// 현재 성능 수준 확인
if let level = PerformanceSystemBootstrap.getCurrentPerformanceLevel() {
    print("현재 성능: \(level.rawValue)")
}

// 성능 리포트 생성
if let report = PerformanceSystemBootstrap.generateReport() {
    print(report)
}
```

## 🧩 개별 컴포넌트 사용법

### 배터리 관리

```swift
let batteryManager = performanceManager.batteryManager

// 배터리 상태 확인
let batteryStatus = batteryManager.getBatteryStatus()
print("배터리: \(batteryStatus.description)")

// 배터리 최적화 요청
batteryManager.requestBatteryOptimization()

// 적응형 최적화 활성화
batteryManager.enableAdaptiveOptimization(true)
```

### 메모리 관리

```swift
let memoryManager = performanceManager.memoryManager

// 메모리 상태 확인
let memoryStatus = memoryManager.getMemoryStatus()
print("메모리 압박 수준: \(memoryStatus.pressureLevel.description)")

// 메모리 최적화 요청
memoryManager.requestMemoryOptimization()

// 이미지 캐시 관리
memoryManager.addToImageCache(myImage, forKey: "key")
let cachedImage = memoryManager.getFromImageCache(forKey: "key")
```

### 성능 최적화

```swift
let optimizer = performanceManager.performanceOptimizer

// 디바운싱 (과도한 호출 방지)
optimizer.debounce(identifier: "search", delay: 0.3) {
    // 실제 검색 로직
    print("검색 실행")
}

// 배치 처리
optimizer.batchOperation(identifier: "updates", delay: 0.1) {
    // 업데이트 로직
    print("UI 업데이트")
}

// 성능 측정
optimizer.startPerformanceMeasurement("heavy_task")
// ... 무거운 작업 수행
optimizer.endPerformanceMeasurement("heavy_task")
```

### ML 추론 최적화

```swift
let mlOptimizer = performanceManager.mlOptimizer

// 성능 모드 설정
mlOptimizer.setPerformanceMode(.efficient) // .maximum, .balanced, .efficient, .powerSaver

// 현재 모드 확인
let currentMode = mlOptimizer.getCurrentMode()
print("ML 모드: \(currentMode.description)")

// 최적화 상태 확인
let status = mlOptimizer.getOptimizationStatus()
print("ML 최적화 상태: \(status)")
```

### 백그라운드 작업 관리

```swift
let backgroundManager = performanceManager.backgroundTaskManager

// 제한 레벨 설정
backgroundManager.setThrottlingLevel(.moderate) // .none, .mild, .moderate, .aggressive

// 백그라운드 작업 스케줄
let success = backgroundManager.scheduleBackgroundTask(type: .dataSync) {
    // 데이터 동기화 작업
    print("데이터 동기화 완료")
}

// 현재 상태 확인
let status = backgroundManager.getBackgroundTaskStatus()
print("백그라운드 작업 상태: \(status)")
```

## 📊 성능 모니터링

### 실시간 상태 모니터링

```swift
class PerformanceMonitorViewController: UIViewController {
    @Published var systemStatus: SystemPerformanceStatus?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        guard let performanceManager = PerformanceSystemBootstrap.shared.getPerformanceManager() else { return }
        
        // 성능 상태 변화 구독
        performanceManager.$systemStatus
            .sink { [weak self] status in
                self?.systemStatus = status
                self?.updateUI()
            }
            .store(in: &cancellables)
    }
    
    private func updateUI() {
        guard let status = systemStatus else { return }
        
        // UI 업데이트
        performanceLevelLabel.text = status.performanceLevel.rawValue
        batteryLabel.text = "\(status.batteryStatus.levelPercentage)%"
        memoryLabel.text = String(format: "%.1fMB", status.memoryStatus.currentUsageMB)
    }
}
```

### 성능 분석

```swift
let analytics = performanceManager.getPerformanceAnalytics()

print("현재 점수: \(analytics.currentScorePercentage)%")
print("최근 최적화: \(analytics.lastOptimizationTime?.formatted() ?? "없음")")
print("권장사항:")
analytics.recommendations.forEach { print("• \($0)") }
```

## 🔧 고급 사용법

### 커스텀 의존성 주입

```swift
// 테스트용 Mock 객체 주입
class MockBatteryManager: BatteryOptimizationProtocol {
    var isLowPowerModeEnabled = false
    var batteryLevel: Float = 0.5
    // ... 프로토콜 구현
}

let customManager = UnifiedPerformanceManager(
    batteryManager: MockBatteryManager(),
    // 다른 의존성들...
)
```

### 성능 이벤트 리스너

```swift
// 위험 성능 상태 알림 수신
NotificationCenter.default.addObserver(
    forName: NSNotification.Name("CriticalPerformanceDetected"),
    object: nil,
    queue: .main
) { notification in
    print("⚠️ 위험한 성능 상태 감지됨!")
    // 사용자에게 경고 표시
}
```

### 성능 히스토리 추적 (향후 구현)

```swift
// 성능 히스토리 추적 활성화
performanceManager.enablePerformanceHistoryTracking(true)

// 성능 알림 설정
performanceManager.configurePerformanceAlerts(
    enableCriticalAlerts: true,
    enableRecommendations: true
)
```

## 🐛 디버깅 및 진단

### 시스템 진단

```swift
// 전체 시스템 상태 출력 (개발용)
PerformanceSystemBootstrap.shared.printSystemDiagnostics()

// 의존성 컨테이너 상태 확인
let container = PerformanceContainer.shared
let registrations = container.getRegistrationStatus()
print("등록된 서비스들: \(registrations)")
```

### 성능 리포트 생성

```swift
if let report = performanceManager.generatePerformanceReport() {
    print(report)
    // 또는 파일로 저장, 서버로 전송 등
}
```

## ⚠️ 주의사항

### 1. 초기화 순서
- 성능 관리 시스템은 AppDelegate에서 가장 먼저 초기화됩니다
- 다른 시스템들이 성능 관리자에 의존할 수 있으므로 순서가 중요합니다

### 2. 메모리 관리
- 모든 클래스는 weak 참조를 적절히 사용하여 순환 참조를 방지합니다
- Timer와 Combine 구독은 자동으로 정리됩니다

### 3. 성능 최적화
```swift
// PERF-WARNING: 메인 스레드에서 무거운 작업 방지
// 확인 방법: Instruments > Time Profiler
performanceManager.performanceOptimizer.batchOperation(identifier: "heavy") {
    // 무거운 작업들을 배치로 처리
}
```

### 4. 배터리 효율성
- 성능 관리 시스템 자체도 배터리를 고려하여 설계되었습니다
- Low Power Mode에서는 자동으로 모니터링 주기가 조정됩니다

## 🔄 마이그레이션 가이드

### 기존 Singleton 코드 변경

```swift
// ❌ 변경 전
class OldViewController {
    func checkBattery() {
        let level = BatteryOptimizationManager.shared.batteryLevel
        print("배터리: \(Int(level * 100))%")
    }
}

// ✅ 변경 후
class NewViewController {
    private let performanceManager: PerformanceManagerProtocol
    
    init() {
        // 앱 전역 성능 관리자 사용
        self.performanceManager = PerformanceSystemBootstrap.shared.getPerformanceManager()!
    }
    
    func checkBattery() {
        let status = performanceManager.batteryManager.getBatteryStatus()
        print("배터리: \(status.levelPercentage)%")
    }
}
```

## 📈 성능 기준

### 목표 지표 (2025년 iOS 표준)
- **메모리 사용량**: 200MB 이하 유지
- **배터리 드레인**: 시간당 5% 이하
- **CPU 사용률**: 일반 상태에서 10% 이하
- **열 상태**: Nominal/Fair 유지

### 성능 수준별 동작
- **Excellent (80-100%)**: 모든 기능 최대 성능
- **Good (60-80%)**: 균형 잡힌 성능
- **Fair (40-60%)**: 일부 기능 제한
- **Poor (20-40%)**: 적극적 최적화
- **Critical (0-20%)**: 응급 모드

## 🤝 기여 가이드

새로운 성능 기능을 추가할 때:

1. 적절한 프로토콜 정의
2. 의존성 주입 패턴 준수
3. UnifiedLogger 사용
4. 메모리 누수 방지
5. 배터리 효율성 고려

## 📚 추가 자료

- `DEEPSLEEP_COMPREHENSIVE_GUIDE.md`: 전체 프로젝트 가이드
- `DEEPSLEEP_CODEBASE.md`: 코드베이스 분석 결과
- Xcode Instruments 프로파일링 가이드
- iOS 26 성능 최적화 Best Practices

---

**작성자**: Claude Code Assistant  
**마지막 업데이트**: 2025년 7월 26일  
**버전**: v2.0.0 (의존성 주입 기반 아키텍처)