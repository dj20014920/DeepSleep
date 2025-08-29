import Foundation
import StoreKit
import os.log

public enum SubscriptionProduct: String, CaseIterable {
    case proMonthly = "com.emozleep.pro.monthly"
    case proYearly  = "com.emozleep.pro.yearly"
    case maxMonthly = "com.emozleep.max.monthly"
    case maxYearly  = "com.emozleep.max.yearly"
}

public extension Notification.Name {
    /// 제품 목록이 갱신되었을 때 브로드캐스트
    static let iapProductsUpdated = Notification.Name("iapProductsUpdated")
}

/// StoreKit 2 기반 구독 관리
public final class StoreKitSubscriptionManager: NSObject {
    public static let shared = StoreKitSubscriptionManager()

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "DeepSleep", category: "IAP")

    private(set) var products: [SubscriptionProduct: Product] = [:] {
        didSet {
            if Thread.isMainThread {
                NotificationCenter.default.post(name: .iapProductsUpdated, object: nil)
            } else {
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .iapProductsUpdated, object: nil)
                }
            }
        }
    }

    // 현재 활성 구독 상품들 (만료되지 않은 entitlement)
    public private(set) var activeProducts: Set<SubscriptionProduct> = []
    // 계산된 현재 티어
    public var currentTier: SubscriptionTier {
        if activeProducts.contains(.maxMonthly) || activeProducts.contains(.maxYearly) {
            return .max
        }
        if activeProducts.contains(.proMonthly) || activeProducts.contains(.proYearly) {
            return .pro
        }
        return .free
    }

    /// 과거 구독 거래 내역 존재 여부(최소 정책 판단에 사용)
    private var hasAnySubscriptionHistory: Bool = false

    /// 현재 메모리에 필요한 상품이 모두 로드되었는지
    public var hasAllRequiredProducts: Bool {
        SubscriptionProduct.allCases.allSatisfy { products[$0] != nil }
    }

    /// 특정 상품이 로드되었는지
    public func hasProduct(_ product: SubscriptionProduct) -> Bool { products[product] != nil }

    /// 첫 구독자 무료 체험 가능 여부(최소 정책): 과거 거래가 전무하면 eligible
    public var isTrialEligible: Bool {
        return !hasAnySubscriptionHistory
    }

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
        
        // StoreKit이 준비될 때까지 약간의 지연
        #if targetEnvironment(simulator)
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5초 대기
        #endif
        
        await refreshEntitlements()
        await loadProducts()
    }

    // MARK: - Load Products
    private var isLoadingProducts = false
    private var loadAttempts = 0
    private let maxLoadAttempts = 3
    
    public func loadProducts() async {
        // 동시 호출 방지(스팸 루프 차단)
        if isLoadingProducts { return }
        
        // 최대 시도 횟수 제한
        if loadAttempts >= self.maxLoadAttempts {
            logger.warning("[IAP] Product loading stopped after \(self.maxLoadAttempts) attempts")
            return
        }
        
        isLoadingProducts = true
        loadAttempts += 1
        defer { isLoadingProducts = false }
        do {
            let ids = Set(SubscriptionProduct.allCases.map { $0.rawValue })
            logger.debug("[IAP] Requesting products for IDs: \(ids.joined(separator: ", "))")
            
            // StoreKit Configuration 체크
            #if targetEnvironment(simulator)
            logger.debug("[IAP] Running in Simulator - using StoreKit Configuration")
            #else
            logger.debug("[IAP] Running on Device - using App Store Connect")
            #endif
            
            let storeProducts = try await Product.products(for: ids)
            logger.debug("[IAP] Raw products returned: \(storeProducts.count) items")
            
            var dict: [SubscriptionProduct: Product] = [:]
            for product in storeProducts {
                logger.debug("[IAP] Found product: \(product.id) - \(product.displayName) - \(product.displayPrice)")
                if let key = SubscriptionProduct(rawValue: product.id) { 
                    dict[key] = product 
                }
            }
            
            // 찾지 못한 제품 ID 로깅
            let foundIds = Set(storeProducts.map { $0.id })
            let missingIds = ids.subtracting(foundIds)
            if !missingIds.isEmpty {
                logger.warning("[IAP] Missing products: \(missingIds.joined(separator: ", "))")
                // 시뮬레이터 환경에서 0개가 지속되면, StoreKit 설정 문제 가능성 안내 로그
                #if targetEnvironment(simulator)
                if dict.isEmpty {
                    logger.error("[IAP] Simulator returned 0 products. 확인사항: (1) Scheme > Run > Options 에서 DeepSleep.storekit 선택, (2) 대상 스킴/타깃 일치, (3) In-App Purchase capability 추가, (4) Xcode StoreKit 테스트 리셋 후 재빌드")
                }
                #endif
            }
            
            self.products = dict
            logger.debug("[IAP] loadProducts finished. count=\(dict.count), ids=\(Array(dict.keys).map { $0.rawValue }.joined(separator: ", "))")
        } catch {
            logger.error("[IAP] Failed to load products: \(error.localizedDescription)")
            logger.error("[IAP] Error details: \(String(describing: error))")
        }
    }

    // MARK: - Purchase
    @MainActor
    public func purchase(_ target: SubscriptionProduct) async throws {
        var targetProduct = products[target]
        if targetProduct == nil {
            // 1회 재시도: 로드 후 다시 조회
            await loadProducts()
            targetProduct = products[target]
        }
        guard let product = targetProduct else {
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
        var newActiveProducts: Set<SubscriptionProduct> = []

        // 정책: 환불 시 결제일로부터 30일간 프리미엄 유지
        func computeRefundGrace(until purchaseDate: Date) -> Date {
            Calendar.current.date(byAdding: .day, value: 30, to: purchaseDate) ?? purchaseDate
        }

        var observedAnyTransactions = false
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                guard let _ = SubscriptionProduct(rawValue: transaction.productID) else { continue }

                observedAnyTransactions = true

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
                            if let p = SubscriptionProduct(rawValue: transaction.productID) {
                                newActiveProducts.insert(p)
                            }
                        } else {
                            anyExpiredAt = max(anyExpiredAt ?? exp, exp)
                        }
                    } else {
                        // 비소모성/무기한인 경우로 간주(여기서는 프리미엄 활성 처리)
                        premium = true
                        if let p = SubscriptionProduct(rawValue: transaction.productID) {
                            newActiveProducts.insert(p)
                        }
                    }
                }
            } catch {
                logger.error("Entitlement verification failed: \(error.localizedDescription)")
            }
        }
        // 활성 상품 반영
        self.activeProducts = newActiveProducts
        // 관찰된 거래가 하나라도 있으면 과거 구독 이력이 있다고 간주(최소 정책)
        self.hasAnySubscriptionHistory = observedAnyTransactions

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
        // 정책: 첫 구독자 대상 7일 무료체험 제공. 사전 노출 목적의 표시값.
        // 실제 구매 후 남은 일수 계산은 트랜잭션 기반으로 별도 처리 가능하나,
        // 현재는 구매 전 안내 단계에서 항상 7일을 노출합니다(eligible 한 경우).
        return isTrialEligible ? 7 : nil
    }
}
