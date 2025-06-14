import Foundation

/// 감정 라벨(enum)
public enum EmotionType: String, Codable, CaseIterable {
    case happy, sad, anxious, angry, neutral, unknown
}

/// 텍스트 감정 분석기 (플러그형, 향후 ML/Vision 확장 가능)
@available(iOS 17.0, *)
public final class SentimentAnalyzer {
    /// 입력 텍스트에서 감정 라벨을 추론합니다.
    /// - Parameter text: 분석할 자연어 텍스트
    /// - Returns: 추론된 EmotionType
    /// - Throws: 분석 실패 시 오류
    public func analyze(text: String) async throws -> EmotionType {
        let lowered = text.lowercased()
        if lowered.contains("기쁨") || lowered.contains("행복") || lowered.contains(":)") {
            return .happy
        } else if lowered.contains("슬픔") || lowered.contains("우울") {
            return .sad
        } else if lowered.contains("불안") || lowered.contains("걱정") {
            return .anxious
        } else if lowered.contains("화남") || lowered.contains("분노") {
            return .angry
        } else if lowered.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .unknown
        } else {
            return .neutral
        }
    }
} 