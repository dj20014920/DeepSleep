import Foundation

/// LLM 서비스의 성능 메트릭을 추적하는 모니터링 시스템
public final class LLMMonitor {
    // MARK: - Properties
    public static let shared = LLMMonitor()
    
    private let queue = DispatchQueue(label: "com.deepsleep.llm.monitor", attributes: .concurrent)
    private var metrics: [LLMServiceType: LLMMetrics] = [:]
    private var warnings: [String] = []
    
    // 메트릭 보관 기간
    private let metricsRetentionPeriod: TimeInterval = 3600 // 1시간
    
    // MARK: - Initialization
    private init() {
        setupPeriodicCleanup()
    }
    
    // MARK: - Public Methods
    /// 성공적인 작업 처리를 기록
    /// - Parameters:
    ///   - taskType: 작업 유형
    ///   - duration: 처리 소요 시간
    public func recordSuccess(taskType: AITaskType, duration: TimeInterval) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            let serviceType = self.getServiceType(for: taskType)
            var metrics = self.metrics[serviceType] ?? LLMMetrics()
            
            metrics.successCount += 1
            metrics.totalLatency += duration
            metrics.lastUpdated = Date()
            
            // 토큰 비용 추정
            let estimatedTokens = self.estimateTokens(for: taskType)
            metrics.totalTokens += estimatedTokens
            metrics.totalCost += self.calculateCost(tokens: estimatedTokens, serviceType: serviceType)
            
            self.metrics[serviceType] = metrics
        }
    }
    
    /// 에러 발생을 기록
    /// - Parameters:
    ///   - taskType: 작업 유형
    ///   - error: 발생한 에러
    public func recordError(taskType: AITaskType, error: Error) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            let serviceType = self.getServiceType(for: taskType)
            var metrics = self.metrics[serviceType] ?? LLMMetrics()
            
            metrics.errorCount += 1
            metrics.lastError = error
            metrics.lastUpdated = Date()
            
            if let llmError = error as? LLMError {
                metrics.lastLLMError = llmError
            }
            
            self.metrics[serviceType] = metrics
        }
    }
    
    /// 폴백 서비스 사용을 기록
    /// - Parameters:
    ///   - taskType: 작업 유형
    ///   - originalError: 원인이 된 에러
    public func recordFallback(taskType: AITaskType, originalError: Error) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            let serviceType = self.getServiceType(for: taskType)
            var metrics = self.metrics[serviceType] ?? LLMMetrics()
            
            metrics.fallbackCount += 1
            metrics.lastFallbackError = originalError
            metrics.lastUpdated = Date()
            
            self.metrics[serviceType] = metrics
        }
    }
    
    /// 경고 메시지를 기록
    /// - Parameter message: 경고 메시지
    public func recordWarning(message: String) {
        queue.async(flags: .barrier) { [weak self] in
            self?.warnings.append(message)
        }
    }
    
    /// 현재 메트릭 상태를 반환
    /// - Returns: 서비스별 메트릭 정보
    public func getCurrentMetrics() -> [LLMServiceType: LLMMetrics] {
        var result: [LLMServiceType: LLMMetrics] = [:]
        queue.sync {
            result = metrics
        }
        return result
    }
    
    /// 경고 메시지 목록을 반환
    /// - Returns: 기록된 경고 메시지들
    public func getWarnings() -> [String] {
        var result: [String] = []
        queue.sync {
            result = warnings
        }
        return result
    }
    
    // MARK: - Private Methods
    private func setupPeriodicCleanup() {
        Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            self?.cleanupOldMetrics()
        }
    }
    
    private func cleanupOldMetrics() {
        let now = Date()
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            self.metrics = self.metrics.filter { _, metrics in
                guard let lastUpdated = metrics.lastUpdated else { return false }
                return now.timeIntervalSince(lastUpdated) < self.metricsRetentionPeriod
            }
            
            // 경고 메시지도 정리
            if self.warnings.count > 1000 {
                self.warnings = Array(self.warnings.suffix(1000))
            }
        }
    }
    
    private func getServiceType(for taskType: AITaskType) -> LLMServiceType {
        switch taskType {
        case .generalChat, .analyzeEmotionDiary, .analyzeEmotion, .summarizeDiary:
            return .claude
        case .recommendTodo:
            return .openAI
        case .recommendSound, .recommendPreset:
            return .gemini
        case .generateFortune:
            return .naver
        }
    }
    
    private func estimateTokens(for taskType: AITaskType) -> Int {
        switch taskType {
        case .generalChat:
            return 500
        case .analyzeEmotionDiary:
            return 1000
        case .analyzeEmotion:
            return 300
        case .summarizeDiary:
            return 800
        case .recommendTodo:
            return 400
        case .recommendSound:
            return 200
        case .recommendPreset:
            return 300
        case .generateFortune:
            return 150
        }
    }
    
    private func calculateCost(tokens: Int, serviceType: LLMServiceType) -> Double {
        let ratePerToken: Double
        switch serviceType {
        case .claude:
            ratePerToken = 0.00001 // $0.01 per 1K tokens
        case .openAI:
            ratePerToken = 0.00003 // $0.03 per 1K tokens
        case .gemini:
            ratePerToken = 0.000005 // $0.005 per 1K tokens
        case .naver:
            ratePerToken = 0.000008 // $0.008 per 1K tokens
        case .onDevice:
            ratePerToken = 0 // 무료
        }
        return Double(tokens) * ratePerToken
    }
}

// MARK: - Supporting Types
public struct LLMMetrics {
    var successCount: Int = 0
    var errorCount: Int = 0
    var fallbackCount: Int = 0
    var totalLatency: TimeInterval = 0
    var totalTokens: Int = 0
    var totalCost: Double = 0
    var lastError: Error?
    var lastLLMError: LLMError?
    var lastFallbackError: Error?
    var lastUpdated: Date?
    
    var averageLatency: TimeInterval {
        guard successCount > 0 else { return 0 }
        return totalLatency / Double(successCount)
    }
    
    var errorRate: Double {
        let total = successCount + errorCount
        guard total > 0 else { return 0 }
        return Double(errorCount) / Double(total)
    }
    
    var averageCostPerRequest: Double {
        guard successCount > 0 else { return 0 }
        return totalCost / Double(successCount)
    }
} 
