import XCTest
@testable import DeepSleepApp

final class AIContextAndTuningBoundaryTests: XCTestCase {
    override func setUp() {
        super.setUp()
        // 베이스 설정 초기화
        var s = UserSettingsModel()
        s.nickname = "테스터"
        s.personalityDescription = "테스트 유저"
        s.preferredFriendTones = []
        s.mbti = .init()
        s.saveToUserDefaults()
    }

    // 경계/중앙/한계: 말투 프리셋(0개/중앙값/최대) + MBTI(미정/부분/전부)
    func testContext_NoTone_NoMBTI() {
        var s = UserSettingsModel.loadFromUserDefaults()
        s.preferredFriendTones = []
        s.mbti = .init()
        s.saveToUserDefaults()
        let ctx = s.generateAIContext()
        XCTAssertFalse(ctx.contains("MBTI 경향:"))
        XCTAssertFalse(ctx.contains("친구 말투 프리셋:"))
    }

    func testContext_SingleMBTITraitOnly() {
        var s = UserSettingsModel.loadFromUserDefaults()
        s.mbti.tf = .f
        s.saveToUserDefaults()
        let ctx = s.generateAIContext()
        XCTAssertTrue(ctx.contains("MBTI 경향: F"))
        XCTAssertTrue(ctx.contains("감정 공감")) // F 가이드라인 문구 일부
        XCTAssertFalse(ctx.contains("I "))
        XCTAssertFalse(ctx.contains("N "))
        XCTAssertFalse(ctx.contains("P "))
    }

    func testContext_AllTones_AllMBTI_MaximalButNoDup() {
        var s = UserSettingsModel.loadFromUserDefaults()
        s.preferredFriendTones = UserSettingsModel.FriendTonePreset.allCases
        s.mbti.ie = .e; s.mbti.ns = .n; s.mbti.tf = .f; s.mbti.pj = .p
        s.saveToUserDefaults()

        // 프롬프트 조립: 사용자 컨텍스트 중복 금지
        let assembled = AIContextBuilder.shared.buildPrompt(
            for: .generalConversation,
            personaSignature: AIContextSignature.computeBaseKeyForCurrentUser(mode: .generalConversation, maxItems: 5),
            recentMessages: [],
            coreMemorySummary: nil,
            currentUserMessage: "안녕"
        )
        // 사용자 컨텍스트 헤더는 1회만
        let countPersona = assembled.text.components(separatedBy: "[사용자 페르소나]").count - 1
        XCTAssertEqual(countPersona, 1, "사용자 컨텍스트가 중복되지 않아야 합니다")
        // 세그먼트 레이블 확인
        XCTAssertTrue(assembled.text.contains("### System"))
        XCTAssertTrue(assembled.text.contains("### User"))
    }

    // 토큰 튜닝 경계/조합 확인(네트워크 미사용): 내부 헬퍼로 검증
    func testTuning_BoundsClamp_AndTopPAdjust() {
        let svc = UnifiedAIServiceImpl.shared
        var base = TokenConfiguration(maxTokens: 800, temperature: 0.7)

        // 최대 증가 시나리오: 장난/유머 + ENFP
        var s = UserSettingsModel.loadFromUserDefaults()
        s.preferredFriendTones = [.playful, .humorous, .supportive]
        s.mbti.ie = .e; s.mbti.ns = .n; s.mbti.tf = .f; s.mbti.pj = .p
        s.saveToUserDefaults()
        let inc = svc._testApplyUserPersonaTuning(base, mode: .generalConversation)
        XCTAssertGreaterThanOrEqual(inc.temperature, 0.7)
        XCTAssertLessThanOrEqual(inc.temperature, 0.85) // +0.15 이내
        if let tp = inc.topP { XCTAssertGreaterThanOrEqual(tp, 0.9) }

        // 최대 감소 시나리오: 전문/간결/분석 + ISTJ
        s.preferredFriendTones = [.professional, .concise, .analytical]
        s.mbti.ie = .i; s.mbti.ns = .s; s.mbti.tf = .t; s.mbti.pj = .j
        s.saveToUserDefaults()
        let dec = svc._testApplyUserPersonaTuning(base, mode: .generalConversation)
        XCTAssertLessThanOrEqual(dec.temperature, 0.7)
        XCTAssertGreaterThanOrEqual(dec.temperature, 0.55) // -0.15 이내
        if let tp = dec.topP { XCTAssertLessThanOrEqual(tp, 0.9) }

        // 하한/상한 클램프: base 낮거나 높은 경우
        base = TokenConfiguration(maxTokens: 800, temperature: 0.02)
        let low = svc._testApplyUserPersonaTuning(base, mode: .generalConversation)
        XCTAssertGreaterThanOrEqual(low.temperature, 0.1)
        base = TokenConfiguration(maxTokens: 800, temperature: 1.2)
        let high = svc._testApplyUserPersonaTuning(base, mode: .generalConversation)
        XCTAssertLessThanOrEqual(high.temperature, 1.0)
    }
}

