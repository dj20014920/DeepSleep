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
    case user, bot, aiResponse, presetRecommendation, recommendationSelector, loading, error, system, presetOptions, postPresetOptions, text
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
    case freeModel = "free-model"  // 무료 모델 (베타)
    case testModel = "test-model"  // 테스트 모델 (베타)
    
    public var displayName: String {
        switch self {
        case .claude35: return "클로드"
        case .gpt4: return "지피티"
        case .gemini: return "제미니"
        case .naver: return "하이퍼클로바"
        case .onDevice: return "온디"
        case .freeModel: return "오픈AI (무료)"
        case .testModel: return "실험 친구"
        }
    }
    
    public var icon: String {
        switch self {
        case .claude35: return "🌸"
        case .gpt4: return "⚡"
        case .gemini: return "💎"
        case .naver: return "🇰🇷"
        case .onDevice: return "📱"
        case .freeModel: return "🎁"
        case .testModel: return "🧪"
        }
    }
    
    public var description: String {
        switch self {
        case .claude35: return "철학자이자 감정 전문가"
        case .gpt4: return "활발한 문제해결사"
        case .gemini: return "창의적인 예술가"
        case .naver: return "따뜻한 한국 친구"
        case .onDevice: return "개인정보 보호 우선"
        case .freeModel: return "무료 모델입니다. 응답이 느리거나 오류가 발생할 수 있으며 한국어가 부정확할 수 있습니다."
        case .testModel: return "새로운 기능을 시험하는 모험가"
        }
    }
    
    public var features: [String] {
        switch self {
        case .claude35: return ["깊은 공감", "철학적 사고", "세심한 분석", "윤리적 조언"]
        case .gpt4: return ["빠른 응답", "논리적 분석", "체계적 정리", "명확한 설명"]
        case .gemini: return ["창의적 발상", "재미있는 대화", "유연한 사고", "상상력 풍부"]
        case .naver: return ["친근한 말투", "한국 문화", "현실적 조언", "정겨운 소통"]
        case .onDevice: return ["빠른 처리", "개인정보 보호", "오프라인 사용", "배터리 효율"]
        case .freeModel: return ["무료 이용", "다양한 기능", "베타 테스트", "자동 전환"]
        case .testModel: return ["실험적 기능", "최신 모델", "피드백 환영", "향상된 성능"]
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
        case .freeModel: return .openAI  // 무료 모델은 OpenRouter를 통해 OpenAI 호환 API 사용
        case .testModel: return .openAI  // 테스트 모델도 OpenRouter 사용
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

// MARK: - Session Data Models (Single Source of Truth)

/// 저장된 채팅 메시지 모델
public struct StoredChatMessage: Codable, Identifiable {
    public let id: String
    public let timestamp: Date
    public let role: String
    public let content: String
    public let type: ChatMessageType
    
    public init(id: String = UUID().uuidString, timestamp: Date = Date(), role: String, content: String, type: ChatMessageType = .text) {
        self.id = id
        self.timestamp = timestamp
        self.role = role
        self.content = content
        self.type = type
    }
}

/// 프리셋 피드백 모델 (통합 버전)
public struct PresetFeedback: Codable, Identifiable {
    public let id: UUID
    public let timestamp: Date
    public let presetName: String?
    public let contextEmotion: String
    public let contextTime: Int16
    public let recommendedVolumes: [Float]
    public let recommendedVersions: [Int]
    public let finalVolumes: [Float]
    public let listeningDuration: TimeInterval
    public let wasSkipped: Bool
    public let wasSaved: Bool
    public let userSatisfaction: Int
    public let comment: String?
    
    // Extended properties for enhanced feedback
    public let qualitative: QualitativeFeedback?
    public let context: Context?
    public let deviceContext: DeviceContext?
    public let environmentContext: EnvironmentContext?
    public let userEmotion: String?
    
    // Legacy support - quantitative dictionary for backward compatibility
    public var quantitative: [String: Any] {
        return [
            "presetName": presetName as Any,
            "contextEmotion": contextEmotion,
            "contextTime": Int(contextTime),
            "recommendedVolumes": recommendedVolumes,
            "recommendedVersions": recommendedVersions,
            "finalVolumes": finalVolumes,
            "listeningDuration": listeningDuration,
            "wasSkipped": wasSkipped,
            "wasSaved": wasSaved,
            "userSatisfaction": userSatisfaction
        ]
    }
    
    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        presetName: String? = nil,
        contextEmotion: String,
        contextTime: Int16,
        recommendedVolumes: [Float] = [],
        recommendedVersions: [Int] = [],
        finalVolumes: [Float] = [],
        listeningDuration: TimeInterval = 0,
        wasSkipped: Bool = false,
        wasSaved: Bool = false,
        userSatisfaction: Int = 0,
        comment: String? = nil,
        qualitative: QualitativeFeedback? = nil,
        context: Context? = nil,
        deviceContext: DeviceContext? = nil,
        environmentContext: EnvironmentContext? = nil,
        userEmotion: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.presetName = presetName
        self.contextEmotion = contextEmotion
        self.contextTime = contextTime
        self.recommendedVolumes = recommendedVolumes
        self.recommendedVersions = recommendedVersions
        self.finalVolumes = finalVolumes
        self.listeningDuration = listeningDuration
        self.wasSkipped = wasSkipped
        self.wasSaved = wasSaved
        self.userSatisfaction = userSatisfaction
        self.comment = comment
        self.qualitative = qualitative
        self.context = context
        self.deviceContext = deviceContext
        self.environmentContext = environmentContext
        self.userEmotion = userEmotion
    }
    
    // Legacy computed properties for backward compatibility
    public var satisfactionScore: Float {
        return Float(userSatisfaction) / 10.0  // Convert 1-10 scale to 0.0-1.0
    }
    
    // MARK: - Nested Types
    
    /// 정성적 피드백
    public struct QualitativeFeedback: Codable {
        public let freeText: String?
        public let moodAfter: String
        public let tags: [String]
        
        public init(freeText: String? = nil, moodAfter: String, tags: [String] = []) {
            self.freeText = freeText
            self.moodAfter = moodAfter
            self.tags = tags
        }
    }
    
    /// 사용 컨텍스트
    public struct Context: Codable {
        public let usageDuration: TimeInterval
        public let intentionalStop: Bool
        public let repeatUsageIntent: Bool
        public let recommendationIntent: Bool
        
        public init(usageDuration: TimeInterval, intentionalStop: Bool, repeatUsageIntent: Bool, recommendationIntent: Bool) {
            self.usageDuration = usageDuration
            self.intentionalStop = intentionalStop
            self.repeatUsageIntent = repeatUsageIntent
            self.recommendationIntent = recommendationIntent
        }
    }
    
    /// 기기 컨텍스트
    public struct DeviceContext: Codable {
        public let isCharging: Bool
        public let batteryLevel: Float
        
        public init(isCharging: Bool, batteryLevel: Float) {
            self.isCharging = isCharging
            self.batteryLevel = batteryLevel
        }
    }
    
    /// 환경 컨텍스트
    public struct EnvironmentContext: Codable {
        public let timeOfDay: String
        public let noiseLevel: Float
        
        public init(timeOfDay: String, noiseLevel: Float) {
            self.timeOfDay = timeOfDay
            self.noiseLevel = noiseLevel
        }
    }
}

/// 행동 이벤트 모델
public struct BehaviorEvent: Codable, Identifiable {
    public let id: String
    public let type: BehaviorEventType
    public let timestamp: Date
    public let data: [String: String]
    
    public init(id: String = UUID().uuidString, type: BehaviorEventType, timestamp: Date = Date(), data: [String: String] = [:]) {
        self.id = id
        self.type = type
        self.timestamp = timestamp
        self.data = data
    }
}

/// 행동 이벤트 타입
public enum BehaviorEventType: String, Codable, CaseIterable {
    case presetStart = "preset_start"
    case presetEnd = "preset_end"
    case volumeChange = "volume_change"
    case skip = "skip"
    case save = "save"
    case feedback = "feedback"
    case sessionStart = "session_start"
    case sessionEnd = "session_end"
    case harmonyAnalysis = "harmonyAnalysis"
    case harmonyAnalysisError = "harmonyAnalysisError"
    case weightUpdate = "weightUpdate"
    case contextGeneration = "contextGeneration"
}

/// 조화 가중치 - 개인별 조화 기준 우선순위
public struct HarmonyWeights: Codable {
    public var frequencyMasking: Float     // 주파수 마스킹 중요도
    public var rhythmConflict: Float       // 리듬 충돌 중요도
    public var emotionalHarmony: Float     // 감정적 조화 중요도
    public var dynamicRange: Float         // 다이나믹 레인지 중요도
    public var lengthMatching: Float       // 길이 일치 중요도
    public var temporalFitness: Float      // 시간적 적합성 중요도
    
    public static let `default` = HarmonyWeights(
        frequencyMasking: 0.2,
        rhythmConflict: 0.15,
        emotionalHarmony: 0.25,
        dynamicRange: 0.1,
        lengthMatching: 0.15,
        temporalFitness: 0.15
    )
    
    /// 가중치 정규화 (합이 1.0이 되도록)
    public mutating func normalize() {
        let sum = frequencyMasking + rhythmConflict + emotionalHarmony +
                 dynamicRange + lengthMatching + temporalFitness
        
        guard sum > 0 else { return }
        
        frequencyMasking /= sum
        rhythmConflict /= sum
        emotionalHarmony /= sum
        dynamicRange /= sum
        lengthMatching /= sum
        temporalFitness /= sum
    }
    
    /// 배열로 변환 (신경망 입력용)
    public func toArray() -> [Float] {
        return [frequencyMasking, rhythmConflict, emotionalHarmony,
               dynamicRange, lengthMatching, temporalFitness]
    }
}

/// 통합 세션 모델
public struct UnifiedSession: Codable, Identifiable {
    public let id: String
    public let createdAt: Date
    public var lastActivityAt: Date
    public var chatMessages: [StoredChatMessage]
    public var feedbackData: [PresetFeedback]
    public var behaviorEvents: [BehaviorEvent]
    public var metadata: SessionMetadata
    
    public init(
        id: String = UUID().uuidString,
        createdAt: Date = Date(),
        lastActivityAt: Date = Date(),
        chatMessages: [StoredChatMessage] = [],
        feedbackData: [PresetFeedback] = [],
        behaviorEvents: [BehaviorEvent] = [],
        metadata: SessionMetadata = SessionMetadata()
    ) {
        self.id = id
        self.createdAt = createdAt
        self.lastActivityAt = lastActivityAt
        self.chatMessages = chatMessages
        self.feedbackData = feedbackData
        self.behaviorEvents = behaviorEvents
        self.metadata = metadata
    }
}

/// 세션 메타데이터
public struct SessionMetadata: Codable {
    public var primaryEmotion: String?
    public var emotionIntensity: Float?
    public var context: String?
    public var userProfile: String?
    
    public init(primaryEmotion: String? = nil, emotionIntensity: Float? = nil, context: String? = nil, userProfile: String? = nil) {
        self.primaryEmotion = primaryEmotion
        self.emotionIntensity = emotionIntensity
        self.context = context
        self.userProfile = userProfile
    }
}

/// 로컬 AI를 위한 컨텍스트
public struct LocalAIContext {
    public let feedbackData: [PresetFeedback]
    public let emotionHistory: [EmotionHistoryItem]
    public let behaviorPatterns: [BehaviorPattern]
    public let timePreferences: [TimePreference]
    public let lastUpdated: Date
    
    public init(feedbackData: [PresetFeedback], emotionHistory: [EmotionHistoryItem], 
                behaviorPatterns: [BehaviorPattern], timePreferences: [TimePreference], 
                lastUpdated: Date) {
        self.feedbackData = feedbackData
        self.emotionHistory = emotionHistory
        self.behaviorPatterns = behaviorPatterns
        self.timePreferences = timePreferences
        self.lastUpdated = lastUpdated
    }
}

/// 감정 히스토리 아이템
public struct EmotionHistoryItem: Codable {
    public let emotion: String
    public let timestamp: Date
    public let intensity: Float
    
    public init(emotion: String, timestamp: Date, intensity: Float) {
        self.emotion = emotion
        self.timestamp = timestamp
        self.intensity = intensity
    }
}

/// 행동 패턴
public struct BehaviorPattern: Codable {
    public let pattern: String
    public let frequency: Int
    public let confidence: Float
    
    public init(pattern: String, frequency: Int, confidence: Float) {
        self.pattern = pattern
        self.frequency = frequency
        self.confidence = confidence
    }
}

/// 시간 선호도
public struct TimePreference: Codable {
    public let hour: Int
    public let preference: Float
    public let sampleCount: Int
    
    public init(hour: Int, preference: Float, sampleCount: Int) {
        self.hour = hour
        self.preference = preference
        self.sampleCount = sampleCount
    }
}

// MARK: - Legacy Support Models

/// 채팅 세션 모델 (기존 ChatManager와의 호환성)
public struct ChatSession: Codable, Identifiable {
    public let id: String
    public let createdAt: Date
    public var lastActivityAt: Date
    public var messages: [StoredChatMessage]
    public var metadata: ChatSessionMetadata?
    
    public init(id: String = UUID().uuidString, createdAt: Date = Date(), lastActivityAt: Date = Date(), messages: [StoredChatMessage] = [], metadata: ChatSessionMetadata? = nil) {
        self.id = id
        self.createdAt = createdAt
        self.lastActivityAt = lastActivityAt
        self.messages = messages
        self.metadata = metadata
    }
}

/// 채팅 세션 메타데이터
public struct ChatSessionMetadata: Codable {
    public var emotion: String?
    public var context: String?
    public var userProfile: String?
    
    public init(emotion: String? = nil, context: String? = nil, userProfile: String? = nil) {
        self.emotion = emotion
        self.context = context
        self.userProfile = userProfile
    }
}

// MARK: - Legacy Types for Backward Compatibility

/// 사용자 행동 프로필 (UserBehaviorAnalytics 호환)
public struct UserBehaviorProfile: Codable {
    public let userId: String
    public let soundPreferences: SoundPreferenceAnalysis
    public let soundPatterns: SoundPatternAnalysis
    public let timePatterns: [Int: TimeUsagePattern]
    public let emotionPatterns: [String: EmotionPreferencePattern]
    public let overallSatisfaction: Float
    public let totalSessions: Int
    public let lastUpdated: Date
    
    public init(userId: String, soundPreferences: SoundPreferenceAnalysis, soundPatterns: SoundPatternAnalysis, timePatterns: [Int: TimeUsagePattern], emotionPatterns: [String: EmotionPreferencePattern], overallSatisfaction: Float, totalSessions: Int, lastUpdated: Date) {
        self.userId = userId
        self.soundPreferences = soundPreferences
        self.soundPatterns = soundPatterns
        self.timePatterns = timePatterns
        self.emotionPatterns = emotionPatterns
        self.overallSatisfaction = overallSatisfaction
        self.totalSessions = totalSessions
        self.lastUpdated = lastUpdated
    }
}

/// 사운드 패턴 분석
public struct SoundPatternAnalysis: Codable {
    public let individualSoundMetrics: [IndividualSoundMetric]
    public let combinationPatterns: [String: Float]
    public let temporalPatterns: [String: Float]
    
    public init(individualSoundMetrics: [IndividualSoundMetric], combinationPatterns: [String: Float], temporalPatterns: [String: Float]) {
        self.individualSoundMetrics = individualSoundMetrics
        self.combinationPatterns = combinationPatterns
        self.temporalPatterns = temporalPatterns
    }
}

/// 개별 사운드 메트릭
public struct IndividualSoundMetric: Codable {
    public let soundName: String
    public let usageCount: Int
    public let averageSatisfaction: Float
    public let preferredVolume: Float
    public let preferredVersion: Int
    
    public init(soundName: String, usageCount: Int, averageSatisfaction: Float, preferredVolume: Float, preferredVersion: Int) {
        self.soundName = soundName
        self.usageCount = usageCount
        self.averageSatisfaction = averageSatisfaction
        self.preferredVolume = preferredVolume
        self.preferredVersion = preferredVersion
    }
}

/// 사운드 선호도 분석
public struct SoundPreferenceAnalysis: Codable {
    public let preferredSounds: [String: Float]
    public let avoidedSounds: [String: Float]
    public let optimalVolumes: [String: Float]
    
    public init(preferredSounds: [String: Float], avoidedSounds: [String: Float], optimalVolumes: [String: Float]) {
        self.preferredSounds = preferredSounds
        self.avoidedSounds = avoidedSounds
        self.optimalVolumes = optimalVolumes
    }
}

/// 시간 사용 패턴
public struct TimeUsagePattern: Codable {
    public let hour: Int
    public let usageCount: Int
    public let averageSatisfaction: Float
    public let preferredDuration: TimeInterval
    
    public init(hour: Int, usageCount: Int, averageSatisfaction: Float, preferredDuration: TimeInterval) {
        self.hour = hour
        self.usageCount = usageCount
        self.averageSatisfaction = averageSatisfaction
        self.preferredDuration = preferredDuration
    }
}

/// 감정 선호도 패턴
public struct EmotionPreferencePattern: Codable {
    public let emotion: String
    public let frequency: Int
    public let averageSatisfaction: Float
    public let preferredSounds: [String]
    public let versionPreferences: [Int: Float]
    
    public init(emotion: String, frequency: Int, averageSatisfaction: Float, preferredSounds: [String], versionPreferences: [Int: Float] = [:]) {
        self.emotion = emotion
        self.frequency = frequency
        self.averageSatisfaction = averageSatisfaction
        self.preferredSounds = preferredSounds
        self.versionPreferences = versionPreferences
    }
}

/// 일일 대화 (ChatManager 호환)
public struct DailyConversation: Codable {
    public let id: String
    public let date: Date
    public var messages: [ConversationMessage]
    public var emotionContext: EmotionContext?
    
    public init(id: String = UUID().uuidString, date: Date = Date(), messages: [ConversationMessage] = [], emotionContext: EmotionContext? = nil) {
        self.id = id
        self.date = date
        self.messages = messages
        self.emotionContext = emotionContext
    }
}

/// 대화 메시지 (ChatManager 호환)
public struct ConversationMessage: Codable {
    public let id: String
    public let type: ConversationMessageType
    public let content: String
    public let timestamp: Date
    public let metadata: [String: String]?
    
    public init(id: String = UUID().uuidString, type: ConversationMessageType, content: String, timestamp: Date = Date(), metadata: [String: String]? = nil) {
        self.id = id
        self.type = type
        self.content = content
        self.timestamp = timestamp
        self.metadata = metadata
    }
}

/// 대화 메시지 타입
public enum ConversationMessageType: String, Codable {
    case user = "user"
    case assistant = "assistant"
    case system = "system"
    case emotion = "emotion"
}

/// 감정 컨텍스트 (ChatManager 호환)
public struct EmotionContext: Codable {
    public let primaryEmotion: String
    public let intensity: Float
    public let timestamp: Date
    public let context: String?
    
    public init(primaryEmotion: String, intensity: Float, timestamp: Date = Date(), context: String? = nil) {
        self.primaryEmotion = primaryEmotion
        self.intensity = intensity
        self.timestamp = timestamp
        self.context = context
    }
}

// MARK: - Storage Management Types

/// 일일 저장소 정보
public struct DailyStorageInfo: Codable {
    public let date: Date
    public let totalSizeKB: Int
    public let feedbackSizeKB: Int
    public let diarySizeKB: Int
    public let presetSizeKB: Int
    public let itemCount: Int
    
    public init(date: Date, totalSizeKB: Int, feedbackSizeKB: Int, diarySizeKB: Int, presetSizeKB: Int, itemCount: Int) {
        self.date = date
        self.totalSizeKB = totalSizeKB
        self.feedbackSizeKB = feedbackSizeKB
        self.diarySizeKB = diarySizeKB
        self.presetSizeKB = presetSizeKB
        self.itemCount = itemCount
    }
    
    // StorageManagementViewController 호환성을 위한 computed properties
    public var displayDate: String {
        return DateFormatter.localizedString(from: date, dateStyle: .short, timeStyle: .none)
    }
    
    public var formattedSize: String {
        return ByteCountFormatter.string(fromByteCount: Int64(totalSizeKB * 1024), countStyle: .file)
    }
    
    public var messageCount: Int {
        return itemCount
    }
    
    public var conversationCount: Int {
        return itemCount / 5 // 추정치
    }
}

/// 저장소 통계
public struct StorageStatistics: Codable {
    public let totalSizeKB: Int
    public let feedbackCount: Int
    public let feedbackSizeKB: Int
    public let diaryCount: Int
    public let diarySizeKB: Int
    public let presetCount: Int
    public let presetSizeKB: Int
    public let retentionDays: Int
    public let oldestItemDate: Date?
    public let newestItemDate: Date?
    
    public init(totalSizeKB: Int, feedbackCount: Int, feedbackSizeKB: Int, diaryCount: Int, diarySizeKB: Int, presetCount: Int, presetSizeKB: Int, retentionDays: Int, oldestItemDate: Date? = nil, newestItemDate: Date? = nil) {
        self.totalSizeKB = totalSizeKB
        self.feedbackCount = feedbackCount
        self.feedbackSizeKB = feedbackSizeKB
        self.diaryCount = diaryCount
        self.diarySizeKB = diarySizeKB
        self.presetCount = presetCount
        self.presetSizeKB = presetSizeKB
        self.retentionDays = retentionDays
        self.oldestItemDate = oldestItemDate
        self.newestItemDate = newestItemDate
    }
}
