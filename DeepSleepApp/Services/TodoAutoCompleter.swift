import Foundation

/// 시간 지정된 할 일을 기한 도달 시 자동으로 완료 처리하는 경량 서비스
/// - 간편등록(하루 종일) 일정은 제외하고, 구체적인 시간(dueDate 시각)이 있는 항목만 대상으로 함
final class TodoAutoCompleter {
    static let shared = TodoAutoCompleter()
    private var timer: Timer?
    private let queue = DispatchQueue(label: "TodoAutoCompleter.queue", qos: .utility)
    private init() {}

    func start() {
        // 중복 시작 방지
        if timer != nil { return }
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
                self?.tick()
            }
            // 즉시 1회 수행 (앱 시작 직후 지연 없이 반영)
            self.tick()
        }
    }

    func stop() {
        DispatchQueue.main.async { [weak self] in
            self?.timer?.invalidate()
            self?.timer = nil
        }
    }

    private func tick() {
        queue.async {
            let now = Date()
            let incompletes = TodoManager.shared.getIncompleteTodos()
            guard !incompletes.isEmpty else { return }

            var toComplete: [TodoItem] = []
            for t in incompletes {
                // 간편등록(하루 종일)은 제외, 구체적 시간 지정만 자동 완료
                if !t.isAllDayQuickRegistration && t.dueDate <= now {
                    toComplete.append(t)
                }
            }
            guard !toComplete.isEmpty else { return }

            // 완료 처리 수행
            for var item in toComplete {
                item.complete()
                TodoManager.shared.updateTodo(item) { _, _ in /* no-op */ }
            }
        }
    }
}

