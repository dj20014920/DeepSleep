import UIKit

/// 화면단에서 게이트 체크와 페이월 표시를 일관되게 처리하기 위한 유틸리티
public enum EntitlementUI {

    /// 기능 접근을 검사하고, 불가 시 페이월을 표시합니다.
    /// - Returns: 접근 가능하면 true, 페이월을 표시하고 false
    @discardableResult
    public static func require(_ feature: AppFeature,
                               from host: UIViewController,
                               monthlyPrice: String? = nil,
                               yearlyPrice: String? = nil,
                               trialDaysRemaining: Int? = nil,
                               delegate: PaywallViewControllerDelegate? = nil) -> Bool {
        let (can, _) = EntitlementGate.canAccess(feature)
        if can { return true }
        PaywallPresenter.present(from: host,
                                 monthlyPrice: monthlyPrice,
                                 yearlyPrice: yearlyPrice,
                                 trialDaysRemaining: trialDaysRemaining,
                                 delegate: delegate)
        return false
    }
}
