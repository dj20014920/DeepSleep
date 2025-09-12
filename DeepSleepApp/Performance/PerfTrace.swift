import Foundation

/// Lightweight performance tracer for end-to-end chat flow timing.
/// - Uses monotonic `ProcessInfo.processInfo.systemUptime` to avoid clock skew
/// - Emits compact one-line summaries per flow to Console
/// - Enabled only in DEBUG builds (guarded by DebugFlags.performanceVerboseLogging)
final class PerfTrace {
    private let flow: String
    let id: String
    private let t0: TimeInterval
    private var marks: [(label: String, t: TimeInterval)] = []
    private var extras: [String: String] = [:]

    /// Create a new tracer
    /// - Parameters:
    ///   - flow: flow category (e.g., "ChatFlow", "SessionManager", "UnifiedAIService", "ProxyCall")
    ///   - id: optional correlation id (if nil, generates short UUID)
    init(flow: String, id: String? = nil) {
        self.flow = flow
        self.id = id ?? String(UUID().uuidString.prefix(8))
        self.t0 = ProcessInfo.processInfo.systemUptime
    }

    /// Attach optional metadata which will be printed at summary
    @discardableResult
    func with(extra key: String, _ value: String?) -> PerfTrace {
        if let v = value, !v.isEmpty { extras[key] = v }
        return self
    }

    /// Mark a step
    func mark(_ label: String) {
        guard PerfTrace.isEnabled else { return }
        marks.append((label, ProcessInfo.processInfo.systemUptime))
    }

    /// End and print summary
    func end(_ finalLabel: String? = nil) {
        guard PerfTrace.isEnabled else { return }
        let tEnd = ProcessInfo.processInfo.systemUptime
        if let fl = finalLabel { marks.append((fl, tEnd)) }
        let totalMs = Int(((tEnd - t0) * 1000.0).rounded())

        // Build step deltas
        var last = t0
        var parts: [String] = []
        for (label, t) in marks {
            let ms = Int(((t - last) * 1000.0).rounded())
            parts.append("\(label)=\(ms)ms")
            last = t
        }
        parts.append("total=\(totalMs)ms")

        var extraStr = extras.map { "\($0.key)=\($0.value)" }.sorted().joined(separator: ", ")
        if !extraStr.isEmpty { extraStr = " (" + extraStr + ")" }

        print("⏱️ [⚡ Performance] [tid=\(id)] \(flow): " + parts.joined(separator: ", ") + extraStr)
    }

    /// Quick helper to measure a single block
    static func measure<T>(_ flow: String, id: String? = nil, block: () throws -> T) rethrows -> T {
        let p = PerfTrace(flow: flow, id: id)
        defer { p.end() }
        return try block()
    }

    /// Global toggle
    static var isEnabled: Bool {
        #if DEBUG
        return DebugFlags.performanceVerboseLogging || DebugFlags.internalUsageVerbose
        #else
        return false
        #endif
    }
}
