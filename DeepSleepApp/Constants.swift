import Foundation

// MARK: - 캐시 및 대화 보존 상수
enum CacheConst {
    static let keepDays       = 14   // 캐시 보관 기간 (14일)
    static let recentDaysRaw  = 3    // "날것"으로 프롬프트에 포함하는 기간 (3일)
    static let maxPromptTokens = 4000 // 프롬프트 최대 토큰 제한
}

// MARK: - 토큰 계산 헬퍼
struct TokenEstimator {
    /// 대략적인 토큰 수 계산 (±4 char ≈ 1 token)
    static func roughCount(_ text: String) -> Int {
        return max(1, text.count / 4)
    }
} 