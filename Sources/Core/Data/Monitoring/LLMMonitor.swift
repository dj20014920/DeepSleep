import Foundation
import os.log

/// LLM 모니터링 구현체
public final class LLMMonitor: LLMMonitoringProtocol {
    // MARK: - Constants
    
    private enum Constants {
        static let metricsFileName = "llm_metrics.json"
        static let errorLogFileName = "llm_errors.log"
        static let maxErrorLogSize = 10 * 1024 * 1024 // 10MB
        static let maxMetricsAge: TimeInterval = 30 * 24 * 60 * 60 // 30일
    }
    
    // MARK: - Types
    
    private struct MetricsEntry: Codable {
        let timestamp: Date
        let service: LLMServiceType
        let metrics: [String: Double]
    }
    
    private struct ErrorEntry: Codable {
        let timestamp: Date
        let service: LLMServiceType
        let error: String
        let context: [String: String]
    }
    
    // MARK: - Properties
    
    private let fileManager: FileManager
    private let metricsURL: URL
    private let errorLogURL: URL
    private let logger: Logger
    private let queue = DispatchQueue(label: "com.deepsleep.llmmonitor")
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    private var metrics: [MetricsEntry] = []
    private var errors: [ErrorEntry] = []
    private var alertThresholds: [LLMServiceType: [String: Any]] = [:]
    
    // MARK: - Initialization
    
    public init(fileManager: FileManager = .default) throws {
        self.fileManager = fileManager
        self.logger = Logger(subsystem: "com.deepsleep", category: "LLMMonitor")
        
        // 모니터링 디렉토리 설정
        let monitorDirectory = try fileManager.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ).appendingPathComponent("Monitoring", isDirectory: true)
        
        if !fileManager.fileExists(atPath: monitorDirectory.path) {
            try fileManager.createDirectory(
                at: monitorDirectory,
                withIntermediateDirectories: true
            )
        }
        
        self.metricsURL = monitorDirectory.appendingPathComponent(Constants.metricsFileName)
        self.errorLogURL = monitorDirectory.appendingPathComponent(Constants.errorLogFileName)
        
        // 데이터 로드
        loadMetrics()
        loadErrors()
        
        // 오래된 데이터 정리
        cleanupOldData()
    }
    
    // MARK: - LLMMonitoringProtocol Implementation
    
    public func recordMetrics(
        _ metrics: [String: Any],
        for service: LLMServiceType
    ) {
        queue.async {
            // 메트릭 변환
            let doubleMetrics = metrics.compactMapValues { value -> Double? in
                switch value {
                case let number as Double:
                    return number
                case let number as Int:
                    return Double(number)
                case let number as Float:
                    return Double(number)
                default:
                    return nil
                }
            }
            
            // 메트릭 저장
            let entry = MetricsEntry(
                timestamp: Date(),
                service: service,
                metrics: doubleMetrics
            )
            self.metrics.append(entry)
            
            // 임계값 확인
            self.checkThresholds(doubleMetrics, for: service)
            
            // 디스크에 저장
            self.saveMetrics()
        }
    }
    
    public func recordError(
        _ error: Error,
        context: [String: Any]?,
        for service: LLMServiceType
    ) {
        queue.async {
            // 컨텍스트 변환
            let stringContext = (context ?? [:]).compactMapValues { "\($0)" }
            
            // 에러 저장
            let entry = ErrorEntry(
                timestamp: Date(),
                service: service,
                error: error.localizedDescription,
                context: stringContext
            )
            self.errors.append(entry)
            
            // 로그 기록
            self.logger.error("""
                LLM Error (\(service.rawValue)):
                Error: \(error.localizedDescription)
                Context: \(stringContext)
                """)
            
            // 디스크에 저장
            self.saveErrors()
        }
    }
    
    public func generateReport(
        for service: LLMServiceType
    ) -> [String: Any] {
        queue.sync {
            let serviceMetrics = self.metrics.filter { $0.service == service }
            let serviceErrors = self.errors.filter { $0.service == service }
            
            // 기본 통계 계산
            var totalRequests = 0
            var totalTokens = 0
            var totalLatency = 0.0
            let errorCount = serviceErrors.count
            
            for entry in serviceMetrics {
                if let requests = entry.metrics["requests"] {
                    totalRequests += Int(requests)
                }
                if let tokens = entry.metrics["tokens"] {
                    totalTokens += Int(tokens)
                }
                if let latency = entry.metrics["latency"] {
                    totalLatency += latency
                }
            }
            
            let averageLatency = serviceMetrics.isEmpty ? 0 : totalLatency / Double(serviceMetrics.count)
            
            let successRate: Double
            if totalRequests > 0 {
                successRate = (1.0 - Double(errorCount) / Double(totalRequests)) * 100.0
            } else {
                successRate = 100.0
            }
            
            // 보고서 생성
            return [
                "total_requests": totalRequests,
                "total_tokens": totalTokens,
                "average_latency": averageLatency,
                "error_count": errorCount,
                "success_rate": successRate,
                "last_24h_metrics": serviceMetrics.filter {
                    $0.timestamp.timeIntervalSinceNow > -24 * 60 * 60
                }.map { [
                    "timestamp": $0.timestamp,
                    "metrics": $0.metrics
                ] },
                "recent_errors": serviceErrors.suffix(5).map { [
                    "timestamp": $0.timestamp,
                    "error": $0.error,
                    "context": $0.context
                ] }
            ]
        }
    }
    
    public func setAlertThresholds(
        _ thresholds: [String: Any],
        for service: LLMServiceType
    ) {
        queue.async {
            self.alertThresholds[service] = thresholds
        }
    }
    
    // MARK: - Private Helpers
    
    private func loadMetrics() {
        guard fileManager.fileExists(atPath: metricsURL.path),
              let data = try? Data(contentsOf: metricsURL) else {
            return
        }
        
        metrics = (try? decoder.decode([MetricsEntry].self, from: data)) ?? []
    }
    
    private func loadErrors() {
        guard fileManager.fileExists(atPath: errorLogURL.path),
              let data = try? Data(contentsOf: errorLogURL) else {
            return
        }
        
        errors = (try? decoder.decode([ErrorEntry].self, from: data)) ?? []
    }
    
    private func saveMetrics() {
        do {
            let data = try encoder.encode(metrics)
            try data.write(to: metricsURL, options: .atomic)
        } catch {
            logger.error("Failed to save metrics: \(error.localizedDescription)")
        }
    }
    
    private func saveErrors() {
        do {
            let data = try encoder.encode(errors)
            try data.write(to: errorLogURL, options: .atomic)
            
            // 로그 크기 제한 확인
            let attributes = try fileManager.attributesOfItem(atPath: errorLogURL.path)
            if let fileSize = attributes[.size] as? Int64,
               fileSize > Constants.maxErrorLogSize {
                // 가장 오래된 에러 로그 절반 제거
                errors.removeFirst(errors.count / 2)
                try encoder.encode(errors).write(to: errorLogURL, options: .atomic)
            }
        } catch {
            logger.error("Failed to save errors: \(error.localizedDescription)")
        }
    }
    
    private func cleanupOldData() {
        let cutoffDate = Date().addingTimeInterval(-Constants.maxMetricsAge)
        
        metrics.removeAll { $0.timestamp < cutoffDate }
        errors.removeAll { $0.timestamp < cutoffDate }
        
        saveMetrics()
        saveErrors()
    }
    
    private func checkThresholds(_ newMetrics: [String: Double], for service: LLMServiceType) {
        guard let thresholds = alertThresholds[service] else { return }
        
        // 예시: Latency 임계값 확인
        if let maxLatency = thresholds["maxLatency"] as? Double,
           let currentLatency = newMetrics["latency"],
           currentLatency > maxLatency {
            logger.warning("[\(service.displayName)] High latency detected: \(currentLatency)s")
            // 여기에 실제 알림 로직 (Push, Email 등) 추가 가능
        }

        // 예시: 에러율 임계값 확인
        if let maxErrorRate = thresholds["maxErrorRate"] as? Double {
            let serviceErrors = self.errors.filter { $0.service == service }
            let serviceRequests = self.metrics.filter { $0.service == service }
            
            if !serviceRequests.isEmpty {
                let errorRate = Double(serviceErrors.count) / Double(serviceRequests.count)
                if errorRate > maxErrorRate {
                    logger.warning("[\(service.displayName)] High error rate detected: \(errorRate * 100)%")
                }
            }
        }
    }
} 
