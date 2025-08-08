//
//  OpenRouterFallbackManager.swift
//  DeepSleep
//
//  Created by Agent on 2025-08-08.
//

import Foundation

/// 간단한 OpenRouter 무료/테스트 모델 폴백 매니저
/// - 베타 기간: 무료 모델 우선 순차 시도
/// - 목표: 한국어 대화, 프리셋 추천 파싱, JSON 생성 안정성
final class OpenRouterFallbackManager {
    static let shared = OpenRouterFallbackManager()
    private init() {}

    // 🎯 통합 무료 모델 리스트 (지능순 + 한국어 대화 + JSON 파싱 최적화)
    // 웹 검색 결과 기반으로 성능 순서 재배치 (2025년 8월 기준)
    private let unifiedFreeModels: [String] = [
        // Tier 1: 최고 성능 추론 모델들 (한국어 + JSON 특화)
        "deepseek/deepseek-r1:free",                    // 🥇 최신 추론 모델, O3급 성능
        "deepseek/deepseek-r1-0528:free",               // 🥈 안정화된 R1, 수학/코딩 우수
        "deepseek/deepseek-r1-0528-qwen3-8b:free",     // 🥉 경량화된 R1, 8B로 235B급 성능
        
        // Tier 2: 대형 고성능 모델들 (한국어 우수)
        "qwen/qwen-2.5-72b-instruct:free",             // 72B 대형, JSON 생성 특화
        "qwen/qwen-2.5-coder-32b-instruct:free",       // 코딩/JSON 특화, 한국어 지원
        "meta-llama/llama-3.3-70b-instruct:free",      // Meta 최신 70B, 범용성 우수
        "shisa-ai/shisa-v2-llama3.3-70b:free",         // 일본어 특화이지만 한국어도 우수
        
        // Tier 3: 중형 안정 모델들 (JSON 파싱 안정)
        "mistralai/mistral-small-3.2-24b-instruct:free", // 최신 Mistral, JSON 안정
        "mistralai/mistral-small-24b-instruct-2501:free", // 2025년 1월 최신
        "google/gemma-3-27b-it:free",                   // Google 대형 Gemma
        "qwen/qwq-32b:free",                           // 추론 능력 우수
        
        // Tier 4: 실험적 고성능 모델들
        "google/gemini-2.0-flash-exp:free",            // 최신 Gemini 실험 모델
        "google/gemini-2.5-pro-exp-03-25",            // Gemini 2.5 Pro 실험
        "nvidia/llama-3.1-nemotron-ultra-253b-v1:free", // NVIDIA 초대형 (제한적)
        "rekaai/reka-flash-3:free",                    // Reka 최신
        
        // Tier 5: 중형 백업 모델들
        "google/gemma-3-12b-it:free",                  // 중형 Gemma
        "mistralai/mistral-small-3.1-24b-instruct:free", // 검증된 안정성
        "mistralai/mistral-nemo:free",                 // 경량 Mistral
        "moonshotai/kimi-dev-72b:free",                // Moonshot 대형
        
        // Tier 6: 경량 백업 모델들
        "qwen/qwen3-30b-a3b:free",                     // Qwen 3세대 30B
        "deepseek/deepseek-chat-v3-0324:free",         // DeepSeek 채팅 특화
        "google/gemma-3-4b-it:free",                   // 경량 Gemma
        "qwen/qwen3-14b:free",                         // 중소형 Qwen
        "mistralai/devstral-small-2505:free",          // 개발 특화
        "qwen/qwen3-8b:free",                          // 경량 Qwen
        "meta-llama/llama-3.2-11b-vision-instruct:free" // 비전 지원 (제외 대상이지만 백업용)
    ]

    /// 모드별 기본 시스템 지침 (간결)
    private func systemPromptPrefix(for mode: AIMode) -> String {
        switch mode {
        case .presetRecommendation:
            return "다음 규칙을 반드시 지키세요. 1) 한국어로 답변. 2) JSON만 출력. 3) 키는 preset, volumes, rationale. 4) 문자열에 줄바꿈/설명 포함 금지."
        case .emotionAnalysis:
            return "한국어로 감정을 분석하세요. JSON만 출력. 키는 primary, intensity(0..1), secondary(사전)."
        default:
            return "한국어로 간결하고 친절하게 답변하세요."
        }
    }

    /// OpenRouter 호출 (순차 폴백) - 통합된 무료 모델 리스트 사용
    func sendMessageWithFallback(content: String, mode: AIMode) async throws -> String {
        var tried: [String] = []
        var lastError: Error?

        print("🔄 [OpenRouterFallback] 순차 폴백 시작 - 총 \(unifiedFreeModels.count)개 모델")
        
        for (index, model) in unifiedFreeModels.enumerated() {
            do {
                print("🔄 [OpenRouterFallback] \(index + 1)/\(unifiedFreeModels.count) 시도: \(model)")
                
                let prefixed = systemPromptPrefix(for: mode) + "\n\n" + content
                let output = try await callOpenRouter(model: model, userContent: prefixed)
                
                print("✅ [OpenRouterFallback] 성공: \(model)")
                return output
                
            } catch {
                tried.append(model)
                lastError = error
                print("❌ [OpenRouterFallback] \(model) 실패: \(error.localizedDescription)")
                
                // 처음 몇 개 모델 실패 시 더 자세한 로그
                if index < 5 {
                    print("🔍 [OpenRouterFallback] 상세 오류: \(error)")
                }
                
                continue
            }
        }
        
        print("💥 [OpenRouterFallback] 모든 \(tried.count)개 모델 실패")
        print("🔍 [OpenRouterFallback] 시도한 모델들: \(tried.joined(separator: ", "))")
        throw AIServiceError.allModelsFailed(tried)
    }

    private struct ORMessage: Codable { let role: String; let content: String }
    private struct ORRequest: Codable { let model: String; let messages: [ORMessage] }
    private struct ORChoice: Codable { let message: ORMessage }
    private struct ORResponse: Codable { let choices: [ORChoice]? }

    private func callOpenRouter(model: String, userContent: String) async throws -> String {
        guard let url = URL(string: "https://openrouter.ai/api/v1/chat/completions") else {
            throw AIServiceError.invalidURL
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // 환경에서 안전하게 API 키 로드 (Info.plist에 OPENROUTER_API_KEY 존재 가정)
        guard let apiKey = Bundle.main.object(forInfoDictionaryKey: "OPENROUTER_API_KEY") as? String, !apiKey.isEmpty else {
            throw AIServiceError.configurationError("OPENROUTER_API_KEY 누락")
        }
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        if let referer = Bundle.main.bundleIdentifier {
            req.setValue(referer, forHTTPHeaderField: "HTTP-Referer")
            req.setValue("DeepSleep", forHTTPHeaderField: "X-Title")
        }

        let body = ORRequest(model: model, messages: [
            ORMessage(role: "user", content: userContent)
        ])
        req.httpBody = try JSONEncoder().encode(body)

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw AIServiceError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            if let text = String(data: data, encoding: .utf8) {
                throw AIServiceError.apiError(http.statusCode, text)
            } else {
                throw AIServiceError.httpError(http.statusCode)
            }
        }
        let decoded = try JSONDecoder().decode(ORResponse.self, from: data)
        guard let content = decoded.choices?.first?.message.content, !content.isEmpty else {
            throw AIServiceError.invalidResponse
        }
        return content
    }
}

