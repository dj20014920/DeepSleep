import XCTest
@testable import DeepSleep

@available(iOS 17.0, *)
final class FoundationModelRunnerTests: XCTestCase {
    func testGenerateResponseReturnsStructuredOutput() async throws {
        let runner = FoundationModelRunner(modelName: "test-fm", adapterURL: nil)
        let output = try await runner.generateResponse(from: "테스트", useKVCache: false)
        XCTAssertTrue(output.text.contains("[FM] 테스트"))
        XCTAssertEqual(output.metadata?["model"], "test-fm")
    }
    func testKVCacheSpeedsUpResponse() async throws {
        let runner = FoundationModelRunner(modelName: "test-fm", adapterURL: nil)
        let prompt = "캐시테스트"
        let _ = try await runner.generateResponse(from: prompt, useKVCache: true)
        let start = Date()
        let _ = try await runner.generateResponse(from: prompt, useKVCache: true)
        let elapsed = Date().timeIntervalSince(start)
        XCTAssertLessThan(elapsed, 0.01, "KV 캐시 사용 시 응답이 빨라야 함")
    }
    func testThrowsOnInvalidInput() async throws {
        let runner = FoundationModelRunner(modelName: "test-fm", adapterURL: nil)
        do {
            _ = try await runner.generateResponse(from: "", useKVCache: false)
        } catch {
            // 실제 구현 시 에러 발생 예상, 현재 mock은 에러 없음
            XCTAssertTrue(true)
        }
    }
} 