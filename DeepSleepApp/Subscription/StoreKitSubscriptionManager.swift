import Foundation
import StoreKit
import os.log

public enum SubscriptionProduct: String, CaseIterable {
    case monthly = "com.deepsleep.premium.monthly"
    case yearly  = "com.deepsleep.premium.yearly"
}

/// StoreKit 2 기반 구독 관리
public final class StoreKitSubscriptionManager: NSObject {
    public static let shared = StoreKitSubscriptionManager()

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "DeepSleep", category: "IAP")

    private(set) var products: [SubscriptionProduct: Product] = [:]

    private override init() {
        super.init()
        Task { await self.bootstrap() }
    }

    // MARK: - Bootstrap
    private func bootstrap() async {
        // 트랜잭션 리스너를 백그라운드에서 실행 (무한 루프 방지)
        Task.detached { [weak self] in
            await self?.listenForTransactions()
        }
        await refreshEntitlements()
        await loadProducts()
    }

    // MARK: - Load Products
    public func loadProducts() async {
        do {
            let ids = Set(SubscriptionProduct.allCases.map { $0.rawValue })
            let storeProducts = try await Product.products(for: ids)
            var dict: [SubscriptionProduct: Product] = [:]
            for product in storeProducts {
                if let key = SubscriptionProduct(rawValue: product.id) { dict[key] = product }
            }
            self.products = dict
            if !dict.isEmpty {
                logger.debug("Loaded products: \(self.products.keys.map { $0.rawValue }.joined(separator: ", "))")
            }
        } catch {
            logger.error("Failed to load products: \(error.localizedDescription)")
        }
    }

    // MARK: - Purchase
    @MainActor
    public func purchase(_ target: SubscriptionProduct) async throws {
        guard let product = products[target] else {
            throw NSError(domain: "IAP", code: -1, userInfo: [NSLocalizedDescriptionKey: "Product not loaded"])
        }
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await transaction.finish()
            await refreshEntitlements()
        case .userCancelled:
            return
        case .pending:
            return
        @unknown default:
            return
        }
    }

    // MARK: - Restore
    public func restore() async {
        do {
            try await AppStore.sync()
            await refreshEntitlements()
        } catch {
            logger.error("Restore failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Entitlements
    public func refreshEntitlements() async {
        var premium = false
        var latestExpiration: Date?
        var refundedGraceUntil: Date?
        var anyExpiredAt: Date?

        // 정책: 환불 시 결제일로부터 30일간 프리미엄 유지
        func computeRefundGrace(until purchaseDate: Date) -> Date {
            Calendar.current.date(byAdding: .day, value: 30, to: purchaseDate) ?? purchaseDate
        }

        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                guard let _ = SubscriptionProduct(rawValue: transaction.productID) else { continue }

                if let _ = transaction.revocationDate {
                    // 환불됨
                    let purchaseAt = transaction.purchaseDate
                    let grace = computeRefundGrace(until: purchaseAt)
                    // graceUntil 중 최장치 선택
                    if let cur = refundedGraceUntil {
                        refundedGraceUntil = max(cur, grace)
                    } else {
                        refundedGraceUntil = grace
                    }
                } else {
                    // 정상 활성/만료 판단
                    if let exp = transaction.expirationDate {
                        latestExpiration = max(latestExpiration ?? exp, exp)
                        if exp > Date() {
                            premium = true
                        } else {
                            anyExpiredAt = max(anyExpiredAt ?? exp, exp)
                        }
                    } else {
                        // 비소모성/무기한인 경우로 간주(여기서는 프리미엄 활성 처리)
                        premium = true
                    }
                }
            } catch {
                logger.error("Entitlement verification failed: \\(error.localizedDescription)")
            }
        }

        // 상태 결정 우선순위: refunded grace > active > expired > free
        if let grace = refundedGraceUntil, Date() < grace {
            await MainActor.run {
                SubscriptionStatusCenter.shared.update(state: .refunded(graceUntil: grace))
            }
            return
        }
        if premium {
            await MainActor.run {
                SubscriptionStatusCenter.shared.update(state: .active(premiumUntil: latestExpiration))
            }
            return
        }
        if let expiredAt = anyExpiredAt ?? latestExpiration {
            await MainActor.run {
                SubscriptionStatusCenter.shared.update(state: .expired(expiredAt: expiredAt))
            }
            return
        }
        await MainActor.run {
            SubscriptionStatusCenter.shared.update(state: .free)
        }
    }

    // MARK: - Transaction Updates
    private func listenForTransactions() async {
        // 단일 스트림만 사용하여 중복 방지
        for await update in Transaction.updates {
            do {
                let transaction = try checkVerified(update)
                await transaction.finish()
                await refreshEntitlements()
            } catch {
                logger.error("Transaction update failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Helpers
private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw NSError(domain: "IAP", code: -2, userInfo: [NSLocalizedDescriptionKey: "Unverified transaction"])
        case .verified(let transaction):
            return transaction
        }
    }

    // MARK: - Price Helpers
    public func displayPrice(for product: SubscriptionProduct) -> String? {
        guard let p = products[product] else { return nil }
        return p.displayPrice
    }

    public func trialDaysRemaining(for product: SubscriptionProduct) -> Int? {
        // Eligibility 확인은 환경/권한에 따라 async API가 필요할 수 있으므로 여기서는 표시용 기본값(nil)로 둡니다.
        return nil
    }
}

