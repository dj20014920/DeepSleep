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

            // 단일 출처 규칙 적용: TodoItem.shouldAutoComplete(at:) 사용
            let toComplete: [TodoItem] = incompletes.filter { $0.shouldAutoComplete(at: now) }
            guard !toComplete.isEmpty else { return }

            // 완료 처리 수행 (경쟁 상태 대비 3중 가드)
            for var item in toComplete {
                // 최종 안전성 체크: 여전히 자동완료 조건을 만족하는지(완료됨 제외, 하루종일 제외, 마감 도달) 확인
                if item.isCompleted || !item.shouldAutoComplete(at: now) { continue }
                item.complete()
                TodoManager.shared.updateTodo(item) { _, _ in /* no-op */ }
            }
        }
    }
}
