import Foundation
import Combine

/// LLM 설정 화면 뷰모델
public final class LLMSettingsViewModel: ObservableObject {
    // MARK: - Properties
    
    @Published public var availableServices: [LLMServiceType] = []
    @Published public var isPremium: Bool
    @Published public var selectedService: LLMServiceType
    @Published public var serviceStatus: [LLMServiceType: LLMServiceStatus]
    @Published public var usageStats: [LLMServiceType: LLMUsageStats]
    @Published public var requestConfig: LLMRequestConfig
    @Published public var isLoading: Bool = false
    @Published public var error: Error?
    
    private let repository: LLMRepository
    private let configuration: LLMConfiguration
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    public init(
        repository: LLMRepository,
        configuration: LLMConfiguration
    ) {
        self.repository = repository
        self.configuration = configuration
        
        // 초기값 설정
        self.isPremium = UserDefaults.standard.bool(forKey: "is_premium_user")
        self.selectedService = .claude
        self.serviceStatus = [:]
        self.usageStats = [:]
        self.requestConfig = configuration.getRequestConfig(for: .claude)
        
        // 서비스 상태 모니터링
        startMonitoring()
    }
    
    // MARK: - Public Methods
    
    public func refreshServiceStatus() {
        isLoading = true
        
        Task {
            await withTaskGroup(of: Void.self) { group in
                for service in LLMServiceType.allCases {
                    group.addTask {
                        let status = await self.repository.checkServiceStatus(for: service)
                        let stats = await self.repository.getUsageStats(for: service)
                
                await MainActor.run {
                            self.serviceStatus[service] = status
                            self.usageStats[service] = stats
                        }
                    }
                }
            }
            
                await MainActor.run {
                    isLoading = false
            }
        }
    }
    
    public func updateRequestConfig(
        maxTokens: Int? = nil,
        temperature: Double? = nil,
        topP: Double? = nil
    ) {
        requestConfig = requestConfig.with(
            maxTokens: maxTokens,
            temperature: temperature,
            topP: topP
        )
        
        Task {
            await repository.updateServiceConfig(
                requestConfig,
                for: selectedService
            )
        }
    }
    
    public func selectService(_ service: LLMServiceType) {
        selectedService = service
        requestConfig = configuration.getRequestConfig(for: service)
    }
    
    public func resetUsageStats(for service: LLMServiceType) {
        Task {
            var stats = await repository.getUsageStats(for: service)
            stats.reset()
            await MainActor.run {
                usageStats[service] = stats
            }
        }
    }
    
    public func generateReport(for service: LLMServiceType) -> String {
        guard let stats = usageStats[service] else {
            return "통계 정보가 없습니다."
        }
        
        let status = serviceStatus[service]?.statusDescription ?? "알 수 없음"
        let config = configuration.getRequestConfig(for: service)
        
        return """
        서비스: \(service.displayName)
        상태: \(status)
        
        === 사용량 통계 ===
        \(stats.usageDescription)
        
        === 설정 ===
        최대 토큰: \(config.maxTokens)
        온도: \(String(format: "%.1f", config.temperature))
        Top-P: \(String(format: "%.1f", config.topP))
        
        === 제한 ===
        무료 사용자: \(configuration.getDailyQuota(for: service, tier: .free))회/일
        프리미엄 사용자: \(configuration.getDailyQuota(for: service, tier: .premium))회/일
        """
    }
    
    // MARK: - Private Methods
    
    private func startMonitoring() {
        // 5분마다 서비스 상태 갱신
        Timer.publish(every: 300, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.refreshServiceStatus()
            }
            .store(in: &cancellables)
        
        // 1분마다 사용량 통계 갱신
        Timer.publish(every: 60, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateUsageStats()
            }
            .store(in: &cancellables)
        
        // 초기 데이터 로드
        refreshServiceStatus()
        updateUsageStats()
    }
    
    private func updateUsageStats() {
        Task {
            for service in LLMServiceType.allCases {
                let stats = await repository.getUsageStats(for: service)
                await MainActor.run {
                    usageStats[service] = stats
                }
            }
        }
    }
} 