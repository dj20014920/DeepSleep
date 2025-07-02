import Foundation
import Core

/// 감정 분석 서비스 프로토콜
protocol EmotionAnalysisServiceProtocol {
    // MARK: - Analysis Methods
    
    /// 감정 분석 수행
    /// - Parameter text: 분석할 텍스트
    /// - Returns: 감정 분석 결과
    func analyzeEmotion(text: String) async throws -> EmotionAnalysisModels.EmotionAnalysisResponse
    
    /// 감정 패턴 분석 수행
    /// - Parameter data: 분석할 감정 데이터
    /// - Returns: 분석 결과
    func analyzeEmotionPattern(_ data: String) async throws -> EmotionAnalysisResult
    
    /// 대화형 응답 생성
    /// - Parameters:
    ///   - message: 사용자 메시지
    ///   - history: 이전 대화 내역
    /// - Returns: AI 응답
    func generateChatResponse(to message: String, history: [(isUser: Bool, message: String)]) async throws -> String
    
    /// 빠른 팁 생성
    /// - Parameter intent: 요청 의도
    /// - Returns: 팁 메시지
    func generateQuickTip(for intent: String) async throws -> String
    
    /// AI 기반 사운드 추천
    /// - Returns: 추천 결과
    func getAIRecommendation() async throws -> RecommendationResult
    
    /// 로컬 기반 사운드 추천
    /// - Returns: 추천 결과
    func getLocalRecommendation() async throws -> RecommendationResult
    
    /// 피드백 저장
    /// - Parameters:
    ///   - recommendationId: 추천 ID
    ///   - score: 만족도 점수
    ///   - comment: 선택적 코멘트
    func saveFeedback(recommendationId: String, score: Int, comment: String?) async throws
}

// MARK: - Helper Types
extension EmotionAnalysisServiceProtocol {
    /// 감정 분석 결과
    struct EmotionAnalysisResult {
        let summary: String
        let recommendations: [String]
        let followUpQuestions: [String]
    }
    
    /// 추천 결과
    struct RecommendationResult {
        let id: String
        let title: String
        let description: String
        let components: [SoundComponent]
    }
    
    /// 사운드 컴포넌트
    struct SoundComponent {
        let soundId: String
        let version: Int
        let volume: Float
    }
}

// MARK: - Error Types
extension EmotionAnalysisServiceProtocol {
    enum ServiceError: LocalizedError {
        case invalidInput
        case analysisFailure
        case recommendationFailure
        case networkError(Error)
        case aiUnavailable
        case databaseError
        
        var errorDescription: String? {
            switch self {
            case .invalidInput:
                return "입력값이 올바르지 않습니다."
            case .analysisFailure:
                return "감정 분석을 수행할 수 없습니다."
            case .recommendationFailure:
                return "추천을 생성할 수 없습니다."
            case .networkError(let error):
                return "네트워크 오류: \(error.localizedDescription)"
            case .aiUnavailable:
                return "AI 서비스를 사용할 수 없습니다."
            case .databaseError:
                return "데이터베이스 오류가 발생했습니다."
            }
        }
    }
}

// MARK: - Constants
extension EmotionAnalysisServiceProtocol {
    enum Constants {
        static let maxRetryAttempts = 3
        static let retryDelay: TimeInterval = 1.0
        static let maxTokens = 1000
        static let temperature = 0.7
    }
} 