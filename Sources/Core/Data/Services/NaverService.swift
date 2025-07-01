import Foundation

/// Naver HyperCLOVA X API 서비스
/// 2025년 기준 최적화된 구현 - 메모리 효율성, 배터리 최적화 적용
public final class NaverService: LLMServiceProtocol {
    
    // MARK: - Properties
    
    private let apiKey: String
    private let baseURL = "https://clovastudio.stream.ntruss.com/testapp/v1/chat-completions/HCX-DASH-002"  // 가이드 기준 모델
    private let session: URLSession
    
    // MARK: - 2025 최적화: Lazy initialization으로 메모리 효율성 향상
    public static let shared: NaverService = {
        return NaverService()
    }()
    
    // MARK: - Initialization
    
    private init() {
        self.apiKey = EnvironmentConfig.shared.naverCloudApiKey
        
        // 2025 최적화: URLSession 설정 최적화 (배터리 효율성)
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.waitsForConnectivity = true
        config.allowsCellularAccess = true
        config.networkServiceType = .responsiveData // 배터리 최적화
        
        self.session = URLSession(configuration: config)
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
        
        // HyperCLOVA X API 요청 구조
        let requestBody: [String: Any] = [
            "messages": [
                [
                    "role": "system",
                    "content": systemPrompt ?? "You are a helpful assistant."
                ],
                [
                    "role": "user", 
                    "content": prompt
                ]
            ],
            "topP": requestConfig.topP,
            "topK": 0,
            "maxTokens": requestConfig.maxTokens,
            "temperature": requestConfig.temperature,
            "repeatPenalty": 1.2,
            "stopBefore": [],
            "includeAiFilters": true
        ]
        
        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            throw LLMError.invalidResponse
        }
        
        let startTime = Date()
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw LLMError.networkError
            }
            
            guard httpResponse.statusCode == 200 else {
                if httpResponse.statusCode == 401 {
                    throw LLMError.unauthorized
                } else if httpResponse.statusCode == 429 {
                    throw LLMError.quotaExceeded
                } else {
                    throw LLMError.apiError("HTTP \(httpResponse.statusCode)")
                }
            }
            
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let result = json["result"] as? [String: Any],
                  let message = result["message"] as? [String: Any],
                  let content = message["content"] as? String else {
                throw LLMError.invalidResponse
            }
            
            let processingTime = Date().timeIntervalSince(startTime)
            
            // 토큰 사용량 추출 (HyperCLOVA X 응답 구조에 따라)
            let inputLength = (result["inputLength"] as? Int) ?? prompt.count / 4
            let outputLength = (result["outputLength"] as? Int) ?? content.count / 4
            
            let metadata = LLMResponseMetadata(
                modelUsed: .naver,
                tokensUsed: inputLength + outputLength,
                processingTime: processingTime,
                cached: false
            )
            
            return LLMResponse(
                content: content,
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
extension NaverService {
    
    /// 메모리 정리 (필요시 호출)
    public func cleanup() {
        // 필요한 경우 캐시 정리 등 수행
    }
} 
