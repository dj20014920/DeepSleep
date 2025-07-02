//
//  GeminiService.swift
//  DeepSleep
//
//  Created by AI on 2025/06/28.
//

import Foundation
import GoogleGenerativeAI

/// Gemini 2.0 Flash-Lite API 서비스
/// 2025년 기준 최적화된 구현 - 메모리 효율성, 배터리 최적화 적용
public final class GeminiService: LLMServiceProtocol {
    
    // MARK: - Properties
    
    private let apiKey: String
    private let session: URLSession
    
    private var apiURL: URL {
        // "Efficient Worker" 역할인 Gemini Flash 모델을 사용합니다.
        // gemini-1.5-flash-latest
        let modelName = "gemini-1.5-flash-latest"
        return URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(modelName):generateContent?key=\(apiKey)")!
    }
    
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
        
        do {
            request.httpBody = try JSONEncoder().encode(requestBody)
        } catch {
            throw LLMError.apiError("Failed to encode request body: \(error.localizedDescription)")
        }
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            // TODO: API 에러 응답 파싱
            throw LLMError.apiError("Invalid response from Gemini API. Status: \((response as? HTTPURLResponse)?.statusCode ?? 0)")
        }
        
        do {
            let geminiResponse = try JSONDecoder().decode(GeminiResponse.self, from: data)
            let content = geminiResponse.candidates.first?.content.parts.first?.text ?? ""
            let tokensUsed = geminiResponse.usageMetadata?.totalTokenCount ?? 0
            
            let metadata = LLMResponseMetadata(
                modelUsed: .gemini,
                tokensUsed: tokensUsed,
                processingTime: 0 // TODO: 정확한 처리 시간 측정
            )
            
            return LLMResponse(content: content, metadata: metadata)
        } catch {
            throw LLMError.invalidResponse
        }
    }
    
    private func createRequestBody(from task: AITask) -> GeminiRequest {
        let part = GeminiRequest.Content.Part(text: task.userPrompt)
        let content = GeminiRequest.Content(parts: [part], role: "user")
        let systemInstruction = GeminiRequest.Content(parts: [.init(text: task.systemPrompt)], role: "system")
        
        let config = task.requestConfig
        let generationConfig = GeminiRequest.GenerationConfig(
            temperature: config.temperature,
            topP: config.topP,
            maxOutputTokens: config.maxTokens
        )
        
        return GeminiRequest(contents: [systemInstruction, content], generationConfig: generationConfig)
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

// MARK: - Gemini API Data Structures

struct GeminiRequest: Codable {
    let contents: [Content]
    let generationConfig: GenerationConfig

    struct Content: Codable {
        let parts: [Part]
        let role: String
        
        struct Part: Codable {
            let text: String
        }
    }

    struct GenerationConfig: Codable {
        let temperature: Double
        let topP: Double
        let maxOutputTokens: Int
    }
    
    enum CodingKeys: String, CodingKey {
        case contents
        case generationConfig = "generation_config"
    }
}

struct GeminiResponse: Codable {
    let candidates: [Candidate]
    let usageMetadata: UsageMetadata?

    struct Candidate: Codable {
        let content: GeminiRequest.Content
    }

    struct UsageMetadata: Codable {
        let promptTokenCount: Int
        let candidatesTokenCount: Int
        let totalTokenCount: Int
    }
    
    enum CodingKeys: String, CodingKey {
        case candidates
        case usageMetadata = "usageMetadata"
    }
} 
