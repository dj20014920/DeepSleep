import Foundation
import Combine

// MARK: - 🚀 통합 AI 서비스 프로토콜
/// 모든 AI 서비스를 통합하는 단일 인터페이스
/// 세계 최고 수준의 아키텍처로 설계되었으며, 확장성과 유지보수성을 고려
public protocol UnifiedAIService {
    /// 통합된 메시지 전송 함수
    /// - Parameters:
    ///   - content: 전송할 메시지 내용
    ///   - model: 사용할 AI 모델
    ///   - mode: AI 사용 모드 (감정 분석, 조언, 대화 등)
    ///   - context: 추가 컨텍스트 정보
    ///   - tokenConfig: 토큰 설정 (옵션)
    /// - Returns: AI 응답
    func sendMessage(
        content: String,
        model: AIModel,
        mode: AIMode,
        context: AIContext?,
        tokenConfig: TokenConfiguration?,
        assembledPrompt: String?
) async throws -> AIResponse
    
    /// 스트리밍 응답을 위한 메시지 전송
    func sendMessageStream(
        content: String,
        model: AIModel,
        mode: AIMode,
        context: AIContext?,
        tokenConfig: TokenConfiguration?,
        assembledPrompt: String?
    ) -> AsyncThrowingStream<AIStreamResponse, Error>
    
    /// 모델별 사용량 확인
    func getUsageStatistics(for model: AIModel) async -> AIUsageStatistics
    
    /// 모델 상태 확인
    func checkModelStatus(for model: AIModel) async -> AIModelStatus
}

// 모든 타입은 AIServiceTypes.swift에 정의되어 있음
// 중복 정의 제거로 타입 충돌 해결