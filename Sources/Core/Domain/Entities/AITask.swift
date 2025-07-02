import Foundation

/// AI 작업 타입을 나타내는 enum
public enum AITaskType: String, CaseIterable {
    case generalChat
    case analyzeEmotion
    case recommendPreset
    case summarizeDiary
    case analyzeEmotionDiary
    case recommendTodo
    case generateFortune
    case recommendSound
}

/// AI에 요청할 작업의 종류와 필요 데이터를 정의하는 "작업 명세서"
public enum AITask {
    case generalChat(message: String, history: [ChatMessage])
    case analyzeEmotion(text: String)
    case recommendPreset(emotion: String, context: SoundRecommendationContext)
    case summarizeDiary(entries: [String])
    case analyzeEmotionDiary(diaryContent: String)
    case recommendTodo(todos: [String])
    case generateFortune(userInfo: UserInfo)
    case recommendSound(emotion: String, situation: String)

    /// 작업 타입을 반환합니다.
    public var type: AITaskType {
        switch self {
        case .generalChat:
            return .generalChat
        case .analyzeEmotion:
            return .analyzeEmotion
        case .recommendPreset:
            return .recommendPreset
        case .summarizeDiary:
            return .summarizeDiary
        case .analyzeEmotionDiary:
            return .analyzeEmotionDiary
        case .recommendTodo:
            return .recommendTodo
        case .generateFortune:
            return .generateFortune
        case .recommendSound:
            return .recommendSound
        }
    }

    /// 각 작업에 맞는 시스템 프롬프트를 반환합니다.
    var systemPrompt: String {
        switch self {
        case .generalChat:
            // TODO: - 최종 시스템 프롬프트 확정 필요
            return "당신은 사용자의 말을 잘 들어주는 친한 친구입니다. 따뜻하고 다정하게 대화해주세요."
        case .analyzeEmotionDiary:
            return "당신은 심리 상담가입니다. 사용자의 일기 내용을 바탕으로 깊이 공감하고 긍정적인 분석을 제공해주세요. 답변은 항상 한국어로 해주세요."
        case .recommendTodo:
            return "당신은 최고의 생산성 코치입니다. 할 일 목록을 보고, 가장 효율적인 다음 행동을 제안해주세요. 답변은 항상 한국어로 해주세요."
        case .generateFortune:
            return "당신은 미래를 긍정적으로 예측해주는 운세 전문가입니다. 사용자의 정보를 바탕으로 희망적인 오늘의 운세를 알려주세요. 답변은 항상 한국어로 해주세요."
        case .recommendSound:
            return "당신은 소리 추천 전문가입니다. 사용자의 감정과 상황에 맞는 최적의 소리를 추천해주세요. 답변은 항상 한국어로 해주세요."
        case .analyzeEmotion:
            return "당신은 텍스트 감정 분석 전문가입니다. 주어진 텍스트의 감정을 정확하게 분석하고, 그에 따른 통찰을 제공해주세요. 답변은 항상 한국어로 해주세요."
        case .recommendPreset:
            return "당신은 사용자 맞춤형 프리셋 추천 전문가입니다. 사용자의 감정과 상황에 맞는 최적의 프리셋을 추천해주세요. 답변은 항상 한국어로 해주세요."
        case .summarizeDiary:
            return "당신은 일기 요약 전문가입니다. 주어진 일기 내용을 간결하고 핵심적으로 요약해주세요. 답변은 항상 한국어로 해주세요."
        }
    }

    /// 각 작업에 맞는 요청 설정을 반환합니다.
    var requestConfig: LLMRequestConfig {
        switch self {
        case .generalChat:
            return LLMRequestConfig(maxTokens: 1500, temperature: 0.7, topP: 0.9, frequencyPenalty: 0.0, presencePenalty: 0.0)
        case .analyzeEmotionDiary:
            return LLMRequestConfig(maxTokens: 2000, temperature: 0.5, topP: 0.8, frequencyPenalty: 0.0, presencePenalty: 0.0)
        case .recommendTodo:
            return LLMRequestConfig(maxTokens: 500, temperature: 0.8, topP: 0.9, frequencyPenalty: 0.1, presencePenalty: 0.0)
        case .generateFortune:
            return LLMRequestConfig(maxTokens: 800, temperature: 0.9, topP: 0.95, frequencyPenalty: 0.0, presencePenalty: 0.1)
        case .recommendSound:
            return LLMRequestConfig(maxTokens: 300, temperature: 0.6, topP: 0.8, frequencyPenalty: 0.0, presencePenalty: 0.0)
        case .analyzeEmotion:
            return LLMRequestConfig(maxTokens: 500, temperature: 0.5, topP: 0.8, frequencyPenalty: 0.0, presencePenalty: 0.0)
        case .recommendPreset:
            return LLMRequestConfig(maxTokens: 700, temperature: 0.7, topP: 0.9, frequencyPenalty: 0.0, presencePenalty: 0.0)
        case .summarizeDiary:
            return LLMRequestConfig(maxTokens: 1000, temperature: 0.6, topP: 0.8, frequencyPenalty: 0.0, presencePenalty: 0.0)
        }
    }
    
    /// AI 모델에 전달될 최종 사용자 프롬프트를 구성합니다.
    var userPrompt: String {
        switch self {
        case .generalChat(let message, _):
            return message
        case .analyzeEmotion(let text):
            return "Analyze the emotion of the following text: \(text)"
        case .recommendPreset(let emotion, let context):
            return "Recommend a preset for a user feeling \(emotion). Context: Time of day is \(context.timeOfDay), headphones: \(context.isHeadphonesConnected)."
        case .summarizeDiary(let entries):
            return "Summarize the following diary entries: \(entries.joined(separator: "\n---\n"))"
        case .analyzeEmotionDiary(let diaryContent):
            return "다음은 내 감정 일기야. 이 내용을 바탕으로 나를 위로하고 힘이 될만한 이야기를 해줘.\n\n\(diaryContent)"
        case .recommendTodo(let todos):
            return "다음 할 일 목록을 보고, 지금 가장 집중해야 할 일과 그 이유를 추천해줘: \(todos.joined(separator: ", "))"
        case .generateFortune(let userInfo):
            return "내 정보는 다음과 같아. 이걸 바탕으로 오늘의 운세를 알려줘.\n\n\(userInfo.emotionalState)"
        case .recommendSound(let emotion, let situation):
            return "나는 지금 \(emotion) 감정을 느끼고 있고, \(situation)에 있어. 이럴 때 어떤 소리를 들으면 좋을까?"
        }
    }

    /// AI 응답 처리를 위한 메타데이터
    public var metadata: [String: String] {
        switch self {
        case .generalChat, .analyzeEmotion, .summarizeDiary, .analyzeEmotionDiary, .recommendTodo, .generateFortune:
            return [:]
        case .recommendPreset(let emotion, _):
            return ["emotion": emotion]
        case .recommendSound(let emotion, _):
            return ["emotion": emotion]
        }
    }

    public var taskDescription: String {
        switch self {
        case .generalChat:
            return "General user chat"
        case .analyzeEmotion:
            return "Emotion analysis"
        case .recommendPreset:
            return "Sound preset recommendation"
        case .summarizeDiary:
            return "Diary summarization"
        case .analyzeEmotionDiary:
            return "Emotion diary analysis"
        case .recommendTodo:
            return "To-do recommendation"
        case .generateFortune:
            return "Fortune generation"
        case .recommendSound:
            return "Sound recommendation"
        }
    }

    /// 메모리를 사용해야 하는지 여부
    public var shouldUseMemory: Bool {
        switch self {
        case .generalChat, .analyzeEmotionDiary:
            return true
        case .analyzeEmotion, .recommendPreset, .summarizeDiary, .recommendTodo, .generateFortune, .recommendSound:
            return false
        }
    }
    
    /// 메모리를 추가한 새로운 AITask를 반환
    public func with(memory: String) -> AITask {
        switch self {
        case .generalChat(let message, let history):
            let enhancedMessage = "\(memory)\n\n\(message)"
            return .generalChat(message: enhancedMessage, history: history)
        case .analyzeEmotionDiary(let content):
            let enhancedContent = "\(memory)\n\n\(content)"
            return .analyzeEmotionDiary(diaryContent: enhancedContent)
        default:
            return self // 메모리를 사용하지 않는 작업은 그대로 반환
        }
    }
} 
