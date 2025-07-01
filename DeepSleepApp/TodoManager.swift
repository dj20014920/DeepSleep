import Foundation
import UserNotifications
import EventKit

// MARK: - Custom Errors for TodoManager
enum TodoManagerError: LocalizedError {
    case calendarAccessDenied(String)
    case calendarAccessRestricted(String)
    case calendarWriteOnlyAccess(String)
    case unknownCalendarAuthorization(String)
    case eventSaveFailed(Error)
    case eventRemoveFailed(Error)
    case eventFetchFailed(String)

    var errorDescription: String? {
        switch self {
        case .calendarAccessDenied(let message),
             .calendarAccessRestricted(let message),
             .calendarWriteOnlyAccess(let message),
             .unknownCalendarAuthorization(let message),
             .eventFetchFailed(let message):
            return message
        case .eventSaveFailed(let underlyingError):
            return "캘린더 이벤트 저장에 실패했습니다: \\(underlyingError.localizedDescription)"
        case .eventRemoveFailed(let underlyingError):
            return "캘린더 이벤트 삭제에 실패했습니다: \\(underlyingError.localizedDescription)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .calendarAccessDenied, .calendarAccessRestricted, .calendarWriteOnlyAccess:
            return "캘린더 접근 권한을 확인하려면 '설정' 앱으로 이동하세요."
        default:
            return "문제가 지속되면 앱을 재시작하거나 지원팀에 문의하세요."
        }
    }
}

class TodoManager {
    static let shared = TodoManager()
    private let todosKey = "todoItems"
    private let notificationCenter = UNUserNotificationCenter.current()
    private let eventStore = EKEventStore()

    private init() {
        // 앱 초기화 시 또는 CRUD 작업 직전에 권한 확인/요청
    }

    // MARK: - Calendar Access
    internal func requestCalendarAccessIfNeeded(completion: @escaping (Bool, Error?) -> Void) {
        let status = EKEventStore.authorizationStatus(for: .event)
        switch status {
        case .authorized, .fullAccess:
            print("✅ EKEventStore: 접근 권한 이미 있음")
            completion(true, nil)
        case .notDetermined:
            let requestHandler: (Bool, Error?) -> Void = { [weak self] granted, error in
                self?.handleCalendarAccessResponse(granted: granted, error: error, completion: completion)
            }
            if #available(iOS 17.0, *) {
                eventStore.requestFullAccessToEvents(completion: requestHandler)
            } else {
                eventStore.requestAccess(to: .event, completion: requestHandler)
            }
        case .denied:
            print("🔴 EKEventStore: 접근 권한 거부됨.")
            completion(false, TodoManagerError.calendarAccessDenied("캘린더 접근 권한이 거부되었습니다. 할 일을 캘린더에 연동하려면 설정에서 권한을 허용해야 합니다."))
        case .restricted:
            print("🔴 EKEventStore: 접근 권한 제한됨.")
            completion(false, TodoManagerError.calendarAccessRestricted("캘린더 접근이 시스템에 의해 제한되었습니다."))
        case .writeOnly:
             print("🟡 EKEventStore: 쓰기 전용 권한. 이벤트 수정/읽기를 위해 전체 접근 권한이 필요할 수 있습니다.")
             completion(false, TodoManagerError.calendarWriteOnlyAccess("캘린더 쓰기 전용 권한입니다. 이벤트 수정 및 읽기를 위해 전체 접근 권한이 필요할 수 있습니다. 설정에서 권한을 변경해주세요."))
        @unknown default:
            print("🔴 EKEventStore: 알 수 없는 권한 상태")
            completion(false, TodoManagerError.unknownCalendarAuthorization("알 수 없는 캘린더 접근 권한 상태입니다."))
        }
    }
    
    private func handleCalendarAccessResponse(granted: Bool, error: Error?, completion: (Bool, Error?) -> Void) {
        if granted {
            print("✅ EKEventStore: 접근 권한 허용됨")
        } else if let error = error {
            print("🔴 EKEventStore: 접근 권한 요청 오류: \(error.localizedDescription)")
        } else {
            print("🔴 EKEventStore: 접근 권한 거부됨 (handle)")
        }
        completion(granted, error)
    }

    // MARK: - CRUD Operations

    func addTodo(title: String, dueDate: Date, startTime: Date? = nil, endTime: Date? = nil, notes: String? = nil, priority: Int = 0, completion: @escaping (TodoItem?, Error?) -> Void) {
        requestCalendarAccessIfNeeded { [weak self] granted, accessError in
            guard let self = self else { return }
            
            var currentTodos = self.loadTodos()
            var newTodo = TodoItem(title: title, dueDate: dueDate, endDate: endTime, notes: notes, priority: priority)

            if granted {
                self.addEventToCalendar(todo: newTodo) { eventIdentifier, eventError in
                    if let eventError = eventError {
                        // 캘린더 이벤트 추가 실패 시에도 로컬에는 저장하고 에러 전달
                        currentTodos.append(newTodo)
                        self.saveTodos(currentTodos)
                        self.scheduleNotification(for: newTodo)
                        completion(newTodo, eventError) // 에러 전달
                        return
                    }
                    newTodo.calendarEventIdentifier = eventIdentifier
                    currentTodos.append(newTodo)
                    self.saveTodos(currentTodos)
                    self.scheduleNotification(for: newTodo)
                    completion(newTodo, nil) // 성공
                }
            } else {
                // 캘린더 접근 불가 시 로컬에만 저장하고 에러(또는 정보) 전달
                currentTodos.append(newTodo)
                self.saveTodos(currentTodos)
                self.scheduleNotification(for: newTodo)
                completion(newTodo, accessError ?? TodoManagerError.calendarAccessDenied("캘린더 접근 권한이 없어 로컬에만 저장되었습니다."))
            }
        }
    }

    func loadTodos() -> [TodoItem] {
        guard let data = UserDefaults.standard.data(forKey: todosKey) else { return [] }
        do {
            let todos = try JSONDecoder().decode([TodoItem].self, from: data)
            return todos.sorted(by: { $0.dueDate < $1.dueDate })
        } catch {
            print("Error decoding todos: \(error)")
            return []
        }
    }

    func updateTodo(_ todoToUpdate: TodoItem, completion: @escaping (TodoItem?, Error?) -> Void) {
        requestCalendarAccessIfNeeded { [weak self] granted, accessError in
            guard let self = self else { return }
            
            var currentTodos = self.loadTodos()
            guard let index = currentTodos.firstIndex(where: { $0.id == todoToUpdate.id }) else {
                completion(nil, NSError(domain: "TodoManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "수정할 할 일을 찾을 수 없습니다."]))
                return
            }
            
            self.removeNotification(for: currentTodos[index])
            
            var mutableTodo = todoToUpdate

            if granted {
                self.updateEventInCalendar(todo: mutableTodo) { success, updatedEventIdentifier, eventError in
                    if let eventError = eventError {
                         // 캘린더 이벤트 업데이트 실패 시에도 로컬에는 저장하고 에러 전달
                        currentTodos[index] = mutableTodo
                        self.saveTodos(currentTodos)
                        self.scheduleNotification(for: mutableTodo)
                        completion(mutableTodo, eventError)
                        return
                    }
                    if success {
                        mutableTodo.calendarEventIdentifier = updatedEventIdentifier
                    }
                    currentTodos[index] = mutableTodo
                    self.saveTodos(currentTodos)
                    self.scheduleNotification(for: mutableTodo)
                    completion(mutableTodo, nil)
                }
            } else {
                currentTodos[index] = mutableTodo
                self.saveTodos(currentTodos)
                self.scheduleNotification(for: mutableTodo)
                completion(mutableTodo, accessError ?? TodoManagerError.calendarAccessDenied("캘린더 접근 권한이 없어 로컬 변경사항만 저장되었습니다."))
            }
        }
    }

    func updateTodoItem(_ todoToUpdate: TodoItem) {
        updateTodo(todoToUpdate) { _, _ in
            // The synchronous call doesn't handle completion, so we can leave this empty.
            // Consider adding logging or error handling here in the future.
        }
    }

    func deleteTodo(withId id: UUID, completion: @escaping (Bool, Error?) -> Void) {
        requestCalendarAccessIfNeeded { [weak self] granted, accessError in
            guard let self = self else { return }
            
            var currentTodos = self.loadTodos()
            guard let todoToDelete = currentTodos.first(where: { $0.id == id }) else {
                completion(false, NSError(domain: "TodoManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "삭제할 할 일을 찾을 수 없습니다."]))
                return
            }

            self.removeNotification(for: todoToDelete)
            
            if granted, let eventIdentifier = todoToDelete.calendarEventIdentifier {
                self.removeEventFromCalendar(identifier: eventIdentifier) { success, eventError in
                    if let eventError = eventError {
                        // 캘린더 이벤트 삭제 실패 시에도 로컬에서는 삭제하고 에러 전달
                        currentTodos.removeAll(where: { $0.id == id })
                        self.saveTodos(currentTodos)
                        completion(true, eventError) // 로컬 삭제는 성공했으므로 true, 그러나 캘린더 에러 전달
                        return
                    }
                    // 캘린더 이벤트 삭제 성공 또는 원래 없었음
                    currentTodos.removeAll(where: { $0.id == id })
                    self.saveTodos(currentTodos)
                    completion(true, nil)
                }
            } else {
            currentTodos.removeAll(where: { $0.id == id })
            self.saveTodos(currentTodos)
                completion(true, accessError) // 캘린더 접근 불가 에러 전달 가능성
            }
        }
    }
    
    func toggleCompletion(for todoId: UUID, completion: @escaping (TodoItem?, Error?) -> Void) {
        var currentTodos = loadTodos()
        guard let index = currentTodos.firstIndex(where: { $0.id == todoId }) else {
            completion(nil, NSError(domain: "TodoManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "완료 상태를 변경할 할 일을 찾을 수 없습니다."]))
            return
        }
        
            currentTodos[index].isCompleted.toggle()
        let todo = currentTodos[index]
        saveTodos(currentTodos) // 로컬 저장 먼저
            
        // 알림 업데이트
            if todo.isCompleted {
                removeNotification(for: todo)
            } else {
                scheduleNotification(for: todo)
            }
        
        // 캘린더 이벤트 제목 업데이트
        if let eventIdentifier = todo.calendarEventIdentifier {
            requestCalendarAccessIfNeeded { [weak self] granted, accessError in
                guard let self = self else { 
                    completion(todo, NSError(domain: "TodoManager", code: 500, userInfo: [NSLocalizedDescriptionKey: "내부 오류 발생"])) 
                    return 
                }
                if granted {
                    self.updateCalendarEventTitleForCompletion(eventIdentifier: eventIdentifier, todo: todo) { updateError in
                        completion(todo, updateError) // 성공 시 updateError는 nil
                    }
                } else {
                    completion(todo, accessError ?? TodoManagerError.calendarAccessDenied("캘린더 접근 권한이 없어 완료 상태가 캘린더에 반영되지 않았습니다."))
                }
            }
        } else {
            completion(todo, nil) // 캘린더 이벤트 없으므로 로컬 변경으로 성공 처리
        }
    }

    // MARK: - Private Helper
    private func saveTodos(_ todos: [TodoItem]) {
        do {
            let data = try JSONEncoder().encode(todos)
            UserDefaults.standard.set(data, forKey: todosKey)
        } catch {
            print("Error encoding todos: \(error)")
        }
    }
    
    // MARK: - Filtering (예시)
    func getTodos(for date: Date) -> [TodoItem] {
        let allTodos = loadTodos()
        return allTodos.filter { todo in
            // 기본적으로 dueDate가 같은 날인지 확인
            if Calendar.current.isDate(todo.dueDate, inSameDayAs: date) {
                return true
            }
            
            // 연속 일정인 경우 날짜 범위 내에 있는지 확인
            if let endDate = todo.endDate {
                let calendar = Calendar.current
                let startDay = calendar.startOfDay(for: todo.dueDate)
                let endDay = calendar.startOfDay(for: endDate)
                let checkDay = calendar.startOfDay(for: date)
                
                return checkDay >= startDay && checkDay <= endDay
            }
            
            return false
        }
    }
    
    func getIncompleteTodos() -> [TodoItem] {
        return loadTodos().filter { !$0.isCompleted }
    }

    // MARK: - Notification Scheduling
    private func scheduleNotification(for todo: TodoItem) {
        guard !todo.isCompleted else {
            removeNotification(for: todo)
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "할 일 미리 알림 ⏰"
        content.sound = .default
        content.userInfo = ["todoID": todo.id.uuidString]
        
        // 알림 시간 계산
        let notificationTime: Date
        let calendar = Calendar.current
        
        // 마감일 1시간 전으로 알림 설정
        guard let oneHourBefore = calendar.date(byAdding: .hour, value: -1, to: todo.dueDate) else { return }
        notificationTime = oneHourBefore
        
        if let endDate = todo.endDate {
            // 여러 날 일정인 경우
            content.body = "'\(todo.title)' 시작 1시간 전입니다! (\(todo.dateRangeString))"
        } else {
            // 하루 일정인 경우
            content.body = "'\(todo.title)' 마감 1시간 전입니다!"
        }
        
        if notificationTime <= Date() {
            print("🔔 알림 스케줄링 건너뜀: 알림 시간(\(notificationTime))이 이미 지남 (할 일: \(todo.title))")
            return
        }

        let triggerDate = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: notificationTime)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)

        let request = UNNotificationRequest(identifier: todo.id.uuidString, content: content, trigger: trigger)

        notificationCenter.add(request) { error in
            if let error = error {
                print("🔔 알림 스케줄링 오류 (\(todo.title)): \(error.localizedDescription)")
            } else {
                print("🔔 알림 스케줄링 성공: \(todo.title) (ID: \(todo.id.uuidString)) at \(notificationTime)")
            }
        }
    }

    private func removeNotification(for todo: TodoItem) {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [todo.id.uuidString])
        print("🔔 예정된 알림 제거: \(todo.title) (ID: \(todo.id.uuidString))")
    }
    
    func rescheduleAllNotifications() {
        let todos = loadTodos()
        notificationCenter.removeAllPendingNotificationRequests()
        print("🔔 모든 예정된 알림 초기화 후 재스케줄링 시작")
        for todo in todos {
            scheduleNotification(for: todo)
        }
        print("🔔 모든 알림 재스케줄링 완료")
    }

    // MARK: - EventKit Interaction Methods
    private func addEventToCalendar(todo: TodoItem, completion: @escaping (String?, Error?) -> Void) {
        let event = EKEvent(eventStore: eventStore)
        event.title = todo.isCompleted ? "[완료] \(todo.title)" : todo.title
        
        // 시간 설정 처리
        if let endDate = todo.endDate {
            // 여러 날 일정
            event.isAllDay = true
            event.startDate = Calendar.current.startOfDay(for: todo.dueDate)
            event.endDate = Calendar.current.startOfDay(for: endDate)
        } else {
            // 하루 일정 (시간 지정됨)
            event.isAllDay = false
            event.startDate = todo.dueDate
            // 1시간 이벤트로 설정
            event.endDate = Calendar.current.date(byAdding: .hour, value: 1, to: todo.dueDate) ?? todo.dueDate
        }
        
        event.notes = todo.notes
        event.calendar = eventStore.defaultCalendarForNewEvents

        do {
            try eventStore.save(event, span: .thisEvent)
            print("✅ EKEventStore: 이벤트 추가 성공 - \(event.title ?? ""), ID: \(event.eventIdentifier ?? "N/A")")
            completion(event.eventIdentifier, nil)
        } catch {
            print("�� EKEventStore: 이벤트 추가 실패 - \(error.localizedDescription)")
            completion(nil, TodoManagerError.eventSaveFailed(error))
        }
    }

    private func updateEventInCalendar(todo: TodoItem, completion: @escaping (Bool, String?, Error?) -> Void) {
        guard let eventIdentifier = todo.calendarEventIdentifier, 
              let event = eventStore.event(withIdentifier: eventIdentifier) else {
            // 기존 이벤트 ID가 없거나, ID로 이벤트를 찾을 수 없는 경우 새로 추가 시도 (선택적)
            // 여기서는 그냥 실패 처리 또는 새 이벤트 추가 로직 호출
            print("🟡 EKEventStore: 업데이트할 이벤트 ID(\(todo.calendarEventIdentifier ?? "nil"))를 찾을 수 없거나 이벤트 없음. 새로 추가를 시도할 수 있습니다.")
            // completion(false, nil, TodoManagerError.eventFetchFailed("업데이트할 캘린더 이벤트를 찾지 못했습니다."))
            // 또는 새 이벤트 추가:
            addEventToCalendar(todo: todo) { newIdentifier, error in
                completion(newIdentifier != nil, newIdentifier, error)
            }
            return
        }
        
        event.title = todo.isCompleted ? "[완료] \(todo.title)" : todo.title
        
        // 시간 설정 처리
        if let endDate = todo.endDate {
            // 여러 날 일정
            event.isAllDay = true
            event.startDate = Calendar.current.startOfDay(for: todo.dueDate)
            event.endDate = Calendar.current.startOfDay(for: endDate)
        } else {
            // 하루 일정 (시간 지정됨)
            event.isAllDay = false
            event.startDate = todo.dueDate
            // 1시간 이벤트로 설정
            event.endDate = Calendar.current.date(byAdding: .hour, value: 1, to: todo.dueDate) ?? todo.dueDate
        }
        
        event.notes = todo.notes
            do {
                try eventStore.save(event, span: .thisEvent)
            print("✅ EKEventStore: 이벤트 업데이트 성공 - \(event.title ?? "")")
            completion(true, event.eventIdentifier, nil)
            } catch {
                print("🔴 EKEventStore: 이벤트 업데이트 실패 - \(error.localizedDescription)")
            completion(false, todo.calendarEventIdentifier, TodoManagerError.eventSaveFailed(error))
            }
    }

    private func removeEventFromCalendar(identifier: String, completion: @escaping (Bool, Error?) -> Void) {
        guard let event = eventStore.event(withIdentifier: identifier) else {
            print("🟡 EKEventStore: 삭제할 이벤트 ID(\(identifier))에 해당하는 이벤트를 찾을 수 없음.")
            completion(true, nil) // 이미 없으므로 성공으로 간주
            return
        }
        do {
            try eventStore.remove(event, span: .thisEvent)
            print("✅ EKEventStore: 이벤트 삭제 성공 - ID: \(identifier)")
            completion(true, nil)
        } catch {
            print("🔴 EKEventStore: 이벤트 삭제 실패 - \(error.localizedDescription)")
            completion(false, TodoManagerError.eventRemoveFailed(error))
        }
    }

    // 캘린더 이벤트 제목에 [완료] 상태 업데이트하는 헬퍼 함수
    private func updateCalendarEventTitleForCompletion(eventIdentifier: String, todo: TodoItem, completion: @escaping (Error?) -> Void) {
        guard let event = eventStore.event(withIdentifier: eventIdentifier) else {
            completion(TodoManagerError.eventFetchFailed("캘린더에서 해당 일정을 찾을 수 없습니다."))
            return
        }
        
        let originalTitle = event.title?.replacingOccurrences(of: "[완료] ", with: "") ?? todo.title // 원본 제목 최대한 복원
        event.title = todo.isCompleted ? "[완료] \(originalTitle)" : originalTitle
        
        do {
            try eventStore.save(event, span: .thisEvent)
            print("✅ EKEventStore: 이벤트 완료 상태('제목') 업데이트 성공 - \(event.title ?? "")")
            completion(nil)
        } catch {
            print("🔴 EKEventStore: 이벤트 완료 상태('제목') 업데이트 실패 - \(error.localizedDescription)")
            completion(TodoManagerError.eventSaveFailed(error))
        }
    }

    // MARK: - 기존 할 일 마이그레이션 (선택적)
    func migrateExistingTodosToCalendar(completion: ((Int, [Error]) -> Void)?) {
        let todosToMigrate = loadTodos().filter { $0.calendarEventIdentifier == nil && !$0.isCompleted }
        if todosToMigrate.isEmpty {
            print("ℹ️ EKEventStore: 캘린더에 마이그레이션할 기존 할 일 없음.")
            completion?(0, [])
            return
        }

        print("ℹ️ EKEventStore: 기존 할 일 \(todosToMigrate.count)개 캘린더 마이그레이션 시작...")
        var migratedCount = 0
        var errors: [Error] = []
        let group = DispatchGroup()

        requestCalendarAccessIfNeeded { [weak self] granted, accessError in
            guard let self = self else { 
                completion?(0, [NSError(domain: "TodoManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "내부 오류."])])
                return
            }
            if !granted {
                print("🔴 EKEventStore: 마이그레이션 위한 캘린더 접근 권한 없음.")
                errors.append(accessError ?? TodoManagerError.calendarAccessDenied("캘린더 접근 권한이 없어 마이그레이션이 중단되었습니다."))
                completion?(0, errors)
                return
            }

            for todoFromLoop in todosToMigrate { // 'let'으로 루프 변수 선언
                group.enter()
                // todoFromLoop는 값 타입(struct)이므로 addEventToCalendar에 복사본이 전달됨
                self.addEventToCalendar(todo: todoFromLoop) { eventIdentifier, error in
                    if let error = error {
                        errors.append(error)
                    } else if let eventIdentifier = eventIdentifier {
                        // 캘린더 이벤트 ID를 포함하여 저장할 새 TodoItem 인스턴스 생성
                        var todoToUpdateInStorage = todoFromLoop 
                        todoToUpdateInStorage.calendarEventIdentifier = eventIdentifier
                        
                        var allCurrentTodos = self.loadTodos()
                        if let indexInStorage = allCurrentTodos.firstIndex(where: { $0.id == todoToUpdateInStorage.id }) {
                            allCurrentTodos[indexInStorage] = todoToUpdateInStorage
                            self.saveTodos(allCurrentTodos)
                            migratedCount += 1
        } else {
                            // 이론적으로는 todosToMigrate에서 가져왔으므로 항상 찾아야 함
                            errors.append(NSError(domain: "TodoManagerMigration", code: 1, userInfo: [NSLocalizedDescriptionKey: "마이그레이션 중인 할 일(\(todoToUpdateInStorage.title))을 전체 목록에서 찾을 수 없습니다."]))
                        }
                    }
                    group.leave()
                }
            }

            group.notify(queue: .main) {
                print("✅ EKEventStore: 기존 할 일 마이그레이션 완료. 성공: \(migratedCount)/\(todosToMigrate.count), 오류: \(errors.count)개")
                completion?(migratedCount, errors)
            }
        }
    }

    // MARK: - AI Advice Cleanup (New)
    public func cleanupOldAIAdvices() {
        var currentTodos = loadTodos()
        var didChange = false
        let threeMonthsAgo = Calendar.current.date(byAdding: .month, value: -3, to: Date()) ?? Date() // 3개월 전 날짜, 실패 시 현재 날짜 (이 경우 아무것도 삭제 안됨)
        var cleanedCount = 0

        print("⏳ AI 조언 정리 시작... 3개월 이전 기준일: \(threeMonthsAgo)")

        for (index, var todo) in currentTodos.enumerated() { // 'var'로 선언하여 수정 가능하게 함
            if let generatedAt = todo.aiAdvicesGeneratedAt, generatedAt < threeMonthsAgo {
                if todo.aiAdvices != nil || todo.aiAdvicesGeneratedAt != nil || todo.hasReceivedAIAdvice != false {
                    print("🗑️ ID \(todo.id) 할 일의 오래된 AI 조언 삭제. 생성일: \(generatedAt)")
                    todo.aiAdvices = nil
                    todo.aiAdvicesGeneratedAt = nil
                    todo.hasReceivedAIAdvice = false // 다시 조언 받을 수 있도록
                    currentTodos[index] = todo // 수정된 항목을 배열에 다시 할당
                    didChange = true
                    cleanedCount += 1
                }
            }
        }

        if didChange {
            saveTodos(currentTodos)
            print("💾 총 \(cleanedCount)개 할 일의 오래된 AI 조언 정리 및 저장 완료.")
        } else {
            print("👍 오래된 AI 조언 없음. 모든 조언이 최신 상태입니다.")
        }
    }
} 
