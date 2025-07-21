import Foundation
import Core

/// 📅 일별 대화 저장 및 검색 매니저
/// 감정 대화 앱의 핵심: 사용자와의 모든 대화를 날짜별로 체계적으로 관리
/// PERF-WARNING: 대용량 JSON 파일 처리 시 메모리 사용량 주의
/// - 테스트 방안: Instruments의 Allocations로 파일 I/O 성능 확인
final class DailyConversationManager {
    static let shared = DailyConversationManager()
    
    private let documentsURL: URL
    private let conversationsDirectory = "DailyConversations"
    private let dateFormatter: DateFormatter
    
    private init() {
        self.documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.dateFormatter = DateFormatter()
        self.dateFormatter.dateFormat = "yyyy-MM-dd"
        
        createConversationsDirectoryIfNeeded()
    }
    
    // MARK: - Public Methods
    
    /// 🎯 오늘의 대화 저장
    /// - Parameters:
    ///   - conversation: 저장할 대화 내용
    ///   - emotionContext: 감정 맥락 정보
    func saveTodaysConversation(_ conversation: DailyConversation) async throws {
        let today = dateFormatter.string(from: Date())
        let fileURL = getConversationFileURL(for: today)
        
        print("💾 [DailyConversationManager] 오늘(\(today)) 대화 저장 시작")
        
        do {
            // 기존 대화가 있다면 로드
            var dailyData = try await loadConversation(for: today)
            
            // 새로운 대화 추가
            dailyData.conversations.append(conversation)
            dailyData.lastUpdated = Date()
            dailyData.totalMessages += conversation.messages.count
            
            // JSON으로 저장
            let jsonData = try JSONEncoder().encode(dailyData)
            try jsonData.write(to: fileURL)
            
            print("✅ [DailyConversationManager] 대화 저장 완료: \(conversation.messages.count)개 메시지")
            
        } catch {
            print("❌ [DailyConversationManager] 대화 저장 실패: \(error)")
            throw ConversationManagerError.saveFailed(error)
        }
    }
    
    /// 🔍 특정 날짜의 대화 로드
    func loadConversation(for date: String) async throws -> DailyConversationData {
        let fileURL = getConversationFileURL(for: date)
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            // 파일이 없으면 빈 데이터 반환
            return DailyConversationData(
                date: date,
                conversations: [],
                totalMessages: 0,
                lastUpdated: Date()
            )
        }
        
        do {
            let jsonData = try Data(contentsOf: fileURL)
            let dailyData = try JSONDecoder().decode(DailyConversationData.self, from: jsonData)
            print("📖 [DailyConversationManager] \(date) 대화 로드 완료: \(dailyData.totalMessages)개 메시지")
            return dailyData
            
        } catch {
            print("❌ [DailyConversationManager] 대화 로드 실패: \(error)")
            throw ConversationManagerError.loadFailed(error)
        }
    }
    
    /// 🎯 오늘의 대화 로드 (편의 메서드)
    func loadTodaysConversation() async throws -> DailyConversationData {
        let today = dateFormatter.string(from: Date())
        return try await loadConversation(for: today)
    }
    
    /// 📅 최근 N일간의 대화 로드 (컨텍스트 구성용)
    func loadRecentConversations(days: Int = 7) async throws -> [DailyConversationData] {
        var conversations: [DailyConversationData] = []
        
        for i in 0..<days {
            let date = Calendar.current.date(byAdding: .day, value: -i, to: Date())!
            let dateString = dateFormatter.string(from: date)
            
            do {
                let dailyData = try await loadConversation(for: dateString)
                if !dailyData.conversations.isEmpty {
                    conversations.append(dailyData)
                }
            } catch {
                // 특정 날짜 로드 실패는 무시하고 계속
                print("⚠️ [DailyConversationManager] \(dateString) 로드 실패, 건너뜀")
            }
        }
        
        print("📊 [DailyConversationManager] 최근 \(days)일 중 \(conversations.count)일의 대화 로드 완료")
        return conversations
    }
    
    // MARK: - Storage Management
    
    /// 📊 전체 대화 저장소 통계 조회
    func getStorageStatistics() async throws -> StorageStatistics {
        let directoryURL = documentsURL.appendingPathComponent(conversationsDirectory)
        
        guard FileManager.default.fileExists(atPath: directoryURL.path) else {
            return StorageStatistics(totalSize: 0, fileCount: 0, oldestDate: nil, newestDate: nil, dailyBreakdown: [])
        }
        
        let fileURLs = try FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.fileSizeKey, .creationDateKey],
            options: .skipsHiddenFiles
        )
        
        var totalSize: Int64 = 0
        var dailyBreakdown: [DailyStorageInfo] = []
        var dates: [Date] = []
        
        for fileURL in fileURLs where fileURL.pathExtension == "json" {
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey, .creationDateKey])
                let fileSize = Int64(resourceValues.fileSize ?? 0)
                let creationDate = resourceValues.creationDate ?? Date()
                
                totalSize += fileSize
                dates.append(creationDate)
                
                // 파일명에서 날짜 추출 (yyyy-MM-dd.json)
                let fileName = fileURL.deletingPathExtension().lastPathComponent
                
                // 해당 날짜의 대화 개수 조회
                let dailyData = try await loadConversation(for: fileName)
                
                let dailyInfo = DailyStorageInfo(
                    date: fileName,
                    fileSize: fileSize,
                    messageCount: dailyData.totalMessages,
                    conversationCount: dailyData.conversations.count
                )
                dailyBreakdown.append(dailyInfo)
                
            } catch {
                print("⚠️ [DailyConversationManager] 파일 정보 읽기 실패: \(fileURL.lastPathComponent)")
            }
        }
        
        // 날짜순 정렬
        dailyBreakdown.sort { $0.date > $1.date }
        dates.sort()
        
        let statistics = StorageStatistics(
            totalSize: totalSize,
            fileCount: fileURLs.count,
            oldestDate: dates.first,
            newestDate: dates.last,
            dailyBreakdown: dailyBreakdown
        )
        
        print("📊 [DailyConversationManager] 저장소 통계: \(formatBytes(totalSize)), \(fileURLs.count)개 파일")
        return statistics
    }
    
    /// 🗑️ 특정 날짜의 대화 삭제
    func deleteConversation(for date: String) async throws {
        let fileURL = getConversationFileURL(for: date)
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw ConversationManagerError.fileNotFound(date)
        }
        
        do {
            try FileManager.default.removeItem(at: fileURL)
            print("🗑️ [DailyConversationManager] \(date) 대화 삭제 완료")
        } catch {
            print("❌ [DailyConversationManager] \(date) 대화 삭제 실패: \(error)")
            throw ConversationManagerError.deleteFailed(error)
        }
    }
    
    /// 🗑️ 여러 날짜의 대화 일괄 삭제
    func deleteConversations(for dates: [String]) async throws {
        var deletedCount = 0
        var failedDates: [String] = []
        
        for date in dates {
            do {
                try await deleteConversation(for: date)
                deletedCount += 1
            } catch {
                failedDates.append(date)
                print("❌ [DailyConversationManager] \(date) 삭제 실패")
            }
        }
        
        print("🗑️ [DailyConversationManager] 일괄 삭제 완료: \(deletedCount)개 성공, \(failedDates.count)개 실패")
        
        if !failedDates.isEmpty {
            throw ConversationManagerError.partialDeletionFailed(failedDates)
        }
    }
    
    /// 🗑️ 특정 기간 이전 대화 자동 삭제
    func deleteConversationsOlderThan(days: Int) async throws -> Int {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        let cutoffString = dateFormatter.string(from: cutoffDate)
        
        let statistics = try await getStorageStatistics()
        let oldConversations = statistics.dailyBreakdown.filter { $0.date < cutoffString }
        
        let datesToDelete = oldConversations.map { $0.date }
        
        if datesToDelete.isEmpty {
            print("🗑️ [DailyConversationManager] \(days)일 이전 삭제할 대화가 없음")
            return 0
        }
        
        try await deleteConversations(for: datesToDelete)
        print("🗑️ [DailyConversationManager] \(days)일 이전 \(datesToDelete.count)개 대화 삭제 완료")
        
        return datesToDelete.count
    }
    
    /// 📦 대화 데이터 압축 (오래된 대화는 요약본만 보관)
    func compressOldConversations(olderThanDays: Int) async throws -> Int {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -olderThanDays, to: Date())!
        let cutoffString = dateFormatter.string(from: cutoffDate)
        
        let statistics = try await getStorageStatistics()
        let oldConversations = statistics.dailyBreakdown.filter { $0.date < cutoffString && $0.messageCount > 10 }
        
        var compressedCount = 0
        
        for dailyInfo in oldConversations {
            do {
                let dailyData = try await loadConversation(for: dailyInfo.date)
                let compressedData = compressConversationData(dailyData)
                
                // 압축된 데이터로 덮어쓰기
                let fileURL = getConversationFileURL(for: dailyInfo.date)
                let jsonData = try JSONEncoder().encode(compressedData)
                try jsonData.write(to: fileURL)
                
                compressedCount += 1
                print("📦 [DailyConversationManager] \(dailyInfo.date) 대화 압축 완료")
                
            } catch {
                print("❌ [DailyConversationManager] \(dailyInfo.date) 압축 실패: \(error)")
            }
        }
        
        print("📦 [DailyConversationManager] \(compressedCount)개 대화 압축 완료")
        return compressedCount
    }
    
    /// 🔎 키워드로 과거 대화 검색
    func searchConversations(keyword: String, maxResults: Int = 5) async throws -> [ConversationSearchResult] {
        let recentConversations = try await loadRecentConversations(days: 30) // 최근 30일
        var results: [ConversationSearchResult] = []
        
        for dailyData in recentConversations {
            for conversation in dailyData.conversations {
                for message in conversation.messages {
                    if message.content.lowercased().contains(keyword.lowercased()) {
                        let result = ConversationSearchResult(
                            date: dailyData.date,
                            conversationId: conversation.id,
                            matchingMessage: message,
                            relevanceScore: calculateRelevance(message: message, keyword: keyword)
                        )
                        results.append(result)
                    }
                }
            }
        }
        
        // 관련성 순으로 정렬하고 상위 결과만 반환
        results.sort { $0.relevanceScore > $1.relevanceScore }
        return Array(results.prefix(maxResults))
    }
    
    // MARK: - Private Methods
    
    private func createConversationsDirectoryIfNeeded() {
        let directoryURL = documentsURL.appendingPathComponent(conversationsDirectory)
        
        if !FileManager.default.fileExists(atPath: directoryURL.path) {
            do {
                try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
                print("📁 [DailyConversationManager] 대화 저장 디렉토리 생성됨")
            } catch {
                print("❌ [DailyConversationManager] 디렉토리 생성 실패: \(error)")
            }
        }
    }
    
    private func getConversationFileURL(for date: String) -> URL {
        return documentsURL
            .appendingPathComponent(conversationsDirectory)
            .appendingPathComponent("\(date).json")
    }
    
    private func calculateRelevance(message: ConversationMessage, keyword: String) -> Double {
        let content = message.content.lowercased()
        let keyword = keyword.lowercased()
        
        // 간단한 관련성 점수 계산
        let occurrences = content.components(separatedBy: keyword).count - 1
        let proximity = content.range(of: keyword)?.lowerBound.utf16Offset(in: content) ?? content.count
        
        // 감정 메시지에 가중치 부여
        let emotionBonus = message.emotionIntensity ?? 0.0
        
        return Double(occurrences) * 10.0 - Double(proximity) * 0.1 + emotionBonus * 5.0
    }
    
    // MARK: - Utility Methods
    
    /// 📦 대화 데이터 압축 (중요한 메시지만 보관)
    private func compressConversationData(_ dailyData: DailyConversationData) -> DailyConversationData {
        var compressedConversations: [DailyConversation] = []
        
        for conversation in dailyData.conversations {
            // 중요한 메시지만 필터링 (감정적 메시지, 목표 설정 등)
            let importantMessages = conversation.messages.filter { message in
                return message.messageType == .emotional || 
                       message.messageType == .goal ||
                       (message.emotionIntensity ?? 0.0) > 0.6 ||
                       message.content.count > 100 // 긴 메시지는 중요할 가능성
            }
            
            // 압축된 대화 생성 (최대 5개 메시지만)
            let limitedMessages = Array(importantMessages.prefix(5))
            
            if !limitedMessages.isEmpty {
                let compressedConversation = DailyConversation(
                    emotionContext: conversation.emotionContext,
                    messages: limitedMessages
                )
                compressedConversations.append(compressedConversation)
            }
        }
        
        return DailyConversationData(
            date: dailyData.date,
            conversations: compressedConversations,
            totalMessages: compressedConversations.reduce(0) { $0 + $1.messages.count },
            lastUpdated: Date()
        )
    }
    
    /// 📏 바이트 크기를 읽기 쉬운 형태로 포맷팅
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - Data Models

/// 📅 일별 대화 전체 데이터
struct DailyConversationData: Codable {
    let date: String
    var conversations: [DailyConversation]
    var totalMessages: Int
    var lastUpdated: Date
}

/// 💬 개별 대화 세션
struct DailyConversation: Codable {
    let id: String
    let startTime: Date
    let endTime: Date?
    let emotionContext: EmotionContext
    let messages: [ConversationMessage]
    let metadata: ConversationMetadata
    
    init(emotionContext: EmotionContext, messages: [ConversationMessage] = []) {
        self.id = UUID().uuidString
        self.startTime = Date()
        self.endTime = nil
        self.emotionContext = emotionContext
        self.messages = messages
        self.metadata = ConversationMetadata(
            userGoal: nil,
            sessionType: .emotional,
            qualityScore: nil
        )
    }
}

/// 📝 개별 메시지
struct ConversationMessage: Codable {
    let id: String
    let content: String
    let isFromUser: Bool
    let timestamp: Date
    let emotionIntensity: Double? // 0.0 ~ 1.0
    let messageType: ConversationMessageType
    
    init(content: String, isFromUser: Bool, emotionIntensity: Double? = nil, messageType: ConversationMessageType = .normal) {
        self.id = UUID().uuidString
        self.content = content
        self.isFromUser = isFromUser
        self.timestamp = Date()
        self.emotionIntensity = emotionIntensity
        self.messageType = messageType
    }
}

/// 🎭 감정 맥락
struct EmotionContext: Codable {
    let primaryEmotion: String
    let intensity: Double // 0.0 ~ 1.0
    let secondaryEmotions: [String]
    let userGoal: String?
    let timeOfDay: String
    
    init(primaryEmotion: String, intensity: Double, secondaryEmotions: [String] = [], userGoal: String? = nil) {
        self.primaryEmotion = primaryEmotion
        self.intensity = intensity
        self.secondaryEmotions = secondaryEmotions
        self.userGoal = userGoal
        self.timeOfDay = getCurrentTimeOfDay()
    }
}

/// 📊 대화 메타데이터
struct ConversationMetadata: Codable {
    let userGoal: String?
    let sessionType: SessionType
    let qualityScore: Double? // AI 응답 품질 점수
}

/// 🔍 검색 결과
struct ConversationSearchResult {
    let date: String
    let conversationId: String
    let matchingMessage: ConversationMessage
    let relevanceScore: Double
}

/// 📱 메시지 타입
enum ConversationMessageType: String, Codable {
    case normal = "normal"
    case emotional = "emotional"
    case goal = "goal"
    case feedback = "feedback"
    case systemResponse = "system"
}

/// 🎯 세션 타입
enum SessionType: String, Codable {
    case emotional = "emotional"
    case goalSetting = "goal"
    case feedback = "feedback"
    case casual = "casual"
}

/// 📊 저장소 통계
struct StorageStatistics {
    let totalSize: Int64
    let fileCount: Int
    let oldestDate: Date?
    let newestDate: Date?
    let dailyBreakdown: [DailyStorageInfo]
    
    /// 📏 포맷된 크기 문자열
    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: totalSize)
    }
    
    /// 📅 보관 기간 (일수)
    var retentionDays: Int {
        guard let oldest = oldestDate, let newest = newestDate else { return 0 }
        return Calendar.current.dateComponents([.day], from: oldest, to: newest).day ?? 0
    }
}

/// 📅 일별 저장소 정보
struct DailyStorageInfo {
    let date: String
    let fileSize: Int64
    let messageCount: Int
    let conversationCount: Int
    
    /// 📏 포맷된 크기 문자열
    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }
    
    /// 📅 Date 객체로 변환
    var dateObject: Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: date)
    }
    
    /// 📅 표시용 날짜 문자열
    var displayDate: String {
        guard let dateObj = dateObject else { return date }
        let formatter = DateFormatter()
        formatter.dateFormat = "MM월 dd일"
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter.string(from: dateObj)
    }
}

/// ❌ 에러 타입
enum ConversationManagerError: Error {
    case saveFailed(Error)
    case loadFailed(Error)
    case searchFailed(Error)
    case fileNotFound(String)
    case deleteFailed(Error)
    case partialDeletionFailed([String])
    
    var localizedDescription: String {
        switch self {
        case .saveFailed(let error):
            return "대화 저장 실패: \(error.localizedDescription)"
        case .loadFailed(let error):
            return "대화 로드 실패: \(error.localizedDescription)"
        case .searchFailed(let error):
            return "대화 검색 실패: \(error.localizedDescription)"
        case .fileNotFound(let date):
            return "\(date) 날짜의 대화 파일이 없습니다"
        case .deleteFailed(let error):
            return "대화 삭제 실패: \(error.localizedDescription)"
        case .partialDeletionFailed(let dates):
            return "일부 대화 삭제 실패: \(dates.joined(separator: ", "))"
        }
    }
}

// MARK: - Utility Functions

private func getCurrentTimeOfDay() -> String {
    let hour = Calendar.current.component(.hour, from: Date())
    switch hour {
    case 6..<12: return "morning"
    case 12..<18: return "afternoon"
    case 18..<22: return "evening"
    default: return "night"
    }
}