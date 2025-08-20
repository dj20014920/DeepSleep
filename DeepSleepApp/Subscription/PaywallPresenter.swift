import UIKit

/// Paywall 표시를 중앙에서 관리(중복 방지)
public enum PaywallPresenter {
    public static func present(from host: UIViewController, reason: String? = nil,
                               monthlyPrice: String? = nil,
                               yearlyPrice: String? = nil,
                               trialDaysRemaining: Int? = nil,
                               delegate: PaywallViewControllerDelegate? = nil) {
        let vc = PaywallViewController()
        vc.monthlyDisplayPrice = monthlyPrice
        vc.yearlyDisplayPrice = yearlyPrice
        vc.trialDaysRemaining = trialDaysRemaining
        vc.delegate = delegate
        vc.modalPresentationStyle = .formSheet
        host.present(vc, animated: true)

        // 표시 후 가격/Trial 자동 주입 (비동기)
        Task { @MainActor in
            await StoreKitSubscriptionManager.shared.loadProducts()
            if vc.monthlyDisplayPrice == nil {
                vc.monthlyDisplayPrice = StoreKitSubscriptionManager.shared.displayPrice(for: .monthly)
            }
            if vc.yearlyDisplayPrice == nil {
                vc.yearlyDisplayPrice = StoreKitSubscriptionManager.shared.displayPrice(for: .yearly)
            }
            if vc.trialDaysRemaining == nil {
                vc.trialDaysRemaining = StoreKitSubscriptionManager.shared.trialDaysRemaining(for: .monthly)
                    ?? StoreKitSubscriptionManager.shared.trialDaysRemaining(for: .yearly)
            }
        }
    }
}
