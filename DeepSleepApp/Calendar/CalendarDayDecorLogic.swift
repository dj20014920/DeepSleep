import Foundation

/// 캘린더 날짜 셀 데코레이션(그라데이션 테두리) 상태 계산 로직
enum CalendarDayDecorState {
    case none
    case premiumRing   // 미완료 할 일 존재 (현재/미래)
    case freeRing      // 과거에 할 일 있었음
}

struct CalendarDayDecorLogic {
    /// 날짜별 데코레이션 상태를 계산한다.
    /// - Parameters:
    ///   - date: 대상 일자
    ///   - todosForDate: 해당 일자와 매칭되는 할 일들
    ///   - now: 기준 현재 시각(테스트 용이성 위해 주입 가능)
    /// - Returns: 데코 상태
    static func state(for date: Date, todosForDate: [TodoItem], now: Date = Date()) -> CalendarDayDecorState {
        if todosForDate.isEmpty {
            return .none
        }

        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: now)
        let startOfDate = calendar.startOfDay(for: date)

        // 미완료 할 일 존재 여부
        let hasPending = todosForDate.contains { !$0.isCompleted }

        if startOfDate >= startOfToday {
            // 오늘 또는 미래: 미완료가 있으면 프리미엄 링
            return hasPending ? .premiumRing : .none
        } else {
            // 과거 날짜: 해당 날짜에 할 일이 있었던 경우 무료 링
            return .freeRing
        }
    }
}

