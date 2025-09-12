import UIKit

/// 간편 결제 시트를 중앙에서 표시(배지/게이트 공용 진입점)
public enum PaywallPresenter {
    public static func present(from host: UIViewController,
                               reason: String? = nil,
                               monthlyPrice: String? = nil,
                               yearlyPrice: String? = nil,
                               trialDaysRemaining: Int? = nil,
                               delegate: AnyObject? = nil) {
        let defaultTier: PurchaseOptionSheetViewController.Tier = .pro
        let defaultTerm: PurchaseOptionSheetViewController.Term = .monthly
        let sheet = PurchaseOptionSheetViewController(model: .init(
            tier: defaultTier,
            term: defaultTerm,
            trialDays: trialDaysRemaining
        ))
        sheet.modalPresentationStyle = .pageSheet
        UnifiedLogger.shared.logUI("paywall_view")
        host.present(sheet, animated: true)
    }
}
