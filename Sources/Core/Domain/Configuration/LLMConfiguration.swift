import Foundation

/// LLM 설정 모델
public struct LLMConfiguration: Codable {
    // MARK: - Properties
    
    /// API 키
    public let claudeAPIKey: String
    public let geminiAPIKey: String
    public let naverAPIKey: String
    public let openAIAPIKey: String
    
    /// 서비스별 기본 설정
    public let defaultConfigs: [LLMServiceType: LLMRequestConfig]
    
    /// 사용량 제한
    public let quotaLimits: [SubscriptionTier: [LLMServiceType: Int]]
    
    /// 캐시 설정
    public let cacheEnabled: Bool
    public let cacheExpirationInterval: TimeInterval
    
    /// 모니터링 설정
    public let monitoringEnabled: Bool
    public let alertThresholds: [LLMServiceType: [String: Double]]
    
    /// 온디바이스 설정
    public let onDeviceModelName: String
    public let onDeviceModelVersion: String
    
    // MARK: - Initialization
    
    public init(
        claudeAPIKey: String,
        geminiAPIKey: String,
        naverAPIKey: String,
        openAIAPIKey: String,
        defaultConfigs: [LLMServiceType: LLMRequestConfig] = [:],
        quotaLimits: [SubscriptionTier: [LLMServiceType: Int]] = [:],
        cacheEnabled: Bool = true,
        cacheExpirationInterval: TimeInterval = 24 * 60 * 60,
        monitoringEnabled: Bool = true,
        alertThresholds: [LLMServiceType: [String: Double]] = [:],
        onDeviceModelName: String = "DeepSleepLLM",
        onDeviceModelVersion: String = "1.0"
    ) {
        self.claudeAPIKey = claudeAPIKey
        self.geminiAPIKey = geminiAPIKey
        self.naverAPIKey = naverAPIKey
        self.openAIAPIKey = openAIAPIKey
        self.defaultConfigs = defaultConfigs
        self.quotaLimits = quotaLimits
        self.cacheEnabled = cacheEnabled
        self.cacheExpirationInterval = cacheExpirationInterval
        self.monitoringEnabled = monitoringEnabled
        self.alertThresholds = alertThresholds
        self.onDeviceModelName = onDeviceModelName
        self.onDeviceModelVersion = onDeviceModelVersion
    }
    
    // MARK: - Default Configuration
    
    public static var `default`: LLMConfiguration {
        LLMConfiguration(
            claudeAPIKey: "",
            geminiAPIKey: "",
            naverAPIKey: "",
            openAIAPIKey: "",
            defaultConfigs: [
                .claude: LLMRequestConfig(
                    serviceType: .claude,
                    maxTokens: 4096,
                    temperature: 0.7,
                    topP: 1.0,
                    frequencyPenalty: 0.0,
                    presencePenalty: 0.0
                ),
                .gemini: LLMRequestConfig(
                    serviceType: .gemini,
                    maxTokens: 8192,
                    temperature: 0.8,
                    topP: 0.95,
                    frequencyPenalty: 0.0,
                    presencePenalty: 0.0
                ),
                .naver: LLMRequestConfig(
                    serviceType: .naver,
                    maxTokens: 4096,
                    temperature: 0.7,
                    topP: 0.9,
                    frequencyPenalty: 0.0,
                    presencePenalty: 0.0
                ),
                .openAI: LLMRequestConfig(
                    serviceType: .openAI,
                    maxTokens: 4096,
                    temperature: 0.7,
                    topP: 0.9,
                    frequencyPenalty: 0.0,
                    presencePenalty: 0.0
                ),
                .onDevice: LLMRequestConfig(
                    serviceType: .onDevice,
                    maxTokens: 2048,
                    temperature: 0.9,
                    topP: 1.0,
                    frequencyPenalty: 0.0,
                    presencePenalty: 0.0
                )
            ],
            quotaLimits: [
                .premium: [
                    .claude: 100,
                    .gemini: Int.max,
                    .naver: 500,
                    .openAI: 1000,
                    .onDevice: Int.max
                ],
                .free: [
                    .claude: 3,
                    .gemini: 50,
                    .naver: 10,
                    .openAI: 20,
                    .onDevice: Int.max
                ]
            ],
            alertThresholds: [
                .claude: [
                    "latency": 5.0,
                    "error_rate": 0.1
                ],
                .gemini: [
                    "latency": 3.0,
                    "error_rate": 0.1
                ],
                .naver: [
                    "latency": 3.0,
                    "error_rate": 0.1
                ],
                .openAI: [
                    "latency": 3.0,
                    "error_rate": 0.1
                ],
                .onDevice: [
                    "latency": 1.0,
                    "error_rate": 0.05
                ]
            ]
        )
    }
    
    // MARK: - Helper Methods
    
    public func getRequestConfig(for service: LLMServiceType) -> LLMRequestConfig {
        defaultConfigs[service] ?? .defaultConfig
    }
    
    public func getDailyQuota(
        for service: LLMServiceType,
        tier: SubscriptionTier
    ) -> Int {
        quotaLimits[tier]?[service] ?? 0
    }
    
    public func getAlertThresholds(for service: LLMServiceType) -> [String: Double] {
        alertThresholds[service] ?? [:]
    }
} 
