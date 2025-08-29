import XCTest
@testable import DeepSleep

final class CalendarDayDecorLogicTests: XCTestCase {
    private func makeTodo(
        title: String = "t",
        due: Date,
        end: Date? = nil,
        completed: Bool
    ) -> TodoItem {
        TodoItem(title: title, dueDate: due, endDate: end, isCompleted: completed)
    }

    func testState_NoTodos_None() {
        let date = Date()
        let result = CalendarDayDecorLogic.state(for: date, todosForDate: [])
        XCTAssertEqual(result, .none)
    }

    func testState_Today_WithPending_PremiumRing() {
        let now = Date()
        let todos = [makeTodo(due: now, completed: false)]
        let result = CalendarDayDecorLogic.state(for: now, todosForDate: todos, now: now)
        XCTAssertEqual(result, .premiumRing)
    }

    func testState_Today_AllCompleted_None() {
        let now = Date()
        let todos = [makeTodo(due: now, completed: true)]
        let result = CalendarDayDecorLogic.state(for: now, todosForDate: todos, now: now)
        XCTAssertEqual(result, .none)
    }

    func testState_Future_WithPending_PremiumRing() {
        let now = Date()
        let future = Calendar.current.date(byAdding: .day, value: 2, to: now)!
        let todos = [makeTodo(due: future, completed: false)]
        let result = CalendarDayDecorLogic.state(for: future, todosForDate: todos, now: now)
        XCTAssertEqual(result, .premiumRing)
    }

    func testState_Past_WithAnyTodo_FreeRing() {
        let now = Date()
        let past = Calendar.current.date(byAdding: .day, value: -2, to: now)!
        let todos = [makeTodo(due: past, completed: true)]
        let result = CalendarDayDecorLogic.state(for: past, todosForDate: todos, now: now)
        XCTAssertEqual(result, .freeRing)
    }
}

