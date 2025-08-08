//
//  ClaudeAPIService.swift
//  DeepSleep
//
//  Created by Claude on 2025-07-21.
//  Copyright © 2025 DeepSleep. All rights reserved.
//

import Foundation

/// 🤖 **Claude API 서비스**
/// Anthropic Claude API와의 통신을 담당하는 서비스
/// PERF-WARNING: 대량 토큰 처리 시 메모리 사용량 주의
/// - 테스트 방안: Instruments의 Network 프로파일러로 네트워크 성능 측정
class ClaudeAPIService {
    private let apiKey: String
    private let baseURL = "https://api.anthropic.com/v1/messages"
    private let defaultModel = "claude-3-5-sonnet-20241022" // 2025년 최신 모델
    
    // MARK: - 초기화
    
    init(apiKey: String) {
        self.apiKey = apiKey
        // Claude API 서비스 초기화됨
    }
    
    // MARK: - 🚀 메시지 전송 메인 함수
    
    func sendMessage(
        content: String,
        systemPrompt: String,
        mode: AIMode,
        tokenConfig: TokenConfiguration
    ) async throws -> AIResponse {
        
        let startTime = Date()
        print("🤖 [ClaudeAPI] 메시지 전송 시작 - 모드: \(mode.rawValue)")
        
        // 1. 요청 데이터 구성
        let requestBody = buildClaudeRequest(
            content: content,
            systemPrompt: systemPrompt,
            tokenConfig: tokenConfig
        )
        
        // 2. API 요청
        let responseData = try await performAPIRequest(requestBody: requestBody)
        
        // 3. 응답 파싱
        let claudeResponse = try parseClaudeResponse(responseData)
        
        // 4. AIResponse로 변환
        let processingTime = Date().timeIntervalSince(startTime)
        return convertToAIResponse(
            claudeResponse: claudeResponse,
            mode: mode,
            processingTime: processingTime
        )
    }
    
    // MARK: - 🔧 Claude API 요청 구성
    
    private func buildClaudeRequest(
        content: String,
        systemPrompt: String,
        tokenConfig: TokenConfiguration
    ) -> [String: Any] {
        
        // Claude API 2025년 형식에 맞는 요청 구성
        return [
            "model": defaultModel,
            "max_tokens": tokenConfig.maxTokens,
            "temperature": tokenConfig.temperature,
            "system": systemPrompt,
            "messages": [
                [
                    "role": "user",
                    "content": content
                ]
            ]
        ]
    }
    
    // MARK: - 🌐 API 요청 수행
    
    private func performAPIRequest(requestBody: [String: Any]) async throws -> Data {
        guard let url = URL(string: baseURL) else {
            throw AIServiceError.invalidResponse
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version") // API 버전
        
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
    
    private func parseClaudeResponse(_ data: Data) throws -> ClaudeResponse {
        do {
            // 응답을 String으로 변환하여 디버깅
            if let jsonString = String(data: data, encoding: .utf8) {
                print("🤖 [ClaudeAPI] 응답 수신: \(jsonString.prefix(200))...")
            }
            
            let decoder = JSONDecoder()
            return try decoder.decode(ClaudeResponse.self, from: data)
            
        } catch {
            print("❌ [ClaudeAPI] 응답 파싱 실패: \(error)")
            throw AIServiceError.invalidResponse
        }
    }
    
    // MARK: - 🔄 응답 변환
    
    private func convertToAIResponse(
        claudeResponse: ClaudeResponse,
        mode: AIMode,
        processingTime: TimeInterval
    ) -> AIResponse {
        
        // Claude 응답에서 텍스트 추출
        let content = claudeResponse.content.first?.text ?? ""
        
        // 토큰 사용량 정보
        let usage = TokenUsage(
            promptTokens: claudeResponse.usage.inputTokens,
            completionTokens: claudeResponse.usage.outputTokens,
            totalTokens: claudeResponse.usage.inputTokens + claudeResponse.usage.outputTokens,
            estimatedCost: calculateEstimatedCost(claudeResponse.usage)
        )
        
        // 메타데이터 구성
        let metadata = ResponseMetadata(
            emotionAnalysis: nil, // TODO: 필요시 감정 분석 추가
            recommendations: nil, // TODO: 필요시 추천 항목 추가
            confidenceScore: 0.85, // Claude는 일반적으로 높은 품질
            additionalInfo: [
                "model": claudeResponse.model,
                "stop_reason": claudeResponse.stopReason ?? "end_turn"
            ]
        )
        
        return AIResponse(
            id: claudeResponse.id,
            model: .claude,
            mode: mode,
            content: content,
            metadata: metadata,
            usage: usage,
            timestamp: Date(),
            processingTime: Int(processingTime * 1000) // 밀리초로 변환
        )
    }
    
    // MARK: - 💰 비용 계산
    
    private func calculateEstimatedCost(_ usage: ClaudeUsage) -> Double {
        // Claude 3.5 Sonnet 가격 (2025년 기준 예상)
        let inputCostPer1000 = 0.003  // $0.003 per 1K input tokens
        let outputCostPer1000 = 0.015 // $0.015 per 1K output tokens
        
        let inputCost = Double(usage.inputTokens) / 1000.0 * inputCostPer1000
        let outputCost = Double(usage.outputTokens) / 1000.0 * outputCostPer1000
        
        return inputCost + outputCost
    }
}

// MARK: - 📋 Claude API 응답 모델

struct ClaudeResponse: Codable {
    let id: String
    let type: String
    let role: String
    let content: [ClaudeContent]
    let model: String
    let stopReason: String?
    let stopSequence: String?
    let usage: ClaudeUsage
    
    enum CodingKeys: String, CodingKey {
        case id, type, role, content, model, usage
        case stopReason = "stop_reason"
        case stopSequence = "stop_sequence"
    }
}

struct ClaudeContent: Codable {
    let type: String
    let text: String
}

struct ClaudeUsage: Codable {
    let inputTokens: Int
    let outputTokens: Int
    
    enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
    }
}

// MARK: - 🔍 에러 처리 확장

extension ClaudeAPIService {
    
    /// Claude API 에러 응답 처리
    private func handleClaudeError(_ data: Data) -> AIServiceError {
        do {
            if let errorResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = errorResponse["error"] as? [String: Any],
               let type = error["type"] as? String,
               let message = error["message"] as? String {
                
                print("❌ [ClaudeAPI] 에러 응답: \(type) - \(message)")
                
                switch type {
                case "authentication_error":
                    return .unauthorized
                case "rate_limit_error":
                    return .rateLimitExceeded
                case "overloaded_error":
                    return .serverError(statusCode: 503)
                default:
                    return .unknown(NSError(domain: "ClaudeAPI", code: 0, userInfo: [NSLocalizedDescriptionKey: message]))
                }
            }
        } catch {
            print("❌ [ClaudeAPI] 에러 응답 파싱 실패: \(error)")
        }
        
        return .invalidResponse
    }
}

// MARK: - 🧪 테스트 지원

extension ClaudeAPIService {
    
    /// API 연결 테스트
    func testConnection() async -> Bool {
        do {
            let testResponse = try await sendMessage(
                content: "Hello, test connection.",
                systemPrompt: "You are a helpful assistant. Respond briefly.",
                mode: .generalConversation,
                tokenConfig: TokenConfiguration(maxTokens: 50)
            )
            
            print("✅ [ClaudeAPI] 연결 테스트 성공: \(testResponse.content.prefix(50))")
            return true
            
        } catch {
            print("❌ [ClaudeAPI] 연결 테스트 실패: \(error)")
            return false
        }
    }
}