import Foundation
import Core

final class EmotionAnalysisService: EmotionAnalysisServiceProtocol {
    func analyzeEmotion(text: String) async throws -> EmotionAnalysisModels.EmotionAnalysisResponse {
        // 간단한 스텁 구현
        let emotions = ["기쁨", "슬픔", "평온", "흥미", "걱정", "스트레스"]
        let randomEmotion = emotions.randomElement() ?? "평온"
        let intensity = Float.random(in: 0.3...0.9)
        
        return EmotionAnalysisModels.EmotionAnalysisResponse(
            primaryEmotion: randomEmotion,
            intensity: intensity,
            secondaryEmotions: emotions.filter { $0 != randomEmotion }.prefix(2).map { $0 },
            suggestion: "\(randomEmotion) 감정을 더 잘 이해해보세요."
        )
    }
    
    func analyzeEmotionPattern(_ data: String) async throws -> EmotionAnalysisResult {
        return EmotionAnalysisResult(
            summary: "감정 패턴 분석 결과",
            recommendations: ["추천 1", "추천 2"],
            followUpQuestions: ["질문 1", "질문 2"]
        )
    }
    
    func generateChatResponse(to message: String, history: [(isUser: Bool, message: String)]) async throws -> String {
        return "AI 응답: \(message)에 대한 답변입니다."
    }
    
    func generateQuickTip(for intent: String) async throws -> String {
        return "팁: \(intent)에 대한 조언입니다."
    }
    
    func getAIRecommendation() async throws -> RecommendationResult {
        return RecommendationResult(
            id: UUID().uuidString,
            title: "AI 추천",
            description: "AI가 추천하는 사운드입니다.",
            components: []
        )
    }
    
    func getLocalRecommendation() async throws -> RecommendationResult {
        return RecommendationResult(
            id: UUID().uuidString,
            title: "로컬 추천",
            description: "로컬 기반 추천 사운드입니다.",
            components: []
        )
    }
    
    func saveFeedback(recommendationId: String, score: Int, comment: String?) async throws {
        // 스텁 구현
        print("피드백 저장: \(recommendationId), 점수: \(score)")
    }
    
    // MARK: - Message Loading
    func loadMessages(page: Int, pageSize: Int) async throws -> [(isUser: Bool, content: String)] {
        do {
            // 메시지 저장소에서 메시지 로드
            let messages = try await MessageStore.shared.loadMessages(page: page, pageSize: pageSize)
            return messages.map { (isUser: $0.isUser, content: $0.content) }
        } catch {
            throw EmotionAnalysisServiceError.databaseError
        }
    }
}