import Foundation
import CoreData

/// 🎯 Phase 2: 통합 세션 관리자 - Core Data 완전 통합
/// ChatManager, FeedbackManager, UserBehaviorAnalytics의 데이터를 통합 관리
/// 중앙집중형 처리방식으로 데이터 관리 3중 분열 문제 해결
public class SessionManager {
    public static let shared = SessionManager()
    
    // MARK: - Core Data Stack
    private let coreDataStack = CoreDataStack.shared
    
    private var context: NSManagedObjectContext {
        return coreDataStack.viewContext
    }
    
    // MARK: - 통합 세션 캐시
    private var sessionCache: [String: UnifiedSession] = [:]
    private let cacheQueue = DispatchQueue(label: "com.deepsleep.sessionmanager", attributes: .concurrent)
    
    // MARK: - 피드백 세션 관리 (FeedbackManager 통합)
    private var currentFeedbackSession: FeedbackSession?
    private let feedbackQueue = DispatchQueue(label: "com.deepsleep.feedback", attributes: .concurrent)
    
    // MARK: - 마이그레이션 상태
    private var isMigrationCompleted: Bool {
        get { UserDefaults.standard.bool(forKey: "sessionManager_migration_completed") }
        set { UserDefaults.standard.set(newValue, forKey: "sessionManager_migration_completed") }
    }
    
    private init() {
        print("🎯 [SessionManager] 초기화 시작")
        
        // Core Data 변경 알림 구독 (캐시 동기화)
        setupCoreDataNotifications()
        
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
    
    /// 데이터 플러시 (메모리 캐시를 Core Data에 저장)
    public func flush() {
        do {
            if context.hasChanges {
                try context.save()
                print("✅ [SessionManager] 데이터 플러시 완료")
            }
        } catch {
            print("❌ [SessionManager] 데이터 플러시 실패: \(error)")
        }
    }
    
    /// 새로운 통합 세션 생성 (에러 전파)
    public func createSession(metadata: SessionMetadata? = nil) throws -> UnifiedSession {
        let sessionEntity = UnifiedSessionEntity(context: context)
        sessionEntity.id = UUID()
        sessionEntity.createdAt = Date()
        sessionEntity.lastActivityAt = Date()
        
        // 메타데이터를 JSON으로 인코딩하여 저장
        if let metadata = metadata {
            sessionEntity.metadataData = try? JSONEncoder().encode(metadata)
        }
        
        // Core Data에 저장 (에러 전파)
        do {
            try saveContext()
        } catch {
            // 저장 실패 시 엔티티 삭제
            context.delete(sessionEntity)
            throw error
        }
        
        // struct 모델로 변환하여 반환
        let session = convertToUnifiedSession(from: sessionEntity)
        
        // 메모리 캐시에도 저장
        cacheQueue.async(flags: .barrier) {
            self.sessionCache[session.id] = session
        }
        
        print("🎯 [SessionManager] 새 세션 생성: \(session.id)")
        return session
    }
    
    /// 새로운 통합 세션 생성 (호환성 유지 - 에러 무시)
    public func createSessionSafely(metadata: SessionMetadata? = nil) -> UnifiedSession {
        do {
            return try createSession(metadata: metadata)
        } catch {
            print("❌ [SessionManager] 세션 생성 실패, 임시 세션 반환: \(error)")
            // 실패 시 임시 세션 반환 (메모리에만 존재)
            let tempSession = UnifiedSession(
                id: UUID().uuidString,
                createdAt: Date(),
                lastActivityAt: Date(),
                chatMessages: [],
                feedbackData: [],
                behaviorEvents: [],
                metadata: metadata ?? SessionMetadata()
            )
            
            cacheQueue.async(flags: .barrier) {
                self.sessionCache[tempSession.id] = tempSession
            }
            
            return tempSession
        }
    }
    
    /// 세션 조회
    public func getSession(id: String) -> UnifiedSession? {
        // 먼저 캐시에서 확인
        if let cachedSession = cacheQueue.sync(execute: { sessionCache[id] }) {
            return cachedSession
        }
        
        // 캐시에 없으면 Core Data에서 조회 (성능 최적화)
        return getSessionFromCoreData(id: id)
    }
    
    /// Core Data에서 세션 조회 (비동기 처리 가능)
    private func getSessionFromCoreData(id: String) -> UnifiedSession? {
        let request: NSFetchRequest<UnifiedSessionEntity> = UnifiedSessionEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        
        do {
            let sessionEntities = try context.fetch(request)
            if let sessionEntity = sessionEntities.first {
                let session = convertToUnifiedSession(from: sessionEntity)
                
                // 캐시에 저장
                cacheQueue.async(flags: .barrier) {
                    self.sessionCache[id] = session
                }
                
                return session
            }
        } catch {
            print("❌ [SessionManager] 세션 조회 실패: \(error)")
        }
        
        return nil
    }
    
    /// 비동기 세션 조회 (성능 최적화)
    public func getSessionAsync(id: String, completion: @escaping (UnifiedSession?) -> Void) {
        // 먼저 캐시에서 확인
        if let cachedSession = cacheQueue.sync(execute: { sessionCache[id] }) {
            completion(cachedSession)
            return
        }
        
        // 백그라운드에서 Core Data 조회
        coreDataStack.performBackgroundTask { backgroundContext in
            let request: NSFetchRequest<UnifiedSessionEntity> = UnifiedSessionEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1
            
            do {
                let sessionEntities = try backgroundContext.fetch(request)
                if let sessionEntity = sessionEntities.first {
                    let session = self.convertToUnifiedSession(from: sessionEntity)
                    
                    // 캐시에 저장
                    self.cacheQueue.async(flags: .barrier) {
                        self.sessionCache[id] = session
                    }
                    
                    DispatchQueue.main.async {
                        completion(session)
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(nil)
                    }
                }
            } catch {
                print("❌ [SessionManager] 비동기 세션 조회 실패: \(error)")
                DispatchQueue.main.async {
                    completion(nil)
                }
            }
        }
    }
    
    /// 현재 활성 세션 가져오기 또는 새로 생성
    public func getCurrentOrCreateSession() -> UnifiedSession {
        // 오늘 날짜의 세션을 Core Data에서 직접 조회
        let calendar = Calendar.current
        let today = Date()
        let startOfDay = calendar.startOfDay(for: today)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let request: NSFetchRequest<UnifiedSessionEntity> = UnifiedSessionEntity.fetchRequest()
        request.predicate = NSPredicate(format: "lastActivityAt >= %@ AND lastActivityAt < %@", startOfDay as NSDate, endOfDay as NSDate)
        request.sortDescriptors = [NSSortDescriptor(key: "lastActivityAt", ascending: false)]
        request.fetchLimit = 1
        
        do {
            let sessionEntities = try context.fetch(request)
            if let latestSessionEntity = sessionEntities.first {
                let session = convertToUnifiedSession(from: latestSessionEntity)
                
                // 캐시 업데이트
                cacheQueue.async(flags: .barrier) {
                    self.sessionCache[session.id] = session
                }
                
                return session
            }
        } catch {
            print("❌ [SessionManager] 현재 세션 조회 실패: \(error)")
        }
        
        // 오늘 세션이 없으면 새로 생성
        return createSessionSafely()
    }
    
    /// 모든 세션 조회 (최근 활동 순)
    public func getAllSessions() -> [UnifiedSession] {
        // 먼저 캐시에서 확인
        let cachedSessions = cacheQueue.sync {
            Array(sessionCache.values).sorted { $0.lastActivityAt > $1.lastActivityAt }
        }
        
        // 캐시가 비어있으면 Core Data에서 직접 로드
        if cachedSessions.isEmpty {
            let request: NSFetchRequest<UnifiedSessionEntity> = UnifiedSessionEntity.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(key: "lastActivityAt", ascending: false)]
            
            do {
                let sessionEntities = try context.fetch(request)
                return sessionEntities.map { convertToUnifiedSession(from: $0) }
            } catch {
                print("❌ [SessionManager] 세션 조회 실패: \(error)")
                return []
            }
        }
        
        return cachedSessions
    }
    
    /// 최근 N개 세션 조회
    public func getRecentSessions(limit: Int = 20) -> [UnifiedSession] {
        let request: NSFetchRequest<UnifiedSessionEntity> = UnifiedSessionEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "lastActivityAt", ascending: false)]
        request.fetchLimit = limit
        
        do {
            let sessionEntities = try context.fetch(request)
            return sessionEntities.map { convertToUnifiedSession(from: $0) }
        } catch {
            print("❌ [SessionManager] 최근 세션 조회 실패: \(error)")
            return []
        }
    }
    
    /// 세션 삭제 (에러 전파)
    private func deleteSessionInternal(by sessionId: String) throws {
        let request: NSFetchRequest<UnifiedSessionEntity> = UnifiedSessionEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", sessionId as CVarArg)
        
        do {
            let sessions = try context.fetch(request)
            guard let sessionEntity = sessions.first else {
                throw SessionManagerError.sessionNotFound(id: sessionId)
            }
            
            // Core Data에서 삭제 (Cascade 규칙으로 관련 데이터도 자동 삭제)
            context.delete(sessionEntity)
            try saveContext()
            
            print("✅ [SessionManager] 세션 삭제 완료: \(sessionId)")
            
        } catch let error as SessionManagerError {
            throw error
        } catch {
            throw SessionManagerError.saveFailure(underlying: error)
        }
    }
    
    /// 세션 삭제 (호환성 유지)
    public func deleteSession(by sessionId: String) -> Bool {
        do {
            try deleteSessionInternal(by: sessionId)
            return true
        } catch {
            print("❌ [SessionManager] 세션 삭제 실패: \(error.localizedDescription)")
            NotificationCenter.default.post(
                name: .sessionManagerError,
                object: nil,
                userInfo: ["error": error, "operation": "deleteSession"]
            )
            return false
        }
    }
    
    /// 오래된 세션들 정리 (30일 이상)
    public func cleanupOldSessions(olderThanDays days: Int = 30) -> Int {
        let now = SettingsManager.shared.currentDate()
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: now) ?? now
        let recentProtectionDays = SettingsManager.shared.protectedDaysWindow
        let protectionStart = Calendar.current.date(byAdding: .day, value: -recentProtectionDays, to: now) ?? now
        
        let request: NSFetchRequest<UnifiedSessionEntity> = UnifiedSessionEntity.fetchRequest()
        request.predicate = NSPredicate(format: "createdAt < %@", cutoffDate as NSDate)
        
        do {
            let oldSessions = try context.fetch(request)
            var deletedCount = 0
            
            let protectedWeekdays = SettingsManager.shared.protectedWeekdays
            let favoriteDates = SettingsManager.shared.favoriteDates
            for session in oldSessions {
                // 1) 최근 보호 기간 내 세션은 제외
                if session.createdAt >= protectionStart { continue }
                // 2) 즐겨찾기 날짜(yyyy-MM-dd)면 완전 보호
                let dateKey = SettingsManager.shared.dateKey(for: session.createdAt)
                if favoriteDates.contains(dateKey) { continue }
                // 3) 보호 요일 제외
                let weekday = Calendar.current.component(.weekday, from: session.createdAt)
                if protectedWeekdays.contains(weekday) { continue }
                
                context.delete(session)
                deletedCount += 1
                
                // 캐시에서도 제거
                cacheQueue.async(flags: .barrier) {
                    self.sessionCache.removeValue(forKey: session.id.uuidString)
                }
            }
            
            try? saveContext()
            print("✅ [SessionManager] 오래된 세션 정리 완료: \(deletedCount)개")
            return deletedCount
            
        } catch {
            print("❌ [SessionManager] 오래된 세션 정리 실패: \(error)")
            return 0
        }
    }
    
    /// 오래된 세션을 요약 메시지 1건으로 압축합니다. (피드백/행동 데이터는 유지)
    /// - Parameter olderThanDays: 이 일수보다 오래된 세션에 대해 압축을 수행합니다. 기본 60일.
    /// - Returns: 압축된 세션 개수
    public func compressOldSessions(olderThanDays days: Int = 60) -> Int {
        let now = SettingsManager.shared.currentDate()
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: now) ?? now
        let recentProtectionDays = SettingsManager.shared.protectedDaysWindow
        let protectionStart = Calendar.current.date(byAdding: .day, value: -recentProtectionDays, to: now) ?? now
        let request: NSFetchRequest<UnifiedSessionEntity> = UnifiedSessionEntity.fetchRequest()
        request.predicate = NSPredicate(format: "createdAt < %@", cutoffDate as NSDate)
        var compressedCount = 0
        do {
            let oldSessions = try context.fetch(request)
            let protectedWeekdays = SettingsManager.shared.protectedWeekdays
            let favoriteDates = SettingsManager.shared.favoriteDates
            for session in oldSessions {
                // 보호 기간 내 세션 제외
                if session.createdAt >= protectionStart { continue }
                // 즐겨찾기 날짜(yyyy-MM-dd) 제외 (요약/압축도 하지 않음)
                let dateKey = SettingsManager.shared.dateKey(for: session.createdAt)
                if favoriteDates.contains(dateKey) { continue }
                // 보호 요일 제외
                let weekday = Calendar.current.component(.weekday, from: session.createdAt)
                if protectedWeekdays.contains(weekday) { continue }
                
                // 기존 채팅 메시지 수집
                let messageEntities = (session.chatMessages?.allObjects as? [StoredChatMessageEntity]) ?? []
                // 메시지가 매우 적으면 압축 필요 없음
                if messageEntities.count <= 3 { continue }
                // 최신순으로 정렬 후 경량 메시지 구성
                let sorted = messageEntities.sorted { ($0.timestamp) > ($1.timestamp) }
                let recentLite: [ChatMessageLite] = sorted.map { ChatMessageLite(role: $0.role, content: $0.content, createdAt: $0.timestamp) }
                // 요약 생성 (파일 내부 전용 유틸)
                let summary = SessionManager.summarizeRecent(recentLite)
                // 기존 메시지 제거
                for m in messageEntities { context.delete(m) }
                // 요약 메시지 1건 추가
                let summaryEntity = StoredChatMessageEntity(context: context)
                summaryEntity.id = UUID()
                summaryEntity.timestamp = now
                summaryEntity.role = "system"
                summaryEntity.content = summary.isEmpty ? "이전 대화가 요약되었습니다." : summary
                summaryEntity.session = session
                // 세션 활동 시간 업데이트(압축 시각 유지)
                session.lastActivityAt = session.lastActivityAt
                compressedCount += 1
            }
            try? saveContext()
            print("📦 [SessionManager] 세션 압축 완료: \(compressedCount)개 (기준: \(days)일)")
        } catch {
            print("❌ [SessionManager] 세션 압축 실패: \(error)")
        }
        return compressedCount
    }
    
    // MARK: - 데이터 추가 API (기존 매니저들과의 호환성)
    
    /// 채팅 메시지 추가 (에러 전파)
    public func addChatMessage(to sessionId: String, message: StoredChatMessage) throws {
        var sessionError: Error?
        
        // viewContext는 메인 스레드에서만 안전하게 접근해야 함
        // performAndWait를 사용하여 어떤 스레드에서 호출되더라도 작업을 메인 큐에서 동기적으로 실행
        context.performAndWait {
            do {
                // Core Data에서 세션 찾기
                let request: NSFetchRequest<UnifiedSessionEntity> = UnifiedSessionEntity.fetchRequest()
                request.predicate = NSPredicate(format: "id == %@", sessionId as CVarArg)
                
                let sessions = try context.fetch(request)
                guard let sessionEntity = sessions.first else {
                    throw SessionManagerError.sessionNotFound(id: sessionId)
                }
                
                // 새 메시지 엔티티 생성
                let messageEntity = StoredChatMessageEntity(context: context)
                messageEntity.id = UUID()
                messageEntity.timestamp = message.timestamp
                messageEntity.role = message.role
                messageEntity.content = message.content
                messageEntity.session = sessionEntity
                
                // 세션 활동 시간 업데이트
                sessionEntity.lastActivityAt = Date()
                
                // 저장
                try saveContext()
                
                print("✅ [SessionManager] 메시지 추가 완료: \(sessionId)")
                
            } catch {
                sessionError = error
            }
        }
        
        if let error = sessionError {
            // performAndWait 블록 내에서 발생한 에러를 다시 던짐
            if let specificError = error as? SessionManagerError {
                throw specificError
            } else {
                throw SessionManagerError.saveFailure(underlying: error)
            }
        }
    }
    
    /// 채팅 메시지 추가 (호환성 유지 - 에러 무시)
    public func addChatMessageSafely(to sessionId: String, message: StoredChatMessage) {
        let effectiveSessionId: String = {
            if let overrideId = SettingsManager.shared.activeChatSessionOverrideId,
               getSession(id: overrideId) != nil {
                return overrideId
            }
            return sessionId
        }()
        do {
            try addChatMessage(to: effectiveSessionId, message: message)
        } catch {
            print("❌ [SessionManager] 메시지 추가 실패: \(error.localizedDescription)")
            NotificationCenter.default.post(
                name: .sessionManagerError,
                object: nil,
                userInfo: ["error": error, "operation": "addChatMessage"]
            )
        }
    }
    
    /// 피드백 데이터 추가 (에러 전파)
    public func addFeedbackData(to sessionId: String, feedback: PresetFeedback) throws {
        // Core Data에서 세션 찾기
        let request: NSFetchRequest<UnifiedSessionEntity> = UnifiedSessionEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", sessionId as CVarArg)
        
        do {
            let sessions = try context.fetch(request)
            guard let sessionEntity = sessions.first else {
                throw SessionManagerError.sessionNotFound(id: sessionId)
            }
            
            // 새 피드백 엔티티 생성
            let feedbackEntity = PresetFeedbackEntity(context: context)
            feedbackEntity.id = UUID()
            feedbackEntity.timestamp = feedback.timestamp
            feedbackEntity.presetName = feedback.presetName ?? ""
            feedbackEntity.rating = Int16(feedback.userSatisfaction)
            feedbackEntity.comment = feedback.comment
            feedbackEntity.session = sessionEntity
            
            // 세션 활동 시간 업데이트
            sessionEntity.lastActivityAt = Date()
            
            // 저장 (에러 전파)
            try saveContext()
            
            print("✅ [SessionManager] 피드백 추가 완료: \(sessionId)")
            
        } catch let error as SessionManagerError {
            throw error
        } catch {
            throw SessionManagerError.saveFailure(underlying: error)
        }
    }
    
    /// 피드백 데이터 추가 (호환성 유지 - 에러 무시)
    public func addFeedbackDataSafely(to sessionId: String, feedback: PresetFeedback) {
        do {
            try addFeedbackData(to: sessionId, feedback: feedback)
        } catch {
            print("❌ [SessionManager] 피드백 추가 실패: \(error.localizedDescription)")
            NotificationCenter.default.post(
                name: .sessionManagerError,
                object: nil,
                userInfo: ["error": error, "operation": "addFeedbackData"]
            )
        }
    }
    
    /// 행동 이벤트 추가
    public func addBehaviorEvent(to sessionId: String, event: BehaviorEvent) {
        // Core Data에서 세션 찾기
        let request: NSFetchRequest<UnifiedSessionEntity> = UnifiedSessionEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", sessionId as CVarArg)
        
        do {
            let sessions = try context.fetch(request)
            guard let sessionEntity = sessions.first else {
                print("❌ [SessionManager] 세션을 찾을 수 없음: \(sessionId)")
                return
            }
            
            // 새 행동 이벤트 엔티티 생성
            let eventEntity = BehaviorEventEntity(context: context)
            eventEntity.id = UUID()
            eventEntity.timestamp = event.timestamp
            eventEntity.eventType = event.type.rawValue
            eventEntity.details = event.data.description
            eventEntity.session = sessionEntity
            
            // 세션 활동 시간 업데이트
            sessionEntity.lastActivityAt = Date()
            
            // 저장
            try? saveContext()
            
            // 메모리 캐시 업데이트
            cacheQueue.async(flags: .barrier) {
                if var cachedSession = self.sessionCache[sessionId] {
                    cachedSession.behaviorEvents.append(event)
                    cachedSession.lastActivityAt = Date()
                    self.sessionCache[sessionId] = cachedSession
                }
            }
            
            print("✅ [SessionManager] 행동 이벤트 추가 완료: \(sessionId)")
            
        } catch {
            print("❌ [SessionManager] 행동 이벤트 추가 실패: \(error)")
        }
    }
    
    // MARK: - 호환성 API (기존 매니저들을 위한)
    
    /// ChatManager 호환성: 최근 메시지 조회 (성능 최적화)
    public func getRecentChatMessages(limit: Int = 100) -> [StoredChatMessage] {
        let request: NSFetchRequest<StoredChatMessageEntity> = StoredChatMessageEntity.fetchRequest()
        // 최신 메시지를 우선 가져온 뒤, 표시용으로만 시간순으로 정렬
        request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
        request.fetchLimit = limit
        
        // 성능 최적화: 세션 관계 미리 페칭
        request.relationshipKeyPathsForPrefetching = ["session"]
        
        do {
            // 1) 최신 N개를 가져옴 (내림차순)
            let fetched = try context.fetch(request)
            // 2) 반환 전 시간순(오름차순)으로 재정렬하여 컨텍스트가 자연스럽게 이어지도록 함
            let messageEntities = fetched.sorted { ($0.timestamp ?? Date()) < ($1.timestamp ?? Date()) }
            return messageEntities.map { entity in
                StoredChatMessage(
                    id: entity.id.uuidString,
                    timestamp: entity.timestamp ?? Date(),
                    role: entity.role ?? "user",
                    content: entity.content ?? "",
                    type: .text
                )
            }
        } catch {
            print("❌ [SessionManager] 최근 메시지 조회 실패: \(error)")
            return []
        }
    }
    
    /// 특정 세션의 모든 채팅 메시지 조회 (시간순)
    public func getChatMessages(forSessionId sessionId: String, limit: Int? = nil) -> [StoredChatMessage] {
        let request: NSFetchRequest<StoredChatMessageEntity> = StoredChatMessageEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: true)]
        request.predicate = NSPredicate(format: "session.id == %@", sessionId as CVarArg)
        if let limit = limit { request.fetchLimit = limit }
        do {
            let fetched = try context.fetch(request)
            return fetched.map { entity in
                StoredChatMessage(
                    id: entity.id.uuidString,
                    timestamp: entity.timestamp ?? Date(),
                    role: entity.role ?? "user",
                    content: entity.content ?? "",
                    type: .text
                )
            }
        } catch {
            print("❌ [SessionManager] 세션별 메시지 조회 실패: \(error)")
            return []
        }
    }
    
    /// FeedbackManager 호환성: 최근 피드백 조회 (성능 최적화)
    public func getRecentFeedback(limit: Int = 20) -> [PresetFeedback] {
        let request: NSFetchRequest<PresetFeedbackEntity> = PresetFeedbackEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
        request.fetchLimit = limit
        
        // 성능 최적화: 세션 관계 미리 페칭
        request.relationshipKeyPathsForPrefetching = ["session"]
        
        do {
            let feedbackEntities = try context.fetch(request)
            return feedbackEntities.map { entity in
                PresetFeedback(
                    id: entity.id ?? UUID(),
                    timestamp: entity.timestamp ?? Date(),
                    presetName: entity.presetName,
                    contextEmotion: "평온", // 기본값
                    contextTime: entity.rating, // 임시 매핑
                    recommendedVolumes: [],
                    recommendedVersions: [],
                    finalVolumes: [],
                    listeningDuration: 0,
                    wasSkipped: false,
                    wasSaved: true,
                    userSatisfaction: Int(entity.rating),
                    comment: entity.comment
                )
            }
        } catch {
            print("❌ [SessionManager] 최근 피드백 조회 실패: \(error)")
            return []
        }
    }
    
    /// UserBehaviorAnalytics 호환성: 최근 행동 데이터 조회 (성능 최적화)
    public func getRecentBehaviorEvents(limit: Int = 50) -> [BehaviorEvent] {
        let request: NSFetchRequest<BehaviorEventEntity> = BehaviorEventEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
        request.fetchLimit = limit
        
        // 성능 최적화: 세션 관계 미리 페칭
        request.relationshipKeyPathsForPrefetching = ["session"]
        
        do {
            let eventEntities = try context.fetch(request)
            return eventEntities.map { entity in
                BehaviorEvent(
                    id: entity.id.uuidString,
                    type: BehaviorEventType(rawValue: entity.eventType ?? "sessionStart") ?? .sessionStart,
                    timestamp: entity.timestamp ?? Date(),
                    data: parseEventDetails(entity.details ?? "")
                )
            }
        } catch {
            print("❌ [SessionManager] 최근 행동 이벤트 조회 실패: \(error)")
            return []
        }
    }
    
    /// 이벤트 세부사항 파싱 헬퍼
    private func parseEventDetails(_ details: String) -> [String: String] {
        // 간단한 키-값 파싱 (실제로는 JSON 파싱 등을 사용할 수 있음)
        var result: [String: String] = [:]
        let pairs = details.components(separatedBy: ",")
        for pair in pairs {
            let keyValue = pair.components(separatedBy: ":")
            if keyValue.count == 2 {
                result[keyValue[0].trimmingCharacters(in: .whitespaces)] = keyValue[1].trimmingCharacters(in: .whitespaces)
            }
        }
        return result
    }
    
    // MARK: - FeedbackManager 호환성 API (완전 통합)
    
    /// 피드백 세션 시작 (FeedbackManager.startSession 대체)
    public func startSession(presetName: String, recommendation: Any?, contextEmotion: String) {
        feedbackQueue.async(flags: .barrier) {
            let session = FeedbackSession(
                id: UUID().uuidString,
                presetName: presetName,
                startTime: Date(),
                contextEmotion: contextEmotion,
                recommendedVolumes: [],
                currentVolumes: []
            )
            self.currentFeedbackSession = session
            
            print("🎯 [SessionManager] 피드백 세션 시작: \(presetName)")
        }
    }
    
    /// 현재 세션 볼륨 업데이트 (FeedbackManager.updateCurrentSessionVolumes 대체)
    public func updateCurrentSessionVolumes(_ volumes: [Float]) {
        feedbackQueue.async(flags: .barrier) {
            self.currentFeedbackSession?.currentVolumes = volumes
        }
    }
    
    /// 피드백 세션 종료 (FeedbackManager.endCurrentSession 대체)
    public func endCurrentSession(finalVolumes: [Float], listeningDuration: TimeInterval, wasSaved: Bool, satisfaction: Int = 0) {
        feedbackQueue.async(flags: .barrier) {
            guard let session = self.currentFeedbackSession else {
                print("⚠️ [SessionManager] 종료할 피드백 세션이 없음")
                return
            }
            
            // PresetFeedback 생성
            let feedback = PresetFeedback(
                id: UUID(),
                timestamp: Date(),
                presetName: session.presetName,
                contextEmotion: session.contextEmotion,
                contextTime: Int16(Calendar.current.component(.hour, from: Date())),
                recommendedVolumes: session.recommendedVolumes,
                recommendedVersions: [],
                finalVolumes: finalVolumes,
                listeningDuration: listeningDuration,
                wasSkipped: !wasSaved,
                wasSaved: wasSaved,
                userSatisfaction: satisfaction,
                comment: nil
            )
            
            // 현재 세션에 피드백 추가
            let currentSession = self.getCurrentOrCreateSession()
            self.addFeedbackDataSafely(to: currentSession.id, feedback: feedback)
            
            // 피드백 세션 정리
            self.currentFeedbackSession = nil
            
            print("🏁 [SessionManager] 피드백 세션 종료: 청취시간 \(String(format: "%.1f", listeningDuration))초")
        }
    }
    
    /// 현재 세션 프리셋 이름 (FeedbackManager.getCurrentSessionPresetName 대체)
    public func getCurrentSessionPresetName() -> String? {
        return feedbackQueue.sync {
            return currentFeedbackSession?.presetName
        }
    }
    
    /// 현재 세션 지속 시간 (FeedbackManager.currentSessionDuration 대체)
    public var currentSessionDuration: TimeInterval {
        return feedbackQueue.sync {
            guard let session = currentFeedbackSession else { return 0 }
            return Date().timeIntervalSince(session.startTime)
        }
    }
    
    // MARK: - 로컬 AI 추천을 위한 통합 데이터 제공
    
    /// 로컬 AI 추천을 위한 풍부한 컨텍스트 생성
    public func buildRichContextForLocalAI() -> LocalAIContext {
        let recentSessions = getRecentSessions(limit: AppConfig.Pagination.richContextSessionLimit)
        
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
        let request: NSFetchRequest<UnifiedSessionEntity> = UnifiedSessionEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "lastActivityAt", ascending: false)]
        
        do {
            let sessionEntities = try context.fetch(request)
            
            cacheQueue.async(flags: .barrier) {
                self.sessionCache.removeAll()
                for entity in sessionEntities {
                    let session = self.convertToUnifiedSession(from: entity)
                    self.sessionCache[session.id] = session
                }
            }
            
            print("🎯 [SessionManager] 세션 로드 완료 - 총 \(sessionEntities.count)개")
            
        } catch {
            print("❌ [SessionManager] 세션 로드 실패: \(error)")
        }
    }
    
    /// Core Data 컨텍스트 저장 (에러 전파)
    private func saveContext() throws {
        try coreDataStack.saveContextWithError()
    }
    
    /// UnifiedSessionEntity를 UnifiedSession struct로 변환 (개선된 버전)
    private func convertToUnifiedSession(from entity: UnifiedSessionEntity) -> UnifiedSession {
        return entity.toStruct()
    }
    
    /// 실제 데이터 마이그레이션 구현
    private func performDataMigration() async {
        print("🔄 [SessionManager] 데이터 마이그레이션 시작")
        
        do {
            var totalMigrated = 0
            
            // ChatManager 데이터 마이그레이션
            let migratedChatSessions = await migrateChatManagerData()
            totalMigrated += migratedChatSessions
            print("✅ [SessionManager] ChatManager 데이터 마이그레이션 완료: \(migratedChatSessions)개 세션")
            
            // FeedbackManager 데이터 마이그레이션
            let migratedFeedback = await migrateFeedbackManagerData()
            totalMigrated += migratedFeedback
            print("✅ [SessionManager] FeedbackManager 데이터 마이그레이션 완료: \(migratedFeedback)개 피드백")
            
            // UserBehaviorAnalytics 데이터 마이그레이션
            let migratedBehavior = await migrateBehaviorAnalyticsData()
            totalMigrated += migratedBehavior
            print("✅ [SessionManager] UserBehaviorAnalytics 데이터 마이그레이션 완료: \(migratedBehavior)개 이벤트")
            
            // 마이그레이션 완료 표시
            isMigrationCompleted = true
            
            if totalMigrated > 0 {
                print("✅ [SessionManager] 전체 데이터 마이그레이션 완료 - 총 \(totalMigrated)개 항목")
            } else {
                print("ℹ️ [SessionManager] 마이그레이션할 기존 데이터가 없음")
            }
            
        } catch {
            print("❌ [SessionManager] 데이터 마이그레이션 실패: \(error)")
            // 마이그레이션 실패 시에도 앱이 동작하도록 함
            isMigrationCompleted = true
        }
    }
    
    private func migrateChatManagerData() async -> Int {
        // ChatManager의 UserDefaults 데이터를 Core Data로 실제 이전
        let userDefaults = UserDefaults.standard
        
        guard let data = userDefaults.data(forKey: "deepSleep_chatHistory"),
              let existingSessions = try? JSONDecoder().decode([String: ChatSession].self, from: data) else {
            print("📝 [SessionManager] ChatManager 마이그레이션할 데이터 없음")
            return 0
        }
        
        var migratedCount = 0
        
        for (_, chatSession) in existingSessions {
            // Core Data 엔티티 생성
            let sessionEntity = UnifiedSessionEntity(context: context)
            sessionEntity.id = UUID(uuidString: chatSession.id) ?? UUID()
            sessionEntity.createdAt = chatSession.createdAt
            sessionEntity.lastActivityAt = chatSession.lastActivityAt
            
            // 메타데이터 변환 및 저장
            let metadata = SessionMetadata(
                primaryEmotion: chatSession.metadata?.emotion,
                emotionIntensity: nil,
                context: chatSession.metadata?.context,
                userProfile: chatSession.metadata?.userProfile
            )
            sessionEntity.metadataData = try? JSONEncoder().encode(metadata)
            
            // 채팅 메시지들 변환
            for message in chatSession.messages {
                let messageEntity = StoredChatMessageEntity(context: context)
                messageEntity.id = UUID(uuidString: message.id) ?? UUID()
                messageEntity.timestamp = message.timestamp
                messageEntity.role = message.role
                messageEntity.content = message.content
                messageEntity.session = sessionEntity
            }
            
            migratedCount += 1
        }
        
        // Core Data에 저장
        try? saveContext()
        
        // 마이그레이션 완료 후 UserDefaults에서 제거
        userDefaults.removeObject(forKey: "deepSleep_chatHistory")
        
        return migratedCount
    }
    
    private func migrateFeedbackManagerData() async -> Int {
        // FeedbackManager의 UserDefaults 데이터를 Core Data로 실제 이전
        let userDefaults = UserDefaults.standard
        
        guard let data = userDefaults.data(forKey: "feedback_data") else {
            print("📝 [SessionManager] FeedbackManager 마이그레이션할 데이터 없음")
            return 0
        }
        
        // 피드백 데이터 디코딩 시도
        do {
            // PresetFeedbackWrapper 구조체가 있다고 가정하고 시도
            if let feedbackWrappers = try? JSONDecoder().decode([PresetFeedbackWrapper].self, from: data) {
                var migratedCount = 0
                
                // 가장 최근 세션을 찾거나 새로 생성
                let recentSession = getCurrentOrCreateSession()
                
                let request: NSFetchRequest<UnifiedSessionEntity> = UnifiedSessionEntity.fetchRequest()
                request.predicate = NSPredicate(format: "id == %@", recentSession.id as CVarArg)
                
                if let sessionEntity = try? context.fetch(request).first {
                    for wrapper in feedbackWrappers {
                        let feedbackEntity = PresetFeedbackEntity(context: context)
                        feedbackEntity.id = wrapper.feedback.id
                        feedbackEntity.timestamp = wrapper.feedback.timestamp
                        feedbackEntity.presetName = wrapper.feedback.presetName ?? ""
                        feedbackEntity.rating = Int16(wrapper.feedback.userSatisfaction)
                        feedbackEntity.comment = wrapper.feedback.comment
                        feedbackEntity.session = sessionEntity
                        
                        migratedCount += 1
                    }
                    
                    try? saveContext()
                }
                
                // 마이그레이션 완료 후 UserDefaults에서 제거
                userDefaults.removeObject(forKey: "feedback_data")
                
                return migratedCount
            }
        } catch {
            print("⚠️ [SessionManager] 피드백 데이터 파싱 실패: \(error)")
        }
        
        // 파싱 실패 시에도 UserDefaults 정리
        userDefaults.removeObject(forKey: "feedback_data")
        return 0
    }
    
    private func migrateBehaviorAnalyticsData() async -> Int {
        // UserBehaviorAnalytics의 UserDefaults 데이터를 Core Data로 실제 이전
        let userDefaults = UserDefaults.standard
        
        guard let data = userDefaults.data(forKey: "userSessions") else {
            print("📝 [SessionManager] UserBehaviorAnalytics 마이그레이션할 데이터 없음")
            return 0
        }
        
        // 행동 분석 데이터 디코딩 시도
        do {
            // UserSession 배열로 디코딩 시도
            if let userSessions = try? JSONDecoder().decode([UserSession].self, from: data) {
                var migratedCount = 0
                
                for userSession in userSessions {
                    // 해당 날짜의 세션을 찾거나 새로 생성
                    let sessionId = findOrCreateSessionForDate(userSession.startTime)
                    
                    // 행동 이벤트로 변환
                    let behaviorEvent = BehaviorEvent(
                        type: .presetStart,
                        timestamp: userSession.startTime,
                        data: [
                            "presetName": userSession.presetName,
                            "duration": String(userSession.duration),
                            "completionRate": String(userSession.completionRate)
                        ]
                    )
                    
                    addBehaviorEvent(to: sessionId, event: behaviorEvent)
                    migratedCount += 1
                }
                
                // 마이그레이션 완료 후 UserDefaults에서 제거
                userDefaults.removeObject(forKey: "userSessions")
                
                return migratedCount
            }
        } catch {
            print("⚠️ [SessionManager] 행동 분석 데이터 파싱 실패: \(error)")
        }
        
        // 파싱 실패 시에도 UserDefaults 정리
        userDefaults.removeObject(forKey: "userSessions")
        return 0
    }
    
    /// 특정 날짜의 세션을 찾거나 새로 생성
    public func findOrCreateSessionForDate(_ date: Date) -> String {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let request: NSFetchRequest<UnifiedSessionEntity> = UnifiedSessionEntity.fetchRequest()
        request.predicate = NSPredicate(format: "createdAt >= %@ AND createdAt < %@", startOfDay as NSDate, endOfDay as NSDate)
        request.fetchLimit = 1
        
        do {
            if let existingSession = try context.fetch(request).first {
                return existingSession.id.uuidString
            }
        } catch {
            print("❌ [SessionManager] 날짜별 세션 조회 실패: \(error)")
        }
        
        // 해당 날짜의 세션이 없으면 새로 생성
        let newSession = createSessionSafely()
        return newSession.id
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
    
    /// 사용자 8턴 + AI 8턴으로 균형 있게 최신순 16개를 생성
    static func buildBalancedRecent(_ raw: [StoredChatMessage], userMax: Int, assistantMax: Int) -> [ChatMessageLite] {
        // 최신 메시지를 우선 고려하기 위해 역순(최신부터)로 순회
        let sortedDesc = raw.sorted { $0.timestamp > $1.timestamp }
        var pickedUser: [StoredChatMessage] = []
        var pickedAssistant: [StoredChatMessage] = []
        for m in sortedDesc {
            if m.role == "user" {
                if pickedUser.count < userMax { pickedUser.append(m) }
            } else if m.role == "assistant" {
                if pickedAssistant.count < assistantMax { pickedAssistant.append(m) }
            }
            if pickedUser.count >= userMax && pickedAssistant.count >= assistantMax { break }
        }
        // 병합 후 최신순으로 정렬
        let merged = (pickedUser + pickedAssistant).sorted { $0.timestamp > $1.timestamp }
        // ChatMessageLite로 변환 (최신순 그대로 유지)
        return merged.map { m in
            ChatMessageLite(
                role: m.role == "assistant" ? "assistant" : (m.role == "system" ? "system" : "user"),
                content: m.content,
                createdAt: m.timestamp
            )
        }
    }
}

private extension SessionManager {
    /// 최근 대화를 기반으로 경량 요약을 생성합니다. (개인정보/토큰 최소화)
    /// - Note: 최신순 상위 16개(사용자/AI 합계)를 한 문단으로 압축
    static func summarizeRecent(_ recent: [ChatMessageLite]) -> String {
        guard !recent.isEmpty else { return "" }
        // 최신순으로 정렬되어 온 입력을 상정하고 상위 16개만 사용
        let top = Array(recent.prefix(16))
        var bullets: [String] = []
        for item in top {
            let role = (item.role == "assistant") ? "AI" : (item.role == "system" ? "시스템" : "사용자")
            let text = item.content
                .replacingOccurrences(of: "\n", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if text.isEmpty { continue }
            // 너무 긴 문장은 축약
            let trimmed = text.count > 80 ? String(text.prefix(80)) + "…" : text
            bullets.append("- \(role): \(trimmed)")
        }
        let joined = bullets.joined(separator: "\n")
        return joined.isEmpty ? "" : "최근 대화 요약:\n" + joined
    }
}

// MARK: - Data Models
// All data models moved to SharedModels.swift as Single Source of Truth
// UnifiedSession, SessionMetadata, BehaviorEvent, BehaviorEventType,
// LocalAIContext, EmotionHistoryItem, BehaviorPattern, TimePreference
// are now defined in SharedModels.swift

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
    
    // MARK: - 🎯 중앙집중형 AI 호출 시스템 (ChatManager 통합)
    
    /// 현재 세션 ID 가져오기 (없으면 새로 생성)
    public func getCurrentSessionId() -> String {
        // 오버라이드 세션이 설정되어 있으면 우선 사용
        if let overrideId = SettingsManager.shared.activeChatSessionOverrideId,
           getSession(id: overrideId) != nil {
            return overrideId
        }
        let currentSession = getCurrentOrCreateSession()
        return currentSession.id
    }
    
    /// 🎯 모든 외부 AI 모델 호출의 중앙집중 처리 메서드
    /// ChatManager.sendMessage() 역할을 SessionManager에서 통합 처리
    /// - Parameters:
    ///   - content: 전송할 메시지 내용
    ///   - model: 사용할 AI 모델 (.claude, .openAI, .gemini 등)
    ///   - context: 컨텍스트 정보 (선택사항)
    ///   - saveMessages: 메시지 저장 여부 (기본값: true)
    /// - Returns: AI 응답 문자열
    public func sendMessage(
        content: String,
        model: AIModel = .claude,
        context: String? = nil,
        saveMessages: Bool = true
    ) async throws -> String {
        // 하위 호환: 모드 정보가 없는 호출은 일반 대화로 처리
        return try await sendMessage(
            content: content,
            model: model,
            mode: .generalConversation,
            saveMessages: saveMessages
        )
    }
    
    /// 모드 기반 중앙집중형 AI 호출(저장 정책 및 멀티-메시지 컨텍스트 일원화)
    public func sendMessage(
        content: String,
        model: AIModel = .claude,
        mode: AIMode,
        saveMessages: Bool = true
    ) async throws -> String {
        print("🎯 [SessionManager] 중앙집중 AI 호출 - 모델: \(model.rawValue), 모드: \(mode.rawValue), 내용: \(content.prefix(50))...")
        
        // 1) 사용자 메시지 저장(정책 적용)
        if saveMessages {
            let currentSessionId = getCurrentSessionId()
            let toSaveUser = summarizeIfNeeded(role: "user", content: content, mode: mode)
            let userMessage = StoredChatMessage(
                id: UUID().uuidString,
                timestamp: Date(),
                role: "user",
                content: toSaveUser,
                type: .text
            )
            addChatMessageSafely(to: currentSessionId, message: userMessage)
        }
        
        do {
            // 2) 최근 대화(사용자 8/AI 8) 균형 구성 → 컨텍스트 조립
            let rawMessages = getRecentChatMessages(limit: 60)
            let recent: [ChatMessageLite] = Self.buildBalancedRecent(rawMessages, userMax: 8, assistantMax: 8)
            
            let personaSignature = UserRulesManager.shared.personaSignature()
            let coreSummary = MemoryManager.shared.getMemorySummary(maxItems: 10)
            let effectiveSummary: String? = {
                if !coreSummary.isEmpty { return coreSummary }
                let summary = Self.summarizeRecent(recent)
                return summary.isEmpty ? nil : summary
            }()
            let assembled = AIContextBuilder.shared.buildPrompt(
                for: mode,
                personaSignature: personaSignature,
                recentMessages: recent,
                coreMemorySummary: effectiveSummary,
                currentUserMessage: content
            )
            
            // 멀티-메시지 경로를 위한 역할 기반 히스토리 구성
            let historyTurns: [AIConversationTurn] = recent.map { lite in
                AIConversationTurn(role: Role(rawValue: lite.role) ?? .user, content: lite.content, timestamp: lite.createdAt)
            }
            let aiContext = AIContext(
                userId: "user_\(getCurrentSessionId())",
                sessionId: getCurrentSessionId(),
                conversationHistory: historyTurns,
                userPreferences: nil,
                environmentContext: nil
            )
            
            // 3) 통합 서비스 호출(모드 전달)
            let aiResponse = try await UnifiedAIServiceImpl.shared.sendMessage(
                content: content,
                model: model,
                mode: mode,
                context: aiContext,
                tokenConfig: nil,
                assembledPrompt: assembled.text
            )
            let response = aiResponse.content
            
            // 4) AI 응답 저장(정책 적용)
            if saveMessages {
                let currentSessionId = getCurrentSessionId()
                let toSaveAI = summarizeIfNeeded(role: "assistant", content: response, mode: mode)
                let aiMessage = StoredChatMessage(
                    id: UUID().uuidString,
                    timestamp: Date(),
                    role: "assistant",
                    content: toSaveAI,
                    type: .text
                )
                addChatMessageSafely(to: currentSessionId, message: aiMessage)
            }
            
            print("✅ [SessionManager] AI 응답 성공 - 길이: \(response.count)자")
            return response
            
        } catch {
            print("❌ [SessionManager] AI 호출 실패: \(error.localizedDescription)")
            
            if saveMessages {
                let currentSessionId = getCurrentSessionId()
                let errorMessage = StoredChatMessage(
                    id: UUID().uuidString,
                    timestamp: Date(),
                    role: "assistant",
                    content: "죄송합니다. 일시적인 오류가 발생했습니다. 잠시 후 다시 시도해주세요.",
                    type: .text
                )
                addChatMessageSafely(to: currentSessionId, message: errorMessage)
            }
            
            throw error
        }
    }
    
    /// 저장 정책: 프리셋 모드에서 요약 저장, 그 외 원문 저장
    private func summarizeIfNeeded(role: String, content: String, mode: AIMode) -> String {
        switch mode {
        case .presetRecommendation:
            if role == "user" {
                return PresetInteractionSummarizer.summarizeUserRequest(content)
            } else {
                return PresetInteractionSummarizer.summarizeAIResponse(presetName: nil)
            }
        default:
            return content
        }
    }
    
    // MARK: - 호환성 메서드들 (ChatManager 대체)
    
    /// 감정 분석 전용 AI 호출
    public func analyzeEmotion(content: String) async throws -> String {
        let prompt = "다음 텍스트의 감정을 분석해주세요: \(content)"
        return try await sendMessage(content: prompt, model: .claude)
    }
    
    /// 프리셋 추천 전용 AI 호출
    public func recommendPreset(emotion: String, context: String) async throws -> String {
        let prompt = "감정: \(emotion), 상황: \(context)에 맞는 음악 프리셋을 추천해주세요."
        return try await sendMessage(content: prompt, model: .openAI)
    }
    
    /// 일반 채팅 AI 호출
    public func chat(message: String) async throws -> String {
        return try await sendMessage(content: message, model: .claude)
    }
    
    // MARK: - Cache Synchronization System
    
    /// Core Data 변경 알림 설정 (캐시 동기화)
    private func setupCoreDataNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(contextDidSave(_:)),
            name: .NSManagedObjectContextDidSave,
            object: nil
        )
        
        print("🔄 [SessionManager] Core Data 알림 구독 완료")
    }
    
    /// Core Data 컨텍스트 저장 알림 처리 (성능 최적화)
    @objc private func contextDidSave(_ notification: Notification) {
        guard let context = notification.object as? NSManagedObjectContext,
              context != self.context else {
            return // 자신의 컨텍스트 변경은 무시
        }
        
        print("🔄 [SessionManager] 외부 Core Data 변경 감지, 캐시 동기화 시작")
        
        // 백그라운드에서 캐시 동기화 수행 (성능 최적화)
        DispatchQueue.global(qos: .utility).async {
            self.synchronizeCache(with: notification)
        }
    }
    
    /// 캐시와 Core Data 동기화
    private func synchronizeCache(with notification: Notification) {
        guard let userInfo = notification.userInfo else { return }
        
        // 삽입된 객체들 처리
        if let insertedObjects = userInfo[NSInsertedObjectsKey] as? Set<NSManagedObject> {
            handleInsertedObjects(insertedObjects)
        }
        
        // 업데이트된 객체들 처리
        if let updatedObjects = userInfo[NSUpdatedObjectsKey] as? Set<NSManagedObject> {
            handleUpdatedObjects(updatedObjects)
        }
        
        // 삭제된 객체들 처리
        if let deletedObjects = userInfo[NSDeletedObjectsKey] as? Set<NSManagedObject> {
            handleDeletedObjects(deletedObjects)
        }
        
        print("✅ [SessionManager] 캐시 동기화 완료")
    }
    
    /// 삽입된 객체들 캐시에 반영 (성능 최적화)
    private func handleInsertedObjects(_ objects: Set<NSManagedObject>) {
        let sessionUpdates: [(String, UnifiedSession)] = objects.compactMap { object in
            guard let sessionEntity = object as? UnifiedSessionEntity else { return nil }
            let session = convertToUnifiedSession(from: sessionEntity)
            return (session.id, session)
        }
        
        guard !sessionUpdates.isEmpty else { return }
        
        cacheQueue.async(flags: .barrier) {
            for (sessionId, session) in sessionUpdates {
                self.sessionCache[sessionId] = session
                print("🔄 [SessionManager] 새 세션 캐시에 추가: \(sessionId)")
            }
        }
    }
    
    /// 업데이트된 객체들 캐시에 반영 (성능 최적화)
    private func handleUpdatedObjects(_ objects: Set<NSManagedObject>) {
        let sessionUpdates: [(String, UnifiedSession)] = objects.compactMap { object in
            guard let sessionEntity = object as? UnifiedSessionEntity else { return nil }
            let session = convertToUnifiedSession(from: sessionEntity)
            return (session.id, session)
        }
        
        guard !sessionUpdates.isEmpty else { return }
        
        cacheQueue.async(flags: .barrier) {
            for (sessionId, session) in sessionUpdates {
                self.sessionCache[sessionId] = session
                print("🔄 [SessionManager] 세션 캐시 업데이트: \(sessionId)")
            }
        }
    }
    
    /// 삭제된 객체들 캐시에서 제거 (성능 최적화)
    private func handleDeletedObjects(_ objects: Set<NSManagedObject>) {
        let sessionIds: [String] = objects.compactMap { object in
            guard let sessionEntity = object as? UnifiedSessionEntity else { return nil }
            return sessionEntity.id.uuidString
        }
        
        guard !sessionIds.isEmpty else { return }
        
        cacheQueue.async(flags: .barrier) {
            for sessionId in sessionIds {
                self.sessionCache.removeValue(forKey: sessionId)
                print("🔄 [SessionManager] 세션 캐시에서 제거: \(sessionId)")
            }
        }
    }
    
    /// 캐시 무효화 (전체 재로드)
    public func invalidateCache() {
        print("🔄 [SessionManager] 캐시 무효화 및 재로드 시작")
        
        cacheQueue.async(flags: .barrier) {
            self.sessionCache.removeAll()
        }
        
        loadAllSessions()
        
        print("✅ [SessionManager] 캐시 무효화 완료")
    }
    
    /// 캐시 상태 검증
    public func validateCacheIntegrity() -> Bool {
        let cacheCount = cacheQueue.sync { sessionCache.count }
        
        let request: NSFetchRequest<UnifiedSessionEntity> = UnifiedSessionEntity.fetchRequest()
        
        do {
            let coreDataCount = try context.count(for: request)
            let isValid = cacheCount == coreDataCount
            
            if !isValid {
                print("⚠️ [SessionManager] 캐시 불일치 감지 - 캐시: \(cacheCount), Core Data: \(coreDataCount)")
            }
            
            return isValid
        } catch {
            print("❌ [SessionManager] 캐시 검증 실패: \(error)")
            return false
        }
    }
    
    // deinit 임시 제거 - 컴파일 에러 해결을 위해
    // deinit {
    //     NotificationCenter.default.removeObserver(self)
    // }
}

// MARK: - Notification Names
extension Notification.Name {
    static let sessionManagerError = Notification.Name("SessionManagerError")
    static let sessionManagerCacheUpdated = Notification.Name("SessionManagerCacheUpdated")
}

// MARK: - FeedbackSession 데이터 모델

/// 피드백 세션 임시 데이터 구조체
private struct FeedbackSession {
    let id: String
    let presetName: String
    let startTime: Date
    let contextEmotion: String
    var recommendedVolumes: [Float]
    var currentVolumes: [Float]
}
