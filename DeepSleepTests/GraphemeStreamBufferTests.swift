import XCTest
@testable import DeepSleepApp

final class GraphemeStreamBufferTests: XCTestCase {
    func testCombiningAcuteIsBuffered() {
        let buf = GraphemeStreamBuffer()
        // "e" + combining acute(U+0301)
        let s1 = "e"
        let s2 = "\u{0301}"
        var out = buf.process(s1)
        // e는 바로 방출됨
        XCTAssertEqual(out, "e")
        out = buf.process(s2)
        // 결합표만 단독으로 오면 보류되어야 함 (바로 방출 X)
        XCTAssertEqual(out, "")
        // flush에서 결합표가 포함된 결과 방출: 표준적으로 "é" (여전히 NFD이나 사용자 단위는 1글자)
        let flushed = buf.flush()
        XCTAssertEqual(flushed, s2)
    }

    func testZWJSequenceBuffered() {
        let buf = GraphemeStreamBuffer()
        // "👩‍💻" = woman technologist (woman + ZWJ + laptop)
        let full = "👩‍💻"
        // ZWJ(200D) 앞뒤를 끊어서 들어오는 상황 시뮬레이션
        let scalars = Array(full.unicodeScalars)
        let mid = scalars.count / 2
        let part1 = String(String.UnicodeScalarView(scalars.prefix(mid)))
        let part2 = String(String.UnicodeScalarView(scalars.suffix(from: mid)))
        var out = buf.process(part1)
        // 중간까지는 불완전할 수 있으므로 일부 보류
        XCTAssertTrue(out.count <= part1.count)
        out += buf.process(part2)
        out += buf.flush()
        XCTAssertEqual(out, full)
    }

    func testRegionalIndicatorPair() {
        let buf = GraphemeStreamBuffer()
        // 국기 예: 🇰🇷 (KR) — 지역표시자 2개 쌍
        let flag = "🇰🇷"
        let scalars = Array(flag.unicodeScalars)
        // 첫 번째만 먼저 들어오면 보류되어야 한다
        let first = String(String.UnicodeScalarView([scalars[0]]))
        let second = String(String.UnicodeScalarView([scalars[1]]))
        var out = buf.process(first)
        // 홀수 개의 지역표시자 → 보류
        XCTAssertEqual(out, "")
        out = buf.process(second)
        out += buf.flush()
        XCTAssertEqual(out, flag)
    }
}

