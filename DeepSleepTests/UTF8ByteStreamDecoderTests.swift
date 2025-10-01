import XCTest
@testable import DeepSleepApp

final class UTF8ByteStreamDecoderTests: XCTestCase {
    func testDecodesHangulAcrossByteBoundaries() {
        let decoder = UTF8ByteStreamDecoder()
        // 예: "무슨"을 바이트 단위로 분할해 순차 처리
        let target = "무슨"
        let bytes = Array(target.utf8)
        // 일부러 어색한 경계로 쪼갬 (3바이트 문자 중간 경계)
        let chunk1 = Array(bytes.prefix(2))
        let chunk2 = Array(bytes[2..<4])
        let chunk3 = Array(bytes.suffix(from: 4))

        var out = ""
        out += decoder.processBytes(chunk1)
        XCTAssertEqual(out, "", "미완성 바이트는 출력되지 않아야 함")
        out += decoder.processBytes(chunk2)
        // 여기까지 최소한 첫 글자("무")는 완성되어야 함
        XCTAssertTrue(out.hasPrefix("무"), "첫 글자가 온전히 복원되어야 함")
        out += decoder.processBytes(chunk3)
        out += decoder.flush()

        XCTAssertEqual(out, target, "모든 바이트를 처리하면 원문과 일치해야 함")
    }

    func testDecodesEmojiAcrossByteBoundaries() {
        let decoder = UTF8ByteStreamDecoder()
        let target = "안녕😊하세요"
        let bytes = Array(target.utf8)

        // 4바이트 이모지를 분할해 경계 안전성 확인
        let splitIndex = bytes.firstIndex(of: 0xF0) ?? (bytes.count / 2)
        let chunk1 = Array(bytes.prefix(splitIndex + 2))
        let chunk2 = Array(bytes.suffix(from: splitIndex + 2))

        var out = ""
        out += decoder.processBytes(chunk1)
        out += decoder.processBytes(chunk2)
        out += decoder.flush()
        XCTAssertEqual(out, target)
    }
}

