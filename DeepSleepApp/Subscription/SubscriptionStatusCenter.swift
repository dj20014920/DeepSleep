import Foundation

/// 구독 상태 제공 프로토콜(단일 소스 오브 트루스 파사드)
public protocol SubscriptionStatusProviding {
    var isPremium: Bool { get }
    var expiration: Date? { get }
}

/// 현재는 기존 Mock SubscriptionManager에 위임.
/// 이후 StoreKit2 매니저로 교체 시 내부 위임체만 바꾸면 전역 게이트가 자동 전환됩니다.
public final class SubscriptionStatusCenter: SubscriptionStatusProviding {
    public static let shared = SubscriptionStatusCenter()
    private init() {}

    // MARK: - Delegation to existing mock (bridge)
    public var isPremium: Bool {
        // 기존 Mock 매니저를 단일 진입점으로 래핑
        return SubscriptionManager.shared.isSubscribed
    }

    public var expiration: Date? {
        return SubscriptionManager.shared.expirationDate
    }
}
