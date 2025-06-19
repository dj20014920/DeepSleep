import Foundation

// MARK: - Domain Entities for Chat

public enum MessageType: String, Codable, Equatable {
    case user
    case bot
    case aiResponse
    case presetRecommendation
    case recommendationSelector
    case loading
    case error
    case system
    case presetOptions
    case postPresetOptions
}

public struct ChatEntity: Codable, Identifiable, Equatable {
    public let id: UUID
    public let type: MessageType
    public let content: String
    public let presetName: String?
    public let timestamp: Date
    public let metadata: [String: String]?
    
    public init(
        id: UUID = UUID(),
        type: MessageType,
        content: String,
        presetName: String? = nil,
        timestamp: Date = Date(),
        metadata: [String: String]? = nil
    ) {
        self.id = id
        self.type = type
        self.content = content
        self.presetName = presetName
        self.timestamp = timestamp
        self.metadata = metadata
    }
    
    // Equatable conformance
    public static func == (lhs: ChatEntity, rhs: ChatEntity) -> Bool {
        return lhs.id == rhs.id &&
               lhs.type == rhs.type &&
               lhs.content == rhs.content &&
               lhs.presetName == rhs.presetName &&
               lhs.timestamp == rhs.timestamp
    }
}

// MARK: - Chat Session Entity
public struct ChatSessionEntity: Codable, Identifiable {
    public let id: UUID
    public let title: String
    public let createdAt: Date
    public let updatedAt: Date
    public let messageCount: Int
    
    public init(
        id: UUID = UUID(),
        title: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        messageCount: Int = 0
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.messageCount = messageCount
    }
}

// MARK: - Chat Actions (Value Objects)
public struct ChatAction {
    public let title: String
    public let identifier: String
    public let isDestructive: Bool
    
    public init(title: String, identifier: String, isDestructive: Bool = false) {
        self.title = title
        self.identifier = identifier
        self.isDestructive = isDestructive
    }
}

// MARK: - Conversation Context Entity
public struct ConversationContextEntity: Codable {
    public let sessionId: UUID
    public let emotionalState: String?
    public let userPreferences: [String: String]
    public let lastActivity: Date
    
    public init(
        sessionId: UUID,
        emotionalState: String? = nil,
        userPreferences: [String: String] = [:],
        lastActivity: Date = Date()
    ) {
        self.sessionId = sessionId
        self.emotionalState = emotionalState
        self.userPreferences = userPreferences
        self.lastActivity = lastActivity
    }
} 