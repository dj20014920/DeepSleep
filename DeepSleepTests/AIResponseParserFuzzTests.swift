import XCTest
@testable import DeepSleep

final class AIResponseParserFuzzTests: XCTestCase {
    func testParserDoesNotCrashOnMalformedInputs() {
        let providers: [AIProvider] = [.unknown, .openAI, .anthropic, .google, .naver, .openrouter]
        var samples: [String] = []

        // 생성 규칙: 큰따옴표/중괄호/백틱/이모지/널문자/이상한 유니코드 혼합
        let weirds = ["\u{0000}", "`", "\"", "{", "}", "[", "]", "\\", "\n", "💥", "한글", String(repeating: "A", count: 1000)]
        for i in 0..<200 { // 200개의 퍼즈 샘플
            let partCount = Int.random(in: 3...10)
            let parts = (0..<partCount).map { _ in weirds.randomElement()! }
            let joined = parts.joined(separator: String(Int.random(in: 0...1) == 0 ? "," : "\n"))
            let maybeJson = Int.random(in: 0...1) == 0 ? "{\"message\": \"\(joined)\"}" : joined
            samples.append(maybeJson)
        }

        for raw in samples {
            for p in providers {
                let output = AIResponseParser.shared.parse(raw, from: p)
                // 안전성: 너무 길지 않음, 크래시 없이 문자열 반환
                XCTAssertLessThan(output.count, 50_001)
            }
        }
    }
}
