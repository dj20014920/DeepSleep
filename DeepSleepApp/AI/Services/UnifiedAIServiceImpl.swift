//
//  UnifiedAIServiceImpl.swift
//  DeepSleep
//
//  Created by Claude on 2025-07-21.
//  Copyright © 2025 DeepSleep. All rights reserved.
//

import Combine
import CryptoKit
import Foundation
import Security

#if canImport(UIKit)
    import UIKit
#endif

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
    private let usageGate = UsageGate.shared

    // Idempotency/inflight dedup
    private var isSending: Bool = false
    private var inflightKeys = Set<String>()

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
        modelChangedObserver = NotificationCenter.default.addObserver(
            forName: .aiModelChanged, object: nil, queue: .main
        ) { [weak self] note in
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
        case .onDevice:
            // 온디바이스 모델은 API 키가 필요하지 않음
            return nil
        }

        guard let apiKey = ConfigReader.string(keyName),
            !apiKey.isEmpty
        else {
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
                if let claudeKey = getAPIKey(for: .claude) {
                    claudeService = ClaudeAPIService(apiKey: claudeKey)
                }
                if let openAIKey = getAPIKey(for: .openAI) {
                    openAIService = OpenAIAPIService(apiKey: openAIKey)
                }
                // Vertex-Gemini는 항상 프록시 경유. 로컬 직접 Gemini 폴백은 비활성화한다.
                geminiService = nil
                if let naverKey = getAPIKey(for: .naver) {
                    naverService = NaverAPIService(apiKey: naverKey)
                }
                print(
                    "ℹ️ [UnifiedAIService] DEBUG 프록시 모드: direct Gemini fallback 비활성화 (Vertex via proxy)"
                )
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
        #if os(iOS)
            if #available(iOS 18.0, *) { models.append(.onDevice) }
        #endif
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
        assembledPrompt: String? = nil,
        policyMeta: [String: String]? = nil
    ) async throws -> AIResponse {
        #if DEBUG
            let perf = PerfTrace(flow: "UnifiedAIService")
            perf.with(extra: "mode", mode.rawValue).with(extra: "model", model.rawValue)
                .with(extra: "userLen", String(content.count))
        #endif
        let reqId = UUID().uuidString
        ContextMetrics.shared.logRequestStart(id: reqId, model: model.rawValue, mode: mode.rawValue)
        let overallStart = Date()
        // Simple dedup: prevent overlapping sends
        if isSending {
            throw AIServiceError.configurationError("REQUEST_INFLIGHT")
        }
        isSending = true
        defer { isSending = false }
        // Build idempotency key from stable inputs (no PII): mode+personaCoreSignature+hash(content)
        let personaKey = UserRulesManager.shared.personaCoreSignature()
        let contentHash = SHA256.hash(data: Data(content.utf8)).compactMap {
            String(format: "%02x", $0)
        }.joined()
        let idemKey = String((mode.rawValue + ":" + personaKey + ":" + contentHash).prefix(64))
        if inflightKeys.contains(idemKey) {
            throw AIServiceError.configurationError("DUPLICATE_INFLIGHT")
        }
        inflightKeys.insert(idemKey)
        defer { inflightKeys.remove(idemKey) }

        // 주기적 메트릭 요약 로그 (20요청마다)
        requestCounter += 1
        if requestCounter % 20 == 0 {
            emitMetricsSummaryLog()
        }

        // 0. 일일 사용량 한도 체크 (통합 진입점에서 강제)
        if mode == .taskAdviceOverall {
            // SSOT: 티어별 전체 조언 제한은 Secrets의 AI_LIMITS_TODO_OVERALL_ADVICE_*만 사용
            let tier = StoreKitSubscriptionManager.shared.currentTier
            let tierKey: String = {
                switch tier {
                case .max: return "AI_LIMITS_TODO_OVERALL_ADVICE_MAX"
                case .pro: return "AI_LIMITS_TODO_OVERALL_ADVICE_PRO"
                case .free: return "AI_LIMITS_TODO_OVERALL_ADVICE_FREE"
                }
            }()
            let limit = ConfigReader.int(tierKey, default: 0) ?? 0
            let status = usageGate.canUseDailyKeyedFeature(
                key: "todo_overall_advice", limit: limit)
            guard status.canUse else {
                ContextMetrics.shared.logRequestEnd(
                    id: reqId, model: model.rawValue, mode: mode.rawValue, success: false,
                    duration: Date().timeIntervalSince(overallStart))
                throw AIServiceError.configurationError(
                    "USAGE_LIMIT_EXCEEDED: task_advice_overall 0/\(limit)")
            }
        } else {
            let usage = usageGate.checkUsage(for: mode)
            guard usage.canUse else {
                ContextMetrics.shared.logRequestEnd(
                    id: reqId, model: model.rawValue, mode: mode.rawValue, success: false,
                    duration: Date().timeIntervalSince(overallStart))
                throw AIServiceError.configurationError(
                    "USAGE_LIMIT_EXCEEDED: \(mode.rawValue) \(usage.currentUsage)/\(usage.dailyLimit)"
                )
            }
        }

        #if DEBUG
            perf.mark("validate:security")
        #endif
        // 1. 보안 검증
        let validationResult = securityManager.validateAndSanitizeInput(
            content, userId: context?.userId ?? "unknown")

        let cleaned: String
        switch validationResult {
        case .rejected(_):
            ContextMetrics.shared.logRequestEnd(
                id: reqId, model: model.rawValue, mode: mode.rawValue, success: false,
                duration: Date().timeIntervalSince(overallStart))
            throw AIServiceError.unauthorized
        case .flagged(let reason, let cleanInput):
            print("⚠️ [UnifiedAIService] 입력이 플래그됨: \(reason)")
            cleaned = cleanInput
        case .approved(let cleanInput):
            cleaned = cleanInput
        }

        #if DEBUG
            perf.mark("svc:internal:start")
        #endif
        do {
            // 2. 실제 호출 (성공 시에만 사용량 증가)
            let response = try await sendMessageInternal(
                cleaned, model, mode, context, tokenConfig, assembledPrompt, policyMeta)
            // Call logging success (mode/model 포함)
            let elapsedMs = Int(Date().timeIntervalSince(overallStart) * 1000)
            AICallLogger.shared.logAICallSuccess(
                callId: reqId,
                mode: response.mode,
                model: response.model,
                responseLength: response.content.count,
                processingTime: elapsedMs,
                tokenUsage: response.usage
            )
            if mode == .taskAdviceOverall {
                usageGate.incrementDailyKeyedFeature(key: "todo_overall_advice")
            } else {
                usageGate.incrementUsage(for: mode)
            }
            ContextMetrics.shared.logRequestEnd(
                id: reqId, model: model.rawValue, mode: mode.rawValue, success: true,
                duration: Date().timeIntervalSince(overallStart))
            #if DEBUG
                perf.end("svc:internal:done")
            #endif
            return response
        } catch {
            // Call logging failure
            let elapsedMs = Int(Date().timeIntervalSince(overallStart) * 1000)
            let aiError = (error as? AIServiceError) ?? AIServiceError.unknown(error)
            AICallLogger.shared.logAICallFailure(
                callId: reqId,
                mode: mode,
                model: model,
                error: aiError,
                processingTime: elapsedMs
            )
            ContextMetrics.shared.logRequestEnd(
                id: reqId, model: model.rawValue, mode: mode.rawValue, success: false,
                duration: Date().timeIntervalSince(overallStart))
            throw error
        }
    }

    // Backward-compatible overload to satisfy UnifiedAIService protocol
    public func sendMessage(
        content: String,
        model: AIModel,
        mode: AIMode,
        context: AIContext?,
        tokenConfig: TokenConfiguration?,
        assembledPrompt: String?
    ) async throws -> AIResponse {
        return try await sendMessage(
            content: content,
            model: model,
            mode: mode,
            context: context,
            tokenConfig: tokenConfig,
            assembledPrompt: assembledPrompt,
            policyMeta: nil
        )
    }

    /// 내부 메시지 전송 로직 (보안 검증 후)
    private func sendMessageInternal(
        _ content: String,
        _ model: AIModel,
        _ mode: AIMode,
        _ context: AIContext?,
        _ tokenConfig: TokenConfiguration?,
        _ assembledPrompt: String?,
        _ policyMeta: [String: String]?
    ) async throws -> AIResponse {

        let startTime = Date()

        // 🛰️ 프록시 모드 절대 우선: 어떤 로컬 라우팅/폴백보다 먼저 서버 프록시로 보낸다.
        if EnvironmentConfig.shared.useProxy {
            do {
                let proxyURL = try resolveProxyBaseURL()
                // 모드별 최적 모델을 우선 적용(사용자 선호를 존중하되, 특정 모드는 정책상 고정)
                let preferredForMode = getOptimalModelForMode(mode: mode, userPreferred: model)
                var roleMessages: [RoleMessage] = []
                if let assembled = assembledPrompt, !assembled.isEmpty {
                    // assembledPrompt가 시스템 프롬프트(안정 프리픽스) 전체를 포함하므로
                    // 별도 히스토리를 중복 추가하지 않는다. 변동 정보는 아래에서 요약(user)과 현재 입력(user)로 전달.
                    roleMessages.append(RoleMessage(role: .system, content: assembled))
                    // 최근 대화 요약을 변동 정보로 user 메시지로 추가(캐시 키 오염 방지)
                    if let history = context?.conversationHistory, !history.isEmpty {
                        let lite = history.map {
                            ChatMessageLite(
                                role: $0.role.rawValue, content: $0.content, createdAt: $0.timestamp
                            )
                        }
                        // 남은 예산 기반 목표 토큰 산정
                        let optimizer = TokenOptimizer.shared
                        let sysT = optimizer.estimateTokens(for: assembled)
                        let userT = optimizer.estimateTokens(for: content)
                        let recentTail = Array(history.suffix(6))
                        let recentTokens = recentTail.reduce(0) {
                            $0 + optimizer.estimateTokens(for: $1.content)
                        }
                        let effCfg = tokenConfig ?? mode.recommendedTokenConfig
                        let budget = effCfg.maxTokens
                        let remaining = max(100, budget - sysT - userT - recentTokens)
                        let targetSummaryTokens = max(80, min(280, Int(Double(remaining) * 0.25)))
                        let summary = AIContextBuilder.shared.summarizeRecentAdaptive(
                            lite, targetTokens: targetSummaryTokens, maxItemsLimit: 16)
                        if !summary.isEmpty {
                            roleMessages.append(RoleMessage(role: .user, content: summary))
                        }
                    }
                    // 현재 사용자 입력은 별도의 user 역할로 명확히 전달
                    roleMessages.append(RoleMessage(role: .user, content: content))
                } else {
                    let sys = generateOptimizedSystemPrompt(for: mode, model: preferredForMode)
                    roleMessages.append(RoleMessage(role: .system, content: sys))
                    // 최근 대화 요약을 먼저 user로 전달
                    if let history = context?.conversationHistory, !history.isEmpty {
                        let lite = history.map {
                            ChatMessageLite(
                                role: $0.role.rawValue, content: $0.content, createdAt: $0.timestamp
                            )
                        }
                        let optimizer = TokenOptimizer.shared
                        let sysT = optimizer.estimateTokens(for: sys)
                        let userT = optimizer.estimateTokens(for: content)
                        let recentTail = Array(history.suffix(6))
                        let recentTokens = recentTail.reduce(0) {
                            $0 + optimizer.estimateTokens(for: $1.content)
                        }
                        let effCfg = tokenConfig ?? mode.recommendedTokenConfig
                        let budget = effCfg.maxTokens
                        let remaining = max(100, budget - sysT - userT - recentTokens)
                        let targetSummaryTokens = max(80, min(280, Int(Double(remaining) * 0.25)))
                        let summary = AIContextBuilder.shared.summarizeRecentAdaptive(
                            lite, targetTokens: targetSummaryTokens, maxItemsLimit: 16)
                        if !summary.isEmpty {
                            roleMessages.append(RoleMessage(role: .user, content: summary))
                        }
                        // 최근 턴은 3+3 정책(사용자 3 + 어시스턴트 3)만 포함
                        let recent = Self.selectBalancedRecent(history, userMax: 3, assistantMax: 3)
                        for turn in recent {
                            roleMessages.append(
                                RoleMessage(
                                    role: turn.role, content: turn.content, ts: turn.timestamp))
                        }
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
                print(
                    "🧩 [AICallPrep] preferred=\(preferredForMode.rawValue) mode=\(mode.rawValue) assembledPrompt=\(usedAssembled) sysLen=\(sysLen) histTurns=\(histTurns) userLen=\(userLen) ctx=\(ctxSnap)"
                )
                // Effective token/generation config for proxy path
                let effTokenConfig = optimizeTokenConfigForModel(
                    tokenConfig ?? mode.recommendedTokenConfig, model: preferredForMode, mode: mode)
                let outgoingPolicy = policyMeta
                let personaCore = UserRulesManager.shared.personaCoreSignature()
                let rawResp = try await sendViaProxy(
                    messages: roleMessages, mode: mode, preferred: preferredForMode,
                    proxyURL: proxyURL, tokenConfig: effTokenConfig, policyMeta: outgoingPolicy,
                    personaCoreKey: personaCore)
                let nickname = UserSettingsModel.loadFromUserDefaults().nickname
                let (processedText, reason) =
                    AIResponsePostProcessor.stripRepetitiveGreetingIfNeeded(
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
                            print(
                                "🛟 [UnifiedAIService] Proxy 오류(\(statusCode)) → OpenRouter 안전 폴백 시도"
                            )
                            var messages: [OpenRouterFallbackManager.ORMessage] = []
                            if let assembled = assembledPrompt, !assembled.isEmpty {
                                messages.append(.init(role: "system", content: assembled))
                            } else {
                                messages.append(
                                    .init(
                                        role: "system",
                                        content: generateOptimizedSystemPrompt(
                                            for: mode, model: .freeModel)))
                                if let history = context?.conversationHistory, !history.isEmpty {
                                    let recent = Array(history.suffix(16))
                                    for turn in recent {
                                        messages.append(
                                            .init(role: turn.role.rawValue, content: turn.content))
                                    }
                                }
                            }
                            messages.append(.init(role: "user", content: content))
                            let responseText = try await freeService.sendMessageWithFallback(
                                messages: messages, mode: mode)
                            // New: fallback summary log (OpenRouter)
                            let durationMs = Int(Date().timeIntervalSince(startTime) * 1000)
                            print(
                                "🛟 [AIFallback] path=openrouter from=\(model.rawValue) mode=\(mode.rawValue) status=\(statusCode) durationMs=\(durationMs)"
                            )
                            let usage = TokenUsage(
                                promptTokens: 0, completionTokens: 0, totalTokens: 0,
                                estimatedCost: 0)
                            let meta = ResponseMetadata(
                                emotionAnalysis: nil, recommendations: nil, confidenceScore: 0.0,
                                additionalInfo: ["provider": "openrouter", "fallback": true])
                            return AIResponse(
                                id: UUID().uuidString, model: .freeModel, mode: mode,
                                content: responseText, metadata: meta, usage: usage,
                                timestamp: Date(),
                                processingTime: Int(Date().timeIntervalSince(startTime) * 1000))
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
                            let durationMs = Int(Date().timeIntervalSince(startTime) * 1000)
                            print(
                                "🛟 [AIFallback] path=direct from=\(model.rawValue) to=\(resp.model.rawValue) mode=\(mode.rawValue) status=\(statusCode) durationMs=\(durationMs)"
                            )
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

        print(
            "🚀 [UnifiedAIService] 메시지 전송 시작 - 모델: \(selectedModel.rawValue), 모드: \(mode.rawValue)")

        // 🎯 모드별 최적 모델 추천 (사용자 선택을 존중하되, 더 적합한 모델이 있으면 제안)
        let recommendedModel = getOptimalModelForMode(mode: mode, userPreferred: selectedModel)
        if recommendedModel != selectedModel {
            print(
                "💡 [UnifiedAIService] 모드 \(mode.rawValue)에는 \(recommendedModel.rawValue) 모델이 더 적합합니다."
            )
        }
        let finalModel = recommendedModel

        do {
            // 모델별 분기 처리
            let response = try await sendToSpecificModel(
                content: content,
                model: finalModel,
                mode: mode,
                context: context,
                tokenConfig: optimizeTokenConfigForModel(
                    tokenConfig ?? mode.recommendedTokenConfig, model: finalModel, mode: mode),
                assembledPrompt: assembledPrompt
            )

            // 출력 보안 검증
            let outputValidation = securityManager.validateOutput(
                response.content, originalInput: content)

            switch outputValidation {
            case .blocked(let reason):
                print("🚫 [UnifiedAIService] 출력이 차단됨: \(reason)")
                // fallback 시도
                return try await attemptFallback(
                    content, originalModel: finalModel, mode: mode, context: context,
                    tokenConfig: tokenConfig, assembledPrompt: assembledPrompt)

            case .approved:
                let processingTime = Date().timeIntervalSince(startTime)
                print("✅ [UnifiedAIService] 메시지 전송 완료 - 처리시간: \(Int(processingTime * 1000))ms")
                // Post-process to reduce repetitive greetings after the first assistant turn
                let nickname = UserSettingsModel.loadFromUserDefaults().nickname
                let (processedText, reason) =
                    AIResponsePostProcessor.stripRepetitiveGreetingIfNeeded(
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
                print(
                    "🎯 [AICallSummary] path=direct provider=\(finalModel.rawValue) mode=\(mode.rawValue) durationMs=\(Int(processingTime * 1000)) cacheProvider=- cacheAction=- fallback=false"
                )
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
            return try await attemptFallback(
                content, originalModel: finalModel, mode: mode, context: context,
                tokenConfig: tokenConfig, assembledPrompt: assembledPrompt)
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
                    for turn in recent {
                        roleMessages.append(
                            RoleMessage(role: turn.role, content: turn.content, ts: turn.timestamp))
                    }
                }
                roleMessages.append(RoleMessage(role: .user, content: content))
            }
            // Compute effective token config for proxy
            let effTokenConfig = optimizeTokenConfigForModel(tokenConfig, model: model, mode: mode)
            // Call proxy inline (avoid project membership issues)
            return try await sendViaProxy(
                messages: roleMessages, mode: mode, preferred: model, proxyURL: proxyURL,
                tokenConfig: effTokenConfig, policyMeta: nil,
                personaCoreKey: UserRulesManager.shared.personaCoreSignature())
        }

        // 📉 Claude 일일 요청 상한 체크(유료도 상한 적용)
        if model == .claude {
            let (canUseClaude, _, _) = claudeUsageStatus()
            if !canUseClaude {
                // Claude 상한 초과 → Gemini 우선 폴백
                let fallbackModel: AIModel =
                    availableModels.contains(.gemini)
                    ? .gemini : (fallbackOrder.first { $0 != .claude } ?? .freeModel)
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
            // 최근 대화 요약을 user 메시지로 먼저 전달 (캐시 프리픽스와 분리)
            let lite = history.map {
                ChatMessageLite(
                    role: $0.role.rawValue, content: $0.content, createdAt: $0.timestamp)
            }
            let optimizer = TokenOptimizer.shared
            let sysT = optimizer.estimateTokens(for: systemPrompt)
            let userT = optimizer.estimateTokens(for: content)
            let recentTail = Array(history.suffix(6))
            let recentTokens = recentTail.reduce(0) {
                $0 + optimizer.estimateTokens(for: $1.content)
            }
            let effCfg = tokenConfig ?? mode.recommendedTokenConfig
            let budget = effCfg.maxTokens
            let remaining = max(100, budget - sysT - userT - recentTokens)
            let targetSummaryTokens = max(80, min(280, Int(Double(remaining) * 0.25)))
            let summary = AIContextBuilder.shared.summarizeRecentAdaptive(
                lite, targetTokens: targetSummaryTokens, maxItemsLimit: 16)
            if !summary.isEmpty {
                roleMessages.append(RoleMessage(role: .user, content: summary))
            }
            // 최근 턴은 3+3 정책(사용자 3 + 어시스턴트 3)만 포함
            let recent = Self.selectBalancedRecent(history, userMax: 3, assistantMax: 3)
            for turn in recent {
                roleMessages.append(
                    RoleMessage(role: turn.role, content: turn.content, ts: turn.timestamp))
            }
        }
        roleMessages.append(RoleMessage(role: .user, content: content))

        switch model {
        case .claude:
            guard let service = claudeService else {
                throw AIServiceError.modelUnavailable(model: model)
            }
            let result = try await service.sendMessages(
                messages: roleMessages, mode: mode, tokenConfig: tokenConfig)
            incrementClaudeUsage()
            return result

        case .openAI:
            guard let service = openAIService else {
                throw AIServiceError.modelUnavailable(model: model)
            }
            return try await service.sendMessages(
                messages: roleMessages, mode: mode, tokenConfig: tokenConfig)

        case .gemini:
            guard let service = geminiService else {
                throw AIServiceError.modelUnavailable(model: model)
            }
            return try await service.sendMessages(
                messages: roleMessages, mode: mode, tokenConfig: tokenConfig)

        case .naver:
            guard let service = naverService else {
                throw AIServiceError.modelUnavailable(model: model)
            }
            return try await service.sendMessages(
                messages: roleMessages, mode: mode, tokenConfig: tokenConfig)

        case .onDevice:
            return try await sendToOnDevice(
                messages: roleMessages, mode: mode, context: context, tokenConfig: tokenConfig)

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

            if assembledPrompt == nil, let history = context?.conversationHistory, !history.isEmpty
            {
                let recent = Array(history.suffix(16))  // 최근 16개만 포함
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
                    estimatedCost: 0.0  // 무료
                ),
                timestamp: Date(),
                processingTime: 0
            )
        }
    }

    private func sendToOnDevice(
        messages: [RoleMessage],
        mode: AIMode,
        context: AIContext?,
        tokenConfig: TokenConfiguration
    ) async throws -> AIResponse {
        // System prompt: 우선 messages의 첫 system, 없으면 통합 생성
        let sys: String = {
            if let first = messages.first, first.role == .system { return first.content }
            return generateOptimizedSystemPrompt(for: mode, model: .onDevice)
        }()
        // Latest user content
        guard let userText = messages.last?.content, !userText.isEmpty else {
            throw AIServiceError.invalidRequest(reason: "EMPTY_INPUT")
        }
        // 온디바이스 생성(스트리밍 수집)
        var buffer = ""
        let start = Date()
        do {
            let summary = try await OnDeviceAdapter.shared.generate(
                preferred: nil,
                text: userText,
                config: OnDeviceAdapter.StreamConfig(systemPrompt: sys, params: nil)
            ) { delta in
                buffer += delta
            }
            // 후처리(인사 제거)
            let nickname = UserSettingsModel.loadFromUserDefaults().nickname
            let (processedText, reason) = AIResponsePostProcessor.stripRepetitiveGreetingIfNeeded(
                response: buffer,
                history: context?.conversationHistory,
                nickname: nickname
            )
            var addInfo: [String: Any] = [
                "provider": "ondevice",
                "ondeviceModelID": summary.modelID.rawValue,
                "ttiMs": summary.ttiMilliseconds,
            ]
            if let r = reason {
                addInfo["greeting_stripped"] = true
                addInfo["greeting_stripped_reason"] = r
            } else {
                addInfo["greeting_stripped"] = false
            }
            let meta = ResponseMetadata(
                emotionAnalysis: nil,
                recommendations: nil,
                confidenceScore: 0.0,
                additionalInfo: addInfo
            )
            let usage = TokenUsage(
                promptTokens: 0, completionTokens: 0, totalTokens: 0, estimatedCost: 0)
            return AIResponse(
                id: UUID().uuidString,
                model: .onDevice,
                mode: mode,
                content: processedText,
                metadata: meta,
                usage: usage,
                timestamp: Date(),
                processingTime: Int(Date().timeIntervalSince(start) * 1000)
            )
        } catch let e as OnDeviceAdapter.AdapterError {
            // 정책적 폴백 신호면 상위로 전달
            switch e {
            case .cloudFallbackSuggested:
                throw AIServiceError.modelUnavailable(model: .onDevice)
            case .notAvailableForOS:
                throw AIServiceError.configurationError("ONDEVICE_UNAVAILABLE_OS")
            case .cancelled:
                throw AIServiceError.timeoutError
            case .underlying(let cause):
                throw AIServiceError.unknown(cause)
            case .noInstalledModel:
                throw AIServiceError.modelUnavailable(model: .onDevice)
            }
        } catch {
            throw AIServiceError.unknown(error)
        }
    }

    // MARK: - Claude 일일 상한 관리 (단일 진실원칙: 프록시 사용 시 로컬 상한 비활성화)
    private func claudeUsageStatus() -> (canUse: Bool, current: Int, limit: Int) {
        // 프록시 모드에서는 서버 정책 헤더(X-Policy-*)가 단일 진실원칙(SSOT)으로 작동하므로,
        // 로컬 상한 체크를 비활성화합니다.
        if EnvironmentConfig.shared.useProxy {
            return (true, 0, Int.max)
        }
        // 프록시 미사용(개발/offline)에서만 로컬 제한을 사용하며, 기본값은 0(무제한)으로 둡니다.
        let limit = 0
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
        print(
            "📋 [UnifiedAIService] Fallback 순서: \(availableFallbacks.map { $0.rawValue }.joined(separator: " → "))"
        )

        // 각 fallback 모델을 순서대로 시도
        for (index, fallbackModel) in availableFallbacks.enumerated() {
            ContextMetrics.shared.logFallbackTried(
                from: originalModel.rawValue, to: fallbackModel.rawValue)
            do {
                print(
                    "🔄 [UnifiedAIService] Fallback \(index + 1)/\(availableFallbacks.count): \(fallbackModel.rawValue) 시도"
                )

                let response = try await sendToSpecificModel(
                    content: content,
                    model: fallbackModel,
                    mode: mode,
                    context: context,
                    tokenConfig: tokenConfig ?? mode.recommendedTokenConfig,
                    assembledPrompt: assembledPrompt
                )

                // fallback 성공 알림 ([] 형식으로 구분)
                let fallbackNotice =
                    "\n\n[ℹ️ \(originalModel.displayName) 서버 오류로 인해 \(fallbackModel.displayName) 모델을 임시 사용했습니다]"

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

                print(
                    "✅ [UnifiedAIService] Fallback 성공: \(originalModel.rawValue) → \(fallbackModel.rawValue)"
                )
                return finalResponse

            } catch {
                print(
                    "❌ [UnifiedAIService] Fallback \(index + 1) 실패 (\(fallbackModel.rawValue)): \(error.localizedDescription)"
                )

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
            return .onDevice
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
            return .onDevice
        case .freeModel:
            return .freeModel
        case .testModel:
            return .freeModel  // testModel도 통합된 freeModel로 처리
        }
    }

    // MARK: - 강제 지정 모델 전송(퍼블릭)
    public func sendMessageForceProvider(
        content: String,
        model: AIModel,
        mode: AIMode,
        context: AIContext?,
        tokenConfig: TokenConfiguration?,
        assembledPrompt: String? = nil
    ) async throws -> AIResponse {
        // 지정 모델을 그대로 이용하여 프록시에 전달(또는 direct)하기 위해 내부 전용 경로 재사용
        return try await sendToSpecificModel(
            content: content,
            model: model,
            mode: mode,
            context: context,
            tokenConfig: optimizeTokenConfigForModel(
                tokenConfig ?? mode.recommendedTokenConfig, model: model, mode: mode),
            assembledPrompt: assembledPrompt
        )
    }

    // MARK: - 🌊 스트리밍 응답 (프록시 SSE 사용)

    public func sendMessageStream(
        content: String,
        model: AIModel,
        mode: AIMode,
        context: AIContext?,
        tokenConfig: TokenConfiguration?,
        assembledPrompt: String? = nil
    ) -> AsyncThrowingStream<AIStreamResponse, Error> {
        // 프록시 스트리밍 우선. 비활성 시 기존 단일 청크로 폴백
        guard EnvironmentConfig.shared.useProxy else {
            return AsyncThrowingStream { continuation in
                Task {
                    do {
                        let full = try await sendMessage(
                            content: content, model: model, mode: mode,
                            context: context, tokenConfig: tokenConfig,
                            assembledPrompt: assembledPrompt
                        )
                        continuation.yield(
                            AIStreamResponse(
                                id: full.id, delta: full.content, isComplete: true,
                                metadata: StreamMetadata(
                                    tokenCount: full.usage.totalTokens, timestamp: Date())
                            ))
                        continuation.finish()
                    } catch { continuation.finish(throwing: error) }
                }
            }
        }

        return AsyncThrowingStream { continuation in
            Task {
                do {
                    let proxyURL = try resolveProxyBaseURL()
                    print(
                        "🛰️ [UnifiedAIService] Proxy stream engaged → /v1/chat/stream (model=\(model.rawValue), mode=\(mode.rawValue))"
                    )
                    // 메시지 구성(프록시 경로와 동일 원칙)
                    var roleMessages: [RoleMessage] = []
                    if let assembled = assembledPrompt, !assembled.isEmpty {
                        roleMessages.append(RoleMessage(role: .system, content: assembled))
                    } else {
                        let sys = generateOptimizedSystemPrompt(for: mode, model: model)
                        roleMessages.append(RoleMessage(role: .system, content: sys))
                        if let history = context?.conversationHistory, !history.isEmpty {
                            let recent = Array(history.suffix(16))
                            for turn in recent {
                                roleMessages.append(
                                    RoleMessage(
                                        role: turn.role, content: turn.content, ts: turn.timestamp))
                            }
                        }
                    }
                    roleMessages.append(RoleMessage(role: .user, content: content))

                    // 바디 구성(프록시와 동일)
                    let preferred = getOptimalModelForMode(mode: mode, userPreferred: model)
                    let effCfg = optimizeTokenConfigForModel(
                        tokenConfig ?? mode.recommendedTokenConfig, model: preferred, mode: mode)
                    var body: [String: Any] = [
                        "model": preferred.rawValue,
                        "mode": mode.rawValue,
                        "messages": roleMessages.map {
                            [
                                "role": $0.role.rawValue,
                                "content": $0.content,
                            ]
                        },
                        "temperature": effCfg.temperature,
                        "maxTokens": effCfg.maxTokens,
                    ]
                    // providerCaching 힌트(서버 SSOT 기준 참고용)
                    body["providerCaching"] = [
                        "enable": true,
                        "strategy": "auto",
                        "ttlSeconds": providerCacheTTLSeconds(for: mode),
                        "cacheKey":
                            "\(UserRulesManager.shared.personaCoreSignature()):\(mode.rawValue)",
                    ]

                    // 공통 인증 헤더
                    let uid: String = await MainActor.run {
                        UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
                    }
                    let tier: String = {
                        switch StoreKitSubscriptionManager.shared.currentTier {
                        case .free: return "free"
                        case .pro: return "pro"
                        case .max: return "max"
                        }
                    }()
                    let proxyBase = proxyURL
                    // enroll/secret 확보
                    let effectiveSecret = try await ProxyAuthClient.loadSecretOrEnroll(
                        uid: uid, proxyBase: proxyBase)
                    // idempotency(간단): 마지막 user content 기반
                    let contentHash = SHA256.hash(data: Data(content.utf8)).compactMap {
                        String(format: "%02x", $0)
                    }.joined()
                    let idemKey = String(
                        SHA256.hash(data: Data((mode.rawValue + contentHash).utf8)).compactMap {
                            String(format: "%02x", $0)
                        }.joined().prefix(64))
                    // 추정 캐시 토큰(4자≈1토큰)
                    let estTokens: Int = (roleMessages.first?.content.count ?? 0) / 4

                    // 요청 생성
                    let ts = String(Int64(Date().timeIntervalSince1970 * 1000))
                    let signature = ProxyAuthSigner.hmacSHA256Hex(
                        message: ProxyAuthSigner.composeSigningMessage(
                            ts: ts, uid: uid, tier: tier, nonce: nil), secret: effectiveSecret)
                    var req = URLRequest(url: proxyBase.appendingPathComponent("v1/chat/stream"))
                    req.httpMethod = "POST"
                    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    req.setValue("text/event-stream", forHTTPHeaderField: "Accept")
                    req.setValue(ProxyAuthConfig.origin, forHTTPHeaderField: "Origin")
                    req.setValue(uid, forHTTPHeaderField: "X-Emozleep-UID")
                    req.setValue(tier, forHTTPHeaderField: "X-Emozleep-Tier")
                    req.setValue(ts, forHTTPHeaderField: "X-Emozleep-Timestamp")
                    req.setValue(idemKey, forHTTPHeaderField: "X-Idempotency-Key")
                    req.setValue(signature, forHTTPHeaderField: "X-Emozleep-Sig")
                    req.setValue(mode.rawValue, forHTTPHeaderField: "X-Emozleep-Mode")
                    if estTokens > 0 {
                        req.setValue(
                            String(estTokens), forHTTPHeaderField: "X-Estimated-Cacheable-Tokens")
                    }
                    req.setValue("bypass-if-small", forHTTPHeaderField: "X-Cache-Hint")
                    req.httpBody = try JSONSerialization.data(withJSONObject: body)

                    // 스트리밍 수신
                    let t0 = Date()
                    let (bytes, response) = try await URLSession.shared.bytes(for: req)
                    guard let http = response as? HTTPURLResponse,
                        (200...299).contains(http.statusCode)
                    else {
                        throw AIServiceError.serverError(
                            statusCode: (response as? HTTPURLResponse)?.statusCode ?? -1)
                    }
                    var aggregate = ""
                    var emittedFirst = false
                    for try await line in bytes.lines {
                        if line.hasPrefix(":") { continue }  // comment ping
                        // SSE 형식: data: <payload>
                        let payload =
                            line.hasPrefix("data:")
                            ? String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces) : line
                        guard !payload.isEmpty else { continue }
                        var delta = ""
                        // 1) JSON 시도: candidates.delta.parts[].text 또는 candidates.content.parts[].text
                        if payload.first == "{" {
                            struct Part: Decodable { let text: String? }
                            struct Content: Decodable { let parts: [Part]? }
                            struct Candidate: Decodable {
                                let content: Content?
                                let delta: Content?
                            }
                            struct Resp: Decodable { let candidates: [Candidate]? }
                            if let data = payload.data(using: .utf8),
                                let resp = try? JSONDecoder().decode(Resp.self, from: data),
                                let cand = resp.candidates?.first
                            {
                                if let d = cand.delta?.parts?.compactMap({ $0.text }).joined(),
                                    !d.isEmpty
                                {
                                    delta = d
                                } else if let c = cand.content?.parts?.compactMap({ $0.text })
                                    .joined(), !c.isEmpty
                                {
                                    delta = c
                                }
                            }
                        }
                        // 2) JSON 파싱 실패 또는 비 JSON: "text":"…" 정규식으로 추출(복수 매치 결합)
                        if delta.isEmpty {
                            let regex = try? NSRegularExpression(
                                pattern: "\\\"text\\\"\\s*:\\s*\\\"([\\s\\S]*?)\\\"", options: [])
                            if let re = regex {
                                let ns = payload as NSString
                                let matches = re.matches(
                                    in: payload, range: NSRange(location: 0, length: ns.length))
                                if !matches.isEmpty {
                                    delta = matches.map { ns.substring(with: $0.range(at: 1)) }
                                        .joined()
                                        .replacingOccurrences(of: "\\n", with: "\n")
                                        .replacingOccurrences(of: "\\\"", with: "\"")
                                }
                            }
                        }
                        // 3) 여전히 비어있으면 순수 텍스트로 취급(서버가 텍스트만 보낼 때)
                        if delta.isEmpty,
                            payload.first != "{" && payload.first != "[" && payload.first != "("
                        {
                            delta = payload
                        }
                        guard !delta.isEmpty else { continue }
                        aggregate += delta
                        if !emittedFirst {
                            let ms = Int(Date().timeIntervalSince(t0) * 1000)
                            print("⏱️ [UnifiedAIService] firstTokenMs=\(ms)")
                            emittedFirst = true
                        }
                        continuation.yield(
                            AIStreamResponse(
                                id: UUID().uuidString,
                                delta: delta,
                                isComplete: false,
                                metadata: StreamMetadata(tokenCount: 0, timestamp: Date())
                            ))
                    }
                    continuation.yield(
                        AIStreamResponse(
                            id: UUID().uuidString, delta: "", isComplete: true,
                            metadata: StreamMetadata(tokenCount: 0, timestamp: Date())))
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
            latency: 0.0,  // TODO: 실제 레이턴시 측정
            errorRate: 0.0,  // TODO: 실제 에러율 계산
            remainingQuota: nil,
            healthScore: isAvailable ? 1.0 : 0.0
        )
    }

    // MARK: - 🎯 누락된 핵심 함수들 구현

    /// 모드별 최적 AI 모델 추천
    private func getOptimalModelForMode(mode: AIMode, userPreferred: AIModel) -> AIModel {
        // 프리셋 추천은 항상 Gemini 고정(Strict JSON/스키마 강제 안정화 목적)
        if EnvironmentConfig.shared.useProxy {
            if mode == .presetRecommendation { return .gemini }
            return userPreferred
        }

        // 프록시 미사용 시: 로컬 가용성 기반으로 최적 모델 선택
        let optimalModelMapping: [AIMode: AIModel] = [
            .generalConversation: userPreferred,
            .emotionDiaryAnalysis: availableModels.contains(.gemini) ? .gemini : .freeModel,
            .taskAdvice: availableModels.contains(.openAI) ? .openAI : .freeModel,
            .presetRecommendation: availableModels.contains(.gemini)
                ? .gemini : (availableModels.contains(.openAI) ? .openAI : .freeModel),
            .monthlyStatistics: availableModels.contains(.gemini) ? .gemini : .freeModel,
            .fortuneTelling: availableModels.contains(.naver) ? .naver : .freeModel,
            .emotionAnalysis: availableModels.contains(.openAI) ? .openAI : .freeModel,
        ]

        if let optimalModel = optimalModelMapping[mode], availableModels.contains(optimalModel) {
            return optimalModel
        }
        if availableModels.contains(userPreferred) {
            return userPreferred
        }
        return fallbackOrder.first ?? .freeModel
    }

    // 중앙집중형 시스템 프롬프트 제공자(공개 래퍼)
    // - DRY: 시스템 프롬프트 생성은 이 경로만 사용하도록 통일
    // - 테스트/다른 모듈에서 호출할 수 있도록 공개 메서드 제공
    public func makeSystemPrompt(for mode: AIMode, model: AIModel) -> String {
        return generateOptimizedSystemPrompt(for: mode, model: model)
    }

    /// 모드와 모델에 맞는 시스템 프롬프트 생성
    private func generateOptimizedSystemPrompt(for mode: AIMode, model: AIModel) -> String {
        let basePromptText = getBaseSystemPromptForMode(mode)
        let generalGuidelines = """
            핵심 지침:
            - 당신은 역할은 우리 어플[리플릿(Leaflet)]의 대나무숲(채팅창) 친구임
            - 한국어로 사용자의 페르소나와 감정과 말투와 상황의 따라 유연하게 친근하고 친절하게 대답할 것
            - 시스템 텍스트를 그대로 복사/반영하지 말 것.
            - JSON이 요구되면 정확한 스키마만 출력, 아니면 명료한 텍스트로 답변.
            """
        // 사용자 프로필 컨텍스트(개인화) 주입: 캐시 키는 persona+memoryFP로 관리되므로 안전
        let userSettings = UserSettingsModel.loadFromUserDefaults()
        let userContext = userSettings.generateAIContext()

        // 🔄 리팩터: components 기반 캐시 키 사용 (memory 요약 비포함)
        let userSettingsForTones = UserSettingsModel.loadFromUserDefaults()
        let components = UserRulesManager.shared.personaSignatureComponents(
            currentMode: mode,
            model: model,
            conversationTones: userSettingsForTones.conversationTones
        )

        // 3시간 TTL 캐시 활용: 모델 불문 베이스 프롬프트만 캐시
        let basePrompt = contextManager.getSystemPrompt(
            components: (
                composite: components.composite,
                coreHash: components.coreHash,
                modeHash: components.modeHash,
                modelHash: components.modelHash,
                toneHash: components.toneHash
            )
        ) {
            var prompt = "\(basePromptText)\n\n\(generalGuidelines)"
            if !userContext.isEmpty {
                prompt += "\n\n사용자 컨텍스트:\n\(userContext)"
            }
            if mode == .presetRecommendation {
                // 프리셋: 모델이 자유롭게 조합/제목 생성하되, 토큰 최소화를 위해 카탈로그 전체를 실어 나르지 않음.
                // 대신 총 카테고리 수와 버전 개수만 제공 → 모델은 volumes(13), versions(13)로 출력.
                let catCount = SoundPresetCatalog.categoryCount
                let versionCounts: [Int] = (0..<catCount).map { idx in
                    SoundManager.shared.getSoundCatalog(at: idx)?.versions.count ?? 1
                }
                let countsStr = versionCounts.map { String($0) }.joined(separator: ",")
                prompt +=
                    "\n\n사운드 카탈로그 사양(토큰 절약형):\n- categoryCount=\(catCount)\n- versionCounts=[\(countsStr)] (각 카테고리별 버전 개수)\n\n요구사항(엄격):\n- 오직 JSON 1개만 출력. 추가 텍스트/코드펜스 금지.\n- 자유롭게 새로운 presetName을 생성(창의적/간결).\n- reason은 한국어 120자 이내.\n- volumes: 길이 \(catCount), 0..100 정수(또는 0..100 소수).\n- versions: 길이 \(catCount), 각 항목은 0..versionCounts[i]-1 정수.\n- confidence: 0..1.\n- items는 생략(선택). volumes+versions가 있으면 items는 없어야 함.\n- 모델이 자체 지식과 사용자 컨텍스트를 바탕으로 조합/균형/타이틀을 결정. 내부 카탈로그 이름 목록에 제한되지 않음."
            }
            return prompt
        }
        /// 모델별 특화 최적화 지침은 런타임에 덧붙임 (캐시 키에 포함되지 않음)
        let modelSpecific = getModelSpecificOptimization(for: model)
        // 일반 대화 모드에서는 토큰 상한 내 완결 지시를 명시적으로 추가하여 모델이 스스로 마무리하도록 유도
        let lengthRule: String = {
            if mode == .generalConversation {
                let cap =
                    ConfigReader.int("AI_GENERAL_CONVERSATION_MAX_TOKENS", default: 256) ?? 256
                return
                    "\n\n응답 길이 규칙: 반드시 최대 \(cap) 토큰 이내에서 완결된 답변을 제공하세요. 핵심 위주로 1~2단락, 중복/장황함 금지, 마지막에 한 줄 요약을 포함하세요."
            } else {
                return ""
            }
        }()
        return basePrompt + lengthRule + "\n\n" + modelSpecific
    }

    // MARK: - Strict JSON Schema Builders
    private static func buildPresetRecommendationSchema() -> [String: Any] {
        // JSON Schema enforcing either volumes[0..100] (1..13 items) or items[{soundName, versionName?, volume(0..100)}]
        // Keep lenient but precise enough to guide providers; server maps to provider-specific strict JSON.
        return [
            "$schema": "https://json-schema.org/draft/2020-12/schema",
            "type": "object",
            "additionalProperties": false,
            "properties": [
                "presetName": ["type": "string", "minLength": 1],
                "reason": ["type": "string", "minLength": 1, "maxLength": 200],
                "confidence": ["type": "number", "minimum": 0, "maximum": 1],
                "volumes": [
                    "type": "array",
                    "minItems": 1,
                    "maxItems": 13,
                    "items": ["type": "number", "minimum": 0, "maximum": 100],
                ],
                "versions": [
                    "type": "array",
                    "minItems": 1,
                    "maxItems": 13,
                    "items": ["type": "integer", "minimum": 0],
                ],
                "items": [
                    "type": "array",
                    "minItems": 1,
                    "maxItems": 13,
                    "items": [
                        "type": "object",
                        "additionalProperties": false,
                        "properties": [
                            "soundName": ["type": "string", "minLength": 1],
                            "versionName": ["type": "string"],
                            "volume": ["type": "number", "minimum": 0, "maximum": 100],
                        ],
                        "required": ["soundName", "volume"],
                    ],
                ],
            ],
            "required": ["reason"],
            "anyOf": [
                ["required": ["volumes", "versions"]],
                ["required": ["items"]],
            ],
        ]
    }

    /// 모드별 기본 시스템 프롬프트
    private func getBaseSystemPromptForMode(_ mode: AIMode) -> String {
        switch mode {
        case .generalConversation:
            return ""

        case .emotionDiaryAnalysis:
            return """
                일기 기반 위로/격려/칭찬/공감대화를 진행하세요 유연하게 응대하세요.
                """

        case .taskAdvice, .taskAdviceOverall:
            return """
                실행 코치.
                - 목표/제약 파악 → 3단계 실행 계획
                - 30–60분 타임박스와 우선순위 제안
                - 바로 시작할 1가지 첫 행동 제시
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
            // 시간대 기반 Top-5 후보(토큰 최소화)
            let hour = Calendar.current.component(.hour, from: Date())
            let timeLabel: String = {
                switch hour {
                case 5..<9: return "아침"
                case 9..<12: return "오전"
                case 12..<18: return "오후"
                case 18..<22: return "저녁"
                default: return "밤"
                }
            }()
            var candidates: [String] = []
            for (name, details) in SoundPresetCatalog.supplementalSoundDetails {
                if let times = details["timeOfDay"] as? [String],
                    times.contains(where: { $0 == timeLabel || $0 == "모든 시간" })
                {
                    let opt = (details["optimalIntensity"] as? Int) ?? 30
                    candidates.append("\(name)(opt=\(opt))")
                }
                if candidates.count >= 5 { break }
            }
            let candidateLine =
                candidates.isEmpty ? "" : "\n[시간대 후보 Top-5] " + candidates.joined(separator: ", ")
            return """
                사운드 큐레이터.
                - 오직 JSON 객체 1개만 출력(추가 텍스트/코드펜스/주석 금지)
                - items: 1–13개, volume: 0–100 정수
                - soundName: 카탈로그 이름, versionName: 해당 사운드의 버전
                - reason: 120자 이내 한국어
                [앱 사운드 카탈로그 요약]
                \(catalogSummary)\(candidateLine)
                """

        case .monthlyStatistics:
            return """
                데이터 분석가.
                - 지난달 패턴 3개 요약(간단 근거)
                - 개선점 2개와 긍정 변화 1개
                - 다음 달 목표 2개 + 실행 팁
                """

        case .fortuneTelling:
            return """
                따뜻한 운세 상담.
                - 희망적 메시지, 미신보다 삶의 지혜 중심
                - 선택과 노력의 중요성 강조
                - 가벼운 재미 요소 1줄 포함
                """

        case .emotionAnalysis:
            return """
                감정 분석(JSON).
                - 주요 감정, 강도(0–1), 보조 감정 배열
                - 근거 문장 인용 최대 2개
                - 오직 JSON만 출력
                """
        }
    }

    /// 모델별 특화 최적화 지침
    private func getModelSpecificOptimization(for model: AIModel) -> String {
        switch model {
        case .claude:
            return """
                맥락 깊이+우아함, 그러나 간결·명료.
                """

        case .openAI:
            return """
                구조화·단계적 사고, JSON 스키마 엄수.
                """

        case .gemini:
            return """
                맥락 깊이+우아함, 그러나 간결·명료.
                """

        case .naver:
            return """
                한국 문화·정서 반영, 정중한 존댓말.
                """
        case .freeModel:
            return """
                간결·정확, JSON 스키마 준수.
                """
        case .onDevice:
            return """
                간결·정확, 로컬 모델 특성 고려.
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
                let claudeLimit = ConfigReader.int("AI_CLAUDE_MAX_TOKENS_LIMIT")
            {
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
                let tempMax = ConfigReader.double("AI_FREE_MODEL_TEMPERATURE_MAX")
            {
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
        case .onDevice:
            // 온디바이스는 리소스 보수적 설정
            var onDev = config
            if let onDeviceLimit = ConfigReader.int("AI_ONDEVICE_MAX_TOKENS_LIMIT") {
                onDev = TokenConfiguration(
                    maxTokens: min(onDev.maxTokens, onDeviceLimit),
                    temperature: onDev.temperature,
                    topP: onDev.topP,
                    frequencyPenalty: onDev.frequencyPenalty,
                    presencePenalty: onDev.presencePenalty,
                    responseFormat: onDev.responseFormat
                )
            }
            optimizedConfig = onDev
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
                let creativeTempMax = ConfigReader.double("AI_CREATIVE_MODE_TEMPERATURE_MAX")
            {
                optimizedConfig = TokenConfiguration(
                    maxTokens: optimizedConfig.maxTokens,
                    temperature: min(
                        optimizedConfig.temperature + creativeTempBonus, creativeTempMax),
                    topP: optimizedConfig.topP,
                    frequencyPenalty: optimizedConfig.frequencyPenalty,
                    presencePenalty: optimizedConfig.presencePenalty,
                    responseFormat: optimizedConfig.responseFormat
                )
            }

        default:
            break
        }

        // 사용자 페르소나 기반 미세 튜닝(친구 말투/MBTI)
        optimizedConfig = applyUserPersonaTuning(optimizedConfig, mode: mode)
        // JSON 모드는 다시 한 번 상한 캡(보수적)
        if optimizedConfig.responseFormat == .json,
            let jsonTempMax = ConfigReader.double("AI_JSON_MODE_TEMPERATURE_MAX")
        {
            optimizedConfig = TokenConfiguration(
                maxTokens: optimizedConfig.maxTokens,
                temperature: min(optimizedConfig.temperature, jsonTempMax),
                topP: optimizedConfig.topP,
                frequencyPenalty: optimizedConfig.frequencyPenalty,
                presencePenalty: optimizedConfig.presencePenalty,
                responseFormat: optimizedConfig.responseFormat
            )
        }
        // 최종 하드 캡: 일반 대화는 반드시 SSOT 상한을 준수(기본 256)
        if mode == .generalConversation {
            let hardCap =
                ConfigReader.int("AI_GENERAL_CONVERSATION_MAX_TOKENS", default: 256) ?? 256
            if optimizedConfig.maxTokens > hardCap {
                optimizedConfig = TokenConfiguration(
                    maxTokens: hardCap,
                    temperature: optimizedConfig.temperature,
                    topP: optimizedConfig.topP,
                    frequencyPenalty: optimizedConfig.frequencyPenalty,
                    presencePenalty: optimizedConfig.presencePenalty,
                    responseFormat: optimizedConfig.responseFormat
                )
            }
        }
        return optimizedConfig
    }

    /// 사용자 말투/MBTI에 따른 경량 튜닝(온도/탑P). 서버/모드/모델 정책을 침범하지 않도록 ±0.15 내에서만 조정.
    private func applyUserPersonaTuning(_ base: TokenConfiguration, mode: AIMode)
        -> TokenConfiguration
    {
        var tDelta: Double = 0.0
        var topP: Double? = base.topP

        let settings = UserSettingsModel.loadFromUserDefaults()
        // 톤 프리셋 영향(가중치 합산, 클램프)
        for p in settings.preferredFriendTones {
            switch p {
            case .friendly, .supportive, .coaching: tDelta += 0.03
            case .professional, .concise, .analytical: tDelta -= 0.05
            case .calm: tDelta -= 0.03
            case .playful, .humorous:
                tDelta += 0.05
                topP = max(topP ?? 0.9, 0.9)
            }
        }
        // MBTI 영향(선택된 축만 반영)
        let mbti = settings.mbti
        switch mbti.ie {
        case .i: tDelta -= 0.05
        case .e: tDelta += 0.05
        default: break
        }
        switch mbti.ns {
        case .n:
            tDelta += 0.03
            topP = max(topP ?? 0.9, 0.9)
        case .s:
            tDelta -= 0.03
            topP = min(topP ?? 0.8, 0.8)
        default: break
        }
        switch mbti.tf {
        case .t: tDelta -= 0.04
        case .f: tDelta += 0.04
        default: break
        }
        switch mbti.pj {
        case .p: tDelta += 0.03
        case .j: tDelta -= 0.03
        default: break
        }

        // 모드별 상한/하한 보호(일반 대화는 창의성 허용, JSON 모드는 별도 캡 적용 예정)
        let tempBase = base.temperature
        let clampedTemp = max(0.1, min(1.0, tempBase + max(-0.15, min(0.15, tDelta))))
        return TokenConfiguration(
            maxTokens: base.maxTokens,
            temperature: clampedTemp,
            topP: topP ?? base.topP,
            frequencyPenalty: base.frequencyPenalty,
            presencePenalty: base.presencePenalty,
            responseFormat: base.responseFormat
        )
    }

    #if DEBUG
        /// 테스트 전용 헬퍼: 사용자 페르소나 튜닝 결과 노출(네트워크 호출 없이 검증용)
        internal func _testApplyUserPersonaTuning(_ base: TokenConfiguration, mode: AIMode)
            -> TokenConfiguration
        {
            return applyUserPersonaTuning(base, mode: mode)
        }
    #endif

    /// DEBUG 전용: 로컬 직접 서비스 사용 가능 여부
    private func hasAnyDirectServiceAvailable() -> Bool {
        return claudeService != nil || openAIService != nil || geminiService != nil
            || naverService != nil
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
                roleMessages.append(
                    RoleMessage(role: turn.role, content: turn.content, ts: turn.timestamp))
            }
        }
        roleMessages.append(RoleMessage(role: .user, content: content))
        // 모델별 직접 호출
        let tokenCfg = optimizeTokenConfigForModel(
            mode.recommendedTokenConfig, model: model, mode: mode)
        let response: AIResponse
        switch model {
        case .claude:
            guard let service = claudeService else {
                throw AIServiceError.modelUnavailable(model: .claude)
            }
            response = try await service.sendMessages(
                messages: roleMessages, mode: mode, tokenConfig: tokenCfg)
        case .openAI:
            guard let service = openAIService else {
                throw AIServiceError.modelUnavailable(model: .openAI)
            }
            response = try await service.sendMessages(
                messages: roleMessages, mode: mode, tokenConfig: tokenCfg)
        case .gemini:
            guard let service = geminiService else {
                throw AIServiceError.modelUnavailable(model: .gemini)
            }
            response = try await service.sendMessages(
                messages: roleMessages, mode: mode, tokenConfig: tokenCfg)
        case .naver:
            guard let service = naverService else {
                throw AIServiceError.modelUnavailable(model: .naver)
            }
            response = try await service.sendMessages(
                messages: roleMessages, mode: mode, tokenConfig: tokenCfg)
        case .onDevice:
            return try await sendToOnDevice(
                messages: roleMessages, mode: mode, context: context, tokenConfig: tokenCfg)
        case .freeModel:
            // freeModelService가 없으므로, 차선인 Gemini/OpenAI/Claude/Naver 순으로 선택
            if let svc = geminiService {
                return try await svc.sendMessages(
                    messages: roleMessages, mode: mode, tokenConfig: tokenCfg)
            } else if let svc = openAIService {
                return try await svc.sendMessages(
                    messages: roleMessages, mode: mode, tokenConfig: tokenCfg)
            } else if let svc = claudeService {
                return try await svc.sendMessages(
                    messages: roleMessages, mode: mode, tokenConfig: tokenCfg)
            } else if let svc = naverService {
                return try await svc.sendMessages(
                    messages: roleMessages, mode: mode, tokenConfig: tokenCfg)
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
        if let r = reason {
            print("✂️ [UnifiedAIService] Direct fallback: leading greeting stripped (\(r))")
        }
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
        let raw = EnvironmentConfig.shared.proxyBaseURL.trimmingCharacters(
            in: .whitespacesAndNewlines)
        guard !raw.isEmpty else {
            throw AIServiceError.configurationError("PROXY_BASE_URL_INVALID")
        }
        let normalized: String = {
            if raw.lowercased().hasPrefix("http://") || raw.lowercased().hasPrefix("https://") {
                return raw
            }
            return "https://" + raw
        }()
        guard let url = URL(string: normalized),
            let scheme = url.scheme?.lowercased(), scheme == "https" || scheme == "http",
            let host = url.host, !host.isEmpty
        else {
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

    private func sendViaProxy(
        messages: [RoleMessage], mode: AIMode, preferred: AIModel, proxyURL: URL,
        tokenConfig: TokenConfiguration, policyMeta: [String: String]?,
        personaCoreKey: String
    ) async throws -> AIResponse {
        #if DEBUG
            let perf = PerfTrace(flow: "ProxyCall")
            perf.with(extra: "provider", preferred.rawValue)
                .with(extra: "mode", mode.rawValue)
                .with(extra: "sysLen", String(messages.first?.content.count ?? 0))
                .with(extra: "userLen", String(messages.last?.content.count ?? 0))
            perf.mark("build:req")
        #endif
        var body: [String: Any] = [
            "model": mapPreferredModelForProxy(preferred),
            "messages": messages.map { ["role": $0.role.rawValue, "content": $0.content] },
            "mode": mode.rawValue,
        ]
        if let pm = policyMeta, !pm.isEmpty { body["policy"] = pm }
        // Generation parameters (optionally used by the proxy)
        body["temperature"] = tokenConfig.temperature
        body["maxTokens"] = tokenConfig.maxTokens
        if let v = tokenConfig.topP { body["topP"] = v }
        if let v = tokenConfig.frequencyPenalty { body["frequencyPenalty"] = v }
        if let v = tokenConfig.presencePenalty { body["presencePenalty"] = v }
        if let rf = tokenConfig.responseFormat { body["responseFormat"] = rf.rawValue }

        // Strict JSON for preset recommendation: enforce MIME + schema to maximize parse success and minimize retries
        if mode == .presetRecommendation {
            body["responseMimeType"] = "application/json"
            body["responseSchema"] = Self.buildPresetRecommendationSchema()
        }

        // 서버 공급자 캐싱 활성화
        // 주의: 캐시 키를 클라이언트에서 강제 지정하지 않는다.
        //       서버가 system 텍스트와 모델을 해시하여 모드별/프롬프트별로 안전하게 분리된 캐시를 생성한다.
        // 클라이언트 측 지난 7일 사용량 기반 동적 임계 힌트 계산
        let clientAssistant7d = SessionManager.shared.countAssistantMessages(lastNDays: 7)
        let clientMinOverride: Int? = {
            // 근사 맵핑: 사용량이 많을수록 캐시 생성 임계를 낮춰 재사용 기대를 반영
            if clientAssistant7d >= 100 { return 512 }
            if clientAssistant7d >= 50 { return 640 }
            if clientAssistant7d >= 20 { return 768 }
            return nil
        }()
        var providerCaching: [String: Any] = [
            "enable": true,
            "strategy": "auto",
            "ttlSeconds": providerCacheTTLSeconds(for: mode),
            // SSOT: 서버 캐시 키 힌트(안정키). 모드 차원을 포함하여 캐시 오염 방지.
            "cacheKey": "\(personaCoreKey):\(mode.rawValue)",
        ]
        if let override = clientMinOverride {
            providerCaching["clientMinTokensOverride"] = override
        }
        body["providerCaching"] = providerCaching
        // New: providerCaching config log
        if let ov = clientMinOverride {
            print(
                "🧱 [ProviderCaching] enable=true strategy=auto ttlSeconds=\(providerCacheTTLSeconds(for: mode)) clientMinTokensOverride=\(ov) (7d assistant msgs=\(clientAssistant7d))"
            )
        } else {
            print(
                "🧱 [ProviderCaching] enable=true strategy=auto ttlSeconds=\(providerCacheTTLSeconds(for: mode)) clientMinTokensOverride=nil (7d assistant msgs=\(clientAssistant7d))"
            )
        }
        // 서버 캐시 무효화 이벤트가 보류되어 있으면 1회성으로 헤더 전송
        let contextInvalidation = AIContextManager.shared.consumeInvalidationReasonForHeader()

        // Compose client idempotency key (same scheme as sendMessage)
        let contentConcat = messages.last?.content ?? ""
        let contentHash = SHA256.hash(data: Data(contentConcat.utf8)).compactMap {
            String(format: "%02x", $0)
        }.joined()
        // Idempotency key: 64-char hex SHA256 of (mode + personaCore + SHA256(content))
        let personaKeyForIdem = personaCoreKey
        let baseForIdem = mode.rawValue + personaKeyForIdem + contentHash
        let idemKey = String(
            SHA256.hash(data: Data(baseForIdem.utf8)).compactMap { String(format: "%02x", $0) }
                .joined().prefix(64))

        // 서명/요청 생성: 서명에 사용한 ts/nonce와 헤더의 ts/nonce를 반드시 동일하게 유지
        // 추정 가능한 캐시 prefix 토큰(시스템/페르소나/불변 컨텍스트) — 간단 근사(4자≈1토큰)
        let estimatedCacheableTokens: Int = {
            if let first = (body["messages"] as? [[String: Any]])?.first,
                (first["role"] as? String)?.lowercased() == "system",
                let sys = first["content"] as? String
            {
                return max(0, sys.count / 4)
            }
            return 0
        }()
        func makeRequest(ts: String, nonce: String?, signature: String) throws -> URLRequest {
            var r = URLRequest(url: proxyURL.appendingPathComponent("v1/chat"))
            r.httpMethod = "POST"
            r.setValue("application/json", forHTTPHeaderField: "Content-Type")
            r.setValue(ProxyAuthConfig.origin, forHTTPHeaderField: "Origin")
            r.setValue(uid, forHTTPHeaderField: "X-Emozleep-UID")
            r.setValue(tier, forHTTPHeaderField: "X-Emozleep-Tier")
            r.setValue(ts, forHTTPHeaderField: "X-Emozleep-Timestamp")
            if let n = nonce { r.setValue(n, forHTTPHeaderField: "X-Emozleep-Nonce") }
            // Mode hint for server-side per-feature policy enforcement
            r.setValue(mode.rawValue, forHTTPHeaderField: "X-Emozleep-Mode")
            if let inv = contextInvalidation, !inv.isEmpty {
                r.setValue(inv, forHTTPHeaderField: "X-Context-Invalidation")
            }
            // Pass idempotency key for server-side dedup
            r.setValue(idemKey, forHTTPHeaderField: "X-Idempotency-Key")
            r.setValue(signature, forHTTPHeaderField: "X-Emozleep-Sig")
            // Provider cache 힌트(선택): 서버 SSOT 정책 하에서 참고용
            if estimatedCacheableTokens > 0 {
                r.setValue(
                    String(estimatedCacheableTokens),
                    forHTTPHeaderField: "X-Estimated-Cacheable-Tokens")
            }
            r.setValue("bypass-if-small", forHTTPHeaderField: "X-Cache-Hint")
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
        let uid: String = await MainActor.run {
            UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
        }
        let tier: String = {
            switch StoreKitSubscriptionManager.shared.currentTier {
            case .free: return "free"
            case .pro: return "pro"
            case .max: return "max"
            }
        }()

        // Device secret 확보: Keychain → 없으면 enroll 호출. DEBUG에서는 마지막 폴백 허용
        print("🔐 [UnifiedAIService] 프록시 인증 준비 - UID: \(uid), Tier: \(tier)")
        var effectiveSecret: String
        do {
            effectiveSecret = try await ProxyAuthClient.loadSecretOrEnroll(
                uid: uid, proxyBase: proxyURL)
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
            let curNonce =
                useNonce
                ? UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased() : nil
            let sigMessage = ProxyAuthSigner.composeSigningMessage(
                ts: curTs, uid: uid, tier: tier, nonce: curNonce)
            print("🔏 [UnifiedAIService] 서명 생성 - Message: \(sigMessage)")
            let signature = ProxyAuthSigner.hmacSHA256Hex(
                message: sigMessage, secret: effectiveSecret)
            let req = try makeRequest(ts: curTs, nonce: curNonce, signature: signature)
            print(
                "📤 [UnifiedAIService] 프록시 요청 전송(attempt=\(attempt+1)): \(proxyURL.absoluteString)/v1/chat"
            )
            let result = try await URLSession.shared.data(for: req)
            #if DEBUG
                perf.mark("net:await")
            #endif
            data = result.0
            if let r = result.1 as? HTTPURLResponse {
                http = r
            } else {
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
                ProxyAuthClient.invalidateMemoryCache(for: uid)
                effectiveSecret = try await ProxyAuthClient.loadSecretOrEnroll(
                    uid: uid, proxyBase: proxyURL)
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
        #if DEBUG
            perf.mark("parse:headers")
        #endif
        struct ProxyResp: Codable {
            let provider: String
            let content: String
        }
        let proxy = try JSONDecoder().decode(ProxyResp.self, from: data)
        #if DEBUG
            perf.mark("parse:body")
        #endif

        // 정책/프로바이더/캐시 헤더 파싱
        if let st = header(http, "Server-Timing") {
            print("⏱️ [Server-Timing] \(st)")
        }
        let polRemaining = header(http, "X-Policy-Remaining")
        let polResetAt = header(http, "X-Policy-ResetAt")
        let polTier = header(http, "X-Policy-Tier")
        let claudeLeft = header(http, "X-Policy-Claude-Remaining")
        let providerHdr = header(http, "X-Provider")
        let cacheProv = header(http, "X-Cache-Provider")
        let cacheAction = header(http, "X-Cache-Action")
        let cacheTTL = header(http, "X-Cache-TTL")
        let cacheTokens = header(http, "X-Cache-Tokens")
        let canaryHdr = header(http, "X-Canary")
        let idemStatus = header(http, "X-Idempotency-Status")

        #if DEBUG
            if !Self.hasLoggedCacheHeaderSample {
                print(
                    "🧪 [CacheHeaders] provider=\(cacheProv ?? "-") action=\(cacheAction ?? "-") ttl=\(cacheTTL ?? "-") tokens=\(cacheTokens ?? "-")"
                )
                Self.hasLoggedCacheHeaderSample = true
            }
        #endif

        // New: one-line call summary for proxy path
        let ms = Int(Date().timeIntervalSince(start) * 1000)
        let providerUsed = proxy.provider
        let preferredName = preferred.rawValue
        let cacheUsed = (cacheAction?.lowercased() == "read")
        let serverFallback = (providerHdr ?? providerUsed) != preferredName
        print(
            "🎯 [AICallSummary] path=proxy provider=\(providerUsed) xProvider=\(providerHdr ?? "-") preferred=\(preferredName) mode=\(mode.rawValue) durationMs=\(ms) cacheProvider=\(cacheProv ?? "-") cacheAction=\(cacheAction ?? "-") cacheUsed=\(cacheUsed) cacheTTL=\(cacheTTL ?? "-") tokens=\(cacheTokens ?? "-") canary=\(canaryHdr ?? "-") idempotency=\(idemStatus ?? "-") policyTier=\(polTier ?? "-") remaining=\(polRemaining ?? "-") resetAt=\(polResetAt ?? "-") fallback=\(serverFallback)"
        )
        if let xProv = providerHdr, xProv != providerUsed {
            print(
                "⚠️ [AICallSummary] provider header mismatch: body=\(providerUsed) header=\(xProv)")
        }
        #if DEBUG
            perf.end("done")
        #endif

        var addInfo: [String: Any] = ["provider": proxy.provider]
        if let r = polRemaining { addInfo["policyRemaining"] = r }
        if let r = polResetAt { addInfo["policyResetAt"] = r }
        if let r = polTier { addInfo["policyTier"] = r }
        if let r = claudeLeft { addInfo["claudeRemaining"] = r }
        if let r = providerHdr { addInfo["providerHeader"] = r }
        if let r = cacheProv { addInfo["cacheProvider"] = r }
        if let r = cacheAction { addInfo["cacheAction"] = r }
        if let r = cacheTTL { addInfo["cacheTTL"] = r }
        if let r = cacheTokens { addInfo["cacheTokens"] = r }
        if let r = canaryHdr { addInfo["canary"] = r }
        if let r = idemStatus { addInfo["idempotency"] = r }

        let usage = TokenUsage(
            promptTokens: 0, completionTokens: 0, totalTokens: 0, estimatedCost: 0)
        let meta = ResponseMetadata(
            emotionAnalysis: nil, recommendations: nil, confidenceScore: 0.0,
            additionalInfo: addInfo)
        return AIResponse(
            id: UUID().uuidString, model: preferred, mode: mode, content: proxy.content,
            metadata: meta, usage: usage, timestamp: Date(),
            processingTime: Int(Date().timeIntervalSince(start) * 1000))
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
    case .freeModel: return "openrouter"  // 통합 무료 모델은 서버에서 openrouter로 시작
    case .onDevice: return "ondevice"  // 참고: 프록시 경로에서는 사용되지 않음
    }
}

// MARK: - Recent turns selector (3+3 균형 선택)
extension UnifiedAIServiceImpl {
    /// 최근 대화에서 사용자/어시스턴트 균형을 맞춰 최대 개수만 선택
    /// - Parameters:
    ///   - history: 전체 대화(turn) 배열
    ///   - userMax: 사용자 턴 최대 개수
    ///   - assistantMax: 어시스턴트 턴 최대 개수
    /// - Returns: 시간순(오래된→최근) 정렬된 턴 배열
    static func selectBalancedRecent(
        _ history: [AIConversationTurn], userMax: Int, assistantMax: Int
    ) -> [AIConversationTurn] {
        guard !history.isEmpty else { return [] }
        var users: [AIConversationTurn] = []
        var assists: [AIConversationTurn] = []
        // 최신부터 스캔하며 역할별 상한까지 채움
        for t in history.reversed() {
            switch t.role {
            case .user:
                if users.count < userMax { users.append(t) }
            case .assistant:
                if assists.count < assistantMax { assists.append(t) }
            default:
                break
            }
            if users.count >= userMax && assists.count >= assistantMax { break }
        }
        // 합쳐서 시간순으로 재정렬
        return (users + assists).sorted { $0.timestamp < $1.timestamp }
    }
}
