import Foundation

/// 사운드 프리셋 구조체
public struct SoundPreset: Codable, Equatable {
    public let presetName: String
    public let volumes: [Float] // 각 사운드 채널별 볼륨
    public let versions: [Int]  // 각 사운드 채널별 버전
    public let analysis: String?
    public let recommendationReason: String?
    public let confidence: Float?
    public let expectedMoodImprovement: String?
}

/// 감정+사용 이력 기반 사운드 추천 엔진
@available(iOS 17.0, *)
public final class ComprehensiveRecommendationEngine {
    /// 감정 라벨에 따라 사운드 프리셋을 추천합니다.
    /// - Parameter emotion: 감정 라벨(String)
    /// - Returns: 추천된 SoundPreset
    /// - Throws: 추천 실패 시 오류
    public func recommend(forEmotion emotion: String) async throws -> SoundPreset {
        // 실제 구현: 감정+사용 이력+LLMOutput 기반 추천
        // 현재는 감정별 rule 기반 placeholder
        switch emotion.lowercased() {
        case "happy":
            return SoundPreset(
                presetName: "행복 에너지 부스트",
                volumes: [0.7, 0.5, 0.6, 0.4, 0.3, 0.2, 0.1, 0.1, 0.5, 0.3, 0.2, 0.1, 0.1],
                versions: Array(repeating: 1, count: 13),
                analysis: "긍정적 감정에 최적화된 사운드 믹스",
                recommendationReason: "활력과 긍정 에너지를 증진",
                confidence: 0.9,
                expectedMoodImprovement: "기분 상승 및 스트레스 완화"
            )
        case "sad":
            return SoundPreset(
                presetName: "마음 안정 휴식",
                volumes: [0.3, 0.4, 0.5, 0.5, 0.2, 0.1, 0.1, 0.1, 0.4, 0.2, 0.2, 0.1, 0.1],
                versions: Array(repeating: 1, count: 13),
                analysis: "우울/슬픔 완화에 적합한 사운드",
                recommendationReason: "심신 안정 및 위로 제공",
                confidence: 0.85,
                expectedMoodImprovement: "감정 안정 및 위로"
            )
        case "anxious":
            return SoundPreset(
                presetName: "불안 완화 집중",
                volumes: [0.2, 0.3, 0.4, 0.6, 0.3, 0.2, 0.1, 0.1, 0.3, 0.2, 0.2, 0.1, 0.1],
                versions: Array(repeating: 1, count: 13),
                analysis: "불안/걱정 완화에 최적화",
                recommendationReason: "집중력 향상 및 긴장 완화",
                confidence: 0.8,
                expectedMoodImprovement: "불안 감소 및 집중력 향상"
            )
        case "angry":
            return SoundPreset(
                presetName: "분노 진정",
                volumes: [0.2, 0.2, 0.3, 0.5, 0.4, 0.2, 0.1, 0.1, 0.2, 0.2, 0.2, 0.1, 0.1],
                versions: Array(repeating: 1, count: 13),
                analysis: "분노/짜증 완화에 적합",
                recommendationReason: "진정 및 감정 조절 도움",
                confidence: 0.75,
                expectedMoodImprovement: "분노 완화 및 평정 유지"
            )
        default:
            return SoundPreset(
                presetName: "기본 휴식 프리셋",
                volumes: Array(repeating: 0.3, count: 13),
                versions: Array(repeating: 1, count: 13),
                analysis: "기본/중립 감정용 사운드",
                recommendationReason: "편안한 휴식 제공",
                confidence: 0.7,
                expectedMoodImprovement: "기본 감정 안정화"
            )
        }
    }
} 