import XCTest
@testable import DeepSleepApp

// MARK: - Mock ClaudeService
final class MockClaudeService: ClaudeServiceProtocol {
    var lastPrompt: String?
    var response: Any?
    var shouldThrow = false
    func sendChat(prompt: String, apiKey: String) async throws -> Any {
        lastPrompt = prompt
        if shouldThrow { throw NSError(domain: "Claude", code: 99) }
        return response ?? ""
    }
}

// MARK: - Mock FoundationModelRunner
@available(iOS 17.0, *)
final class MockFoundationModelRunner: FoundationModelRunner {
    var shouldThrow = false
    var mockOutput: LLMOutput?
    override func generateResponse(from prompt: String, useKVCache: Bool) async throws -> LLMOutput {
        if shouldThrow { throw NSError(domain: "FM", code: 99) }
        return mockOutput ?? LLMOutput(text: "FM 응답", metadata: ["engine": "fm"])
    }
}

final class LLMRouterTests: XCTestCase {
    override func setUp() {
        super.setUp()
        // Mock 주입 (실제 DI 구조에 맞게 수정 필요)
        ClaudeService.shared = MockClaudeService() // ClaudeServiceProtocol 채택 필요
    }

    // 1. iOS 17 & 짧은 프롬프트 → FoundationModelRunner 호출
    func test_iOS17_짧은프롬프트_FM호출() async throws {
        if #available(iOS 17.0, *) {
            let router = LLMRouter.shared
            let input = LLMInput(prompt: "안녕")
            FoundationModelRunner.shared = MockFoundationModelRunner() // DI 필요
            let result = try await router.route(input: input)
            XCTAssertEqual(result.text, "FM 응답")
        }
    }

    // 2. iOS 17 & 장문/코드블록 → Claude fallback
    func test_iOS17_장문_ClaudeFallback() async throws {
        if #available(iOS 17.0, *) {
            let router = LLMRouter.shared
            let longPrompt = String(repeating: "a", count: 1001)
            let input = LLMInput(prompt: longPrompt)
            let mockClaude = MockClaudeService()
            mockClaude.response = LLMOutput(text: "Claude 응답", metadata: ["engine": "claude"])
            ClaudeService.shared = mockClaude
            let result = try await router.route(input: input)
            XCTAssertEqual(result.text, "Claude 응답")
        }
    }
    func test_iOS17_코드블록_ClaudeFallback() async throws {
        if #available(iOS 17.0, *) {
            let router = LLMRouter.shared
            let input = LLMInput(prompt: "코드 예시: ```print('hi')``` ")
            let mockClaude = MockClaudeService()
            mockClaude.response = LLMOutput(text: "Claude 응답", metadata: ["engine": "claude"])
            ClaudeService.shared = mockClaude
            let result = try await router.route(input: input)
            XCTAssertEqual(result.text, "Claude 응답")
        }
    }

    // 3. iOS 16 이하 → Claude fallback
    func test_iOS16_ClaudeFallback() async throws {
        // iOS 16 이하 시뮬레이션은 실제 환경에서 분기 필요
        // 여기서는 ClaudeService가 무조건 호출되는지 확인
        let router = LLMRouter.shared
        let input = LLMInput(prompt: "iOS 16 테스트")
        let mockClaude = MockClaudeService()
        mockClaude.response = LLMOutput(text: "Claude 응답", metadata: ["engine": "claude"])
        ClaudeService.shared = mockClaude
        let result = try await router.route(input: input)
        XCTAssertEqual(result.text, "Claude 응답")
    }

    // 4. FoundationModelRunner 실패 시 Claude fallback
    func test_FM실패시_ClaudeFallback() async throws {
        if #available(iOS 17.0, *) {
            let router = LLMRouter.shared
            let input = LLMInput(prompt: "FM 실패 테스트")
            let mockFM = MockFoundationModelRunner()
            mockFM.shouldThrow = true
            FoundationModelRunner.shared = mockFM
            let mockClaude = MockClaudeService()
            mockClaude.response = LLMOutput(text: "Claude 응답", metadata: ["engine": "claude"])
            ClaudeService.shared = mockClaude
            let result = try await router.route(input: input)
            XCTAssertEqual(result.text, "Claude 응답")
        }
    }

    // 5. Claude 응답 파싱 (LLMOutput/String)
    func test_Claude_응답파싱_LLMOutput() async throws {
        let router = LLMRouter.shared
        let input = LLMInput(prompt: "파싱 테스트")
        let mockClaude = MockClaudeService()
        mockClaude.response = LLMOutput(text: "LLMOutput 응답", metadata: nil)
        ClaudeService.shared = mockClaude
        let result = try await router.route(input: input)
        XCTAssertEqual(result.text, "LLMOutput 응답")
    }
    func test_Claude_응답파싱_String() async throws {
        let router = LLMRouter.shared
        let input = LLMInput(prompt: "파싱 테스트")
        let mockClaude = MockClaudeService()
        mockClaude.response = "String 응답"
        ClaudeService.shared = mockClaude
        let result = try await router.route(input: input)
        XCTAssertEqual(result.text, "String 응답")
    }

    // 6. API 키 로딩 실패 시 예외
    func test_API키없을때_예외() async throws {
        let router = LLMRouter.shared
        let input = LLMInput(prompt: "API키 없음 테스트")
        // SecureEnclaveKeyStore, Info.plist 모두 nil로 세팅 필요 (실제 환경에 맞게)
        // ...
        await XCTAssertThrowsErrorAsync {
            _ = try await router.route(input: input)
        }
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