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

        // 가격/Trial은 Paywall 내부에서 자동 로딩됨
    }
}
