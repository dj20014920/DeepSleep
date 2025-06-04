import Foundation

struct TodoItem: Codable, Identifiable, Hashable {
    var id = UUID()
    var title: String
    var dueDate: Date
    var isCompleted: Bool = false
    var notes: String? = nil
    var priority: Int = 0 // 0: 낮음, 1: 보통, 2: 높음 (예시)
    var calendarEventIdentifier: String? = nil // EventKit 연동용
    var hasReceivedAIAdvice: Bool = false // AI 조언 수신 여부 (개별 조언 1회 제한용)
    var aiAdvices: [String]? = nil // AI가 생성한 조언들 저장 (여러 개 누적 가능)
    var aiAdvicesGeneratedAt: Date? = nil // AI 조언이 생성된 시간 (3개월 후 자동 삭제용)

    // 편의를 위한 computed property (예: 마감일 문자열)
    var dueDateString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: dueDate)
    }
    
    // 모든 프로퍼티를 포함하는 초기화 메서드
    init(id: UUID = UUID(), 
         title: String, 
         dueDate: Date, 
         isCompleted: Bool = false, 
         notes: String? = nil, 
         priority: Int = 0, 
         calendarEventIdentifier: String? = nil, 
         hasReceivedAIAdvice: Bool = false,
         aiAdvices: [String]? = nil,
         aiAdvicesGeneratedAt: Date? = nil) { // aiAdvicesGeneratedAt 파라미터 추가
        self.id = id
        self.title = title
        self.dueDate = dueDate
        self.isCompleted = isCompleted
        self.notes = notes
        self.priority = priority
        self.calendarEventIdentifier = calendarEventIdentifier
        self.hasReceivedAIAdvice = hasReceivedAIAdvice
        self.aiAdvices = aiAdvices
        self.aiAdvicesGeneratedAt = aiAdvicesGeneratedAt // 할당 추가
    }
} 