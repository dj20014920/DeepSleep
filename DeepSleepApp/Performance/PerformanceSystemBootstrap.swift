import Foundation
import UIKit

/// 성능 관리 시스템 부트스트랩 - 앱 시작 시 초기화
final class PerformanceSystemBootstrap {
    
    static let shared = PerformanceSystemBootstrap()
    private var isInitialized = false
    private var performanceManager: UnifiedPerformanceManager?
    
    private init() {}
    
    // MARK: - Public Interface
    
    /// 성능 관리 시스템 초기화 (AppDelegate에서 호출)
    func initializePerformanceSystem() {
        guard !isInitialized else {
            UnifiedLogger.shared.warning("성능 관리 시스템이 이미 초기화됨", category: .system)
            return
        }
        
        Task { @MainActor in
            await performInitializationSequence()
            isInitialized = true
            
            // 성능 관리 시스템 초기화 완료
        }
    }
    
    /// 초기화된 성능 관리자 반환
    func getPerformanceManager() -> UnifiedPerformanceManager? {
        guard isInitialized else {
            UnifiedLogger.shared.error("성능 관리 시스템이 초기화되지 않음. initializePerformanceSystem() 호출 필요", category: .system)
            return nil
        }
        return performanceManager
    }
    
    /// 성능 관리 시스템 종료 (앱 종료 시 호출)
    func shutdownPerformanceSystem() {
        guard isInitialized else { return }
        
        performShutdownSequence()
        isInitialized = false
        performanceManager = nil
        
        UnifiedLogger.shared.info("성능 관리 시스템 종료 완료", category: .system)
    }
    
    // MARK: - Private Implementation
    
    @MainActor
    private func performInitializationSequence() async {
        // 성능 관리 시스템 초기화 시작
        
        // 1단계: 의존성 컨테이너 설정
        setupDependencyContainer()
        
        // 2단계: 프로토콜 구현체 등록
        registerImplementations()
        
        // 3단계: 통합 성능 관리자 생성
        createUnifiedPerformanceManager()
        
        // 4단계: 시스템 상태 검증
        validateSystemIntegrity()
        
        // 5단계: 초기 최적화 실행
        performInitialOptimization()
        
        // 6단계: 이벤트 리스너 설정
        setupEventListeners()
    }
    
    private func setupDependencyContainer() {
        PerformanceManagerFactory.setupDefaultConfiguration()
        UnifiedLogger.shared.debug("의존성 컨테이너 설정 완료", category: .system)
    }
    
    private func registerImplementations() {
        let container = PerformanceContainer.shared
        
        // 기존 싱글톤들을 컨테이너에 등록
        container.register(type: BatteryOptimizationProtocol.self) {
            BatteryOptimizationManager.shared
        }
        
        container.register(type: MemoryOptimizationProtocol.self) {
            MemoryOptimizationManager.shared
        }
        
        container.register(type: PerformanceOptimizationProtocol.self) {
            PerformanceOptimizer.shared
        }
        
        container.register(type: MLInferenceOptimizationProtocol.self) {
            MLInferenceOptimizer.shared
        }
        
        container.register(type: BackgroundTaskManagementProtocol.self) {
            BackgroundTaskManager.shared
        }
        
        UnifiedLogger.shared.debug("프로토콜 구현체 등록 완료", category: .system)
    }
    
    @MainActor
    private func createUnifiedPerformanceManager() {
        let container = PerformanceContainer.shared
        
        guard let batteryManager = container.resolve(type: BatteryOptimizationProtocol.self),
              let memoryManager = container.resolve(type: MemoryOptimizationProtocol.self),
              let performanceOptimizer = container.resolve(type: PerformanceOptimizationProtocol.self),
              let mlOptimizer = container.resolve(type: MLInferenceOptimizationProtocol.self),
              let backgroundTaskManager = container.resolve(type: BackgroundTaskManagementProtocol.self) else {
            
            UnifiedLogger.shared.error("의존성 해결 실패", category: .system)
            fatalError("성능 관리 시스템 초기화 실패: 의존성 해결 불가")
        }
        
        let manager = UnifiedPerformanceManager(
            batteryManager: batteryManager,
            memoryManager: memoryManager,
            performanceOptimizer: performanceOptimizer,
            mlOptimizer: mlOptimizer,
            backgroundTaskManager: backgroundTaskManager
        )
        self.performanceManager = manager
        
        // 생성 완료 후 컨테이너에 등록
        container.register(type: PerformanceManagerProtocol.self) {
            manager
        }
        
        UnifiedLogger.shared.debug("통합 성능 관리자 생성 및 등록 완료", category: .system)
    }
    
    @MainActor
    private func validateSystemIntegrity() {
        guard let manager = performanceManager else {
            UnifiedLogger.shared.error("성능 관리자가 생성되지 않음", category: .system)
            return
        }
        
        // 각 구성 요소의 상태 확인
        let status = manager.getSystemStatus()
            
            let validationResults = [
                "배터리 관리자": status.batteryStatus.level >= 0,
                "메모리 관리자": status.memoryStatus.currentUsage > 0,
                "ML 최적화": !status.mlOptimizationStatus.isEmpty,
                "백그라운드 작업": !status.backgroundTaskStatus.isEmpty
            ]
            
            let failedComponents = validationResults.filter { !$0.value }.map { $0.key }
            
            if failedComponents.isEmpty {
                UnifiedLogger.shared.info("✅ 시스템 무결성 검증 완료", category: .system)
            } else {
                UnifiedLogger.shared.warning("⚠️ 시스템 검증 실패: \(failedComponents.joined(separator: ", "))", category: .system)
            }
        }
    
    private func performInitialOptimization() {
        guard let manager = performanceManager else { return }
        
        Task { @MainActor in
            // 현재 조건에 맞는 초기 최적화 실행
            manager.optimizeForCurrentConditions()
            
            // 전역 최적화 활성화
            manager.enableGlobalOptimization(true)
        }
        
        UnifiedLogger.shared.debug("초기 최적화 실행 완료", category: .system)
    }
    
    private func setupEventListeners() {
        // 앱 생명주기 이벤트 리스너
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleAppBackgrounding()
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: UIApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleAppTermination()
        }
        
        // 메모리 경고 리스너
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleMemoryWarning()
            }
        }
        
        // 배터리 상태 변화 리스너
        NotificationCenter.default.addObserver(
            forName: .NSProcessInfoPowerStateDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handlePowerStateChange()
            }
        }
        
        UnifiedLogger.shared.debug("이벤트 리스너 설정 완료", category: .system)
    }
    
    private func performShutdownSequence() {
        UnifiedLogger.shared.info("성능 관리 시스템 종료 시작...", category: .system)
        
        // 1. 이벤트 리스너 제거
        NotificationCenter.default.removeObserver(self)
        
        // 2. 성능 최적화 도구 정리
        if let manager = performanceManager {
            Task { @MainActor in
                manager.enableGlobalOptimization(false)
            }
        }
        
        // 3. 의존성 컨테이너 초기화
        PerformanceContainer.shared.reset()
        
        UnifiedLogger.shared.info("성능 관리 시스템 종료 완료", category: .system)
    }
    
    // MARK: - Event Handlers
    
    @MainActor
    private func handleAppBackgrounding() {
        UnifiedLogger.shared.info("앱 백그라운드 이벤트 - 성능 최적화 모드 활성화", category: .system)
        
        guard let manager = performanceManager else { return }
        
        // 백그라운드 최적화 실행
        manager.optimizeForCurrentConditions()
    }
    
    private func handleAppTermination() {
        UnifiedLogger.shared.info("앱 종료 이벤트 - 리소스 정리 시작", category: .system)
        self.shutdownPerformanceSystem()
    }
    
    @MainActor
    private func handleMemoryWarning() {
        UnifiedLogger.shared.warning("메모리 경고 이벤트 - 긴급 최적화 실행", category: .system)
        
        guard let manager = performanceManager else { return }
        
        // 즉시 메모리 최적화
        manager.memoryManager.requestMemoryOptimization()
        manager.optimizeForCurrentConditions()
    }
    
    @MainActor
    private func handlePowerStateChange() {
        UnifiedLogger.shared.info("전원 상태 변화 이벤트 - 배터리 최적화 실행", category: .system)
        
        guard let manager = performanceManager else { return }
        
        // 배터리 상태에 따른 최적화
        manager.batteryManager.requestBatteryOptimization()
        manager.optimizeForCurrentConditions()
    }
    
    // MARK: - Debugging & Diagnostics
    
    /// 시스템 진단 정보 출력 (개발용)
    @MainActor
    func printSystemDiagnostics() {
        guard let manager = performanceManager else {
            print("❌ 성능 관리자가 초기화되지 않음")
            return
        }
        
        let status = manager.getSystemStatus()
        let analytics = manager.getPerformanceAnalytics()
        
        print("""
        
        === DeepSleep 성능 관리 시스템 진단 ===
        초기화 상태: \(isInitialized ? "✅" : "❌")
        시스템 점수: \(analytics.currentScorePercentage)%
        성능 수준: \(status.performanceLevel.rawValue)
        
        배터리: \(status.batteryStatus.levelPercentage)% (\(status.batteryStatus.state.description))
        메모리: \(String(format: "%.1f", status.memoryStatus.currentUsageMB))MB (\(status.memoryStatus.pressureLevel.description))
        
        권장사항:
        \(analytics.recommendations.map { "• \($0)" }.joined(separator: "\n"))
        ========================================
        
        """)
    }
}

// MARK: - 편의 확장
extension PerformanceSystemBootstrap {
    
    /// 빠른 성능 최적화 (다른 곳에서 호출 가능)
    @MainActor
    static func quickOptimize() {
        shared.getPerformanceManager()?.optimizeForCurrentConditions()
    }
    
    /// 현재 성능 상태 확인
    @MainActor
    static func getCurrentPerformanceLevel() -> PerformanceLevel? {
        return shared.getPerformanceManager()?.getSystemStatus().performanceLevel
    }
    
    /// 성능 리포트 생성
    @MainActor
    static func generateReport() -> String? {
        return shared.getPerformanceManager()?.generatePerformanceReport()
    }
}

