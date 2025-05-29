import Foundation
import Network

class ReplicateChatService {
    static let shared = ReplicateChatService()
    private init() {}
    
    private struct ConversationLimits {
        static let maxTokensPerRequest = 500
        static let maxConversationLength = 3000
        static let maxMessagesInMemory = 20
        static let contextCompressionThreshold = 2500
    }
    
    // 대화 히스토리 관리
    private var conversationHistory: [String] = []
    private var currentTokenCount = 0
    private var conversationId: String?
    private var isContextSet = false
    private var consecutiveFailures = 0

    // MARK: - 네트워크 체크
    func isNetworkAvailable(completion: @escaping (Bool) -> Void) {
        let monitor = NWPathMonitor()
        let queue = DispatchQueue(label: "NetworkMonitor")
        monitor.pathUpdateHandler = { path in
            monitor.cancel()
            DispatchQueue.main.async {
                completion(path.status == .satisfied)
            }
        }
        monitor.start(queue: queue)
    }

    // MARK: - ✅ 토큰 최적화된 sendPrompt
    func sendPrompt(message: String, intent: String, completion: @escaping (String?) -> Void) {
        let optimizedPrompt = buildOptimizedPrompt(message: message, intent: intent)
        let maxTokens = getOptimalTokens(for: intent)
        
        // ✅ 완성된 응답 요청 추가
        let enhancedPrompt = optimizedPrompt + "\n\n완전한 문장으로 답변 완료. 중간에 끊기지 않도록 주의."
        
        let input: [String: Any] = [
            "prompt": enhancedPrompt,
            "temperature": getTemperature(for: intent),
            "top_p": 0.9,
            "max_tokens": maxTokens,
            "system_prompt": getSystemPrompt(for: intent) + " 완전한 응답 필수."
        ]

        sendToReplicate(input: input, completion: completion)
    }
    
    // ✅ 최적화된 프롬프트 빌더
    private func buildOptimizedPrompt(message: String, intent: String) -> String {
        switch intent {
        case "diary_analysis":
            return "일기분석: \(message)\n\n깊은공감+격려+조언 제공"
        case "pattern_analysis":
            return "감정패턴분석: \(message)\n\n패턴해석+개선방안+관리전략 제시"
        case "diary":
            return "일기상담: \(message)\n\n따뜻한공감+위로 응답"
        case "chat":
            return message
        default:
            return message
        }
    }
    
    // ✅ Intent별 최적 토큰 수
    private func getOptimalTokens(for intent: String) -> Int {
        switch intent {
        case "pattern_analysis": return 300
        case "diary_analysis": return 200
        case "diary": return 180
        case "chat": return 120
        default: return 150
        }
    }
    
    // ✅ Intent별 최적 Temperature
    private func getTemperature(for intent: String) -> Double {
        switch intent {
        case "pattern_analysis": return 0.6
        case "diary_analysis": return 0.7
        case "diary": return 0.8
        case "chat": return 0.7
        default: return 0.7
        }
    }
    
    // ✅ 간결한 시스템 프롬프트
    private func getSystemPrompt(for intent: String) -> String {
        switch intent {
        case "diary_analysis":
            return "감정분석 상담사. 한국어. 공감+격려+조언. 완전한 문장으로 응답."
        case "pattern_analysis":
            return "감정패턴 전문가. 한국어. 객관적분석+실용조언. 끝까지 완성된 응답."
        case "diary":
            return "감정 친구. 한국어. 따뜻한위로+공감. 완전한 응답 필수."
        default:
            return "AI친구. 한국어. 자연스러운대화. 문장 완성 필수."
        }
    }

    // MARK: - ✅ 최적화된 프리셋 추천
    func recommendPreset(emotion: String, completion: @escaping (String?) -> Void) {
        let prompt = """
        감정:\(emotion)
        12사운드(Rain,Thunder,Ocean,Fire,Steam,WindowRain,Forest,Wind,Night,Lullaby,Fan,WhiteNoise) 볼륨0-100 설정.
        출력:[프리셋명] Rain:값,Thunder:값,...(12개)
        """

        let input: [String: Any] = [
            "prompt": prompt,
            "temperature": 0.3,
            "top_p": 0.8,
            "max_tokens": 100,
            "system_prompt": "사운드전문가"
        ]

        sendToReplicate(input: input, completion: completion)
    }

    // MARK: - ✅ 감정 분석 전용 최적화 메서드
    func analyzeEmotionPattern(data: String, completion: @escaping (String?) -> Void) {
        let optimizedPrompt = """
        감정데이터:\(String(data.prefix(200)))
        
        다음 형식으로 완전한 분석 제공:
        1. 주요패턴 (2-3줄)
        2. 긍정적 변화 포인트 (2줄)  
        3. 개선 필요 부분 (2줄)
        4. 실용적 조언 (3줄)
        
        총 300자 이내로 완성된 분석 제공. 중간에 끊기지 않도록 주의.
        """
        
        let input: [String: Any] = [
            "prompt": optimizedPrompt,
            "temperature": 0.7,
            "top_p": 0.9,
            "max_tokens": 250,  // 토큰 증가
            "system_prompt": "감정분석전문가. 한국어. 완전한 문장으로 응답 완료 필수."
        ]
        
        sendToReplicate(input: input, completion: completion)
    }
    
    // MARK: - ✅ 감정 대화 전용 메서드
    func respondToEmotionQuery(query: String, context: String, completion: @escaping (String?) -> Void) {
        let contextSummary = String(context.suffix(100))
        let optimizedPrompt = """
        맥락:\(contextSummary)
        질문:\(query)
        
        따뜻한 공감과 실용적 조언을 포함한 완전한 응답 제공.
        200자 이내로 완성된 답변. 문장 중간에 끊기지 않도록 주의.
        """
        
        let input: [String: Any] = [
            "prompt": optimizedPrompt,
            "temperature": 0.8,
            "top_p": 0.9,
            "max_tokens": 180,  // 토큰 증가
            "system_prompt": "감정상담사. 한국어. 완전한 문장으로 응답 완료."
        ]
        
        sendToReplicate(input: input, completion: completion)
    }
    
    // MARK: - ✅ 빠른 감정 팁 제공
    func getQuickEmotionTip(emotion: String, type: String, completion: @escaping (String?) -> Void) {
        let tipPrompt: String
        
        switch type {
        case "improvement":
            tipPrompt = """
            감정:\(emotion)
            
            개선 방법 3가지를 완전한 문장으로 제공:
            1. [구체적 방법 1]
            2. [구체적 방법 2] 
            3. [구체적 방법 3]
            
            150자 이내로 완성된 조언. 끝까지 완성 필수.
            """
        case "stress":
            tipPrompt = """
            \(emotion) 상황의 스트레스 관리법 3가지를 완전한 문장으로:
            1. [즉시 실행 가능한 방법]
            2. [중장기 관리법]
            3. [예방법]
            
            150자 이내 완성된 답변.
            """
        case "trend":
            tipPrompt = """
            \(emotion) 패턴 분석 결과:
            - 주요 원인: [원인 설명]
            - 변화 추이: [추이 설명]
            - 개선 방향: [구체적 제안]
            
            150자 이내 완성된 분석.
            """
        default:
            tipPrompt = """
            \(emotion) 감정 조절 조언을 완전한 문장으로 제공.
            실용적이고 즉시 적용 가능한 방법 위주.
            120자 이내 완성된 답변.
            """
        }
        
        let input: [String: Any] = [
            "prompt": tipPrompt,
            "temperature": 0.6,
            "top_p": 0.8,
            "max_tokens": 120,  // 토큰 증가
            "system_prompt": "감정코치. 완전한 문장으로 응답 완료 필수."
        ]
        
        sendToReplicate(input: input, completion: completion)
    }
    // MARK: - Replicate API 요청
    private func sendToReplicate(input: [String: Any], completion: @escaping (String?) -> Void) {
        isNetworkAvailable { isConnected in
            guard isConnected else {
                print("❌ 네트워크 연결 안 됨")
                completion(nil)
                return
            }

            guard let apiToken = Bundle.main.object(forInfoDictionaryKey: "REPLICATE_API_TOKEN") as? String else {
                print("❌ API 토큰 누락")
                completion(nil)
                return
            }

            let url = URL(string: "https://api.replicate.com/v1/models/anthropic/claude-3.5-haiku/predictions")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.addValue("Bearer \(apiToken)", forHTTPHeaderField: "Authorization")
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")

            let body: [String: Any] = ["input": input]
            
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
                print("📤 API 요청 전송 (\(input["max_tokens"] ?? 0) 토큰)")
            } catch {
                print("❌ JSON 직렬화 실패: \(error)")
                completion(nil)
                return
            }
            
            let session = URLSession(configuration: .default)
            self.executeRequest(session: session, request: request, completion: completion, retriesLeft: 3)
        }
    }
    
    // ✅ 요청 실행 최적화
    private func executeRequest(session: URLSession, request: URLRequest, completion: @escaping (String?) -> Void, retriesLeft: Int) {
        session.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ 네트워크 오류: \(error)")
                if retriesLeft > 0 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        self.executeRequest(session: session, request: request, completion: completion, retriesLeft: retriesLeft - 1)
                    }
                } else {
                    DispatchQueue.main.async { completion(nil) }
                }
                return
            }
            
            guard let data = data else {
                print("❌ 데이터 없음")
                DispatchQueue.main.async { completion(nil) }
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if let predictionID = json["id"] as? String {
                        print("✅ 예측 시작: \(predictionID)")
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            self.pollPredictionResult(id: predictionID, attempts: 0, completion: completion)
                        }
                    } else if let error = json["error"] as? String {
                        print("❌ API 에러: \(error)")
                        if retriesLeft > 0 {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                self.executeRequest(session: session, request: request, completion: completion, retriesLeft: retriesLeft - 1)
                            }
                        } else {
                            DispatchQueue.main.async { completion(nil) }
                        }
                    }
                }
            } catch {
                print("❌ JSON 파싱 실패: \(error)")
                DispatchQueue.main.async { completion(nil) }
            }
        }.resume()
    }

    // MARK: - ✅ 최적화된 결과 폴링
    private func pollPredictionResult(id: String, attempts: Int, completion: @escaping (String?) -> Void) {
        guard attempts < 25 else {
            print("❌ 시간 초과")
            DispatchQueue.main.async { completion(nil) }
            return
        }

        guard let apiToken = Bundle.main.object(forInfoDictionaryKey: "REPLICATE_API_TOKEN") as? String else {
            completion(nil)
            return
        }

        let getURL = URL(string: "https://api.replicate.com/v1/predictions/\(id)")!
        var request = URLRequest(url: getURL)
        request.httpMethod = "GET"
        request.addValue("Bearer \(apiToken)", forHTTPHeaderField: "Authorization")

        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    self.pollPredictionResult(id: id, attempts: attempts + 1, completion: completion)
                }
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    let status = json["status"] as? String ?? "unknown"
                    
                    switch status {
                    case "succeeded":
                        var result: String?
                        if let outputArray = json["output"] as? [String] {
                            result = outputArray.joined()
                        } else if let outputString = json["output"] as? String {
                            result = outputString
                        }
                        
                        print("✅ 응답 완료")
                        DispatchQueue.main.async { completion(result) }
                        
                    case "failed", "canceled":
                        print("❌ 실패")
                        DispatchQueue.main.async { completion(nil) }
                        
                    case "starting", "processing":
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            self.pollPredictionResult(id: id, attempts: attempts + 1, completion: completion)
                        }
                        
                    default:
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            self.pollPredictionResult(id: id, attempts: attempts + 1, completion: completion)
                        }
                    }
                }
            } catch {
                print("❌ 파싱 실패")
                DispatchQueue.main.async { completion(nil) }
            }
        }.resume()
    }

    // MARK: - ✅ 스마트 컨텍스트 압축
    func sendPromptWithContextManagement(
        message: String,
        intent: String,
        conversationHistory: [String] = [],
        completion: @escaping (String?) -> Void
    ) {
        let totalContext = ([message] + conversationHistory).joined(separator: " ")
        
        if totalContext.count > ConversationLimits.contextCompressionThreshold {
            let compressedContext = compressConversationContext(history: conversationHistory)
            let optimizedPrompt = buildContextualPrompt(
                message: message,
                compressedContext: compressedContext,
                intent: intent
            )
            
            sendPrompt(message: optimizedPrompt, intent: intent, completion: completion)
        } else {
            sendPrompt(message: message, intent: intent, completion: completion)
        }
    }
    
    // MARK: - ✅ 대화 히스토리 압축
    private func compressConversationContext(history: [String]) -> String {
        guard history.count > 3 else { return history.joined(separator: "\n") }
        
        let recentMessages = Array(history.suffix(3))
        let olderMessages = Array(history.prefix(history.count - 3))
        
        let summary = summarizeOlderMessages(olderMessages)
        let compressed = ([summary] + recentMessages).joined(separator: "\n")
        
        print("📝 컨텍스트 압축: \(history.count)개 → 요약+3개")
        return compressed
    }
    
    private func summarizeOlderMessages(_ messages: [String]) -> String {
        let allText = messages.joined(separator: " ")
        let keywords = extractKeywords(from: allText)
        
        return "이전대화요약: \(keywords.prefix(5).joined(separator: ", "))"
    }
    
    private func extractKeywords(from text: String) -> [String] {
        // ✅ 수정: .whitespacesAndPunctuationMarks → .whitespacesAndNewlines와 .punctuationCharacters 조합
        let words = text.components(separatedBy: .whitespacesAndNewlines)
            .flatMap { $0.components(separatedBy: .punctuationCharacters) }
        let meaningfulWords = words.filter { $0.count > 2 && !isStopWord($0) }
        
        let wordCounts = Dictionary(grouping: meaningfulWords, by: { $0 })
            .mapValues { $0.count }
            .sorted { $0.value > $1.value }
        
        return wordCounts.prefix(10).map { $0.key }
    }
    
    private func isStopWord(_ word: String) -> Bool {
        let stopWords = ["그런데", "그래서", "하지만", "그리고", "그냥", "정말", "진짜", "아니", "네"]
        return stopWords.contains(word.lowercased())
    }
    
    // MARK: - ✅ 컨텍스트 기반 프롬프트 구성
    private func buildContextualPrompt(message: String, compressedContext: String, intent: String) -> String {
        switch intent {
        case "pattern_analysis":
            return """
            맥락:\(String(compressedContext.suffix(150)))
            요청:\(message)
            간단분석응답
            """
        case "diary_analysis":
            return """
            이전대화:\(String(compressedContext.suffix(100)))
            일기:\(message)
            공감응답
            """
        default:
            return """
            맥락:\(String(compressedContext.suffix(100)))
            질문:\(message)
            """
        }
    }
    
    // MARK: - ✅ 자동 새 대화 시작 감지
    func shouldStartNewConversation(currentLength: Int, messageCount: Int) -> Bool {
        return currentLength > ConversationLimits.maxConversationLength ||
               messageCount > ConversationLimits.maxMessagesInMemory
    }
    
    // MARK: - ✅ 대화 초기화 알림
    func handleConversationReset(completion: @escaping (String) -> Void) {
        let resetMessage = """
        💾 대화가 길어져서 새로운 대화를 시작합니다.
        
        이전 대화의 맥락을 기억하면서 계속 도움을 드릴게요!
        무엇에 대해 이야기하고 싶으신가요?
        """
        
        conversationHistory.removeAll()
        currentTokenCount = 0
        
        completion(resetMessage)
    }
    
    // MARK: - ✅ 에러 복구 전략
    func handleAPIError(_ error: String, retryAttempt: Int, completion: @escaping (String?) -> Void) {
        switch error {
        case let e where e.contains("token"):
            if retryAttempt == 0 {
                handleConversationReset { resetMessage in
                    completion(resetMessage)
                }
            } else {
                completion("죄송해요, 서버가 바쁩니다. 잠시 후 다시 시도해주세요.")
            }
        case let e where e.contains("rate"):
            completion("⏰ 잠시 쉬었다가 다시 대화해보세요. (1분 후 재시도)")
        case let e where e.contains("network"):
            completion("🌐 네트워크 연결을 확인해주세요.")
        default:
            completion("일시적인 문제가 발생했습니다. 다시 시도해주세요.")
        }
    }
    
    // MARK: - ✅ 프리엠티브 메모리 관리
    func preemptiveMemoryCheck(conversationLength: Int) -> (shouldCompress: Bool, shouldReset: Bool) {
        let shouldCompress = conversationLength > ConversationLimits.contextCompressionThreshold
        let shouldReset = conversationLength > ConversationLimits.maxConversationLength
        
        if shouldReset {
            print("⚠️ 대화 길이 초과, 리셋 필요: \(conversationLength)")
        } else if shouldCompress {
            print("📝 컨텍스트 압축 권장: \(conversationLength)")
        }
        
        return (shouldCompress, shouldReset)
    }
    
    // MARK: - ✅ 네트워크 상태 모니터링
    func getOptimalTokensForNetworkCondition(baseTokens: Int) -> Int {
        // 네트워크 체크는 비동기이므로 기본값 반환
        return baseTokens
    }
    
    func adjustTokensForFailures(baseTokens: Int) -> Int {
        let reduction = min(consecutiveFailures * 20, 100)
        return max(baseTokens - reduction, 50)
    }
    
    func resetFailureCount() {
        consecutiveFailures = 0
    }
    
    func incrementFailureCount() {
        consecutiveFailures += 1
        if consecutiveFailures > 5 {
            print("⚠️ 연속 실패 감지, 토큰 제한 강화")
        }
    }
    
    // MARK: - ✅ 토큰 사용량 모니터링
    private func logTokenUsage(intent: String, tokens: Int) {
        print("📊 토큰 사용: \(intent) - \(tokens)토큰")
        
        if tokens > 300 {
            print("⚠️ 높은 토큰 사용량 감지: \(tokens)")
        }
    }
    
    private func validatePromptLength(_ prompt: String, maxLength: Int = 500) -> String {
        if prompt.count > maxLength {
            print("⚠️ 프롬프트 길이 초과, 자동 단축: \(prompt.count) -> \(maxLength)")
            return String(prompt.prefix(maxLength)) + "..."
        }
        return prompt
    }
}
