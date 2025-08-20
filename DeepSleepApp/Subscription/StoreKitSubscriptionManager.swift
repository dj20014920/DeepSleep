import Foundation
import StoreKit
import os.log

public final class SubscriptionStatusCenter {
    public static let shared = SubscriptionStatusCenter()
    private init() {}

    public private(set) var isPremium: Bool = false
    public private(set) var expirationDate: Date?

    public func update(isPremium: Bool, expiration: Date?) {
        self.isPremium = isPremium
        self.expirationDate = expiration
        NotificationCenter.default.post(name: .subscriptionStatusChanged, object: nil)
    }
}

public extension Notification.Name {
    static let subscriptionStatusChanged = Notification.Name("subscriptionStatusChanged")
}

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
        await listenForTransactions()
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
            logger.debug("Loaded products: \(self.products.keys.map { $0.rawValue }.joined(separator: ", "))")
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
        var isPremium = false
        var expiration: Date?

        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                guard transaction.revocationDate == nil else { continue }
                if let _ = SubscriptionProduct(rawValue: transaction.productID) {
                    isPremium = true
                    if let date = transaction.expirationDate { expiration = max(expiration ?? date, date) }
                }
            } catch {
                logger.error("Entitlement verification failed: \(error.localizedDescription)")
            }
        }
        SubscriptionStatusCenter.shared.update(isPremium: isPremium, expiration: expiration)
    }

    // MARK: - Transaction Updates
    private func listenForTransactions() async {
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
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T where T : Transaction {
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
        // Heuristic: If user is eligible for intro offer. StoreKit2 does not directly give days remaining here.
        // For simplicity, return 7 if eligible, else nil.
        guard let p = products[product] else { return nil }
        if p.subscription?.isEligibleForIntroOffer ?? false { return 7 }
        return nil
    }
}

