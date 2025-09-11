import Foundation

public final class ContextMetrics {
    public static let shared = ContextMetrics()

    private let queue = DispatchQueue(label: "ai.context.metrics.queue", qos: .utility)
    private var cacheLogs: [CacheLogEntry] = []
    private var lastQualityScores: [Int] = []
    private var lastTokenEstimates: [Int] = []

    // Request-level metrics (model/mode as String to avoid type coupling)
    private var totalRequests: Int = 0
    private var totalFailures: Int = 0
    private var latenciesMs: [Int] = []

    // Per-model/mode counters and fallback attempts
    private var requestsByModel: [String: Int] = [:]
    private var requestsByMode: [String: Int] = [:]
    private var fallbackAttempts: Int = 0

    // Cache counters
    private var cacheHits: Int = 0
    private var cacheMisses: Int = 0

    // 품질 경고 임계치 (기본 60, 설정값이 있으면 사용)
    private lazy var qualityWarnThreshold: Int = {
        return ConfigReader.int("AI_QUALITY_WARN_THRESHOLD", default: 60) ?? 60
    }()

    private init() {}

    public func logCache(event: CacheEvent, reason: InvalidationReason, age: TimeInterval?, caller: String? = nil) {
        let entry = CacheLogEntry(event: event, reason: reason, age: age, caller: caller)
        queue.async { [weak self] in
            self?.cacheLogs.append(entry)
            switch event {
            case .hit:
                self?.cacheHits += 1
            case .miss:
                self?.cacheMisses += 1
            }
        }
        let ageDesc = age.map { String(Int($0)) } ?? "-1"
        debugPrint("🧠 [AIContext] Cache \(event.rawValue.uppercased()) reason=\(reason.rawValue) age=\(ageDesc)s caller=\(caller ?? "-")")
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
        if score < qualityWarnThreshold {
            debugPrint("⚠️ [AIContext] LowQuality score=\(score) (<\(qualityWarnThreshold))")
        } else {
            debugPrint("📊 [AIContext] QualityScore=\(score)")
        }
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

    // MARK: - Request metrics
    public func logRequestStart(id: String, model: String, mode: String) {
        queue.async { [weak self] in
            self?.totalRequests += 1
            self?.requestsByModel[model, default: 0] += 1
            self?.requestsByMode[mode, default: 0] += 1
        }
        debugPrint("🚀 [AIReq] start id=\(id) model=\(model) mode=\(mode)")
    }

    public func logRequestEnd(id: String, model: String, mode: String, success: Bool, duration: TimeInterval) {
        let ms = Int(duration * 1000)
        queue.async { [weak self] in
            self?.latenciesMs.append(ms)
            if self?.latenciesMs.count ?? 0 > 5000 { self?.latenciesMs.removeFirst() }
            if !success { self?.totalFailures += 1 }
        }
        debugPrint("✅ [AIReq] end id=\(id) model=\(model) mode=\(mode) success=\(success) dur=\(ms)ms")
    }

    public func logFallbackTried(from: String, to: String) {
        queue.async { [weak self] in
            self?.fallbackAttempts += 1
        }
        debugPrint("🔁 [AIReq] fallback from=\(from) to=\(to)")
    }

    // 간단한 스냅샷
    public func snapshot() -> (cacheCount: Int, avgQuality: Double, avgTokens: Double) {
        return queue.sync {
            let qAvg = lastQualityScores.isEmpty ? 0.0 : Double(lastQualityScores.reduce(0,+)) / Double(lastQualityScores.count)
            let tAvg = lastTokenEstimates.isEmpty ? 0.0 : Double(lastTokenEstimates.reduce(0,+)) / Double(lastTokenEstimates.count)
            return (cacheLogs.count, qAvg, tAvg)
        }
    }
    public func cacheSummary() -> (hits: Int, misses: Int, hitRate: Double) {
        return queue.sync {
            let total = cacheHits + cacheMisses
            let rate = total == 0 ? 0.0 : Double(cacheHits) / Double(total)
            return (cacheHits, cacheMisses, rate)
        }
    }
    public func requestSummary() -> (total: Int, failures: Int, p95ms: Int) {
        return queue.sync {
            let total = totalRequests
            let failures = totalFailures
            let p95: Int
            if latenciesMs.isEmpty {
                p95 = 0
            } else {
                let sorted = latenciesMs.sorted()
                let idx = Int(Double(sorted.count - 1) * 0.95)
                p95 = sorted[max(0, min(idx, sorted.count - 1))]
            }
            return (total, failures, p95)
        }
    }

    // 한 줄 요약 문자열 생성
    public func oneLineSummary() -> String {
        let (hits, misses, rate) = cacheSummary()
        let (total, failures, p95) = requestSummary()
        let hitPct = Int(rate * 100)
        let fb = queue.sync { fallbackAttempts }
        return "Metrics cache: H=\(hits) M=\(misses) hit=\(hitPct)% | req: total=\(total) fail=\(failures) p95=\(p95)ms | fb=\(fb)"
    }
    // 모델/모드별 요약 문자열 (Top 3)
    public func modelModeSummary(topK: Int = 3) -> String {
        return queue.sync {
            func topKString(from dict: [String:Int], label: String) -> String {
                if dict.isEmpty { return "\(label): -" }
                let sorted = dict.sorted { $0.value > $1.value }.prefix(topK)
                let parts = sorted.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
                return "\(label): [\(parts)]"
            }
            let models = topKString(from: requestsByModel, label: "models")
            let modes = topKString(from: requestsByMode, label: "modes")
            return "\(models) | \(modes)"
        }
    }
    
    // 모델/모드 분포 스냅샷 제공
    public func modelModeSnapshot() -> ([String:Int], [String:Int]) {
        return queue.sync { (requestsByModel, requestsByMode) }
    }
}
