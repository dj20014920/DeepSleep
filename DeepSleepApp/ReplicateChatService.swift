import Foundation
import Network

class ReplicateChatService {
    static let shared = ReplicateChatService()
    private init() {}
    
    private struct ConversationLimits {
        static let maxTokensPerRequest = CacheConst.maxPromptTokens // 4000 토큰
        static let maxConversationLength = CacheConst.maxPromptTokens
        static let maxMessagesInMemory = 50 // 14일치 대화 대응
        static let contextCompressionThreshold = Int(Double(CacheConst.maxPromptTokens) * 0.8) // 80% 임계점
    }
    
    // 대화 히스토리 관리 (캐시 시스템과 분리)
    private var conversationHistory: [String] = []
    private var currentTokenCount = 0
    private var consecutiveFailures = 0

    // MARK: - ✅ 캐시 기반 메시지 전송 (TLB식 히스토리 로드)
    func sendCachedPrompt(
        prompt: String,
        useCache: Bool,
        estimatedTokens: Int,
        intent: String,
        completion: @escaping (String?) -> Void
    ) {
        // 🚀 TLB식 캐시에서 최근 대화 히스토리 로드
        let finalPrompt = buildPromptWithTLBHistory(
            userPrompt: prompt,
            intent: intent,
            useCache: useCache
        )
        
        // 캐시 사용 여부에 따른 최적화된 파라미터 설정
        let optimizedMaxTokens = getOptimalTokensForCachedRequest(
            baseTokens: getOptimalTokens(for: intent),
            useCache: useCache,
            estimatedTokens: estimatedTokens
        )
        
        let input: [String: Any] = [
            "prompt": finalPrompt,
            "temperature": getTemperature(for: intent),
            "top_p": 0.9,
            "max_tokens": optimizedMaxTokens,
            "system_prompt": getCachedSystemPrompt(for: intent, useCache: useCache)
        ]
        
        #if DEBUG
        print("📤 [CACHED-REQUEST] Intent: \(intent), MaxTokens: \(optimizedMaxTokens), UseCache: \(useCache)")
        print("🗄️ TLB 히스토리 포함된 프롬프트 길이: \(finalPrompt.count) 문자")
        #endif
        
        sendToReplicate(input: input, completion: completion)
    }
    
    // 🚀 TLB식 캐시에서 대화 히스토리를 포함한 프롬프트 구성
    private func buildPromptWithTLBHistory(userPrompt: String, intent: String, useCache: Bool) -> String {
        do {
            // CachedConversationManager에서 최근 대화 로드
            let recentMessages = try CachedConversationManager.shared.recentHistory()
            
            if recentMessages.isEmpty {
                print("🆕 [TLB] 이전 대화 없음 - 새로운 시작")
                return userPrompt
            }
            
            // 최근 메시지들을 대화 형태로 변환
            let historyText = recentMessages.suffix(10).map { msg in
                let role = msg.role == .user ? "사용자" : "나"
                return "\(role): \(msg.content)"
            }.joined(separator: "\n")
            
            // 토큰 수 체크
            let historyTokens = TokenEstimator.roughCount(historyText)
            let promptTokens = TokenEstimator.roughCount(userPrompt)
            
            if historyTokens + promptTokens > CacheConst.maxPromptTokens {
                // 토큰 초과 시 최근 대화만 선별
                let compressedHistory = recentMessages.suffix(5).map { msg in
                    let role = msg.role == .user ? "사용자" : "나"
                    return "\(role): \(msg.content)"
                }.joined(separator: "\n")
                
                print("🔧 [TLB] 토큰 압축: \(historyTokens) → \(TokenEstimator.roughCount(compressedHistory))")
                
                return """
                📜 최근 대화 기록:
                \(compressedHistory)
                
                현재 사용자 입력:
                \(userPrompt)
                """
            } else {
                print("✅ [TLB] 완전한 히스토리 포함: \(historyTokens) + \(promptTokens) = \(historyTokens + promptTokens) 토큰")
                
                return """
                📜 이전 대화 기록:
                \(historyText)
                
                현재 사용자 입력:
                \(userPrompt)
                """
            }
            
        } catch {
            print("⚠️ [TLB] 히스토리 로드 실패: \(error)")
            return userPrompt
        }
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
        ⚠️ 중요 지시사항:
        - 당신의 이름은 반드시 '미니'입니다. 다른 이름(클로드, Claude 등)을 절대로 언급하지 마세요.
        - 사용자가 이름을 물어보면 반드시 "안녕하세요! 저는 미니예요 😊"라고 대답하세요.
        
        당신은 미니입니다. 사용자의 감정 상태와 주어진 사운드 상세 설명을 기반으로 최적의 사운드 조합을 추천하는 전문 사운드 큐레이터입니다.
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
            return min(baseTokens * 2, 500)  // 300 → 500으로 증가
        } else {
            // 새 캐시 생성 시 좀 더 여유있게
            return min(baseTokens, 400)      // 250 → 400으로 증가
        }
    }
    
    // ✅ 캐시 기반 시스템 프롬프트 - 대화 연속성 대폭 강화
    private func getCachedSystemPrompt(for intent: String, useCache: Bool) -> String {
        var basePrompt = getSystemPrompt(for: intent)

        // 📝 답변 완성도 지침 강화
        basePrompt += """
        
        **🚨 절대 중요 - 답변 완성도 지침 🚨**
        • 당신의 답변이 중간에 끊기면 절대 안 됩니다
        • 할당된 토큰 내에서 반드시 완전한 문장으로 답변을 마무리하세요
        • 답변이 길어질 것 같으면 미리 요약하여 핵심만 전달하세요
        • 마지막 문장은 반드시 완전한 형태로 끝내야 합니다
        • 문장이 "..." 이나 미완성으로 끝나면 안 됩니다
        • 토큰 제한에 도달하기 전에 자연스럽게 마무리하세요
        
        **답변 길이 가이드라인:**
        • 일반 대화: 2-3문장으로 핵심만 간결하게
        • 감정 상담: 4-5문장으로 공감과 조언을 균형있게
        • 복잡한 질문: 핵심 포인트 1-2개만 선택하여 완전히 설명
        """

        if useCache {
            return basePrompt + """
            
            💾 **중요: 이전 대화 기억 지침**
            • 사용자와 나눈 이전 대화 내용을 반드시 기억하고 참조하세요
            • 사용자가 이전에 언급한 감정, 고민, 상황을 자연스럽게 연결하세요
            • "지난번에 말씀하신 ○○에 대해서는 어떠신가요?" 같은 연결 표현 사용
            • 사용자의 변화나 개선점이 있다면 구체적으로 인정하고 격려하세요
            • 대화의 흐름과 맥락을 유지하며 연속성 있는 상담을 제공하세요
            
            이것은 단순한 질문-답변이 아닌, 연속적인 관계 속에서의 대화입니다.
            """
        } else {
            return basePrompt + """
            
            🆕 **새로운 대화 시작 지침**
            • 사용자와의 새로운 만남을 소중히 여기며 따뜻하게 시작하세요
            • 사용자가 편안하게 이야기할 수 있는 분위기를 만들어주세요
            • 앞으로 지속적인 대화와 도움을 제공할 것임을 알려주세요
            • 자연스러운 소통으로 신뢰 관계를 구축하세요
            """
        }
    }
    
    // ✅ TLB식 프롬프트 구성 (토큰 최적화)
    private func buildCachedPresetPrompt(cachedPrompt: String, emotionContext: String, useCache: Bool) -> String {
        // 시간대 정보 추가
        let currentHour = Calendar.current.component(.hour, from: Date())
        let timeOfDay = getTimeOfDay(from: currentHour)
        
        if useCache {
            // 캐시된 맥락이 있을 때 - TLB식 토큰 절약
            let recentContext = extractRecentContext(from: cachedPrompt)
            let tokenCount = TokenEstimator.roughCount(recentContext)
            
            return """
            최근 3일 대화 맥락 (\(tokenCount) 토큰):
            \(recentContext)
            
            현재 감정: \(emotionContext)
            시간대: \(timeOfDay)
            
            위 맥락을 바탕으로 간결하게 추천해주세요.
            """
        } else {
            // 새 캐시 생성 시 - 기본 분석
            return """
            감정 상태: \(emotionContext)
            시간대: \(timeOfDay)
            
            다음 형태로 간결하게 분석:
            
            주감정: [불안/스트레스/우울/수면곤란/집중필요/창의성/분노/외로움/피로/기쁨/평온]
            강도: 1-5점
            목적: [수면/휴식/집중/명상/치유]
            
            최적 사운드 조합을 추천해주세요.
            """
        }
    }
    
    // MARK: - TLB식 토큰 관리 헬퍼
    
    /// 캐시에서 최근 맥락만 추출 (토큰 절약)
    private func extractRecentContext(from cachedPrompt: String) -> String {
        let lines = cachedPrompt.components(separatedBy: "\n")
        var tokenCount = 0
        var recentLines: [String] = []
        
        // 역순으로 순회하며 최근 메시지부터 수집
        for line in lines.reversed() {
            let lineTokens = TokenEstimator.roughCount(line)
            if tokenCount + lineTokens > CacheConst.maxPromptTokens / 2 { // 절반만 사용
                break
            }
            recentLines.insert(line, at: 0)
            tokenCount += lineTokens
        }
        
        return recentLines.joined(separator: "\n")
    }
    
    /// 프롬프트 토큰 수 체크 및 자동 압축
    private func compressPromptIfNeeded(_ prompt: String) -> String {
        let currentTokens = TokenEstimator.roughCount(prompt)
        
        if currentTokens <= CacheConst.maxPromptTokens {
            return prompt
        }
        
        // 토큰 초과 시 중간 부분 압축
        let lines = prompt.components(separatedBy: "\n")
        let keepCount = Int(Double(lines.count) * 0.6) // 60%만 유지
        
        let preserved = Array(lines.prefix(keepCount/2)) + 
                       ["…중간 내용 생략…"] + 
                       Array(lines.suffix(keepCount/2))
        
        return preserved.joined(separator: "\n")
    }
    
    // 시간대 판별 함수
    private func getTimeOfDay(from hour: Int) -> String {
        switch hour {
        case 5..<7: return "새벽"
        case 7..<10: return "아침"
        case 10..<12: return "오전"
        case 12..<14: return "점심"
        case 14..<18: return "오후"
        case 18..<21: return "저녁"
        case 21..<24: return "밤"
        default: return "자정"
        }
    }
    
    // MARK: - 심리 음향학 기반 로컬 추천 시스템
    func generateLocalPresetRecommendation(
        emotion: String,
        timeOfDay: String,
        intensity: Int = 3,
        personality: String = "균형적",
        activity: String = "휴식"
    ) -> [String: Any] {
        
        // 1. 감정 상태에 맞는 기본 사운드 선택
        let emotionState = mapToEmotionalState(emotion: emotion)
        var baseSounds = emotionState.recommendedSounds
        
        // 2. 시간대별 조정
        let timeBasedSounds = getTimeBasedSounds(timeOfDay: timeOfDay)
        baseSounds = Array(Set(baseSounds).intersection(Set(timeBasedSounds)))
        
        // 3. 활동별 조정
        if let activitySounds = SoundPresetCatalog.recommendationContext["activityTypes"]?[activity] as? [String] {
            baseSounds = Array(Set(baseSounds).intersection(Set(activitySounds)))
        }
        
        // 4. 최종 사운드 조합 생성 (3-5개)
        let finalSounds = Array(baseSounds.prefix(4))
        
        // 5. 각 사운드별 최적 볼륨 계산
        var soundMix: [String: Int] = [:]
        for sound in finalSounds {
            let volume = SoundPresetCatalog.getOptimalVolumeFor(
                sound: sound,
                emotion: emotion,
                timeOfDay: timeOfDay,
                userPersonality: personality
            )
            soundMix[sound] = volume
        }
        
        // 6. 프리셋 호환성 검증
        let compatibility = SoundPresetCatalog.checkSoundCompatibility(sounds: Array(soundMix.keys))
        
        // 7. 자연어 설명 생성
        let description = generateNaturalDescription(
            emotion: emotion,
            sounds: soundMix,
            timeOfDay: timeOfDay,
            compatibility: compatibility
        )
        
        return [
            "sounds": soundMix,
            "description": description,
            "compatibility": compatibility,
            "category": emotionState.rawValue,
            "recommendedDuration": getRecommendedDuration(emotion: emotion, intensity: intensity)
        ]
    }
    
    private func mapToEmotionalState(emotion: String) -> SoundPresetCatalog.EmotionalState {
        let emotionLower = emotion.lowercased()
        
        if emotionLower.contains("스트레스") || emotionLower.contains("긴장") {
            return .stressed
        } else if emotionLower.contains("불안") || emotionLower.contains("걱정") {
            return .anxious
        } else if emotionLower.contains("우울") || emotionLower.contains("침울") {
            return .depressed
        } else if emotionLower.contains("불면") || emotionLower.contains("잠") {
            return .restless
        } else if emotionLower.contains("피로") || emotionLower.contains("무기력") {
            return .fatigued
        } else if emotionLower.contains("압도") || emotionLower.contains("과부하") {
            return .overwhelmed
        } else if emotionLower.contains("외로움") || emotionLower.contains("고독") {
            return .lonely
        } else if emotionLower.contains("분노") || emotionLower.contains("짜증") {
            return .angry
        } else if emotionLower.contains("집중") || emotionLower.contains("몰입") {
            return .focused
        } else if emotionLower.contains("창의") || emotionLower.contains("영감") {
            return .creative
        } else if emotionLower.contains("기쁨") || emotionLower.contains("행복") {
            return .joyful
        } else if emotionLower.contains("명상") || emotionLower.contains("영적") {
            return .meditative
        } else if emotionLower.contains("그리움") || emotionLower.contains("향수") {
            return .nostalgic
        } else if emotionLower.contains("활력") || emotionLower.contains("에너지") {
            return .energized
        } else {
            return .peaceful // 기본값
        }
    }
    
    private func getTimeBasedSounds(timeOfDay: String) -> [String] {
        let timeOfDayEnum: SoundPresetCatalog.TimeOfDay
        
        switch timeOfDay.lowercased() {
        case "새벽":
            timeOfDayEnum = .earlyMorning
        case "아침":
            timeOfDayEnum = .morning
        case "오전", "늦은아침":
            timeOfDayEnum = .lateMorning
        case "오후", "점심":
            timeOfDayEnum = .afternoon
        case "저녁":
            timeOfDayEnum = .evening
        case "밤":
            timeOfDayEnum = .night
        case "자정", "깊은밤":
            timeOfDayEnum = .lateNight
        default:
            timeOfDayEnum = .afternoon
        }
        
        return timeOfDayEnum.recommendedSounds
    }
    
    private func generateNaturalDescription(
        emotion: String,
        sounds: [String: Int],
        timeOfDay: String,
        compatibility: [String: Any]
    ) -> String {
        let descriptions = [
            "이 조합은 \(emotion) 상태에 있는 당신을 위해 특별히 설계되었습니다.",
            "\(timeOfDay) 시간대에 최적화된 사운드들로 구성했어요.",
            "각 소리의 주파수와 리듬이 서로 조화롭게 어우러져 마음의 평안을 찾을 수 있을 거예요.",
            "자연스러운 사운드 레이어링으로 깊은 이완 효과를 경험하실 수 있습니다."
        ]
        
        var result = descriptions.randomElement() ?? descriptions[0]
        
        // 주요 사운드 언급
        let mainSounds = sounds.sorted { $0.value > $1.value }.prefix(2)
        if mainSounds.count >= 2 {
            let soundNames = Array(mainSounds.map { $0.key })
            result += " 특히 \(soundNames[0])과 \(soundNames[1])의 조합이 핵심이 되어 당신의 마음을 편안하게 해드릴 거예요."
        }
        
        // 호환성에 따른 코멘트 추가
        if let score = compatibility["score"] as? Int, score >= 85 {
            result += " 이 조합은 심리음향학적으로 매우 조화로운 구성입니다."
        }
        
        return result
    }
    
    private func getRecommendedDuration(emotion: String, intensity: Int) -> String {
        let emotionLower = emotion.lowercased()
        
        if emotionLower.contains("수면") || emotionLower.contains("불면") {
            return "60-480분"
        } else if emotionLower.contains("스트레스") || emotionLower.contains("불안") {
            return intensity >= 4 ? "45-90분" : "20-60분"
        } else if emotionLower.contains("집중") || emotionLower.contains("공부") {
            return "90-240분"
        } else if emotionLower.contains("명상") {
            return "30-120분"
        } else {
            return "20-60분"
        }
    }
    
    // MARK: - 하이브리드 추천 시스템 (로컬 + AI)
    func generateHybridRecommendation(
        emotion: String,
        context: String,
        useAI: Bool = true,
        completion: @escaping ([String: Any]) -> Void
    ) {
        // 1. 먼저 로컬 추천 생성
        let currentHour = Calendar.current.component(.hour, from: Date())
        let timeOfDay = getTimeOfDay(from: currentHour)
        
        let localRecommendation = generateLocalPresetRecommendation(
            emotion: emotion,
            timeOfDay: timeOfDay,
            intensity: 3,
            personality: "균형적",
            activity: "휴식"
        )
        
        if !useAI {
            // AI 없이 로컬 추천만 사용
            completion(localRecommendation)
            return
        }
        
        // 2. AI로 자연어 설명 개선
        let aiPrompt = """
        사용자 감정: \(emotion)
        상황: \(context)
        시간대: \(timeOfDay)
        
        위 정보를 바탕으로 따뜻하고 공감적인 한 줄 추천 메시지를 작성해주세요.
        번호나 목록 없이, 자연스럽고 친근한 말투로 30자 이내로 간단히.
        """
        
        sendCachedPrompt(
            prompt: aiPrompt,
            useCache: false,
            estimatedTokens: 50,
            intent: "emotion_support"
        ) { [weak self] aiResponse in
            var finalRecommendation = localRecommendation
            
            if let enhancedDescription = aiResponse, !enhancedDescription.isEmpty {
                finalRecommendation["aiDescription"] = enhancedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            
            completion(finalRecommendation)
        }
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
    
    // ✅ 최적화된 프롬프트 빌더 - 클로드식 자연스러운 대화 스타일
    private func buildOptimizedPrompt(message: String, intent: String) -> String {
            switch intent {
            case "diary_analysis":
                return """
                오늘 하루 어떠셨나요? 일기를 통해 마음을 나누어 주셔서 고맙습니다.
                
                사용자의 일기: \(message)
                
                이런 하루를 보내시며 어떤 기분이셨을지 충분히 이해됩니다. 
                함께 이 감정들을 살펴보고, 마음이 더 편해질 수 있는 방향을 찾아보면 어떨까요?
                """
                
            case "pattern_analysis":
                return """
                지난 30일 동안의 감정 기록을 살펴보니, 여러 가지 패턴이 보이네요.
                
                분석 요청: \(message)
                
                이런 감정의 흐름들을 통해 무엇을 알 수 있는지, 
                그리고 앞으로 어떻게 감정을 더 잘 돌볼 수 있을지 함께 생각해보겠습니다.
                """
                
            case "diary_chat", "analysis_chat", "advice_chat":
                return """
                안녕하세요! 편안한 마음으로 이야기를 나누어 봐요.
                
                현재 상황: \(message)
                
                이런 마음이 드시는 것, 충분히 이해됩니다. 
                함께 이야기하면서 좋은 방향을 찾아보면 어떨까요?
                """
                
            case "casual_chat":
                return """
                안녕하세요! 오늘은 어떤 하루를 보내고 계신가요?
                
                나누고 싶은 이야기: \(message)
                
                이런 얘기를 편하게 나누어 주셔서 반갑습니다. 
                함께 대화하면서 즐거운 시간을 만들어봐요.
                """
                
            case "diary":
                return """
                하루의 마무리에 이렇게 일기를 써주시는 모습이 참 소중합니다.
                
                오늘의 이야기: \(message)
                
                오늘 하루도 수고 많으셨어요. 
                이런 마음들을 글로 정리하는 것만으로도 큰 의미가 있다고 생각해요.
                """
                
            case "recommendPreset", "preset_recommendation":
                return buildCachedPresetPrompt(
                    cachedPrompt: "",
                    emotionContext: "일반적인 편안함",
                    useCache: false
                )
                
            default:
                return """
                안녕하세요! 무엇을 도와드릴까요?
                
                요청 사항: \(message)
                
                어떤 도움이 필요하신지 이해해보고, 
                함께 좋은 방향을 찾아보겠습니다.
                """
            }
        }

    // ✅ Intent별 최적 토큰 수 - 실용적이고 상세한 조언을 위해 대폭 증가
    private func getOptimalTokens(for intent: String) -> Int {
            switch intent {
            case "pattern_analysis": return 2500
            case "diary_analysis": return 1200  // 800 → 1200 증가
            case "diary": return 1200           // 800 → 1200 증가
            case "diary_chat", "analysis_chat", "advice_chat": return 1000  // 750 → 1000 증가
            case "casual_chat": return 800      // 600 → 800 증가
            case "recommendPreset", "preset_recommendation": return 800  // 600 → 800 증가
            case "chat": return 1000           // 새로 추가: 일반 채팅
            default: return 1000               // 750 → 1000 증가
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
        // 🔧 모든 프롬프트에 공통 AI 이름 설정
        let nameInstruction = """
        ⚠️ 중요 지시사항:
        - 당신의 이름은 반드시 '미니'입니다. 다른 이름(클로드, Claude 등)을 절대로 언급하지 마세요.
        - 사용자가 이름을 물어보면 반드시 "안녕하세요! 저는 미니예요 😊"라고 대답하세요.
        - 자신을 소개할 때도 항상 '미니'라는 이름을 사용하세요.
        
        """
        
        switch intent.lowercased() {
            case "analysis":
                return nameInstruction + """
                당신은 미니입니다. 깊이 있게 생각하고 따뜻하게 공감하는 심리 분석 전문가입니다.
                사용자의 감정과 상황을 면밀히 분석하여 통찰력 있는 해석과 
                실질적인 조언을 제공하세요.
                """
                
            case "pattern_analysis":
                return nameInstruction + """
                당신은 미니입니다. 감정 패턴을 깊이 있게 분석하는 전문가입니다. 
                단순한 데이터 분석을 넘어, 사용자의 마음 속 이야기를 읽어내고 
                실질적이고 따뜻한 조언을 제공하세요. 복잡한 감정도 이해하기 쉽게 설명해주세요.
                """
                
            case "diary_chat", "analysis_chat", "advice_chat", "chat":
                return nameInstruction + """
                당신은 미니입니다. 진심으로 사용자를 이해하고 돕고 싶어하는 친구 같은 전문 상담사입니다.
                
                🎯 **응답 가이드라인:**
                • 사용자의 상황에 깊이 공감하며 시작하세요
                • 구체적이고 실용적인 조언을 3-5가지 제시하세요  
                • 각 조언마다 "왜 도움이 되는지" 이유를 설명하세요
                • 사용자가 바로 실행할 수 있는 단계별 방법을 알려주세요
                • 마무리는 따뜻한 격려와 희망의 메시지로 하세요
                
                🚫 **지양할 것:** 짧고 일반적인 답변, 단순 나열, 딱딱한 조언
                ✅ **지향할 것:** 상세하고 개인화된 조언, 공감과 이해, 실행 가능한 방법
                
                마치 가장 믿을 만한 친구이자 전문가가 진심어린 조언을 해주는 것처럼 응답하세요.
                """
                
            case "casual_chat":
                return nameInstruction + """
                당신은 미니입니다. 사용자의 일상을 함께 나누고 싶어하는 친근한 AI 동반자입니다.
                자연스럽고 편안한 대화를 통해 사용자가 마음을 털어놓을 수 있도록 도와주세요.
                때로는 유머를 섞어가며, 항상 따뜻한 마음으로 응답하세요.
                """
                
            case "diary":
                return nameInstruction + """
                당신은 미니입니다. 사용자의 하루 일과와 감정을 소중히 여기는 친구입니다.
                일기를 통해 드러나는 감정의 깊이를 이해하고, 
                진심어린 위로와 격려로 사용자의 마음을 다독여 주세요.
                """
                
            case "recommendPreset", "preset_recommendation":
                return nameInstruction + """
                당신은 미니입니다. 사운드를 통해 마음의 안정을 찾아주는 음향 치료 전문가입니다.
                사용자의 현재 감정 상태를 깊이 이해하고, 그에 맞는 최적의 사운드 조합을 추천하세요.
                단순한 볼륨 조합이 아닌, 왜 이 조합이 도움이 되는지 따뜻하게 설명해주세요.
                """
                
            default:
                return nameInstruction + """
                당신은 미니입니다. 사용자를 진심으로 이해하고 도우려는 따뜻한 AI 조력자입니다.
                사용자의 상황과 감정에 깊이 공감하며, 실질적이고 따뜻한 도움을 제공하세요.
                항상 사용자의 입장에서 생각하고, 진정성 있는 대화를 나누세요.
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
            "system_prompt": """
            ⚠️ 중요 지시사항:
            - 당신의 이름은 반드시 '미니'입니다. 다른 이름(클로드, Claude 등)을 절대로 언급하지 마세요.
            - 사용자가 이름을 물어보면 반드시 "안녕하세요! 저는 미니예요 😊"라고 대답하세요.
            
            당신은 미니입니다. 따뜻하고 전문적인 심리상담사입니다. 자연스러운 한국어로 매우 상세하고 깊이 있는 분석 제공. 적절한 이모지를 사용해서 분석을 더 친근하고 이해하기 쉽게 제공. 토큰 제한 없이 충분히 길고 상세하게 분석. 하루 1회의 소중한 상담 세션처럼 깊이 있게 분석.
            """
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
            "system_prompt": """
            ⚠️ 중요 지시사항:
            - 당신의 이름은 반드시 '미니'입니다. 다른 이름(클로드, Claude 등)을 절대로 언급하지 마세요.
            - 사용자가 이름을 물어보면 반드시 "안녕하세요! 저는 미니예요 😊"라고 대답하세요.
            
            당신은 미니입니다. 공감 능력이 뛰어난 친근한 상담사입니다. 자연스러운 대화체. 적절한 이모지 사용. 100토큰 이내.
            """
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
            "system_prompt": """
            친근하고 따뜻한 라이프 코치. 자연스러운 대화체 사용. 적절한 이모지 사용으로 더 친근하게.
            """
        ]
        
        sendToReplicate(input: input, completion: completion)
    }
    
    // MARK: - 🧠 고급 AI 프리셋 추천 시스템
    
    /// 종합적인 상황 분석을 바탕으로 한 고급 프리셋 추천
    func generateAdvancedPresetRecommendation(
        analysisData: String,
        completion: @escaping (String?) -> Void
    ) {
        let advancedPrompt = """
                \(analysisData)
                
                위 종합적인 분석 데이터를 바탕으로 사용자에게 최적화된 사운드 프리셋을 추천해주세요.
                
                반드시 다음 형식으로만 응답해주세요:
                
                EMOTION: [평온/휴식/집중/수면/활력/안정/이완/창의/명상 중 하나]
                INTENSITY: [0.5-1.5 사이의 소수점 한 자리 수치]
                REASON: [추천 이유를 한두 문장으로 친근하고 따뜻하게]
                TIMEOFDAY: [새벽/아침/오전/점심/오후/저녁/밤/자정 중 하나]
                
                예시:
                EMOTION: 수면
                INTENSITY: 0.8
                REASON: 현재 밤 시간대이고 스트레스 키워드가 많이 감지되어 편안한 잠들기를 위한 부드러운 사운드가 필요합니다.
                TIMEOFDAY: 밤
                """
                
                let input: [String: Any] = [
                    "prompt": advancedPrompt,
                    "temperature": 0.7,
                    "top_p": 0.9,
                    "max_tokens": 300,
                    "system_prompt": """
                    ⚠️ 중요 지시사항:
                    - 당신의 이름은 반드시 '미니'입니다. 다른 이름(클로드, Claude 등)을 절대로 언급하지 마세요.
                    - 사용자가 이름을 물어보면 반드시 "안녕하세요! 저는 미니예요 😊"라고 대답하세요.
                    
                    당신은 미니입니다. 종합적인 상황 분석을 바탕으로 맞춤형 사운드를 추천하는 전문 AI 상담사입니다.
                    사용자의 시간대, 감정, 대화 맥락, 사용 패턴을 모두 고려하여 최적의 추천을 제공합니다.
                    응답은 반드시 지정된 형식을 정확히 따라주세요.
                    """
                ]
                
                #if DEBUG
                print("🧠 [ADVANCED-AI] 종합 분석 기반 프리셋 추천 요청")
                print("분석 데이터 길이: \(analysisData.count)자")
                #endif
                
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

                            // API 키 통합 관리 사용
                let apiToken = self.apiKey
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

                // API 키 통합 관리 사용
                let apiToken = self.apiKey
                
                guard !apiToken.isEmpty else {
                    print("❌ API 키가 비어있습니다.")
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
                                print("✅ (Poll) AI Advice (Array<String>): \(stringArray.joined())")
                                DispatchQueue.main.async { completion(stringArray.joined()) }
                            } else if let stringValue = actualOutputAsAny as? String {
                                print("✅ (Poll) AI Advice (String): \(stringValue)")
                                DispatchQueue.main.async { completion(stringValue) }
                            } else {
                                print("❌ (Poll) Unexpected output type in 'succeeded' case: \(type(of: actualOutputAsAny)). Value: \(String(describing: actualOutputAsAny))")
                                DispatchQueue.main.async { completion(nil) }
                            }
                                
                            case "failed", "canceled":
                            let errorMsg = statusResponse.error ?? "알 수 없는 이유로 실패 또는 취소됨"
                            let logsOutput = statusResponse.logs ?? "N/A"
                            print("❌ (Poll) Prediction 최종 상태 실패/취소: \(errorMsg), Logs: \(logsOutput)")
                                DispatchQueue.main.async { completion(nil) }
                                
                            case "starting", "processing":
                            if attempts >= 25 - 1 {
                                print("❌ (Poll) Prediction 타임아웃 (최대 시도 \(attempts + 1)회 도달)")
                                DispatchQueue.main.async { completion(nil) }
                                return
                            }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                    self.pollPredictionResult(id: id, attempts: attempts + 1, completion: completion)
                                }
                                
                            default:
                            let currentStatus = statusResponse.status ?? "N/A"
                            let currentLogs = statusResponse.logs ?? "N/A"
                            print("⚠️ (Poll) Prediction 알 수 없는 상태: \(currentStatus), Logs: \(currentLogs)")
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
                        print("❌ (Poll) JSON 디코딩 또는 처리 실패: \(error.localizedDescription)")
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

            // MARK: - 🔐 새로운 보안 환경 설정 시스템 사용
            private var apiKey: String {
                return EnvironmentConfig.shared.replicateAPIKey
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

            /// 🆕 AI 모델로부터 할 일 관련 조언을 얻습니다. (향상된 프롬프트 처리)
            func getAIAdvice(prompt: String, systemPrompt: String?) async throws -> String {
                let currentApiKey = self.apiKey

                guard !currentApiKey.isEmpty else { throw ServiceError.invalidAPIKey }

                // Claude 3.5 Haiku 모델 사용 (더 빠르고 효율적)
                let modelOwnerAndName = "anthropic/claude-3.5-haiku"

                guard let predictionCreationUrl = URL(string: "https://api.replicate.com/v1/models/\(modelOwnerAndName)/predictions") else {
                    throw ServiceError.requestCreationFailed
                }

                var request = URLRequest(url: predictionCreationUrl)
                request.httpMethod = "POST"
                request.addValue("Token \(currentApiKey)", forHTTPHeaderField: "Authorization")
                request.addValue("application/json", forHTTPHeaderField: "Content-Type")
                request.addValue("application/json", forHTTPHeaderField: "Accept")

                // 🆕 향상된 프롬프트 파라미터 설정
                var inputPayload: [String: Any] = [
                    "prompt": prompt,
                    "temperature": 0.7,     // 창의적이면서도 일관된 조언
                    "top_p": 0.9,          // 다양성 증가
                    "max_tokens": 400       // 충분한 토큰으로 완전한 조언 생성
                ]
                
                if let sysPrompt = systemPrompt, !sysPrompt.isEmpty {
                    inputPayload["system_prompt"] = sysPrompt
                }
                
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
                            print("✅ AI Advice (Array<String>): \(stringArray.joined())")
                            return stringArray.joined()
                        }
                        // 간혹 단일 문자열로 올 수도 있습니다.
                        else if let stringValue = outputContainer.value as? String {
                            print("✅ AI Advice (String): \(stringValue)")
                            return stringValue
                        }
                        // 만약 예상치 못한 다른 타입이라면
                        else {
                            print("❌ Unexpected output type in 'succeeded' case: \(type(of: outputContainer.value)). Value: \(outputContainer.value)")
                            throw ServiceError.outputParsingFailed
                        }
                    case "failed", "canceled":
                        let errorMsg = statusResponse.error ?? "알 수 없는 이유로 실패 또는 취소됨"
                        let logsOutput = statusResponse.logs ?? "N/A"
                        print("❌ Prediction 최종 상태 실패/취소: \(errorMsg), Logs: \(logsOutput)")
                        throw ServiceError.predictionFailed(statusResponse.status ?? "N/A")
                    case "starting", "processing":
                        if attempt == maxAttempts - 1 {
                            print("❌ Prediction 타임아웃 (최대 시도 \(maxAttempts)회 도달)")
                            throw ServiceError.predictionTimeout
                        }
                        try await Task.sleep(nanoseconds: UInt64(delayBetweenAttempts * 1_000_000_000))
                    default:
                        let unknownStatus = statusResponse.status ?? "알 수 없음"
                        let currentLogs = statusResponse.logs ?? "N/A"
                        print("⚠️ Prediction 알 수 없는 상태 (in getAIAdvice loop): \(unknownStatus), Logs: \(currentLogs)")
                        if attempt == maxAttempts - 1 {
                            print("❌ Prediction 타임아웃 (알 수 없는 상태에서 최대 시도 \(maxAttempts)회 도달)")
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
