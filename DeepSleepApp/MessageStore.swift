import Foundation

/// 💬 채팅 스타일 메시지 저장소 - 안정적인 메시지 지속성 보장
final class MessageStore {
    static let shared = MessageStore()
    
    private init() {
        // 🎯 시스템 메시지들을 앱 시작 시 자동으로 추가
        loadInitialSystemMessages()
    }
    
    // 메시지 저장소 - 더 자세한 정보 포함
    private var messages: [(id: UUID, isUser: Bool, content: String, timestamp: Date, messageType: String, isPersistent: Bool)] = []
    
    // MARK: - Public Methods
    
    /// 🎯 개선된 메시지 저장 (타입과 지속성 포함)
    /// - Parameters:
    ///   - content: 메시지 내용
    ///   - isUser: 사용자 메시지 여부
    ///   - messageType: 메시지 타입 ("user", "bot", "system", "preset", "quickAction" 등)
    ///   - isPersistent: 지속적으로 유지할 메시지인지 (시스템 메시지 등)
    func saveMessage(content: String, isUser: Bool, messageType: String = "normal", isPersistent: Bool = false) async throws {
        let message = (
            id: UUID(), 
            isUser: isUser, 
            content: content, 
            timestamp: Date(),
            messageType: messageType,
            isPersistent: isPersistent
        )
        messages.append(message)
        print("[MessageStore] 메시지 저장: \(messageType) - \(content.prefix(50))...")
    }
    
    /// 🎯 시스템 메시지 전용 저장 함수 (항상 지속적)
    func saveSystemMessage(content: String) async throws {
        try await saveMessage(content: content, isUser: false, messageType: "system", isPersistent: true)
    }
    
    /// 메시지 로드 (기존 API 호환성 유지)
    /// - Parameters:
    ///   - page: 페이지 번호 (0부터 시작)
    ///   - pageSize: 페이지당 메시지 수
    /// - Returns: 메시지 배열
    func loadMessages(page: Int, pageSize: Int) async throws -> [(isUser: Bool, content: String)] {
        let startIndex = page * pageSize
        let endIndex = min(startIndex + pageSize, messages.count)
        
        guard startIndex < messages.count else {
            return []
        }
        
        // 시간순 정렬 (최신순이 아님 - 채팅앱처럼 시간 순서대로)
        let sortedMessages = messages.sorted { $0.timestamp < $1.timestamp }
        let pageMessages = Array(sortedMessages[startIndex..<endIndex])
        
        return pageMessages.map { (isUser: $0.isUser, content: $0.content) }
    }
    
    /// 🆕 확장된 메시지 로드 (새로운 API)
    func loadMessagesWithType(page: Int, pageSize: Int) async throws -> [(isUser: Bool, content: String, messageType: String)] {
        let startIndex = page * pageSize
        let endIndex = min(startIndex + pageSize, messages.count)
        
        guard startIndex < messages.count else {
            return []
        }
        
        let sortedMessages = messages.sorted { $0.timestamp < $1.timestamp }
        let pageMessages = Array(sortedMessages[startIndex..<endIndex])
        
        return pageMessages.map { (isUser: $0.isUser, content: $0.content, messageType: $0.messageType) }
    }
    
    /// 🛡️ 임시 메시지만 삭제 (지속성 메시지는 보존)
    func clearTemporaryMessages() {
        let persistentMessages = messages.filter { $0.isPersistent }
        messages = persistentMessages
        print("[MessageStore] 임시 메시지 삭제, 지속성 메시지 \(persistentMessages.count)개 보존")
    }
    
    /// 모든 메시지 삭제 (긴급상황용)
    func clearAllMessages() {
        messages.removeAll()
        print("[MessageStore] 모든 메시지 삭제")
    }
    
    /// 메시지 개수 반환
    var messageCount: Int {
        messages.count
    }
    
    /// 지속성 메시지 개수 반환
    var persistentMessageCount: Int {
        messages.filter { $0.isPersistent }.count
    }
    
    // MARK: - Private Methods
    
    /// 🎯 앱 시작 시 기본 시스템 메시지들 로드
    private func loadInitialSystemMessages() {
        let welcomeMessages = [
            "안녕하세요! 오늘 하루는 어떠셨나요?",
            "편안한 휴식을 위해 도와드리겠습니다 ✨",
            "아래 버튼을 눌러 맞춤형 사운드를 추천받아보세요!"
        ]
        
        for message in welcomeMessages {
            let systemMessage = (
                id: UUID(),
                isUser: false,
                content: message,
                timestamp: Date(),
                messageType: "system",
                isPersistent: true
            )
            messages.append(systemMessage)
        }
        
        print("[MessageStore] 초기 시스템 메시지 \(welcomeMessages.count)개 로드 완료")
    }
} 