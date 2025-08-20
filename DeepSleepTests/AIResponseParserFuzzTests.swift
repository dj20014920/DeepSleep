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
    func testProviderSpecificJSONPaths() {
        let openAI = "{" +
        "\"choices\":[{" +
        "\"message\":{\"content\":\"hello from openai\"}}]}"
        let anthropic = "{" +
        "\"content\":[{\"type\":\"text\",\"text\":\"hello from claude\"}]}"
        let google = "{" +
        "\"candidates\":[{\"content\":{\"parts\":[{\"text\":\"hello from gemini\"}]}}]}"
        let naver = "{" +
        "\"message\":{\"result\":\"hello from naver\"}}"
        let openrouter = "{" +
        "\"choices\":[{\"message\":{\"content\":\"hello from openrouter\"}}]}"

        XCTAssertEqual(AIResponseParser.shared.parse(openAI, from: .openAI), "hello from openai")
        XCTAssertEqual(AIResponseParser.shared.parse(anthropic, from: .anthropic), "hello from claude")
        XCTAssertEqual(AIResponseParser.shared.parse(google, from: .google), "hello from gemini")
        XCTAssertEqual(AIResponseParser.shared.parse(naver, from: .naver), "hello from naver")
        XCTAssertEqual(AIResponseParser.shared.parse(openrouter, from: .openrouter), "hello from openrouter")
    }

    func testCodeFenceSanitization() {
        let fenced = "```\n{\n  \"message\": \"hello\"\n}\n```"
        let out = AIResponseParser.shared.parse(fenced, from: .unknown)
        XCTAssertFalse(out.contains("```"))
        XCTAssertTrue(out.contains("hello"))
    }

    func testLargeNestedJSONAndWeirdUnicode() {
        // 큰 JSON과 이상한 유니코드가 섞여 있어도 크래시 없이 처리
        let largeText = String(repeating: "가", count: 10_000)
        let json = "{" +
        "\"message\": \"\(largeText)💥\"}" // 공통 키 경로
        let out = AIResponseParser.shared.parse(json, from: .unknown)
        XCTAssertFalse(out.isEmpty)
        XCTAssertLessThan(out.count, 50_001)
    }
    }

    func testStreamingLikePartialChunks() {
        // Simulate streaming: partial JSON chunks arriving over time
        let base = "{" +
        "\"choices\":[{\"message\":{\"content\":\"hello world streaming\"}}]}"
        // Split into random chunk sizes
        for _ in 0..<50 {
            var idx = base.startIndex
            var chunks: [String] = []
            while idx < base.endIndex {
                let remain = base.distance(from: idx, to: base.endIndex)
                let step = min(remain, Int.random(in: 1...10))
                let next = base.index(idx, offsetBy: step)
                chunks.append(String(base[idx..<next]))
                idx = next
            }
            // Incremental assembly: at each step, parser should not crash
            var assembled = ""
            for c in chunks {
                assembled += c
                let _ = AIResponseParser.shared.parse(assembled, from: .openAI)
            }
            // Final assembled should parse the expected content
            let out = AIResponseParser.shared.parse(assembled, from: .openAI)
            XCTAssertTrue(out.contains("hello world streaming"))
        }
    }

    func testOutOfOrderChunkTolerance() {
        // Out-of-order should not crash; final parse may be imperfect, but safe
        let json = "{" +
        "\"content\":[{\"type\":\"text\",\"text\":\"anthropic stream\"}]}"
        let a = String(json.prefix(json.count/2))
        let b = String(json.suffix(json.count - json.count/2))
        let out1 = AIResponseParser.shared.parse(b + a, from: .anthropic) // wrong order
        XCTAssertLessThan(out1.count, 50_001)
        // Correct order should produce expected text
        let out2 = AIResponseParser.shared.parse(a + b, from: .anthropic)
        XCTAssertTrue(out2.contains("anthropic stream"))
    }

    func testMidStreamTerminationAndFences() {
        // Truncated JSON + code fences should sanitize without crash
        let truncated = "```\n{\n  \"candidates\":[{\"content\":{\"parts\":[{\"text\":\"gemini abc\"}]}}]"
        let out = AIResponseParser.shared.parse(truncated, from: .google)
        XCTAssertFalse(out.contains("```"))
        XCTAssertLessThan(out.count, 50_001)
    }
}
