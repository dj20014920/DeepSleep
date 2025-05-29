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
        
        let input: [String: Any] = [
            "prompt": optimizedPrompt,
            "temperature": getTemperature(for: intent),
            "top_p": 0.9,
            "max_tokens": maxTokens,
            "system_prompt": getSystemPrompt(for: intent)
        ]

        sendToReplicate(input: input, completion: completion)
    }
    
    // ✅ 최적화된 프롬프트 빌더 - 자연스러운 말투 강조
    private func buildOptimizedPrompt(message: String, intent: String) -> String {
        switch intent {
        case "diary_analysis":
            return """
            일기분석: \(message)
            
            따뜻하고 친근한 말투로 120토큰 이내 응답해주세요.
            마치 친한 친구가 위로해주는 것처럼 자연스럽게 대화하세요.
            공감 → 격려 → 실용적 조언 순서로 완성된 답변을 주세요.
            """
        case "pattern_analysis":
            return """
            감정패턴분석: \(message)
            
            전문적이면서도 따뜻한 말투로 충분히 길고 상세하게 분석해주세요.
            하루 1회의 소중한 기회이므로 깊이 있는 분석을 제공해주세요.
            
            다음 구조로 자세히 분석해주세요:
            1. 전체적인 감정 패턴 해석 (주요 감정, 빈도, 변화 경향)
            2. 긍정적인 변화와 성장 포인트 발견
            3. 주의할 점과 개선이 필요한 부분
            4. 구체적이고 실용적인 개선 방법과 조언
            5. 장기적 감정 관리 전략과 맞춤 추천사항
            
            토큰 제한에 구애받지 말고 충분히 길고 상세하게 분석해주세요.
            마치 전문 심리상담사가 1:1로 상담해주는 것처럼 깊이 있게 해주세요.
            """
        case "diary":
            return """
            일기상담: \(message)
            
            마음을 다독여주는 친근한 말투로 100토큰 이내 응답해주세요.
            "~네요", "~세요" 같은 자연스러운 반말/존댓말을 섞어서 사용하세요.
            공감하는 마음으로 따뜻하고 완성된 위로를 전해주세요.
            """
        case "chat":
            return """
            \(message)
            
            친구처럼 편안하고 자연스러운 말투로 80토큰 이내 대화해주세요.
            딱딱한 설명보다는 일상적이고 친근한 표현을 사용하세요.
            완성된 자연스러운 대화를 해주세요.
            """
        default:
            return """
            다음 메시지에 대해 친근하고 따뜻한 말투로 100토큰 이내 자연스럽게 응답해주세요:
            \(message)
            
            딱딱한 설명이 아닌, 마치 친한 상담사가 대화하는 것처럼 답변해주세요.
            """
        }
    }

    // ✅ Intent별 최적 토큰 수
    private func getOptimalTokens(for intent: String) -> Int {
        switch intent {
        case "pattern_analysis": return 2000
        case "diary_analysis": return 1000
        case "diary": return 150
        case "chat": return 120
        default: return 150
        }
    }
    
    // ✅ Intent별 최적 Temperature - 자연스러운 대화를 위해 증가
    private func getTemperature(for intent: String) -> Double {
        switch intent {
        case "pattern_analysis": return 0.8  // 0.6 → 0.8 (더 자연스럽게)
        case "diary_analysis": return 0.8    // 0.7 → 0.8
        case "diary": return 0.9             // 0.8 → 0.9 (더 따뜻하게)
        case "chat": return 0.9              // 0.7 → 0.9 (더 친근하게)
        default: return 0.8                  // 0.7 → 0.8
        }
    }
    
    // 시스템 프롬프트
    private func getSystemPrompt(for intent: String) -> String {
        switch intent {
        case "diary_analysis":
            return "따뜻하고 친근한 심리상담사. 자연스러운 한국어 대화체 사용. 딱딱하지 않은 친근한 말투. 120토큰 이내 완성."
        case "pattern_analysis":
            return "전문적이고 따뜻한 감정 분석 전문가. 깊이 있고 상세한 분석 제공. 자연스러운 한국어. 토큰 제한 없이 충분히 길고 상세하게 분석. 마치 1:1 심리상담 세션처럼 깊이 있게 분석."
        case "diary":
            return "마음을 다독여주는 친한 친구 같은 상담사. '~네요' '~세요' 같은 자연스러운 말투. 100토큰 이내 완성."
        default:
            return "친근하고 따뜻한 AI 친구. 딱딱한 설명보다 자연스러운 대화. 일상적 표현 사용. 지정 토큰 이내 완성."
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

    // MARK: - ✅ 감정 분석 전용 최적화 메서드 - 자연스러운 말투
    func analyzeEmotionPattern(data: String, completion: @escaping (String?) -> Void) {
        let optimizedPrompt = """
        감정데이터:\(String(data.prefix(400)))
        
        최근 30일간의 감정 패턴을 매우 상세하고 따뜻하게 분석해주세요.
        하루 1회의 소중한 기회이므로 충분히 길고 깊이 있게 분석해주세요:
        
        📊 전체 패턴 상세 분석:
        - 주요 감정들의 경향과 빈도 분석
        - 시간대별, 요일별 패턴이 있다면 자세히 설명
        - 감정 변화의 특징적인 흐름과 주기성
        - 긍정적/부정적 감정의 비율과 균형
        
        💡 긍정적 발견사항:
        - 개선되고 있는 부분들과 그 이유
        - 잘 관리되고 있는 감정들의 특징
        - 성장의 징후들과 발전 가능성
        - 스트레스 대처 능력의 향상점
        
        🎯 개선 방향과 주의점:
        - 주의 깊게 살펴봐야 할 감정 패턴들
        - 반복되는 부정적 패턴의 원인 분석
        - 감정 조절이 어려운 상황들의 공통점
        - 예방할 수 있는 감정적 어려움들
        
        🌟 맞춤 조언과 실천 방안:
        - 당신만의 감정 관리 전략과 방법
        - 일상에서 바로 적용할 수 있는 구체적 팁
        - 단계별 감정 개선 실행 계획
        - 장기적 감정 건강을 위한 생활 습관 추천
        
        💝 격려와 희망 메시지:
        - 현재 상황에 대한 따뜻한 이해와 공감
        - 앞으로의 감정적 성장에 대한 희망적 전망
        - 개인의 강점을 활용한 발전 방향 제시
        
        친근하고 따뜻한 말투로 마치 전문 상담사가 1:1로 깊이 있게 상담해주는 것처럼 
        충분히 길고 상세하게 분석해주세요. 토큰 제한 없이 정말 도움이 되는 분석을 해주세요.
        """
        
        let input: [String: Any] = [
            "prompt": optimizedPrompt,
            "temperature": 0.8,
            "top_p": 0.9,
            "max_tokens": 1500,
            "system_prompt": "따뜻하고 전문적인 심리상담사. 자연스러운 한국어로 매우 상세하고 깊이 있는 분석 제공. 토큰 제한 없이 충분히 길고 상세하게 분석. 하루 1회의 소중한 상담 세션처럼 깊이 있게 분석."
        ]
        
        sendToReplicate(input: input, completion: completion)
    }
    
    // MARK: - ✅ 감정 대화 전용 메서드 - 친근한 말투
    func respondToEmotionQuery(query: String, context: String, completion: @escaping (String?) -> Void) {
        let contextSummary = String(context.suffix(100))
        let optimizedPrompt = """
        이전 대화: \(contextSummary)
        현재 질문: \(query)
        
        친한 친구나 상담사처럼 따뜻하고 자연스러운 말투로 100토큰 이내 응답해주세요.
        
        "아, 그런 마음이시군요" "이해해요" "괜찮아요" 같은 자연스러운 표현을 사용하세요.
        공감 → 위로 → 조언 순서로 완성된 대화를 해주세요.
        """
        
        let input: [String: Any] = [
            "prompt": optimizedPrompt,
            "temperature": 0.9,  // 더 자연스러운 대화를 위해 증가
            "top_p": 0.9,
            "max_tokens": 120,
            "system_prompt": "공감 능력이 뛰어난 친근한 상담사. 자연스러운 대화체. 100토큰 이내."
        ]
        
        sendToReplicate(input: input, completion: completion)
    }
    
    // MARK: - ✅ 빠른 감정 팁 제공 - 친근한 설명
    func getQuickEmotionTip(emotion: String, type: String, completion: @escaping (String?) -> Void) {
        let tipPrompt: String
        
        switch type {
        case "improvement":
            tipPrompt = """
            \(emotion) 이런 감정일 때 도움이 되는 방법들을 친근하게 알려드릴게요! (80토큰 이내)
            
            "이럴 때 이런 방법들이 도움이 될 거예요:
            1. [친근한 설명으로 방법1]
            2. [자연스럽게 방법2] 
            3. [따뜻하게 방법3]"
            
            딱딱한 설명이 아닌, 친구가 조언해주는 느낌으로 완성해주세요.
            """
        case "stress":
            tipPrompt = """
            \(emotion) 상황의 스트레스를 친근하게 관리하는 방법 (80토큰 이내):
            
            "스트레스 받으실 때 이런 것들 해보세요:
            1. [즉시 가능한 방법 - 친근하게]
            2. [장기적 방법 - 따뜻하게]
            3. [예방법 - 자연스럽게]"
            
            상담사가 친근하게 조언하는 느낌으로 완성해주세요.
            """
        case "trend":
            tipPrompt = """
            \(emotion) 패턴을 친근하게 분석해드릴게요 (80토큰 이내):
            
            "최근 패턴을 보면 이런 것 같아요:
            - 원인: [친근하게 설명]
            - 변화: [자연스럽게 설명]
            - 방향: [따뜻하게 제안]"
            
            전문가처럼 딱딱하지 말고, 친한 상담사처럼 말해주세요.
            """
        default:
            tipPrompt = """
            \(emotion) 이런 감정일 때 도움되는 조언을 친근하게 60토큰 이내로 알려드릴게요.
            
            "이럴 때는 이런 것들이 도움이 될 거예요~" 하는 느낌으로
            실용적이면서도 따뜻한 조언을 자연스럽게 완성해주세요.
            """
        }
        
        let input: [String: Any] = [
            "prompt": tipPrompt,
            "temperature": 0.8,  // 자연스러운 표현을 위해 증가
            "top_p": 0.8,
            "max_tokens": 100,
            "system_prompt": "친근하고 따뜻한 라이프 코치. 자연스러운 대화체 사용."
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
