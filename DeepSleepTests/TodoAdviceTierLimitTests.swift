import XCTest
@testable import DeepSleep

final class TodoAdviceTierLimitTests: XCTestCase {
    override func setUp() {
        super.setUp()
        UsageLimitManager.shared.resetAllUsageForTesting()
    }

    func testFreeTierHasFiveIndividualAdvicePerDay() {
        // Given: Free tier
        SubscriptionStatusCenter.shared.update(isPremium: false, expiration: nil)
        // When
        let status = UsageLimitManager.shared.canUseAIFeature(.taskAdvice)
        // Then
        XCTAssertEqual(status.dailyLimit, 5, "Free tier should have 5 individual advices per day")
    }

    func testPremiumTierHasTwentyIndividualAdvicePerDay() {
        // Given: Premium tier
        SubscriptionStatusCenter.shared.update(isPremium: true, expiration: nil)
        // When
        let status = UsageLimitManager.shared.canUseAIFeature(.taskAdvice)
        // Then
        XCTAssertEqual(status.dailyLimit, 20, "Premium tier should have 20 individual advices per day")
    }
}
