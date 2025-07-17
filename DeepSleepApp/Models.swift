import Foundation
import Core
import CoreData
import SwiftUI

#if canImport(SwiftData)
import SwiftData
#endif

// MARK: - Note: UIColor compatibility handled by UIColorExtensions.swift
// typealias UIColor = Color doesn't work properly in this context

// Note: SoundPresetCatalog is defined in SoundPresetCatalog.swift - removed duplicate struct definition
// Note: SettingsManager is defined in SettingsManager.swift - removed duplicate struct definition

// MARK: - Common Models

// MARK: - Message Type for Models (Local Definition)
public enum ModelsMessageType: String, Codable {
    case user = "user"
    case bot = "bot"
    case system = "system"
    case aiResponse = "aiResponse"
    case presetRecommendation = "presetRecommendation"
    case recommendationSelector = "recommendationSelector"
    case loading = "loading"
    case error = "error"
    case presetOptions = "presetOptions"
    case postPresetOptions = "postPresetOptions"
}

// QuickAction, ChatMessageType, ChatMessage, MessageSender, ChatMetadata 등은
// Core/Common/SharedModels.swift 로 이동되었으므로 여기서 삭제합니다.

// 이 부분의 LLMServiceType 정의는 Sources/Core/Domain/Entities/LLMEntity.swift 로 이전되었으므로 삭제합니다.

struct DummyDecoder: Decoder {
    var codingPath: [CodingKey] { [] }
    var userInfo: [CodingUserInfoKey : Any] { [:] }
    func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> { throw NSError() }
    func unkeyedContainer() throws -> UnkeyedDecodingContainer { throw NSError() }
    func singleValueContainer() throws -> SingleValueDecodingContainer { throw NSError() }
}

// MARK: - ChatMessage Codable dictionary conversion
public extension ChatMessage {
    func toDictionary() -> [String: Any]? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(self),
              let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return jsonObject
    }

    static func from(dictionary: [String: Any]) -> ChatMessage? {
        guard let data = try? JSONSerialization.data(withJSONObject: dictionary, options: []),
              let message = try? JSONDecoder().decode(ChatMessage.self, from: data) else {
            return nil
        }
        return message
    }
}

// MARK: - Emotional Profile Model
public struct EmotionalProfile: Codable, Equatable {
    public let primaryEmotion: String
    public let intensity: Float
    public let complexity: Float
    public let description: String
    
    public init(primaryEmotion: String, intensity: Float, complexity: Float, description: String) {
        self.primaryEmotion = primaryEmotion
        self.intensity = intensity
        self.complexity = complexity
        self.description = description
    }
}

// MARK: - LLM Output Model
public struct LLMOutput: Codable, Equatable {
    public let text: String
    public let metadata: [String: String]?
    public let soundPreset: SoundPreset?
    
    public init(text: String, metadata: [String: String]? = nil, soundPreset: SoundPreset? = nil) {
        self.text = text
        self.metadata = metadata
        self.soundPreset = soundPreset
    }
}

// MARK: - Storage Info Models
public struct StorageInfo: Codable {
    public let totalSizeKB: Int
    public let feedbackCount: Int
    public let feedbackSizeKB: Int
    public let diaryCount: Int
    public let diarySizeKB: Int
    public let presetCount: Int
    public let presetSizeKB: Int
    public let retentionDays: Int
    
    public var totalSizeFormatted: String {
        if totalSizeKB < 1024 {
            return "\(totalSizeKB)KB"
        } else {
            let sizeMB = Double(totalSizeKB) / 1024.0
            return String(format: "%.1fMB", sizeMB)
        }
    }
    
    public var detailDescription: String {
        return """
        📊 저장소 사용량 상세
        
        🎵 피드백 데이터: \(feedbackCount)개 (~\(feedbackSizeKB)KB)
        📝 감정 일기: \(diaryCount)개 (~\(diarySizeKB)KB)
        🎼 사운드 프리셋: \(presetCount)개 (~\(presetSizeKB)KB)
        
        📅 데이터 보관 기간: \(retentionDays)일
        💾 총 사용량: \(totalSizeFormatted)
        
        ℹ️ 데이터는 \(retentionDays)일 후 자동으로 정리됩니다.
        """
    }
}

public struct CleanupResult: Codable {
    public let beforeSizeKB: Int
    public let afterSizeKB: Int
    public let freedSpaceKB: Int
    public let deletedFeedbackCount: Int
    
    public var summaryDescription: String {
        let freedSpaceMB = Double(freedSpaceKB) / 1024.0
        return """
        🧹 데이터 정리 완료
        
        📉 정리 전: \(beforeSizeKB)KB
        📈 정리 후: \(afterSizeKB)KB
        💾 절약된 용량: \(freedSpaceKB)KB (~\(String(format: "%.1f", freedSpaceMB))MB)
        🗑️ 삭제된 피드백: \(deletedFeedbackCount)개
        
        ✅ 앱 성능이 개선되었습니다!
        """
    }
    
    public var hasSignificantCleanup: Bool {
        return freedSpaceKB > 100 || deletedFeedbackCount > 10
    }
}

// MARK: - 감정 관련 모델 (기존 유지)
struct Emotion {
    let emoji: String
    let name: String
    let description: String
    let category: EmotionCategory
    
    enum EmotionCategory: String, CaseIterable {
        case happy = "기쁨"
        case sad = "슬픔"
        case anxious = "불안"
        case tired = "피곤"
        case angry = "화남"
        case neutral = "평온"
    }
    
    static let predefinedEmotions: [Emotion] = [
        Emotion(emoji: "😊", name: "기쁨", description: "행복하고 즐거운", category: .happy),
        Emotion(emoji: "😄", name: "신남", description: "에너지 넘치는", category: .happy),
        Emotion(emoji: "🥰", name: "사랑", description: "따뜻하고 포근한", category: .happy),
        
        Emotion(emoji: "😢", name: "슬픔", description: "눈물이 나는", category: .sad),
        Emotion(emoji: "😞", name: "우울", description: "마음이 무거운", category: .sad),
        Emotion(emoji: "😔", name: "실망", description: "기대가 무너진", category: .sad),
        
        Emotion(emoji: "😰", name: "불안", description: "마음이 조급한", category: .anxious),
        Emotion(emoji: "😱", name: "공포", description: "두렵고 무서운", category: .anxious),
        Emotion(emoji: "😨", name: "걱정", description: "앞이 막막한", category: .anxious),
        
        Emotion(emoji: "😴", name: "졸림", description: "잠이 오는", category: .tired),
        Emotion(emoji: "😪", name: "피곤", description: "몸과 마음이 지친", category: .tired),
        
        Emotion(emoji: "😡", name: "화남", description: "분노가 치미는", category: .angry),
        Emotion(emoji: "😤", name: "짜증", description: "신경이 날카로운", category: .angry),
        
        Emotion(emoji: "😐", name: "무덤덤", description: "특별한 감정 없는", category: .neutral),
        Emotion(emoji: "🙂", name: "평온", description: "마음이 고요한", category: .neutral)
    ]
}

// MARK: - Enhanced Emotion Types
// EnhancedEmotion은 Core/Domain/Entities/EmotionEntity.swift의 EmotionType으로 통합되었습니다.
// EmotionType을 import하여 사용하세요. intensity 프로퍼티도 EmotionType에 통합되었습니다.
import Core

// MARK: - 감정 일기 모델
struct EmotionDiary: Codable, Identifiable {
    let id: UUID
    let date: Date
    let selectedEmotion: String
    let userMessage: String
    let aiResponse: String
    
    init(id: UUID = UUID(), selectedEmotion: String, userMessage: String, aiResponse: String, date: Date = Date()) {
        self.id = id
        self.selectedEmotion = selectedEmotion
        self.userMessage = userMessage
        self.aiResponse = aiResponse
        self.date = date
    }
}

// MARK: - 사운드 및 프리셋 모델
public struct SoundItem: Codable, Equatable, Hashable {
    let soundId: String
    let version: String
    let volume: Float
}

public struct SoundPreset: Codable, Equatable {
    public let id: UUID
    public let name: String
    /// Alias for compatibility with tests
    public var presetName: String { name }
    public let volumes: [Float]
    public let emotion: String?
    public let isAIGenerated: Bool
    public let description: String?
    public let scientificBasis: String?  // 과학적 근거
    var createdDate: Date
    var lastUsed: Date?
    
    let selectedVersions: [Int]?
    let presetVersion: String
    
    init(name: String, volumes: [Float], emotion: String? = nil, isAIGenerated: Bool = false, description: String? = nil) {
        self.id = UUID()
        self.name = name
        self.volumes = volumes
        self.emotion = emotion
        self.isAIGenerated = isAIGenerated
        self.description = description
        self.scientificBasis = nil
        self.createdDate = Date()
        self.lastUsed = Date()
        
        if volumes.count == 12 {
            self.presetVersion = "v1.0"
            self.selectedVersions = nil
        } else {
            self.presetVersion = "v2.0"
            self.selectedVersions = SoundPresetCatalog.defaultVersions
        }
    }
    
    init(name: String, volumes: [Float], selectedVersions: [Int]?, emotion: String? = nil, isAIGenerated: Bool = false, description: String? = nil, scientificBasis: String? = nil) {
        self.id = UUID()
        self.name = name
        self.volumes = volumes
        self.selectedVersions = selectedVersions
        self.emotion = emotion
        self.isAIGenerated = isAIGenerated
        self.description = description
        self.scientificBasis = scientificBasis
        self.createdDate = Date()
        self.lastUsed = Date()
        self.presetVersion = "v2.0"
    }
    
    init(id: UUID = UUID(), name: String, volumes: [Float], emotion: String?, isAIGenerated: Bool, description: String?, scientificBasis: String?, createdDate: Date, selectedVersions: [Int]?, presetVersion: String, lastUsed: Date? = nil) {
        self.id = id
        self.name = name
        self.volumes = volumes
        self.emotion = emotion
        self.isAIGenerated = isAIGenerated
        self.description = description
        self.scientificBasis = scientificBasis
        self.createdDate = createdDate
        self.selectedVersions = selectedVersions
        self.presetVersion = presetVersion
        self.lastUsed = lastUsed ?? Date()
    }
    
    var compatibleVolumes: [Float] {
        if presetVersion == "v1.0" && volumes.count == 12 {
            return volumes + [0.0]
        }
        if volumes.count == 11 {
            return volumes + [0.0, 0.0]
        }
        return volumes
    }
    
    var compatibleVersions: [Int] {
        return selectedVersions ?? SoundPresetCatalog.defaultVersions
    }
    
    var isNewFormat: Bool {
        return presetVersion == "v2.0"
    }
    
    func upgraded() -> SoundPreset {
        if isNewFormat {
            return self
        }
        return SoundPreset(
            name: name,
            volumes: compatibleVolumes,
            selectedVersions: SoundPresetCatalog.defaultVersions,
            emotion: emotion,
            isAIGenerated: isAIGenerated,
            description: description,
            scientificBasis: scientificBasis
        )
    }

    public func isEqual(to other: SoundPreset) -> Bool {
        return self.name == other.name && self.volumes == other.volumes && self.compatibleVersions == other.compatibleVersions
    }
}

// MARK: - Preset Feedback Model
public struct PresetFeedback {
    public struct QualitativeFeedback {
        public let freeText: String
        public let moodAfter: String
        public let tags: [String]
        
        public init(freeText: String, moodAfter: String, tags: [String]) {
            self.freeText = freeText
            self.moodAfter = moodAfter
            self.tags = tags
        }
    }
    
    public struct Context {
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
    
    public struct DeviceContext {
        public let isCharging: Bool
        public let batteryLevel: Float
        
        public init(isCharging: Bool, batteryLevel: Float) {
            self.isCharging = isCharging
            self.batteryLevel = batteryLevel
        }
    }
    
    public struct EnvironmentContext {
        public let timeOfDay: String
        public let noiseLevel: Float
        
        public init(timeOfDay: String, noiseLevel: Float) {
            self.timeOfDay = timeOfDay
            self.noiseLevel = noiseLevel
        }
    }
    
    public let presetId: String
    public let sessionId: String
    public let timestamp: Date
    public let quantitative: [String: Any]
    public let qualitative: QualitativeFeedback
    public let context: Context
    public let deviceContext: DeviceContext?
    public let environmentContext: EnvironmentContext?
    public let userEmotion: EmotionType?
    
    public init(presetId: String, sessionId: String, timestamp: Date, quantitative: [String: Any], qualitative: QualitativeFeedback, context: Context, deviceContext: DeviceContext?, environmentContext: EnvironmentContext?, userEmotion: EmotionType?) {
        self.presetId = presetId
        self.sessionId = sessionId
        self.timestamp = timestamp
        self.quantitative = quantitative
        self.qualitative = qualitative
        self.context = context
        self.deviceContext = deviceContext
        self.environmentContext = environmentContext
        self.userEmotion = userEmotion
    }
}

// MARK: - Recommended Preset Model
public struct RecommendedPreset: Equatable {
    public let preset: SoundPreset
    public let score: Float
    public let reasoning: String
    public let personalizedExplanation: String
}

// MARK: - PresetFeedback 확장 (computed properties)
extension PresetFeedback {
    var presetName: String? { quantitative["presetName"] as? String }
    var finalVolumes: [Float]? { quantitative["finalVolumes"] as? [Float] }
    var recommendedVersions: [Int]? { quantitative["recommendedVersions"] as? [Int] }
    var contextEmotion: String? {
        if let ce = quantitative["contextEmotion"] as? String { return ce }
        return nil
    }
    var contextTime: Int? { quantitative["contextTime"] as? Int }
    var listeningDuration: TimeInterval? { quantitative["listeningDuration"] as? TimeInterval }
    var userSatisfaction: Int? { quantitative["userSatisfaction"] as? Int }
    var satisfactionScore: Float {
        return Float(userSatisfaction ?? 5) / 10.0  // Convert 1-10 scale to 0.0-1.0
    }
    var wasSaved: Bool? { quantitative["wasSaved"] as? Bool }
    var wasSkipped: Bool? { quantitative["wasSkipped"] as? Bool }
}

// MARK: - Recommendation Models
public struct RecommendationData: Codable {
    public let title: String
    public let description: String
    public let soundIds: [String]
    public let presetId: String
    public let versions: [String]
    public let timestamp: Date
    
    public init(title: String, description: String, soundIds: [String], presetId: String, versions: [String], timestamp: Date) {
        self.title = title
        self.description = description
        self.soundIds = soundIds
        self.presetId = presetId
        self.versions = versions
        self.timestamp = timestamp
    }
}

public struct RecommendationResponse: Codable {
    public let title: String
    public let description: String
    public let soundIds: [String]
    public let presetId: String
    
    public init(title: String, description: String, soundIds: [String], presetId: String) {
        self.title = title
        self.description = description
        self.soundIds = soundIds
        self.presetId = presetId
    }
}

struct DiaryContext {
    let content: String
    let emotion: String?
}

public struct UserProfile: Codable {
    public var userId: String
    
    public init(userId: String) {
        self.userId = userId
    }
}

// MARK: - Chat & AI Interaction
public extension ChatMessage {
    // ... 기존 ChatMessage 관련 extension 내용
}
