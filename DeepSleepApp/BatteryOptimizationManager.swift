import Foundation
import UIKit
import Combine
import CoreML
import UserNotifications

/// 2025년 최신 iOS 배터리 최적화 관리자
/// iOS 26 기준 최신 배터리 효율성 기법 적용
@MainActor
final class BatteryOptimizationManager: ObservableObject, BatteryOptimizationProtocol {
    static let shared = BatteryOptimizationManager()
    
    // MARK: - Properties
    @Published var isLowPowerModeEnabled = false
    @Published var batteryLevel: Float = 1.0
    @Published var batteryState: UIDevice.BatteryState = .unknown
    @Published var thermalState: ProcessInfo.ThermalState = .nominal
    
    private var cancellables = Set<AnyCancellable>()
    
    // 2025년 최신 배터리 관리 설정
    private var adaptiveThrottling = true
    private var intelligentBackgroundTasking = true
    private var thermalThrottling = true
    private var mlInferenceOptimization = true
    
    // MARK: - Initialization
    private init() {
        setupBatteryMonitoring()
        setupThermalMonitoring()
        configureAdaptiveSettings()
    }
    
    // MARK: - Setup Methods
    private func setupBatteryMonitoring() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        
        // 배터리 상태 모니터링
        NotificationCenter.default.publisher(for: UIDevice.batteryStateDidChangeNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.updateBatteryState()
                }
            }
            .store(in: &cancellables)
        
        // 배터리 레벨 모니터링
        NotificationCenter.default.publisher(for: UIDevice.batteryLevelDidChangeNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.updateBatteryLevel()
                }
            }
            .store(in: &cancellables)
        
        // Low Power Mode 모니터링
        NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.updatePowerState()
                }
            }
            .store(in: &cancellables)
        
        // 초기 상태 설정
        updateBatteryState()
        updateBatteryLevel()
        updatePowerState()
    }
    
    private func setupThermalMonitoring() {
        // 열 상태 모니터링 (iOS 26 개선)
        NotificationCenter.default.publisher(for: ProcessInfo.thermalStateDidChangeNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.updateThermalState()
                }
            }
            .store(in: &cancellables)
        
        updateThermalState()
    }
    
    private func configureAdaptiveSettings() {
        // 배터리 상태에 따른 적응형 설정
        $batteryLevel
            .combineLatest($isLowPowerModeEnabled, $thermalState)
            .sink { [weak self] batteryLevel, isLowPower, thermal in
                self?.adaptSystemPerformance(
                    batteryLevel: batteryLevel,
                    isLowPower: isLowPower,
                    thermalState: thermal
                )
            }
            .store(in: &cancellables)
    }
    
    // MARK: - State Updates
    private func updateBatteryState() {
        batteryState = UIDevice.current.batteryState
        // 배터리 상태 업데이트됨
    }
    
    private func updateBatteryLevel() {
        batteryLevel = UIDevice.current.batteryLevel
        // 배터리 레벨 업데이트됨
    }
    
    private func updatePowerState() {
        isLowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled
        UnifiedLogger.shared.debug("Low Power Mode: \(self.isLowPowerModeEnabled)", category: .system)
    }
    
    private func updateThermalState() {
        thermalState = ProcessInfo.processInfo.thermalState
        UnifiedLogger.shared.debug("Thermal State: \(self.thermalState.description)", category: .system)
    }
    
    // MARK: - Adaptive Performance Management
    private func adaptSystemPerformance(
        batteryLevel: Float,
        isLowPower: Bool,
        thermalState: ProcessInfo.ThermalState
    ) {
        let optimizationLevel = calculateOptimizationLevel(
            batteryLevel: batteryLevel,
            isLowPower: isLowPower,
            thermalState: thermalState
        )
        
        applyOptimizations(level: optimizationLevel)
    }
    
    private func calculateOptimizationLevel(
        batteryLevel: Float,
        isLowPower: Bool,
        thermalState: ProcessInfo.ThermalState
    ) -> OptimizationLevel {
        // 2025년 최신 적응형 알고리즘
        if isLowPower || batteryLevel < 0.15 {
            return .aggressive
        }
        
        if thermalState == .critical || thermalState == .serious {
            return .aggressive
        }
        
        if batteryLevel < 0.30 || thermalState == .fair {
            return .moderate
        }
        
        if batteryLevel < 0.50 {
            return .mild
        }
        
        return .none
    }
    
    private func applyOptimizations(level: OptimizationLevel) {
        
        switch level {
        case .none:
            configureFullPerformance()
        case .mild:
            configureMildOptimization()
        case .moderate:
            configureModerateOptimization()
        case .aggressive:
            configureAggressiveOptimization()
        }
    }
    
    // MARK: - Optimization Configurations
    private func configureFullPerformance() {
        // 최고 성능 모드
        MLInferenceOptimizer.shared.setPerformanceMode(.maximum)
        BackgroundTaskManager.shared.setThrottlingLevel(.none)
        // TODO: SoundManager.shared.setQualityLevel(.high)
    }
    
    private func configureMildOptimization() {
        // 경미한 최적화
        MLInferenceOptimizer.shared.setPerformanceMode(.balanced)
        BackgroundTaskManager.shared.setThrottlingLevel(.mild)
        // TODO: SoundManager.shared.setQualityLevel(.medium)
    }
    
    private func configureModerateOptimization() {
        // 중간 최적화
        MLInferenceOptimizer.shared.setPerformanceMode(.efficient)
        BackgroundTaskManager.shared.setThrottlingLevel(.moderate)
        // TODO: SoundManager.shared.setQualityLevel(.medium)
        
        // AI 추론 빈도 감소
        if mlInferenceOptimization {
            disableNonEssentialAIFeatures()
        }
    }
    
    private func configureAggressiveOptimization() {
        // 적극적 최적화
        MLInferenceOptimizer.shared.setPerformanceMode(.powerSaver)
        BackgroundTaskManager.shared.setThrottlingLevel(.aggressive)
        // TODO: SoundManager.shared.setQualityLevel(.low)
        
        // 대부분의 AI 기능 일시 중단
        disableNonEssentialAIFeatures()
        
        // 백그라운드 작업 최소화
        suspendNonCriticalBackgroundTasks()
    }
    
    // MARK: - Feature Management
    private func disableNonEssentialAIFeatures() {
        // AI 기능 선택적 비활성화 구현
        
        // 사용자 설정을 통한 AI 기능 제한
        UserDefaults.standard.set(true, forKey: "battery_optimization_mode")
        UserDefaults.standard.set(false, forKey: "real_time_analysis_enabled")
        UserDefaults.standard.set(false, forKey: "background_ml_inference_enabled")
        
        // 분석 빈도 감소 설정
        UserDefaults.standard.set(60.0, forKey: "analysis_update_interval") // 60초로 증가
        
        // 백그라운드 작업 제한 플래그 설정
        UserDefaults.standard.set(true, forKey: "limit_background_ai_processing")
        
    }
    
    private func suspendNonCriticalBackgroundTasks() {
        // 백그라운드 작업 일시 중단 구현
        
        // 자동 백업 일시 중단
        UserDefaults.standard.set(false, forKey: "auto_backup_enabled_temp")
        
        // 로그 업로드 지연 설정
        UserDefaults.standard.set(true, forKey: "defer_log_uploading")
        
        // 캐시 정리 작업 연기
        UserDefaults.standard.set(true, forKey: "defer_cache_maintenance")
        
        // 피드백 수집 최소화
        UserDefaults.standard.set(true, forKey: "minimal_feedback_collection")
        
        // 네트워크 사용 제한
        UserDefaults.standard.set(false, forKey: "allow_cellular_data")
        
    }
    
    private func restoreFullFunctionality() {
        // 전체 기능 복원
        
        // AI 기능 복원 설정
        UserDefaults.standard.set(false, forKey: "battery_optimization_mode")
        UserDefaults.standard.set(true, forKey: "real_time_analysis_enabled")
        UserDefaults.standard.set(true, forKey: "background_ml_inference_enabled")
        
        // 분석 빈도 정상화
        UserDefaults.standard.set(15.0, forKey: "analysis_update_interval") // 15초로 복원
        
        // 백그라운드 작업 제한 해제
        UserDefaults.standard.set(false, forKey: "limit_background_ai_processing")
        
        // 백그라운드 작업 복원
        UserDefaults.standard.removeObject(forKey: "auto_backup_enabled_temp")
        UserDefaults.standard.set(false, forKey: "defer_log_uploading")
        UserDefaults.standard.set(false, forKey: "defer_cache_maintenance")
        UserDefaults.standard.set(false, forKey: "minimal_feedback_collection")
        
        // 네트워크 설정 복원
        UserDefaults.standard.set(true, forKey: "allow_cellular_data")
        
    }
    
    // MARK: - Public Methods
    func requestBatteryOptimization() {
        
        let currentLevel = calculateOptimizationLevel(
            batteryLevel: batteryLevel,
            isLowPower: isLowPowerModeEnabled,
            thermalState: thermalState
        )
        
        applyOptimizations(level: currentLevel)
    }
    
    func getBatteryStatus() -> BatteryStatus {
        return BatteryStatus(
            level: batteryLevel,
            state: batteryState,
            isLowPowerMode: isLowPowerModeEnabled,
            thermalState: thermalState,
            optimizationLevel: calculateOptimizationLevel(
                batteryLevel: batteryLevel,
                isLowPower: isLowPowerModeEnabled,
                thermalState: thermalState
            )
        )
    }
    
    func enableAdaptiveOptimization(_ enabled: Bool) {
        adaptiveThrottling = enabled
        UnifiedLogger.shared.info("적응형 최적화: \(enabled)", category: .system)
    }
    
    func enableMLOptimization(_ enabled: Bool) {
        mlInferenceOptimization = enabled
        UnifiedLogger.shared.info("ML 추론 최적화: \(enabled)", category: .ai)
    }
}

// MARK: - Supporting Types
enum OptimizationLevel: String, CaseIterable {
    case none = "없음"
    case mild = "경미"
    case moderate = "중간"
    case aggressive = "적극적"
}

struct BatteryStatus {
    let level: Float
    let state: UIDevice.BatteryState
    let isLowPowerMode: Bool
    let thermalState: ProcessInfo.ThermalState
    let optimizationLevel: OptimizationLevel
    
    var levelPercentage: Int {
        return Int(level * 100)
    }
    
    var description: String {
        return "배터리 \(levelPercentage)%, \(optimizationLevel.rawValue) 최적화"
    }
}

// MARK: - Extensions
extension UIDevice.BatteryState {
    var description: String {
        switch self {
        case .unknown: return "알 수 없음"
        case .unplugged: return "연결되지 않음"
        case .charging: return "충전 중"
        case .full: return "완충"
        @unknown default: return "알 수 없음"
        }
    }
}

extension ProcessInfo.ThermalState {
    var description: String {
        switch self {
        case .nominal: return "정상"
        case .fair: return "보통"
        case .serious: return "심각"
        case .critical: return "위험"
        @unknown default: return "알 수 없음"
        }
    }
}

// MARK: - Placeholder Classes
// 실제 ML 추론 최적화 관리자 구현
class MLInferenceOptimizer: MLInferenceOptimizationProtocol {
    static let shared = MLInferenceOptimizer()
    private init() {}
    
    private var currentMode: PerformanceMode = .balanced
    private var inferenceQueue = DispatchQueue(label: "ml.inference.optimization", qos: .utility)
    private var isOptimizationActive = false
    
    enum PerformanceMode {
        case maximum, balanced, efficient, powerSaver
        
        var description: String {
            switch self {
            case .maximum: return "최대 성능"
            case .balanced: return "균형"
            case .efficient: return "효율적"
            case .powerSaver: return "전력 절약"
            }
        }
        
        var cpuUsageLimit: Double {
            switch self {
            case .maximum: return 1.0
            case .balanced: return 0.7
            case .efficient: return 0.5
            case .powerSaver: return 0.3
            }
        }
        
        var batchSize: Int {
            switch self {
            case .maximum: return 32
            case .balanced: return 16
            case .efficient: return 8
            case .powerSaver: return 4
            }
        }
        
        var inferenceInterval: TimeInterval {
            switch self {
            case .maximum: return 0.1
            case .balanced: return 0.5
            case .efficient: return 1.0
            case .powerSaver: return 2.0
            }
        }
    }
    
    func setPerformanceMode(_ mode: PerformanceMode) {
        inferenceQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.currentMode = mode
            self.applyPerformanceSettings(mode)
            
            DispatchQueue.main.async {
            }
        }
    }
    
    private func applyPerformanceSettings(_ mode: PerformanceMode) {
        // 1. CPU 사용량 제한 설정
        setCPUUsageLimit(mode.cpuUsageLimit)
        
        // 2. 배치 크기 조정
        setBatchSize(mode.batchSize)
        
        // 3. 추론 간격 조정
        setInferenceInterval(mode.inferenceInterval)
        
        // 4. 메모리 사용 최적화
        configureMemoryOptimization(for: mode)
        
        // 5. 코어 ML 설정 최적화
        configureCoreMLSettings(for: mode)
    }
    
    private func setCPUUsageLimit(_ limit: Double) {
        // CPU 사용률 제한 적용
        let processInfo = ProcessInfo.processInfo
        
        // QoS 클래스 조정
        switch limit {
        case 0.9...1.0:
            // 최대 성능 - userInitiated
            UserDefaults.standard.set("userInitiated", forKey: "ml_inference_qos")
        case 0.6...0.9:
            // 균형 - default
            UserDefaults.standard.set("default", forKey: "ml_inference_qos")
        case 0.4...0.6:
            // 효율적 - utility
            UserDefaults.standard.set("utility", forKey: "ml_inference_qos")
        default:
            // 전력 절약 - background
            UserDefaults.standard.set("background", forKey: "ml_inference_qos")
        }
        
        UserDefaults.standard.set(limit, forKey: "ml_cpu_usage_limit")
    }
    
    private func setBatchSize(_ size: Int) {
        UserDefaults.standard.set(size, forKey: "ml_batch_size")
        
        // 메모리 프레셔에 따른 추가 조정
        let memoryPressure = getMemoryPressure()
        let adjustedBatchSize = size / max(1, memoryPressure)
        
        UserDefaults.standard.set(adjustedBatchSize, forKey: "ml_adjusted_batch_size")
    }
    
    private func setInferenceInterval(_ interval: TimeInterval) {
        UserDefaults.standard.set(interval, forKey: "ml_inference_interval")
        
        // 타이머 기반 추론 간격 조정
        NotificationCenter.default.post(
            name: NSNotification.Name("MLInferenceIntervalChanged"),
            object: nil,
            userInfo: ["interval": interval]
        )
    }
    
    private func configureMemoryOptimization(for mode: PerformanceMode) {
        switch mode {
        case .maximum:
            // 메모리 사용량 제한 없음
            UserDefaults.standard.set(false, forKey: "ml_memory_optimization_enabled")
            UserDefaults.standard.set(0.9, forKey: "ml_memory_usage_limit")
            
        case .balanced:
            // 적당한 메모리 최적화
            UserDefaults.standard.set(true, forKey: "ml_memory_optimization_enabled")
            UserDefaults.standard.set(0.7, forKey: "ml_memory_usage_limit")
            
        case .efficient:
            // 적극적 메모리 최적화
            UserDefaults.standard.set(true, forKey: "ml_memory_optimization_enabled")
            UserDefaults.standard.set(0.5, forKey: "ml_memory_usage_limit")
            UserDefaults.standard.set(true, forKey: "ml_aggressive_cache_cleanup")
            
        case .powerSaver:
            // 최대 메모리 절약
            UserDefaults.standard.set(true, forKey: "ml_memory_optimization_enabled")
            UserDefaults.standard.set(0.3, forKey: "ml_memory_usage_limit")
            UserDefaults.standard.set(true, forKey: "ml_aggressive_cache_cleanup")
            UserDefaults.standard.set(true, forKey: "ml_minimize_model_loading")
        }
    }
    
    private func configureCoreMLSettings(for mode: PerformanceMode) {
        // Core ML 컴퓨팅 유닛 설정
        switch mode {
        case .maximum:
            UserDefaults.standard.set("all", forKey: "coreml_compute_units") // CPU + GPU + Neural Engine
            
        case .balanced:
            UserDefaults.standard.set("cpuAndGPU", forKey: "coreml_compute_units") // CPU + GPU
            
        case .efficient:
            UserDefaults.standard.set("cpuOnly", forKey: "coreml_compute_units") // CPU만
            
        case .powerSaver:
            UserDefaults.standard.set("cpuOnly", forKey: "coreml_compute_units") // CPU만
            UserDefaults.standard.set(true, forKey: "coreml_reduce_precision") // 정밀도 감소
        }
    }
    
    private func getMemoryPressure() -> Int {
        // 메모리 압박 수준 계산 (1-4)
        let physicalMemory = ProcessInfo.processInfo.physicalMemory
        let memoryUsage = getMemoryUsage()
        
        let usageRatio = Double(memoryUsage) / Double(physicalMemory)
        
        switch usageRatio {
        case 0.0..<0.5: return 1
        case 0.5..<0.7: return 2
        case 0.7..<0.85: return 3
        default: return 4
        }
    }
    
    private func getMemoryUsage() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return info.resident_size
        } else {
            return 0
        }
    }
    
    func getCurrentMode() -> PerformanceMode {
        return currentMode
    }
    
    func getOptimizationStatus() -> [String: Any] {
        return [
            "mode": currentMode.description,
            "cpu_limit": currentMode.cpuUsageLimit,
            "batch_size": currentMode.batchSize,
            "inference_interval": currentMode.inferenceInterval,
            "memory_pressure": getMemoryPressure(),
            "is_active": isOptimizationActive
        ]
    }
}

class BackgroundTaskManager: BackgroundTaskManagementProtocol {
    static let shared = BackgroundTaskManager()
    private init() {}
    
    private var currentThrottlingLevel: ThrottlingLevel = .none
    private var suspendedTasks: Set<String> = []
    private var taskQueue = DispatchQueue(label: "background.task.management", qos: .utility)
    private var activeBackgroundTasks: [UIBackgroundTaskIdentifier] = []
    
    enum ThrottlingLevel {
        case none, mild, moderate, aggressive
        
        var description: String {
            switch self {
            case .none: return "제한 없음"
            case .mild: return "경미한 제한"
            case .moderate: return "중간 제한"
            case .aggressive: return "적극적 제한"
            }
        }
        
        var maxConcurrentTasks: Int {
            switch self {
            case .none: return 10
            case .mild: return 6
            case .moderate: return 3
            case .aggressive: return 1
            }
        }
        
        var taskTimeLimit: TimeInterval {
            switch self {
            case .none: return 30.0
            case .mild: return 20.0
            case .moderate: return 10.0
            case .aggressive: return 5.0
            }
        }
        
        var allowedTaskTypes: [BackgroundTaskType] {
            switch self {
            case .none:
                return [.dataSync, .analytics, .cacheCleanup, .backup, .logUpload, .feedbackCollection]
            case .mild:
                return [.dataSync, .analytics, .cacheCleanup, .backup]
            case .moderate:
                return [.dataSync, .cacheCleanup]
            case .aggressive:
                return [.dataSync]
            }
        }
    }
    
    enum BackgroundTaskType: String, CaseIterable {
        case dataSync = "data_sync"
        case analytics = "analytics"
        case cacheCleanup = "cache_cleanup"
        case backup = "backup"
        case logUpload = "log_upload"
        case feedbackCollection = "feedback_collection"
        
        var priority: Int {
            switch self {
            case .dataSync: return 1
            case .backup: return 2
            case .cacheCleanup: return 3
            case .analytics: return 4
            case .logUpload: return 5
            case .feedbackCollection: return 6
            }
        }
    }
    
    func setThrottlingLevel(_ level: ThrottlingLevel) {
        taskQueue.async { [weak self] in
            guard let self = self else { return }
            
            let previousLevel = self.currentThrottlingLevel
            self.currentThrottlingLevel = level
            
            self.applyThrottlingSettings(level)
            
            DispatchQueue.main.async {
            }
        }
    }
    
    private func applyThrottlingSettings(_ level: ThrottlingLevel) {
        // 1. 현재 실행 중인 작업 검토 및 조정
        reviewActiveBackgroundTasks(for: level)
        
        // 2. 작업 대기열 우선순위 재조정
        adjustTaskQueuePriorities(for: level)
        
        // 3. 제한 설정 적용
        applyTaskLimits(for: level)
        
        // 4. 허용되지 않는 작업 타입 일시 중단
        suspendDisallowedTasks(for: level)
        
        // 5. 시스템 설정 업데이트
        updateSystemSettings(for: level)
    }
    
    private func reviewActiveBackgroundTasks(for level: ThrottlingLevel) {
        let maxAllowed = level.maxConcurrentTasks
        
        if activeBackgroundTasks.count > maxAllowed {
            let tasksToSuspend = activeBackgroundTasks.suffix(activeBackgroundTasks.count - maxAllowed)
            
            for taskId in tasksToSuspend {
                UIApplication.shared.endBackgroundTask(taskId)
                if let index = activeBackgroundTasks.firstIndex(of: taskId) {
                    activeBackgroundTasks.remove(at: index)
                }
            }
            
        }
    }
    
    private func adjustTaskQueuePriorities(for level: ThrottlingLevel) {
        let allowedTypes = level.allowedTaskTypes
        
        // 허용된 작업 타입에 대해서만 우선순위 설정
        for taskType in allowedTypes {
            let qos: DispatchQoS = {
                switch level {
                case .none: return .default
                case .mild: return .utility
                case .moderate: return .background
                case .aggressive: return .background
                }
            }()
            
            // QoS 클래스를 Int로 변환하여 저장
            let qosValue: Int = {
                switch qos {
                case .userInteractive: return 33
                case .userInitiated: return 25
                case .default: return 21
                case .utility: return 17
                case .background: return 9
                default: return 21 // default
                }
            }()
            UserDefaults.standard.set(qosValue, forKey: "background_task_qos_\(taskType.rawValue)")
        }
    }
    
    private func applyTaskLimits(for level: ThrottlingLevel) {
        // 동시 실행 작업 수 제한
        UserDefaults.standard.set(level.maxConcurrentTasks, forKey: "max_concurrent_background_tasks")
        
        // 작업 시간 제한
        UserDefaults.standard.set(level.taskTimeLimit, forKey: "background_task_time_limit")
        
        // 작업 빈도 제한
        let taskFrequencyLimit: TimeInterval = {
            switch level {
            case .none: return 60.0      // 1분
            case .mild: return 300.0     // 5분
            case .moderate: return 900.0 // 15분
            case .aggressive: return 1800.0 // 30분
            }
        }()
        
        UserDefaults.standard.set(taskFrequencyLimit, forKey: "background_task_frequency_limit")
    }
    
    private func suspendDisallowedTasks(for level: ThrottlingLevel) {
        let allowedTypes = Set(level.allowedTaskTypes.map { $0.rawValue })
        let allTypes = Set(BackgroundTaskType.allCases.map { $0.rawValue })
        let disallowedTypes = allTypes.subtracting(allowedTypes)
        
        for taskType in disallowedTypes {
            suspendedTasks.insert(taskType)
            UserDefaults.standard.set(true, forKey: "suspend_\(taskType)")
        }
        
        // 허용된 작업 복원
        for taskType in allowedTypes {
            suspendedTasks.remove(taskType)
            UserDefaults.standard.set(false, forKey: "suspend_\(taskType)")
        }
        
    }
    
    private func updateSystemSettings(for level: ThrottlingLevel) {
        // iOS 백그라운드 작업 관련 설정
        switch level {
        case .none:
            UserDefaults.standard.set(true, forKey: "background_app_refresh_allowed")
            UserDefaults.standard.set(false, forKey: "background_processing_throttled")
            
        case .mild:
            UserDefaults.standard.set(true, forKey: "background_app_refresh_allowed")
            UserDefaults.standard.set(true, forKey: "background_processing_throttled")
            UserDefaults.standard.set(0.7, forKey: "background_cpu_usage_limit")
            
        case .moderate:
            UserDefaults.standard.set(false, forKey: "background_app_refresh_allowed")
            UserDefaults.standard.set(true, forKey: "background_processing_throttled")
            UserDefaults.standard.set(0.5, forKey: "background_cpu_usage_limit")
            
        case .aggressive:
            UserDefaults.standard.set(false, forKey: "background_app_refresh_allowed")
            UserDefaults.standard.set(true, forKey: "background_processing_throttled")
            UserDefaults.standard.set(0.2, forKey: "background_cpu_usage_limit")
            UserDefaults.standard.set(true, forKey: "defer_all_non_critical_tasks")
        }
    }
    
    func scheduleBackgroundTask(type: BackgroundTaskType, task: @escaping () -> Void) -> Bool {
        // 현재 제한 레벨에서 이 작업이 허용되는지 확인
        guard currentThrottlingLevel.allowedTaskTypes.contains(type) else {
            return false
        }
        
        // 동시 실행 작업 수 확인
        guard activeBackgroundTasks.count < currentThrottlingLevel.maxConcurrentTasks else {
            return false
        }
        
        let taskId = UIApplication.shared.beginBackgroundTask(withName: type.rawValue) {
            // 시간 초과 시 정리
            self.cleanupBackgroundTask(type: type)
        }
        
        guard taskId != .invalid else {
            return false
        }
        
        activeBackgroundTasks.append(taskId)
        
        taskQueue.async {
            task()
            
            DispatchQueue.main.async {
                UIApplication.shared.endBackgroundTask(taskId)
                if let index = self.activeBackgroundTasks.firstIndex(of: taskId) {
                    self.activeBackgroundTasks.remove(at: index)
                }
            }
        }
        
        return true
    }
    
    private func cleanupBackgroundTask(type: BackgroundTaskType) {
        
        // 작업 관련 리소스 정리
        NotificationCenter.default.post(
            name: NSNotification.Name("BackgroundTask_\(type.rawValue)_Timeout"),
            object: nil
        )
    }
    
    func getCurrentThrottlingLevel() -> ThrottlingLevel {
        return currentThrottlingLevel
    }
    
    func getBackgroundTaskStatus() -> [String: Any] {
        return [
            "throttling_level": currentThrottlingLevel.description,
            "active_tasks_count": activeBackgroundTasks.count,
            "max_concurrent_tasks": currentThrottlingLevel.maxConcurrentTasks,
            "suspended_task_types": Array(suspendedTasks),
            "allowed_task_types": currentThrottlingLevel.allowedTaskTypes.map { $0.rawValue },
            "task_time_limit": currentThrottlingLevel.taskTimeLimit
        ]
    }
    
    func restoreAllBackgroundTasks() {
        setThrottlingLevel(.none)
        suspendedTasks.removeAll()
        
        // 모든 일시 중단 플래그 제거
        for taskType in BackgroundTaskType.allCases {
            UserDefaults.standard.removeObject(forKey: "suspend_\(taskType.rawValue)")
        }
        
    }
}
