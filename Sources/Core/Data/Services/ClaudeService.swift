import Foundation

/// Claude 3.5 API 서비스 구현체
public final class ClaudeService: LLMServiceProtocol {
    // MARK: - Constants
    
    private enum Constants {
        static let baseURL = "https://api.anthropic.com/v1"
        static let model = "claude-3-5-haiku-20241022"
        static let defaultMaxTokens = 4096
    }
    
    // MARK: - Properties
    
    private let apiKey: String
    private let baseURL = "https://api.anthropic.com/v1"
    private let session: URLSession
    private var status: LLMServiceStatus
    
    // MARK: - 2025 최적화: Lazy initialization으로 메모리 효율성 향상
    public static let shared: ClaudeService = {
        return ClaudeService()
    }()
    
    // MARK: - Initialization
    
    private init() {
        self.apiKey = EnvironmentConfig.shared.claudeApiKey
        
        // 2025 최적화: URLSession 설정 최적화 (배터리 효율성)
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.waitsForConnectivity = true
        config.allowsCellularAccess = true
        config.networkServiceType = .responsiveData // 배터리 최적화
        
        self.session = URLSession(configuration: config)
        self.status = LLMServiceStatus()
    }
    
    public init(apiKey: String, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
        self.status = LLMServiceStatus()
    }
    
    // MARK: - LLMServiceProtocol Implementation
    
    public func sendMessage(
        _ message: String,
        config: LLMRequestConfig
    ) async throws -> (String, LLMResponseMetadata) {
        let url = URL(string: "\(Constants.baseURL)/messages")!
        var request = URLRequest(url: url)
        
        // 요청 헤더 설정
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "x-api-key")
        request.setValue("anthropic-version=2024-03-01", forHTTPHeaderField: "anthropic-version")
        
        // Claude API 요청 구조 (가이드 기준: Claude 3.5 Haiku)
        let requestBody: [String: Any] = [
            "model": Constants.model,
            "max_tokens": config.maxTokens,
            "temperature": config.temperature,
            "top_p": config.topP,
            "messages": [
                [
                    "role": "system",
                    "content": config.systemPrompt ?? "You are a helpful assistant."
                ],
                [
                    "role": "user",
                    "content": message
                ]
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        // API 요청 실행
        let startTime = Date()
        let (data, response) = try await session.data(for: request)
        
        // 응답 검증
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.invalidResponse
        }
        
        // 에러 처리
        switch httpResponse.statusCode {
        case 200:
            break
        case 401:
            throw LLMError.unauthorized
        case 429:
            throw LLMError.quotaExceeded
        case 500...599:
            throw LLMError.serviceUnavailable
        default:
            throw LLMError.apiError("Status code: \(httpResponse.statusCode)")
        }
        
        // 응답 파싱
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let text = content.first?["text"] as? String,
              let usage = json["usage"] as? [String: Any],
              let tokensUsed = usage["total_tokens"] as? Int else {
            throw LLMError.invalidResponse
        }
        
        // 메타데이터 구성
        let metadata = LLMResponseMetadata(
            modelUsed: .claude,
            tokensUsed: tokensUsed,
            processingTime: Date().timeIntervalSince(startTime),
            cached: false
        )
        
        return (text, metadata)
    }
    
    public func streamMessage(
        _ message: String,
        config: LLMRequestConfig
    ) -> AsyncThrowingStream<String, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    let url = URL(string: "\(Constants.baseURL)/messages")!
                    var request = URLRequest(url: url)
                    
                    // 요청 헤더 설정
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "x-api-key")
                    request.setValue("anthropic-version=2024-03-01", forHTTPHeaderField: "anthropic-version")
                    
                    // Claude API 요청 구조 (가이드 기준: Claude 3.5 Haiku)
                    let requestBody: [String: Any] = [
                        "model": Constants.model,
                        "max_tokens": config.maxTokens,
                        "temperature": config.temperature,
                        "top_p": config.topP,
                        "messages": [
                            [
                                "role": "system",
                                "content": config.systemPrompt ?? "You are a helpful assistant."
                            ],
                            [
                                "role": "user",
                                "content": message
                            ]
                        ]
                    ]
                    
                    request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
                    
                    let (bytes, response) = try await session.bytes(for: request)
                    
                    guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                        throw LLMError.apiError("Invalid response or status code.")
                    }
                    
                    for try await line in bytes.lines {
                        if line.hasPrefix("data:") {
                            let jsonData = Data(line.dropFirst(5).utf8)
                            if let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                               let type = json["type"] as? String, type == "content_block_delta",
                               let delta = json["delta"] as? [String: Any],
                               let text = delta["text"] as? String {
                                continuation.yield(text)
                            }
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    public func checkStatus() async -> LLMServiceStatus {
        do {
            // 간단한 ping 요청으로 서비스 상태 확인
            let url = URL(string: "\(Constants.baseURL)/models")!
            var request = URLRequest(url: url)
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "x-api-key")
            
            let (_, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw LLMError.invalidResponse
            }
            
            let isAvailable = (200...299).contains(httpResponse.statusCode)
            status = LLMServiceStatus(
                isAvailable: isAvailable,
                errorMessage: isAvailable ? nil : "Service unavailable",
                lastChecked: Date()
            )
        } catch {
            status = LLMServiceStatus(
                isAvailable: false,
                errorMessage: error.localizedDescription,
                lastChecked: Date()
            )
        }
        
        return status
    }
    
    public func initialize() async throws {
        status = await checkStatus()
        guard status.isAvailable else {
            throw LLMError.serviceUnavailable
        }
    }
    
    public func shutdown() async {
        // 필요한 정리 작업 수행
    }
    
    public func generateResponse(
        prompt: String,
        systemPrompt: String?,
        config: LLMRequestConfig?
    ) async throws -> LLMResponse {
        
        guard !apiKey.isEmpty else {
            throw LLMError.unauthorized
        }
        
        let requestConfig = config ?? .defaultConfig
        
        // Claude API 요청 구조 (가이드 기준: Claude 3.5 Haiku)
        let requestBody: [String: Any] = [
            "model": "claude-3-5-haiku-20241022",  // 가이드 기준 모델
            "max_tokens": requestConfig.maxTokens,
            "temperature": requestConfig.temperature,
            "top_p": requestConfig.topP,
            "messages": [
                [
                    "role": "system",
                    "content": systemPrompt ?? "You are a helpful assistant."
                ],
                [
                    "role": "user",
                    "content": prompt
                ]
            ]
        ]
        
        var request = URLRequest(url: URL(string: "\(Constants.baseURL)/messages")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        
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
                  let content = json["content"] as? [[String: Any]],
                  let text = content.first?["text"] as? String else {
                throw LLMError.invalidResponse
            }
            
            let processingTime = Date().timeIntervalSince(startTime)
            
            // 토큰 사용량 추출
            let usage = json["usage"] as? [String: Any]
            let inputTokens = (usage?["input_tokens"] as? Int) ?? prompt.count / 4
            let outputTokens = (usage?["output_tokens"] as? Int) ?? text.count / 4
            
            let metadata = LLMResponseMetadata(
                modelUsed: .claude,
                tokensUsed: inputTokens + outputTokens,
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