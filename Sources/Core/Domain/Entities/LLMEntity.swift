import Foundation

// MARK: - LLM Service Types

/// LLM 서비스 타입 정의
public enum LLMServiceType: String, Codable, CaseIterable, Hashable {
    case claude = "claude"      // Claude 3.5
    case gemini = "gemini"      // Gemini Flash
    case naver = "naver"        // Naver HyperCLOVA X
    case openAI = "openAI"      // OpenAI GPT-4o-mini
    case onDevice = "onDevice"  // iOS 18+ 온디바이스
    
    public var displayName: String {
        switch self {
        case .claude: return "클로드"
        case .gemini: return "잼미니"
        case .naver: return "네이버"
        case .openAI: return "지피티"
        case .onDevice: return "온디바이스 AI"
        }
    }
}

/// 사용자 구독 상태
public enum SubscriptionTier: String, Codable {
    case free = "free"
    case premium = "premium"
    
    var servicePriority: [LLMServiceType] {
        switch self {
        case .free:
            return [.onDevice, .gemini, .claude]
        case .premium:
            return [.claude, .openAI, .gemini, .naver]
        }
    }
    
    var dailyLimits: [LLMServiceType: Int] {
        switch self {
        case .free:
            return [
                .claude: 3,
                .gemini: 50,
                .naver: 10,
                .openAI: 20,
                .onDevice: .max
            ]
        case .premium:
            return [
                .claude: 100,
                .gemini: .max,
                .naver: 500,
                .openAI: 1000,
                .onDevice: .max
            ]
        }
    }
}

/// LLM 요청 설정
public struct LLMRequestConfig: Codable {
    public let serviceType: LLMServiceType
    public let maxTokens: Int
    public let temperature: Double
    public let topP: Double
    public let frequencyPenalty: Double
    public let presencePenalty: Double
    public let systemPrompt: String?
    
    public init(
        serviceType: LLMServiceType = .claude,
        maxTokens: Int = 2000,
        temperature: Double = 0.7,
        topP: Double = 0.9,
        frequencyPenalty: Double = 0.0,
        presencePenalty: Double = 0.0,
        systemPrompt: String? = nil
    ) {
        self.serviceType = serviceType
        self.maxTokens = maxTokens
        self.temperature = temperature
        self.topP = topP
        self.frequencyPenalty = frequencyPenalty
        self.presencePenalty = presencePenalty
        self.systemPrompt = systemPrompt
    }
    
    public static let defaultConfig = LLMRequestConfig()

    public func with(
        serviceType: LLMServiceType? = nil,
        maxTokens: Int? = nil,
        temperature: Double? = nil,
        topP: Double? = nil,
        frequencyPenalty: Double? = nil,
        presencePenalty: Double? = nil,
        systemPrompt: String? = nil
    ) -> LLMRequestConfig {
        return LLMRequestConfig(
            serviceType: serviceType ?? self.serviceType,
            maxTokens: maxTokens ?? self.maxTokens,
            temperature: temperature ?? self.temperature,
            topP: topP ?? self.topP,
            frequencyPenalty: frequencyPenalty ?? self.frequencyPenalty,
            presencePenalty: presencePenalty ?? self.presencePenalty,
            systemPrompt: systemPrompt ?? self.systemPrompt
        )
    }
}

/// LLM 사용 통계
public struct LLMUsageStats: Codable, Equatable {
    public var promptTokens: Int
    public var completionTokens: Int
    public var totalTokens: Int
    public var requestCount: Int
    public var lastUsed: Date
    
    public init(promptTokens: Int = 0, completionTokens: Int = 0, totalTokens: Int = 0, requestCount: Int = 0, lastUsed: Date = .distantPast) {
        self.promptTokens = promptTokens
        self.completionTokens = completionTokens
        self.totalTokens = totalTokens
        self.requestCount = requestCount
        self.lastUsed = lastUsed
    }
    
    public mutating func reset() {
        promptTokens = 0
        completionTokens = 0
        totalTokens = 0
        requestCount = 0
    }
    
    public var usageDescription: String {
        """
        프롬프트 토큰: \(promptTokens)
        응답 토큰: \(completionTokens)
        총 토큰: \(totalTokens)
        요청 수: \(requestCount)
        """
    }

    public var formattedLastUsed: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: lastUsed)
    }
}

/// LLM 서비스 상태
public struct LLMServiceStatus: Codable, Equatable {
    public var isAvailable: Bool
    public var errorMessage: String?
    public var lastChecked: Date
    
    public init(isAvailable: Bool = true, errorMessage: String? = nil, lastChecked: Date = Date()) {
        self.isAvailable = isAvailable
        self.errorMessage = errorMessage
        self.lastChecked = lastChecked
    }
    
    public var statusDescription: String {
        isAvailable ? "사용 가능" : "사용 불가 (\(errorMessage ?? "알 수 없는 오류"))"
    }
}

/// LLM 응답 메타데이터
public struct LLMResponseMetadata: Codable {
    public let modelUsed: LLMServiceType
    public let tokensUsed: Int
    public let processingTime: TimeInterval
    public let cached: Bool
    public let timestamp: Date
    
    public init(
        modelUsed: LLMServiceType,
        tokensUsed: Int,
        processingTime: TimeInterval,
        cached: Bool = false,
        timestamp: Date = Date()
    ) {
        self.modelUsed = modelUsed
        self.tokensUsed = tokensUsed
        self.processingTime = processingTime
        self.cached = cached
        self.timestamp = timestamp
    }
}

/// LLM 에러 타입
public enum LLMError: Error {
    case apiError(String)
    case quotaExceeded
    case networkError
    case invalidResponse
    case tokenLimitExceeded
    case serviceUnavailable
    case unauthorized
    case usageLimitExceeded
    case unsupportedTask
    case unknown
    case unexpectedError(Error)
    case maxRetriesExceeded
    case serviceInitializationError(LLMServiceType, Error)
    
    /// 에러가 재시도 가능한지 여부
    public var isRetryable: Bool {
        switch self {
        case .networkError, .serviceUnavailable, .apiError:
            return true
        case .quotaExceeded, .tokenLimitExceeded, .unauthorized, .usageLimitExceeded, .invalidResponse, .unsupportedTask, .unexpectedError, .maxRetriesExceeded, .serviceInitializationError:
            return false
        case .unknown:
            return true // 알 수 없는 오류는 재시도 가능
        }
    }
    
    public var localizedDescription: String {
        switch self {
        case .apiError(let message):
            return "API 오류: \(message)"
        case .quotaExceeded:
            return "일일 사용량 초과"
        case .networkError:
            return "네트워크 연결 오류"
        case .invalidResponse:
            return "잘못된 응답"
        case .tokenLimitExceeded:
            return "토큰 제한 초과"
        case .serviceUnavailable:
            return "서비스 이용 불가"
        case .unauthorized:
            return "인증 오류"
        case .usageLimitExceeded:
            return "사용량 제한 초과"
        case .unsupportedTask:
            return "현재 서비스에서 지원하지 않는 작업입니다."
        case .unknown:
            return "알 수 없는 오류"
        case .unexpectedError(let error):
            return "예기치 않은 오류: \(error.localizedDescription)"
        case .maxRetriesExceeded:
            return "최대 재시도 횟수 초과"
        case .serviceInitializationError(let serviceType, let error):
            return "서비스 초기화 오류: \(serviceType.displayName), \(error.localizedDescription)"
        }
    }
}

/// LLM 응답
public struct LLMResponse: Codable {
    public let content: String
    public let metadata: LLMResponseMetadata
    
    public init(content: String, metadata: LLMResponseMetadata) {
        self.content = content
        self.metadata = metadata
    }
} 
