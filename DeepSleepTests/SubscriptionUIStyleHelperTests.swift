import XCTest
@testable import DeepSleep

final class SubscriptionUIStyleHelperTests: XCTestCase {

    func testSetBadge_WithDaysRemaining_SetsTextWithDday() {
        let label = UILabel()
        SubscriptionUIStyleHelper.setBadge(label, isPremium: false, daysRemaining: 3)
        XCTAssertFalse(label.isHidden)
        XCTAssertTrue(label.text?.contains("D-3") == true)
        XCTAssertTrue(label.text?.contains("7일 무료체험") == true)
    }

    func testSetBadge_Premium_HidesLabel() {
        let label = UILabel()
        SubscriptionUIStyleHelper.setBadge(label, isPremium: true, daysRemaining: nil)
        XCTAssertTrue(label.isHidden)
    }
}

