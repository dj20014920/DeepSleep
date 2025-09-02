//
//  UnifiedAIServiceImpl.swift
//  DeepSleep
//
//  Created by Claude on 2025-07-21.
//  Copyright © 2025 DeepSleep. All rights reserved.
//

import Foundation
import Combine
import CryptoKit
import UIKit
import Security

/// 🚀 **통합 AI 서비스 실제 구현체**
/// 모든 AI 모델을 통합하여 관리하는 메인 서비스
/// PERF-WARNING: 여러 모델 동시 호출 시 메모리 사용량 주의
/// - 테스트 방안: Instruments의 Allocations로 메모리 누수 확인
public class UnifiedAIServiceImpl: UnifiedAIService {
    public static let shared = UnifiedAIServiceImpl()

    #if DEBUG
    // One-time sample log guard for cache headers
    private static var hasLoggedCacheHeaderSample = false
    #endif
    
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
        // 프록시 모드에서는 원칙적으로 서버가 단일 진실(SSOT)입니다.
        // 그러나 개발 환경(DEBUG)에서는 프록시 장애/인증 실패 시를 대비해
        // 안전 폴백 경로를 활성화합니다.
        if EnvironmentConfig.shared.useProxy {
            #if DEBUG
            // 1) 무료 모델 폴백 초기화(있을 경우)
            if getAPIKey(for: .freeModel) != nil {
                freeModelService = OpenRouterFallbackManager.shared
                print("🛟 [UnifiedAIService] DEBUG 프록시 모드: freeModelService 초기화(안전 폴백)")
            } else {
                freeModelService = nil
                print("⚠️ [UnifiedAIService] DEBUG 프록시 모드: OPENROUTER_API_KEY 미설정 (무료 폴백 비활성)")
            }
            // 2) 로컬 직접 서비스도 초기화해 '직접 폴백' 경로 유지(프록시 실패 시에만 사용)
            if let claudeKey = getAPIKey(for: .claude) { claudeService = ClaudeAPIService(apiKey: claudeKey) }
            if let openAIKey = getAPIKey(for: .openAI) { openAIService = OpenAIAPIService(apiKey: openAIKey) }
            if let geminiKey = getAPIKey(for: .gemini) { geminiService = GeminiAPIService(apiKey: geminiKey) }
            if let naverKey = getAPIKey(for: .naver) { naverService = NaverAPIService(apiKey: naverKey) }
            // 주의: 실제 호출은 항상 프록시 우선이며, 아래 sendMessageInternal에서 프록시 실패 시에만 사용됩니다.
            return
            #else
            // Release: 프록시 모드에서는 클라이언트 키를 사용하지 않음(보안/심사).
            claudeService = nil
            openAIService = nil
            geminiService = nil
            naverService = nil
            freeModelService = nil
            return
            #endif
        }
        // 프록시 미사용: 로컬 서비스를 정상 초기화
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

        // 🛰️ 프록시 모드 절대 우선: 어떤 로컬 라우팅/폴백보다 먼저 서버 프록시로 보낸다.
        if EnvironmentConfig.shared.useProxy {
            do {
                let proxyURL = try resolveProxyBaseURL()
                var roleMessages: [RoleMessage] = []
                if let assembled = assembledPrompt, !assembled.isEmpty {
                    roleMessages.append(RoleMessage(role: .system, content: assembled))
                    // 정책: 최근 나+모델의 16개 턴을 원본 그대로 포함(역할/타임스탬프 유지)
                    if let history = context?.conversationHistory, !history.isEmpty {
                        let recent = Array(history.suffix(16))
                        for turn in recent {
                            roleMessages.append(RoleMessage(role: turn.role, content: turn.content, ts: turn.timestamp))
                        }
                    }
                    // 현재 사용자 입력은 별도의 user 역할로 명확히 전달
                    roleMessages.append(RoleMessage(role: .user, content: content))
                } else {
                    let sys = generateOptimizedSystemPrompt(for: mode, model: model)
                    roleMessages.append(RoleMessage(role: .system, content: sys))
                    if let history = context?.conversationHistory, !history.isEmpty {
                        let recent = Array(history.suffix(16))
                        for turn in recent { roleMessages.append(RoleMessage(role: turn.role, content: turn.content, ts: turn.timestamp)) }
                    }
                    roleMessages.append(RoleMessage(role: .user, content: content))
                }
                print("🛰️ [UnifiedAIService] Proxy first-path engaged → /v1/chat")
                // New: Diagnostic prep log (no PII) — assembledPrompt usage, lengths, history turns, context cache snapshot
                let sysLen = roleMessages.first?.content.count ?? 0
                let userLen = roleMessages.last?.content.count ?? 0
                let histTurns = max(0, roleMessages.count - 2)
                let ctxSnap = AIContextManager.shared.debugSnapshot()
                let usedAssembled = (assembledPrompt != nil && !(assembledPrompt!.isEmpty))
                print("🧩 [AICallPrep] preferred=\(model.rawValue) mode=\(mode.rawValue) assembledPrompt=\(usedAssembled) sysLen=\(sysLen) histTurns=\(histTurns) userLen=\(userLen) ctx=\(ctxSnap)")
                let rawResp = try await sendViaProxy(messages: roleMessages, mode: mode, preferred: model, proxyURL: proxyURL)
                let nickname = UserSettingsModel.loadFromUserDefaults().nickname
                let (processedText, reason) = AIResponsePostProcessor.stripRepetitiveGreetingIfNeeded(
                    response: rawResp.content,
                    history: context?.conversationHistory,
                    nickname: nickname
                )
                var addInfo = rawResp.metadata.additionalInfo
                addInfo["greeting_stripped"] = (reason != nil)
                if let r = reason { addInfo["greeting_stripped_reason"] = r }
                let newMeta = ResponseMetadata(
                    emotionAnalysis: rawResp.metadata.emotionAnalysis,
                    recommendations: rawResp.metadata.recommendations,
                    confidenceScore: rawResp.metadata.confidenceScore,
                    additionalInfo: addInfo
                )
                return AIResponse(
                    id: rawResp.id,
                    model: rawResp.model,
                    mode: rawResp.mode,
                    content: processedText,
                    metadata: newMeta,
                    usage: rawResp.usage,
                    timestamp: rawResp.timestamp,
                    processingTime: rawResp.processingTime
                )
            } catch let AIServiceError.serverError(statusCode) {
                // 인증/서버 오류 → DEBUG에서만 안전 폴백(통합 무료 모델 → 로컬 직접 서비스 순)
                #if DEBUG
                if statusCode == 401 || statusCode == 403 || statusCode >= 500 {
                    // 1) OpenRouter 무료 폴백 우선
                    if let freeService = freeModelService {
                        print("🛟 [UnifiedAIService] Proxy 오류(\(statusCode)) → OpenRouter 안전 폴백 시도")
                        var messages: [OpenRouterFallbackManager.ORMessage] = []
                        if let assembled = assembledPrompt, !assembled.isEmpty {
                            messages.append(.init(role: "system", content: assembled))
                        } else {
                            messages.append(.init(role: "system", content: generateOptimizedSystemPrompt(for: mode, model: .freeModel)))
                            if let history = context?.conversationHistory, !history.isEmpty {
                                let recent = Array(history.suffix(16))
                                for turn in recent {
                                    messages.append(.init(role: turn.role.rawValue, content: turn.content))
                                }
                            }
                        }
                        messages.append(.init(role: "user", content: content))
                        let responseText = try await freeService.sendMessageWithFallback(messages: messages, mode: mode)
                        // New: fallback summary log (OpenRouter)
                        let durationMs = Int(Date().timeIntervalSince(startTime)*1000)
                        print("🛟 [AIFallback] path=openrouter from=\(model.rawValue) mode=\(mode.rawValue) status=\(statusCode) durationMs=\(durationMs)")
                        let usage = TokenUsage(promptTokens: 0, completionTokens: 0, totalTokens: 0, estimatedCost: 0)
                        let meta = ResponseMetadata(emotionAnalysis: nil, recommendations: nil, confidenceScore: 0.0, additionalInfo: ["provider": "openrouter", "fallback": true])
                        return AIResponse(id: UUID().uuidString, model: .freeModel, mode: mode, content: responseText, metadata: meta, usage: usage, timestamp: Date(), processingTime: Int(Date().timeIntervalSince(startTime)*1000))
                    }
                    // 2) 무료 모델이 없거나 실패한 경우: 로컬 직접 서비스 폴백(프록시 우회)
                    if hasAnyDirectServiceAvailable() {
                        print("🛟 [UnifiedAIService] Proxy 오류(\(statusCode)) → 로컬 직접 서비스 폴백 시도")
                        let resp = try await sendDirectBypassingProxy(
                            content: content,
                            preferredModel: model,
                            mode: mode,
                            context: context,
                            assembledPrompt: assembledPrompt
                        )
                        // New: fallback summary log (Direct)
                        let durationMs = Int(Date().timeIntervalSince(startTime)*1000)
                        print("🛟 [AIFallback] path=direct from=\(model.rawValue) to=\(resp.model.rawValue) mode=\(mode.rawValue) status=\(statusCode) durationMs=\(durationMs)")
                        return resp
                    } else {
                        print("⚠️ [UnifiedAIService] 직접 폴백 불가: 로컬 서비스 미초기화 또는 키 누락")
                    }
                }
                #endif
                throw AIServiceError.serverError(statusCode: statusCode)
            } catch {
                throw error
            }
        }

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
                // Post-process to reduce repetitive greetings after the first assistant turn
                let nickname = UserSettingsModel.loadFromUserDefaults().nickname
                let (processedText, reason) = AIResponsePostProcessor.stripRepetitiveGreetingIfNeeded(
                    response: response.content,
                    history: context?.conversationHistory,
                    nickname: nickname
                )
                if let r = reason {
                    print("✂️ [UnifiedAIService] Stripped leading greeting (\(r))")
                }
                var addInfo = response.metadata.additionalInfo
                addInfo["greeting_stripped"] = (reason != nil)
                if let r = reason { addInfo["greeting_stripped_reason"] = r }
                let newMeta = ResponseMetadata(
                    emotionAnalysis: response.metadata.emotionAnalysis,
                    recommendations: response.metadata.recommendations,
                    confidenceScore: response.metadata.confidenceScore,
                    additionalInfo: addInfo
                )
                // New: one-line call summary for direct path
                print("🎯 [AICallSummary] path=direct provider=\(finalModel.rawValue) mode=\(mode.rawValue) durationMs=\(Int(processingTime * 1000)) cacheProvider=- cacheAction=- fallback=false")
                return AIResponse(
                    id: response.id,
                    model: response.model,
                    mode: response.mode,
                    content: processedText,
                    metadata: newMeta,
                    usage: response.usage,
                    timestamp: response.timestamp,
                    processingTime: response.processingTime
                )
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
        // 🛰️ 프록시 경유(구성 기반)
        if EnvironmentConfig.shared.useProxy {
            let proxyURL = try resolveProxyBaseURL()
            // Build messages
            var roleMessages: [RoleMessage] = []
            if let assembled = assembledPrompt, !assembled.isEmpty {
                roleMessages.append(RoleMessage(role: .system, content: assembled))
            } else {
                let sys = generateOptimizedSystemPrompt(for: mode, model: model)
                roleMessages.append(RoleMessage(role: .system, content: sys))
                if let history = context?.conversationHistory, !history.isEmpty {
                    let recent = Array(history.suffix(16))
                    for turn in recent { roleMessages.append(RoleMessage(role: turn.role, content: turn.content, ts: turn.timestamp)) }
                }
                roleMessages.append(RoleMessage(role: .user, content: content))
            }
            // Call proxy inline (avoid project membership issues)
            return try await sendViaProxy(messages: roleMessages, mode: mode, preferred: model, proxyURL: proxyURL)
        }

        // 📉 Claude 일일 요청 상한 체크(유료도 상한 적용)
        if model == .claude {
            let (canUseClaude, _, _) = claudeUsageStatus()
            if !canUseClaude {
                // Claude 상한 초과 → Gemini 우선 폴백
                let fallbackModel: AIModel = availableModels.contains(.gemini) ? .gemini : (fallbackOrder.first { $0 != .claude } ?? .freeModel)
                print("🔀 [UnifiedAIService] Claude 일일 상한 도달 → \(fallbackModel.rawValue)로 자동 라우팅")
                return try await sendToSpecificModel(
                    content: content,
                    model: fallbackModel,
                    mode: mode,
                    context: context,
                    tokenConfig: tokenConfig,
                    assembledPrompt: assembledPrompt
                )
            }
        }
        
        // 🎨 시스템 프롬프트 구성: assembledPrompt가 있으면 그것을 단일 시스템 프롬프트로 사용 (중복 제거)
        let systemPrompt: String = {
            if let assembled = assembledPrompt, !assembled.isEmpty {
                return assembled
            } else {
                return generateOptimizedSystemPrompt(for: mode, model: model)
            }
        }()
        
        // 멀티-메시지 구성: 시스템 + (필요 시) 최근 대화 + 현재 사용자 입력
        // assembledPrompt가 제공된 경우, 이미 시스템/메모리/최근/사용자 입력이 조립되어 있으므로
        // 추가 히스토리를 중복해서 붙이지 않습니다.
        var roleMessages: [RoleMessage] = [RoleMessage(role: .system, content: systemPrompt)]
        if assembledPrompt == nil, let history = context?.conversationHistory, !history.isEmpty {
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
            let result = try await service.sendMessages(messages: roleMessages, mode: mode, tokenConfig: tokenConfig)
            incrementClaudeUsage()
            return result
            
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
            let sysPrompt: String = {
                if let assembled = assembledPrompt, !assembled.isEmpty {
                    return assembled
                } else {
                    return generateOptimizedSystemPrompt(for: mode, model: model)
                }
            }()
            var messages: [OpenRouterFallbackManager.ORMessage] = [
                .init(role: "system", content: sysPrompt)
            ]
            
            if assembledPrompt == nil, let history = context?.conversationHistory, !history.isEmpty {
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

    // MARK: - Claude 일일 상한 관리 (단일 진실원칙: 프록시 사용 시 로컬 상한 비활성화)
    private func claudeUsageStatus() -> (canUse: Bool, current: Int, limit: Int) {
        // 프록시 모드에서는 서버 정책 헤더(X-Policy-*)가 단일 진실원칙(SSOT)으로 작동하므로,
        // 로컬 상한 체크를 비활성화합니다.
        if EnvironmentConfig.shared.useProxy {
            return (true, 0, Int.max)
        }
        let isPremium = SubscriptionStatusCenter.shared.isPremium
        let key = isPremium ? "DAILY_CLAUDE_LIMIT_PREMIUM" : "DAILY_CLAUDE_LIMIT_FREE"
        // 프록시 미사용(개발/offline)에서만 로컬 제한을 사용하며, 기본값은 0으로 둡니다.
        let limit = ConfigReader.int(key, default: 0) ?? 0
        let ud = UserDefaults.standard
        let dateKey = claudeDateKey()
        let today = todayString()
        if ud.string(forKey: dateKey) != today {
            ud.set(today, forKey: dateKey)
            ud.set(0, forKey: claudeCountKey())
        }
        let count = ud.integer(forKey: claudeCountKey())
        return (count < limit, count, limit)
    }
    private func incrementClaudeUsage() {
        let ud = UserDefaults.standard
        let today = todayString()
        if ud.string(forKey: claudeDateKey()) != today {
            ud.set(today, forKey: claudeDateKey())
            ud.set(0, forKey: claudeCountKey())
        }
        let cur = ud.integer(forKey: claudeCountKey())
        ud.set(cur + 1, forKey: claudeCountKey())
    }
    private func claudeCountKey() -> String { "claude_usage_count" }
    private func claudeDateKey() -> String { "claude_usage_date" }
    private func todayString() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
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
        print("🔔 [UnifiedAIService] aiModelChanged: \(from) → \(to). 파이프라인 점검")
        // 모델별 특화 지침은 런타임 합성하므로 시스템 프롬프트 캐시는 모델 변경으로 무효화하지 않습니다.
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
            .taskAdvice: availableModels.contains(.openAI) ? .openAI : .freeModel,
            // 비용/가용성 기준: 프리셋 추천은 Gemini 우선, 실패 시 OpenAI로 폴백
            .presetRecommendation: availableModels.contains(.gemini) ? .gemini : (availableModels.contains(.openAI) ? .openAI : .freeModel),
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
        let basePromptText = getBaseSystemPromptForMode(mode)
        let generalGuidelines = """
        중요한 지침:
        - 한국어로 자연스럽고 친근하게 응답하세요
        - 사용자의 감정과 상황을 깊이 이해하고 공감하세요  
        - 실용적이고 도움이 되는 조언을 제공하세요
        - 부정확한 정보는 제공하지 말고, 확신이 없으면 솔직히 말하세요
        - 개인정보를 외부에 저장하지 마세요. 세션 내 제공된 대화 히스토리를 바탕으로 맥락을 이어가세요.
        - "이전 대화를 기억하지 못한다"와 같은 메타 발화를 하지 마세요. 제공된 히스토리 범위에서 자연스럽게 이어가세요.
        - 반복 인사 방지: 첫 응답에서만 간단한 인사가 허용됩니다. 이후 메시지는 "안녕하세요" 등의 인사로 시작하지 말고 바로 본론으로 들어가세요.
        - 호칭 과다 사용 금지: 사용자 닉네임은 필요할 때에만 드물게 사용하세요(매 턴 반복 금지).
        """
        
        // 페르소나 코어 시그니처(모델 불문) 구성 (외부 전송 금지, 캐시 키로만 사용)
        let memorySummaryFP: String = {
            let summary = MemoryManager.shared.getMemorySummary(maxItems: 5)
            return summary.isEmpty ? "none" : String(summary.hashValue)
        }()
        let baseKey = AIContextSignature.buildBase(
            personaSignature: UserRulesManager.shared.personaCoreSignature(),
            mode: mode,
            memorySummaryFP: memorySummaryFP
        )
        
        // 3시간 TTL 캐시 활용: 모델 불문 베이스 프롬프트만 캐시
        let basePrompt = contextManager.getSystemPrompt(personaSignature: baseKey) {
            return "\(basePromptText)\n\n\(generalGuidelines)"
        }
        
        // 모델별 최적화 지침은 런타임에 덧붙임 (캐시 키에 포함되지 않음)
        let modelSpecific = getModelSpecificOptimization(for: model)
        return basePrompt + "\n\n" + modelSpecific
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
            // 사용 가능한 사운드/버전 목록 요약(간결)
            let count = SoundPresetCatalog.categoryCount
            var lines: [String] = []
            for i in 0..<min(count, 13) {
                if let c = SoundManager.shared.getSoundCatalog(at: i) {
                    let vnames = c.versions.map { $0.displayName }.joined(separator: ", ")
                    lines.append("- \(c.baseName): \(vnames)")
                }
            }
            let catalogSummary = lines.joined(separator: "\n")
            return """
            당신은 DeepSleep 앱의 사운드 큐레이터입니다. 아래 지침에 따라 오직 JSON 오브젝트 한 개만 반환하세요.
            (중요) 코드펜스(```), 주석, 설명, 불릿 등 JSON 외 텍스트는 절대 포함하지 마세요.

            [목표]
            - 사용자의 간략한 페르소나/최근 대화/감정 일기를 바탕으로, 앱 내 사운드들 중 어울리는 조합을 직접 선정합니다.
            - 사전 정의 프리셋 키를 사용하지 않습니다. 앱의 실제 사운드 이름과 버전을 사용하세요.

            [반드시 지킬 것]
            - JSON 오브젝트 단 한 개만 반환(추가 텍스트 금지)
            - items는 1~13개, volume은 0~100 정수
            - soundName은 앱 카탈로그의 이름 중 하나, versionName은 해당 사운드의 버전 이름 중 하나
            - reason은 120자 이내 한국어 텍스트

            [앱 사운드 카탈로그 요약]
            \(catalogSummary)

            [예시 JSON 스키마(요약)]
            {
              "presetName": "🌙 부드러운 밤의 호흡",
              "items": [
                {"soundName": "바람", "versionName": "바람2 v2", "volume": 35},
                {"soundName": "파도", "versionName": "파도2 v2", "volume": 30}
              ],
              "reason": "밤 시간대의 안정감을 높이고…",
              "confidence": 0.82
            }

            [주의]
            - 위 스키마를 준수하세요. JSON 외 텍스트 출력 금지.
            - 코드펜스(```json 등), 마크다운, 추가 설명 금지. 순수 JSON만 반환.
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
    
    /// DEBUG 전용: 로컬 직접 서비스 사용 가능 여부
    private func hasAnyDirectServiceAvailable() -> Bool {
        return claudeService != nil || openAIService != nil || geminiService != nil || naverService != nil
    }

    /// DEBUG 전용: 프록시 우회하여 로컬 서비스로 직접 전송(안전 폴백)
    /// - 주의: EnvironmentConfig.shared.useProxy가 true여도 이 경로는 프록시를 사용하지 않습니다.
    private func sendDirectBypassingProxy(
        content: String,
        preferredModel: AIModel,
        mode: AIMode,
        context: AIContext?,
        assembledPrompt: String?
    ) async throws -> AIResponse {
        // 최적 모델 선택(기본 선호 존중)
        let model = getOptimalModelForMode(mode: mode, userPreferred: preferredModel)
        // 시스템 프롬프트
        let systemPrompt: String = {
            if let assembled = assembledPrompt, !assembled.isEmpty { return assembled }
            return generateOptimizedSystemPrompt(for: mode, model: model)
        }()
        // 역할 기반 메시지 구성
        var roleMessages: [RoleMessage] = [RoleMessage(role: .system, content: systemPrompt)]
        if assembledPrompt == nil, let history = context?.conversationHistory, !history.isEmpty {
            let recent = Array(history.suffix(16))
            for turn in recent {
                roleMessages.append(RoleMessage(role: turn.role, content: turn.content, ts: turn.timestamp))
            }
        }
        roleMessages.append(RoleMessage(role: .user, content: content))
        // 모델별 직접 호출
        let tokenCfg = optimizeTokenConfigForModel(mode.recommendedTokenConfig, model: model, mode: mode)
        let response: AIResponse
        switch model {
        case .claude:
            guard let service = claudeService else { throw AIServiceError.modelUnavailable(model: .claude) }
            response = try await service.sendMessages(messages: roleMessages, mode: mode, tokenConfig: tokenCfg)
        case .openAI:
            guard let service = openAIService else { throw AIServiceError.modelUnavailable(model: .openAI) }
            response = try await service.sendMessages(messages: roleMessages, mode: mode, tokenConfig: tokenCfg)
        case .gemini:
            guard let service = geminiService else { throw AIServiceError.modelUnavailable(model: .gemini) }
            response = try await service.sendMessages(messages: roleMessages, mode: mode, tokenConfig: tokenCfg)
        case .naver:
            guard let service = naverService else { throw AIServiceError.modelUnavailable(model: .naver) }
            response = try await service.sendMessages(messages: roleMessages, mode: mode, tokenConfig: tokenCfg)
        case .freeModel:
            // freeModelService가 없으므로, 차선인 Gemini/OpenAI/Claude/Naver 순으로 선택
            if let svc = geminiService {
                return try await svc.sendMessages(messages: roleMessages, mode: mode, tokenConfig: tokenCfg)
            } else if let svc = openAIService {
                return try await svc.sendMessages(messages: roleMessages, mode: mode, tokenConfig: tokenCfg)
            } else if let svc = claudeService {
                return try await svc.sendMessages(messages: roleMessages, mode: mode, tokenConfig: tokenCfg)
            } else if let svc = naverService {
                return try await svc.sendMessages(messages: roleMessages, mode: mode, tokenConfig: tokenCfg)
            } else {
                throw AIServiceError.modelUnavailable(model: .freeModel)
            }
        }
        // 출력 후처리(인사 제거)
        let nickname = UserSettingsModel.loadFromUserDefaults().nickname
        let (processedText, reason) = AIResponsePostProcessor.stripRepetitiveGreetingIfNeeded(
            response: response.content,
            history: context?.conversationHistory,
            nickname: nickname
        )
        if let r = reason { print("✂️ [UnifiedAIService] Direct fallback: leading greeting stripped (\(r))") }
        var addInfo = response.metadata.additionalInfo
        addInfo["fallback"] = true
        addInfo["fallback_path"] = "direct_local"
        let newMeta = ResponseMetadata(
            emotionAnalysis: response.metadata.emotionAnalysis,
            recommendations: response.metadata.recommendations,
            confidenceScore: response.metadata.confidenceScore,
            additionalInfo: addInfo
        )
        return AIResponse(
            id: response.id,
            model: model,
            mode: response.mode,
            content: processedText,
            metadata: newMeta,
            usage: response.usage,
            timestamp: response.timestamp,
            processingTime: response.processingTime
        )
    }
}

// MARK: - Proxy inline call
extension UnifiedAIServiceImpl {
    /// PROXY_BASE_URL 정규화 및 엄격 검증
    private func resolveProxyBaseURL() throws -> URL {
        let raw = EnvironmentConfig.shared.proxyBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { throw AIServiceError.configurationError("PROXY_BASE_URL_INVALID") }
        let normalized: String = {
            if raw.lowercased().hasPrefix("http://") || raw.lowercased().hasPrefix("https://") { return raw }
            return "https://" + raw
        }()
        guard let url = URL(string: normalized),
              let scheme = url.scheme?.lowercased(), (scheme == "https" || scheme == "http"),
              let host = url.host, !host.isEmpty else {
            throw AIServiceError.configurationError("PROXY_BASE_URL_INVALID")
        }
        return url
    }

    private func providerCacheTTLSeconds(for mode: AIMode) -> Int {
        // Gemini는 공급자 최대 TTL이 1시간이므로 서버가 자동 연장한다.
        // 앱은 1시간 요청을 유지해 UX/보안에 영향 없이 단순화.
        switch mode {
        case .emotionDiaryAnalysis, .presetRecommendation:
            return 3600
        default:
            return 3600
        }
    }

    private func sendViaProxy(messages: [RoleMessage], mode: AIMode, preferred: AIModel, proxyURL: URL) async throws -> AIResponse {
        var body: [String: Any] = [
            "model": mapPreferredModelForProxy(preferred),
            "messages": messages.map { ["role": $0.role.rawValue, "content": $0.content] },
            "mode": mode.rawValue
        ]
        // 서버 공급자 캐싱 활성화 + 안정적 캐시 키(PersonaCoreSignature)
        let personaCoreKey = UserRulesManager.shared.personaCoreSignature()
        body["providerCaching"] = [
            "enable": true,
            "strategy": "auto",
            "ttlSeconds": providerCacheTTLSeconds(for: mode),
            "cacheKey": personaCoreKey
        ]
        // New: providerCaching config log
        print("🧱 [ProviderCaching] enable=true strategy=auto ttlSeconds=\(providerCacheTTLSeconds(for: mode)) cacheKey=\(String(personaCoreKey.prefix(16)))…")
        // 서버 캐시 무효화 이벤트가 보류되어 있으면 1회성으로 헤더 전송
        let contextInvalidation = AIContextManager.shared.consumeInvalidationReasonForHeader()
        
        // 서명/요청 생성: 서명에 사용한 ts/nonce와 헤더의 ts/nonce를 반드시 동일하게 유지
        func makeRequest(ts: String, nonce: String?, signature: String) throws -> URLRequest {
            var r = URLRequest(url: proxyURL.appendingPathComponent("v1/chat"))
            r.httpMethod = "POST"
            r.setValue("application/json", forHTTPHeaderField: "Content-Type")
            r.setValue(ProxyAuthConfig.origin, forHTTPHeaderField: "Origin")
            r.setValue(uid, forHTTPHeaderField: "X-Emozleep-UID")
            r.setValue(tier, forHTTPHeaderField: "X-Emozleep-Tier")
            r.setValue(ts, forHTTPHeaderField: "X-Emozleep-Timestamp")
            if let n = nonce { r.setValue(n, forHTTPHeaderField: "X-Emozleep-Nonce") }
            if let inv = contextInvalidation, !inv.isEmpty { r.setValue(inv, forHTTPHeaderField: "X-Context-Invalidation") }
            r.setValue(signature, forHTTPHeaderField: "X-Emozleep-Sig")
            r.httpBody = try JSONSerialization.data(withJSONObject: body)
            return r
        }
        func header(_ http: HTTPURLResponse, _ key: String) -> String? {
            // 대/소문자 무시 헤더 조회
            for (k, v) in http.allHeaderFields {
                if let ks = (k as? String), ks.caseInsensitiveCompare(key) == .orderedSame {
                    return String(describing: v)
                }
            }
            return nil
        }

        // Prepare common header values (uid/tier만 고정, ts/nonce는 시도별 갱신)
        let uid: String = await MainActor.run { UIDevice.current.identifierForVendor?.uuidString ?? "unknown" }
        let tier: String = { switch StoreKitSubscriptionManager.shared.currentTier { case .free: return "free"; case .pro: return "pro"; case .max: return "max" } }()

        // Device secret 확보: Keychain → 없으면 enroll 호출. DEBUG에서는 마지막 폴백 허용
        print("🔐 [UnifiedAIService] 프록시 인증 준비 - UID: \(uid), Tier: \(tier)")
        var effectiveSecret: String
        do {
            effectiveSecret = try await ProxyAuthClient.loadSecretOrEnroll(uid: uid, proxyBase: proxyURL)
            print("✅ [UnifiedAIService] 시크릿 확보 성공")
        } catch {
            print("⚠️ [UnifiedAIService] ProxyAuthClient 실패: \(error)")
            #if DEBUG
            let fallback = EnvironmentConfig.shared.clientProxyHmacSecret
            if !fallback.isEmpty {
                print("🔄 [UnifiedAIService] DEBUG 모드: CLIENT_PROXY_HMAC_SECRET 폴백 사용")
                effectiveSecret = fallback
            } else {
                print("❌ [UnifiedAIService] CLIENT_PROXY_HMAC_SECRET도 비어있음")
                throw AIServiceError.configurationError("PROXY_DEVICE_SECRET_MISSING")
            }
            #else
            print("❌ [UnifiedAIService] 프로덕션 모드: 시크릿 없음")
            throw AIServiceError.configurationError("PROXY_DEVICE_SECRET_MISSING")
            #endif
        }

        let start = Date()
        let useNonce = EnvironmentConfig.shared.proxyAuthUseNonce
        var attempt = 0
        var data: Data = Data()
        var http: HTTPURLResponse!
        while attempt < 2 {
            let curTs = String(Int64(Date().timeIntervalSince1970 * 1000))
            let curNonce = useNonce ? UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased() : nil
            let sigMessage = ProxyAuthSigner.composeSigningMessage(ts: curTs, uid: uid, tier: tier, nonce: curNonce)
            print("🔏 [UnifiedAIService] 서명 생성 - Message: \(sigMessage)")
            let signature = ProxyAuthSigner.hmacSHA256Hex(message: sigMessage, secret: effectiveSecret)
            let req = try makeRequest(ts: curTs, nonce: curNonce, signature: signature)
            print("📤 [UnifiedAIService] 프록시 요청 전송(attempt=\(attempt+1)): \(proxyURL.absoluteString)/v1/chat")
            let result = try await URLSession.shared.data(for: req)
            data = result.0
            if let r = result.1 as? HTTPURLResponse { http = r } else {
                print("❌ [UnifiedAIService] 프록시 응답이 HTTP가 아님")
                throw AIServiceError.serverError(statusCode: -1)
            }
            print("📥 [UnifiedAIService] 프록시 응답: HTTP \(http.statusCode)")
            if (200...299).contains(http.statusCode) {
                break
            }
            if http.statusCode == 401 && attempt == 0 {
                print("↻ [UnifiedAIService] 401 감지 → 시크릿 삭제 후 재등록 시도")
                ProxySecretStore.delete(for: uid)
                effectiveSecret = try await ProxyAuthClient.loadSecretOrEnroll(uid: uid, proxyBase: proxyURL)
                attempt += 1
                continue
            }
            // 그 외 오류는 기존 처리로 전달
            break
        }
        
        guard (200...299).contains(http.statusCode) else {
            let code = http.statusCode
            if code == 401 {
                print("❌ [UnifiedAIService] 401 인증 실패 - 시크릿이 잘못되었거나 만료됨")
            } else if code == 403 {
                print("❌ [UnifiedAIService] 403 권한 없음 - Origin 또는 티어 문제")
            } else {
                print("❌ [UnifiedAIService] 프록시 오류: \(code)")
            }
            throw AIServiceError.serverError(statusCode: code)
        }
        struct ProxyResp: Codable { let provider: String; let content: String }
        let proxy = try JSONDecoder().decode(ProxyResp.self, from: data)

        // 정책/프로바이더/캐시 헤더 파싱
        if let st = header(http, "Server-Timing") {
            print("⏱️ [Server-Timing] \(st)")
        }
        let polRemaining = header(http, "X-Policy-Remaining")
        let polResetAt  = header(http, "X-Policy-ResetAt")
        let polTier     = header(http, "X-Policy-Tier")
        let claudeLeft  = header(http, "X-Policy-Claude-Remaining")
        let providerHdr = header(http, "X-Provider")
        let cacheProv   = header(http, "X-Cache-Provider")
        let cacheAction = header(http, "X-Cache-Action")
        let cacheTTL    = header(http, "X-Cache-TTL")
        let cacheTokens = header(http, "X-Cache-Tokens")

        #if DEBUG
        if !Self.hasLoggedCacheHeaderSample {
            print("🧪 [CacheHeaders] provider=\(cacheProv ?? "-") action=\(cacheAction ?? "-") ttl=\(cacheTTL ?? "-") tokens=\(cacheTokens ?? "-")")
            Self.hasLoggedCacheHeaderSample = true
        }
        #endif

        // New: one-line call summary for proxy path
        let ms = Int(Date().timeIntervalSince(start)*1000)
        let providerUsed = proxy.provider
        let preferredName = preferred.rawValue
        let cacheUsed = (cacheAction?.lowercased() == "read")
        let serverFallback = (providerHdr ?? providerUsed) != preferredName
        print("🎯 [AICallSummary] path=proxy provider=\(providerUsed) xProvider=\(providerHdr ?? "-") preferred=\(preferredName) mode=\(mode.rawValue) durationMs=\(ms) cacheProvider=\(cacheProv ?? "-") cacheAction=\(cacheAction ?? "-") cacheUsed=\(cacheUsed) cacheTTL=\(cacheTTL ?? "-") tokens=\(cacheTokens ?? "-") policyTier=\(polTier ?? "-") remaining=\(polRemaining ?? "-") resetAt=\(polResetAt ?? "-") fallback=\(serverFallback)")
        if let xProv = providerHdr, xProv != providerUsed {
            print("⚠️ [AICallSummary] provider header mismatch: body=\(providerUsed) header=\(xProv)")
        }

        var addInfo: [String: Any] = ["provider": proxy.provider]
        if let r = polRemaining { addInfo["policyRemaining"] = r }
        if let r = polResetAt  { addInfo["policyResetAt"] = r }
        if let r = polTier     { addInfo["policyTier"] = r }
        if let r = claudeLeft  { addInfo["claudeRemaining"] = r }
        if let r = providerHdr { addInfo["providerHeader"] = r }
        if let r = cacheProv   { addInfo["cacheProvider"] = r }
        if let r = cacheAction { addInfo["cacheAction"] = r }
        if let r = cacheTTL    { addInfo["cacheTTL"] = r }
        if let r = cacheTokens { addInfo["cacheTokens"] = r }

        let usage = TokenUsage(promptTokens: 0, completionTokens: 0, totalTokens: 0, estimatedCost: 0)
        let meta = ResponseMetadata(emotionAnalysis: nil, recommendations: nil, confidenceScore: 0.0, additionalInfo: addInfo)
        return AIResponse(id: UUID().uuidString, model: preferred, mode: mode, content: proxy.content, metadata: meta, usage: usage, timestamp: Date(), processingTime: Int(Date().timeIntervalSince(start)*1000))
    }
}

/// 20요청마다 메트릭 요약 로그를 출력 (ContextMetrics 단일 출처 사용)
private func emitMetricsSummaryLog() {
    let summary = ContextMetrics.shared.oneLineSummary()
    let dist = ContextMetrics.shared.modelModeSummary()
    print("📈 [AIMetrics] \(summary)")
    print("📊 [AIMetrics] \(dist)")
}

/// 프록시 서버가 기대하는 모델 식별자 문자열로 매핑
/// - 단일 출처: AIModel → 서버 체인(openrouter/gemini/openai/naver/claude)
private func mapPreferredModelForProxy(_ preferred: AIModel) -> String {
    switch preferred {
    case .gemini: return "gemini"
    case .openAI: return "openai"
    case .claude: return "claude"
    case .naver: return "naver"
    case .freeModel: return "openrouter" // 통합 무료 모델은 서버에서 openrouter로 시작
    }
}
