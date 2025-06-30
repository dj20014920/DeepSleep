import Foundation

// Using EmotionType from EmotionEntity.swift
// Using ModernChatMessage from SharedChatTypes.swift

// MARK: - Chat Domain Entities

// ChatMessageType은 SharedChatTypes.swift에서 정의됨

public struct DomainChatMessage: Codable, Identifiable, Equatable {
    public let id: UUID
    public let content: String
    public let type: MessageType
    public let timestamp: Date
    public let emotion: String? // Store as string for Codable compatibility
    public let metadata: [String: String]?
    
    public init(
        id: UUID = UUID(),
        content: String,
        type: MessageType,
        timestamp: Date = Date(),
        emotion: String? = nil,
        metadata: [String: String]? = nil
    ) {
        self.id = id
        self.content = content
        self.type = type
        self.timestamp = timestamp
        self.emotion = emotion
        self.metadata = metadata
    }
    
    // Computed property for String
    public var emotionType: String? {
        return emotion
    }
    
    public static func == (lhs: DomainChatMessage, rhs: DomainChatMessage) -> Bool {
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
public struct DomainChatSession: Codable, Identifiable, Equatable {
    public let id: UUID
    public let title: String
    public let createdAt: Date
    public let lastMessageAt: Date
    public let messageCount: Int
    public let averageSentiment: Double
    public let participants: [String]
    public let tags: [String]
    
    public init(
        id: UUID = UUID(),
        title: String,
        createdAt: Date = Date(),
        lastMessageAt: Date = Date(),
        messageCount: Int = 0,
        averageSentiment: Double = 0.0,
        participants: [String] = [],
        tags: [String] = []
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.lastMessageAt = lastMessageAt
        self.messageCount = messageCount
        self.averageSentiment = averageSentiment
        self.participants = participants
        self.tags = tags
    }
}

// MARK: - Chat Context Entity
public struct DomainChatContext: Codable, Equatable {
    public let sessionId: UUID
    public let userId: String
    public let deviceInfo: String
    public let appVersion: String
    public let timestamp: Date
    public let conversationalState: String
    public let emotionalContext: String
    
    public init(
        sessionId: UUID,
        userId: String = "default",
        deviceInfo: String = "iOS",
        appVersion: String = "1.0",
        timestamp: Date = Date(),
        conversationalState: String = "active",
        emotionalContext: String = "neutral"
    ) {
        self.sessionId = sessionId
        self.userId = userId
        self.deviceInfo = deviceInfo
        self.appVersion = appVersion
        self.timestamp = timestamp
        self.conversationalState = conversationalState
        self.emotionalContext = emotionalContext
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

// EmotionType is imported from EmotionEntity.swift to avoid duplication

public struct DomainChatAnalysisResult: Codable, Identifiable, Equatable {
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
        emotionScores: [String: Double],
        keywords: [String] = [],
        analysisTimestamp: Date = Date(),
        confidence: Double = 0.0
    ) {
        self.id = id
        self.messageId = messageId
        self.sentimentScore = max(-1.0, min(1.0, sentimentScore))
        self.emotionScores = emotionScores
        self.keywords = keywords
        self.analysisTimestamp = analysisTimestamp
        self.confidence = max(0.0, min(1.0, confidence))
    }
    
    public var emotionScoresTyped: [String: Double] {
        return emotionScores
    }
    
    public static func == (lhs: DomainChatAnalysisResult, rhs: DomainChatAnalysisResult) -> Bool {
        return lhs.id == rhs.id
    }
} 