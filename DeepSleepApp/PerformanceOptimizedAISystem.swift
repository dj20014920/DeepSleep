import Foundation
import CoreML
import os.log

/// iOS 버전별 로컬 신경망 성능 최적화 시스템
@available(iOS 16.0, *)
public class PerformanceOptimizedAISystem: ObservableObject {
    
    // MARK: - Singleton
    public static let shared = PerformanceOptimizedAISystem()
    private init() {
        detectDeviceCapabilities()
        configureOptimalSettings()
    }
    
    // MARK: - Properties
    @Published public var currentPerformanceProfile: PerformanceProfile = .auto
    @Published public var realTimeMetrics: PerformanceMetrics = PerformanceMetrics()
    
    private let logger = Logger(subsystem: "com.deepsleep.ai", category: "Performance")
    private var performanceHistory: [PerformanceMetrics] = []
    
    // MARK: - Performance Profiles
    public enum PerformanceProfile: CaseIterable {
        case auto          // 자동 최적화
        case batteryFirst  // 배터리 우선
        case speedFirst    // 속도 우선
        case balanced      // 균형
        
        var description: String {
            switch self {
            case .auto: return "자동 최적화"
            case .batteryFirst: return "배터리 절약"
            case .speedFirst: return "성능 우선"
            case .balanced: return "균형"
            }
        }
    }
    
    // MARK: - Performance Metrics
    public struct PerformanceMetrics: Codable {
        var inferenceTime: Double = 0.0    // ms
        var batteryImpact: Double = 0.0    // relative scale
        var neuralEngineUtilization: Double = 0.0  // %
        var memoryUsage: Double = 0.0      // MB
        var timestamp: Date = Date()
        
        var score: Double {
            // 종합 성능 점수 (낮을수록 좋음)
            return inferenceTime + (batteryImpact * 100) + (memoryUsage / 10)
        }
    }
    
    // MARK: - Device Capabilities
    private struct DeviceCapabilities {
        let supportsMLTensor: Bool      // iOS 18+
        let hasNeuralEngineIssues: Bool // iOS 17
        let optimalComputeUnits: MLComputeUnits
        let recommendedPrecision: MLModel.PrecisionType
    }
    
    private var deviceCapabilities: DeviceCapabilities!
    
    // MARK: - iOS Version Detection & Optimization
    private func detectDeviceCapabilities() {
        var supportsMLTensor = false
        var hasNeuralEngineIssues = false
        var optimalComputeUnits: MLComputeUnits = .all
        var recommendedPrecision: MLModel.PrecisionType = .float32
        
        if #available(iOS 18.0, *) {
            // iOS 18: MLTensor 지원, Neural Engine 25% 성능 향상
            supportsMLTensor = true
            hasNeuralEngineIssues = false
            optimalComputeUnits = .cpuAndNeuralEngine
            recommendedPrecision = .float16  // 더 효율적
            logger.info("🚀 iOS 18+ 감지: MLTensor 최적화 활성화")
            
        } else if #available(iOS 17.0, *) {
            // iOS 17: Neural Engine 문제, GPU 우선 사용
            supportsMLTensor = false
            hasNeuralEngineIssues = true
            optimalComputeUnits = .cpuAndGPU
            recommendedPrecision = .float32
            logger.warning("⚠️ iOS 17 감지: Neural Engine 문제로 GPU 모드 사용")
            
        } else {
            // iOS 16: Neural Engine 최적화 우수
            supportsMLTensor = false
            hasNeuralEngineIssues = false
            optimalComputeUnits = .all
            recommendedPrecision = .float16
            logger.info("✅ iOS 16 감지: Neural Engine 최적화 사용")
        }
        
        deviceCapabilities = DeviceCapabilities(
            supportsMLTensor: supportsMLTensor,
            hasNeuralEngineIssues: hasNeuralEngineIssues,
            optimalComputeUnits: optimalComputeUnits,
            recommendedPrecision: recommendedPrecision
        )
    }
    
    // MARK: - Model Configuration Optimization
    public func optimizedModelConfiguration(for profile: PerformanceProfile = .auto) -> MLModelConfiguration {
        let config = MLModelConfiguration()
        
        let targetProfile = profile == .auto ? autoSelectProfile() : profile
        
        switch targetProfile {
        case .auto:
            config.computeUnits = deviceCapabilities.optimalComputeUnits
            
        case .batteryFirst:
            // 배터리 절약: CPU 우선, 낮은 정밀도
            config.computeUnits = .cpuOnly
            if #available(iOS 18.0, *) {
                config.allowLowPrecisionAccumulationOnGPU = true
            }
            
        case .speedFirst:
            // 성능 우선: 최고 성능 유닛 사용
            if deviceCapabilities.hasNeuralEngineIssues {
                config.computeUnits = .cpuAndGPU
            } else {
                config.computeUnits = .all
            }
            
        case .balanced:
            // 균형: 디바이스 기본 설정 사용
            config.computeUnits = deviceCapabilities.optimalComputeUnits
        }
        
        logger.info("📊 모델 설정 최적화: \(targetProfile.description)")
        return config
    }
    
    // MARK: - Auto Profile Selection
    private func autoSelectProfile() -> PerformanceProfile {
        let batteryLevel = ProcessInfo.processInfo.thermalState
        let averageInferenceTime = performanceHistory.suffix(10).map(\.inferenceTime).reduce(0, +) / max(1, Double(performanceHistory.suffix(10).count))
        
        // 배터리 상태와 성능 히스토리를 기반으로 프로파일 선택
        switch batteryLevel {
        case .critical, .serious:
            return .batteryFirst
        case .fair:
            return averageInferenceTime > 100 ? .balanced : .speedFirst
        default:
            return .speedFirst
        }
    }
    
    // MARK: - Performance Monitoring
    public func measurePerformance<T>(operation: () async throws -> T) async rethrows -> (result: T, metrics: PerformanceMetrics) {
        let startTime = CFAbsoluteTimeGetCurrent()
        let startMemory = getCurrentMemoryUsage()
        
        let result = try await operation()
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let endMemory = getCurrentMemoryUsage()
        
        let metrics = PerformanceMetrics(
            inferenceTime: (endTime - startTime) * 1000, // ms로 변환
            batteryImpact: estimateBatteryImpact(duration: endTime - startTime),
            neuralEngineUtilization: estimateNeuralEngineUsage(),
            memoryUsage: endMemory - startMemory,
            timestamp: Date()
        )
        
        // 메트릭스 저장 및 업데이트
        await MainActor.run {
            self.realTimeMetrics = metrics
            self.performanceHistory.append(metrics)
            
            // 최근 100개 항목만 유지
            if self.performanceHistory.count > 100 {
                self.performanceHistory.removeFirst(self.performanceHistory.count - 100)
            }
        }
        
        logger.info("📈 성능 측정: \(metrics.inferenceTime)ms, 메모리: \(metrics.memoryUsage)MB")
        
        return (result, metrics)
    }
    
    // MARK: - Helper Methods
    private func configureOptimalSettings() {
        // 디바이스별 최적 설정 구성
        currentPerformanceProfile = .auto
    }
    
    private func getCurrentMemoryUsage() -> Double {
        var taskInfo = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info>.size) / 4
        
        let result = withUnsafeMutablePointer(to: &taskInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        
        if result == KERN_SUCCESS {
            return Double(taskInfo.phys_footprint) / (1024 * 1024) // MB로 변환
        }
        return 0
    }
    
    private func estimateBatteryImpact(duration: Double) -> Double {
        // 추론 시간 기반 배터리 영향도 추정 (상대적 스케일)
        return duration * 0.1
    }
    
    private func estimateNeuralEngineUsage() -> Double {
        // Neural Engine 사용률 추정 (실제 측정 복잡하므로 근사치)
        if deviceCapabilities.hasNeuralEngineIssues {
            return 0.0 // iOS 17에서는 Neural Engine 미사용
        }
        return 75.0 // 평균적인 활용도
    }
    
    // MARK: - Public API
    public func getCurrentOptimizationStatus() -> String {
        let profile = currentPerformanceProfile
        let avgTime = performanceHistory.suffix(5).map(\.inferenceTime).reduce(0, +) / max(1, Double(performanceHistory.suffix(5).count))
        
        return """
        현재 프로파일: \(profile.description)
        평균 추론 시간: \(String(format: "%.1f", avgTime))ms
        iOS 최적화: \(deviceCapabilities.supportsMLTensor ? "MLTensor 활성" : "표준 모드")
        메모리 사용량: \(String(format: "%.1f", realTimeMetrics.memoryUsage))MB
        """
    }
    
    public func switchProfile(to profile: PerformanceProfile) {
        DispatchQueue.main.async {
            self.currentPerformanceProfile = profile
        }
        logger.info("🔄 성능 프로파일 변경: \(profile.description)")
    }
}

// MARK: - MLModel Extension for Precision
extension MLModel {
    public enum PrecisionType {
        case float16
        case float32
        
        var description: String {
            switch self {
            case .float16: return "Float16 (고효율)"
            case .float32: return "Float32 (고정밀)"
            }
        }
    }
} 
