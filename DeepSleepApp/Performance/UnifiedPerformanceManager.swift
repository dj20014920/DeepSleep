import Foundation
import UIKit
import Combine

/// 통합 성능 관리자 - 모든 성능 관련 기능을 의존성 주입 방식으로 관리
@MainActor
final class UnifiedPerformanceManager: PerformanceManagerProtocol, ObservableObject {
    
    // MARK: - Dependencies (의존성 주입)
    let batteryManager: BatteryOptimizationProtocol
    let memoryManager: MemoryOptimizationProtocol
    let performanceOptimizer: PerformanceOptimizationProtocol
    let mlOptimizer: MLInferenceOptimizationProtocol
    let backgroundTaskManager: BackgroundTaskManagementProtocol
    
    // MARK: - Published Properties
    @Published var systemStatus: SystemPerformanceStatus?
    @Published var isGlobalOptimizationEnabled = true
    @Published var lastOptimizationTime: Date?
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    private var statusUpdateTimer: Timer?
    private let statusUpdateInterval: TimeInterval = 5.0 // 5초마다 상태 업데이트
    
    // MARK: - Initialization
    init(
        batteryManager: BatteryOptimizationProtocol? = nil,
        memoryManager: MemoryOptimizationProtocol? = nil,
        performanceOptimizer: PerformanceOptimizationProtocol? = nil,
        mlOptimizer: MLInferenceOptimizationProtocol? = nil,
        backgroundTaskManager: BackgroundTaskManagementProtocol? = nil
    ) {
        // 의존성 주입 또는 컨테이너에서 해결
        let container = PerformanceContainer.shared
        
        self.batteryManager = batteryManager ?? 
            container.resolve(type: BatteryOptimizationProtocol.self) ?? 
            BatteryOptimizationManager.shared
            
        self.memoryManager = memoryManager ?? 
            container.resolve(type: MemoryOptimizationProtocol.self) ?? 
            MemoryOptimizationManager.shared
            
        self.performanceOptimizer = performanceOptimizer ?? 
            container.resolve(type: PerformanceOptimizationProtocol.self) ?? 
            PerformanceOptimizer.shared
            
        self.mlOptimizer = mlOptimizer ?? 
            container.resolve(type: MLInferenceOptimizationProtocol.self) ?? 
            MLInferenceOptimizer.shared
            
        self.backgroundTaskManager = backgroundTaskManager ?? 
            container.resolve(type: BackgroundTaskManagementProtocol.self) ?? 
            BackgroundTaskManager.shared
        
        setupPerformanceMonitoring()
        setupAdaptiveOptimization()
        
        UnifiedLogger.shared.info("통합 성능 관리자 초기화 완료", category: .performance)
    }
    
    deinit {
        statusUpdateTimer?.invalidate()
        UnifiedLogger.shared.debug("통합 성능 관리자 정리됨", category: .performance)
    }
    
    // MARK: - Setup Methods
    private func setupPerformanceMonitoring() {
        // 주기적 시스템 상태 업데이트
        statusUpdateTimer = Timer.scheduledTimer(withTimeInterval: statusUpdateInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateSystemStatus()
            }
        }
        
        // 초기 상태 업데이트
        updateSystemStatus()
    }
    
    private func setupAdaptiveOptimization() {
        // 시스템 상태 변화에 따른 자동 최적화
        $systemStatus
            .compactMap { $0 }
            .sink { [weak self] status in
                self?.handleSystemStatusChange(status)
            }
            .store(in: &cancellables)
        
        // 앱 생명주기 이벤트 모니터링
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.handleBackgroundTransition()
                }
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.handleForegroundTransition()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    func optimizeForCurrentConditions() {
        guard isGlobalOptimizationEnabled else {
            UnifiedLogger.shared.info("전역 최적화가 비활성화되어 있음", category: .performance)
            return
        }
        
        performanceOptimizer.startPerformanceMeasurement("optimizeForCurrentConditions")
        
        let status = getSystemStatus()
        
        switch status.performanceLevel {
        case .excellent:
            optimizeForExcellentPerformance()
        case .good:
            optimizeForGoodPerformance()
        case .fair:
            optimizeForFairPerformance()
        case .poor:
            optimizeForPoorPerformance()
        case .critical:
            optimizeForCriticalPerformance()
        }
        
        lastOptimizationTime = Date()
        performanceOptimizer.endPerformanceMeasurement("optimizeForCurrentConditions")
        
        UnifiedLogger.shared.info("현재 조건에 맞는 최적화 완료: \(status.performanceLevel.rawValue)", category: .performance)
    }
    
    func getSystemStatus() -> SystemPerformanceStatus {
        let batteryStatus = batteryManager.getBatteryStatus()
        let memoryStatus = memoryManager.getMemoryStatus()
        let mlOptimizationStatus = mlOptimizer.getOptimizationStatus()
        let backgroundTaskStatus = backgroundTaskManager.getBackgroundTaskStatus()
        
        return SystemPerformanceStatus(
            batteryStatus: batteryStatus,
            memoryStatus: memoryStatus,
            mlOptimizationStatus: mlOptimizationStatus,
            backgroundTaskStatus: backgroundTaskStatus,
            timestamp: Date()
        )
    }
    
    func enableGlobalOptimization(_ enabled: Bool) {
        isGlobalOptimizationEnabled = enabled
        
        if enabled {
            setupPerformanceMonitoring()
            optimizeForCurrentConditions()
        } else {
            statusUpdateTimer?.invalidate()
            statusUpdateTimer = nil
        }
        
        UnifiedLogger.shared.info("전역 최적화 설정: \(enabled)", category: .performance)
    }
    
    // MARK: - Private Optimization Methods
    private func optimizeForExcellentPerformance() {
        // 최고 성능 상태 - 모든 기능 활성화
        mlOptimizer.setPerformanceMode(.maximum)
        backgroundTaskManager.setThrottlingLevel(.none)
        
        UnifiedLogger.shared.debug("우수 성능 최적화 적용", category: .performance)
    }
    
    private func optimizeForGoodPerformance() {
        // 양호한 성능 상태 - 균형 잡힌 설정
        mlOptimizer.setPerformanceMode(.balanced)
        backgroundTaskManager.setThrottlingLevel(.mild)
        
        // 예방적 캐시 정리
        performanceOptimizer.batchOperation(
            identifier: "preventive_cleanup",
            delay: 1.0
        ) { [weak self] in
            self?.memoryManager.requestMemoryOptimization()
        }
        
        UnifiedLogger.shared.debug("양호 성능 최적화 적용", category: .performance)
    }
    
    private func optimizeForFairPerformance() {
        // 보통 성능 상태 - 일부 제한
        mlOptimizer.setPerformanceMode(.efficient)
        backgroundTaskManager.setThrottlingLevel(.moderate)
        
        // 메모리 최적화 요청
        memoryManager.requestMemoryOptimization()
        
        UnifiedLogger.shared.debug("보통 성능 최적화 적용", category: .performance)
    }
    
    private func optimizeForPoorPerformance() {
        // 나쁜 성능 상태 - 적극적 제한
        mlOptimizer.setPerformanceMode(.powerSaver)
        backgroundTaskManager.setThrottlingLevel(.aggressive)
        
        // 배터리 및 메모리 최적화 모두 실행
        batteryManager.requestBatteryOptimization()
        memoryManager.requestMemoryOptimization()
        
        // 캐시 정리
        performanceOptimizer.removeFromCache(key: "non_essential_cache")
        
        UnifiedLogger.shared.warning("저조한 성능으로 인한 적극적 최적화 적용", category: .performance)
    }
    
    private func optimizeForCriticalPerformance() {
        // 위험 성능 상태 - 응급 최적화
        mlOptimizer.setPerformanceMode(.powerSaver)
        backgroundTaskManager.setThrottlingLevel(.aggressive)
        
        // 모든 최적화 기능 실행
        batteryManager.requestBatteryOptimization()
        memoryManager.requestMemoryOptimization()
        
        // 성능 최적화 도구 정리
        performanceOptimizer.cleanup()
        
        /* 사용자에게 위험 상태 알림
        NotificationCenter.default.post(
            name: NSNotification.Name("CriticalPerformanceDetected"),
            object: nil,
            userInfo: ["timestamp": Date()]
        )
        
        UnifiedLogger.shared.critical("위험 성능 상태 - 응급 최적화 실행", category: .performance)*/
    }
    
    // MARK: - Event Handlers
    private func updateSystemStatus() {
        let newStatus = getSystemStatus()
        systemStatus = newStatus
        
        // 성능 수준이 크게 변화했을 때만 로깅
        if let previousStatus = systemStatus,
           previousStatus.performanceLevel != newStatus.performanceLevel {
            UnifiedLogger.shared.info(
                "성능 수준 변화: \(previousStatus.performanceLevel.rawValue) → \(newStatus.performanceLevel.rawValue)",
                category: .performance
            )
        }
    }
    
    private func handleSystemStatusChange(_ status: SystemPerformanceStatus) {
        guard isGlobalOptimizationEnabled else { return }
        
        // 성능 수준에 따른 자동 최적화
        switch status.performanceLevel {
        case .poor, .critical:
            // 성능이 저하된 경우 즉시 최적화
            optimizeForCurrentConditions()
        case .fair:
            // 성능이 보통인 경우 지연된 최적화
            performanceOptimizer.debounce(
                identifier: "auto_optimization",
                delay: 10.0
            ) { [weak self] in
                self?.optimizeForCurrentConditions()
            }
        default:
            // 성능이 양호한 경우 현재 상태 유지
            break
        }
    }
    
    private func handleBackgroundTransition() {
        UnifiedLogger.shared.info("백그라운드 전환 - 성능 최적화 시작", category: .performance)
        
        // 백그라운드에서 적극적 최적화
        mlOptimizer.setPerformanceMode(.powerSaver)
        backgroundTaskManager.setThrottlingLevel(.aggressive)
        memoryManager.requestMemoryOptimization()
        
        // 상태 업데이트 주기 연장
        statusUpdateTimer?.invalidate()
        statusUpdateTimer = Timer.scheduledTimer(withTimeInterval: statusUpdateInterval * 2, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateSystemStatus()
            }
        }
    }
    
    private func handleForegroundTransition() {
        UnifiedLogger.shared.info("포그라운드 전환 - 성능 복원 시작", category: .performance)
        
        // 포그라운드에서 정상 모드 복원
        optimizeForCurrentConditions()
        
        // 정상 상태 업데이트 주기 복원
        statusUpdateTimer?.invalidate()
        statusUpdateTimer = Timer.scheduledTimer(withTimeInterval: statusUpdateInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateSystemStatus()
            }
        }
    }
    
    // MARK: - Performance Analytics
    func getPerformanceAnalytics() -> PerformanceAnalytics {
        guard let status = systemStatus else {
            return PerformanceAnalytics(
                currentScore: 0.0,
                averageScore: 0.0,
                optimizationCount: 0,
                lastOptimizationTime: nil,
                recommendations: ["시스템 상태를 확인할 수 없음"]
            )
        }
        
        let recommendations = generateRecommendations(for: status)
        
        return PerformanceAnalytics(
            currentScore: status.overallHealthScore,
            averageScore: status.overallHealthScore, // 추후 히스토리 추가 시 계산
            optimizationCount: lastOptimizationTime != nil ? 1 : 0, // 추후 카운터 추가
            lastOptimizationTime: lastOptimizationTime,
            recommendations: recommendations
        )
    }
    
    private func generateRecommendations(for status: SystemPerformanceStatus) -> [String] {
        var recommendations: [String] = []
        
        // 배터리 기반 권장사항
        if status.batteryStatus.level < 0.2 {
            recommendations.append("배터리 충전을 권장합니다")
        }
        if status.batteryStatus.isLowPowerMode {
            recommendations.append("저전력 모드가 활성화되어 있습니다")
        }
        
        // 메모리 기반 권장사항
        switch status.memoryStatus.pressureLevel {
        case .high, .critical:
            recommendations.append("메모리 사용량이 높습니다. 앱 재시작을 고려하세요")
        case .medium:
            recommendations.append("메모리 정리가 필요합니다")
        default:
            break
        }
        
        // 전반적 성능 기반 권장사항
        recommendations.append(contentsOf: status.performanceLevel.recommendedActions)
        
        return recommendations
    }
}

// MARK: - Supporting Types
struct PerformanceAnalytics {
    let currentScore: Double
    let averageScore: Double
    let optimizationCount: Int
    let lastOptimizationTime: Date?
    let recommendations: [String]
    
    var currentScorePercentage: Int {
        return Int(currentScore * 100)
    }
    
    var averageScorePercentage: Int {
        return Int(averageScore * 100)
    }
}

// MARK: - 확장을 통한 추가 기능
extension UnifiedPerformanceManager {
    
    /// 성능 히스토리 추적 (추후 구현)
    func enablePerformanceHistoryTracking(_ enabled: Bool) {
        // TODO: 성능 히스토리 데이터베이스 연동
        UnifiedLogger.shared.info("성능 히스토리 추적 설정: \(enabled)", category: .performance)
    }
    
    /// 성능 알림 설정
    func configurePerformanceAlerts(enableCriticalAlerts: Bool, enableRecommendations: Bool) {
        // TODO: 사용자 알림 시스템 연동
        UnifiedLogger.shared.info("성능 알림 설정 완료", category: .performance)
    }
    
    /// 성능 리포트 생성
    func generatePerformanceReport() -> String {
        guard let status = systemStatus else {
            return "성능 데이터를 사용할 수 없습니다."
        }
        
        let analytics = getPerformanceAnalytics()
        
        return """
        === DeepSleep 성능 리포트 ===
        생성 시간: \(Date().formatted())
        
        전체 성능 점수: \(analytics.currentScorePercentage)% (\(status.performanceLevel.rawValue))
        
        배터리 상태: \(status.batteryStatus.description)
        메모리 상태: \(status.memoryStatus.description)
        
        권장사항:
        \(analytics.recommendations.map { "• \($0)" }.joined(separator: "\n"))
        
        === 리포트 종료 ===
        """
    }
}
