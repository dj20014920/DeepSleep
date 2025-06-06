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
    
    // 대화 히스토리 관리 (캐시 시스템과 분리)
    private var conversationHistory: [String] = []
    private var currentTokenCount = 0
    private var consecutiveFailures = 0

    // MARK: - ✅ 캐시 기반 메시지 전송 (새로운 메서드)
    func sendCachedPrompt(
        prompt: String,
        useCache: Bool,
        estimatedTokens: Int,
        intent: String,
        completion: @escaping (String?) -> Void
    ) {
        // 캐시 사용 여부에 따른 최적화된 파라미터 설정
        let optimizedMaxTokens = getOptimalTokensForCachedRequest(
            baseTokens: getOptimalTokens(for: intent),
            useCache: useCache,
            estimatedTokens: estimatedTokens
        )
        
        let input: [String: Any] = [
            "prompt": prompt,
            "temperature": getTemperature(for: intent),
            "top_p": 0.9,
            "max_tokens": optimizedMaxTokens,
            "system_prompt": getCachedSystemPrompt(for: intent, useCache: useCache)
        ]
        
        #if DEBUG
        print("📤 [CACHED-REQUEST] Intent: \(intent), MaxTokens: \(optimizedMaxTokens), UseCache: \(useCache)")
        #endif
        
        sendToReplicate(input: input, completion: completion)
    }
    
    // ✅ 캐시 기반 프리셋 추천
    func sendCachedPresetRecommendation(
        prompt: String,
        useCache: Bool,
        emotionContext: String,
        completion: @escaping (String?) -> Void
    ) {
        let presetPrompt = buildCachedPresetPrompt(
            cachedPrompt: prompt,
            emotionContext: emotionContext,
            useCache: useCache
        )
        
        let systemPromptForPreset = """
        당신은 사용자의 감정 상태와 주어진 사운드 상세 설명을 기반으로 최적의 사운드 조합을 추천하는 전문 사운드 큐레이터입니다.
        11가지 사운드 카테고리에 대해 각각 0부터 100 사이의 볼륨 값을 추천해야 합니다.
        다중 버전이 있는 사운드('비', '키보드')의 경우, 추천하는 버전 이름(예: V1, V2)도 함께 명시해주세요. (예: 비:75(V2))
        감정에 깊이 공감하며, 창의적이고 효과적인 사운드 프리셋을 제안해주세요.
        """

        let input: [String: Any] = [
            "prompt": presetPrompt,
            "temperature": 0.4, // 약간 더 창의적인 답변 유도
            "top_p": 0.85,
            "max_tokens": useCache ? 200 : 350,  // 상세 설명 추가로 토큰 증가, 캐시 시 더 효율적
            "system_prompt": systemPromptForPreset
        ]
        
        #if DEBUG
        print("🎵 [CACHED-PRESET] UseCache: \(useCache), Emotion: \(emotionContext)")
        if !useCache {
            print("--- 상세 프롬프트 시작 ---")
            print(presetPrompt)
            print("--- 상세 프롬프트 끝 ---")
        }
        #endif
        
        sendToReplicate(input: input, completion: completion)
    }
    
    // ✅ 캐시 사용 시 최적 토큰 수 계산
    private func getOptimalTokensForCachedRequest(baseTokens: Int, useCache: Bool, estimatedTokens: Int) -> Int {
        if useCache {
            // 캐시 사용 시 응답 토큰만 계산하면 되므로 더 효율적
            return min(baseTokens * 2, 300)
        } else {
            // 새 캐시 생성 시 좀 더 여유있게
            return min(baseTokens, 250)
        }
    }
    
    // ✅ 캐시 기반 시스템 프롬프트 - 자연스러운 대화 강조
    private func getCachedSystemPrompt(for intent: String, useCache: Bool) -> String {
            let basePrompt = getSystemPrompt(for: intent)
            
            if useCache {
                return basePrompt + """
                
                추가: 1주일 대화맥락 기억, 연속성 대화, 완성된 문장, 번호나 목록 금지, 자연스러운 문단, 적절한 이모지.
                """
            } else {
                return basePrompt + """
                
                추가: 새로운 대화 시작, 자연스러운 소통, 완성된 문장, 번호나 목록 금지, 친구처럼 대화, 적절한 이모지.
                """
            }
        }
    
    // ✅ 캐시 기반 프리셋 프롬프트 구성
    private func buildCachedPresetPrompt(cachedPrompt: String, emotionContext: String, useCache: Bool) -> String {
        let soundDetails = getSoundDetailsForAIPrompt()
        let soundListString = ["고양이", "바람", "밤", "불", "비", "시냇물", "연필", "우주", "쿨링팬", "키보드", "파도"].joined(separator: ", ")

        // AI가 따라야 할 응답 형식 (버전 정보 포함 가능)
        // 예: [프리셋이름] 카테고리1:값,카테고리2:값,...,카테고리N:값
        // 또는 버전이 없는 경우: [집중하는 오후] 연필:50,쿨링팬:60,키보드:70(V2) (나머지 0으로 간주)
        let responseFormatInstruction = """
        응답은 다음 형식 중 하나를 따라야 합니다:
        1. `[프리셋이름] 카테고리1:값,카테고리2:값,...,카테고리N:값` (모든 11개 카테고리 명시)
        2. `[프리셋이름] 카테고리X:값(버전X),카테고리Y:값,카테고리Z:값(버전Z)` (주요 사운드만 명시, 나머지는 0으로 간주)
        다중 버전 사운드(비, 키보드)는 추천 시 `(V1)` 또는 `(V2)`와 같이 버전을 명시해주세요. (예: `비:75(V2)`)
        11개 사운드 목록: \(soundListString)
        """

        if useCache {
            // 캐시된 맥락이 있을 때 - 간단한 요청
            return """
            \(cachedPrompt)
            
            위 대화 맥락과 현재 감정(\(emotionContext))을 바탕으로 다음 11가지 사운드의 볼륨(0-100)과 필요한 경우 버전(V1/V2)을 추천해주세요.
            사운드 목록: \(soundListString)
            
            \(responseFormatInstruction)
            """
        } else {
            // 새 캐시 생성 시 - 상세한 설명
            return """
            당신은 사용자의 감정 상태(\(emotionContext))에 맞는 최적의 사운드 조합을 추천하는 전문 사운드 큐레이터입니다.
            아래 제공되는 각 사운드 카테고리의 상세 설명을 참고하여, 사용자의 현재 감정을 가장 잘 지원할 수 있는 11가지 사운드의 볼륨(0-100) 조합과,
            다중 버전 사운드('비', '키보드')의 경우 가장 적합한 버전(V1 또는 V2)을 함께 추천해주세요.
            프리셋 이름도 감정과 상황에 맞게 창의적으로 지어주세요.

            \(soundDetails)
            
            \(responseFormatInstruction)
            """
        }
    }
    
    // AI 프롬프트에 사용될 사운드 상세 정보를 반환하는 함수
    private func getSoundDetailsForAIPrompt() -> String {
        let soundCategories = ["고양이", "바람", "밤", "불", "비", "시냇물", "연필", "우주", "쿨링팬", "키보드", "파도"]
        
        return """
        11가지 사운드: \(soundCategories.joined(separator: ", "))
        
        기본 9개: 고양이(편안함), 바람(집중), 밤(수면), 불(안정), 시냇물(휴식), 연필(창작), 우주(명상), 쿨링팬(차단), 파도(긴장완화)
        
        다중버전 2개: 비(V1일반/V2창문), 키보드(V1메카/V2멤브)
        
        중요: 비/키보드 추천시 반드시 버전 명시. 예: 비:80(V2), 키보드:50(V1)
        """
    }
    
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

    // MARK: - ✅ 기존 sendPrompt (호환성 유지)
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
    
    // ✅ 최적화된 프롬프트 빌더 - 자연스러운 말투 강조 + 이모지 사용 추가
    private func buildOptimizedPrompt(message: String, intent: String) -> String {
            switch intent {
            case "diary_analysis":
                return """
                일기분석: \(message)
                
                따뜻하고 친근한 말투로 분석해주세요. 완성된 문장으로 끝내고 적절한 이모지 사용.
                순서: 공감→분석→조언→희망적 마무리
                """
                
            case "pattern_analysis":
                return """
                감정패턴분석: \(message)
                
                상세하고 깊이 있게 분석해주세요. 완성된 결론으로 마무리하고 적절한 이모지 사용.
                포함: 감정패턴 해석→긍정변화 발견→개선점→실용조언→장기전략
                """
                
            case "diary_chat", "analysis_chat", "advice_chat":
                return """
                대화: \(message)
                
                친근하고 따뜻한 말투로 자연스럽게 대화. 완성된 문장으로 끝내고 번호나 목록 금지.
                공감→편안한 조언→이모지 사용→따뜻한 마무리
                """
                
            case "casual_chat":
                return """
                일상대화: \(message)
                
                친구처럼 편안하게 대화. 완성된 문장으로 끝내고 목록 금지.
                친근한 표현→공감→격려→이모지 사용→따뜻한 마무리
                """
                
            case "diary":
                return """
                일기대화: \(message)
                
                충분히 들어주는 마음으로 응답. 완성된 문장으로 끝내고 따뜻한 이모지 사용.
                깊은 공감→위로→필요시 조언→따뜻한 마무리
                """
                
            case "recommendPreset":
                return """
                프리셋추천: \(message)
                
                12가지 사운드 조합 추천. 완성된 추천으로 끝내기.
                형식: [프리셋명] Rain:값,Thunder:값,Ocean:값,Fire:값,Steam:값,WindowRain:값,Forest:값,Wind:값,Night:값,Lullaby:값,Fan:값,WhiteNoise:값
                볼륨: 0-100
                """
                
            default:
                return """
                요청: \(message)
                
                친근하고 따뜻한 말투로 도움되는 응답. 완성된 문장으로 끝내고 목록 금지.
                이해공감→실질적 조언→격려→이모지 사용→자연스러운 마무리
                """
            }
        }

    // ✅ Intent별 최적 토큰 수 - 답변이 잘리지 않도록 충분히 증가
    private func getOptimalTokens(for intent: String) -> Int {
            switch intent {
            case "pattern_analysis": return 2500
            case "diary_analysis": return 800
            case "diary": return 800
            case "diary_chat", "analysis_chat", "advice_chat": return 750
            case "casual_chat": return 600
            case "recommendPreset": return 600
            default: return 750
            }
    }
    
    // ✅ Intent별 최적 Temperature - 자연스러운 대화를 위해 증가
    private func getTemperature(for intent: String) -> Double {
        switch intent {
        case "pattern_analysis": return 0.8
        case "diary_analysis": return 0.8
        case "diary_chat", "analysis_chat", "advice_chat": return 0.9
        case "casual_chat": return 0.9
        default: return 0.8
        }
    }
    
    // 시스템 프롬프트 - 이모지 사용 추가
    private func getSystemPrompt(for intent: String) -> String {
            switch intent {
            case "diary_analysis":
                return """
                따뜻하고 친근한 심리상담사. 자연스러운 한국어 대화체 사용.
                적절한 이모지로 친근하게, 완성된 문장으로 끝내기.
                """
                
            case "pattern_analysis":
                return """
                전문적이고 따뜻한 감정분석 전문가.
                깊이 있고 상세한 분석, 자연스러운 한국어, 적절한 이모지 사용.
                완성된 결론으로 마무리.
                """
                
            case "diary_chat", "analysis_chat", "advice_chat":
                return """
                공감 능력 뛰어난 친근한 상담사.
                자연스럽고 감정적으로 풍부한 대화, 번호 매기기나 목록 형태 금지.
                자연스러운 문단으로 대화, 친근한 이모지 사용, 완성된 문장으로 끝내기.
                """
                
            case "casual_chat":
                return """
                친근하고 따뜻한 AI 친구.
                자연스러운 대화, 일상적 표현 사용, 번호 매기기나 목록 형태 금지.
                자연스럽게 이어지는 문단으로 대화, 친근한 이모지 사용, 완성된 문장으로 끝내기.
                """
                
            case "diary":
                return """
                마음을 다독여주는 친한 친구 같은 상담사.
                자연스러운 말투, 따뜻한 이모지 사용, 완성된 위로로 마무리.
                """
                
            case "recommendPreset":
                return """
                감정 기반 사운드 큐레이터.
                정확한 형식으로 12가지 사운드 볼륨 추천, [프리셋명] 시작, 완성된 추천으로 끝내기.
                """
                
            default:
                return """
                친근하고 따뜻한 AI 조력자.
                자연스러운 대화, 일상적 표현 사용, 번호 매기기나 목록 형태 금지.
                자연스럽게 이어지는 문단으로 대화, 적절한 이모지 사용, 완성된 문장으로 끝내기.
                """
            }
        }

    // MARK: - ✅ 최적화된 프리셋 추천 (기존 호환성)
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

    // MARK: - ✅ 감정 분석 전용 최적화 메서드 - 자연스러운 말투 + 이모지 사용
    func analyzeEmotionPattern(data: String, completion: @escaping (String?) -> Void) {
        let optimizedPrompt = """
        감정데이터:\(String(data.prefix(400)))
        
        최근 30일간의 감정 패턴을 매우 상세하고 따뜻하게 분석해주세요.
        하루 1회의 소중한 기회이므로 충분히 길고 깊이 있게 분석해주세요.
        적절한 이모지를 사용해서 분석을 더 친근하고 이해하기 쉽게 만들어주세요:
        
        📊 전체 패턴 상세 분석:
        - 주요 감정들의 경향과 빈도 분석 📈
        - 시간대별, 요일별 패턴이 있다면 자세히 설명 ⏰
        - 감정 변화의 특징적인 흐름과 주기성 🔄
        - 긍정적/부정적 감정의 비율과 균형 ⚖️
        
        💡 긍정적 발견사항:
        - 개선되고 있는 부분들과 그 이유 ✨
        - 잘 관리되고 있는 감정들의 특징 💪
        - 성장의 징후들과 발전 가능성 🌱
        - 스트레스 대처 능력의 향상점 🛡️
        
        🎯 개선 방향과 주의점:
        - 주의 깊게 살펴봐야 할 감정 패턴들 ⚠️
        - 반복되는 부정적 패턴의 원인 분석 🔍
        - 감정 조절이 어려운 상황들의 공통점 🌀
        - 예방할 수 있는 감정적 어려움들 🚫
        
        🌟 맞춤 조언과 실천 방안:
        - 당신만의 감정 관리 전략과 방법 🎯
        - 일상에서 바로 적용할 수 있는 구체적 팁 💡
        - 단계별 감정 개선 실행 계획 📝
        - 장기적 감정 건강을 위한 생활 습관 추천 🌸
        
        💝 격려와 희망 메시지:
        - 현재 상황에 대한 따뜻한 이해와 공감 🤗
        - 앞으로의 감정적 성장에 대한 희망적 전망 🌅
        - 개인의 강점을 활용한 발전 방향 제시 🚀
        
        친근하고 따뜻한 말투로 마치 전문 상담사가 1:1로 깊이 있게 상담해주는 것처럼 
        충분히 길고 상세하게 분석해주세요. 토큰 제한 없이 정말 도움이 되는 분석을 해주세요.
        """
        
        let input: [String: Any] = [
            "prompt": optimizedPrompt,
            "temperature": 0.8,
            "top_p": 0.9,
            "max_tokens": 1500,
            "system_prompt": "따뜻하고 전문적인 심리상담사. 자연스러운 한국어로 매우 상세하고 깊이 있는 분석 제공. 적절한 이모지를 사용해서 분석을 더 친근하고 이해하기 쉽게 제공. 토큰 제한 없이 충분히 길고 상세하게 분석. 하루 1회의 소중한 상담 세션처럼 깊이 있게 분석."
        ]
        
        sendToReplicate(input: input, completion: completion)
    }
    
    // MARK: - ✅ 감정 대화 전용 메서드 - 친근한 말투 + 이모지 사용
    func respondToEmotionQuery(query: String, context: String, completion: @escaping (String?) -> Void) {
        let contextSummary = String(context.suffix(100))
        let optimizedPrompt = """
        이전 대화: \(contextSummary)
        현재 질문: \(query)
        
        친한 친구나 상담사처럼 따뜻하고 자연스러운 말투로 100토큰 이내 응답해주세요.
        적절한 이모지를 자연스럽게 사용해서 대화를 더 친근하게 만들어주세요. (너무 많지 않게)
        
        "아, 그런 마음이시군요 😊" "이해해요 💙" "괜찮아요 ✨" 같은 자연스러운 표현을 사용하세요.
        공감 → 위로 → 조언 순서로 완성된 대화를 해주세요.
        """
        
        let input: [String: Any] = [
            "prompt": optimizedPrompt,
            "temperature": 0.9,  // 더 자연스러운 대화를 위해 증가
            "top_p": 0.9,
            "max_tokens": 120,
            "system_prompt": "공감 능력이 뛰어난 친근한 상담사. 자연스러운 대화체. 적절한 이모지 사용. 100토큰 이내."
        ]
        
        sendToReplicate(input: input, completion: completion)
    }
    
    // MARK: - ✅ 빠른 감정 팁 제공 - 친근한 설명 + 이모지 사용
    func getQuickEmotionTip(emotion: String, type: String, completion: @escaping (String?) -> Void) {
        let tipPrompt: String
        
        switch type {
        case "improvement":
            tipPrompt = """
            \(emotion) 이런 감정일 때 도움이 되는 방법들을 친근하게 알려드릴게요! (80토큰 이내)
            적절한 이모지를 사용해서 더 친근하게 설명해주세요.
            
            "이럴 때 이런 방법들이 도움이 될 거예요 😊:
            1. [친근한 설명으로 방법1] 💡
            2. [자연스럽게 방법2] ✨ 
            3. [따뜻하게 방법3] 💪"
            
            딱딱한 설명이 아닌, 친구가 조언해주는 느낌으로 완성해주세요.
            """
        case "stress":
            tipPrompt = """
            \(emotion) 상황의 스트레스를 친근하게 관리하는 방법 (80토큰 이내):
            적절한 이모지를 사용해서 더 친근하게 설명해주세요.
            
            "스트레스 받으실 때 이런 것들 해보세요 😌:
            1. [즉시 가능한 방법 - 친근하게] 🌸
            2. [장기적 방법 - 따뜻하게] 🌟
            3. [예방법 - 자연스럽게] 🛡️"
            
            상담사가 친근하게 조언하는 느낌으로 완성해주세요.
            """
        case "trend":
            tipPrompt = """
            \(emotion) 패턴을 친근하게 분석해드릴게요 (80토큰 이내):
            적절한 이모지를 사용해서 더 친근하게 설명해주세요.
            
            "최근 패턴을 보면 이런 것 같아요 📊:
            - 원인: [친근하게 설명] 🔍
            - 변화: [자연스럽게 설명] 📈
            - 방향: [따뜻하게 제안] ✨"
            
            전문가처럼 딱딱하지 말고, 친한 상담사처럼 말해주세요.
            """
        default:
            tipPrompt = """
            \(emotion) 이런 감정일 때 도움되는 조언을 친근하게 60토큰 이내로 알려드릴게요.
            적절한 이모지를 사용해서 더 친근하게 설명해주세요.
            
            "이럴 때는 이런 것들이 도움이 될 거예요 😊✨" 하는 느낌으로
            실용적이면서도 따뜻한 조언을 자연스럽게 완성해주세요.
            """
        }
        
        let input: [String: Any] = [
            "prompt": tipPrompt,
            "temperature": 0.8,  // 자연스러운 표현을 위해 증가
            "top_p": 0.8,
            "max_tokens": 100,
            "system_prompt": "친근하고 따뜻한 라이프 코치. 자연스러운 대화체 사용. 적절한 이모지 사용으로 더 친근하게."
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

                    // 🔧 시뮬레이터 테스트용 임시 하드코딩 (실제 배포시 제거 필요)
        let apiToken = "r8_29j0U8UbheNEVv6ju6n54OlTtyCmToJ3eFDzj"
        print("✅ [DEBUG] API 토큰 사용: \(apiToken.prefix(10))...")
        
        guard !apiToken.isEmpty else {
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

        // 🔧 시뮬레이터 테스트용 임시 하드코딩 (실제 배포시 제거 필요)
        let apiToken = "r8_29j0U8UbheNEVv6ju6n54OlTtyCmToJ3eFDzj"
        
        guard !apiToken.isEmpty else {
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
                    if attempts > 0 {
                    self.pollPredictionResult(id: id, attempts: attempts + 1, completion: completion)
                    } else {
                        DispatchQueue.main.async { completion(nil) }
                    }
                }
                return
            }
            
            do {
                let statusResponse = try JSONDecoder().decode(ReplicatePredictionResponse.self, from: data)
                    
                switch statusResponse.status?.lowercased() {
                    case "succeeded":
                    guard let outputContainerValue = statusResponse.output else {
                        print("❌ Output field is nil in 'succeeded' case (pollPredictionResult).")
                        DispatchQueue.main.async { completion(nil) }
                        return
                    }
                    
                    // outputContainerValue는 AnyDecodableValue 타입이어야 합니다.
                    // .value 를 통해 실제 Any 타입의 값을 가져옵니다.
                    let actualOutputAsAny: Any = outputContainerValue.value

                    if let stringArray = actualOutputAsAny as? [String] {
                        print("✅ (Poll) AI Advice (Array<String>): \\(stringArray.joined())")
                        DispatchQueue.main.async { completion(stringArray.joined()) }
                    } else if let stringValue = actualOutputAsAny as? String {
                        print("✅ (Poll) AI Advice (String): \\(stringValue)")
                        DispatchQueue.main.async { completion(stringValue) }
                    } else {
                        print("❌ (Poll) Unexpected output type in 'succeeded' case. Type: \\(type(of: actualOutputAsAny)). Value: \\(String(describing: actualOutputAsAny))")
                        DispatchQueue.main.async { completion(nil) }
                    }
                        
                    case "failed", "canceled":
                    let _ = statusResponse.error ?? "알 수 없는 이유로 실패 또는 취소됨"
                    let _ = statusResponse.logs ?? "N/A"
                    print("❌ (Poll) Prediction 최종 상태 실패/취소: \\(errorMsg), Logs: \\(logsOutput)")
                        DispatchQueue.main.async { completion(nil) }
                        
                    case "starting", "processing":
                    if attempts >= 25 - 1 {
                        print("❌ (Poll) Prediction 타임아웃 (최대 시도 \\(attempts + 1)회 도달)")
                        DispatchQueue.main.async { completion(nil) }
                        return
                    }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            self.pollPredictionResult(id: id, attempts: attempts + 1, completion: completion)
                        }
                        
                    default:
                    let _ = statusResponse.status ?? "N/A"
                    let _ = statusResponse.logs ?? "N/A"
                    print("⚠️ (Poll) Prediction 알 수 없는 상태: \\(currentStatus), Logs: \\(currentLogs)")
                    if attempts >= 25 - 1 {
                        print("❌ (Poll) Prediction 타임아웃 (알 수 없는 상태, 루프 종료)")
                        DispatchQueue.main.async { completion(nil) }
                        return
                    }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            self.pollPredictionResult(id: id, attempts: attempts + 1, completion: completion)
                    }
                }
            } catch {
                print("❌ (Poll) JSON 디코딩 또는 처리 실패: \\(error.localizedDescription)")
                DispatchQueue.main.async { completion(nil) }
            }
        }.resume()
    }

    // MARK: - ✅ 스마트 컨텍스트 압축 (기존 호환성 유지)
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
        
        이전 대화의 맥락을 기억하면서 계속 도움을 드릴게요! 😊
        무엇에 대해 이야기하고 싶으신가요? ✨
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
                completion("죄송해요, 서버가 바쁩니다 😅 잠시 후 다시 시도해주세요.")
            }
        case let e where e.contains("rate"):
            completion("⏰ 잠시 쉬었다가 다시 대화해보세요. (1분 후 재시도) 😊")
        case let e where e.contains("network"):
            completion("🌐 네트워크 연결을 확인해주세요.")
        default:
            completion("일시적인 문제가 발생했습니다 😓 다시 시도해주세요.")
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

    // MARK: - AI 조언 관련 메서드
    private var apiKey: String { // Bundle에서 로드하도록 수정
        guard let key = Bundle.main.object(forInfoDictionaryKey: "REPLICATE_API_TOKEN") as? String, !key.isEmpty else {
            // fatalError() 보다는 오류를 던지거나 기본값을 제공하는 것이 좋습니다.
            // 여기서는 getAIAdvice 시작 시점에 guard 문으로 처리하므로, 여기서는 단순히 빈 문자열 반환 (사용되지 않도록)
            print("🚨 REPLICATE_API_TOKEN이 Info.plist에 설정되지 않았거나 비어있습니다.")
            return ""
        }
        return key
    }

    enum ServiceError: Error, LocalizedError {
        case invalidAPIKey
        case invalidModelIdentifier
        case replicateAPIError(String)
        case predictionFailed(String)
        case predictionProcessingError(String)
        case predictionTimeout
        case outputParsingFailed
        case requestCreationFailed
        case unexpectedResponseStructure

        var errorDescription: String? {
            switch self {
            case .invalidAPIKey: return "Replicate API 키가 유효하지 않거나 설정되지 않았습니다."
            case .invalidModelIdentifier: return "Replicate 모델 식별자 또는 버전이 유효하지 않습니다."
            case .replicateAPIError(let message): return "Replicate API 통신 오류: \(message)"
            case .predictionFailed(let status): return "AI 모델 예측 실패 (상태: \(status)). Replicate 대시보드에서 상세 로그를 확인하세요."
            case .predictionProcessingError(let message): return "AI 모델 입력 처리 오류: \(message)"
            case .predictionTimeout: return "AI 모델 응답 시간 초과."
            case .outputParsingFailed: return "AI 모델 응답에서 결과를 파싱하는 데 실패했습니다."
            case .requestCreationFailed: return "API 요청 객체 생성에 실패했습니다."
            case .unexpectedResponseStructure: return "Replicate API로부터 예상치 못한 응답 구조를 받았습니다."
            }
        }
    }

    /// AI 모델로부터 할 일 관련 조언을 얻습니다. (Replicate API, Polling 방식)
    func getAIAdvice(prompt: String, systemPrompt: String?) async throws -> String {
        let currentApiKey = self.apiKey // 프로퍼티 호출

        guard !currentApiKey.isEmpty else { throw ServiceError.invalidAPIKey }

        // 모델 정보를 sendToReplicate 함수와 동일하게 설정합니다.
        // anthropic/claude-3.5-haiku 모델의 기본 버전을 사용합니다.
        let modelOwnerAndName = "anthropic/claude-3.5-haiku"

        // Prediction 생성 URL (모델 지정 방식)
        // 모델 버전 해시를 명시하지 않고, 해당 모델의 기본 버전을 사용합니다.
        guard let predictionCreationUrl = URL(string: "https://api.replicate.com/v1/models/\(modelOwnerAndName)/predictions") else {
            throw ServiceError.requestCreationFailed
        }

        var request = URLRequest(url: predictionCreationUrl)
        request.httpMethod = "POST"
        request.addValue("Token \(currentApiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")

        var inputPayload: [String: Any] = ["prompt": prompt]
        if let sysPrompt = systemPrompt, !sysPrompt.isEmpty {
            inputPayload["system_prompt"] = sysPrompt
        }
        
        // API 요청 Body 구성 시 'version' 필드를 제거하고 'input'만 전달합니다.
        // sendToReplicate 함수와 동일한 구조로 맞춥니다.
        let body: [String: Any] = [
            "input": inputPayload
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            throw ServiceError.requestCreationFailed
        }
        
        let (initialData, initialResponse) = try await URLSession.shared.data(for: request)

        guard let httpInitialResponse = initialResponse as? HTTPURLResponse else {
            throw ServiceError.replicateAPIError("초기 요청에 대한 유효하지 않은 HTTP 응답입니다.")
        }

        guard httpInitialResponse.statusCode == 201 else { // 201 Created
            var errorDetail = "Prediction 생성 실패 (HTTP \(httpInitialResponse.statusCode))"
            if let responseData = try? JSONDecoder().decode(ReplicateErrorResponse.self, from: initialData) {
                errorDetail += ": \(responseData.detail ?? "알 수 없는 Replicate API 오류")"
            }
            throw ServiceError.replicateAPIError(errorDetail)
        }

        // 2. Prediction 결과 폴링
        guard let predictionResponse = try? JSONDecoder().decode(ReplicatePredictionResponse.self, from: initialData),
              let getUrlString = predictionResponse.urls?.get, // 이 URL은 prediction ID를 포함한 GET 요청 URL
              let getUrl = URL(string: getUrlString) else {
            throw ServiceError.unexpectedResponseStructure
        }
        
        // predictionResponse.id를 사용할 수도 있지만, urls.get 이 더 직접적입니다.
        guard predictionResponse.id != nil else {
             throw ServiceError.unexpectedResponseStructure // ID가 없으면 폴링 불가
        }


        let maxAttempts = 25 // 약 25초 타임아웃 (딜레이 고려)
        let delayBetweenAttempts: TimeInterval = 1.0 // 1초

        for attempt in 0..<maxAttempts {
            // 폴링 요청은 predictionResponse.urls.get으로 받은 URL 사용
            var pollingRequest = URLRequest(url: getUrl)
            pollingRequest.addValue("Token \(currentApiKey)", forHTTPHeaderField: "Authorization")
            pollingRequest.addValue("application/json", forHTTPHeaderField: "Accept") // Content-Type 불필요

            let (pollData, pollResponse) = try await URLSession.shared.data(for: pollingRequest)
            
            guard let httpPollResponse = pollResponse as? HTTPURLResponse, httpPollResponse.statusCode == 200 else {
                // 여기서도 상세 오류 로깅 가능
                let statusCode = (pollResponse as? HTTPURLResponse)?.statusCode ?? 0
                var errorDetail = "Prediction 폴링 실패 (HTTP \(statusCode))"
                 if let responseErrorData = try? JSONDecoder().decode(ReplicateErrorResponse.self, from: pollData) {
                    errorDetail += ": \(responseErrorData.detail ?? "알 수 없는 Replicate API 오류")"
                } else if let responseString = String(data: pollData, encoding: .utf8) {
                     errorDetail += "\nResponse: \(responseString)"
                 }
                print("Poll Error Detail: \(errorDetail)")
                throw ServiceError.replicateAPIError("Prediction 폴링 실패 (HTTP \(statusCode))")
            }

            let statusResponse = try JSONDecoder().decode(ReplicatePredictionResponse.self, from: pollData)

            switch statusResponse.status?.lowercased() {
            case "succeeded":
                guard let outputContainer = statusResponse.output else {
                    print("❌ Output field is nil in 'succeeded' case.")
                    throw ServiceError.outputParsingFailed
                }

                // Claude Haiku는 주로 문자열 배열로 응답합니다.
                if let stringArray = outputContainer.value as? [String] {
                    print("✅ AI Advice (Array<String>): \\(stringArray.joined())")
                    return stringArray.joined()
                } 
                // 간혹 단일 문자열로 올 수도 있습니다.
                else if let stringValue = outputContainer.value as? String {
                    print("✅ AI Advice (String): \\(stringValue)")
                    return stringValue
                } 
                // 만약 예상치 못한 다른 타입이라면
                else {
                    print("❌ Unexpected output type in 'succeeded' case: \\(type(of: outputContainer.value)). Value: \\(outputContainer.value)")
                    throw ServiceError.outputParsingFailed
                }
            case "failed", "canceled":
                let _ = statusResponse.error ?? "알 수 없는 이유로 실패 또는 취소됨"
                let _ = statusResponse.logs ?? "N/A"
                print("❌ Prediction 최종 상태 실패/취소: \\(errorMsg), Logs: \\(logsOutput)")
                throw ServiceError.predictionFailed(statusResponse.status ?? "N/A")
            case "starting", "processing":
                if attempt == maxAttempts - 1 {
                    print("❌ Prediction 타임아웃 (최대 시도 \\(maxAttempts)회 도달)")
                    throw ServiceError.predictionTimeout
                }
                try await Task.sleep(nanoseconds: UInt64(delayBetweenAttempts * 1_000_000_000))
            default:
                let _ = statusResponse.status ?? "알 수 없음"
                let _ = statusResponse.logs ?? "N/A"
                print("⚠️ Prediction 알 수 없는 상태 (in getAIAdvice loop): \\(unknownStatus), Logs: \\(currentLogs)")
                if attempt == maxAttempts - 1 {
                    print("❌ Prediction 타임아웃 (알 수 없는 상태에서 최대 시도 \\(maxAttempts)회 도달)")
                    throw ServiceError.predictionTimeout
                }
                try await Task.sleep(nanoseconds: UInt64(delayBetweenAttempts * 1_000_000_000))
            }
        }
        // 루프가 정상적으로 끝나면 (maxAttempts에 도달했지만 succeeded, failed, canceled가 아닌 경우) 타임아웃으로 처리
        print("❌ Prediction 타임아웃 (루프 종료)")
        throw ServiceError.predictionTimeout
    }
}

// MARK: - Replicate API 응답 구조체들

struct ReplicatePredictionResponse: Decodable {
    let id: String?
    let version: String?
    let urls: ReplicateURLs?
    let createdAt: String?
    let startedAt: String?
    let completedAt: String?
    let status: String?
    let output: AnyDecodableValue?
    let error: String?
    let logs: String?

    enum CodingKeys: String, CodingKey {
        case id, version, urls, status, output, error, logs
        case createdAt = "created_at"
        case startedAt = "started_at"
        case completedAt = "completed_at"
    }
}

struct ReplicateURLs: Decodable {
    let get: String?
    let cancel: String?
}

struct ReplicateErrorResponse: Decodable {
    let detail: String?
}

struct AnyDecodableValue: Decodable {
    let value: Any

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let stringValue = try? container.decode(String.self) {
            value = stringValue
        } else if let arrayValue = try? container.decode([String].self) {
            value = arrayValue
        } else if let intValue = try? container.decode(Int.self) {
            value = intValue
        } else if let doubleValue = try? container.decode(Double.self) {
            value = doubleValue
        } else if let boolValue = try? container.decode(Bool.self) {
            value = boolValue
        } else if let dictionaryValue = try? container.decode([String: AnyDecodableValue].self) {
            value = dictionaryValue.mapValues { $0.value }
        } else if let arrayDictionaryValue = try? container.decode([[String: AnyDecodableValue]].self) {
            value = arrayDictionaryValue.map { dictArray in dictArray.mapValues { $0.value } }
        }
        else {
            throw DecodingError.typeMismatch(AnyDecodableValue.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unsupported type for AnyDecodableValue"))
        }
    }
}
