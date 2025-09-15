//
//  AIServiceTypes.swift
//  DeepSleep
//
//  Created by Claude on 2025-07-21.
//  Copyright © 2025 DeepSleep. All rights reserved.
//

import Foundation

// MARK: - 🚀 AI 모델 정의

/// 지원되는 AI 모델
public enum AIModel: String, CaseIterable, Codable {
    case claude = "claude"
    case openAI = "openai"
    case gemini = "gemini"
    case naver = "naver"
    case freeModel = "free_model"  // 통합된 무료 모델 (OpenRouter 순차 폴백)
    case onDevice = "on_device"  // 온디바이스 LLM (Background Assets + llama.cpp)

    var displayName: String {
        switch self {
        case .claude: return "Claude (Anthropic)"
        case .openAI: return "OpenAI GPT-4o Mini"
        case .gemini: return "Google Gemini"
        case .naver: return "Naver HyperCLOVA X"
        case .freeModel: return "무료 AI 모델 (통합)"
        case .onDevice: return "온디바이스 LLM"
        }
    }
}

// MARK: - 🎯 AI 모드 정의

/// AI 동작 모드
public enum AIMode: String, CaseIterable, Codable {
    case generalConversation = "general_conversation"
    case emotionDiaryAnalysis = "emotion_diary_analysis"
    case taskAdvice = "task_advice"
    case taskAdviceOverall = "task_advice_overall"
    case presetRecommendation = "preset_recommendation"
    case monthlyStatistics = "monthly_statistics"
    case fortuneTelling = "fortune_telling"
    case emotionAnalysis = "emotion_analysis"

    var displayName: String {
        switch self {
        case .generalConversation: return "일반 대화"
        case .emotionDiaryAnalysis: return "감정 일기 분석"
        case .taskAdvice: return "할일 조언(개별)"
        case .taskAdviceOverall: return "할일 조언(전체)"
        case .presetRecommendation: return "프리셋 추천"
        case .monthlyStatistics: return "월간 통계"
        case .fortuneTelling: return "운세"
        case .emotionAnalysis: return "감정 분석"
        }
    }

    var recommendedTokenConfig: TokenConfiguration {
        switch self {
        case .generalConversation:
            // 기본값을 256으로 타이트화(구성에서 키가 있으면 우선)
            return TokenConfiguration(
                maxTokens: ConfigReader.int("AI_GENERAL_CONVERSATION_MAX_TOKENS", default: 256)
                    ?? 256,
                temperature: ConfigReader.double(
                    "AI_GENERAL_CONVERSATION_TEMPERATURE", default: 0.85) ?? 0.85
            )
        case .emotionDiaryAnalysis:
            return TokenConfiguration(
                maxTokens: ConfigReader.int("AI_EMOTION_DIARY_ANALYSIS_MAX_TOKENS", default: 1000)
                    ?? 1000,
                temperature: ConfigReader.double(
                    "AI_EMOTION_DIARY_ANALYSIS_TEMPERATURE", default: 0.8) ?? 0.8,
                responseFormat: .text
            )
        case .taskAdvice:
            return TokenConfiguration(
                maxTokens: ConfigReader.int("AI_TASK_ADVICE_MAX_TOKENS", default: 800) ?? 800,
                temperature: ConfigReader.double("AI_TASK_ADVICE_TEMPERATURE", default: 0.75)
                    ?? 0.75
            )
        case .taskAdviceOverall:
            return TokenConfiguration(
                maxTokens: ConfigReader.int("AI_TASK_ADVICE_MAX_TOKENS", default: 800) ?? 800,
                temperature: ConfigReader.double("AI_TASK_ADVICE_TEMPERATURE", default: 0.75)
                    ?? 0.75
            )
        case .presetRecommendation:
            return TokenConfiguration(
                maxTokens: ConfigReader.int("AI_PRESET_RECOMMENDATION_MAX_TOKENS", default: 400)
                    ?? 400,
                temperature: ConfigReader.double(
                    "AI_PRESET_RECOMMENDATION_TEMPERATURE", default: 0.6) ?? 0.6,
                responseFormat: .json
            )
        case .monthlyStatistics:
            return TokenConfiguration(
                maxTokens: ConfigReader.int("AI_MONTHLY_STATISTICS_MAX_TOKENS", default: 700)
                    ?? 700,
                temperature: ConfigReader.double("AI_MONTHLY_STATISTICS_TEMPERATURE", default: 0.4)
                    ?? 0.4,
                responseFormat: .json
            )
        case .fortuneTelling:
            return TokenConfiguration(
                maxTokens: ConfigReader.int("AI_FORTUNE_TELLING_MAX_TOKENS", default: 800) ?? 800,
                temperature: ConfigReader.double("AI_FORTUNE_TELLING_TEMPERATURE", default: 0.9)
                    ?? 0.9
            )
        case .emotionAnalysis:
            return TokenConfiguration(
                maxTokens: ConfigReader.int("AI_EMOTION_ANALYSIS_MAX_TOKENS", default: 400) ?? 400,
                temperature: ConfigReader.double("AI_EMOTION_ANALYSIS_TEMPERATURE", default: 0.5)
                    ?? 0.5,
                responseFormat: .json
            )
        }
    }
}

// MARK: - 🔧 토큰 설정

/// 토큰 설정 구조체
public struct TokenConfiguration: Codable {
    let maxTokens: Int
    let temperature: Double
    let topP: Double?
    let frequencyPenalty: Double?
    let presencePenalty: Double?
    let responseFormat: ResponseFormat?

    init(
        maxTokens: Int,
        temperature: Double = 0.7,
        topP: Double? = nil,
        frequencyPenalty: Double? = nil,
        presencePenalty: Double? = nil,
        responseFormat: ResponseFormat? = nil
    ) {
        self.maxTokens = maxTokens
        self.temperature = temperature
        self.topP = topP
        self.frequencyPenalty = frequencyPenalty
        self.presencePenalty = presencePenalty
        self.responseFormat = responseFormat
    }
}

/// 응답 형식
public enum ResponseFormat: String, Codable {
    case json = "json"
    case text = "text"
    case markdown = "markdown"
}

// MARK: - 📊 AI 응답 구조체

/// 통합 AI 응답
public struct AIResponse: Codable {
    let id: String
    let model: AIModel
    let mode: AIMode
    let content: String
    let metadata: ResponseMetadata
    let usage: TokenUsage
    let timestamp: Date
    let processingTime: Int  // milliseconds
}

/// 응답 메타데이터
public struct ResponseMetadata: Codable {
    let emotionAnalysis: EmotionAnalysis?
    let recommendations: [String]?
    let confidenceScore: Double
    let additionalInfo: [String: Any]

    init(
        emotionAnalysis: EmotionAnalysis?, recommendations: [String]?, confidenceScore: Double,
        additionalInfo: [String: Any]
    ) {
        self.emotionAnalysis = emotionAnalysis
        self.recommendations = recommendations
        self.confidenceScore = confidenceScore
        self.additionalInfo = additionalInfo
    }

    // Codable을 위한 커스텀 구현
    enum CodingKeys: String, CodingKey {
        case emotionAnalysis, recommendations, confidenceScore, additionalInfo
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        emotionAnalysis = try container.decodeIfPresent(
            EmotionAnalysis.self, forKey: .emotionAnalysis)
        recommendations = try container.decodeIfPresent([String].self, forKey: .recommendations)
        confidenceScore = try container.decode(Double.self, forKey: .confidenceScore)

        // additionalInfo는 JSON으로 저장/복원
        if let additionalData = try container.decodeIfPresent(Data.self, forKey: .additionalInfo),
            let decoded = try? JSONSerialization.jsonObject(with: additionalData) as? [String: Any]
        {
            additionalInfo = decoded
        } else {
            additionalInfo = [:]
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(emotionAnalysis, forKey: .emotionAnalysis)
        try container.encodeIfPresent(recommendations, forKey: .recommendations)
        try container.encode(confidenceScore, forKey: .confidenceScore)

        // additionalInfo를 JSON 데이터로 변환
        if let data = try? JSONSerialization.data(withJSONObject: additionalInfo) {
            try container.encode(data, forKey: .additionalInfo)
        }
    }
}

/// 감정 분석 결과
public struct EmotionAnalysis: Codable {
    let primaryEmotion: String
    let intensity: Double  // 0.0 ~ 1.0
    let secondaryEmotions: [String: Double]
    let sentiment: Sentiment
}

/// 감정 극성
public enum Sentiment: String, Codable {
    case positive = "positive"
    case neutral = "neutral"
    case negative = "negative"
}

/// 토큰 사용량
public struct TokenUsage: Codable {
    let promptTokens: Int
    let completionTokens: Int
    let totalTokens: Int
    let estimatedCost: Double
}

// MARK: - 🌊 스트리밍 응답

/// 스트리밍 응답
public struct AIStreamResponse: Codable {
    let id: String
    let delta: String
    let isComplete: Bool
    let metadata: StreamMetadata?
}

/// 스트리밍 메타데이터
public struct StreamMetadata: Codable {
    let tokenCount: Int
    let timestamp: Date
}

// MARK: - 📈 사용량 통계

/// AI 사용량 통계
public struct AIUsageStatistics: Codable {
    let model: AIModel
    let totalRequests: Int
    let totalTokens: Int
    let totalCost: Double
    let averageResponseTime: Double
    let successRate: Double
    let lastUpdated: Date
}

/// 모델 상태
public struct AIModelStatus: Codable {
    let model: AIModel
    let isAvailable: Bool
    let latency: Double
    let errorRate: Double
    let remainingQuota: Int?
    let healthScore: Double  // 0.0 ~ 1.0
}

// MARK: - 🔗 컨텍스트

/// AI 컨텍스트
public struct AIContext: Codable {
    let userId: String
    let sessionId: String
    let conversationHistory: [AIConversationTurn]?
    let userPreferences: UserPreferences?
    let environmentContext: AIEnvironmentContext?

    init(
        userId: String,
        sessionId: String,
        conversationHistory: [AIConversationTurn]? = nil,
        userPreferences: UserPreferences? = nil,
        environmentContext: AIEnvironmentContext? = nil
    ) {
        self.userId = userId
        self.sessionId = sessionId
        self.conversationHistory = conversationHistory
        self.userPreferences = userPreferences
        self.environmentContext = environmentContext
    }
}

/// AI 대화 턴 (PersonaMemoryModel의 ConversationTurn과 구분)
public struct AIConversationTurn: Codable {
    let role: Role
    let content: String
    let timestamp: Date
}

/// 역할
public enum Role: String, Codable {
    case user = "user"
    case assistant = "assistant"
    case system = "system"
}

/// 공통 멀티-메시지 타입 (역할 기반)
/// - 역할: user | assistant | system
/// - ts: 메시지 생성 시각(옵션)
public struct RoleMessage: Codable {
    public let role: Role
    public let content: String
    public let ts: Date?

    public init(role: Role, content: String, ts: Date? = nil) {
        self.role = role
        self.content = content
        self.ts = ts
    }
}

/// 사용자 선호도
public struct UserPreferences: Codable {
    let preferredModel: AIModel?
    let responseStyle: ResponseStyle
    let language: String
    let maxResponseLength: Int?
}

/// 응답 스타일
public enum ResponseStyle: String, Codable {
    case concise = "concise"
    case detailed = "detailed"
    case casual = "casual"
    case formal = "formal"
}

/// AI 환경 컨텍스트 (SuperRecommendationEngine의 EnvironmentContext와 구분)
public struct AIEnvironmentContext: Codable {
    let timeOfDay: String
    let userMood: String?
    let recentActivity: String?
    let sleepPattern: SleepPattern?
}

/// 수면 패턴
public struct SleepPattern: Codable {
    let averageBedtime: String
    let averageWakeTime: String
    let averageSleepDuration: Double
    let sleepQuality: Double  // 0.0 ~ 1.0
}

// MARK: - ❌ 에러 정의

/// 🚨 AI 서비스 에러 (통합 에러 처리 시스템)
public enum AIServiceError: Error, LocalizedError {
    // MARK: - 인증 및 권한 에러
    case unauthorized
    case quotaExceeded(model: AIModel)
    case usageLimitExceeded(String)  // 일일 사용량 제한 초과 (UsageLimitManager 연동)

    // MARK: - 네트워크 및 서버 에러
    case networkError(Error)
    case serverError(statusCode: Int)
    case rateLimitExceeded
    case modelUnavailable(model: AIModel)

    // MARK: - 요청/응답 에러
    case invalidRequest(reason: String)
    case invalidResponse
    case tokenLimitExceeded
    case contentFiltered(reason: String)

    // MARK: - 시스템 에러
    case configurationError(String)
    case timeoutError
    case unknown(Error)

    // MARK: - OpenRouter 관련 에러
    case invalidURL
    case httpError(Int)
    case apiError(Int, String)
    case allModelsFailed([String])

    public var errorDescription: String? {
        switch self {
        // MARK: - 인증 및 권한 에러
        case .unauthorized:
            return "🔐 API 인증이 실패했습니다.\n설정을 확인해주세요."
        case .quotaExceeded(let model):
            return "📊 \(model.displayName) 모델의 할당량을 초과했습니다.\n내일 다시 이용해주세요."
        case .usageLimitExceeded(let message):
            return message  // UsageLimitManager에서 이미 포맷된 메시지

        // MARK: - 네트워크 및 서버 에러
        case .networkError(let error):
            return "🌐 네트워크 연결을 확인해주세요.\n(\(error.localizedDescription))"
        case .serverError(let statusCode):
            return "🔧 서비스에 일시적인 문제가 있습니다.\n(서버 오류 \(statusCode))"
        case .rateLimitExceeded:
            return "⏰ 요청이 너무 많습니다.\n잠시 후 다시 시도해주세요."
        case .modelUnavailable(let model):
            return "🚫 \(model.displayName) 모델을 현재 사용할 수 없습니다.\n다른 모델을 선택해주세요."

        // MARK: - 요청/응답 에러
        case .invalidRequest(let reason):
            return "❌ 요청 형식이 올바르지 않습니다.\n(\(reason))"
        case .invalidResponse:
            return "❓ 서버로부터 유효하지 않은 응답을 받았습니다.\n다시 시도해주세요."
        case .tokenLimitExceeded:
            return "📝 메시지가 너무 깁니다.\n더 짧은 메시지를 보내주세요."
        case .contentFiltered(let reason):
            return "🛡️ 컨텐츠가 필터링되었습니다.\n(\(reason))"

        // MARK: - 시스템 에러
        case .configurationError(let message):
            return "⚙️ 시스템 설정 오류가 발생했습니다.\n(\(message))"
        case .timeoutError:
            return "⏱️ 요청 시간이 초과되었습니다.\n다시 시도해주세요."
        case .unknown(let error):
            return "❓ 알 수 없는 오류가 발생했습니다.\n(\(error.localizedDescription))"

        // MARK: - OpenRouter 관련 에러
        case .invalidURL:
            return "🔗 잘못된 API 주소입니다."
        case .httpError(let code):
            return "🌐 HTTP 오류가 발생했습니다.\n(오류 코드: \(code))"
        case .apiError(let code, let message):
            return "⚠️ API 오류: \(message)\n(코드: \(code))"
        case .allModelsFailed(let models):
            return "❌ 모든 모델 호출 실패\n시도한 모델: \(models.joined(separator: ", "))"
        }
    }

    /// 🎨 사용자 친화적인 짧은 제목
    public var shortTitle: String {
        switch self {
        case .unauthorized: return "인증 실패"
        case .quotaExceeded: return "할당량 초과"
        case .usageLimitExceeded: return "사용량 초과"
        case .networkError: return "네트워크 오류"
        case .serverError: return "서버 오류"
        case .rateLimitExceeded: return "요청 제한"
        case .modelUnavailable: return "모델 사용 불가"
        case .invalidRequest: return "잘못된 요청"
        case .invalidResponse: return "응답 오류"
        case .tokenLimitExceeded: return "메시지 길이 초과"
        case .contentFiltered: return "컨텐츠 필터링"
        case .configurationError: return "설정 오류"
        case .timeoutError: return "시간 초과"
        case .unknown: return "알 수 없는 오류"
        case .invalidURL: return "잘못된 주소"
        case .httpError: return "HTTP 오류"
        case .apiError: return "API 오류"
        case .allModelsFailed: return "모든 모델 실패"
        }
    }

    /// 🔄 복구 제안
    public var recoverySuggestion: String? {
        switch self {
        case .unauthorized:
            return "설정 > API 키를 확인하고 다시 시도해주세요."
        case .quotaExceeded:
            return "내일 00시에 할당량이 초기화됩니다."
        case .usageLimitExceeded:
            return "내일 00시에 사용량이 초기화됩니다."
        case .networkError:
            return "Wi-Fi 또는 모바일 데이터 연결을 확인해주세요."
        case .serverError:
            return "잠시 후 다시 시도하거나 고객센터에 문의해주세요."
        case .rateLimitExceeded:
            return "1분 후에 다시 시도해주세요."
        case .modelUnavailable:
            return "다른 AI 모델을 선택하여 이용해주세요."
        case .invalidRequest:
            return "메시지 내용을 확인하고 다시 시도해주세요."
        case .invalidResponse:
            return "같은 내용으로 다시 시도해주세요."
        case .tokenLimitExceeded:
            return "메시지를 여러 번으로 나누어 보내주세요."
        case .contentFiltered:
            return "다른 표현으로 메시지를 작성해주세요."
        case .configurationError:
            return "앱을 재시작하거나 설정을 확인해주세요."
        case .timeoutError:
            return "네트워크 상태를 확인하고 다시 시도해주세요."
        case .unknown:
            return "문제가 지속되면 고객센터에 문의해주세요."
        case .invalidURL:
            return "OpenRouter API 주소를 확인해주세요."
        case .httpError:
            return "일시적인 네트워크/서버 오류입니다. 잠시 후 다시 시도해주세요."
        case .apiError:
            return "모델 또는 요청 형식을 확인한 뒤 다시 시도해주세요."
        case .allModelsFailed:
            return "설정 화면에서 다른 모델을 선택하거나 잠시 후 다시 시도해주세요."
        }
    }
}

// MARK: - 🔄 AIMode → ConversationType 매핑 Extension

extension AIMode {
    /// AIMode를 ConversationType으로 변환
    public func toConversationType() -> ConversationType {
        switch self {
        case .generalConversation:
            return .general
        case .emotionDiaryAnalysis, .emotionAnalysis:
            return .emotional
        case .taskAdvice, .taskAdviceOverall:
            return .task
        case .presetRecommendation, .monthlyStatistics, .fortuneTelling:
            return .analysis
        }
    }
}

// MARK: - 🔒 보안 관련

/// 보안 검증 결과
public enum SecurityValidationResult {
    case approved(cleanInput: String)
    case flagged(reason: String, cleanInput: String)
    case rejected(reason: String)
}

/// 출력 검증 결과
public enum OutputValidationResult {
    case approved
    case blocked(reason: String)
}

// MARK: - 🎛️ 기존 시스템 연동

/// 대화 유형 (기존 시스템과의 호환성)
public enum ConversationType: String, CaseIterable {
    case general = "general"
    case emotional = "emotional"
    case task = "task"
    case analysis = "analysis"

    public init?(rawValue: String) {
        switch rawValue {
        case "general", "general_conversation":
            self = .general
        case "emotional", "emotion_diary_analysis", "emotion_analysis":
            self = .emotional
        case "task", "task_advice", "task_advice_overall":
            self = .task
        case "analysis", "pattern_analysis", "monthly_statistics":
            self = .analysis
        default:
            return nil
        }
    }
}

/// LLM 서비스 타입 (기존 설정 시스템과의 호환성)
public enum LLMServiceType: String, CaseIterable, Codable {
    case claude = "claude"
    case openAI = "openai"
    case gemini = "gemini"
    case naver = "naver"
    case onDevice = "on_device"
}

// MARK: - 📋 채팅 모드

/// 채팅 모드 타입 정의
/// String 대신 사용하여 타입 안정성 보장
public enum ChatMode: String, CaseIterable, Codable {
    // MARK: - 주요 기능별 컨텍스트
    case generalConversation = "일반대화"
    case emotionDiaryAnalysis = "일기분석"
    case emotionDiaryAnalysisAlt = "감정일기분석"  // 대체 이름
    case emotionAnalysis = "감정분석"
    case taskAdvice = "할일조언"
    case presetRecommendation = "프리셋추천"
    case soundRecommendation = "사운드추천"  // 프리셋추천의 대체 이름
    case monthlyPatternAnalysis = "월간패턴분석"
    case monthlyStatistics = "월간통계"  // 월간패턴분석의 대체 이름
    case fortuneTelling = "운세"
    case feedbackAnalysis = "피드백분석"

    // MARK: - 표시 이름
    public var displayName: String {
        return self.rawValue
    }

    // MARK: - AIMode 매핑
    public var aiMode: AIMode {
        switch self {
        case .generalConversation:
            return .generalConversation
        case .emotionDiaryAnalysis, .emotionDiaryAnalysisAlt:
            return .emotionDiaryAnalysis
        case .emotionAnalysis:
            return .emotionAnalysis
        case .taskAdvice:
            return .taskAdvice
        case .presetRecommendation, .soundRecommendation:
            return .presetRecommendation
        case .monthlyPatternAnalysis, .monthlyStatistics:
            return .monthlyStatistics
        case .fortuneTelling:
            return .fortuneTelling
        case .feedbackAnalysis:
            return .generalConversation  // 피드백은 일반 대화로 처리
        }
    }

    // MARK: - String으로부터 생성 (하위 호환성)
    public static func from(_ string: String) -> ChatMode {
        // 기존 String 값과의 호환성 유지
        return ChatMode.allCases.first { $0.rawValue == string } ?? .generalConversation
    }
}
