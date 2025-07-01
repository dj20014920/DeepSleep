import Foundation

/// OpenAI GPT-4o-mini API 서비스
/// 2025년 기준 최적화된 구현 - 메모리 효율성, 배터리 최적화 적용
public final class OpenAIService: LLMServiceProtocol {
    
    // MARK: - Properties
    
    private let apiKey: String
    private let baseURL = "https://api.openai.com/v1/chat/completions"
    private let session: URLSession
    
    // MARK: - 2025 최적화: Lazy initialization으로 메모리 효율성 향상
    public static let shared: OpenAIService = {
        return OpenAIService()
    }()
    
    // MARK: - Initialization
    
    private init() {
        self.apiKey = EnvironmentConfig.shared.openAIApiKey
        
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
        
        // OpenAI API 요청 구조
        let requestBody: [String: Any] = [
            "model": "gpt-4o-mini",
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
            "max_tokens": requestConfig.maxTokens,
            "temperature": requestConfig.temperature,
            "top_p": requestConfig.topP,
            "frequency_penalty": requestConfig.frequencyPenalty,
            "presence_penalty": requestConfig.presencePenalty
        ]
        
        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
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
                } else if httpResponse.statusCode == 400 {
                    throw LLMError.tokenLimitExceeded
                } else {
                    throw LLMError.apiError("HTTP \(httpResponse.statusCode)")
                }
            }
            
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let firstChoice = choices.first,
                  let message = firstChoice["message"] as? [String: Any],
                  let content = message["content"] as? String else {
                throw LLMError.invalidResponse
            }
            
            let processingTime = Date().timeIntervalSince(startTime)
            
            // 토큰 사용량 추출
            let usage = json["usage"] as? [String: Any]
            let totalTokens = (usage?["total_tokens"] as? Int) ?? (prompt.count + content.count) / 4
            
            let metadata = LLMResponseMetadata(
                modelUsed: .openAI,
                tokensUsed: totalTokens,
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
extension OpenAIService {
    
    /// 메모리 정리 (필요시 호출)
    public func cleanup() {
        // 필요한 경우 캐시 정리 등 수행
    }
} 
