import Foundation
import GoogleGenerativeAI

/// Gemini 2.0 Flash-Lite API 서비스
/// 2025년 기준 최적화된 구현 - 메모리 효율성, 배터리 최적화 적용
public final class GeminiService: LLMServiceProtocol {
    
    // MARK: - Properties
    
    private let apiKey: String
    private let model: GenerativeModel
    private let session: URLSession
    
    // MARK: - 2025 최적화: Lazy initialization으로 메모리 효율성 향상
    public static let shared: GeminiService = {
        return GeminiService()
    }()
    
    // MARK: - Initialization
    
    private init() {
        self.apiKey = EnvironmentConfig.shared.geminiApiKey
        
        // 2025 최적화: URLSession 설정 최적화 (배터리 효율성)
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.waitsForConnectivity = true
        config.allowsCellularAccess = true
        config.networkServiceType = .responsiveData // 배터리 최적화
        
        self.session = URLSession(configuration: config)
        
        // Gemini 2.0 Flash-Lite 모델 초기화
        self.model = GenerativeModel(
            name: "gemini-2.0-flash-lite",
            apiKey: apiKey
        )
    }
    
    deinit {
        session.invalidateAndCancel()
    }
    
    // MARK: - LLMServiceProtocol Implementation
    
    public func generateResponse(
        prompt: String,
        systemPrompt: String?,
        config: LLMRequestConfig?
    ) async throws -> LLMResponse {
        
        guard !apiKey.isEmpty else {
            throw LLMError.unauthorized
        }
        
        let requestConfig = config ?? .defaultConfig
        let startTime = Date()
        
        do {
            // 시스템 프롬프트와 사용자 프롬프트 결합
            let fullPrompt = [systemPrompt, prompt]
                .compactMap { $0 }
                .joined(separator: "\n\n")
            
            let response = try await model.generateContent(fullPrompt)
        
            guard let text = response.text else {
            throw LLMError.invalidResponse
        }
        
            let processingTime = Date().timeIntervalSince(startTime)
            
            // 토큰 사용량 계산 (추정)
            let estimatedTokens = (fullPrompt.count + text.count) / 4
        
        let metadata = LLMResponseMetadata(
            modelUsed: .gemini,
                tokensUsed: estimatedTokens,
                processingTime: processingTime,
            cached: false
        )
        
            return LLMResponse(
                content: text,
                metadata: metadata
            )
            
                } catch {
            if error is LLMError {
                throw error
            } else {
                throw LLMError.networkError
            }
        }
    }
    
    public func isAvailable() async -> Bool {
        return !apiKey.isEmpty
        }
    }
    
// MARK: - 2025 최적화: Memory Management
extension GeminiService {
    
    /// 메모리 정리 (필요시 호출)
    public func cleanup() {
        // 필요한 경우 캐시 정리 등 수행
    }
} 