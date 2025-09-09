//
//  FreeAIModels.swift
//  DeepSleep
//
//  무료 AI 모델 정의 및 관리
//

import Foundation

/// 무료 AI 모델 정의
public enum FreeAIModel: String, CaseIterable {
    // Tier 1 - 최우선
    case openAIGPTOSS = "openai/gpt-oss-120b:free"
    case qwenCoder32B = "qwen/qwen-2.5-coder-32b-instruct:free"
    case llamaUltra405B = "meta-llama/llama-3.1-405b-instruct:free"
    case qwen72B = "qwen/qwen-2.5-72b-instruct:free"

    // Tier 2 - 백업
    case geminiFlash = "google/gemini-2.0-flash-exp:free"
    case deepseekR1 = "deepseek/deepseek-r1:free"
    case nemotronUltra = "nvidia/llama-3.1-nemotron-ultra-253b-v1:free"

    // Tier 3 - 추가 폴백
    case mistralSmall = "mistralai/mistral-small-3.2-24b-instruct:free"
    case llama70B = "meta-llama/llama-3.3-70b-instruct:free"
    case gemma27B = "google/gemma-3-27b-it:free"
    case qwq32B = "qwen/qwq-32b:free"

    // 추가 모델들 (필요시 활성화)
    case deepseekR1Distill14B = "deepseek/deepseek-r1-distill-qwen-14b:free"
    case deepseekR1Distill70B = "deepseek/deepseek-r1-distill-llama-70b:free"
    case gemini2Flash = "google/gemini-2.5-flash-exp:free"
    case glm4Air = "z-ai/glm-4.5-air:free"
    case kimiDev72B = "moonshotai/kimi-dev-72b:free"

    var displayName: String {
        switch self {
        case .qwenCoder32B: return "Qwen 2.5 Coder (32B)"
        case .llamaUltra405B: return "Llama 3.1 Ultra (405B)"
        case .qwen72B: return "Qwen 2.5 (72B)"
        case .geminiFlash: return "Gemini Flash 2.0"
        case .deepseekR1: return "DeepSeek R1"
        case .nemotronUltra: return "Nemotron Ultra (253B)"
        case .mistralSmall: return "Mistral Small 3.2"
        case .llama70B: return "Llama 3.3 (70B)"
        case .gemma27B: return "Gemma 3 (27B)"
        case .qwq32B: return "QwQ (32B)"
        case .deepseekR1Distill14B: return "DeepSeek R1 Distill (14B)"
        case .deepseekR1Distill70B: return "DeepSeek R1 Distill (70B)"
        case .gemini2Flash: return "Gemini 2.5 Flash"
        case .openAIGPTOSS: return "GPT-OSS (120B)"
        case .glm4Air: return "GLM 4.5 Air"
        case .kimiDev72B: return "Kimi Dev (72B)"
        }
    }

    var priority: Int {
        switch self {
        // Tier 0 - 최우선: GPT-OSS
        case .openAIGPTOSS: return 1
        // Tier 1
        case .qwenCoder32B: return 2
        case .llamaUltra405B: return 3
        case .qwen72B: return 4
        // Tier 2
        case .geminiFlash: return 5
        case .deepseekR1: return 6
        case .nemotronUltra: return 7
        // Tier 3
        case .mistralSmall: return 8
        case .llama70B: return 9
        case .gemma27B: return 10
        case .qwq32B: return 11
        // 추가 모델
        default: return 99
        }
    }

    /// 특정 용도에 최적화된 모델 선택
    static func recommendedModel(for mode: AIMode) -> FreeAIModel {
        switch mode {
        case .presetRecommendation:
            // 창의성이 필요한 작업 - 대형 모델 우선
            return .llamaUltra405B
        case .emotionAnalysis, .emotionDiaryAnalysis:
            // 감정 분석 - DeepSeek이 강함
            return .deepseekR1
        case .generalConversation:
            // 일반 대화 - GPT-OSS 우선
            return .openAIGPTOSS
        case .taskAdvice, .monthlyStatistics:
            // 구조화된 응답 - Qwen이 JSON에 강함
            return .qwen72B
        case .fortuneTelling:
            // 창의적 답변 - Gemini
            return .geminiFlash
        default:
            return .qwenCoder32B
        }
    }
}

/// 무료 모델 사용량 추적
public class FreeModelUsageTracker {
    static let shared = FreeModelUsageTracker()

    private var modelUsageCount: [String: Int] = [:]
    private var modelLastUsed: [String: Date] = [:]
    private var modelFailureCount: [String: Int] = [:]

    private let userDefaults = UserDefaults.standard
    private let usageKey = "freeModelUsage"
    private let failureKey = "freeModelFailures"

    private init() {
        loadUsageData()
    }

    func incrementUsage(for model: FreeAIModel) {
        let key = model.rawValue
        modelUsageCount[key] = (modelUsageCount[key] ?? 0) + 1
        modelLastUsed[key] = Date()
        saveUsageData()
    }

    func incrementFailure(for model: FreeAIModel) {
        let key = model.rawValue
        modelFailureCount[key] = (modelFailureCount[key] ?? 0) + 1
        saveUsageData()
    }

    func resetFailures(for model: FreeAIModel) {
        modelFailureCount[model.rawValue] = 0
        saveUsageData()
    }

    func canUseModel(_ model: FreeAIModel) -> Bool {
        let failureCount = modelFailureCount[model.rawValue] ?? 0

        // 5회 이상 실패한 모델은 1시간 동안 사용 불가
        if failureCount >= 5 {
            if let lastUsed = modelLastUsed[model.rawValue],
                Date().timeIntervalSince(lastUsed) < 3600
            {
                return false
            } else {
                // 1시간 지났으면 실패 카운트 리셋
                resetFailures(for: model)
                return true
            }
        }

        return true
    }

    func getNextAvailableModel(excluding: [FreeAIModel] = []) -> FreeAIModel? {
        let sortedModels = FreeAIModel.allCases.sorted { $0.priority < $1.priority }

        for model in sortedModels {
            if !excluding.contains(model) && canUseModel(model) {
                return model
            }
        }

        return nil
    }

    private func loadUsageData() {
        if let data = userDefaults.data(forKey: usageKey),
            let decoded = try? JSONDecoder().decode([String: Int].self, from: data)
        {
            modelUsageCount = decoded
        }

        if let data = userDefaults.data(forKey: failureKey),
            let decoded = try? JSONDecoder().decode([String: Int].self, from: data)
        {
            modelFailureCount = decoded
        }
    }

    private func saveUsageData() {
        if let encoded = try? JSONEncoder().encode(modelUsageCount) {
            userDefaults.set(encoded, forKey: usageKey)
        }

        if let encoded = try? JSONEncoder().encode(modelFailureCount) {
            userDefaults.set(encoded, forKey: failureKey)
        }
    }
}
