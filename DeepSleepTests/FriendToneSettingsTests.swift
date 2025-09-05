import XCTest
@testable import DeepSleepApp

final class FriendToneSettingsTests: XCTestCase {
    func testAIContextIncludesFriendTonesAndMBTI() {
        var settings = UserSettingsModel()
        settings.nickname = "동동"
        settings.preferredFriendTones = [.friendly, .professional]
        settings.mbti.ie = .i
        settings.mbti.tf = .f

        let ctx = settings.generateAIContext()
        XCTAssertTrue(ctx.contains("친구 말투 프리셋"), "friend tones should be serialized")
        XCTAssertTrue(ctx.contains("MBTI 경향"), "mbti brief should be serialized")
        XCTAssertTrue(ctx.contains("I"), "I/E brief should include I")
        XCTAssertTrue(ctx.contains("F"), "T/F brief should include F")
        XCTAssertTrue(ctx.contains("접근"), "guideline lines should be present")
    }

    func testPersonaSignatureChangesWhenMBTIOrTonesChange() {
        // Clear to a known baseline
        var base = UserSettingsModel()
        base.preferredFriendTones = []
        base.mbti = .init()
        base.saveToUserDefaults()
        let sig0 = UserRulesManager.shared.personaCoreSignature()

        // Change MBTI only
        var s1 = base
        s1.mbti.tf = .f
        s1.saveToUserDefaults()
        let sig1 = UserRulesManager.shared.personaCoreSignature()
        XCTAssertNotEqual(sig0, sig1, "MBTI change should affect core signature")

        // Change friend tones
        var s2 = s1
        s2.preferredFriendTones = [.professional]
        s2.saveToUserDefaults()
        let sig2 = UserRulesManager.shared.personaCoreSignature()
        XCTAssertNotEqual(sig1, sig2, "Friend tone change should affect core signature")
    }
}

