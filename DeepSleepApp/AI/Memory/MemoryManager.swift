import Foundation

public enum MemoryTier {
    case free    // 최대 5개
    case premium // 최대 20개

    var slotLimit: Int {
        switch self {
        case .free: return 5
        case .premium: return 20
        }
    }
}

public struct CoreMemory: Codable, Equatable {
    public let id: UUID
    public let originalMessage: String
    public let createdAt: Date
    public var importance: Int // 1~5

    public init(id: UUID = UUID(), originalMessage: String, createdAt: Date = Date(), importance: Int = 3) {
        self.id = id
        self.originalMessage = originalMessage
        self.createdAt = createdAt
        self.importance = importance
    }
}

public final class MemoryManager {
    public static let shared = MemoryManager()

    private let queue = DispatchQueue(label: "ai.memory.manager.queue", attributes: .concurrent)
    private var memories: [CoreMemory] = []
    private var tier: MemoryTier = .free

    private init() {}

    public func setTier(_ tier: MemoryTier) {
        queue.async(flags: .barrier) { [weak self] in
            self?.tier = tier
        }
    }

    public func canAddMemory() -> Bool {
        queue.sync {
            return memories.count < tier.slotLimit
        }
    }

    @discardableResult
    public func addMemory(_ message: String, importance: Int = 3) -> Bool {
        guard message.isEmpty == false else { return false }
        var added = false
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            if self.memories.count >= self.tier.slotLimit { return }
            self.memories.append(CoreMemory(originalMessage: message, importance: max(1, min(5, importance))))
            added = true
        }
        queue.sync(flags: .barrier) {} // flush
        if added {
            AIContextManager.shared.clearCache(reason: .coreMemoryUpdated, caller: "MemoryManager.add")
        }
        return added
    }

    @discardableResult
    public func removeMemory(id: UUID) -> Bool {
        var removed = false
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            if let idx = self.memories.firstIndex(where: { $0.id == id }) {
                self.memories.remove(at: idx)
                removed = true
            }
        }
        queue.sync(flags: .barrier) {}
        if removed {
            AIContextManager.shared.clearCache(reason: .coreMemoryUpdated, caller: "MemoryManager.remove")
        }
        return removed
    }

    public func listMemories() -> [CoreMemory] {
        queue.sync { memories.sorted { $0.createdAt < $1.createdAt } }
    }

    // 간단 요약: 중요도/시간 순으로 상위 N개를 합성(실제 서비스에서는 경량 모델 호출 가능)
    public func getMemorySummary(maxItems: Int = 10) -> String {
        let items = queue.sync {
            memories.sorted { (l, r) in
                if l.importance == r.importance {
                    return l.createdAt < r.createdAt
                }
                return l.importance > r.importance
            }.prefix(maxItems)
        }
        guard items.isEmpty == false else { return "" }
        let bullets = items.enumerated().map { idx, m in
            "- (\(idx+1)) [\(m.importance)] \(m.originalMessage)"
        }.joined(separator: "\n")
        return "중요 사용자 메모 요약:\n\(bullets)"
    }
}
