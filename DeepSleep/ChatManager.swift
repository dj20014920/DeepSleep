import Foundation
import UIKit
import CoreData

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

// MARK: - 🚀 Core Data Entity Extensions
@objc(ChatSessionEntity)
public class ChatSessionEntity: NSManagedObject {}

extension ChatSessionEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<ChatSessionEntity> {
        return NSFetchRequest<ChatSessionEntity>(entityName: "ChatSessionEntity")
    }
    
    @NSManaged public var sessionId: UUID
    @NSManaged public var contextType: String
    @NSManaged public var startTime: Date
    @NSManaged public var lastAccessTime: Date
    @NSManaged public var messagesData: Data?
}

// MARK: - 🚀 Enhanced ChatManager with Core Data
class ChatManager {
    static let shared = ChatManager()
    
    // MARK: - 🚀 채팅 상태 보존용 메시지 배열
    private(set) var messages: [ChatMessage] = []
    
    // Core Data Stack
    private lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "ChatModel")
        
        // In-memory store for testing/privacy mode
        if UserDefaults.standard.bool(forKey: "privacy_mode_enabled") {
            let description = NSPersistentStoreDescription()
            description.type = NSInMemoryStoreType
            container.persistentStoreDescriptions = [description]
        }
        
        container.loadPersistentStores { _, error in
            if let error = error {
                print("⚠️ Core Data 로드 실패: \(error)")
                // Fallback to UserDefaults
                self.fallbackToUserDefaults = true
            }
        }
        
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        return container
    }()
    
    private var context: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    // Fallback mechanism
    private var fallbackToUserDefaults = false
    private let legacyStorageKey = "cached_chat_sessions"
    
    // MARK: - Enhanced Memory Management
    private var activeSessions: [UUID: ChatSession] = [:]
    private let maxActiveSessions = 10
    private let automaticCleanupInterval: TimeInterval = 24 * 60 * 60 // 24시간
    private let maxSessionLifetime: TimeInterval = 14 * 24 * 60 * 60 // 2주
    
    private init() {
        setupAutomaticCleanup()
        migrateLegacyData()
        loadRecentMessages() // 🚀 앱 시작 시 최근 메시지 로드
    }
    
    // MARK: - 🚀 메시지 관리 (상태 보존용)
    func append(_ message: ChatMessage) {
        messages.append(message)
        // CachedConversationManager에도 저장
        do {
            let cachedMessage = CachedMessage(
                id: UUID(),
                role: message.type == .user ? .user : .assistant,
                content: message.text,
                createdAt: Date()
            )
            try CachedConversationManager.shared.append(cachedMessage)
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
            print("✅ [ChatManager] 최근 메시지 \(messages.count)개 로드 완료")
        } catch {
            print("⚠️ [ChatManager] 최근 메시지 로드 실패: \(error)")
            messages = []
        }
    }
    
    func clearMessages() {
        messages.removeAll()
        print("🗑️ [ChatManager] 메시지 초기화 완료")
    }
    
    // MARK: - 🔄 Session Management
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
    
    func getSession(_ sessionId: UUID) -> ChatSession? {
        // 메모리에서 먼저 확인
        if let activeSession = activeSessions[sessionId] {
            return activeSession
        }
        
        // Core Data에서 로드
        if let session = loadSessionFromCoreData(sessionId) {
            activeSessions[sessionId] = session
            return session
        }
        
        // Fallback: UserDefaults에서 로드
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
    
    // MARK: - 🔄 Enhanced Persistence
    private func saveSession(_ session: ChatSession) {
        if fallbackToUserDefaults {
            saveSessionToUserDefaults(session)
            return
        }
        
        // Core Data 저장
        let request: NSFetchRequest<ChatSessionEntity> = ChatSessionEntity.fetchRequest()
        request.predicate = NSPredicate(format: "sessionId == %@", session.id as CVarArg)
        
        do {
            let existingSessions = try context.fetch(request)
            let entity = existingSessions.first ?? ChatSessionEntity(context: context)
            
            entity.sessionId = session.id
            entity.contextType = session.contextType.rawValue
            entity.startTime = session.startTime
            entity.lastAccessTime = session.lastAccessTime
            
            if let encodedMessages = try? JSONEncoder().encode(session.messages) {
                entity.messagesData = encodedMessages
            }
            
            try context.save()
        } catch {
            print("⚠️ [ChatManager] Core Data 저장 실패: \(error)")
            // Fallback to UserDefaults
            saveSessionToUserDefaults(session)
        }
    }
    
    private func loadSessionFromCoreData(_ sessionId: UUID) -> ChatSession? {
        let request: NSFetchRequest<ChatSessionEntity> = ChatSessionEntity.fetchRequest()
        request.predicate = NSPredicate(format: "sessionId == %@", sessionId as CVarArg)
        
        do {
            let entities = try context.fetch(request)
            guard let entity = entities.first else { return nil }
            
            var messages: [StoredChatMessage] = []
            if let messagesData = entity.messagesData,
               let decodedMessages = try? JSONDecoder().decode([StoredChatMessage].self, from: messagesData) {
                messages = decodedMessages
            }
            
            let contextType = ChatSession.ContextType(rawValue: entity.contextType) ?? .general
            
            return ChatSession(
                id: entity.sessionId,
                contextType: contextType,
                startTime: entity.startTime,
                lastAccessTime: entity.lastAccessTime,
                messages: messages
            )
        } catch {
            print("⚠️ [ChatManager] Core Data 로드 실패: \(error)")
            return nil
        }
    }
    
    // MARK: - 🔄 UserDefaults Fallback
    private func saveSessionToUserDefaults(_ session: ChatSession) {
        var allSessions = loadAllSessionsFromUserDefaults()
        allSessions[session.id] = session
        
        if let encoded = try? JSONEncoder().encode(allSessions) {
            UserDefaults.standard.set(encoded, forKey: legacyStorageKey)
        }
    }
    
    private func loadSessionFromUserDefaults(_ sessionId: UUID) -> ChatSession? {
        let allSessions = loadAllSessionsFromUserDefaults()
        return allSessions[sessionId]
    }
    
    private func loadAllSessionsFromUserDefaults() -> [UUID: ChatSession] {
        guard let data = UserDefaults.standard.data(forKey: legacyStorageKey),
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
        
        // Core Data에서 오래된 세션 정리
        if !fallbackToUserDefaults {
            cleanupCoreDataSessions(olderThan: cutoffDate)
        } else {
            cleanupUserDefaultsSessions(olderThan: cutoffDate)
        }
        
        // 메모리에서 비활성 세션 정리
        activeSessions = activeSessions.filter { _, session in
            session.lastAccessTime > cutoffDate
        }
        
        print("🧹 [ChatManager] 자동 정리 완료 - 활성 세션: \(activeSessions.count)개")
    }
    
    private func cleanupCoreDataSessions(olderThan cutoffDate: Date) {
        let request: NSFetchRequest<ChatSessionEntity> = ChatSessionEntity.fetchRequest()
        request.predicate = NSPredicate(format: "lastAccessTime < %@", cutoffDate as NSDate)
        
        do {
            let oldSessions = try context.fetch(request)
            for session in oldSessions {
                context.delete(session)
            }
            try context.save()
            print("🗑️ [ChatManager] Core Data에서 \(oldSessions.count)개 오래된 세션 정리")
        } catch {
            print("⚠️ [ChatManager] Core Data 정리 실패: \(error)")
        }
    }
    
    private func cleanupUserDefaultsSessions(olderThan cutoffDate: Date) {
        var allSessions = loadAllSessionsFromUserDefaults()
        let initialCount = allSessions.count
        
        allSessions = allSessions.filter { _, session in
            session.lastAccessTime > cutoffDate
        }
        
        if let encoded = try? JSONEncoder().encode(allSessions) {
            UserDefaults.standard.set(encoded, forKey: legacyStorageKey)
        }
        
        print("🗑️ [ChatManager] UserDefaults에서 \(initialCount - allSessions.count)개 오래된 세션 정리")
    }
    
    // MARK: - 📊 Analytics & Stats
    func getSessionStats() -> (totalSessions: Int, activeSessions: Int, oldestSession: Date?) {
        let activeSessions = self.activeSessions.count
        
        if fallbackToUserDefaults {
            let allSessions = loadAllSessionsFromUserDefaults()
            let oldestSession = allSessions.values.map(\.startTime).min()
            return (allSessions.count, activeSessions, oldestSession)
        } else {
            let request: NSFetchRequest<ChatSessionEntity> = ChatSessionEntity.fetchRequest()
            do {
                let totalSessions = try context.count(for: request)
                
                // 가장 오래된 세션 찾기
                request.sortDescriptors = [NSSortDescriptor(key: "startTime", ascending: true)]
                request.fetchLimit = 1
                let oldestSessions = try context.fetch(request)
                let oldestSession = oldestSessions.first?.startTime
                
                return (totalSessions, activeSessions, oldestSession)
            } catch {
                print("⚠️ [ChatManager] 통계 조회 실패: \(error)")
                return (0, activeSessions, nil)
            }
        }
    }
    
    // MARK: - 🔄 Legacy Migration
    private func migrateLegacyData() {
        // 기존 ChatManager 데이터가 있다면 마이그레이션
        if UserDefaults.standard.data(forKey: "chat_sessions_legacy") != nil {
            print("🔄 [ChatManager] 레거시 데이터 마이그레이션 시작")
            // 마이그레이션 로직 구현
            UserDefaults.standard.removeObject(forKey: "chat_sessions_legacy")
        }
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
        
        if fallbackToUserDefaults {
            UserDefaults.standard.removeObject(forKey: legacyStorageKey)
        } else {
            let request: NSFetchRequest<NSFetchRequestResult> = ChatSessionEntity.fetchRequest()
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
            
            do {
                try context.execute(deleteRequest)
                try context.save()
            } catch {
                print("⚠️ [ChatManager] 전체 세션 삭제 실패: \(error)")
            }
        }
        
        print("🗑️ [ChatManager] 모든 세션 삭제 완료")
    }
    
    // MARK: - 🆕 추가된 getSessions 메서드
    func getSessions() -> [ChatSession] {
        // 1. 메모리에서 활성 세션들 가져오기
        var allSessions = Array(activeSessions.values)
        
        // 2. Core Data에서 저장된 세션들 로드
        if !fallbackToUserDefaults {
            allSessions.append(contentsOf: getAllSessionsFromCoreData())
        } else {
            allSessions.append(contentsOf: loadAllSessionsFromUserDefaults().values)
        }
        
        // 3. 중복 제거 (ID 기준)
        var uniqueSessions: [UUID: ChatSession] = [:]
        for session in allSessions {
            uniqueSessions[session.id] = session
        }
        
        // 4. 최신 순으로 정렬하여 반환
        return Array(uniqueSessions.values).sorted { $0.lastAccessTime > $1.lastAccessTime }
    }
    
    private func getAllSessionsFromCoreData() -> [ChatSession] {
        let request: NSFetchRequest<ChatSessionEntity> = ChatSessionEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "lastAccessTime", ascending: false)]
        
        do {
            let entities = try context.fetch(request)
            return entities.compactMap { entity in
                var messages: [StoredChatMessage] = []
                if let messagesData = entity.messagesData,
                   let decodedMessages = try? JSONDecoder().decode([StoredChatMessage].self, from: messagesData) {
                    messages = decodedMessages
                }
                
                let contextType = ChatSession.ContextType(rawValue: entity.contextType) ?? .general
                
                return ChatSession(
                    id: entity.sessionId,
                    contextType: contextType,
                    startTime: entity.startTime,
                    lastAccessTime: entity.lastAccessTime,
                    messages: messages
                )
            }
        } catch {
            print("⚠️ [ChatManager] 모든 세션 로드 실패: \(error)")
            return []
        }
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
} 