import Foundation

// MARK: - Chat Message Models (이전에 Core 모듈에 있던 타입들)
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


// MARK: - Sound Recommendation Context는 Models.swift에 정의되어 있음

// MARK: - Core Data Types (이전에 Core 모듈에 있던 타입들)
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

// MARK: - AI Model Types

/// 🤖 AI 모델 타입
public enum AIModelType: String, CaseIterable, Sendable {
    case claude35 = "claude-3.5-sonnet"
    case gpt4 = "gpt-4"
    case gemini = "gemini-pro"
    case naver = "hyperclova-x"
    case onDevice = "on-device"
    
    public var displayName: String {
        switch self {
        case .claude35: return "클로드"
        case .gpt4: return "지피티"
        case .gemini: return "제미니"
        case .naver: return "하이퍼클로바"
        case .onDevice: return "온디"
        }
    }
    
    public var icon: String {
        switch self {
        case .claude35: return "🌸"
        case .gpt4: return "⚡"
        case .gemini: return "💎"
        case .naver: return "🇰🇷"
        case .onDevice: return "📱"
        }
    }
    
    public var description: String {
        switch self {
        case .claude35: return "철학자이자 감정 전문가"
        case .gpt4: return "활발한 문제해결사"
        case .gemini: return "창의적인 예술가"
        case .naver: return "따뜻한 한국 친구"
        case .onDevice: return "개인정보 보호 우선"
        }
    }
    
    public var features: [String] {
        switch self {
        case .claude35: return ["깊은 공감", "철학적 사고", "세심한 분석", "윤리적 조언"]
        case .gpt4: return ["빠른 응답", "논리적 분석", "체계적 정리", "명확한 설명"]
        case .gemini: return ["창의적 발상", "재미있는 대화", "유연한 사고", "상상력 풍부"]
        case .naver: return ["친근한 말투", "한국 문화", "현실적 조언", "정겨운 소통"]
        case .onDevice: return ["빠른 처리", "개인정보 보호", "오프라인 사용", "배터리 효율"]
        }
    }
}

// MARK: - Model Context

/// 🔄 모델별 컨텍스트
public struct ModelContext {
    public let messages: [(role: String, content: String)]
    public var systemPrompt: String
    public let conversationSummary: String
    public let tokenCount: Int
    public let metadata: [String: Any]
    
    public init(
        messages: [(role: String, content: String)],
        systemPrompt: String,
        conversationSummary: String,
        tokenCount: Int,
        metadata: [String: Any]
    ) {
        self.messages = messages
        self.systemPrompt = systemPrompt
        self.conversationSummary = conversationSummary
        self.tokenCount = tokenCount
        self.metadata = metadata
    }
}

// MARK: - LLMServiceType Mapping Extension

/// LLMServiceType과 AIModelType 간의 매핑
public extension AIModelType {
    /// LLMServiceType으로 변환
    var toLLMServiceType: LLMServiceType {
        switch self {
        case .claude35: return .claude
        case .gpt4: return .openAI
        case .gemini: return .gemini
        case .naver: return .naver
        case .onDevice: return .onDevice
        }
    }
    
    /// LLMServiceType에서 생성
    init(from llmType: LLMServiceType) {
        switch llmType {
        case .claude: self = .claude35
        case .openAI: self = .gpt4
        case .gemini: self = .gemini
        case .naver: self = .naver
        case .onDevice: self = .onDevice
        }
    }
}

// MARK: - Context Message Types

/// 💬 컨텍스트 메시지
public struct ContextMessage {
    public let id: UUID = UUID()
    public let content: String
    public let isFromUser: Bool
    public let timestamp: Date = Date()
    public let type: ContextMessageType
    public let importance: Double // 0.0 ~ 1.0
    public let detectedEmotion: DetectedEmotion?
    public let modelUsed: AIModelType?
    
    public init(
        content: String,
        isFromUser: Bool,
        type: ContextMessageType,
        importance: Double,
        detectedEmotion: DetectedEmotion?,
        modelUsed: AIModelType?
    ) {
        self.content = content
        self.isFromUser = isFromUser
        self.type = type
        self.importance = importance
        self.detectedEmotion = detectedEmotion
        self.modelUsed = modelUsed
    }
}

/// 🎭 감지된 감정
public struct DetectedEmotion {
    public let type: String
    public let intensity: Double
    public let confidence: Double
    
    public init(type: String, intensity: Double, confidence: Double) {
        self.type = type
        self.intensity = intensity
        self.confidence = confidence
    }
}

/// 💬 메시지 타입
public enum ContextMessageType {
    case normal
    case emotional
    case goal
    case feedback
    case system
}