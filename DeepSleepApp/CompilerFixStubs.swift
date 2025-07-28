// MARK: - CompilerFixStubs.swift
// iOS DeepSleep 앱 - 컴파일 오류 해결을 위한 임시 스텁 모음
// 주의: 프로덕션 코드에서는 실제 구현으로 대체 필요

import Foundation
import UIKit
import SwiftUI
import SwiftData

// MARK: - Settings Model

struct UserSettings: Codable {
    var dailyEmotionLimit: Int = 5
    var enableAIRecommendations: Bool = true
    var preferredLLMService: String = "claude"
    var maxTokensPerRequest: Int = 1000
    var temperatureSetting: Float = 0.7
    var dailyPresetLimit: Int = 10
    var enableNotifications: Bool = true
    var selectedTheme: String = "auto"
    var soundQuality: String = "high"
    var autoSave: Bool = true
    
    init() {}
}

// UsageStats는 Models/Analytics/UsageStats.swift에서 정의됨

// MARK: - Core Data Types
// ChatContext, UserInfo, SoundRecommendationContext는 SharedModels.swift로 이동되었으므로 여기서 삭제합니다.

public struct FeedbackContext: Codable, Hashable {
    public let timeOfDay: String
    public let duration: TimeInterval
    public let batteryLevel: Float?
    public let isHeadphonesConnected: Bool
    
    public init(timeOfDay: String = "오후", duration: TimeInterval = 0, batteryLevel: Float? = nil, isHeadphonesConnected: Bool = false) {
        self.timeOfDay = timeOfDay
        self.duration = duration
        self.batteryLevel = batteryLevel
        self.isHeadphonesConnected = isHeadphonesConnected
    }
}

struct SessionFeedback {
    let sessionId: String
    let rating: Int
    let feedback: String?
    let timestamp: Date
    let context: String?
    
    init(sessionId: String, rating: Int, feedback: String? = nil, context: String? = nil) {
        self.sessionId = sessionId
        self.rating = rating
        self.feedback = feedback
        self.timestamp = Date()
        self.context = context
    }
}

// MARK: - Stubs for Analysis & AI

struct UserProfileVector {
    public var soundPreferences: [Float]  // 각 사운드 카테고리별 선호도 (0.0-1.0)
    public var timePreferences: [Float]   // 시간대별 사용 패턴 (24시간)
    public var averageSatisfaction: Float // 평균 만족도 (0.0-1.0)
    public var emotionPreferences: [String: Float] // 감정별 선호도
    public var usagePatterns: [String: Float] // 사용 패턴 데이터
    
    public init() {
        // 기본값으로 초기화
        self.soundPreferences = Array(repeating: 0.5, count: SoundPresetCatalog.categoryNames.count)
        self.timePreferences = Array(repeating: 0.1, count: 24)
        self.averageSatisfaction = 0.5
        self.emotionPreferences = [:]
        self.usagePatterns = [:]
    }
    
    public init(feedbackData: [PresetFeedback]) {
        // 먼저 지정된 초기화 메서드를 호출하여 self를 완전히 초기화합니다.
        self.init()

        if feedbackData.isEmpty {
            return
        }
        
        // 사운드 선호도 분석
        // var soundScores = Array(repeating: 0.0, count: SoundPresetCatalog.categoryNames.count)
        // var soundCounts = Array(repeating: 0, count: SoundPresetCatalog.categoryNames.count)
        
        // 시간 선호도 분석
        var timeScores = Array(repeating: 0.0, count: 24)
        var timeCounts = Array(repeating: 0, count: 24)
        
        // 감정별 선호도 분석
        var emotionScores: [String: Float] = [:]
        var emotionCounts: [String: Int] = [:]
        
        var totalSatisfaction: Float = 0.0
        var satisfactionCount = 0
        
        for feedback in feedbackData {
            let satisfaction = feedback.satisfactionScore
            totalSatisfaction += satisfaction
            satisfactionCount += 1
            
            // 시간 분석
            if let contextTime = feedback.contextTime, contextTime >= 0 && contextTime < 24 {
                timeScores[contextTime] += Double(satisfaction)
                timeCounts[contextTime] += 1
            }
            
            // 감정 분석
            if let emotion = feedback.contextEmotion {
                emotionScores[emotion, default: 0.0] += satisfaction
                emotionCounts[emotion, default: 0] += 1
            }
        }
        
        // 로컬 변수에 계산 결과 저장
        let calculatedAvgSatisfaction = satisfactionCount > 0 ? totalSatisfaction / Float(satisfactionCount) : 0.5
        
        let calculatedTimePreferences = timeScores.enumerated().map { index, score in
            return timeCounts[index] > 0 ? Float(score / Double(timeCounts[index])) : 0.1
        }
        
        let calculatedSoundPreferences = Array(repeating: calculatedAvgSatisfaction, count: SoundPresetCatalog.categoryNames.count)
        
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

        // 기본값으로 초기화된 프로퍼티들을 계산된 값으로 덮어씁니다.
        self.averageSatisfaction = calculatedAvgSatisfaction
        self.timePreferences = calculatedTimePreferences
        self.soundPreferences = calculatedSoundPreferences
        self.emotionPreferences = normalizedEmotionPreferences
        self.usagePatterns = calculatedUsagePatterns
    }
    
    public func toFeatureVector() -> [Float] {
        return soundPreferences + timePreferences + [averageSatisfaction] + Array(emotionPreferences.values) + Array(usagePatterns.values)
    }
}

struct HarmonyWeights {}

// MARK: - Models Namespace & Types

enum Models {}

// Note: PresetFeedback is defined in Models.swift

// EmotionType은 Core/Domain/Entities/EmotionEntity.swift에서 통합 관리됩니다.
// 이 파일에서는 EmotionType을 import하여 사용하세요.

// Note: EnhancedEmotion is defined in Models.swift

struct EnhancedRecommendationResponse {
    let presetName: String
    let volumes: [Float]
    let versions: [Int]
    let reason: String
}

// MARK: - UI Protocol & Missing Types
// Note: TodoListCellDelegate is now implemented in DeepSleepApp/UI/TodoListCell.swift

// Note: InsightCell and TodoListCell are now implemented in separate files:
// - DeepSleepApp/UI/InsightCell.swift
// - DeepSleepApp/UI/TodoListCell.swift

class SectionHeaderView: UICollectionReusableView {
    static let reuseIdentifier = "SectionHeaderView"
    let titleLabel = UILabel()
    let addButton = UIButton()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }
    
    private func setupViews() {
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        titleLabel.textColor = .label
        
        addButton.translatesAutoresizingMaskIntoConstraints = false
        addButton.setTitle("+", for: .normal)
        addButton.setTitleColor(.systemBlue, for: .normal)
        addButton.titleLabel?.font = .systemFont(ofSize: 18, weight: .medium)
        
        addSubview(titleLabel)
        addSubview(addButton)
        
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            
            addButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            addButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            addButton.widthAnchor.constraint(equalToConstant: 30),
            addButton.heightAnchor.constraint(equalToConstant: 30)
        ])
    }
}

// Note: CHHapticPattern and haptic feedback system are now implemented in DeepSleepApp/System/HapticManager.swift

// EnhancedSoundRecommendationEngine compatibility types
// typealias RecommendationContext = String  // ⚠️ DEPRECATED: SuperRecommendationEngine에서 통합 관리

// Note: isHeadphonesConnected is now implemented in DeepSleepApp/System/SystemDetectionManager.swift

func buildComprehensivePrompt() async -> String {
    return "종합적인 프롬프트를 생성하는 기능입니다."
}

func buildDiaryBasedPrompt() async -> String {
    return "일기 기반 프롬프트를 생성하는 기능입니다."
}

struct UserAnalysisResult {
    init(_ args: Any...) {}
    
    init(riskFactorSummary: String, overallInsight: String) {
        self.init()
    }
}

// MARK: - AI Teaching

class AITeachingViewController: UIViewController {
    weak var delegate: AnyObject?
    
    init(originalMessage: String) {
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
}

// MARK: - Services

final class PresetManager {
    static let shared = PresetManager()
    private init() {}
    
    func migrateLegacyPresetsIfNeeded() {
        LegacyPresetManager.shared.migrateLegacyPresetsIfNeeded()
    }
    
    func getPreset(id: String) -> SoundPreset? {
        // TODO: 실제 구현 필요
        return SoundPreset.createDefault()
    }
}

// Note: LegacyPresetManager is defined in LegacyPresetManager.swift

// MARK: - ChatManager는 실제 구현 사용
// Note: 실제 구현은 ChatManager.swift에 있으므로 스텁 제거됨

// Note: FeedbackManager is defined in FeedbackManager.swift

class LLMServiceFactory {
    static let shared = LLMServiceFactory()
    func getService(for type: Any) throws -> LLMService { return LLMService() }
}

class LLMService {
    func sendMessage(_ prompt: String, config: Any?) async throws -> (String, Any) {
        return ("AI 추천 작업 예시", [:])
    }
}

// LLMRequestConfig is now defined in Sources/Core/Domain/Entities/LLMEntity.swift

class ReplicateChatService {
    static let shared = ReplicateChatService()
    
    func sendPrompt(message: String, a: String, completion: @escaping (String?) -> Void) {
        completion(nil)
    }
    
    enum ServiceError: Error {
        case unknown
    }
}

class EnhancedAIRecommendationService {
    static let shared = EnhancedAIRecommendationService()
    
    func performAdvancedRecommendation(userMessage: String, completion: @escaping (Result<String, Error>) -> Void) {
        completion(.success("AI 추천 결과입니다."))
    }
}

// ✅ ComprehensiveRecommendationEngine 삭제됨 - EnhancedSoundRecommendationEngine 사용

// MARK: - ProcessingMetadata (Codable support in SoundPresetCatalog.swift)

extension ProcessingMetadata: Equatable {
    public static func == (lhs: ProcessingMetadata, rhs: ProcessingMetadata) -> Bool {
        return lhs.modelVersion == rhs.modelVersion &&
               lhs.processingTime == rhs.processingTime &&
               lhs.featureCount == rhs.featureCount &&
               lhs.networkDepth == rhs.networkDepth
    }
}

// MARK: - Model Extensions

// ✅ ComprehensiveRecommendation extensions 삭제됨 - EnhancedSoundRecommendationEngine 사용

extension DiaryContext {
    init(from diary: EmotionDiary) {
        self.content = diary.userMessage  // ✅ 수정: Optional 처리 제거
        self.emotion = diary.selectedEmotion
    }
}

// Note: PresetFeedback init extension removed - now defined in Models.swift

// Note: presetId already defined in Models.PresetFeedback

// LLMRequestConfig extensions removed - use the one from LLMEntity.swift

// ✅ LLMRouter ComprehensiveRecommendation 관련 메서드 삭제됨 - EnhancedSoundRecommendationEngine 사용

extension SoundPresetCatalog {
    static let shared = SoundPresetCatalog()
    
    var presets: [SoundPreset] {
        return [
            SoundPreset(
                name: "평온한 휴식",
                volumes: Array(repeating: 50.0, count: max(1, SoundPresetCatalog.categoryCount)),
                emotion: "평온",
                isAIGenerated: false,
                description: "평온한 밤을 위한 사운드"
            )
        ]
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

extension ViewController {
    func updateTitle(_ title: String) {
        DispatchQueue.main.async {
            self.title = title
        }
    }
    
    func updateUIState(isLoading: Bool) {
        // TODO: 실제 UI 상태 업데이트 로직
    }
    
    func applyUpdatedModel() {
        // TODO: 모델 업데이트 적용 로직
    }
    
    // Note: showToast is now implemented in DeepSleepApp/UI/ToastManager.swift
    
    var aiOrchestrator: Any? {
        return nil
    }
}

@available(iOS 17.0, *)
extension PersonaMemoryManager {
    convenience init(modelContainer: ModelContainer) {
        // SwiftData.ModelContainer를 커스텀 ModelContext로 변환
        let customModelContext = ModelContext(
            messages: [],
            systemPrompt: "DeepSleep AI Assistant",
            conversationSummary: "",
            tokenCount: 0,
            metadata: [:]
        )
        // ✅ ChatManager 기반으로 변경됨 - 파라미터 없는 초기화
        self.init()
    }
}

@available(iOS 17.0, *)
extension PersonaMemoryManager {
    static func createLegacyInstance() -> PersonaMemoryManager {
        // 임시로 기본 초기화 사용 (ModelContainer 의존성 제거)
        do {
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            // UserPersona 및 기타 관련 모델을 사용합니다.
            let _ = try ModelContainer(for: UserPersona.self, ConversationMemory.self, PreferenceMemory.self, ContextualMemory.self, configurations: config)
            let _ = ModelContext(
                messages: [],
                systemPrompt: "DeepSleep AI Assistant",
                conversationSummary: "",
                tokenCount: 0,
                metadata: [:]
            )
            // ✅ ChatManager 기반으로 변경됨 - 파라미터 없는 초기화
            return PersonaMemoryManager()
        } catch {
            fatalError("Failed to create in-memory model container for legacy instance: \(error)")
        }
    }
}

// MARK: - String Extensions

extension String: @retroactive Error {}

extension String {
    var volumes: [Float] { return [] }
    var compatibleVersions: [String] { return [] }
    
    func ranges(of searchString: String, options: NSString.CompareOptions = [], range: NSRange? = nil) -> [NSRange] {
        let string = self as NSString
        var ranges: [NSRange] = []
        var searchRange = range ?? NSRange(location: 0, length: string.length)
        
        while searchRange.location < string.length {
            let foundRange = string.range(of: searchString, options: options, range: searchRange)
            if foundRange.location != NSNotFound {
                ranges.append(foundRange)
                searchRange.location = foundRange.location + foundRange.length
                searchRange.length = string.length - searchRange.location
            } else {
                break
            }
        }
        
        return ranges
    }
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

// MARK: - ChatViewController Extensions removed to avoid conflicts
// Methods are now implemented directly in ChatViewController

// MARK: - Utility Functions

func getCurrentTimeOfDay() -> String {
    let hour = Calendar.current.component(.hour, from: Date())
    switch hour {
    case 6..<12: return "morning"
    case 12..<18: return "afternoon"
    case 18..<22: return "evening"
    default: return "night"
    }
}

func getRecentPresets() -> [SoundPreset] {
    return []
}

func generatePoeticPresetName(for emotion: String) -> String {
    switch emotion.lowercased() {
    case "행복", "기쁨": return "햇살 가득한 오후"
    case "슬픔", "우울": return "빗소리와 함께하는 위로"
    case "평온", "휴식": return "바람결 같은 고요"
    default: return "마음을 다독이는 선율"
    }
}

func generateLocalRecommendationDescription(for emotion: String) -> String {
    return "\(emotion) 상태에 맞는 사운드를 추천드립니다."
}

func buildCurrentEmotionContext() -> String {
    // ⚠️ 토큰 절약: 최소한의 감정 컨텍스트만 제공
    return "현재: 평온"
}

func buildClaudeAnalysisPrompt(context: String) -> String {
    // ⚠️ 토큰 절약: 간단한 프롬프트만 제공
    return "수면 사운드 추천: \(context.prefix(100))"
}

@available(iOS 15.0, *)
func isAvailableForModernAI() -> Bool {
    if #available(iOS 17.0, *) {
        return true
    }
    return false
}

// MARK: - Preset Recommendation Response (ChatViewController에서 사용)
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

