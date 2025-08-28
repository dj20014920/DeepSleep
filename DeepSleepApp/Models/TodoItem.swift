import Foundation

/// 할 일 항목 모델
struct TodoItem: Codable, Identifiable, Hashable {
    let id: UUID
    var title: String
    var isCompleted: Bool
    var priority: Int // 기존 코드와 호환성을 위해 Int 타입 유지
    var dueDate: Date // 기존 코드에서 사용하는 필드
    var endDate: Date? // 기존 코드에서 사용하는 필드
    var createdAt: Date
    var completedAt: Date?
    var category: Category?
    var notes: String?
    
    // 기존 코드와 호환성을 위한 추가 필드들
    var calendarEventIdentifier: String?
    var aiAdvices: [String]?
    var aiAdvicesGeneratedAt: Date?
    var hasReceivedAIAdvice: Bool
    
    // MARK: - Coding Keys
    enum CodingKeys: String, CodingKey {
        case id, title, isCompleted, priority, dueDate, endDate
        case createdAt, completedAt, category, notes
        case calendarEventIdentifier, aiAdvices, aiAdvicesGeneratedAt, hasReceivedAIAdvice
    }
    
    // MARK: - Custom Decoding for Backward Compatibility
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        isCompleted = try container.decode(Bool.self, forKey: .isCompleted)
        priority = try container.decode(Int.self, forKey: .priority)
        dueDate = try container.decode(Date.self, forKey: .dueDate)
        endDate = try container.decodeIfPresent(Date.self, forKey: .endDate)
        
        // createdAt이 없는 기존 데이터를 위한 호환성 처리
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        
        completedAt = try container.decodeIfPresent(Date.self, forKey: .completedAt)
        category = try container.decodeIfPresent(Category.self, forKey: .category)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        calendarEventIdentifier = try container.decodeIfPresent(String.self, forKey: .calendarEventIdentifier)
        aiAdvices = try container.decodeIfPresent([String].self, forKey: .aiAdvices)
        aiAdvicesGeneratedAt = try container.decodeIfPresent(Date.self, forKey: .aiAdvicesGeneratedAt)
        hasReceivedAIAdvice = try container.decodeIfPresent(Bool.self, forKey: .hasReceivedAIAdvice) ?? false
    }
    
    enum Priority: String, Codable, CaseIterable {
        case low = "low"
        case medium = "medium"
        case high = "high"
        
        var displayName: String {
            switch self {
            case .low:
                return "낮음"
            case .medium:
                return "보통"
            case .high:
                return "높음"
            }
        }
        
        var sortOrder: Int {
            switch self {
            case .high:
                return 0
            case .medium:
                return 1
            case .low:
                return 2
            }
        }
    }
    
    enum Category: String, Codable, CaseIterable {
        case sleep = "sleep"
        case wellness = "wellness"
        case work = "work"
        case personal = "personal"
        case health = "health"
        
        var displayName: String {
            switch self {
            case .sleep:
                return "수면"
            case .wellness:
                return "웰니스"
            case .work:
                return "업무"
            case .personal:
                return "개인"
            case .health:
                return "건강"
            }
        }
        
        var emoji: String {
            switch self {
            case .sleep:
                return "😴"
            case .wellness:
                return "🧘‍♀️"
            case .work:
                return "💼"
            case .personal:
                return "👤"
            case .health:
                return "🏥"
            }
        }
    }
    
    // MARK: - Initialization
    init(
        id: UUID = UUID(),
        title: String,
        dueDate: Date = Date(),
        endDate: Date? = nil,
        isCompleted: Bool = false,
        priority: Int = 0,
        category: Category? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.title = title
        self.dueDate = dueDate
        self.endDate = endDate
        self.isCompleted = isCompleted
        self.priority = priority
        self.createdAt = Date()
        self.completedAt = nil
        self.category = category
        self.notes = notes
        self.calendarEventIdentifier = nil
        self.aiAdvices = nil
        self.aiAdvicesGeneratedAt = nil
        self.hasReceivedAIAdvice = false
    }
    
    // MARK: - Methods
    mutating func toggle() {
        isCompleted.toggle()
        completedAt = isCompleted ? Date() : nil
    }
    
    mutating func complete() {
        isCompleted = true
        completedAt = Date()
    }
    
    mutating func uncomplete() {
        isCompleted = false
        completedAt = nil
    }
    
    var displayTitle: String {
        let prefix = category?.emoji ?? ""
        return prefix.isEmpty ? title : "\(prefix) \(title)"
    }
    
    var isOverdue: Bool {
        // 할 일 항목이 24시간 이상 미완료 상태인 경우
        return !isCompleted && Date().timeIntervalSince(createdAt) > 24 * 60 * 60
    }
    
    var completionTimeInterval: TimeInterval? {
        guard let completedAt = completedAt else { return nil }
        return completedAt.timeIntervalSince(createdAt)
    }
    
    var canReceiveAdvice: Bool {
        return !hasReceivedAIAdvice && !isCompleted
    }
    
    var dueDateString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: dueDate)
    }
    
    mutating func requestAdvice() -> Bool {
        guard canReceiveAdvice else { return false }
        hasReceivedAIAdvice = true
        return true
    }
    
    var adviceUsageText: String {
        if hasReceivedAIAdvice {
            return "사용됨"
        } else {
            return "사용 가능"
        }
    }
    
    var adviceRequestCount: Int {
        return hasReceivedAIAdvice ? 1 : 0
    }
    
    var maxAdviceCount: Int {
        return 3 // 최대 3회까지 조언 가능
    }
}

// MARK: - TodoItem Extensions
extension TodoItem {
    /// 기본 할 일 항목들 생성
    static func createDefaultItems() -> [TodoItem] {
        let today = Date()
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today) ?? today
        
        return [
            TodoItem(
                title: "오늘의 감정 체크하기",
                dueDate: today,
                priority: 2, // high
                category: .wellness
            ),
            TodoItem(
                title: "10분 명상하기",
                dueDate: today,
                priority: 1, // medium
                category: .wellness
            ),
            TodoItem(
                title: "취침 전 스마트폰 끄기",
                dueDate: tomorrow,
                priority: 1, // medium
                category: .sleep
            ),
            TodoItem(
                title: "물 8잔 마시기",
                dueDate: today,
                priority: 0, // low
                category: .health
            )
        ]
    }
    
    /// 수면 관련 할 일 항목들
    static func createSleepItems() -> [TodoItem] {
        let today = Date()
        
        return [
            TodoItem(
                title: "취침 시간 정하기",
                dueDate: today,
                priority: 2, // high
                category: .sleep
            ),
            TodoItem(
                title: "침실 온도 조절하기",
                dueDate: today,
                priority: 1, // medium
                category: .sleep
            ),
            TodoItem(
                title: "수면 음악 준비하기",
                dueDate: today,
                priority: 0, // low
                category: .sleep
            )
        ]
    }
    
    /// 웰니스 관련 할 일 항목들
    static func createWellnessItems() -> [TodoItem] {
        let today = Date()
        
        return [
            TodoItem(
                title: "감정 일기 쓰기",
                dueDate: today,
                priority: 2, // high
                category: .wellness
            ),
            TodoItem(
                title: "스트레칭 하기",
                dueDate: today,
                priority: 1, // medium
                category: .wellness
            ),
            TodoItem(
                title: "감사 인사 3가지 생각하기",
                dueDate: today,
                priority: 0, // low
                category: .wellness
            )
        ]
    }
}

// MARK: - TodoItem Manager
class TodoItemManager {
    static let shared = TodoItemManager()
    
    private let userDefaults = UserDefaults.standard
    private let todosKey = "SavedTodoItems"
    
    private init() {}
    
    // MARK: - Persistence
    func saveTodos(_ todos: [TodoItem]) {
        do {
            let data = try JSONEncoder().encode(todos)
            userDefaults.set(data, forKey: todosKey)
            UnifiedLogger.shared.logTodo("Saved \(todos.count) todo items")
        } catch {
            UnifiedLogger.shared.error("Failed to save todos: \(error)")
        }
    }
    
    func loadTodos() -> [TodoItem] {
        guard let data = userDefaults.data(forKey: todosKey) else {
            UnifiedLogger.shared.logTodo("No saved todos found, returning default items")
            return TodoItem.createDefaultItems()
        }
        
        do {
            let todos = try JSONDecoder().decode([TodoItem].self, from: data)
            UnifiedLogger.shared.logTodo("Loaded \(todos.count) todo items")
            return todos
        } catch {
            UnifiedLogger.shared.error("Failed to load todos: \(error)")
            return TodoItem.createDefaultItems()
        }
    }
    
    // MARK: - Operations
    func addTodo(_ todo: TodoItem, to todos: inout [TodoItem]) {
        todos.append(todo)
        saveTodos(todos)
        UnifiedLogger.shared.logTodo("Added todo: \(todo.title)")
    }
    
    func removeTodo(at index: Int, from todos: inout [TodoItem]) {
        guard index < todos.count else { return }
        let removedTodo = todos.remove(at: index)
        saveTodos(todos)
        UnifiedLogger.shared.logTodo("Removed todo: \(removedTodo.title)")
    }
    
    func toggleTodo(at index: Int, in todos: inout [TodoItem]) {
        guard index < todos.count else { return }
        todos[index].toggle()
        saveTodos(todos)
        UnifiedLogger.shared.logTodo("Toggled todo: \(todos[index].title) -> \(todos[index].isCompleted ? "completed" : "incomplete")")
    }
    
    func updateTodo(at index: Int, with newTodo: TodoItem, in todos: inout [TodoItem]) {
        guard index < todos.count else { return }
        todos[index] = newTodo
        saveTodos(todos)
        UnifiedLogger.shared.logTodo("Updated todo: \(newTodo.title)")
    }
    
    // MARK: - Statistics
    func getCompletionStats(for todos: [TodoItem]) -> TodoCompletionStats {
        let total = todos.count
        let completed = todos.filter { $0.isCompleted }.count
        let pending = total - completed
        let completionRate = total > 0 ? Double(completed) / Double(total) : 0.0
        
        return TodoCompletionStats(
            total: total,
            completed: completed,
            pending: pending,
            completionRate: completionRate
        )
    }
}

// MARK: - Supporting Types
struct TodoCompletionStats {
    let total: Int
    let completed: Int
    let pending: Int
    let completionRate: Double
    
    var completionPercentage: Int {
        return Int(completionRate * 100)
    }
} 
