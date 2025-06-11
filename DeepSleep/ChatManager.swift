import Foundation
import UIKit

// MARK: - 🚀 Enhanced Chat Models
struct ChatSession: Codable {
    let id: UUID
    let contextType: ContextType
    let startTime: Date
    var lastAccessTime: Date
    var messages: [StoredChatMessage]
    
    enum ContextType: String, Codable, CaseIterable {
        case general = "general"
        case diaryAnalysis = "diary_analysis"
        case emotionPatternAnalysis = "emotion_pattern"
        case presetRecommendation = "preset_recommendation"
        case enhancedTherapy = "enhanced_therapy"
    }
}

struct StoredChatMessage: Codable {
    let id: UUID
    let type: MessageType
    let text: String
    let timestamp: Date
    let metadata: [String: String]?
    
    enum MessageType: String, Codable {
        case user = "user"
        case bot = "bot"
        case system = "system"
        case loading = "loading"
        case presetRecommendation = "preset_recommendation"
    }
}

// MARK: - 🚀 Enhanced ChatManager (UserDefaults + CachedConversationManager만 사용)
class ChatManager {
    static let shared = ChatManager()
    
    // MARK: - 🚀 채팅 상태 보존용 메시지 배열
    private(set) var messages: [ChatMessage] = []
    
    // UserDefaults 기반 저장소만 사용 (Core Data 제거)
    private let storageKey = "cached_chat_sessions"
    
    // MARK: - Enhanced Memory Management
    private var activeSessions: [UUID: ChatSession] = [:]
    private let maxActiveSessions = 10
    private let automaticCleanupInterval: TimeInterval = 24 * 60 * 60 // 24시간
    private let maxSessionLifetime: TimeInterval = 7 * 24 * 60 * 60 // 1주 (단축)
    
    private init() {
        setupAutomaticCleanup()
        loadRecentMessages() // 🚀 앱 시작 시 최근 메시지 로드
    }
    
    // MARK: - 🚀 메시지 관리 (상태 보존용)
    func append(_ message: ChatMessage) {
        messages.append(message)
        
        // 메모리 최적화: 메시지가 너무 많으면 오래된 것부터 제거
        if messages.count > 200 {
            messages.removeFirst(50) // 처음 50개 제거
        }
        
        // CachedConversationManager에도 저장
        do {
            let cachedMessage = CachedMessage(
                id: UUID(),
                role: message.type == .user ? .user : .assistant,
                content: message.text,
                createdAt: Date()
            )
            try CachedConversationManager.shared.append(cachedMessage)
            print("💾 [appendChat] ChatManager에 메시지 저장: \(message.type == .user ? "user" : "bot")")
        } catch {
            print("⚠️ [ChatManager] 캐시 저장 실패: \(error)")
        }
    }
    
    func loadRecentMessages() {
        do {
            let recentHistory = try CachedConversationManager.shared.recentHistory()
            messages = recentHistory.map { cachedMsg in
                ChatMessage(
                    type: cachedMsg.role == .user ? .user : .bot,
                    text: cachedMsg.content
                )
            }
            print("✅ [ChatManager] ChatManager에서 \(messages.count)개 메시지 로드 완료")
        } catch {
            print("⚠️ [ChatManager] 최근 메시지 로드 실패: \(error)")
            messages = []
        }
    }
    
    func clearMessages() {
        messages.removeAll()
        print("🗑️ [ChatManager] 메시지 초기화 완료")
    }
    
    // MARK: - 🔄 Session Management (UserDefaults만 사용)
    func createSession(contextType: ChatSession.ContextType = .general) -> UUID {
        let sessionId = UUID()
        let session = ChatSession(
            id: sessionId,
            contextType: contextType,
            startTime: Date(),
            lastAccessTime: Date(),
            messages: []
        )
        
        activeSessions[sessionId] = session
        saveSession(session)
        
        print("✅ [ChatManager] 새 세션 생성: \(contextType) - \(sessionId)")
        return sessionId
    }
    
    func createSession(id: UUID, contextType: ChatSession.ContextType = .general) -> UUID {
        let session = ChatSession(
            id: id,
            contextType: contextType,
            startTime: Date(),
            lastAccessTime: Date(),
            messages: []
        )
        
        activeSessions[id] = session
        saveSession(session)
        
        print("✅ [ChatManager] 새 세션 생성 (ID 지정): \(contextType) - \(id)")
        return id
    }
    
    func getSession(_ sessionId: UUID) -> ChatSession? {
        // 메모리에서 먼저 확인
        if let activeSession = activeSessions[sessionId] {
            return activeSession
        }
        
        // UserDefaults에서 로드
        return loadSessionFromUserDefaults(sessionId)
    }
    
    func addMessage(to sessionId: UUID, message: StoredChatMessage) {
        guard var session = getSession(sessionId) else {
            print("⚠️ [ChatManager] 세션을 찾을 수 없음: \(sessionId)")
            return
        }
        
        session.messages.append(message)
        session.lastAccessTime = Date()
        
        activeSessions[sessionId] = session
        saveSession(session)
    }
    
    func getMessages(for sessionId: UUID) -> [StoredChatMessage] {
        return getSession(sessionId)?.messages ?? []
    }
    
    // MARK: - 🔄 UserDefaults Persistence (Core Data 완전 제거)
    private func saveSession(_ session: ChatSession) {
        var allSessions = loadAllSessionsFromUserDefaults()
        allSessions[session.id] = session
        
        // 세션이 너무 많으면 정리
        if allSessions.count > 50 {
            let cutoffDate = Date().addingTimeInterval(-maxSessionLifetime)
            allSessions = allSessions.filter { _, session in
                session.lastAccessTime > cutoffDate
            }
        }
        
        if let encoded = try? JSONEncoder().encode(allSessions) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }
    
    private func loadSessionFromUserDefaults(_ sessionId: UUID) -> ChatSession? {
        let allSessions = loadAllSessionsFromUserDefaults()
        return allSessions[sessionId]
    }
    
    private func loadAllSessionsFromUserDefaults() -> [UUID: ChatSession] {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let sessions = try? JSONDecoder().decode([UUID: ChatSession].self, from: data) else {
            return [:]
        }
        return sessions
    }
    
    // MARK: - 🧹 Automatic Cleanup
    private func setupAutomaticCleanup() {
        Timer.scheduledTimer(withTimeInterval: automaticCleanupInterval, repeats: true) { [weak self] _ in
            self?.performAutomaticCleanup()
        }
    }
    
    private func performAutomaticCleanup() {
        let cutoffDate = Date().addingTimeInterval(-maxSessionLifetime)
        
        // UserDefaults에서 오래된 세션 정리
        cleanupUserDefaultsSessions(olderThan: cutoffDate)
        
        // 메모리에서 비활성 세션 정리
        activeSessions = activeSessions.filter { _, session in
            session.lastAccessTime > cutoffDate
        }
        
        print("🧹 [ChatManager] 자동 정리 완료 - 활성 세션: \(activeSessions.count)개")
    }
    
    private func cleanupUserDefaultsSessions(olderThan cutoffDate: Date) {
        var allSessions = loadAllSessionsFromUserDefaults()
        let initialCount = allSessions.count
        
        allSessions = allSessions.filter { _, session in
            session.lastAccessTime > cutoffDate
        }
        
        if let encoded = try? JSONEncoder().encode(allSessions) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
        
        print("🗑️ [ChatManager] UserDefaults에서 \(initialCount - allSessions.count)개 오래된 세션 정리")
    }
    
    // MARK: - 📊 Analytics & Stats
    func getSessionStats() -> (totalSessions: Int, activeSessions: Int, oldestSession: Date?) {
        let activeSessions = self.activeSessions.count
        let allSessions = loadAllSessionsFromUserDefaults()
        let oldestSession = allSessions.values.map(\.startTime).min()
        return (allSessions.count, activeSessions, oldestSession)
    }
    
    // MARK: - 🆕 Enhanced Features
    func exportSessionData(_ sessionId: UUID) -> Data? {
        guard let session = getSession(sessionId) else { return nil }
        return try? JSONEncoder().encode(session)
    }
    
    func importSessionData(_ data: Data) -> UUID? {
        guard let session = try? JSONDecoder().decode(ChatSession.self, from: data) else { return nil }
        saveSession(session)
        return session.id
    }
    
    func clearAllSessions() {
        activeSessions.removeAll()
        UserDefaults.standard.removeObject(forKey: storageKey)
        print("🗑️ [ChatManager] 모든 세션 삭제 완료")
    }
    
    // MARK: - 🆕 추가된 getSessions 메서드
    func getSessions() -> [ChatSession] {
        // 1. 메모리에서 활성 세션들 가져오기
        var allSessions = Array(activeSessions.values)
        
        // 2. UserDefaults에서 저장된 세션들 로드
        allSessions.append(contentsOf: loadAllSessionsFromUserDefaults().values)
        
        // 3. 중복 제거 (ID 기준)
        var uniqueSessions: [UUID: ChatSession] = [:]
        for session in allSessions {
            uniqueSessions[session.id] = session
        }
        
        // 4. 최신 순으로 정렬하여 반환
        return Array(uniqueSessions.values).sorted { $0.lastAccessTime > $1.lastAccessTime }
    }
} 
