import XCTest
@testable import DeepSleep

final class TodoAdvicePromptFormatTests: XCTestCase {
    func testOverallAdvicePrompt_AllDayQuickRegistration_UsesTodayString() {
        // Given
        var item = TodoItem(title: "하루종일 정리", dueDate: Date(), endDate: nil, priority: 1, notes: "서랍/책상 정리")
        item.isAllDayQuickRegistration = true
        let prompt = TodoManager.buildOverallAdvicePrompt(
            date: Date(),
            todos: [item],
            allTodos: [item],
            weeklyContext: nil
        )

        // Then
        XCTAssertTrue(prompt.contains("시간: 오늘 중"))
        XCTAssertFalse(prompt.contains("시작:"))
        XCTAssertFalse(prompt.contains("종료:"))
        XCTAssertTrue(prompt.contains("우선순위:"))
        XCTAssertTrue(prompt.contains("카테고리:"))
        XCTAssertTrue(prompt.contains("메모:"))
    }

    func testOverallAdvicePrompt_TimedItem_ContainsStartEnd() {
        // Given
        let start = Date()
        var item = TodoItem(title: "회의", dueDate: start, endDate: start.addingTimeInterval(3600), priority: 2, notes: "자료 준비")
        item.isAllDayQuickRegistration = false
        let prompt = TodoManager.buildOverallAdvicePrompt(
            date: Date(),
            todos: [item],
            allTodos: [item],
            weeklyContext: nil
        )

        // Then
        XCTAssertTrue(prompt.contains("시작:"))
        XCTAssertTrue(prompt.contains("종료:"))
        XCTAssertTrue(prompt.contains("우선순위:"))
        XCTAssertTrue(prompt.contains("카테고리:"))
    }
}

