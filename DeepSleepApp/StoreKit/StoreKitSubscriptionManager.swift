import Foundation
import StoreKit
import UIKit

/// StoreKit 2 구독 관리(단일 진입점)
/// - 제품 로드/가격 표시/구매/복원/트라이얼 가능 여부를 캡슐화
/// - 스크린샷 모드(IAP_SCREENSHOT=1)에서는 가격/버튼을 강제 활성화하여 심사용 촬영을 지원
final class StoreKitSubscriptionManager {

    // MARK: - Types
    enum ProductKind: CaseIterable {
        case proMonthly, proYearly, maxMonthly, maxYearly

        var productId: String {
            switch self {
            case .proMonthly: return "com.emozleep.pro.monthly"
            case .proYearly:  return "com.emozleep.pro.yearly"
            case .maxMonthly: return "com.emozleep.max.monthly"
            case .maxYearly:  return "com.emozleep.max.yearly"
            }
        }

        var periodSuffix: String { // 표시용
            switch self {
            case .proMonthly, .maxMonthly: return "/월"
            case .proYearly, .maxYearly:   return "/년"
            }
        }
    }

    // MARK: - Singleton
    static let shared = StoreKitSubscriptionManager()
    private init() {}

    // MARK: - State
    private var products: [String: Product] = [:]
    private(set) var lastLoadError: Error?
    private var didAttemptLoad = false

    /// 현재 추정 티어(기본: 무료, 프리미엄은 Pro로 간주)
    var currentTier: SubscriptionTier {
        return SubscriptionStatusCenter.shared.isPremium ? .pro : .free
    }

    /// 스크린샷 모드에서 가격/버튼 강제 활성화
    private var isScreenshotMode: Bool {
        if let v = ProcessInfo.processInfo.environment["IAP_SCREENSHOT"], v == "1" { return true }
        return false
    }

    /// 트라이얼 가능 추정(간단 휴리스틱)
    /// - 실제 심사/실사용에서는 영수증/거래 이력 기반으로 보수적으로 처리
    var isTrialEligible: Bool {
        if isScreenshotMode { return true }
        // 간단 판정: 현재 활성 구독/과거 구매 이력 없으면 true
        // StoreKit2에서 과거 이력 조회는 전체 영수증 검증이 가장 정확하나, 여기서는 엔타이틀먼트 기반 휴리스틱 사용
        do {
            for await ent in Transaction.currentEntitlements {
                if case .autoRenewable = ent.productType { return false }
            }
        }
        return true
    }

    // MARK: - Public API
    @MainActor
    func loadProducts() async {
        // 이미 시도했고 성공/실패가 있고, 스크린샷 모드도 아니면 재호출 최소화
        if didAttemptLoad, !isScreenshotMode { return }
        didAttemptLoad = true
        lastLoadError = nil
        do {
            let ids = Set(ProductKind.allCases.map { $0.productId })
            let result = try await Product.products(for: ids)
            var map: [String: Product] = [:]
            result.forEach { map[$0.id] = $0 }
            self.products = map
            NotificationCenter.default.post(name: .iapProductsUpdated, object: nil)
        } catch {
            self.lastLoadError = error
            // 스크린샷 모드에서는 실패해도 버튼/가격 강제 표시가 가능해야 함
            NotificationCenter.default.post(name: .iapProductsUpdated, object: nil)
        }
    }

    func hasProduct(_ kind: ProductKind) -> Bool {
        if products[kind.productId] != nil { return true }
        return isScreenshotMode // 스크린샷 모드에서는 항상 true
    }

    /// 현지화된 가격 문자열 반환(예: "₩6,600/월")
    func displayPrice(for kind: ProductKind) -> String? {
        if let p = products[kind.productId] {
            return p.displayPrice + kind.periodSuffix
        }
        guard isScreenshotMode else { return nil }
        // 스크린샷 모드 fallback(요건 예시 값)
        switch kind {
        case .proMonthly: return "₩6,600/월"
        case .proYearly:  return "₩66,000/년"
        case .maxMonthly: return "₩11,000/월"
        case .maxYearly:  return "₩99,000/년"
        }
    }

    /// 구매 수행 및 상태 반영
    @MainActor
    func purchase(_ kind: ProductKind) async throws {
        if let product = products[kind.productId] {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                // 상태 업데이트
                await finalize(transaction)
                try? await transaction.finish()
            case .pending:
                break
            case .userCancelled:
                break
            @unknown default:
                break
            }
        } else if isScreenshotMode {
            // 스크린샷 모드에서는 성공한 것처럼 상태를 반영(실결제 없음)
            SubscriptionStatusCenter.shared.update(state: .active(premiumUntil: Calendar.current.date(byAdding: .day, value: 7, to: Date())))
        } else {
            throw NSError(domain: "IAP", code: -1, userInfo: [NSLocalizedDescriptionKey: "Product not loaded"])
        }
    }

    /// 복원(영수증 동기화 + 활성 권리 반영)
    @MainActor
    func restore() async {
        do { try await AppStore.sync() } catch { /* ignore */ }
        // 현재 엔타이틀먼트 기반으로 상태 추론
        var premiumUntil: Date?
        var hasPremium = false
        for await ent in Transaction.currentEntitlements {
                if case .autoRenewable = ent.productType {
                    hasPremium = true
                    premiumUntil = ent.expirationDate
                }
        }
        if hasPremium {
            SubscriptionStatusCenter.shared.update(state: .active(premiumUntil: premiumUntil))
        } else {
            SubscriptionStatusCenter.shared.update(state: .free)
        }
    }

    // MARK: - Helpers
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw NSError(domain: "IAP", code: -2, userInfo: [NSLocalizedDescriptionKey: "Unverified transaction"])
        case .verified(let safe):
            return safe
        }
    }

    @MainActor
    private func finalize(_ transaction: Transaction) async {
        // 상태 반영
        if case .autoRenewable = transaction.productType {
            SubscriptionStatusCenter.shared.update(state: .active(premiumUntil: transaction.expirationDate))
        }
        // 프록시 리포팅 제거
    }
}

// MARK: - Notifications
extension Notification.Name {
    static let iapProductsUpdated = Notification.Name("iapProductsUpdated")
}
