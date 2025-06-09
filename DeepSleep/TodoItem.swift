import Foundation

struct TodoItem: Codable, Identifiable, Hashable {
    var id = UUID()
    var title: String
    var dueDate: Date
    var endDate: Date? = nil   // 종료일 (여러 날 일정용, 선택사항)
    var isCompleted: Bool = false
    var notes: String? = nil
    var priority: Int = 0 // 0: 낮음, 1: 보통, 2: 높음
    var calendarEventIdentifier: String? = nil // EventKit 연동용
    var hasReceivedAIAdvice: Bool = false // AI 조언 수신 여부 (개별 조언 1회 제한용)
    var aiAdvices: [String]? = nil // AI가 생성한 조언들 저장 (여러 개 누적 가능)
    var aiAdvicesGeneratedAt: Date? = nil // AI 조언이 생성된 시간 (3개월 후 자동 삭제용)

    // 편의를 위한 computed property
    var dueDateString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter.string(from: dueDate)
    }
    
    // 종료일 문자열
    var endDateString: String? {
        guard let endDate = endDate else { return nil }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter.string(from: endDate)
    }
    
    // 기간 문자열 (예: "12월 9일 - 12월 11일" 또는 "12월 9일")
    var dateRangeString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "ko_KR")
        
        if let endDate = endDate {
            let startString = formatter.string(from: dueDate)
            let endString = formatter.string(from: endDate)
            return "\(startString) - \(endString)"
        } else {
            return formatter.string(from: dueDate)
        }
    }
    
    // 기간 (일 단위)
    var durationInDays: Int {
        guard let endDate = endDate else { return 1 }
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: dueDate, to: endDate)
        return max(1, (components.day ?? 0) + 1) // 최소 1일, +1은 당일 포함
    }
    
    // 여러 날 일정인지 확인
    var isMultiDayEvent: Bool {
        return endDate != nil
    }
    
    // 모든 프로퍼티를 포함하는 초기화 메서드
    init(id: UUID = UUID(), 
         title: String, 
         dueDate: Date, 
         endDate: Date? = nil,
         isCompleted: Bool = false, 
         notes: String? = nil, 
         priority: Int = 0, 
         calendarEventIdentifier: String? = nil, 
         hasReceivedAIAdvice: Bool = false,
         aiAdvices: [String]? = nil,
         aiAdvicesGeneratedAt: Date? = nil) {
        self.id = id
        self.title = title
        self.dueDate = dueDate
        self.endDate = endDate
        self.isCompleted = isCompleted
        self.notes = notes
        self.priority = priority
        self.calendarEventIdentifier = calendarEventIdentifier
        self.hasReceivedAIAdvice = hasReceivedAIAdvice
        self.aiAdvices = aiAdvices
        self.aiAdvicesGeneratedAt = aiAdvicesGeneratedAt
    }
} 