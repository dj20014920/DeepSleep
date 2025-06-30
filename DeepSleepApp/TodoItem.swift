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
    
    // 🛡️ AI 조언 관련 통합 관리
    var adviceRequestCount: Int = 0 // 총 조언 요청 횟수 (스와이프 + 직접 입장 통합)
    var maxAdviceCount: Int = 3 // 할 일당 최대 조언 횟수
    var hasReceivedAIAdvice: Bool = false // AI 조언 수신 여부 (개별 조언 1회 제한용) - 하위 호환성 유지
    var aiAdvices: [String]? = nil // AI가 생성한 조언들 저장 (여러 개 누적 가능)
    var aiAdvicesGeneratedAt: Date? = nil // AI 조언이 생성된 시간 (3개월 후 자동 삭제용)
    
    var createdDate: Date = Date() // 생성일(기본값: 현재)
    
    // 🛡️ 기존 데이터 호환성을 위한 커스텀 디코딩
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // 필수 프로퍼티들
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        dueDate = try container.decode(Date.self, forKey: .dueDate)
        endDate = try container.decodeIfPresent(Date.self, forKey: .endDate)
        isCompleted = try container.decodeIfPresent(Bool.self, forKey: .isCompleted) ?? false
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        priority = try container.decodeIfPresent(Int.self, forKey: .priority) ?? 0
        calendarEventIdentifier = try container.decodeIfPresent(String.self, forKey: .calendarEventIdentifier)
        
        // 🛡️ 새로 추가된 프로퍼티들 (기존 데이터에 없을 수 있음)
        adviceRequestCount = try container.decodeIfPresent(Int.self, forKey: .adviceRequestCount) ?? 0
        maxAdviceCount = try container.decodeIfPresent(Int.self, forKey: .maxAdviceCount) ?? 3
        hasReceivedAIAdvice = try container.decodeIfPresent(Bool.self, forKey: .hasReceivedAIAdvice) ?? false
        aiAdvices = try container.decodeIfPresent([String].self, forKey: .aiAdvices)
        aiAdvicesGeneratedAt = try container.decodeIfPresent(Date.self, forKey: .aiAdvicesGeneratedAt)
        createdDate = try container.decodeIfPresent(Date.self, forKey: .createdDate) ?? Date()
    }
    
    // 🛡️ 조언 관련 computed properties
    var canReceiveAdvice: Bool {
        return adviceRequestCount < maxAdviceCount
    }
    
    var remainingAdviceCount: Int {
        return max(0, maxAdviceCount - adviceRequestCount)
    }
    
    var adviceUsageText: String {
        return "\(adviceRequestCount)/\(maxAdviceCount)"
    }
    
    // 🛡️ 조언 요청 처리 메서드
    mutating func requestAdvice() -> Bool {
        guard canReceiveAdvice else { return false }
        adviceRequestCount += 1
        hasReceivedAIAdvice = true
        return true
    }
    
    // 🛡️ 조언 데이터 초기화 (3개월 후 자동 실행용)
    mutating func resetAdviceData() {
        adviceRequestCount = 0
        hasReceivedAIAdvice = false
        aiAdvices = nil
        aiAdvicesGeneratedAt = nil
    }
    
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
         adviceRequestCount: Int = 0,
         maxAdviceCount: Int = 3,
         hasReceivedAIAdvice: Bool = false,
         aiAdvices: [String]? = nil,
         aiAdvicesGeneratedAt: Date? = nil,
         createdDate: Date = Date()) {
        self.id = id
        self.title = title
        self.dueDate = dueDate
        self.endDate = endDate
        self.isCompleted = isCompleted
        self.notes = notes
        self.priority = priority
        self.calendarEventIdentifier = calendarEventIdentifier
        self.adviceRequestCount = adviceRequestCount
        self.maxAdviceCount = maxAdviceCount
        self.hasReceivedAIAdvice = hasReceivedAIAdvice
        self.aiAdvices = aiAdvices
        self.aiAdvicesGeneratedAt = aiAdvicesGeneratedAt
        self.createdDate = createdDate
    }
    
    enum CodingKeys: String, CodingKey {
        case id, title, dueDate, endDate, isCompleted, notes, priority, calendarEventIdentifier, adviceRequestCount, maxAdviceCount, hasReceivedAIAdvice, aiAdvices, aiAdvicesGeneratedAt, createdDate
    }
} 