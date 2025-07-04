import Foundation

/// 메시지 저장소
final class MessageStore {
    static let shared = MessageStore()
    
    private init() {}
    
    // 메시지 저장소
    private var messages: [(id: UUID, isUser: Bool, content: String, timestamp: Date)] = []
    
    // MARK: - Public Methods
    
    /// 메시지 저장
    /// - Parameters:
    ///   - content: 메시지 내용
    ///   - isUser: 사용자 메시지 여부
    func saveMessage(content: String, isUser: Bool) async throws {
        let message = (id: UUID(), isUser: isUser, content: content, timestamp: Date())
        messages.append(message)
    }
    
    /// 메시지 로드
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
        
        // 최신 메시지부터 반환
        let sortedMessages = messages.sorted { $0.timestamp > $1.timestamp }
        let pageMessages = Array(sortedMessages[startIndex..<endIndex])
        
        return pageMessages.map { (isUser: $0.isUser, content: $0.content) }
    }
    
    /// 모든 메시지 삭제
    func clearMessages() {
        messages.removeAll()
    }
    
    /// 메시지 개수 반환
    var messageCount: Int {
        messages.count
    }
} 