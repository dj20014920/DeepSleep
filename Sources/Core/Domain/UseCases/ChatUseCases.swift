import Foundation

// MARK: - Chat Use Cases

public protocol SendMessageUseCase {
    func execute(content: String, sessionId: UUID?) async throws -> Any // Will return ChatEntity
}

public protocol GetChatHistoryUseCase {
    func execute(sessionId: UUID?, limit: Int?) async throws -> [Any] // Will return [ChatEntity]
}

public protocol CreateChatSessionUseCase {
    func execute(title: String?) async throws -> UUID
}

public protocol DeleteChatSessionUseCase {
    func execute(sessionId: UUID) async throws
}

public protocol SearchMessagesUseCase {
    func execute(query: String, sessionId: UUID?) async throws -> [Any] // Will return [ChatEntity]
}

public protocol AnalyzeChatContextUseCase {
    func execute(sessionId: UUID) async throws -> [String: Any] // Will return conversation insights
}

// MARK: - Concrete Implementation Protocols

public protocol ChatService {
    var sendMessageUseCase: SendMessageUseCase { get }
    var getChatHistoryUseCase: GetChatHistoryUseCase { get }
    var createChatSessionUseCase: CreateChatSessionUseCase { get }
    var deleteChatSessionUseCase: DeleteChatSessionUseCase { get }
    var searchMessagesUseCase: SearchMessagesUseCase { get }
    var analyzeChatContextUseCase: AnalyzeChatContextUseCase { get }
}

// MARK: - Error Types

public enum ChatUseCaseError: Error, LocalizedError {
    case invalidContent
    case sessionNotFound(UUID)
    case repositoryError(Error)
    case unauthorized
    case networkError
    
    public var errorDescription: String? {
        switch self {
        case .invalidContent:
            return "Invalid message content"
        case .sessionNotFound(let id):
            return "Chat session not found: \(id)"
        case .repositoryError(let error):
            return "Repository error: \(error.localizedDescription)"
        case .unauthorized:
            return "Unauthorized access"
        case .networkError:
            return "Network connection error"
        }
    }
}

// MARK: - Chat Use Case Configuration

public struct ChatUseCaseConfiguration {
    public let maxMessageLength: Int
    public let sessionTimeout: TimeInterval
    public let enableAnalytics: Bool
    public let cacheEnabled: Bool
    
    public init(
        maxMessageLength: Int = 2000,
        sessionTimeout: TimeInterval = 3600, // 1 hour
        enableAnalytics: Bool = true,
        cacheEnabled: Bool = true
    ) {
        self.maxMessageLength = maxMessageLength
        self.sessionTimeout = sessionTimeout
        self.enableAnalytics = enableAnalytics
        self.cacheEnabled = cacheEnabled
    }
    
    public static let `default` = ChatUseCaseConfiguration()
}

// MARK: - Implementation Note
// Concrete implementations will be provided in the Data layer
// with proper dependency injection and repository access 