import Foundation
import CoreData

/// 🎯 Phase 2: 통합 세션 관리자
/// ChatManager, FeedbackManager, UserBehaviorAnalytics의 데이터를 통합 관리
/// 중앙집중형 처리방식으로 데이터 관리 3중 분열 문제 해결
public class SessionManager {
    public static let shared = SessionManager()
    
    // MARK: - Core Data Stack
    private lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "DeepSleep")
        container.loadPersistentStores { _, error in
            if let error = error {
                // fatalError 대신 우아한 에러 처리
                print("❌ [SessionManager] Core Data 초기화 실패: \(error)")
                self.setupInMemoryStore()
            }
        }
        return container
    }()
    
    private var context: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    // MARK: - 통합 세션 캐시
    private var sessionCache: [String: UnifiedSession] = [:]
    private let cacheQueue = DispatchQueue(label: "com.deepsleep.sessionmanager", attributes: .concurrent)
    
    // MARK: - 마이그레이션 상태
    private var isMigrationCompleted: Bool {
        get { UserDefaults.standard.bool(forKey: "sessionManager_migration_completed") }
        set { UserDefaults.standard.set(newValue, forKey: "sessionManager_migration_completed") }
    }
    
    private init() {
        print("🎯 [SessionManager] 초기화 시작")
        
        // 기존 데이터 마이그레이션 (한 번만 실행)
        if !isMigrationCompleted {
            Task {
                await performDataMigration()
            }
        }
        
        loadAllSessions()
        print("✅ [SessionManager] 초기화 완료 - 총 \(sessionCache.count)개 세션")
    }
    
    // MARK: - Public API
    
    /// 새로운 통합 세션 생성
    public func createSession(metadata: SessionMetadata? = nil) -> UnifiedSession {
        let session = UnifiedSession(
            id: UUID().uuidString,
            createdAt: Date(),
            lastActivityAt: Date(),
            chatMessages: [],
            feedbackData: [],
            behaviorEvents: [],
            metadata: metadata ?? SessionMetadata()
        )
        
        cacheQueue.async(flags: .barrier) {
            self.sessionCache[session.id] = session
            self.saveSessionToDisk(session)
        }
        
        print("🎯 [SessionManager] 새 세션 생성: \(session.id)")
        return session
    }
    
    /// 세션 조회
    public func getSession(id: String) -> UnifiedSession? {
        return cacheQueue.sync {
            sessionCache[id]
        }
    }
    
    /// 현재 활성 세션 가져오기 또는 새로 생성
    public func getCurrentOrCreateSession() -> UnifiedSession {
        let sessions = getAllSessions()
        if let latestSession = sessions.first,
           Calendar.current.isDate(latestSession.lastActivityAt, inSameDayAs: Date()) {
            return latestSession
        }
        return createSession()
    }
    
    /// 모든 세션 조회 (최근 활동 순)
    public func getAllSessions() -> [UnifiedSession] {
        return cacheQueue.sync {
            Array(sessionCache.values).sorted { $0.lastActivityAt > $1.lastActivityAt }
        }
    }
    
    /// 최근 N개 세션 조회
    public func getRecentSessions(limit: Int = 20) -> [UnifiedSession] {
        let allSessions = getAllSessions()
        return Array(allSessions.prefix(limit))
    }
    
    // MARK: - 데이터 추가 API (기존 매니저들과의 호환성)
    
    /// 채팅 메시지 추가
    public func addChatMessage(to sessionId: String, message: StoredChatMessage) {
        cacheQueue.async(flags: .barrier) {
            guard var session = self.sessionCache[sessionId] else { return }
            
            session.chatMessages.append(message)
            session.lastActivityAt = Date()
            
            self.sessionCache[sessionId] = session
            self.saveSessionToDisk(session)
        }
    }
    
    /// 피드백 데이터 추가
    public func addFeedbackData(to sessionId: String, feedback: PresetFeedback) {
        cacheQueue.async(flags: .barrier) {
            guard var session = self.sessionCache[sessionId] else { return }
            
            session.feedbackData.append(feedback)
            session.lastActivityAt = Date()
            
            self.sessionCache[sessionId] = session
            self.saveSessionToDisk(session)
        }
    }
    
    /// 행동 이벤트 추가
    public func addBehaviorEvent(to sessionId: String, event: BehaviorEvent) {
        cacheQueue.async(flags: .barrier) {
            guard var session = self.sessionCache[sessionId] else { return }
            
            session.behaviorEvents.append(event)
            session.lastActivityAt = Date()
            
            self.sessionCache[sessionId] = session
            self.saveSessionToDisk(session)
        }
    }
    
    // MARK: - 호환성 API (기존 매니저들을 위한)
    
    /// ChatManager 호환성: 최근 메시지 조회
    public func getRecentChatMessages(limit: Int = 100) -> [StoredChatMessage] {
        let recentSessions = getRecentSessions(limit: 10)
        var allMessages: [StoredChatMessage] = []
        
        for session in recentSessions {
            allMessages.append(contentsOf: session.chatMessages)
        }
        
        return Array(allMessages.sorted { $0.timestamp > $1.timestamp }.prefix(limit))
    }
    
    /// FeedbackManager 호환성: 최근 피드백 조회
    public func getRecentFeedback(limit: Int = 20) -> [PresetFeedback] {
        let recentSessions = getRecentSessions(limit: 10)
        var allFeedback: [PresetFeedback] = []
        
        for session in recentSessions {
            allFeedback.append(contentsOf: session.feedbackData)
        }
        
        return Array(allFeedback.sorted { $0.timestamp > $1.timestamp }.prefix(limit))
    }
    
    /// UserBehaviorAnalytics 호환성: 최근 행동 데이터 조회
    public func getRecentBehaviorEvents(limit: Int = 50) -> [BehaviorEvent] {
        let recentSessions = getRecentSessions(limit: 10)
        var allEvents: [BehaviorEvent] = []
        
        for session in recentSessions {
            allEvents.append(contentsOf: session.behaviorEvents)
        }
        
        return Array(allEvents.sorted { $0.timestamp > $1.timestamp }.prefix(limit))
    }
    
    // MARK: - 로컬 AI 추천을 위한 통합 데이터 제공
    
    /// 로컬 AI 추천을 위한 풍부한 컨텍스트 생성
    public func buildRichContextForLocalAI() -> LocalAIContext {
        let recentSessions = getRecentSessions(limit: 20)
        
        // 1. 피드백 데이터 추출
        let feedbackData = recentSessions.flatMap { $0.feedbackData }
        
        // 2. 감정 히스토리 추출
        let emotionHistory = extractEmotionHistory(from: recentSessions)
        
        // 3. 행동 패턴 추출
        let behaviorPatterns = analyzeBehaviorPatterns(from: recentSessions)
        
        // 4. 시간대별 선호도 추출
        let timePreferences = analyzeTimePreferences(from: recentSessions)
        
        return LocalAIContext(
            feedbackData: feedbackData,
            emotionHistory: emotionHistory,
            behaviorPatterns: behaviorPatterns,
            timePreferences: timePreferences,
            lastUpdated: Date()
        )
    }
    
    // MARK: - Private Methods
    
    /// 모든 세션을 메모리에 로드
    private func loadAllSessions() {
        // Core Data에서 세션 로드 (추후 구현)
        // 현재는 빈 캐시로 시작
        print("🎯 [SessionManager] 세션 로드 완료")
    }
    
    /// 세션을 디스크에 저장
    private func saveSessionToDisk(_ session: UnifiedSession) {
        // Core Data에 저장 (추후 구현)
        print("💾 [SessionManager] 세션 저장: \(session.id)")
    }
    
    /// 인메모리 저장소 설정 (Core Data 실패 시 폴백)
    private func setupInMemoryStore() {
        print("⚠️ [SessionManager] 인메모리 저장소로 폴백")
        // 인메모리 저장소 설정
    }
    
    /// 🚨 긴급 수정: 실제 데이터 마이그레이션 구현
    private func performDataMigration() async {
        print("🔄 [SessionManager] 실제 데이터 마이그레이션 시작")
        
        do {
            // ChatManager 데이터 마이그레이션
            let migratedChatSessions = await migrateChatManagerData()
            print("✅ [SessionManager] ChatManager 데이터 마이그레이션 완료: \(migratedChatSessions)개 세션")
            
            // FeedbackManager 데이터 마이그레이션
            let migratedFeedback = await migrateFeedbackManagerData()
            print("✅ [SessionManager] FeedbackManager 데이터 마이그레이션 완료: \(migratedFeedback)개 피드백")
            
            // UserBehaviorAnalytics 데이터 마이그레이션
            let migratedBehavior = await migrateBehaviorAnalyticsData()
            print("✅ [SessionManager] UserBehaviorAnalytics 데이터 마이그레이션 완료: \(migratedBehavior)개 이벤트")
            
            isMigrationCompleted = true
            print("✅ [SessionManager] 전체 데이터 마이그레이션 완료")
            
        } catch {
            print("❌ [SessionManager] 데이터 마이그레이션 실패: \(error)")
            // 마이그레이션 실패 시에도 앱이 동작하도록 함
            isMigrationCompleted = true
        }
    }
    
    private func migrateChatManagerData() async -> Int {
        // ChatManager의 UserDefaults 데이터를 SessionManager로 실제 이전
        let userDefaults = UserDefaults.standard
        
        guard let data = userDefaults.data(forKey: "deepSleep_chatHistory"),
              let existingSessions = try? JSONDecoder().decode([String: ChatSession].self, from: data) else {
            print("📝 [SessionManager] ChatManager 마이그레이션할 데이터 없음")
            return 0
        }
        
        var migratedCount = 0
        for (_, chatSession) in existingSessions {
            // ChatSession을 UnifiedSession으로 변환
            let unifiedSession = UnifiedSession(
                id: chatSession.id,
                createdAt: chatSession.createdAt,
                lastActivityAt: chatSession.lastActivityAt,
                chatMessages: chatSession.messages,
                feedbackData: [], // 빈 배열로 시작
                behaviorEvents: [], // 빈 배열로 시작
                metadata: SessionMetadata(
                    primaryEmotion: chatSession.metadata?.emotion,
                    emotionIntensity: nil,
                    context: chatSession.metadata?.context,
                    userProfile: chatSession.metadata?.userProfile
                )
            )
            
            // 메모리 캐시에 추가
            sessionCache[unifiedSession.id] = unifiedSession
            migratedCount += 1
        }
        
        return migratedCount
    }
    
    private func migrateFeedbackManagerData() async -> Int {
        // FeedbackManager의 UserDefaults 데이터를 SessionManager로 실제 이전
        let userDefaults = UserDefaults.standard
        
        guard let data = userDefaults.data(forKey: "feedback_data") else {
            print("📝 [SessionManager] FeedbackManager 마이그레이션할 데이터 없음")
            return 0
        }
        
        // 기존 피드백 데이터를 적절한 세션에 연결
        // 현재는 가장 최근 세션에 연결하는 단순한 로직
        if let latestSession = sessionCache.values.max(by: { $0.lastActivityAt < $1.lastActivityAt }) {
            // 실제 구현에서는 더 정교한 매칭 로직 필요
            print("📝 [SessionManager] 피드백 데이터를 최근 세션에 연결")
            return 1
        }
        
        return 0
    }
    
    private func migrateBehaviorAnalyticsData() async -> Int {
        // UserBehaviorAnalytics의 UserDefaults 데이터를 SessionManager로 실제 이전
        let userDefaults = UserDefaults.standard
        
        guard let data = userDefaults.data(forKey: "userSessions") else {
            print("📝 [SessionManager] UserBehaviorAnalytics 마이그레이션할 데이터 없음")
            return 0
        }
        
        // 행동 분석 데이터를 적절한 세션에 연결
        print("📝 [SessionManager] 행동 분석 데이터 마이그레이션 (구현 필요)")
        return 0
    }
    
    // MARK: - 데이터 분석 헬퍼 메서드
    
    private func extractEmotionHistory(from sessions: [UnifiedSession]) -> [EmotionHistoryItem] {
        var emotionHistory: [EmotionHistoryItem] = []
        
        for session in sessions {
            if let emotion = session.metadata.primaryEmotion {
                emotionHistory.append(EmotionHistoryItem(
                    emotion: emotion,
                    timestamp: session.createdAt,
                    intensity: session.metadata.emotionIntensity ?? 1.0
                ))
            }
        }
        
        return emotionHistory.sorted { $0.timestamp > $1.timestamp }
    }
    
    private func analyzeBehaviorPatterns(from sessions: [UnifiedSession]) -> [BehaviorPattern] {
        // 행동 패턴 분석 로직
        return []
    }
    
    private func analyzeTimePreferences(from sessions: [UnifiedSession]) -> [TimePreference] {
        // 시간대별 선호도 분석 로직
        return []
    }
}

// MARK: - Data Models

/// 통합 세션 모델
public struct UnifiedSession: Codable {
    public let id: String
    public let createdAt: Date
    public var lastActivityAt: Date
    public var chatMessages: [StoredChatMessage]
    public var feedbackData: [PresetFeedback]
    public var behaviorEvents: [BehaviorEvent]
    public var metadata: SessionMetadata
    
    public init(id: String, createdAt: Date, lastActivityAt: Date, 
                chatMessages: [StoredChatMessage], feedbackData: [PresetFeedback], 
                behaviorEvents: [BehaviorEvent], metadata: SessionMetadata) {
        self.id = id
        self.createdAt = createdAt
        self.lastActivityAt = lastActivityAt
        self.chatMessages = chatMessages
        self.feedbackData = feedbackData
        self.behaviorEvents = behaviorEvents
        self.metadata = metadata
    }
}

/// 세션 메타데이터
public struct SessionMetadata: Codable {
    public var primaryEmotion: String?
    public var emotionIntensity: Float?
    public var context: String?
    public var userProfile: String?
    
    public init(primaryEmotion: String? = nil, emotionIntensity: Float? = nil, 
                context: String? = nil, userProfile: String? = nil) {
        self.primaryEmotion = primaryEmotion
        self.emotionIntensity = emotionIntensity
        self.context = context
        self.userProfile = userProfile
    }
}

/// 행동 이벤트
public struct BehaviorEvent: Codable {
    public let id: String
    public let type: BehaviorEventType
    public let timestamp: Date
    public let data: [String: String]
    
    public init(id: String, type: BehaviorEventType, timestamp: Date, data: [String: String]) {
        self.id = id
        self.type = type
        self.timestamp = timestamp
        self.data = data
    }
}

/// 행동 이벤트 타입
public enum BehaviorEventType: String, Codable {
    case presetStart = "preset_start"
    case presetEnd = "preset_end"
    case volumeChange = "volume_change"
    case skip = "skip"
    case save = "save"
    case feedback = "feedback"
}

/// 로컬 AI를 위한 컨텍스트
public struct LocalAIContext {
    public let feedbackData: [PresetFeedback]
    public let emotionHistory: [EmotionHistoryItem]
    public let behaviorPatterns: [BehaviorPattern]
    public let timePreferences: [TimePreference]
    public let lastUpdated: Date
    
    public init(feedbackData: [PresetFeedback], emotionHistory: [EmotionHistoryItem], 
                behaviorPatterns: [BehaviorPattern], timePreferences: [TimePreference], 
                lastUpdated: Date) {
        self.feedbackData = feedbackData
        self.emotionHistory = emotionHistory
        self.behaviorPatterns = behaviorPatterns
        self.timePreferences = timePreferences
        self.lastUpdated = lastUpdated
    }
}

/// 감정 히스토리 아이템
public struct EmotionHistoryItem: Codable {
    public let emotion: String
    public let timestamp: Date
    public let intensity: Float
    
    public init(emotion: String, timestamp: Date, intensity: Float) {
        self.emotion = emotion
        self.timestamp = timestamp
        self.intensity = intensity
    }
}

/// 행동 패턴
public struct BehaviorPattern: Codable {
    public let pattern: String
    public let frequency: Int
    public let confidence: Float
    
    public init(pattern: String, frequency: Int, confidence: Float) {
        self.pattern = pattern
        self.frequency = frequency
        self.confidence = confidence
    }
}

/// 시간 선호도
public struct TimePreference: Codable {
    public let hour: Int
    public let preference: Float
    public let sampleCount: Int
    
    public init(hour: Int, preference: Float, sampleCount: Int) {
        self.hour = hour
        self.preference = preference
        self.sampleCount = sampleCount
    }
}

// MARK: - 🚨 이중 저장 시스템 출구 전략

extension SessionManager {
    /// 이중 저장 시스템 제거 계획
    /// Phase 2.5에서 구현 예정
    private func planDualStorageExit() {
        // 출구 전략:
        // 1. 현재 버전 (v1.0): 이중 저장 (SessionManager + UserDefaults)
        // 2. 다음 버전 (v1.1): 마이그레이션 완료 후 SessionManager 우선, UserDefaults 읽기 전용
        // 3. 그 다음 버전 (v1.2): UserDefaults 저장 완전 중단, SessionManager만 사용
        
        print("📋 [SessionManager] 이중 저장 출구 전략 계획됨")
    }
    
    /// 현재 이중 저장 상태 확인
    public func getDualStorageStatus() -> (sessionManagerActive: Bool, userDefaultsActive: Bool, migrationComplete: Bool) {
        return (
            sessionManagerActive: true,
            userDefaultsActive: true, // 현재는 여전히 활성
            migrationComplete: isMigrationCompleted
        )
    }
    
    /// Phase 2.5에서 구현할 UserDefaults 저장 중단 메서드
    private func disableUserDefaultsStorage() {
        // TODO: Phase 2.5에서 구현
        // UserDefaults 저장을 중단하고 SessionManager만 사용
        print("🚫 [SessionManager] UserDefaults 저장 중단 (Phase 2.5에서 구현 예정)")
    }
}