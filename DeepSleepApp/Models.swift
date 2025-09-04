import Foundation

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

// MARK: - ChatMessage extension methods moved to SharedModels.swift

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

extension SoundPreset {
    static func createDefault() -> SoundPreset {
        return SoundPreset(
            name: "기본 프리셋",
            volumes: Array(repeating: 30.0, count: max(1, SoundPresetCatalog.categoryCount)),
            emotion: "기본",
            isAIGenerated: false,
            description: "기본 사운드 프리셋"
        )
    }
}

// PresetFeedback는 SessionDataModels.swift에서 정의됨

// MARK: - Recommended Preset Model
public struct RecommendedPreset: Equatable {
    public let preset: SoundPreset
    public let score: Float
    public let reasoning: String
    public let personalizedExplanation: String
}

// MARK: - PresetFeedback extensions moved to SharedModels.swift
// PresetFeedback is now defined in SharedModels.swift with built-in properties
// and backward compatibility through quantitative computed property

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

public struct EnhancedRecommendationResponse: Codable, Equatable {
    public let presetName: String
    public let volumes: [Float]
    public let versions: [Int]
    public let reason: String?
}

// MARK: - Preset Recommendation DTO (for AI JSON decoding)
public struct AIPresetRecommendationDTO: Codable {
    public let presetName: String?
    public let description: String?
    public let volumes: [Float]?
    public let presetKey: String?
    public let reason: String?
    public let confidence: Double?
    public let personalizedExplanation: String?
    public let adaptation: String?
    public let adaptationLevel: String?
    public let emotion: String?
    public let items: [AIPresetItem]?
}

public struct AIPresetItem: Codable {
    public let soundName: String?
    public let versionName: String?
    public let volume: Float?
}

extension EnhancedRecommendationResponse {
    func toRecommendationResponse() -> RecommendationResponse {
        return RecommendationResponse(
            title: self.presetName,
            description: self.reason ?? "AI 추천 프리셋",
            soundIds: Array(0..<self.volumes.count).map { "sound_\($0)" },
            presetId: UUID().uuidString
        )
    }
}

// MARK: - Preset Recommendation Response (used by ChatViewController)
public struct PresetRecommendationResponse {
    public let volumes: [Float]
    public let presetName: String
    public let selectedVersions: [Int]?
    public let reasoning: String?
    
    public init(volumes: [Float], presetName: String, selectedVersions: [Int]? = nil, reasoning: String? = nil) {
        self.volumes = volumes
        self.presetName = presetName
        self.selectedVersions = selectedVersions
        self.reasoning = reasoning
    }
}

struct DiaryContext {
    let content: String
    let emotion: String?
}

extension DiaryContext {
    init(from diary: EmotionDiary) {
        self.content = diary.userMessage
        self.emotion = diary.selectedEmotion
    }
}

public struct UserProfile: Codable {
    public var userId: String
    
    public init(userId: String) {
        self.userId = userId
    }
}

// MARK: - User Profile Vector (moved from stubs)
struct UserProfileVector {
    var soundPreferences: [Float]
    var timePreferences: [Float]
    var averageSatisfaction: Float
    var emotionPreferences: [String: Float]
    var usagePatterns: [String: Float]
    
    init() {
        self.soundPreferences = Array(repeating: 0.5, count: SoundPresetCatalog.categoryCount)
        self.timePreferences = Array(repeating: 0.1, count: 24)
        self.averageSatisfaction = 0.5
        self.emotionPreferences = [:]
        self.usagePatterns = [:]
    }
    
    init(feedbackData: [PresetFeedback]) {
        self.init()
        if feedbackData.isEmpty { return }
        var timeScores = Array(repeating: 0.0, count: 24)
        var timeCounts = Array(repeating: 0, count: 24)
        var emotionScores: [String: Float] = [:]
        var emotionCounts: [String: Int] = [:]
        var totalSatisfaction: Float = 0.0
        var satisfactionCount = 0
        for feedback in feedbackData {
            let satisfaction = feedback.satisfactionScore
            totalSatisfaction += satisfaction
            satisfactionCount += 1
            let contextTime = Int(feedback.contextTime)
            if contextTime >= 0 && contextTime < 24 {
                timeScores[contextTime] += Double(satisfaction)
                timeCounts[contextTime] += 1
            }
            let emotion = feedback.contextEmotion
            if !emotion.isEmpty {
                emotionScores[emotion, default: 0.0] += satisfaction
                emotionCounts[emotion, default: 0] += 1
            }
        }
        let calculatedAvgSatisfaction = satisfactionCount > 0 ? totalSatisfaction / Float(satisfactionCount) : 0.5
        let calculatedTimePreferences = timeScores.enumerated().map { index, score in
            return timeCounts[index] > 0 ? Float(score / Double(timeCounts[index])) : 0.1
        }
        let calculatedSoundPreferences = Array(repeating: calculatedAvgSatisfaction, count: SoundPresetCatalog.categoryCount)
        var normalizedEmotionPreferences: [String: Float] = [:]
        for (emotion, score) in emotionScores {
            if let count = emotionCounts[emotion], count > 0 {
                normalizedEmotionPreferences[emotion] = score / Float(count)
            }
        }
        let calculatedUsagePatterns: [String: Float]
        if feedbackData.isEmpty {
            calculatedUsagePatterns = [
                "avgDuration": 0.0,
                "completionRate": 0.0,
                "skipRate": 0.0
            ]
        } else {
            calculatedUsagePatterns = [
                "avgDuration": Float(feedbackData.compactMap { $0.listeningDuration }.reduce(0, +)) / Float(feedbackData.count),
                "completionRate": Float(feedbackData.filter { $0.wasSaved == true }.count) / Float(feedbackData.count),
                "skipRate": Float(feedbackData.filter { $0.wasSkipped == true }.count) / Float(feedbackData.count)
            ]
        }
        self.averageSatisfaction = calculatedAvgSatisfaction
        self.timePreferences = calculatedTimePreferences
        self.soundPreferences = calculatedSoundPreferences
        self.emotionPreferences = normalizedEmotionPreferences
        self.usagePatterns = calculatedUsagePatterns
    }
    
    func toFeatureVector() -> [Float] {
        return soundPreferences + timePreferences + [averageSatisfaction] + Array(emotionPreferences.values) + Array(usagePatterns.values)
    }
}

// MARK: - Chat & AI Interaction extensions moved to SharedModels.swift

// MARK: - Core 모듈 마이그레이션으로 누락된 타입들

/// 감정 타입 열거형
public enum EmotionType: String, CaseIterable, Codable {
    case happy = "기쁨"
    case sad = "슬픔"
    case angry = "화남"
    case anxious = "불안"
    case tired = "피곤"
    case neutral = "평온"
    case excited = "신남"
    case calm = "차분함"
    case stressed = "스트레스"
    case peaceful = "평화로움"
    
    public var displayName: String { rawValue }
    public var emoji: String {
        switch self {
        case .happy: return "😊"
        case .sad: return "😢"
        case .angry: return "😡"
        case .anxious: return "😰"
        case .tired: return "😴"
        case .neutral: return "😐"
        case .excited: return "😄"
        case .calm: return "😌"
        case .stressed: return "😫"
        case .peaceful: return "🕊️"
        }
    }
}

/// 추천 컨텍스트 구조체
public struct RecommendationContext {
    public let userEmotion: String
    public let timeOfDay: String
    public let batteryLevel: Float
    public let isHeadphonesConnected: Bool
    public let previousPreferences: [String]
    public let currentActivity: String?
    
    public init(
        userEmotion: String = "평온",
        timeOfDay: String = "오후",
        batteryLevel: Float = 0.8,
        isHeadphonesConnected: Bool = false,
        previousPreferences: [String] = [],
        currentActivity: String? = nil
    ) {
        self.userEmotion = userEmotion
        self.timeOfDay = timeOfDay
        self.batteryLevel = batteryLevel
        self.isHeadphonesConnected = isHeadphonesConnected
        self.previousPreferences = previousPreferences
        self.currentActivity = currentActivity
    }
}

/// AI 작업 라우터
public class LLMRouter {
    public static let shared = LLMRouter()
    
    private init() {}
    
    /// AI 작업 전송
    public func send(task: String, completion: @escaping (Result<String, Error>) -> Void) {
        // UnifiedAIService를 통해 작업 처리
        Task {
            do {
                // TODO: UnifiedAIService와 연동
                let response = "LLMRouter 응답: \(task)"
                DispatchQueue.main.async {
                    completion(.success(response))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
}

/// 슈퍼 추천 엔진
public class SuperRecommendationEngine {
    public static let shared = SuperRecommendationEngine()
    
    private init() {}
    
    /// 사운드 추천
    public func recommendSound(
        for emotion: String,
        context: RecommendationContext? = nil,
        completion: @escaping (Result<[String], Error>) -> Void
    ) {
        // 추천 로직 구현
        DispatchQueue.global(qos: .userInitiated).async {
            let recommendations = ["바다소리", "빗소리", "새소리"] // 기본 추천
            DispatchQueue.main.async {
                completion(.success(recommendations))
            }
        }
    }
    
    /// 일반 추천
    public func recommend(
        for context: RecommendationContext,
        completion: @escaping (Result<[String], Error>) -> Void
    ) {
        recommendSound(for: context.userEmotion, context: context, completion: completion)
    }
}

/// 신경망 프로세서
public class NeuralNetworkProcessor {
    public static let shared = NeuralNetworkProcessor()
    
    private init() {}
    
    /// 데이터 처리
    public func processData<T>(_ data: T) -> T {
        // 신경망 처리 로직 (현재는 그대로 반환)
        return data
    }
    
    /// HealthKit 데이터 분석
    public func analyzeHealthData(_ data: [String: Any]) -> [String: Any] {
        // 건강 데이터 분석 로직
        return data
    }
}

// MARK: - Shared Types (통합)
// ChatMessage, MessageSender, ChatMessageType은 SharedModels.swift에서 정의됨


/// 사운드 추천 컨텍스트
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

/// LLM 요청 설정
public struct LLMRequestConfig {
    public let maxTokens: Int
    public let temperature: Double
    public let topP: Double
    public let model: String?
    
    public init(maxTokens: Int = 1000, temperature: Double = 0.7, topP: Double = 1.0, model: String? = nil) {
        self.maxTokens = maxTokens
        self.temperature = temperature
        self.topP = topP
        self.model = model
    }
}

// MARK: - String Extensions

extension String {
    public static func generalChat(message: String, history: [String]) -> String {
        return "general_chat"
    }
    
    public static func recommendTodo(todos: [String]) -> String {
        return "recommend_todo"
    }
    
    public var generalChat: String {
        return "general_chat"
    }
    
    public var recommendTodo: String {
        return "recommend_todo"
    }
}
