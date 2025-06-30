import Foundation

/// 2025 최적화: LLM 서비스 팩토리 - 메모리 효율적 서비스 생성 및 관리
public class LLMServiceFactory {
    
    // MARK: - Properties
    
    private var serviceCache: [LLMServiceType: any LLMServiceProtocol] = [:]
    private let cacheQueue = DispatchQueue(label: "com.deepsleep.servicefactory", qos: .userInitiated)
    
    // MARK: - Singleton
    
    public static let shared = LLMServiceFactory()
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// 지정된 서비스 타입에 맞는 `LLMService` 인스턴스를 생성하여 반환합니다.
    /// 2025 최적화: 필요할 때만 서비스를 생성하여 메모리 사용량 최소화
    ///
    /// - Parameter type: 생성할 서비스의 타입 (`LLMServiceType`).
    /// - Returns: `LLMServiceProtocol`을 준수하는 서비스 인스턴스.
    /// - Throws: `FactoryError` - 서비스 생성 실패 시.
    public func createService(for type: LLMServiceType) throws -> any LLMServiceProtocol {
        return cacheQueue.sync { () -> any LLMServiceProtocol in
            if let cachedService = serviceCache[type] {
                return cachedService
            }
            
            let service: any LLMServiceProtocol
            
            switch type {
            case .claude:
                service = ClaudeService.shared
        case .gemini:
                service = GeminiService.shared
            case .naver:
                // 임시로 Claude 서비스 사용 (NaverService import 문제 해결 전까지)
                service = ClaudeService.shared
            case .openAI:
                // 임시로 Claude 서비스 사용 (OpenAIService import 문제 해결 전까지)
                service = ClaudeService.shared
            case .onDevice:
                // 임시로 Gemini 서비스 사용 (OnDeviceService 생성 전까지)
                service = GeminiService.shared
            }
            
            // 서비스 가용성 확인
            Task {
                let isAvailable = await service.isAvailable()
                if !isAvailable {
                    // 로그 기록하지만 오류는 발생시키지 않음 (사용자 경험 향상)
                    print("⚠️ Service \(type.displayName) is not available")
                }
            }
            
            serviceCache[type] = service
            return service
            }
        }
    
    // MARK: - Cache Management (2025 최적화)
    
    /// 특정 서비스의 캐시를 제거합니다 (메모리 최적화)
    public func removeCachedService(for type: LLMServiceType) {
        cacheQueue.async { [weak self] in
            self?.serviceCache.removeValue(forKey: type)
        }
    }
    
    /// 모든 서비스 캐시를 제거합니다 (메모리 최적화)
    public func clearCache() {
        cacheQueue.async { [weak self] in
            self?.serviceCache.removeAll()
        }
    }
    
    // MARK: - Memory Management
    
    /// 메모리 경고 시 호출하여 메모리 해제
    public func handleMemoryWarning() {
        clearCache()
    }
    
    /// 앱이 백그라운드로 이동할 때 호출하여 메모리 최적화
    public func handleAppDidEnterBackground() {
        // 백그라운드 진입 시 캐시 정리
        clearCache()
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
                return "서비스가 현재 사용 불가능합니다."
            }
        }
    }
} 