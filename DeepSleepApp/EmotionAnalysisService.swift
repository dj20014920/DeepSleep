import Foundation
import Core

final class EmotionAnalysisService: EmotionAnalysisServiceProtocol {
    // MARK: - Properties
    private let llmService: LLMService
    private let soundRepository: SoundRepository
    private let emotionRepository: EmotionRepository
    
    // MARK: - Initialization
    init(llmService: LLMService = LLMRouter.shared as LLMService,
         soundRepository: SoundRepository = SoundRepositoryImpl(),
         emotionRepository: EmotionRepository = EmotionRepositoryImpl()) {
        self.llmService = llmService
        self.soundRepository = soundRepository
        self.emotionRepository = emotionRepository
    }
    
    // MARK: - EmotionAnalysisServiceProtocol
    func analyzeEmotionPattern(_ data: String) async throws -> EmotionAnalysisResult {
        let task = AITask(
            type: .emotionAnalysis,
            input: data,
            parameters: [
                "mode": "pattern_analysis",
                "format": "structured"
            ]
        )
        
        let response = try await llmService.processTask(task)
        
        // 응답 파싱
        guard let result = try? JSONDecoder().decode(EmotionAnalysisResult.self, from: response.data) else {
            throw ServiceError.analysisFailure
        }
        
        return result
    }
    
    func generateChatResponse(to message: String, history: [(isUser: Bool, message: String)]) async throws -> String {
        let formattedHistory = history.map { entry in
            "\(entry.isUser ? "User" : "Assistant"): \(entry.message)"
        }.joined(separator: "\n")
        
        let task = AITask(
            type: .chat,
            input: message,
            parameters: [
                "history": formattedHistory,
                "mode": "emotion_support"
            ]
        )
        
        let response = try await llmService.processTask(task)
        return response.text
    }
    
    func generateQuickTip(for intent: String) async throws -> String {
        let task = AITask(
            type: .quickTip,
            input: intent,
            parameters: [
                "context": "emotion_support",
                "format": "concise"
            ]
        )
        
        let response = try await llmService.processTask(task)
        return response.text
    }
    
    func getAIRecommendation() async throws -> RecommendationResult {
        // 감정 데이터 가져오기
        let recentEmotions = try await emotionRepository.getRecentEmotions(limit: 5)
        
        // AI 추천 요청
        let task = AITask(
            type: .soundRecommendation,
            input: try JSONEncoder().encode(recentEmotions),
            parameters: [
                "mode": "personalized",
                "source": "ai"
            ]
        )
        
        let response = try await llmService.processTask(task)
        
        // 응답 파싱
        guard let recommendation = try? JSONDecoder().decode(RecommendationResult.self, from: response.data) else {
            throw ServiceError.recommendationFailure
        }
        
        // 추천된 사운드 유효성 검증
        for component in recommendation.components {
            guard try await soundRepository.isAvailable(soundId: component.soundId) else {
                throw ServiceError.recommendationFailure
            }
        }
        
        return recommendation
    }
    
    func getLocalRecommendation() async throws -> RecommendationResult {
        // 현재 시간 기반 추천
        let currentHour = Calendar.current.component(.hour, from: Date())
        let timeOfDay: String
        
        switch currentHour {
        case 5...11: timeOfDay = "morning"
        case 12...17: timeOfDay = "afternoon"
        case 18...22: timeOfDay = "evening"
        default: timeOfDay = "night"
        }
        
        // 로컬 추천 가져오기
        let recommendation = try await soundRepository.getRecommendation(for: timeOfDay)
        
        // RecommendationResult로 변환
        return RecommendationResult(
            id: UUID().uuidString,
            title: recommendation.title,
            description: recommendation.description,
            components: recommendation.components
        )
    }
    
    func saveFeedback(recommendationId: String, score: Int, comment: String?) async throws {
        let feedback = RecommendationFeedback(
            recommendationId: UUID(uuidString: recommendationId) ?? UUID(),
            score: score,
            comment: comment
        )
        
        try await soundRepository.saveFeedback(feedback)
    }
}

// MARK: - Private Extensions
private extension EmotionAnalysisService {
    func validateSoundComponents(_ components: [SoundComponent]) async throws -> Bool {
        for component in components {
            guard try await soundRepository.isAvailable(soundId: component.soundId) else {
                return false
            }
        }
        return true
    }
} 