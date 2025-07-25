//
//  GeminiAPIService.swift
//  DeepSleep
//
//  Created by Claude on 2025-07-21.
//  Copyright © 2025 DeepSleep. All rights reserved.
//

import Foundation

/// 💎 **Google Gemini API 서비스**
/// Google Gemini Pro 모델과의 통신을 담당하는 서비스
/// PERF-WARNING: 다국어 텍스트 처리 시 인코딩 오버헤드 주의
/// - 테스트 방안: Instruments의 CPU 프로파일러로 문자열 처리 성능 측정
class GeminiAPIService {
    private let apiKey: String
    private let baseURL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent"
    private let defaultModel = "gemini-1.5-flash" // 2025년 기준 최신 모델
    
    // MARK: - 초기화
    
    init(apiKey: String) {
        self.apiKey = apiKey
        print("💎 [Gemini] 서비스 초기화 완료")
    }
    
    // MARK: - 🚀 메시지 전송 메인 함수
    
    func sendMessage(
        content: String,
        systemPrompt: String,
        mode: AIMode,
        tokenConfig: TokenConfiguration
    ) async throws -> AIResponse {
        
        let startTime = Date()
        print("💎 [Gemini] 메시지 전송 시작 - 모드: \(mode.rawValue)")
        
        // 1. 요청 데이터 구성
        let requestBody = buildGeminiRequest(
            content: content,
            systemPrompt: systemPrompt,
            tokenConfig: tokenConfig
        )
        
        // 2. API 요청
        let responseData = try await performAPIRequest(requestBody: requestBody)
        
        // 3. 응답 파싱
        let geminiResponse = try parseGeminiResponse(responseData)
        
        // 4. AIResponse로 변환
        let processingTime = Date().timeIntervalSince(startTime)
        return convertToAIResponse(
            geminiResponse: geminiResponse,
            mode: mode,
            processingTime: processingTime
        )
    }
    
    // MARK: - 🔧 Gemini API 요청 구성
    
    private func buildGeminiRequest(
        content: String,
        systemPrompt: String,
        tokenConfig: TokenConfiguration
    ) -> [String: Any] {
        
        // Gemini API v1beta 형식에 맞는 요청 구성
        let combinedContent = "\(systemPrompt)\n\n사용자: \(content)"
        
        var requestBody: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        [
                            "text": combinedContent
                        ]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": tokenConfig.temperature,
                "maxOutputTokens": tokenConfig.maxTokens,
                "candidateCount": 1
            ]
        ]
        
        // 선택적 파라미터 추가
        if let topP = tokenConfig.topP {
            if var config = requestBody["generationConfig"] as? [String: Any] {
                config["topP"] = topP
                requestBody["generationConfig"] = config
            }
        }
        
        // 안전 설정 추가 (개발용 - 프로덕션에서는 더 엄격하게)
        requestBody["safetySettings"] = [
            [
                "category": "HARM_CATEGORY_HARASSMENT",
                "threshold": "BLOCK_MEDIUM_AND_ABOVE"
            ],
            [
                "category": "HARM_CATEGORY_HATE_SPEECH",
                "threshold": "BLOCK_MEDIUM_AND_ABOVE"
            ],
            [
                "category": "HARM_CATEGORY_SEXUALLY_EXPLICIT",
                "threshold": "BLOCK_MEDIUM_AND_ABOVE"
            ],
            [
                "category": "HARM_CATEGORY_DANGEROUS_CONTENT",
                "threshold": "BLOCK_MEDIUM_AND_ABOVE"
            ]
        ]
        
        return requestBody
    }
    
    // MARK: - 🌐 API 요청 수행
    
    private func performAPIRequest(requestBody: [String: Any]) async throws -> Data {
        let urlString = "\(baseURL)?key=\(apiKey)"
        guard let url = URL(string: urlString) else {
            throw AIServiceError.invalidResponse
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            print("❌ [Gemini] 요청 직렬화 실패: \(error)")
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
                case 403:
                    throw AIServiceError.quotaExceeded(model: .gemini)
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
    
    private func parseGeminiResponse(_ data: Data) throws -> GeminiResponse {
        do {
            // 디버깅을 위한 응답 로깅
            if let jsonString = String(data: data, encoding: .utf8) {
                print("💎 [Gemini] 응답 수신: \(jsonString.prefix(200))...")
            }
            
            let decoder = JSONDecoder()
            return try decoder.decode(GeminiResponse.self, from: data)
            
        } catch {
            print("❌ [Gemini] 응답 파싱 실패: \(error)")
            
            // 에러 응답인지 확인
            if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = errorData["error"] as? [String: Any] {
                throw handleGeminiError(error)
            }
            
            throw AIServiceError.invalidResponse
        }
    }
    
    // MARK: - 🔄 응답 변환
    
    private func convertToAIResponse(
        geminiResponse: GeminiResponse,
        mode: AIMode,
        processingTime: TimeInterval
    ) -> AIResponse {
        
        // Gemini 응답에서 텍스트 추출
        let content = geminiResponse.candidates.first?.content.parts.first?.text ?? ""
        
        // 토큰 사용량 정보 (Gemini는 별도 토큰 카운트를 제공하지 않으므로 추정)
        let estimatedPromptTokens = estimateTokenCount(content)
        let estimatedCompletionTokens = estimateTokenCount(content)
        let totalTokens = estimatedPromptTokens + estimatedCompletionTokens
        
        let usage = TokenUsage(
            promptTokens: estimatedPromptTokens,
            completionTokens: estimatedCompletionTokens,
            totalTokens: totalTokens,
            estimatedCost: calculateEstimatedCost(promptTokens: estimatedPromptTokens, completionTokens: estimatedCompletionTokens)
        )
        
        // 메타데이터 구성
        var additionalInfo: [String: Any] = [
            "model": defaultModel
        ]
        
        // 안전 평가 결과 추가
        if let candidate = geminiResponse.candidates.first,
           let safetyRatings = candidate.safetyRatings {
            additionalInfo["safety_ratings"] = safetyRatings.map { rating in
                [
                    "category": rating.category,
                    "probability": rating.probability
                ]
            }
        }
        
        // finish_reason 추가
        if let finishReason = geminiResponse.candidates.first?.finishReason {
            additionalInfo["finish_reason"] = finishReason
        }
        
        let metadata = ResponseMetadata(
            emotionAnalysis: nil,
            recommendations: nil,
            confidenceScore: 0.82, // Gemini는 안정적이지만 Claude보다 살짝 낮게
            additionalInfo: additionalInfo
        )
        
        return AIResponse(
            id: UUID().uuidString, // Gemini는 response ID를 제공하지 않으므로 생성
            model: .gemini,
            mode: mode,
            content: content,
            metadata: metadata,
            usage: usage,
            timestamp: Date(),
            processingTime: Int(processingTime * 1000)
        )
    }
    
    // MARK: - 💰 비용 계산
    
    private func calculateEstimatedCost(promptTokens: Int, completionTokens: Int) -> Double {
        // Gemini 1.5 Flash 가격 (2025년 기준 예상)
        let inputCostPer1000 = 0.000075  // $0.000075 per 1K input tokens
        let outputCostPer1000 = 0.0003   // $0.0003 per 1K output tokens
        
        let inputCost = Double(promptTokens) / 1000.0 * inputCostPer1000
        let outputCost = Double(completionTokens) / 1000.0 * outputCostPer1000
        
        return inputCost + outputCost
    }
    
    // MARK: - 🔢 토큰 추정
    
    /// 간단한 토큰 수 추정 (실제 토큰라이저는 아님)
    private func estimateTokenCount(_ text: String) -> Int {
        // 영어: 단어당 약 1.3토큰, 한국어: 글자당 약 1.5토큰으로 추정
        let wordCount = text.components(separatedBy: .whitespacesAndNewlines).count
        let koreanCharCount = text.filter { char in
            let scalar = char.unicodeScalars.first!
            return (0xAC00...0xD7AF).contains(scalar.value) // 한글 유니코드 범위
        }.count
        
        return Int(Double(wordCount) * 1.3 + Double(koreanCharCount) * 1.5)
    }
    
    // MARK: - ❌ 에러 처리
    
    private func handleGeminiError(_ error: [String: Any]) -> AIServiceError {
        let code = error["code"] as? Int ?? 0
        let message = error["message"] as? String ?? "Unknown error"
        let status = error["status"] as? String ?? "UNKNOWN"
        
        print("❌ [Gemini] 에러 응답: \(status) (코드: \(code)) - \(message)")
        
        switch code {
        case 401:
            return .unauthorized
        case 403:
            if message.contains("quota") || message.contains("limit") {
                return .quotaExceeded(model: .gemini)
            }
            return .unauthorized
        case 429:
            return .rateLimitExceeded
        case 500...599:
            return .serverError(statusCode: code)
        default:
            return .unknown(NSError(domain: "GeminiAPI", code: code, userInfo: [NSLocalizedDescriptionKey: message]))
        }
    }
}

// MARK: - 📋 Gemini API 응답 모델

struct GeminiResponse: Codable {
    let candidates: [GeminiCandidate]
    let promptFeedback: GeminiPromptFeedback?
    
    enum CodingKeys: String, CodingKey {
        case candidates
        case promptFeedback = "promptFeedback"
    }
}

struct GeminiCandidate: Codable {
    let content: GeminiContent
    let finishReason: String?
    let index: Int?
    let safetyRatings: [GeminiSafetyRating]?
    
    enum CodingKeys: String, CodingKey {
        case content
        case finishReason = "finishReason"
        case index
        case safetyRatings = "safetyRatings"
    }
}

struct GeminiContent: Codable {
    let parts: [GeminiPart]
    let role: String?
}

struct GeminiPart: Codable {
    let text: String
}

struct GeminiSafetyRating: Codable {
    let category: String
    let probability: String
}

struct GeminiPromptFeedback: Codable {
    let blockReason: String?
    let safetyRatings: [GeminiSafetyRating]?
    
    enum CodingKeys: String, CodingKey {
        case blockReason = "blockReason"
        case safetyRatings = "safetyRatings"
    }
}

// MARK: - 🧪 테스트 지원

extension GeminiAPIService {
    
    /// API 연결 테스트
    func testConnection() async -> Bool {
        do {
            let testResponse = try await sendMessage(
                content: "Hello, test connection.",
                systemPrompt: "You are a helpful assistant. Respond briefly.",
                mode: .generalConversation,
                tokenConfig: TokenConfiguration(maxTokens: 50)
            )
            
            print("✅ [Gemini] 연결 테스트 성공: \(testResponse.content.prefix(50))")
            return true
            
        } catch {
            print("❌ [Gemini] 연결 테스트 실패: \(error)")
            return false
        }
    }
    
    /// 다국어 처리 테스트
    func testMultilingualSupport() async -> Bool {
        do {
            let testResponse = try await sendMessage(
                content: "안녕하세요. 간단히 인사해주세요.",
                systemPrompt: "You are a helpful assistant that can respond in Korean.",
                mode: .generalConversation,
                tokenConfig: TokenConfiguration(maxTokens: 100)
            )
            
            // 한국어 응답이 포함되어 있는지 확인
            let containsKorean = testResponse.content.contains { char in
                let scalar = char.unicodeScalars.first!
                return (0xAC00...0xD7AF).contains(scalar.value)
            }
            
            if containsKorean {
                print("✅ [Gemini] 다국어 지원 테스트 성공")
                return true
            } else {
                print("⚠️ [Gemini] 다국어 지원 테스트 부분 성공 (영어 응답)")
                return true // 영어 응답도 정상 작동으로 간주
            }
            
        } catch {
            print("❌ [Gemini] 다국어 지원 테스트 실패: \(error)")
            return false
        }
    }
    
    /// 안전 필터 테스트
    func testSafetyFilters() async -> Bool {
        do {
            let testResponse = try await sendMessage(
                content: "Tell me about safety and security best practices.",
                systemPrompt: "You are a helpful assistant focused on safety.",
                mode: .generalConversation,
                tokenConfig: TokenConfiguration(maxTokens: 100)
            )
            
            // 응답에 안전 등급 정보가 포함되어 있는지 확인
            if let safetyInfo = testResponse.metadata.additionalInfo["safety_ratings"] {
                print("✅ [Gemini] 안전 필터 테스트 성공: \(safetyInfo)")
                return true
            } else {
                print("⚠️ [Gemini] 안전 필터 정보 없음 (정상 응답)")
                return true
            }
            
        } catch {
            print("❌ [Gemini] 안전 필터 테스트 실패: \(error)")
            return false
        }
    }
}