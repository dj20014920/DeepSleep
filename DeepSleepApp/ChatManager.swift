import Foundation
import Core

/// 채팅 세션 및 메시지 관리를 담당하는 매니저
/// PERF-WARNING: 대량의 채팅 히스토리 처리 시 메모리 사용량 주의
/// - 테스트 방안: Instruments의 Allocations로 메모리 누수 확인
public class ChatManager {
    public static let shared = ChatManager()
    
    private let userDefaults = UserDefaults.standard
    private let chatHistoryKey = "deepSleep_chatHistory"
    private let sessionMetadataKey = "deepSleep_sessionMetadata"
    
    // 메모리 캐시
    private var sessionCache: [String: ChatSession] = [:]
    private let cacheQueue = DispatchQueue(label: "com.deepsleep.chatmanager", attributes: .concurrent)
    
    private init() {
        loadAllSessions()
    }
    
    
    // MARK: - Public Methods
    
    /// 모든 채팅 세션 가져오기 (최근 활동 순으로 정렬)
    public func getSessions() -> [ChatSession] {
        return cacheQueue.sync {
            Array(sessionCache.values).sorted { $0.lastActivityAt > $1.lastActivityAt }
        }
    }
    
    /// 특정 세션 가져오기
    public func getSession(id: String) -> ChatSession? {
        return cacheQueue.sync {
            sessionCache[id]
        }
    }
    
    /// 새 세션 생성
    public func createSession(metadata: ChatSessionMetadata? = nil) -> ChatSession {
        let session = ChatSession(
            id: UUID().uuidString,
            createdAt: Date(),
            lastActivityAt: Date(),
            messages: [],
            metadata: metadata
        )
        
        cacheQueue.async(flags: .barrier) {
            self.sessionCache[session.id] = session
            self.saveSessionToDisk(session)
        }
        
        return session
    }
    
    /// 세션에 메시지 추가
    public func addMessage(to sessionId: String, message: StoredChatMessage) {
        cacheQueue.async(flags: .barrier) {
            guard var session = self.sessionCache[sessionId] else { return }
            
            session.messages.append(message)
            session.lastActivityAt = Date()
            
            self.sessionCache[sessionId] = session
            self.saveSessionToDisk(session)
        }
    }
    
    /// 🎯 ChatMessage를 현재 활성 세션에 추가 (ChatViewController에서 호출)
    public func append(_ message: ChatMessage) {
        print("🔵 [ChatManager] append 호출됨 - 메시지: \(message.text?.prefix(50) ?? "")")
        
        // 현재 활성 세션 가져오기 또는 새로 생성
        let currentSession = getCurrentOrCreateSession()
        
        // ChatMessage를 StoredChatMessage로 변환
        let storedMessage = StoredChatMessage(
            id: message.id,
            text: message.text ?? "",
            type: getStoredMessageType(from: message.type, sender: message.sender),
            timestamp: message.date,
            metadata: createStringMetadata(from: message)
        )
        
        // 세션에 메시지 추가
        addMessage(to: currentSession.id, message: storedMessage)
        
        // 🎯 MessageStore에도 저장 (이중 저장으로 안정성 확보)
        Task {
            do {
                try await MessageStore.shared.saveMessage(
                    content: message.text ?? "",
                    isUser: message.sender == .user,
                    messageType: getMessageTypeString(from: message.type),
                    isPersistent: shouldBePersistent(message.type)
                )
                print("🔵 [ChatManager] MessageStore에도 저장 완료")
            } catch {
                print("❌ [ChatManager] MessageStore 저장 실패: \(error)")
            }
        }
        
        print("🔵 [ChatManager] 메시지 저장 완료 - 세션 ID: \(currentSession.id)")
    }
    
    /// 현재 활성 세션 가져오기 또는 새로 생성
    private func getCurrentOrCreateSession() -> ChatSession {
        // 가장 최근 세션 가져오기
        let sessions = getSessions()
        if let latestSession = sessions.first,
           Calendar.current.isDate(latestSession.lastActivityAt, inSameDayAs: Date()) {
            return latestSession
        }
        
        // 새 세션 생성
        return createSession()
    }
    
    /// ChatMessageType을 StoredMessageType으로 변환
    private func getStoredMessageType(from type: ChatMessageType, sender: ChatMessageSender) -> StoredMessageType {
        switch type {
        case .user: return .user
        case .bot, .aiResponse: return .bot
        case .system: return .system
        case .presetRecommendation: return .presetRecommendation
        case .error: return .error
        default: 
            // sender 기반으로 결정
            return sender == .user ? .user : .bot
        }
    }
    
    /// ChatMessageType을 String으로 변환 (MessageStore 호환성용)
    private func getMessageTypeString(from type: ChatMessageType) -> String {
        switch type {
        case .user: return "user"
        case .bot, .aiResponse: return "bot"
        case .system: return "system"
        case .presetRecommendation: return "preset"
        case .recommendationSelector: return "selector"
        case .presetOptions, .postPresetOptions: return "options"
        case .loading: return "loading"
        case .error: return "error"
        }
    }
    
    /// 메시지 메타데이터 생성 (Any 타입)
    private func createMetadata(from message: ChatMessage) -> [String: Any] {
        var metadata: [String: Any] = [:]
        
        if let quickActions = message.quickActions {
            metadata["quickActions"] = quickActions.map { ["title": $0.title, "action": $0.action] }
        }
        
        metadata["messageId"] = message.id.uuidString
        
        return metadata
    }
    
    /// 메시지 메타데이터 생성 (String 타입 - ChatManager 호환성용)
    private func createStringMetadata(from message: ChatMessage) -> [String: String] {
        var metadata: [String: String] = [:]
        
        if let quickActions = message.quickActions {
            let actionsString = quickActions.map { "\($0.title):\($0.action)" }.joined(separator: ",")
            metadata["quickActions"] = actionsString
        }
        
        metadata["messageId"] = message.id.uuidString
        metadata["messageType"] = getMessageTypeString(from: message.type)
        
        return metadata
    }
    
    /// 메시지 타입에 따라 지속성 여부 결정
    private func shouldBePersistent(_ type: ChatMessageType) -> Bool {
        switch type {
        case .system: return true
        case .presetRecommendation: return true
        case .error: return true
        default: return false
        }
    }
    
    /// 세션 삭제
    public func deleteSession(id: String) {
        cacheQueue.async(flags: .barrier) {
            self.sessionCache.removeValue(forKey: id)
            self.deleteSessionFromDisk(id)
        }
    }
    
    /// 모든 세션 삭제
    public func clearAllSessions() {
        cacheQueue.async(flags: .barrier) {
            self.sessionCache.removeAll()
            self.userDefaults.removeObject(forKey: self.chatHistoryKey)
            self.userDefaults.removeObject(forKey: self.sessionMetadataKey)
        }
    }
    
    // MARK: - Private Methods
    
    private func loadAllSessions() {
        guard let data = userDefaults.data(forKey: chatHistoryKey),
              let sessions = try? JSONDecoder().decode([String: ChatSession].self, from: data) else {
            return
        }
        
        cacheQueue.async(flags: .barrier) {
            self.sessionCache = sessions
        }
    }
    
    private func saveSessionToDisk(_ session: ChatSession) {
        var allSessions = sessionCache
        allSessions[session.id] = session
        
        guard let data = try? JSONEncoder().encode(allSessions) else { return }
        userDefaults.set(data, forKey: chatHistoryKey)
    }
    
    private func deleteSessionFromDisk(_ sessionId: String) {
        var allSessions = sessionCache
        allSessions.removeValue(forKey: sessionId)
        
        guard let data = try? JSONEncoder().encode(allSessions) else { return }
        userDefaults.set(data, forKey: chatHistoryKey)
    }
    
    
    /// 모든 메시지 가져오기 (ChatRouter 호환성용)
    public var messages: [StoredChatMessage] {
        return cacheQueue.sync {
            var allMessages: [StoredChatMessage] = []
            for session in sessionCache.values {
                allMessages.append(contentsOf: session.messages)
            }
            return allMessages.sorted { $0.timestamp > $1.timestamp }
        }
    }
}

// MARK: - Data Models

/// 채팅 세션
public struct ChatSession: Codable {
    public let id: String
    public let createdAt: Date
    public var lastActivityAt: Date
    public var messages: [StoredChatMessage]
    public let metadata: ChatSessionMetadata?
    
    public init(id: String, createdAt: Date, lastActivityAt: Date, messages: [StoredChatMessage], metadata: ChatSessionMetadata?) {
        self.id = id
        self.createdAt = createdAt
        self.lastActivityAt = lastActivityAt
        self.messages = messages
        self.metadata = metadata
    }
}

/// 채팅 세션 메타데이터
public struct ChatSessionMetadata: Codable {
    public let emotion: String?
    public let context: String?
    public let userProfile: String?
    
    public init(emotion: String? = nil, context: String? = nil, userProfile: String? = nil) {
        self.emotion = emotion
        self.context = context
        self.userProfile = userProfile
    }
}

/// 저장된 채팅 메시지
public struct StoredChatMessage: Codable {
    public let id: UUID
    public let text: String
    public let type: StoredMessageType
    public let timestamp: Date
    public let metadata: [String: String]?
    
    public init(id: UUID, text: String, type: StoredMessageType, timestamp: Date, metadata: [String: String]?) {
        self.id = id
        self.text = text
        self.type = type
        self.timestamp = timestamp
        self.metadata = metadata
    }
}

/// 저장된 메시지 타입
public enum StoredMessageType: String, Codable {
    case user = "user"
    case bot = "bot"
    case system = "system"
    case presetRecommendation = "presetRecommendation"
    case error = "error"
}

// MARK: - Memory Management

extension ChatManager {
    /// 메모리 사용량 계산
    public var estimatedMemoryUsage: Int {
        return cacheQueue.sync {
            var totalSize = 0
            for session in sessionCache.values {
                totalSize += session.estimatedMemorySize
            }
            return totalSize
        }
    }
    
    /// 오래된 세션 정리 (30일 이상)
    public func cleanupOldSessions(olderThan days: Int = 30) {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        
        cacheQueue.async(flags: .barrier) {
            let sessionsToDelete = self.sessionCache.values.filter { $0.lastActivityAt < cutoffDate }
            
            for session in sessionsToDelete {
                self.sessionCache.removeValue(forKey: session.id)
            }
            
            if !sessionsToDelete.isEmpty {
                self.saveAllSessionsToDisk()
            }
        }
    }
    
    private func saveAllSessionsToDisk() {
        guard let data = try? JSONEncoder().encode(sessionCache) else { return }
        userDefaults.set(data, forKey: chatHistoryKey)
    }
}

// MARK: - Extensions

extension ChatSession {
    /// 예상 메모리 크기
    var estimatedMemorySize: Int {
        var size = MemoryLayout<ChatSession>.size
        
        for message in messages {
            size += message.text.utf8.count
            size += MemoryLayout<StoredChatMessage>.size
        }
        
        return size
    }
}
