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
    // 클라우드 서비스 제거(온디바이스 전용)

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

    // MARK: - 🔑 API 키 관리 (제거됨: 온디바이스만 사용)

    deinit {
        if let obs = modelChangedObserver {
            NotificationCenter.default.removeObserver(obs)
        }
    }

    // MARK: - 🔧 서비스 초기화

    private func initializeServices() {
        // 온디바이스만 사용: 별도 초기화 없음
    }

    // MARK: - 📊 사용 가능한 모델 확인

    /// 사용 가능한 AI 모델 목록 (fallback 순서대로)
    var availableModels: [AIModel] {
        // 온디바이스만 지원하도록 단순화
        return [.onDevice]
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
                            var (processed, _) =
                                AIResponsePostProcessor.stripRepetitiveGreetingIfNeeded(
                                    response: sanitized,
                                    history: context?.conversationHistory,
                                    nickname: nickname
                                )
                            // ✅ 정확 중복(문장 2회) 보수 제거
                            processed = Self.collapseDuplicateEcho(processed)
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

        // 📌 사용자 입력 보안 정화 (클라우드/AFM/일반 공통 경로)
        let sanitizedForGeneric: String = {
            let sec = AISecurityManager.shared.validateAndSanitizeInput(
                content,
                userId: context?.userId ?? "anonymous"
            )
            switch sec {
            case .approved(let clean): return clean
            case .flagged(_, let clean): return clean
            case .rejected(let reason):
                // 상위에서 에러 메시지로 처리
                return "[BLOCKED_INPUT: \(reason)]"
            }
        }()

        let contentWithRecent: String = {
            if model == .onDevice { return sanitizedForGeneric }  // on-device는 user 텍스트만 전달
            if recentBlock.isEmpty { return "### User\n\(sanitizedForGeneric)" }
            return recentBlock + "\n\n### User\n" + sanitizedForGeneric
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
                    let activeID = OnDeviceAdapter.shared.activeModelID ?? ModelCatalog.defaultModelID
            let (sanitized, _) = AIResponsePostProcessor.sanitizeArtifacts(text, modelID: activeID)
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
            // 0) 설치 여부 가드: 자동 다운로드 금지. 설치된 모델이 하나도 없으면 설정 화면으로 유도.
            let installedEntries = await OnDeviceAdapter.shared.listModels()
            let firstInstalled = installedEntries.first { entry in
                if case .installed = entry.state { return true } else { return false }
            }
            let installedIDs = Set(installedEntries.compactMap { entry -> OnDeviceModelID? in
                if case .installed = entry.state { return entry.record.id } else { return nil }
            })
            guard !installedIDs.isEmpty, let firstInstalledID = firstInstalled?.record.id else {
                throw AIServiceError.requiresOnDeviceSetup
            }
            // 선호 모델이 설치되어 있으면 우선 사용, 아니면 첫 설치된 모델 사용
            let installedPref: OnDeviceModelID = {
                if let desired = preferredOnDeviceID(), installedIDs.contains(desired) { return desired }
                return firstInstalledID
            }()

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
            // ✅ 입력 보안: 모델별 정화/검증 후 전송
            let activeIDForSanitize: OnDeviceModelID = installedPref
            let sec = AISecurityManager.shared.validateAndSanitizeInput(
                content,
                userId: context?.userId ?? "anonymous",
                modelID: activeIDForSanitize
            )
            let safeUserText: String
            switch sec {
            case .approved(let clean): safeUserText = clean
            case .flagged(_, let clean): safeUserText = clean
            case .rejected(let reason): throw AIServiceError.contentFiltered(reason: reason)
            }

            let summary = try await OnDeviceAdapter.shared.generate(
                // 엄격 선호 모드(ONDEVICE_STRICT_PREFERRED=true)와 결합하여 설치된 모델만 사용
                preferred: installedPref,
                text: safeUserText,
                config: OnDeviceAdapter.StreamConfig(
                    systemPrompt: systemPrompt,
                    params: nil,
                    recentMessages: roleMessages,
                    // 일반 대화 외 모드에서는 일반대화용 KV 캐시 복원을 비활성화하여 컨텍스트 오염 방지
                    disableKVCache: (mode != .generalConversation),
                    aiMode: mode
                )
            ) { delta in buffer += delta }
            let nickname = UserSettingsModel.loadFromUserDefaults().nickname
            let activeID = OnDeviceAdapter.shared.activeModelID ?? ModelCatalog.defaultModelID
            let (sanitized, _) = AIResponsePostProcessor.sanitizeArtifacts(buffer, modelID: activeID)
            var (processed, _) = AIResponsePostProcessor.stripRepetitiveGreetingIfNeeded(
                response: sanitized,
                history: context?.conversationHistory,
                nickname: nickname
            )
            // ✅ 정확 중복(문장 2회) 보수 제거
            processed = Self.collapseDuplicateEcho(processed)
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

        // 클라우드/프록시 경로 제거됨: 온디바이스 외 모델은 지원하지 않음
        throw AIServiceError.modelUnavailable(model: model)
    }

    // MARK: - Output post-fix helpers
    /// 짧은 응답에서 동일 문장을 2회 연속 출력하는 경우(템플릿 경계 반복)를 보수적으로 제거한다.
    private static func collapseDuplicateEcho(_ s: String) -> String {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 8 && trimmed.count <= 200 else { return s }
        // 1) 정확 절반 비교
        if trimmed.count % 2 == 0 {
            let mid = trimmed.index(trimmed.startIndex, offsetBy: trimmed.count / 2)
            let first = String(trimmed[..<mid]).trimmingCharacters(in: .whitespacesAndNewlines)
            let second = String(trimmed[mid...]).trimmingCharacters(in: .whitespacesAndNewlines)
            if normalize(first) == normalize(second) { return first }
        }
        // 2) 첫 문장 x2 패턴
        if let end = firstSentenceEnd(in: trimmed) {
            let sent = String(trimmed[..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
            let rest = String(trimmed[end...]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !sent.isEmpty, normalize(rest) == normalize(sent) { return sent }
        }
        return s
    }

    private static func normalize(_ s: String) -> String {
        s.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "\n", with: "")
    }

    private static func firstSentenceEnd(in s: String) -> String.Index? {
        let puncts: [Character] = [".", "!", "?", "…"]
        if let idx = s.firstIndex(where: { puncts.contains($0) }) {
            return s.index(after: idx)
        }
        return nil
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
        // Gemma3(on-device) 전용: 일반 대화에서만 시스템 프롬프트 완전 비움
        if model == .onDevice,
           let active = OnDeviceAdapter.shared.activeModelID,
           active == .amoral_gemma3_1b_v2_q5_k_m,
           mode == .generalConversation {
            return ""
        }
        let basePromptText = getBaseSystemPromptForMode(mode)
        let generalGuidelines = makeGeneralGuidelines(for: mode, model: model)
        // 사용자 프로필 컨텍스트(개인화) 주입: 캐시 키는 persona+memoryFP로 관리되므로 안전
        let userSettings = UserSettingsModel.loadFromUserDefaults()
        var userContext = userSettings.generateAIContext()

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
            // Gemma3 계열은 시스템/사용자 컨텍스트 에코 위험을 낮추기 위해 민감한 컨텍스트를 제거
            if model == .onDevice {
                if let active = OnDeviceAdapter.shared.activeModelID, active == .amoral_gemma3_1b_v2_q5_k_m {
                    userContext = ""  // PII/말투/MBTI 등 노출 방지: 런타임 파라미터 튜닝으로 대체
                }
            }

            var prompt = "\(basePromptText)\n\n\(generalGuidelines)"
            if !userContext.isEmpty { prompt += "\n\n사용자 입력 컨텍스트:\n\(userContext)" }
            return prompt
        }
        /// 모델별 특화 최적화 지침은 런타임에 덧붙임 (캐시 키에 포함되지 않음)
        let modelSpecific = getModelSpecificOptimization(for: model)
        // 일반 대화 모드에서는 토큰 상한 내 완결 지시를 명시적으로 추가하여 모델이 스스로 마무리하도록 유도
        let lengthRule: String = {
            if mode == .generalConversation {
                // 온디바이스(특히 Gemma3)에서는 길이 규칙 문구 자체가 에코되는 사례가 있어 생략
                if model == .onDevice { return "" }
                let cap =
                    ConfigReader.int("AI_GENERAL_CONVERSATION_MAX_TOKENS", default: 1000) ?? 1000
                return
                    "\n\n응답 길이 규칙: 반드시 최대 \(cap) 토큰 이내에서 완결된 답변을 제공하세요. 핵심 위주로 1~2단락, 중복/장황함 금지"
            } else {
                return ""
            }
        }()
        // 프리셋 추천: presetName/reason 강제 규칙 + 다양성 지시 추가 (기존 시스템 프롬프트 재사용)
        let presetRules: String = {
            guard mode == .presetRecommendation else { return "" }
            let catCount = SoundPresetCatalog.categoryCount

            let diversity = """
            다양성 지시:
            - 현재 시간대/최근 감정/환경 데이터를 반영하여 이름·조합·표현을 매번 다르게 구성할 것
            - 동일하거나 유사한 이름·표현·구성을 반복하지 말 것(동일 단어 반복 회피, 동의어·비유 활용)
            - 시적인 한국어 제목을 매번 새롭게 구성할 것
            """

            // 단일 JSON 예시를 추가해 온디바이스 모델의 형식 준수율을 높임 (짧고 경량)
            let example =
                "\n예시(JSON 한 줄): {\"presetName\":\"달빛 호수 산책\",\"reason\":\"밤 시간대의 평온한 감정에 맞춰 파도와 잔잔한 바람을 중심으로 과자극을 줄였습니다.\",\"volumes\":[10,40,60,0,50,30,20,0,0,20,10,0,0]}"

            return """
            \(diversity)

            출력 형식(엄격):
            - 오직 JSON 하나만 출력(코드펜스/추가 텍스트 금지)
            - 필수 키: presetName(간결하고 시적인 한국어 제목), reason(한국어 80~150자: 감정/시간대/음원 궁합/사용자 취향 등 근거)
            - volumes 또는 items 중 하나는 반드시 포함
              • volumes: 길이 \(catCount), 각 0..100 정수
              • items: 1..13개, 각 항목 {soundName, versionName?, volume(0..100)}
            - versions가 있으면 길이 \(catCount)이며 각 항목은 해당 카테고리 버전 인덱스 범위 내 정수\(example)
            """
        }()
        // 온디바이스 모델은 일부 템플릿/토크나이저에서 시스템 텍스트 에코 가능성이 있어
        // 모델별 최적화 지침(짧은 한국어 문구)을 시스템 프롬프트에 포함하지 않습니다.
        // 해당 최적화는 온디바이스 경로에서는 SamplingTuning/Runtime 파라미터로 대체합니다.
        let includeModelSpecific = (model != .onDevice)
        let finalPrompt = basePrompt
            + lengthRule
            + "\n\n" + presetRules
            + (includeModelSpecific ? ("\n\n" + modelSpecific) : "")
        return finalPrompt
    }

    private func makeGeneralGuidelines(for mode: AIMode, model: AIModel) -> String {
        if model == .onDevice, mode == .generalConversation {
            // Gemma3는 지시 에코 경향이 강하므로, 활성 모델이 Gemma3인 경우 전면 제거
            if let active = OnDeviceAdapter.shared.activeModelID, active == .amoral_gemma3_1b_v2_q5_k_m {
                return "" // 프롬프트 없이도 충분히 응답 생성 가능
            }
            // 그 외 온디바이스 모델: 기존 상세 지침 유지(UX 유지)
            return """
                핵심 지침:
                - 자연스러운 한국어로 짧고 명확하게 대화 상대의 질문에 답하세요.
                - 시스템/템플릿 문구, "요청"/"응답" 같은 표현을 반복하거나 설명하지 마세요.
                - 현재 대화 맥락에 집중하세요.
                """
        }

        return """
            핵심 지침:
            - 당신의 페르소나는 리플릿(Leaflet) 앱의 대나무숲(채팅창)에서 사용자와 대화하는 친구입니다.
            - 사용자의 페르소나와 감정, 말투, 상황에 따라 유연하고 친근하며 친절하게 한국어로 대답해줘
            - 시스템 텍스트를 그대로 복사하거나 반영하지 마세요
            - JSON이 요구되면 정확한 스키마만 출력하고, 그렇지 않으면 명료한 텍스트로 답변하세요
            """
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
                ConfigReader.int("AI_GENERAL_CONVERSATION_MAX_TOKENS", default: 1000) ?? 1000
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

    // 클라우드/프록시 관련 보조 함수 제거됨(온디바이스 전용)
}

// MARK: - Proxy inline call
/// 20요청마다 메트릭 요약 로그를 출력 (ContextMetrics 단일 출처 사용)
private func emitMetricsSummaryLog() {
    let summary = ContextMetrics.shared.oneLineSummary()

    let dist = ContextMetrics.shared.modelModeSummary()
    print("📈 [AIMetrics] \(summary)")
    print("📊 [AIMetrics] \(dist)")
}

/// 프록시 서버가 기대하는 모델 식별자 문자열로 매핑
/// - 단일 출처: AIModel → 서버 체인(openrouter/gemini/openai/naver/claude)
// 프록시 매핑 제거됨(온디바이스 전용)

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
