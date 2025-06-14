import XCTest
@testable import DeepSleepApp

@available(iOS 17.0, *)
@MainActor
final class ComprehensiveRecommendationEngineTests: XCTestCase {
    func testRecommend_행복일때() async throws {
        let engine = ComprehensiveRecommendationEngine()
        let preset = try await engine.recommend(forEmotion: "happy")
        XCTAssertEqual(preset.presetName, "행복 에너지 부스트")
        XCTAssertEqual(preset.volumes.count, 13)
    }
    func testRecommend_슬플때() async throws {
        let engine = ComprehensiveRecommendationEngine()
        let preset = try await engine.recommend(forEmotion: "sad")
        XCTAssertEqual(preset.presetName, "마음 안정 휴식")
    }
    func testRecommend_불안할때() async throws {
        let engine = ComprehensiveRecommendationEngine()
        let preset = try await engine.recommend(forEmotion: "anxious")
        XCTAssertEqual(preset.presetName, "불안 완화 집중")
    }
    func testRecommend_분노할때() async throws {
        let engine = ComprehensiveRecommendationEngine()
        let preset = try await engine.recommend(forEmotion: "angry")
        XCTAssertEqual(preset.presetName, "분노 진정")
    }
    func testRecommend_정의되지않은감정_예외() async throws {
        let engine = ComprehensiveRecommendationEngine()
        await XCTAssertThrowsErrorAsync {
            _ = try await engine.recommend(forEmotion: "unknown_emotion")
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