import Foundation

// MARK: - 🚀 TLB식 캐시 메시지 구조체
struct CachedMessage: Codable, Identifiable {
    let id: UUID
    let role: ChatRole
    let content: String
    let createdAt: Date
    
    init(id: UUID = UUID(), role: ChatRole, content: String, createdAt: Date = Date()) {
        self.id = id
        self.role = role
        self.content = content
        self.createdAt = createdAt
    }
}

enum ChatRole: String, Codable {
    case user = "user"
    case assistant = "assistant"
    case system = "system"
}

// MARK: - Prompt Caching 기반 1주일 대화 관리자
class CachedConversationManager {
    static let shared = CachedConversationManager()
    private init() {}
    
    // MARK: - 데이터 구조
    struct CachedConversation: Codable {
        let cacheId: String
        let weeklyHistory: String
        let cacheTimestamp: Date
        var totalCachedTokens: Int
        var conversationCount: Int
    }
    
    struct WeeklyMemory: Codable {
    let emotionalPattern: String
    let recurringThemes: [String]
    let userConcerns: [String]
    let keyAdvice: [String]
    let progressNotes: [String]
    let totalMessages: Int
    
    // 🆕 로컬 AI 추천 기록 추가
    let localAIRecommendations: [LocalAIRecommendationRecord]
    let preferredSoundCategories: [String]
    let optimalListeningTimes: [String]
}

// 🆕 로컬 AI 추천 기록 구조체
struct LocalAIRecommendationRecord: Codable {
    let date: Date
    let recommendationType: String // "local" or "ai"
    let presetName: String
    let confidence: Float
    let userContext: String
    let volumes: [Float]
    let versions: [Int]
}
    
    // MARK: - 캐시 관리 (14일 보존 + 3일 raw 시스템)
    var currentCache: CachedConversation?
    private let cacheExpiryTime: TimeInterval = TimeInterval(CacheConst.keepDays * 24 * 60 * 60) // 14일
    private let maxCacheTokens = CacheConst.maxPromptTokens // 4000 토큰 제한
    
    // MARK: - ✅ 메인 캐싱 메서드
    func buildCachedPrompt(
        newMessage: String,
        context: ChatContext? = nil
    ) -> (prompt: String, useCache: Bool, estimatedTokens: Int) {
        
        let recentMessages = getRecentRawMessages()
        
        // 캐시 유효성 검사
        if let cache = currentCache, isCacheValid(cache) {
            // 🗄️ 기존 캐시 사용
            let prompt = buildPromptWithExistingCache(
                recentMessages: recentMessages,
                newMessage: newMessage,
                context: context
            )
            let tokens = TokenTracker.shared.estimateTokens(for: prompt)
            
            #if DEBUG
            print("🗄️ 캐시 재사용: \(cache.conversationCount + 1)번째 대화")
            #endif
            
            return (prompt, true, tokens)
            
        } else {
            // 🆕 새 캐시 생성
            let weeklyHistory = buildWeeklyHistory()
            let prompt = buildPromptWithNewCache(
                weeklyHistory: weeklyHistory,
                recentMessages: recentMessages,
                newMessage: newMessage,
                context: context
            )
            let tokens = TokenTracker.shared.estimateTokens(for: prompt)
            
            // 새 캐시 정보 저장
            let newCacheId = "cache_\(Int(Date().timeIntervalSince1970))"
            currentCache = CachedConversation(
                cacheId: newCacheId,
                weeklyHistory: weeklyHistory,
                cacheTimestamp: Date(),
                totalCachedTokens: TokenTracker.shared.estimateTokens(for: weeklyHistory),
                conversationCount: 0
            )
            
            #if DEBUG
            print("🆕 새 캐시 생성: \(currentCache?.totalCachedTokens ?? 0)토큰")
            #endif
            
            return (prompt, false, tokens)
        }
    }
    
    // MARK: - ✅ 기존 캐시 사용 프롬프트
    private func buildPromptWithExistingCache(
        recentMessages: [String],
        newMessage: String,
        context: ChatContext?
    ) -> String {
        
        let recentContext = recentMessages.suffix(3).joined(separator: "\n")
        
        var prompt = """
        [최근_대화]
        \(recentContext)
        
        [새_메시지]
        \(newMessage)
        
        캐시된 1주일 대화 맥락을 기억하면서 최근 대화와 자연스럽게 연결하여 개인화된 응답을 해주세요.
        """
        
        // 컨텍스트 추가 (일기분석, 패턴분석 등)
        if let ctx = context {
            prompt = addContextToPrompt(prompt, context: ctx)
        }
        
        return prompt
    }
    
    // MARK: - ✅ 새 캐시 생성 프롬프트
    private func buildPromptWithNewCache(
        weeklyHistory: String,
        recentMessages: [String],
        newMessage: String,
        context: ChatContext?
    ) -> String {
        
        let recentContext = recentMessages.suffix(3).joined(separator: "\n")
        
        var prompt = """
        [1주일_대화_히스토리_캐시_START]
        \(weeklyHistory)
        [1주일_대화_히스토리_캐시_END]
        
        [최근_대화]
        \(recentContext)
        
        [새_메시지]
        \(newMessage)
        
        위 1주일간의 대화 맥락을 기억하면서 개인화되고 연속적인 대화를 이어가주세요.
        """
        
        // 컨텍스트 추가
        if let ctx = context {
            prompt = addContextToPrompt(prompt, context: ctx)
        }
        
        return prompt
    }
    
    // MARK: - ✅ TLB식 히스토리 구성 (3일 raw + 14일 요약)
    private func buildWeeklyHistory() -> String {
        let weeklyMemory = loadWeeklyMemory()
        let recentMessages = getRecentRawMessages() // 최근 3일 원본
        let summaryCount = getOlderMessageCount() // 3일 이전 메시지 수
        
        var historyBuilder = """
        === 사용자 프로필 (14일 종합 분석) ===
        
        🎭 감정 패턴: \(weeklyMemory.emotionalPattern)
        🎯 관심 주제: \(weeklyMemory.recurringThemes.prefix(4).joined(separator: ", "))
        💭 주요 고민: \(weeklyMemory.userConcerns.prefix(3).joined(separator: "; "))
        💡 효과적 조언: \(weeklyMemory.keyAdvice.prefix(3).joined(separator: "; "))
        📈 변화 추이: \(weeklyMemory.progressNotes.joined(separator: "; "))
        
        """
        
        // 이전 대화 요약 (토큰 0 방식)
        if summaryCount > 0 {
            historyBuilder += """
            === 이전 대화 요약 ===
            …지난 \(summaryCount)개의 메시지 기록이 있습니다 (3일 이전)…
            
            """
        }
        
        // 최근 3일 대화 (원본)
        if !recentMessages.isEmpty {
            historyBuilder += """
            === 최근 3일 대화 원본 ===
            \(recentMessages.joined(separator: "\n"))
            
            """
        }
        
        historyBuilder += """
        === 히스토리 종료 ===
        
        ⚠️ 중요: 위 정보를 바탕으로 연속적이고 개인화된 대화를 이어가주세요.
        """
        
        return historyBuilder
    }
    
    // MARK: - 🚀 TLB식 메시지 저장 및 로드
    
    /// 메시지 추가 (14일 보존)
    func append(_ message: CachedMessage) throws {
        var allMessages = try loadAllMessages()
        allMessages.append(message)
        
        // 14일 이전 메시지 제거
        let cutOff = Calendar.current.date(byAdding: .day, value: -CacheConst.keepDays, to: Date())!
        allMessages.removeAll { $0.createdAt < cutOff }
        
        try saveAllMessages(allMessages)
    }
    
    /// 최근 14일 메시지 반환
    func recentHistory() throws -> [CachedMessage] {
        let cutOff = Calendar.current.date(byAdding: .day, value: -CacheConst.keepDays, to: Date())!
        let allMessages = try loadAllMessages()
        return allMessages.filter { $0.createdAt >= cutOff }
                          .sorted { $0.createdAt < $1.createdAt }
    }
    
    /// 모든 메시지 로드
    private func loadAllMessages() throws -> [CachedMessage] {
        guard let data = UserDefaults.standard.data(forKey: "cached_messages"),
              let messages = try? JSONDecoder().decode([CachedMessage].self, from: data) else {
            return []
        }
        return messages
    }
    
    /// 모든 메시지 저장
    private func saveAllMessages(_ messages: [CachedMessage]) throws {
        let data = try JSONEncoder().encode(messages)
        UserDefaults.standard.set(data, forKey: "cached_messages")
    }
    
    // MARK: - ✅ TLB 시스템 메서드들
    
    /// 최근 3일 원본 메시지 로드
    func getRecentRawMessages() -> [String] {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -CacheConst.recentDaysRaw, to: Date()) ?? Date()
        
        let allKeys = UserDefaults.standard.dictionaryRepresentation().keys
        let messageKeys = allKeys.filter { $0.hasPrefix("chat_message_") }
            .compactMap { key -> (String, Date)? in
                guard let timestamp = extractTimestamp(from: key) else { return nil }
                return (key, timestamp)
            }
            .filter { $0.1 >= cutoffDate }
            .sorted { $0.1 < $1.1 } // 시간순
        
        return messageKeys.compactMap { key, _ in
            guard let messageData = UserDefaults.standard.data(forKey: key),
                  let message = try? JSONDecoder().decode(ChatMessage.self, from: messageData) else { return nil }
            return message.text
        }
    }
    
    /// 3일 이전 메시지 개수
    func getOlderMessageCount() -> Int {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -CacheConst.recentDaysRaw, to: Date()) ?? Date()
        
        let allKeys = UserDefaults.standard.dictionaryRepresentation().keys
        return allKeys.filter { key in
            guard key.hasPrefix("chat_message_"),
                  let timestamp = extractTimestamp(from: key) else { return false }
            return timestamp < cutoffDate
        }.count
    }
    
    /// 키에서 타임스탬프 추출
    private func extractTimestamp(from key: String) -> Date? {
        let components = key.components(separatedBy: "_")
        guard components.count >= 3,
              let timestamp = Double(components[2]) else { return nil }
        return Date(timeIntervalSince1970: timestamp)
    }
    
    /// 초기화 메서드
    func initialize() {
        // 필요한 경우 초기화 로직
        #if DEBUG
        print("🗄️ CachedConversationManager 초기화")
        #endif
    }
    
    /// 디버그 정보
    func getDebugInfo() -> String {
        let cacheInfo = currentCache != nil ? "활성" : "없음"
        let recentCount = getRecentRawMessages().count
        let olderCount = getOlderMessageCount()
        
        return """
        📊 TLB 캐시 시스템 상태:
        - 캐시: \(cacheInfo)
        - 최근 3일: \(recentCount)개 메시지
        - 이전 기록: \(olderCount)개 메시지
        """
    }
    
    // MARK: - TLB식 메시지 분리 헬퍼
    
    /// 메시지가 최근 3일 이내인지 확인
    private func isMessageRecent(_ message: String, cutOff: Date) -> Bool {
        // 메시지 포맷에서 날짜 추출: "M/d: ..." 형태
        let components = message.components(separatedBy: ":")
        guard let dateStr = components.first?.trimmingCharacters(in: .whitespaces) else { return true }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        formatter.calendar = Calendar.current
        
        if let messageDate = formatter.date(from: dateStr) {
            // 올해 날짜로 보정
            let year = Calendar.current.component(.year, from: Date())
            let correctedDate = Calendar.current.date(bySetting: .year, value: year, of: messageDate) ?? messageDate
            return correctedDate >= cutOff
        }
        
        return true // 파싱 실패 시 최근 메시지로 간주
    }
    
    // MARK: - Public Access to Weekly History
    public func getFormattedWeeklyHistory() -> String {
        return buildWeeklyHistory()
    }
    
    // MARK: - 🔄 대화 맥락 강화 시스템
    
    /// 현재 세션의 감정 기록 (대화 맥락 유지용)
    func recordSessionEmotion(_ emotion: String) {
        var emotionFlow = UserDefaults.standard.array(forKey: "session_emotion_flow") as? [String] ?? []
        
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "ko_KR")
        let timestamp = formatter.string(from: Date())
        
        emotionFlow.append("\(emotion)(\(timestamp))")
        
        // 최근 10개만 유지
        if emotionFlow.count > 10 {
            emotionFlow = Array(emotionFlow.suffix(10))
        }
        
        UserDefaults.standard.set(emotionFlow, forKey: "session_emotion_flow")
        
        print("📊 [Session] 감정 기록: \(emotion) at \(timestamp)")
    }
    
    /// 최근 대화 메시지 수집 강화 (맥락 연속성 보장)
    private func getRecentMessages() -> [String] {
        var messages: [String] = []
        
        // 1. 현재 세션의 감정 흐름
        let emotionFlow = UserDefaults.standard.array(forKey: "session_emotion_flow") as? [String] ?? []
        if !emotionFlow.isEmpty {
            let flow = emotionFlow.suffix(3).joined(separator: " → ")
            messages.append("감정 흐름: \(flow)")
        }
        
        // 2. 최근 대화 요약
        let recentSummary = getLastConversationSummary()
        if !recentSummary.isEmpty {
            messages.append("이전 대화: \(recentSummary)")
        }
        
        // 3. 최근 추천 히스토리
        let recentRecommendations = getRecentRecommendationContext()
        if !recentRecommendations.isEmpty {
            messages.append("최근 추천: \(recentRecommendations)")
        }
        
        // 4. 현재 시간대 컨텍스트
        let hour = Calendar.current.component(.hour, from: Date())
        let timeContext = getTimeContextMessage(hour: hour)
        messages.append("시간 컨텍스트: \(timeContext)")
        
        return messages
    }
    
    /// 마지막 대화 요약 가져오기
    private func getLastConversationSummary() -> String {
        let summaries = loadRecentDailySummaries()
        return summaries.last ?? ""
    }
    
    /// 최근 추천 맥락 가져오기
    private func getRecentRecommendationContext() -> String {
        let records = loadLocalAIRecommendations().suffix(3)
        return records.map { "[\($0.presetName)]" }.joined(separator: ", ")
    }
    
    /// 시간대별 컨텍스트 메시지
    private func getTimeContextMessage(hour: Int) -> String {
        switch hour {
        case 5..<9: return "아침 시간대"
        case 9..<12: return "오전 시간대"
        case 12..<14: return "점심 시간대"
        case 14..<18: return "오후 시간대"
        case 18..<21: return "저녁 시간대"
        case 21..<24: return "밤 시간대"
        default: return "새벽 시간대"
        }
    }
    
    /// 세션 시작 시 감정 흐름 초기화
    func resetSessionEmotionFlow() {
        UserDefaults.standard.removeObject(forKey: "session_emotion_flow")
        print("🔄 [Session] 감정 흐름 초기화")
    }
    
    // MARK: - ✅ 컨텍스트 추가 (기존 기능 유지)
    private func addContextToPrompt(_ prompt: String, context: ChatContext) -> String {
        switch context {
        case .diaryAnalysis(let diary):
            return prompt + """
            
            [일기_분석_모드]
            감정: \(diary.emotion)
            날짜: \(diary.formattedDate)
            내용: \(String(diary.content.prefix(200)))...
            
            1주일 대화 맥락과 이 일기를 연결하여 깊이 있는 분석을 해주세요.
            """
            
        case .patternAnalysis(let data):
            return prompt + """
            
            [감정_패턴_분석_모드]
            데이터: \(String(data.prefix(200)))...
            
            1주일 대화 패턴과 연결하여 종합적인 감정 분석을 해주세요.
            """
            
        case .emotionChat(let emotion):
            return prompt + """
            
            [감정_대화_모드]
            현재 감정: \(emotion)
            
            1주일간의 감정 패턴을 참고하여 맞춤형 위로와 조언을 해주세요.
            """
        }
    }
    
    // MARK: - 🆕 로컬 AI 추천 기록 관리
    
    /// 로컬 AI 추천 기록 저장
    func recordLocalAIRecommendation(
        type: String,
        presetName: String,
        confidence: Float,
        context: String,
        volumes: [Float],
        versions: [Int]
    ) {
        let record = LocalAIRecommendationRecord(
            date: Date(),
            recommendationType: type,
            presetName: presetName,
            confidence: confidence,
            userContext: context,
            volumes: volumes,
            versions: versions
        )
        
        // 기존 기록 로드
        var records = loadLocalAIRecommendations()
        records.append(record)
        
        // 최근 50개만 유지
        if records.count > 50 {
            records = Array(records.suffix(50))
        }
        
        // 저장
        saveLocalAIRecommendations(records)
        
        #if DEBUG
        print("로컬 AI 추천 기록 저장: \(presetName) (신뢰도: \(confidence))")
        #endif
    }
    
    /// 로컬 AI 추천 기록 로드
    private func loadLocalAIRecommendations() -> [LocalAIRecommendationRecord] {
        guard let data = UserDefaults.standard.data(forKey: "localAIRecommendations"),
              let records = try? JSONDecoder().decode([LocalAIRecommendationRecord].self, from: data) else {
            return []
        }
        return records
    }
    
    /// 로컬 AI 추천 기록 저장
    private func saveLocalAIRecommendations(_ records: [LocalAIRecommendationRecord]) {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(records) {
            UserDefaults.standard.set(data, forKey: "localAIRecommendations")
        }
    }
    
    // MARK: - ✅ 캐시 관리
    func updateCacheAfterResponse() {
        if let cache = currentCache {
            // 대화 횟수 증가 및 타이머 리셋
            currentCache = CachedConversation(
                cacheId: cache.cacheId,
                weeklyHistory: cache.weeklyHistory,
                cacheTimestamp: Date(), // TTL 리셋
                totalCachedTokens: cache.totalCachedTokens,
                conversationCount: cache.conversationCount + 1
            )
            
            safeSaveCacheToStorage()
        }
    }
    
    func invalidateCache() {
        currentCache = nil
        UserDefaults.standard.removeObject(forKey: "currentConversationCache")
        
        #if DEBUG
        print("🗑️ 캐시 무효화 완료")
        #endif
    }
    
    private func isCacheValid(_ cache: CachedConversation) -> Bool {
            let timeSinceCache = Date().timeIntervalSince(cache.cacheTimestamp)
            let isTimeValid = timeSinceCache < cacheExpiryTime
            let isTokenValid = cache.totalCachedTokens < maxCacheTokens
            
            #if DEBUG
            if !isTimeValid {
                print("⏰ 캐시 시간 만료: \(Int(timeSinceCache))초 경과")
            }
            if !isTokenValid {
                print("📊 캐시 토큰 초과: \(cache.totalCachedTokens)/\(maxCacheTokens)")
            }
            #endif
            
            return isTimeValid && isTokenValid
        }
    
    // MARK: - ✅ 데이터 관리 (수정된 부분) - 중복 제거됨
    
    // MARK: - ✅ WeeklyMemory 로드 (단일 정의)
    func loadWeeklyMemory() -> WeeklyMemory {
        if let data = UserDefaults.standard.data(forKey: "weeklyMemory"),
           let memory = try? JSONDecoder().decode(WeeklyMemory.self, from: data) {
            return memory
        }
        
        // 기본값 반환
        return WeeklyMemory(
            emotionalPattern: "새로운 대화 시작",
            recurringThemes: [],
            userConcerns: [],
            keyAdvice: [],
            progressNotes: [],
            totalMessages: 0,
            localAIRecommendations: [],
            preferredSoundCategories: [],
            optimalListeningTimes: []
        )
    }
    
    private func loadRecentDailySummaries() -> [String] {
            var summaries: [String] = []
            let calendar = Calendar.current
            
            for i in 1...3 {
                let date = calendar.date(byAdding: .day, value: -i, to: Date())!
                let dailyMessages = UserDefaults.standard.loadDailyMessages(for: date)
                
                if !dailyMessages.isEmpty {
                    let summary = createDailySummary(messages: dailyMessages, date: date)
                    summaries.append(summary)
                }
            }
            
            return summaries
        }
    
    private func createDailySummary(messages: [ChatMessage], date: Date) -> String {
        let userMessages = messages.compactMap { message in
            switch message.type {
            case .user:
                return message.text
            default:
                // ✅ 다른 케이스들은 사용자 메시지가 아니므로 nil 반환
                return nil
            }
        }
        
        let botMessages = messages.compactMap { message in
            switch message.type {
            case .bot, .aiResponse, .presetRecommendation, .recommendationSelector:
                return message.text
            default:
                // ✅ 사용자 메시지와 옵션 메시지, 로딩 메시지는 bot 메시지가 아니므로 nil 반환
                return nil
            }
        }
        
        let emotions = extractEmotionsFromMessages(userMessages)
        let themes = extractThemesFromMessages(userMessages)
        
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        let dateStr = formatter.string(from: date)
        
        return "\(dateStr): \(emotions), 주제[\(themes.joined(separator: ", "))] (\(messages.count/2)회 대화)"
    }
    
    // MARK: - ✅ 주간 메모리 업데이트 (백그라운드)
    func updateWeeklyMemoryAsync() {
        DispatchQueue.global(qos: .background).async {
            let weeklyMessages = self.loadWeeklyMessages()
            guard weeklyMessages.count > 20 else { return } // 충분한 대화가 있을 때만
            
            let newMemory = self.analyzeWeeklyMessages(weeklyMessages)
            
            DispatchQueue.main.async {
                self.safeSaveWeeklyMemory(newMemory)
                
                #if DEBUG
                print("📊 주간 메모리 업데이트: \(newMemory.totalMessages)개 메시지 분석")
                #endif
            }
        }
    }
    
    private func analyzeWeeklyMessages(_ messages: [ChatMessage]) -> WeeklyMemory {
        let userTexts = messages.compactMap { message in
            switch message.type {
            case .user:
                return message.text
            default:
                // ✅ 사용자 텍스트가 아닌 경우 nil 반환
                return nil
            }
        }
        
        let aiTexts = messages.compactMap { message in
            switch message.type {
            case .bot, .aiResponse, .presetRecommendation, .recommendationSelector:
                return message.text
            default:
                // ✅ AI 텍스트가 아닌 경우 nil 반환
                return nil
            }
        }
        
        return WeeklyMemory(
            emotionalPattern: analyzeEmotionalPattern(userTexts),
            recurringThemes: findRecurringThemes(userTexts),
            userConcerns: extractUserConcerns(userTexts),
            keyAdvice: extractKeyAdvice(aiTexts),
            progressNotes: analyzeProgress(userTexts),
            totalMessages: messages.count,
            localAIRecommendations: [],
            preferredSoundCategories: [],
            optimalListeningTimes: []
        )
    }
    
    // MARK: - ✅ 분석 메서드들
    private func analyzeEmotionalPattern(_ texts: [String]) -> String {
        let allText = texts.joined(separator: " ")
        let positiveCount = countWords(in: allText, words: ["기쁘", "행복", "좋", "만족", "즐거", "웃"])
        let negativeCount = countWords(in: allText, words: ["힘들", "슬프", "우울", "화", "스트레스", "걱정"])
        _ = countWords(in: allText, words: ["그냥", "보통", "괜찮", "평범"])
        
        if positiveCount > negativeCount + 2 {
            return "전반적으로 긍정적이고 밝은 성향"
        } else if negativeCount > positiveCount + 2 {
            return "스트레스나 고민이 있어 관심과 지원이 필요한 상태"
        } else {
            return "감정적으로 균형잡힌 안정적인 상태"
        }
    }
    
    private func findRecurringThemes(_ texts: [String]) -> [String] {
        let themes = ["일", "직장", "가족", "연애", "친구", "건강", "운동", "스트레스", "공부", "취미", "미래", "돈", "여행"]
        let allText = texts.joined(separator: " ")
        
        var themeCounts: [String: Int] = [:]
        for theme in themes {
            themeCounts[theme] = countWords(in: allText, words: [theme])
        }
        
        return themeCounts.filter { $0.value >= 2 }
                          .sorted { $0.value > $1.value }
                          .prefix(4)
                          .map { $0.key }
    }
    
    private func extractUserConcerns(_ texts: [String]) -> [String] {
        var concerns: [String] = []
        let concernWords = ["고민", "걱정", "문제", "어려움", "힘들", "스트레스"]
        
        for text in texts {
            for word in concernWords {
                if text.contains(word) {
                    let sentences = text.components(separatedBy: ".")
                    for sentence in sentences {
                        if sentence.contains(word) && sentence.count > 5 {
                            concerns.append(String(sentence.trimmingCharacters(in: .whitespaces).prefix(40)))
                            break
                        }
                    }
                    break
                }
            }
        }
        
        return Array(Set(concerns).prefix(3))
    }
    
    private func extractKeyAdvice(_ texts: [String]) -> [String] {
        var advice: [String] = []
        let adviceWords = ["추천", "제안", "해보", "시도", "방법", "도움"]
        
        for text in texts {
            let sentences = text.components(separatedBy: ".")
            for sentence in sentences {
                if adviceWords.contains(where: { sentence.contains($0) }) && sentence.count > 10 {
                    advice.append(String(sentence.trimmingCharacters(in: .whitespaces).prefix(50)))
                }
            }
        }
        
        return Array(Set(advice).prefix(3))
    }
    
    private func analyzeProgress(_ texts: [String]) -> [String] {
        let recentTexts = Array(texts.suffix(10)).joined(separator: " ")
        let olderTexts = Array(texts.prefix(max(0, texts.count - 10))).joined(separator: " ")
        
        let recentPositive = countWords(in: recentTexts, words: ["좋아졌", "개선", "나아졌", "발전"])
        let olderPositive = countWords(in: olderTexts, words: ["좋아졌", "개선", "나아졌", "발전"])
        
        if recentPositive > olderPositive {
            return ["감정 상태나 상황이 점진적으로 개선되는 중"]
        } else {
            return ["지속적인 관심과 맞춤형 지원이 필요한 상황"]
        }
    }
    
    // MARK: - ✅ 보조 메서드들
    private func countWords(in text: String, words: [String]) -> Int {
        return words.reduce(0) { count, word in
            count + text.components(separatedBy: word).count - 1
        }
    }
    
    private func extractEmotionsFromMessages(_ messages: [String]) -> String {
        let allText = messages.joined(separator: " ")
        if countWords(in: allText, words: ["기쁘", "행복"]) > 0 { return "긍정적" }
        if countWords(in: allText, words: ["힘들", "스트레스"]) > 0 { return "어려움" }
        return "평온"
    }
    
    private func extractThemesFromMessages(_ messages: [String]) -> [String] {
        let themes = ["일", "가족", "친구", "건강", "스트레스"]
        let allText = messages.joined(separator: " ")
        return themes.filter { allText.contains($0) }.prefix(2).map { $0 }
    }
    
    // MARK: - 🆕 로컬 AI 패턴 분석
    
    private func analyzeLocalAIPatterns(_ records: [LocalAIRecommendationRecord]) -> String {
        guard !records.isEmpty else {
            return "아직 로컬 AI 추천 기록이 없습니다."
        }
        
        // 가장 많이 추천된 프리셋
        let presetCounts = Dictionary(grouping: records, by: { $0.presetName })
            .mapValues { $0.count }
            .sorted { $0.value > $1.value }
        
        // 평균 신뢰도
        let averageConfidence = records.reduce(0) { $0 + $1.confidence } / Float(records.count)
        
        // 추천 타입 분석
        let typeCounts = Dictionary(grouping: records, by: { $0.recommendationType })
            .mapValues { $0.count }
        
        // 시간대 패턴 분석
        let timePatterns = analyzeTimePatterns(records)
        
        var analysis = """
        📊 선호 프리셋: \(presetCounts.prefix(3).map { "\($0.key)(\($0.value)회)" }.joined(separator: ", "))
        🎯 평균 신뢰도: \(String(format: "%.1f", averageConfidence * 100))%
        🤖 추천 타입: \(typeCounts.map { "\($0.key): \($0.value)회" }.joined(separator: ", "))
        ⏰ 활용 시간대: \(timePatterns)
        """
        
        // 최근 추천 컨텍스트
        if let lastRecord = records.last {
            let formatter = DateFormatter()
            formatter.dateFormat = "M/d HH:mm"
            analysis += "\n🕐 마지막 추천: \(formatter.string(from: lastRecord.date)) - \(lastRecord.presetName)"
        }
        
        return analysis
    }
    
    private func analyzeTimePatterns(_ records: [LocalAIRecommendationRecord]) -> String {
        let hourCounts = Dictionary(grouping: records) { record in
            Calendar.current.component(.hour, from: record.date)
        }.mapValues { $0.count }
        
        let sortedHours = hourCounts.sorted { $0.value > $1.value }
        
        if let topHour = sortedHours.first {
            let timeRange = getTimeRange(for: topHour.key)
            return "\(timeRange) (\(topHour.value)회)"
        } else {
            return "다양한 시간대"
        }
    }
    
    private func getTimeRange(for hour: Int) -> String {
        switch hour {
        case 6..<12: return "오전"
        case 12..<18: return "오후"
        case 18..<22: return "저녁"
        case 22...23, 0..<6: return "밤/새벽"
        default: return "기타"
        }
    }
    
    // MARK: - ✅ 저장/로드
    func safeSaveCacheToStorage() {
            guard let cache = currentCache else { return }
            
            // TTL 포함한 캐시 저장
            if UserDefaults.standard.setCacheData(cache, forKey: "currentConversationCache", ttl: cacheExpiryTime) {
                #if DEBUG
                print("✅ 캐시 저장 성공 (TTL: \(Int(cacheExpiryTime))초)")
                #endif
            } else {
                #if DEBUG
                print("❌ 캐시 저장 실패")
                #endif
            }
        }
    
    private func safeLoadCacheFromStorage() {
            currentCache = UserDefaults.standard.getCacheData(CachedConversation.self, forKey: "currentConversationCache")
            
            #if DEBUG
            if let cache = currentCache {
                let timeLeft = cacheExpiryTime - Date().timeIntervalSince(cache.cacheTimestamp)
                print("✅ 캐시 로드 성공 (남은시간: \(Int(timeLeft))초)")
            } else {
                print("ℹ️ 저장된 캐시 없음")
            }
            #endif
        }
        
        // ✅ 주간 메모리 저장 메서드 개선
        func safeSaveWeeklyMemory(_ memory: WeeklyMemory) {
            if UserDefaults.standard.safeSetObject(memory, forKey: "weeklyMemory") {
                #if DEBUG
                print("✅ 주간 메모리 저장 성공: \(memory.totalMessages)개 메시지")
                #endif
            } else {
                #if DEBUG
                print("❌ 주간 메모리 저장 실패")
                #endif
            }
        }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    
    private func loadDailyMessages(for dateKey: String) -> [ChatMessage] {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            
            guard let date = formatter.date(from: dateKey) else {
                return []
            }
            
            return UserDefaults.standard.loadDailyMessages(for: date)
        }
    
    private func loadTodayMessages() -> [ChatMessage] {
            return UserDefaults.standard.loadDailyMessages(for: Date())
        }
        
        // ✅ loadWeeklyMessages 메서드 수정 (UserDefaults 확장 사용)
        private func loadWeeklyMessages() -> [ChatMessage] {
            return UserDefaults.standard.loadWeeklyMessages()
        }
    

    
    // MARK: - ✅ 대화 추가
    func addConversation(messages: [ChatMessage], context: String = "일반 대화") {
        #if DEBUG
        print("💬 [대화 추가] 메시지 \(messages.count)개, 컨텍스트: \(context)")
        #endif
        
        // 새 대화 생성
        let conversationId = UUID().uuidString
        let timestamp = Date()
        
        // 캐시 업데이트 또는 생성
        if var cache = currentCache {
            cache.conversationCount += 1
            cache.totalCachedTokens += messages.reduce(0) { $0 + $1.text.count }
            currentCache = cache
        } else {
            // 새 캐시 생성
            let weeklyHistory = """
            컨텍스트: \(context)
            대화 내용:
            \(messages.map { "[\(typeName(for: $0.type))] \($0.text)" }.joined(separator: "\n"))
            """
            
            currentCache = CachedConversation(
                cacheId: conversationId,
                weeklyHistory: weeklyHistory,
                cacheTimestamp: timestamp,
                totalCachedTokens: messages.reduce(0) { $0 + $1.text.count },
                conversationCount: 1
            )
        }
        
        // 메시지 저장
        UserDefaults.standard.saveDailyMessages(messages, for: timestamp)
        
        // 캐시 저장
        safeSaveCacheToStorage()
        
        #if DEBUG
        print("✅ [대화 추가 완료] 총 \(currentCache?.conversationCount ?? 0)회 대화")
        #endif
    }
    
    // MARK: - ✅ 테스트 대화 생성
    func createTestConversations() {
        #if DEBUG
        print("🧪 [테스트 대화 생성] 시작...")
        #endif
        
        let testConversations: [(messages: [ChatMessage], context: String)] = [
            // 1. 우울감 상담 대화
            (messages: [
                ChatMessage(type: .user, text: "요즘 너무 우울해서 잠이 안 와요"),
                ChatMessage(type: .bot, text: "우울감으로 인한 수면 장애는 매우 흔한 증상입니다. 차분한 피아노 음악이나 자연의 소리를 들어보시는 것은 어떨까요?"),
                ChatMessage(type: .user, text: "비가 오는 소리가 좋을 것 같아요")
            ], context: "우울감 수면상담"),
            
            // 2. 불면증 대화
            (messages: [
                ChatMessage(type: .user, text: "밤에 계속 생각이 많아서 잠들 수가 없어요"),
                ChatMessage(type: .bot, text: "머릿속 잡념을 줄이는 데는 백색소음이나 명상음악이 도움이 됩니다. 호흡에 집중할 수 있는 음향을 추천드려요."),
                ChatMessage(type: .user, text: "명상음악으로 해볼게요")
            ], context: "불면증 상담"),
            
            // 3. 스트레스 해소 대화
            (messages: [
                ChatMessage(type: .user, text: "회사 스트레스 때문에 잠이 안 와요"),
                ChatMessage(type: .bot, text: "직장 스트레스로 인한 수면 장애는 심각합니다. 스트레스 해소에 도움이 되는 파도소리나 새소리를 들어보세요."),
                ChatMessage(type: .user, text: "새소리가 좋네요. 더 자주 들어볼게요")
            ], context: "스트레스 관리")
        ]
        
        // 테스트 대화들 추가
        for (messages, context) in testConversations {
            addConversation(messages: messages, context: context)
        }
        
        #if DEBUG
        print("✅ [테스트 대화 생성 완료] 3개 대화 추가됨")
        print("📊 현재 캐시 상태: \(currentCache?.conversationCount ?? 0)회 대화")
        #endif
    }
    
    // MARK: - ✅ 캐시 상태 출력
    func printCacheStatus() {
        #if DEBUG
        let debugInfo = getDebugInfo()
        print("=== 💾 캐시 상태 보고서 ===")
        print(debugInfo)
        print("===========================")
        #endif
    }
    
    // MARK: - ✅ 헬퍼 함수
    private func typeName(for type: ChatMessageType) -> String {
        switch type {
        case .user:
            return "사용자"
        case .bot:
            return "AI"
        default:
            return "시스템"
        }
    }
    

}

// MARK: - ✅ 컨텍스트 열거형
enum ChatContext {
    case diaryAnalysis(DiaryContext)
    case patternAnalysis(String)
    case emotionChat(String)
}
