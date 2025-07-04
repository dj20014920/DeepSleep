import Foundation

/// `LLMServiceFactory`는 `LLMServiceType`에 따라 적절한 `LLMServiceProtocol` 구현체를 생성하고 관리하는 중앙 허브입니다.
/// 각 서비스는 자체적으로 API 키를 `EnvironmentConfig`에서 주입받고 사용 가능 여부를 결정합니다.
/// 이 클래스는 `Actor`로 구현되어 동시성 환경에서 캐시 접근을 안전하게 관리합니다.
public actor LLMServiceFactory {
    
    public static let shared = LLMServiceFactory()
    
    // 생성된 서비스 인스턴스를 캐싱하여 재사용합니다. (메모리 및 성능 최적화)
    private var serviceCache: [LLMServiceType: any LLMServiceProtocol] = [:]
    
    private init() {}
    
    /// 지정된 타입의 `LLMService` 인스턴스를 반환합니다.
    /// 이미 생성된 인스턴스가 있으면 캐시에서 반환하고, 없으면 새로 생성하여 캐시에 저장합니다.
    ///
    /// - Parameter type: 요청하는 `LLMService`의 타입.
    /// - Returns: `LLMServiceProtocol`을 준수하는 서비스 인스턴스.
    /// - Throws: `FactoryError` - 서비스 생성에 실패한 경우.
    public func getService(for type: LLMServiceType) async throws -> any LLMServiceProtocol {
            if let cachedService = serviceCache[type] {
                return cachedService
            }
            
        let newService: any LLMServiceProtocol
            
            switch type {
            case .claude:
            let service = ClaudeService.shared
            guard await service.isAvailable() else { throw FactoryError.serviceUnavailable }
            newService = service
        case .gemini:
            let service = GeminiService.shared
            guard await service.isAvailable() else { throw FactoryError.serviceUnavailable }
            newService = service
            case .naver:
            let service = NaverService.shared
            guard await service.isAvailable() else { throw FactoryError.serviceUnavailable }
            newService = service
            case .openAI:
            let service = OpenAIService.shared
            guard await service.isAvailable() else { throw FactoryError.serviceUnavailable }
            newService = service
            case .onDevice:
            if #available(iOS 18.0, *) {
                let service = OnDeviceService.shared
                guard await service.isAvailable() else { throw FactoryError.serviceUnavailable }
                newService = service
            } else {
                throw FactoryError.serviceNotAvailableOnThisOS
                }
            }
            
        serviceCache[type] = newService
        return newService
        }
    
    /// 모든 서비스의 상태를 확인합니다. (네트워크 연결, API 키 유효성 등)
    public func checkAllServicesStatus() async -> [LLMServiceType: LLMServiceStatus] {
        var statuses: [LLMServiceType: LLMServiceStatus] = [:]
        for type in LLMServiceType.allCases {
            let isAvailable: Bool
            switch type {
            case .claude: isAvailable = await ClaudeService.shared.isAvailable()
            case .gemini: isAvailable = await GeminiService.shared.isAvailable()
            case .naver: isAvailable = await NaverService.shared.isAvailable()
            case .openAI: isAvailable = await OpenAIService.shared.isAvailable()
            case .onDevice:
                if #available(iOS 18.0, *) {
                    isAvailable = await OnDeviceService.shared.isAvailable()
                } else {
                    isAvailable = false
                }
            }
            statuses[type] = LLMServiceStatus(isAvailable: isAvailable, lastChecked: Date())
        }
        return statuses
    }
    
    /// 폴백 서비스를 반환합니다. (우선순위 순서에 따라)
    public func getFallbackService() async throws -> any LLMServiceProtocol {
        let fallbackOrder: [LLMServiceType] = [.gemini, .onDevice, .claude, .naver, .openAI]
        
        for serviceType in fallbackOrder {
            do {
                let service = try await getService(for: serviceType)
                return service
            } catch {
                // 다음 서비스로 계속 시도
                continue
            }
        }
        
        throw FactoryError.serviceUnavailable
    }
}

// MARK: - Factory Errors
extension LLMServiceFactory {
    public enum FactoryError: Error, LocalizedError {
        case serviceNotFound
        case serviceNotAvailableOnThisOS
        case serviceNotYetAvailable
        case serviceUnavailable
        
        public var errorDescription: String? {
            switch self {
            case .serviceNotFound:
                return "요청한 LLM 서비스를 찾을 수 없습니다."
            case .serviceNotAvailableOnThisOS:
                return "이 OS 버전에서는 해당 서비스를 사용할 수 없습니다."
            case .serviceNotYetAvailable:
                return "해당 서비스는 아직 사용할 수 없습니다."
            case .serviceUnavailable:
                return "서비스가 현재 사용 불가능합니다. API 키를 확인해주세요."
            }
        }
    }
} 
