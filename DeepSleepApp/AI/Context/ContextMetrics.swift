import Foundation

public final class ContextMetrics {
    public static let shared = ContextMetrics()

    private let queue = DispatchQueue(label: "ai.context.metrics.queue", qos: .utility)
    private var cacheLogs: [CacheLogEntry] = []
    private var lastQualityScores: [Int] = []
    private var lastTokenEstimates: [Int] = []

    private init() {}

    public func logCache(event: CacheEvent, reason: InvalidationReason, age: TimeInterval?, caller: String? = nil) {
        let entry = CacheLogEntry(event: event, reason: reason, age: age, caller: caller)
        queue.async { [weak self] in
            self?.cacheLogs.append(entry)
        }
        debugPrint("🧠 [AIContext] Cache \(event.rawValue.uppercased()) reason=\(reason.rawValue) age=\(age != nil ? Int(age!) : -1)s caller=\(caller ?? "-")")
    }

    public func logInvalidation(reason: InvalidationReason, caller: String?) {
        debugPrint("🧹 [AIContext] Cache invalidated reason=\(reason.rawValue) caller=\(caller ?? "-")")
    }

    public func logQualityScore(_ score: Int) {
        queue.async { [weak self] in
            self?.lastQualityScores.append(score)
            if self?.lastQualityScores.count ?? 0 > 1000 {
                self?.lastQualityScores.removeFirst()
            }
        }
        debugPrint("📊 [AIContext] QualityScore=\(score)")
    }

    public func logTokenEstimate(_ tokens: Int) {
        queue.async { [weak self] in
            self?.lastTokenEstimates.append(tokens)
            if self?.lastTokenEstimates.count ?? 0 > 1000 {
                self?.lastTokenEstimates.removeFirst()
            }
        }
        debugPrint("🔢 [AIContext] TokenEstimate=\(tokens)")
    }

    // 간단한 스냅샷
    public func snapshot() -> (cacheCount: Int, avgQuality: Double, avgTokens: Double) {
        return queue.sync {
            let qAvg = lastQualityScores.isEmpty ? 0.0 : Double(lastQualityScores.reduce(0,+)) / Double(lastQualityScores.count)
            let tAvg = lastTokenEstimates.isEmpty ? 0.0 : Double(lastTokenEstimates.reduce(0,+)) / Double(lastTokenEstimates.count)
            return (cacheLogs.count, qAvg, tAvg)
        }
    }
}
