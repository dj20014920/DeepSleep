import Foundation
import UIKit
import Combine

// MARK: - 성능 관리 프로토콜 아키텍처
// 2025년 최신 iOS 의존성 주입 기반 설계

/// 배터리 최적화 관리 프로토콜
@MainActor
protocol BatteryOptimizationProtocol: AnyObject {
    var isLowPowerModeEnabled: Bool { get }
    var batteryLevel: Float { get }
    var batteryState: UIDevice.BatteryState { get }
    var thermalState: ProcessInfo.ThermalState { get }
    
    func requestBatteryOptimization()
    func getBatteryStatus() -> BatteryStatus
    func enableAdaptiveOptimization(_ enabled: Bool)
    func enableMLOptimization(_ enabled: Bool)
}

/// 메모리 최적화 관리 프로토콜
@MainActor
protocol MemoryOptimizationProtocol: AnyObject {
    var currentMemoryUsage: UInt64 { get }
    var peakMemoryUsage: UInt64 { get }
    var memoryPressureLevel: MemoryPressureLevel { get }
    var isMemoryWarningActive: Bool { get }
    
    func requestMemoryOptimization()
    func getMemoryStatus() -> MemoryStatus
    func addToImageCache(_ image: UIImage, forKey key: String)
    func getFromImageCache(forKey key: String) -> UIImage?
    func removeFromImageCache(forKey key: String)
    func enableDetailedLogging(_ enabled: Bool)
}

/// 일반 성능 최적화 프로토콜
protocol PerformanceOptimizationProtocol: AnyObject {
    func debounce(identifier: String, delay: TimeInterval, action: @escaping () -> Void)
    func batchOperation(identifier: String, delay: TimeInterval, operation: @escaping () -> Void)
    func resizeImageEfficiently(_ image: UIImage, to targetSize: CGSize) -> UIImage?
    func compressImage(_ image: UIImage, quality: CGFloat) -> Data?
    func cacheData<T>(_ data: T, forKey key: String)
    func getCachedData<T>(forKey key: String, type: T.Type) -> T?
    func removeFromCache(key: String)
    func startPerformanceMeasurement(_ identifier: String)
    func endPerformanceMeasurement(_ identifier: String)
    func cleanup()
}

/// ML 추론 최적화 프로토콜
protocol MLInferenceOptimizationProtocol: AnyObject {
    func setPerformanceMode(_ mode: MLInferenceOptimizer.PerformanceMode)
    func getCurrentMode() -> MLInferenceOptimizer.PerformanceMode
    func getOptimizationStatus() -> [String: Any]
}

/// 백그라운드 작업 관리 프로토콜
protocol BackgroundTaskManagementProtocol: AnyObject {
    func setThrottlingLevel(_ level: BackgroundTaskManager.ThrottlingLevel)
    func scheduleBackgroundTask(type: BackgroundTaskManager.BackgroundTaskType, task: @escaping () -> Void) -> Bool
    func getCurrentThrottlingLevel() -> BackgroundTaskManager.ThrottlingLevel
    func getBackgroundTaskStatus() -> [String: Any]
    func restoreAllBackgroundTasks()
}

// MARK: - 통합 성능 관리자 프로토콜
/// 모든 성능 관리 기능을 통합하는 메인 프로토콜
@MainActor
protocol PerformanceManagerProtocol: AnyObject {
    var batteryManager: BatteryOptimizationProtocol { get }
    var memoryManager: MemoryOptimizationProtocol { get }
    var performanceOptimizer: PerformanceOptimizationProtocol { get }
    var mlOptimizer: MLInferenceOptimizationProtocol { get }
    var backgroundTaskManager: BackgroundTaskManagementProtocol { get }
    
    func optimizeForCurrentConditions()
    func getSystemStatus() -> SystemPerformanceStatus
    func enableGlobalOptimization(_ enabled: Bool)
}

// MARK: - 시스템 성능 상태
struct SystemPerformanceStatus {
    let batteryStatus: BatteryStatus
    let memoryStatus: MemoryStatus
    let mlOptimizationStatus: [String: Any]
    let backgroundTaskStatus: [String: Any]
    let timestamp: Date
    
    var overallHealthScore: Double {
        var score = 1.0
        
        // 배터리 상태 반영 (40%)
        let batteryScore = min(1.0, Double(batteryStatus.level))
        score *= (0.6 + 0.4 * batteryScore)
        
        // 메모리 상태 반영 (30%)
        let memoryScore: Double = {
            switch memoryStatus.pressureLevel {
            case .normal: return 1.0
            case .medium: return 0.7
            case .high: return 0.4
            case .critical: return 0.1
            }
        }()
        score *= (0.7 + 0.3 * memoryScore)
        
        // 메모리 경고 활성화 시 추가 감점 (30%)
        if memoryStatus.isWarningActive {
            score *= 0.5
        }
        
        return max(0.0, min(1.0, score))
    }
    
    var performanceLevel: PerformanceLevel {
        switch overallHealthScore {
        case 0.8...1.0: return .excellent
        case 0.6..<0.8: return .good
        case 0.4..<0.6: return .fair
        case 0.2..<0.4: return .poor
        default: return .critical
        }
    }
}

enum PerformanceLevel: String, CaseIterable {
    case excellent = "우수"
    case good = "양호"
    case fair = "보통"
    case poor = "나쁨"
    case critical = "위험"
    
    var color: UIColor {
        switch self {
        case .excellent: return .systemGreen
        case .good: return .systemBlue
        case .fair: return .systemYellow
        case .poor: return .systemOrange
        case .critical: return .systemRed
        }
    }
    
    var recommendedActions: [String] {
        switch self {
        case .excellent:
            return ["모든 기능 정상 작동", "성능 모니터링 지속"]
        case .good:
            return ["현재 상태 유지", "정기적 캐시 정리 권장"]
        case .fair:
            return ["비필수 기능 제한", "메모리 사용량 확인"]
        case .poor:
            return ["백그라운드 작업 제한", "AI 기능 일시 중단"]
        case .critical:
            return ["응급 최적화 실행", "앱 재시작 권장"]
        }
    }
}

// MARK: - 의존성 주입 컨테이너
/// 성능 관리 의존성 주입 컨테이너
final class PerformanceContainer {
    static let shared = PerformanceContainer()
    
    private var registrations: [String: () -> Any] = [:]
    private var singletonInstances: [String: Any] = [:]
    
    private init() {}
    
    /// 서비스 등록 (Singleton)
    func register<T>(type: T.Type, factory: @escaping () -> T) {
        let key = String(describing: type)
        registrations[key] = factory
    }
    
    /// 서비스 등록 (Transient)
    func registerTransient<T>(type: T.Type, factory: @escaping () -> T) {
        let key = String(describing: type) + "_transient"
        registrations[key] = factory
    }
    
    /// 서비스 해결 (Singleton)
    func resolve<T>(type: T.Type) -> T? {
        let key = String(describing: type)
        
        // 싱글톤 인스턴스가 이미 있으면 반환
        if let instance = singletonInstances[key] as? T {
            return instance
        }
        
        // 새 인스턴스 생성 및 캐시
        guard let factory = registrations[key] else {
            UnifiedLogger.shared.error("서비스 등록되지 않음: \(key)", category: .system)
            return nil
        }
        
        let instance = factory() as! T
        singletonInstances[key] = instance
        return instance
    }
    
    /// 서비스 해결 (Transient)
    func resolveTransient<T>(type: T.Type) -> T? {
        let key = String(describing: type) + "_transient"
        
        guard let factory = registrations[key] else {
            UnifiedLogger.shared.error("Transient 서비스 등록되지 않음: \(key)", category: .system)
            return nil
        }
        
        return factory() as? T
    }
    
    /// 등록된 모든 서비스 초기화
    func reset() {
        singletonInstances.removeAll()
        registrations.removeAll()
        UnifiedLogger.shared.info("성능 관리 의존성 컨테이너 초기화 완료", category: .system)
    }
    
    /// 컨테이너 상태 확인
    func getRegistrationStatus() -> [String: String] {
        var status: [String: String] = [:]
        
        for (key, _) in registrations {
            let hasInstance = singletonInstances[key] != nil
            status[key] = hasInstance ? "인스턴스 생성됨" : "등록됨"
        }
        
        return status
    }
}

// MARK: - 성능 관리 팩토리
/// 성능 관리 객체들을 생성하는 팩토리
enum PerformanceManagerFactory {
    
    /// 기본 성능 관리자 구성 설정
    static func setupDefaultConfiguration() {
        let container = PerformanceContainer.shared
        
        // 각 프로토콜의 구현체 등록
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
        
        // UnifiedPerformanceManager는 @MainActor이므로 직접 생성하지 않고
        // PerformanceSystemBootstrap에서 생성하도록 함
        // container.register는 createUnifiedPerformanceManager에서 처리됨
        
        UnifiedLogger.shared.info("성능 관리 의존성 설정 완료", category: .system)
    }
    
    /// 테스트용 Mock 구성 설정
    static func setupTestConfiguration() {
        let container = PerformanceContainer.shared
        container.reset()
        
        // Mock 객체들 등록 (테스트용)
        // 추후 테스트 Mock 객체들 구현 시 여기에 추가
        
        UnifiedLogger.shared.info("테스트용 성능 관리 의존성 설정 완료", category: .system)
    }
}