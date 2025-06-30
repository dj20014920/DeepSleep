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

// MARK: - Chat Message Models
public struct ChatMessage: Codable, Identifiable {
    public let id = UUID()
    public let type: ModelsMessageType
    public let text: String
    public let presetName: String?
    public let timestamp: Date
    
    // Non-codable properties
    public var onApplyPreset: (() -> Void)?
    public var onSavePreset: (() -> Void)?
    public var onFeedback: (() -> Void)?
    public var onContinueChat: (() -> Void)?
    public var onRetry: (() -> Void)?
    public var quickActions: [(String, String)]?

    private enum CodingKeys: String, CodingKey {
        case type, text, presetName, timestamp
    }
    
    public init(type: ModelsMessageType, text: String, presetName: String? = nil, timestamp: Date = Date()) {
        self.type = type
        self.text = text
        self.presetName = presetName
        self.timestamp = timestamp
    }
    
    // Custom Codable implementation
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(ModelsMessageType.self, forKey: .type)
        text = try container.decode(String.self, forKey: .text)
        presetName = try container.decodeIfPresent(String.self, forKey: .presetName)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encode(text, forKey: .text)
        try container.encodeIfPresent(presetName, forKey: .presetName)
        try container.encode(timestamp, forKey: .timestamp)
    }
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

// MARK: - ✅ 원래 구조 복원된 감정 일기 모델 (기존 유지)
struct EmotionDiary: Codable, Identifiable {
    let id: UUID
    let date: Date
    let selectedEmotion: String
    let userMessage: String    // ✅ 원래대로 userMessage 사용
    let aiResponse: String     // ✅ 원래대로 aiResponse 사용
    
    // ✅ 원래 초기화 방식 복원
    init(id: UUID = UUID(), selectedEmotion: String, userMessage: String, aiResponse: String, date: Date = Date()) {
        self.id = id
        self.selectedEmotion = selectedEmotion
        self.userMessage = userMessage
        self.aiResponse = aiResponse
        self.date = date
    }
    
    // ✅ 편의 초기화 (기존 코드 호환성)
    init(selectedEmotion: String, userMessage: String, aiResponse: String) {
        self.init(selectedEmotion: selectedEmotion, userMessage: userMessage, aiResponse: aiResponse, date: Date())
    }
}

// MARK: - ✅ 확장된 사운드 프리셋 모델 (버전 정보 포함)
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
    var createdDate: Date         // 🛑 let에서 var로 변경하여 업데이트 가능하도록 함
    var lastUsed: Date?           // ✅ 최근 사용 시간 추가
    
    // ✅ 새로 추가: 버전 정보 (11개 카테고리)
    let selectedVersions: [Int]?  // 각 카테고리별 선택된 버전 인덱스
    let presetVersion: String     // 프리셋 버전 ("v1.0" = 12개, "v2.0" = 11개)
    
    // MARK: - 기존 호환성 초기화 (12개 → 11개 변환 없이 저장)
    init(name: String, volumes: [Float], emotion: String? = nil, isAIGenerated: Bool = false, description: String? = nil) {
        self.id = UUID()
        self.name = name
        self.volumes = volumes
        self.emotion = emotion
        self.isAIGenerated = isAIGenerated
        self.description = description
        self.scientificBasis = nil  // 기존 호환성을 위해 nil
        self.createdDate = Date()
        self.lastUsed = Date()      // ✅ 수정: 새로 생성되는 프리셋은 현재 시간으로 설정
        
        // 기존 버전 호환성
        if volumes.count == 12 {
            self.presetVersion = "v1.0"  // 기존 12개 프리셋
            self.selectedVersions = nil  // 버전 정보 없음
        } else {
            self.presetVersion = "v2.0"  // 새로운 11개 프리셋
            self.selectedVersions = SoundPresetCatalog.defaultVersions  // 기본 버전
        }
    }
    
    // MARK: - 새로운 초기화 (버전 정보 포함)
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
        self.lastUsed = Date()      // ✅ 수정: 새로 생성되는 프리셋은 현재 시간으로 설정
        self.presetVersion = "v2.0"  // 새로운 형식
    }
    
    // MARK: - 완전한 초기화 (모든 속성 지정)
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
        self.lastUsed = lastUsed ?? Date() // ✅ 수정: nil인 경우 현재 시간으로 설정
    }
    
    // MARK: - 버전 호환성 메서드
    
    /// 11개 카테고리용 볼륨 배열 반환
    var compatibleVolumes: [Float] {
        // v1.0 (12개) -> 13개로 변환 (패딩 1개)
        if presetVersion == "v1.0" && volumes.count == 12 {
            return volumes + [0.0]
        }
        
        // 초기 버전 (11개) -> 13개로 변환 (패딩 2개)
        if volumes.count == 11 {
            return volumes + [0.0, 0.0]
        }
        
        // 크기가 이미 맞거나 다른 경우, 원본을 반환하여 applyPreset의 보정 로직에 위임
            return volumes
    }
    
    /// 현재 선택된 버전들 반환 (없으면 기본값)
    var compatibleVersions: [Int] {
        return selectedVersions ?? SoundPresetCatalog.defaultVersions
    }
    
    /// 프리셋이 새로운 11개 카테고리 형식인지 확인
    var isNewFormat: Bool {
        return presetVersion == "v2.0"
    }
    
    /// 레거시 형식에서 새 형식으로 업그레이드
    func upgraded() -> SoundPreset {
        if isNewFormat {
            return self  // 이미 새 형식
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
}

// MARK: - ✅ 프리셋 버전 관리
struct PresetManager {
    static let shared = PresetManager()
    
    private init() {}
    
    /// 기존 프리셋들을 새 형식으로 마이그레이션 (통합 및 강화)
    func migrateLegacyPresetsIfNeeded() {
        let userDefaults = UserDefaults.standard
        let migrationKey = "presetMigrationV3Completed" // 키 변경으로 재실행 보장

        guard !userDefaults.bool(forKey: migrationKey) else {
            print("✅ 통합 프리셋 마이그레이션 이미 완료됨")
            return
        }

        let existingPresets = SettingsManager.shared.loadSoundPresets()
        var migratedCount = 0
        // needsSave 변수는 미래 확장을 위해 예약됨
        // var needsSave = false

        let updatedPresets = existingPresets.map { preset -> SoundPreset in
            var mutablePreset = preset
            var presetWasModified = false

            // 조건 1: isNewFormat이 false인 경우 (12개 볼륨 -> 11개로 변환 필요)
            if !mutablePreset.isNewFormat {
                mutablePreset = mutablePreset.upgraded()
                presetWasModified = true
            }

            // 조건 2: selectedVersions가 nil인 경우 (버전 정보 추가 필요)
            if mutablePreset.selectedVersions == nil {
                // SoundPreset의 init에서 이미 기본값을 할당하므로, 여기서는 nil 체크만으로 충분
                // 하지만 명시적으로 다시 할당하여 안정성 강화
                var newVolumes = mutablePreset.volumes
                if newVolumes.count != SoundPresetCatalog.categoryCount {
                    newVolumes = Array(repeating: 0.0, count: SoundPresetCatalog.categoryCount)
                }
                
                mutablePreset = SoundPreset(
                    name: mutablePreset.name,
                    volumes: newVolumes,
                    selectedVersions: SoundPresetCatalog.defaultVersions,
                    emotion: mutablePreset.emotion,
                    isAIGenerated: mutablePreset.isAIGenerated,
                    description: mutablePreset.description,
                    scientificBasis: mutablePreset.scientificBasis
                )
                presetWasModified = true
            }

            if presetWasModified {
                migratedCount += 1
            }
            return mutablePreset
        }
        
        // 변경된 경우에만 전체 프리셋을 다시 저장
        if migratedCount > 0 {
            SettingsManager.shared.replaceAllPresets(with: updatedPresets)
            print("✅ 통합 프리셋 마이그레이션 완료: \(migratedCount)개 업그레이드")
        }

        userDefaults.set(true, forKey: migrationKey)
    }
    
    /// 새로운 버전 정보를 포함한 프리셋 저장
    func savePresetWithVersions(name: String, volumes: [Float], versions: [Int], emotion: String? = nil, isAIGenerated: Bool = false) {
        let preset = SoundPreset(
            name: name,
            volumes: volumes,
            selectedVersions: versions,
            emotion: emotion,
            isAIGenerated: isAIGenerated,
            description: isAIGenerated ? "AI 추천 프리셋" : "사용자 저장 프리셋",
            scientificBasis: nil
        )
        
        SettingsManager.shared.saveSoundPreset(preset)
        print("✅ 새 형식 프리셋 저장: \(name)")
    }
}

// MARK: - 추천 응답 모델 (중복 정의 방지를 위해 통합)
struct RecommendationResponse {
    let volumes: [Float]
    let presetName: String
    let selectedVersions: [Int]
    
    init(volumes: [Float], presetName: String = "맞춤 프리셋", selectedVersions: [Int]? = nil) {
        self.volumes = volumes
        self.presetName = presetName
        self.selectedVersions = selectedVersions ?? Array(repeating: 0, count: 13)
    }
}

// MARK: - 일기 컨텍스트 모델 (기존 유지)
struct DiaryContext {
    let emotion: String
    let content: String
    let date: Date
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy년 M월 d일"
        return formatter.string(from: date)
    }
    
    var contextPrompt: String {
        return """
        사용자가 작성한 감정 일기:
        
        날짜: \(formattedDate)
        감정: \(emotion)
        
        일기 내용:
        \(content)
        
        위 일기를 읽고 사용자의 감정에 깊이 공감해주시고, 
        따뜻하고 위로가 되는 대화를 해주세요.
        마음의 안정을 위한 조언도 함께 해주시면 좋겠습니다.
        """
    }
    
    // ✅ EmotionDiary에서 DiaryContext 생성하는 편의 메소드 (원래 구조로)
    init(from diary: EmotionDiary) {
        self.emotion = diary.selectedEmotion
        self.content = diary.userMessage  // ✅ userMessage 사용
        self.date = diary.date
    }
}

// MARK: - 사용자 설정 모델 (기존 유지)
struct UserSettings: Codable {
    var dailyChatLimit: Int = 50
    var dailyPresetLimit: Int = 5
    var enableNotifications: Bool = true
    var autoSavePresets: Bool = true
    var preferredFadeOutDuration: TimeInterval = 30.0
    var enableHapticFeedback: Bool = true
    var preferredTheme: Theme = .system
    
    enum Theme: String, CaseIterable, Codable {
        case light = "라이트"
        case dark = "다크"
        case system = "시스템"
    }
}

// MARK: - 사용 통계 모델 (기존 유지)
struct UsageStats: Codable {
    let date: String
    var chatCount: Int = 0
    var presetRecommendationCount: Int = 0
    var patternAnalysisCount: Int = 0
    var diaryAnalysisCount: Int = 0
    var timerUsageCount: Int = 0
    var totalSessionTime: TimeInterval = 0
    var mostUsedEmotion: String?
    var effectivePresets: [String] = []
    
    init(date: String) {
        self.date = date
    }
}

// MARK: - Phase 1: JSON 기반 AI 응답 데이터 모델

/// JSON 파싱 에러 타입
enum JSONParsingError: Error, LocalizedError {
    case invalidJSON
    case missingRequiredFields
    case invalidVolumeCount
    case invalidVersionCount
    
    var errorDescription: String? {
        switch self {
        case .invalidJSON:
            return "JSON 형식이 올바르지 않습니다"
        case .missingRequiredFields:
            return "필수 필드가 누락되었습니다"
        case .invalidVolumeCount:
            return "볼륨 배열의 크기가 올바르지 않습니다 (13개 필요)"
        case .invalidVersionCount:
            return "버전 배열의 크기가 올바르지 않습니다 (13개 필요)"
        }
    }
}

/// AI API 응답 데이터 모델
struct AIResponseData: Codable {
    let presetName: String
    let volumes: [Float]
    let versions: [Int]?
    let explanation: String?
    let confidence: Float?
    let scientificBasis: String?
    let estimatedEffectiveness: Float?
    let additionalNotes: String?
    
    private enum CodingKeys: String, CodingKey {
        case presetName = "preset_name"
        case volumes
        case versions
        case explanation
        case confidence
        case scientificBasis = "scientific_basis"
        case estimatedEffectiveness = "estimated_effectiveness"
        case additionalNotes = "additional_notes"
    }
}

/// ChatViewController+Preset.swift에서 사용하는 향상된 추천 응답 모델
struct EnhancedRecommendationResponse {
    let volumes: [Float]
    let selectedVersions: [Int]?
    let presetName: String
    let explanation: String?
    let confidence: Float?
    let scientificBasis: String?
    let estimatedEffectiveness: Float?
    let additionalNotes: String?
    
    /// AIResponseData로부터 생성
    init(from aiResponse: AIResponseData) {
        self.volumes = aiResponse.volumes
        self.selectedVersions = aiResponse.versions
        self.presetName = aiResponse.presetName
        self.explanation = aiResponse.explanation
        self.confidence = aiResponse.confidence
        self.scientificBasis = aiResponse.scientificBasis
        self.estimatedEffectiveness = aiResponse.estimatedEffectiveness
        self.additionalNotes = aiResponse.additionalNotes
    }
    
    /// 직접 생성 (레거시 호환성)
    init(
        volumes: [Float],
        selectedVersions: [Int]? = nil,
        presetName: String,
        explanation: String? = nil,
        confidence: Float? = nil,
        scientificBasis: String? = nil,
        estimatedEffectiveness: Float? = nil,
        additionalNotes: String? = nil
    ) {
        self.volumes = volumes
        self.selectedVersions = selectedVersions
        self.presetName = presetName
        self.explanation = explanation
        self.confidence = confidence
        self.scientificBasis = scientificBasis
        self.estimatedEffectiveness = estimatedEffectiveness
        self.additionalNotes = additionalNotes
    }
}

// MARK: - Phase 2: SwiftData 기반 피드백 모델

#if canImport(SwiftData)
@Model
@available(iOS 17.0, *)
class PresetFeedback {
    @Attribute(.unique) var id: UUID
    var timestamp: Date
    var presetName: String
    var contextEmotion: String
    var contextTime: Int
    
    // 추천 데이터
    var recommendedVolumes: [Float]
    var recommendedVersions: [Int]
    
    // 실제 사용 데이터
    var finalVolumes: [Float]
    var listeningDuration: TimeInterval
    var wasSkipped: Bool
    var wasSaved: Bool
    
    // 피드백 데이터
    var userSatisfaction: Int // 0: 없음, 1: 싫어요, 2: 좋아요
    
    init(
        presetName: String,
        contextEmotion: String,
        contextTime: Int,
        recommendedVolumes: [Float],
        recommendedVersions: [Int]
    ) {
        self.id = UUID()
        self.timestamp = Date()
        self.presetName = presetName
        self.contextEmotion = contextEmotion
        self.contextTime = contextTime
        self.recommendedVolumes = recommendedVolumes
        self.recommendedVersions = recommendedVersions
        
        // 초기값
        self.finalVolumes = recommendedVolumes
        self.listeningDuration = 0
        self.wasSkipped = false
        self.wasSaved = false
        self.userSatisfaction = 0
    }
    
    /// 만족도 점수 (0.0 ~ 1.0)
    var satisfactionScore: Float {
        // 복합 점수 계산
        var score: Float = 0.5 // 기본값
        
        // 1. 명시적 피드백 (가중치 40%)
        if userSatisfaction == 2 { // 좋아요
            score += 0.4
        } else if userSatisfaction == 1 { // 싫어요
            score -= 0.4
        }
        
        // 2. 청취 시간 (가중치 30%)
        let timeScore = min(listeningDuration / 600.0, 1.0) * 0.3 // 10분 = 최고점
        score += Float(timeScore)
        
        // 3. 저장 여부 (가중치 20%)
        if wasSaved {
            score += 0.2
        }
        
        // 4. 스킵 여부 (가중치 10%)
        if wasSkipped {
            score -= 0.1
        }
        
        return max(0.0, min(1.0, score))
    }
    
    // MARK: - 내부 구조체들 (호환성을 위해 추가)
    
    struct DeviceContext: Codable {
        let volume: Float                 // 시스템 볼륨
        let brightness: Float             // 화면 밝기
        let batteryLevel: Float           // 배터리 수준
        let deviceOrientation: String     // 기기 방향
        let headphonesConnected: Bool     // 헤드폰 연결 여부
        
        init(
            volume: Float = 0.5,
            brightness: Float = 0.5,
            batteryLevel: Float = 1.0,
            deviceOrientation: String = "portrait",
            headphonesConnected: Bool = false
        ) {
            self.volume = volume
            self.brightness = brightness
            self.batteryLevel = batteryLevel
            self.deviceOrientation = deviceOrientation
            self.headphonesConnected = headphonesConnected
        }
    }
    
    struct EnvironmentContext: Codable {
        let lightLevel: String            // "어두움", "밝음", "보통"
        let noiseLevel: Float             // 0.0-1.0 주변 소음
        let weatherCondition: String?     // 날씨 (가능시)
        let location: String?             // "집", "사무실", "카페" 등 (일반화)
        let timeOfUse: String             // "아침", "점심", "저녁", "밤", "새벽"
        
        init(
            lightLevel: String = "보통",
            noiseLevel: Float = 0.5,
            weatherCondition: String? = nil,
            location: String? = nil,
            timeOfUse: String = "하루"
        ) {
            self.lightLevel = lightLevel
            self.noiseLevel = noiseLevel
            self.weatherCondition = weatherCondition
            self.location = location
            self.timeOfUse = timeOfUse
        }
    }
}
#endif

/// Phase 2: 사용자 프로필 벡터 (피드백 기반 분석)
@available(iOS 17.0, *)
struct UserProfileVector {
    // 사운드 선호도 (13차원)
    let soundPreferences: [Float]
    
    // 시간대별 패턴 (24차원)
    let timePreferences: [Float]
    
    // 감정별 패턴 (3차원: 긍정, 중성, 부정)
    let emotionPatterns: [Float]
    
    // 사용 패턴 (13차원: 각 카테고리별 사용 빈도)
    let usagePatterns: [Float]
    
    // 평균 만족도 (호환성을 위해 추가)
    let averageSatisfaction: Float
    
    // 버전 선호도 (호환성을 위해 추가)
    let versionPreferences: [Float]
    
    init(feedbackData: [PresetFeedback]) {
        // 사운드 선호도 계산 (13차원)
        self.soundPreferences = Self.calculateSoundPreferences(from: feedbackData)
        
        // 시간대별 선호도 계산 (24차원)
        self.timePreferences = Self.calculateTimePreferences(from: feedbackData)
        
        // 감정별 패턴 계산 (3차원)
        self.emotionPatterns = Self.calculateEmotionPatterns(from: feedbackData)
        
        // 사용 패턴 계산 (13차원)
        self.usagePatterns = Self.calculateUsagePatterns(from: feedbackData)
        
        // 평균 만족도 계산
        self.averageSatisfaction = Self.calculateAverageSatisfaction(from: feedbackData)
        
        // 버전 선호도 계산 (13차원)
        self.versionPreferences = Self.calculateVersionPreferences(from: feedbackData)
    }
    
    /// 특성 벡터로 변환 (53차원: 13+24+3+13)
    func toFeatureVector() -> [Float] {
        var vector: [Float] = []
        vector.append(contentsOf: soundPreferences)
        vector.append(contentsOf: timePreferences)
        vector.append(contentsOf: emotionPatterns)
        vector.append(contentsOf: usagePatterns)
        return vector
    }
    
    /// 배열로 변환 (호환성을 위해 추가)
    func toArray() -> [Float] {
        return toFeatureVector()
    }
    
    // MARK: - 계산 메서드들
    
    private static func calculateSoundPreferences(from feedbackData: [PresetFeedback]) -> [Float] {
        guard !feedbackData.isEmpty else {
            return Array(repeating: 0.5, count: 13)
        }
        
        var preferences: [Float] = Array(repeating: 0.0, count: 13)
        var counts: [Int] = Array(repeating: 0, count: 13)
        
        for feedback in feedbackData {
            let satisfaction = feedback.satisfactionScore
            
            for (index, volume) in feedback.finalVolumes.enumerated() {
                if index < 13 && volume > 0 {
                    preferences[index] += satisfaction * (volume / 100.0)
                    counts[index] += 1
                }
            }
        }
        
        // 평균 계산
        for i in 0..<13 {
            if counts[i] > 0 {
                preferences[i] /= Float(counts[i])
            } else {
                preferences[i] = 0.5 // 기본값
            }
        }
        
        return preferences
    }
    
    private static func calculateTimePreferences(from feedbackData: [PresetFeedback]) -> [Float] {
        var timeStats: [Float] = Array(repeating: 0.0, count: 24)
        var timeCounts: [Int] = Array(repeating: 0, count: 24)
        
        for feedback in feedbackData {
            let hour = feedback.contextTime
            if hour >= 0 && hour < 24 {
                timeStats[hour] += feedback.satisfactionScore
                timeCounts[hour] += 1
            }
        }
        
        // 평균 계산 및 정규화
        for i in 0..<24 {
            if timeCounts[i] > 0 {
                timeStats[i] /= Float(timeCounts[i])
            } else {
                timeStats[i] = 0.5 // 기본값
            }
        }
        
        return timeStats
    }
    
    private static func calculateEmotionPatterns(from feedbackData: [PresetFeedback]) -> [Float] {
        var positiveScore: Float = 0.0
        var neutralScore: Float = 0.0
        var negativeScore: Float = 0.0
        var posCount = 0, neuCount = 0, negCount = 0
        
        for feedback in feedbackData {
            let satisfaction = feedback.satisfactionScore
            
            switch feedback.contextEmotion {
            case "기쁨", "신남", "사랑", "행복":
                positiveScore += satisfaction
                posCount += 1
            case "무덤덤", "평온":
                neutralScore += satisfaction
                neuCount += 1
            default:
                negativeScore += satisfaction
                negCount += 1
            }
        }
        
        return [
            posCount > 0 ? positiveScore / Float(posCount) : 0.5,
            neuCount > 0 ? neutralScore / Float(neuCount) : 0.5,
            negCount > 0 ? negativeScore / Float(negCount) : 0.5
        ]
    }
    
    private static func calculateUsagePatterns(from feedbackData: [PresetFeedback]) -> [Float] {
        var usageFreq: [Float] = Array(repeating: 0.0, count: 13)
        
        let totalSessions = max(1, feedbackData.count)
        
        for feedback in feedbackData {
            for (index, volume) in feedback.finalVolumes.enumerated() {
                if index < 13 && volume > 0 {
                    usageFreq[index] += 1.0
                }
            }
        }
        
        // 정규화 (0-1 범위)
        return usageFreq.map { $0 / Float(totalSessions) }
    }
    
    private static func calculateAverageSatisfaction(from feedbackData: [PresetFeedback]) -> Float {
        guard !feedbackData.isEmpty else { return 0.5 }
        
        let totalSatisfaction = feedbackData.reduce(0.0) { $0 + $1.satisfactionScore }
        return totalSatisfaction / Float(feedbackData.count)
    }
    
    private static func calculateVersionPreferences(from feedbackData: [PresetFeedback]) -> [Float] {
        guard !feedbackData.isEmpty else {
            return Array(repeating: 0.5, count: 13)
        }
        
        var versionStats: [Float] = Array(repeating: 0.0, count: 13)
        var versionCounts: [Int] = Array(repeating: 0, count: 13)
        
        for feedback in feedbackData {
            let satisfaction = feedback.satisfactionScore
            
            for (index, version) in feedback.recommendedVersions.enumerated() {
                if index < 13 {
                    versionStats[index] += satisfaction * Float(version)
                    versionCounts[index] += 1
                }
            }
        }
        
        // 평균 계산
        for i in 0..<13 {
            if versionCounts[i] > 0 {
                versionStats[i] /= Float(versionCounts[i])
                versionStats[i] = versionStats[i] / 5.0 // 0-5 범위를 0-1로 정규화
            } else {
                versionStats[i] = 0.5 // 기본값
            }
        }
        
        return versionStats
    }
}

// MARK: - ✅ 감정 패턴 분석 모델 (기존 유지)
struct EmotionPattern: Codable {
    let startDate: Date
    let endDate: Date
    let emotionFrequency: [String: Int]
    let totalEntries: Int
    let mostFrequentEmotion: String
    let averageEntriesPerDay: Double
    let emotionTrend: EmotionTrend
    
    enum EmotionTrend: String, Codable {
        case improving = "개선"
        case stable = "안정"
        case declining = "하락"
        case mixed = "혼재"
    }
    
    var analysisText: String {
        let period = Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 0
        return """
        📊 \(period)일간 감정 패턴 분석
        
        • 총 기록: \(totalEntries)개
        • 가장 많은 감정: \(mostFrequentEmotion)
        • 평균 일일 기록: \(String(format: "%.1f", averageEntriesPerDay))개
        • 전체적 경향: \(emotionTrend.rawValue)
        
        감정별 빈도:
        \(emotionFrequency.map { "\($0.key): \($0.value)회" }.joined(separator: "\n"))
        """
    }
}

// MARK: - ✅ 차트 데이터 모델 (향후 차트 구현용)
struct ChartDataPoint: Codable {
    let date: Date
    let emotion: String
    let value: Double // 감정 점수 또는 빈도
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"
        return formatter.string(from: date)
    }
}

struct EmotionChartData: Codable {
    let title: String
    let dataPoints: [ChartDataPoint]
    let chartType: ChartType
    
    enum ChartType: String, Codable {
        case line = "라인"
        case bar = "막대"
        case pie = "원형"
    }
}

// MARK: - ✅ 인사이트 카드 모델
struct InsightCard {
    let id = UUID()
    let title: String
    let content: String
    let color: UIColor
    let icon: String
    let actionTitle: String?
    let action: (() -> Void)?
    
    init(title: String, content: String, color: UIColor, icon: String, actionTitle: String? = nil, action: (() -> Void)? = nil) {
        self.title = title
        self.content = content
        self.color = color
        self.icon = icon
        self.actionTitle = actionTitle
        self.action = action
    }
}

// MARK: - ✅ 데이터 내보내기/가져오기 모델
struct ExportData: Codable {
    let exportDate: Date
    let diaries: [EmotionDiary]
    let presets: [SoundPreset]
    let settings: UserSettings
    let stats: [String: UsageStats]
    let appVersion: String
    
    init(diaries: [EmotionDiary], presets: [SoundPreset], settings: UserSettings, stats: [String: UsageStats]) {
        self.exportDate = Date()
        self.diaries = diaries
        self.presets = presets
        self.settings = settings
        self.stats = stats
        self.appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }
}

// MARK: - ✅ 확장 메소드들
extension EmotionDiary {
    
    /// 일기의 감정 카테고리 반환
    var emotionCategory: Emotion.EmotionCategory {
        let emotion = Emotion.predefinedEmotions.first { $0.emoji == selectedEmotion }
        return emotion?.category ?? .neutral
    }
    
    /// 일기 길이에 따른 상세도 레벨
    var detailLevel: DetailLevel {
        switch userMessage.count {  // ✅ userMessage 사용
        case 0..<50:
            return .brief
        case 50..<200:
            return .moderate
        default:
            return .detailed
        }
    }
    
    enum DetailLevel: String {
        case brief = "간단"
        case moderate = "보통"
        case detailed = "상세"
    }
}

extension Array where Element == EmotionDiary {
    
    /// 날짜 범위별 일기 필터링
    func entries(in dateRange: ClosedRange<Date>) -> [EmotionDiary] {
        return self.filter { dateRange.contains($0.date) }
    }
    
    /// 특정 감정의 일기만 필터링
    func entries(with emotion: String) -> [EmotionDiary] {
        return self.filter { $0.selectedEmotion == emotion }
    }
    
    /// 감정 패턴 분석 생성
    func generatePattern(for period: Int = 30) -> EmotionPattern {
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -period, to: endDate) ?? endDate
        
        let filteredEntries = self.entries(in: startDate...endDate)
        let emotionFrequency = Dictionary(grouping: filteredEntries, by: { $0.selectedEmotion })
            .mapValues { $0.count }
        
        let mostFrequent = emotionFrequency.max { $0.value < $1.value }?.key ?? "😊"
        let averagePerDay = Double(filteredEntries.count) / Double(period)
        
        return EmotionPattern(
            startDate: startDate,
            endDate: endDate,
            emotionFrequency: emotionFrequency,
            totalEntries: filteredEntries.count,
            mostFrequentEmotion: mostFrequent,
            averageEntriesPerDay: averagePerDay,
            emotionTrend: calculateTrend(for: filteredEntries)
        )
    }
    
    /// 감정 트렌드 계산
    private func calculateTrend(for entries: [EmotionDiary]) -> EmotionPattern.EmotionTrend {
        guard entries.count >= 7 else { return .stable }
        
        let sortedEntries = entries.sorted { $0.date < $1.date }
        let midPoint = sortedEntries.count / 2
        
        let firstHalf = Array(sortedEntries.prefix(midPoint))
        let secondHalf = Array(sortedEntries.suffix(midPoint))
        
        let firstPositiveRatio = calculatePositiveEmotionRatio(firstHalf)
        let secondPositiveRatio = calculatePositiveEmotionRatio(secondHalf)
        
        let difference = secondPositiveRatio - firstPositiveRatio
        
        switch difference {
        case 0.1...:
            return .improving
        case ..<(-0.1):
            return .declining
        case -0.1...0.1:
            return .stable
        default:
            return .mixed
        }
    }
    
    /// 긍정적 감정 비율 계산
    private func calculatePositiveEmotionRatio(_ entries: [EmotionDiary]) -> Double {
        guard !entries.isEmpty else { return 0 }
        
        let positiveEmotions = ["😊", "😄", "🥰", "😐", "🙂"]
        let positiveCount = entries.filter { positiveEmotions.contains($0.selectedEmotion) }.count
        
        return Double(positiveCount) / Double(entries.count)
    }
}

// MARK: - ✅ SoundPreset 확장
extension SoundPreset {
    
    /// 프리셋의 주요 사운드 카테고리들 (볼륨이 높은 순)
    var dominantCategories: [(emoji: String, name: String, volume: Float)] {
        let volumes = compatibleVolumes
        let categoryCount = min(volumes.count, SoundPresetCatalog.categoryCount)
        
        var results: [(emoji: String, name: String, volume: Float)] = []
        
        for i in 0..<categoryCount {
            if volumes[i] > 0 {
                results.append((
                    emoji: SoundPresetCatalog.categoryEmojis[i],
                    name: SoundPresetCatalog.categoryNames[i],
                    volume: volumes[i]
                ))
            }
        }
        
        return results.sorted { $0.volume > $1.volume }
    }
    
    /// 프리셋 요약 텍스트
    var summaryText: String {
        let dominant = dominantCategories.prefix(3)
        if dominant.isEmpty {
            return "🔇 무음"
        }
        
        let descriptions = dominant.map { "\($0.emoji)\($0.name)" }
        return descriptions.joined(separator: " + ")
    }
    
    /// 프리셋의 전체 볼륨 레벨
    var totalVolumeLevel: VolumeLevel {
        let totalVolume = compatibleVolumes.reduce(0, +)
        switch totalVolume {
        case 0:
            return .silent
        case 1..<100:
            return .low
        case 100..<300:
            return .medium
        case 300..<600:
            return .high
        default:
            return .veryHigh
        }
    }
    
    enum VolumeLevel: String {
        case silent = "무음"
        case low = "낮음"
        case medium = "보통"
        case high = "높음"
        case veryHigh = "매우 높음"
    }
}

// MARK: - ✅ SettingsManager 확장을 위한 프로토콜
protocol EmotionDiaryManaging {
    func saveEmotionDiary(_ entry: EmotionDiary)
    func loadEmotionDiary() -> [EmotionDiary]
    func deleteEmotionDiary(id: UUID)
    func updateEmotionDiary(_ updatedDiary: EmotionDiary)
    func clearAllEmotionDiaries()
}

// MARK: - ✅ 유틸리티 확장
extension Date {
    
    /// 오늘인지 확인
    var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }
    
    /// 이번 주인지 확인
    var isThisWeek: Bool {
        Calendar.current.isDate(self, equalTo: Date(), toGranularity: .weekOfYear)
    }
    
    /// 상대적 시간 표현
    var relativeString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}

extension String {
    
    /// 감정 이모지인지 확인
    var isEmotionEmoji: Bool {
        let emotionEmojis = ["😊", "😢", "😡", "😰", "😴", "🥰", "😞", "😤", "😱", "😪", "😐", "🙂"]
        return emotionEmojis.contains(self)
    }
    
    /// 텍스트 감정 점수 (간단한 키워드 기반)
    var emotionScore: Double {
        let positiveKeywords = ["좋", "행복", "기쁨", "즐거", "편안", "만족", "완벽", "최고"]
        let negativeKeywords = ["나쁘", "슬프", "우울", "힘들", "불안", "화나", "짜증", "최악"]
        
        let text = self.lowercased()
        var score = 0.0
        
        for keyword in positiveKeywords {
            if text.contains(keyword) { score += 1.0 }
        }
        
        for keyword in negativeKeywords {
            if text.contains(keyword) { score -= 1.0 }
        }
        
        return score
    }
}

// MARK: - ✅ 색상 확장 (감정별 색상)
extension UIColor {
    
    static func emotionColor(for emotion: String) -> UIColor {
        switch emotion {
        case "😊", "😄", "🥰":
            return .systemYellow.withAlphaComponent(0.3)
        case "😢", "😞", "😔":
            return .systemBlue.withAlphaComponent(0.3)
        case "😡", "😤":
            return .systemRed.withAlphaComponent(0.3)
        case "😰", "😱", "😨":
            return .systemOrange.withAlphaComponent(0.3)
        case "😴", "😪":
            return .systemPurple.withAlphaComponent(0.3)
        default:
            return .systemGray.withAlphaComponent(0.3)
        }
    }
    
    /// 다크 모드 호환 색상
    static var adaptiveBackground: UIColor {
        if #available(iOS 13.0, *) {
            return UIColor { traitCollection in
                traitCollection.userInterfaceStyle == .dark ? .systemGray6 : .systemBackground
            }
        } else {
            return .white
        }
    }
    
    static var adaptiveText: UIColor {
        if #available(iOS 13.0, *) {
            return .label
        } else {
            return .black
        }
    }
}

// MARK: - ✅ 디버그 및 로깅 확장
extension EmotionDiary {
    
    #if DEBUG
    /// 디버그용 일기 생성
    static func mockDiary(emotion: String = "😊", userMessage: String = "테스트 일기입니다.", aiResponse: String = "테스트 AI 응답입니다.", daysAgo: Int = 0) -> EmotionDiary {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
        return EmotionDiary(selectedEmotion: emotion, userMessage: userMessage, aiResponse: aiResponse, date: date)
    }
    
    /// 디버그용 여러 일기 생성
    static func mockDiaries(count: Int = 10) -> [EmotionDiary] {
        let emotions = ["😊", "😢", "😡", "😰", "😴", "🥰", "😞", "😤", "😱", "😪"]
        let userMessages = [
            "오늘은 정말 좋은 하루였어요!",
            "조금 우울한 기분이에요.",
            "화가 나는 일이 있었어요.",
            "불안한 마음이 들어요.",
            "너무 피곤해요.",
            "사랑스러운 순간이었어요.",
            "실망스러운 하루였어요.",
            "짜증이 많이 났어요.",
            "무서운 일이 있었어요.",
            "잠이 너무 와요."
        ]
        let aiResponses = [
            "좋은 하루를 보내셨군요! 이런 긍정적인 에너지를 계속 유지하세요.",
            "우울한 기분이 드는 것은 자연스러운 일이에요. 천천히 회복해나가세요.",
            "화나는 일이 있으셨군요. 깊게 숨을 쉬고 마음을 진정시켜보세요.",
            "불안함을 느끼고 계시는군요. 명상이나 가벼운 운동이 도움이 될 수 있어요.",
            "피곤하신 것 같네요. 충분한 휴식을 취하시길 바래요.",
            "사랑스러운 순간을 경험하셨군요! 이런 따뜻한 감정을 간직하세요.",
            "실망스러운 하루였군요. 내일은 더 나은 하루가 될 거예요.",
            "짜증이 나셨군요. 잠시 휴식을 취하고 마음을 가라앉혀보세요.",
            "무서운 경험을 하셨군요. 안전한 곳에 계시니 괜찮을 거예요.",
            "잠이 오는군요. 충분한 수면은 건강에 중요해요."
        ]
        
        return (0..<count).map { index in
            mockDiary(
                emotion: emotions[index % emotions.count],
                userMessage: userMessages[index % userMessages.count],
                aiResponse: aiResponses[index % aiResponses.count],
                daysAgo: index
            )
        }
    }
    #endif
}

// MARK: - ✅ 에러 타입 정의
enum DeepSleepError: LocalizedError {
    case diaryNotFound
    case invalidData
    case saveFailure
    case loadFailure
    case networkError
    case permissionDenied
    case presetVersionMismatch
    case soundFileNotFound
    
    var errorDescription: String? {
        switch self {
        case .diaryNotFound:
            return "일기를 찾을 수 없습니다."
        case .invalidData:
            return "잘못된 데이터입니다."
        case .saveFailure:
            return "저장에 실패했습니다."
        case .loadFailure:
            return "불러오기에 실패했습니다."
        case .networkError:
            return "네트워크 오류가 발생했습니다."
        case .permissionDenied:
            return "권한이 거부되었습니다."
        case .presetVersionMismatch:
            return "프리셋 버전이 호환되지 않습니다."
        case .soundFileNotFound:
            return "사운드 파일을 찾을 수 없습니다."
        }
    }
}

// MARK: - ✅ 상수 정의
struct DeepSleepConstants {
    struct UI {
        static let cornerRadius: CGFloat = 12
        static let padding: CGFloat = 16
        static let smallPadding: CGFloat = 8
        static let buttonHeight: CGFloat = 50
        static let cellHeight: CGFloat = 140
    }
    
    struct Animation {
        static let duration: TimeInterval = 0.3
        static let springDamping: CGFloat = 0.8
        static let springVelocity: CGFloat = 0.5
    }
    
    struct Limits {
        static let maxDiaryLength = 1000
        static let maxDiaryCount = 500
        static let recentDiaryCount = 10
        static let analysisDefaultPeriod = 30
    }
    
    struct Sound {
        static let categoryCount = 13  // 그룹화된 13개 슬라이더
        static let previewDuration: TimeInterval = 3.0
        static let defaultFadeOutDuration: TimeInterval = 30.0
        static let maxVolume: Float = 100.0
        static let minVolume: Float = 0.0
    }
}

// MARK: - 향상된 감정 모델

/// 고도화된 감정 분석 모델
struct EnhancedEmotion: Codable {
    let id: UUID
    let timestamp: Date
    let primaryEmotion: String
    let intensity: Float // 0.0-1.0
    let cognitiveState: CognitiveState
    let physicalState: PhysicalState
    let environmentalContext: EnvironmentalContext
    let socialContext: SocialContext
    
    init(
        primaryEmotion: String,
        intensity: Float,
        cognitiveState: CognitiveState = CognitiveState(),
        physicalState: PhysicalState = PhysicalState(),
        environmentalContext: EnvironmentalContext = EnvironmentalContext(),
        socialContext: SocialContext = SocialContext()
    ) {
        self.id = UUID()
        self.timestamp = Date()
        self.primaryEmotion = primaryEmotion
        self.intensity = max(0.0, min(1.0, intensity))
        self.cognitiveState = cognitiveState
        self.physicalState = physicalState
        self.environmentalContext = environmentalContext
        self.socialContext = socialContext
    }
    
    struct CognitiveState: Codable {
        let focus: Float // 0.0-1.0
        let energy: Float // 0.0-1.0
        let motivation: Float // 0.0-1.0
        let clarity: Float // 0.0-1.0
        
        init(focus: Float = 0.5, energy: Float = 0.5, motivation: Float = 0.5, clarity: Float = 0.5) {
            self.focus = max(0.0, min(1.0, focus))
            self.energy = max(0.0, min(1.0, energy))
            self.motivation = max(0.0, min(1.0, motivation))
            self.clarity = max(0.0, min(1.0, clarity))
        }
    }
    
    struct PhysicalState: Codable {
        let tension: Float // 0.0-1.0
        let fatigue: Float // 0.0-1.0
        let restlessness: Float // 0.0-1.0
        
        init(tension: Float = 0.5, fatigue: Float = 0.5, restlessness: Float = 0.5) {
            self.tension = max(0.0, min(1.0, tension))
            self.fatigue = max(0.0, min(1.0, fatigue))
            self.restlessness = max(0.0, min(1.0, restlessness))
        }
    }
    
    struct EnvironmentalContext: Codable {
        let location: String // "home", "office", "public", "nature"
        let noiseLevel: Float // 0.0-1.0
        let lighting: String // "bright", "dim", "natural", "artificial"
        let temperature: String // "cold", "cool", "comfortable", "warm", "hot"
        
        init(
            location: String = "unknown",
            noiseLevel: Float = 0.5,
            lighting: String = "natural",
            temperature: String = "comfortable"
        ) {
            self.location = location
            self.noiseLevel = max(0.0, min(1.0, noiseLevel))
            self.lighting = lighting
            self.temperature = temperature
        }
    }
    
    struct SocialContext: Codable {
        let alone: Bool
        let socialPressure: Float // 0.0-1.0
        let supportLevel: Float // 0.0-1.0
        
        init(alone: Bool = true, socialPressure: Float = 0.0, supportLevel: Float = 0.5) {
            self.alone = alone
            self.socialPressure = max(0.0, min(1.0, socialPressure))
            self.supportLevel = max(0.0, min(1.0, supportLevel))
        }
    }
    
    /// 전체적인 웰빙 점수 계산
    var wellbeingScore: Float {
        let positiveEmotions = ["😊", "😄", "🥰", "😌", "🙂", "😍", "🤗", "😇"]
        let baseScore = positiveEmotions.contains(primaryEmotion) ? intensity : (1.0 - intensity)
        let cognitiveBonus = (cognitiveState.focus + cognitiveState.energy + cognitiveState.motivation + cognitiveState.clarity) / 4.0 * 0.3
        return min(1.0, baseScore + cognitiveBonus)
    }
}

// MARK: - Master Recommendation 모델
struct MasterRecommendation: Codable {
    let id: UUID
    let recommendedVolumes: [Float]
    let recommendedVersions: [Int]
    let confidenceScore: Float
    let reasoning: String
    let estimatedDuration: Int
    let adaptationLevel: String
    let createdAt: Date
    
    init(recommendedVolumes: [Float], recommendedVersions: [Int], confidenceScore: Float, reasoning: String, estimatedDuration: Int, adaptationLevel: String) {
        self.id = UUID()
        self.recommendedVolumes = recommendedVolumes
        self.recommendedVersions = recommendedVersions
        self.confidenceScore = confidenceScore
        self.reasoning = reasoning
        self.estimatedDuration = estimatedDuration
        self.adaptationLevel = adaptationLevel
        self.createdAt = Date()
    }
}

