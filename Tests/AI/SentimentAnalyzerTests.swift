import XCTest
@testable import DeepSleepApp

@available(iOS 17.0, *)
@MainActor
final class SentimentAnalyzerTests: XCTestCase {
    func testAnalyzeEmotion_행복일때() async throws {
        let analyzer = SentimentAnalyzer()
        let result = try await analyzer.analyze(text: "정말 기분이 좋아요! 행복해요 :)")
        XCTAssertEqual(result, .happy)
    }
    func testAnalyzeEmotion_슬플때() async throws {
        let analyzer = SentimentAnalyzer()
        let result = try await analyzer.analyze(text: "오늘은 너무 우울하고 슬퍼요")
        XCTAssertEqual(result, .sad)
    }
    func testAnalyzeEmotion_불안할때() async throws {
        let analyzer = SentimentAnalyzer()
        let result = try await analyzer.analyze(text: "불안하고 걱정이 많아요")
        XCTAssertEqual(result, .anxious)
    }
    func testAnalyzeEmotion_분노할때() async throws {
        let analyzer = SentimentAnalyzer()
        let result = try await analyzer.analyze(text: "정말 화가 나고 분노가 치밀어요")
        XCTAssertEqual(result, .angry)
    }
    func testAnalyzeEmotion_중립일때() async throws {
        let analyzer = SentimentAnalyzer()
        let result = try await analyzer.analyze(text: "그냥 그런 하루였어요")
        XCTAssertEqual(result, .neutral)
    }
    func testAnalyzeEmotion_공백입력_예외() async throws {
        let analyzer = SentimentAnalyzer()
        await XCTAssertThrowsErrorAsync {
            _ = try await analyzer.analyze(text: "   ")
        }
    }
    func testAnalyzeEmotion_너무짧은입력_예외() async throws {
        let analyzer = SentimentAnalyzer()
        await XCTAssertThrowsErrorAsync {
            _ = try await analyzer.analyze(text: "a")
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