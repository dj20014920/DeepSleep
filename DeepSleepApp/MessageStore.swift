import Foundation

/// 💬 채팅 스타일 메시지 저장소 - 안정적인 메시지 지속성 보장
final class MessageStore {
    static let shared = MessageStore()
    
    private init() {
        // 디스크에서 로드 (없으면 시스템 메시지 초기화)
        if !loadFromDisk() {
            loadInitialSystemMessages()
            saveToDisk()
        }
    }
    
    struct StoredMessage: Codable {
        let id: UUID
        let isUser: Bool
        let content: String
        let timestamp: Date
        let messageType: String
        let isPersistent: Bool
    }
    
    // 메시지 저장소 - 더 자세한 정보 포함 (id, 사용자 여부, 내용, 시간, 타입, 지속성)
    private var messages: [(id: UUID, isUser: Bool, content: String, timestamp: Date, messageType: String, isPersistent: Bool)] = []
    
    // MARK: - Public Methods
    
    /// 🎯 개선된 메시지 저장 (타입과 지속성 포함)
    /// - Parameters:
    ///   - content: 메시지 내용
    ///   - isUser: 사용자 메시지 여부
    ///   - messageType: 메시지 타입 ("user", "bot", "system", "preset", "quickAction" 등)
    ///   - isPersistent: 지속적으로 유지할 메시지인지 (시스템 메시지 등)
    @discardableResult
    func saveMessage(content: String, isUser: Bool, messageType: String = "normal", isPersistent: Bool = false) -> UUID {
        let message = (
            id: UUID(),
            isUser: isUser,
            content: content,
            timestamp: Date(),
            messageType: messageType,
            isPersistent: isPersistent
        )
        messages.append(message)
        saveToDisk()
        return message.id
    }
    
    /// 🎯 시스템 메시지 전용 저장 함수 (항상 지속적)
    func saveSystemMessage(content: String) {
        _ = saveMessage(content: content, isUser: false, messageType: "system", isPersistent: true)
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
    
    /// 최신 메시지 모두 반환 (간단 뷰 갱신용)
    func allMessages() -> [(isUser: Bool, content: String, messageType: String)] {
        let sorted = messages.sorted { $0.timestamp < $1.timestamp }
        return sorted.map { ($0.isUser, $0.content, $0.messageType) }
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
    
    /// 🔄 임시 메시지만 삭제 (지속성 메시지는 보존)
    func clearTemporaryMessages() {
        let persistentMessages = messages.filter { $0.isPersistent }
        let removedCount = messages.count - persistentMessages.count
        messages = persistentMessages
        saveToDisk()
        
#if DEBUG
        print("💾 [ChatPersistence] 임시 메시지 \(removedCount)개 삭제, 지속성 메시지 \(persistentMessages.count)개 보존")
#endif
    }
    
    /// 모든 메시지 삭제 (긴급상황용)
    func clearAllMessages() {
        let totalCount = messages.count
        messages.removeAll()
        saveToDisk()
        
#if DEBUG
        print("💾 [ChatPersistence] 🔄 모든 메시지 삭제 - 총 \(totalCount)개")
#endif
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
                isPersistent: true  // 시스템 메시지는 항상 지속성
            )
            messages.append(systemMessage)
        }
    }
    
    // MARK: - Disk Persistence
    private var storeURL: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return dir.appendingPathComponent("message_store.json")
    }
    
    private func saveToDisk() {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        let arr = messages.map { StoredMessage(id: $0.id, isUser: $0.isUser, content: $0.content, timestamp: $0.timestamp, messageType: $0.messageType, isPersistent: $0.isPersistent) }
        do {
            let data = try enc.encode(arr)
            try data.write(to: storeURL, options: .atomic)
        } catch {
            print("⚠️ [MessageStore] saveToDisk 실패: \(error)")
        }
    }
    
    @discardableResult
    private func loadFromDisk() -> Bool {
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        do {
            let data = try Data(contentsOf: storeURL)
            let arr = try dec.decode([StoredMessage].self, from: data)
            self.messages = arr.map { ($0.id, $0.isUser, $0.content, $0.timestamp, $0.messageType, $0.isPersistent) }
            return true
        } catch {
            return false
        }
    }
}
