import Foundation

/// 구독 상태 제공 프로토콜(단일 소스 오브 트루스 파사드)
public protocol SubscriptionStatusProviding {
    var isPremium: Bool { get }
    var expiration: Date? { get }
}

/// 단일 소스 오브 트루스: 구독 상태 브로드캐스트 센터
public final class SubscriptionStatusCenter: SubscriptionStatusProviding {
    public static let shared = SubscriptionStatusCenter()
    private init() {}

    public private(set) var isPremium: Bool = false
    public private(set) var expiration: Date?

    /// 상태 갱신 및 브로드캐스트(모든 소스는 이 경로만 사용)
    public func update(isPremium: Bool, expiration: Date?) {
        self.isPremium = isPremium
        self.expiration = expiration
        NotificationCenter.default.post(name: .subscriptionStatusChanged, object: nil)
    }
}

public extension Notification.Name {
    /// 구독 상태 변경 알림(전역 공통)
    static let subscriptionStatusChanged = Notification.Name("subscriptionStatusChanged")
}
