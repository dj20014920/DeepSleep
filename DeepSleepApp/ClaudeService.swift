import Foundation

/// `LLMService`를 준수하여 Claude API와의 통신을 담당하는 서비스 클래스.
/// 기존 `ClaudeServiceProtocol`의 역할도 겸합니다.
public protocol ClaudeServiceProtocol: LLMService {
    /// 비동기 방식으로 메시지를 전송하고 결과를 반환합니다. (기존 프로토콜 호환용)
    func sendChat(prompt: String, apiKey: String) async throws -> Any
}

/// Claude API 통신 서비스 (Keychain 연동)
/// - Conforms to `ClaudeServiceProtocol`
open class ClaudeService: ClaudeServiceProtocol {
    /// Shared singleton for global access.
    public static var shared: ClaudeServiceProtocol = ClaudeService()
    
    private let session: URLSession
    
    public init(session: URLSession = .shared) {
        self.session = session
    }
    
    /// Keychain에서 API 키 로드
    public func getAPIKey() -> String? {
        SecureEnclaveKeyStore.shared.loadAPIKey()
    }
    
    /// Sends a chat message via callback
    open func sendMessage(_ message: String, completion: @escaping (Result<String, Error>) -> Void) {
        guard let apiKey = getAPIKey() else {
            completion(.failure(NSError(domain: "ClaudeService", code: 401, userInfo: [NSLocalizedDescriptionKey: "API 키 없음"])))
            return
        }
        
        // TODO: Update to the correct Claude API endpoint and request body format.
        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        
        let body: [String: Any] = [
            "model": "claude-3-sonnet-20240229",
            "max_tokens": 1024,
            "messages": [
                ["role": "user", "content": message]
            ]
        ]
        
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        let task = session.dataTask(with: req) { data, resp, err in
            if let err = err {
                completion(.failure(err))
            } else if let data = data {
                // TODO: Implement proper JSON parsing to extract content.
                // For now, returning the raw string for debugging.
                let responseString = String(data: data, encoding: .utf8) ?? "Failed to decode response"
                completion(.success(responseString))
            } else {
                completion(.failure(NSError(domain: "ClaudeService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
            }
        }
        task.resume()
    }
    
    /// Async wrapper for `sendMessage`. It now fetches the API key internally.
    open func sendMessageAsync(prompt: String) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            sendMessage(prompt) { result in
                continuation.resume(with: result)
            }
        }
    }
    
    /// Protocol conformance for legacy `sendChat`
    open func sendChat(prompt: String, apiKey: String) async throws -> Any {
        return try await sendMessageAsync(prompt: prompt)
    }

    // MARK: - LLMService Conformance
    
    public func generateResponse(prompt: String) async throws -> String {
        return try await sendMessageAsync(prompt: prompt)
    }
} 