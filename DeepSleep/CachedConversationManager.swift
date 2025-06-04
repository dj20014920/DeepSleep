import Foundation

// MARK: - Prompt Caching 기반 1주일 대화 관리자
class CachedConversationManager {
    static let shared = CachedConversationManager()
    private init() {}
    
    // MARK: - 데이터 구조
    struct CachedConversation: Codable {
        let cacheId: String
        let weeklyHistory: String
        let cacheTimestamp: Date
        let totalCachedTokens: Int
        let conversationCount: Int
    }
    
    struct WeeklyMemory: Codable {
        let emotionalPattern: String
        let recurringThemes: [String]
        let userConcerns: [String]
        let keyAdvice: [String]
        let progressNotes: [String]
        let totalMessages: Int
    }
    
    // MARK: - 캐시 관리 (✅ internal로 변경)
    var currentCache: CachedConversation?  // ✅ private 제거. (실제로는 internal 접근 수준이 적절할 수 있습니다.)
    private let cacheExpiryTime: TimeInterval = 300 // 5분 (Claude 캐시 TTL)
    private let maxCacheTokens = 3000 // 캐시 최대 토큰 제한
    
    // MARK: - ✅ 메인 캐싱 메서드
    func buildCachedPrompt(
        newMessage: String,
        context: ChatContext? = nil
    ) -> (prompt: String, useCache: Bool, estimatedTokens: Int) {
        
        let recentMessages = getRecentMessages()
        
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
    
    // MARK: - ✅ 1주일 히스토리 구성
    private func buildWeeklyHistory() -> String {
        let weeklyMemory = loadWeeklyMemory()
        let recentSummaries = loadRecentDailySummaries()
        
        return """
        === 사용자 프로필 (1주일 분석) ===
        
        🎭 감정 패턴: \(weeklyMemory.emotionalPattern)
        🎯 관심 주제: \(weeklyMemory.recurringThemes.prefix(4).joined(separator: ", "))
        💭 주요 고민: \(weeklyMemory.userConcerns.prefix(3).joined(separator: "; "))
        💡 효과적 조언: \(weeklyMemory.keyAdvice.prefix(3).joined(separator: "; "))
        📈 변화 추이: \(weeklyMemory.progressNotes.joined(separator: "; "))
        
        === 최근 3일 요약 ===
        \(recentSummaries.joined(separator: "\n"))
        
        === 대화 기반 정보 종료 ===
        """
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
    
    // MARK: - ✅ 데이터 관리 (수정된 부분)
    private func getRecentMessages() -> [String] {
        // UserDefaults 확장 메서드 사용
        let todayMessages = UserDefaults.standard.loadDailyMessages(for: Date())
        
        // ArraySlice를 Array로 변환하여 compactMap 호출
        return Array(todayMessages.suffix(5)).compactMap { (message: ChatMessage) -> String? in
            switch message {
            case .user(let text):
                return "사용자: \(text)"
            case .bot(let text):
                return "AI: \(text)"
            case .presetRecommendation(let presetName, let msg, _):
                return "AI (프리셋 추천): \(msg)"
            case .postPresetOptions(let presetName, _, _, _, _):
                return "시스템 (프리셋 옵션): \(presetName)"
            }
        }
    }
    
    // MARK: - ✅ 주간 히스토리 공개 메서드 (새로 추가)
    public func getFormattedWeeklyHistory() -> String {
        // 내부적으로 buildWeeklyHistory()를 호출하여 결과를 반환합니다.
        // 이 메서드는 AddEditTodoViewController에서 AI 조언 컨텍스트를 가져오기 위해 사용됩니다.
        let history = buildWeeklyHistory()
        if history.isEmpty {
            // 만약 buildWeeklyHistory가 비어있는 문자열을 반환할 가능성이 있다면,
            // 여기서 기본 메시지나 빈 문자열에 대한 처리를 할 수 있습니다.
            // 예를 들어, "사용자 활동 기록이 아직 충분하지 않습니다." 와 같은 메시지를 반환할 수 있습니다.
            print("DEBUG: buildWeeklyHistory() returned an empty string.")
            return ""
        }
        return history
    }
    
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
            totalMessages: 0
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
            switch message {
            case .user(let text):
                return text
            case .bot, .presetRecommendation, .postPresetOptions:
                // ✅ 다른 케이스들은 사용자 메시지가 아니므로 nil 반환
                return nil
            }
        }
        
        let botMessages = messages.compactMap { message in
            switch message {
            case .bot(let text):
                return text
            case .presetRecommendation(_, let msg, _):
                return msg
            case .user, .postPresetOptions:
                // ✅ 사용자 메시지와 옵션 메시지는 bot 메시지가 아니므로 nil 반환
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
            switch message {
            case .user(let text):
                return text
            case .bot, .presetRecommendation, .postPresetOptions:
                // ✅ 사용자 텍스트가 아닌 경우 nil 반환
                return nil
            }
        }
        
        let aiTexts = messages.compactMap { message in
            switch message {
            case .bot(let text):
                return text
            case .presetRecommendation(_, let msg, _):
                return msg
            case .user, .postPresetOptions:
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
            totalMessages: messages.count
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
    
    // MARK: - ✅ 초기화
    func initialize() {
            // 만료된 캐시 정리
            UserDefaults.standard.cleanExpiredCaches()
            
            // 캐시 로드
            safeLoadCacheFromStorage()
            
            // 주간 메모리 업데이트 (비동기)
            updateWeeklyMemoryAsync()
            
            #if DEBUG
            if let cache = currentCache {
                let timeRemaining = cacheExpiryTime - Date().timeIntervalSince(cache.cacheTimestamp)
                print("🗄️ 캐시 초기화: \(cache.conversationCount)회 대화, \(Int(timeRemaining))초 남음")
            } else {
                print("🆕 캐시 없음: 새 캐시 생성 예정")
            }
            #endif
        }
    
    // MARK: - ✅ 디버그 정보
#if DEBUG
   func getDebugInfo() -> String {
       let weeklyMemory = loadWeeklyMemory()
       let cacheInfo = currentCache?.cacheId ?? "없음"
       let cacheTokens = currentCache?.totalCachedTokens ?? 0
       let cacheTimeLeft = currentCache.map { Int(cacheExpiryTime - Date().timeIntervalSince($0.cacheTimestamp)) } ?? 0
       
       return """
       🗄️ 캐시 시스템 상태:
       
       📋 캐시 정보:
       • ID: \(cacheInfo)
       • 토큰: \(cacheTokens)개/\(maxCacheTokens)개
       • 남은시간: \(cacheTimeLeft)초/\(Int(cacheExpiryTime))초
       • 대화횟수: \(currentCache?.conversationCount ?? 0)회
       
       🧠 주간 메모리:
       • 감정패턴: \(weeklyMemory.emotionalPattern)
       • 주요주제: \(weeklyMemory.recurringThemes.prefix(3).joined(separator: ", "))
       • 총메시지: \(weeklyMemory.totalMessages)개
       
       💾 저장소 상태:
       • 오늘메시지: \(loadTodayMessages().count)개
       • 주간메시지: \(loadWeeklyMessages().count)개
       """
   }
   
   // ✅ 캐시 성능 통계
   func getCachePerformanceStats() -> String {
       guard let cache = currentCache else {
           return "캐시 없음"
       }
       
       let efficiency = cache.conversationCount > 0 ?
           Float(cache.totalCachedTokens) / Float(cache.conversationCount) : 0
       
       return """
       📊 캐시 성능 통계:
       
       • 재사용 횟수: \(cache.conversationCount)회
       • 토큰 효율성: \(String(format: "%.1f", efficiency)) 토큰/대화
       • 메모리 절약: 약 \(cache.totalCachedTokens * cache.conversationCount)토큰
       • 캐시 적중률: \(cache.conversationCount > 0 ? "활성" : "신규")
       """
   }
   #endif
}

// MARK: - ✅ 컨텍스트 열거형
enum ChatContext {
    case diaryAnalysis(DiaryContext)
    case patternAnalysis(String)
    case emotionChat(String)
}
