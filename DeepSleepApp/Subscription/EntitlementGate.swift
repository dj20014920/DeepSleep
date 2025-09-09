import Foundation

/// 기능 접근 게이트의 단일 진입점(DRY)
public enum EntitlementGate {

    private static let usageGate = UsageGate.shared

    /// 기능 접근 가능 여부를 평가합니다.
    /// - Returns: (canAccess, reason) 튜플. reason은 UI/로그 표시에 사용.
    public static func canAccess(_ feature: AppFeature) -> (Bool, String) {
        // 1) 프리미엄/Trial 사용자는 전역 허용(특정 모델 상한은 별도 분기)
        if SubscriptionStatusCenter.shared.isPremium {
            // 월간 통계(주간 1회 제한)는 프리미엄도 공통 제한을 적용
            if feature == .monthlyStatistics {
                let status = usageGate.canUseWeeklyFeature(
                    anchor: UsageLimitManager.WeekAnchor.kstMonday, key: "monthly_statistics")
                if status.canUse { return (true, "premium_weekly_ok") }
                return (
                    false,
                    "weekly_limit_reached_resetAt_\(Int(status.resetAt.timeIntervalSince1970))"
                )
            }
            return (true, "premium")
        }

        // 2) 무료 사용자: 모델 정책/일일 한도/주간 한도 적용
        switch feature {
        case .chat:
            // 일일 일반 채팅 한도(무료)
            let status = usageGate.checkUsage(for: .generalConversation)
            return status.canUse ? (true, "free_daily_ok") : (false, "free_daily_limit_reached")
        case .diaryAnalysis:
            let status = usageGate.checkUsage(for: .emotionDiaryAnalysis)
            return status.canUse ? (true, "free_daily_ok") : (false, "free_daily_limit_reached")
        case .presetRecommendation:
            let status = usageGate.checkUsage(for: .presetRecommendation)
            return status.canUse ? (true, "free_daily_ok") : (false, "free_daily_limit_reached")
        case .monthlyStatistics:
            // 주간 1회 제한(무료/유료 공통 정책)
            let status = usageGate.canUseWeeklyFeature(
                anchor: UsageLimitManager.WeekAnchor.kstMonday, key: "monthly_statistics")
            return status.canUse
                ? (true, "weekly_ok")
                : (
                    false,
                    "weekly_limit_reached_resetAt_\(Int(status.resetAt.timeIntervalSince1970))"
                )
        case .todoAdvice:
            let status = usageGate.checkUsage(for: .taskAdvice)
            return status.canUse ? (true, "free_daily_ok") : (false, "free_daily_limit_reached")
        case .fortune:
            let status = usageGate.checkUsage(for: .fortuneTelling)
            return status.canUse ? (true, "free_daily_ok") : (false, "free_daily_limit_reached")
        case .patternAnalysis:
            // 별도 키가 있다면 AIMode 추가 필요. 임시로 일기 분석 한도 재사용
            let status = usageGate.checkUsage(for: .emotionDiaryAnalysis)
            return status.canUse ? (true, "free_daily_ok") : (false, "free_daily_limit_reached")
        case .claudeRequests:
            // 무료는 0회, 프리미엄은 등급별 상한. 여기서는 접근만 판단(상세 카운트는 호출부에서)
            return (false, "free_claude_disabled")
        }
    }
}
