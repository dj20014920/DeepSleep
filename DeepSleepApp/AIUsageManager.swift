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
    
    // MARK: - 중앙 관리 로직

    /// 특정 기능을 오늘 더 사용할 수 있는지 확인합니다.
    func canUse(feature: AIFeatureType) -> Bool {
        switch feature {
        case .monthlyStatistics:
            let status = UsageLimitManager.shared.canUseWeeklyLimitedFeature(anchor: .kstMonday, key: "monthly_statistics")
            return status.canUse
        case .chat:
            return UsageLimitManager.shared.canUseAIFeature(.generalConversation).canUse
        case .presetRecommendation:
            return UsageLimitManager.shared.canUseAIFeature(.presetRecommendation).canUse
        case .diaryAnalysis:
            return UsageLimitManager.shared.canUseAIFeature(.emotionDiaryAnalysis).canUse
        case .overallTodoAdvice:
            return UsageLimitManager.shared.canUseAIFeature(.taskAdvice).canUse
        case .individualTodoAdvice:
            return UsageLimitManager.shared.canUseAIFeature(.taskAdvice).canUse
        }
    }

    /// 특정 기능의 남은 사용 횟수를 반환합니다.
    func getRemainingCount(for feature: AIFeatureType) -> Int {
        switch feature {
        case .monthlyStatistics:
            // 주간 1회 제한 기준 남은 횟수
            let status = UsageLimitManager.shared.canUseWeeklyLimitedFeature(anchor: .kstMonday, key: "monthly_statistics")
            return status.remaining
        case .chat:
            let s = UsageLimitManager.shared.canUseAIFeature(.generalConversation)
            return max(0, s.dailyLimit - s.currentUsage)
        case .presetRecommendation:
            let s = UsageLimitManager.shared.canUseAIFeature(.presetRecommendation)
            return max(0, s.dailyLimit - s.currentUsage)
        case .diaryAnalysis:
            let s = UsageLimitManager.shared.canUseAIFeature(.emotionDiaryAnalysis)
            return max(0, s.dailyLimit - s.currentUsage)
        case .overallTodoAdvice, .individualTodoAdvice:
            let s = UsageLimitManager.shared.canUseAIFeature(.taskAdvice)
            return max(0, s.dailyLimit - s.currentUsage)
        }
    }

    /// 특정 기능의 사용을 기록합니다.
    @discardableResult
    func recordUsage(for feature: AIFeatureType) -> Bool {
        switch feature {
        case .monthlyStatistics:
            UsageLimitManager.shared.incrementWeeklyLimitedFeature(anchor: .kstMonday, key: "monthly_statistics")
        case .chat:
            UsageLimitManager.shared.incrementUsage(for: .generalConversation)
        case .presetRecommendation:
            UsageLimitManager.shared.incrementUsage(for: .presetRecommendation)
        case .diaryAnalysis:
            UsageLimitManager.shared.incrementUsage(for: .emotionDiaryAnalysis)
        case .overallTodoAdvice, .individualTodoAdvice:
            UsageLimitManager.shared.incrementUsage(for: .taskAdvice)
        }
        // 🛰️ 변경 브로드캐스트 (기존 의존성 유지)
        let total = getTotalLimit(for: feature)
        let used = (total - getRemainingCount(for: feature))
        NotificationCenter.default.post(name: .aiUsageUpdated, object: nil, userInfo: [
            "feature": feature.rawValue,
            "used": used,
            "limit": total
        ])
        return true
    }
    
}

// CaseIterable 추가
extension AIFeatureType: CaseIterable {} 

public extension Notification.Name {
    static let aiUsageUpdated = Notification.Name("aiUsageUpdated")
}

// MARK: - Dynamic Limits
extension AIUsageManager {
    /// 유/무료 구독 상태를 고려한 동적 일일 제한
    private func limit(for feature: AIFeatureType) -> Int {
        switch feature {
        case .monthlyStatistics:
            return 1
        case .chat:
            return UsageLimitManager.shared.canUseAIFeature(.generalConversation).dailyLimit
        case .presetRecommendation:
            return UsageLimitManager.shared.canUseAIFeature(.presetRecommendation).dailyLimit
        case .diaryAnalysis:
            return UsageLimitManager.shared.canUseAIFeature(.emotionDiaryAnalysis).dailyLimit
        case .overallTodoAdvice, .individualTodoAdvice:
            return UsageLimitManager.shared.canUseAIFeature(.taskAdvice).dailyLimit
        }
    }

    /// 총 일일 제한 조회(표시용)
    func getTotalLimit(for feature: AIFeatureType) -> Int {
        return limit(for: feature)
    }
}
