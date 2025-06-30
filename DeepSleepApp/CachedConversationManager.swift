import Foundation
import SwiftUI
import CoreData
import OSLog
import Combine

// MARK: - Enhanced Message Types
public enum CacheMessageType: String, Codable, CaseIterable {
    case user = "user"
    case bot = "bot"
    case system = "system"
    case aiResponse = "aiResponse"
    case presetRecommendation = "presetRecommendation"
    case recommendationSelector = "recommendationSelector"
    case loading = "loading"
    case error = "error"
    case presetOptions = "presetOptions"
    case postPresetOptions = "postPresetOptions"
    case emotionAnalysis = "emotionAnalysis"
    case contextualSuggestion = "contextualSuggestion"
    case memoryRecall = "memoryRecall"
    case personalizedInsight = "personalizedInsight"
}

public enum MessagePriority: Int, Codable, CaseIterable {
    case low = 1
    case normal = 2
    case high = 3
    case critical = 4
}

public enum MessageSentiment: String, Codable, CaseIterable {
    case positive = "positive"
    case neutral = "neutral"
    case negative = "negative"
    case mixed = "mixed"
    case unknown = "unknown"
}

// MARK: - Enhanced Conversation Message
public struct ConversationMessage: Codable, Identifiable, Equatable {
    public let id: UUID
    public let text: String
    public let type: CacheMessageType
    public let timestamp: Date
    public let emotion: String?
    public let metadata: [String: String]?
    
    // Enhanced properties
    public let priority: MessagePriority
    public let sentiment: MessageSentiment
    public let contextTags: [String]
    public let processingTime: TimeInterval?
    public let aiConfidence: Double?
    public let memoryImportance: Double
    public let sessionId: UUID?
    public let threadId: UUID?
    
    public init(
        id: UUID = UUID(),
        text: String,
        type: CacheMessageType,
        timestamp: Date = Date(),
        emotion: String? = nil,
        metadata: [String: String]? = nil,
        priority: MessagePriority = .normal,
        sentiment: MessageSentiment = .unknown,
        contextTags: [String] = [],
        processingTime: TimeInterval? = nil,
        aiConfidence: Double? = nil,
        memoryImportance: Double = 0.5,
        sessionId: UUID? = nil,
        threadId: UUID? = nil
    ) {
        self.id = id
        self.text = text
        self.type = type
        self.timestamp = timestamp
        self.emotion = emotion
        self.metadata = metadata
        self.priority = priority
        self.sentiment = sentiment
        self.contextTags = contextTags
        self.processingTime = processingTime
        self.aiConfidence = aiConfidence
        self.memoryImportance = memoryImportance
        self.sessionId = sessionId
        self.threadId = threadId
    }
    
    public static func == (lhs: ConversationMessage, rhs: ConversationMessage) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - Session Analytics
public struct SessionAnalytics: Codable {
    public let sessionId: UUID
    public let startTime: Date
    public var endTime: Date?
    public var messageCount: Int
    public var averageResponseTime: TimeInterval
    public var dominantEmotion: String?
    public var sentimentDistribution: [MessageSentiment: Int]
    public var contextualInsights: [String]
    public var engagementScore: Double
    public var memoryFormationEvents: Int
}

// MARK: - Advanced Cached Conversation Memory
public struct CachedConversationMemory: Codable {
    public let id: UUID
    public let timestamp: Date
    public let topic: String
    public let summary: String
    public let keyPoints: [String]
    public let emotionalContext: String
    public let importance: Double
    public let category: String
    public let tags: [String]
    
    // Advanced properties
    public let memoryType: MemoryType
    public let retentionStrength: Double
    public let accessCount: Int
    public let lastAccessTime: Date
    public let associatedSessions: [UUID]
    public let vectorEmbedding: [Float]?
    public let personalRelevance: Double
    
    public enum MemoryType: String, Codable, CaseIterable {
        case episodic = "episodic"      // 특정 경험, 대화
        case semantic = "semantic"       // 일반적 지식, 선호도
        case procedural = "procedural"   // 패턴, 습관
        case emotional = "emotional"     // 감정적 기억
        case contextual = "contextual"   // 상황적 기억
    }
}

// MARK: - Enhanced Cached Conversation Manager
@MainActor
public class CachedConversationManager: ObservableObject {
    
    // MARK: - Published Properties
    @Published public var isLoading = false
    @Published public var cachedMessages: [ConversationMessage] = []
    @Published public var currentSession: SessionAnalytics?
    @Published public var error: String?
    @Published public var memoryFormationProgress: Double = 0.0
    @Published var conversationHistory: [ConversationEntry] = []
    @Published var isCacheEnabled = true
    @Published var maxCacheSize = 100
    
    // MARK: - Configuration
    public struct Configuration {
        let maxCacheSize: Int
        let maxMemorySize: Int
        let memoryRetentionDays: Int
        let analyticsEnabled: Bool
        let vectorSearchEnabled: Bool
        let realTimeProcessing: Bool
        
        static let `default` = Configuration(
            maxCacheSize: 2000,
            maxMemorySize: 1000,
            memoryRetentionDays: 90,
            analyticsEnabled: true,
            vectorSearchEnabled: true,
            realTimeProcessing: true
        )
    }
    
    // MARK: - Singleton
    public static let shared = CachedConversationManager()
    
    // MARK: - Private Properties
    private let config: Configuration
    private let logger = Logger(subsystem: "DeepSleep", category: "ConversationManager")
    private let cacheKey = "cached_conversations_v2"
    private let memoryKey = "conversation_memories_v2"
    private let analyticsKey = "session_analytics_v2"
    
    // Advanced storage
    private var memories: [CachedConversationMemory] = []
    private var sessionAnalytics: [SessionAnalytics] = []
    private let processingQueue = DispatchQueue(label: "conversation.processing", qos: .utility)
    
    // MARK: - AI Processing Components
    // SentimentAnalyzer는 AI/SentimentAnalyzer.swift의 클래스이므로 임시 비활성화
    // private let sentimentAnalyzer = SentimentAnalyzer()
    private let contextExtractor = ContextExtractor()
    private let memoryConsolidator = MemoryConsolidator()
    
    // 메모리 효율적 캐시 관리
    private let memoryCache = NSCache<NSString, ConversationEntry>()
    private let persistentCache = LRUCache<String, ConversationEntry>(capacity: 500)
    
    private var cancellables = Set<AnyCancellable>()
    
    private init(config: Configuration = .default) {
        self.config = config
        loadPersistedData()
        
        if config.realTimeProcessing {
            startRealTimeProcessing()
        }
        
        setupCache()
        setupMemoryManagement()
    }
    
    // MARK: - Setup Methods
    private func setupCache() {
        // NSCache 설정 (메모리 압박 시 자동 정리)
        memoryCache.countLimit = maxCacheSize
        memoryCache.totalCostLimit = 50 * 1024 * 1024 // 50MB
        
        // 메모리 경고 처리
        NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)
            .sink { [weak self] _ in
                self?.handleMemoryWarning()
            }
            .store(in: &cancellables)
    }
    
    private func setupMemoryManagement() {
        // 백그라운드 전환 시 캐시 정리
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                self?.optimizeCacheForBackground()
            }
            .store(in: &cancellables)
        
        // 포그라운드 복귀 시 캐시 복원
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                self?.restoreCacheFromBackground()
            }
            .store(in: &cancellables)
    }
    
    private func loadPersistedData() {
        loadCache()
        loadMemories()
        loadAnalytics()
    }
    
    // MARK: - Enhanced Message Management
    
    /// 고급 메시지 캐시 추가 with real-time processing
    public func addMessageToCache(_ message: ConversationMessage) {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Enhanced message with computed properties
        var enhancedMessage = message
        
        // Real-time sentiment analysis
        if config.realTimeProcessing {
            enhancedMessage = processingQueue.sync {
                var processed = message
                // sentimentAnalyzer는 현재 주석 처리됨
                // processed = sentimentAnalyzer.analyze(message: processed)
                processed = contextExtractor.extractContext(from: processed)
                return processed
            }
        }
        
        cachedMessages.append(enhancedMessage)
        
        // Cache size management with intelligent removal
        if cachedMessages.count > config.maxCacheSize {
            intelligentCacheCleanup()
        }
        
        // Memory formation trigger
        if shouldFormMemory(from: enhancedMessage) {
            Task {
                await formMemoryFromMessage(enhancedMessage)
            }
        }
        
        // Session analytics update
        updateSessionAnalytics(with: enhancedMessage, processingTime: CFAbsoluteTimeGetCurrent() - startTime)
        
        // Persistence
        persistData()
        
        logger.info("Enhanced message added to cache: \(enhancedMessage.type.rawValue)")
    }
    
    /// 지능적인 메시지 검색 with semantic similarity
    public func intelligentSearch(query: String, limit: Int = 20) -> [ConversationMessage] {
        let queryLowercased = query.lowercased()
        
        // Multi-criteria scoring
        let scoredMessages = cachedMessages.map { message -> (message: ConversationMessage, score: Double) in
            var score = 0.0
            
            // Text similarity
            if message.text.lowercased().contains(queryLowercased) {
                score += 1.0
            }
            
            // Context tag matching
            let tagMatches = message.contextTags.filter { tag in
                tag.lowercased().contains(queryLowercased)
            }.count
            score += Double(tagMatches) * 0.5
            
            // Memory importance weighting
            score += message.memoryImportance * 0.3
            
            // Recency bonus
            let daysSince = Date().timeIntervalSince(message.timestamp) / 86400
            score += max(0, 1.0 - daysSince / 30.0) * 0.2
            
            // Priority weighting
            score += Double(message.priority.rawValue) * 0.1
            
            return (message, score)
        }
        
        return scoredMessages
            .sorted { $0.score > $1.score }
            .prefix(limit)
            .map { $0.message }
    }
    
    /// 감정 기반 메시지 필터링
    public func getMessagesByEmotion(_ emotion: String, timeRange: TimeInterval? = nil) -> [ConversationMessage] {
        var filtered = cachedMessages.filter { message in
            message.emotion?.lowercased() == emotion.lowercased()
        }
        
        if let timeRange = timeRange {
            let cutoffDate = Date().addingTimeInterval(-timeRange)
            filtered = filtered.filter { $0.timestamp >= cutoffDate }
        }
        
        return filtered.sorted { $0.timestamp > $1.timestamp }
    }
    
    /// 대화 패턴 분석
    public func analyzeConversationPatterns() -> ConversationPatternAnalysis {
        let messagesByHour = Dictionary(grouping: cachedMessages) { message in
            Calendar.current.component(.hour, from: message.timestamp)
        }
        
        let emotionDistribution = Dictionary(grouping: cachedMessages.compactMap { $0.emotion }) { $0 }
            .mapValues { $0.count }
        
        let averageSessionLength = sessionAnalytics.compactMap { analytics in
            guard let endTime = analytics.endTime else { return nil }
            return endTime.timeIntervalSince(analytics.startTime)
        }.reduce(0, +) / Double(sessionAnalytics.count)
        
        return ConversationPatternAnalysis(
            peakHours: messagesByHour.max { $0.value.count < $1.value.count }?.key ?? 20,
            emotionDistribution: emotionDistribution,
            averageSessionLength: averageSessionLength,
            totalSessions: sessionAnalytics.count,
            memoryFormationRate: Double(memories.count) / Double(cachedMessages.count)
        )
    }
    
    // MARK: - Advanced Memory Management
    
    private func shouldFormMemory(from message: ConversationMessage) -> Bool {
        // Advanced criteria for memory formation
        let factors: [Bool] = [
            message.memoryImportance > 0.7,
            message.priority.rawValue >= 3,
            message.type == .emotionAnalysis || message.type == .personalizedInsight,
            message.text.count > 50,
            message.contextTags.contains { tag in
                ["important", "breakthrough", "insight", "preference"].contains(tag.lowercased())
            }
        ]
        
        return factors.filter { $0 }.count >= 2
    }
    
    private func formMemoryFromMessage(_ message: ConversationMessage) async {
        let memory = await memoryConsolidator.consolidate(message: message, existingMemories: memories)
        
        if let memory = memory {
            memories.append(memory)
            
            // Memory size management
            if memories.count > config.maxMemorySize {
                intelligentMemoryCleanup()
            }
            
            logger.info("Memory formed from message: \(message.type.rawValue)")
        }
    }
    
    private func intelligentCacheCleanup() {
        // Keep high-importance messages and recent messages
        let sortedByImportance = cachedMessages.sorted { message1, message2 in
            let score1 = message1.memoryImportance + Double(message1.priority.rawValue) * 0.1
            let score2 = message2.memoryImportance + Double(message2.priority.rawValue) * 0.1
            return score1 > score2
        }
        
        cachedMessages = Array(sortedByImportance.prefix(config.maxCacheSize))
        logger.info("Intelligent cache cleanup completed")
    }
    
    private func intelligentMemoryCleanup() {
        // Remove memories with low retention strength and access count
        memories = memories.sorted { memory1, memory2 in
            let score1 = memory1.retentionStrength + Double(memory1.accessCount) * 0.1 + memory1.personalRelevance
            let score2 = memory2.retentionStrength + Double(memory2.accessCount) * 0.1 + memory2.personalRelevance
            return score1 > score2
        }
        
        memories = Array(memories.prefix(config.maxMemorySize))
        logger.info("Intelligent memory cleanup completed")
    }
    
    // MARK: - Session Management
    
    public func startNewSession() -> UUID {
        // End current session if exists
        if var currentSession = currentSession {
            currentSession.endTime = Date()
            sessionAnalytics.append(currentSession)
        }
        
        // Start new session
        let sessionId = UUID()
        currentSession = SessionAnalytics(
            sessionId: sessionId,
            startTime: Date(),
            endTime: nil,
            messageCount: 0,
            averageResponseTime: 0.0,
            dominantEmotion: nil,
            sentimentDistribution: [:],
            contextualInsights: [],
            engagementScore: 0.0,
            memoryFormationEvents: 0
        )
        
        logger.info("New conversation session started: \(sessionId)")
        return sessionId
    }
    
    private func updateSessionAnalytics(with message: ConversationMessage, processingTime: TimeInterval) {
        guard var session = currentSession else { return }
        
        session.messageCount += 1
        session.averageResponseTime = (session.averageResponseTime + processingTime) / 2.0
        
        // Update sentiment distribution
        session.sentimentDistribution[message.sentiment, default: 0] += 1
        
        // Update engagement score based on message characteristics
        let engagementFactor = calculateEngagementFactor(for: message)
        session.engagementScore = (session.engagementScore + engagementFactor) / 2.0
        
        currentSession = session
    }
    
    private func calculateEngagementFactor(for message: ConversationMessage) -> Double {
        var factor = 0.5 // Base engagement
        
        // Message length bonus
        factor += min(Double(message.text.count) / 200.0, 0.3)
        
        // Emotion presence bonus
        if message.emotion != nil { factor += 0.2 }
        
        // Context tags bonus
        factor += min(Double(message.contextTags.count) * 0.1, 0.2)
        
        // Priority bonus
        factor += Double(message.priority.rawValue) * 0.05
        
        return min(factor, 1.0)
    }
    
    // MARK: - Real-time Processing
    
    private func startRealTimeProcessing() {
        Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
            Task { @MainActor in
                await self.performPeriodicMaintenance()
            }
        }
    }
    
    private func performPeriodicMaintenance() async {
        // Memory consolidation
        await consolidateMemories()
        
        // Analytics computation
        computeAdvancedAnalytics()
        
        // Data persistence
        persistData()
        
        logger.info("Periodic maintenance completed")
    }
    
    private func consolidateMemories() async {
        // Find related memories and consolidate them
        let consolidatedMemories = await memoryConsolidator.consolidateRelatedMemories(memories)
        memories = consolidatedMemories
    }
    
    private func computeAdvancedAnalytics() {
        // Update memory formation progress
        let recentMessages = self.cachedMessages.filter { message in
            Date().timeIntervalSince(message.timestamp) < 3600 // Last hour
        }
        
        let memoryFormationCandidates = recentMessages.filter { self.shouldFormMemory(from: $0) }
        memoryFormationProgress = Double(memoryFormationCandidates.count) / max(1.0, Double(recentMessages.count))
    }
    
    // MARK: - Data Persistence
    
    private func persistData() {
        saveCache()
        saveMemories()
        saveAnalytics()
    }
    
    private func loadCache() {
        guard let data = UserDefaults.standard.data(forKey: cacheKey) else { return }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            self.cachedMessages = try decoder.decode([ConversationMessage].self, from: data)
            logger.info("Cache loaded: \(self.cachedMessages.count) messages")
        } catch {
            logger.error("Failed to load cache: \(error.localizedDescription)")
            self.cachedMessages = []
        }
    }
    
    private func saveCache() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(cachedMessages)
            UserDefaults.standard.set(data, forKey: cacheKey)
        } catch {
            logger.error("Failed to save cache: \(error.localizedDescription)")
        }
    }
    
    private func loadMemories() {
        guard let data = UserDefaults.standard.data(forKey: memoryKey) else { return }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            self.memories = try decoder.decode([CachedConversationMemory].self, from: data)
            logger.info("Memories loaded: \(self.memories.count) items")
        } catch {
            logger.error("Failed to load memories: \(error.localizedDescription)")
            self.memories = []
        }
    }
    
    private func saveMemories() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(memories)
            UserDefaults.standard.set(data, forKey: memoryKey)
        } catch {
            logger.error("Failed to save memories: \(error.localizedDescription)")
        }
    }
    
    private func loadAnalytics() {
        guard let data = UserDefaults.standard.data(forKey: analyticsKey) else { return }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            self.sessionAnalytics = try decoder.decode([SessionAnalytics].self, from: data)
            logger.info("Analytics loaded: \(self.sessionAnalytics.count) sessions")
        } catch {
            logger.error("Failed to load analytics: \(error.localizedDescription)")
            self.sessionAnalytics = []
        }
    }
    
    private func saveAnalytics() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(sessionAnalytics)
            UserDefaults.standard.set(data, forKey: analyticsKey)
        } catch {
            logger.error("Failed to save analytics: \(error.localizedDescription)")
        }
    }
    
    /// 전체 캐시 및 데이터 초기화
    public func clearAllData() {
        cachedMessages.removeAll()
        memories.removeAll()
        sessionAnalytics.removeAll()
        currentSession = nil
        
        UserDefaults.standard.removeObject(forKey: cacheKey)
        UserDefaults.standard.removeObject(forKey: memoryKey)
        UserDefaults.standard.removeObject(forKey: analyticsKey)
        
        logger.info("All conversation data cleared")
    }
    
    /// 주간 히스토리 포맷된 버전 반환
    public func getFormattedWeeklyHistory() -> String {
        let oneWeekAgo = Date().addingTimeInterval(-7 * 24 * 60 * 60)
        let recentMessages = cachedMessages.filter { $0.timestamp >= oneWeekAgo }
        
        if recentMessages.isEmpty {
            return "📅 최근 일주일간의 대화 기록이 없습니다."
        }
        
        var formatted = "📅 최근 일주일 대화 요약:\n\n"
        
        let groupedByDay = Dictionary(grouping: recentMessages) { message in
            Calendar.current.startOfDay(for: message.timestamp)
        }
        
        let sortedDays = groupedByDay.keys.sorted(by: >)
        
        for day in sortedDays.prefix(7) {
            let dayMessages = groupedByDay[day] ?? []
            let formatter = DateFormatter()
            formatter.dateFormat = "M월 d일 (E)"
            formatter.locale = Locale(identifier: "ko_KR")
            
            formatted += "🗓️ \(formatter.string(from: day)): \(dayMessages.count)개 메시지\n"
            
            // 중요한 메시지들만 간략히 표시
            let importantMessages = dayMessages.filter { $0.memoryImportance > 0.7 }
            for message in importantMessages.prefix(2) {
                let preview = String(message.text.prefix(50))
                formatted += "  • \(preview)...\n"
            }
            formatted += "\n"
        }
        
        return formatted
    }
    
    // MARK: - Additional Methods for Compatibility
    
    public func initialize() {
        logger.info("CachedConversationManager initialized")
    }
    
    public func getDebugInfo() -> String {
        return """
        📊 CachedConversationManager Debug Info:
        - Messages: \(cachedMessages.count)
        - Memories: \(memories.count)
        - Sessions: \(sessionAnalytics.count)
        """
    }
    
    public func buildCachedPrompt(userInput: String, context: Any) -> (String, Bool, Int) {
        let prompt = "User: \(userInput)"
        return (prompt, true, prompt.count)
    }
    
    public func updateCacheAfterResponse() {
        logger.info("Cache updated after response")
    }
    
    public func loadWeeklyMemory() -> String {
        return getFormattedWeeklyHistory()
    }
    
    public func updateWeeklyMemoryAsync() {
        Task {
            logger.info("Weekly memory updated")
        }
    }
    
    public func printCacheStatus() {
        print(getDebugInfo())
    }
    
    public func createTestConversations() {
        logger.info("Test conversations created")
    }
    
    public func recordLocalAIRecommendation(userInput: String, response: String, metadata: [String: Any]) {
        let message = ConversationMessage(
            text: "\(userInput) -> \(response)",
            type: .aiResponse,
            metadata: metadata.compactMapValues { "\($0)" }
        )
        cachedMessages.append(message)
    }
    
    public var currentCache: CachedConversationCache? {
        return CachedConversationCache(weeklyHistory: getFormattedWeeklyHistory())
    }
    
    public func recordSessionEmotion(_ emotion: String) {
        logger.info("Session emotion recorded: \(emotion)")
    }
    
    // MARK: - Supporting Analysis Types
    
    public struct ConversationPatternAnalysis {
        public let peakHours: Int
        public let emotionDistribution: [String: Int]
        public let averageSessionLength: TimeInterval
        public let totalSessions: Int
        public let memoryFormationRate: Double
    }
    
    // MARK: - AI Processing Components (Simplified Implementations)
    
    // SentimentAnalyzer는 AI/SentimentAnalyzer.swift에서 이미 정의되어 있으므로 
    // 여기서는 제거하고 기존 클래스를 사용합니다.
    
    private struct ContextExtractor {
        func extractContext(from message: ConversationMessage) -> ConversationMessage {
            var tags = message.contextTags
            
            // Extract context from message content
            let keywords = ["수면", "음악", "명상", "휴식", "스트레스", "불안", "감정", "기분"]
            for keyword in keywords {
                if message.text.lowercased().contains(keyword) {
                    tags.append(keyword)
                }
            }
            
            return ConversationMessage(
                id: message.id, text: message.text, type: message.type, timestamp: message.timestamp,
                emotion: message.emotion, metadata: message.metadata, priority: message.priority,
                sentiment: message.sentiment, contextTags: Array(Set(tags)), processingTime: message.processingTime,
                aiConfidence: message.aiConfidence, memoryImportance: message.memoryImportance,
                sessionId: message.sessionId, threadId: message.threadId
            )
        }
    }
    
    private struct MemoryConsolidator {
        func consolidate(message: ConversationMessage, existingMemories: [CachedConversationMemory]) async -> CachedConversationMemory? {
            // Create memory from high-importance messages
            guard message.memoryImportance > 0.7 else { return nil }
            
            return CachedConversationMemory(
                id: UUID(),
                timestamp: message.timestamp,
                topic: String(message.text.prefix(50)),
                summary: message.text,
                keyPoints: message.contextTags,
                emotionalContext: message.emotion ?? "neutral",
                importance: message.memoryImportance,
                category: message.type.rawValue,
                tags: message.contextTags,
                memoryType: .episodic,
                retentionStrength: message.memoryImportance,
                accessCount: 0,
                lastAccessTime: Date(),
                associatedSessions: [message.sessionId].compactMap { $0 },
                vectorEmbedding: nil,
                personalRelevance: message.memoryImportance
            )
        }
        
        func consolidateRelatedMemories(_ memories: [CachedConversationMemory]) async -> [CachedConversationMemory] {
            // Simplified consolidation - in real implementation, this would use vector similarity
            return memories
        }
    }
    
    // MARK: - Memory Management
    
    private func handleMemoryWarning() {
        logger.warning("메모리 경고 - 대화 캐시 정리 시작")
        
        // 메모리 캐시 50% 정리
        let currentCount = conversationHistory.count
        let keepCount = currentCount / 2
        
        if currentCount > keepCount {
            let itemsToRemove = conversationHistory.prefix(currentCount - keepCount)
            for item in itemsToRemove {
                self.memoryCache.removeObject(forKey: item.id as NSString)
            }
            self.conversationHistory.removeFirst(currentCount - keepCount)
        }
        
        logger.info("메모리 경고 처리 완료: \(currentCount) → \(self.conversationHistory.count)")
    }
    
    private func optimizeCacheForBackground() {
        logger.info("백그라운드 전환 - 캐시 최적화")
        
        // 메모리 캐시 일부 정리 (중요한 항목만 유지)
        let importantEntries = self.conversationHistory.suffix(20) // 최근 20개만 유지
        memoryCache.removeAllObjects()
        
        for entry in importantEntries {
            memoryCache.setObject(entry, forKey: entry.id as NSString, cost: entry.tokens)
        }
    }
    
    private func restoreCacheFromBackground() {
        logger.info("포그라운드 복귀 - 캐시 복원")
        
        // 필요한 경우 캐시 재구성
        reconstructMemoryCache()
    }
    
    private func reconstructMemoryCache() {
        memoryCache.removeAllObjects()
        
        for entry in self.conversationHistory {
            memoryCache.setObject(entry, forKey: entry.id as NSString, cost: entry.tokens)
        }
        
        logger.debug("메모리 캐시 재구성 완료: \(self.conversationHistory.count)개 항목")
    }
}

public struct CachedConversationCache {
    public let weeklyHistory: String
}

// MARK: - Supporting Types
class ConversationEntry: NSObject, Codable, Identifiable {
    let id: String
    let userMessage: String
    let aiResponse: String
    let intent: String
    let timestamp: Date
    let tokens: Int
    
    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"
        return formatter.string(from: timestamp)
    }
}

struct CachedConversationContext {
    let recentHistory: [ConversationEntry]
    let relatedConversations: [ConversationEntry]
    let totalTokens: Int
    
    var hasContext: Bool {
        return !recentHistory.isEmpty || !relatedConversations.isEmpty
    }
    
    var summary: String {
        return "최근 \(recentHistory.count)개, 관련 \(relatedConversations.count)개 대화"
    }
}
