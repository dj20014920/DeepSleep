import Foundation

public final class TokenOptimizer {
    public static let shared = TokenOptimizer()

    private init() {}

    // 대략적 토큰 추정: CJK 비율을 고려해 1.5 가중치 적용
    public func estimateTokens(for text: String) -> Int {
        if text.isEmpty { return 0 }
        let cjkCount = text.unicodeScalars.filter { $0.properties.isIdeographic }.count
        let cjkRatio = Double(cjkCount) / Double(text.unicodeScalars.count)
        let weight = 1.0 + (0.5 * min(1.0, cjkRatio))
        let chars = text.count
        // 대략 3-4 문자당 1 토큰으로 가정
        let base = Double(chars) / 3.5
        return Int(ceil(base * weight))
    }

    public func maxTokens(for mode: AIMode) -> Int {
        switch mode {
        case .generalConversation:
            return ConfigReader.int("AI_GENERAL_CONVERSATION_MAX_TOKENS", default: 800) ?? 800
        case .presetRecommendation:
            return ConfigReader.int("AI_PRESET_RECOMMENDATION_MAX_TOKENS", default: 300) ?? 300
        case .emotionDiaryAnalysis:
            return ConfigReader.int("AI_EMOTION_DIARY_ANALYSIS_MAX_TOKENS", default: 600) ?? 600
        case .monthlyStatistics:
            return ConfigReader.int("AI_MONTHLY_STATISTICS_MAX_TOKENS", default: 600) ?? 600
        case .taskAdvice:
            return ConfigReader.int("AI_TASK_ADVICE_MAX_TOKENS", default: 500) ?? 500
        case .fortuneTelling:
            return ConfigReader.int("AI_FORTUNE_TELLING_MAX_TOKENS", default: 400) ?? 400
        case .emotionAnalysis:
            return ConfigReader.int("AI_EMOTION_ANALYSIS_MAX_TOKENS", default: 300) ?? 300
        }
    }

    // 예산 내로 최근 메시지를 줄이는 간단한 정책(시스템>기억>최근대화 순서)
    public func fitRecentMessages(systemPrompt: String, memories: String?, recentMessages: [String], userInput: String, budget: Int) -> (included: [String], total: Int) {
        let sysT = estimateTokens(for: systemPrompt)
        let memT = estimateTokens(for: memories ?? "")
        let userT = estimateTokens(for: userInput)

        var remain = max(0, budget - sysT - memT - userT)
        var included: [String] = []

        // 최신 메시지부터 역순으로 채움
        for msg in recentMessages.reversed() {
            let t = estimateTokens(for: msg)
            if t <= remain {
                included.append(msg)
                remain -= t
            } else {
                break
            }
        }
        included.reverse()
        let total = budget - remain
        return (included, total)
    }
}
