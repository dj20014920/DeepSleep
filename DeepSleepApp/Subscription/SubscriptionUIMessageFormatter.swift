import Foundation

/// 구독 상태 관련 사용자 메시지/배지 문구를 중앙에서 생성하는 포맷터
/// - 목표: 환불/만료/유예/활성/무료 상태에 대한 카피를 일관되게 제공(DRY)
/// - 사용법: 화면단에서 현재 상태 값을 전달하여 문자열을 받아 사용
public enum SubscriptionUIMessageFormatter {

    /// 활성(유료/체험) 상태 문구
    public static func active(premiumUntil: Date?) -> String {
        if let until = premiumUntil {
            let d = format(date: until)
            return "프리미엄 활성 • 만료 예정일: \(d)"
        }
        return "프리미엄 활성"
    }

    /// 유예(결제 재시도) 상태 문구
    public static func gracePeriod(retryUntil: Date?) -> String {
        if let until = retryUntil {
            let d = format(date: until)
            return "결제 재시도 중 • 기존 혜택 유지 (\(d)까지)"
        }
        return "결제 재시도 중 • 기존 혜택 유지"
    }

    /// 환불 상태 문구(정책: 결제일로부터 30일 혜택 유지)
    public static func refunded(graceUntil: Date) -> String {
        let d = format(date: graceUntil)
        return "환불 처리됨 • \(d)까지 프리미엄 유지 후 무료 전환"
    }

    /// 만료 상태 문구
    public static func expired(expiredAt: Date?) -> String {
        if let at = expiredAt {
            let d = format(date: at)
            return "구독 만료(\(d)) • 계속 이용하려면 갱신하세요"
        }
        return "구독 만료 • 계속 이용하려면 갱신하세요"
    }

    /// 무료 상태 문구(Trial 비대상 포함 안내 선택적으로 표시)
    public static func free(isTrialEligible: Bool) -> String {
        return isTrialEligible ? "무료 • 첫 구독자 7일 체험 가능" : "무료 • 7일 무료체험은 첫 구독자 대상"
    }

    /// 툴팁: 월간 통계 주간 1회 제한(KST)
    public static func monthlyStatsWeeklyTooltip(resetAt: Date) -> String {
        let d = format(date: resetAt, format: "M월 d일 (E) 00:00")
        return "주 1회 이용 가능 • 다음 초기화: \(d) (KST)"
    }

    // MARK: - Helpers
    private static func format(date: Date, format: String = "yyyy.MM.dd") -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.timeZone = TimeZone(secondsFromGMT: 9 * 3600)
        f.dateFormat = format
        return f.string(from: date)
    }
}
