import Foundation

struct BrandingCopy {
    static let friend = "대나무숲 친구"
    static let recommendationCTA = "대나무숲 분석 추천받기"
    static func recommendationCTA(remaining: Int, total: Int) -> String { "\(recommendationCTA) (\(remaining)/\(total))" }

    static let recommendationName = "대나무숲 추천"
    static let analyzedPreset = "\(friend)가 분석한 추천 프리셋입니다."

    static let quotaExceededTitle = "오늘의 대나무숲 추천 횟수를 모두 사용했습니다"
    static let quotaResetHint = "내일이면 대나무숲 추천 횟수가 초기화되니까, 그때 다시 받아보실 수 있어요. ✨"
    static let localFallbackDueToQuota = "오늘의 대나무숲 추천 횟수를 모두 사용하여 로컬 추천을 제공합니다."

    static let analyzingNow = "🧠 \(friend)가 현재 상황을 종합적으로 분석하고 있어요..."
    static let analysisCompleteTitle = "🧠 \(friend) 종합 분석 완료"
    static let analysisHeader = "🧠 \(friend) 종합 분석 결과"
    static let analysisLabel = "\(friend) 분석"
    static let analysisReasonLabel = "\(friend) 추천 이유"

    static let subscriptionFreeLabel = "무료: 기본 대나무숲 친구 모델 + 50회/일"
    static let subscriptionProLabel = "프리미엄: 모든 대나무숲 친구 모델 + 무제한"

    static let botNamePrefix = "\(friend): "

    static func quickActionAIRecommendationTitle() -> String { "🧠 대나무숲 분석 추천" }
}
