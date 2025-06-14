import XCTest
@testable import DeepSleepApp

@available(iOS 17.0, *)
@MainActor
final class LLMFullFlowTests: XCTestCase {
    // 1. [정상 시나리오] 행복한 감정에 대한 정상 응답 흐름
    func test_행복한감정_정상추천응답() async throws {
        let text = "오늘 하루 너무 기분이 좋고 평화로워요!"
        let analyzer = SentimentAnalyzer()
        let emotion = try await analyzer.analyze(text: text)
        XCTAssertEqual(emotion, .happy)
        let recommender = ComprehensiveRecommendationEngine()
        let preset = try await recommender.recommend(forEmotion: emotion.rawValue)
        XCTAssertEqual(preset.presetName.contains("행복"), true)
        let router = LLMRouter.shared
        let output = try await router.route(input: LLMInput(prompt: text))
        XCTAssertNotNil(output.text)
        XCTAssertGreaterThanOrEqual(output.text.count, 30)
        XCTAssertNotNil(output.metadata?["engine"])
        if let sp = output.soundPreset {
            XCTAssertEqual(sp.volumes.count, 13)
            XCTAssertEqual(sp.versions.count, 13)
        }
    }

    // 2. [예외 시나리오] 감정 분석 불가 시 graceful fallback
    func test_감정분석불가_예외시_친절한Fallback() async throws {
        let text = "아으악악!!!!@*!!"
        let analyzer = SentimentAnalyzer()
        let emotion = try await analyzer.analyze(text: text)
        XCTAssertTrue(emotion == .unknown || emotion == .neutral)
        let recommender = ComprehensiveRecommendationEngine()
        let preset = try await recommender.recommend(forEmotion: emotion.rawValue)
        XCTAssertEqual(preset.presetName.contains("기본"), true)
        let router = LLMRouter.shared
        let output = try await router.route(input: LLMInput(prompt: text))
        XCTAssertNotNil(output.text)
        XCTAssertTrue(output.text.contains("죄송") || output.text.contains("이해하지 못했어요") || output.text.count >= 10)
    }

    // 3. [iOS 16 이하 fallback 시나리오] FoundationModelRunner 미지원 디바이스
    func test_iOS16이하_ClaudeFallback() async throws {
        // 실제 iOS 16 환경 분기는 시뮬레이션 필요 (여기선 ClaudeService가 호출되는지 확인)
        let router = LLMRouter.shared
        let input = LLMInput(prompt: "iOS 15.9 환경 테스트")
        let output = try await router.route(input: input)
        XCTAssertNotNil(output.text)
        XCTAssertNotNil(output.metadata?["engine"])
        XCTAssertEqual(output.metadata?["engine"], "claude-3.5")
    }

    // 4. [Claude 3.5 fallback 시나리오] 장문 + 코드 포함 프롬프트
    func test_장문_코드포함_ClaudeFallback() async throws {
        let longPrompt = String(repeating: "a", count: 1500) + "```swift\nprint()"
        let router = LLMRouter.shared
        let output = try await router.route(input: LLMInput(prompt: longPrompt))
        XCTAssertNotNil(output.text)
        XCTAssertGreaterThanOrEqual(output.text.count, 10)
        XCTAssertEqual(output.metadata?["engine"], "claude-3.5")
        if let sp = output.soundPreset {
            XCTAssertEqual(sp.volumes.count, 13)
            XCTAssertEqual(sp.versions.count, 13)
        }
    }

    // 5. [보안 시나리오] API 키가 없음 (Keychain + Info.plist 모두 누락)
    func test_API키없음_예외() async throws {
        // SecureEnclaveKeyStore, Info.plist 모두 nil로 세팅 필요 (실제 환경에 맞게)
        let router = LLMRouter.shared
        let input = LLMInput(prompt: "API키 없음 테스트")
        await XCTAssertThrowsErrorAsync {
            _ = try await router.route(input: input)
        }
    }

    // 6. [블랙컨슈머 시나리오] 악성 반복 입력/욕설 입력
    func test_악성반복_욕설입력_진정유도() async throws {
        let repeatText = String(repeating: "야", count: 40)
        let swearText = "씨X 뭐야 이게"
        let analyzer = SentimentAnalyzer()
        let emotion1 = try await analyzer.analyze(text: repeatText)
        let emotion2 = try await analyzer.analyze(text: swearText)
        XCTAssertEqual(emotion1, .angry)
        XCTAssertEqual(emotion2, .angry)
        let router = LLMRouter.shared
        let output1 = try await router.route(input: LLMInput(prompt: repeatText))
        let output2 = try await router.route(input: LLMInput(prompt: swearText))
        XCTAssertTrue(output1.text.contains("진정") || output1.text.contains("마음"))
        XCTAssertTrue(output2.text.contains("진정") || output2.text.contains("마음"))
        XCTAssertNotNil(output1.metadata?["engine"])
        XCTAssertNotNil(output2.metadata?["engine"])
    }
}

// async throws용 XCTAssertThrowsError 래퍼
extension XCTestCase {
    func XCTAssertThrowsErrorAsync(_ expression: @escaping () async throws -> Void, file: StaticString = #file, line: UInt = #line) async {
        do {
            try await expression()
            XCTFail("예외가 발생해야 합니다.", file: file, line: line)
        } catch {
            // 성공적으로 예외 발생
        }
    }
} 