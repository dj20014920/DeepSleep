import Foundation

// MARK: - Chat Repository Protocol
// Note: Entities will be imported from their respective modules in actual implementation

public protocol ChatRepository {
    // MARK: - Message Operations
    func saveMessage<T: Codable & Identifiable>(_ message: T) async throws
    func getMessages<T: Codable & Identifiable>(for sessionId: UUID, limit: Int?) async throws -> [T]
    func getRecentMessages<T: Codable & Identifiable>(limit: Int) async throws -> [T]
    func deleteMessage(id: UUID) async throws
    func updateMessage<T: Codable & Identifiable>(_ message: T) async throws
    
    // MARK: - Session Operations
    func createSession(title: String) async throws -> UUID // Returns session ID
    func getSessions() async throws -> [Any] // Will be [ChatSessionEntity] in implementation
    func getSession(id: UUID) async throws -> Any? // Will be ChatSessionEntity? in implementation
    func updateSession(id: UUID, title: String?, messageCount: Int?) async throws
    func deleteSession(id: UUID) async throws
    
    // MARK: - Context Operations
    func saveContext<T: Codable>(sessionId: UUID, context: T) async throws
    func getContext<T: Codable>(for sessionId: UUID, type: T.Type) async throws -> T?
    func updateContext<T: Codable>(sessionId: UUID, context: T) async throws
    
    // MARK: - Search and Filter
    func searchMessages(query: String, sessionId: UUID?) async throws -> [Any]
    func getMessagesByType(type: String, sessionId: UUID?) async throws -> [Any]
    func getMessagesInDateRange(from: Date, to: Date) async throws -> [Any]
    
    // MARK: - Analytics
    func getMessageCount(for sessionId: UUID?) async throws -> Int
    func getSessionUsageStats() async throws -> [String: Any]
} 