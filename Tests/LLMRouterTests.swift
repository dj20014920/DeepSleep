import XCTest
@testable import DeepSleep

final class LLMRouterTests: XCTestCase {
    override class func setUp() {
        super.setUp()
        // iOS 버전 mocking을 위해 swizzling 등 필요시 적용 (여기선 실제 환경 기준)
    }
    /// iOS 26 이상, 일반 프롬프트 → Foundation
    func testRoute_iOS26_Foundation() {
        let result = LLMRouter.route(prompt: "안녕", outputHint: "짧은 답변")
        // 실제 환경에서 26 미만이면 이 테스트는 skip
        if ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 26 {
            XCTAssertEqual(result.model, .foundation)
            XCTAssertTrue(result.reason.contains("Foundation"))
        }
    }
    /// iOS 26 이상, 1000자 초과 or 코드블록 → Claude fallback
    func testRoute_iOS26_ClaudeFallback() {
        if ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 26 {
            let long = String(repeating: "a", count: 1001)
            let result1 = LLMRouter.route(prompt: "", outputHint: long)
            XCTAssertEqual(result1.model, .claude)
            let code = "```swift\nlet x = 1\n```"
            let result2 = LLMRouter.route(prompt: "", outputHint: code)
            XCTAssertEqual(result2.model, .claude)
        }
    }
    /// iOS 26 미만 → Claude fallback
    func testRoute_iOSBelow26_Claude() {
        if ProcessInfo.processInfo.operatingSystemVersion.majorVersion < 26 {
            let result = LLMRouter.route(prompt: "hi", outputHint: "test")
            XCTAssertEqual(result.model, .claude)
            XCTAssertTrue(result.reason.contains("Claude"))
        }
    }
    /// iOS 17 미만: ClaudeService만 사용
    func testRoute_iOSBelow17_Claude() async throws {
        if #available(iOS 17.0, *) { return } // 17 이상 환경에서는 skip
        let output = try await LLMRouter.generateResponse(prompt: "hi", outputHint: "test")
        XCTAssertTrue(output.text.count > 0)
        XCTAssertEqual(output.metadata?["model"], "claude-3.5")
    }
    /// iOS 17 이상: FoundationModelRunner 사용
    func testRoute_iOS17_Foundation() async throws {
        if #available(iOS 17.0, *) {
            let output = try await LLMRouter.generateResponse(prompt: "테스트", outputHint: "짧은 답변")
            XCTAssertTrue(output.text.contains("[FM] 테스트"))
            XCTAssertEqual(output.metadata?["model"], "foundation-llm")
        }
    }
    /// iOS 17 이상: 1000자 이상/코드블록 포함 시 Claude fallback
    func testRoute_iOS17_ClaudeFallback() async throws {
        if #available(iOS 17.0, *) {
            let long = String(repeating: "a", count: 1000)
            let output1 = try await LLMRouter.generateResponse(prompt: "", outputHint: long)
            XCTAssertEqual(output1.metadata?["model"], "claude-3.5")
            let code = "```swift\nlet x = 1\n```"
            let output2 = try await LLMRouter.generateResponse(prompt: "", outputHint: code)
            XCTAssertEqual(output2.metadata?["model"], "claude-3.5")
        }
    }
    /// FoundationModelRunner KV 캐시 사용 시 응답 속도 개선
    func testFoundationModelRunnerKVCacheSpeedsUp() async throws {
        if #available(iOS 17.0, *) {
            let prompt = "캐시테스트"
            let _ = try await LLMRouter.generateResponse(prompt: prompt, outputHint: "", useKVCache: true)
            let start = Date()
            let _ = try await LLMRouter.generateResponse(prompt: prompt, outputHint: "", useKVCache: true)
            let elapsed = Date().timeIntervalSince(start)
            XCTAssertLessThan(elapsed, 0.01, "KV 캐시 사용 시 응답이 빨라야 함")
        }
    }
} 