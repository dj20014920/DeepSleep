import Foundation

public final class OpenAIService: LLMServiceProtocol {
    
    private let apiKey: String
    private let session: URLSession
    
    private let apiURL = URL(string: "https://api.openai.com/v1/chat/completions")!
    
    // MARK: - Singleton
    public static let shared: OpenAIService = {
        return OpenAIService()
    }()

    private init() {
        self.apiKey = EnvironmentConfig.shared.openAIApiKey
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.waitsForConnectivity = true
        self.session = URLSession(configuration: config)
    }
    
    public init(apiKey: String, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }
    
    public func isAvailable() async -> Bool {
        return !apiKey.isEmpty
    }
    
    public func send(task: AITask) async throws -> LLMResponse {
        let requestBody = createRequestBody(from: task)
        
        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        do {
            request.httpBody = try JSONEncoder().encode(requestBody)
        } catch {
            throw LLMError.apiError("Failed to encode request body: \(error.localizedDescription)")
        }
        
        let startTime = Date()
        let (data, response) = try await session.data(for: request)
        let processingTime = Date().timeIntervalSince(startTime)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.apiError("Invalid response type from OpenAI API")
        }
        
        // API 에러 응답 파싱
        if httpResponse.statusCode != 200 {
            let errorMessage = parseOpenAIError(from: data, statusCode: httpResponse.statusCode)
            throw LLMError.apiError(errorMessage)
        }
        
        do {
            let openAIResponse = try JSONDecoder().decode(OpenAIResponse.self, from: data)
            let content = openAIResponse.choices.first?.message.content ?? ""
            let tokensUsed = openAIResponse.usage.totalTokens
            
            let metadata = LLMResponseMetadata(
                modelUsed: .openAI,
                tokensUsed: tokensUsed,
                processingTime: processingTime
            )
            
            return LLMResponse(content: content, metadata: metadata)
        } catch {
            throw LLMError.invalidResponse
        }
    }
    
    private func createRequestBody(from task: AITask) -> OpenAIRequest {
        let userMessage = OpenAIRequest.Message(role: "user", content: task.userPrompt)
        let systemMessage = OpenAIRequest.Message(role: "system", content: task.systemPrompt)
        
        let config = task.requestConfig
        
        return OpenAIRequest(
            model: "gpt-4o-mini", // 가이드에 명시된 모델
            messages: [systemMessage, userMessage],
            maxTokens: config.maxTokens,
            temperature: config.temperature,
            topP: config.topP
        )
    }
    
    // MARK: - Error Parsing
    
    private func parseOpenAIError(from data: Data?, statusCode: Int) -> String {
        guard let data = data else {
            return "OpenAI API error with status code: \(statusCode)"
        }
        
        do {
            if let errorResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = errorResponse["error"] as? [String: Any],
               let message = error["message"] as? String {
                let type = error["type"] as? String ?? "unknown"
                return "OpenAI API error (\(type)): \(message) (Status: \(statusCode))"
            }
        } catch {
            // JSON 파싱 실패 시 원본 데이터 확인
            if let errorString = String(data: data, encoding: .utf8) {
                return "OpenAI API error: \(errorString) (Status: \(statusCode))"
            }
        }
        
        return "OpenAI API error with status code: \(statusCode)"
    }
}

// MARK: - OpenAI API Data Structures

struct OpenAIRequest: Codable {
    let model: String
    let messages: [Message]
    let maxTokens: Int
    let temperature: Double
    let topP: Double
    
    struct Message: Codable {
        let role: String
        let content: String?
    }
    
    enum CodingKeys: String, CodingKey {
        case model, messages, temperature
        case maxTokens = "max_tokens"
        case topP = "top_p"
    }
}

struct OpenAIResponse: Codable {
    let choices: [Choice]
    let usage: Usage
    
    struct Choice: Codable {
        let message: OpenAIRequest.Message
    }
    
    struct Usage: Codable {
        let promptTokens: Int
        let completionTokens: Int
        let totalTokens: Int
        
        enum CodingKeys: String, CodingKey {
            case promptTokens = "prompt_tokens"
            case completionTokens = "completion_tokens"
            case totalTokens = "total_tokens"
        }
    }
}
