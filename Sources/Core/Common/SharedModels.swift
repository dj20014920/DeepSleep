import Foundation

// MARK: - Chat Message Models (Moved from DeepSleepApp/Models.swift)
public struct ChatMessage: Codable, Identifiable, Hashable {
    public func toDictionary() -> [String: Any]? {
        guard let data = try? JSONEncoder().encode(self) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data, options: .allowFragments)).flatMap { $0 as? [String: Any] }
    }

    public static func from(dictionary: [String: Any]) -> ChatMessage? {
        guard let data = try? JSONSerialization.data(withJSONObject: dictionary, options: .prettyPrinted) else { return nil }
        return try? JSONDecoder().decode(ChatMessage.self, from: data)
    }
    public let id: UUID
    public var text: String?
    public let date: Date
    public var sender: MessageSender
    public var isPending: Bool?
    public var aithoughts: String?
    public var metadata: ChatMetadata?

    public var type: ChatMessageType = .bot
    public var quickActions: [QuickAction]? = nil

    enum CodingKeys: String, CodingKey {
        case id, text, date, sender, isPending, aithoughts, metadata, type, quickActions
    }
    
    public init(id: UUID = UUID(), text: String?, date: Date = Date(), sender: MessageSender, type: ChatMessageType, quickActions: [QuickAction]? = nil, isPending: Bool? = false, aithoughts: String? = nil, metadata: ChatMetadata? = nil) {
        self.id = id
        self.text = text
        self.date = date
        self.sender = sender
        self.type = type
        self.quickActions = quickActions
        self.isPending = isPending
        self.aithoughts = aithoughts
        self.metadata = metadata
    }
}

public struct QuickAction: Codable, Hashable {
    public let title: String
    public let action: String
    
    public init(title: String, action: String) {
        self.title = title
        self.action = action
    }
}

public enum ChatMessageType: String, Codable, Equatable {
    case user, bot, aiResponse, presetRecommendation, recommendationSelector, loading, error, system, presetOptions, postPresetOptions
}

public enum MessageSender: String, Codable, Hashable {
    case user, ai, system
}

public struct ChatMetadata: Codable, Hashable {
    public let responseTime: TimeInterval?
    public let modelUsed: String?
    public let tokenCount: Int?
    public let sessionId: String?
    
    public init(responseTime: TimeInterval? = nil, modelUsed: String? = nil, tokenCount: Int? = nil, sessionId: String? = nil) {
        self.responseTime = responseTime
        self.modelUsed = modelUsed
        self.tokenCount = tokenCount
        self.sessionId = sessionId
    }
}


// MARK: - Sound Recommendation Context (Moved from DeepSleepApp/CompilerFixStubs.swift)
public struct SoundRecommendationContext {
    public let userEmotion: String
    public let timeOfDay: String
    public let batteryLevel: Float
    public let isHeadphonesConnected: Bool
    
    public init(userEmotion: String = "평온", timeOfDay: String = "오후", batteryLevel: Float = 0.8, isHeadphonesConnected: Bool = false) {
        self.userEmotion = userEmotion
        self.timeOfDay = timeOfDay
        self.batteryLevel = batteryLevel
        self.isHeadphonesConnected = isHeadphonesConnected
    }
}

// MARK: - Core Data Types (Moved from DeepSleepApp/CompilerFixStubs.swift)
public struct ChatContext {
    public var messages: [ChatMessage] = []
    public var sessionId: String = UUID().uuidString
    public var userEmotion: String?
    
    public init(messages: [ChatMessage] = [], userEmotion: String? = nil) {
        self.messages = messages
        self.userEmotion = userEmotion
    }
}

public struct UserInfo {
    public let userId: String
    public let preferences: [String: Any]
    public let emotionalState: String
    
    public init(userId: String = "default", preferences: [String: Any] = [:], emotionalState: String = "평온") {
        self.userId = userId
        self.preferences = preferences
        self.emotionalState = emotionalState
    }
} 