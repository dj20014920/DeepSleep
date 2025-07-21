import Foundation
import Core

final class EmotionAnalysisService: EmotionAnalysisServiceProtocol {
    func analyzeEmotion(text: String) async throws -> EmotionAnalysisModels.EmotionAnalysisResponse {
        // 간단한 스텁 구현
        let emotions = ["기쁨", "슬픔", "평온", "흥미", "걱정", "스트레스"]
        let randomEmotion = emotions.randomElement() ?? "평온"
        let intensity = Float.random(in: 0.3...0.9)
        
        return EmotionAnalysisModels.EmotionAnalysisResponse(
            primaryEmotion: randomEmotion,
            intensity: intensity,
            secondaryEmotions: emotions.filter { $0 != randomEmotion }.prefix(2).map { $0 },
            suggestion: "\(randomEmotion) 감정을 더 잘 이해해보세요."
        )
    }
    
    func analyzeEmotionPattern(_ data: String) async throws -> EmotionAnalysisResult {
        return EmotionAnalysisResult(
            summary: "감정 패턴 분석 결과",
            recommendations: ["추천 1", "추천 2"],
            followUpQuestions: ["질문 1", "질문 2"]
        )
    }
    
    func generateChatResponse(to message: String, history: [(isUser: Bool, message: String)]) async throws -> String {
        return "AI 응답: \(message)에 대한 답변입니다."
    }
    
    func generateQuickTip(for intent: String) async throws -> String {
        return "팁: \(intent)에 대한 조언입니다."
    }
    
    func getAIRecommendation() async throws -> RecommendationResult {
        return RecommendationResult(
            id: UUID().uuidString,
            title: "AI 추천",
            description: "AI가 추천하는 사운드입니다.",
            components: []
        )
    }
    
    func getLocalRecommendation() async throws -> RecommendationResult {
        return RecommendationResult(
            id: UUID().uuidString,
            title: "로컬 추천",
            description: "로컬 기반 추천 사운드입니다.",
            components: []
        )
    }
    
    func saveFeedback(recommendationId: String, score: Int, comment: String?) async throws {
        // 스텁 구현
        print("피드백 저장: \(recommendationId), 점수: \(score)")
    }
    
    // MARK: - Enhanced Message Loading (과거 대화 맥락 포함)
    func loadMessages(page: Int, pageSize: Int) async throws -> [(isUser: Bool, content: String)] {
        do {
            print("🎯 [EmotionAnalysisService] 향상된 컨텍스트 로딩 시작")
            
            // 1. 오늘의 최근 대화 로드
            let messageStoreMessages = try await MessageStore.shared.loadMessages(page: 0, pageSize: 30)
            
            // 2. 과거 대화에서 관련 맥락 검색
            let pastContext = try await loadRelevantPastContext(from: messageStoreMessages)
            
            // 3. 현재 + 과거 컨텍스트 통합
            let currentContext = classifyAndCompressContextFromMessageStore(from: messageStoreMessages)
            let enhancedContext = integrateContexts(current: currentContext, past: pastContext)
            
            print("📊 [EmotionAnalysisService] 향상된 컨텍스트 크기: \(enhancedContext.count)개 (과거 맥락 포함)")
            return enhancedContext
            
        } catch {
            print("❌ [EmotionAnalysisService] 향상된 컨텍스트 로드 실패: \(error)")
            // 실패 시 기본 방식으로 fallback
            return try await loadBasicMessages(page: page, pageSize: pageSize)
        }
    }
    
    // MARK: - Fallback Method (기본 방식)
    private func loadBasicMessages(page: Int, pageSize: Int) async throws -> [(isUser: Bool, content: String)] {
        let messageStoreMessages = try await MessageStore.shared.loadMessages(page: 0, pageSize: 50)
        return classifyAndCompressContextFromMessageStore(from: messageStoreMessages)
    }
    
    // MARK: - Smart Context Classification (MessageStore 호환)
    private func classifyAndCompressContextFromMessageStore(from messages: [(isUser: Bool, content: String)]) -> [(isUser: Bool, content: String)] {
        var essentialMessages: [(isUser: Bool, content: String)] = []
        
        // 1. 감정 일기 관련 메시지 (최근 3개)
        let emotionMessages = messages
            .filter { message in
                let content = message.content.lowercased()
                return content.contains("감정") || 
                       content.contains("기분") ||
                       content.contains("슬프") ||
                       content.contains("행복") ||
                       content.contains("스트레스") ||
                       content.contains("걱정") ||
                       content.contains("평온") ||
                       content.contains("일기")
            }
            .suffix(3) // 최근 3개
        
        // 2. 사용자 목표 및 의도 (최근 2개)
        let goalMessages = messages
            .filter { message in
                let content = message.content.lowercased()
                return content.contains("목표") ||
                       content.contains("원해") ||
                       content.contains("하고 싶") ||
                       content.contains("계획") ||
                       content.contains("수면")
            }
            .suffix(2) // 최근 2개
        
        // 3. 중요한 사용자 피드백 (최근 2개)
        let feedbackMessages = messages
            .filter { message in
                let content = message.content.lowercased()
                return (content.contains("좋") && content.contains("않")) ||
                       content.contains("마음에") ||
                       content.contains("만족") ||
                       content.contains("별로") ||
                       content.contains("추천")
            }
            .suffix(2) // 최근 2개
        
        // 4. 컨텍스트 통합 및 압축 (중복 제거)
        let allRelevantMessages = Array(emotionMessages) + Array(goalMessages) + Array(feedbackMessages)
        
        // 중복 제거 (내용 기반)
        var seenContents = Set<String>()
        let uniqueMessages = allRelevantMessages.filter { message in
            let shortContent = String(message.content.prefix(50)) // 첫 50자로 중복 판단
            if seenContents.contains(shortContent) {
                return false
            } else {
                seenContents.insert(shortContent)
                return true
            }
        }
        
        let relevantMessages = Array(uniqueMessages.suffix(5)) // 최대 5개 메시지만
        
        // 5. 메시지 요약 및 압축
        for message in relevantMessages {
            let compressedContent = compressMessage(message.content)
            essentialMessages.append((
                isUser: message.isUser,
                content: compressedContent
            ))
        }
        
        // 6. 현재 시간 컨텍스트 추가 (토큰 효율적)
        if !essentialMessages.isEmpty {
            let timeContext = getCurrentTimeContext()
            essentialMessages.insert((
                isUser: false,
                content: timeContext
            ), at: 0)
        }
        
        print("✅ [EmotionAnalysisService] 필수 컨텍스트 추출 완료: \(essentialMessages.count)개")
        return essentialMessages
    }
    
    // MARK: - Smart Context Classification (ChatManager 호환 - 레거시)
    private func classifyAndCompressContext(from messages: [StoredChatMessage]) -> [(isUser: Bool, content: String)] {
        var essentialMessages: [(isUser: Bool, content: String)] = []
        
        // 1. 감정 일기 관련 메시지 (최근 3개)
        let emotionMessages = messages
            .filter { message in
                let content = message.text.lowercased()
                return content.contains("감정") || 
                       content.contains("기분") ||
                       content.contains("슬프") ||
                       content.contains("행복") ||
                       content.contains("스트레스") ||
                       content.contains("걱정") ||
                       content.contains("평온") ||
                       content.contains("일기")
            }
            .prefix(3)
        
        // 2. 사용자 목표 및 의도 (최근 2개)
        let goalMessages = messages
            .filter { message in
                let content = message.text.lowercased()
                return content.contains("목표") ||
                       content.contains("원해") ||
                       content.contains("하고 싶") ||
                       content.contains("계획") ||
                       content.contains("수면")
            }
            .prefix(2)
        
        // 3. 중요한 사용자 피드백 (최근 2개)
        let feedbackMessages = messages
            .filter { message in
                let content = message.text.lowercased()
                return (content.contains("좋") && content.contains("않")) ||
                       content.contains("마음에") ||
                       content.contains("만족") ||
                       content.contains("별로") ||
                       content.contains("추천")
            }
            .prefix(2)
        
        // 4. 컨텍스트 통합 및 압축 (중복 제거)
        var allRelevantMessages = Array(emotionMessages) + Array(goalMessages) + Array(feedbackMessages)
        
        // 중복 제거 (ID 기반)
        var seenIds = Set<UUID>()
        let uniqueMessages = allRelevantMessages.filter { message in
            if seenIds.contains(message.id) {
                return false
            } else {
                seenIds.insert(message.id)
                return true
            }
        }
        
        let relevantMessages = uniqueMessages
            .sorted { $0.timestamp > $1.timestamp }
            .prefix(5) // 최대 5개 메시지만
        
        // 5. 메시지 요약 및 압축
        for message in relevantMessages {
            let compressedContent = compressMessage(message.text)
            let isUser = (message.type == .user)
            essentialMessages.append((
                isUser: isUser,
                content: compressedContent
            ))
        }
        
        // 6. 현재 시간 컨텍스트 추가 (토큰 효율적)
        if !essentialMessages.isEmpty {
            let timeContext = getCurrentTimeContext()
            essentialMessages.insert((
                isUser: false,
                content: timeContext
            ), at: 0)
        }
        
        print("✅ [EmotionAnalysisService] 필수 컨텍스트 추출 완료: \(essentialMessages.count)개")
        return essentialMessages
    }
    
    // MARK: - Message Compression
    private func compressMessage(_ content: String) -> String {
        // 감정 대화의 맥락 보존을 위해 500자로 확대
        if content.count > 500 {
            let compressed = String(content.prefix(500))
            return compressed + "..."
        }
        return content
    }
    
    // MARK: - Time Context
    private func getCurrentTimeContext() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        let timeOfDay = getTimeOfDay(hour: hour)
        return "[시간: \(timeOfDay)]"
    }
    
    private func getTimeOfDay(hour: Int) -> String {
        switch hour {
        case 6..<12: return "오전"
        case 12..<18: return "오후"
        case 18..<22: return "저녁"
        default: return "밤"
        }
    }
    
    // MARK: - Enhanced Context Management (과거 대화 활용)
    
    /// 🔍 현재 대화와 관련된 과거 맥락 검색
    private func loadRelevantPastContext(from currentMessages: [(isUser: Bool, content: String)]) async throws -> [(isUser: Bool, content: String)] {
        // 현재 대화에서 키워드 추출
        let keywords = extractKeywords(from: currentMessages)
        var pastContext: [(isUser: Bool, content: String)] = []
        
        // 키워드별로 과거 대화 검색
        for keyword in keywords {
            do {
                // DailyConversationManager 임시 비활성화
                // let searchResults = try await DailyConversationManager.shared.searchConversations(
                //     keyword: keyword, 
                //     maxResults: 2
                // )
                
                // 검색 결과를 컨텍스트 형태로 변환
                // for result in searchResults {
                //     let contextMessage = formatPastContext(result: result)
                //     pastContext.append(contextMessage)
                // }
            } catch {
                print("⚠️ [EmotionAnalysisService] 키워드 '\(keyword)' 검색 실패: \(error)")
            }
        }
        
        // 과거 맥락이 너무 많으면 최신 순으로 제한
        let limitedPastContext = Array(pastContext.prefix(3))
        print("🔍 [EmotionAnalysisService] 과거 맥락 \(limitedPastContext.count)개 로드됨")
        
        return limitedPastContext
    }
    
    /// 📝 현재 대화에서 중요 키워드 추출
    private func extractKeywords(from messages: [(isUser: Bool, content: String)]) -> [String] {
        var keywords: Set<String> = []
        
        // 사용자 메시지에서만 키워드 추출 (AI 응답 제외)
        let userMessages = messages.filter { $0.isUser }
        
        for message in userMessages {
            let content = message.content.lowercased()
            
            // 감정 관련 키워드
            let emotionKeywords = ["스트레스", "우울", "불안", "걱정", "행복", "기쁨", "슬픔", "화남", "평온"]
            for keyword in emotionKeywords {
                if content.contains(keyword) {
                    keywords.insert(keyword)
                }
            }
            
            // 상황 관련 키워드 (명사 추출 - 간단한 버전)
            let situationKeywords = ["직장", "가족", "친구", "연인", "학교", "시험", "면접", "여행", "건강", "수면"]
            for keyword in situationKeywords {
                if content.contains(keyword) {
                    keywords.insert(keyword)
                }
            }
            
            // 최대 5개 키워드로 제한
            if keywords.count >= 5 {
                break
            }
        }
        
        return Array(keywords)
    }
    
    /// 📅 과거 대화 검색 결과를 컨텍스트 형태로 포맷팅
    private func formatPastContext(result: Any) -> (isUser: Bool, content: String) {
        // 임시 구현 - 실제 ConversationSearchResult 타입 사용 시 수정 필요
        let contextMessage = "💭 [과거 대화]: 관련 대화 내용"
        return (isUser: false, content: contextMessage)
    }
    
    /// 🔗 현재 컨텍스트와 과거 맥락 통합
    private func integrateContexts(
        current: [(isUser: Bool, content: String)], 
        past: [(isUser: Bool, content: String)]
    ) -> [(isUser: Bool, content: String)] {
        var integrated: [(isUser: Bool, content: String)] = []
        
        // 1. 시간 컨텍스트 추가
        let timeContext = getCurrentTimeContext()
        integrated.append((isUser: false, content: timeContext))
        
        // 2. 과거 맥락 추가 (관련성 있는 경우만)
        if !past.isEmpty {
            integrated.append((isUser: false, content: "📚 [관련 과거 대화]"))
            integrated.append(contentsOf: past)
            integrated.append((isUser: false, content: "📚 [현재 대화]"))
        }
        
        // 3. 현재 대화 추가
        integrated.append(contentsOf: current)
        
        // 4. 토큰 제한 (최대 15개 메시지)
        if integrated.count > 15 {
            // 과거 맥락을 먼저 줄임
            let essentialPast = Array(past.prefix(1))
            let essentialCurrent = Array(current.suffix(10))
            
            integrated = [(isUser: false, content: timeContext)]
            if !essentialPast.isEmpty {
                integrated.append((isUser: false, content: "💭 [관련 과거]"))
                integrated.append(contentsOf: essentialPast)
            }
            integrated.append(contentsOf: essentialCurrent)
        }
        
        print("🔗 [EmotionAnalysisService] 컨텍스트 통합 완료: 현재 \(current.count)개 + 과거 \(past.count)개 = 총 \(integrated.count)개")
        return integrated
    }
}