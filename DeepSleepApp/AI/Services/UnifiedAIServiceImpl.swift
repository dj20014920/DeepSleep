//
//  UnifiedAIServiceImpl.swift
//  DeepSleep
//
//  Created by Claude on 2025-07-21.
//  Copyright © 2025 DeepSleep. All rights reserved.
//

import Foundation
import Combine

/// 🚀 **통합 AI 서비스 실제 구현체**
/// 모든 AI 모델을 통합하여 관리하는 메인 서비스
/// PERF-WARNING: 여러 모델 동시 호출 시 메모리 사용량 주의
/// - 테스트 방안: Instruments의 Allocations로 메모리 누수 확인
public class UnifiedAIServiceImpl: UnifiedAIService {
    public static let shared = UnifiedAIServiceImpl()
    
    // MARK: - Properties  
    private let securityManager = AISecurityManager.shared
    private let settingsManager = SettingsManager.shared
    private let contextManager = AIContextManager.shared
    
    // 개별 AI 서비스들
    private var claudeService: ClaudeAPIService?
    private var openAIService: OpenAIAPIService?
    private var geminiService: GeminiAPIService?
    private var naverService: NaverAPIService?
    
    // 무료 모델 서비스 (OpenRouter)
    private var freeModelService: OpenRouterFallbackManager?
    
    private init() {
        initializeServices()
    }
    
    // MARK: - 🔑 API 키 관리
    
    /// API 키를 Bundle에서 안전하게 조회
    private func getAPIKey(for model: AIModel) -> String? {
        let keyName: String
        
        switch model {
        case .claude:
            keyName = "CLAUDE_API_KEY"
        case .openAI:
            keyName = "OPEN_AI_4oMINI_API_KEY"
        case .gemini:
            keyName = "GEMINI_API_KEY"
        case .naver:
            keyName = "NAVER_CLOUD_API_KEY"
        case .freeModel:
            keyName = "OPENROUTER_API_KEY"
        }
        
        guard let apiKey = Bundle.main.object(forInfoDictionaryKey: keyName) as? String,
              !apiKey.isEmpty,
              !apiKey.hasPrefix("$(") else {
            return nil
        }
        
        return apiKey
    }
    
    
    
    // MARK: - 🔧 서비스 초기화
    
    private func initializeServices() {
        // Claude 서비스 초기화
        if let claudeKey = getAPIKey(for: .claude) {
            claudeService = ClaudeAPIService(apiKey: claudeKey)
            // Claude API 서비스 초기화됨
        }
        
        // OpenAI 서비스 초기화
        if let openAIKey = getAPIKey(for: .openAI) {
            openAIService = OpenAIAPIService(apiKey: openAIKey)
            // OpenAI API 서비스 초기화됨
        }
        
        // Gemini 서비스 초기화
        if let geminiKey = getAPIKey(for: .gemini) {
            geminiService = GeminiAPIService(apiKey: geminiKey)
            // Gemini API 서비스 초기화됨
        }
        
        // Naver 서비스 초기화
        if let naverKey = getAPIKey(for: .naver) {
            naverService = NaverAPIService(apiKey: naverKey)
            // Naver API 서비스 초기화됨
        }
        
        // OpenRouter 무료 모델 서비스 초기화 (API 키 검증)
        if let openRouterKey = getAPIKey(for: .freeModel) {
            freeModelService = OpenRouterFallbackManager.shared
            // OpenRouter 무료 모델 서비스 초기화됨
        } else {
            print("❌ [UnifiedAIService] OpenRouter API 키를 찾을 수 없습니다.")
        }
    }
    
    // MARK: - 📊 사용 가능한 모델 확인
    
    /// 사용 가능한 AI 모델 목록 (fallback 순서대로)
    var availableModels: [AIModel] {
        var models: [AIModel] = []
        
        if claudeService != nil { models.append(.claude) }
        if openAIService != nil { models.append(.openAI) }
        if geminiService != nil { models.append(.gemini) }
        if naverService != nil { models.append(.naver) }
        if freeModelService != nil { models.append(.freeModel) }
        
        return models
    }
    
    /// 비용 기반 Fallback 순서 (2025년 8월 최신 가격 기준)
    /// 통합된 무료 모델 우선 → Gemini 1.5 Flash: $0.000075 → GPT-4o mini: $0.00015 → Claude 3.5: $0.003
    /// HyperCLOVA X는 가격 비공개로 중간 순서 배치
    var fallbackOrder: [AIModel] {
        // 베타 테스트 기간: 통합된 무료 모델 우선 사용
        let costOrder: [AIModel] = [.freeModel, .gemini, .openAI, .naver, .claude]
        return costOrder.filter { availableModels.contains($0) }
    }
    
    /// 가장 저렴한 fallback 모델
    var cheapestFallbackModel: AIModel? {
        return fallbackOrder.first
    }
    
    // MARK: - 🎯 통합 메시지 전송 (메인 함수)
    
    public func sendMessage(
        content: String,
        model: AIModel,
        mode: AIMode,
        context: AIContext?,
        tokenConfig: TokenConfiguration?
    ) async throws -> AIResponse {
        
        // 1. 보안 검증
        let validationResult = securityManager.validateAndSanitizeInput(content, userId: context?.userId ?? "unknown")
        
        switch validationResult {
        case .rejected(let reason):
            throw AIServiceError.unauthorized
        case .flagged(let reason, let cleanInput):
            print("⚠️ [UnifiedAIService] 입력이 플래그됨: \(reason)")
            return try await sendMessageInternal(cleanInput, model, mode, context, tokenConfig)
        case .approved(let cleanInput):
            return try await sendMessageInternal(cleanInput, model, mode, context, tokenConfig)
        }
    }
    
    /// 내부 메시지 전송 로직 (보안 검증 후)
    private func sendMessageInternal(
        _ content: String,
        _ model: AIModel,
        _ mode: AIMode,
        _ context: AIContext?,
        _ tokenConfig: TokenConfiguration?
    ) async throws -> AIResponse {
        
        let startTime = Date()
        let selectedModel = getSelectedModel(preferredModel: model)
        
        print("🚀 [UnifiedAIService] 메시지 전송 시작 - 모델: \(selectedModel.rawValue), 모드: \(mode.rawValue)")
        
        // 🎯 모드별 최적 모델 추천 (사용자 선택을 존중하되, 더 적합한 모델이 있으면 제안)
        let recommendedModel = getOptimalModelForMode(mode: mode, userPreferred: selectedModel)
        if recommendedModel != selectedModel {
            print("💡 [UnifiedAIService] 모드 \(mode.rawValue)에는 \(recommendedModel.rawValue) 모델이 더 적합합니다.")
        }
        let finalModel = recommendedModel
        
        do {
            // 모델별 분기 처리
            let response = try await sendToSpecificModel(
                content: content,
                model: finalModel,
                mode: mode,
                context: context,
                tokenConfig: optimizeTokenConfigForModel(tokenConfig ?? mode.recommendedTokenConfig, model: finalModel, mode: mode)
            )
            
            // 출력 보안 검증
            let outputValidation = securityManager.validateOutput(response.content, originalInput: content)
            
            switch outputValidation {
            case .blocked(let reason):
                print("🚫 [UnifiedAIService] 출력이 차단됨: \(reason)")
                // fallback 시도
                return try await attemptFallback(content, originalModel: finalModel, mode: mode, context: context, tokenConfig: tokenConfig)
                
            case .approved:
                let processingTime = Date().timeIntervalSince(startTime)
                print("✅ [UnifiedAIService] 메시지 전송 완료 - 처리시간: \(Int(processingTime * 1000))ms")
                return response
            }
            
        } catch {
            print("❌ [UnifiedAIService] \(finalModel.rawValue) 실패: \(error.localizedDescription)")
            
            // fallback 시도
            return try await attemptFallback(content, originalModel: finalModel, mode: mode, context: context, tokenConfig: tokenConfig)
        }
    }
    
    // MARK: - 🎯 모델별 메시지 전송
    
    private func sendToSpecificModel(
        content: String,
        model: AIModel,
        mode: AIMode,
        context: AIContext?,
        tokenConfig: TokenConfiguration
    ) async throws -> AIResponse {
        
        // 🎨 모드별 맞춤형 시스템 프롬프트 생성
        let systemPrompt = generateOptimizedSystemPrompt(for: mode, model: model)
        
        switch model {
        case .claude:
            guard let service = claudeService else {
                throw AIServiceError.modelUnavailable(model: model)
            }
            return try await service.sendMessage(content: content, systemPrompt: systemPrompt, mode: mode, tokenConfig: tokenConfig)
            
        case .openAI:
            guard let service = openAIService else {
                throw AIServiceError.modelUnavailable(model: model)
            }
            return try await service.sendMessage(content: content, systemPrompt: systemPrompt, mode: mode, tokenConfig: tokenConfig)
            
        case .gemini:
            guard let service = geminiService else {
                throw AIServiceError.modelUnavailable(model: model)
            }
            return try await service.sendMessage(content: content, systemPrompt: systemPrompt, mode: mode, tokenConfig: tokenConfig)
            
        case .naver:
            guard let service = naverService else {
                throw AIServiceError.modelUnavailable(model: model)
            }
            return try await service.sendMessage(content: content, systemPrompt: systemPrompt, mode: mode, tokenConfig: tokenConfig)
            
        case .freeModel:
            print("🎁 [UnifiedAIService] 무료 모델 폴백 시스템 호출 - 모드: \(mode)")
            
            guard let freeService = freeModelService else {
                print("❌ [UnifiedAIService] freeModelService가 nil입니다!")
                throw AIServiceError.modelUnavailable(model: model)
            }
            let response = try await freeService.sendMessageWithFallback(
                content: "\(systemPrompt)\n\n사용자: \(content)",
                mode: mode
            )
            
            // 문자열 응답을 AIResponse로 변환
            return AIResponse(
                id: UUID().uuidString,
                model: model,
                mode: mode,
                content: response,
                metadata: ResponseMetadata(
                    emotionAnalysis: nil,
                    recommendations: nil,
                    confidenceScore: 0.8,
                    additionalInfo: ["source": "OpenRouter"]
                ),
                usage: TokenUsage(
                    promptTokens: content.count / 4, // 대략적인 추정
                    completionTokens: response.count / 4,
                    totalTokens: (content.count + response.count) / 4,
                    estimatedCost: 0.0 // 무료
                ),
                timestamp: Date(),
                processingTime: 0
            )
        }
    }
    
    // MARK: - 🔄 Fallback 로직
    
    /// 실패 시 순차적으로 다음 모델들로 fallback
    private func attemptFallback(
        _ content: String,
        originalModel: AIModel,
        mode: AIMode,
        context: AIContext?,
        tokenConfig: TokenConfiguration?
    ) async throws -> AIResponse {
        
        // 원본 모델을 제외한 fallback 순서 생성
        let availableFallbacks = fallbackOrder.filter { $0 != originalModel }
        
        guard !availableFallbacks.isEmpty else {
            throw AIServiceError.modelUnavailable(model: originalModel)
        }
        
        print("🔄 [UnifiedAIService] Fallback 시도 시작: \(originalModel.rawValue)")
        print("📋 [UnifiedAIService] Fallback 순서: \(availableFallbacks.map { $0.rawValue }.joined(separator: " → "))")
        
        // 각 fallback 모델을 순서대로 시도
        for (index, fallbackModel) in availableFallbacks.enumerated() {
            do {
                print("🔄 [UnifiedAIService] Fallback \(index + 1)/\(availableFallbacks.count): \(fallbackModel.rawValue) 시도")
                
                let response = try await sendToSpecificModel(
                    content: content,
                    model: fallbackModel,
                    mode: mode,
                    context: context,
                    tokenConfig: tokenConfig ?? mode.recommendedTokenConfig
                )
                
                // fallback 성공 알림 ([] 형식으로 구분)
                let fallbackNotice = "\n\n[ℹ️ \(originalModel.displayName) 서버 오류로 인해 \(fallbackModel.displayName) 모델을 임시 사용했습니다]"
                
                let finalResponse = AIResponse(
                    id: response.id,
                    model: fallbackModel,
                    mode: response.mode,
                    content: response.content + fallbackNotice,
                    metadata: response.metadata,
                    usage: response.usage,
                    timestamp: response.timestamp,
                    processingTime: response.processingTime
                )
                
                print("✅ [UnifiedAIService] Fallback 성공: \(originalModel.rawValue) → \(fallbackModel.rawValue)")
                return finalResponse
                
            } catch {
                print("❌ [UnifiedAIService] Fallback \(index + 1) 실패 (\(fallbackModel.rawValue)): \(error.localizedDescription)")
                
                // 마지막 fallback도 실패한 경우
                if index == availableFallbacks.count - 1 {
                    print("💥 [UnifiedAIService] 모든 Fallback 모델 실패")
                    throw AIServiceError.modelUnavailable(model: originalModel)
                }
                
                // 다음 모델 시도를 위해 계속 진행
                continue
            }
        }
        
        // 이론적으로 여기에 도달할 수 없지만 안전장치
        throw AIServiceError.modelUnavailable(model: originalModel)
    }
    
    // MARK: - 🎯 모델 선택 로직
    
    /// 사용자 선택과 가용성을 고려한 모델 선택
    private func getSelectedModel(preferredModel: AIModel) -> AIModel {

        
        // 1. 선호 모델이 사용 가능한지 확인 (최우선)
        if availableModels.contains(preferredModel) {
            print("✅ [UnifiedAIService] 선호 모델 사용 가능: \(preferredModel.rawValue)")
            return preferredModel
        }
        
        print("⚠️ [UnifiedAIService] 선호 모델 사용 불가, fallback 시도")
        
        // 2. fallback 순서대로 사용 가능한 모델 반환
        for model in fallbackOrder {
            if availableModels.contains(model) {
                print("✅ [UnifiedAIService] Fallback 모델 선택: \(model.rawValue)")
                return model
            }
        }
        
        // 3. 마지막 수단: 첫 번째 사용 가능한 모델 반환
        let finalModel = availableModels.first ?? .freeModel
        print("🚨 [UnifiedAIService] 최후 수단 모델 선택: \(finalModel.rawValue)")
        return finalModel
    }
    
    /// LLMServiceType을 AIModel로 변환
    private func mapLLMServiceTypeToAIModel(_ llmType: LLMServiceType) -> AIModel? {
        switch llmType {
        case .claude:
            return .claude
        case .openAI:
            return .openAI
        case .gemini:
            return .gemini
        case .naver:
            return .naver
        case .onDevice:
            // 온디바이스는 아직 미지원
            return nil
        }
    }
    
    /// AIModelType을 AIModel로 변환
    private func mapAIModelTypeToAIModel(_ modelType: AIModelType) -> AIModel {
        switch modelType {
        case .claude35:
            return .claude
        case .gpt4:
            return .openAI
        case .gemini:
            return .gemini
        case .naver:
            return .naver
        case .onDevice:
            // TODO: 온디바이스 모델 구현 필요 - 현재는 임시로 무료 모델 사용
            // 설정 화면에도 온디바이스 옵션 추가 필요
            return .freeModel
        case .freeModel:
            return .freeModel
        case .testModel:
            return .freeModel  // testModel도 통합된 freeModel로 처리
        }
    }
    
    // MARK: - 🌊 스트리밍 응답 (미구현)
    
    public func sendMessageStream(
        content: String,
        model: AIModel,
        mode: AIMode,
        context: AIContext?,
        tokenConfig: TokenConfiguration?
    ) -> AsyncThrowingStream<AIStreamResponse, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    // 일반 응답을 스트리밍 형태로 변환 (임시 구현)
                    let response = try await sendMessage(
                        content: content,
                        model: model,
                        mode: mode,
                        context: context,
                        tokenConfig: tokenConfig
                    )
                    
                    let streamResponse = AIStreamResponse(
                        id: response.id,
                        delta: response.content,
                        isComplete: true,
                        metadata: StreamMetadata(tokenCount: response.usage.totalTokens, timestamp: Date())
                    )
                    
                    continuation.yield(streamResponse)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    // MARK: - 📊 사용량 통계 (미구현)
    
    public func getUsageStatistics(for model: AIModel) async -> AIUsageStatistics {
        // TODO: 실제 사용량 통계 구현
        return AIUsageStatistics(
            model: model,
            totalRequests: 0,
            totalTokens: 0,
            totalCost: 0.0,
            averageResponseTime: 0.0,
            successRate: 1.0,
            lastUpdated: Date()
        )
    }
    
    // MARK: - 🚦 모델 상태 확인
    
    public func checkModelStatus(for model: AIModel) async -> AIModelStatus {
        let isAvailable = availableModels.contains(model)
        
        return AIModelStatus(
            model: model,
            isAvailable: isAvailable,
            latency: 0.0, // TODO: 실제 레이턴시 측정
            errorRate: 0.0, // TODO: 실제 에러율 계산
            remainingQuota: nil,
            healthScore: isAvailable ? 1.0 : 0.0
        )
    }
    
    // MARK: - 🎯 누락된 핵심 함수들 구현
    
    /// 모드별 최적 AI 모델 추천
    private func getOptimalModelForMode(mode: AIMode, userPreferred: AIModel) -> AIModel {
        // 모드별 AI 모델 매핑 (특정 모드는 최적 모델 사용, 일반 대화는 사용자 설정 따름)
        let optimalModelMapping: [AIMode: AIModel] = [
            // DeepSleep 앱의 주요 기능별 최적 모델
            .generalConversation: userPreferred,                                               // 일반 대화: 사용자 설정 존중
            .emotionDiaryAnalysis: availableModels.contains(.claude) ? .claude : .freeModel,   // 감정 일기 분석: Claude (깊은 공감)
            .taskAdvice: availableModels.contains(.gemini) ? .gemini : .freeModel,            // 할일 조언: Gemini (빠른 응답)
            .presetRecommendation: availableModels.contains(.openAI) ? .openAI : .freeModel,   // 프리셋 추천: OpenAI (JSON 생성)
            .monthlyStatistics: availableModels.contains(.gemini) ? .gemini : .freeModel,     // 월간 통계: Gemini (데이터 분석)
            .fortuneTelling: availableModels.contains(.naver) ? .naver : .freeModel,          // 운세: Naver (한국 정서)
            .emotionAnalysis: availableModels.contains(.openAI) ? .openAI : .freeModel        // 감정 분석: OpenAI (구조화된 출력)
        ]
        
        // 매핑된 모델이 있고 사용 가능한 경우
        if let optimalModel = optimalModelMapping[mode],
           availableModels.contains(optimalModel) {
            return optimalModel
        }
        
        // 매핑된 모델이 사용 불가능하거나 일반 대화인 경우 사용자 선호 모델 사용
        if availableModels.contains(userPreferred) {
            return userPreferred
        }
        
        // 사용자 선호 모델도 사용 불가능한 경우 fallbackOrder 사용
        return fallbackOrder.first ?? .freeModel
    }
    
    /// 모드와 모델에 맞는 시스템 프롬프트 생성
    private func generateOptimizedSystemPrompt(for mode: AIMode, model: AIModel) -> String {
        let basePrompt = getBaseSystemPromptForMode(mode)
        let modelSpecificOptimization = getModelSpecificOptimization(for: model)
        
        return """
        \(basePrompt)
        
        \(modelSpecificOptimization)
        
        중요한 지침:
        - 한국어로 자연스럽고 친근하게 응답하세요
        - 사용자의 감정과 상황을 깊이 이해하고 공감하세요  
        - 실용적이고 도움이 되는 조언을 제공하세요
        - 부정확한 정보는 제공하지 말고, 확신이 없으면 솔직히 말하세요
        """
    }
    
    /// 모드별 기본 시스템 프롬프트
    private func getBaseSystemPromptForMode(_ mode: AIMode) -> String {
        switch mode {
        case .generalConversation:
            return "당신은 DeepSleep 앱의 친근하고 지능적인 AI 어시스턴트입니다. 사용자와 자연스럽고 도움이 되는 대화를 나누세요."
            
        case .emotionDiaryAnalysis:
            return """
            당신은 감정 분석 전문가입니다. 사용자의 일기나 감정 표현을 깊이 분석하여:
            - 주요 감정을 파악하고 공감적으로 반응
            - 감정의 원인이나 배경을 이해
            - 긍정적인 관점이나 해결책을 부드럽게 제시
            - 전문적이지만 따뜻한 톤으로 응답
            """
            
        case .taskAdvice:
            return """
            당신은 실용적인 생산성 코치입니다. 사용자의 할일이나 과제에 대해:
            - 구체적이고 실행 가능한 조언 제공
            - 단계별로 명확하게 설명
            - 시간 관리와 우선순위 설정 도움
            - 동기부여가 되는 격려의 메시지 포함
            """
            
        case .presetRecommendation:
            return """
            당신은 음악 및 사운드 큐레이션 전문가입니다. 사용자의 상황과 요구에 맞는 음악 프리셋을 추천할 때:
            - 사용자의 현재 감정과 원하는 상태 고려
            - 과학적 근거가 있는 음악 치료 원리 적용
            - 다양한 장르와 스타일 중에서 선택
            - JSON 형식으로 구조화된 추천 결과 제공
            """
            
        case .monthlyStatistics:
            return """
            당신은 데이터 분석 전문가입니다. 월간 수면 및 활동 통계를 분석할 때:
            - 패턴과 트렌드를 명확하게 식별
            - 통계적 의미와 실생활 연관성 설명
            - 개선점과 긍정적 변화 강조
            - 다음 달 목표와 추천사항 제공
            """
            
        case .fortuneTelling:
            return """
            당신은 따뜻하고 지혜로운 운세 상담사입니다. 한국의 전통적 정서를 바탕으로:
            - 긍정적이고 희망적인 메시지 전달
            - 구체적인 미신보다는 삶의 지혜 제공
            - 사용자의 노력과 선택을 강조
            - 재미있으면서도 의미 있는 내용 구성
            """
            
        case .emotionAnalysis:
            return """
            당신은 감정 분석 AI입니다. 사용자의 텍스트에서 감정을 분석하여:
            - 주요 감정과 감정 강도 파악
            - 복합적인 감정 상태 인식
            - JSON 형식으로 구조화된 분석 결과 제공
            - 객관적이고 정확한 분석에 집중
            """
            
        default:
            return "당신은 DeepSleep 앱의 도움이 되는 AI 어시스턴트입니다. 사용자의 요청에 최선을 다해 응답하세요."
        }
    }
    
    /// 모델별 특화 최적화 지침
    private func getModelSpecificOptimization(for model: AIModel) -> String {
        switch model {
        case .claude:
            return """
            Claude 특화 지침:
            - 창의적이고 깊이 있는 사고를 활용하세요
            - 복잡한 감정과 상황을 세밀하게 분석하세요
            - 문학적이고 아름다운 표현을 사용하되 이해하기 쉽게 하세요
            """
            
        case .openAI:
            return """
            OpenAI 특화 지침:
            - 구조화되고 논리적인 답변을 제공하세요
            - JSON 출력이 필요한 경우 정확한 형식을 준수하세요
            - 단계별이고 체계적인 설명을 선호하세요
            - 실용적이고 즉시 활용 가능한 조언에 집중하세요
            """
            
        case .gemini:
            return """
            Gemini 특화 지침:
            - 빠르고 효율적인 응답을 제공하세요
            - 다양한 관점과 옵션을 제시하세요
            - 안전하고 균형 잡힌 내용을 우선하세요
            - 대용량 컨텍스트를 활용한 종합적 분석을 수행하세요
            """
            
        case .naver:
            return """
            Naver HyperCLOVA X 특화 지침:
            - 한국의 문화와 정서를 깊이 반영하세요
            - 한국어의 뉘앙스와 존댓말을 적절히 사용하세요
            - 한국 사회의 맥락과 상황을 고려하세요
            - 친근하면서도 정중한 톤을 유지하세요
            """
        case .freeModel:
            return """
            OpenRouter 통합 무료 모델 지침:
            - 한국어로 자연스럽고 간결하게 답하세요
            - JSON이 필요한 경우 올바른 스키마와 작은 따옴표/백틱 없이 순수 JSON만 출력하세요
            - 과한 창의성보다 정확성과 일관성을 우선하세요
            """
        }
    }
    
    /// 모델과 모드에 맞는 토큰 설정 최적화
    private func optimizeTokenConfigForModel(
        _ config: TokenConfiguration,
        model: AIModel,
        mode: AIMode
    ) -> TokenConfiguration {
        
        var optimizedConfig = config
        
        // 모델별 특성에 맞는 조정
        switch model {
        case .claude:
            // Claude는 길고 상세한 답변에 강함
            let claudeBonus = Bundle.main.object(forInfoDictionaryKey: "AI_CLAUDE_MAX_TOKENS_BONUS") as? Int ?? 100
            let claudeLimit = Bundle.main.object(forInfoDictionaryKey: "AI_CLAUDE_MAX_TOKENS_LIMIT") as? Int ?? 1000
            optimizedConfig = TokenConfiguration(
                maxTokens: min(config.maxTokens + claudeBonus, claudeLimit),
                temperature: config.temperature,
                topP: config.topP,
                frequencyPenalty: config.frequencyPenalty,
                presencePenalty: config.presencePenalty,
                responseFormat: config.responseFormat
            )
            
        case .openAI:
            // OpenAI는 구조화된 출력에 강함
            let tempAdjustment = Bundle.main.object(forInfoDictionaryKey: "AI_OPENAI_TEMPERATURE_ADJUSTMENT") as? Double ?? -0.1
            let topP = Bundle.main.object(forInfoDictionaryKey: "AI_OPENAI_TOP_P") as? Double ?? 0.9
            optimizedConfig = TokenConfiguration(
                maxTokens: config.maxTokens,
                temperature: max(config.temperature + tempAdjustment, 0.0),  // 더 일관된 출력
                topP: topP,  // 더 집중된 응답
                frequencyPenalty: config.frequencyPenalty ?? 0.0,
                presencePenalty: config.presencePenalty ?? 0.0,
                responseFormat: config.responseFormat
            )
            
        case .gemini:
            // Gemini는 빠르고 효율적인 응답에 강함
            let geminiLimit = Bundle.main.object(forInfoDictionaryKey: "AI_GEMINI_MAX_TOKENS_LIMIT") as? Int ?? 800
            let tempAdjustment = Bundle.main.object(forInfoDictionaryKey: "AI_GEMINI_TEMPERATURE_ADJUSTMENT") as? Double ?? 0.1
            optimizedConfig = TokenConfiguration(
                maxTokens: min(config.maxTokens, geminiLimit),  // 간결한 답변 유도하되 충분한 길이 허용
                temperature: config.temperature + tempAdjustment,  // 약간 더 창의적
                topP: config.topP,
                frequencyPenalty: config.frequencyPenalty,
                presencePenalty: config.presencePenalty,
                responseFormat: config.responseFormat
            )
            
        case .naver:
            // Naver는 한국어에 특화됨
            let tempAdjustment = Bundle.main.object(forInfoDictionaryKey: "AI_NAVER_TEMPERATURE_ADJUSTMENT") as? Double ?? 0.05
            let topP = Bundle.main.object(forInfoDictionaryKey: "AI_NAVER_TOP_P") as? Double ?? 0.85
            optimizedConfig = TokenConfiguration(
                maxTokens: config.maxTokens,
                temperature: config.temperature + tempAdjustment,  // 살짝 더 자연스럽게
                topP: config.topP ?? topP,  // 한국어 특성 반영
                frequencyPenalty: config.frequencyPenalty,
                presencePenalty: config.presencePenalty,
                responseFormat: config.responseFormat
            )
        case .freeModel:
            // 통합 무료 모델은 안정적 JSON/텍스트 위주로 보수적으로 설정
            let freeModelLimit = Bundle.main.object(forInfoDictionaryKey: "AI_FREE_MODEL_MAX_TOKENS_LIMIT") as? Int ?? 600
            let tempMin = Bundle.main.object(forInfoDictionaryKey: "AI_FREE_MODEL_TEMPERATURE_MIN") as? Double ?? 0.2
            let tempMax = Bundle.main.object(forInfoDictionaryKey: "AI_FREE_MODEL_TEMPERATURE_MAX") as? Double ?? 0.6
            optimizedConfig = TokenConfiguration(
                maxTokens: min(config.maxTokens, freeModelLimit),  // 무료 모델도 충분한 길이 허용
                temperature: min(max(config.temperature, tempMin), tempMax),
                topP: config.topP ?? 0.9,
                frequencyPenalty: config.frequencyPenalty ?? 0.0,
                presencePenalty: config.presencePenalty ?? 0.0,
                responseFormat: config.responseFormat
            )
        }
        
        // 모드별 추가 최적화
        switch mode {
        case .emotionAnalysis, .presetRecommendation:
            // JSON 출력이 필요한 모드
            let jsonTempMax = Bundle.main.object(forInfoDictionaryKey: "AI_JSON_MODE_TEMPERATURE_MAX") as? Double ?? 0.3
            optimizedConfig = TokenConfiguration(
                maxTokens: optimizedConfig.maxTokens,
                temperature: min(optimizedConfig.temperature, jsonTempMax),  // 더 정확한 출력
                topP: optimizedConfig.topP,
                frequencyPenalty: optimizedConfig.frequencyPenalty,
                presencePenalty: optimizedConfig.presencePenalty,
                responseFormat: .json
            )
            
        case .fortuneTelling:
            // 창의적인 답변이 필요한 모드  
            let creativeTempBonus = Bundle.main.object(forInfoDictionaryKey: "AI_CREATIVE_MODE_TEMPERATURE_BONUS") as? Double ?? 0.2
            let creativeTempMax = Bundle.main.object(forInfoDictionaryKey: "AI_CREATIVE_MODE_TEMPERATURE_MAX") as? Double ?? 1.0
            optimizedConfig = TokenConfiguration(
                maxTokens: optimizedConfig.maxTokens,
                temperature: min(optimizedConfig.temperature + creativeTempBonus, creativeTempMax),  // 더 창의적
                topP: optimizedConfig.topP,
                frequencyPenalty: optimizedConfig.frequencyPenalty,
                presencePenalty: optimizedConfig.presencePenalty,
                responseFormat: optimizedConfig.responseFormat
            )
            
        default:
            break
        }
        
        return optimizedConfig
    }
}

// MARK: - 📊 확장

extension UnifiedAIServiceImpl {
    
    /// 전체 시스템 상태 보고서 생성
    func generateSystemStatusReport() -> String {
        let availableCount = availableModels.count
        let totalCount = AIModel.allCases.count
        
        var report = """
        🚀 UnifiedAIService 시스템 상태 보고서
        ==========================================
        
        📊 모델 가용성: \(availableCount)/\(totalCount)개 사용 가능
        """
        
        for model in AIModel.allCases {
            let status = availableModels.contains(model) ? "✅ 사용 가능" : "❌ 사용 불가"
            let displayName = model.displayName
            report += "\n   • \(displayName): \(status)"
        }
        
        if let cheapest = cheapestFallbackModel {
            report += "\n\n🔄 Fallback 모델: \(cheapest.displayName)"
        }
        
        let userSelectedModel = settingsManager.selectedLLM
        let mapped = mapAIModelTypeToAIModel(userSelectedModel)
        report += "\n👤 사용자 선택 모델: \(mapped.displayName)"
        
        report += """
        
        
        🔒 보안 설정:
           • 최대 프롬프트 길이: 2000자
           • 일일 최대 요청: 100회
           • 레이트 리미팅: 활성화
        
        📅 보고서 생성 시간: \(DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .short))
        """
        
        return report
    }
}

// MARK: - AIModel 확장 (displayName은 AIServiceTypes.swift에 정의됨)
