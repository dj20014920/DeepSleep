import XCTest
@testable import DeepSleep

final class AIUsageIsolationTests: XCTestCase {
    override func setUp() {
        super.setUp()
        // 강제 초기화 (DEBUG 전용 도우미)
        UsageLimitManager.shared.resetAllUsageForTesting()
        clearDailyKeyedSpaces()
    }

    override func tearDown() {
        clearDailyKeyedSpaces()
        super.tearDown()
    }

    private func clearDailyKeyedSpaces() {
        // 테스트 간 간섭 방지: 키드 스페이스도 정리
        let ud = UserDefaults.standard
        for k in ud.dictionaryRepresentation().keys {
            if k.hasPrefix("daily_key_count_") || k.hasPrefix("daily_key_fps_") || k.hasPrefix("weekly_usage_") || k.hasPrefix("weekly_lastSeen_") {
                ud.removeObject(forKey: k)
            }
        }
    }

    func testPresetRecommendationExhaustDoesNotAffectTodoAdvice() {
        // Given: 프리셋 추천을 한도까지 소진
        let preset = UsageLimitManager.shared.canUseAIFeature(.presetRecommendation)
        UsageLimitManager.shared.setUsageForTesting(mode: .presetRecommendation, usage: preset.dailyLimit)

        // When/Then: 개별/전체 조언은 여전히 사용 가능해야 함(키드/모드 분리)
        let taskAdvice = UsageLimitManager.shared.canUseAIFeature(.taskAdvice)
        XCTAssertTrue(taskAdvice.canUse || taskAdvice.dailyLimit == 0) // 환경에 따라 0일 수 있음

        let overallLimit = ConfigReader.int("AI_LIMITS_TODO_OVERALL_ADVICE_PRO") ?? ConfigReader.int("AI_LIMITS_TODO_OVERALL_ADVICE_FREE") ?? 0
        let overall = UsageLimitManager.shared.canUseDailyKeyedFeature(key: "todo_overall_advice", limit: overallLimit)
        XCTAssertTrue(overall.canUse)
    }

    func testDiaryAnalysisExhaustDoesNotAffectTodoAdvice() {
        // Given: 일기 분석을 한도까지 소진
        let diary = UsageLimitManager.shared.canUseAIFeature(.emotionDiaryAnalysis)
        UsageLimitManager.shared.setUsageForTesting(mode: .emotionDiaryAnalysis, usage: diary.dailyLimit)

        // When/Then: 개별/전체 조언은 여전히 사용 가능해야 함(키드/모드 분리)
        let taskAdvice = UsageLimitManager.shared.canUseAIFeature(.taskAdvice)
        XCTAssertTrue(taskAdvice.canUse || taskAdvice.dailyLimit == 0)

        let overallLimit = ConfigReader.int("AI_LIMITS_TODO_OVERALL_ADVICE_PRO") ?? ConfigReader.int("AI_LIMITS_TODO_OVERALL_ADVICE_FREE") ?? 0
        let overall = UsageLimitManager.shared.canUseDailyKeyedFeature(key: "todo_overall_advice", limit: overallLimit)
        XCTAssertTrue(overall.canUse)
    }

    func testOverallTodoAdviceExhaustDoesNotAffectOthers() {
        // Given: 전체 조언을 한도까지 소진(키드 카운터)
        let overallLimit = ConfigReader.int("AI_LIMITS_TODO_OVERALL_ADVICE_PRO") ?? ConfigReader.int("AI_LIMITS_TODO_OVERALL_ADVICE_FREE") ?? 0
        for _ in 0..<overallLimit { UsageLimitManager.shared.incrementDailyKeyedFeature(key: "todo_overall_advice") }

        // When/Then: 프리셋 추천과 개별 조언은 별도 제한을 사용
        let preset = UsageLimitManager.shared.canUseAIFeature(.presetRecommendation)
        XCTAssertTrue(preset.canUse || preset.dailyLimit == 0)

        let taskAdvice = UsageLimitManager.shared.canUseAIFeature(.taskAdvice)
        XCTAssertTrue(taskAdvice.canUse || taskAdvice.dailyLimit == 0)
    }
}
