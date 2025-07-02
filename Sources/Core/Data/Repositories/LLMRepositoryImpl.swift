import Foundation
import Combine

/// LLM 리포지토리 구현체
public final class LLMRepositoryImpl: LLMRepository {
    // MARK: - Properties
    
    private let serviceFactory: LLMServiceFactory
    private let cache: LLMCacheProtocol
    private let monitor: LLMMonitoringProtocol
    private let userDefaults: UserDefaults
    
    // 동시성 관리를 위한 큐
    private let usageQueue = DispatchQueue(label: "com.deepsleep.llm.usage", qos: .utility)
    
    // 서비스별 사용량 통계를 저장합니다.
    private var usageStats: [LLMServiceType: LLMUsageStats] = [:]
    
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
        
        // 초기 사용량 통계 설정
        LLMServiceType.allCases.forEach { type in
            usageStats[type] = LLMUsageStats()
        }
    }
    
    // MARK: - LLMRepository Implementation
    
    public func sendMessage(
        _ message: String,
        config: LLMRequestConfig?,
        preferredService: LLMServiceType?
    ) async throws -> String {
        
        let serviceType = try await selectService(preferred: preferredService)
        
        guard await checkDailyQuota(for: serviceType) else {
            throw LLMError.quotaExceeded
        }
        
        do {
            let service = try await serviceFactory.getService(for: serviceType)
            
            // Task 생성: 현재는 히스토리 없이 일반 채팅만 지원
            // TODO: 히스토리 관리 로직 추가 필요
            let task = AITask.generalChat(message: message, history: [])
            
            let startTime = Date()
            let response = try await service.send(task: task)
            let latency = Date().timeIntervalSince(startTime)
            
            let metrics: [String: Any] = [
                "latency": latency,
                "tokens": response.metadata.tokensUsed,
                "cache_hit": false
            ]
            monitor.recordMetrics(metrics, for: serviceType)
            
            await cacheResponse(response.content, for: message, metadata: response.metadata)
            await updateUsageStats(for: serviceType, tokensUsed: response.metadata.tokensUsed, latency: latency)
            
            return response.content
            
        } catch {
            monitor.recordError(error, context: ["message": message], for: serviceType)
            
            // Fallback 시도
            if let fallbackType = try? await selectFallbackService(excluding: serviceType) {
                return try await sendMessage(message, config: config, preferredService: fallbackType)
            }
            
            throw error
        }
    }
    
    public func getUsageStats(for service: LLMServiceType) async -> LLMUsageStats {
        usageStats[service] ?? LLMUsageStats()
    }
    
    public func checkServiceStatus(for service: LLMServiceType) async -> LLMServiceStatus {
        let statuses = await serviceFactory.checkAllServicesStatus()
        return statuses[service] ?? LLMServiceStatus(isAvailable: false, lastChecked: Date())
    }
    
    public func getCachedResponse(for message: String) async -> (String, LLMResponseMetadata)? {
        cache.get(message)
    }
    
    public func cacheResponse(_ response: String, for message: String, metadata: LLMResponseMetadata) async {
        cache.set(response, forKey: message, metadata: metadata)
    }
    
    public func checkDailyQuota(for service: LLMServiceType) async -> Bool {
        let stats = await getUsageStats(for: service)
        let tier = getCurrentSubscriptionTier()
        let limit = tier.dailyLimits[service] ?? 0
        
        if limit == Int.max { return true }
        
        if !Calendar.current.isDateInToday(stats.lastUsed) {
            usageStats[service] = LLMUsageStats()
            return true
        }
        
        return stats.requestCount < limit
    }
    
    public func getAvailableServices() async -> [LLMServiceType] {
        let statuses = await serviceFactory.checkAllServicesStatus()
        return statuses.filter { $0.value.isAvailable }.map { $0.key }
    }
    
    public func updateServiceConfig(_ config: LLMRequestConfig, for service: LLMServiceType) async {
        let key = "llm_config_\(service.rawValue)"
        if let data = try? JSONEncoder().encode(config) {
            userDefaults.set(data, forKey: key)
        }
    }
    
    public func logError(_ error: LLMError, for service: LLMServiceType, context: [String: Any]?) async {
        monitor.recordError(error, context: context, for: service)
    }
    
    // MARK: - Private Helpers
    
    private func selectService(preferred: LLMServiceType?) async throws -> LLMServiceType {
        let availableServices = await getAvailableServices()
        
        if let preferred = preferred, availableServices.contains(preferred) {
            return preferred
        }
        
        let tier = getCurrentSubscriptionTier()
        
        let servicePriority = tier.servicePriority
        
        for service in servicePriority {
            if availableServices.contains(service) {
                return service
            }
        }
        
        guard let firstAvailable = availableServices.first else {
            throw LLMError.serviceUnavailable
        }
        
        return firstAvailable
    }
    
    private func selectFallbackService(excluding: LLMServiceType) async throws -> LLMServiceType? {
        let available = await getAvailableServices().filter { $0 != excluding }
        return available.first
    }
    
    private func getCurrentSubscriptionTier() -> SubscriptionTier {
        let isPremium = userDefaults.bool(forKey: "is_premium_user")
        return isPremium ? .premium : .free
    }
    
    private func updateUsageStats(for service: LLMServiceType, tokensUsed: Int, latency: TimeInterval) async {
        usageQueue.async { [weak self] in
            guard let self = self else { return }
            var stats = self.usageStats[service] ?? LLMUsageStats()
            stats.requestCount += 1
            stats.totalTokens += tokensUsed
            stats.lastUsed = Date()
            self.usageStats[service] = stats
        }
    }
}