import Foundation

/// LLM 서비스 리포지토리 프로토콜
public protocol LLMRepository {
    /// 메시지 전송
    func sendMessage(_ message: String,
                    config: LLMRequestConfig?,
                    preferredService: LLMServiceType?) async throws -> String
    
    /// 사용량 통계 조회
    func getUsageStats(for service: LLMServiceType) async -> LLMUsageStats
    
    /// 서비스 상태 확인
    func checkServiceStatus(for service: LLMServiceType) async -> LLMServiceStatus
    
    /// 캐시된 응답 조회
    func getCachedResponse(for message: String) async -> (String, LLMResponseMetadata)?
    
    /// 응답 캐싱
    func cacheResponse(_ response: String,
                      for message: String,
                      metadata: LLMResponseMetadata) async
    
    /// 일일 사용량 제한 확인
    func checkDailyQuota(for service: LLMServiceType) async -> Bool
    
    /// 사용 가능한 서비스 목록 조회
    func getAvailableServices() async -> [LLMServiceType]
    
    /// 서비스별 설정 업데이트
    func updateServiceConfig(_ config: LLMRequestConfig,
                           for service: LLMServiceType) async
    
    /// 에러 로깅
    func logError(_ error: LLMError,
                 for service: LLMServiceType,
                 context: [String: Any]?) async
}

/// LLM 리포지토리 기본 구현을 위한 프로토콜 확장
public extension LLMRepository {
    /// 기본 설정으로 메시지 전송
    func sendMessage(_ message: String) async throws -> String {
        try await sendMessage(message,
                            config: LLMRequestConfig.defaultConfig,
                            preferredService: nil)
    }
    
    /// 선호 서비스로 메시지 전송
    func sendMessage(_ message: String,
                    preferredService: LLMServiceType) async throws -> String {
        try await sendMessage(message,
                            config: LLMRequestConfig.defaultConfig,
                            preferredService: preferredService)
    }
    
    /// 설정을 지정하여 메시지 전송
    func sendMessage(_ message: String,
                    config: LLMRequestConfig) async throws -> String {
        try await sendMessage(message,
                            config: config,
                            preferredService: nil)
    }
}

/// LLM 서비스 프로토콜
public protocol LLMServiceProtocol {
    /// 응답 생성 (가이드 기준 메서드명)
    func generateResponse(
        prompt: String,
        systemPrompt: String?,
        config: LLMRequestConfig?
    ) async throws -> LLMResponse
    
    /// 서비스 사용 가능 여부 확인
    func isAvailable() async -> Bool
}

/// LLM 캐시 프로토콜
public protocol LLMCacheProtocol {
    /// 응답 조회
    func get(_ key: String) -> (String, LLMResponseMetadata)?
    
    /// 응답 저장
    func set(_ value: String,
             forKey key: String,
             metadata: LLMResponseMetadata)
    
    /// 캐시 삭제
    func remove(_ key: String)
    
    /// 캐시 초기화
    func clear()
}

/// LLM 모니터링 프로토콜
public protocol LLMMonitoringProtocol {
    /// 메트릭 기록
    func recordMetrics(_ metrics: [String: Any],
                      for service: LLMServiceType)
    
    /// 에러 기록
    func recordError(_ error: Error,
                    context: [String: Any]?,
                    for service: LLMServiceType)
    
    /// 성능 보고서 생성
    func generateReport(for service: LLMServiceType) -> [String: Any]
    
    /// 알림 설정
    func setAlertThresholds(_ thresholds: [String: Any],
                           for service: LLMServiceType)
} 