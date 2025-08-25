import Foundation
import Combine
import CryptoKit

/// Centralizes chat requests, persists messages, and delivers AI responses
/// even when the chat screen is not visible or the app goes background.
/// KISS/DRY/SOLID: Single responsibility for chat networking lifecycle.
final class ChatRequestCenter {
    static let shared = ChatRequestCenter()

    enum EventName {
        static let responseArrived = Notification.Name("ChatRequestCenter.responseArrived")
        static let requestFailed = Notification.Name("ChatRequestCenter.requestFailed")
    }

    private let queue: OperationQueue
    private let sessionManager = SessionManager.shared

    private init() {
        self.queue = OperationQueue()
        self.queue.name = "chat.requests.queue"
        self.queue.maxConcurrentOperationCount = 2
        self.queue.qualityOfService = .userInitiated
        // 디스크에서 미해결/완료 키 로드
        loadPending()
        loadCompletedKeys()
    }

    struct Pending: Codable {
        let id: UUID
        let content: String
        let model: AIModel
        let mode: AIMode
        let createdAt: Date
        let sessionId: String
        let dedupKey: String

        // 레거시 호환을 위한 커스텀 디코딩(기존 JSON에 sessionId/dedupKey가 없을 수 있음)
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            self.id = try c.decode(UUID.self, forKey: .id)
            self.content = try c.decode(String.self, forKey: .content)
            self.model = try c.decode(AIModel.self, forKey: .model)
            self.mode = try c.decode(AIMode.self, forKey: .mode)
            self.createdAt = try c.decode(Date.self, forKey: .createdAt)
            // sessionId/dedupKey가 없으면 임시 기본값을 생성
            let decodedSessionId = try c.decodeIfPresent(String.self, forKey: .sessionId) ?? "unknown-session"
            self.sessionId = decodedSessionId
            if let k = try c.decodeIfPresent(String.self, forKey: .dedupKey) {
                self.dedupKey = k
            } else {
                // 레거시 데이터를 위한 보수적 키(세션 정보가 없을 수 있어 id 기반)
                self.dedupKey = ChatRequestCenter.computeDedupKey(sessionId: decodedSessionId, mode: self.mode, content: self.content, model: self.model)
            }
        }

        init(id: UUID, content: String, model: AIModel, mode: AIMode, createdAt: Date, sessionId: String, dedupKey: String) {
            self.id = id
            self.content = content
            self.model = model
            self.mode = mode
            self.createdAt = createdAt
            self.sessionId = sessionId
            self.dedupKey = dedupKey
        }
    }

    private var pending: [Pending] = [] { didSet { persistPending() } }
    private var inFlight: Set<UUID> = [] // idempotency guard (legacy id)
    private var inFlightKeys: Set<String> = [] // idempotency guard (stable key)
    // Completed request index with TTL and capacity guard
    private struct CompletedEntry: Codable {
        let key: String
        var createdAt: Date
        var lastSeenAt: Date
    }
    private var completedIndex: [String: CompletedEntry] = [:] { didSet { persistCompletedKeys() } }
    private let completedTTL: TimeInterval = 14 * 24 * 60 * 60 // 14 days
    private let completedMax: Int = 20000

    private func isCompleted(_ key: String, touch: Bool = true) -> Bool {
        if let entry = completedIndex[key] {
            // expire check
            if Date().timeIntervalSince(entry.lastSeenAt) > completedTTL {
                completedIndex.removeValue(forKey: key)
                return false
            }
            if touch {
                var updated = entry
                updated.lastSeenAt = Date()
                completedIndex[key] = updated
            }
            return true
        }
        return false
    }

    private func markCompleted(_ key: String) {
        // prune old entries first if needed
        pruneCompletedIfNeeded()
        let now = Date()
        completedIndex[key] = CompletedEntry(key: key, createdAt: now, lastSeenAt: now)
    }

    private func pruneCompletedIfNeeded() {
        // remove expired
        let now = Date()
        for (k, v) in completedIndex {
            if now.timeIntervalSince(v.lastSeenAt) > completedTTL {
                completedIndex.removeValue(forKey: k)
            }
        }
        // enforce capacity by removing oldest lastSeenAt
        if completedIndex.count > completedMax {
            let toDrop = completedIndex
                .sorted { $0.value.lastSeenAt < $1.value.lastSeenAt }
                .prefix(completedIndex.count - completedMax)
            for (k, _) in toDrop { completedIndex.removeValue(forKey: k) }
        }
    }
    private let pendingURL: URL = {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return dir.appendingPathComponent("pending_chat_requests.json")
    }()
    private let completedURL: URL = {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return dir.appendingPathComponent("completed_chat_request_keys.json")
    }()

    // MARK: Public API

    /// Enqueue a chat request. Returns the user message id persisted.
    @discardableResult
    func enqueue(content: String, model: AIModel, mode: AIMode, context: AIContext?) -> UUID {
        // 세션 식별자 확보 (없으면 오늘자 세션 생성)
        let sessionId = context?.sessionId ?? sessionManager.getCurrentOrCreateSession().id
        // 신규 표준 키(정규화)와 레거시 키(원문) 모두 계산하여 호환성 유지
        let normalizedKey = Self.computeDedupKey(sessionId: sessionId, mode: mode, content: content, model: model)
        let legacyKey = Self.computeLegacyDedupKey(sessionId: sessionId, mode: mode, content: content, model: model)

        // 이미 완료된 키면 재요청 무시 (멱등성)
        if isCompleted(normalizedKey) || isCompleted(legacyKey) {
            // 안정적 UUID를 만들어 반환 (호출자 기대치 보존)
            return Self.stableUUID(for: normalizedKey)
        }

        // 이미 pending에 동일 키가 있으면 기존 id를 반환하고 재등록하지 않음
        if let existing = pending.first(where: { $0.dedupKey == normalizedKey || $0.dedupKey == legacyKey }) {
            return existing.id
        }

        // 1) 사용자 메시지는 SessionManager가 전송 시 저장하므로 즉시 저장 생략
        let userMsgId = UUID()

        // 2) Create pending record (안정적 dedupKey 포함)
        let p = Pending(
            id: userMsgId,
            content: content,
            model: model,
            mode: mode,
            createdAt: Date(),
            sessionId: sessionId,
            dedupKey: normalizedKey
        )
        pending.append(p)

        // 3) Schedule operation
        scheduleOperation(for: p, context: context)

        return userMsgId
    }

    /// Call this on app launch/foreground to resume pending work
    func resumePending(contextProvider: () -> AIContext?) {
        for p in pending {
            if inFlightKeys.contains(p.dedupKey) { continue }
            scheduleOperation(for: p, context: contextProvider())
        }
    }

    // MARK: Internal

    private func scheduleOperation(for p: Pending, context: AIContext?) {
        // Idempotency: prevent duplicate operations for the same id/key
        if inFlight.contains(p.id) || inFlightKeys.contains(p.dedupKey) { return }
        inFlight.insert(p.id)
        inFlightKeys.insert(p.dedupKey)

        let op = BlockOperation { [weak self] in
            guard let self = self else { return }
            Task {
                defer {
                    self.inFlight.remove(p.id)
                    self.inFlightKeys.remove(p.dedupKey)
                }
                do {
                    let responseContent = try await self.sessionManager.sendMessage(
                        content: p.content,
                        model: p.model,
                        mode: p.mode,
                        saveMessages: true
                    )

                    // Remove from pending and notify
                    await MainActor.run {
                        self.removePending(id: p.id)
                        self.markCompleted(p.dedupKey)
                        NotificationCenter.default.post(name: EventName.responseArrived, object: nil, userInfo: [
                            "content": responseContent,
                            "model": p.model.rawValue,
                            "mode": p.mode.rawValue
                        ])
                    }
                } catch {
                    await MainActor.run {
                        self.removePending(id: p.id)
                        NotificationCenter.default.post(name: EventName.requestFailed, object: nil, userInfo: [
                            "error": error.localizedDescription
                        ])
                    }
                }
            }
        }
        queue.addOperation(op)
    }

    private func removePending(id: UUID) {
        pending.removeAll { $0.id == id }
    }

    // MARK: Persistence

    private func persistPending() {
        do {
            let data = try JSONEncoder().encode(pending)
            try data.write(to: pendingURL, options: .atomic)
        } catch {
            print("⚠️ [ChatRequestCenter] persistPending failed: \(error)")
        }
    }

    private func loadPending() {
        do {
            let data = try Data(contentsOf: pendingURL)
            let arr = try JSONDecoder().decode([Pending].self, from: data)
            self.pending = arr
        } catch {
            self.pending = []
        }
    }

    private func persistCompletedKeys() {
        do {
            let entries = Array(completedIndex.values)
            let data = try JSONEncoder().encode(entries)
            try data.write(to: completedURL, options: .atomic)
        } catch {
            print("⚠️ [ChatRequestCenter] persistCompletedKeys failed: \(error)")
        }
    }

    private func loadCompletedKeys() {
        do {
            let data = try Data(contentsOf: completedURL)
            // 1) 최신 포맷 시도: [CompletedEntry]
            if let entries = try? JSONDecoder().decode([CompletedEntry].self, from: data) {
                var dict: [String: CompletedEntry] = [:]
                for e in entries { dict[e.key] = e }
                self.completedIndex = dict
                return
            }
            // 2) 레거시 포맷: [String]
            if let legacy = try? JSONDecoder().decode([String].self, from: data) {
                let now = Date()
                var dict: [String: CompletedEntry] = [:]
                for k in legacy {
                    dict[k] = CompletedEntry(key: k, createdAt: now, lastSeenAt: now)
                }
                self.completedIndex = dict
                return
            }
            self.completedIndex = [:]
        } catch {
            self.completedIndex = [:]
        }
    }

    // MARK: - Dedup Helpers
    private static func computeDedupKey(sessionId: String, mode: AIMode, content: String, model: AIModel) -> String {
        // 안정적 멱등 키(정규화된 콘텐츠 기반)
        let normalized = canonicalizeContent(content)
        let base = "sid=\(sessionId)|mode=\(mode.rawValue)|model=\(model.rawValue)|content=\(normalized)"
        return computeKeyHex(for: base)
    }

    // 레거시 키(정규화 이전: 원본 콘텐츠 기반) - 호환성용
    private static func computeLegacyDedupKey(sessionId: String, mode: AIMode, content: String, model: AIModel) -> String {
        let base = "sid=\(sessionId)|mode=\(mode.rawValue)|model=\(model.rawValue)|content=\(content)"
        return computeKeyHex(for: base)
    }

    private static func computeKeyHex(for base: String) -> String {
        let digest = SHA256.hash(data: Data(base.utf8))
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }

    private static func canonicalizeContent(_ content: String) -> String {
        // 줄바꿈 통일 및 트리밍, 제로-위드스 문자 제거, 길이 상한
        var s = content.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        s = s.replacingOccurrences(of: "\u{FEFF}", with: "")
            .replacingOccurrences(of: "\u{200B}", with: "")
            .replacingOccurrences(of: "\u{200C}", with: "")
            .replacingOccurrences(of: "\u{200D}", with: "")
        s = s.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.count > 8000 { s = String(s.prefix(8000)) }
        return s
    }

    private static func stableUUID(for key: String) -> UUID {
        let digest = SHA256.hash(data: Data(key.utf8))
        var bytes = Array(digest)
        if bytes.count < 16 { bytes += Array(repeating: 0, count: 16 - bytes.count) }
        let uuid: uuid_t = (
            bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]
        )
        return UUID(uuid: uuid)
    }
}

