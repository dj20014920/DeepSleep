import Foundation
import Combine

// MARK: - 🚀 통합 AI 서비스 프로토콜
/// 모든 AI 서비스를 통합하는 단일 인터페이스
/// 세계 최고 수준의 아키텍처로 설계되었으며, 확장성과 유지보수성을 고려
public protocol UnifiedAIService {
    /// 통합된 메시지 전송 함수
    /// - Parameters:
    ///   - content: 전송할 메시지 내용
    ///   - model: 사용할 AI 모델
    ///   - mode: AI 사용 모드 (감정 분석, 조언, 대화 등)
    ///   - context: 추가 컨텍스트 정보
    ///   - tokenConfig: 토큰 설정 (옵션)
    /// - Returns: AI 응답
    func sendMessage(
        content: String,
        model: AIModel,
        mode: AIMode,
        context: AIContext?,
        tokenConfig: TokenConfiguration?
    ) async throws -> AIResponse
    
    /// 스트리밍 응답을 위한 메시지 전송
    func sendMessageStream(
        content: String,
        model: AIModel,
        mode: AIMode,
        context: AIContext?,
        tokenConfig: TokenConfiguration?
    ) -> AsyncThrowingStream<AIStreamResponse, Error>
    
    /// 모델별 사용량 확인
    func getUsageStatistics(for model: AIModel) async -> AIUsageStatistics
    
    /// 모델 상태 확인
    func checkModelStatus(for model: AIModel) async -> AIModelStatus
}

// MARK: - 🤖 AI 모델 정의
public enum AIModel: String, CaseIterable, Codable {
    case claude = "claude"
    case openAI = "openai"
    case naver = "naver"
    case gemini = "gemini"
    
    /// 모델의 상세 버전 정보
    public enum Version {
        case claude(String = "claude-3-opus-20240229")
        case openAI(String = "gpt-4-turbo-preview")
        case naver(String = "clova-x")
        case gemini(String = "gemini-1.5-pro")
        
        var displayName: String {
            switch self {
            case .claude(let version): return "Claude \(version)"
            case .openAI(let version): return "OpenAI \(version)"
            case .naver(let version): return "Naver \(version)"
            case .gemini(let version): return "Gemini \(version)"
            }
        }
    }
    
    /// 기본 버전
    var defaultVersion: Version {
        switch self {
        case .claude: return .claude()
        case .openAI: return .openAI()
        case .naver: return .naver()
        case .gemini: return .gemini()
        }
    }
    
    /// 모델별 최대 토큰 수
    var maxTokens: Int {
        switch self {
        case .claude: return 200000  // Claude 3 Opus
        case .openAI: return 128000  // GPT-4 Turbo
        case .naver: return 4096     // Clova X
        case .gemini: return 1048576 // Gemini 1.5 Pro
        }
    }
    
    /// 모델별 권장 토큰 수
    var recommendedTokens: Int {
        switch self {
        case .claude: return 4096
        case .openAI: return 4096
        case .naver: return 2048
        case .gemini: return 8192
        }
    }
}

// MARK: - 🎯 AI 사용 모드
public enum AIMode: String, CaseIterable, Codable {
    // 핵심 기능
    case emotionDiaryAnalysis = "emotion_diary"
    case taskAdvice = "task_advice"
    case generalConversation = "general_chat"
    case monthlyStatistics = "monthly_stats"
    case presetRecommendation = "preset_recommend"
    case sleepPatternAnalysis = "sleep_pattern"
    case personalizedInsights = "personalized_insights"
    
    // 추가 기능
    case dreamAnalysis = "dream_analysis"
    case meditationGuide = "meditation_guide"
    case stressManagement = "stress_management"
    case habitFormation = "habit_formation"
    case emotionalSupport = "emotional_support"
    
    /// 모드별 설명
    var description: String {
        switch self {
        case .emotionDiaryAnalysis: return "감정 일기 분석 및 통찰"
        case .taskAdvice: return "할 일 및 생산성 조언"
        case .generalConversation: return "일반 대화 및 상담"
        case .monthlyStatistics: return "월간 통계 및 리포트"
        case .presetRecommendation: return "맞춤형 사운드 프리셋 추천"
        case .sleepPatternAnalysis: return "수면 패턴 분석"
        case .personalizedInsights: return "개인화된 인사이트"
        case .dreamAnalysis: return "꿈 분석 및 해석"
        case .meditationGuide: return "명상 가이드"
        case .stressManagement: return "스트레스 관리"
        case .habitFormation: return "습관 형성 도우미"
        case .emotionalSupport: return "감정적 지원"
        }
    }
    
    /// 모드별 시스템 프롬프트
    var systemPrompt: String {
        switch self {
        case .emotionDiaryAnalysis:
            return """
            당신은 전문적인 감정 분석 상담사입니다. 사용자의 감정 일기를 분석하여 
            깊이 있는 통찰과 실용적인 조언을 제공합니다. 공감적이고 따뜻한 톤을 유지하며,
            사용자의 감정 패턴과 트리거를 파악하여 건설적인 피드백을 제공하세요.
            """
            
        case .taskAdvice:
            return """
            당신은 생산성 전문가이자 라이프 코치입니다. 사용자의 일정과 할 일을 분석하여
            효율적인 작업 방법과 우선순위 설정을 도와줍니다. 실행 가능한 구체적인 조언을
            제공하고, 동기부여가 되는 긍정적인 메시지를 포함하세요.
            """
            
        case .generalConversation:
            return """
            당신은 친근하고 지적인 대화 파트너입니다. 다양한 주제에 대해 자연스럽게
            대화하며, 사용자의 관심사와 감정 상태를 고려하여 적절한 반응을 보입니다.
            유용한 정보와 흥미로운 관점을 제공하면서도 편안한 대화를 유지하세요.
            """
            
        case .monthlyStatistics:
            return """
            당신은 데이터 분석 전문가입니다. 사용자의 월간 활동 데이터를 분석하여
            의미 있는 패턴과 트렌드를 발견합니다. 시각적으로 이해하기 쉽게 설명하고,
            개선을 위한 구체적인 제안을 포함하세요.
            """
            
        case .presetRecommendation:
            return """
            당신은 사운드 테라피 전문가입니다. 사용자의 현재 상태와 선호도를 고려하여
            최적의 수면 사운드 조합을 추천합니다. 각 사운드의 효과와 조합의 시너지를
            과학적 근거와 함께 설명하세요.
            """
            
        case .sleepPatternAnalysis:
            return """
            당신은 수면 전문의입니다. 사용자의 수면 데이터를 분석하여 수면의 질을
            평가하고 개선 방안을 제시합니다. 수면 위생, 생활 습관 개선 등 포괄적인
            조언을 제공하세요.
            """
            
        case .personalizedInsights:
            return """
            당신은 개인화 분석 전문가입니다. 사용자의 모든 데이터를 종합적으로 분석하여
            개인 맞춤형 인사이트를 제공합니다. 숨겨진 패턴을 발견하고, 사용자가
            인지하지 못한 중요한 연결점을 찾아내세요.
            """
            
        case .dreamAnalysis:
            return """
            당신은 꿈 해석 전문가이자 심리학자입니다. 사용자가 기록한 꿈을 분석하여
            잠재의식의 메시지와 심리 상태를 해석합니다. 다양한 해석 관점을 제시하고
            개인적 성장을 위한 통찰을 제공하세요.
            """
            
        case .meditationGuide:
            return """
            당신은 명상 지도자입니다. 사용자의 현재 상태에 맞는 명상 기법을 안내하고,
            마음챙김과 이완을 도와줍니다. 차분하고 안정적인 톤으로 단계별 가이드를
            제공하세요.
            """
            
        case .stressManagement:
            return """
            당신은 스트레스 관리 전문가입니다. 사용자의 스트레스 요인을 파악하고
            효과적인 대처 전략을 제시합니다. 즉각적인 완화 방법과 장기적인 관리
            계획을 모두 포함하세요.
            """
            
        case .habitFormation:
            return """
            당신은 습관 형성 코치입니다. 사용자가 원하는 습관을 만들고 유지할 수 있도록
            과학적인 방법론과 실용적인 전략을 제공합니다. 작은 성공을 축하하고
            지속 가능한 변화를 도와주세요.
            """
            
        case .emotionalSupport:
            return """
            당신은 공감적인 정서 지원 상담사입니다. 사용자의 감정을 깊이 이해하고
            따뜻한 위로와 지지를 제공합니다. 판단하지 않고 경청하며, 사용자가
            자신의 감정을 안전하게 표현할 수 있도록 도와주세요.
            """
        }
    }
    
    /// 모드별 권장 토큰 설정
    var recommendedTokenConfig: TokenConfiguration {
        switch self {
        case .emotionDiaryAnalysis:
            return TokenConfiguration(
                maxTokens: 2000,
                temperature: 0.8,
                topP: 0.95,
                frequencyPenalty: 0.3,
                presencePenalty: 0.2
            )
            
        case .taskAdvice:
            return TokenConfiguration(
                maxTokens: 1500,
                temperature: 0.7,
                topP: 0.9,
                frequencyPenalty: 0.2,
                presencePenalty: 0.1
            )
            
        case .generalConversation:
            return TokenConfiguration(
                maxTokens: 1000,
                temperature: 0.9,
                topP: 0.95,
                frequencyPenalty: 0.5,
                presencePenalty: 0.5
            )
            
        case .monthlyStatistics:
            return TokenConfiguration(
                maxTokens: 3000,
                temperature: 0.5,
                topP: 0.85,
                frequencyPenalty: 0.1,
                presencePenalty: 0.0
            )
            
        case .presetRecommendation:
            return TokenConfiguration(
                maxTokens: 1200,
                temperature: 0.6,
                topP: 0.9,
                frequencyPenalty: 0.2,
                presencePenalty: 0.1
            )
            
        default:
            return TokenConfiguration(
                maxTokens: 1500,
                temperature: 0.7,
                topP: 0.9,
                frequencyPenalty: 0.3,
                presencePenalty: 0.2
            )
        }
    }
}

// MARK: - ⚙️ 토큰 설정
public struct TokenConfiguration: Codable {
    /// 최대 토큰 수
    public let maxTokens: Int
    
    /// 창의성 수준 (0.0 ~ 2.0)
    public let temperature: Double
    
    /// 누적 확률 임계값 (0.0 ~ 1.0)
    public let topP: Double?
    
    /// 반복 억제 (-2.0 ~ 2.0)
    public let frequencyPenalty: Double?
    
    /// 새로운 주제 유도 (-2.0 ~ 2.0)
    public let presencePenalty: Double?
    
    /// 스트리밍 여부
    public let stream: Bool
    
    /// 응답 포맷
    public let responseFormat: ResponseFormat?
    
    public init(
        maxTokens: Int = 1500,
        temperature: Double = 0.7,
        topP: Double? = nil,
        frequencyPenalty: Double? = nil,
        presencePenalty: Double? = nil,
        stream: Bool = false,
        responseFormat: ResponseFormat? = nil
    ) {
        self.maxTokens = maxTokens
        self.temperature = max(0.0, min(2.0, temperature))
        self.topP = topP.map { max(0.0, min(1.0, $0)) }
        self.frequencyPenalty = frequencyPenalty.map { max(-2.0, min(2.0, $0)) }
        self.presencePenalty = presencePenalty.map { max(-2.0, min(2.0, $0)) }
        self.stream = stream
        self.responseFormat = responseFormat
    }
    
    /// 기본 설정
    public static let `default` = TokenConfiguration()
    
    /// 창의적 응답용 설정
    public static let creative = TokenConfiguration(
        temperature: 1.2,
        topP: 0.95,
        frequencyPenalty: 0.5,
        presencePenalty: 0.5
    )
    
    /// 정확한 응답용 설정
    public static let precise = TokenConfiguration(
        temperature: 0.3,
        topP: 0.8,
        frequencyPenalty: 0.1,
        presencePenalty: 0.0
    )
}

// MARK: - 📄 응답 포맷
public enum ResponseFormat: String, Codable {
    case text = "text"
    case json = "json_object"
    case markdown = "markdown"
}

// MARK: - 🎨 AI 컨텍스트
public struct AIContext: Codable {
    /// 사용자 ID
    public let userId: String
    
    /// 현재 감정 상태
    public let currentEmotion: EmotionState?
    
    /// 최근 대화 기록
    public let conversationHistory: [ConversationMessage]?
    
    /// 사용자 프로필 정보
    public let userProfile: UserProfile?
    
    /// 현재 시간대 정보
    public let timeContext: TimeContext?
    
    /// 추가 메타데이터
    public let metadata: [String: Any]?
    
    public init(
        userId: String,
        currentEmotion: EmotionState? = nil,
        conversationHistory: [ConversationMessage]? = nil,
        userProfile: UserProfile? = nil,
        timeContext: TimeContext? = nil,
        metadata: [String: Any]? = nil
    ) {
        self.userId = userId
        self.currentEmotion = currentEmotion
        self.conversationHistory = conversationHistory
        self.userProfile = userProfile
        self.timeContext = timeContext
        self.metadata = metadata
    }
    
    // Codable 구현을 위한 CodingKeys
    private enum CodingKeys: String, CodingKey {
        case userId, currentEmotion, conversationHistory, userProfile, timeContext
    }
    
    // 커스텀 인코딩
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(userId, forKey: .userId)
        try container.encodeIfPresent(currentEmotion, forKey: .currentEmotion)
        try container.encodeIfPresent(conversationHistory, forKey: .conversationHistory)
        try container.encodeIfPresent(userProfile, forKey: .userProfile)
        try container.encodeIfPresent(timeContext, forKey: .timeContext)
    }
    
    // 커스텀 디코딩
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userId = try container.decode(String.self, forKey: .userId)
        currentEmotion = try container.decodeIfPresent(EmotionState.self, forKey: .currentEmotion)
        conversationHistory = try container.decodeIfPresent([ConversationMessage].self, forKey: .conversationHistory)
        userProfile = try container.decodeIfPresent(UserProfile.self, forKey: .userProfile)
        timeContext = try container.decodeIfPresent(TimeContext.self, forKey: .timeContext)
        metadata = nil
    }
}

// MARK: - 💬 대화 메시지
public struct ConversationMessage: Codable {
    public let role: MessageRole
    public let content: String
    public let timestamp: Date
    
    public enum MessageRole: String, Codable {
        case user
        case assistant
        case system
    }
}

// MARK: - 😊 감정 상태
public struct EmotionState: Codable {
    public let primary: String
    public let secondary: String?
    public let intensity: Double  // 0.0 ~ 1.0
    public let confidence: Double // 0.0 ~ 1.0
}

// MARK: - 👤 사용자 프로필
public struct UserProfile: Codable {
    public let age: Int?
    public let gender: String?
    public let preferences: [String: Any]?
    public let sleepGoals: SleepGoals?
    
    private enum CodingKeys: String, CodingKey {
        case age, gender, sleepGoals
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(age, forKey: .age)
        try container.encodeIfPresent(gender, forKey: .gender)
        try container.encodeIfPresent(sleepGoals, forKey: .sleepGoals)
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        age = try container.decodeIfPresent(Int.self, forKey: .age)
        gender = try container.decodeIfPresent(String.self, forKey: .gender)
        sleepGoals = try container.decodeIfPresent(SleepGoals.self, forKey: .sleepGoals)
        preferences = nil
    }
}

// MARK: - 🛌 수면 목표
public struct SleepGoals: Codable {
    public let targetBedtime: String
    public let targetWakeTime: String
    public let targetSleepDuration: Int // 분 단위
}

// MARK: - ⏰ 시간 컨텍스트
public struct TimeContext: Codable {
    public let currentTime: Date
    public let dayOfWeek: String
    public let isWeekend: Bool
    public let isHoliday: Bool
    public let season: String
}

// MARK: - 📤 AI 응답
public struct AIResponse: Codable {
    /// 응답 ID
    public let id: String
    
    /// 사용된 모델
    public let model: AIModel
    
    /// 사용된 모드
    public let mode: AIMode
    
    /// 응답 내용
    public let content: String
    
    /// 응답 메타데이터
    public let metadata: ResponseMetadata
    
    /// 사용량 정보
    public let usage: TokenUsage
    
    /// 응답 생성 시간
    public let timestamp: Date
    
    /// 처리 시간 (밀리초)
    public let processingTime: Int
}

// MARK: - 📊 응답 메타데이터
public struct ResponseMetadata: Codable {
    /// 감정 분석 결과
    public let emotionAnalysis: EmotionAnalysis?
    
    /// 추천 항목들
    public let recommendations: [Recommendation]?
    
    /// 신뢰도 점수
    public let confidenceScore: Double
    
    /// 추가 정보
    public let additionalInfo: [String: String]?
}

// MARK: - 😊 감정 분석
public struct EmotionAnalysis: Codable {
    public let detectedEmotions: [EmotionState]
    public let sentiment: Sentiment
    public let triggers: [String]
    
    public enum Sentiment: String, Codable {
        case positive
        case negative
        case neutral
        case mixed
    }
}

// MARK: - 💡 추천
public struct Recommendation: Codable {
    public let type: RecommendationType
    public let title: String
    public let description: String
    public let priority: Priority
    public let actionItems: [String]?
    
    public enum RecommendationType: String, Codable {
        case sound = "sound"
        case activity = "activity"
        case routine = "routine"
        case meditation = "meditation"
        case other = "other"
    }
    
    public enum Priority: String, Codable {
        case high
        case medium
        case low
    }
}

// MARK: - 📈 토큰 사용량
public struct TokenUsage: Codable {
    public let promptTokens: Int
    public let completionTokens: Int
    public let totalTokens: Int
    public let estimatedCost: Double?
}

// MARK: - 🌊 스트리밍 응답
public struct AIStreamResponse: Codable {
    public let id: String
    public let delta: String
    public let isComplete: Bool
    public let metadata: StreamMetadata?
}

// MARK: - 📊 스트리밍 메타데이터
public struct StreamMetadata: Codable {
    public let tokenCount: Int
    public let timestamp: Date
}

// MARK: - 📊 사용량 통계
public struct AIUsageStatistics: Codable {
    public let model: AIModel
    public let totalRequests: Int
    public let totalTokens: Int
    public let totalCost: Double
    public let averageResponseTime: Double
    public let successRate: Double
    public let lastUpdated: Date
}

// MARK: - 🚦 모델 상태
public struct AIModelStatus: Codable {
    public let model: AIModel
    public let isAvailable: Bool
    public let latency: Double
    public let errorRate: Double
    public let remainingQuota: Int?
    public let healthScore: Double // 0.0 ~ 1.0
}

// MARK: - ❌ AI 서비스 에러
public enum AIServiceError: LocalizedError {
    case invalidAPIKey(model: AIModel)
    case quotaExceeded(model: AIModel)
    case modelUnavailable(model: AIModel)
    case networkError(Error)
    case invalidResponse
    case tokenLimitExceeded
    case contextTooLong
    case rateLimitExceeded
    case unauthorized
    case serverError(statusCode: Int)
    case unknown(Error)
    
    public var errorDescription: String? {
        switch self {
        case .invalidAPIKey(let model):
            return "\(model.rawValue) API 키가 유효하지 않습니다."
        case .quotaExceeded(let model):
            return "\(model.rawValue) 사용량 한도를 초과했습니다."
        case .modelUnavailable(let model):
            return "\(model.rawValue) 모델을 사용할 수 없습니다."
        case .networkError(let error):
            return "네트워크 오류: \(error.localizedDescription)"
        case .invalidResponse:
            return "잘못된 응답 형식입니다."
        case .tokenLimitExceeded:
            return "토큰 제한을 초과했습니다."
        case .contextTooLong:
            return "컨텍스트가 너무 깁니다."
        case .rateLimitExceeded:
            return "요청 속도 제한을 초과했습니다."
        case .unauthorized:
            return "인증에 실패했습니다."
        case .serverError(let statusCode):
            return "서버 오류 (상태 코드: \(statusCode))"
        case .unknown(let error):
            return "알 수 없는 오류: \(error.localizedDescription)"
        }
    }
}

// MARK: - 🔄 재시도 정책
public struct RetryPolicy {
    public let maxAttempts: Int
    public let initialDelay: TimeInterval
    public let maxDelay: TimeInterval
    public let multiplier: Double
    
    public static let `default` = RetryPolicy(
        maxAttempts: 3,
        initialDelay: 1.0,
        maxDelay: 10.0,
        multiplier: 2.0
    )
}
