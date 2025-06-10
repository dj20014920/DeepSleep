import Foundation
import UIKit

// MARK: - 채팅 컨텍스트 타입 정의
enum ChatContextType {
    case general           // 일반 대화
    case diaryAnalysis     // 일기 분석
    case emotionPatternAnalysis  // 감정 패턴 분석
    case presetRecommendation    // 프리셋 추천
    case todoAdvice        // 할 일 조언
}

// MARK: - 채팅 세션 데이터
struct ChatSession: Codable {
    let id: UUID
    let contextType: ChatContextType
    let startDate: Date
    var lastUpdate: Date
    var messages: [StoredChatMessage]
    var metadata: [String: String]
    
    init(contextType: ChatContextType) {
        self.id = UUID()
        self.contextType = contextType
        self.startDate = Date()
        self.lastUpdate = Date()
        self.messages = []
        self.metadata = [:]
    }
}

// MARK: - 저장용 채팅 메시지
struct StoredChatMessage: Codable {
    let id: UUID
    let type: String  // ChatMessageType의 rawValue
    let text: String
    let timestamp: Date
    let presetName: String?
    
    init(from chatMessage: ChatMessage) {
        self.id = UUID()
        self.type = chatMessage.type.rawValue
        self.text = chatMessage.text
        self.timestamp = Date()
        self.presetName = chatMessage.presetName
    }
    
    func toChatMessage() -> ChatMessage {
        guard let messageType = ChatMessageType(rawValue: type) else {
            return ChatMessage(type: .bot, text: text, presetName: presetName)
        }
        return ChatMessage(type: messageType, text: text, presetName: presetName)
    }
}

// MARK: - ChatContextType Codable 지원
extension ChatContextType: Codable {
    enum CodingKeys: String, CodingKey {
        case type
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let typeString = try container.decode(String.self)
        
        switch typeString {
        case "general":
            self = .general
        case "diaryAnalysis":
            self = .diaryAnalysis
        case "emotionPatternAnalysis":
            self = .emotionPatternAnalysis
        case "presetRecommendation":
            self = .presetRecommendation
        case "todoAdvice":
            self = .todoAdvice
        default:
            self = .general
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        let typeString: String
        switch self {
        case .general:
            typeString = "general"
        case .diaryAnalysis:
            typeString = "diaryAnalysis"
        case .emotionPatternAnalysis:
            typeString = "emotionPatternAnalysis"
        case .presetRecommendation:
            typeString = "presetRecommendation"
        case .todoAdvice:
            typeString = "todoAdvice"
        }
        
        try container.encode(typeString)
    }
}

// MARK: - ChatManager 클래스
class ChatManager {
    static let shared = ChatManager()
    
    private let userDefaults = UserDefaults.standard
    private let chatSessionsKey = "DeepSleep_ChatSessions_v2"
    private let maxRetentionDays = 14 // 2주
    
    private var currentSessions: [ChatSession] = []
    
    private init() {
        loadSavedSessions()
        cleanExpiredSessions()
    }
    
    // MARK: - 세션 관리
    
    /// 새로운 채팅 세션 시작
    func startNewSession(contextType: ChatContextType) -> UUID {
        let session = ChatSession(contextType: contextType)
        currentSessions.append(session)
        saveSessions()
        
        #if DEBUG
        print("🆕 [ChatManager] 새 세션 시작: \(contextType), ID: \(session.id)")
        #endif
        
        return session.id
    }
    
    /// 현재 활성 세션 가져오기 (가장 최근 세션)
    func getCurrentSession() -> ChatSession? {
        return currentSessions.last
    }
    
    /// 특정 컨텍스트 타입의 최근 세션 가져오기
    func getRecentSession(for contextType: ChatContextType) -> ChatSession? {
        return currentSessions
            .filter { $0.contextType == contextType }
            .sorted { $0.lastUpdate > $1.lastUpdate }
            .first
    }
    
    /// 모든 메시지를 하나의 연속된 대화로 가져오기
    func getAllMessagesAsContinuousChat() -> [ChatMessage] {
        var allMessages: [ChatMessage] = []
        
        // 시간순으로 정렬된 모든 세션의 메시지들
        let sortedSessions = currentSessions.sorted { $0.startDate < $1.startDate }
        
        var isFirstSession = true
        for session in sortedSessions {
            // 세션 구분자 추가 (첫 번째 세션 제외)
            if !isFirstSession && !session.messages.isEmpty {
                let separator = ChatMessage(type: .bot, text: "--- 새로운 대화 주제 ---")
                allMessages.append(separator)
            }
            
            // 세션의 메시지들 추가
            let sessionMessages = session.messages.map { $0.toChatMessage() }
            allMessages.append(contentsOf: sessionMessages)
            
            isFirstSession = false
        }
        
        return allMessages
    }
    
    // MARK: - 메시지 관리
    
    /// 현재 세션에 메시지 추가
    func addMessage(_ message: ChatMessage) {
        guard let currentSessionIndex = currentSessions.indices.last else {
            // 현재 세션이 없으면 일반 세션 생성
            let sessionId = startNewSession(contextType: .general)
            addMessage(message)
            return
        }
        
        let storedMessage = StoredChatMessage(from: message)
        currentSessions[currentSessionIndex].messages.append(storedMessage)
        currentSessions[currentSessionIndex].lastUpdate = Date()
        
        saveSessions()
        
        #if DEBUG
        print("💬 [ChatManager] 메시지 추가: \(message.type.rawValue) - \(message.text.prefix(50))...")
        #endif
    }
    
    /// 특정 세션에 메시지 추가
    func addMessage(_ message: ChatMessage, to sessionId: UUID) {
        guard let sessionIndex = currentSessions.firstIndex(where: { $0.id == sessionId }) else {
            print("⚠️ [ChatManager] 세션을 찾을 수 없음: \(sessionId)")
            return
        }
        
        let storedMessage = StoredChatMessage(from: message)
        currentSessions[sessionIndex].messages.append(storedMessage)
        currentSessions[sessionIndex].lastUpdate = Date()
        
        saveSessions()
    }
    
    /// 메시지 개수 제한 (메모리 관리)
    private func limitMessagesPerSession() {
        let maxMessagesPerSession = 100
        
        for i in 0..<currentSessions.count {
            if currentSessions[i].messages.count > maxMessagesPerSession {
                // 오래된 메시지부터 제거 (첫 번째와 마지막 메시지는 보존)
                let messagesToRemove = currentSessions[i].messages.count - maxMessagesPerSession
                currentSessions[i].messages.removeSubrange(1..<(1 + messagesToRemove))
            }
        }
    }
    
    // MARK: - 데이터 저장/로드
    
    private func saveSessions() {
        limitMessagesPerSession()
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(currentSessions)
            userDefaults.set(data, forKey: chatSessionsKey)
            
            #if DEBUG
            print("💾 [ChatManager] 세션 저장 완료: \(currentSessions.count)개 세션, \(getTotalMessageCount())개 메시지")
            #endif
        } catch {
            print("❌ [ChatManager] 세션 저장 실패: \(error)")
        }
    }
    
    private func loadSavedSessions() {
        guard let data = userDefaults.data(forKey: chatSessionsKey) else {
            print("📭 [ChatManager] 저장된 세션 없음")
            return
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            currentSessions = try decoder.decode([ChatSession].self, from: data)
            
            #if DEBUG
            print("📚 [ChatManager] 세션 로드 완료: \(currentSessions.count)개 세션, \(getTotalMessageCount())개 메시지")
            #endif
        } catch {
            print("❌ [ChatManager] 세션 로드 실패: \(error)")
            currentSessions = []
        }
    }
    
    // MARK: - 데이터 정리
    
    /// 만료된 세션들 정리 (2주 이상 된 것들)
    private func cleanExpiredSessions() {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -maxRetentionDays, to: Date()) ?? Date()
        
        let beforeCount = currentSessions.count
        currentSessions.removeAll { session in
            session.lastUpdate < cutoffDate
        }
        
        let removedCount = beforeCount - currentSessions.count
        if removedCount > 0 {
            saveSessions()
            
            #if DEBUG
            print("🧹 [ChatManager] 만료된 세션 정리: \(removedCount)개 제거")
            #endif
        }
    }
    
    /// 수동으로 데이터 정리
    func cleanupOldData() {
        cleanExpiredSessions()
    }
    
    /// 모든 채팅 기록 삭제
    func clearAllChatHistory() {
        currentSessions.removeAll()
        userDefaults.removeObject(forKey: chatSessionsKey)
        
        #if DEBUG
        print("🗑️ [ChatManager] 모든 채팅 기록 삭제")
        #endif
    }
    
    // MARK: - 통계 및 정보
    
    func getTotalMessageCount() -> Int {
        return currentSessions.reduce(0) { $0 + $1.messages.count }
    }
    
    func getSessionCount() -> Int {
        return currentSessions.count
    }
    
    func getOldestSessionDate() -> Date? {
        return currentSessions.map { $0.startDate }.min()
    }
    
    func getDebugInfo() -> String {
        let messageCount = getTotalMessageCount()
        let sessionCount = getSessionCount()
        let oldestDate = getOldestSessionDate()
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .short
        
        return """
        📊 ChatManager 상태:
        • 세션 수: \(sessionCount)개
        • 총 메시지: \(messageCount)개
        • 가장 오래된 기록: \(oldestDate.map { dateFormatter.string(from: $0) } ?? "없음")
        • 보존 기간: \(maxRetentionDays)일
        """
    }
} 