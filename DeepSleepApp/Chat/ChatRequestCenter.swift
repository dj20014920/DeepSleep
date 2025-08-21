import Foundation
import Combine

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
    private let service: UnifiedAIService
    private let messageStore = MessageStore.shared

    private init(service: UnifiedAIService = UnifiedAIServiceImpl.shared) {
        self.service = service
        self.queue = OperationQueue()
        self.queue.name = "chat.requests.queue"
        self.queue.maxConcurrentOperationCount = 2
        self.queue.qualityOfService = .userInitiated
    }

    struct Pending: Codable {
        let id: UUID
        let content: String
        let model: AIModel
        let mode: AIMode
        let createdAt: Date
    }

    private var pending: [Pending] = [] { didSet { persistPending() } }
    private let pendingURL: URL = {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return dir.appendingPathComponent("pending_chat_requests.json")
    }()

    // MARK: Public API

    /// Enqueue a chat request. Returns the user message id persisted.
    @discardableResult
    func enqueue(content: String, model: AIModel, mode: AIMode, context: AIContext?) -> UUID {
        // 1) Persist user message immediately
        let userMsgId = messageStore.saveMessage(content: content, isUser: true, messageType: "user", isPersistent: false)

        // 2) Create pending record
        let p = Pending(id: UUID(), content: content, model: model, mode: mode, createdAt: Date())
        pending.append(p)

        // 3) Schedule operation
        scheduleOperation(for: p, context: context)

        return userMsgId
    }

    /// Call this on app launch/foreground to resume pending work
    func resumePending(contextProvider: () -> AIContext?) {
        for p in pending { scheduleOperation(for: p, context: contextProvider()) }
    }

    // MARK: Internal

    private func scheduleOperation(for p: Pending, context: AIContext?) {
        let op = BlockOperation { [weak self] in
            guard let self = self else { return }
            Task {
                do {
                    let response = try await self.service.sendMessage(
                        content: p.content,
                        model: p.model,
                        mode: p.mode,
                        context: context,
                        tokenConfig: nil,
                        assembledPrompt: nil
                    )
                    // Persist AI message
                    self.messageStore.saveMessage(content: response.content, isUser: false, messageType: "bot", isPersistent: false)

                    // Remove from pending and notify
                    await MainActor.run {
                        self.removePending(id: p.id)
                        NotificationCenter.default.post(name: EventName.responseArrived, object: nil, userInfo: [
                            "content": response.content,
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
}

