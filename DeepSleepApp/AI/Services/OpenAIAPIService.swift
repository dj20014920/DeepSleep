//
//  OpenAIAPIService.swift
//  DeepSleep
//
//  Created by Claude on 2025-07-21.
//  Copyright © 2025 DeepSleep. All rights reserved.
//

import Foundation

/// 🧠 **OpenAI API 서비스**
/// OpenAI GPT 모델과의 통신을 담당하는 서비스
/// PERF-WARNING: Structured Outputs 사용 시 추가 레이턴시 발생 가능
/// - 테스트 방안: Network 프로파일러로 응답 시간 측정
class OpenAIAPIService {
    private let apiKey: String
    private let baseURL = "https://api.openai.com/v1/chat/completions"
    private let defaultModel = "gpt-4o-mini" // 비용 효율적인 최신 모델
    
    // MARK: - 초기화
    
    init(apiKey: String) {
        self.apiKey = apiKey
        // OpenAI 서비스 초기화됨
    }
    
    // MARK: - 🚀 메시지 전송 메인 함수
    
    func sendMessage(
        content: String,
        systemPrompt: String,
        mode: AIMode,
        tokenConfig: TokenConfiguration
    ) async throws -> AIResponse {
        
        let startTime = Date()
        print("🧠 [OpenAI] 메시지 전송 시작 - 모드: \(mode.rawValue)")
        
        // 1. 요청 데이터 구성
        let requestBody = buildOpenAIRequest(
            content: content,
            systemPrompt: systemPrompt,
            tokenConfig: tokenConfig,
            mode: mode
        )
        
        // 2. API 요청
        let responseData = try await performAPIRequest(requestBody: requestBody)
        
        // 3. 응답 파싱
        let openAIResponse = try parseOpenAIResponse(responseData)
        
        // 4. AIResponse로 변환
        let processingTime = Date().timeIntervalSince(startTime)
        return convertToAIResponse(
            openAIResponse: openAIResponse,
            mode: mode,
            processingTime: processingTime
        )
    }
    
    // MARK: - 🔧 OpenAI API 요청 구성
    
    private func buildOpenAIRequest(
        content: String,
        systemPrompt: String,
        tokenConfig: TokenConfiguration,
        mode: AIMode
    ) -> [String: Any] {
        
        var requestBody: [String: Any] = [
            "model": defaultModel,
            "max_tokens": tokenConfig.maxTokens,
            "temperature": tokenConfig.temperature,
            "messages": [
                [
                    "role": "system",
                    "content": systemPrompt
                ],
                [
                    "role": "user",
                    "content": content
                ]
            ]
        ]
        
        // 선택적 파라미터 추가
        if let topP = tokenConfig.topP {
            requestBody["top_p"] = topP
        }
        
        if let frequencyPenalty = tokenConfig.frequencyPenalty {
            requestBody["frequency_penalty"] = frequencyPenalty
        }
        
        if let presencePenalty = tokenConfig.presencePenalty {
            requestBody["presence_penalty"] = presencePenalty
        }
        
        // Structured Outputs 설정 (특정 모드에서)
        if shouldUseStructuredOutput(for: mode), let responseFormat = tokenConfig.responseFormat {
            requestBody["response_format"] = buildResponseFormat(responseFormat)
        }
        
        return requestBody
    }
    
    /// 모드별 Structured Outputs 사용 여부 결정
    private func shouldUseStructuredOutput(for mode: AIMode) -> Bool {
        switch mode {
        case .presetRecommendation, .monthlyStatistics, .emotionAnalysis:
            return true // 구조화된 데이터가 필요한 모드들
        default:
            return false
        }
    }
    
    /// 응답 포맷 구성
    private func buildResponseFormat(_ format: ResponseFormat) -> [String: Any] {
        switch format {
        case .json:
            return ["type": "json_object"]
        case .text:
            return ["type": "text"]
        case .markdown:
            return ["type": "text"] // OpenAI는 마크다운을 별도 지원하지 않음
        }
    }
    
    // MARK: - 🌐 API 요청 수행
    
    private func performAPIRequest(requestBody: [String: Any]) async throws -> Data {
        guard let url = URL(string: baseURL) else {
            throw AIServiceError.invalidResponse
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            throw AIServiceError.invalidResponse
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            // HTTP 상태 코드 확인
            if let httpResponse = response as? HTTPURLResponse {
                switch httpResponse.statusCode {
                case 200...299:
                    break // 성공
                case 401:
                    throw AIServiceError.unauthorized
                case 429:
                    throw AIServiceError.rateLimitExceeded
                case 500...599:
                    throw AIServiceError.serverError(statusCode: httpResponse.statusCode)
                default:
                    throw AIServiceError.serverError(statusCode: httpResponse.statusCode)
                }
            }
            
            return data
            
        } catch let error as AIServiceError {
            throw error
        } catch {
            throw AIServiceError.networkError(error)
        }
    }
    
    // MARK: - 📊 응답 파싱
    
    private func parseOpenAIResponse(_ data: Data) throws -> OpenAIResponse {
        do {
            // 디버깅을 위한 응답 로깅
            if let jsonString = String(data: data, encoding: .utf8) {
                print("🧠 [OpenAI] 응답 수신: \(jsonString.prefix(200))...")
            }
            
            let decoder = JSONDecoder()
            return try decoder.decode(OpenAIResponse.self, from: data)
            
        } catch {
            print("❌ [OpenAI] 응답 파싱 실패: \(error)")
            
            // 에러 응답인지 확인
            if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = errorData["error"] as? [String: Any] {
                throw handleOpenAIError(error)
            }
            
            throw AIServiceError.invalidResponse
        }
    }
    
    // MARK: - 🔄 응답 변환
    
    private func convertToAIResponse(
        openAIResponse: OpenAIResponse,
        mode: AIMode,
        processingTime: TimeInterval
    ) -> AIResponse {
        
        // OpenAI 응답에서 텍스트 추출
        let content = openAIResponse.choices.first?.message.content ?? ""
        
        // 토큰 사용량 정보
        let usage = TokenUsage(
            promptTokens: openAIResponse.usage.promptTokens,
            completionTokens: openAIResponse.usage.completionTokens,
            totalTokens: openAIResponse.usage.totalTokens,
            estimatedCost: calculateEstimatedCost(openAIResponse.usage)
        )
        
        // 메타데이터 구성
        let metadata = ResponseMetadata(
            emotionAnalysis: nil,
            recommendations: nil,
            confidenceScore: 0.80, // GPT는 안정적이지만 Claude보다 살짝 낮게
            additionalInfo: [
                "model": openAIResponse.model,
                "finish_reason": openAIResponse.choices.first?.finishReason ?? "stop"
            ]
        )
        
        return AIResponse(
            id: openAIResponse.id,
            model: .openAI,
            mode: mode,
            content: content,
            metadata: metadata,
            usage: usage,
            timestamp: Date(),
            processingTime: Int(processingTime * 1000)
        )
    }
    
    // MARK: - 💰 비용 계산
    
    private func calculateEstimatedCost(_ usage: OpenAIUsage) -> Double {
        // GPT-4o-mini 가격 (2025년 기준 예상)
        let inputCostPer1000 = 0.00015  // $0.00015 per 1K input tokens
        let outputCostPer1000 = 0.0006  // $0.0006 per 1K output tokens
        
        let inputCost = Double(usage.promptTokens) / 1000.0 * inputCostPer1000
        let outputCost = Double(usage.completionTokens) / 1000.0 * outputCostPer1000
        
        return inputCost + outputCost
    }
    
    // MARK: - ❌ 에러 처리
    
    private func handleOpenAIError(_ error: [String: Any]) -> AIServiceError {
        let type = error["type"] as? String ?? "unknown"
        let message = error["message"] as? String ?? "Unknown error"
        
        print("❌ [OpenAI] 에러 응답: \(type) - \(message)")
        
        switch type {
        case "invalid_api_key", "authentication_error":
            return .unauthorized
        case "rate_limit_exceeded":
            return .rateLimitExceeded
        case "quota_exceeded":
            return .quotaExceeded(model: .openAI)
        case "model_not_found":
            return .modelUnavailable(model: .openAI)
        case "insufficient_quota":
            return .quotaExceeded(model: .openAI)
        default:
            return .unknown(NSError(domain: "OpenAI", code: 0, userInfo: [NSLocalizedDescriptionKey: message]))
        }
    }
}

// MARK: - 📋 OpenAI API 응답 모델

struct OpenAIResponse: Codable {
    let id: String
    let object: String
    let created: Int
    let model: String
    let choices: [OpenAIChoice]
    let usage: OpenAIUsage
}

struct OpenAIChoice: Codable {
    let index: Int
    let message: OpenAIMessage
    let finishReason: String?
    
    enum CodingKeys: String, CodingKey {
        case index, message
        case finishReason = "finish_reason"
    }
}

struct OpenAIMessage: Codable {
    let role: String
    let content: String
}

struct OpenAIUsage: Codable {
    let promptTokens: Int
    let completionTokens: Int
    let totalTokens: Int
    
    enum CodingKeys: String, CodingKey {
        case promptTokens = "prompt_tokens"
        case completionTokens = "completion_tokens"
        case totalTokens = "total_tokens"
    }
}

// MARK: - 🧪 테스트 지원

extension OpenAIAPIService {
    
    /// API 연결 테스트
    func testConnection() async -> Bool {
        do {
            let testResponse = try await sendMessage(
                content: "Hello, test connection.",
                systemPrompt: "You are a helpful assistant. Respond briefly.",
                mode: .generalConversation,
                tokenConfig: TokenConfiguration(maxTokens: 50)
            )
            
            print("✅ [OpenAI] 연결 테스트 성공: \(testResponse.content.prefix(50))")
            return true
            
        } catch {
            print("❌ [OpenAI] 연결 테스트 실패: \(error)")
            return false
        }
    }
    
    /// Structured Outputs 테스트
    func testStructuredOutput() async -> Bool {
        do {
            let testResponse = try await sendMessage(
                content: "Create a simple JSON with name and age fields.",
                systemPrompt: "Return a JSON object with the requested fields.",
                mode: .presetRecommendation,
                tokenConfig: TokenConfiguration(
                    maxTokens: 100,
                    responseFormat: .json
                )
            )
            
            // JSON 파싱 가능한지 확인
            if let data = testResponse.content.data(using: .utf8),
               let _ = try? JSONSerialization.jsonObject(with: data) {
                print("✅ [OpenAI] Structured Output 테스트 성공")
                return true
            } else {
                print("❌ [OpenAI] Structured Output 테스트 실패: 유효하지 않은 JSON")
                return false
            }
            
        } catch {
            print("❌ [OpenAI] Structured Output 테스트 실패: \(error)")
            return false
        }
    }
}