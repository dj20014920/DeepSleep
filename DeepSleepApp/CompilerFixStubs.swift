// MARK: - CompilerFixStubs.swift
// iOS DeepSleep 앱 - 컴파일 오류 해결을 위한 임시 스텁 모음
// 주의: 프로덕션 코드에서는 실제 구현으로 대체 필요

import Foundation
import UIKit
import SwiftUI
import SwiftData
import Core

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

struct UsageStats: Codable {
    let date: String
    var chatCount: Int = 0
    var presetRecommendationCount: Int = 0
    var timerUsageCount: Int = 0
    var totalSessionTime: TimeInterval = 0
    var patternAnalysisCount: Int = 0
    
    init(date: String) {
        self.date = date
    }
    
    init() {
        self.date = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none)
    }
}

// MARK: - Core Data Types
// ChatContext와 UserInfo는 Core/Common/SharedModels.swift로 이동되었으므로 여기서 삭제합니다.

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

enum EmotionType: String, CaseIterable {
    case happy = "😊"
    case sad = "😢"
    case angry = "😠"
    case neutral = "😐"
}

// Note: EnhancedEmotion is defined in Models.swift

struct EnhancedRecommendationResponse {
    let presetName: String
    let volumes: [Float]
    let versions: [Int]
    let reason: String
}

// MARK: - UI Protocol & Missing Types

protocol TodoListCellDelegate: AnyObject {
    func todoListCellDidSelectTodoItem(_ item: TodoItem)
    func todoListCellDidToggleComplete(for item: TodoItem, isCompleted: Bool)
}

class InsightCell: UICollectionViewCell {
    static let reuseIdentifier = "InsightCell"
    func configure(with text: String) {}
}

class TodoListCell: UICollectionViewCell {
    static let reuseIdentifier = "TodoListCell"
    weak var delegate: TodoListCellDelegate?
    func configure(with items: [TodoItem]) {}
}

class SectionHeaderView: UICollectionReusableView {
    static let reuseIdentifier = "SectionHeaderView"
    let titleLabel = UILabel()
    let addButton = UIButton()
}

// System type stubs
import AVFoundation
typealias CHHapticPattern = AVFoundation.AVAsset

// EnhancedSoundRecommendationEngine compatibility types
// typealias UserProfile = String
typealias RecommendationContext = String

func isHeadphonesConnected() -> Bool {
    let route = AVAudioSession.sharedInstance().currentRoute
    for description in route.outputs {
        if description.portType == .headphones ||
           description.portType == .bluetoothA2DP ||
           description.portType == .bluetoothLE {
            return true
        }
    }
    return false
}

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

final class ChatManager {
    static let shared = ChatManager()
    var messages: [ChatMessage] = []
    func append(_ message: ChatMessage) { messages.append(message) }
    func addMessage(to sessionId: String, message: ChatMessage) {}
    func getSessions() -> [String] { return [] }
}

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

class ComprehensiveRecommendationEngine {
    static let shared = ComprehensiveRecommendationEngine()
    
    func generateRecommendation(for emotion: String, timeOfDay: String, intensity: Double) -> String {
        return "추천 결과 예시"
    }
    
    func generatePrimaryRecommendation() -> ComprehensiveRecommendation {
        let dummyResult = ComprehensiveRecommendation.RecommendationResult(
            soundId: "AI Placeholder",
            reasoning: "임시 추천 결과",
                confidence: 0.5,
            personalizedExplanation: "실제 설명 구현 필요"
        )
        return ComprehensiveRecommendation(
            primaryRecommendation: dummyResult,
            alternatives: []
        )
    }
    
    func triggerModelUpdate() async -> Bool {
        return false
    }
    
    func applyUpdatedModel() {
        // 임시로 아무 동작 없음
    }
}

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

extension ComprehensiveRecommendation.RecommendationResult {
    init(soundId: String, reasoning: String, confidence: Double, personalizedExplanation: String) {
        self.init(soundId: soundId, reasoning: reasoning, confidence: confidence, personalizedExplanation: personalizedExplanation, details: nil)
    }
}

extension ComprehensiveRecommendation {
    init(primaryRecommendation: ComprehensiveRecommendation.RecommendationResult,
         alternatives: [ComprehensiveRecommendation.RecommendationResult]) {
        self.init(primaryRecommendation: primaryRecommendation,
                  alternativeRecommendations: alternatives,
                  overallConfidence: 0.0,
                  learningRecommendations: [],
                  processingMetadata: ProcessingMetadata(),
                  adaptationLevel: "basic",
                  comprehensivenessScore: 0.0,
                  contextualInsights: [])
    }
}

extension DiaryContext {
    init(from diary: EmotionDiary) {
        self.content = diary.userMessage ?? ""
        self.emotion = diary.selectedEmotion
    }
}

// Note: PresetFeedback init extension removed - now defined in Models.swift

// Note: presetId already defined in Models.PresetFeedback

// LLMRequestConfig extensions removed - use the one from LLMEntity.swift

extension LLMRouter {
    func generatePrimaryRecommendation(for userProfile: UserProfileVector, completion: @escaping (Result<ComprehensiveRecommendation, Error>) -> Void) {
        let dummyResult = ComprehensiveRecommendation.RecommendationResult(soundId: "dummy_sound", reasoning: "dummy_reason", confidence: 0.8, personalizedExplanation: "dummy_explanation")
        let dummyRecommendation = ComprehensiveRecommendation(primaryRecommendation: dummyResult, alternatives: [])
        completion(.success(dummyRecommendation))
    }
}

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

extension MainViewController {
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
    
    func showToast(message: String) {
        print("Toast: \(message)")
    }
    
    var aiOrchestrator: Any? {
        return nil
    }
}

@available(iOS 17.0, *)
extension PersonaMemoryManager {
    convenience init(modelContainer: ModelContainer) {
        // 임시로 기본 초기화 사용 (ModelContainer 의존성 제거)
        self.init(modelContext: modelContainer.mainContext)
    }
}

@available(iOS 17.0, *)
extension PersonaMemoryManager {
    static func createLegacyInstance() -> PersonaMemoryManager {
        // 임시로 기본 초기화 사용 (ModelContainer 의존성 제거)
        do {
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            // UserPersona 및 기타 관련 모델을 사용합니다.
            let container = try ModelContainer(for: UserPersona.self, ConversationMemory.self, PreferenceMemory.self, ContextualMemory.self, configurations: config)
            let context = ModelContext(container)
            return PersonaMemoryManager(modelContext: context)
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
            volumes: self.volumes,
            presetName: self.presetName,
            selectedVersions: self.versions,
            reasoning: self.reason
        )
    }
}

// MARK: - ChatViewController Extensions

extension ChatViewController {
    func removeLastLoadingMessage() {
        DispatchQueue.main.async {
            if let lastMessage = self.messages.last, lastMessage.type == .loading {
                self.messages.removeLast()
                // self.tableView.reloadData() // tableView 없음
            }
        }
    }
    
    func appendChat(_ message: ChatMessage) {
        DispatchQueue.main.async {
            self.messages.append(message)
            
            if let chatManager = self.chatManager {
                chatManager.append(message)
            }
            
            // self.tableView.reloadData() // tableView 없음
            self.scrollToBottom()
        }
    }
    
    func addMessageToChat(message: String, fromUser: Bool) {
        let messageType: ChatMessageType = fromUser ? .user : .bot
        let sender: MessageSender = fromUser ? .user : .ai
        let chatMessage = ChatMessage(
            text: message,
            date: Date(),
            sender: sender,
            type: messageType
        )
        appendChat(chatMessage)
    }
    
    func showLoading(_ show: Bool) {
        DispatchQueue.main.async {
            if show {
                let loadingMessage = ChatMessage(
                    text: "생각하고 있어요...",
                    date: Date(),
                    sender: .ai,
                    type: .loading
                )
                self.messages.append(loadingMessage)
            } else {
                if let lastMessage = self.messages.last, lastMessage.type == .loading {
                    self.messages.removeLast()
                }
            }
            // self.tableView.reloadData() // tableView 없음
            self.scrollToBottom()
        }
    }
    
    func scrollToBottom() {
        DispatchQueue.main.async {
            guard !self.messages.isEmpty else { return }
            let indexPath = IndexPath(row: self.messages.count - 1, section: 0)
            // self.tableView.scrollToRow(at: indexPath, at: .bottom, animated: true) // tableView 없음
        }
    }
    
    func didCreateNewRule(userInput: String, correctedMeaning: String) {
        print("새 규칙 생성: \(userInput) -> \(correctedMeaning)")
    }
    
    func didSaveTeaching(text: String, for persona: String) {
        print("티칭 저장: \(text) for \(persona)")
    }
    
    func debugCheckFeedbackStatus() {
        if #available(iOS 17.0, *) {
            let totalCount = FeedbackManager.shared.getTotalFeedbackCount()
            let recentCount = FeedbackManager.shared.getRecentFeedback(limit: 20).count
            let avgSatisfaction = FeedbackManager.shared.getAverageSatisfaction()
            print("Feedback - Total: \(totalCount), Recent: \(recentCount), Avg: \(avgSatisfaction)")
        } else {
            print("Feedback system requires iOS 17.0+")
        }
    }
    
    func debugCreateTestData() {
        if #available(iOS 17.0, *) {
            FeedbackManager.shared.createTestFeedbackData()
            print("Test feedback data created")
        } else {
            print("Test data creation requires iOS 17.0+")
        }
    }
    
    func debugTestLearningSystem() {
        if #available(iOS 17.0, *) {
            let feedbackCount = FeedbackManager.shared.getTotalFeedbackCount()
            print("Learning system test - Feedback count: \(feedbackCount)")
        } else {
            print("Learning system requires iOS 17.0+")
        }
    }
    
    func getEmotionData() -> [String: Any] {
        return [
            "primaryEmotion": "평온",
            "intensity": 0.5,
            "timestamp": Date().timeIntervalSince1970
        ]
    }
    
    func applyLocalPreset(_ preset: [String: Any]) {
        print("로컬 프리셋 적용: \(preset)")
    }
    
    func presentAITeachingView(with message: String) {
        print("AI 티칭 뷰 표시: \(message)")
    }
    
    func setupInputView() {
        // Stub implementation for missing setupInputView method
        print("setupInputView called - stub implementation")
    }
    
    func loadInitialMessages() {
        // Stub implementation for missing loadInitialMessages method
        print("loadInitialMessages called - stub implementation")
    }
}

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
    return "현재 사용자의 감정 상태를 분석한 컨텍스트입니다."
}

func buildClaudeAnalysisPrompt(context: String) -> String {
    return "다음 감정 상태를 분석해주세요: \(context)"
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

