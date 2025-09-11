import Foundation
import UIKit

/// AI 기능 유형을 정의하여 중앙에서 관리
enum AIFeatureType: String {
    case chat = "Chat"
    case presetRecommendation = "PresetRecommendation"
    case diaryAnalysis = "DiaryAnalysis"
    case monthlyStatistics = "MonthlyStatistics"  // patternAnalysis → monthlyStatistics로 변경
    case individualTodoAdvice = "IndividualTodoAdvice"
    case overallTodoAdvice = "OverallTodoAdvice"
}

class AIUsageManager {
    static let shared = AIUsageManager()
    private init() {}

    // 중앙집중형 사용량 게이트 (UsageLimitManager 직접 사용 제거)
    private let usageGate = UsageGate.shared

    // MARK: - 중앙 관리 로직

    /// 특정 기능을 오늘 더 사용할 수 있는지 확인합니다.
    func canUse(feature: AIFeatureType) -> Bool {
        switch feature {
        case .monthlyStatistics:
            let status = usageGate.canUseWeeklyFeature(
                anchor: UsageLimitManager.WeekAnchor.kstMonday, key: "monthly_statistics")
            return status.canUse
        case .chat:
            return usageGate.canUse(.generalConversation)
        case .presetRecommendation:
            return usageGate.canUse(.presetRecommendation)
        case .diaryAnalysis:
            return usageGate.canUse(.emotionDiaryAnalysis)
        case .overallTodoAdvice:
            // 티어별: AI_LIMITS_TODO_OVERALL_ADVICE_{FREE,PRO,MAX} (SSOT)
            let tier: SubscriptionTier = StoreKitSubscriptionManager.shared.currentTier
            let candidates: [String]
            switch tier {
            case .max:
                candidates = [
                    "AI_LIMITS_TODO_OVERALL_ADVICE_MAX",
                    "AI_LIMITS_TODO_OVERALL_ADVICE_PRO",
                ]
            case .pro:
                candidates = [
                    "AI_LIMITS_TODO_OVERALL_ADVICE_PRO",
                ]
            case .free:
                candidates = [
                    "AI_LIMITS_TODO_OVERALL_ADVICE_FREE",
                ]
            }
            var limit = 0
            for key in candidates {
                if let v = ConfigReader.int(key) { limit = max(0, v); break }
            }
            return usageGate.canUseDailyKeyedFeature(
                key: "todo_overall_advice", limit: limit
            ).canUse
        case .individualTodoAdvice:
            return usageGate.canUse(.taskAdvice)
        }
    }

    /// 특정 기능의 남은 사용 횟수를 반환합니다.
    func getRemainingCount(for feature: AIFeatureType) -> Int {
        switch feature {
        case .monthlyStatistics:
            // 주간 1회 제한 기준 남은 횟수
            let status = usageGate.canUseWeeklyFeature(
                anchor: UsageLimitManager.WeekAnchor.kstMonday, key: "monthly_statistics")
            return status.remaining
        case .chat:
            return usageGate.remainingCount(for: .generalConversation)
        case .presetRecommendation:
            return usageGate.remainingCount(for: .presetRecommendation)
        case .diaryAnalysis:
            return usageGate.remainingCount(for: .emotionDiaryAnalysis)
        case .overallTodoAdvice:
            let tier: SubscriptionTier = StoreKitSubscriptionManager.shared.currentTier
            let candidates: [String]
            switch tier {
            case .max:
                candidates = [
                    "AI_LIMITS_TODO_OVERALL_ADVICE_MAX",
                    "AI_LIMITS_TODO_OVERALL_ADVICE_PRO",
                ]
            case .pro:
                candidates = [
                    "AI_LIMITS_TODO_OVERALL_ADVICE_PRO",
                ]
            case .free:
                candidates = [
                    "AI_LIMITS_TODO_OVERALL_ADVICE_FREE",
                ]
            }
            var limit = 0
            for key in candidates {
                if let v = ConfigReader.int(key) { limit = max(0, v); break }
            }
            return usageGate.canUseDailyKeyedFeature(
                key: "todo_overall_advice", limit: limit
            ).remaining
        case .individualTodoAdvice:
            return usageGate.remainingCount(for: .taskAdvice)
        }
    }

    /// 특정 기능의 사용을 기록합니다.
    @discardableResult
    func recordUsage(for feature: AIFeatureType) -> Bool {
        // 사전 가드: 한도 초과 시 중복 증가 방지
        switch feature {
        case .monthlyStatistics:
            let status = usageGate.canUseWeeklyFeature(anchor: .kstMonday, key: "monthly_statistics")
            if status.canUse { usageGate.incrementWeeklyFeature(anchor: .kstMonday, key: "monthly_statistics") } else { break }
        case .chat:
            if usageGate.canUse(AIMode.generalConversation) { usageGate.incrementUsage(for: .generalConversation) } else { break }
        case .presetRecommendation:
            if usageGate.canUse(AIMode.presetRecommendation) { usageGate.incrementUsage(for: .presetRecommendation) } else { break }
        case .diaryAnalysis:
            if usageGate.canUse(AIMode.emotionDiaryAnalysis) { usageGate.incrementUsage(for: .emotionDiaryAnalysis) } else { break }
        case .overallTodoAdvice:
            let limit = getTotalLimit(for: .overallTodoAdvice)
            let status = usageGate.canUseDailyKeyedFeature(key: "todo_overall_advice", limit: limit)
            if status.canUse { usageGate.incrementDailyKeyedFeature(key: "todo_overall_advice") } else { break }
        case .individualTodoAdvice:
            if usageGate.canUse(AIMode.taskAdvice) { usageGate.incrementUsage(for: .taskAdvice) } else { break }
        }
        // 🛰️ 변경 브로드캐스트 (기존 의존성 유지)
        let total = getTotalLimit(for: feature)
        let used = (total - getRemainingCount(for: feature))
        NotificationCenter.default.post(
            name: .aiUsageUpdated, object: nil,
            userInfo: [
                "feature": feature.rawValue,
                "used": used,
                "limit": total,
            ])
        return true
    }

}

// CaseIterable 추가
extension AIFeatureType: CaseIterable {}

extension Notification.Name {
    public static let aiUsageUpdated = Notification.Name("aiUsageUpdated")
}

// MARK: - Dynamic Limits
extension AIUsageManager {
    /// 유/무료 구독 상태를 고려한 동적 일일 제한
    private func limit(for feature: AIFeatureType) -> Int {
        switch feature {
        case .monthlyStatistics:
            return 1
        case .chat:
            return usageGate.dailyLimit(for: .generalConversation)
        case .presetRecommendation:
            return usageGate.dailyLimit(for: .presetRecommendation)
        case .diaryAnalysis:
            return usageGate.dailyLimit(for: .emotionDiaryAnalysis)
        case .overallTodoAdvice:
            let tier: SubscriptionTier = StoreKitSubscriptionManager.shared.currentTier
            let candidates: [String]
            switch tier {
            case .max:
                candidates = [
                    "AI_LIMITS_TODO_OVERALL_ADVICE_MAX",
                    "AI_LIMITS_TODO_OVERALL_ADVICE_PRO",
                ]
            case .pro:
                candidates = [
                    "AI_LIMITS_TODO_OVERALL_ADVICE_PRO",
                ]
            case .free:
                candidates = [
                    "AI_LIMITS_TODO_OVERALL_ADVICE_FREE",
                ]
            }
            for key in candidates {
                if let v = ConfigReader.int(key) { return max(0, v) }
            }
            return 0
        case .individualTodoAdvice:
            return usageGate.dailyLimit(for: .taskAdvice)
        }
    }

    /// 총 일일 제한 조회(표시용)
    func getTotalLimit(for feature: AIFeatureType) -> Int {
        return limit(for: feature)
    }
}
