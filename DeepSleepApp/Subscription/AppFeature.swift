import Foundation

/// 앱 내 유료/무료 게이트 판단에 사용하는 기능 키
public enum AppFeature: String {
    case chat
    case diaryAnalysis
    case presetRecommendation
    case monthlyStatistics   // 주간 1회 제한 대상
    case todoAdvice
    case fortune
    case patternAnalysis
    case claudeRequests      // 모델별 상한(예: Claude) 분기용
}
