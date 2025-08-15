import Foundation
import UIKit

// MARK: - EmotionAnalysisModels Namespace
public enum EmotionAnalysisModels {
    // MARK: - Analysis Response Models
    public struct EmotionAnalysisResponse: Codable {
    public let primaryEmotion: String
    public let intensity: Float
    public let secondaryEmotions: [String]
    public let suggestion: String?
    public let timestamp: Date
    
    public init(primaryEmotion: String, intensity: Float, secondaryEmotions: [String] = [], suggestion: String? = nil, timestamp: Date = Date()) {
        self.primaryEmotion = primaryEmotion
        self.intensity = intensity
        self.secondaryEmotions = secondaryEmotions
        self.suggestion = suggestion
        self.timestamp = timestamp
    }
}

// MARK: - Chat Models (removed duplicates - use SharedModels.swift instead)

// MARK: - Analysis Models
struct EmotionPattern: Codable {
    let entries: [EmotionEntry]
    let startDate: Date
    let endDate: Date
    
    var summary: String {
        // 감정 패턴 요약 생성 로직
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        
        return """
        분석 기간: \(formatter.string(from: startDate)) - \(formatter.string(from: endDate))
        기록된 감정: \(entries.count)개
        주요 감정: \(dominantEmotions.joined(separator: ", "))
        """
    }
    
    private var dominantEmotions: [String] {
        let emotionCounts = Dictionary(grouping: entries, by: { $0.emotion })
            .mapValues { $0.count }
        
        return emotionCounts
            .sorted { $0.value > $1.value }
            .prefix(3)
            .map { $0.key }
    }
}

struct EmotionEntry: Codable {
    let date: Date
    let emotion: String
    let intensity: Int
    let note: String?
}

// MARK: - Recommendation Models
struct SoundRecommendation: Codable {
    let id: UUID
    let title: String
    let description: String
    let components: [SoundComponent]
    let createdAt: Date
    let source: RecommendationSource
    
    enum RecommendationSource: String, Codable {
        case ai
        case local
    }
}

struct SoundComponent: Codable {
    let soundId: String
    let version: Int
    let volume: Float
    
    enum CodingKeys: String, CodingKey {
        case soundId
        case version
        case volume
    }
}

// MARK: - Feedback Models
struct RecommendationFeedback: Codable {
    let id: UUID
    let recommendationId: UUID
    let score: Int
    let comment: String?
    let timestamp: Date
    
    init(id: UUID = UUID(),
         recommendationId: UUID,
         score: Int,
         comment: String? = nil,
         timestamp: Date = Date()) {
        self.id = id
        self.recommendationId = recommendationId
        self.score = score
        self.comment = comment
        self.timestamp = timestamp
    }
}

// MARK: - View State Models
enum EmotionAnalysisViewState {
    case loading
    case analyzing
    case ready
    case error(Error)
}

// MARK: - Configuration Models
struct EmotionAnalysisConfig {
    let maxHistoryItems: Int
    let maxMessageLength: Int
    let aiTemperature: Double
    let maxTokens: Int
    
    static let `default` = EmotionAnalysisConfig(
        maxHistoryItems: AppConfig.Pagination.recentMessagesLimit,
        maxMessageLength: AppConfig.Security.maxPromptLength,
        aiTemperature: AppConfig.AITokens.generalConversationTemperature,
        maxTokens: AppConfig.AITokens.generalConversationMaxTokens
    )
}

// MARK: - Error Types
    enum EmotionAnalysisError: LocalizedError {
        case invalidData
        case analysisFailure
        case networkError(Error)
        case aiUnavailable
        case recommendationFailure
        case feedbackSubmissionFailed
        
        var errorDescription: String? {
            switch self {
            case .invalidData:
                return "데이터가 올바르지 않습니다."
            case .analysisFailure:
                return "감정 분석을 수행할 수 없습니다."
            case .networkError(let error):
                return "네트워크 오류: \(error.localizedDescription)"
            case .aiUnavailable:
                return "AI 서비스를 사용할 수 없습니다."
            case .recommendationFailure:
                return "추천을 생성할 수 없습니다."
            case .feedbackSubmissionFailed:
                return "피드백을 제출할 수 없습니다."
            }
        }
    }
}