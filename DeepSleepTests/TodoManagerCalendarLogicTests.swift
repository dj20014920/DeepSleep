import XCTest
@testable import DeepSleep

final class TodoManagerCalendarLogicTests: XCTestCase {
    override func setUp() {
        super.setUp()
        // Clean persisted todos
        UserDefaults.standard.removeObject(forKey: "todoItems")
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "todoItems")
        super.tearDown()
    }

    func testGetTodos_OnSameDay_ReturnsItems() {
        let manager = TodoManager.shared
        let now = Date()
        let exp = expectation(description: "add")
        manager.addTodo(title: "테스트", dueDate: now, notes: nil, priority: 1) { _, _ in
            exp.fulfill()
        }
        wait(for: [exp], timeout: 2.0)

        let result = manager.getTodos(for: now)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.title, "테스트")
    }

    func testGetTodos_MultiDayRange_CoversDates() {
        let manager = TodoManager.shared
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        let twoDaysLater = cal.date(byAdding: .day, value: 2, to: start)!

        let exp = expectation(description: "add")
        manager.addTodo(title: "여행", dueDate: start, endTime: twoDaysLater, notes: nil, priority: 0) { _, _ in
            exp.fulfill()
        }
        wait(for: [exp], timeout: 2.0)

        // 중간 날짜
        let middle = cal.date(byAdding: .day, value: 1, to: start)!
        XCTAssertEqual(manager.getTodos(for: middle).count, 1)
        XCTAssertEqual(manager.getTodos(for: twoDaysLater).count, 1)
    }
}

