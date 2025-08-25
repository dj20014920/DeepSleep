//
//  NaverAPIService.swift
//  DeepSleep
//
//  Created by Claude on 2025-07-21.
//  Copyright © 2025 DeepSleep. All rights reserved.
//

import Foundation

/// 🔷 **Naver HyperCLOVA X API 서비스**
/// Naver HyperCLOVA X 모델과의 통신을 담당하는 서비스
/// PERF-WARNING: 한국어 특화 모델로 인한 추가 전처리 시간 발생 가능
/// - 테스트 방안: Instruments의 Time Profiler로 전처리 시간 측정
class NaverAPIService {
    private let apiKey: String
    private let apiSecret: String
    private let baseURL = "https://clovastudio.stream.ntruss.com/testapp/v1/chat-completions/HCX-003"
    private let defaultModel = "HCX-003" // 2025년 기준 최신 HyperCLOVA X 모델
    
    // MARK: - 초기화
    
    init(apiKey: String) {
        // Naver API 키는 "key:secret" 형식으로 저장되어 있을 수 있음
        let components = apiKey.components(separatedBy: ":")
        if components.count == 2 {
            self.apiKey = components[0]
            self.apiSecret = components[1]
        } else {
            self.apiKey = apiKey
            self.apiSecret = "" // 별도 시크릿이 없는 경우
        }
        
        // Naver 서비스 초기화됨
    }
    
    // MARK: - 🚀 메시지 전송 메인 함수
    
    func sendMessage(
        content: String,
        systemPrompt: String,
        mode: AIMode,
        tokenConfig: TokenConfiguration
    ) async throws -> AIResponse {
        
        let startTime = Date()
        print("🔷 [Naver] 메시지 전송 시작 - 모드: \(mode.rawValue)")
        
        // 1. 요청 데이터 구성
        let requestBody = buildNaverRequest(
            content: content,
            systemPrompt: systemPrompt,
            tokenConfig: tokenConfig
        )
        
        // 2. API 요청
        let responseData = try await performAPIRequest(requestBody: requestBody)
        
        // 3. 응답 파싱
        let naverResponse = try parseNaverResponse(responseData)
        
        // 4. AIResponse로 변환
        let processingTime = Date().timeIntervalSince(startTime)
        return convertToAIResponse(
            naverResponse: naverResponse,
            mode: mode,
            processingTime: processingTime
        )
    }
    
    /// 멀티-메시지 전송 (역할 기반)
    /// HyperCLOVA X는 다양한 메시지 역할 지원이 제한될 수 있어 안전하게 system + 합성 본문으로 전송
    func sendMessages(
        messages: [RoleMessage],
        mode: AIMode,
        tokenConfig: TokenConfiguration
    ) async throws -> AIResponse {
        let startTime = Date()
        print("🔷 [Naver] 멀티-메시지 전송 시작 - 모드: \(mode.rawValue), 메시지: \(messages.count)개")
        let composed = composeFromMessages(messages)
        let response = try await sendMessage(
            content: composed.body,
            systemPrompt: composed.system,
            mode: mode,
            tokenConfig: tokenConfig
        )
        let processingTime = Date().timeIntervalSince(startTime)
        return AIResponse(
            id: response.id,
            model: response.model,
            mode: response.mode,
            content: response.content,
            metadata: response.metadata,
            usage: response.usage,
            timestamp: response.timestamp,
            processingTime: Int(processingTime * 1000)
        )
    }
    
    // MARK: - 🔧 Naver API 요청 구성
    
    private func buildNaverRequest(
        content: String,
        systemPrompt: String,
        tokenConfig: TokenConfiguration
    ) -> [String: Any] {
        
        // HyperCLOVA X API 형식에 맞는 요청 구성
        var requestBody: [String: Any] = [
            "messages": [
                [
                    "role": "system",
                    "content": systemPrompt
                ],
                [
                    "role": "user",
                    "content": content
                ]
            ],
            "topP": tokenConfig.topP ?? 0.8,
            "topK": 0,
            "maxTokens": tokenConfig.maxTokens,
            "temperature": tokenConfig.temperature,
            "repeatPenalty": tokenConfig.presencePenalty ?? 5.0,
            "stopBefore": [],
            "includeAiFilters": true,
            "seed": 0
        ]
        
        // 선택적 파라미터 추가
        if let frequencyPenalty = tokenConfig.frequencyPenalty {
            requestBody["frequencyPenalty"] = frequencyPenalty
        }
        
        return requestBody
    }
    
    /// 역할 기반 메시지를 안전한 단일 문자열로 합성
    private func composeFromMessages(_ messages: [RoleMessage]) -> (system: String, body: String) {
        let systemCombined = messages.filter { $0.role == .system }.map { $0.content }.joined(separator: "\n\n")
        let history = messages.filter { $0.role != .system }
        var lines: [String] = []
        for m in history {
            let roleLabel: String
            switch m.role {
            case .user: roleLabel = "사용자"
            case .assistant: roleLabel = "AI"
            case .system: roleLabel = "시스템" // 여기 오지 않음
            }
            lines.append("- \(roleLabel): \(m.content)")
        }
        let body = lines.joined(separator: "\n")
        return (system: systemCombined, body: body)
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
        
        // Naver API는 추가 헤더가 필요할 수 있음
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        // API Secret이 있는 경우 추가
        if !apiSecret.isEmpty {
            request.setValue(apiSecret, forHTTPHeaderField: "X-NCP-CLOVASTUDIO-API-SECRET")
        }
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            print("❌ [Naver] 요청 직렬화 실패: \(error)")
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
                    throw AIServiceError.quotaExceeded(model: .naver)
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
    
    private func parseNaverResponse(_ data: Data) throws -> NaverResponse {
        do {
            // 디버깅을 위한 응답 로깅
            if let jsonString = String(data: data, encoding: .utf8) {
                print("🔷 [Naver] 응답 수신: \(jsonString.prefix(200))...")
            }
            
            let decoder = JSONDecoder()
            return try decoder.decode(NaverResponse.self, from: data)
            
        } catch {
            print("❌ [Naver] 응답 파싱 실패: \(error)")
            
            // 에러 응답인지 확인
            if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = errorData["error"] as? [String: Any] {
                throw handleNaverError(error)
            }
            
            throw AIServiceError.invalidResponse
        }
    }
    
    // MARK: - 🔄 응답 변환
    
    private func convertToAIResponse(
        naverResponse: NaverResponse,
        mode: AIMode,
        processingTime: TimeInterval
    ) -> AIResponse {
        
        // Naver 응답에서 텍스트 추출
        let content = naverResponse.result.message.content
        
        // 토큰 사용량 정보
        let usage = TokenUsage(
            promptTokens: naverResponse.result.inputLength ?? 0,
            completionTokens: naverResponse.result.outputLength ?? 0,
            totalTokens: (naverResponse.result.inputLength ?? 0) + (naverResponse.result.outputLength ?? 0),
            estimatedCost: calculateEstimatedCost(naverResponse.result)
        )
        
        // 메타데이터 구성
        var additionalInfo: [String: Any] = [
            "model": defaultModel,
            "stop_reason": naverResponse.result.stopReason
        ]
        
        // AI 필터 결과 추가 (배열 지원)
        if let aiFilters = naverResponse.result.aiFilter, !aiFilters.isEmpty {
            additionalInfo["ai_filter"] = aiFilters.map { filter in
                [
                    "groupName": filter.groupName,
                    "name": filter.name,
                    "score": filter.score
                ]
            }
        }
        
        // 한국어 특화 신뢰도 점수 (Naver는 한국어에 강함)
        let confidenceScore: Double = content.contains { char in
            let scalar = char.unicodeScalars.first!
            return (0xAC00...0xD7AF).contains(scalar.value) // 한글 유니코드 범위
        } ? 0.88 : 0.78 // 한국어 포함 시 더 높은 신뢰도
        
        let metadata = ResponseMetadata(
            emotionAnalysis: nil,
            recommendations: nil,
            confidenceScore: confidenceScore,
            additionalInfo: additionalInfo
        )
        
        return AIResponse(
            id: naverResponse.result.requestId,
            model: .naver,
            mode: mode,
            content: content,
            metadata: metadata,
            usage: usage,
            timestamp: Date(),
            processingTime: Int(processingTime * 1000)
        )
    }
    
    // MARK: - 💰 비용 계산
    
    private func calculateEstimatedCost(_ result: NaverResult) -> Double {
        // HyperCLOVA X 가격 (2025년 기준 예상) - 일반적으로 가장 저렴
        let inputCostPer1000 = 0.0002   // $0.0002 per 1K input tokens
        let outputCostPer1000 = 0.0008  // $0.0008 per 1K output tokens
        
        let inputTokens = Double(result.inputLength ?? 0)
        let outputTokens = Double(result.outputLength ?? 0)
        
        let inputCost = inputTokens / 1000.0 * inputCostPer1000
        let outputCost = outputTokens / 1000.0 * outputCostPer1000
        
        return inputCost + outputCost
    }
    
    // MARK: - ❌ 에러 처리
    
    private func handleNaverError(_ error: [String: Any]) -> AIServiceError {
        let code = error["code"] as? String ?? "UNKNOWN"
        let message = error["message"] as? String ?? "Unknown error"
        let statusCode = error["status"] as? Int ?? 0
        
        print("❌ [Naver] 에러 응답: \(code) - \(message)")
        
        switch code {
        case "UNAUTHORIZED":
            return .unauthorized
        case "FORBIDDEN":
            return .quotaExceeded(model: .naver)
        case "TOO_MANY_REQUESTS":
            return .rateLimitExceeded
        case "INTERNAL_SERVER_ERROR", "SERVICE_UNAVAILABLE":
            return .serverError(statusCode: statusCode)
        case "INVALID_PARAMETER":
            return .invalidResponse
        default:
            return .unknown(NSError(domain: "NaverAPI", code: statusCode, userInfo: [NSLocalizedDescriptionKey: message]))
        }
    }
}

// MARK: - 📋 Naver API 응답 모델

struct NaverResponse: Codable {
    let status: NaverStatus
    let result: NaverResult
}

struct NaverStatus: Codable {
    let code: String
    let message: String
}

struct NaverResult: Codable {
    let message: NaverMessage
    let inputLength: Int?
    let outputLength: Int?
    let stopReason: String
    let seed: Int?
    let aiFilter: [NaverAIFilter]? // 서버가 배열 또는 단일 객체로 제공되는 변종 모두 지원
    let requestId: String
    
    enum CodingKeys: String, CodingKey {
        case message
        case inputLength = "inputLength"
        case outputLength = "outputLength"
        case stopReason = "stopReason"
        case seed
        case aiFilter = "aiFilter"
        case requestId = "requestId"
    }
    
    init(message: NaverMessage, inputLength: Int?, outputLength: Int?, stopReason: String, seed: Int?, aiFilter: [NaverAIFilter]?, requestId: String) {
        self.message = message
        self.inputLength = inputLength
        self.outputLength = outputLength
        self.stopReason = stopReason
        self.seed = seed
        self.aiFilter = aiFilter
        self.requestId = requestId
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.message = try container.decode(NaverMessage.self, forKey: .message)
        self.inputLength = try container.decodeIfPresent(Int.self, forKey: .inputLength)
        self.outputLength = try container.decodeIfPresent(Int.self, forKey: .outputLength)
        self.stopReason = try container.decode(String.self, forKey: .stopReason)
        self.seed = try container.decodeIfPresent(Int.self, forKey: .seed)
        // aiFilter: 배열 또는 단일 객체 모두 지원
        if let filters = try? container.decode([NaverAIFilter].self, forKey: .aiFilter) {
            self.aiFilter = filters
        } else if let single = try? container.decode(NaverAIFilter.self, forKey: .aiFilter) {
            self.aiFilter = [single]
        } else {
            self.aiFilter = nil
        }
        self.requestId = try container.decode(String.self, forKey: .requestId)
    }
}

struct NaverMessage: Codable {
    let role: String
    let content: String
}

struct NaverAIFilter: Codable {
    let groupName: String
    let name: String
    let score: Double
    
    enum CodingKeys: String, CodingKey {
        case groupName = "groupName"
        case name
        case score
    }
}
