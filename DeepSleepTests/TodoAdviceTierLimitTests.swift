import XCTest
@testable import DeepSleep

final class TodoAdviceTierLimitTests: XCTestCase {
    override func setUp() {
        super.setUp()
        UsageLimitManager.shared.resetAllUsageForTesting()
    }

    func testFreeTierHasThreeIndividualAdvicePerDay() {
        // Given: Free tier
        SubscriptionStatusCenter.shared.update(isPremium: false, expiration: nil)
        // When
        let status = UsageLimitManager.shared.canUseAIFeature(.taskAdvice)
        // Then
        XCTAssertEqual(status.dailyLimit, 3, "Free tier should have 3 individual advices per day")
    }

    func testPremiumTierHasSevenIndividualAdvicePerDay() {
        // Given: Premium tier
        SubscriptionStatusCenter.shared.update(isPremium: true, expiration: nil)
        // When
        let status = UsageLimitManager.shared.canUseAIFeature(.taskAdvice)
        // Then
        XCTAssertEqual(status.dailyLimit, 7, "Premium tier should have 7 individual advices per day")
    }
}

