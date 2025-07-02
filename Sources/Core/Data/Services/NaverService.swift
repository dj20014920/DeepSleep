//
//  NaverService.swift
//  DeepSleep
//
//  Created by AI on 2025/06/28.
//

import Foundation

/// Naver HyperCLOVA X API 서비스
/// 2025년 기준 최적화된 구현 - 메모리 효율성, 배터리 최적화 적용
public final class NaverService: LLMServiceProtocol {
    
    // MARK: - Properties
    
    private let clientId: String
    private let clientSecret: String
    private let session: URLSession
    
    // HCX-DASH-002 모델 사용
    private let apiURL = URL(string: "https://clovastudio.stream.ntruss.com/testapp/v1/chat-completions/HCX-DASH-002")!
    
    // MARK: - 2025 최적화: Lazy initialization으로 메모리 효율성 향상
    public static let shared: NaverService = {
        return NaverService()
    }()
    
    // MARK: - Initialization
    
    private init() {
        self.clientId = EnvironmentConfig.shared.naverCloudApiKey
        self.clientSecret = EnvironmentConfig.shared.naverCloudApiSecret
        
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
    
    // MARK: - LLMService Implementation
    
    public func send(task: AITask) async throws -> LLMResponse {
        let requestBody = createRequestBody(from: task)
        
        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(clientId, forHTTPHeaderField: "X-NCP-CLOVASTUDIO-API-KEY")
        request.setValue(clientSecret, forHTTPHeaderField: "X-NCP-APIGW-API-KEY")
        
        do {
            request.httpBody = try JSONEncoder().encode(requestBody)
        } catch {
            throw LLMError.apiError("Failed to encode request body: \(error.localizedDescription)")
        }
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            // TODO: API 에러 응답 파싱
            throw LLMError.apiError("Invalid response from Naver API. Status: \((response as? HTTPURLResponse)?.statusCode ?? 0)")
        }
        
        do {
            let naverResponse = try JSONDecoder().decode(NaverResponse.self, from: data)
            let content = naverResponse.result.message.content ?? ""
            let tokensUsed = naverResponse.result.outputTokens
            
            let metadata = LLMResponseMetadata(
                modelUsed: .naver,
                tokensUsed: tokensUsed,
                processingTime: 0 // TODO: 정확한 처리 시간 측정
            )
            
            return LLMResponse(content: content, metadata: metadata)
        } catch {
            throw LLMError.invalidResponse
        }
    }
    
    private func createRequestBody(from task: AITask) -> NaverRequest {
        let userMessage = NaverRequest.Message(role: "user", content: task.userPrompt)
        let systemMessage = NaverRequest.Message(role: "system", content: task.systemPrompt)
        
        let config = task.requestConfig
        
        return NaverRequest(
            messages: [systemMessage, userMessage],
            temperature: config.temperature,
            topP: config.topP,
            maxTokens: config.maxTokens
        )
    }
    
    public func isAvailable() async -> Bool {
        return !clientId.isEmpty && !clientSecret.isEmpty
    }
}

// MARK: - 2025 최적화: Memory Management
extension NaverService {
    
    /// 메모리 정리 (필요시 호출)
    public func cleanup() {
        // 필요한 경우 캐시 정리 등 수행
    }
}

// MARK: - Naver API Data Structures

struct NaverRequest: Codable {
    let messages: [Message]
    let temperature: Double
    let topP: Double
    let maxTokens: Int
    
    struct Message: Codable {
        let role: String
        let content: String?
    }
    
    enum CodingKeys: String, CodingKey {
        case messages, temperature
        case topP = "topP"
        case maxTokens
    }
}

struct NaverResponse: Codable {
    let result: Result
    
    struct Result: Codable {
        let message: NaverRequest.Message
        let inputTokens: Int
        let outputTokens: Int
    }
} 
