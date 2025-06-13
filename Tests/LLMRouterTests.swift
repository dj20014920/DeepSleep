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
} 