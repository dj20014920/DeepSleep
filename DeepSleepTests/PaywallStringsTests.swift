import XCTest
@testable import DeepSleep

final class PaywallStringsTests: XCTestCase {
    func testAutoRenewNoticeKOContainsKeyPhrases() {
        let ko = SubscriptionUIMessageFormatter.autoRenewNoticeKO()
        XCTAssertTrue(ko.contains("자동으로 갱신"))
        XCTAssertTrue(ko.contains("Apple ID"))
    }

    func testScreenshotModeProvidesFallbackPrices() async {
        setenv("IAP_SCREENSHOT", "1", 1)
        let m = StoreKitSubscriptionManager.shared.displayPrice(for: .proMonthly)
        let y = StoreKitSubscriptionManager.shared.displayPrice(for: .proYearly)
        XCTAssertNotNil(m)
        XCTAssertNotNil(y)
        unsetenv("IAP_SCREENSHOT")
    }
}

