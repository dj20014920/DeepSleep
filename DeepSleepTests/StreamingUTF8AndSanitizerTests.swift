import XCTest
@testable import DeepSleep

final class StreamingUTF8AndSanitizerTests: XCTestCase {

    func testStreamingCleaner_DoesNotStripFFFD_DuringStreaming() {
        // given: 스트림 중간에 임시로 삽입된 U+FFFD (�)
        let delta = "멍�청이, 치� 샐러드"

        // when: 스트리밍 단계 정화를 수행
        let cleaned = SpecialTokenSanitizer.cleanStreamingToken(delta, modelID: .hyperclovax_seed_text_instruct_0_5b_q4_k_m)

        // then: 스트리밍 단계에서는 U+FFFD를 제거하지 않는다 (원형 유지)
        XCTAssertEqual(cleaned, delta)
    }

    func testFinalCleaner_ReplacesFFFDWithSpace_AndNormalizesNFC() {
        // given: U+FFFD 포함 및 NFD 조합형 문자열("한글"을 NFD로 구성)
        let nfd = "\u{1112}\u{1161}\u{11AB}\u{1100}\u{1173}\u{11AF}" // 한글
        let output = "테스트 � " + nfd

        // when: 최종 출력 정화
        let cleaned = SpecialTokenSanitizer.cleanAIOutput(output, modelID: .hyperclovax_seed_text_instruct_0_5b_q4_k_m)

        // then: U+FFFD는 공백으로 치환되고, NFD는 NFC로 정규화되어 "한글"이 된다
        XCTAssertFalse(cleaned.contains("�"))
        XCTAssertTrue(cleaned.contains("한글"))

        // 공백 치환이므로 "테스트  한글" 형태(이중 공백은 최종 단계에서 1개로 줄어듦)
        XCTAssertTrue(cleaned.contains("테스트 한글"))
    }

    func testStopSequencesRemovedInStreaming() {
        // given: 모델 템플릿 토큰이 섞여 들어온 델타
        let delta = "안녕하세요 <|im_start|>assistant 오늘의 일정은 |> 점검입니다."

        // when
        let cleaned = SpecialTokenSanitizer.cleanStreamingToken(delta, modelID: .hyperclovax_seed_text_instruct_0_5b_q4_k_m)

        // then: stop/partial 토큰이 제거되어야 함 (의미 텍스트는 남음)
        XCTAssertFalse(cleaned.contains("<|im_start|>"))
        XCTAssertFalse(cleaned.contains("|>"))
        XCTAssertTrue(cleaned.contains("안녕하세요"))
    }
}

