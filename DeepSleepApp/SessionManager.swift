import CoreData
import Foundation

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
    private let cacheQueue = DispatchQueue(
        label: "com.deepsleep.sessionmanager", attributes: .concurrent)

    // MARK: - 중앙집중형 사용량 관리
    private let usageGate = UsageGate.shared

    // MARK: - 피드백 세션 관리 (FeedbackManager 통합)
    private var currentFeedbackSession: FeedbackSession?
    private let feedbackQueue = DispatchQueue(
        label: "com.deepsleep.feedback", attributes: .concurrent)

    // MARK: - 마이그레이션 상태
    private var isMigrationCompleted: Bool {
        get { UserDefaults.standard.bool(forKey: "sessionManager_migration_completed") }
        set { UserDefaults.standard.set(newValue, forKey: "sessionManager_migration_completed") }
    }

    private init() {
        print("[SessionManager][INIT] start")

        // Core Data 변경 알림 구독 (캐시 동기화)
        setupCoreDataNotifications()

        // 기존 데이터 마이그레이션 (한 번만 실행)
        if !isMigrationCompleted {
            Task {
                await performDataMigration()
            }
        }

        loadAllSessions()
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
        request.predicate = NSPredicate(
            format: "lastActivityAt >= %@ AND lastActivityAt < %@", startOfDay as NSDate,
            endOfDay as NSDate)
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

    /// 지난 N일 동안 저장된 AI 응답(assistant role) 메시지 개수
    /// - Note: 모드 정보가 메시지 단위로 저장되지 않으므로, 전체 AI 사용량의 근사치로 사용
    public func countAssistantMessages(lastNDays days: Int = 7) -> Int {
        let now = SettingsManager.shared.currentDate()
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: now) ?? now
        let request: NSFetchRequest<StoredChatMessageEntity> =
            StoredChatMessageEntity.fetchRequest()
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "role == %@", "assistant"),
            NSPredicate(format: "timestamp >= %@", cutoff as NSDate),
        ])
        do {
            let count = try context.count(for: request)
            return max(0, count)
        } catch {
            print("❌ [SessionManager] countAssistantMessages 실패: \(error)")
            return 0
        }
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
        let protectionStart =
            Calendar.current.date(byAdding: .day, value: -recentProtectionDays, to: now) ?? now

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
        let protectionStart =
            Calendar.current.date(byAdding: .day, value: -recentProtectionDays, to: now) ?? now
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
                let messageEntities: [StoredChatMessageEntity] = {
                    if let ns = session.chatMessages {
                        return ns.allObjects.compactMap { $0 as? StoredChatMessageEntity }
                    }
                    return []
                }()
                // 메시지가 매우 적으면 압축 필요 없음
                if messageEntities.count <= 3 { continue }
                // 최신순으로 정렬 후 경량 메시지 구성
                let sorted = messageEntities.sorted { ($0.timestamp) > ($1.timestamp) }
                let recentLite: [ChatMessageLite] = sorted.map {
                    ChatMessageLite(role: $0.role, content: $0.content, createdAt: $0.timestamp)
                }
                // 요약 생성 (중앙 유틸 사용)
                let summary = AIContextBuilder.shared.summarizeRecent(recentLite, maxItems: 16)
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
                let request: NSFetchRequest<UnifiedSessionEntity> =
                    UnifiedSessionEntity.fetchRequest()
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
                getSession(id: overrideId) != nil
            {
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
        let request: NSFetchRequest<StoredChatMessageEntity> =
            StoredChatMessageEntity.fetchRequest()
        // 최신 메시지를 우선 가져온 뒤, 표시용으로만 시간순으로 정렬
        request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
        request.fetchLimit = limit

        // 성능 최적화: 세션 관계 미리 페칭
        request.relationshipKeyPathsForPrefetching = ["session"]

        do {
            // 1) 최신 N개를 가져옴 (내림차순)
            let fetched = try context.fetch(request)
            // 2) 반환 전 시간순(오름차순) + 동률 시 역할(user<assistant<system) + UUID 결정적 정렬
            let roleRank: (String?) -> Int = { role in
                switch role ?? "user" {
                case "user": return 0
                case "assistant": return 1
                case "system": return 2
                default: return 3
                }
            }
            let messageEntities = fetched.sorted { a, b in
                let ta = a.timestamp ?? Date.distantPast
                let tb = b.timestamp ?? Date.distantPast
                if ta != tb { return ta < tb }
                let ra = roleRank(a.role)
                let rb = roleRank(b.role)
                if ra != rb { return ra < rb }
                return a.id.uuidString < b.id.uuidString
            }
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

    /// 특정 세션의 채팅 메시지 조회
    /// - Note: limit가 지정된 경우 최신 메시지를 우선적으로 가져온 뒤, 반환 시 시간순(오름차순)으로 정렬합니다.
    public func getChatMessages(forSessionId sessionId: String, limit: Int? = nil) -> [StoredChatMessage] {
        let request: NSFetchRequest<StoredChatMessageEntity> = StoredChatMessageEntity.fetchRequest()
        // 최신 우선으로 페치하여 fetchLimit가 있을 때 최신 N개를 보장
        request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
        request.predicate = NSPredicate(format: "session.id == %@", sessionId as CVarArg)
        if let limit = limit { request.fetchLimit = limit }
        do {
            // 1) 최신 우선으로 가져오기 (내림차순)
            let fetched = try context.fetch(request)
            // 2) 반환 전 시간순(오름차순) + 동률 시 역할(user<assistant<system) + UUID로 결정성 보장
            let roleRank: (String?) -> Int = { role in
                switch role ?? "user" {
                case "user": return 0
                case "assistant": return 1
                case "system": return 2
                default: return 3
                }
            }
            let sorted = fetched.sorted { a, b in
                let ta = a.timestamp ?? Date.distantPast
                let tb = b.timestamp ?? Date.distantPast
                if ta != tb { return ta < tb }
                let ra = roleRank(a.role)
                let rb = roleRank(b.role)
                if ra != rb { return ra < rb }
                return a.id.uuidString < b.id.uuidString
            }
            return sorted.map { entity in
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
                    contextEmotion: "평온",  // 기본값
                    contextTime: entity.rating,  // 임시 매핑
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
                    type: BehaviorEventType(rawValue: entity.eventType ?? "sessionStart")
                        ?? .sessionStart,
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
                result[keyValue[0].trimmingCharacters(in: .whitespaces)] = keyValue[1]
                    .trimmingCharacters(in: .whitespaces)
            }
        }
        return result
    }

    // MARK: - FeedbackManager 호환성 API (완전 통합)

    /// 피드백 세션 시작 (FeedbackManager.startSession 대체)
    public func startSession(presetName: String, recommendation: Any?, contextEmotion: String) {
        feedbackQueue.async(flags: .barrier) {
            var recVolumes: [Float] = []
            var recVersions: [Int] = []
            if let rec = recommendation as? EnhancedRecommendationResponse {
                recVolumes = rec.volumes
                recVersions = rec.versions
            }
            let session = FeedbackSession(
                id: UUID().uuidString,
                presetName: presetName,
                startTime: Date(),
                contextEmotion: contextEmotion,
                recommendedVolumes: recVolumes,
                recommendedVersions: recVersions,
                currentVolumes: recVolumes
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
    public func endCurrentSession(
        finalVolumes: [Float], listeningDuration: TimeInterval, wasSaved: Bool,
        satisfaction: Int = 0
    ) {
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

            print(
                "🏁 [SessionManager] 피드백 세션 종료: 청취시간 \(String(format: "%.1f", listeningDuration))초")
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

    // MARK: - AI 통합 호출 (단일 진입점)

    /// 스트리밍 단일 진입점: 첫 토큰 즉시 UI 반영 + 완료 시 저장(옵션)
    public func sendMessageStream(
        content: String,
        mode: AIMode,
        saveMessages: Bool = true,
        sessionId: String? = nil,
        tokenConfigOverride: TokenConfiguration? = nil
    ) -> AsyncThrowingStream<AIStreamResponse, Error> {
        // 사용량/권한 게이트는 동기 확인 후 스트림 생성
        if mode == .taskAdviceOverall {
            let tier = StoreKitSubscriptionManager.shared.currentTier
            let tierKey: String = {
                switch tier {
                case .max: return "AI_LIMITS_TODO_OVERALL_ADVICE_MAX"
                case .pro: return "AI_LIMITS_TODO_OVERALL_ADVICE_PRO"
                case .free: return "AI_LIMITS_TODO_OVERALL_ADVICE_FREE"
                }
            }()
            let limit = ConfigReader.int(tierKey, default: 0) ?? 0
            let status = usageGate.canUseDailyKeyedFeature(key: "todo_overall_advice", limit: limit)
            guard status.canUse else {
                return AsyncThrowingStream {
                    $0.finish(
                        throwing: AIServiceError.configurationError("사용량 한도를 초과했습니다. 내일 다시 시도해주세요.")
                    )
                }
            }
        } else {
            let usage = usageGate.checkUsage(for: mode)
            guard usage.canUse else {
                return AsyncThrowingStream {
                    $0.finish(
                        throwing: AIServiceError.configurationError("사용량 한도를 초과했습니다. 내일 다시 시도해주세요.")
                    )
                }
            }
        }

        let targetSessionId = sessionId ?? getCurrentOrCreateSession().id
        return AsyncThrowingStream { continuation in
            // 내부 생산 Task를 보관하여 소비자가 스트림을 취소할 때 즉시 중단
            let producer = Task {
                do {
                    let aiContext = try await buildAIContext(for: mode, sessionId: targetSessionId)
                    let selectedModel = SettingsManager.shared.selectedAIModel
                    let tokenCfg = tokenConfigOverride ?? mode.recommendedTokenConfig
                    var aggregate = ""
                    let stream = UnifiedAIServiceImpl.shared.sendMessageStream(
                        content: content,
                        model: selectedModel,
                        mode: mode,
                        context: aiContext,
                        tokenConfig: tokenCfg,
                        assembledPrompt: nil
                    )
                    for try await piece in stream {
                        try Task.checkCancellation()
                        // 모든 조각의 델타를 누적(완료 조각 포함)하여 저장 시 누락 방지
                        aggregate += piece.delta
                        if piece.isComplete {
                            // 저장 전 공백 제거 후 빈 문자열이면 저장하지 않음
                            let trimmed = aggregate.trimmingCharacters(in: .whitespacesAndNewlines)
                            if saveMessages && !trimmed.isEmpty {
                                // 저장은 비동기로 수행하여 UI 스트림 지연 최소화
                                Task { [trimmed] in
                                    let aiResponse = AIResponse(
                                        id: UUID().uuidString, model: selectedModel, mode: mode,
                                        content: trimmed,
                                        metadata: ResponseMetadata(
                                            emotionAnalysis: nil, recommendations: nil,
                                            confidenceScore: 0, additionalInfo: [:]),
                                        usage: TokenUsage(
                                            promptTokens: 0, completionTokens: 0, totalTokens: 0,
                                            estimatedCost: 0), timestamp: Date(), processingTime: 0)
                                    try? await self.saveAIConversation(
                                        sessionId: targetSessionId, userMessage: content,
                                        aiResponse: aiResponse, mode: mode)
                                }
                            }
                            continuation.yield(piece)
                            continuation.finish()
                        } else {
                            continuation.yield(piece)
                        }
                    }
                } catch is CancellationError {
                    // 소비자 취소로 인한 중단 → 조용히 종료
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { @Sendable _ in
                producer.cancel()
            }
        }
    }

    /// 모든 AI 호출의 단일 진입점 - 3시간 캐싱 보장
    /// - Parameters:
    ///   - content: 사용자 입력
    ///   - mode: AI 모드
    ///   - saveMessages: 메시지 저장 여부 (기본 true)
    ///   - sessionId: 특정 세션 ID (기본적으로 현재 세션 사용)
    /// - Returns: AI 응답
    public func sendMessage(
        content: String,
        mode: AIMode,
        saveMessages: Bool = true,
        sessionId: String? = nil,
        policyMeta: [String: String]? = nil,
        tokenConfigOverride: TokenConfiguration? = nil
    ) async throws -> AIResponse {
        #if DEBUG
            let __perfStart = ProcessInfo.processInfo.systemUptime
            func __log(_ step: String) {
                let now = ProcessInfo.processInfo.systemUptime
                let ms = Int(((now - __perfStart) * 1000.0).rounded())
                print(
                    "⏱️ [⚡ Performance] [SessionManager] \(step)=\(ms)ms mode=\(mode.rawValue) userLen=\(content.count)"
                )
            }
            __log("gate:usage")
        #endif
        print("🚀 [SessionManager] AI 호출 시작 - 모드: \(mode.rawValue), 내용: \(content.prefix(50))...")

        // 1. 사용량 한도 확인 (모드별 정책)
        if mode == .taskAdviceOverall {
            // 전체 조언은 별도 키드 제한을 사용
            // SSOT: 전체 조언 기본치는 티어별 AI_LIMITS_TODO_OVERALL_ADVICE_* 에서만 관리
            let base = 0
            // 티어별 키 우선 적용: MAX > PRO > FREE > 기본
            let tier = StoreKitSubscriptionManager.shared.currentTier
            let tierKey: String = {
                switch tier {
                case .max: return "AI_LIMITS_TODO_OVERALL_ADVICE_MAX"
                case .pro: return "AI_LIMITS_TODO_OVERALL_ADVICE_PRO"
                case .free: return "AI_LIMITS_TODO_OVERALL_ADVICE_FREE"
                }
            }()
            let limit = ConfigReader.int(tierKey, default: base) ?? base
            let status = usageGate.canUseDailyKeyedFeature(
                key: "todo_overall_advice", limit: limit)
            guard status.canUse else {
                print("❌ [SessionManager] 사용량 한도 초과: task_advice_overall 0/\(limit)")
                throw AIServiceError.configurationError("사용량 한도를 초과했습니다. 내일 다시 시도해주세요.")
            }
        } else {
            let usage = usageGate.checkUsage(for: mode)
            guard usage.canUse else {
                print(
                    "❌ [SessionManager] 사용량 한도 초과: \(mode.rawValue) \(usage.currentUsage)/\(usage.dailyLimit)"
                )
                throw AIServiceError.configurationError("사용량 한도를 초과했습니다. 내일 다시 시도해주세요.")
            }
        }

        // 2. 세션 ID 결정
        let targetSessionId = sessionId ?? getCurrentOrCreateSession().id
        #if DEBUG
            __log("ctx:resolveSession")
        #endif

        // 3. 컨텍스트 구성 (3시간 캐싱 적용)
        let aiContext = try await buildAIContext(for: mode, sessionId: targetSessionId)
        #if DEBUG
            __log("ctx:build")
        #endif

        // 4. AI 서비스 호출
        // 단일 진실: 설정에서 실제 호출용 모델을 바로 가져옴
        let selectedModel = SettingsManager.shared.selectedAIModel
        let effectiveTokenConfig = tokenConfigOverride ?? mode.recommendedTokenConfig
        #if DEBUG
            __log("svc:call:start")
        #endif
        let response = try await UnifiedAIServiceImpl.shared.sendMessage(
            content: content,
            model: selectedModel,
            mode: mode,
            context: aiContext,
            tokenConfig: effectiveTokenConfig,
            assembledPrompt: nil  // AIContextBuilder에서 자동 생성
        )
        #if DEBUG
            __log("svc:call:done")
        #endif

        // 5. 메시지 저장 (옵션)
        if saveMessages {
            try await saveAIConversation(
                sessionId: targetSessionId,
                userMessage: content,
                aiResponse: response,
                mode: mode
            )
        }

        print("✅ [SessionManager] AI 호출 완료 - 응답 길이: \(response.content.count)자")
        #if DEBUG
            __log("done")
        #endif
        return response
    }

    // Backward-compatible overload (no policyMeta)
    public func sendMessage(
        content: String,
        mode: AIMode,
        saveMessages: Bool = true,
        sessionId: String? = nil,
        tokenConfigOverride: TokenConfiguration? = nil
    ) async throws -> AIResponse {
        return try await sendMessage(
            content: content,
            mode: mode,
            saveMessages: saveMessages,
            sessionId: sessionId,
            policyMeta: nil,
            tokenConfigOverride: tokenConfigOverride
        )
    }

    /// AI 컨텍스트 구성 (3시간 캐싱 적용)
    private func buildAIContext(for mode: AIMode, sessionId: String) async throws -> AIContext {
        print("🏗️ [SessionManager] AI 컨텍스트 구성 시작 - 모드: \(mode.rawValue)")

        // 최근 대화 내역 조회 (3+3 구성으로 축소: UX 유지 + 토큰 절감)
        let recentMessages = buildBalancedRecent(sessionId: sessionId, userMax: 3, assistantMax: 3)

        // 사용자 프로필 정보
        let userSettings = UserSettingsModel.loadFromUserDefaults()

        // 핵심 기억 요약
        let coreMemorySummary = MemoryManager.shared.getMemorySummary(maxItems: 5)

        // AIContext 생성
        let context = AIContext(
            userId: "user_\(sessionId)",
            sessionId: sessionId,
            conversationHistory: convertToAIConversationTurns(recentMessages),
            userPreferences: createUserPreferences(from: userSettings),
            environmentContext: nil
        )

        print("✅ [SessionManager] AI 컨텍스트 구성 완료 - 최근 메시지: \(recentMessages.count)개")
        return context
    }

    /// 균형잡힌 최근 대화 구성 (사용자 3개, AI 3개)
    private func buildBalancedRecent(sessionId: String, userMax: Int, assistantMax: Int)
        -> [StoredChatMessage]
    {
        let messages = getChatMessages(forSessionId: sessionId, limit: 50)  // 충분한 양 조회

        var userMessages: [StoredChatMessage] = []
        var assistantMessages: [StoredChatMessage] = []

        // 최신순으로 정렬하여 균형잡힌 선택
        let sortedMessages = messages.sorted { $0.timestamp > $1.timestamp }

        for message in sortedMessages {
            switch message.role {
            case "user":
                if userMessages.count < userMax {
                    userMessages.append(message)
                }
            case "assistant":
                if assistantMessages.count < assistantMax {
                    assistantMessages.append(message)
                }
            default:
                // 시스템 메시지는 제외 (시스템 프롬프트에서 처리)
                continue
            }
        }

        // 시간순으로 다시 정렬하여 자연스러운 대화 흐름 유지
        let combined = (userMessages + assistantMessages).sorted { $0.timestamp < $1.timestamp }

        print(
            "🔄 [SessionManager] 균형잡힌 대화 구성: 사용자 \(userMessages.count)개, AI \(assistantMessages.count)개"
        )
        return combined
    }

    /// AI 대화 저장
    private func saveAIConversation(
        sessionId: String,
        userMessage: String,
        aiResponse: AIResponse,
        mode: AIMode
    ) async throws {
        print("💾 [SessionManager] AI 대화 저장 시작")

        // 프리셋 추천 모드는 대화 원문을 저장하지 않고 요약만 저장(토큰/스토리지 최적화)
        if mode == .presetRecommendation {
            let masked = SettingsManager.shared.maskPIIForExport(userMessage)
            let userSummary = "프리셋을 요청!"  // 사용자 입력의 사실만 기록
            let userStoredMessage = StoredChatMessage(
                id: UUID().uuidString,
                timestamp: Date(),
                role: "user",
                content: userSummary,
                type: .text
            )
            try addChatMessage(to: sessionId, message: userStoredMessage)
            // AI 응답은 JSON 파싱 후 프리셋명만 요약 저장
            var aiSummary = "프리셋을 추천!."
            if let parsed = AIResponseParser.shared.parsePresetRecommendation(aiResponse.content) {
                let name = parsed.presetName.trimmingCharacters(in: .whitespacesAndNewlines)
                aiSummary = name.isEmpty ? "프리셋을 추천!." : "프리셋을 추천!: [\(name)]."
            }
            let aiStoredMessage = StoredChatMessage(
                id: aiResponse.id,
                timestamp: aiResponse.timestamp,
                role: "assistant",
                content: aiSummary,
                type: .text
            )
            try addChatMessage(to: sessionId, message: aiStoredMessage)
            print("✅ [SessionManager] AI 대화 저장 완료(요약 모드)")
            return
        }

        // 사용자/AI 타임스탬프 정합성 보장: 동일 시각이면 역할 우선 정렬이 적용되지만, 가독성을 위해 AI를 >= 사용자로 보정
        let userTs = Date()
        let aiTsBase = aiResponse.timestamp
        let aiTs = aiTsBase < userTs ? userTs : aiTsBase

        // 사용자 메시지 저장
        let userStoredMessage = StoredChatMessage(
            id: UUID().uuidString,
            timestamp: userTs,
            role: "user",
            content: userMessage,
            type: .text
        )
        try addChatMessage(to: sessionId, message: userStoredMessage)
        // AI 응답 저장
        let aiStoredMessage = StoredChatMessage(
            id: aiResponse.id,
            timestamp: aiTs,
            role: "assistant",
            content: aiResponse.content,
            type: .text
        )
        try addChatMessage(to: sessionId, message: aiStoredMessage)
        print("✅ [SessionManager] AI 대화 저장 완료")
    }

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

    // MARK: - Private Helper Methods

    /// AIModelType을 AIModel로 변환
    private func mapAIModelTypeToAIModel(_ modelType: AIModelType) -> AIModel {
        switch modelType {
        case .claude35:
            return .claude
        case .gpt4:
            return .openAI
        case .gemini:
            return .gemini
        case .naver:
            return .naver
        case .freeModel:
            return .freeModel
        case .apple:
            return .onDevice  // Apple Foundation Models는 온디바이스 경로 사용
        case .onDevice:
            return .onDevice  // 온디바이스는 현재 무료 모델로 매핑
        case .testModel:
            return .freeModel  // 테스트 모델도 무료 모델로 매핑
        }
    }

    /// StoredChatMessage 배열을 AIConversationTurn 배열로 변환
    private func convertToAIConversationTurns(_ messages: [StoredChatMessage])
        -> [AIConversationTurn]
    {
        return messages.map { message in
            let role: Role
            switch message.role {
            case "user":
                role = .user
            case "assistant":
                role = .assistant
            case "system":
                role = .system
            default:
                role = .user  // 기본값
            }

            return AIConversationTurn(
                role: role,
                content: message.content,
                timestamp: message.timestamp
            )
        }
    }

    /// UserSettingsModel에서 UserPreferences 생성
    private func createUserPreferences(from settings: UserSettingsModel) -> UserPreferences {
        return UserPreferences(
            preferredModel: nil,
            responseStyle: .casual,
            language: "ko",
            maxResponseLength: nil
        )
    }

    /// 모든 세션을 메모리에 로드
    private func loadAllSessions() {
        let request: NSFetchRequest<UnifiedSessionEntity> = UnifiedSessionEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "lastActivityAt", ascending: false)]

        do {
            let sessionEntities = try context.fetch(request)

            // ⚠️ NSManagedObject는 스레드-세이프하지 않음. fetch한 스레드(현재 스레드)에서
            // value type으로 변환을 완료한 뒤, 캐시에 저장만 배리어 큐에서 수행한다.
            let sessions: [UnifiedSession] = sessionEntities.map { entity in
                return self.convertToUnifiedSession(from: entity)
            }

            cacheQueue.async(flags: .barrier) {
                self.sessionCache.removeAll()
                for session in sessions {
                    self.sessionCache[session.id] = session
                }
            }

            print("[SessionManager][LOAD] fetched=\(sessions.count)")

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
            print(
                "✅ [SessionManager] UserBehaviorAnalytics 데이터 마이그레이션 완료: \(migratedBehavior)개 이벤트")

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
            let existingSessions = try? JSONDecoder().decode([String: ChatSession].self, from: data)
        else {
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
            if let feedbackWrappers = try? JSONDecoder().decode(
                [PresetFeedbackWrapper].self, from: data)
            {
                var migratedCount = 0

                // 가장 최근 세션을 찾거나 새로 생성
                let recentSession = getCurrentOrCreateSession()

                let request: NSFetchRequest<UnifiedSessionEntity> =
                    UnifiedSessionEntity.fetchRequest()
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
                            "completionRate": String(userSession.completionRate),
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
        request.predicate = NSPredicate(
            format: "createdAt >= %@ AND createdAt < %@", startOfDay as NSDate, endOfDay as NSDate)
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
                emotionHistory.append(
                    EmotionHistoryItem(
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

    /// 사용자 3턴 + AI 3턴으로 균형 있게 최신순 6개를 생성
    static func buildBalancedRecent(_ raw: [StoredChatMessage], userMax: Int, assistantMax: Int)
        -> [ChatMessageLite]
    {
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
                role: m.role == "assistant"
                    ? "assistant" : (m.role == "system" ? "system" : "user"),
                content: m.content,
                createdAt: m.timestamp
            )
        }
    }
}

// 요약 유틸은 AIContextBuilder로 이동(단일 출처)

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
    public func getDualStorageStatus() -> (
        sessionManagerActive: Bool, userDefaultsActive: Bool, migrationComplete: Bool
    ) {
        return (
            sessionManagerActive: true,
            userDefaultsActive: true,  // 현재는 여전히 활성
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
            getSession(id: overrideId) != nil
        {
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
        model: AIModel = .onDevice,
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
        model: AIModel = .onDevice,
        mode: AIMode,
        saveMessages: Bool = true,
        policyMeta: [String: String]? = nil
    ) async throws -> String {
        print(
            "🎯 [SessionManager] 중앙집중 AI 호출 - 모델: \(model.rawValue), 모드: \(mode.rawValue), 내용: \(content.prefix(50))..."
        )

        // 1) 사용자 메시지 저장(정책 적용)
        // 프리셋 추천 모드에서는 화면(UI)에서 이미 사용자 액션 버블을 표시하므로
        // 저장소에는 중복 텍스트를 남기지 않는다(노이즈 방지).
        if saveMessages && mode != .presetRecommendation {
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
            // 2) 최근 대화(사용자 3/AI 3) 균형 구성 → 컨텍스트 조립
            let rawMessages = getRecentChatMessages(limit: 60)
            let recent: [ChatMessageLite] = Self.buildBalancedRecent(
                rawMessages, userMax: 3, assistantMax: 3)

            let personaSignature = UserRulesManager.shared.personaSignature()
            let coreSummary = MemoryManager.shared.getMemorySummary(maxItems: 10)
            let effectiveSummary: String? = {
                if !coreSummary.isEmpty { return coreSummary }
                let summary = AIContextBuilder.shared.summarizeRecent(recent, maxItems: 16)
                return summary.isEmpty ? nil : summary
            }()

            // 멀티-메시지 경로를 위한 역할 기반 히스토리 구성
            let historyTurns: [AIConversationTurn] = recent.map { lite in
                AIConversationTurn(
                    role: Role(rawValue: lite.role) ?? .user, content: lite.content,
                    timestamp: lite.createdAt)
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
                assembledPrompt: nil
            )
            let response = aiResponse.content

            // 4) AI 응답 저장(정책 적용)
            // 프리셋 추천 모드에서는 중앙 파서가 생성하는 카드가 UI/저장의 단일 진실(SSoT)이며,
            // 요약 텍스트("AI: 프리셋을 추천했습니다.")를 별도 저장하면 채팅에 노이즈 버블이 생긴다.
            // 따라서 presetRecommendation 모드에서는 조용히 저장을 생략한다.
            if saveMessages && mode != .presetRecommendation {
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

    // Backward-compatible overload (no policyMeta)
    public func sendMessage(
        content: String,
        model: AIModel = .claude,
        mode: AIMode,
        saveMessages: Bool = true
    ) async throws -> String {
        return try await sendMessage(
            content: content,
            model: model,
            mode: mode,
            saveMessages: saveMessages,
            policyMeta: nil
        )
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
        return try await sendMessage(content: prompt, model: .onDevice)
    }

    /// 프리셋 추천 전용 AI 호출
    public func recommendPreset(emotion: String, context: String) async throws -> String {
        let prompt = "감정: \(emotion), 상황: \(context)에 맞는 음악 프리셋을 추천해주세요."
        return try await sendMessage(content: prompt, model: .onDevice)
    }

    /// 일반 채팅 AI 호출
    public func chat(message: String) async throws -> String {
        return try await sendMessage(content: message, model: .onDevice)
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
            context != self.context
        else {
            return  // 자신의 컨텍스트 변경은 무시
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
                print(
                    "⚠️ [SessionManager] 캐시 불일치 감지 - 캐시: \(cacheCount), Core Data: \(coreDataCount)")
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
    var recommendedVersions: [Int]
    var currentVolumes: [Float]
}
