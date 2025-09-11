import UIKit

/// Paywall 표시 유틸
enum PaywallPresenter {
    static func present(from host: UIViewController,
                        monthlyPrice: String?,
                        yearlyPrice: String?,
                        trialDaysRemaining: Int?,
                        delegate: PaywallViewControllerDelegate?) {
        let vc = PaywallViewController()
        vc.monthlyDisplayPrice = monthlyPrice
        vc.yearlyDisplayPrice = yearlyPrice
        vc.trialDaysRemaining = trialDaysRemaining
        vc.delegate = delegate
        let nav = UINavigationController(rootViewController: vc)
        nav.modalPresentationStyle = .pageSheet
        UnifiedLogger.shared.logUI("paywall_view")
        host.present(nav, animated: true)
    }
}

