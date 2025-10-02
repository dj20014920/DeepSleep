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
        models.append(.onDevice)
        return models
    }

    // MARK: - Public API (UnifiedAIService)

    public func sendMessage(
        content: String,
        model: AIModel,
        mode: AIMode,
        context: AIContext?,
        tokenConfig: TokenConfiguration?,
        assembledPrompt: String?
    ) async throws -> AIResponse {
        return try await sendMessageInternal(
            content, model, mode, context, tokenConfig, assembledPrompt
        )
    }

    public func sendMessageForceProvider(
        content: String,
        model: AIModel,
        mode: AIMode,
        context: AIContext?,
        tokenConfig: TokenConfiguration?,
        assembledPrompt: String?
    ) async throws -> AIResponse {
        // 지정된 모델을 그대로 사용하여 내부 코어로 위임
        return try await sendMessageInternal(
            content, model, mode, context, tokenConfig, assembledPrompt
        )
    }

    public func sendMessageStream(
        content: String,
        model: AIModel,
        mode: AIMode,
        context: AIContext?,
        tokenConfig: TokenConfiguration?,
        assembledPrompt: String?
    ) -> AsyncThrowingStream<AIStreamResponse, Error> {
        // AFM one-chunk branch (top-only). Keeps UI streaming contract but yields once.
        if model == .onDevice, SettingsManager.shared.selectedLLM == .apple,
            AppleFMAdapter.isAvailable
        {
            return AsyncThrowingStream { continuation in
                Task {
                    #if canImport(UIKit)
                    let bg = BackgroundTaskManager.shared.begin("ai.ondevice.afm.stream")
                    defer { BackgroundTaskManager.shared.end(bg) }
                    #endif
                    do {
                        let sys: String? = {
                            if let a = assembledPrompt, !a.isEmpty { return a }
                            return generateOptimizedSystemPrompt(for: mode, model: .onDevice)
                        }()
                        let t0 = Date()
                        if #available(iOS 26.0, *) {
                            let full = try await AppleFMAdapter.generateFull(
                                sys: sys, user: content)
                            let ms = Int(Date().timeIntervalSince(t0) * 1000)
                            let userSettingsForTones = UserSettingsModel.loadFromUserDefaults()
                            let comps = UserRulesManager.shared.personaSignatureComponents(
                                currentMode: mode,
                                model: .onDevice,
                                conversationTones: userSettingsForTones.conversationTones
                            )
                            let sysDigest = AppleFMSessionPool.digestSystemPrompt(sys)
                            print(
                                "🍎 Apple FM stream (one-chunk) durationMs=\(ms) key=\(comps.coreHash.prefix(8)):\(mode.rawValue):onDevice:\(comps.toneHash.prefix(8)):\(sysDigest.prefix(8)) poolEnabled=\(AppleFMSessionPool.isEnabled)"
                            )
                            // Sanitize + greeting trim
                            let nickname = UserSettingsModel.loadFromUserDefaults().nickname
                            let modelID = (OnDeviceAdapter.shared.activeModelID) ?? ModelCatalog.defaultModelID
                            let (sanitized, _) = AIResponsePostProcessor.sanitizeArtifacts(
                                full,
                                modelID: modelID
                            )
                            let (processed, _) =
                                AIResponsePostProcessor.stripRepetitiveGreetingIfNeeded(
                                    response: sanitized,
                                    history: context?.conversationHistory,
                                    nickname: nickname
                                )
                            continuation.yield(
                                AIStreamResponse(
                                    id: UUID().uuidString,
                                    delta: processed,
                                    isComplete: true,
                                    metadata: StreamMetadata(tokenCount: 0, timestamp: Date())
                                )
                            )
                            continuation.finish()
                        } else {
                            throw AppleFMError.notAvailable
                        }
                    } catch {
                        continuation.finish(throwing: error)
                    }
                }
            }
        }
        // Fallback: use non-stream path and yield once
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    let full = try await sendMessage(
                        content: content,
                        model: model,
                        mode: mode,
                        context: context,
                        tokenConfig: tokenConfig,
                        assembledPrompt: assembledPrompt
                    )
                    continuation.yield(
                        AIStreamResponse(
                            id: full.id,
                            delta: full.content,
                            isComplete: true,
                            metadata: StreamMetadata(
                                tokenCount: full.usage.totalTokens, timestamp: Date())
                        )
                    )
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - Internals

    private func sendMessageInternal(
        _ content: String,
        _ model: AIModel,
        _ mode: AIMode,
        _ context: AIContext?,
        _ tokenConfig: TokenConfiguration?,
        _ assembledPrompt: String?
    ) async throws -> AIResponse {
        // 📱 백그라운드 시간 확보 (iOS)
        #if canImport(UIKit)
        let bg = BackgroundTaskManager.shared.begin("ai.ondevice.generation")
        defer { BackgroundTaskManager.shared.end(bg) }
        #endif
        // System prompt assembly (SSOT)
        let systemPrompt: String = {
            if let a = assembledPrompt, !a.isEmpty { return a }
            return generateOptimizedSystemPrompt(for: mode, model: model)
        }()

        // 3+3 최근 대화 블록 구성 (역할별 상한 적용, 시간순 정렬)
        // NOTE: On-device(llama.cpp) 경로는 최근 3+3을 역할 메시지(recentMessages)로 전달하고,
        // 텍스트에는 포함하지 않는다. 아래 Recent 블록은 클라우드(프록시/직결) 경로에서만 사용한다.
        let recentBlock: String = {
            guard let history = context?.conversationHistory, !history.isEmpty else { return "" }
            let recent = Self.selectBalancedRecent(history, userMax: 3, assistantMax: 3)
            guard !recent.isEmpty else { return "" }
            let lines = recent.map { turn in
                let role =
                    (turn.role == .assistant)
                    ? "assistant" : (turn.role == .system ? "system" : "user")
                return "\(role): \(turn.content)"
            }
            return "### Recent\n" + lines.joined(separator: "\n")
        }()

        let contentWithRecent: String = {
            if model == .onDevice { return content }  // on-device는 user 텍스트만 전달
            if recentBlock.isEmpty { return "### User\n\(content)" }
            return recentBlock + "\n\n### User\n" + content
        }()

        // Token config optimization
        let effCfg = optimizeTokenConfigForModel(
            tokenConfig ?? mode.recommendedTokenConfig, model: model, mode: mode
        )

        // Routing
        // 전역 SSoT: 사용자가 선택한 모델을 최우선으로 사용 (모든 모드 공통)
        let effectiveModel = model
        if effectiveModel == .onDevice {
            // Prefer Apple FM when available (only when user explicitly selected Apple)
            if SettingsManager.shared.selectedLLM == .apple, AppleFMAdapter.isAvailable {
                let t0 = Date()
                if #available(iOS 26.0, *) {
                    // AFM에 'Recent+User'를 합친 본문을 전달해 맥락을 확실히 반영
                    let text = try await AppleFMAdapter.generateFull(
                        sys: systemPrompt, user: contentWithRecent)
                    let ms = Int(Date().timeIntervalSince(t0) * 1000)
                    let userSettingsForTones = UserSettingsModel.loadFromUserDefaults()
                    let comps = UserRulesManager.shared.personaSignatureComponents(
                        currentMode: mode,
                        model: .onDevice,
                        conversationTones: userSettingsForTones.conversationTones
                    )
                    let sysDigest = AppleFMSessionPool.digestSystemPrompt(systemPrompt)
                    print(
                        "🍎 Apple FM complete durationMs=\(ms) provider=applefm key=\(comps.coreHash.prefix(8)):\(mode.rawValue):onDevice:\(comps.toneHash.prefix(8)):\(sysDigest.prefix(8)) poolEnabled=\(AppleFMSessionPool.isEnabled)"
                    )
                    let nickname = UserSettingsModel.loadFromUserDefaults().nickname
                    let (sanitized, _) = AIResponsePostProcessor.sanitizeArtifacts(text)
                    let (processed, _) = AIResponsePostProcessor.stripRepetitiveGreetingIfNeeded(
                        response: sanitized,
                        history: context?.conversationHistory,
                        nickname: nickname
                    )
                    // Console log full model response (Apple FM)
                    print(
                        "📝 [AIResp] provider=applefm model=onDevice chars=\(processed.count)\n\(processed)"
                    )
                    let usage = TokenUsage(
                        promptTokens: 0, completionTokens: 0, totalTokens: 0, estimatedCost: 0)
                    let meta = ResponseMetadata(
                        emotionAnalysis: nil, recommendations: nil, confidenceScore: 0.0,
                        additionalInfo: ["provider": "applefm"]
                    )
                    return AIResponse(
                        id: UUID().uuidString, model: .onDevice, mode: mode, content: processed,
                        metadata: meta, usage: usage, timestamp: Date(),
                        processingTime: ms
                    )
                } else {
                    throw AppleFMError.notAvailable
                }
            }
            // llama.cpp on-device path (aggregate stream)
            var buffer = ""
            // 온디바이스 SSOT: recent(3+3)은 어댑터가 템플릿 직렬화/프리필. 여기서는 역할 메시지만 전달하고, 현재 user만 텍스트로 전달
            var roleMessages: [RoleMessage] = []
            if let history = context?.conversationHistory, !history.isEmpty {
                let recent = Self.selectBalancedRecent(history, userMax: 3, assistantMax: 3)
                for turn in recent {
                    roleMessages.append(
                        RoleMessage(role: turn.role, content: turn.content, ts: turn.timestamp)
                    )
                }
            }
            let summary = try await OnDeviceAdapter.shared.generate(
                preferred: preferredOnDeviceID(),
                text: content,
                config: OnDeviceAdapter.StreamConfig(
                    systemPrompt: systemPrompt,
                    params: nil,
                    recentMessages: roleMessages,
                    // 일반 대화 외 모드에서는 일반대화용 KV 캐시 복원을 비활성화하여 컨텍스트 오염 방지
                    disableKVCache: (mode != .generalConversation)
                )
            ) { delta in buffer += delta }
            let nickname = UserSettingsModel.loadFromUserDefaults().nickname
            let (sanitized, _) = AIResponsePostProcessor.sanitizeArtifacts(buffer)
            let (processed, _) = AIResponsePostProcessor.stripRepetitiveGreetingIfNeeded(
                response: sanitized,
                history: context?.conversationHistory,
                nickname: nickname
            )
            // Console log full model response (llama.cpp)
            print(
                "📝 [AIResp] provider=llama.cpp model=\(OnDeviceAdapter.shared.activeModelID?.rawValue ?? "unknown") ttiMs=\(summary.ttiMilliseconds) chars=\(processed.count)\n\(processed)"
            )
            let usage = TokenUsage(
                promptTokens: 0, completionTokens: 0, totalTokens: 0, estimatedCost: 0)
            let meta = ResponseMetadata(
                emotionAnalysis: nil, recommendations: nil, confidenceScore: 0.0,
                additionalInfo: ["provider": "llama.cpp", "ttiMs": summary.ttiMilliseconds]
            )
            return AIResponse(
                id: UUID().uuidString, model: .onDevice, mode: mode, content: processed,
                metadata: meta, usage: usage, timestamp: Date(),
                processingTime: summary.durationMs
            )
        }

        // Proxy path or direct provider services
        if EnvironmentConfig.shared.useProxy || freeModelService != nil
            || hasAnyDirectServiceAvailable()
        {
            do {
                if EnvironmentConfig.shared.useProxy {
                    let proxyURL = try resolveProxyBaseURL()
                    let personaCoreKey = UserRulesManager.shared.personaCoreSignature()
                    let resp = try await sendViaProxy(
                        messages: {
                            var roleMessages: [RoleMessage] = [
                                RoleMessage(role: .system, content: systemPrompt)
                            ]
                            if let history = context?.conversationHistory, !history.isEmpty {
                                let recent = Self.selectBalancedRecent(
                                    history, userMax: 3, assistantMax: 3)
                                for turn in recent {
                                    roleMessages.append(
                                        RoleMessage(
                                            role: turn.role, content: turn.content,
                                            ts: turn.timestamp))
                                }
                            }
                            roleMessages.append(RoleMessage(role: .user, content: content))
                            return roleMessages
                        }(),
                        mode: mode,
                        preferred: model,
                        proxyURL: proxyURL,
                        tokenConfig: effCfg,
                        policyMeta: nil,
                        personaCoreKey: personaCoreKey
                    )
                    // Post-process
                    let nickname = UserSettingsModel.loadFromUserDefaults().nickname
                    let (sanitized, _) = AIResponsePostProcessor.sanitizeArtifacts(resp.content)
                    let (processed, _) = AIResponsePostProcessor.stripRepetitiveGreetingIfNeeded(
                        response: sanitized,
                        history: context?.conversationHistory,
                        nickname: nickname
                    )
                    return AIResponse(
                        id: resp.id, model: resp.model, mode: resp.mode, content: processed,
                        metadata: resp.metadata, usage: resp.usage, timestamp: resp.timestamp,
                        processingTime: resp.processingTime
                    )
                } else {
                    // Direct local services fallback
                    return try await sendDirectBypassingProxy(
                        content: content,
                        preferredModel: model,
                        mode: mode,
                        context: context,
                        assembledPrompt: assembledPrompt
                    )
                }
            } catch {
                throw error
            }
        }

        throw AIServiceError.modelUnavailable(model: model)
    }

    // Context invalidation on model change
    private func handleModelChanged(notification: Notification) {
        AIContextManager.shared.clearCache(
            reason: .modelSelectionChanged,
            caller: "UnifiedAIServiceImpl"
        )
        // AFM 세션 풀도 전역 무효화 (모델 변경 시 기존 세션은 재사용 불가)
        Task {
            await AppleFMSessionPool.shared.invalidateAll(reason: "modelSelectionChanged")
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
    /// KISS/DRY: 모든 모드는 사용자가 설정한 모델을 그대로 사용합니다.
    /// - 단, 실제 가용성(설치/OS 제약) 문제는 하위 호출에서 에러로 처리됩니다.
    private func getOptimalModelForMode(mode: AIMode, userPreferred: AIModel) -> AIModel {
        return userPreferred
    }

    // 중앙집중형 시스템 프롬프트 제공자(공개 래퍼)
    // - DRY: 시스템 프롬프트 생성은 이 경로만 사용하도록 통일
    // - 테스트/다른 모듈에서 호출할 수 있도록 공개 메서드 제공
    public func makeSystemPrompt(for mode: AIMode, model: AIModel) -> String {
        return generateOptimizedSystemPrompt(for: mode, model: model)
    }

    // 온디바이스 선호 모델 선택(사용자 설정 우선 → 현재 활성 모델 폴백)
    private func preferredOnDeviceID() -> OnDeviceModelID? {
        return SettingsManager.shared.preferredOnDeviceModelID
            ?? OnDeviceAdapter.shared.activeModelID
    }

    /// 모드와 모델에 맞는 시스템 프롬프트 생성
    private func generateOptimizedSystemPrompt(for mode: AIMode, model: AIModel) -> String {
        let basePromptText = getBaseSystemPromptForMode(mode)
        let generalGuidelines = """
            핵심 지침:
            - 당신은 리플릿(Leaflet) 앱의 대나무숲 채팅창에서 사용자와 대화하는 AI 친구입니다
            - 사용자의 페르소나와 감정, 말투, 상황에 따라 유연하고 친근하며 친절하게 한국어로 대답하세요
            - 아래 '사용자 컨텍스트'의 정보는 대화 상대방인 사용자에 대한 정보이며, 당신 자신에 대한 정보가 아닙니다
            - 시스템 텍스트를 그대로 복사하거나 반영하지 마세요
            - JSON이 요구되면 정확한 스키마만 출력하고, 그렇지 않으면 명료한 텍스트로 답변하세요
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
                    "\n\n응답 길이 규칙: 반드시 최대 \(cap) 토큰 이내에서 완결된 답변을 제공하세요. 핵심 위주로 1~2단락, 중복/장황함 금지"
            } else {
                return ""
            }
        }()
        // 프리셋 추천: presetName/reason 강제 규칙 추가 (경량, 토큰 부담 없음)
        let presetRules: String = {
            guard mode == .presetRecommendation else { return "" }
            let catCount = SoundPresetCatalog.categoryCount
            // 단일 JSON 예시를 추가해 온디바이스 모델의 형식 준수율을 높임 (짧고 경량)
            let example =
                "\n예시(JSON 한 줄): {\"presetName\":\"달빛 호수 산책\",\"reason\":\"밤 시간대의 평온한 감정에 맞춰 파도와 잔잔한 바람을 중심으로 과자극을 줄였습니다.\",\"volumes\":[10,40,60,0,50,30,20,0,0,20,10,0,0]}"
            return
                "\n\n출력 형식(엄격):\n- 오직 JSON 하나만 출력(코드펜스/추가 텍스트 금지)\n- 필수 키: presetName(간결하고 시적인 한국어 제목), reason(한국어 80~150자: 감정·시간대·음원 궁합·사용자 취향 등 추론 근거)\n- volumes 또는 items 중 하나는 반드시 포함\n  • volumes: 길이 \(catCount), 각 0..100 정수\n  • items: 1..13개, 각 항목 {soundName, versionName?, volume(0..100)}\n- versions가 있으면 길이 \(catCount)이며 각 항목은 해당 카테고리 버전 인덱스 범위 내 정수\(example)"
        }()
        return basePrompt + lengthRule + "\n\n" + presetRules + "\n\n" + modelSpecific
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
                일기 기반 위주로 위로/격려/칭찬/공감대화를 진행하세요 유연하게 응대하세요.
                """

        case .taskAdvice, .taskAdviceOverall:
            return """
                실행 코치.
                - 목표/제약 파악 → 3단계 실행 계획
                - 30–60분 타임박스와 우선순위 제안
                - 바로 시작할 1가지 첫 행동 제시
                """

        case .presetRecommendation:
            // 사용 가능한 사운드/버전 목록 요약(간결) - 스레드 안전 캐시 사용
            let catalogSummary = SoundPresetCatalog.promptCatalogSummary
            return """
                사운드 큐레이터.
                - 오직 JSON 객체 1개만 출력(추가 텍스트/코드펜스/주석 금지)
                - items: 1–13개, volume: 0–100 정수
                - soundName: 카탈로그 이름, versionName: 해당 사운드의 버전
                - reason: 120자 이내 한국어
                [앱 사운드 카탈로그 요약]
                \(catalogSummary)
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
        // Gemma on-device는 별도 분기에서 system 내재화 처리됨. 여기서는 항상 user 추가.
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
            // Reuse the core on-device path with explicit assembled system prompt
            return try await sendMessageInternal(
                content,
                .onDevice,
                mode,
                context,
                tokenCfg,
                systemPrompt
            )
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
