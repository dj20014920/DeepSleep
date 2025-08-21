import Foundation

/// 구독 라이프사이클 상태(세분화)
public enum SubscriptionLifecycleState: Equatable {
    case active(premiumUntil: Date?)        // 유료/체험 활성
    case gracePeriod(retryUntil: Date?)     // 결제 재시도 유예(표시용)
    case refunded(graceUntil: Date)         // 환불되었으나 정책상 해당 일자까지 혜택 유지
    case expired(expiredAt: Date?)          // 만료
    case free                               // 무료(Trial 비대상 포함)
}

/// 구독 상태 제공 프로토콜(단일 소스 오브 트루스 파사드)
public protocol SubscriptionStatusProviding {
    var isPremium: Bool { get }
    var expiration: Date? { get }
    var state: SubscriptionLifecycleState { get }
}

/// 단일 소스 오브 트루스: 구독 상태 브로드캐스트 센터
public final class SubscriptionStatusCenter: SubscriptionStatusProviding {
    public static let shared = SubscriptionStatusCenter()
    private init() {}

    public private(set) var isPremium: Bool = false
    public private(set) var expiration: Date?
    public private(set) var state: SubscriptionLifecycleState = .free

    /// 상태 갱신 및 브로드캐스트(모든 소스는 이 경로만 사용)
    public func update(isPremium: Bool, expiration: Date?) {
        self.isPremium = isPremium
        self.expiration = expiration
        // 하위 호환: isPremium/expiration으로부터 state 추론
        if isPremium {
            self.state = .active(premiumUntil: expiration)
        } else {
            if let exp = expiration {
                self.state = .expired(expiredAt: exp)
            } else {
                self.state = .free
            }
        }
        NotificationCenter.default.post(name: .subscriptionStatusChanged, object: nil)
    }

    /// 세분화된 상태로 직접 갱신(권장 경로)
    public func update(state: SubscriptionLifecycleState) {
        self.state = state
        switch state {
        case .active(let until):
            self.isPremium = true
            self.expiration = until
        case .gracePeriod(let retryUntil):
            self.isPremium = true
            self.expiration = retryUntil
        case .refunded(let graceUntil):
            self.isPremium = Date() < graceUntil
            self.expiration = graceUntil
        case .expired(let expiredAt):
            self.isPremium = false
            self.expiration = expiredAt
        case .free:
            self.isPremium = false
            self.expiration = nil
        }
        NotificationCenter.default.post(name: .subscriptionStatusChanged, object: nil)
    }
}

public extension Notification.Name {
    /// 구독 상태 변경 알림(전역 공통)
    static let subscriptionStatusChanged = Notification.Name("subscriptionStatusChanged")
}
