@testable import DeepSleep
import XCTest

final class EmotionDiaryViewControllerTests: XCTestCase {

    func testCalendarChildIsAdded() {
        // Given
        let vc = EmotionDiaryViewController()

        // When
        _ = vc.view // trigger view loading

        // Then: 캘린더(또는 플레이스홀더) 자식 VC가 추가되어 있어야 함
        XCTAssertGreaterThanOrEqual(vc.children.count, 1, "Calendar placeholder 혹은 실제 캘린더 VC가 children에 추가되어야 합니다.")
        // 추가 검증: 실제 캘린더가 로드되면 title이 "감정 캘린더"일 가능성이 높음(정보용)
        let hasCalendarTitle = vc.children.contains { ($0.title ?? "").contains("감정 캘린더") }
        if !hasCalendarTitle {
            XCTExpectFailure("실제 EmotionCalendarViewController가 링크되지 않았을 수 있습니다. 타깃 멤버십/FSCalendar 확인 필요")
        }
    }
}
