import Foundation

/// AI에 요청할 작업의 종류와 필요 데이터를 정의하는 "작업 명세서"
enum AITask {
    case generalChat(message: String)
    case analyzeEmotionDiary(diaryContent: String)
    case recommendTodo(todos: [String])
    case generateFortune(userInfo: String)
    case recommendSound(emotion: String, situation: String)

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
        }
    }
    
    /// AI 모델에 전달될 최종 사용자 프롬프트를 구성합니다.
    var userPrompt: String {
        switch self {
        case .generalChat(let message):
            return message
        case .analyzeEmotionDiary(let diaryContent):
            return "다음은 내 감정 일기야. 이 내용을 바탕으로 나를 위로하고 힘이 될만한 이야기를 해줘.\n\n\(diaryContent)"
        case .recommendTodo(let todos):
            let todoList = todos.joined(separator: "\n- ")
            return "내 할 일 목록이야. 어떤 것부터 시작하면 좋을지, 그리고 어떻게 하면 더 잘할 수 있을지 조언해줘.\n\n- \(todoList)"
        case .generateFortune(let userInfo):
            return "내 정보는 다음과 같아. 이걸 바탕으로 오늘의 운세를 알려줘.\n\n\(userInfo)"
        case .recommendSound(let emotion, let situation):
            return "나는 지금 \(emotion) 감정을 느끼고 있고, \(situation)에 있어. 이럴 때 어떤 소리를 들으면 좋을까?"
        }
    }
} 