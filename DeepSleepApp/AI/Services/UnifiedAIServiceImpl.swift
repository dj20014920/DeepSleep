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
    
    private var modelChangedObserver: Any?
    private var requestCounter: Int = 0
    
    private init() {
        initializeServices()
        modelChangedObserver = NotificationCenter.default.addObserver(forName: .aiModelChanged, object: nil, queue: .main) { [weak self] note in
            self?.handleModelChanged(notification: note)
        }
    }
    
    // MARK: - 🔑 API 키 관리
    
    /// API 키를 구성에서 안전하게 조회
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
        
        guard let apiKey = ConfigReader.string(keyName),
              !apiKey.isEmpty else {
            return nil
        }
        
        return apiKey
    }
    
    
    deinit {
        if let obs = modelChangedObserver {
            NotificationCenter.default.removeObserver(obs)
        }
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
        if getAPIKey(for: .freeModel) != nil {
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
        tokenConfig: TokenConfiguration?,
        assembledPrompt: String? = nil
) async throws -> AIResponse {
        let reqId = UUID().uuidString
        ContextMetrics.shared.logRequestStart(id: reqId, model: model.rawValue, mode: mode.rawValue)
        let overallStart = Date()
        
        // 주기적 메트릭 요약 로그 (20요청마다)
        requestCounter += 1
        if requestCounter % 20 == 0 {
            emitMetricsSummaryLog()
        }
        
        // 0. 일일 사용량 한도 체크 (통합 진입점에서 강제)
        let usage = UsageLimitManager.shared.canUseAIFeature(mode)
        guard usage.canUse else {
            ContextMetrics.shared.logRequestEnd(id: reqId, model: model.rawValue, mode: mode.rawValue, success: false, duration: Date().timeIntervalSince(overallStart))
            throw AIServiceError.configurationError("USAGE_LIMIT_EXCEEDED: \(mode.rawValue) \(usage.currentUsage)/\(usage.dailyLimit)")
        }
        
        // 1. 보안 검증
        let validationResult = securityManager.validateAndSanitizeInput(content, userId: context?.userId ?? "unknown")
        
        let cleaned: String
        switch validationResult {
        case .rejected(_):
            ContextMetrics.shared.logRequestEnd(id: reqId, model: model.rawValue, mode: mode.rawValue, success: false, duration: Date().timeIntervalSince(overallStart))
            throw AIServiceError.unauthorized
        case .flagged(let reason, let cleanInput):
            print("⚠️ [UnifiedAIService] 입력이 플래그됨: \(reason)")
            cleaned = cleanInput
        case .approved(let cleanInput):
            cleaned = cleanInput
        }
        
        do {
            // 2. 실제 호출 (성공 시에만 사용량 증가)
            let response = try await sendMessageInternal(cleaned, model, mode, context, tokenConfig, assembledPrompt)
            UsageLimitManager.shared.incrementUsage(for: mode)
            ContextMetrics.shared.logRequestEnd(id: reqId, model: model.rawValue, mode: mode.rawValue, success: true, duration: Date().timeIntervalSince(overallStart))
            return response
        } catch {
            ContextMetrics.shared.logRequestEnd(id: reqId, model: model.rawValue, mode: mode.rawValue, success: false, duration: Date().timeIntervalSince(overallStart))
            throw error
        }
    }
    
    /// 내부 메시지 전송 로직 (보안 검증 후)
    private func sendMessageInternal(
        _ content: String,
        _ model: AIModel,
        _ mode: AIMode,
        _ context: AIContext?,
        _ tokenConfig: TokenConfiguration?,
        _ assembledPrompt: String?
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
                tokenConfig: optimizeTokenConfigForModel(tokenConfig ?? mode.recommendedTokenConfig, model: finalModel, mode: mode),
                assembledPrompt: assembledPrompt
            )
            
            // 출력 보안 검증
            let outputValidation = securityManager.validateOutput(response.content, originalInput: content)
            
            switch outputValidation {
            case .blocked(let reason):
                print("🚫 [UnifiedAIService] 출력이 차단됨: \(reason)")
                // fallback 시도
                return try await attemptFallback(content, originalModel: finalModel, mode: mode, context: context, tokenConfig: tokenConfig, assembledPrompt: assembledPrompt)
                
            case .approved:
                let processingTime = Date().timeIntervalSince(startTime)
                print("✅ [UnifiedAIService] 메시지 전송 완료 - 처리시간: \(Int(processingTime * 1000))ms")
                return response
            }
            
        } catch {
            print("❌ [UnifiedAIService] \(finalModel.rawValue) 실패: \(error.localizedDescription)")
            
            // fallback 시도
            return try await attemptFallback(content, originalModel: finalModel, mode: mode, context: context, tokenConfig: tokenConfig, assembledPrompt: assembledPrompt)
        }
    }
    
    // MARK: - 🎯 모델별 메시지 전송
    
    private func sendToSpecificModel(
        content: String,
        model: AIModel,
        mode: AIMode,
        context: AIContext?,
        tokenConfig: TokenConfiguration,
        assembledPrompt: String?
) async throws -> AIResponse {
        
        // 🎨 모드별 맞춤형 시스템 프롬프트 생성 + assembledPrompt 병합
        var systemPrompt = generateOptimizedSystemPrompt(for: mode, model: model)
        if let assembled = assembledPrompt, !assembled.isEmpty {
            systemPrompt += "\n\n" + assembled
        }
        
        // 멀티-메시지 구성: 시스템 + 최근 대화 + 현재 사용자 입력
        var roleMessages: [RoleMessage] = [RoleMessage(role: .system, content: systemPrompt)]
        if let history = context?.conversationHistory, !history.isEmpty {
            let recent = Array(history.suffix(16))
            for turn in recent {
                roleMessages.append(RoleMessage(role: turn.role, content: turn.content, ts: turn.timestamp))
            }
        }
        roleMessages.append(RoleMessage(role: .user, content: content))
        
        switch model {
        case .claude:
            guard let service = claudeService else {
                throw AIServiceError.modelUnavailable(model: model)
            }
            return try await service.sendMessages(messages: roleMessages, mode: mode, tokenConfig: tokenConfig)
            
        case .openAI:
            guard let service = openAIService else {
                throw AIServiceError.modelUnavailable(model: model)
            }
            return try await service.sendMessages(messages: roleMessages, mode: mode, tokenConfig: tokenConfig)
            
        case .gemini:
            guard let service = geminiService else {
                throw AIServiceError.modelUnavailable(model: model)
            }
            return try await service.sendMessages(messages: roleMessages, mode: mode, tokenConfig: tokenConfig)
            
        case .naver:
            guard let service = naverService else {
                throw AIServiceError.modelUnavailable(model: model)
            }
            return try await service.sendMessages(messages: roleMessages, mode: mode, tokenConfig: tokenConfig)
            
        case .freeModel:
            print("🎁 [UnifiedAIService] 무료 모델 폴백 시스템 호출 - 모드: \(mode)")
            
            guard let freeService = freeModelService else {
                print("❌ [UnifiedAIService] freeModelService가 nil입니다!")
                throw AIServiceError.modelUnavailable(model: model)
            }
            
            // 멀티-메시지 구성: 시스템 + (대화 이력 또는 assembledPrompt) + 현재 사용자 입력
            var sysPrompt = generateOptimizedSystemPrompt(for: mode, model: model)
            if let assembled = assembledPrompt, !assembled.isEmpty {
                sysPrompt += "\n\n" + assembled
            }
            var messages: [OpenRouterFallbackManager.ORMessage] = [
                .init(role: "system", content: sysPrompt)
            ]
            
            if let history = context?.conversationHistory, !history.isEmpty {
                let recent = Array(history.suffix(16)) // 최근 16개만 포함
                for turn in recent {
                    messages.append(.init(role: turn.role.rawValue, content: turn.content))
                }
            }
            // 최신 사용자 입력 추가
            messages.append(.init(role: "user", content: content))
            
            let responseText = try await freeService.sendMessageWithFallback(
                messages: messages,
                mode: mode
            )
            
            let promptChars = messages.reduce(0) { $0 + $1.content.count }
            let promptTokensEst = promptChars / 4
            let completionTokensEst = responseText.count / 4
            
            // 문자열 응답을 AIResponse로 변환
            return AIResponse(
                id: UUID().uuidString,
                model: model,
                mode: mode,
                content: responseText,
                metadata: ResponseMetadata(
                    emotionAnalysis: nil,
                    recommendations: nil,
                    confidenceScore: 0.8,
                    additionalInfo: ["source": "OpenRouter", "message_count": messages.count]
                ),
                usage: TokenUsage(
                    promptTokens: promptTokensEst,
                    completionTokens: completionTokensEst,
                    totalTokens: promptTokensEst + completionTokensEst,
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
        tokenConfig: TokenConfiguration?,
        assembledPrompt: String?
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
                ContextMetrics.shared.logFallbackTried(from: originalModel.rawValue, to: fallbackModel.rawValue)
            do {
                print("🔄 [UnifiedAIService] Fallback \(index + 1)/\(availableFallbacks.count): \(fallbackModel.rawValue) 시도")
                
                let response = try await sendToSpecificModel(
                    content: content,
                    model: fallbackModel,
                    mode: mode,
                    context: context,
                    tokenConfig: tokenConfig ?? mode.recommendedTokenConfig,
                    assembledPrompt: assembledPrompt
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
    
    // MARK: - 🔔 모델 변경 알림 처리
    
    private func handleModelChanged(notification: Notification) {
        let from = (notification.userInfo?["from"] as? String) ?? "unknown"
        let to = (notification.userInfo?["to"] as? String) ?? "unknown"
        print("🔔 [UnifiedAIService] aiModelChanged: \(from) → \(to). 컨텍스트 캐시 무효화 및 파이프라인 점검")
        // 컨텍스트 캐시 무효화는 SettingsManager에서 이미 수행하지만, 이중 안전망으로 한 번 더 보장 가능
        AIContextManager.shared.clearCache(reason: .modelSelectionChanged, caller: "UnifiedAIServiceImpl")
        // 필요 시 모델별 세션 상태 초기화/메트릭 리셋 등을 여기에 추가 가능
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
        tokenConfig: TokenConfiguration?,
        assembledPrompt: String? = nil
    ) -> AsyncThrowingStream<AIStreamResponse, Error> {
        // 중앙집중형 assembledPrompt 경로를 우선 사용한다.
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    // 현재는 단일 청크로 전달하지만, 서비스별 네이티브 스트리밍을 도입해도 인터페이스는 유지된다.
                    let response = try await sendMessage(
                        content: content,
                        model: model,
                        mode: mode,
                        context: context,
                        tokenConfig: tokenConfig,
                        assembledPrompt: assembledPrompt
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
        // 모드별 AI 모델 매핑 (특정 모드는 최적 모델 사용, 일반 대화는 사용자 설정 존중)
        let optimalModelMapping: [AIMode: AIModel] = [
            .generalConversation: userPreferred,
            .emotionDiaryAnalysis: availableModels.contains(.claude) ? .claude : .freeModel,
            .taskAdvice: availableModels.contains(.gemini) ? .gemini : .freeModel,
            .presetRecommendation: availableModels.contains(.openAI) ? .openAI : .freeModel,
            .monthlyStatistics: availableModels.contains(.gemini) ? .gemini : .freeModel,
            .fortuneTelling: availableModels.contains(.naver) ? .naver : .freeModel,
            .emotionAnalysis: availableModels.contains(.openAI) ? .openAI : .freeModel
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
        
        // 페르소나 시그니처 구성 (외부 전송 금지, 캐시 키로만 사용)
        let selectedModel = settingsManager.selectedLLM.rawValue
        let memorySummaryFP: String = {
            let summary = MemoryManager.shared.getMemorySummary(maxItems: 5)
            return summary.isEmpty ? "none" : String(summary.hashValue)
        }()
        // DRY: 중앙 유틸로 통일
        let personaSignature = AIContextSignature.build(
            personaSignature: UserRulesManager.shared.personaSignature(),
            mode: mode,
            model: model,
            memorySummaryFP: memorySummaryFP
        )
        
        // 3시간 TTL 캐시 활용
        let prompt = contextManager.getSystemPrompt(personaSignature: personaSignature) {
            return """
            \(basePrompt)
            
            \(modelSpecificOptimization)
            
            중요한 지침:
            - 한국어로 자연스럽고 친근하게 응답하세요
            - 사용자의 감정과 상황을 깊이 이해하고 공감하세요  
            - 실용적이고 도움이 되는 조언을 제공하세요
            - 부정확한 정보는 제공하지 말고, 확신이 없으면 솔직히 말하세요
            - 개인정보를 외부에 저장하지 마세요. 세션 내 제공된 대화 히스토리를 바탕으로 맥락을 이어가세요.
            - "이전 대화를 기억하지 못한다"와 같은 메타 발화를 하지 마세요. 제공된 히스토리 범위에서 자연스럽게 이어가세요.
            """
        }
        return prompt
    }
    
    /// 모드별 기본 시스템 프롬프트
    private func getBaseSystemPromptForMode(_ mode: AIMode) -> String {
        switch mode {
        case .generalConversation:
            return "당신은 우리 앱의 친근하고 지능적인 AI 어시스턴트입니다. 사용자와 자연스럽고 도움이 되는 대화를 나누세요."
            
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
            if let claudeBonus = ConfigReader.int("AI_CLAUDE_MAX_TOKENS_BONUS"),
               let claudeLimit = ConfigReader.int("AI_CLAUDE_MAX_TOKENS_LIMIT") {
                optimizedConfig = TokenConfiguration(
                    maxTokens: min(config.maxTokens + claudeBonus, claudeLimit),
                    temperature: config.temperature,
                    topP: config.topP,
                    frequencyPenalty: config.frequencyPenalty,
                    presencePenalty: config.presencePenalty,
                    responseFormat: config.responseFormat
                )
            } else {
                optimizedConfig = config
            }
            
        case .openAI:
            // OpenAI는 구조화된 출력에 강함
            var newConfig = config
            if let tempAdjustment = ConfigReader.double("AI_OPENAI_TEMPERATURE_ADJUSTMENT") {
                newConfig = TokenConfiguration(
                    maxTokens: newConfig.maxTokens,
                    temperature: max(newConfig.temperature + tempAdjustment, 0.0),
                    topP: newConfig.topP,
                    frequencyPenalty: newConfig.frequencyPenalty,
                    presencePenalty: newConfig.presencePenalty,
                    responseFormat: newConfig.responseFormat
                )
            }
            if let topP = ConfigReader.double("AI_OPENAI_TOP_P") {
                newConfig = TokenConfiguration(
                    maxTokens: newConfig.maxTokens,
                    temperature: newConfig.temperature,
                    topP: topP,
                    frequencyPenalty: newConfig.frequencyPenalty,
                    presencePenalty: newConfig.presencePenalty,
                    responseFormat: newConfig.responseFormat
                )
            }
            optimizedConfig = newConfig
            
        case .gemini:
            // Gemini는 빠르고 효율적인 응답에 강함
            var newConfig = config
            if let geminiLimit = ConfigReader.int("AI_GEMINI_MAX_TOKENS_LIMIT") {
                newConfig = TokenConfiguration(
                    maxTokens: min(newConfig.maxTokens, geminiLimit),
                    temperature: newConfig.temperature,
                    topP: newConfig.topP,
                    frequencyPenalty: newConfig.frequencyPenalty,
                    presencePenalty: newConfig.presencePenalty,
                    responseFormat: newConfig.responseFormat
                )
            }
            if let tempAdjustment = ConfigReader.double("AI_GEMINI_TEMPERATURE_ADJUSTMENT") {
                newConfig = TokenConfiguration(
                    maxTokens: newConfig.maxTokens,
                    temperature: newConfig.temperature + tempAdjustment,
                    topP: newConfig.topP,
                    frequencyPenalty: newConfig.frequencyPenalty,
                    presencePenalty: newConfig.presencePenalty,
                    responseFormat: newConfig.responseFormat
                )
            }
            optimizedConfig = newConfig
            
        case .naver:
            // Naver는 한국어에 특화됨
            var newConfig = config
            if let tempAdjustment = ConfigReader.double("AI_NAVER_TEMPERATURE_ADJUSTMENT") {
                newConfig = TokenConfiguration(
                    maxTokens: newConfig.maxTokens,
                    temperature: newConfig.temperature + tempAdjustment,
                    topP: newConfig.topP,
                    frequencyPenalty: newConfig.frequencyPenalty,
                    presencePenalty: newConfig.presencePenalty,
                    responseFormat: newConfig.responseFormat
                )
            }
            if let topP = ConfigReader.double("AI_NAVER_TOP_P") {
                newConfig = TokenConfiguration(
                    maxTokens: newConfig.maxTokens,
                    temperature: newConfig.temperature,
                    topP: topP,
                    frequencyPenalty: newConfig.frequencyPenalty,
                    presencePenalty: newConfig.presencePenalty,
                    responseFormat: newConfig.responseFormat
                )
            }
            optimizedConfig = newConfig
        case .freeModel:
            // 통합 무료 모델은 안정적 JSON/텍스트 위주로 보수적으로 설정
            var newConfig = config
            if let freeModelLimit = ConfigReader.int("AI_FREE_MODEL_MAX_TOKENS_LIMIT") {
                newConfig = TokenConfiguration(
                    maxTokens: min(newConfig.maxTokens, freeModelLimit),
                    temperature: newConfig.temperature,
                    topP: newConfig.topP,
                    frequencyPenalty: newConfig.frequencyPenalty,
                    presencePenalty: newConfig.presencePenalty,
                    responseFormat: newConfig.responseFormat
                )
            }
            // 온도 범위는 구성값이 있을 때만 적용
            if let tempMin = ConfigReader.double("AI_FREE_MODEL_TEMPERATURE_MIN"),
               let tempMax = ConfigReader.double("AI_FREE_MODEL_TEMPERATURE_MAX") {
                newConfig = TokenConfiguration(
                    maxTokens: newConfig.maxTokens,
                    temperature: min(max(newConfig.temperature, tempMin), tempMax),
                    topP: newConfig.topP,
                    frequencyPenalty: newConfig.frequencyPenalty,
                    presencePenalty: newConfig.presencePenalty,
                    responseFormat: newConfig.responseFormat
                )
            }
            optimizedConfig = newConfig
        }
        
        // 모드별 추가 최적화
        switch mode {
        case .emotionAnalysis, .presetRecommendation:
            // JSON 출력이 필요한 모드
            if let jsonTempMax = ConfigReader.double("AI_JSON_MODE_TEMPERATURE_MAX") {
                optimizedConfig = TokenConfiguration(
                    maxTokens: optimizedConfig.maxTokens,
                    temperature: min(optimizedConfig.temperature, jsonTempMax),
                    topP: optimizedConfig.topP,
                    frequencyPenalty: optimizedConfig.frequencyPenalty,
                    presencePenalty: optimizedConfig.presencePenalty,
                    responseFormat: .json
                )
            }
            
        case .fortuneTelling:
            // 창의적인 답변이 필요한 모드  
            if let creativeTempBonus = ConfigReader.double("AI_CREATIVE_MODE_TEMPERATURE_BONUS"),
               let creativeTempMax = ConfigReader.double("AI_CREATIVE_MODE_TEMPERATURE_MAX") {
                optimizedConfig = TokenConfiguration(
                    maxTokens: optimizedConfig.maxTokens,
                    temperature: min(optimizedConfig.temperature + creativeTempBonus, creativeTempMax),
                    topP: optimizedConfig.topP,
                    frequencyPenalty: optimizedConfig.frequencyPenalty,
                    presencePenalty: optimizedConfig.presencePenalty,
                    responseFormat: optimizedConfig.responseFormat
                )
            }
            
        default:
            break
        }
        
        return optimizedConfig
    }
}

// MARK: - 📊 확장

extension UnifiedAIServiceImpl {
    
    /// 메트릭 요약 로그 출력
    func emitMetricsSummaryLog() {
        let line = ContextMetrics.shared.oneLineSummary()
        let dist = ContextMetrics.shared.modelModeSummary()
        print("📈 [Metrics] \(line)")
        print("📊 [Metrics] \(dist)")
    }
    
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
