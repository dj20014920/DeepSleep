import Foundation
import Combine

/// LLM 리포지토리 구현체
public final class LLMRepositoryImpl: LLMRepository {
    // MARK: - Properties
    
    private let serviceFactory: LLMServiceFactory
    private let cache: LLMCacheProtocol
    private let monitor: LLMMonitoringProtocol
    private let userDefaults: UserDefaults
    
    // 2025 최적화: 동시성 관리를 위한 큐
    private let usageQueue = DispatchQueue(label: "com.deepsleep.llm.usage", qos: .utility)
    
    private var services: [LLMServiceType: any LLMServiceProtocol] = [:]
    private var usageStats: [LLMServiceType: LLMUsageStats] = [:]
    private var serviceStatus: [LLMServiceType: LLMServiceStatus] = [:]
    
    // MARK: - Initialization
    
    public init(
        serviceFactory: LLMServiceFactory,
        cache: LLMCacheProtocol,
        monitor: LLMMonitoringProtocol,
        userDefaults: UserDefaults = .standard
    ) {
        self.serviceFactory = serviceFactory
        self.cache = cache
        self.monitor = monitor
        self.userDefaults = userDefaults
        
        // 초기 서비스 상태 설정
        LLMServiceType.allCases.forEach { type in
            serviceStatus[type] = LLMServiceStatus()
            usageStats[type] = LLMUsageStats()
        }
    }
    
    // MARK: - LLMRepository Implementation
    
    public func sendMessage(
        _ message: String,
        config: LLMRequestConfig?,
        preferredService: LLMServiceType?
    ) async throws -> String {
        
        // 1. 서비스 선택
        let service = try await selectService(preferred: preferredService)
        
        // 2. 사용량 제한 확인
        guard await checkDailyQuota(for: service) else {
            throw LLMError.quotaExceeded
        }
        
        do {
            // 4. 메시지 전송
            let startTime = Date()
            let response = try await getService(for: service)
                .generateResponse(prompt: message, systemPrompt: config?.systemPrompt, config: config)
            
            // 5. 메트릭 기록
            let metrics: [String: Any] = [
                "latency": Date().timeIntervalSince(startTime),
                "tokens": response.metadata.tokensUsed,
                "cache_hit": false
            ]
            monitor.recordMetrics(metrics, for: service)
            
            // 6. 응답 캐싱
            await cacheResponse(response.content, for: message, metadata: response.metadata)
            
            // 7. 사용량 통계 업데이트
            await updateUsageStats(for: service, tokensUsed: response.metadata.tokensUsed, latency: Date().timeIntervalSince(startTime))
            
            return response.content
            
        } catch {
            // 에러 처리 및 로깅
            monitor.recordError(error, context: ["message": message], for: service)
            
            // Fallback 시도
            if let fallback = try? await selectFallbackService(excluding: service) {
                return try await sendMessage(message, config: config, preferredService: fallback)
            }
            
            throw error
        }
    }
    
    public func getUsageStats(for service: LLMServiceType) async -> LLMUsageStats {
        usageStats[service] ?? LLMUsageStats()
    }
    
    public func checkServiceStatus(for service: LLMServiceType) async -> LLMServiceStatus {
        do {
            let isAvailable = await (try getService(for: service)).isAvailable()
            let status = LLMServiceStatus(
                isAvailable: isAvailable,
                errorMessage: isAvailable ? nil : "Service unavailable",
                lastChecked: Date()
            )
            serviceStatus[service] = status
            return status
        } catch {
            let errorStatus = LLMServiceStatus(
                isAvailable: false,
                errorMessage: error.localizedDescription,
                lastChecked: Date()
            )
            serviceStatus[service] = errorStatus
            return errorStatus
        }
    }
    
    public func getCachedResponse(
        for message: String
    ) async -> (String, LLMResponseMetadata)? {
        cache.get(message)
    }
    
    public func cacheResponse(
        _ response: String,
        for message: String,
        metadata: LLMResponseMetadata
    ) async {
        cache.set(response, forKey: message, metadata: metadata)
    }
    
    public func checkDailyQuota(for service: LLMServiceType) async -> Bool {
        let stats = await getUsageStats(for: service)
        let tier = getCurrentSubscriptionTier()
        let limit = tier.dailyLimits[service] ?? 0
        
        // 무제한인 경우
        if limit == Int.max {
            return true
        }
        
        // 마지막 사용 날짜가 오늘이 아닌 경우 초기화
        if !Calendar.current.isDateInToday(stats.lastUsed) {
            let newStats = LLMUsageStats()
            usageStats[service] = newStats
            return true
        }
        
        return stats.requestCount < limit
    }
    
    public func getAvailableServices() async -> [LLMServiceType] {
        var available: [LLMServiceType] = []
        
        for service in LLMServiceType.allCases {
            let status = await checkServiceStatus(for: service)
            if status.isAvailable {
                available.append(service)
            }
        }
        
        return available
    }
    
    public func updateServiceConfig(
        _ config: LLMRequestConfig,
        for service: LLMServiceType
    ) async {
        // 설정 저장
        let key = "llm_config_\(service.rawValue)"
        if let data = try? JSONEncoder().encode(config) {
            userDefaults.set(data, forKey: key)
        }
    }
    
    public func logError(
        _ error: LLMError,
        for service: LLMServiceType,
        context: [String: Any]?
    ) async {
        monitor.recordError(error, context: context, for: service)
    }
    
    // MARK: - Private Helpers
    
    private func selectService(preferred: LLMServiceType?) async throws -> LLMServiceType {
        // 1. 선호 서비스가 있고 사용 가능한 경우
        if let preferred = preferred,
           let status = serviceStatus[preferred],
           status.isAvailable {
            return preferred
        }
        
        // 2. 구독 상태에 따른 서비스 선택
        let tier = getCurrentSubscriptionTier()
        let available = await getAvailableServices()
        
        switch tier {
        case .premium:
            // Claude 3.5 우선
            if available.contains(.claude) {
                return .claude
            }
        case .free:
            // 온디바이스 → Gemini 순
            if available.contains(.onDevice) {
                return .onDevice
            } else if available.contains(.gemini) {
                return .gemini
            }
        }
        
        // 3. 사용 가능한 첫 번째 서비스
        guard let first = available.first else {
            throw LLMError.serviceUnavailable
        }
        
        return first
    }
    
    private func selectFallbackService(
        excluding: LLMServiceType
    ) async throws -> LLMServiceType? {
        let available = await getAvailableServices()
            .filter { $0 != excluding }
        
        return available.first
    }
    
    /// LLM 서비스 인스턴스를 가져옵니다. 없으면 새로 생성합니다.
    private func getService(for type: LLMServiceType) throws -> any LLMServiceProtocol {
        if let existingService = services[type] {
            return existingService
        }
        
        // 서비스 생성 및 반환
        let service = try serviceFactory.createService(for: type)
        services[type] = service
        return service
    }
    
    private func getCurrentSubscriptionTier() -> SubscriptionTier {
        let isPremium = userDefaults.bool(forKey: "is_premium_user")
        return isPremium ? .premium : .free
    }
    
    private func updateUsageStats(
        for service: LLMServiceType,
        tokensUsed: Int,
        latency: TimeInterval
    ) async {
        var stats = await getUsageStats(for: service)
        stats.totalTokens += tokensUsed
        stats.requestCount += 1
        stats.lastUsed = Date()
        
        // TODO: 평균 latency 계산 로직 추가
        
        usageStats[service] = stats
    }
} 