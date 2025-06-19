import Foundation

// Re-export EmotionType for convenience
public typealias EmotionType = EmotionType

// MARK: - Chat Domain Entities

public enum ChatMessageType: String, Codable {
    case user = "user"
    case ai = "ai"
    case system = "system"
}

public struct ChatMessage: Codable, Identifiable, Equatable {
    public let id: UUID
    public let content: String
    public let type: ChatMessageType
    public let timestamp: Date
    public let emotion: String? // Store as string for Codable compatibility
    public let metadata: [String: String]?
    
    public init(
        id: UUID = UUID(),
        content: String,
        type: ChatMessageType,
        timestamp: Date = Date(),
        emotion: EmotionType? = nil,
        metadata: [String: String]? = nil
    ) {
        self.id = id
        self.content = content
        self.type = type
        self.timestamp = timestamp
        self.emotion = emotion?.rawValue
        self.metadata = metadata
    }
    
    // Computed property for EmotionType
    public var emotionType: EmotionType? {
        guard let emotion = emotion else { return nil }
        return EmotionType(rawValue: emotion)
    }
    
    public static func == (lhs: ChatMessage, rhs: ChatMessage) -> Bool {
        return lhs.id == rhs.id
    }
}

public struct ChatSession: Codable, Identifiable, Equatable {
    public let id: UUID
    public let title: String
    public let messages: [ChatMessage]
    public let createdAt: Date
    public let updatedAt: Date
    public let isActive: Bool
    public let metadata: [String: String]?
    
    public init(
        id: UUID = UUID(),
        title: String,
        messages: [ChatMessage] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        isActive: Bool = true,
        metadata: [String: String]? = nil
    ) {
        self.id = id
        self.title = title
        self.messages = messages
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isActive = isActive
        self.metadata = metadata
    }
    
    public static func == (lhs: ChatSession, rhs: ChatSession) -> Bool {
        return lhs.id == rhs.id
    }
}

public struct ChatAnalysisResult: Codable, Identifiable, Equatable {
    public let id: UUID
    public let messageId: UUID
    public let sentimentScore: Double // -1.0 to 1.0
    public let emotionScores: [String: Double] // Store as string keys for Codable
    public let keywords: [String]
    public let analysisTimestamp: Date
    public let confidence: Double
    
    public init(
        id: UUID = UUID(),
        messageId: UUID,
        sentimentScore: Double,
        emotionScores: [EmotionType: Double],
        keywords: [String] = [],
        analysisTimestamp: Date = Date(),
        confidence: Double = 0.0
    ) {
        self.id = id
        self.messageId = messageId
        self.sentimentScore = max(-1.0, min(1.0, sentimentScore))
        // Convert EmotionType keys to strings for Codable compatibility
        self.emotionScores = Dictionary(uniqueKeysWithValues: emotionScores.map { ($0.key.rawValue, $0.value) })
        self.keywords = keywords
        self.analysisTimestamp = analysisTimestamp
        self.confidence = max(0.0, min(1.0, confidence))
    }
    
    // Computed property for EmotionType scores
    public var emotionTypeScores: [EmotionType: Double] {
        return Dictionary(compactMap { key, value in
            guard let emotionType = EmotionType(rawValue: key) else { return nil }
            return (emotionType, value)
        })
    }
    
    public static func == (lhs: ChatAnalysisResult, rhs: ChatAnalysisResult) -> Bool {
        return lhs.id == rhs.id
    }
}

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

public struct ChatMessageViewModel: Identifiable, Equatable {
    public let id: UUID
    public let content: String
    public let isUser: Bool
    public let timestamp: Date
    public let messageType: MessageType
    
    public enum MessageType {
        case text
        case emotion
        case presetRecommendation
        case soundRecommendation
    }
    
    public init(
        id: UUID = UUID(),
        content: String,
        isUser: Bool,
        timestamp: Date = Date(),
        messageType: MessageType = .text
    ) {
        self.id = id
        self.content = content
        self.isUser = isUser
        self.timestamp = timestamp
        self.messageType = messageType
    }
    
    public static func == (lhs: ChatMessageViewModel, rhs: ChatMessageViewModel) -> Bool {
        return lhs.id == rhs.id
    }
} 