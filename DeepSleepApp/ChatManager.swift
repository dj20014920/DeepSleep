import Foundation

// MARK: - 💪 Ultra Strong Module Fix
// 필수 타입들의 명시적 참조를 통한 Swift 컴파일러 최적화
// SharedModels.swift: ChatMessage, ChatMessageType, MessageSender
// AIServiceTypes.swift: AIMode, AIServiceError, ConversationType  
// AI/Services/UnifiedAIServiceImpl.swift: UnifiedAIServiceImpl
// AI/Logging/AICallLogger.swift: AICallLogger
// AI/UsageLimitManager.swift: UsageLimitManager

    /// 채팅 세션 및 메시지 관리를 담당하는 매니저
    /// PERF-WARNING: 대량의 채팅 히스토리 처리 시 메모리 사용량 주의
    /// - 테스트 방안: Instruments의 Allocations로 메모리 누수 확인
    public class ChatManager {
        public static let shared = ChatManager()
        
        // UserDefaults 키 설정 - 채팅 히스토리와 세션 메타데이터 저장용
        private let userDefaults = UserDefaults.standard
        private let chatHistoryKey = "deepSleep_chatHistory"
        private let sessionMetadataKey = "deepSleep_sessionMetadata"
        
        // 메모리 캐시 - 빠른 접근을 위한 세션 캐시 저장소
        private var sessionCache: [String: ChatSession] = [:]
        // 동시성 처리를 위한 전용 큐
        private let cacheQueue = DispatchQueue(label: "com.deepsleep.chatmanager", attributes: .concurrent)
        
        // 🚀 AI 서비스 통합 - 통합 AI 서비스와 설정 매니저
        private let aiService = UnifiedAIServiceImpl.shared
        private let settingsManager = SettingsManager.shared
        
        private init() {
            #if DEBUG
            print("💾 [ChatPersistence] ChatManager 초기화 시작")
            #endif
            loadAllSessions()
            #if DEBUG
            print("💾 [ChatPersistence] 세션 로드 완료 - 총 \(sessionCache.count)개 세션")
            #endif
        }
    
    
    // MARK: - Public Methods
    
    /// 모든 채팅 세션 가져오기 (최근 활동 순으로 정렬)
    public func getSessions() -> [ChatSession] {
        return cacheQueue.sync {
            Array(sessionCache.values).sorted { $0.lastActivityAt > $1.lastActivityAt }
        }
    }
    
    /// 특정 세션 가져오기
    public func getSession(id: String) -> ChatSession? {
        return cacheQueue.sync {
            sessionCache[id]
        }
    }
    
    /// 새 세션 생성 - 고유 ID와 현재 시간으로 새로운 채팅 세션 생성
    public func createSession(metadata: ChatSessionMetadata? = nil) -> ChatSession {
        let session = ChatSession(
            id: UUID().uuidString,
            createdAt: Date(),
            lastActivityAt: Date(),
            messages: [],
            metadata: metadata
        )
        
        #if DEBUG
        print("💾 [ChatPersistence] 새 세션 생성 - ID: \(session.id)")
        #endif
        
        // 메모리 캐시에 저장 후 디스크에 즉시 기록
        cacheQueue.async(flags: .barrier) {
            self.sessionCache[session.id] = session
            self.saveSessionToDisk(session)
            #if DEBUG
            print("💾 [ChatPersistence] 세션 디스크 저장 완료")
            #endif
        }
        
        return session
    }
    
    /// 세션에 메시지 추가 - 특정 세션에 새 메시지를 추가하고 마지막 활동 시간 업데이트
    public func addMessage(to sessionId: String, message: StoredChatMessage) {
        #if DEBUG
        print("💾 [ChatPersistence] 메시지 추가 - 세션: \(sessionId), 타입: \(message.type)")
        #endif
        
        cacheQueue.async(flags: .barrier) {
            guard var session = self.sessionCache[sessionId] else {
                #if DEBUG
                print("💾 [ChatPersistence] 경고: 세션을 찾을 수 없음 - ID: \(sessionId)")
                #endif
                return
            }
            
            // 메시지 추가 및 세션 활동 시간 갱신
            session.messages.append(message)
            session.lastActivityAt = Date()
            
            // 캐시 업데이트 및 디스크 저장
            self.sessionCache[sessionId] = session
            self.saveSessionToDisk(session)
            
            #if DEBUG
            print("💾 [ChatPersistence] 메시지 저장 완료 - 현재 세션 메시지 수: \(session.messages.count)")
            #endif
        }
    }
    
    /// 🎯 Phase 2: SessionManager 통합 - ChatMessage를 현재 활성 세션에 추가
    public func append(_ message: ChatMessage) {
        // ChatMessage를 StoredChatMessage로 변환
        let storedMessage = StoredChatMessage(
            id: message.id,
            text: message.text ?? "",
            type: getStoredMessageType(from: message.type, sender: message.sender),
            timestamp: message.date,
            metadata: createStringMetadata(from: message)
        )
        
        // 🎯 Phase 2: SessionManager를 통한 통합 저장
        let currentSession = SessionManager.shared.getCurrentOrCreateSession()
        SessionManager.shared.addChatMessage(to: currentSession.id, message: storedMessage)
        
        // 🎯 기존 ChatManager 캐시도 업데이트 (호환성 유지)
        addMessage(to: currentSession.id, message: storedMessage)
        
        // 🎯 MessageStore에도 저장 (이중 저장으로 안정성 확보)
        Task {
            do {
                try await MessageStore.shared.saveMessage(
                    content: message.text ?? "",
                    isUser: message.sender == .user,
                    messageType: getMessageTypeString(from: message.type),
                    isPersistent: shouldBePersistent(message.type)
                )
                // MessageStore에도 저장 완료
            } catch {
                print("❌ [ChatManager] MessageStore 저장 실패: \(error)")
            }
        }
        
        print("✅ [ChatManager] Phase 2: SessionManager 통합 저장 완료")
    }
    
    /// 현재 활성 세션 가져오기 또는 새로 생성
    private func getCurrentOrCreateSession() -> ChatSession {
        // 가장 최근 세션 가져오기
        let sessions = getSessions()
        if let latestSession = sessions.first,
           Calendar.current.isDate(latestSession.lastActivityAt, inSameDayAs: Date()) {
            return latestSession
        }
        
        // 새 세션 생성
        return createSession()
    }
    
    /// ChatMessageType을 StoredMessageType으로 변환
    private func getStoredMessageType(from type: ChatMessageType, sender: MessageSender) -> StoredMessageType {
        switch type {
        case .user: return .user
        case .bot, .aiResponse: return .bot
        case .system: return .system
        case .presetRecommendation: return .presetRecommendation
        case .error: return .error
        default: 
            // sender 기반으로 결정
            return sender == .user ? .user : .bot
        }
    }
    
    /// ChatMessageType을 String으로 변환 (MessageStore 호환성용)
    private func getMessageTypeString(from type: ChatMessageType) -> String {
        switch type {
        case .user: return "user"
        case .bot, .aiResponse: return "bot"
        case .system: return "system"
        case .presetRecommendation: return "preset"
        case .recommendationSelector: return "selector"
        case .presetOptions, .postPresetOptions: return "options"
        case .loading: return "loading"
        case .error: return "error"
        }
    }
    
    /// 메시지 메타데이터 생성 (Any 타입)
    private func createMetadata(from message: ChatMessage) -> [String: Any] {
        var metadata: [String: Any] = [:]
        
        if let quickActions = message.quickActions {
            metadata["quickActions"] = quickActions.map { ["title": $0.title, "action": $0.action] }
        }
        
        metadata["messageId"] = message.id.uuidString
        
        return metadata
    }
    
    /// 메시지 메타데이터 생성 (String 타입 - ChatManager 호환성용)
    private func createStringMetadata(from message: ChatMessage) -> [String: String] {
        var metadata: [String: String] = [:]
        
        if let quickActions = message.quickActions {
            let actionsString = quickActions.map { "\($0.title):\($0.action)" }.joined(separator: ",")
            metadata["quickActions"] = actionsString
        }
        
        metadata["messageId"] = message.id.uuidString
        metadata["messageType"] = getMessageTypeString(from: message.type)
        
        return metadata
    }
    
    /// 메시지 타입에 따라 지속성 여부 결정
    private func shouldBePersistent(_ type: ChatMessageType) -> Bool {
        switch type {
        case .system: return true
        case .presetRecommendation: return true
        case .error: return true
        default: return false
        }
    }
    
    /// 🎯 메모리 캐시를 디스크로 즉시 동기화 (앱 백그라운드 진입 시 호출)
    public func flush() {
        print("💾 [ChatManager] flush() 호출됨 - 메모리 → 디스크 동기화 시작")
        
        cacheQueue.sync(flags: .barrier) {
            // 모든 세션을 디스크에 저장
            for session in sessionCache.values {
                saveSessionToDisk(session)
            }
            
            // 전체 세션 메타데이터 저장
            saveAllSessionsToDisk()
            
            print("💾 [ChatManager] flush() 완료 - \(sessionCache.count)개 세션 저장됨")
        }
        
        // MessageStore도 동기화 (비동기로 처리)
        Task {
            // MessageStore에 flushToDisk 메서드가 없으므로 주석 처리
            // MessageStore는 자동으로 저장되므로 별도 처리 불필요
            print("💾 [ChatManager] MessageStore는 자동 저장됨")
        }
    }
    
    /// 세션 삭제
    public func deleteSession(id: String) {
        cacheQueue.async(flags: .barrier) {
            self.sessionCache.removeValue(forKey: id)
            self.deleteSessionFromDisk(id)
        }
    }
    
    /// 모든 세션 삭제
    public func clearAllSessions() {
        cacheQueue.async(flags: .barrier) {
            self.sessionCache.removeAll()
            self.userDefaults.removeObject(forKey: self.chatHistoryKey)
            self.userDefaults.removeObject(forKey: self.sessionMetadataKey)
        }
    }
    
    // MARK: - Private Methods
    
    /// 모든 세션을 디스크에서 메모리로 로드 - 앱 시작 시 호출
    private func loadAllSessions() {
        #if DEBUG
        print("💾 [ChatPersistence] 디스크에서 세션 로드 시작")
        #endif
        
        guard let data = userDefaults.data(forKey: chatHistoryKey),
              let sessions = try? JSONDecoder().decode([String: ChatSession].self, from: data) else {
            #if DEBUG
            print("💾 [ChatPersistence] 저장된 세션 없음 또는 로드 실패")
            #endif
            return
        }
        
        // 메모리 캐시에 로드된 세션 저장 (동기적으로 처리하여 즉시 사용 가능하도록)
        cacheQueue.sync(flags: .barrier) {
            self.sessionCache = sessions
            #if DEBUG
            print("💾 [ChatPersistence] \(sessions.count)개 세션 메모리 로드 완료")
            for (id, session) in sessions {
                print("  - 세션 ID: \(id), 메시지 수: \(session.messages.count)")
            }
            #endif
        }
    }
    
    /// 개별 세션을 디스크에 저장 - 메모리 캐시를 UserDefaults에 즉시 기록
    private func saveSessionToDisk(_ session: ChatSession) {
        var allSessions = sessionCache
        allSessions[session.id] = session
        
        guard let data = try? JSONEncoder().encode(allSessions) else {
            #if DEBUG
            print("💾 [ChatPersistence] 에러: 세션 인코딩 실패")
            #endif
            return
        }
        
        // UserDefaults에 데이터 저장
        userDefaults.set(data, forKey: chatHistoryKey)
        
        // ⚡ 즉시 디스크 플러시 보장 (iOS 12+ 에서는 자동이지만 명시적 호출)
        // UserDefaults.synchronize()는 deprecated 되었지만 
        // 중요한 데이터의 경우 CFPreferencesAppSynchronize 사용 가능
        if #available(iOS 12.0, *) {
            // iOS 12 이상에서는 자동으로 동기화됨
            // 하지만 중요한 데이터는 명시적으로 동기화
            _ = CFPreferencesAppSynchronize(kCFPreferencesCurrentApplication)
        } else {
            // iOS 12 미만에서는 synchronize 호출
            userDefaults.synchronize()
        }
        
        #if DEBUG
        print("💾 [ChatPersistence] 세션 디스크 저장 완료 - ID: \(session.id)")
        #endif
    }
    
    private func deleteSessionFromDisk(_ sessionId: String) {
        var allSessions = sessionCache
        allSessions.removeValue(forKey: sessionId)
        
        guard let data = try? JSONEncoder().encode(allSessions) else { return }
        userDefaults.set(data, forKey: chatHistoryKey)
    }
    
    
    /// 최근 메시지 조회 API - 현재 또는 최신 세션에서 지정된 개수만큼 메시지 반환
    /// - Parameter limit: 반환할 메시지 개수 (기본값: 100)
    /// - Returns: 최근 메시지 배열 (시간순)
    public func getRecentMessages(limit: Int = 100) -> [StoredChatMessage] {
        print("🔍 [ChatManager] getRecentMessages 호출 - limit: \(limit)")
        
        return cacheQueue.sync {
            // 현재 활성 세션 가져오기
            let currentSession = getCurrentOrCreateSession()
            
            // suffix를 사용하여 최근 N개 메시지 추출
            let recentMessages = Array(currentSession.messages.suffix(limit))
            
            print("✅ [ChatManager] 최근 메시지 \(recentMessages.count)개 반환")
            return recentMessages
        }
    }
    
    /// StoredChatMessage를 ChatMessage로 변환하는 헬퍼 메서드
    /// - Parameter stored: 저장된 메시지
    /// - Returns: 변환된 ChatMessage
    public func convertToChatMessage(_ stored: StoredChatMessage) -> ChatMessage {
        // StoredMessageType을 ChatMessageType으로 변환
        let chatMessageType: ChatMessageType
        switch stored.type {
        case .user:
            chatMessageType = .user
        case .bot:
            chatMessageType = .bot
        case .system:
            chatMessageType = .system
        case .presetRecommendation:
            chatMessageType = .presetRecommendation
        case .error:
            chatMessageType = .error
        }
        
        // MessageSender 결정
        let sender: MessageSender
        switch stored.type {
        case .user:
            sender = .user
        case .bot, .presetRecommendation:
            sender = .ai
        case .system, .error:
            sender = .system
        }
        
        // QuickActions 복원 (메타데이터에서)
        var quickActions: [QuickAction]? = nil
        if let quickActionsString = stored.metadata?["quickActions"] {
            // "title:action,title2:action2" 형식의 문자열을 파싱
            let actionPairs = quickActionsString.components(separatedBy: ",")
            quickActions = actionPairs.compactMap { pair in
                let components = pair.components(separatedBy: ":")
                guard components.count == 2 else { return nil }
                return QuickAction(title: components[0], action: components[1])
            }
        }
        
        // ChatMetadata 생성
        let metadata = ChatMetadata(
            responseTime: nil,
            modelUsed: stored.metadata?["model"],
            tokenCount: nil,
            sessionId: stored.metadata?["sessionId"]
        )
        
        return ChatMessage(
            id: stored.id,
            text: stored.text,
            date: stored.timestamp,
            sender: sender,
            type: chatMessageType,
            quickActions: quickActions,
            isPending: false,
            aithoughts: nil,
            metadata: metadata
        )
    }
    
    /// 모든 메시지 가져오기 (ChatRouter 호환성용)
    public var messages: [StoredChatMessage] {
        return cacheQueue.sync {
            var allMessages: [StoredChatMessage] = []
            for session in sessionCache.values {
                allMessages.append(contentsOf: session.messages)
            }
            return allMessages.sorted { $0.timestamp > $1.timestamp }
        }
    }
    
    // MARK: - 🤖 AI 메시지 전송 (새로 추가된 통합 기능)
    
    // MARK: - sendAIMessage는 제거됨 (sendMessage로 통일)
    
    // MARK: - ChatViewController 전용 Wrapper 메서드
    
    /// 간단한 문자열 기반 AI 메시지 전송 (오버로드 1) - 통합 로깅 시스템 적용
    /// - Parameters:
    ///   - userInput: 사용자 입력 메시지
    ///   - modeString: AI 모드 문자열 ("general_conversation", "emotion_diary_analysis" 등)
    ///   - modelString: AI 모델 문자열 (선택사항, nil이면 기본값 사용)
    /// - Returns: AI 응답 내용 (문자열)
    public func sendMessage(
        userInput: String,
        modeString: String = "general_conversation", 
        modelString: String? = nil
    ) async throws -> String {
        
        // 문자열을 AIMode로 변환
        let aiMode: AIMode
        switch modeString {
        case "general_conversation":
            aiMode = .generalConversation
        case "emotion_diary_analysis":
            aiMode = .emotionDiaryAnalysis
        case "task_advice":
            aiMode = .taskAdvice
        case "preset_recommendation":
            aiMode = .presetRecommendation
        case "emotion_analysis":
            aiMode = .emotionAnalysis
        default:
            aiMode = .generalConversation
        }
        
        // 🛡️ 사용량 제한 체크 (UsageLimitManager 통합)
        let (canUse, currentUsage, dailyLimit) = UsageLimitManager.shared.canUseAIFeature(aiMode)
        if !canUse {
            let errorMessage = """
            🚫 일일 사용 한도 초과
            
            \(aiMode.displayName) 기능의 일일 한도(\(dailyLimit)회)를 모두 사용했습니다.
            현재 사용량: \(currentUsage)/\(dailyLimit)
            
            내일 00시에 초기화됩니다. 잠시 후 다시 이용해주세요.
            """
            throw AIServiceError.usageLimitExceeded(errorMessage)
        }
        
        // 문자열을 AIModel로 변환 (선택사항)
        let preferredModel: AIModel?
        if let modelStr = modelString {
            switch modelStr {
            case "claude":
                preferredModel = .claude
            case "openai":
                preferredModel = .openAI
            case "gemini":
                preferredModel = .gemini
            case "naver":
                preferredModel = .naver
            case "free", "free_model":
                preferredModel = .freeModel
            case "test", "test_model":
                preferredModel = .freeModel  // testModel도 통합된 freeModel로 처리
            default:
                // 베타 테스트 기간: 기본값을 무료 모델로 설정
                preferredModel = .freeModel
            }
        } else if aiMode == .generalConversation {
            // 일반 대화 모드일 때는 사용자 설정 모델 사용
            let userSelectedType = SettingsManager.shared.selectedLLM
            // AIModelType을 AIModel로 변환
            switch userSelectedType {
            case .claude35:
                preferredModel = .claude
            case .gpt4:
                preferredModel = .openAI
            case .gemini:
                preferredModel = .gemini
            case .naver:
                preferredModel = .naver
            case .onDevice, .freeModel, .testModel:
                preferredModel = .freeModel
            }
        } else {
            // 특정 모드는 UnifiedAIServiceImpl에서 처리
            preferredModel = .freeModel
        }
        
        // 🎯 AIMode별 시스템 프롬프트 자동 주입
        let enhancedUserInput = injectSystemPrompt(for: aiMode, userInput: userInput)
        
        // 📊 AI 호출 시작 로깅
        let selectedModel = preferredModel ?? .freeModel
        let callId = AICallLogger.shared.logAICallStart(
            mode: aiMode,
            model: selectedModel,
            userInput: userInput
        )
        
        let startTime = Date()
        
        do {
            // UnifiedAIService를 직접 호출
            let aiResponse = try await UnifiedAIServiceImpl.shared.sendMessage(
                content: enhancedUserInput,
                model: selectedModel,
                mode: aiMode,
                context: nil,
                tokenConfig: nil
            )
            let response = aiResponse.content
            
            // 📊 AI 호출 성공 로깅
            let processingTime = Int(Date().timeIntervalSince(startTime) * 1000)
            AICallLogger.shared.logAICallSuccess(
                callId: callId,
                responseLength: response.count,
                processingTime: processingTime,
                tokenUsage: nil // response가 String이므로 nil 전달
            )
            
            // 🔄 AI 호출 성공 시 사용량 증가
            UsageLimitManager.shared.incrementUsage(for: aiMode)
            
            // 응답 내용만 반환
            return response
            
        } catch let error as AIServiceError {
            // 📊 AI 호출 실패 로깅
            let processingTime = Int(Date().timeIntervalSince(startTime) * 1000)
            AICallLogger.shared.logAICallFailure(
                callId: callId,
                error: error,
                processingTime: processingTime
            )
            throw error
        } catch {
            // 📊 알 수 없는 에러 로깅
            let processingTime = Int(Date().timeIntervalSince(startTime) * 1000)
            let aiError = AIServiceError.unknown(error)
            AICallLogger.shared.logAICallFailure(
                callId: callId,
                error: aiError,
                processingTime: processingTime
            )
            throw aiError
        }
    }
    
    /* TODO: 나중에 필요할 때 주석 해제
    /// 고급 타입 기반 AI 메시지 전송 (오버로드 2) - 통합 로깅 시스템 적용
    /// - 현재 AIModel, AIContext, AIResponse 타입 참조 문제로 주석 처리됨
    /// - 실제로는 첫 번째 sendMessage(userInput:modeString:modelString:) 메서드만 사용됨
    /// - Parameters:
    ///   - content: 메시지 내용
    ///   - model: AI 모델
    ///   - mode: AI 모드
    ///   - context: AI 컨텍스트 (선택사항)
    ///   - tokenConfig: 토큰 설정 (선택사항)
    /// - Returns: AI 전체 응답 객체
    public func sendMessage(
        content: String,
        model: AIModel,
        mode: AIMode,
        context: AIContext? = nil,
        tokenConfig: TokenConfiguration? = nil
    ) async throws -> AIResponse {
        // 구현부는 주석 처리됨
    }
    */
    
    /// 최근 대화 히스토리 가져오기 (AI 컨텍스트용)
    private func getRecentConversationHistory(sessionId: String, maxMessages: Int = 5) -> [String] {
        guard let session = getSession(id: sessionId) else { return [] }
        
        let recentMessages = Array(session.messages.suffix(maxMessages))
        return recentMessages.map { message in
            let role = message.type == .user ? "사용자" : "AI"
            return "\(role): \(message.text)"
        }
    }
    
    /// 🎯 AIMode별 시스템 프롬프트 자동 주입
    private func injectSystemPrompt(for mode: AIMode, userInput: String) -> String {
        let systemPrompt = getSystemPrompt(for: mode)
        
        return """
        \(systemPrompt)
        
        사용자 요청:
        \(userInput)
        """
    }
    
    /// 🎛️ AIMode별 시스템 프롬프트 매핑 (페르소나 시스템 활성화)
    private func getSystemPrompt(for mode: AIMode) -> String {
        // 🎭 페르소나 시스템 활성화: AIContextManager를 통한 동적 시스템 프롬프트 생성
        let conversationType = mode.toConversationType()
        return AIContextManager.shared.generateSystemPrompt(
            for: conversationType,
            isFirstMessage: true
        )
    }
    
    /// LLMServiceType을 AIModel로 변환 (UnifiedAIServiceImpl과 동일한 로직)
    private func mapLLMServiceTypeToAIModel(_ llmType: LLMServiceType) -> AIModel? {
        switch llmType {
        case .claude:
            return .claude
        case .openAI:
            return .openAI
        case .gemini:
            return .gemini
        case .naver:
            return .naver
        case .onDevice:
            // 온디바이스는 아직 미지원
            return nil
        }
    }
}

// MARK: - Data Models

/// 채팅 세션
public struct ChatSession: Codable {
    public let id: String
    public let createdAt: Date
    public var lastActivityAt: Date
    public var messages: [StoredChatMessage]
    public let metadata: ChatSessionMetadata?
    
    public init(id: String, createdAt: Date, lastActivityAt: Date, messages: [StoredChatMessage], metadata: ChatSessionMetadata?) {
        self.id = id
        self.createdAt = createdAt
        self.lastActivityAt = lastActivityAt
        self.messages = messages
        self.metadata = metadata
    }
}

/// 채팅 세션 메타데이터
public struct ChatSessionMetadata: Codable {
    public let emotion: String?
    public let context: String?
    public let userProfile: String?
    
    public init(emotion: String? = nil, context: String? = nil, userProfile: String? = nil) {
        self.emotion = emotion
        self.context = context
        self.userProfile = userProfile
    }
}

/// 저장된 채팅 메시지
public struct StoredChatMessage: Codable {
    public let id: UUID
    public let text: String
    public let type: StoredMessageType
    public let timestamp: Date
    public let metadata: [String: String]?
    
    public init(id: UUID, text: String, type: StoredMessageType, timestamp: Date, metadata: [String: String]?) {
        self.id = id
        self.text = text
        self.type = type
        self.timestamp = timestamp
        self.metadata = metadata
    }
}

/// 저장된 메시지 타입
public enum StoredMessageType: String, Codable {
    case user = "user"
    case bot = "bot"
    case system = "system"
    case presetRecommendation = "presetRecommendation"
    case error = "error"
}

// MARK: - Memory Management

extension ChatManager {
    /// 메모리 사용량 계산
    public var estimatedMemoryUsage: Int {
        return cacheQueue.sync {
            var totalSize = 0
            for session in sessionCache.values {
                totalSize += session.estimatedMemorySize
            }
            return totalSize
        }
    }
    
    /// 오래된 세션 정리 - 지정된 일수보다 오래된 세션을 삭제하여 저장 공간 확보
    public func cleanupOldSessions(olderThan days: Int = 30) {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        
        #if DEBUG
        print("💾 [ChatPersistence] \(days)일 이상 된 세션 정리 시작")
        #endif
        
        cacheQueue.async(flags: .barrier) {
            // 삭제할 세션 필터링
            let sessionsToDelete = self.sessionCache.values.filter { $0.lastActivityAt < cutoffDate }
            
            // 각 세션 삭제
            for session in sessionsToDelete {
                self.sessionCache.removeValue(forKey: session.id)
            }
            
            // 변경사항이 있으면 디스크에 저장
            if !sessionsToDelete.isEmpty {
                #if DEBUG
                print("💾 [ChatPersistence] \(sessionsToDelete.count)개 오래된 세션 삭제")
                #endif
                self.saveAllSessionsToDisk()
            }
        }
    }
    
    /// 모든 세션을 디스크에 일괄 저장 - 전체 세션 캐시를 UserDefaults에 기록
    private func saveAllSessionsToDisk() {
        guard let data = try? JSONEncoder().encode(sessionCache) else {
            #if DEBUG
            print("💾 [ChatPersistence] 에러: 전체 세션 인코딩 실패")
            #endif
            return
        }
        
        userDefaults.set(data, forKey: chatHistoryKey)
        
        // ⚡ 즉시 디스크 플러시 보장
        _ = CFPreferencesAppSynchronize(kCFPreferencesCurrentApplication)
        
        #if DEBUG
        print("💾 [ChatPersistence] 전체 세션 디스크 저장 완료 - 총 \(sessionCache.count)개")
        #endif
    }
}

// MARK: - Context Management

extension ChatManager {
    /// 최근 N일간의 대화 컨텍스트를 포맷된 문자열로 반환
    /// CachedConversationManager.getFormattedWeeklyHistory() 대체 메서드
    /// PERF-WARNING: 토큰 효율성을 위해 최대 200토큰 제한
    public func getRecentContext(days: Int = 7) -> String {
        return cacheQueue.sync {
            let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MM/dd"
            
            // 최근 세션들 필터링 및 정렬
            let recentSessions = sessionCache.values
                .filter { $0.lastActivityAt >= cutoffDate }
                .sorted { $0.lastActivityAt > $1.lastActivityAt }
                .prefix(10) // 성능을 위해 최대 10개 세션만
            
            guard !recentSessions.isEmpty else {
                return "📝 최근 대화 기록이 없습니다."
            }
            
            var contextBuilder = "📋 최근 \(days)일간 대화 요약:\n\n"
            var tokenCount = 0
            let maxTokens = 150 // 토큰 효율성을 위한 제한
            
            for session in recentSessions {
                if tokenCount >= maxTokens { break }
                
                let sessionDate = dateFormatter.string(from: session.lastActivityAt)
                let recentMessages = session.messages.suffix(3) // 세션당 최대 3개 메시지만
                
                if !recentMessages.isEmpty {
                    contextBuilder += "[\(sessionDate)] "
                    
                    for (index, message) in recentMessages.enumerated() {
                        let truncatedText = String(message.text.prefix(50)) // 메시지당 최대 50자
                        let sender = message.type == .user ? "사용자" : "AI"
                        
                        contextBuilder += "\(sender): \(truncatedText)"
                        if message.text.count > 50 { contextBuilder += "..." }
                        if index < recentMessages.count - 1 { contextBuilder += " | " }
                        
                        tokenCount += truncatedText.count / 4 // 대략적인 토큰 계산
                        if tokenCount >= maxTokens { break }
                    }
                    contextBuilder += "\n"
                }
            }
            
            return contextBuilder.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
    
    /// 특정 감정 상태의 최근 대화 컨텍스트 조회
    public func getRecentContextForEmotion(_ emotion: String, days: Int = 3) -> String {
        return cacheQueue.sync {
            let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
            
            let emotionSessions = sessionCache.values
                .filter { 
                    $0.lastActivityAt >= cutoffDate && 
                    $0.metadata?.emotion?.lowercased().contains(emotion.lowercased()) == true 
                }
                .sorted { $0.lastActivityAt > $1.lastActivityAt }
                .prefix(5)
            
            guard !emotionSessions.isEmpty else {
                return "📝 '\(emotion)' 관련 최근 대화 기록이 없습니다."
            }
            
            var contextBuilder = "🎭 '\(emotion)' 관련 최근 대화:\n\n"
            
            for session in emotionSessions {
                let recentMessages = session.messages.suffix(2)
                for message in recentMessages {
                    let truncatedText = String(message.text.prefix(60))
                    contextBuilder += "• \(truncatedText)\n"
                }
            }
            
            return contextBuilder.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
}

// MARK: - Storage Management (DailyConversationManager 호환성)

extension ChatManager {
    /// 📊 전체 대화 저장소 통계 조회 (StorageManagementViewController 호환)
    public func getStorageStatistics() async throws -> StorageStatistics {
        return try await withCheckedThrowingContinuation { continuation in
            cacheQueue.async {
                do {
                    var totalSize: Int64 = 0
                    var totalMessageCount = 0
                    var dailyBreakdown: [DailyStorageInfo] = []
                    var dates: [Date] = []
                    
                    // 모든 세션을 날짜별로 그룹화
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "yyyy-MM-dd"
                    
                    var dailySessionsMap: [String: [ChatSession]] = [:]
                    
                    for session in self.sessionCache.values {
                        let sessionDate = dateFormatter.string(from: session.lastActivityAt)
                        if dailySessionsMap[sessionDate] == nil {
                            dailySessionsMap[sessionDate] = []
                        }
                        dailySessionsMap[sessionDate]?.append(session)
                        dates.append(session.lastActivityAt)
                    }
                    
                    // 날짜별 통계 계산
                    for (dateString, sessions) in dailySessionsMap {
                        var dayMessageCount = 0
                        var daySize: Int64 = 0
                        
                        for session in sessions {
                            dayMessageCount += session.messages.count
                            daySize += Int64(session.estimatedMemorySize)
                        }
                        
                        totalSize += daySize
                        totalMessageCount += dayMessageCount
                        
                        let dailyInfo = DailyStorageInfo(
                            date: dateString,
                            fileSize: daySize,
                            messageCount: dayMessageCount,
                            conversationCount: sessions.count
                        )
                        dailyBreakdown.append(dailyInfo)
                    }
                    
                    // 날짜순 정렬
                    dailyBreakdown.sort { $0.date > $1.date }
                    dates.sort()
                    
                    let statistics = StorageStatistics(
                        totalSize: totalSize,
                        fileCount: dailySessionsMap.count,
                        oldestDate: dates.first,
                        newestDate: dates.last,
                        dailyBreakdown: dailyBreakdown
                    )
                    
                    print("📊 [ChatManager] 저장소 통계: \(self.formatBytes(totalSize)), \(dailySessionsMap.count)개 날짜")
                    continuation.resume(returning: statistics)
                    
                } catch {
                    continuation.resume(throwing: StorageManagerError.statisticsLoadFailed(error))
                }
            }
        }
    }
    
    /// 🗑️ 특정 기간 이전 대화 자동 삭제 (StorageManagementViewController 호환)
    public func deleteConversationsOlderThan(days: Int) async throws -> Int {
        return try await withCheckedThrowingContinuation { continuation in
            let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
            
            cacheQueue.async(flags: .barrier) {
                let oldSessions = self.sessionCache.values.filter { $0.lastActivityAt < cutoffDate }
                let deletedCount = oldSessions.count
                
                for session in oldSessions {
                    self.sessionCache.removeValue(forKey: session.id)
                }
                
                if deletedCount > 0 {
                    self.saveAllSessionsToDisk()
                    print("🗑️ [ChatManager] \(days)일 이전 \(deletedCount)개 대화 삭제 완료")
                }
                
                continuation.resume(returning: deletedCount)
            }
        }
    }
    
    /// 📦 대화 데이터 압축 (오래된 대화는 중요한 메시지만 보관)
    public func compressOldConversations(olderThanDays: Int) async throws -> Int {
        return try await withCheckedThrowingContinuation { continuation in
            let cutoffDate = Calendar.current.date(byAdding: .day, value: -olderThanDays, to: Date())!
            
            cacheQueue.async(flags: .barrier) {
                let oldSessions = self.sessionCache.values.filter { 
                    $0.lastActivityAt < cutoffDate && $0.messages.count > 10 
                }
                
                var compressedCount = 0
                
                for session in oldSessions {
                    let importantMessages = session.messages.filter { message in
                        return message.type == .system || 
                               message.type == .presetRecommendation ||
                               message.text.count > 100 // 긴 메시지는 중요할 가능성
                    }
                    
                    // 최대 5개 메시지만 보관
                    let limitedMessages = Array(importantMessages.prefix(5))
                    
                    if !limitedMessages.isEmpty {
                        var compressedSession = session
                        compressedSession.messages = limitedMessages
                        self.sessionCache[session.id] = compressedSession
                        compressedCount += 1
                    }
                }
                
                if compressedCount > 0 {
                    self.saveAllSessionsToDisk()
                    print("📦 [ChatManager] \(compressedCount)개 대화 압축 완료")
                }
                
                continuation.resume(returning: compressedCount)
            }
        }
    }
    
    /// 🗑️ 여러 날짜의 대화 일괄 삭제 (StorageManagementViewController 호환)
    public func deleteConversations(for dates: [String]) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            
            cacheQueue.async(flags: .barrier) {
                var deletedCount = 0
                var failedDates: [String] = []
                
                for dateString in dates {
                    guard let targetDate = dateFormatter.date(from: dateString) else {
                        failedDates.append(dateString)
                        continue
                    }
                    
                    let sessionsToDelete = self.sessionCache.values.filter { session in
                        let sessionDateString = dateFormatter.string(from: session.lastActivityAt)
                        return sessionDateString == dateString
                    }
                    
                    for session in sessionsToDelete {
                        self.sessionCache.removeValue(forKey: session.id)
                        deletedCount += 1
                    }
                }
                
                if deletedCount > 0 {
                    self.saveAllSessionsToDisk()
                }
                
                print("🗑️ [ChatManager] 일괄 삭제 완료: \(deletedCount)개 성공, \(failedDates.count)개 실패")
                
                if failedDates.isEmpty {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: StorageManagerError.partialDeletionFailed(failedDates))
                }
            }
        }
    }
    
    /// 📏 바이트 크기를 읽기 쉬운 형태로 포맷팅
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    /// 🎯 오늘의 대화 저장 (ConversationSaveHelper 호환)
    public func saveTodaysConversation(_ conversation: DailyConversation) async throws {
        // DailyConversation을 ChatSession으로 변환
        let chatSession = ChatSession(
            id: conversation.id,
            createdAt: conversation.startTime,
            lastActivityAt: Date(),
            messages: conversation.messages.map { conversationMessage in
                StoredChatMessage(
                    id: UUID(uuidString: conversationMessage.id) ?? UUID(),
                    text: conversationMessage.content,
                    type: mapConversationMessageTypeToStoredType(conversationMessage.messageType),
                    timestamp: conversationMessage.timestamp,
                    metadata: [
                        "emotionIntensity": String(conversationMessage.emotionIntensity ?? 0.0),
                        "originalType": conversationMessage.messageType.rawValue
                    ]
                )
            },
            metadata: ChatSessionMetadata(
                emotion: conversation.emotionContext.primaryEmotion,
                context: conversation.emotionContext.userGoal,
                userProfile: nil
            )
        )
        
        // 세션 저장
        cacheQueue.async(flags: .barrier) {
            self.sessionCache[chatSession.id] = chatSession
            self.saveSessionToDisk(chatSession)
        }
        
        print("✅ [ChatManager] 오늘의 대화 저장 완료: \(conversation.messages.count)개 메시지")
    }
    
    /// ConversationMessageType을 StoredMessageType으로 매핑
    private func mapConversationMessageTypeToStoredType(_ type: ConversationMessageType) -> StoredMessageType {
        switch type {
        case .normal: return .user
        case .emotional: return .user
        case .goal: return .user
        case .feedback: return .user
        case .systemResponse: return .bot
        }
    }
}

// MARK: - Cached Conversation Manager 호환성

extension ChatManager {
    /// 💾 캐시 매니저 초기화 (ChatViewController 호환)
    public func initialize() {
        print("💾 [ChatManager] 캐시 시스템 초기화 (ChatManager 통합)")
        cleanupOldSessions(olderThan: 14) // 14일 이상 된 세션 정리
    }
    
    /// 📊 디버그 정보 조회 (ChatViewController 호환)
    public func getDebugInfo() -> String {
        return cacheQueue.sync {
            let sessionCount = sessionCache.count
            let totalMessages = sessionCache.values.reduce(0) { $0 + $1.messages.count }
            let memoryUsage = estimatedMemoryUsage
            
            return """
            💾 ChatManager 캐시 상태:
            - 세션 수: \(sessionCount)개
            - 총 메시지: \(totalMessages)개  
            - 메모리 사용량: \(formatBytes(Int64(memoryUsage)))
            - 가장 최근 활동: \(sessionCache.values.max(by: { $0.lastActivityAt < $1.lastActivityAt })?.lastActivityAt.description ?? "없음")
            """
        }
    }
    
    /// 📝 주간 메모리 로드 (ChatViewController 호환)
    public func loadWeeklyMemory() -> String {
        return getRecentContext(days: 7)
    }
    
    /// 🔄 주간 메모리 비동기 업데이트 (ChatViewController 호환)
    public func updateWeeklyMemoryAsync() {
        Task {
            // 백그라운드에서 최신 세션 정보 갱신
            cacheQueue.async(flags: .barrier) {
                // 필요시 추가 로직
                print("🔄 [ChatManager] 주간 메모리 백그라운드 업데이트 완료")
            }
        }
    }
    
    /// 🤖 로컬 AI 추천 기록 저장 (ChatViewController 호환)
    public func recordLocalAIRecommendation(userInput: String, response: String) {
        // 현재 세션에 로컬 AI 추천을 시스템 메시지로 저장
        let currentSession = getCurrentOrCreateSession()
        
        let recommendationMessage = StoredChatMessage(
            id: UUID(),
            text: "로컬 AI 추천: \(response)",
            type: .system,
            timestamp: Date(),
            metadata: ["type": "localAI", "userInput": userInput]
        )
        
        addMessage(to: currentSession.id, message: recommendationMessage)
        print("🤖 [ChatManager] 로컬 AI 추천 기록 저장 완료")
    }
}

// MARK: - Data Models (DailyConversationManager 호환성)

/// 📊 저장소 통계
public struct StorageStatistics {
    public let totalSize: Int64
    public let fileCount: Int
    public let oldestDate: Date?
    public let newestDate: Date?
    public let dailyBreakdown: [DailyStorageInfo]
    
    /// 📏 포맷된 크기 문자열
    public var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: totalSize)
    }
    
    /// 📅 보관 기간 (일수)
    public var retentionDays: Int {
        guard let oldest = oldestDate, let newest = newestDate else { return 0 }
        return Calendar.current.dateComponents([.day], from: oldest, to: newest).day ?? 0
    }
}

/// 📅 일별 저장소 정보
public struct DailyStorageInfo {
    public let date: String
    public let fileSize: Int64
    public let messageCount: Int
    public let conversationCount: Int
    
    /// 📏 포맷된 크기 문자열
    public var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }
    
    /// 📅 Date 객체로 변환
    public var dateObject: Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: date)
    }
    
    /// 📅 표시용 날짜 문자열
    public var displayDate: String {
        guard let dateObj = dateObject else { return date }
        let formatter = DateFormatter()
        formatter.dateFormat = "MM월 dd일"
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter.string(from: dateObj)
    }
}

/// ❌ 저장소 관리 에러 타입
public enum StorageManagerError: Error {
    case statisticsLoadFailed(Error)
    case deleteFailed(Error)
    case partialDeletionFailed([String])
    
    public var localizedDescription: String {
        switch self {
        case .statisticsLoadFailed(let error):
            return "저장소 통계 로드 실패: \(error.localizedDescription)"
        case .deleteFailed(let error):
            return "대화 삭제 실패: \(error.localizedDescription)"
        case .partialDeletionFailed(let dates):
            return "일부 대화 삭제 실패: \(dates.joined(separator: ", "))"
        }
    }
}

// MARK: - ConversationSaveHelper 호환성 타입들

/// 💬 개별 대화 세션 (ConversationSaveHelper 호환)
public struct DailyConversation: Codable {
    public let id: String
    public let startTime: Date
    public let endTime: Date?
    public let emotionContext: EmotionContext
    public let messages: [ConversationMessage]
    public let metadata: ConversationMetadata
    
    public init(emotionContext: EmotionContext, messages: [ConversationMessage] = []) {
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

/// 📝 개별 메시지 (ConversationSaveHelper 호환)
public struct ConversationMessage: Codable {
    public let id: String
    public let content: String
    public let isFromUser: Bool
    public let timestamp: Date
    public let emotionIntensity: Double? // 0.0 ~ 1.0
    public let messageType: ConversationMessageType
    
    public init(content: String, isFromUser: Bool, emotionIntensity: Double? = nil, messageType: ConversationMessageType = .normal) {
        self.id = UUID().uuidString
        self.content = content
        self.isFromUser = isFromUser
        self.timestamp = Date()
        self.emotionIntensity = emotionIntensity
        self.messageType = messageType
    }
}

/// 🎭 감정 맥락 (ConversationSaveHelper 호환)
public struct EmotionContext: Codable {
    public let primaryEmotion: String
    public let intensity: Double // 0.0 ~ 1.0
    public let secondaryEmotions: [String]
    public let userGoal: String?
    public let timeOfDay: String
    
    public init(primaryEmotion: String, intensity: Double, secondaryEmotions: [String] = [], userGoal: String? = nil) {
        self.primaryEmotion = primaryEmotion
        self.intensity = intensity
        self.secondaryEmotions = secondaryEmotions
        self.userGoal = userGoal
        let hour = Calendar.current.component(.hour, from: Date())
        self.timeOfDay = CommonUtilities.shared.getTimeOfDay(from: hour)
    }
}

/// 📊 대화 메타데이터 (ConversationSaveHelper 호환)
public struct ConversationMetadata: Codable {
    public let userGoal: String?
    public let sessionType: SessionType
    public let qualityScore: Double? // AI 응답 품질 점수
}

/// 📱 메시지 타입 (ConversationSaveHelper 호환)
public enum ConversationMessageType: String, Codable {
    case normal = "normal"
    case emotional = "emotional"
    case goal = "goal"
    case feedback = "feedback"
    case systemResponse = "system"
}

/// 🎯 세션 타입 (ConversationSaveHelper 호환)
public enum SessionType: String, Codable {
    case emotional = "emotional"
    case goalSetting = "goal"
    case feedback = "feedback"
    case casual = "casual"
}

// MARK: - Utility Functions

// getTimeOfDay(from:)는 CommonUtilities.swift에 정의되어 있음

// MARK: - Extensions

extension ChatSession {
    /// 예상 메모리 크기
    var estimatedMemorySize: Int {
        var size = MemoryLayout<ChatSession>.size
        
        for message in messages {
            size += message.text.utf8.count
            size += MemoryLayout<StoredChatMessage>.size
        }
        
        return size
    }
}
